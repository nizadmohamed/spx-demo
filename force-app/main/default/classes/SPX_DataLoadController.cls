/**
 * Demo-only CSV loader behind the "SPX Data Load" tab. Simulates an integration feed.
 * Not part of the production build. Runs with the user's sharing and FLS.
 * CSV headers are field API names; lookups use Rel__r.ExternalIdField__c (e.g. Project__r.CC_Project_ID__c).
 * Insights and Competitors: only when BOTH an Opportunity and a Project reference are on the row, the Project
 * must be the Opportunity's project, otherwise the row is rejected.
 */
public with sharing class SPX_DataLoadController {

    private static final Integer MAX_ROWS = 5000;
    private static final Integer MAX_ERRORS = 50;

    // key -> [sObject, upsert external id field or blank, comma-separated match fields or blank]
    // Match fields: no external id; an existing record with the same values in ALL match fields is updated,
    // none = insert (also when a row lacks any match value), several = row rejected as ambiguous.
    // Leads: CC Project ID + Brand + Market (Vertical__c).
    private static final Map<String, List<String>> CONFIG = new Map<String, List<String>>{
        // Projects: matched in code (see matchProjects): CC Project ID first, then Project Reference
        'Projects'     => new List<String>{ 'Project__c', '', '' },
        'Leads'        => new List<String>{ 'Lead', '', 'CC_Project_ID__c,Brand__c,Vertical__c' },
        'Stakeholders' => new List<String>{ 'Project_Relationship__c', '', '' },
        'Insights'     => new List<String>{ 'Project_Intelligence__c', '', '' },
        'Competitors'  => new List<String>{ 'Opportunity_Competitor__c', '', '' }
    };

    // Objects that must have an Opportunity and whose Project (if given) must match it
    private static final String PROJECT_REF = 'Project_Reference__c';

    private static final Set<String> OPP_CHILD_KEYS = new Set<String>{ 'Insights', 'Competitors' };

    public class LoadResult {
        @AuraEnabled public String key;
        @AuraEnabled public Integer total = 0;
        @AuraEnabled public Integer created = 0;
        @AuraEnabled public Integer updated = 0;
        @AuraEnabled public Integer failed = 0;
        @AuraEnabled public List<String> errors = new List<String>();
        @AuraEnabled public String fatalError;
        @AuraEnabled public String successCsv;
        @AuraEnabled public String errorCsv;
    }

    private class LookupInfo {
        String field;
        String targetObject;
        String targetField;
        Map<String, Id> ids = new Map<String, Id>();
        Set<String> ambiguous = new Set<String>();
    }

    @AuraEnabled
    public static LoadResult loadCsv(String objectKey, String csvText) {
        LoadResult res = new LoadResult();
        res.key = objectKey;
        try {
            List<String> cfg = CONFIG.get(objectKey);
            if (cfg == null) {
                res.fatalError = 'Unknown object key: ' + objectKey;
                return res;
            }
            String objName = cfg[0];
            String extField = cfg[1];
            String matchField = cfg[2];
            List<String> matchFields = matchField == '' ? new List<String>() : matchField.split(',');

            List<List<String>> rows = parseCsv(csvText);
            if (rows.size() < 2) {
                res.fatalError = 'The file has no data rows.';
                return res;
            }
            if (rows.size() - 1 > MAX_ROWS) {
                res.fatalError = 'Too many rows (max ' + MAX_ROWS + ').';
                return res;
            }

            Schema.SObjectType sot = Schema.getGlobalDescribe().get(objName);
            Map<String, Schema.SObjectField> fmap = sot.getDescribe().fields.getMap();
            List<String> headers = new List<String>();
            for (String h : rows[0]) {
                headers.add(h.trim());
            }

            // Resolve lookup columns first (Rel__r.Ext__c)
            Map<Integer, LookupInfo> lookups = new Map<Integer, LookupInfo>();
            for (Integer c = 0; c < headers.size(); c++) {
                String h = headers[c];
                if (h.contains('.')) {
                    List<String> parts = h.split('\\.');
                    String relName = parts[0];
                    String lookupField = relName.endsWith('__r') ? relName.removeEnd('__r') + '__c' : relName + 'Id';
                    Schema.SObjectField lf = fmap.get(lookupField);
                    if (lf == null) {
                        res.fatalError = 'Unknown lookup column: ' + h;
                        return res;
                    }
                    LookupInfo li = new LookupInfo();
                    li.field = lookupField;
                    li.targetObject = lf.getDescribe().getReferenceTo()[0].getDescribe().getName();
                    li.targetField = parts[1];
                    lookups.put(c, li);
                } else if (!fmap.containsKey(h)) {
                    res.fatalError = 'Unknown column "' + h + '" for ' + objName + '.';
                    return res;
                }
            }
            for (Integer c : lookups.keySet()) {
                resolveLookup(lookups.get(c), rows, c);
            }

            // For Insights / Competitors: the Opportunity's project, to validate a given Project reference
            Boolean oppChild = OPP_CHILD_KEYS.contains(objectKey);
            Map<Id, Id> oppProject = new Map<Id, Id>();
            if (oppChild) {
                Set<Id> oppIds = new Set<Id>();
                for (LookupInfo li : lookups.values()) {
                    if (li.field == 'Opportunity__c') {
                        oppIds.addAll(li.ids.values());
                    }
                }
                if (!oppIds.isEmpty()) {
                    for (Opportunity o : [SELECT Id, Project__c FROM Opportunity WHERE Id IN :oppIds WITH USER_MODE]) {
                        oppProject.put(o.Id, o.Project__c);
                    }
                }
            }

            Boolean isProjects = objectKey == 'Projects';
            Map<Integer, String> refByRow = new Map<Integer, String>();
            Map<Integer, String> errByRow = new Map<Integer, String>();
            List<SObject> recs = (List<SObject>) Type.forName('List<' + objName + '>').newInstance();
            List<Integer> rowNums = new List<Integer>();
            for (Integer r = 1; r < rows.size(); r++) {
                List<String> row = rows[r];
                SObject rec = sot.newSObject();
                String rowError = null;
                for (Integer c = 0; c < headers.size() && c < row.size() && rowError == null; c++) {
                    String v = row[c] == null ? '' : row[c].trim();
                    if (v == '') {
                        continue;
                    }
                    if (lookups.containsKey(c)) {
                        LookupInfo li = lookups.get(c);
                        Id target = li.ids.get(v);
                        if (target == null) {
                            rowError = 'No ' + li.targetObject + ' found with ' + li.targetField + ' = ' + v;
                        } else if (li.ambiguous.contains(v)) {
                            rowError = 'More than one ' + li.targetObject + ' has ' + li.targetField + ' = ' + v
                                + '. Cannot tell which one to use.';
                        } else {
                            rec.put(li.field, target);
                        }
                    } else if (isProjects && headers[c] == PROJECT_REF) {
                        refByRow.put(r, v); // auto-number: used only to find an existing Project
                    } else {
                        try {
                            rec.put(headers[c], convert(fmap.get(headers[c]), v));
                        } catch (Exception e) {
                            rowError = headers[c] + ': cannot read "' + v + '"';
                        }
                    }
                }
                if (rowError == null && oppChild) {
                    rowError = checkOpportunityProject(
                        (Id) rec.get('Opportunity__c'), (Id) rec.get('Project__c'), oppProject);
                }
                res.total++;
                if (rowError != null) {
                    res.failed++;
                    errByRow.put(r, rowError);
                    addError(res, r, rowError);
                    continue;
                }
                recs.add(rec);
                rowNums.add(r);
            }

            Map<Integer, String> okByRow = new Map<Integer, String>();
            // Match on all match fields (Leads: CC Project ID + Brand + Market): update the one existing
            // record, insert when none
            if (!matchFields.isEmpty() && !recs.isEmpty()) {
                Set<String> keys = new Set<String>();
                for (SObject s : recs) {
                    if (s.get(matchFields[0]) != null) {
                        keys.add(String.valueOf(s.get(matchFields[0])));
                    }
                }
                Map<String, List<SObject>> existing = new Map<String, List<SObject>>();
                if (!keys.isEmpty()) {
                    String q = 'SELECT Id, Project__c, ' + String.join(matchFields, ', ') + ' FROM ' + objName
                        + ' WHERE ' + matchFields[0] + ' IN :keys'
                        // A converted lead cannot be updated, so it is never a match: the row is loaded as a new lead
                        + (objName == 'Lead' ? ' AND IsConverted = false' : '')
                        + ' WITH USER_MODE';
                    for (SObject e : Database.query(q)) {
                        String k = matchKey(e, matchFields);
                        if (k != null) {
                            if (!existing.containsKey(k)) {
                                existing.put(k, new List<SObject>());
                            }
                            existing.get(k).add(e);
                        }
                    }
                }
                List<SObject> kept = (List<SObject>) Type.forName('List<' + objName + '>').newInstance();
                List<Integer> keptRows = new List<Integer>();
                for (Integer i = 0; i < recs.size(); i++) {
                    SObject s = recs[i];
                    String rowKey = matchKey(s, matchFields);
                    List<SObject> m = rowKey == null ? null : existing.get(rowKey);
                    if (m != null && m.size() > 1) {
                        res.failed++;
                        errByRow.put(rowNums[i], m.size() + ' existing records match ' + String.join(matchFields, ' + ')
                            + ' (' + rowKey.replace('|', ' | ') + '). Cannot tell which one to update.');
                        addError(res, rowNums[i], errByRow.get(rowNums[i]));
                        continue;
                    }
                    kept.add(m == null || m.isEmpty() ? s : applyExisting(s, m[0], sot));
                    keptRows.add(rowNums[i]);
                }
                recs = kept;
                rowNums = keptRows;
            }
            if (isProjects && !recs.isEmpty()) {
                matchProjects(recs, rowNums, refByRow, errByRow, res);
                List<SObject> keptP = (List<SObject>) Type.forName('List<' + objName + '>').newInstance();
                List<Integer> keptPRows = new List<Integer>();
                for (Integer i = 0; i < recs.size(); i++) {
                    if (!errByRow.containsKey(rowNums[i])) {
                        keptP.add(recs[i]);
                        keptPRows.add(rowNums[i]);
                    }
                }
                recs = keptP;
                rowNums = keptPRows;
            }
            if (!recs.isEmpty()) {
                Boolean useUpsert = extField != '' || !matchFields.isEmpty() || isProjects;
                SObjectAccessDecision dec = Security.stripInaccessible(
                    useUpsert ? AccessType.UPSERTABLE : AccessType.CREATABLE, recs);
                List<SObject> clean = dec.getRecords();

                if (!useUpsert) {
                    Database.DMLOptions dmlI = new Database.DMLOptions();
                    dmlI.duplicateRuleHeader.allowSave = true;
                    dmlI.optAllOrNone = false;
                    List<Database.SaveResult> srs = Database.insert(clean, dmlI);
                    for (Integer i = 0; i < srs.size(); i++) {
                        if (srs[i].isSuccess()) {
                            res.created++;
                            okByRow.put(rowNums[i], srs[i].getId() + ',Created');
                        } else {
                            res.failed++;
                            errByRow.put(rowNums[i], firstMsg(srs[i].getErrors()));
                            addError(res, rowNums[i], errByRow.get(rowNums[i]));
                        }
                    }
                } else {
                    // Rows with an Id are updated, the rest inserted. Duplicate rules that only warn (alert)
                    // must not stop a deliberate file load, so the save is allowed through them.
                    Database.DMLOptions dml = new Database.DMLOptions();
                    dml.duplicateRuleHeader.allowSave = true;
                    dml.optAllOrNone = false;
                    List<SObject> toUpdate = (List<SObject>) Type.forName('List<' + objName + '>').newInstance();
                    List<Integer> updRows = new List<Integer>();
                    List<SObject> toInsert = (List<SObject>) Type.forName('List<' + objName + '>').newInstance();
                    List<Integer> insRows = new List<Integer>();
                    for (Integer i = 0; i < clean.size(); i++) {
                        if (clean[i].Id != null) {
                            toUpdate.add(clean[i]);
                            updRows.add(rowNums[i]);
                        } else {
                            toInsert.add(clean[i]);
                            insRows.add(rowNums[i]);
                        }
                    }
                    if (extField != '') {
                        // not used today; kept for objects configured with an external id
                        List<Database.UpsertResult> urs = Database.upsert(clean, fmap.get(extField), false);
                        for (Integer i = 0; i < urs.size(); i++) {
                            recordResult(res, okByRow, errByRow, rowNums[i], urs[i].isSuccess(), urs[i].getId(),
                                urs[i].isCreated(), urs[i].getErrors());
                        }
                    } else {
                        List<Database.SaveResult> uSrs = Database.update(toUpdate, dml);
                        for (Integer i = 0; i < uSrs.size(); i++) {
                            recordResult(res, okByRow, errByRow, updRows[i], uSrs[i].isSuccess(), uSrs[i].getId(),
                                false, uSrs[i].getErrors());
                        }
                        List<Database.SaveResult> iSrs = Database.insert(toInsert, dml);
                        for (Integer i = 0; i < iSrs.size(); i++) {
                            recordResult(res, okByRow, errByRow, insRows[i], iSrs[i].isSuccess(), iSrs[i].getId(),
                                true, iSrs[i].getErrors());
                        }
                    }
                }
            }
            buildResultFiles(res, rows, headers, okByRow, errByRow);
        } catch (Exception e) {
            res.fatalError = e.getMessage();
        }
        return res;
    }

    /**
     * Projects: sets Id on rows that match an existing Project, so the upsert updates them.
     * 1) CC Project ID; 2) if that finds nothing, Project Reference (the update then also writes the CC Project ID);
     * 3) neither matches: Id stays blank and a new Project is created.
     * Rows are rejected when the keys point at different Projects, or two rows hit the same Project.
     */
    @TestVisible
    private static void matchProjects(List<SObject> recs, List<Integer> rowNums, Map<Integer, String> refByRow,
            Map<Integer, String> errByRow, LoadResult res) {
        Set<String> ccIds = new Set<String>();
        Set<String> refs = new Set<String>();
        for (Integer i = 0; i < recs.size(); i++) {
            String cc = (String) recs[i].get('CC_Project_ID__c');
            if (String.isNotBlank(cc)) {
                ccIds.add(cc);
            }
            String ref = refByRow.get(rowNums[i]);
            if (String.isNotBlank(ref)) {
                refs.add(ref);
            }
        }
        // Sharing applies; field-level security is not checked for these two lookup fields
        Map<String, Id> byCc = new Map<String, Id>();
        for (Project__c p : [SELECT Id, CC_Project_ID__c FROM Project__c WHERE CC_Project_ID__c IN :ccIds]) {
            byCc.put(p.CC_Project_ID__c.toLowerCase(), p.Id);
        }
        Map<String, Id> byRef = new Map<String, Id>();
        for (Project__c p : [SELECT Id, Project_Reference__c FROM Project__c WHERE Project_Reference__c IN :refs]) {
            byRef.put(p.Project_Reference__c.toLowerCase(), p.Id);
        }
        Set<Id> used = new Set<Id>();
        Set<String> newCc = new Set<String>();
        for (Integer i = 0; i < recs.size(); i++) {
            Integer rn = rowNums[i];
            String cc = (String) recs[i].get('CC_Project_ID__c');
            String ref = refByRow.get(rn);
            Id viaCc = String.isBlank(cc) ? null : byCc.get(cc.toLowerCase());
            Id viaRef = String.isBlank(ref) ? null : byRef.get(ref.toLowerCase());
            String err = null;
            if (viaCc != null && viaRef != null && viaCc != viaRef) {
                err = 'CC Project ID ' + cc + ' and Project Reference ' + ref + ' belong to two different Projects.';
            }
            Id target = viaCc != null ? viaCc : viaRef;
            if (err == null && target != null) {
                if (used.contains(target)) {
                    err = 'Another row in this file already updates the same Project.';
                } else {
                    used.add(target);
                    recs[i].put('Id', target);
                }
            } else if (err == null && String.isNotBlank(cc) && !newCc.add(cc.toLowerCase())) {
                err = 'Another row in this file already creates a Project with CC Project ID ' + cc + '.';
            }
            if (err != null) {
                res.failed++;
                errByRow.put(rn, err);
                addError(res, rn, err);
            }
        }
    }

    /** Joins the match field values; null when any of them is blank (such a row cannot be matched). */
    @TestVisible
    private static String matchKey(SObject s, List<String> fields) {
        List<String> parts = new List<String>();
        for (String f : fields) {
            Object v = s.get(f);
            if (v == null || String.valueOf(v).trim() == '') {
                return null;
            }
            parts.add(String.valueOf(v).trim().toLowerCase());
        }
        return String.join(parts, '|');
    }

    /**
     * Turns a row into an update of the existing record. A Project in the file only fills an empty Project:
     * if the existing record already has one, Project__c is left out of the update.
     */
    @TestVisible
    private static SObject applyExisting(SObject row, SObject existing, Schema.SObjectType sot) {
        SObject copy = sot.newSObject(existing.Id);
        Boolean keepProject = existing.get('Project__c') != null;
        Map<String, Object> populated = row.getPopulatedFieldsAsMap();
        for (String k : populated.keySet()) {
            if (k != 'Id' && !(k == 'Project__c' && keepProject)) {
                copy.put(k, populated.get(k));
            }
        }
        return copy;
    }

    /** Only when BOTH Opportunity and Project are on the row: error if the Opportunity's project differs. */
    @TestVisible
    private static String checkOpportunityProject(Id oppId, Id projectId, Map<Id, Id> oppProject) {
        if (oppId == null || projectId == null) {
            return null;
        }
        Id actual = oppProject.get(oppId);
        if (actual == null) {
            return 'The Opportunity has no Project, so it cannot belong to the Project given in the file.';
        }
        if (actual != projectId) {
            return 'The Opportunity belongs to a different Project than the one given in the file.';
        }
        return null;
    }

    private static void buildResultFiles(LoadResult res, List<List<String>> rows, List<String> headers,
            Map<Integer, String> okByRow, Map<Integer, String> errByRow) {
        String base = csvLine(headers);
        String ok = 'sf__Id,sf__Result,' + base + '\n';
        String err = 'sf__Error,' + base + '\n';
        for (Integer r = 1; r < rows.size(); r++) {
            List<String> row = new List<String>();
            for (Integer c = 0; c < headers.size(); c++) {
                row.add(c < rows[r].size() ? rows[r][c] : '');
            }
            if (okByRow.containsKey(r)) {
                ok += okByRow.get(r) + ',' + csvLine(row) + '\n';
            } else if (errByRow.containsKey(r)) {
                err += csvCell(errByRow.get(r)) + ',' + csvLine(row) + '\n';
            }
        }
        res.successCsv = ok;
        res.errorCsv = err;
    }

    private static String csvLine(List<String> cells) {
        List<String> out = new List<String>();
        for (String c : cells) {
            out.add(csvCell(c));
        }
        return String.join(out, ',');
    }

    private static String csvCell(String s) {
        if (s == null) {
            return '';
        }
        if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
            return '"' + s.replace('"', '""') + '"';
        }
        return s;
    }

    private static void resolveLookup(LookupInfo li, List<List<String>> rows, Integer col) {
        Set<String> vals = new Set<String>();
        for (Integer r = 1; r < rows.size(); r++) {
            if (col < rows[r].size() && String.isNotBlank(rows[r][col])) {
                vals.add(rows[r][col].trim());
            }
        }
        if (vals.isEmpty()) {
            return;
        }
        String soql = 'SELECT Id, ' + String.escapeSingleQuotes(li.targetField) + ' FROM '
            + String.escapeSingleQuotes(li.targetObject) + ' WHERE ' + String.escapeSingleQuotes(li.targetField)
            + ' IN :vals WITH USER_MODE';
        for (SObject s : Database.query(soql)) {
            String key = String.valueOf(s.get(li.targetField));
            if (li.ids.containsKey(key)) {
                li.ambiguous.add(key);
            }
            li.ids.put(key, s.Id);
        }
    }

    private static Object convert(Schema.SObjectField f, String v) {
        Schema.DisplayType t = f.getDescribe().getType();
        if (t == Schema.DisplayType.BOOLEAN) {
            return v.equalsIgnoreCase('true') || v == '1' || v.equalsIgnoreCase('yes');
        }
        if (t == Schema.DisplayType.DATE) {
            return parseDate(v);
        }
        if (t == Schema.DisplayType.DATETIME) {
            return (Datetime) JSON.deserialize('"' + v + '"', Datetime.class);
        }
        if (t == Schema.DisplayType.INTEGER) {
            return Integer.valueOf(v);
        }
        if (t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.PERCENT) {
            return Decimal.valueOf(v);
        }
        return v;
    }

    /** ISO (2030-12-15) or US month/day/year (12/15/2030, as Excel shows it). */
    @TestVisible
    private static Date parseDate(String v) {
        if (v.contains('/')) {
            List<String> p = v.split('/');
            if (p.size() == 3) {
                return Date.newInstance(Integer.valueOf(p[2].trim()), Integer.valueOf(p[0].trim()),
                    Integer.valueOf(p[1].trim()));
            }
        }
        return Date.valueOf(v);
    }

    private static void recordResult(LoadResult res, Map<Integer, String> okByRow, Map<Integer, String> errByRow,
            Integer rowNum, Boolean success, Id recId, Boolean created, List<Database.Error> errs) {
        if (success) {
            if (created) {
                res.created++;
            } else {
                res.updated++;
            }
            okByRow.put(rowNum, recId + ',' + (created ? 'Created' : 'Updated'));
        } else {
            res.failed++;
            errByRow.put(rowNum, firstMsg(errs));
            addError(res, rowNum, errByRow.get(rowNum));
        }
    }

    private static String firstMsg(List<Database.Error> errs) {
        return errs.isEmpty() ? 'Unknown error' : errs[0].getMessage();
    }

    private static void addError(LoadResult res, Integer rowIdx, String msg) {
        if (res.errors.size() < MAX_ERRORS) {
            res.errors.add('Row ' + (rowIdx + 1) + ': ' + msg);
        }
    }

    /** RFC-4180 style parser: quotes, escaped quotes, embedded commas/newlines, BOM. */
    @TestVisible
    private static List<List<String>> parseCsv(String s) {
        List<List<String>> out = new List<List<String>>();
        if (s == null) {
            return out;
        }
        if (s.length() > 0 && s.charAt(0) == 65279) {
            s = s.substring(1);
        }
        List<String> row = new List<String>();
        String cur = '';
        Boolean inQ = false;
        Integer n = s.length();
        for (Integer i = 0; i < n; i++) {
            String ch = s.substring(i, i + 1);
            if (inQ) {
                if (ch == '"') {
                    if (i + 1 < n && s.substring(i + 1, i + 2) == '"') {
                        cur += '"';
                        i++;
                    } else {
                        inQ = false;
                    }
                } else {
                    cur += ch;
                }
            } else if (ch == '"') {
                inQ = true;
            } else if (ch == ',') {
                row.add(cur);
                cur = '';
            } else if (ch == '\n' || ch == '\r') {
                if (ch == '\r' && i + 1 < n && s.substring(i + 1, i + 2) == '\n') {
                    i++;
                }
                row.add(cur);
                cur = '';
                if (!(row.size() == 1 && row[0] == '')) {
                    out.add(row);
                }
                row = new List<String>();
            } else {
                cur += ch;
            }
        }
        if (cur != '' || !row.isEmpty()) {
            row.add(cur);
            out.add(row);
        }
        return out;
    }
}
