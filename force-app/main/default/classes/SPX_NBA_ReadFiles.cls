/**
 * Reads the text of files attached to a Project (and to its Opportunities and Leads) plus the
 * agent guidance file, so the Next Best Action prompt can use them. Flows cannot read file bodies.
 * Only text-like files are read (txt, md, csv, json). Runs with sharing, so users only get files they can see.
 */
public with sharing class SPX_NBA_ReadFiles {

    public static final Integer MAX_FILES = 5;
    public static final Integer MAX_CHARS = 20000;
    public static final String GUIDANCE_PREFIX = 'NBA_Agent_Guidance';
    private static final Set<String> TEXT_EXT = new Set<String>{ 'txt', 'md', 'csv', 'json' };

    public class Request {
        @InvocableVariable(label='Project Id' required=true)
        public Id projectId;
    }

    public class Result {
        @InvocableVariable(label='Files Text')
        public String filesText;
        @InvocableVariable(label='Guidance Text')
        public String guidanceText;
        @InvocableVariable(label='Files Read')
        public Integer filesRead;
        @InvocableVariable(label='Files Skipped')
        public Integer filesSkipped;
    }

    @InvocableMethod(label='SPX NBA Read Project Files' description='Returns the text of project files and the NBA guidance file.')
    public static List<Result> readFiles(List<Request> requests) {
        List<Result> out = new List<Result>();
        for (Request r : requests) {
            out.add(readOne(r.projectId));
        }
        return out;
    }

    public static Result readOne(Id projectId) {
        Result res = new Result();
        res.filesRead = 0;
        res.filesSkipped = 0;
        res.filesText = '';
        res.guidanceText = '';
        if (projectId == null) {
            return res;
        }

        Set<Id> linked = new Set<Id>{ projectId };
        for (Opportunity o : [SELECT Id FROM Opportunity WHERE Project__c = :projectId LIMIT 200]) {
            linked.add(o.Id);
        }
        for (Lead l : [SELECT Id FROM Lead WHERE Project__c = :projectId LIMIT 200]) {
            linked.add(l.Id);
        }

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :linked LIMIT 500
        ]) {
            docIds.add(cdl.ContentDocumentId);
        }
        res.guidanceText = guidance();
        if (docIds.isEmpty()) {
            return res;
        }

        List<ContentVersion> versions = [
            SELECT Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds AND IsLatest = true
            ORDER BY LastModifiedDate DESC
            LIMIT 50
        ];
        for (ContentVersion cv : versions) {
            if (cv.Title != null && cv.Title.startsWith(GUIDANCE_PREFIX)) {
                continue; // guidance is returned separately
            }
            String ext = cv.FileExtension == null ? '' : cv.FileExtension.toLowerCase();
            if (!TEXT_EXT.contains(ext) || res.filesRead >= MAX_FILES) {
                res.filesSkipped++;
                continue;
            }
            res.filesText += formatFile(cv.Title, ext, cv.VersionData.toString());
            res.filesRead++;
        }
        return res;
    }

    private static String guidance() {
        List<ContentVersion> g = [
            SELECT Title, VersionData FROM ContentVersion
            WHERE IsLatest = true AND Title LIKE :(GUIDANCE_PREFIX + '%') AND FileExtension IN :TEXT_EXT
            ORDER BY LastModifiedDate DESC LIMIT 1
        ];
        return g.isEmpty() ? '' : truncate(g[0].VersionData.toString());
    }

    private static String formatFile(String title, String ext, String body) {
        return '=== FILE: ' + title + '.' + ext + ' ===\n' + truncate(body) + '\n=== END FILE ===\n\n';
    }

    private static String truncate(String body) {
        if (body == null) {
            return '';
        }
        return body.length() > MAX_CHARS
            ? body.substring(0, MAX_CHARS) + '\n[TRUNCATED at ' + MAX_CHARS + ' characters]'
            : body;
    }
}
