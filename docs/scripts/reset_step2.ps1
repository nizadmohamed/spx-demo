# SPX demo: reset Scenario 2 (ERP mapping) after the live merge.
# Recreates ARDENT BLDRS INC as the Integration User with duplicate rules active (so a Duplicate Record Set
# is created) and moves ERP cross-reference PK|004417 back under it.
# Requires CLI aliases: spx-demo (admin) and spx-integ (spxinteg, authorized via sf org login web).
param([string]$Org = 'spx-demo', [string]$IntegOrg = 'spx-integ')
# 1) remove the account if it still exists (cross-reference link is cleared automatically)
$old = (sf data query -o $Org -q "SELECT Id FROM Account WHERE External_ID__c = 'A-ERP-4417'" --json | ConvertFrom-Json).result.records
foreach ($x in $old) { sf data delete record -o $Org -s Account -i $x.Id | Out-Null }
Write-Output "Removed existing A-ERP-4417: $(@($old).Count)"
# 2) recreate as the Integration User, allow save so the possible-match rule creates the Duplicate Record Set
$body = @{ Name='ARDENT BLDRS INC'; AccountSource='Patterson-Kelley ERP'; BillingStreet='4100 Arlington Ln'; BillingCity='Columbus'; BillingState='OH'; BillingPostalCode='43219'; Phone='(614) 555-0190'; External_ID__c='A-ERP-4417' } | ConvertTo-Json -Compress
$res = $body | sf api request rest '/services/data/v68.0/sobjects/Account' -X POST --body - -H 'Sforce-Duplicate-Rule-Header: allowSave=true' -H 'Content-Type: application/json' -o $IntegOrg | ConvertFrom-Json
Write-Output "Created account: $($res.id) success=$($res.success)"
# 3) move PK|004417 back under it (the ERP flow recreates the Brand Relationship)
$erp = (sf data query -o $Org -q "SELECT Id FROM ERP_Cross_Reference__c WHERE ERP_Key__c = 'PK|004417'" --json | ConvertFrom-Json).result.records[0].Id
sf data update record -o $IntegOrg -s ERP_Cross_Reference__c -i $erp -v "Account__c=$($res.id)" | Out-Null
Write-Output "Moved PK|004417 under the new account."
# 4) report
$drs = (sf data query -o $Org -q "SELECT COUNT() FROM DuplicateRecordSet" --json | ConvertFrom-Json).result.totalSize
Write-Output "Duplicate Record Sets in org: $drs"
