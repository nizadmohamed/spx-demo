# SPX Segment Assistant: Agentforce build sheet

Source: Developer Handover Pack section 9, and SPX_Demo_Clickthrough.html (scenario 1, Lead from feed).
Labelled in the room as "art of the possible, not in Foundation scope". All actions are read only except the confirmed notification. No Apex, LWC or Visualforce.

## Already built (metadata in this project)

| Component | Name | Purpose |
|---|---|---|
| Prompt template (flex, Lead) | `SPX_Lead_Summary` | Summarize this lead: project, owner contact, engineer, why it is yours, potential, other brands |
| Flow | `SPX_Agent_Lead_Context` | Called by the template: sibling brand leads on the project; other SPX project with the same engineer and who holds the BOD there |
| Flow | `SPX_Agent_Get_Feed_Leads` | Returns one text line per released feed lead (not Staged, not converted) |
| Flow | `SPX_Agent_Notify_Brand_Leader` | Sends the brand leader a notification about a project. Inputs: `brandName`, `projectName` |
| Permission set | `SPX_Agentforce_User` | Flow access for the three flows above |

Assigned to 20 users (16 RSM, 1 brand leader, 1 segment leader, Sam Okafor, the admin): licences Agentforce (Default) and Einstein Prompt Templates; permission sets Access Agentforce Default Agent, Prompt Template User, SPX Agentforce User.
Not assigned: SPX_Cincinnati_Fan (no one), SPX_Migration_Bypass (migrate only), integration users.

## Build in Agentforce Builder (Setup, then Agentforce Agents, then New Agent, Employee Agent)

Name: **SPX Segment Assistant**. Description: "Helps SPX HVAC segment reps and segment operations review ConstructConnect feed leads."

Agent-level instructions:
- You only read information. You never create, update, release or convert leads.
- Answer only from the action results. If a value is n/a, say it is not available. Do not invent history.
- Keep answers short, in bullets.

### Topic 1: Lead summary
- Classification: the user asks to summarize a lead, or what they need to know before calling.
- Instructions: When the user is on a lead and asks for a summary, run **Summarize Lead** for the current record and show the result as is. Do not add suggestions to create tasks, emails or records.
- Action: **Prompt template `SPX Lead Summary`**. Input Lead = the record the user is viewing.
- Chip: "Summarize this lead".

### Topic 2: Feed review
- Classification: the user asks about the latest ConstructConnect feed, which projects are strategic, or what was held and why.
- Instructions:
  - Run **Get feed leads** first, then answer from its text only.
  - Group by project. Say how many projects and leads, which are strategic (Strategic = Yes), which were routed (Status New) and which were held.
  - Held reasons: Match result "Already in pursuit" means that brand already has an open opportunity on the project. Match result "Held" means the project did not meet that brand's routing rules (for example the project is still in the Planning phase, earlier than Schematic Design).
  - Never offer to release or run the feed.
- Action: **Flow `SPX Agent Get Feed Leads`** (no inputs; output `feedText`, `leadCount`).
- Chips: "Summarize the latest feed", "Which new projects are strategic?", "What was held, and why?".

### Topic 3: Notify brand leader
- Classification: the user asks to tell a brand leader (for example TAMCO) about a project.
- Instructions: Ask the user to confirm the brand and project name in one sentence and wait for a clear yes. Only after yes run the action. Report the result text. If the user does not say yes, do nothing.
- Action: **Flow `SPX Agent Notify Brand Leader`**. Inputs `brandName` (Ingénia, Cooling, Patterson-Kelley or TAMCO) and `projectName` (exact project name). Turn on "Require user confirmation" if the action settings offer it.
- Chip: "Notify the TAMCO brand leader".

Then **Activate** the agent and check that the Agentforce icon appears in the header for dreyes and sokafor.

## Test script (after the feed is released on a test run, then reset)
1. As dreyes, open a Westfield lead, click "Summarize this lead". Expect: Dublin, OH; $148M Schematic Design strategic; Rachel Tran; Kessler MEP also on Lakemont East Tower with Ingénia and Cooling holding the BOD; Ohio Valley; $2.7M for Ingénia (Ingénia lead only); Cooling and Patterson-Kelley also received leads.
2. As sokafor, "Summarize the latest feed". Expect 4 projects, 12 leads: Westfield 3 New, Buckeye Cooling and TAMCO New, Lakemont 3 held in pursuit, Buckeye Ingénia and PK held in pursuit, Riverbend 2 held.
3. "Notify the TAMCO brand leader" about Buckeye State University Research Building: the agent must ask first. Confirm yes sends one notification.
4. Run reset_feed.ps1 afterwards.

## Known limits
- The HTML line "similar hospitals also bought TAMCO dampers" cannot be produced: there is no similar-project history in the org.
- A lead not yet released (Staged) has no project, territory or potential, so its summary is short. Summaries are meant for released leads.
- No email draft and no task creation, per the Pack.

## Status (2026-10-23)
Agent SPX_Segment_Assistant is published and active (version 2). Source of truth is force-app/main/default/aiAuthoringBundles/SPX_Segment_Assistant. In the Agent Script, flow and prompt-template actions use only a target line (flow://... or generatePromptResponse://...); a source line is for built-in library actions and causes a validation error. Tested through sf agent preview: lead summary, feed summary, held and why, strategic new projects, and the notify confirmation prompt (not confirmed, nothing sent). To change the agent: edit the script, sf agent validate authoring-bundle, sf agent publish authoring-bundle, sf agent activate.
