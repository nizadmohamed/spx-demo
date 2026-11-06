# SPX live demo: developer handover pack

**Audience:** a developer who knows Salesforce well.
**Goal:** build everything shown in `SPX_Demo_Clickthrough.html` in a live sandbox, as configuration, with staging only where noted.
**Companion files:** `SPX_Demo_Data_Workbook.xlsx` (every record to load), `SPX_Demo_Data_and_Process_Audit.md` (value sources), `Steps_5_and_6_Build_Notes.md` (quote and new-brand detail), `SPX_Demo_Process_Flows.html`.

> **The client requirement:** everything in the click-through must run in a live, non-production org. Where Salesforce cannot render something exactly as the prototype draws it, this pack says so and gives the closest standard equivalent. Tell the presenter about every such difference before the session.

---

## 0. Before you start: environments and licenses

| Need | Detail | Check |
|---|---|---|
| Demo org | A sandbox that plays the live org: Cooling and three other brands live, Chicago Fan pre-built and inactive | About **11 Salesforce licenses** (see Users sheet) |
| Single org | All seven scenarios, including step 6, run in **one** demo org. No developer sandbox or change sets | Step 6 components are pre-built and left inactive, then activated live |
| Agentforce | Only if building agent moments for real (section 9) | Agentforce provisioned for the org; confirm sandbox availability with Salesforce |
| In-App Guidance | Prompts are included; walkthroughs beyond a small free allowance need an add-on | Count walkthroughs before you build them |
| Multi-currency | USD, CAD, EUR | **Enable before loading any data**; it cannot be undone |

**Naming used throughout:** Vertical (not vertical). Strategic large project = estimated construction value over $100M. Brand names: Ingénia, Patterson-Kelley, Cooling, TAMCO, Chicago Fan.

**Starting point:** the earlier `spx-demo-org` metadata package can be reused for the object structure, but it predates this pack. Its field names, thresholds and seed data are out of date, so apply the changes in section 1.

---

## 1. Shared foundation (build once)

### 1.1 Data model

| Object | Key fields | Notes |
|---|---|---|
| Account (standard) | Account Role (Owner, General Contractor, Mechanical Contractor, Engineer, Architect, Rep firm), Global Ultimate, Tier | Account Contact Relationships on |
| Project (custom, Private) | Project Code (ext ID), Project ID (ext ID), **Vertical** (Healthcare, Education, Multifamily, Data Center, Other), City, State, Postal, Territory, Estimated Construction Value, Project Phase (Planning, Schematic Design, Design Development, Construction Documents, Bid, Awarded), Project Stage, **Strategic Project** (checkbox, set by flow when value > $100M), Segment Coordinator, Owner, GC, Engineer of Record, Originating Brand, one "Participating" checkbox per brand, **Total SPX Potential**, **Brands Engaged**, **BOD Secured** (number fields maintained by flow), **Rep Conflict** (checkbox, set by flow) | Opportunity has a lookup to Project, so the standard Opportunities related list shows every brand's opportunity |
| Project Intake (custom) | Mirrors ConstructConnect fields, including contact fields | Stands in for the AppExchange package's objects |
| ERP Cross-Reference (custom) | ERP system, customer number, ERP Key (ext ID), name, bill-to, ship-to, terms, credit limit, phone, Global Account, Brand Relationship, Match Status | ERP fields read-only except for the ERP Integration permission |
| Brand Relationship (master-detail to Account) | Brand, Brand Owner, Open Pipeline | No ERP orders field |
| QTC Message Log (custom) | Opportunity, Brand, Sent At, Result | Stands in for Boomi outbound messages to QTC |
| Opportunity (standard) | Project (lookup), Brand, BU (stamped by flow), Vertical, BOD Status, Rep Firm, Spec Section, Territory, **Rep Conflict** (checkbox, set by flow) | Golden Template record type and sales process (1.0 to 5.0, Closed Won, Closed Lost) |
| Lead (standard) | Project, Brand, Vertical, Est. Construction Value, Est. Brand Potential, Potential Basis, Routing Rule, Strategic Project, Territory | |
| Brand Configuration (custom metadata) | BU, Brand Value, Target Verticals, Routing Threshold, Sends to QTC, Default Currency | Every flow reads it; new brands are new records |
| Potential Factor (custom metadata, optional) | Brand, Vertical, three factors | Calculates recommended potential on leads |
| Routing Rule (custom metadata) | Brand, State, Owner Alias, Territory | Sets lead owners |

### 1.2 Security

- **Org-wide defaults:** Opportunity, Lead and Project Private; Account Public Read Only.
- **Role hierarchy:** Segment Sales Leader → Brand Sales Leaders (one per brand) → Reps (RSM). Segment Support and Segment CRM Owner sit outside the line hierarchy.
- **Sharing rules on Project:**
  - "[Brand] Participating = true" → that brand's **Sales Leader role and subordinates**. This gives Dana the Ingénia projects with **no code**; see section 5.
  - "Strategic Project = true" → every Brand Sales Leader role.
- **Permission sets:** Golden Template User, Segment Visibility (segment-only fields), Segment Support (View All on Opportunity and Project), ERP Integration (custom permission), and one per brand (for example "SPX Ingénia User", "SPX Chicago Fan"). These are also In-App Guidance audiences.
- **Admin access:** enable "Administrators Can Log in as Any User".

### 1.3 App and pages

- **Lightning app:** "HVAC Segment" with tabs Home, Projects, Leads, Accounts, Contacts, Opportunities, Quotes, Reports, Dashboards.
- **Record pages:** Dynamic Forms pages for Lead, Opportunity, Project, Account and ERP Cross-Reference.

### 1.4 Data

- **Load order:** follow the workbook's Read me sheet. Load anchor records first, then background volume.
- **Background volume:** generate outside Ohio Valley, so the step 4 list views stay exactly as scripted.

### 1.5 Prototype visuals that don't exist as standard Salesforce components

| Prototype element | Build it as |
|---|---|
| KPI tiles on record pages | Fields in the Highlights panel (compact layout) or a Dynamic Forms "Summary" section |
| Project numbers | Flow-maintained fields in the highlights panel (compact layout); brand split in the standard Opportunities related list. No custom LWC |
| "Proof" checklists, scope notes | Presenter talking points, or a Rich Text component with static text |
| Agentforce side panel | Real Agentforce panel (section 9) |
| Pulsing highlights | Prototype only |

---

## 2. Scenario 1: Lead from feed

**Feasible as configuration: yes.** The ConstructConnect feed is **staged**.

1. **Flow "SPX Intake process":** record-triggered on Project Intake.
   1. Match on Project ID, then on a normalized name and postal key.
   2. Enrich, or create, the Project.
   3. Set Strategic if the value is over $100M.
   4. Loop Brand Configuration: create one Lead per brand whose Target Verticals include the project's vertical **and** whose Routing Threshold is met.
   5. Set the owner from Routing Rule, and set the potential from Potential Factor.
   6. If strategic, assign the Segment Coordinator and send a custom notification to the brand leaders.
2. **Lead page:** sections Project intelligence (feed fields read-only), Brand potential (estimate and basis), Routing.
3. **Lead field mapping to Opportunity:** Project, Brand, Vertical, and Est. Brand Potential → Amount (amount via a before-save flow on Opportunity, if mapping isn't possible). Golden Template is the profile default record type.
4. **Matching and duplicate rules:** Account (name and postal) and Contact (name and email).
5. **RSM home page:** the "HVAC Home – RSM" page from scenario 4 (section 5). Standard **Report Chart** components plus Today's Tasks:
   - **Leads:** a report "My New Leads" (Leads, owner = me, status New; columns Name, Company, Brand, Vertical, Est. Brand Potential, Lead Status), charted by lead. Dana clicks the Westfield bar, the report opens, and she opens the lead from the report.
   - **My Pipeline by Stage**, **Opportunities** (top open opportunities by amount), **Today's Tasks**.
6. **Notification (optional, not clicked in the demo):** custom notification type "New strategic project in your territory".

**Path:** Guidance for Success only (no Key Fields) at each golden stage.

**Riverbend (held by phase):** intake row CC-88424, $112M, Multifamily, **Planning**. Add field **Earliest Routing Phase** to Brand Configuration (Schematic Design for every brand); the intake flow creates no leads before that phase, so Riverbend is held.

**Staging:**
- Load the 4 intake rows as Staged. Before the session, set them to New (or use a scheduled-triggered flow) so the results are on screen. **Never press a "run feed" button live.**
- Load Dana's 5 opportunities and 4 tasks.

**In-App Guidance (Setup › In-App Guidance):**

| Prompt | Type | Where | Audience | Note |
|---|---|---|---|---|
| How to read the feed | Targeted or docked | Project Intake list view | Segment operations | |
| Your recommended potential | Docked or targeted | Lead page | Reps | Targeted prompts anchor to page components, not single fields. Anchor to the Dynamic Forms section, or use docked |
| Qualified? Convert it | Targeted | Lead page, Convert action | Reps | |

**Agentforce moments (optional):** feed summary, and **Summarize this lead** (standard Summarize action with a record summary prompt template on Lead). No task, email or pursuit-plan moments. See section 9.

**Reset:** delete the Westfield project and its leads, Rachel Tran, and the Westfield opportunity. Set the intake rows back to Staged.

---

## 3. Scenario 2: ERP mapping and Unified Customer View

**Feasible as configuration: yes, using standard Salesforce duplicate management.** The ERP batch is **staged**.

**Why ERP customers land as Accounts:** standard duplicate rules compare records of the same object (plus Leads with Contacts). For the matching rules to find the global account, Boomi creates each new ERP customer as an **Account** (Account Source = the brand ERP). It creates its ERP-mastered data on an **ERP Cross-Reference** child record.

### Configuration
1. **ERP Cross-Reference:** a lookup to Account (merge moves lookup children to the master). Make the ERP fields read-only through field-level security for everyone except the ERP Integration permission, add a validation rule on `$Permission.ERP_Integration`, and turn on field history.
2. **Account Source:** add one value per brand ERP (for example "Patterson-Kelley ERP").
3. **Matching rules on Account:**
   - **Custom "ERP exact match":** Account Name (fuzzy, company name) AND Billing Zip/Postal Code (exact) AND Phone (exact).
   - **Standard Account Matching Rule:** activate it.
4. **Duplicate rules on Account,** with conditions limiting them to Account Source = a brand ERP:
   - **"ERP customer: exact match":** uses ERP exact match. Action on create: **Block**.
   - **"ERP customer: possible match":** uses the Standard Account Matching Rule. Action on create: **Allow**, with **Alert** and **Report** ticked, so a Duplicate Record Set is created.
5. **Integration logic (Boomi; describe it, don't build it for the demo):**
   - If a cross-reference with the ERP Key already exists, update only the cross-reference.
   - Otherwise, create the Account. If the exact rule blocks it, take the matched Account ID from the duplicate error and create the cross-reference under that account. **This is the auto-link.**
   - If the account is created (possible match or none), create the cross-reference under it.
   - **Never recreate an account for an ERP key that already has a cross-reference.** Otherwise merged accounts would come back.
6. **Account page:** add the standard **Potential Duplicates** component, the ERP References related list, and a Details section.
7. **Steward access:** stewards need Delete on Account to use **Merge Accounts** (standard; up to three accounts at a time).
8. **Steward entry point:** the record itself. The steward opens the ERP-created account and works the standard **Potential Duplicates** component. No custom list, tiles or report in the demo.
9. **Flow on ERP Cross-Reference:** when Account changes, set the Brand Relationship on the account's global ultimate (create or reuse).
10. **Unified Customer View (Account page):**
    - **Highlights:** Customer Type, **Account Owner = "SPX"** (a placeholder user named SPX owns global accounts), Tier. No Regions field.
    - **Three metrics** (report charts or highlight fields): Open pipeline, all brands; Brands active (count only); Strategic projects as GC. **No ERP orders data**; that isn't being integrated.
    - **Four full-width related lists, stacked in this order:**
      1. **Brand Relationships** (Brand, ERP References, Brand Owner, Open Pipeline);
      2. **Project Relationships** (Account, Relationship Type, Project);
      3. **Related Projects** (Project, Vertical, Brands, Project Phase);
      4. **Related Contacts** (Name, Title, Account), with no extra descriptive text.

### Staging
- **Load the linked cross-references** under their global accounts as the Integration User.
- **For the last batch, create** "ARDENT BLDRS INC" (Account Source Patterson-Kelley ERP, Columbus 43219, (614) 555-0190) **as the Integration User** with the duplicate rules active. Confirm Duplicate Record Set DRS-… is created with Ardent Builders – Ohio Region and Arden Mechanical as items. Then create PK-004417 under it.
- **Duplicate record set check:** confirm in the sandbox that records created through the API produce Duplicate Record Sets. If they don't, create this one account through the UI.
- **Other batch records:** create "MIDWEST MECH CONTR" the same way (no duplicates, so it stays new). Show the three auto-linked records with their cross-references already under existing accounts.

### In-App Guidance
None in this scenario.

### Agentforce
None in this scenario.

### Reset
1. Merge can't be undone in place. Restore ARDENT BLDRS INC from the Recycle Bin, or create it again as the Integration User.
2. Move PK-004417 back to it.
3. Delete the Patterson-Kelley brand relationship if the flow created it.
4. Confirm a Duplicate Record Set exists again.

## 4. Scenario 3: One project, all brands

**Feasible as configuration: yes. Standard components only.** No Brand Participation or Rep Coverage objects, no custom LWC, no Agentforce. The demo is two screens: the strategic projects list view, then the project record.

### Project record page (Lightning App Builder)
- **Highlights panel** (compact layout): Vertical, Project Phase, Estimated Construction Value, Total SPX Potential, Brands Engaged, BOD Secured, Rep Conflict.
- **Path** on Project Phase.
- **Opportunities related list** (standard, via Opportunity.Project__c). Label it **Opportunities**. Columns: Opportunity Name, Brand, Stage, BOD Status, Rep Firm, Owner, Amount, Rep Conflict.
- **Related list:** Project Stakeholders. **No Project History** related list on the page.

### Fields

| Object | Field | API name | Type |
|---|---|---|---|
| Project | Total SPX Potential | `Total_SPX_Potential__c` | Currency (flow-maintained) |
| Project | Brands Engaged | `Brands_Engaged__c` | Number (flow-maintained) |
| Project | BOD Secured | `BOD_Secured__c` | Text(20), for example "2 of 3" (flow-maintained) |
| Project | Rep Conflict | `Rep_Conflict__c` | Checkbox (flow-maintained) |
| Opportunity | Rep Conflict | `Rep_Conflict__c` | Checkbox (flow-maintained) |

### Flow 1: "SPX Project totals"
Record-triggered on Opportunity, after save; created, updated or deleted. Entry: Project, Amount, Brand, Stage, BOD Status or IsDeleted changed. Runs in system context without sharing.
1. **Get Records:** Opportunities where Project__c = the record's Project__c AND StageName ≠ Closed Lost.
2. **Loop:**
   - add Amount to `varTotal`;
   - add the Brand to a text collection `varBrands` if it isn't already there;
   - count the brands where any opportunity has BOD Status = Secured into `varBod`.
3. **Update** the Project: Total_SPX_Potential__c = `varTotal`; Brands_Engaged__c = count of `varBrands`; BOD_Secured__c = `varBod` & " of " & Brands_Engaged.

Why a flow: Opportunity → Project is a lookup, so roll-up summary fields aren't available.

### Flow 2: "SPX Rep conflict check"
The check compares owners **within the same brand** on a project. Different brands always have different owners, so comparing across all opportunities would flag every multi-brand project.

Record-triggered on Opportunity, after save; created, or Owner, Brand, Project or Stage changed. Also run on delete. Runs in system context without sharing.
1. **Get Records** `colSameBrand`: Opportunities where Project__c = record's Project__c AND Brand__c = record's Brand__c AND IsClosed = false.
2. **Decision:** does any opportunity in `colSameBrand` have an OwnerId different from the record's OwnerId?
   - **Yes:** Loop `colSameBrand` and set Rep_Conflict__c = true on each (including the record). Update the records.
   - **No:** set Rep_Conflict__c = false on each in `colSameBrand`. Update.
3. **Get Records** `colFlagged`: Opportunities where Project__c = record's Project__c AND Rep_Conflict__c = true.
4. **Update** the Project: Rep_Conflict__c = (`colFlagged` is not empty).

**Optional, not shown live:** a validation rule on Opportunity that blocks moving past 2.0 while the conflict is open.

```
AND(Rep_Conflict__c,
    ISCHANGED(StageName),
    NOT(ISPICKVAL(StageName, "1.0 Prospect and Market ID")),
    NOT(ISPICKVAL(StageName, "2.0 Needs Analysis and Qualify")))
```

Error message: "Another owner has an open opportunity for this brand on this project. Agree one owner before moving past 2.0."

**List view:** "Strategic projects" (Strategic Project = true), with columns Project, Vertical, Estimated Construction Value, Project Phase, Brands Engaged, BOD Secured, Rep Conflict.

### Staging
- Add user **Rob Keane** (Patterson-Kelley Rep, Illinois).
- Create opportunity **Lakemont Health East Tower – PK – Hydronic plant**: Brand Patterson-Kelley, owner Rob Keane, Rep Firm Lakeshore Hydronic Sales, Stage 1.0, **Amount blank**, so project totals are unchanged.
- The flow flags both Patterson-Kelley opportunities and the project.

**In-App Guidance:** none in this scenario.

**Reset:** none needed; the flag stays until the duplicate PK opportunity is closed or reassigned.

## 5. Scenario 4: Role-based visibility (three home pages)

**Feasible as configuration: yes. Standard Report Chart components (plus Today's Tasks) only.** No List View or Key Deals components; object and component names are consistent (Leads, Opportunities, Projects).

### Profiles and assignment
- Three profiles: **SPX RSM**, **SPX Brand Sales Leader**, **SPX Segment Sales Leader**.
- Three Lightning home pages, activated with **Assign to apps and profiles**, app HVAC Segment:
  - **HVAC Home – RSM** → SPX RSM
  - **HVAC Home – Brand Sales Leader** → SPX Brand Sales Leader
  - **HVAC Home – Segment** → SPX Segment Sales Leader

### Components (all Report Chart unless stated)

| Home page | Components |
|---|---|
| RSM (Dana) | **My Pipeline by Stage**; **Leads** (my new leads by estimated brand potential); **Opportunities** (my top open opportunities by amount); Today's Tasks |
| Brand Sales Leader (Marcus) | **Pipeline by Owner** (my team's open opportunities grouped by owner: 10 RSMs, total $214.0M); **Opportunities** (my team's top open opportunities by amount); Today's Tasks |
| Segment (Priya) | **Open Pipeline by BU**; **Open Pipeline by Stage**; **Projects** (top projects by Total SPX Potential); **Opportunities** (top open opportunities across BUs and brands) |

**Top-N charts:** a report sorted by Amount (or Total SPX Potential) descending with a row limit of 5 or 6, charted as a bar.

### How visibility works
Report charts run as the **viewing user**, so the role hierarchy and sharing decide the data:
- **Dana:** her records.
- **Marcus:** every RSM under him.
- **Priya:** everything.

### Staging (see the data workbook)
- **Ingénia RSMs under Marcus:** Maria Santos, Jordan Blake, Alicia Gomez, Ben Ortiz, Hannah Lee, Samir Patel, Leo Fischer, Grace Kim, plus Dana and Kevin. Their background pipeline totals match the chart.
- **Two new leads for Dana:** Grove City Surgical Center – Ingénia, and Ohio Valley Rehab Hospital – Ingénia.
- **Top segment opportunities:** Meridian Hyperscale Campus (Cooling, $11.4M), Lone Star DC Campus (Cooling, $8.9M), Great Lakes Medical Center (Ingénia, $5.6M), Carolina Research Campus (Ingénia, $4.9M), Atlanta Data Hub (TAMCO, $3.9M).

**Not shown:** "why you see" panels, Sharing Hierarchy, Agentforce.

## 6. Scenario 5: Quote and price capture (native Sales Cloud, no CPQ or Revenue Cloud)

**Feasible as configuration: yes.** No PDF, no discount, no approval process.

### Setup
1. **Quote Settings:** enable Quotes. Add the related lists **Opportunity Products** (labelled as such) and **Quotes** to the Opportunity page, and **Quote Line Items** to the Quote page.
2. **Products** at product-family level, with Product Family set:
   - Custom air handling unit, double wall
   - Custom air handling unit, 100% outside air
   - Modular air handling unit
   - Jobsite assembled air handling unit
   - Factory startup and commissioning
   - Freight and rigging
3. **Price books** per brand and currency (USD, CAD, EUR), with standard price book entries.
4. **Price book flow:** a before-save flow sets the Opportunity price book from Brand Configuration and currency.
5. **Fields:** keep Opportunity Product and Quote Line Item to **standard fields** (Product, Quantity, Sales Price). **Remove Line Description** from the edit screens and layouts. Native sync doesn't carry custom line fields without extra automation.
   - **Sales Price is shown but not edited live.** The demo values are pre-staged.
   - Making Sales Price truly read-only would force it to equal list price, which changes every total. Confirm with SPX before locking it.
6. **No PDF:** don't configure quote templates or the Create PDF button for the demo.

### Native mechanics (what the demo relies on)

| Step | Native behavior |
|---|---|
| Add opportunity products | Once an opportunity has products, **Amount is the total of its products** and is no longer edited directly |
| New Quote from the opportunity | **The new quote includes the opportunity's products by default** and uses the opportunity's price book |
| Refine the quote | Add Products and Edit Products on Quote Line Items: product, quantity, sales price |
| Start Sync | **The quote's line items replace the opportunity's products, and the opportunity amount updates to match.** Only one quote per opportunity can sync |
| While syncing | Adding, removing or changing line items on either record syncs to the other, until Stop Sync |
| Requirement | The opportunity must have a price book |
| Automation | Start Sync is a user action, not available to Flow, so the rep clicks it |
| Quote fields | Quote shipping and tax don't affect Opportunity Amount; leave them blank |

### Staging
- The opportunity starts at **$3,350,000 with no products** and no quotes.
- Live, the rep adds **one** estimate line (double wall × 8 at $418,750).
- The quote copies it. The rep changes it to 6 units at $427,500 and adds outside air × 2 ($450,000), startup × 8 ($12,500) and freight × 1 ($35,000), for a total of **$3,600,000**.

### Dashboard for this step
Metric components and bar charts only:
- **Metrics:** Segment open pipeline, plus **one per vertical** (Healthcare $302.10M, Data Center $401.50M, Education $142.30M, Multifamily $88.40M, Other $53.70M).
- **Bar charts:** Open pipeline by BU, and **Projects by Total SPX Potential**.

**No trend line, no "what moved" component, no comparisons.**

**In-App Guidance and Agentforce:** none in this scenario.

**Reset:**
1. Stop Sync and delete the quote.
2. Delete the opportunity products.
3. Set Amount back to $3,350,000.

## 7. Scenario 6: Onboard a new brand into a live org (Configure → Isolate → Validate → Transition)

**What the client is really asking:** "Can we keep operating while we bring another brand onto this platform?" The answer is in how the solution and cutover are designed, not in the deployment tool. The story is **tool-agnostic**.

**Voice-over:** "In a program with separate environments these components arrive by change set or a DevOps tool. The metadata deployment principles are the same, and so is the go-live."

**One org, configuration only, no Agentforce.** Chicago Fan is pre-built and inactive in the demo org and activated live.

### Demo choreography

| Phase | Screens | Message |
|---|---|---|
| **Configure** | Record types and sales processes, then activate the brand value, Lightning page, Brand Configuration Live, flow version 4 and validation rule | Two processes coexist; the new brand goes onto the golden template |
| **Isolate** | Permission set **SPX Migration Bypass** (custom permissions), then Kim's permission set | Automation and rules can be bypassed for one controlled migration user; the new brand is limited to its own users |
| **Validate** | Kim creates and progresses a golden-template opportunity. The legacy Cooling regression is **voiced over**, not clicked | New brand works; the existing process is regression-tested before every release |
| **Transition** | Setup › Bulk Data Load Jobs: the migration user's Account and Opportunity loads | Controlled data migration and cutover, no big bang |

### A. Transition architecture: two sales processes coexisting

| Component | Exact name | Detail |
|---|---|---|
| Sales process | **Golden Template** | Stages 1.0 to 5.0, Closed Won, Closed Lost |
| Sales process | **Cooling Legacy** | Stages Qualify, Design Assist, Quote, Negotiate, Closed Won, Closed Lost (Cooling's current stages) |
| Record type | **Golden Template – Project Sale** | Golden Template process; default for every brand profile, including Cooling |
| Record type | **Cooling – Legacy** | Cooling Legacy process. **Assigned to Cooling profiles but not as default**; new Cooling opportunities use the golden template. Existing Cooling opportunities carry this record type |
| Page assignment | Opportunity – Golden Template (+ Chicago Fan) | For Golden Template – Project Sale |
| Page assignment | Opportunity – Cooling Legacy | Existing Cooling page, for the Cooling – Legacy record type |
| Reporting | Field **Golden Stage** on Opportunity (formula text) | Maps legacy stages to golden stages (Qualify → 2.0, Design Assist → 3.0, Quote → 4.0, Negotiate → 5.0), so segment dashboards report one funnel. Use it in the stage charts |

**Long term,** the target is one golden template. The legacy record type is retired once Cooling opportunities have closed or been migrated.

### B. Isolation: the bypass framework (configuration only)

| Component | Exact name | Detail |
|---|---|---|
| Custom permission | `SPX_Bypass_Validation_Rules` | Checked first in every SPX validation rule: `NOT($Permission.SPX_Bypass_Validation_Rules)` |
| Custom permission | `SPX_Bypass_Automation` | Added to the entry conditions of every SPX record-triggered flow. The formula entry condition includes `NOT({!$Permission.SPX_Bypass_Automation})` |
| Permission set | **SPX Migration Bypass** | Contains both custom permissions. **Assigned only to the Migration User**, never to sales users |
| User | **Migration User** | Profile SPX Integration; used only for data loads |
| Brand switch | Brand Configuration **Live** checkbox | Flows that loop over brands ignore non-live brands |
| Page isolation | Fan selection section visibility | Brand = Chicago Fan |

Flows to update with the bypass entry condition:
- SPX Intake process
- SPX Opportunity participation
- SPX Project totals
- SPX Rep conflict check
- the price book flow
- the ERP cross-reference flow

The validation rules to update are all SPX rules, including `CF_Fan_Selection_Before_Spec`.

### C. Build and leave INACTIVE (activated live, in this order)

| # | Component | Exact name | Pre-demo state | Live action |
|---|---|---|---|---|
| 1 | Global value set value | Brand › **Chicago Fan** | Inactive | Activate |
| 2 | Lightning record page | **Opportunity – Golden Template v2** (`Opportunity_Golden_Template_v2`) | Not activated | App Default › HVAC Segment |
| 3 | Custom metadata record | Brand Configuration › **Cincinnati_Fan** | Live = false | Tick Live |
| 4 | Flow version | **SPX Opportunity participation** version 4 | v3 active, v4 inactive | Activate v4 |
| 5 | Validation rule | **CF_Fan_Selection_Before_Spec** (formula below) | Inactive | Activate |
| 6 | Permission set assignment | **SPX Chicago Fan** → Kim Alvarez | Not assigned | Assign |

```
AND(
  NOT($Permission.SPX_Bypass_Validation_Rules),
  ISPICKVAL(Brand__c, "Chicago Fan"),
  OR(ISPICKVAL(StageName, "3.0 Spec and Influence"),
     ISPICKVAL(StageName, "4.0 Solution and Proposal"),
     ISPICKVAL(StageName, "5.0 Negotiate and Close")),
  OR(ISBLANK(TEXT(Fan_Arrangement__c)), ISBLANK(TEXT(Wheel_Type__c)))
)
```

**Pre-built with no effect until activation:**
- fan fields
- the CF participating flag on Project
- routing rules
- roles: Chicago Fan Brand Sales Leader, Chicago Fan Rep (RSM)
- sharing rule: CF participating → CF leader and subordinates
- the CF leader role added to group Brand Sales Leaders
- permission set SPX Chicago Fan (unassigned)
- user Kim Alvarez
- price book Chicago Fan 2026 list (USD) (inactive)
- Account Source value Chicago Fan ERP (inactive)

### D. Validate: regression of the existing process (voiced over)
- **Not clicked in the demo.** The presenter states that existing Cooling deals carry on on the legacy process, and that a scripted regression test confirms it before every release.
- **Staging still needed:** Tom's opportunity "Northpoint DC Bldg D – Cooling – Towers" (record type **Cooling – Legacy**, stage Quote, $2,750,000) appears in scenario 4.
- **Scripted regression test**, run before every release and voiced over:
  - save a Cooling legacy opportunity;
  - save a Cooling golden opportunity;
  - confirm the QTC message;
  - open both Cooling pages;
  - run the segment dashboard.

### E. Transition: data migration and cutover
**Before the session**, as the Migration User with SPX Migration Bypass, load Chicago Fan's data with **Data Loader using the Bulk API**, so the jobs appear in **Setup › Bulk Data Load Jobs**:
- Accounts: 214 records, upsert on the ERP key.
- Opportunities: 38 open opportunities from Chicago Fan's spreadsheets, on the golden template.

**Post-load:** recalculate project totals. Run a one-off autolaunched flow, or re-save the affected projects, because the bypass skipped the totals flow during the load.

**Cooling cutover options (voice-over):**
1. migrate legacy opportunities onto the golden template when the business is ready (mapping legacy stages to golden stages, loaded with the bypass on), or
2. let legacy opportunities finish on the Cooling Legacy process while every new opportunity starts on the golden template.

**Caveat to state honestly:** some changes have dependencies that must be released in sequence (for example dependent objects and fields, or OmniStudio components). The cutover plan sequences them; we don't promise zero operational consideration for every possible change.

### Reset (reverse order)
1. Delete Kim's opportunity; clear the CF flag on Lakemont.
2. Remove Kim's permission set assignment.
3. Deactivate the validation rule.
4. Reactivate flow version 3.
5. Untick Live.
6. Set the app default back to "Opportunity – Golden Template".
7. Deactivate the brand value.

The Bulk Data Load Jobs history stays; it is evidence, not demo state.

## 8. Scenario 7: Segment dashboard (native Lightning dashboards and reports)

**Feasible as configuration: yes.**

### Filters
**Lightning dashboards allow up to 3 filters**, and filters can't use custom formula fields. The demo uses exactly three:
- **Business unit:** text field stamped by flow.
- **Vertical:** picklist.
- **Strategic project:** a checkbox set by flow, not a formula. Values All, True, False.

Map each filter to equivalent fields on each component's source report. Remove any toggle-style control.

### Components
All report-based:
- **Metrics:** open pipeline, strategic projects, BOD/spec rate, strategic attachment, win rate with BOD. Explanations go in the component footer.
- **Stacked bar:** pipeline by BU and brand.
- **Funnel:** pipeline by golden stage.
- **Bar:** projects by project phase.
- **Bar:** strategic attachment by vertical (summary formula in the source report).
- **Lightning Table** titled **Projects**, from an Opportunities with Project report: columns Project, Project Phase, Brand, Stage, Amount.
- **Dashboard title:** "HVAC segment". The stage funnel is titled "Brand opportunity stage".

### Drill-through
Clicking a chart opens its **source report**, filtered to the clicked value. Show the standard report run page: chart, grouping by Brand, subtotals, detail rows, and the Row Counts, Detail Rows, Subtotals and Grand Total toggles. **Never drill from a chart to a list view.** Return with Back or the Dashboards tab.

### Subscription
Priya subscribed weekly. **Filters aren't applied in subscription emails**, so the email shows the unfiltered dashboard.

**Not used:** reporting snapshots, trend comparisons, "what moved" panels.

## 9. Agentforce moments: build or stage

**Only two scenarios now use Agentforce. Both are optional, and both are labelled in the room as "art of the possible, not in Foundation scope".**
- **Scenario 1:** feed summary (segment operations); **Summarize this lead** (rep).
- **Scenario 7:** "Please can you summarize the health of the segment" (segment leader): a summary of pipeline, stage mix, BOD rate, strategic attachment and the newest brand.

| Option | How |
|---|---|
| **A. Real** | **Summarize this lead:** the standard Summarize action with a Prompt Builder record summary template grounded on the Lead and its Project. This one is realiztic to build for real. |
| **B. Staged** | Custom metadata type "Demo Response" (Topic, Question, Response) plus an autolaunched flow action that returns the text. Use it for the feed summary and the segment intervention answer, which cite history a demo org doesn't have. |

**Before choosing:** confirm Agentforce is available in your sandbox. If it isn't, run these moments from the prototype.

## 10. Code inventory

| Item | Code? | Decision |
|---|---|---|
| Project access for reps | No | Sharing rule to the brand leader role and subordinates |
| Step 6 go-live and isolation | No | Activation of pre-built inactive components; bypass via custom permissions in validation rules and flow entry conditions |
| Project totals and rep conflict | No | Two record-triggered flows on Opportunity writing to Project and Opportunity fields; standard Opportunities related list and highlights panel |
| Agentforce staged responses | No | Custom metadata plus flow |
| Seed and reset scripts | Tooling only | Anonymous Apex or Data Loader; not part of the solution |

**Result: no solution code is needed.**

---

## 12. Recommended-practice optimizations built into the demo

These came out of the process flows. Each is configuration and is visible on screen; the presenter panel labels them "Recommended practice".

| Tab | Optimization | Build |
|---|---|---|
| 1 | Contact matching at conversion | A matching rule and duplicate rule on Contact (name and email); Lead Convert then offers existing contacts |
| 1 | First contact with the engineer on strategic projects | Field "First Contact with Engineer" (User lookup) on Project, set by the segment coordinator |
| 2 | Auto-link high-confidence ERP matches | Standard duplicate management: an exact matching rule with a **Block** duplicate rule, and the integration attaches the cross-reference to the matched account. Possible matches use the Standard Account Matching Rule with **Allow and Report**, creating Duplicate Record Sets for stewards. Four summary tiles as report charts |
| 3 | Owner conflict flag | Flow compares owners within a brand on a project; flag in highlights and Opportunities list; optional stage-gate validation rule |
| 5 | Price book set automatically | A before-save flow on Opportunity sets Pricebook2Id from Brand Configuration plus opportunity currency, so reps never choose it. Keep USD, CAD and EUR price books |
| 6 | Release plan and go-live order | A release plan per wave, prepared by the release lead: what to pre-build inactive, the activation order, and the Cooling regression test |
| 7 | KPI definitions | Agreed in Blueprint and documented; not shown as a dashboard component |
| 7 | Weekly subscription | A standard dashboard subscription for Priya. Filters aren't applied in subscription emails |

**Discussion points only, no build:** quarterly routing-threshold review; the same matching rules for migration and daily batches; fixed release cadence; pre-approved deviation packs.

**Discuss with SPX, not built:** owner-conflict resolution policy, rep firms on the platform, configurator write-back, Data Cloud identity resolution, discount approval threshold.

---

## 11. Rehearsal checklist

- **Day 1:** confirm licenses, the demo org and Agentforce availability.
- **Dashboard filter limit:** confirm it, and that In-App Guidance targeted-prompt anchors work on each page.
- **Load:** anchor data, then volume; check the counts in section 5.
- **Dry run 1:** log every gap against the prototype.
- **Dry run 2:** run with a stopwatch. Step 6 takes about 20 minutes, including deployment.
- **Morning of:** reset all scenarios; set intake rows to New; refresh dashboards once; log in to every persona.
