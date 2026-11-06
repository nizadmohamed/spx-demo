@IsTest
private class SPX_NBA_ServiceTest {

    private class MockLlm implements SPX_NBA_Service.LlmClient {
        private String answer;
        public String seenContext;
        public String seenGuidance;
        MockLlm(String answer) {
            this.answer = answer;
        }
        public String generate(String context, String guidance) {
            seenContext = context;
            seenGuidance = guidance;
            return answer;
        }
    }

    private static Project__c project() {
        Project__c p = new Project__c(Name = 'NBA Svc Project');
        insert p;
        return p;
    }

    private static SPX_NBA_Service.Result run(Id projectId) {
        SPX_NBA_Service.Request r = new SPX_NBA_Service.Request();
        r.projectId = projectId;
        return SPX_NBA_Service.recommend(new List<SPX_NBA_Service.Request>{ r })[0];
    }

    @IsTest
    static void createsSuggestedActionsFromJson() {
        Project__c p = project();
        insert new ContentVersion(
            Title = 'NBA_Agent_Guidance', PathOnClient = 'g.md', VersionData = Blob.valueOf('Be specific.'),
            FirstPublishLocationId = p.Id
        );
        insert new ContentVersion(
            Title = 'Spec 23', PathOnClient = 's.md', VersionData = Blob.valueOf('Strobic named in spec.'),
            FirstPublishLocationId = p.Id
        );
        MockLlm mock = new MockLlm(
            'Here you go:\n```json\n{"actions":[' +
            '{"action":"Meet the engineer","description":"d","due_in_days":5,"priority":"High","brand":"Strobic","rationale":"r","evidence":"e"},' +
            '{"action":"Second action","priority":"bogus","brand":"NotABrand","due_in_days":500}]}\n```'
        );
        SPX_NBA_Service.client = mock;
        Test.startTest();
        SPX_NBA_Service.Result res = run(p.Id);
        Test.stopTest();

        System.assertEquals(2, res.createdCount, res.message);
        List<Next_Best_Action__c> rows = [
            SELECT Name, Status__c, Source__c, Priority__c, Brand__c, Due_Date__c, OwnerId, Run_Id__c
            FROM Next_Best_Action__c WHERE Project__c = :p.Id ORDER BY Name
        ];
        System.assertEquals(2, rows.size());
        System.assertEquals('Meet the engineer', rows[0].Name);
        System.assertEquals('Suggested', rows[0].Status__c);
        System.assertEquals('Agent', rows[0].Source__c);
        System.assertEquals('High', rows[0].Priority__c);
        System.assertEquals('Strobic', rows[0].Brand__c);
        System.assertEquals(Date.today().addDays(5), rows[0].Due_Date__c);
        System.assertEquals(UserInfo.getUserId(), rows[0].OwnerId);
        System.assertEquals(res.runId, rows[0].Run_Id__c);
        System.assertEquals('Medium', rows[1].Priority__c);
        System.assertEquals(null, rows[1].Brand__c);
        System.assertEquals(Date.today().addDays(90), rows[1].Due_Date__c);
        System.assert(mock.seenContext.contains('NBA Svc Project'));
        System.assert(mock.seenContext.contains('Strobic named in spec.'));
        System.assertEquals('Be specific.', mock.seenGuidance);
    }

    @IsTest
    static void skipsActionsThatAlreadyExist() {
        Project__c p = project();
        insert new Next_Best_Action__c(Name = 'Meet the engineer', Project__c = p.Id, Status__c = 'Not Started');
        SPX_NBA_Service.client = new MockLlm('{"actions":[{"action":"meet the ENGINEER"},{"action":"New one"}]}');
        SPX_NBA_Service.Result res = run(p.Id);
        System.assertEquals(1, res.createdCount);
        System.assertEquals(1, res.skippedCount);
    }

    @IsTest
    static void completedActionsCanBeSuggestedAgain() {
        Project__c p = project();
        insert new Next_Best_Action__c(Name = 'Meet the engineer', Project__c = p.Id, Status__c = 'Complete');
        SPX_NBA_Service.client = new MockLlm('{"actions":[{"action":"Meet the engineer"}]}');
        System.assertEquals(1, run(p.Id).createdCount);
    }

    private class SequenceLlm implements SPX_NBA_Service.LlmClient {
        private List<String> answers;
        public Integer calls = 0;
        SequenceLlm(List<String> answers) {
            this.answers = answers;
        }
        public String generate(String context, String guidance) {
            String a = answers[Math.min(calls, answers.size() - 1)];
            calls++;
            return a;
        }
    }

    @IsTest
    static void asksAgainWhenTooFewActionsAndKeepsFullestAnswer() {
        Project__c p = project();
        SequenceLlm seq = new SequenceLlm(new List<String>{
            '{"actions":[{"action":"Only one"}]}',
            '{"actions":[{"action":"A1"},{"action":"A2"},{"action":"A3"},{"action":"A4"},{"action":"A5"}]}'
        });
        SPX_NBA_Service.client = seq;
        SPX_NBA_Service.Result res = run(p.Id);
        System.assertEquals(2, seq.calls);
        System.assertEquals(5, res.createdCount);
    }

    @IsTest
    static void contextListsItemsThatNeedAnAction() {
        Project__c p = project();
        Account a = new Account(Name = 'Pending Engineer Co');
        insert a;
        insert new Project_Relationship__c(
            Project__c = p.Id, Account__c = a.Id, Relationship_Type__c = 'Engineer', Status__c = 'Pending'
        );
        insert new Lead(
            LastName = 'Contact', Company = 'Owner Co', Status = 'New', LeadSource = 'Rep Firm', Project__c = p.Id, Brand__c = 'Cooling'
        );
        insert new Task(WhatId = p.Id, Subject = 'Late thing', ActivityDate = Date.today().addDays(-3), Status = 'Not Started');
        String ctx = SPX_NBA_Service.buildContext(p.Id, SPX_NBA_ReadFiles.readOne(p.Id));
        System.assert(ctx.contains('## ITEMS THAT NEED AN ACTION'));
        System.assert(ctx.contains('Stakeholder to confirm: Pending Engineer Co'));
        System.assert(ctx.contains('Lead not yet contacted: Contact'));
        System.assert(ctx.contains('Overdue task: Late thing (3 days overdue)'));
    }

    @IsTest
    static void badAnswerCreatesNothing() {
        Project__c p = project();
        SPX_NBA_Service.client = new MockLlm('Sorry, I cannot help.');
        SPX_NBA_Service.Result res = run(p.Id);
        System.assertEquals(0, res.createdCount);
        System.assert(res.message.startsWith('No actions were created'));
        System.assertEquals(0, [SELECT COUNT() FROM Next_Best_Action__c WHERE Project__c = :p.Id]);
    }

    @IsTest
    static void contextCoversRelatedRecords() {
        Project__c p = project();
        Account a = new Account(Name = 'Test Engineer Co');
        insert a;
        insert new Project_Relationship__c(Project__c = p.Id, Account__c = a.Id, Relationship_Type__c = 'Engineer');
        insert new Project_Intelligence__c(Name = 'Spec risk', Project__c = p.Id, Project_Intelligence_Type__c = 'Risk', Insight_Type__c = 'Project Intelligence');
        insert new Opportunity_Competitor__c(Name = 'Rival Co', Project__c = p.Id);
        Test.startTest();
        String ctx = SPX_NBA_Service.buildContext(p.Id, SPX_NBA_ReadFiles.readOne(p.Id));
        Test.stopTest();
        System.assert(ctx.contains('## OPPORTUNITIES'));
        System.assert(ctx.contains('Test Engineer Co'));
        System.assert(ctx.contains('Spec risk'));
        System.assert(ctx.contains('Rival Co'));
        System.assert(ctx.contains('EXISTING NEXT BEST ACTIONS'));
    }
}
