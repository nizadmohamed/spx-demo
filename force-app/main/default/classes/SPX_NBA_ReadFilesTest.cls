@IsTest
private class SPX_NBA_ReadFilesTest {

    private static void addFile(String title, String path, String body, Id linkTo) {
        insert new ContentVersion(
            Title = title,
            PathOnClient = path,
            VersionData = Blob.valueOf(body),
            FirstPublishLocationId = linkTo
        );
    }

    private static SPX_NBA_ReadFiles.Result run(Id projectId) {
        SPX_NBA_ReadFiles.Request r = new SPX_NBA_ReadFiles.Request();
        r.projectId = projectId;
        return SPX_NBA_ReadFiles.readFiles(new List<SPX_NBA_ReadFiles.Request>{ r })[0];
    }

    @IsTest
    static void readsTextFilesAndGuidance() {
        Project__c p = new Project__c(Name = 'NBA Test Project');
        insert p;
        addFile('Spec Section 23', 'spec.md', 'Strobic exhaust fans are specified.', p.Id);
        addFile('NBA_Agent_Guidance', 'guide.md', 'Recommend an engineer meeting.', p.Id);
        addFile('Drawing', 'drawing.pdf', 'binary', p.Id);
        Test.startTest();
        SPX_NBA_ReadFiles.Result res = run(p.Id);
        Test.stopTest();
        System.assertEquals(1, res.filesRead);
        System.assertEquals(1, res.filesSkipped);
        System.assert(res.filesText.contains('Strobic exhaust fans'));
        System.assert(res.filesText.contains('=== FILE: Spec Section 23.md ==='));
        System.assert(!res.filesText.contains('Recommend an engineer meeting'));
        System.assertEquals('Recommend an engineer meeting.', res.guidanceText);
    }

    @IsTest
    static void truncatesLongFiles() {
        Project__c p = new Project__c(Name = 'NBA Test Project 2');
        insert p;
        addFile('Long Spec', 'long.txt', 'x'.repeat(SPX_NBA_ReadFiles.MAX_CHARS + 500), p.Id);
        SPX_NBA_ReadFiles.Result res = run(p.Id);
        System.assert(res.filesText.contains('[TRUNCATED at'));
    }

    @IsTest
    static void capsNumberOfFiles() {
        Project__c p = new Project__c(Name = 'NBA Test Project 3');
        insert p;
        for (Integer i = 0; i < SPX_NBA_ReadFiles.MAX_FILES + 2; i++) {
            addFile('Spec ' + i, 'spec' + i + '.txt', 'text ' + i, p.Id);
        }
        SPX_NBA_ReadFiles.Result res = run(p.Id);
        System.assertEquals(SPX_NBA_ReadFiles.MAX_FILES, res.filesRead);
        System.assertEquals(2, res.filesSkipped);
    }

    @IsTest
    static void noFilesReturnsEmpty() {
        Project__c p = new Project__c(Name = 'NBA Test Project 4');
        insert p;
        SPX_NBA_ReadFiles.Result res = run(p.Id);
        System.assertEquals(0, res.filesRead);
        System.assertEquals('', res.filesText);
    }
}
