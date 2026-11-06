# Plan: deploy the SPX demo to a new sandbox

Status: PLAN ONLY. Nothing here has been run against a new org. Every org change needs the user's explicit go-ahead (standing rule).
Source of truth: the metadata in `force-app/main/default` (retrieved from `spx-demo`, API 67.0). Scripts: `scripts/deploy_new_sandbox.ps1` (validate by default).

## 0. The one risk to settle first: is the new sandbox an SDO org?
The project was retrieved from a Salesforce **SDO** (Solution Demo Org) sandbox and contains metadata from that baseline and its managed packages that a plain org does not have, for example `maps__*` (MapAnything), `FSL__*` (Field Service), `pi__*` (Pardot), `cccalendar__*`, `SDO_*` record types, list views, layouts and field sets, plus 15 standard objects customised by SDO.

| New sandbox type | What to expect | Approach |
|---|---|---|
| Another SDO-based org (recommended) | Most or all of the project deploys unchanged | Run the phased script as is |
| Plain Developer/Partial/Full sandbox of a normal org | Deploy fails on missing packages, record types and fields | Use `-SkipManagedPackages`, then fix each remaining failure from the dry-run output (remove or stub SDO-only components). Expect an iterative loop of 3 to 6 dry runs |
| Scratch org | Same as plain; also needs features in `config/project-scratch-def.json` | Not recommended for this project |

Things SPX itself uses from the SDO baseline (do not strip blindly): record types `Lead.SDO_Lead_Default` (Lead Source default "Rep Entered"), `Account.SDO_Account_Simple` and `Business_Account` (compact layout assignment), Lead path `SDO_Sales_Lead_Path`, Account `Tier__c`, `CreditLimit__c`.

## 1. Before any deploy: confirm with the user
1. Target sandbox type and alias (section 0) and who owns the org.
2. Username domain for the new org. Folder shares in `reports/SPX_Executive.reportFolder-meta.xml` and `dashboards/SPX_Executive.dashboardFolder-meta.xml` are hard-coded to `mhill@accenture.com.spx.demo` (John Leader). In a different org that user must exist first, or the share line must be edited.
3. Whether to keep the Chicago Fan components inactive (yes: demo Step 6 activates them live).
4. Permission to run each phase with `-Execute` (the script validates first; run the dry run, review, then approve).

## 2. Org prerequisites (Setup, not metadata)
Do these first; several cannot be undone or must precede data.
- **Multi-currency ON** (USD, CAD, EUR) before loading any data (irreversible).
- **Quotes** enabled; **Account Contact Relationships** on; **Duplicate management** available; **Field history** enabled by deploy.
- **Opportunity**: Contact Roles, Team Selling as in the source org (compare Setup > Opportunity Settings with `spx-demo`).
- **Agentforce**: Einstein generative AI on, Agentforce enabled, Prompt Builder available, licences available (the demo used Agentforce (Default) and Einstein Prompt Templates licences; 20 users).
- **In-App Guidance**: Walkthroughs licences (limited; original org had 10).
- "Administrators can log in as any user" (Setup > Login Access Policies).
- Lead and Opportunity standard picklists (Lead Status, Stage) are deployed via `standardValueSets`; the removed Lead Status "Received" must not reappear.
- Org-wide email address / deliverability set to **All email** only if you need the notification and password emails; keep restricted otherwise.

## 3. Deploy order (what `deploy_new_sandbox.ps1` does)
Validate-only first (default), then `-Execute` per phase after approval.

| Phase | Components | Why this order |
|---|---|---|
| 1 | globalValueSets, standardValueSets, objects (custom + 15 standard), customPermissions, roles, groups, customMetadata (Brand_Configuration, Routing_Rule, Potential_Factor, Task templates) | Everything else references objects, fields, value sets and roles |
| 2 | classes (SPX_DataLoadController, SPX_NBA_Service, SPX_NBA_ReadFiles and tests), lwc (spxDataLoad), tabs | Permission sets, profiles and flows reference classes and tabs |
| 3 | flows (34), quickActions, matchingRules, duplicateRules, sharingRules, notificationtypes | Flows after objects; sharing rules after roles |
| 4 | permissionsets (12), profiles (5) | Reference classes, flows, tabs, fields |
| 5 | layouts, flexipages, applications, pathAssistants | Reference quick actions, flows, record types |
| 6 | reportTypes, reports, dashboards | Report types before reports, reports before dashboards; folder shares need John Leader to exist |
| 7 | genAiPromptTemplates | Needed by the NBA and lead-summary actions |

Then run Apex tests in the new org:
`sf apex run test --target-org <alias> --class-names SPX_DataLoadControllerTest --class-names SPX_NBA_ServiceTest --class-names SPX_NBA_ReadFilesTest --result-format human --wait 20`
(expect all pass; the earlier org result was 12/12 for the data loader test class, 7 and 4 for the NBA classes).

Notes that affect the deploy:
- Deploy table can show "Unchanged" yet apply; verify key settings with queries (for example Project OWD via `EntityDefinition`: expect `ReadWrite`).
- Picklist values cannot be deleted by deploy; irrelevant for a fresh org.
- `Opportunity_Golden_Template` flexipage and the Golden Template layout in the repo match the source org (retrieved), so a first deploy to a NEW org is fine. The "do not overwrite" warning applies to the old org only.
- If a phase fails, fix the named component locally, re-run that phase. An approval covers fixing deploy errors in the approved scope only.

## 4. Agentforce (not source-deployable in one step)
1. After phase 7, retrieve/verify the prompt templates `SPX_Lead_Summary` and `SPX_NBA_Recommendations`. A deployed template needs `<activeVersionIdentifier>` equal to its `<versionIdentifier>`, otherwise calls fail with "No active template version".
2. Agent bundle `SPX_Segment_Assistant` (in `aiAuthoringBundles`): `sf agent validate authoring-bundle --api-name SPX_Segment_Assistant`, then `sf agent publish authoring-bundle --api-name SPX_Segment_Assistant`, then `sf agent activate --api-name SPX_Segment_Assistant --version <N>` (needs `--version` or it prompts). Source org had version 6 active (confirms by project name via flow `SPX_Agent_Get_Project_Name`).
3. Flow access for the agent flows must be in the profiles/permission sets (already in metadata).
4. Never test `SPX_Agent_Notify_Brand_Leader` live (sends a real notification).

## 5. Users and access (not in metadata)
The users, their permission set assignments and Flow User flags are org data. Rebuild them from the Users sheet of `docs/SPX_Demo_Data_Workbook.xlsx` and `docs/SPX_Session_Resume_Context.md`:
- **Profiles:** SPX RSM (18 users incl. Dana, Steven (Marley), Tony (Strobic)), SPX Brand Sales Leader (John Leader, mhill), SPX Segment Sales Leader (Priya, John SalesEngineer jsengr, Erica pnataraj), System Administrator (Sam Okafor), SPX Integration (spxinteg, migrate).
- **Roles:** per user as in the workbook (Segment Sales Leader > Brand Sales Leaders > RSMs; Marley and Strobic reps swapped on 2026-11-02: srsm = Marley, trsm = Strobic).
- **Permission sets:** `Golden_Template_User` and brand sets (`Ingenia_User` etc.) per user; `Segment_Visibility`; `SPX_Agentforce_User` for the 20 agent users plus Agentforce and Einstein Prompt Template licences and `CopilotSalesforceUser`; `SPX_Next_Best_Action_Segment_Lead` (pnataraj, jsengr, admin, sokafor); `SPX_Project_Intelligence_Segment_Lead` (pnataraj, jsengr); `SPX_Strobic_Key_Information` (trsm only); `SPX_Data_Load` (admin, sokafor, spxinteg); `SPX_Migration_Bypass` (migrate only); `ERP_Integration` (integration user).
- **Do NOT assign:** `SPX_Cincinnati_Fan` (label "SPX Chicago Fan") until demo Step 6 (Kim Alvarez live).
- **Flow User checkbox** (`UserPermissionsInteractionUser`) = true for all 21 SPX users; without it the New Lead and Recommend buttons do not appear. Bulk: `sf data update bulk --sobject User --file users.csv`.
- **Passwords:** set via `System.resetPassword(userId, true)` or Setup; persona passwords were deliberately discarded in the source org.
- Usernames in the new org may need a different domain; update anything that names a username (folder shares, data files, docs).
- Brand leaders exist only for Ingenia (mhill); no user has Manager populated. Task templates and routing use user **aliases** (dreyes, srsm, trsm, jsengr, pnataraj), so keep those aliases.

## 6. Data
Order per the workbook Read me sheet: anchor records first, then background volume.
1. Anchor data: Accounts (Account Number is the loader key), Contacts, Projects, Opportunities, Leads, ERP cross references, stakeholders, etc. (workbook: `docs/SPX_Demo_Data_Workbook.xlsx`).
2. Use the **Data Load** tab (templates in `data-load/templates`) or `data-load/load_all.ps1` for Projects, Leads, Stakeholders, Insights, Competitors.
3. The feed staging: ConstructConnect leads load as **Staged**; release only on the demo morning with `docs/scripts/release_feed.ps1` (needs the user's say-so; it sends notifications). Reset scripts: `reset_feed.ps1`, `reset_step2.ps1`, `reset_step5.ps1`.
4. NBA demo: edit `data-load/demo-nba/demo_nba_create.apex` (insert the two file texts), run it; remove later with `demo_nba_delete.apex`.
5. `docs/backup/*` are snapshots of the SOURCE org dated 2026-10-22 (contain record Ids from that org). Do not reload them into a new org.
6. After a bulk load as the Migration User (bypass on), recalculate project totals (re-save projects or run a one-off flow).
7. Scripts and templates contain org-specific values (the original username and one Id in `demo_nba_create.apex`, `spxDataLoad.js`, two lead templates). Search for `accenture.com.spx.demo` and `gL` Ids before running.

## 7. Post-deploy activation and checks
- Confirm flows are Active; keep inactive: `CF_Fan_Selection_Before_Spec` validation rule, Brand value "Chicago Fan", ERP value "Chicago Fan ERP", `Brand_Configuration.Cincinnati_Fan` Live = false, Chicago Fan price book. `SPX_Opportunity_Participation` active version has no Chicago Fan branch (add it at Step 6; saved copy `docs/scripts/SPX_Opportunity_Participation_v4_with_ChicagoFan.flow-meta.xml`).
- Lightning pages apply inside the HVAC_Segment app; check app and profile assignments for the three home pages.
- Duplicate and matching rules active (alert only).
- Refresh dashboards (HVAC Segment, SPX Executive): the Executive dashboard runs as the viewing user, and its Project Name filter is a static list of 27 names.
- Sharing: verify Project OWD = Public Read/Write (internal), Lead Private, Opportunity Private, Project Intelligence Private.
- Smoke tests (as the right persona, with approval): New Lead from a Project; ConstructConnect lead intake after releasing one lead; Recommend Next Actions on the DEMO NBA project; data load as `spxinteg`.

## 8. Rollback and safety
- A sandbox: if a phase goes wrong, refresh or recreate the sandbox rather than repairing in place. Keep the source org untouched.
- Metadata deploy is not transactional across phases; record which phases ran.
- Never run destructive changes against the source org from this plan.

## 9. Known open items carried over (not blockers)
Lead "insufficient access rights on object id" for the Integration user (hypothesis: Lead OWD Private after intake reassigns owner; proposed View All/Modify All on Lead in `SPX_Data_Load`, not approved); John Leader dashboard retest; Risk report row-count discrepancy; browser testing of most 2026-11-04 to 2026-11-05 deployments; per-brand strategic thresholds (all 100,000,000).
