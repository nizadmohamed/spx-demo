# SPX HVAC CRM demo: oral exam prep guide

Purpose: explain every functionality, how it is built, and why, then practise the questions you are likely to be asked.
Sources: `SPX_Developer_Handover_Pack.md`, `SPX_Session_Resume_Context.md`, `SPX_NBA_Agent_Design.md`, `SPX_Agentforce_Build_Sheet.md`, and the metadata in `force-app/main/default`.
State as of 2026-11-06. Org: Salesforce SDO sandbox, alias `spx-demo`, API 67.0.

How to use it: read section 1 (the story), learn sections 2 to 4 (model, security, automation), then the feature sections 5 to 13, then drill section 15 (Q&A) out loud. Section 14 lists what is NOT tested or not done: say so openly rather than bluff.

---

## 1. The 60-second story

**Client:** SPX Technologies, HVAC segment. Several brands (Ingenia, Patterson-Kelley, Cooling, TAMCO, plus Marley and Strobic added later, and Chicago Fan held back for the onboarding scenario). They sell into construction **projects**. Today each brand sees the same project separately, so there are duplicate pursuits, no single customer view, and no segment-level reporting.

**What we built:** one Salesforce org where the **Project** is the anchor. A construction-feed record (ConstructConnect) becomes a Project plus one Lead per eligible brand. Leads convert to Opportunities on a shared "golden" sales process. Flows roll brand opportunities up to the project (total potential, brands engaged, BOD secured, rep conflict). Role hierarchy and sharing give each persona the right view. ERP customers are matched to global accounts with duplicate management. Dashboards answer segment questions. Agentforce adds a lead summary, feed review and Next Best Action recommendations.

**Design principle:** configuration first. No code except two demo-only exceptions: the CSV **Data Load** tab (LWC + Apex) and the **Next Best Action** service (Apex, because flows cannot read file bodies or call a prompt template with JSON parsing cleanly). Be ready to defend that exception (see Q&A).

**The seven demo scenarios (the "click-through"):**

| # | Scenario | One-line answer |
|---|---|---|
| 1 | Lead from feed | Project Intake record triggers flow that matches/creates Project, creates a Lead per eligible brand, routes owner, notifies if strategic |
| 2 | ERP mapping and Unified Customer View | Duplicate and matching rules link ERP customers to global accounts; Account page shows all brands |
| 3 | One project, all brands | Flows maintain project totals and rep-conflict flag; standard Opportunities related list |
| 4 | Role-based visibility | Three profiles, three home pages, role hierarchy and sharing |
| 5 | Quote and price capture | Native Quotes with sync; pricebook set by flow |
| 6 | Onboard a new brand live | Pre-built inactive components, bypass custom permissions, bulk migration |
| 7 | Segment dashboard | Report-based Lightning dashboard with three filters and drill-down |

Later additions (post-build): Global Parent account page, Project Intelligence, Next Best Actions, New Lead from Project, CSV Data Load tab, SPX Executive dashboard, Agentforce agents.

---

## 2. Data model

### 2.1 Custom objects (8)

| Object | Purpose | Key facts |
|---|---|---|
| `Project__c` | The construction project; the anchor | Sharing now **Public Read/Write internal**, external Private (was Private; changed 2026-11-05). Ext IDs `CC_Project_ID__c`, `Project_Code__c`; auto-number `Project_Reference__c` (P-{00000}). Fields: Vertical, Phase, Estimated Construction Value, `Strategic_Project__c`, flow-maintained `Total_SPX_Potential__c`, `Brands_Engaged__c`, `BOD_Secured__c`, `Rep_Conflict__c`, one Participating checkbox per brand |
| `Project_Relationship__c` | Stakeholder junction Project to Account | **Master-detail** to Project (so it follows Project sharing). Relationship Type, Status (Confirmed/Pending), brand-relationship text copies |
| `Project_Intelligence__c` | Insights, risks, channel conflicts on a project | **Private** OWD. `Share_with_Project__c` checkbox opens it to the project team through 7 sharing rules. Type picklist is dependent on Insight Type |
| `Opportunity_Competitor__c` | Competitors on a project or opportunity | Opportunity lookup is **optional** (was master-detail); validation rule requires Project or Opportunity. Multi-select Brand, formula `Brands_Text__c` |
| `Next_Best_Action__c` | Recommended actions on a project | Public R/W. Status Suggested/Not Started/In Progress/Complete/Dismissed, Priority, Rationale, Evidence, Source (Agent/Manual), Run_Id, formula `Owner_Name__c` |
| `Brand_Relationship__c` | Brand to Account relationship | Master-detail to Account. Open Pipeline, Brand Owner, ERP References text, Global Parent |
| `ERP_Cross_Reference__c` | ERP customer record linked to an Account | ERP key external ID; ERP fields read-only except for ERP Integration permission |
| `QTC_Message_Log__c` | Stand-in for outbound messages to QTC (Boomi) | Logged when an opportunity of a QTC-sending brand is saved |

### 2.2 Standard objects used
Account (hierarchy, Global Parent flag, roll-ups, Account Number as match key), Contact, Lead (Project, Brand, BOD Status, routing fields), Opportunity (Project lookup, Brand, Golden Stage formula, BOD Status, Rep Conflict, Strategic text), Quote, Product, Pricebook.

### 2.3 Custom metadata types (configuration as data)
- `Brand_Configuration__mdt`: BU, Brand value, Target Verticals, Routing Threshold, **Strategic_Threshold__c**, Sends to QTC, Live, Default currency, Brand Leader alias. **Every flow reads it.** A new brand is a new record, not new code.
- `Routing_Rule__mdt`: Brand + State/Territory to owner alias (for example `Marley_NC` to srsm).
- `Potential_Factor__mdt`: brand, vertical, factors; calculates recommended potential.
- `Opportunity_Task_Template__mdt`: 35 rows driving automatic opportunity tasks.

**Why custom metadata:** deployable, readable in flows and Apex without queries counting against limits, editable without code. Same logic as "brand is data".

### 2.4 Key design choices to explain
- **Opportunity to Project is a lookup, not master-detail.** So no roll-up summary fields; flows do the roll-up instead.
- **Why a junction (Project Relationship)** rather than lookups on Project: many accounts per project in different roles (Owner, GC, Engineer, Architect, Rep firm), and an account appears on many projects.
- **Brand is a picklist value set (global)** so Lead, Opportunity and Competitor share one list. Inactive values hold future brands.
- **Strategic project:** checkbox on Project set by flow when estimated value exceeds the brand's threshold (default 100,000,000). A text formula `Strategic_Project_Text__c` (Yes/No) exists only because dashboards filter badly on checkboxes.

---

## 3. Security model

### 3.1 Org-wide defaults (current)
| Object | OWD |
|---|---|
| Account, Contact | Public Read Only |
| Lead, Opportunity | Private |
| Project | **Public Read/Write** internal, Private external |
| Project Intelligence | Private |
| Project Relationship | Controlled by Parent |
| Opportunity Competitor, Next Best Action | Public Read/Write |

Say why Project changed: Erica AccManager (segment lead) could not create a lead on a project she did not own. Existing Project sharing rules are now redundant but harmless. The earlier design said "Project Private"; the reason it moved is a legitimate answer if challenged.

### 3.2 Role hierarchy
Segment Sales Leader at top; under it one **Brand Sales Leader** role per brand (Ingenia, Cooling, PK, TAMCO, Marley, Strobic, Chicago Fan), each with **RSM** (rep) roles beneath. Segment Support and CRM Owner sit outside the line. Result: a rep sees their own records, a brand leader sees all reps below, the segment leader sees everything.

### 3.3 Sharing rules
- "Brand Participating = true" shares the Project to that brand's leader role and subordinates (no code; flows maintain the checkbox).
- "Strategic = true" shares to all brand leader roles.
- `Segment_Sales_Leader_Edit_All_Projects`: Edit for Segment Sales Leader role.
- Seven Project Intelligence rules keyed on `Share_with_Project__c`.

### 3.4 Profiles and permission sets
- Profiles: SPX RSM, SPX Brand Sales Leader, SPX Segment Sales Leader, SPX Integration (plus Admin).
- Permission sets: `Golden_Template_User`, `Ingenia_User`, `Segment_Visibility`, `Segment_Support`, `ERP_Integration`, `SPX_Agentforce_User`, `SPX_Next_Best_Action_Segment_Lead`, `SPX_Project_Intelligence_Segment_Lead`, `SPX_Strobic_Key_Information`, `SPX_Data_Load`, `SPX_Migration_Bypass`, `SPX_Cincinnati_Fan` (label Chicago Fan).
- **Pattern:** profiles hold the baseline, permission sets add per-brand or per-feature access. Fields created by metadata are not auto-granted, so FLS must be deployed explicitly.
- **Flow User checkbox** (`UserPermissionsInteractionUser`) is per user and required to see Flow quick actions on a record page. Set on 21 users; new SPX users need it too.

### 3.5 Custom permissions (feature switches)
- `SPX_Bypass_Validation_Rules`, `SPX_Bypass_Automation`: used in validation rules and flow entry conditions; only the Migration User holds them.
- `ERP_Integration`: lets integrations edit ERP fields (validation rule uses `$Permission`).
- `SPX_Strobic_Key_Information`: now only a field-level control through its permission set.

### 3.6 Field-level and record-level, how they differ (be ready to explain)
- Record access = OWD + role hierarchy + sharing rules + ownership + manual/team.
- Object and field access = profile + permission sets.
- Example: Strobic fields visible only to Tony because only his permission set grants them.
- Flows run in **system mode without sharing** here, so they can update Project fields for users who cannot see all opportunities. The Apex NBA service is `with sharing` and reads the Strobic fields only if the user can see them.

---

## 4. Automation inventory (34 flows)

### 4.1 Lead intake and creation
- **`SPX_Lead_intake`** (record-triggered, Lead). Fires when Status = New and Source = ConstructConnect, or Source = **Rep Entered with a Project**. Steps: match or create the Project (Project ID, then normalized name and postal key), set Strategic per brand threshold, check brand eligibility (Target Verticals, Routing Threshold, Earliest Routing Phase), skip brands already in pursuit (open opportunity), set owner from Routing Rule, set potential from Potential Factor, set Match Result (Routed, Held, Already in pursuit), notify brand leaders if strategic. A Rep Entered lead with a preset project skips matching.
- **`SPX_New_Lead_From_Project`** (screen flow, "New Lead" quick action on Project). Screen 1: Brand, Est. Brand Potential, BOD Status. Screen 2: Company (optional, blank becomes "First Last"), Title, name, phone, email. Creates Lead Status New, Source Rep Entered, copies project fields; then intake routes it.
- **`SPX_Lead_Convert_Origination`, `SPX_Lead_converted_amount`**: carry project, brand, vertical and amount onto the converted Opportunity.

### 4.2 Project roll-ups and conflict
- **`SPX_Project_totals` (+ Delete)**: after save on Opportunity. Gets opportunities on the project not Closed Lost, loops to sum Amount, collect distinct brands, count brands with BOD Secured, updates Project (Total, Brands Engaged, "x of y" BOD).
- **`SPX_Rep_conflict_check` (+ Delete)**: compares owners **within the same brand** on a project; flags opportunities and Project `Rep_Conflict__c`. Cross-brand comparison would always flag.
- **`SPX_Opportunity_Participation`**: sets each brand's Participating checkbox on the Project (drives sharing rules). Active version has Marley and Strobic but **not** Chicago Fan; the Chicago Fan branch is added at Step 6 (old version saved in `docs/scripts`).
- **`SPX_Price_book_flow`**: before-save, sets Pricebook2Id from Brand Configuration and currency.
- **`SPX_Opportunity_Tasks`**: on create and stage change, reads `Opportunity_Task_Template__mdt` and creates tasks (due days after, assigned to owner, brand leader, or named user). Untested by the user; a Priority fix was applied.

### 4.3 Account and Global Parent
- **`SPX_ERP_cross_reference_flow`**: when an ERP reference is set, creates/reuses Brand Relationship on the global ultimate account.
- **`SPX_Account_Hierarchy_Before/After/Delete`, `SPX_Set_Global_Parent_*` (4)**: maintain `Is_Global_Parent__c` and the Global Parent lookup on child records.
- **`SPX_Rollups_*` (4), `SPX_Recalc_Global_Rollups`**: pipeline, brands active, strategic GC projects roll-ups on the parent.
- **`SPX_ERP_References_Text`**, **`SPX_Account_Brand_Relationships_To_Stakeholders`**: text copies used in related lists (pointer lookups, no copied data).

### 4.4 Project Intelligence and competitors
- **`SPX_Project_Intelligence_Defaults`**: defaults Project and Brand from the Opportunity; keeps Project when no Opportunity.
- **`SPX_Competitor_Set_Project`**: sets the Project from the Opportunity on competitors.

### 4.5 Agent and NBA flows
- `SPX_Agent_Lead_Context`, `SPX_Agent_Get_Feed_Leads`, `SPX_Agent_Notify_Brand_Leader` (never run live), `SPX_Agent_Get_Project_Name`, `SPX_Agent_Recommend_Actions`, `SPX_Recommend_Next_Actions` (screen flow).

### 4.6 Cross-cutting patterns
- **Bypass:** every SPX record-triggered flow has `NOT({!$Permission.SPX_Bypass_Automation})` in its entry condition.
- **Why flows, not Apex:** declarative, admin-maintainable, and the brief required configuration.
- **Known quirks:** saving the same stage twice recreates tasks; strategic-flag change on a Project does not trigger roll-up recalculation; migration user skips roll-ups, so a recalculation is needed post-load.

---

## 5. Scenario 1: Lead from feed (detail)

1. ConstructConnect rows land in **Project Intake** (staged as Status Staged; staging is for the demo, a real integration would insert them).
2. Release: `release_feed.ps1` moves Staged leads to New. (Never press "run feed" live.)
3. Intake flow runs per lead, as described in 4.1. Output: Project record, Match Result, owner, estimated potential, Strategic flag.
4. Strategic projects notify brand leaders (custom notification type).
5. RSM home page shows "My New Leads" report chart; rep opens the lead, converts it to an Opportunity (Golden Template record type).
6. Duplicate and matching rules on Account and Contact (alert only, never block) support conversion.

Why it works this way: one project, many brand leads, each brand sees only their lead. "Held" and "Already in pursuit" statuses show why a brand did not get a lead (for example Planning phase earlier than Schematic Design).

---

## 6. Scenario 2: ERP mapping and Unified Customer View

- **Problem:** ERP customer IDs differ per brand; the same company appears several times.
- **Solution:** standard duplicate management. Matching rules on Account: custom ERP exact match (name fuzzy + postal exact + phone exact) and the standard Account matching rule. Duplicate rules: exact match **Block** (the integration reads the matched Account ID from the error and attaches the cross-reference there: auto-link), possible match **Allow + Alert + Report** (creates Duplicate Record Sets for stewards).
- **Steward flow:** open the account, use Potential Duplicates, Merge Accounts (needs Delete on Account).
- **Integration logic (described, not built):** if cross-reference with the ERP key exists, update only it; never recreate an account for an existing ERP key.
- **Unified Customer View** (`Account_Unified_Customer_View` page): highlights, roll-ups (open pipeline, brands active, strategic GC projects), related lists for Brand Relationships, Project Relationships, ERP References, Contacts.
- **Global Parent page:** a global parent is an account with at least one child and no parent. Roll-ups are flows; related lists show pointer lookups (`Global_Parent__c`) with no copied data. Ardent Builders example: pipeline $12.6M, 4 brands, 5 strategic GC projects.

---

## 7. Scenario 3: One project, all brands

- Project record page: highlights (Vertical, Phase, Estimated Value, Total SPX Potential, Brands Engaged, BOD Secured, Rep Conflict), Path on Phase, related lists (Next Best Actions, Project Insights sorted newest first, Opportunities, Stakeholders, Leads, Competitors, History).
- Flows 4.2 maintain the numbers. List view "Strategic projects".
- **Rep conflict demo:** David RSM (formerly rkeane) opens a second Patterson-Kelley opportunity on Lakemont; the flow flags both and the project.
- Project history tracking on selected fields (phase, value, strategic flag, brand participation, totals).

---

## 8. Scenario 4: Role-based visibility

- Three profiles and three Lightning home pages assigned by app and profile: `HVAC_Home_RSM`, `HVAC_Home_Brand_Sales_Leader`, `HVAC_Home_Segment`.
- Components are **Report Charts** and Today's Tasks. Charts run as the **viewing user**, so the role hierarchy decides what each persona sees (Dana: her own; Marcus: team; Priya: everything).
- Reports: My New Leads, My Pipeline by Stage, My Top Opportunities, Team Pipeline by Owner, Team Top Opportunities, Open Pipeline by BU/Stage, Top Projects by Total SPX Potential, Top Opportunities All Brands.

---

## 9. Scenario 5: Quote and price capture

- Native Sales Cloud Quotes (no CPQ/Revenue Cloud). Products at family level, pricebooks per brand and currency (USD, CAD, EUR), multi-currency enabled.
- **Mechanics:** products on an opportunity make Amount the sum of products; New Quote copies the products; **Start Sync** replaces opportunity products with quote lines and updates Amount; only one quote syncs; Start Sync is a user action, not available to flow.
- Demo numbers: $3,350,000 estimate becomes $3,600,000 after refinement (6 units at 427,500 + outside air + startup + freight).
- No PDF, discount or approval process.

---

## 10. Scenario 6: Onboard a new brand live (Configure, Isolate, Validate, Transition)

- **Configure:** two sales processes coexist: Golden Template (1.0 to 5.0) and Cooling Legacy (Qualify, Design Assist, Quote, Negotiate). Record type Golden Template Project Sale is default for all; Cooling Legacy record type is now **deactivated** (user request 2026-11-02; its one opportunity still works).
- **Reporting bridge:** `Golden_Stage__c` formula maps legacy stages to golden stages so dashboards show one funnel.
- **Isolate:** bypass framework (section 3.5), Migration User with `SPX_Migration_Bypass`, Brand Configuration `Live` checkbox, page isolation by brand.
- **Pre-built inactive, activated live in order:** Brand value Chicago Fan; Opportunity Golden Template v2 page; Brand Configuration Cincinnati_Fan Live; flow version (participation); validation rule `CF_Fan_Selection_Before_Spec`; permission set assignment to Kim Alvarez.
- **Validate:** regression of the existing process is voiced over (save legacy and golden opportunity, check QTC message, open pages, run dashboard).
- **Transition:** Data Loader with Bulk API as Migration User (214 accounts, 38 opportunities), visible in Setup, Bulk Data Load Jobs. Then recalculate project totals because bypass skipped the flow.
- **Honest caveat:** some changes have dependencies that must be released in sequence; zero operational consideration is not promised.

---

## 11. Scenario 7 and SPX Executive dashboards

### 11.1 HVAC Segment dashboard (scenario 7)
Filters (max 3): Business Unit (text stamped by flow), Vertical, Strategic Project. Components: metrics (open pipeline, strategic projects, BOD/spec rate, strategic attachment, win rate with BOD), stacked bar by BU and brand, funnel by golden stage, bar by phase, strategic attachment by vertical, Lightning Table of projects. Clicking a chart opens the source report filtered to that value. Subscription email does not apply filters.

### 11.2 SPX Executive dashboard (for John Leader)
- Folders `SPX_Executive` (dashboard and reports), shared only with John Leader.
- Running user = viewing user (`LoggedInUser`), so numbers follow each viewer's access.
- Filters: Brand, Project Name (hard-coded list of 27 names; new projects need a redeploy), Strategic Projects (Yes/No/All).
- Components: Total SPX value, % BOD secured, Project risks, Pipeline by sales stage, BOD status donut, Project risks by project.
- **Custom report type** `Projects_with_Project_Intelligence`: base Project, join to Project Intelligence, **inner join** (`outerJoin=false`) so projects without risks drop out.
- **Two fixes worth telling as a story:**
  1. Risk report showed projects without risks, because the report type was an outer join. Fixed with inner join.
  2. Strategic filter failed for true/false because dashboards do not filter well on checkbox fields. Fixed by text formula fields (Yes/No) on Opportunity and Project and by listing them in the report type.
- Gotcha: dashboard metadata only accepts the `Project__c$Field` column form; custom report type fields must be in the report type before a dashboard filter can use them; GET on a dashboard can return cached data, refresh by PUT.

---

## 12. Agentforce

### 12.1 SPX Segment Assistant (agent, active)
- Authoring bundle `SPX_Segment_Assistant` (Agent Script). Published and activated with the CLI: edit script, `sf agent validate authoring-bundle`, `sf agent publish authoring-bundle`, `sf agent activate --version N`.
- Topics: lead summary (prompt template `SPX_Lead_Summary` calling flow `SPX_Agent_Lead_Context`), feed review (`SPX_Agent_Get_Feed_Leads`), notify brand leader (`SPX_Agent_Notify_Brand_Leader`, requires explicit user confirmation, never run live), next actions.
- Agent rules: read-only except confirmed actions; answers only from action output; no invented history.
- 20 users hold Agentforce licences and the `SPX_Agentforce_User` permission set.
- Flow and prompt-template actions use only a `target:` line, never `source:`.

### 12.2 Next Best Action (NBA)
- **Trigger:** Project quick action "Recommend Next Actions" (screen flow `SPX_Recommend_Next_Actions`) and agent topic `next_actions` (flow `SPX_Agent_Recommend_Actions`). Agent version 6 confirms by project name via `SPX_Agent_Get_Project_Name`; `RecommendActions` has built-in confirmation off because the chat question is the gate.
- **Apex:**
  - `SPX_NBA_Service` (with sharing): gathers context (project, opportunities, leads, stakeholders, competitors, insights, tasks, current NBAs), builds an "ITEMS THAT NEED AN ACTION" checklist in code, calls the prompt template, parses JSON, retries up to 3 times if fewer than 4 actions, skips duplicate open titles, cleans brand and priority values, saves as **Suggested**.
  - `SPX_NBA_ReadFiles`: reads text from txt/md/csv/json files linked to the project (5 files, 20,000 chars each); guidance file `NBA_Agent_Guidance*` returned separately. Flows cannot read file bodies, which is why this is Apex.
- **Prompt template** `SPX_NBA_Recommendations` (inputs Context, Guidance; JSON-only output). A deployed template needs `activeVersionIdentifier` equal to `versionIdentifier`.
- **Why Suggested:** a person accepts or dismisses; the agent never creates committed work.
- **Limits:** text files only (PDF would need conversion), prompt-size caps, each run 10 to 30 seconds, only as good as the data and guidance.
- **Demo data:** project DEMO NBA - Halston University Biosciences Building (CC ID DEMO-NBA-0001); delete script `data-load/demo-nba/demo_nba_delete.apex`.
- **Tests:** `SPX_NBA_ServiceTest` (7) and `SPX_NBA_ReadFilesTest` (4).

---

## 13. CSV Data Load tab (the one custom UI)

- Components: LWC `spxDataLoad`, Apex `SPX_DataLoadController` (+ Test, 12 tests), tab `SPX_Data_Load`, permission set `SPX_Data_Load`. CLI twin in `data-load/load_all.ps1`. Templates in `data-load/templates`.
- Loads Projects (upsert on CC_Project_ID__c, falls back to Project Reference), Leads, Stakeholders, Insights, Competitors, one or many objects at a time, with success and error CSV downloads.
- **Rules:**
  - Lookups written as `Rel__r.<key field>`; accounts resolve by **Account Number**, duplicate numbers reject the row.
  - Leads match existing records on CC Project ID + Brand + Market; the match **ignores converted leads** (Salesforce forbids updating them, error "cannot reference converted lead"), so those rows insert a new lead (can duplicate a worked lead; trade-off chosen by the user).
  - Existing Project on a matched lead is never overwritten.
  - Project vs Opportunity mismatch is checked only when both are given.
  - Dates ISO or US slash; plain numbers.
- **Security:** uses `Security.stripInaccessible` (silently drops fields the user cannot write) and `WITH USER_MODE` queries, so the loader honours the running user's permissions. Consequence: the Integration user needed explicit edit FLS on `Project_Intelligence__c.Project__c` (added to `SPX_Data_Load`), otherwise Insights loaded without a project. Required fields carry no FLS rows; optional custom fields need explicit FLS.
- **Integration user** `spxinteg`: permission sets `SPX_Data_Load` + `Golden_Template_User`; password reset email sent. Latest report from the user: a lead action failing with "insufficient access rights on object id" (unresolved; likely re-load updating a lead the Integration user no longer owns because intake reassigned it and Lead OWD is Private).

---

## 14. Honest status: what is untested or open

Say these confidently if asked; do not claim they are verified.

- **Not browser-tested by the user:** most 2026-11-04 and 2026-11-05 deployments (New Lead flow end to end, brand-relationship flows, Global Parent page in a browser, NBA agent chat, NBA button after final fixes).
- **SPX_Opportunity_Tasks:** deployed, a Priority bug fixed; user closed the item, but never exercised end to end in this record.
- **SPX Executive dashboard:** tested as admin only; John Leader retest pending. The Risk report shows more rows per project than SOQL counts of Risk records (unexplained).
- **Agent `Notify Brand Leader`:** never run live (it sends real notifications).
- **Project Name dashboard filter** is a static list (27 names).
- **Known flow gaps:** strategic-flag change on a Project does not recalc roll-ups; deleting a parent account with children does not repoint children; migration user bypasses roll-up flows.
- **Open decisions:** per-brand strategic thresholds (all 100M), Chicago Fan routing/price data, backfill Project Reference for existing projects, true search box on the dashboard (needs custom LWC).
- **Assumptions to confirm with client:** Marley and Strobic Brand Configuration values.
- **Deviation from original pack:** the pack concluded "no solution code needed". It now has Apex and an LWC: the data loader (demo-only integration simulation) and the NBA service (Apex because flows cannot read files). Project OWD moved from Private to Public Read/Write.

---

## 15. Likely oral questions and model answers

### Architecture and approach
1. **Why a Project object instead of using Account or Opportunity?**
   A construction project has many accounts (owner, GC, engineer), many brands pursuing it, and a lifecycle independent of any deal. Opportunity is one brand's deal; Account is a company. Project is the shared anchor that makes "one project, all brands" possible, with Opportunity lookup to Project.
2. **Why a lookup from Opportunity to Project and not master-detail?**
   An opportunity can exist without a project, and master-detail would change sharing and delete behaviour for standard Opportunity. It also is not allowed on a standard object in the child role. Cost: no roll-up summary fields, so flows maintain totals.
3. **Why custom metadata for Brand Configuration, routing and task templates?**
   Deployable configuration, usable in flows and Apex without SOQL limits, so new brands and rules are data changes. Scenario 6 relies on it: a brand goes live by ticking Live.
4. **Why configuration instead of code, and where did you break that?**
   Maintainability by admins, speed, and the client's brief. Exceptions: the Data Load tab (simulates an integration; demo-only) and NBA Apex (flows cannot read file bodies or parse JSON from a prompt reliably). Both are isolated and tested.
5. **Why record-triggered flows instead of Apex triggers?**
   Visible to admins, versionable, bypassable with custom permissions, no deployment test burden. Trade-offs: governor limits still apply, order of execution needs care, bulk loads can be slow.

### Security
6. **Explain OWD, role hierarchy, sharing rules and how a rep sees a project.**
   OWD sets the floor. Hierarchy grants access upward. Sharing rules open records by criteria (brand participating shares project to the brand leader role and subordinates). Reps see projects through OWD (now Public R/W internal), their ownership, and team sharing.
7. **Why did you change the Project OWD?**
   A segment lead could not create a lead on a project she did not own. Public Read/Write internal fixed it; external stays Private. Sharing rules remain but are redundant. Stakeholders follow because they are master-detail.
8. **How do you give one user access to Strobic-only fields?**
   Field-level security through the `SPX_Strobic_Key_Information` permission set assigned to Tony only; the field is placed on the layout, and the NBA service reads them only if the running user can see them.
9. **What is the difference between permission sets and profiles, and why use both?**
   Profile is baseline and mandatory; permission sets add access per feature or brand and can be assigned or removed without changing the profile, which fits brand onboarding (assign SPX Chicago Fan live).
10. **How do dashboards respect security?**
    Running user is the viewing user; so the same dashboard shows each persona different numbers. The Executive dashboard also lives in a folder shared only with John Leader.
11. **What does "Flow User" do?**
    A user permission that lets someone run flows from record pages. Without it, Flow quick actions do not show. It is per-user, not in profiles, so new users need it.
12. **Why do flows run in system mode?**
    Roll-ups and routing must update Project fields and records the user cannot see (a rep cannot see other brands' opportunities). Risk: exposure of data via flow output, so flows only write derived fields.
13. **How is the bypass framework safe?**
    Two custom permissions in a permission set assigned only to the Migration User; validation rules and flow entries check them. Sales users never hold it.

### Automation
14. **Walk through what happens when a ConstructConnect lead is released.**
    Status Staged becomes New; intake flow fires, matches or creates the Project, flags Strategic by brand threshold, checks each brand's eligibility and phase, skips brands already in pursuit, assigns owner from Routing Rule, sets potential, sets Match Result, notifies if strategic.
15. **How do project totals stay correct?**
    `SPX_Project_totals` runs after save on Opportunity (create, update, delete), re-queries open opportunities for the project and rewrites totals; delete has its own flow.
16. **Why compare owners within a brand for rep conflict?**
    Different brands naturally have different owners; only the same brand with two owners is a conflict.
17. **What are the limits of flow-based roll-ups?**
    Bulk volume, recursion risk, and no recalculation when a non-triggering field changes (for example strategic flag on Project). Mitigation: recalculation flow or scheduled job.
18. **How would you stop the flows during a data migration?**
    Assign `SPX_Migration_Bypass` to the Migration User; entry conditions skip flows; afterwards run a recalculation.

### Data and integration
19. **How do you stop duplicate ERP customers?**
    Matching rules and duplicate rules on Account; exact match blocks and the integration links to the matched account; possible matches are allowed with alerts and reported to stewards who merge.
20. **Why Account Number as the loader key?**
    It is the stable business key present on accounts; lookups by name are ambiguous. Duplicates reject the row rather than guess.
21. **Why does the loader ignore converted leads?**
    Salesforce does not allow updating a converted lead ("cannot reference converted lead"). Ignoring them inserts a new lead instead of failing. The risk is duplicating an already worked lead; the user accepted that trade-off.
22. **What does `stripInaccessible` do and what is the downside?**
    Removes fields the user cannot access so DML does not fail, but it fails silently. We saw it: Project Insights loaded without a Project because the Integration user lacked edit FLS on that field. A stricter loader would fail the row instead.
23. **How would a real feed be integrated?**
    Middleware (Boomi/MuleSoft) calling REST/Bulk API as the Integration User, inserting Project Intake or Leads with external IDs; the same intake flow processes them. Today it is staged and released by script.
24. **What is the Bulk API used for in Step 6?**
    Large migration of accounts and opportunities as the Migration User, with bypass; jobs appear in Setup, Bulk Data Load Jobs.

### Reporting
25. **Why did the Strategic filter fail and how did you fix it?**
    Dashboard filters do not handle checkbox fields well. I created Yes/No text formula fields and used them in the report type and dashboard filter.
26. **Why did the Risk report show projects with no risks?**
    The custom report type was an outer join. Setting `outerJoin=false` makes it an inner join.
27. **What are the dashboard limits you hit?**
    Max three filters, filter fields must be in the report, subscriptions ignore filters, GET can return cached results, metadata column naming (`Project__c$Field`).
28. **Why a custom report type?**
    Standard types cannot join Project to Project Intelligence as a child with the project as the base.

### Agentforce and AI
29. **What is an agent topic and action?**
    A topic groups instructions and actions for a category of user requests. Actions are the things an agent can do (flows, Apex, prompt templates). Our topics: lead summary, feed review, notify (with confirmation), next actions.
30. **How do you keep the agent safe?**
    Read-only by default; actions return text; instructions forbid invention; notify requires explicit user yes; NBA creates only Suggested records a human accepts.
31. **How does NBA work end to end?**
    Quick action or agent topic calls flow, which calls `SPX_NBA_Service`. Apex gathers project context and file text, builds a checklist, calls the prompt template for JSON, validates and retries, creates Suggested NBA records, skipping duplicates.
32. **Why Apex there?**
    Flows cannot read file bodies and JSON parsing, retry and cleaning logic are clearer in code. Everything else remains declarative.
33. **How do you test and publish an agent?**
    Validate the authoring bundle, publish, activate a specific version (`--version`), preview in CLI or builder. Prompt templates need matching active version identifiers.
34. **What are the AI risks?**
    Hallucination, thin data, cost and latency, prompt injection through spec files, data exposure if system mode reads restricted records. Controls: grounded prompts, caps, `with sharing`, FLS checks, human acceptance.

### Release and ops
35. **How did you deploy and manage this?**
    Salesforce DX project with `sf` CLI; metadata deploys, partial profile deploys through temporary `--metadata-dir`; destructive changes with `--post-destructive-changes`; retrieve before redeploying org-owned pages.
36. **How do you reset the demo?**
    Scripts in `docs/scripts`: `reset_feed.ps1`, `reset_step2.ps1`, `reset_step5.ps1`; NBA delete script; Chicago Fan activations reversed in order.
37. **How would you take this to production?**
    Add a proper integration, remove the staging and bypass-assigned demo users, harden loader (fail rather than strip), real SSO and permission design, test classes and flow tests, sandbox pipeline and change management.

### Hard or trap questions
38. **"Is the demo fully tested?"** No. Section 14 lists what is verified (queries, admin tests, unit tests: Apex tests pass) versus untested in a browser as end users.
39. **"Why not Data Cloud or CPQ?"** Out of scope for foundation; native Quotes sync is enough; Data Cloud identity resolution is a discussion point.
40. **"What happens if two brands both want the same lead?"** Each brand gets its own lead on the same project; opportunities share the Project; Rep Conflict only flags same-brand duplicates.
41. **"Why does the lead 'insufficient access' error occur?"** Leads are Private; after intake reassigns the owner the Integration user loses access; update on re-load fails. Fix options: View All/Modify All on Lead for the loader permission set, or a loader role at the top of the hierarchy (pending confirmation).
42. **"Why would a user not see a Flow button?"** Missing Flow User, missing flow access in profile or permission set, or no record access.

---

## 16. One-page cheat sheet

- **Anchor:** Project. **Per-brand:** Lead and Opportunity. **Junction:** Project Relationship. **Config as data:** Brand Configuration, Routing Rule, Task Templates.
- **Security chain:** OWD, roles, sharing rules, permission sets, FLS, custom permissions, Flow User.
- **Flows:** intake, roll-ups, conflict, participation, price book, tasks, global parent, ERP link, agent helpers.
- **Code (only two exceptions):** Data Load (LWC + Apex), NBA (Apex service + file reader).
- **AI:** prompt template for lead summary, agent topics for feed, notify, next actions; NBA creates Suggested records.
- **Dashboards:** viewing-user running; three filters; inner-join report type; Yes/No text formula for strategic.
- **Numbers worth remembering:** 34 flows, 8 custom objects, 12 Apex classes, 12 permission sets, 18 roles, 5 profiles, 21 Flow Users, 6 live brands plus Chicago Fan held, 35 task templates, 27 projects in the dashboard filter.
