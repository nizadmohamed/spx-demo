# SPX demo: reset Scenario 1 (lead from feed) after a run.
# 1) deletes the Westfield project, any Westfield opportunity, and the contact Rachel Tran
# 2) puts all 12 feed leads back to Staged (re-creates any that were converted or deleted)
# Run from the repo root (C:\dev\spx-demo).
param([string]$Org = 'spx-demo')
function Remove-SpxRecords($obj,$where){
  $r = (sf data query -o $Org -q "SELECT Id FROM $obj WHERE $where" --json | ConvertFrom-Json).result.records
  foreach ($x in $r) { sf data delete record -o $Org -s $obj -i $x.Id | Out-Null }
  Write-Output "$obj deleted: $(@($r).Count)"
}
Remove-SpxRecords 'Opportunity' "Name LIKE '%Westfield%'"
Remove-SpxRecords 'Contact' "FirstName = 'Rachel' AND LastName = 'Tran'"
Remove-SpxRecords 'Lead' "LeadSource = 'ConstructConnect' AND IsConverted = true"
Remove-SpxRecords 'Project__c' "Name = 'Westfield Regional Medical Center'"
$r = sf data upsert bulk -o $Org -s Lead -f docs\data\feed_leads_reset.csv -i External_ID__c --wait 15 --json 2>&1 | Out-String
Write-Output 'Feed leads reset to Staged.'
