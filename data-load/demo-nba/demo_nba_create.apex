// DEMO NBA data: one Strobic-led project with related records and two text files.
// Run: sf apex run -o spx-demo -f data-load/demo-nba/demo_nba_create.apex
// Remove: sf apex run -o spx-demo -f data-load/demo-nba/demo_nba_delete.apex
// Everything is keyed on CC_Project_ID__c = 'DEMO-NBA-0001' and names starting 'DEMO NBA'.

if ([SELECT COUNT() FROM Project__c WHERE CC_Project_ID__c = 'DEMO-NBA-0001'] > 0) {
    System.debug('DEMO NBA project already exists, nothing created.');
    return;
}

Map<String, Account> acc = new Map<String, Account>();
for (Account a : [SELECT Id, Name, AccountNumber FROM Account WHERE AccountNumber IN ('A13332565', 'A93780150', 'A66406456')]) {
    acc.put(a.AccountNumber, a);
}
Account engineer = acc.get('A13332565'); // Momentum Design
Account owner = acc.get('A93780150');    // Tech Labs
Account gc = acc.get('A66406456');       // Red Studio Designs
User trsm = [SELECT Id FROM User WHERE Username = 'trsm@accenture.com.spx.demo'];
Id rt = [SELECT Id FROM RecordType WHERE SobjectType = 'Opportunity' AND DeveloperName = 'Golden_Template_Project_Sale'].Id;

Project__c p = new Project__c(
    Name = 'DEMO NBA - Halston University Biosciences Building',
    CC_Project_ID__c = 'DEMO-NBA-0001',
    Vertical__c = 'Education',
    Project_Phase__c = 'Design Development',
    Estimated_Construction_Value__c = 62000000,
    City__c = 'Raleigh',
    State__c = 'NC',
    Estimated_Construction_Start__c = Date.newInstance(2027, 2, 1),
    Estimated_Completion__c = Date.newInstance(2028, 9, 30),
    Engineer_of_Record__c = engineer.Id,
    GC__c = gc.Id
);
insert p;

Opportunity o = new Opportunity(
    Name = 'DEMO NBA - Halston Biosciences - Strobic - Lab exhaust',
    AccountId = owner.Id,
    Project__c = p.Id,
    RecordTypeId = rt,
    Brand__c = 'Strobic',
    StageName = '3.0 Spec and Influence',
    CloseDate = Date.newInstance(2027, 9, 30),
    Amount = 1850000,
    BOD_Status__c = 'Pending',
    NextStep = 'Confirm dispersion study scope with the engineer',
    OwnerId = trsm.Id
);
insert o;

insert new List<Lead>{
    new Lead(
        FirstName = 'Priya', LastName = 'Okonkwo', Company = 'Halston University', Title = 'Facilities Director',
        Status = 'New', LeadSource = 'Rep Firm', Project__c = p.Id, Brand__c = 'Cooling', Vertical__c = 'Education',
        Est_Brand_Potential__c = 600000, BOD_Status__c = 'Not yet',
        Description = 'DEMO NBA. Cooling tower plant for the same building; no contact made yet.'
    ),
    new Lead(
        FirstName = 'Marcus', LastName = 'Lindqvist', Company = 'Halston University', Title = 'Energy Manager',
        Status = 'New', LeadSource = 'Rep Firm', Project__c = p.Id, Brand__c = 'Ingénia', Vertical__c = 'Education',
        Est_Brand_Potential__c = 350000, BOD_Status__c = 'Not yet',
        Description = 'DEMO NBA. Owner asked about heat recovery on the lab exhaust.'
    )
};

insert new List<Project_Relationship__c>{
    new Project_Relationship__c(Project__c = p.Id, Account__c = engineer.Id, Relationship_Type__c = 'Engineer', Status__c = 'Pending'),
    new Project_Relationship__c(Project__c = p.Id, Account__c = owner.Id, Relationship_Type__c = 'Owner', Status__c = 'Confirmed'),
    new Project_Relationship__c(Project__c = p.Id, Account__c = gc.Id, Relationship_Type__c = 'General Contractor', Status__c = 'Pending')
};

insert new List<Opportunity_Competitor__c>{
    new Opportunity_Competitor__c(
        Name = 'DEMO NBA Rival Fan Systems', Project__c = p.Id, Opportunity__c = o.Id, Referenced_in_Spec__c = true,
        Strengths__c = 'Named as basis of design in spec section 23 34 00 (clause 1.3 A)',
        Weaknesses__c = 'Fan delivery lead time is about 20 weeks'
    ),
    new Opportunity_Competitor__c(
        Name = 'DEMO NBA Allied Air Handling', Project__c = p.Id, Opportunity__c = o.Id, Referenced_in_Spec__c = false,
        Strengths__c = 'Local rep with a long relationship with the GC',
        Weaknesses__c = 'No wind-tunnel study on file for this fan series'
    )
};

insert new List<Project_Intelligence__c>{
    new Project_Intelligence__c(
        Name = 'DEMO NBA Spec names an alternate basis of design', Project__c = p.Id, Opportunity__c = o.Id, Brand__c = 'Strobic',
        Insight_Type__c = 'Project Intelligence', Project_Intelligence_Type__c = 'Risk', Share_with_Project__c = true,
        Detailed_Notes__c = 'Section 23 34 00 names Rival Fan Systems series HP-4 as basis of design. Substitution requests are due 10 days before the June 15, 2027 bid.'
    ),
    new Project_Intelligence__c(
        Name = 'DEMO NBA Dispersion study not yet scoped', Project__c = p.Id, Opportunity__c = o.Id, Brand__c = 'Strobic',
        Insight_Type__c = 'Project Intelligence', Project_Intelligence_Type__c = 'Risk', Share_with_Project__c = true,
        Detailed_Notes__c = 'Engineer has not confirmed who pays for the wind-tunnel dispersion study. A study is required for bid.'
    ),
    new Project_Intelligence__c(
        Name = 'DEMO NBA Local rep also in front of the GC', Project__c = p.Id, Brand__c = 'Cooling',
        Insight_Type__c = 'Project Intelligence', Project_Intelligence_Type__c = 'Channel Conflict', Share_with_Project__c = true,
        Detailed_Notes__c = 'A local rep firm is also talking to the GC about cooling towers. Not yet agreed who quotes.'
    ),
    new Project_Intelligence__c(
        Name = 'DEMO NBA Owner wants heat recovery', Project__c = p.Id, Brand__c = 'Ingénia',
        Insight_Type__c = 'Project Intelligence', Project_Intelligence_Type__c = 'Insight', Share_with_Project__c = true,
        Detailed_Notes__c = 'Owner energy manager asked for a future heat-recovery loop on the lab exhaust and wants LEED credit.'
    )
};

insert new List<Task>{
    new Task(WhatId = o.Id, OwnerId = trsm.Id, Subject = 'DEMO NBA Send dispersion study proposal to the engineer',
             ActivityDate = Date.today().addDays(-15), Status = 'Not Started', Priority = 'High'),
    new Task(WhatId = o.Id, OwnerId = trsm.Id, Subject = 'DEMO NBA Schedule lab tour with the owner',
             ActivityDate = Date.today().addDays(16), Status = 'Not Started', Priority = 'Normal'),
    new Task(WhatId = o.Id, OwnerId = trsm.Id, Subject = 'DEMO NBA Review addendum 2',
             ActivityDate = Date.today().addDays(-30), Status = 'Completed', Priority = 'Normal')
};

// Files. Guidance is linked to this project for the demo; the agent finds it by its title.
insert new List<ContentVersion>{
    new ContentVersion(
        Title = 'Spec Section 23 34 00 Laboratory Exhaust', PathOnClient = 'Spec_Section_23_34_00_Laboratory_Exhaust.md',
        VersionData = Blob.valueOf('SPEC_PLACEHOLDER'), FirstPublishLocationId = p.Id
    ),
    new ContentVersion(
        Title = 'NBA_Agent_Guidance', PathOnClient = 'NBA_Agent_Guidance.md',
        VersionData = Blob.valueOf('GUIDANCE_PLACEHOLDER'), FirstPublishLocationId = p.Id
    )
};
System.debug('DEMO NBA created project ' + p.Id + ' and opportunity ' + o.Id);
