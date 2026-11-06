@IsTest
private class SPX_DataLoadControllerTest {

    @IsTest
    static void projectsMatchByReferenceWhenCcIdNotFound() {
        SPX_DataLoadController.loadCsv('Projects', 'CC_Project_ID__c,Name\nCC-R-1,Ref One\n');
        Project__c p = [SELECT Id, Project_Reference__c FROM Project__c WHERE CC_Project_ID__c = 'CC-R-1'];
        // CC ID not found, reference found: update the record and write the new CC ID
        String csv = 'Project_Reference__c,CC_Project_ID__c,Name\n' + p.Project_Reference__c + ',CC-R-2,Ref Renamed\n';
        SPX_DataLoadController.LoadResult r = SPX_DataLoadController.loadCsv('Projects', csv);
        System.assertEquals(1, r.updated, r.fatalError + ' ' + r.errors);
        Project__c after = [SELECT CC_Project_ID__c, Name FROM Project__c WHERE Id = :p.Id];
        System.assertEquals('CC-R-2', after.CC_Project_ID__c);
        System.assertEquals('Ref Renamed', after.Name);
        System.assertEquals(1, [SELECT COUNT() FROM Project__c]);
        // Neither key found: new record
        SPX_DataLoadController.LoadResult n = SPX_DataLoadController.loadCsv('Projects',
            'Project_Reference__c,CC_Project_ID__c,Name\nP-99999,CC-R-3,Brand New\n');
        System.assertEquals(1, n.created, n.fatalError + ' ' + n.errors);
        System.assertEquals(2, [SELECT COUNT() FROM Project__c]);
        // Both keys found but on different Projects: rejected
        SPX_DataLoadController.LoadResult c = SPX_DataLoadController.loadCsv('Projects',
            'Project_Reference__c,CC_Project_ID__c,Name\n' + p.Project_Reference__c + ',CC-R-3,Clash\n');
        System.assertEquals(1, c.failed);
    }

    @IsTest
    static void datesAcceptIsoAndUsSlashFormat() {
        System.assertEquals(Date.newInstance(2030, 12, 15), SPX_DataLoadController.parseDate('12/15/2030'));
        System.assertEquals(Date.newInstance(2030, 1, 5), SPX_DataLoadController.parseDate('1/5/2030'));
        System.assertEquals(Date.newInstance(2030, 12, 15), SPX_DataLoadController.parseDate('2030-12-15'));
    }

    @IsTest
    static void parsesQuotesAndNewlines() {
        List<List<String>> r = SPX_DataLoadController.parseCsv('a,b\r\n"x,1","he said ""hi"""\n');
        System.assertEquals(2, r.size());
        System.assertEquals('x,1', r[1][0]);
        System.assertEquals('he said "hi"', r[1][1]);
    }

    @IsTest
    static void projectUpsertCreatesThenUpdatesAndBuildsResultFiles() {
        String csv = 'CC_Project_ID__c,Name,City__c\nCC-T-1,Test Project,Chicago\n';
        SPX_DataLoadController.LoadResult a = SPX_DataLoadController.loadCsv('Projects', csv);
        System.assertEquals(1, a.created, a.fatalError + ' ' + a.errors);
        System.assert(a.successCsv.startsWith('sf__Id,sf__Result,CC_Project_ID__c,Name,City__c'));
        System.assert(a.successCsv.contains(',Created,CC-T-1,Test Project,Chicago'));
        System.assertEquals('sf__Error,CC_Project_ID__c,Name,City__c\n', a.errorCsv);
        SPX_DataLoadController.LoadResult b = SPX_DataLoadController.loadCsv('Projects', csv);
        System.assertEquals(1, b.updated, b.fatalError + ' ' + b.errors);
        System.assert(b.successCsv.contains(',Updated,'));
    }

    @IsTest
    static void unknownLookupGoesToErrorFile() {
        SPX_DataLoadController.loadCsv('Projects', 'CC_Project_ID__c,Name\nCC-T-2,P2\n');
        String csv = 'Project__r.CC_Project_ID__c,Account__r.External_ID__c,Relationship_Type__c\nCC-T-2,NOPE,Engineer\n';
        SPX_DataLoadController.LoadResult r = SPX_DataLoadController.loadCsv('Stakeholders', csv);
        System.assertEquals(1, r.failed);
        System.assert(r.errors[0].contains('NOPE'));
        System.assert(r.errorCsv.contains('NOPE'));
        SPX_DataLoadController.LoadResult bad = SPX_DataLoadController.loadCsv('Projects', 'Nope__c\n1\n');
        System.assertNotEquals(null, bad.fatalError);
    }

    @IsTest
    static void accountLookupByAccountNumber() {
        insert new List<Account>{
            new Account(Name = 'A1', AccountNumber = 'AN-1'),
            new Account(Name = 'D1', AccountNumber = 'AN-2'),
            new Account(Name = 'D2', AccountNumber = 'AN-2')
        };
        SPX_DataLoadController.loadCsv('Projects', 'CC_Project_ID__c,Name\nCC-T-9,P9\n');
        String csv = 'Project__r.CC_Project_ID__c,Account__r.AccountNumber,Relationship_Type__c\n'
            + 'CC-T-9,AN-1,Engineer\nCC-T-9,AN-2,Owner\nCC-T-9,AN-X,Owner\n';
        SPX_DataLoadController.LoadResult r = SPX_DataLoadController.loadCsv('Stakeholders', csv);
        System.assertEquals(null, r.fatalError);
        System.assertEquals(1, r.created);
        System.assertEquals(2, r.failed);
        System.assert(r.errorCsv.contains('More than one'));
        System.assert(r.errorCsv.contains('AN-X'));
    }

    @IsTest
    static void projectOnlyRowIsNotRejectedByOpportunityCheck() {
        SPX_DataLoadController.loadCsv('Projects', 'CC_Project_ID__c,Name\nCC-T-3,P3\n');
        SPX_DataLoadController.LoadResult i = SPX_DataLoadController.loadCsv('Insights',
            'Project__r.CC_Project_ID__c,Name\nCC-T-3,x\n');
        // No project/opportunity mismatch error: any failure must come from the platform, not our check
        for (String er : i.errors) {
            System.assert(!er.contains('Opportunity belongs'), er);
        }
    }
    @IsTest
    static void existingProjectIsNotOverwrittenOnMatchedLead() {
        Id projB = 'a00000000000002AAA';
        Id projC = 'a00000000000003AAA';
        Id leadId = '00Q000000000001AAA';
        Lead row = new Lead(LastName = 'A', Company = 'X', CC_Project_ID__c = 'CC-1', Project__c = projB);
        // existing lead already has a project: the file's project is dropped, other fields kept
        SObject withProject = SPX_DataLoadController.applyExisting(
            row, new Lead(Id = leadId, Project__c = projC), Schema.Lead.SObjectType);
        System.assertEquals(leadId, withProject.Id);
        System.assertEquals(null, withProject.get('Project__c'));
        System.assertEquals('A', withProject.get('LastName'));
        // existing lead has no project: the file's project fills it
        SObject noProject = SPX_DataLoadController.applyExisting(
            row, new Lead(Id = leadId), Schema.Lead.SObjectType);
        System.assertEquals(projB, noProject.get('Project__c'));
    }
    @IsTest
    static void leadMatchKeyNeedsProjectBrandAndMarket() {
        List<String> f = new List<String>{ 'CC_Project_ID__c', 'Brand__c', 'Vertical__c' };
        Lead a = new Lead(CC_Project_ID__c = 'CC-1', Brand__c = 'Cooling', Vertical__c = 'Healthcare');
        Lead sameDifferentCase = new Lead(CC_Project_ID__c = 'cc-1', Brand__c = 'Cooling', Vertical__c = 'Healthcare');
        Lead otherBrand = new Lead(CC_Project_ID__c = 'CC-1', Brand__c = 'Marley', Vertical__c = 'Healthcare');
        Lead noMarket = new Lead(CC_Project_ID__c = 'CC-1', Brand__c = 'Cooling');
        System.assertEquals(SPX_DataLoadController.matchKey(a, f), SPX_DataLoadController.matchKey(sameDifferentCase, f));
        System.assertNotEquals(SPX_DataLoadController.matchKey(a, f), SPX_DataLoadController.matchKey(otherBrand, f));
        System.assertEquals(null, SPX_DataLoadController.matchKey(noMarket, f));
    }
    @IsTest
    static void projectMustMatchOpportunityProject() {
        Id opp = '006000000000001AAA';
        Id projA = 'a00000000000001AAA';
        Id projB = 'a00000000000002AAA';
        Map<Id, Id> m = new Map<Id, Id>{ opp => projA };
        System.assertEquals(null, SPX_DataLoadController.checkOpportunityProject(opp, projA, m));
        System.assertEquals(null, SPX_DataLoadController.checkOpportunityProject(opp, null, m));
        System.assert(SPX_DataLoadController.checkOpportunityProject(opp, projB, m).contains('different Project'));
        System.assert(SPX_DataLoadController.checkOpportunityProject(opp, projB, new Map<Id, Id>{ opp => null })
            .contains('has no Project'));
        System.assertEquals(null, SPX_DataLoadController.checkOpportunityProject(null, projA, m));
    }

    @IsTest
    static void convertedLeadIsNotMatchedSoRowCreatesNewLead() {
        Lead old = new Lead(
            LastName = 'Old', Company = 'Old Co', LeadSource = 'Rep Firm',
            CC_Project_ID__c = 'CC-CONV-1', Brand__c = 'Cooling', Vertical__c = 'Healthcare'
        );
        insert old;
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(old.Id);
        lc.setConvertedStatus([SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1].MasterLabel);
        lc.setDoNotCreateOpportunity(true);
        System.assert(Database.convertLead(lc).isSuccess());
        String csv = 'LastName,Company,LeadSource,CC_Project_ID__c,Brand__c,Vertical__c\n'
            + 'New,New Co,Rep Firm,CC-CONV-1,Cooling,Healthcare\n';
        SPX_DataLoadController.LoadResult r = SPX_DataLoadController.loadCsv('Leads', csv);
        System.assertEquals(0, r.failed, r.fatalError + ' ' + r.errors);
        System.assertEquals(1, r.created, r.fatalError + ' ' + r.errors);
        System.assertEquals(2, [SELECT COUNT() FROM Lead WHERE CC_Project_ID__c = 'CC-CONV-1']);
    }

    @IsTest
    static void emptyAndUnknownKey() {
        System.assertNotEquals(null, SPX_DataLoadController.loadCsv('Projects', 'Name\n').fatalError);
        System.assertNotEquals(null, SPX_DataLoadController.loadCsv('Bogus', 'a\n1').fatalError);
    }
}
