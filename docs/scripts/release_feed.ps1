# SPX demo: release the staged ConstructConnect feed (morning of the demo).
# Sets every Staged feed lead to New so the flow SPX_Lead_intake processes them.
# Never run this live in front of the audience.
param([string]$Org = 'spx-demo')
$q = "SELECT Id FROM Lead WHERE LeadSource = 'ConstructConnect' AND Status = 'Staged'"
$ids = (sf data query -o $Org -q $q --json | ConvertFrom-Json).result.records
if (-not $ids) { Write-Output 'No Staged feed leads found.'; exit 0 }
$tmp = Join-Path $env:TEMP 'spx_release_feed.csv'
$ids | ForEach-Object { [pscustomobject]@{ Id = $_.Id; Status = 'New' } } | Export-Csv $tmp -NoTypeInformation
$r = sf data update bulk -o $Org -s Lead -f $tmp --wait 15 --json 2>&1 | Out-String
Write-Output "Released $(@($ids).Count) feed leads."
