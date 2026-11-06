# SPX HVAC Demo — Claude Code Session Prompts
## How to use this file
- Each session is a self-contained prompt to paste into Claude Code
- Attach all 9 source documents to every session (listed in the context setter)
- At the END of each session, paste the "End-of-Session Request" to get your handoff summary
- Paste that summary at the top of the NEXT session before the phase instruction
- Do not skip sessions or combine them

---

# CONTEXT SETTER
## (Paste this at the top of EVERY session, before the session-specific instruction)

```
You are a Salesforce developer building a live 7-step sales demonstration for 
SPX Technologies in a Salesforce SDO sandbox org. All design decisions have 
already been made. Your job is to build exactly what the source documents specify 
— do not invent field names, logic, or data values that are not in the documents.

YOUR SOURCE DOCUMENTS (all attached — read before acting):
1. SPX_Developer_Handover_Pack.md          ← PRIMARY: exact component names, 
                                              formulas, logic, activation order
2. SPX_Demo_Data_Workbook.xlsx             ← PRIMARY: every record to load, 
                                              exact values, load order
3. Steps_5_and_6_Build_Notes.md           ← Supplement: Steps 5 and 6 detail
4. SPX_Demo_Clickthrough.html              ← Visual reference only
5. SPX_Demo_Process_Flows.html             ← Context: what each step demonstrates
6. SPX_HVAC_CRM_Salesforce_RFP_Sep172026_Final.pdf
7. HVAC_CRM_RFP_SPXResponses_October_12_2026_Final.xlsx
8. HVAC Segment CRM Transformation RFP Response-Edited.pptx
9. HVAC Segment CRM Transformation RFP Requirements Response.pptx

WORKING RULES:
- Before acting on any instruction, confirm which source document and section 
  you are reading from
- After every step, tell me: what was built, any issues found, what needs 
  my manual input before you continue
- When a step requires me to click something in Setup, give me the exact 
  navigation path and what to click — then WAIT for me to confirm before 
  proceeding
- Do not jump ahead to the next step until the current one is confirmed working
- If source documents conflict with each other, stop and ask me which to follow
- If something is not in the source documents, say so — do not guess

CONSTRAINT: No custom Apex, no LWC, no Visualforce. Configuration only.
```

---

# END-OF-SESSION REQUEST
## (Paste this at the END of every session to generate your handoff summary)

```
Before we finish this session, give me a handoff summary with exactly these sections:

1. COMPLETED: Everything built or deployed in this session (object/API names, 
   exact component names)

2. MANUAL STEPS DONE: Any Setup UI actions I confirmed completing

3. VERIFIED: What was tested and confirmed working (include the SOQL queries 
   or CLI commands you ran to verify)

4. INCOMPLETE / CARRY FORWARD: Anything started but not finished, with the 
   exact stopping point

5. ASSUMPTIONS MADE: Any values or decisions not specified in the source 
   documents that you defaulted on — flag these for my review

6. ISSUES TO WATCH: Anything that worked but may need attention in a later 
   session (dependencies, ordering risks, etc.)

7. NEXT SESSION STARTS WITH: The first instruction to give Claude Code in 
   the next session

I will paste this summary at the top of the next session.
```

---
---

# SESSION 1
## Org Readiness + Foundation: Objects, Security, Metadata
## Estimated time: 3–4 hours

### PASTE ORDER:
1. Context setter (above)
2. Previous session summary: NONE (this is the first session)
3. Session 1 instruction (below)

---

```
SESSION 1 INSTRUCTION: Org readiness + shared foundation

This is Session 1 of 6. We are building the shared foundation that every 
demo scenario depends on. Nothing scenario-specific is built today.

Reference: Handover Pack Sections 0 and 1.

---

STEP 1 — ORG READINESS CHECKS (do all of these before writing any metadata)

Run each check below. For each one, tell me the current status, whether it 
needs a manual action from me, and the exact Setup path if it does. 
Wait for my confirmation of each manual action before moving on.

Check 1: Multi-currency
  - Run: sf org display --target-org [my-org-alias]
  - Then query: SELECT IsoCode FROM CurrencyType
  - Required: USD, CAD, EUR must all be enabled
  - If not enabled: tell me to go to Setup → Company Settings → Currencies
    and enable multi-currency, then add CAD and EUR
  - CRITICAL: this must be done before ANY data is loaded. It cannot be undone.

Check 2: Quotes
  - Query: SELECT Id FROM Quote LIMIT 1 (if object doesn't exist, quotes are off)
  - If off: tell me to go to Setup → Quotes Settings → Enable Quotes

Check 3: Account Contact Relationships
  - Run: sf sobject describe --sobject AccountContactRelation
  - If not found: tell me to go to Setup → Account Settings → 
    Allow Users to Relate a Contact to Multiple Accounts → enable

Check 4: Collaborative Forecasting
  - Query: SELECT Id FROM ForecastingItem LIMIT 1
  - If off: tell me to go to Setup → Forecasts Settings → Enable Forecasts

Check 5: Licenses
  - Run: sf limits display
  - Tell me how many Salesforce licenses are available
  - We need at least 11 (see Users sheet of Data Workbook)

Check 6: Agentforce
  - Query: SELECT Id FROM BotVersion LIMIT 1
  - Report whether Agentforce is available. Do not block on this — 
    it is optional and the last thing we build if time permits.

Check 7: Existing metadata conflicts
  - Run: sf sobject list
  - Check for any existing objects named Project__c, Brand_Relationship__c, 
    ERP_Cross_Reference__c, QTC_Message_Log__c, Project_Intake__c
  - If any exist: stop and report — do not overwrite without my instruction

Report all 7 checks. Wait for me to confirm any manual steps are done 
before proceeding to Step 2.

---

STEP 2 — GLOBAL VALUE SETS

Deploy these global value sets. Each one is used across multiple objects.
Reference: Handover Pack Section 1.1.

Value set 1: Brand__c
  Values (in this order): Cooling, Ingénia, Patterson-Kelley, TAMCO, Chicago Fan
  IMPORTANT: "Chicago Fan" value must be created as INACTIVE.
  It is activated live during the demo in Session 5 (Step 6).

Value set 2: Vertical__c
  Values: Healthcare, Education, Multifamily, Data Center, Other

Value set 3: BOD_Status__c
  Values: Not yet, Pending, Secured, At Risk, Defended, Lost

Value set 4: Project_Phase__c
  Values (in order): Planning, Schematic Design, Design Development, 
  Construction Documents, Bid, Awarded

After deploying, verify each value set exists and that Chicago Fan 
is inactive. Show me the CLI output.

---

STEP 3 — CUSTOM METADATA TYPES

Create these two custom metadata types. Reference: Handover Pack Section 1.1.

Metadata type 1: Brand_Configuration__mdt
Fields:
  - BU__c (Text 50)
  - Brand_Value__c (Text 50) — the exact picklist value from the Brand GVS
  - Target_Verticals__c (Text 255) — comma-separated list
  - Routing_Threshold__c (Currency 16,0)
  - Sends_to_QTC__c (Checkbox)
  - Default_Currency__c (Picklist: USD, CAD, EUR)
  - Live__c (Checkbox)
  - Earliest_Routing_Phase__c (Text 50)

Records to create:
  Label             | BU             | Brand_Value      | Live  | Default_Currency | Earliest_Routing_Phase
  Cooling           | Cooling        | Cooling          | TRUE  | USD              | Schematic Design
  Ingenia           | cAHU           | Ingénia          | TRUE  | USD              | Schematic Design
  TAMCO             | EAM            | TAMCO            | TRUE  | USD              | Schematic Design
  Patterson_Kelley  | Hydronics      | Patterson-Kelley | TRUE  | USD              | Schematic Design
  Cincinnati_Fan    | Chicago Fan | Chicago Fan   | FALSE | USD              | Schematic Design

Metadata type 2: Routing_Rule__mdt
Fields:
  - Brand__c (Text 50)
  - State__c (Text 2)
  - Owner_Alias__c (Text 8)
  - Territory__c (Text 50)

Records: Load from the Routing Rule sheet of the Data Workbook.

After deploying, query both metadata types to verify record counts. 
Confirm Cincinnati_Fan Brand Configuration record has Live__c = FALSE.

---

STEP 4 — CUSTOM OBJECTS

Build these 5 custom objects. Reference: Handover Pack Section 1.1.
Deploy each one individually and confirm before moving to the next.

Object 1: Project__c
  Label: Project | Plural: Projects | API: Project__c
  OWD: Private (set this AFTER the object is created via sharing settings)
  Standard fields to enable: Description, Owner
  
  Custom fields (deploy all):
  - Project_Code__c (Text 50, External ID, Unique)
  - CC_Project_ID__c (Text 50, External ID)
  - Vertical__c (Picklist — use global value set Vertical__c)
  - City__c (Text 100)
  - State__c (Text 10)
  - Postal_Code__c (Text 10)
  - Territory__c (Text 50)
  - Estimated_Construction_Value__c (Currency 16,0)
  - Project_Phase__c (Picklist — use global value set Project_Phase__c)
  - Project_Stage__c (Picklist: Identified, Qualified, In Pursuit, 
                      Partially Awarded, Resolved)
  - Strategic_Project__c (Checkbox, default false — set by flow, NOT formula)
  - Segment_Coordinator__c (Lookup: User)
  - Owner_Account__c (Lookup: Account, label "Owner")
  - GC__c (Lookup: Account, label "General Contractor")
  - Engineer_of_Record__c (Lookup: Account)
  - Originating_Brand__c (Picklist — use global value set Brand__c)
  - First_Contact_with_Engineer__c (Lookup: User)
  - Ingenia_Participating__c (Checkbox, default false — flow-maintained)
  - Cooling_Participating__c (Checkbox, default false — flow-maintained)
  - TAMCO_Participating__c (Checkbox, default false — flow-maintained)
  - PK_Participating__c (Checkbox, default false — flow-maintained)
  - CF_Participating__c (Checkbox, default false — flow-maintained, 
                         pre-built for Step 6)
  - Total_SPX_Potential__c (Currency 16,0 — flow-maintained)
  - Brands_Engaged__c (Number 3,0 — flow-maintained)
  - BOD_Secured__c (Text 20 — flow-maintained, e.g. "2 of 3")
  - Rep_Conflict__c (Checkbox, default false — flow-maintained)

Object 2: Project_Intake__c
  Label: Project Intake | Plural: Project Intakes | API: Project_Intake__c
  OWD: Private

  Custom fields:
  - CC_Project_ID__c (Text 50, External ID)
  - Project_Name__c (Text 255)
  - Vertical__c (Picklist — global value set Vertical__c)
  - City__c (Text 100)
  - State__c (Text 10)
  - Postal_Code__c (Text 10)
  - Estimated_Construction_Value__c (Currency 16,0)
  - Project_Phase__c (Picklist — global value set Project_Phase__c)
  - Status__c (Picklist: Staged, Received, Processed, Held)
  - Owner_Name__c (Text 255, label "Owner")
  - Contact_First__c (Text 50)
  - Contact_Last__c (Text 50)
  - Contact_Title__c (Text 100)
  - Contact_Email__c (Email)
  - Project__c (Lookup: Project__c)

Object 3: ERP_Cross_Reference__c
  Label: ERP Cross-Reference | API: ERP_Cross_Reference__c
  OWD: Public Read Only

  Custom fields:
  - ERP_Key__c (Text 100, External ID, Unique — format: "ERP System|Number")
  - ERP_System__c (Picklist: QTC, Ingénia ERP, TAMCO ERP, Patterson-Kelley ERP, 
                   Chicago Fan ERP)
  - ERP_Customer_Number__c (Text 50)
  - ERP_Customer_Name__c (Text 255)
  - Bill_To__c (Text Area 500)
  - Ship_To__c (Text Area 500)
  - Payment_Terms__c (Text 50)
  - Credit_Limit__c (Currency 16,0)
  - Phone__c (Phone)
  - Account__c (Lookup: Account, label "Account")
  - Brand_Relationship__c (Lookup: Brand_Relationship__c)
  - Match_Status__c (Picklist: Linked, Auto-linked, Possible Duplicate, 
                     New Customer)

  Field-level security: ERP_Customer_Name__c, Bill_To__c, Ship_To__c, 
  Payment_Terms__c, Credit_Limit__c — set to Read Only for all profiles 
  EXCEPT System Administrator and the ERP Integration permission set 
  (build this permission set in Step 7 below).

Object 4: Brand_Relationship__c
  Label: Brand Relationship | API: Brand_Relationship__c
  Relationship type: Master-Detail to Account

  Custom fields:
  - Brand__c (Picklist — global value set Brand__c)
  - Brand_Owner__c (Lookup: User)
  - Open_Pipeline__c (Currency 16,0)

Object 5: QTC_Message_Log__c
  Label: QTC Message Log | API: QTC_Message_Log__c
  OWD: Private

  Custom fields:
  - Opportunity__c (Lookup: Opportunity)
  - Brand__c (Picklist — global value set Brand__c)
  - Sent_At__c (DateTime)
  - Result__c (Text 255)

After deploying each object, run:
  sf sobject describe --sobject [ObjectAPIName]
to confirm the object and field count. Report results before proceeding.

---

STEP 5 — STANDARD OBJECT CUSTOM FIELDS

Add custom fields to Opportunity, Lead, and Account.
Reference: Handover Pack Section 1.1.

Opportunity custom fields:
  - Project__c (Lookup: Project__c, label "Project")
  - Brand__c (Picklist — global value set Brand__c, Required)
  - BU__c (Text 50, label "BU" — stamped by flow, not by user)
  - Vertical__c (Picklist — global value set Vertical__c)
  - BOD_Status__c (Picklist — global value set BOD_Status__c)
  - Rep_Firm__c (Lookup: Account, filter: Account_Role__c = "Rep firm")
  - Spec_Section__c (Text 100)
  - Territory__c (Text 50)
  - Rep_Conflict__c (Checkbox, default false — flow-maintained)
  - Fan_Arrangement__c (Picklist: Arrangement 1, Arrangement 2, Arrangement 3, 
                        Arrangement 4, Arrangement 7, Arrangement 8, 
                        label "Fan Arrangement")
  - Wheel_Type__c (Picklist: BI, SWSI, DWDI, label "Wheel Type")
  - Golden_Stage__c (Formula Text):
    Formula:
    IF(ISPICKVAL(StageName, "Qualify"), "2.0 Needs Analysis and Qualify",
    IF(ISPICKVAL(StageName, "Design Assist"), "3.0 Spec and Influence",
    IF(ISPICKVAL(StageName, "Quote"), "4.0 Solution and Proposal",
    IF(ISPICKVAL(StageName, "Negotiate"), "5.0 Negotiate and Close",
    TEXT(StageName)))))

Lead custom fields:
  - Project__c (Lookup: Project__c, label "Project")
  - Brand__c (Picklist — global value set Brand__c, Required)
  - Vertical__c (Picklist — global value set Vertical__c)
  - Est_Construction_Value__c (Currency 16,0, label "Est. Construction Value")
  - Est_Brand_Potential__c (Currency 16,0, label "Est. Brand Potential")
  - Potential_Basis__c (Text 255)
  - Routing_Rule__c (Text 100, label "Routing Rule")
  - Strategic_Project__c (Checkbox, default false)
  - Territory__c (Text 50)

Account custom fields:
  - Account_Role__c (Picklist: Owner, General Contractor, Mechanical Contractor,
                    Engineer, Architect, Rep firm)
  - Global_Ultimate__c (Lookup: Account, label "Global Ultimate")
  - Tier__c (Picklist: Strategic, Preferred, Standard)

Also add these values to the standard Account Source field:
  "QTC", "Ingénia ERP", "TAMCO ERP", "Patterson-Kelley ERP", "Chicago Fan ERP"
  (Chicago Fan ERP value: create as INACTIVE)

After deploying, run a describe on each object to confirm field count.

---

STEP 6 — SALES PROCESSES AND RECORD TYPES

Create these in this exact order. Reference: Handover Pack Section 7A.

Sales Process 1: "Golden Template"
  Opportunity stages to include (in order):
  1.0 Prospect and Market ID (Probability: 10, Type: Open)
  2.0 Needs Analysis and Qualify (Probability: 20, Type: Open)
  3.0 Spec and Influence (Probability: 40, Type: Open)
  4.0 Solution and Proposal (Probability: 60, Type: Open)
  5.0 Negotiate and Close (Probability: 80, Type: Open)
  Closed Won (Probability: 100, Type: Closed/Won)
  Closed Lost (Probability: 0, Type: Closed/Lost)

Sales Process 2: "Cooling Legacy"
  Stages:
  Qualify (Probability: 20, Type: Open)
  Design Assist (Probability: 40, Type: Open)
  Quote (Probability: 60, Type: Open)
  Negotiate (Probability: 80, Type: Open)
  Closed Won (Probability: 100, Type: Closed/Won)
  Closed Lost (Probability: 0, Type: Closed/Lost)

Record Type 1: "Golden Template – Project Sale"
  Object: Opportunity
  Sales Process: Golden Template
  This is the DEFAULT record type for all brand profiles

Record Type 2: "Cooling – Legacy"
  Object: Opportunity
  Sales Process: Cooling Legacy
  NOT the default for any profile. Assigned to Cooling profiles only.

After creating, verify both record types exist:
  sf sobject describe --sobject Opportunity | grep recordTypeInfos

---

STEP 7 — PROFILES

Create these profiles by cloning from Standard User.
Reference: Handover Pack Section 1.2.

  1. SPX RSM
  2. SPX Brand Sales Leader
  3. SPX Segment Sales Leader
  4. SPX Integration

Profile record type assignments:
  - SPX RSM: assign both record types; default = Golden Template – Project Sale
  - SPX Brand Sales Leader: assign both; default = Golden Template – Project Sale
  - SPX Segment Sales Leader: assign both; default = Golden Template – Project Sale
  - SPX Integration: Golden Template – Project Sale only

NOTE: Profile creation via CLI requires metadata deployment. Generate the 
profile XML from the existing Standard User profile and modify. 
Show me the XML before deploying.

---

STEP 8 — ROLE HIERARCHY

Create this exact role hierarchy. Reference: Handover Pack Section 1.2.
Use API names without spaces.

  Segment_Sales_Leader (label: Segment Sales Leader)
  ├── Segment_Support (label: Segment Support)
  ├── Ingenia_Brand_Sales_Leader (label: Ingénia Brand Sales Leader)
  │   ├── Ingenia_RSM_Ohio_Valley (label: Ingénia Rep (RSM) Ohio Valley)
  │   └── Ingenia_RSM (label: Ingénia RSM)  ← for background RSMs
  ├── Cooling_Brand_Sales_Leader (label: Cooling Brand Sales Leader)
  │   └── Cooling_RSM (label: Cooling Rep (RSM))
  ├── PK_Brand_Sales_Leader (label: Patterson-Kelley Brand Sales Leader)
  │   ├── PK_RSM_Ohio_Valley (label: Patterson-Kelley Rep (RSM))
  │   └── PK_RSM_Illinois (label: Patterson-Kelley Rep (RSM) Illinois)
  ├── TAMCO_Brand_Sales_Leader (label: TAMCO Brand Sales Leader)
  │   └── TAMCO_RSM (label: TAMCO Rep (RSM))
  └── CF_Brand_Sales_Leader (label: Chicago Fan Brand Sales Leader)
      └── CF_RSM (label: Chicago Fan Rep (RSM))

After creating, verify the hierarchy:
  sf data query --query "SELECT Name, ParentRoleId FROM UserRole ORDER BY Name"

---

STEP 9 — CUSTOM PERMISSIONS AND PERMISSION SETS

Reference: Handover Pack Sections 1.2 and 7B.

First, create these two custom permissions (Setup → Custom Permissions):
  1. SPX_Bypass_Validation_Rules
     Label: SPX Bypass Validation Rules
  2. SPX_Bypass_Automation
     Label: SPX Bypass Automation

Then create these permission sets:

  1. Golden_Template_User (label: Golden Template User)
     Object permissions: Opportunity (Read, Edit, Create, Delete own)
                         Lead (Read, Edit, Create)
                         Project__c (Read, Edit, Create)
                         Project_Intake__c (Read)
                         Account (Read, Edit)
                         Contact (Read, Edit, Create)
                         Quote (Read, Edit, Create)
     Tab visibility: all HVAC Segment app tabs

  2. Segment_Visibility (label: Segment Visibility)
     Object permissions: Opportunity (View All), Project__c (View All)
     Field permissions: all Opportunity and Project__c fields readable

  3. Segment_Support (label: Segment Support)
     Object permissions: Opportunity (View All, Edit), Project__c (View All, Edit)

  4. ERP_Integration (label: ERP Integration)
     Custom permission: none (this is the permission set that grants ERP field access)
     Object permissions: ERP_Cross_Reference__c (Read, Edit, Create)
     Field permissions: ERP_Customer_Name__c, Bill_To__c, Ship_To__c, 
                        Payment_Terms__c, Credit_Limit__c — Read + Edit

  5. Ingenia_User (label: Ingénia User)
     Object permissions: same as Golden Template User
     Intended for: Ingénia-specific RSMs

  6. SPX_Cincinnati_Fan (label: SPX Chicago Fan)
     Object permissions: same as Golden Template User
     Fan fields: Fan_Arrangement__c, Wheel_Type__c — Read + Edit
     NOTE: do NOT assign to any user. This is assigned live in Session 5 Step 6.

  7. SPX_Migration_Bypass (label: SPX Migration Bypass)
     Custom permissions: SPX_Bypass_Validation_Rules AND SPX_Bypass_Automation
     NOTE: assigned ONLY to the Migration User. Never to sales users.

After deploying, verify all 7 permission sets exist:
  sf data query --query "SELECT Name FROM PermissionSet WHERE IsCustom = true"

---

STEP 10 — ORG-WIDE DEFAULTS AND SHARING RULES

Set OWDs. Reference: Handover Pack Section 1.2.

OWD settings (set in Setup → Sharing Settings):
  - Account: Public Read Only
  - Contact: Controlled by Parent
  - Lead: Private
  - Opportunity: Private
  - Project__c: Private
  - ERP_Cross_Reference__c: Public Read Only
  - Brand_Relationship__c: Controlled by Parent (Account)
  - QTC_Message_Log__c: Private
  - Project_Intake__c: Private

MANUAL STEP: OWD changes must be made in Setup → Sharing Settings.
Tell me each setting to change, wait for my confirmation, then run 
a sharing recalculation verify before continuing.

After OWDs are set, create these sharing rules on Project__c:

Sharing Rule 1: Ingenia_Participating_Projects
  Object: Project__c
  Criteria: Ingenia_Participating__c = true
  Share with: Role: Ingenia_Brand_Sales_Leader (and subordinates)
  Access: Read Only

Sharing Rule 2: Cooling_Participating_Projects
  Object: Project__c
  Criteria: Cooling_Participating__c = true
  Share with: Role: Cooling_Brand_Sales_Leader (and subordinates)
  Access: Read Only

Sharing Rule 3: PK_Participating_Projects
  Object: Project__c
  Criteria: PK_Participating__c = true
  Share with: Role: PK_Brand_Sales_Leader (and subordinates)
  Access: Read Only

Sharing Rule 4: TAMCO_Participating_Projects
  Object: Project__c
  Criteria: TAMCO_Participating__c = true
  Share with: Role: TAMCO_Brand_Sales_Leader (and subordinates)
  Access: Read Only

Sharing Rule 5: CF_Participating_Projects
  Object: Project__c
  Criteria: CF_Participating__c = true
  Share with: Role: CF_Brand_Sales_Leader (and subordinates)
  Access: Read Only

Sharing Rule 6: Strategic_Projects_All_Leaders
  Object: Project__c
  Criteria: Strategic_Project__c = true
  Share with: Role Group: all Brand Sales Leader roles
  Access: Read Only

Verify all 6 sharing rules exist after deployment.

---

STEP 11 — LIGHTNING APP

Create the HVAC Segment Lightning app.
Reference: Handover Pack Section 1.3.

App name: HVAC Segment
API name: HVAC_Segment
Navigation items (in this order):
  Home, Projects (Project__c tab), Leads, Accounts, Contacts, 
  Opportunities, Quotes, Reports, Dashboards

Profiles with access: SPX RSM, SPX Brand Sales Leader, 
SPX Segment Sales Leader, System Administrator

After deploying, verify the app appears in the App Launcher.
MANUAL STEP: Open the app in Setup → App Manager → HVAC Segment → 
confirm navigation items are in the correct order.

---

STEP 12 — SESSION 1 VERIFICATION

Run these verification queries before declaring Session 1 complete:

  sf data query --query "SELECT COUNT() FROM Project__c"
  sf data query --query "SELECT COUNT() FROM Project_Intake__c"
  sf data query --query "SELECT COUNT() FROM ERP_Cross_Reference__c"
  sf data query --query "SELECT COUNT() FROM Brand_Relationship__c"
  sf data query --query "SELECT COUNT() FROM QTC_Message_Log__c"
  sf data query --query "SELECT Name, Live__c FROM Brand_Configuration__mdt"
  sf data query --query "SELECT Name FROM PermissionSet WHERE IsCustom = true"
  sf data query --query "SELECT Name, ParentRoleId FROM UserRole ORDER BY Name"
  sf data query --query "SELECT DefaultRecordTypeId FROM RecordType 
                          WHERE SobjectType = 'Opportunity'"

Report the result of every query. Flag any that return unexpected results.

Now paste the End-of-Session Request and give me the handoff summary.
```

---
---

# SESSION 2
## Flows
## Estimated time: 2–3 hours

### PASTE ORDER:
1. Context setter
2. [Paste Session 1 handoff summary here]
3. Session 2 instruction (below)

---

```
SESSION 2 INSTRUCTION: Flows

This is Session 2 of 6. Session 1 built the foundation objects, metadata, 
security, and app. This session builds all 6 flows.

Reference: Handover Pack Sections 2, 3, 4, 5, 6, and 7.

CRITICAL RULE FOR EVERY FLOW: Every SPX record-triggered flow must include 
this as an entry condition so the Migration User can bypass it during data loads:
  NOT({!$Permission.SPX_Bypass_Automation})
Add this as the FIRST entry condition on every flow below.

Build each flow, deploy it, and verify it before building the next one.

---

FLOW 1 — "SPX Project totals"
Reference: Handover Pack Section 4 (Scenario 3).

Type: Record-Triggered Flow
Object: Opportunity
Trigger: After Save
Runs when: A record is created, updated, or deleted
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Project__c IS NOT NULL
Run in: System context without sharing

Logic:
1. Get Records: all Opportunities where Project__c = triggeringRecord.Project__c 
   AND IsClosed = false
2. Loop through all retrieved Opportunities:
   a. Add Amount to variable varTotal (Currency)
   b. Collect unique Brand__c values into text collection varBrands 
      (check if brand already in collection before adding)
   c. Count records where BOD_Status__c = 'Secured' into variable varBODCount
3. After loop, calculate:
   varBrandsCount = count of varBrands collection
   varBODText = TEXT(varBODCount) & " of " & TEXT(varBrandsCount)
4. Update Record: Project__c (the triggering Opportunity's Project__c)
   - Total_SPX_Potential__c = varTotal
   - Brands_Engaged__c = varBrandsCount
   - BOD_Secured__c = varBODText

After building, test by:
1. Creating a test Project__c record
2. Creating two Opportunities linked to it with different brands and amounts
3. Verifying Project.Total_SPX_Potential__c = sum of both amounts
4. Verifying Project.Brands_Engaged__c = 2
Then delete the test records.

---

FLOW 2 — "SPX Rep conflict check"
Reference: Handover Pack Section 4 (Scenario 3).

IMPORTANT: This flow compares owners WITHIN the same brand on a project — 
NOT across all brands. Different brands always have different owners by design.

Type: Record-Triggered Flow
Object: Opportunity
Trigger: After Save
Runs when: Created, or any of these fields changed: OwnerId, Brand__c, 
           Project__c, StageName; also fires on Delete
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Project__c IS NOT NULL
Run in: System context without sharing

Logic:
1. Get Records (colSameBrand): Opportunities where
   - Project__c = triggeringRecord.Project__c
   - Brand__c = triggeringRecord.Brand__c
   - IsClosed = false
2. Decision: does any record in colSameBrand have OwnerId ≠ triggeringRecord.OwnerId?
   YES path:
     - Loop colSameBrand: set Rep_Conflict__c = true on each record
     - Bulk update all records in colSameBrand
   NO path:
     - Loop colSameBrand: set Rep_Conflict__c = false on each record
     - Bulk update all records in colSameBrand
3. Get Records (colFlagged): Opportunities where
   - Project__c = triggeringRecord.Project__c
   - Rep_Conflict__c = true
4. Update the Project: Rep_Conflict__c = (colFlagged is NOT empty)

After building, test by:
1. Creating a test Project, two Opportunities same brand, two different owners
2. Verify Rep_Conflict__c = true on both Opportunities and the Project
3. Change one Opportunity's owner to match the other
4. Verify Rep_Conflict__c = false on both and the Project
Then delete test records.

---

FLOW 3 — "SPX Opportunity participation"
Reference: Handover Pack Sections 4 and 7C.

IMPORTANT: This flow has FOUR versions. Build v1 through v4.
v3 is active. v4 is pre-built but left INACTIVE (activated live in Step 6).

Type: Record-Triggered Flow
Object: Opportunity
Trigger: After Save
Runs when: Created or Brand__c, Project__c, IsClosed changed
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Project__c IS NOT NULL
Run in: System context without sharing

Version 1 logic (Cooling only):
  If Brand__c = 'Cooling' and IsClosed = false:
    Update Project: Cooling_Participating__c = true
  If Brand__c = 'Cooling' and IsClosed = true:
    Check if any open Cooling Opps on project remain; if none, set false

Version 2 logic (adds Ingénia):
  Same as v1, plus the same logic for Brand__c = 'Ingénia' and Ingenia_Participating__c

Version 3 logic (adds TAMCO and Patterson-Kelley) — ACTIVE:
  Same as v2, plus:
    TAMCO_Participating__c for Brand__c = 'TAMCO'
    PK_Participating__c for Brand__c = 'Patterson-Kelley'

Version 4 logic (adds Chicago Fan) — INACTIVE:
  Same as v3, plus:
    CF_Participating__c for Brand__c = 'Chicago Fan'

Deploy all four versions. Activate version 3. Confirm version 4 exists 
but is NOT active. Show me the version list before we proceed.

MANUAL STEP: In Setup → Flows → SPX Opportunity participation:
  Confirm v3 shows as Active and v4 shows as Inactive.

---

FLOW 4 — "SPX Intake process"
Reference: Handover Pack Section 2 (Scenario 1).

Type: Record-Triggered Flow
Object: Project_Intake__c
Trigger: After Save
Runs when: Status__c changes to "Received"
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Status__c = "Received" (current value)
Run in: System context without sharing

Logic:
1. Try to match intake to existing Project__c:
   a. First: exact match on CC_Project_ID__c
   b. If no match: fuzzy match (same Postal_Code__c + similar name — 
      use exact postal match as a proxy in Flow since fuzzy isn't available; 
      flag this as a limitation)
2. If match found:
   - Update existing Project: Estimated_Construction_Value__c, Project_Phase__c
   - Set Project_Intake__c.Project__c = matched project Id
   - Set Status__c = "Processed"
3. If no match:
   - Create new Project__c:
     Name = Project_Intake__c.Project_Name__c
     CC_Project_ID__c = intake CC_Project_ID__c
     Vertical__c, City__c, State__c, Postal_Code__c, Estimated_Construction_Value__c,
     Project_Phase__c — all copied from intake
     Strategic_Project__c = (Estimated_Construction_Value__c > 100000000)
   - Set Project_Intake__c.Project__c = new project Id
   - Set Status__c = "Processed"
4. Set Strategic_Project__c = true if Estimated_Construction_Value__c > 100000000
5. Loop Brand_Configuration__mdt where Live__c = true:
   For each live brand:
   a. Check if intake Vertical is in brand's Target_Verticals__c
   b. Check if intake value >= brand's Routing_Threshold__c
   c. Check if intake Project_Phase__c is at or past brand's Earliest_Routing_Phase__c
   d. If all conditions met:
      - Create new Lead:
        LastName = intake Contact_Last__c (or "Unknown" if blank)
        FirstName = intake Contact_First__c
        Title = intake Contact_Title__c
        Email = intake Contact_Email__c
        Company = intake Project_Name__c
        Brand__c = brand metadata Brand_Value__c
        Vertical__c = intake Vertical__c
        Est_Construction_Value__c = intake Estimated_Construction_Value__c
        Est_Brand_Potential__c = from Potential_Factor__mdt if available
        Project__c = the matched or created project Id
        Strategic_Project__c = (value > 100000000)
        Territory__c = from Routing_Rule__mdt by brand + state
        OwnerId = from Routing_Rule__mdt by brand + state 
                  (use queue or user alias match)
        Status = New
6. If Strategic_Project__c = true:
   - Send custom notification (type: "New strategic project in your territory")
     to all brand leader users whose brand has a Lead created

NOTE: The ConstructConnect feed is STAGED. This flow runs on Status = Received.
The demo pre-sets intake rows to Received before the session; this flow 
already ran. Never trigger it live during the demo.

After building, do NOT test with live intake records — test with a 
temporary staging record and verify Lead creation, then delete.

---

FLOW 5 — Price book flow (before-save on Opportunity)
Reference: Handover Pack Section 6, "Price book flow".

Type: Record-Triggered Flow
Object: Opportunity
Trigger: Before Save
Runs when: Created, or Brand__c or CurrencyIsoCode changed
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Brand__c IS NOT NULL

Logic:
1. Get Brand_Configuration__mdt record where Brand_Value__c = {!Record.Brand__c}
2. Get the matching Price Book where Name contains the brand name and 
   currency matches {!Record.CurrencyIsoCode}
   (Name convention: "[Brand] [Year] List ([Currency])", 
   e.g. "Ingénia 2026 List (USD)")
3. Set {!Record.Pricebook2Id} = matched price book Id
   If no match found: leave Pricebook2Id unchanged (do not error)

Note: Price books are created in Session 5. This flow will be deployed 
now but will not find price books until Session 5. That is expected.

---

FLOW 6 — ERP cross-reference flow
Reference: Handover Pack Section 3 (Scenario 2).

Type: Record-Triggered Flow
Object: ERP_Cross_Reference__c
Trigger: After Save
Runs when: Account__c changes
Entry conditions:
  1. NOT({!$Permission.SPX_Bypass_Automation})
  2. Account__c IS NOT NULL

Logic:
1. Get the Account record for Account__c
2. Get the Global_Ultimate__c of that Account (may be the account itself 
   if it is the global parent)
3. Look for existing Brand_Relationship__c where:
   Account = Global_Ultimate__c AND Brand__c = triggeringRecord.Brand__c
   (get Brand__c from the ERP_System__c mapping — 
    "QTC" → "Cooling", "Ingénia ERP" → "Ingénia", etc.)
4. If Brand Relationship exists: update Open_Pipeline__c (recalculate from Opportunities)
5. If no Brand Relationship exists: create one:
   AccountId = Global_Ultimate__c
   Brand__c = derived from ERP_System__c
   Brand_Owner__c = leave blank (user sets manually)

---

SESSION 2 VERIFICATION

After all 6 flows are built and deployed:

  sf data query --query "SELECT ApiName, Status, VersionNumber 
                          FROM FlowVersionView 
                          WHERE ApiName LIKE 'SPX%' 
                          ORDER BY ApiName, VersionNumber"

Expected: 
  - SPX_Intake_process: one active version
  - SPX_Opportunity_participation: v3 Active, v4 Inactive
  - SPX_Project_totals: one active version
  - SPX_Rep_conflict_check: one active version
  - Price book flow: one active version
  - ERP_cross_reference_flow: one active version

Flag any flow that is not in the expected state.

Now paste the End-of-Session Request.
```

---
---

# SESSION 3
## Data Load
## Estimated time: 2–3 hours

### PASTE ORDER:
1. Context setter
2. [Paste Session 2 handoff summary here]
3. Session 3 instruction (below)

---

```
SESSION 3 INSTRUCTION: Data load

This is Session 3 of 6. Sessions 1 and 2 built the foundation and flows. 
This session loads all demo data from the Data Workbook.

Reference: SPX_Demo_Data_Workbook.xlsx — every sheet, in the load order 
specified on the "Read me" sheet.

LOAD RULES:
- Use the "Key" column from each sheet as the external ID for upserts
- Use sf data import or the Bulk API (sf data upsert bulk) for all loads
- Load flows are ACTIVE — this means participating checkboxes and project 
  totals will calculate automatically. That is correct behaviour.
- Exception: the Migration User (alias: migrate) with SPX_Migration_Bypass 
  must be used for Opportunity loads ONLY — this bypasses automation during 
  the bulk Opportunity load so we can control when totals recalculate

WHAT NOT TO LOAD (created live in the demo — do not pre-load):
  - Rachel Tran (Contact)
  - Westfield Regional Medical Center (Project)
  - Any leads or opportunity for Westfield
  - Quote Q-00128
  - Kim Alvarez's Chicago Fan opportunity

---

STEP 1 — USERS

Generate a CSV from the Users sheet of the Data Workbook.
Load all users in the sheet EXCEPT: integ and migrate (create these manually 
or as part of profile setup since they need specific profiles).

For each user, set:
  - Profile: per the Users sheet (SPX RSM, SPX Brand Sales Leader, etc.)
  - Role: per the role hierarchy built in Session 1
  - Permission Sets: per the "Permission sets" column — assign after user creation

After loading, query to verify:
  sf data query --query "SELECT Alias, ProfileId, UserRoleId 
                          FROM User 
                          WHERE IsActive = true AND Alias IN 
                          ('sokafor','pnataraj','mhill','dreyes','tbrennan',
                           'kalvarez','amoreau','lduval','jpark','rkeane',
                           'msantos','jblake','agomez','bortiz','hlee',
                           'spatel','lfischer','gkim','kliu')"

Then assign permission sets per the Users sheet. Verify assignments:
  sf data query --query "SELECT Assignee.Alias, PermissionSet.Name 
                          FROM PermissionSetAssignment 
                          WHERE Assignee.IsActive = true 
                          ORDER BY Assignee.Alias"

IMPORTANT: Do NOT assign SPX_Cincinnati_Fan to Kim Alvarez (kalvarez) now.
That is done live in Session 5 (Step 6 demo).

Create Integration User (integ) and Migration User (migrate) manually:
  - Both use profile SPX_Integration
  - integ: assign ERP_Integration permission set
  - migrate: assign SPX_Migration_Bypass permission set

---

STEP 2 — ACCOUNTS (parents first, then children)

Load in this exact order — parent accounts must exist before children.

Round 1 (global parents and standalone accounts):
  Load these first: A-LAK, A-ARD, A-KES, A-HOL, A-NPD, A-BSU, A-LVC, 
  A-RCD, A-BAS, A-MVH, A-LHS, A-ARDM, A-MMC

Round 2 (child accounts — after parents are confirmed):
  Load: A-ARD-OH, A-ARD-GL, A-ARD-SE
  Parent: A-ARD (use external ID to reference)

Round 3 (ERP-created accounts — load as Integration User with duplicate rules ACTIVE):
  Load: A-ERP-4431 (MIDWEST MECH CONTR — Patterson-Kelley ERP, no duplicates)
  
  Then load: A-ERP-4417 (ARDENT BLDRS INC — Patterson-Kelley ERP, Columbus 43219)
  CRITICAL: Load this as the Integration User. A Duplicate Record Set must be 
  created because it matches A-ARD-OH (same phone and postal code).
  After loading, verify:
    sf data query --query "SELECT Id FROM DuplicateRecordSet WHERE Name LIKE '%ARDENT%'"
  If no Duplicate Record Set was created via API (some sandboxes don't create 
  DRS via API), create A-ERP-4417 manually in the UI as the Integration User 
  so the duplicate rules fire. Tell me if this is needed.

After all accounts, verify:
  sf data query --query "SELECT COUNT() FROM Account"
  sf data query --query "SELECT Name, Account_Role__c FROM Account ORDER BY Name"

---

STEP 3 — CONTACTS

Load from the Contacts sheet of the Data Workbook.
After loading, set up Account Contact Relationships for contacts who 
are related to multiple accounts (per the "Also related to" column).

Verify:
  sf data query --query "SELECT FirstName, LastName, Title, Account.Name 
                          FROM Contact ORDER BY LastName"

---

STEP 4 — PROJECTS

Load from the Projects sheet. Do NOT load the Westfield project 
(CC-88412 / Westfield Regional Medical Center) — created live in Step 1.

After loading, verify:
  sf data query --query "SELECT Name, Vertical__c, Estimated_Construction_Value__c, 
                          Strategic_Project__c FROM Project__c ORDER BY Name"

Confirm that projects with Estimated_Construction_Value__c > 100000000 
have Strategic_Project__c = true (set by the intake flow or manually 
if these were created without going through intake).

NOTE: Projects loaded directly (not through Project Intake) will not 
have Strategic_Project__c set automatically. After loading, run:
  sf data update --sobject Project__c --records [csv with Id and Strategic_Project__c]
for any project with value > $100M.

---

STEP 5 — PROJECT STAKEHOLDERS

Add Account-to-Project relationships (Owner, GC, Engineer) using the 
Owner_Account__c, GC__c, and Engineer_of_Record__c lookups on Project__c.
These should be set as part of the Project load in Step 4 if the 
Account external IDs are referenced correctly.

Verify the Lakemont East Tower project (P-00977):
  sf data query --query "SELECT Name, Owner_Account__r.Name, GC__r.Name, 
                          Engineer_of_Record__r.Name 
                          FROM Project__c WHERE Project_Code__c = 'P-00977'"
  Expected: Owner = Lakemont Health, GC = Ardent Builders (Ohio Region), 
             Engineer = Kessler MEP Engineers

---

STEP 6 — OPPORTUNITIES

Load opportunities using the MIGRATION USER to bypass automation.
Run as: migrate (SPX_Migration_Bypass permission set active)

Load all Opportunities from the Opportunities sheet EXCEPT:
  - O-ET-PK2 (Lakemont East Tower – PK – Hydronic plant, owned by rkeane)
    Load this one WITH automation active — we want the rep conflict flag to fire
  - Kim's Chicago Fan opportunity — not loaded, created live

For each Opportunity, set:
  - Record Type: Golden Template – Project Sale 
    (EXCEPT O-ND-COOL: Cooling – Legacy)
  - All custom fields from the sheet
  - OwnerId via user alias

After loading the bulk Opportunities (with bypass), run a one-off 
recalculation by re-saving each Project (or running an anonymous Apex script):
  sf apex run --file recalculate_projects.apex
  
  Content of recalculate_projects.apex:
  List<Project__c> projects = [SELECT Id FROM Project__c];
  for(Project__c p : projects) {
    update p; // triggers won't fire without a DML change — 
              // alternatively query related Opps and recalculate
  }
  
  NOTE: Since flows are triggered by Opportunity changes, re-save the 
  Opportunities one per project instead to force recalculation.

After recalculation, verify Lakemont East Tower project (P-00977):
  sf data query --query "SELECT Total_SPX_Potential__c, Brands_Engaged__c, 
                          BOD_Secured__c, Rep_Conflict__c 
                          FROM Project__c WHERE Project_Code__c = 'P-00977'"
  Expected: 
    Total_SPX_Potential__c ≈ $3,880,000 (sum of linked open Opps)
    Brands_Engaged__c = 3 (Ingénia, Cooling, Patterson-Kelley)
    Rep_Conflict__c = true (two PK Opps with different owners)

---

STEP 7 — BRAND RELATIONSHIPS

Load from the Brand Relationships sheet.
Use the Integration User for these loads.

Verify:
  sf data query --query "SELECT Account.Name, Brand__c, Brand_Owner__r.Alias, 
                          Open_Pipeline__c 
                          FROM Brand_Relationship__c ORDER BY Account.Name"

---

STEP 8 — ERP CROSS-REFERENCES

Load all ERP Cross-References EXCEPT the last batch (5 records marked 
"Last batch" in the Data Workbook — load those separately below).

First batch (auto-linked / already under correct accounts):
  QTC|118220, QTC|118904, QTC|120011, ING|20931, TAM|7781

Load these as the Integration User.

Last batch (5 records — load in this order as the Integration User):
  1. TAM|7802 (KESSLER MEP ENGRS → A-KES) — auto-linked
  2. PK|004435 (HOLLOWAY PARTNERS ARCH → A-HOL) — auto-linked  
  3. TAM|7810 (NORTHPOINT DIGITAL INFRA → A-NPD) — auto-linked
  4. PK|004431 (MIDWEST MECH CONTR → A-ERP-4431) — new customer
  5. PK|004417 (ARDENT BLDRS INC → A-ERP-4417) — possible duplicate, 
     should have a DRS

After loading all, verify:
  sf data query --query "SELECT ERP_Key__c, ERP_Customer_Name__c, 
                          Account__r.Name, Match_Status__c 
                          FROM ERP_Cross_Reference__c ORDER BY ERP_Key__c"
  
  sf data query --query "SELECT COUNT() FROM DuplicateRecordSet"
  Confirm at least 1 DuplicateRecordSet exists for ARDENT BLDRS INC.

---

STEP 9 — PROJECT INTAKE

Load from the Project Intake sheet with Status = Staged.
Load all 4 rows (CC-88412, CC-88409, CC-88422, CC-88424) as Staged.

IMPORTANT: Do NOT set these to Received during the load.
Before the demo session (morning of), they will be manually set to 
Received so the flow runs and results are pre-staged on screen.

Verify:
  sf data query --query "SELECT CC_Project_ID__c, Project_Name__c, 
                          Status__c FROM Project_Intake__c"
  All 4 rows should show Status = Staged.

---

STEP 10 — TASKS

Load from the Tasks sheet. 
These are Dana's (dreyes) pre-existing tasks shown on the RSM home page.

Verify:
  sf data query --query "SELECT Subject, ActivityDate, OwnerId 
                          FROM Task WHERE Owner.Alias = 'dreyes'"

---

STEP 11 — BACKGROUND VOLUME

Generate background pipeline Opportunities for the inactive RSMs 
(msantos, jblake, agomez, bortiz, hlee, spatel, lfischer, gkim) so that 
Marcus's "Pipeline by Owner" home page chart shows the correct totals.

Required totals per owner (from the Data Workbook):
  msantos: $38.4M | jblake: $31.2M | agomez: $29.7M | bortiz: $27.5M
  hlee: $26.1M    | spatel: $24.8M | lfischer: $11.6M | gkim: $8.76M

Generate these as Opportunities OUTSIDE the Ohio Valley territory 
(territory = e.g. Great Lakes, Southeast, Southwest) so they do not 
appear in Dana's Ohio Valley list views.

Create them on placeholder projects or standalone (no Project__c required 
for background volume). Brand = Ingénia for all. Stage = any open stage.

Also load these top Segment opportunities (shown on Priya's home page):
  O-MER-COOL: Meridian Hyperscale Campus, Cooling, tbrennan, $11.4M, Southwest
  O-LSD-COOL: Lone Star DC Campus, Cooling, tbrennan, $8.9M, Southwest
  O-GLM-ING: Great Lakes Medical Center, Ingénia, msantos, $5.6M, Great Lakes
  O-CRC-ING: Carolina Research Campus, Ingénia, jblake, $4.9M, Southeast
  O-ADH-TAM: Atlanta Data Hub, TAMCO, jpark, $3.9M, Southeast

---

STEP 12 — SESSION 3 VERIFICATION

Run full data verification:
  sf data query --query "SELECT COUNT() FROM User WHERE IsActive = true"
  sf data query --query "SELECT COUNT() FROM Account"
  sf data query --query "SELECT COUNT() FROM Contact"
  sf data query --query "SELECT COUNT() FROM Project__c"
  sf data query --query "SELECT COUNT() FROM Opportunity WHERE IsClosed = false"
  sf data query --query "SELECT COUNT() FROM ERP_Cross_Reference__c"
  sf data query --query "SELECT COUNT() FROM Project_Intake__c"
  sf data query --query "SELECT COUNT() FROM Task"

Security spot-check (run as dreyes using sf cli org login):
  - dreyes should see only her own Opportunities
  - dreyes should be able to see Project P-00977 (via sharing rule)
  - dreyes should NOT see tbrennan's Opportunities

Tell me the count results and the security spot-check outcome.

Now paste the End-of-Session Request.
```

---
---

# SESSION 4
## Scenarios 1–4: Pages, Home Pages, Reports, Rules
## Estimated time: 2–3 hours

### PASTE ORDER:
1. Context setter
2. [Paste Session 3 handoff summary here]
3. Session 4 instruction (below)

---

```
SESSION 4 INSTRUCTION: Scenarios 1–4

This is Session 4 of 6. Data is loaded. This session configures 
the scenario-specific UI, rules, and reports for Steps 1–4 of the demo.

Reference: Handover Pack Sections 2 (Scenario 1), 3 (Scenario 2), 
4 (Scenario 3), 5 (Scenario 4).

---

STEP 1 — SCENARIO 1: LEAD FROM FEED

Reference: Handover Pack Section 2.

1a. Lead record page (Dynamic Forms in Lightning App Builder)
Create a Dynamic Forms Lead page with these sections:

  Section 1: "Project intelligence" (collapsible, collapsed by default)
    Fields: CC_Project_ID__c, Est_Construction_Value__c, Project_Phase__c,
            Vertical__c, Strategic_Project__c
    Visibility: show when Intelligence_Source = 'ConstructConnect' 
    (add Intelligence_Source as a picklist field on Lead if not already there)
    All fields in this section: Read Only

  Section 2: "Brand potential"
    Fields: Brand__c, Est_Brand_Potential__c, Potential_Basis__c

  Section 3: "Routing"
    Fields: Territory__c, Routing_Rule__c, OwnerId

  Standard sections: Contact information, Address Information, 
  Additional Information (standard fields)

  Assign to: HVAC Segment app, all Lead record types

MANUAL STEP: Open Lightning App Builder, build this page, 
assign to HVAC Segment app, and save. Tell me when done.

1b. Lead field mapping to Opportunity (Setup → Lead Convert)
Add these custom field mappings:
  Lead.Project__c → Opportunity.Project__c
  Lead.Brand__c → Opportunity.Brand__c
  Lead.Vertical__c → Opportunity.Vertical__c
  Lead.Est_Brand_Potential__c → Opportunity.Amount (if direct mapping is possible; 
  if not, note this and we will handle it with the before-save flow on Opportunity)
  Lead.Strategic_Project__c → Opportunity.Strategic_Project__c (add this field 
  to Opportunity if not already there)
  Lead.Territory__c → Opportunity.Territory__c

MANUAL STEP: Go to Setup → Lead Convert → verify field mappings, 
add any missing ones. Tell me when done.

1c. Duplicate and matching rules
Create these rules. Reference: Handover Pack Section 3.

Matching Rule 1: "ERP Exact Match" (on Account)
  Criteria:
    Account Name: Exact (Company Name variation)
    Billing Zip/Postal Code: Exact
    Phone: Exact
  Match blank fields: false

Matching Rule 2: Activate the standard "Standard Account Matching Rule" 
(if not already active).

Matching Rule 3: Contact matching rule
  Criteria:
    First Name: Exact
    Last Name: Exact
    Email: Exact

Duplicate Rule 1: "ERP customer: exact match" (on Account)
  Matching rule: ERP Exact Match
  Conditions: Account Source includes any brand ERP value
  Action on Create: Block
  Action on Edit: Block

Duplicate Rule 2: "ERP customer: possible match" (on Account)
  Matching rule: Standard Account Matching Rule
  Conditions: Account Source includes any brand ERP value
  Action on Create: Allow with Alert and Report (creates Duplicate Record Set)
  Action on Edit: Allow with Alert

Duplicate Rule 3: Contact deduplication
  Matching rule: Contact matching rule
  Action on Create: Allow with Alert
  Action on Edit: Allow with Alert

MANUAL STEP: Duplicate rules must be activated in Setup → Duplicate Management. 
Tell me when all three are active.

1d. RSM home page: "HVAC Home – RSM"
Build this page with Report Chart components only (no List View or Key Deals).
Reference: Handover Pack Section 5.

First, create these reports (save to HVAC Segment folder):

Report A: "My New Leads" 
  Object: Leads
  Filter: Owner = Current User, Status = New
  Columns: Name, Company, Brand__c, Vertical__c, Est_Brand_Potential__c, Status
  Chart: bar, grouped by Name (or Company), value = Est_Brand_Potential__c
  Row limit: 5

Report B: "My Pipeline by Stage"
  Object: Opportunities
  Filter: Owner = Current User, IsClosed = false
  Group by: StageName
  Chart: funnel or bar, value = Amount

Report C: "My Top Opportunities"
  Object: Opportunities  
  Filter: Owner = Current User, IsClosed = false
  Sort: Amount descending
  Row limit: 5
  Chart: bar, value = Amount

Then build the home page with these components (top to bottom, two columns):
  Column 1: "My Pipeline by Stage" (Report Chart, Report B)
  Column 2: "Leads" (Report Chart, Report A)
  Column 1: "Opportunities" (Report Chart, Report C)
  Column 2: Today's Tasks (standard component)

Assign to: SPX RSM profile, HVAC Segment app.

MANUAL STEP: Lightning App Builder → New Home Page → 
assign to SPX RSM, HVAC Segment. Tell me when done.

1e. In-App Guidance (MANUAL STEPS — tell me exactly what to click)
Build these prompts in Setup → In-App Guidance:

Prompt 1: "How to read the feed"
  Type: Targeted or Docked
  Location: Project Intake list view
  Audience: SPX Integration profile users (Segment operations)
  Content: Brief explanation of how to read ConstructConnect feed rows

Prompt 2: "Your recommended potential"
  Type: Docked
  Location: Lead record page
  Audience: SPX RSM profile
  Content: Explain how Est_Brand_Potential__c was calculated

Prompt 3: "Qualified? Convert it"
  Type: Targeted
  Location: Lead record page (anchor to Convert action or brand potential section)
  Audience: SPX RSM profile
  Content: Prompt to convert qualified leads

For each prompt: tell me the exact navigation path in Setup. 
I will build these manually and confirm when each is done.

---

STEP 2 — SCENARIO 2: ERP MAPPING AND UNIFIED CUSTOMER VIEW

Reference: Handover Pack Section 3.

2a. Account record page (Unified Customer View)
MANUAL STEP: Open Lightning App Builder for Account.
Build a Dynamic Forms Account page with these sections in order:

Section 1: Highlights panel (compact layout)
  Fields: Account_Role__c, Tier__c, Owner (set as placeholder "SPX" for 
  global accounts — the Owner is the user named "SPX" — create this 
  placeholder user if needed), Phone, BillingCity

Section 2: Three metric tiles (report charts)
  Metric 1: "Open pipeline, all brands" — report summing Opportunity Amount 
    across all brands related to this account
  Metric 2: "Brands active" — count of distinct Brand__c values on open Opps
  Metric 3: "Strategic projects as GC" — count of Project__c where GC = this account 
    and Strategic_Project__c = true

Section 3: Standard Potential Duplicates component (drag from component panel)

Section 4: Four related lists stacked in this order:
  1. Brand Relationships (Brand_Relationship__c)
     Columns: Brand__c, Brand_Owner__r.Name, Open_Pipeline__c
  2. Project Relationships (Project_Stakeholder__c or via GC/Engineer lookups — 
     use a related list of Projects where Account = GC or Engineer or Owner)
  3. ERP Cross-References (ERP_Cross_Reference__c)
     Columns: ERP_System__c, ERP_Customer_Number__c, ERP_Customer_Name__c, Match_Status__c
  4. Contacts (Contact related list)
     Columns: Name, Title, Account.Name

Assign to: HVAC Segment app, all Account record types.

Tell me when the page is built and saved.

2b. SPX placeholder user for global accounts
Create a user named "SPX" (or use a queue):
  FirstName: SPX | LastName: Account Owner | Alias: spxacct
  Profile: SPX Integration (no license needed for placeholder)
  This user is set as Owner on global parent accounts.

---

STEP 3 — SCENARIO 3: ONE PROJECT, ALL BRANDS

Reference: Handover Pack Section 4.

3a. Project record page
MANUAL STEP: Open Lightning App Builder for Project__c.
Build with these components:

  Path component: Project_Phase__c (at the top)

  Highlights panel (compact layout for Project__c):
    Fields: Vertical__c, Project_Phase__c, Estimated_Construction_Value__c,
            Total_SPX_Potential__c, Brands_Engaged__c, BOD_Secured__c, Rep_Conflict__c

  Standard Opportunities related list:
    Label: "Opportunities"
    Columns: Opportunity Name, Brand__c, StageName, BOD_Status__c, 
             Rep_Firm__r.Name, Owner.Name, Amount, Rep_Conflict__c
    Sort: Amount descending

  Project Stakeholders section (read-only fields):
    Owner_Account__r.Name, GC__r.Name, Engineer_of_Record__r.Name

  Do NOT add: Project History related list

Assign to: HVAC Segment app, all Project__c record types.
Tell me when done.

3b. Strategic projects list view on Project__c
Create list view "Strategic Projects":
  Filter: Strategic_Project__c = true
  Columns: Name, Vertical__c, Estimated_Construction_Value__c, Project_Phase__c,
           Brands_Engaged__c, BOD_Secured__c, Rep_Conflict__c
  Sort: Estimated_Construction_Value__c descending
  Visibility: visible to all users

---

STEP 4 — SCENARIO 4: ROLE-BASED VISIBILITY / THREE HOME PAGES

Reference: Handover Pack Section 5.

4a. Create additional reports (save to HVAC Segment folder)

Report D: "Team Pipeline by Owner" (for Marcus's home page)
  Object: Opportunities
  Filter: Owner Role = Ingénia Brand Sales Leader and subordinates, IsClosed = false
  Group by: Owner.Name
  Chart: bar, grouped by Owner, value = Amount
  Show: up to 10 owners

Report E: "Team Top Opportunities" (for Marcus)
  Object: Opportunities
  Filter: Owner Role = Ingénia Brand Sales Leader and subordinates, IsClosed = false
  Sort: Amount descending, row limit 5
  Chart: bar, value = Amount

Report F: "Open Pipeline by BU" (for Priya)
  Object: Opportunities
  Filter: IsClosed = false
  Group by: BU__c, then Brand__c
  Chart: stacked bar, value = Amount

Report G: "Open Pipeline by Stage" (for Priya)
  Object: Opportunities
  Filter: IsClosed = false
  Group by: Golden_Stage__c
  Chart: funnel, value = Amount

Report H: "Top Projects by Total SPX Potential" (for Priya)
  Object: Projects (Project__c)
  Filter: Strategic_Project__c = true
  Sort: Total_SPX_Potential__c descending, row limit 6
  Chart: bar, value = Total_SPX_Potential__c

Report I: "Top Opportunities — All Brands" (for Priya)
  Object: Opportunities
  Filter: IsClosed = false
  Sort: Amount descending, row limit 6
  Chart: bar, value = Amount

4b. Brand Sales Leader home page: "HVAC Home – Brand Sales Leader"
MANUAL STEP: Lightning App Builder → New Home Page

Components:
  Column 1: "Pipeline by Owner" (Report Chart, Report D)
  Column 2: "Opportunities" (Report Chart, Report E)
  Full width: Today's Tasks

Assign to: SPX Brand Sales Leader profile, HVAC Segment app.
Tell me when done.

4c. Segment Sales Leader home page: "HVAC Home – Segment"
MANUAL STEP: Lightning App Builder → New Home Page

Components (two columns):
  Column 1: "Open Pipeline by BU" (Report Chart, Report F)
  Column 2: "Open Pipeline by Stage" (Report Chart, Report G)
  Column 1: "Projects" (Report Chart, Report H)
  Column 2: "Opportunities" (Report Chart, Report I)

Assign to: SPX Segment Sales Leader profile, HVAC Segment app.
Tell me when done.

4d. Opportunity record page (Dynamic Forms)
The Opportunity page needs Dynamic Form visibility for the Chicago Fan 
fan selection section (pre-built for Step 6, invisible until activation).

MANUAL STEP: Lightning App Builder → Opportunity page.

Create or update the Opportunity Golden Template page:
  Standard sections: all standard Opportunity fields
  "Project" section: Project__c lookup, BOD_Status__c, Rep_Conflict__c
  "Brand & Territory" section: Brand__c, BU__c, Territory__c, Rep_Firm__c
  Products related list (labelled "Opportunity Products")
  Quotes related list

  "Chicago Fan Details" section:
    Fields: Fan_Arrangement__c, Wheel_Type__c
    Visibility rule: Brand__c = "Chicago Fan"
    This section is INVISIBLE to all users until Chicago Fan is activated.

Save as "Opportunity – Golden Template" and set as App Default for HVAC Segment.

Also save a copy as "Opportunity – Golden Template v2" but do NOT activate it 
as App Default. This version is activated live in Step 6.
The difference between v1 and v2 can be minimal (e.g., a label change or 
component addition) — the purpose is to demonstrate the page swap live.

For the Cooling Legacy record type, keep the existing/standard page layout.
Name it "Opportunity – Cooling Legacy" and assign to Cooling – Legacy record type.

Tell me when all three pages are saved and assigned correctly.

---

SESSION 4 VERIFICATION

  sf data query --query "SELECT Name FROM Report WHERE FolderName = 'HVAC Segment'"
  Expected: at least 9 reports (A through I)

MANUAL CHECKS (you verify in the browser):
  1. Log in as dreyes (Dana, RSM) → HVAC Segment app → Home
     Expected: HVAC Home – RSM with 4 components
  2. Log in as mhill (Marcus, Brand Leader) → Home
     Expected: HVAC Home – Brand Sales Leader with 3 components
  3. Log in as pnataraj (Priya, Segment) → Home
     Expected: HVAC Home – Segment with 4 components
  4. Open Project P-00977 (Lakemont East Tower)
     Expected: Path, Highlights panel with all 7 fields, Opportunities related list
  5. Open Account A-ARD (Ardent Builders — global)
     Expected: Unified Customer View with 4 related lists

Tell me the result of each check.

Now paste the End-of-Session Request.
```

---
---

# SESSION 5
## Scenarios 5 & 6: Quotes + Chicago Fan Inactive Build
## Estimated time: 3–4 hours

### PASTE ORDER:
1. Context setter
2. [Paste Session 4 handoff summary here]
3. Session 5 instruction (below)

---

```
SESSION 5 INSTRUCTION: Scenario 5 (quotes) and Scenario 6 (Chicago Fan)

This is Session 5 of 6. UI and pages are built. This session configures 
native quoting and builds all Chicago Fan components in their pre-demo 
inactive state.

Reference: Handover Pack Section 6 (Scenario 5), Section 7 (Scenario 6), 
Steps_5_and_6_Build_Notes.md.

---

STEP 1 — SCENARIO 5: QUOTES AND PRICE CAPTURE

Reference: Handover Pack Section 6, Steps_5_and_6_Build_Notes.md Step 5.

1a. Org settings (MANUAL STEPS)
  - Setup → Quote Settings → Enable Quotes (if not already done in Session 1)
  - Tell me when confirmed.

1b. Products
Create these products in the standard Product object:

  Product 1:
    Name: Custom air handling unit, double wall
    Product Code: AHU-DW
    Product Family: Air handling
    Active: true
    Description: Double-wall custom AHU

  Product 2:
    Name: Custom air handling unit, 100% outside air
    Product Code: AHU-OA
    Product Family: Air handling
    Active: true

  Product 3:
    Name: Modular air handling unit
    Product Code: AHU-MOD
    Product Family: Air handling
    Active: true

  Product 4:
    Name: Jobsite assembled air handling unit
    Product Code: AHU-JSA
    Product Family: Air handling
    Active: true

  Product 5:
    Name: Factory startup and commissioning
    Product Code: SVC-START
    Product Family: Services
    Active: true

  Product 6:
    Name: Freight and rigging
    Product Code: SVC-FREIGHT
    Product Family: Services
    Active: true

Verify:
  sf data query --query "SELECT Name, ProductCode, Family FROM Product2 WHERE IsActive = true"

1c. Price books
Create one price book per brand per currency (USD, CAD, EUR).
Active brands: Cooling, Ingénia, TAMCO, Patterson-Kelley.
Chicago Fan: create price book "Chicago Fan 2026 List (USD)" as INACTIVE.

Price book naming convention: "[Brand] 2026 List ([Currency])"
Examples:
  "Ingénia 2026 List (USD)"
  "Ingénia 2026 List (CAD)"
  "Ingénia 2026 List (EUR)"
  "Cooling 2026 List (USD)"
  ... etc.

Add all 6 products to the Ingénia 2026 List (USD) price book with these prices
(from Steps_5_and_6_Build_Notes.md):
  AHU-DW:       $450,000 per unit (List)
  AHU-OA:       $450,000 per unit (List)
  AHU-MOD:      $280,000 per unit (List)
  AHU-JSA:      $410,000 per unit (List)
  SVC-START:     $12,500 per unit (List)
  SVC-FREIGHT:   $35,000 per unit (List)

Add the same products to all other brand price books with the same 
list prices (these are estimates — SPX will confirm actual prices).

IMPORTANT: The demo uses Sales Price on Quote Line Items, NOT List Price.
The list prices above seed the price books. Sales Price is shown 
pre-staged and not edited live (it matches the list price for the demo).

Verify:
  sf data query --query "SELECT Name, IsActive FROM Pricebook2 ORDER BY Name"
  Expected: Chicago Fan price book shows IsActive = false

1d. Quote layout configuration (MANUAL STEPS)
In Setup → Object Manager → Opportunity → Page Layouts:
  Add to the Opportunity Golden Template layout:
    - Related list: Opportunity Products (label: "Opportunity Products")
    - Related list: Quotes

In Setup → Object Manager → Quote → Page Layouts:
  Add to the Quote layout:
    - Related list: Quote Line Items
    - Remove field: Line Description (from Quote Line Item edit screen)
  Do NOT add: Create PDF button, Discount field, Approval process

Tell me when both layouts are updated.

1e. Pre-stage Step 5 demo data
Verify the target Opportunity for Step 5 is in the correct state:
  sf data query --query "SELECT Name, Amount, Brand__c, Owner.Alias 
                          FROM Opportunity 
                          WHERE Name LIKE '%Lakemont%' AND Brand__c = 'Ingénia' 
                          AND Owner.Alias = 'dreyes'"

Expected: O-ET-ING should show Amount = $3,350,000, no products, no quotes.
If quotes or products exist on this Opportunity from previous testing, 
delete them now:
  - Stop Sync if active
  - Delete quotes
  - Delete opportunity products
  - Manually set Amount back to $3,350,000

Verify Amount is $3,350,000 and no products or quotes exist:
  sf data query --query "SELECT COUNT() FROM OpportunityLineItem 
                          WHERE OpportunityId IN 
                          (SELECT Id FROM Opportunity WHERE Name LIKE '%ET%ING%')"
  Expected: 0

---

STEP 2 — SCENARIO 6: CHICAGO FAN — BUILD ALL INACTIVE COMPONENTS

Reference: Handover Pack Section 7, Steps_5_and_6_Build_Notes.md Step 6.

This is the most important build step. Everything here must be pre-built 
and left in an inactive state. The presenter activates them live during 
the demo in a specific order. Do not activate anything here.

After building each item, confirm its inactive state before moving on.

COMPONENT 1 — Brand value "Chicago Fan" (ALREADY DONE in Session 1)
Verify it is still inactive:
  MANUAL CHECK: Setup → Picklist Value Sets → Brand__c → confirm 
  "Chicago Fan" shows as Inactive.

COMPONENT 2 — Lightning record page "Opportunity – Golden Template v2"
MANUAL STEP: Lightning App Builder → Opportunity.
  Open "Opportunity – Golden Template" (the active page from Session 4).
  Clone it → name the clone "Opportunity – Golden Template v2"
  API name: Opportunity_Golden_Template_v2
  Make a minor visible difference (e.g., add a Rich Text component with 
  "Chicago Fan onboarding active — [date]" in a collapsible section)
  Save but do NOT set as App Default.
  The current App Default remains "Opportunity – Golden Template".

Verify:
  MANUAL CHECK: App Builder → Opportunity pages list. 
  "Opportunity – Golden Template" = App Default for HVAC Segment. 
  "Opportunity – Golden Template v2" = exists but not activated.

COMPONENT 3 — Brand Configuration record "Cincinnati_Fan"
Already created in Session 1 with Live__c = false.
Verify:
  sf data query --query "SELECT Label, Live__c FROM Brand_Configuration__mdt 
                          WHERE Label = 'Cincinnati_Fan'"
  Expected: Live__c = false

COMPONENT 4 — Flow "SPX Opportunity participation" version 4
Already built in Session 2 as inactive.
Verify:
  sf data query --query "SELECT VersionNumber, Status FROM FlowVersionView 
                          WHERE ApiName = 'SPX_Opportunity_participation' 
                          ORDER BY VersionNumber"
  Expected: v3 = Active, v4 = Inactive

COMPONENT 5 — Validation rule "CF_Fan_Selection_Before_Spec"
Create this validation rule on Opportunity:

  Rule Name: CF_Fan_Selection_Before_Spec
  Active: FALSE (build it but leave inactive)
  Error condition formula:
    AND(
      NOT($Permission.SPX_Bypass_Validation_Rules),
      ISPICKVAL(Brand__c, "Chicago Fan"),
      OR(
        ISPICKVAL(StageName, "3.0 Spec and Influence"),
        ISPICKVAL(StageName, "4.0 Solution and Proposal"),
        ISPICKVAL(StageName, "5.0 Negotiate and Close")
      ),
      OR(
        ISBLANK(TEXT(Fan_Arrangement__c)),
        ISBLANK(TEXT(Wheel_Type__c))
      )
    )
  Error message: "Fan arrangement and wheel type are required before 
                  moving to Spec and Influence or later for Chicago Fan."
  Error location: Top of page

ALSO: Apply this pattern to ALL existing SPX validation rules 
(add NOT($Permission.SPX_Bypass_Validation_Rules) as the first AND condition):
  - Check if any other validation rules exist on Opportunity or Project__c
  - For each one: edit to add the bypass permission check as the first condition
  - This enables the Migration User to bypass them during data loads

Verify the new rule is INACTIVE:
  sf data query --query "SELECT ValidationName, Active FROM ValidationRule 
                          WHERE EntityDefinition.QualifiedApiName = 'Opportunity'"
  Expected: CF_Fan_Selection_Before_Spec = Active: false

COMPONENT 6 — Permission set assignment SPX Chicago Fan → Kim Alvarez
DO NOT ASSIGN. This is done live in the demo.
Verify the permission set exists but Kim has no CF assignment:
  sf data query --query "SELECT Assignee.Alias, PermissionSet.Name 
                          FROM PermissionSetAssignment 
                          WHERE PermissionSet.Name = 'SPX_Cincinnati_Fan'"
  Expected: 0 rows (no one has it yet)

ADDITIONAL PRE-BUILT COMPONENTS (also inactive / unassigned):

Chicago Fan Account Source value: already inactive (set in Session 1)

Chicago Fan price book "Chicago Fan 2026 List (USD)": 
  already inactive (set in Step 1c above). Verify it is inactive.

Chicago Fan roles (CF_Brand_Sales_Leader, CF_RSM):
  Verify Kim Alvarez (kalvarez) is in the CF_RSM role:
  sf data query --query "SELECT Alias, UserRole.Name FROM User 
                          WHERE Alias = 'kalvarez'"
  Expected: Role = Chicago Fan Rep (RSM) — set in Session 1 Step 8.

Sharing rule CF_Participating_Projects: 
  Verify it exists (built in Session 1 Step 10).
  This rule has no effect until CF_Participating__c is set on a Project, 
  which can only happen when the brand is live and opportunities exist.

---

STEP 3 — STEP 6 ACTIVATION SEQUENCE VERIFICATION

Before declaring Session 5 complete, verify the EXACT activation 
order is possible and all components are in the correct pre-demo state.

Run through each activation step mentally and confirm the component state:

| # | Component | Expected State | Verified? |
|---|-----------|---------------|-----------|
| 1 | Brand value "Chicago Fan" | Inactive | |
| 2 | "Opportunity – Golden Template v2" page | Exists, not App Default | |
| 3 | Brand_Configuration__mdt Cincinnati_Fan | Live__c = false | |
| 4 | SPX Opportunity participation v4 | Inactive (v3 is active) | |
| 5 | CF_Fan_Selection_Before_Spec | Inactive | |
| 6 | SPX Chicago Fan → Kim Alvarez | Not assigned | |

For each row: run the verification query or manual check and fill in 
the Verified column. Do not proceed until all 6 are confirmed.

Also verify that Cooling's process is still working:
  sf data query --query "SELECT Name, StageName, RecordType.Name 
                          FROM Opportunity 
                          WHERE Owner.Alias = 'tbrennan' 
                          ORDER BY StageName"
  Expected: O-ND-COOL shows RecordType = "Cooling – Legacy", 
            Stage = "Quote" (Cooling Legacy stage)

---

SESSION 5 VERIFICATION

  sf data query --query "SELECT COUNT() FROM Product2 WHERE IsActive = true"
  Expected: 6

  sf data query --query "SELECT Name, IsActive FROM Pricebook2 ORDER BY Name"
  Expected: Chicago Fan price book = IsActive false; all others = true

  sf data query --query "SELECT Amount FROM Opportunity WHERE Name LIKE '%ET%ING%'"
  Expected: $3,350,000, no products

  sf data query --query "SELECT ValidationName, Active FROM ValidationRule 
                          WHERE EntityDefinition.QualifiedApiName = 'Opportunity'"
  Expected: CF_Fan_Selection_Before_Spec = false

MANUAL CHECK: In the browser as dreyes (Dana), open the Lakemont Ingénia 
Opportunity. Confirm:
  - No products listed
  - No quotes listed
  - Amount = $3,350,000
  - Chicago Fan Details section is NOT visible

Tell me the results of all checks.

Now paste the End-of-Session Request.
```

---
---

# SESSION 6
## Scenario 7: Dashboard + Full Regression + Demo Rehearsal
## Estimated time: 2–3 hours

### PASTE ORDER:
1. Context setter
2. [Paste Session 5 handoff summary here]
3. Session 6 instruction (below)

---

```
SESSION 6 INSTRUCTION: Scenario 7, full regression, and demo-day preparation

This is Session 6 of 6 — the final session. This session builds the 
segment dashboard, runs the full regression checklist, verifies all 
reset procedures, and produces the demo-day run sheet.

Reference: Handover Pack Section 8 (Scenario 7), Section 11 (Rehearsal Checklist).

---

STEP 1 — SCENARIO 7: SEGMENT DASHBOARD

Reference: Handover Pack Section 8.

1a. Source reports for the dashboard
Create these reports and save to the "HVAC Segment" folder.

Report J: "Segment Open Pipeline" (metric)
  Object: Opportunities
  Filter: IsClosed = false
  Aggregate: SUM(Amount)
  Use as: Metric component — "Open pipeline"

Report K: "Strategic Projects Count" (metric)
  Object: Project__c
  Filter: Strategic_Project__c = true
  Aggregate: COUNT
  Use as: Metric component — "Strategic projects"

Report L: "BOD Spec Rate"
  Object: Opportunities
  Filter: IsClosed = false, BOD_Status__c != "Not yet"
  Summary formula: 
    Count where BOD_Status__c = "Secured" / Total count
    (Create a custom summary formula: 
     PARENTGROUPVAL(COUNT, GRAND_SUMMARY) to calculate the rate)
  Use as: Metric component — "BOD / spec rate"

Report M: "Strategic Attachment Rate"
  Object: Project__c
  Filter: Strategic_Project__c = true
  Summary: Avg(Brands_Engaged__c)
  Use as: Metric — "Strategic attachment"

Report N: "Pipeline by BU and Brand" (stacked bar)
  Object: Opportunities
  Filter: IsClosed = false
  Group by: BU__c, then Brand__c
  Aggregate: SUM(Amount)
  Chart: Stacked bar

Report O: "Pipeline by Golden Stage" (funnel)
  Object: Opportunities
  Filter: IsClosed = false
  Group by: Golden_Stage__c (the formula field — NOT StageName)
  Aggregate: SUM(Amount)
  Chart: Funnel

Report P: "Projects by Phase" (bar)
  Object: Project__c
  Filter: Strategic_Project__c = true
  Group by: Project_Phase__c
  Aggregate: COUNT
  Chart: Bar

Report Q: "Strategic Attachment by Vertical" (bar)
  Object: Project__c
  Filter: Strategic_Project__c = true
  Group by: Vertical__c
  Summary formula: Avg(Brands_Engaged__c) per vertical
  Chart: Bar

Report R: "Projects Lightning Table" (table for dashboard)
  Object: Opportunities (with Project__c lookup fields)
  Filter: IsClosed = false, Project__c IS NOT NULL
  Columns: Project__r.Name (label "Project"), 
           Project__r.Project_Phase__c (label "Project Phase"),
           Brand__c, StageName, Amount
  Sort: Amount descending
  Row limit: 10

After creating all reports, verify:
  sf data query --query "SELECT Name FROM Report 
                          WHERE FolderName = 'HVAC Segment' 
                          ORDER BY Name"
  Expected: at least 18 reports (A through R)

1b. Build the dashboard "HVAC segment"
MANUAL STEP: Navigate to Dashboards → New Dashboard.
Name: HVAC segment
Folder: HVAC Segment

Add components in this layout (Reference: Handover Pack Section 8):

Row 1 — Metrics (4 across):
  "Open pipeline"          → Report J, Metric component
  "Strategic projects"     → Report K, Metric component
  "BOD / spec rate"        → Report L, Metric component
  "Strategic attachment"   → Report M, Metric component
  Add footer text explaining each metric definition.

Row 2 — Charts (2 across):
  "Pipeline by BU and brand"  → Report N, Stacked bar
  "Brand opportunity stage"   → Report O, Funnel
  (Title this funnel exactly "Brand opportunity stage")

Row 3 — Charts (2 across):
  "Projects by phase"                → Report P, Bar
  "Strategic attachment by vertical" → Report Q, Bar

Row 4 — Table (full width):
  "Projects"  → Report R, Lightning Table

Add exactly 3 dashboard filters:
  Filter 1: Business unit → maps to BU__c on Opportunity reports
  Filter 2: Vertical → maps to Vertical__c on Opportunity and Project reports
  Filter 3: Strategic project → maps to Strategic_Project__c on Project reports
             (Values: All, True, False)

MANUAL STEP: Set running user to Priya Natarajan (pnataraj).
  Dashboard → Edit → Properties → Running User → pnataraj

Tell me when the dashboard is saved.

1c. Dashboard subscription
MANUAL STEP: Open the HVAC segment dashboard as pnataraj.
  Subscribe → Weekly, Monday morning → Save.
Tell me when the subscription is set.

1d. Drill-through verification
MANUAL CHECK: Open the dashboard. Click on any bar in the 
"Pipeline by BU and brand" chart.
  Expected: opens the source report (Report N), filtered to the clicked bar.
  Expected: does NOT open a list view.
Tell me the result.

---

STEP 2 — FULL REGRESSION CHECKLIST

Run every check from Handover Pack Section 11. These are mandatory.

SECURITY CHECKS:

Check 1: dreyes (Dana) sees only own Opportunities
  MANUAL: Log in as dreyes → Opportunities → All Opportunities
  Expected: only Dana's Ingénia Opportunities (Ohio Valley territory)
  Result: ___

Check 2: mhill (Marcus) sees all Ingénia RSMs
  MANUAL: Log in as mhill → Opportunities → All Opportunities
  Expected: all opportunities owned by users in Ingénia RSM roles
  Expected: Pipeline by Owner shows 10 Ingénia RSMs with correct amounts
  Result: ___

Check 3: pnataraj (Priya) sees all brands
  MANUAL: Log in as pnataraj → Opportunities → All Opportunities
  Expected: Cooling, Ingénia, TAMCO, Patterson-Kelley all visible
  Result: ___

Check 4: tbrennan (Tom) cannot see dreyes Opportunities
  MANUAL: Log in as tbrennan → Opportunities → All Opportunities
  Expected: ONLY Cooling Opportunities — no Ingénia records
  Result: ___

Check 5: Strategic project sharing
  MANUAL: Log in as mhill → Projects tab
  Expected: can see Lakemont East Tower (P-00977, strategic, Ingénia participating)
  Expected: can see other strategic projects via the Strategic_Project__c sharing rule
  Result: ___

FLOW CHECKS:

Check 6: Project totals flow
  Query current state:
  sf data query --query "SELECT Total_SPX_Potential__c, Brands_Engaged__c, 
                          BOD_Secured__c, Rep_Conflict__c 
                          FROM Project__c WHERE Project_Code__c = 'P-00977'"
  Expected: 
    Total_SPX_Potential__c = $3,880,000 (sum of open Opps)
    Brands_Engaged__c = 3
    Rep_Conflict__c = true
  Result: ___

Check 7: Rep conflict flow
  Verify Rep_Conflict__c = true on both Patterson-Kelley Opportunities 
  on P-00977 (lduval's O-ET-PK and rkeane's O-ET-PK2):
  sf data query --query "SELECT Name, Owner.Alias, Rep_Conflict__c 
                          FROM Opportunity 
                          WHERE Project__c IN (SELECT Id FROM Project__c 
                                               WHERE Project_Code__c = 'P-00977') 
                          AND Brand__c = 'Patterson-Kelley'"
  Expected: both records show Rep_Conflict__c = true
  Result: ___

Check 8: Cooling Legacy record type
  sf data query --query "SELECT Name, RecordType.Name, StageName 
                          FROM Opportunity WHERE Name LIKE '%Bldg D%'"
  Expected: O-ND-COOL has RecordType = "Cooling – Legacy", StageName = "Quote"
  Result: ___

Check 9: Chicago Fan components are all inactive
  Run the 6-row verification table from Session 5 Step 3 again.
  All 6 rows must confirm inactive/unassigned state.
  Result: ___

Check 10: Intake records status
  sf data query --query "SELECT CC_Project_ID__c, Project_Name__c, Status__c 
                          FROM Project_Intake__c"
  Expected: all 4 rows show Status = Staged
  Result: ___

Check 11: Quote pre-stage
  sf data query --query "SELECT Name, Amount FROM Opportunity 
                          WHERE Owner.Alias = 'dreyes' 
                          AND Name LIKE '%East Tower%'"
  Expected: Amount = $3,350,000
  sf data query --query "SELECT COUNT() FROM OpportunityLineItem 
                          WHERE Opportunity.Owner.Alias = 'dreyes'"
  Expected: 0 (no products on Dana's Opportunities)
  Result: ___

Check 12: Dashboard
  MANUAL: Open HVAC segment dashboard as pnataraj
  - All 9 components load without errors
  - Metric "Open pipeline" shows a non-zero value
  - "Brand opportunity stage" funnel shows the 5 golden stages 
    (NOT "Qualify", "Design Assist" etc. — those are Cooling Legacy stages)
  - Filters work without errors
  Result: ___

Report the result of ALL 12 checks. Any FAIL means we fix before 
declaring the build complete.

---

STEP 3 — RESET PROCEDURES VERIFICATION

Test each reset procedure to confirm it works. This is essential — 
if a reset fails on demo day, the session cannot be repeated.

RESET TEST 1 — Scenario 1 (Lead from feed)
  Confirm what would need to be done after Step 1:
  - Delete: Westfield project, its leads, Rachel Tran contact, Westfield Opp
  - Set intake rows back to Staged (all 4 rows)
  Test: Manually set one intake row (CC-88412) to Staged now if it was changed.
  sf data query --query "SELECT Status__c FROM Project_Intake__c 
                          WHERE CC_Project_ID__c = 'CC-88412'"
  Expected: Staged
  Result: ___

RESET TEST 2 — Scenario 2 (ERP mapping)
  This reset requires restoring ARDENT BLDRS INC after it is merged.
  Merging in Salesforce cannot be undone — the merged account goes to Recycle Bin.
  MANUAL CHECK: Confirm you know how to restore from Recycle Bin:
    Setup → Recycle Bin → find merged record → restore
  Practice: Do NOT actually merge the account now. Just confirm you can 
  see A-ERP-4417 and the DuplicateRecordSet in the org.
  sf data query --query "SELECT COUNT() FROM DuplicateRecordSet"
  Expected: at least 1
  Result: ___

RESET TEST 3 — Scenario 5 (Quote)
  Verify the reset procedure works:
  - The quote and products on Dana's Lakemont Opportunity should not exist
  - If they do exist (from testing), stop sync, delete quote, delete products, 
    reset Amount to $3,350,000
  sf data query --query "SELECT Amount FROM Opportunity 
                          WHERE Owner.Alias = 'dreyes' AND Name LIKE '%East Tower%'"
  Expected: $3,350,000
  Result: ___

RESET TEST 4 — Scenario 6 (Chicago Fan)
  Document the exact reset steps in order (reverse of activation):
  1. Delete Kim's Chicago Fan opportunity (if created during testing — 
     confirm none exists now)
  2. Remove SPX Chicago Fan permission set from Kim (confirm not assigned)
  3. Deactivate CF_Fan_Selection_Before_Spec (confirm already inactive)
  4. Reactivate SPX Opportunity participation v3 / deactivate v4 
     (confirm v3 active, v4 inactive)
  5. Set Brand_Configuration__mdt Cincinnati_Fan Live__c = false 
     (confirm already false)
  6. Set App Default back to "Opportunity – Golden Template" 
     (confirm already set)
  7. Deactivate Brand value "Chicago Fan" (confirm already inactive)

  Verify all 7 reset steps are in their correct pre-demo state:
  sf data query --query "SELECT Label, Live__c FROM Brand_Configuration__mdt 
                          WHERE Label = 'Cincinnati_Fan'"
  Expected: Live__c = false
  Result: ___

---

STEP 4 — MORNING-OF CHECKLIST (document only — do not run now)

Generate a morning-of checklist I can run on demo day, 2 hours before the session.

The checklist should cover:
1. Set all 4 intake rows to Status = Received 
   (so the feed results are pre-staged for Scenario 1)
   Command: [provide the exact sf data update command]

2. Refresh the HVAC segment dashboard as pnataraj
   (MANUAL: open dashboard → Refresh button)

3. Log in to all presenter personas and confirm pages load:
   dreyes (Step 1, 4, 5), mhill (Step 4), pnataraj (Steps 2, 3, 4, 5, 7), 
   sokafor (Steps 1, 2, 6), tbrennan (Step 6 Cooling regression), 
   kalvarez (Step 6 Chicago Fan)
   (MANUAL: open each in a separate browser profile)

4. Verify Lakemont Ingénia Opportunity amount = $3,350,000, no products, no quotes
   Command: [provide the exact sf data query command]

5. Verify all 4 intake rows are now Received (if step 1 was run successfully)
   Command: [provide the exact sf data query command]

6. Open the Strategic Projects list view — confirm Lakemont East Tower shows 
   Rep_Conflict__c = true, Brands_Engaged = 3, BOD_Secured = "1 of 3"
   (MANUAL: open as pnataraj)

7. Confirm Chicago Fan is still inactive (brand value, metadata record)
   Command: [provide the exact sf data query command]

Produce this as a numbered checklist with the sf commands filled in. 
I will save this and use it on demo day.

---

STEP 5 — DEMO DAY PERSONA QUICK REFERENCE

Produce a one-page quick reference card with:
- Each persona's name, alias, role, and what they can see
- Which demo steps they are used in
- The login URL format for the SDO org
- The 6-step Chicago Fan activation sequence with exact Setup paths
- The Step 5 reset steps (stop sync, delete quote, delete products, set $3.35M)
- The Step 2 reset steps (restore ARDENT BLDRS INC from Recycle Bin)

Format this as plain text so I can print it.

---

SESSION 6 FINAL VERIFICATION

When all regression checks pass and reset procedures are confirmed, 
run this final summary:

  sf data query --query "SELECT COUNT() FROM User WHERE IsActive = true"
  sf data query --query "SELECT COUNT() FROM Account"
  sf data query --query "SELECT COUNT() FROM Project__c"
  sf data query --query "SELECT COUNT() FROM Opportunity WHERE IsClosed = false"
  sf data query --query "SELECT COUNT() FROM Project_Intake__c"
  sf data query --query "SELECT COUNT() FROM Product2 WHERE IsActive = true"
  sf data query --query "SELECT COUNT() FROM Report"
  sf data query --query "SELECT COUNT() FROM Dashboard"

Report all counts. Then declare one of:
  READY FOR DEMO — all 12 regression checks passed, all resets verified
  NOT READY — list which checks failed and what remains

Now paste the End-of-Session Request for the final handoff summary.
```

---

# QUICK REFERENCE: SESSION ORDER AND DEPENDENCIES

```
SESSION 1  →  Org settings, objects, metadata, security, roles, app
    ↓
SESSION 2  →  All 6 flows (depends on Session 1 objects existing)
    ↓
SESSION 3  →  Data load (depends on Session 1 objects + Session 2 flows)
    ↓
SESSION 4  →  Pages, home pages, reports for Scenarios 1–4
              (depends on Session 3 data for reports to show values)
    ↓
SESSION 5  →  Quotes + Chicago Fan inactive build
              (depends on Session 1 permission sets + Session 3 Opps)
    ↓
SESSION 6  →  Dashboard + full regression + reset verification
              (depends on all previous sessions being complete)
```

---

# WHAT TO DO IF SOMETHING GOES WRONG

**A flow is firing unexpectedly during data loads**
→ Assign SPX_Migration_Bypass to your admin user temporarily, 
  run the load, then remove the permission set.

**A sharing recalculation is taking too long**
→ Run it during off-hours. In the meantime, use Manual Share 
  to give specific users access for testing.

**A component in Session 5 can't be left inactive via CLI**
→ MANUAL: activate it, screenshot it, then deactivate. 
  The screenshot proves it was built correctly.

**Session context is getting long and Claude Code seems confused**
→ Say: "Stop. Summarise what has been done in this session so far, 
  then wait for my next instruction." Start a fresh session with 
  the updated summary.

**A regression check fails on demo day morning**
→ Do not try to fix it. Note the failure, prepare a verbal 
  talking point ("In a full implementation we would also configure X"), 
  and skip that specific sub-step in the demo.
```

