---
name: feedback-confirm-org-changes
description: "Always ask the user for confirmation before any change to the Salesforce org (deploys, record updates, permission assignments)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 91784797-669c-4a3d-bac0-3f978fc9d746
  modified: 2026-11-03T05:58:28.840Z
---

Always ask for the user's confirmation before making any change to the ORG (`spx-demo`): deploys, data updates, permission set assignments, profile changes, test records. Read-only queries and retrieves are fine without asking.

**Why:** the user stated this explicitly mid-session (2026-11-02) after I deployed a layout while testing column names without asking.

**How to apply:** prepare changes locally, describe what will be deployed, ask, then deploy. An approval covers the listed scope including fixing deploy errors in those same files. Do not work around auto-mode classifier denials (e.g. destructive deploys, creating test records, session-token API calls); stop and let the user decide. See [[spx-demo-resume-context]].
