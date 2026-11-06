# SPX demo: reset Scenario 5 (quote and price capture).
# Stops sync, deletes quotes and opportunity products on Lakemont East Tower - Ingenia, and restores Amount to $3,350,000.
param([string]$Org = 'spx-demo')
$oid = (sf data query -o $Org -q "SELECT Id FROM Opportunity WHERE External_ID__c = 'O-ET-ING'" --json | ConvertFrom-Json).result.records[0].Id
sf data update record -o $Org -s Opportunity -i $oid -v "SyncedQuoteId=" | Out-Null
$q = (sf data query -o $Org -q "SELECT Id FROM Quote WHERE OpportunityId = '$oid'" --json | ConvertFrom-Json).result.records
foreach ($x in $q) { sf data delete record -o $Org -s Quote -i $x.Id | Out-Null }
$l = (sf data query -o $Org -q "SELECT Id FROM OpportunityLineItem WHERE OpportunityId = '$oid'" --json | ConvertFrom-Json).result.records
foreach ($x in $l) { sf data delete record -o $Org -s OpportunityLineItem -i $x.Id | Out-Null }
sf data update record -o $Org -s Opportunity -i $oid -v "Amount=3350000" | Out-Null
Write-Output "Quotes deleted: $(@($q).Count) ; products deleted: $(@($l).Count) ; Amount reset to 3350000"
