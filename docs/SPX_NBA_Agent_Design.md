# Next Best Action (NBA) agent: design (DRAFT, not built)

Date: 2026-11-04. Status: for sign-off. Nothing here has been built or deployed.

## 1. Starting point (checked in the org)
- `Next_Best_Action__c`: Name (label "Action"), Description__c, Due_Date__c, Project__c (lookup), Status__c, standard Owner. 2 records. Sharing ReadWrite. Related list on the Project page.
- Agent `SPX_Segment_Assistant` (v4, active), flows `SPX_Agent_Lead_Context`, `SPX_Agent_Get_Feed_Leads`, `SPX_Agent_Notify_Brand_Leader`, prompt template `SPX_Lead_Summary`, permission set `SPX_Agentforce_User`. Reuse these patterns.
- No files are attached to any Project today (0 ContentDocumentLinks). Spec files and guidance must be created for the demo.
- Rule from earlier work: the demo is configuration only, except the demo-only Data Load tab. A small Apex action is needed only for reading file text (section 3).

## 2. Recommended design in one view
1. **Gather**: one autolaunched flow, `SPX_NBA_Context`, takes a Project Id and returns one text block with everything the agent must review (section 3).
2. **Reason**: a prompt template, `SPX_NBA_Recommendations`, takes the context plus the guidance text and returns a JSON list of 3 to 5 actions, each with action title, description, due in days, priority, brand, rationale and evidence ("Competitor Marley named in spec section 2.3").
3. **Create**: a flow, `SPX_NBA_Create`, writes the actions as NBA records. It skips an action that matches an open one and marks superseded ones.
4. **Invoke** (both, built in this order):
   - **On demand (build first):** a "Recommend Next Actions" button on the Project page and an agent action on the segment assistant ("what should I do next on Lakemont?"). The user sees the proposed list and accepts, edits or drops each one before records are created.
   - **Automatic (second step):** a scheduled or record-triggered run when a project changes stage or gets a new lead, insight or file. It creates records as Status "Suggested" so a person still accepts them.
5. **Show**: the existing related list, plus new fields and a Suggested / Open / Done / Dismissed status flow (section 4).

## 3. What the agent reads (your six items)
| Your item | Source | Mechanism |
|---|---|---|
| 1 Project details | Project__c | Get Records in `SPX_NBA_Context` |
| 2 Opportunities and child records | Opportunity, Opportunity_Competitor__c, Tasks and Events on the opportunity | Get Records, collections joined to text |
| 3 Leads and child records | Lead (brand, BOD status, potential, status), Tasks on leads | Get Records |
| 4 Current NBA | Next_Best_Action__c on the project | Get Records, so the agent does not repeat itself |
| 5 Child records | Project_Intelligence__c (risks, insights, conflicts), Project_Relationship__c (stakeholders, status, brand relationships), Opportunity_Competitor__c, Tasks and Events, Files | Get Records |
| 6 Spec and guidance files | Files on the Project (ContentDocumentLink) and a guidance file in a Library | Apex invocable action `SPX_NBA_ReadFiles` reads the text of `.txt` / `.md` files. Flows cannot read file bodies |

Limits to accept for the demo:
- File text is capped (about 20,000 characters per file, 5 files) to fit the prompt. Longer files are truncated and the agent says so.
- Only text files are read. A PDF or Word spec would need a conversion step, so demo spec files are `.txt` or `.md`. (Real PDF reading needs Data Cloud or a document-AI service. Out of scope.)
- Guidance for the agent ("see more, win more" rules: for example "if the BOD is not secured and a Strategic project passes design, recommend an engineer meeting") lives in one `NBA_Agent_Guidance.md` file, or as custom metadata rows, so it can be edited without a deploy. I recommend the file, since you described it as "training guidance".
- Visibility: the context flow runs in system mode, so it can read records the person cannot. I would filter out Project Intelligence marked not shared (Share_with_Project__c) when the output is shown to users.

## 4. How NBA shows up (proposed fields, not yet added)
- Priority (High, Medium, Low)
- Rationale (long text), Evidence (long text)
- Source (Agent, Manual)
- Brand (Brand value set) and Opportunity (optional lookup)
- Status values: Suggested, Open, In Progress, Done, Dismissed
- Generated_On (date time) and Run Id (to group one run)
- Owner: the Project's Segment Coordinator or the segment lead who invoked the run (decision below)
- Display: related list on Project (add Priority, Status, Due), the same related list on the Opportunity page filtered by brand, and an "Open actions" count on the Project highlights. A card with Accept / Dismiss buttons is a later nicety; the first version uses list view and the screen-flow review step.

## 5. Demo data plan
- One new project with one opportunity for one brand (brand to be chosen), 2 leads (one other brand), 3 stakeholders (engineer, owner, GC, one with Status Pending), 2 competitors with brands, 4 insights (2 risks, 1 channel conflict, 1 insight), 3 tasks (one overdue), a BOD status of Pending, and 2 files: `Spec_Section_23_Water_Treatment.md` (names a competing brand and a spec clause that favors it) and `NBA_Agent_Guidance.md`.
- Load it through the existing Data Load tab where possible (projects, leads, stakeholders, insights, competitors). The opportunity, tasks and files are created by script or by hand.
- Expected NBAs for the demo, for example: "Meet the engineer about spec section 2.3 before the bid date", "Submit a substitution request, Marley named in spec", "Confirm the pending stakeholder", "Close the overdue site-visit task". These come from the data, not hard-coded.
- Created as test data in the org, with names starting "DEMO NBA" so they can be removed later.

## 6. Decisions needed before build
1. Invocation: on demand first with automatic later (recommended), on demand only, or automatic only.
2. Brand for the demo project.
3. Owner of created NBAs: invoking user (recommended), project Segment Coordinator, or a fixed segment lead.
4. Files: text spec and guidance files for the demo (recommended), or you supply real PDFs and accept the extra conversion work.
5. Agent output goes to "Suggested" until a person accepts (recommended), or creates "Open" records straight away.

## 7. Risks
- The agent can only be as good as the data and guidance. Thin data gives generic actions.
- Prompt size: a big project (many opportunities and insights) may need trimming rules (newest first, caps per object).
- Cost and latency: each run is one prompt call, roughly 10 to 30 seconds. Automatic runs on every change would be noisy, so use change-based triggers with a daily cap.
- Nothing in this design has been tested. The `SPX_Agent_Notify_Brand_Leader` flow was never run live, so end-to-end agent actions in this org are unproven for write actions.

## 8. Build order (after sign-off, each deploy needs your approval)
1. NBA fields and layouts, permissions.
2. `SPX_NBA_ReadFiles` Apex action plus test.
3. `SPX_NBA_Context`, prompt template, `SPX_NBA_Create`.
4. Recommend button (screen flow) and agent action; publish a new agent version.
5. Demo data and files; run, review output, tune the guidance.
6. Optional: automatic trigger.

## 9. Decisions recorded 2026-11-04
1. Invocation: on demand first (button on Project plus agent action, review before create), automatic later.
2. Demo brand: Strobic (RSM trsm / Tony). Strobic has no Brand Leader user, so brand-leader tasks fall back to the owner. Strobic-specific opportunity fields (Exhaust_Dispersion_Study_Status__c, Lab_Exhaust_Application_Class__c) should be filled on the demo opportunity so the spec file can reference a lab exhaust study.
3. Owner of created NBAs: the user who runs it.
4. Files: I write text spec and guidance files (.md), attached to the demo project.
5. Status flow: Suggested, then Open after acceptance (default from the design).
Next: user approval to start build step 1 (fields, layouts, permissions). Nothing built yet.

## 10. Built and deployed 2026-11-04 (what is actually in the org)
Changes from the design above:
- **No context or create flows.** One Apex class, `SPX_NBA_Service` (with sharing), does context gathering, the prompt call, JSON parsing and saving. `SPX_NBA_ReadFiles` reads file text (txt, md, csv, json; 5 files, 20,000 characters each; guidance file `NBA_Agent_Guidance*` returned separately). Tests: `SPX_NBA_ServiceTest` (7), `SPX_NBA_ReadFilesTest` (4), all pass (run with `sf apex run test`, the deploy summary shows 0 tests).
- **Prompt template** `SPX_NBA_Recommendations` (inputs Context and Guidance, text; JSON-only answer; small default model). A deployed template needs `<activeVersionIdentifier>` equal to its `<versionIdentifier>` (retrieve it from the org to get the value) or the call fails with "No active template version".
- **NBA object:** new fields Priority, Source (Agent/Manual), Rationale, Evidence, Brand, Opportunity, Generated_On, Run_Id; Status adds Suggested and Dismissed (Not Started acts as Open). Segment lead permission set `SPX_Next_Best_Action_Segment_Lead` has edit on the new fields and access to both classes; Admin and the four SPX profiles have field read (Admin edit).
- **Invoke:** Project quick action "Recommend Next Actions" (screen flow `SPX_Recommend_Next_Actions`, calls Apex, shows result), and agent topic `next_actions` (flow `SPX_Agent_Recommend_Actions`, confirm first). Agent version 5 is active (v4 inactive). Flow access granted to Admin and the 4 SPX profiles.
- **Reliability fixes in the service:** the context ends with an "ITEMS THAT NEED AN ACTION" checklist built in code (uncontacted leads, overdue tasks, Pending stakeholders, competitors named in spec, Risk and Channel Conflict intelligence); leads are labelled with the contact and "SPX lead owner" separately; it asks the model again (up to 3 tries) if fewer than 4 actions come back; duplicate titles of open actions are skipped; unknown brand or priority values are cleaned; the two Strobic opportunity fields (Exhaust_Dispersion_Study_Status__c, Lab_Exhaust_Application_Class__c) are only read when the running user can see them (FLS; only trsm has them).
- **Gotchas found:** the Lead record type default Lead Source "Rep Entered" triggers SPX_Lead_intake in tests and scripts (set LeadSource explicitly, for example Rep Firm); Project_Intelligence_Type__c depends on Insight_Type__c (only "Project Intelligence" allows Risk, Channel Conflict, Insight); `sf agent activate` prompts unless you pass `--version`.
- **Demo data** (`data-load\demo-nba\`): `demo_nba_create.apex` (builds project DEMO-NBA-0001, Strobic opportunity, 2 leads, 3 stakeholders, 2 competitors, 4 intelligence records, 3 tasks, 2 files; replace the two placeholders with file text first, see how it was run), `demo_nba_delete.apex` (removes everything), the spec and guidance `.md` files. Spec file version 2 in the org states the substitution deadline as June 5, 2027. The 6 test suggestions from the first runs were deleted. Guidance file is linked to the demo project only (a shared library would be needed for other projects).
- **Status 2026-11-04:** probes returned 5 good actions twice; the button path ran once end to end (created 6 actions). Not yet tested: re-run after the final fixes through the button, and the agent topic in chat.
