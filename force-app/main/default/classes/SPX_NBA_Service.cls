/**
 * Next Best Action recommender for a Project.
 *  1. buildContext gathers the project, its opportunities, leads, existing actions, intelligence, stakeholders,
 *     competitors, activities and file text into one block of text.
 *  2. The prompt template SPX_NBA_Recommendations turns that and the guidance file into a JSON list of actions.
 *  3. The actions are saved as Next_Best_Action__c records with Status = Suggested, owned by the running user.
 * Runs with sharing. Called by a screen flow button and by the segment assistant agent.
 */
public with sharing class SPX_NBA_Service {

    public static final String TEMPLATE = 'SPX_NBA_Recommendations';
    public static final Integer MAX_ROWS = 25;
    public static final Integer MIN_ACTIONS = 4;
    public static final Integer MAX_ATTEMPTS = 3;
    private static final Integer NOTE_CHARS = 300;
    private static final Set<String> PRIORITIES = new Set<String>{ 'High', 'Medium', 'Low' };

    public interface LlmClient {
        String generate(String context, String guidance);
    }

    /** Calls the prompt template through Connect API. */
    public class ConnectApiLlm implements LlmClient {
        public String generate(String context, String guidance) {
            ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            input.isPreview = false;
            input.inputParams = new Map<String, ConnectApi.WrappedValue>();
            input.inputParams.put('Input:Context', wrap(context));
            input.inputParams.put('Input:Guidance', wrap(guidance));
            input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            input.additionalConfig.applicationName = 'PromptBuilderPreview';
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation rep =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(TEMPLATE, input);
            if (rep == null || rep.generations == null || rep.generations.isEmpty()) {
                throw new NbaException('The prompt template returned no text.');
            }
            return rep.generations[0].text;
        }
        private ConnectApi.WrappedValue wrap(String s) {
            ConnectApi.WrappedValue w = new ConnectApi.WrappedValue();
            w.value = s == null ? '' : s;
            return w;
        }
    }

    public class NbaException extends Exception {}

    @TestVisible
    private static LlmClient client = new ConnectApiLlm();

    public class Request {
        @InvocableVariable(label='Project Id' required=true)
        public Id projectId;
    }

    public class Result {
        @InvocableVariable(label='Message')
        public String message;
        @InvocableVariable(label='Created Count')
        public Integer createdCount;
        @InvocableVariable(label='Skipped Count')
        public Integer skippedCount;
        @InvocableVariable(label='Run Id')
        public String runId;
        @InvocableVariable(label='Created Actions')
        public String createdActions;
    }

    @InvocableMethod(
        label='SPX NBA Recommend Next Actions'
        description='Reviews a Project and its related records and files, then saves suggested Next Best Actions.'
    )
    public static List<Result> recommend(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            out.add(recommendOne(r.projectId));
        }
        return out;
    }

    public static Result recommendOne(Id projectId) {
        Result res = new Result();
        res.createdCount = 0;
        res.skippedCount = 0;
        res.createdActions = '';
        try {
            SPX_NBA_ReadFiles.Result files = SPX_NBA_ReadFiles.readOne(projectId);
            String context = buildContext(projectId, files);
            // The model sometimes answers with too few actions, so ask again (up to 3 tries) and keep the fullest answer.
            List<Next_Best_Action__c> parsed = new List<Next_Best_Action__c>();
            for (Integer attempt = 0; attempt < MAX_ATTEMPTS && parsed.size() < MIN_ACTIONS; attempt++) {
                List<Next_Best_Action__c> tryRows = parseActions(client.generate(context, files.guidanceText), projectId);
                if (tryRows.size() > parsed.size()) {
                    parsed = tryRows;
                }
            }
            save(parsed, projectId, res);
        } catch (Exception e) {
            res.message = 'No actions were created: ' + e.getMessage();
        }
        return res;
    }

    // ---------- context ----------

    public static String buildContext(Id projectId, SPX_NBA_ReadFiles.Result files) {
        Project__c p = [
            SELECT Name, Project_Reference__c, Vertical__c, Project_Phase__c, Project_Status__c, Project_Source__c,
                   Estimated_Construction_Value__c, Estimated_Construction_Start__c, Estimated_Completion__c,
                   City__c, State__c, Territory__c, Strategic_Project__c, Total_SPX_Potential__c,
                   Brands_Engaged__c, BOD_Secured__c, Engineer_of_Record__r.Name, GC__r.Name
            FROM Project__c WHERE Id = :projectId
        ];
        List<String> needs = new List<String>();
        String t = 'TODAY: ' + Date.today().format() + '\n\n## PROJECT\n';
        t += line('Name', p.Name) + line('Reference', p.Project_Reference__c) + line('Vertical', p.Vertical__c)
            + line('Phase', p.Project_Phase__c) + line('Status', p.Project_Status__c) + line('Source', p.Project_Source__c)
            + line('Estimated construction value', p.Estimated_Construction_Value__c)
            + line('Construction start', p.Estimated_Construction_Start__c) + line('Completion', p.Estimated_Completion__c)
            + line('City / State', p.City__c + ' / ' + p.State__c) + line('Territory', p.Territory__c)
            + line('Strategic project', p.Strategic_Project__c) + line('Total SPX potential', p.Total_SPX_Potential__c)
            + line('Brands engaged', p.Brands_Engaged__c) + line('BOD secured', p.BOD_Secured__c)
            + line('Engineer of record', p.Engineer_of_Record__r.Name) + line('General contractor', p.GC__r.Name);

        // Strobic key fields are only read when the running user can see them (field level security).
        Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
        List<String> extra = new List<String>();
        for (String fn : new List<String>{ 'Exhaust_Dispersion_Study_Status__c', 'Lab_Exhaust_Application_Class__c' }) {
            if (oppFields.containsKey(fn) && oppFields.get(fn).getDescribe().isAccessible()) {
                extra.add(fn);
            }
        }
        Integer rowLimit = MAX_ROWS;
        String oppSoql = 'SELECT Name, Brand__c, StageName, Amount, CloseDate, BOD_Status__c, Current_Status__c, NextStep, Owner.Name'
            + (extra.isEmpty() ? '' : ', ' + String.join(extra, ', '))
            + ' FROM Opportunity WHERE Project__c = :projectId ORDER BY Amount DESC NULLS LAST LIMIT :rowLimit';
        List<Opportunity> opps = Database.query(oppSoql);
        t += '\n## OPPORTUNITIES (' + opps.size() + ')\n';
        Set<Id> whatIds = new Set<Id>{ projectId };
        for (Opportunity o : opps) {
            whatIds.add(o.Id);
            t += '- ' + o.Name + ' | brand ' + o.Brand__c + ' | stage ' + o.StageName + ' | amount ' + o.Amount
                + ' | close ' + fmt(o.CloseDate) + ' | BOD ' + o.BOD_Status__c + ' | status ' + o.Current_Status__c
                + ' | next step ' + o.NextStep + ' | owner ' + o.Owner.Name;
            for (String fn : extra) {
                t += ' | ' + oppFields.get(fn).getDescribe().getLabel() + ' ' + o.get(fn);
            }
            t += '\n';
        }

        List<Lead> leads = [
            SELECT Name, Company, Brand__c, Status, Vertical__c, Est_Brand_Potential__c, BOD_Status__c, Owner.Name
            FROM Lead WHERE Project__c = :projectId AND IsConverted = false LIMIT :MAX_ROWS
        ];
        t += '\n## LEADS (' + leads.size() + ')\n';
        for (Lead l : leads) {
            t += '- Lead contact ' + l.Name + ' at ' + l.Company + ' | brand ' + l.Brand__c + ' | status ' + l.Status
                + (l.Status == 'New' ? ' (NOT YET CONTACTED)' : '')
                + ' | potential ' + l.Est_Brand_Potential__c + ' | BOD ' + l.BOD_Status__c
                + ' | SPX lead owner (an SPX employee, not the contact) ' + l.Owner.Name + '\n';
            if (l.Status == 'New') {
                needs.add('Lead not yet contacted: ' + l.Name + ' at ' + l.Company + ' for brand ' + l.Brand__c);
            }
        }

        List<Next_Best_Action__c> nbas = [
            SELECT Name, Status__c, Priority__c, Due_Date__c, Brand__c FROM Next_Best_Action__c
            WHERE Project__c = :projectId ORDER BY CreatedDate DESC LIMIT :MAX_ROWS
        ];
        t += '\n## EXISTING NEXT BEST ACTIONS (do not repeat these)\n';
        for (Next_Best_Action__c n : nbas) {
            t += '- ' + n.Name + ' | ' + n.Status__c + ' | ' + n.Priority__c + ' | due ' + fmt(n.Due_Date__c) + '\n';
        }
        if (nbas.isEmpty()) {
            t += 'none\n';
        }

        t += '\n## PROJECT INTELLIGENCE\n';
        for (Project_Intelligence__c i : [
            SELECT Name, Project_Intelligence_Type__c, Brand__c, Insight_Type__c, Detailed_Notes__c
            FROM Project_Intelligence__c WHERE Project__c = :projectId ORDER BY CreatedDate DESC LIMIT :MAX_ROWS
        ]) {
            t += '- [' + i.Project_Intelligence_Type__c + '] ' + i.Name + ' | brand ' + i.Brand__c + ' | '
                + i.Insight_Type__c + ' | ' + cut(i.Detailed_Notes__c) + '\n';
            if (i.Project_Intelligence_Type__c == 'Risk' || i.Project_Intelligence_Type__c == 'Channel Conflict') {
                needs.add(i.Project_Intelligence_Type__c + ' to resolve: ' + i.Name);
            }
        }

        t += '\n## PROJECT STAKEHOLDERS\n';
        for (Project_Relationship__c r : [
            SELECT Account__r.Name, Relationship_Type__c, Status__c, Positive_Brand_Rel_Text__c,
                   Neutral_Brand_Rel_Text__c, Negative_Brand_Rel_Text__c
            FROM Project_Relationship__c WHERE Project__c = :projectId LIMIT :MAX_ROWS
        ]) {
            t += '- ' + r.Account__r.Name + ' | ' + r.Relationship_Type__c + ' | status ' + r.Status__c
                + (r.Status__c == 'Pending' ? ' (NEEDS CONFIRMATION)' : '')
                + ' | positive brands: ' + r.Positive_Brand_Rel_Text__c + ' | neutral: ' + r.Neutral_Brand_Rel_Text__c
                + ' | negative: ' + r.Negative_Brand_Rel_Text__c + '\n';
            if (r.Status__c == 'Pending') {
                needs.add('Stakeholder to confirm: ' + r.Account__r.Name + ' (' + r.Relationship_Type__c + ')');
            }
        }

        t += '\n## COMPETITORS\n';
        for (Opportunity_Competitor__c c : [
            SELECT Name, Brands_Text__c, Referenced_in_Spec__c, Strengths__c, Weaknesses__c, Competitor_Account__r.Name,
                   Opportunity__r.Name
            FROM Opportunity_Competitor__c WHERE Project__c = :projectId LIMIT :MAX_ROWS
        ]) {
            t += '- ' + c.Name + ' | account ' + c.Competitor_Account__r.Name + ' | brands ' + c.Brands_Text__c
                + ' | in spec ' + c.Referenced_in_Spec__c + ' | opportunity ' + c.Opportunity__r.Name
                + ' | strengths ' + cut(c.Strengths__c) + ' | weaknesses ' + cut(c.Weaknesses__c) + '\n';
            if (c.Referenced_in_Spec__c == true) {
                needs.add('Competitor named in the spec: ' + c.Name + ' (plan a substitution request and an engineer meeting; use the deadline in the spec file)');
            }
        }

        t += '\n## ACTIVITIES (tasks and events on the project and its opportunities)\n';
        for (Task k : [
            SELECT Subject, Status, ActivityDate, IsClosed, Owner.Name FROM Task WHERE WhatId IN :whatIds
            ORDER BY ActivityDate DESC NULLS LAST LIMIT :MAX_ROWS
        ]) {
            Boolean overdue = !k.IsClosed && k.ActivityDate != null && k.ActivityDate < Date.today();
            t += '- task: ' + k.Subject + ' | ' + k.Status + ' | due ' + fmt(k.ActivityDate)
                + (overdue ? ' | OVERDUE by ' + k.ActivityDate.daysBetween(Date.today()) + ' days' : '')
                + ' | assigned to ' + k.Owner.Name + '\n';
            if (overdue) {
                needs.add('Overdue task: ' + k.Subject + ' (' + k.ActivityDate.daysBetween(Date.today()) + ' days overdue)');
            }
        }
        for (Event v : [
            SELECT Subject, StartDateTime FROM Event WHERE WhatId IN :whatIds ORDER BY StartDateTime DESC LIMIT :MAX_ROWS
        ]) {
            t += '- event: ' + v.Subject + ' | ' + v.StartDateTime + '\n';
        }

        t += '\n## FILES (' + files.filesRead + ' read, ' + files.filesSkipped + ' skipped as unreadable)\n';
        t += String.isBlank(files.filesText) ? 'none\n' : files.filesText;
        if (!needs.isEmpty()) {
            t += '\n## ITEMS THAT NEED AN ACTION (found in the data above; address every item, combining only closely related ones)\n';
            for (String n : needs) {
                t += '- ' + n + '\n';
            }
        }
        return t;
    }

    private static String line(String label, Object v) {
        return v == null ? '' : '- ' + label + ': ' + String.valueOf(v) + '\n';
    }

    private static String fmt(Date d) {
        return d == null ? 'none' : d.format();
    }

    private static String cut(String s) {
        if (s == null) {
            return '';
        }
        String flat = s.replace('\n', ' ');
        return flat.length() > NOTE_CHARS ? flat.substring(0, NOTE_CHARS) + '...' : flat;
    }

    // ---------- parse and save ----------

    public static List<Next_Best_Action__c> parseActions(String raw, Id projectId) {
        if (String.isBlank(raw)) {
            throw new NbaException('The agent returned no text.');
        }
        Integer a = raw.indexOf('{');
        Integer b = raw.lastIndexOf('}');
        if (a < 0 || b <= a) {
            throw new NbaException('The agent answer was not in the expected format.');
        }
        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(raw.substring(a, b + 1));
        } catch (Exception e) {
            throw new NbaException('The agent answer could not be read: ' + e.getMessage());
        }
        Map<String, Object> top = (Map<String, Object>) parsed;
        List<Object> items = top.get('actions') instanceof List<Object> ? (List<Object>) top.get('actions') : new List<Object>();

        Map<String, Id> oppByName = new Map<String, Id>();
        for (Opportunity o : [SELECT Id, Name FROM Opportunity WHERE Project__c = :projectId LIMIT 200]) {
            oppByName.put(o.Name.toLowerCase(), o.Id);
        }
        Set<String> brands = new Set<String>();
        for (Schema.PicklistEntry e : Next_Best_Action__c.Brand__c.getDescribe().getPicklistValues()) {
            brands.add(e.getValue());
        }

        List<Next_Best_Action__c> out = new List<Next_Best_Action__c>();
        for (Object item : items) {
            if (!(item instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> m = (Map<String, Object>) item;
            String title = text(m.get('action'));
            if (String.isBlank(title)) {
                continue;
            }
            Integer days = 7;
            if (m.get('due_in_days') instanceof Integer || m.get('due_in_days') instanceof Decimal) {
                days = Math.max(1, Math.min(90, Integer.valueOf(m.get('due_in_days'))));
            }
            String priority = text(m.get('priority'));
            String brand = text(m.get('brand'));
            String oppName = text(m.get('opportunity_name'));
            out.add(new Next_Best_Action__c(
                Name = title.length() > 80 ? title.substring(0, 77) + '...' : title,
                Description__c = text(m.get('description')),
                Rationale__c = text(m.get('rationale')),
                Evidence__c = text(m.get('evidence')),
                Due_Date__c = Date.today().addDays(days),
                Priority__c = PRIORITIES.contains(priority) ? priority : 'Medium',
                Brand__c = brands.contains(brand) ? brand : null,
                Opportunity__c = oppName == null ? null : oppByName.get(oppName.toLowerCase())
            ));
        }
        return out;
    }

    private static String text(Object o) {
        return o == null ? null : String.valueOf(o).trim();
    }

    private static void save(List<Next_Best_Action__c> proposed, Id projectId, Result res) {
        Set<String> open = new Set<String>();
        for (Next_Best_Action__c n : [
            SELECT Name FROM Next_Best_Action__c
            WHERE Project__c = :projectId AND Status__c NOT IN ('Complete', 'Dismissed')
        ]) {
            open.add(n.Name.toLowerCase());
        }
        res.runId = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        List<Next_Best_Action__c> toInsert = new List<Next_Best_Action__c>();
        for (Next_Best_Action__c n : proposed) {
            if (open.contains(n.Name.toLowerCase())) {
                res.skippedCount++;
                continue;
            }
            open.add(n.Name.toLowerCase());
            n.Project__c = projectId;
            n.Status__c = 'Suggested';
            n.Source__c = 'Agent';
            n.Generated_On__c = Datetime.now();
            n.Run_Id__c = res.runId;
            n.OwnerId = UserInfo.getUserId();
            toInsert.add(n);
        }
        SObjectAccessDecision dec = Security.stripInaccessible(AccessType.CREATABLE, toInsert);
        List<Next_Best_Action__c> clean = (List<Next_Best_Action__c>) dec.getRecords();
        insert clean;
        res.createdCount = clean.size();
        for (Next_Best_Action__c n : clean) {
            res.createdActions += '- ' + n.Name + ' (due ' + fmt(n.Due_Date__c) + ', ' + n.Priority__c + ')\n';
        }
        res.message = 'Created ' + res.createdCount + ' suggested action(s)'
            + (res.skippedCount > 0 ? ', skipped ' + res.skippedCount + ' that already exist' : '') + '.';
    }
}
