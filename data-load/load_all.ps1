<#
 SPX demo CSV loader. Run from C:\dev\spx-demo\data-load.
 Examples:
   .\load_all.ps1                      # all five, in dependency order
   .\load_all.ps1 -Only Leads,Competitors
   .\load_all.ps1 -Dir C:\my\csvs -Org spx-demo -WhatIf
 CSV files are looked up by name in -Dir (default .\templates). Delete the sample rows first.
 Project uses its external ID (CC_Project_ID__c), so re-running updates, not duplicates. Project Reference matching is Data Load tab only.
 Leads here always insert (matching on CC Project ID is only done by the Data Load tab in Salesforce).

 Stakeholders, Insights, Competitors have no external ID, so re-running creates new rows.
#>
param(
  [string[]]$Only,
  [string]$Dir = (Join-Path $PSScriptRoot 'templates'),
  [string]$Org = 'spx-demo',
  [switch]$WhatIf
)
$steps = @(
  @{Key='Projects';     File='1_Project_Enrich.csv';      Object='Project__c';              Ext='CC_Project_ID__c'},
  @{Key='Leads';        File='2_Leads.csv';               Object='Lead';                    Ext=$null},
  @{Key='Stakeholders'; File='4_Project_Stakeholders.csv';Object='Project_Relationship__c'; Ext=$null},
  @{Key='Insights';     File='3_Project_Insights.csv';    Object='Project_Intelligence__c'; Ext=$null},
  @{Key='Competitors';  File='5_Competitors.csv';         Object='Opportunity_Competitor__c';Ext=$null}
)
foreach ($s in $steps) {
  if ($Only -and ($Only -notcontains $s.Key)) { continue }
  $f = Join-Path $Dir $s.File
  if (-not (Test-Path $f)) { Write-Warning "Skip $($s.Key): $f not found"; continue }
  if (@(Import-Csv $f).Count -eq 0) { Write-Warning "Skip $($s.Key): no rows"; continue }
  Write-Host "== $($s.Key) -> $($s.Object)" -ForegroundColor Cyan
  if ($s.Key -eq 'Projects' -and (@((Import-Csv $f)[0].PSObject.Properties.Name) -contains 'Project_Reference__c')) { Write-Warning 'Project_Reference__c matching works only in the Data Load tab. The CLI upserts on CC_Project_ID__c; remove the Project_Reference__c column.'; continue }
  # Normalise line endings (mixed CRLF/LF makes Bulk API reject the file) via a temp copy
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("spx_" + $s.File)
  $text = ([IO.File]::ReadAllText($f) -replace "`r`n","`n" -replace "`r","`n").TrimEnd("`n") + "`n"
  [IO.File]::WriteAllText($tmp, $text, (New-Object Text.UTF8Encoding $false))
  $f = $tmp; $le = 'LF'
  if ($s.Ext) { $cmd = @('data','upsert','bulk','-s',$s.Object,'-f',$f,'-i',$s.Ext,'-o',$Org,'--line-ending',$le,'--wait','10') }
  else        { $cmd = @('data','import','bulk','-s',$s.Object,'-f',$f,'-o',$Org,'--line-ending',$le,'--wait','10') }
  if ($WhatIf) { Write-Host "sf $($cmd -join ' ')"; continue }
  & sf @cmd
  if ($LASTEXITCODE -ne 0) { Write-Warning "$($s.Key) reported errors; continuing." }
}
