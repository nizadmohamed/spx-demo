# SPX demo CSV load

Order matters: Projects, Leads, Stakeholders, Insights, Competitors (the script does this).
Run: `.\load_all.ps1` (all) or `.\load_all.ps1 -Only Leads,Insights`; add `-WhatIf` to preview.

Templates are in `templates\` (one sample row each, delete before loading). Columns = fields on the demo page layouts.
- Lookups use a business key: `Opportunity__r.External_ID__c`, `Project__r.CC_Project_ID__c`, and for accounts the **Account Number** (`Account__r.AccountNumber`, `Competitor_Account__r.AccountNumber`, `Engineer_of_Record__r.AccountNumber`). If two accounts share a number the row is rejected.
- Project and Lead upsert (safe to re-run). Others always insert.
- Project match (Data Load tab): 1) `CC_Project_ID__c`; 2) if not found, `Project_Reference__c` (e.g. P-01034), then the record is updated with every column in the file, including the CC Project ID; 3) neither found: new Project (reference is auto-assigned, leave the column blank for new rows). A row is rejected if its two keys point at different Projects, or two rows hit the same Project. The CLI script supports only the CC Project ID, so drop the `Project_Reference__c` column there.
- Not loadable (auto-set by flows/formulas): Project on Insights/Competitors, rollups on Project.
- Picklist values must match exactly (e.g. Relationship_Type__c: Owner, Engineer, Mechanical Contractor, Architect, General Contractor, Rep Firm, Architectural Firm, Consulting Engineer).
