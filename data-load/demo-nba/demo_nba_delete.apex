// Removes everything created by demo_nba_create.apex (project DEMO-NBA-0001 and its records and files).
List<Project__c> ps = [SELECT Id FROM Project__c WHERE CC_Project_ID__c = 'DEMO-NBA-0001'];
Set<Id> pids = new Map<Id, Project__c>(ps).keySet();
Set<Id> oids = new Map<Id, Opportunity>([SELECT Id FROM Opportunity WHERE Project__c IN :pids]).keySet();
Set<Id> lids = new Map<Id, Lead>([SELECT Id FROM Lead WHERE Project__c IN :pids]).keySet();

Set<Id> linked = new Set<Id>();
linked.addAll(pids);
linked.addAll(oids);
linked.addAll(lids);
Set<Id> docs = new Set<Id>();
for (ContentDocumentLink l : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :linked]) {
    docs.add(l.ContentDocumentId);
}
delete [SELECT Id FROM Task WHERE WhatId IN :linked];
delete [SELECT Id FROM Event WHERE WhatId IN :linked];
delete [SELECT Id FROM Next_Best_Action__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Project_Intelligence__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Opportunity_Competitor__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Project_Relationship__c WHERE Project__c IN :pids];
delete [SELECT Id FROM Lead WHERE Project__c IN :pids];
delete [SELECT Id FROM Opportunity WHERE Project__c IN :pids];
delete [SELECT Id FROM ContentDocument WHERE Id IN :docs];
delete ps;
System.debug('DEMO NBA removed.');
