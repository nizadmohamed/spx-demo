# SPX HVAC CRM demo: project instructions for Claude Code

Salesforce DX project (API 67.0) for a 7-scenario sales demo for SPX Technologies, HVAC segment, built in a Salesforce SDO sandbox (original org alias `spx-demo`). Metadata is in `force-app/main/default`. Read `docs/SPX_Session_Resume_Context.md` first on any resume (dated updates), then `docs/SPX_Oral_Prep_Guide.md` for the architecture overview and `docs/SPX_New_Sandbox_Deployment_Plan.md` before deploying anywhere new.

## Standing rules (from the user)
- **Always ask for confirmation before making any change to an ORG** (deploys, data changes, user changes, permission changes, deletes, password resets). Pattern: investigate read-only, edit local files, summarise the plan, wait for an explicit "deploy"/"ok"/"run", change the org, verify, report faithfully (including what was not verified).
- Do not work around permission or classifier denials; the user decides.
- Use they/them for people whose pronouns are not stated. The user's email is for identification only.
- Say which source you read. Do not invent field names, logic or data. If sources conflict, stop and ask.
- Do not suggest the Claude in Chrome extension (user declined).

## Do not (unless the user says so)
- Run `docs/scripts/release_feed.ps1` (releases the ConstructConnect feed and sends brand-leader notifications).
- Press any "run feed" button live; activate Chicago Fan components before demo Step 6 (brand value, `Cincinnati_Fan` Brand Configuration Live, `CF_Fan_Selection_Before_Spec`, `SPX_Cincinnati_Fan` permission set assignment).
- Deploy `Opportunity_Golden_Template` flexipage or the Golden Template layout over an EXISTING org without retrieving first (the user edits them in the org). A brand-new org is fine.
- Run `SPX_Agent_Notify_Brand_Leader` live (sends a real notification).
- Grant Fan-only fields (`Opportunity.Fan_Arrangement__c`, `Wheel_Type__c`, `Project__c.CF_Participating__c`) to the System Administrator profile.

## Build principles
- Configuration first. Custom code exists only for two demo-only exceptions: the CSV Data Load tab (LWC `spxDataLoad`, Apex `SPX_DataLoadController`) and the Next Best Action service (`SPX_NBA_Service`, `SPX_NBA_ReadFiles`).
- Brand is data: `Brand_Configuration__mdt`, `Routing_Rule__mdt`, `Opportunity_Task_Template__mdt`. New brand = new record.
- Flows run in system mode and check `NOT({!$Permission.SPX_Bypass_Automation})`. Validation rules check `SPX_Bypass_Validation_Rules`.
- Keep SPX branding (SLDS blue #0176D3, white background).

## Tooling notes (sf CLI v2, PowerShell on Windows)
- Run `sf` from the project root. Long deploys: run in the background (can exceed 2 minutes). `COUNT()` queries need `--json`.
- Profiles: metadata-created fields are NOT auto-granted. Use a partial profile deploy (`--metadata-dir` with `package.xml` plus `profiles\<Name>.profile`) or permission sets. Remove temp dirs afterwards.
- Destructive changes: temp `package.xml` + `destructiveChanges.xml`, `--manifest ... --post-destructive-changes`.
- Picklist values cannot be deleted by deploy. Deploy table may say "Unchanged" yet apply (verify with a query, for example `EntityDefinition`).
- Report types deploy before reports; reports before dashboards. Custom report type referenced as `Name__c` in report XML. Dashboard column form is `Project__c$Field`; dashboards filter badly on checkboxes (use Yes/No text formulas); GET on a dashboard may be cached (refresh with PUT).
- Layout related lists: `OWNER.ALIAS`, `OWNER.FIRST_NAME`, `OWNER.LAST_NAME` accepted; sort field must be a displayed column. Polymorphic Owner formulas need `Owner:User.FirstName`.
- Flow XML: `rightValue` takes raw `<booleanValue>`; use an unset String variable instead of `$GlobalConstant.EmptyString`.
- Agent bundle: edit `.agent`, `sf agent validate authoring-bundle`, `sf agent publish authoring-bundle -n <Name>`, `sf agent activate -n <Name> --version N` (prompts without `--version`). Flow and prompt-template actions use only `target:`, never `source:`. A deployed prompt template needs `activeVersionIdentifier` equal to `versionIdentifier`.
- Flow User checkbox (`UserPermissionsInteractionUser`) is per user and required to see Flow quick actions; set it for every new SPX user.
- `Lead` record type SDO_Lead_Default defaults Lead Source to "Rep Entered", which triggers `SPX_Lead_intake` in tests and scripts: set LeadSource explicitly in test data.
- Python is not reliably available on the original machine; prefer the Edit/Write tools and PowerShell. Bulk CSV files need CRLF.

## Data loader facts
- Lookups are `Rel__r.<key>`; accounts resolve by Account Number; Leads match on CC Project ID + Brand + Market and ignore converted leads; `Security.stripInaccessible` silently drops unwritable fields (loader users need explicit FLS on optional custom fields).
- Templates in `data-load/templates`; CLI twin `data-load/load_all.ps1`; NBA demo data in `data-load/demo-nba/`.

## Memory and moving to another machine
- Claude Code memory for this project is copied in `.claude/memory/`. Restore on a new machine with `scripts/restore_claude_memory.ps1` (see `.claude/README.md`).
- Client RFP files (pdf/pptx/xlsx in `docs/`) are deliberately NOT in the repository.
