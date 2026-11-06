# SPX HVAC CRM demo (Salesforce DX)

A configuration-first Salesforce build for a seven-scenario sales demo for SPX Technologies' HVAC segment: one Project anchors leads and opportunities from several brands, with routing, roll-ups, role-based visibility, ERP/duplicate handling, quotes, brand onboarding, dashboards and Agentforce agents.

| Item | Detail |
|---|---|
| Source API version | 67.0 |
| Metadata | `force-app/main/default` (12 custom objects, 34 flows, 6 Apex classes, 1 LWC, 12 permission sets, 5 profiles, dashboards, reports, flexipages, agent bundles) |
| Custom code | Only the CSV Data Load tab and the Next Best Action service; everything else is configuration |

## Start here
- `CLAUDE.md`: rules and tooling notes for Claude Code (also useful to humans)
- `docs/SPX_Oral_Prep_Guide.md`: what was built and how (Word copy alongside)
- `docs/SPX_Session_Resume_Context.md`: dated state log, open items
- `docs/SPX_New_Sandbox_Deployment_Plan.md`: deploy to a new sandbox
- `docs/SPX_Developer_Handover_Pack.md`: original build specification
- `.claude/README.md`: restore the Claude Code memory on another machine

## Quick commands
```powershell
sf org login web --alias spx-new --set-default
sf project deploy start --source-dir force-app --target-org spx-new --dry-run   # validate only
```
Do not deploy blindly: read the deployment plan first. Some metadata is org-specific and some components must stay inactive until demo Step 6.

## Not in this repository
Client RFP files, org credentials, and conversation transcripts.
