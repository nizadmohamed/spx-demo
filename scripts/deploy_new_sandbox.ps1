<#
Phased deploy of the SPX demo metadata to a NEW sandbox.

SAFE BY DEFAULT: without -Execute every phase runs as a validate-only deploy (--dry-run); nothing is changed in the org.
Read docs\SPX_New_Sandbox_Deployment_Plan.md first. Run from the repo root.

Examples
  .\scripts\deploy_new_sandbox.ps1 -TargetOrg spx-new                      # validate all phases (no changes)
  .\scripts\deploy_new_sandbox.ps1 -TargetOrg spx-new -Phase 1             # validate phase 1 only
  .\scripts\deploy_new_sandbox.ps1 -TargetOrg spx-new -Phase 1 -Execute    # REALLY deploy phase 1 (only after approval)

If the target is NOT an SDO-based org, add -SkipManagedPackages to exclude metadata from managed packages
(maps__, FSL__, pi__, cccalendar__) that a non-SDO org does not have. It temporarily swaps .forceignore and restores it.
#>
param(
  [Parameter(Mandatory)] [string] $TargetOrg,
  [int] $Phase = 0,
  [switch] $Execute,
  [switch] $SkipManagedPackages
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$base = 'force-app/main/default'

# Order matters: each phase only depends on earlier ones. Profiles come last because they reference almost everything.
$phases = [ordered]@{
  1 = @('globalValueSets','standardValueSets','objects','customPermissions','roles','groups','customMetadata')
  2 = @('classes','lwc','tabs')
  3 = @('flows','quickActions','matchingRules','duplicateRules','sharingRules','notificationtypes')
  4 = @('permissionsets','profiles')
  5 = @('layouts','flexipages','applications','pathAssistants')
  6 = @('reportTypes','reports','dashboards')
  7 = @('genAiPromptTemplates')
}
# NOT in this script (see the plan): Agentforce agent (sf agent publish/activate), users, permission set assignments, data.

$ignore = Join-Path $root '.forceignore'
$backup = "$ignore.bak"
if ($SkipManagedPackages) {
  Copy-Item $ignore $backup -Force
  Add-Content $ignore "`n# temporary: non-SDO target`n**/maps__*`n**/FSL__*`n**/pi__*`n**/cccalendar__*"
}
try {
  foreach ($n in $phases.Keys) {
    if ($Phase -ne 0 -and $Phase -ne $n) { continue }
    $dirs = $phases[$n] | ForEach-Object { "$base/$_" } | Where-Object { Test-Path $_ }
    $args = @('project','deploy','start','--target-org',$TargetOrg,'--wait','60','--json')
    foreach ($d in $dirs) { $args += @('--source-dir',$d) }
    if (-not $Execute) { $args += '--dry-run' }
    Write-Host ("== Phase {0}: {1} ({2})" -f $n, ($phases[$n] -join ', '), $(if ($Execute) {'DEPLOY'} else {'validate only'}))
    $raw = & sf @args 2>$null
    $i = ($raw -join "`n").IndexOf('{')
    $res = ($raw -join "`n").Substring($i) | ConvertFrom-Json
    $r = $res.result
    Write-Host ("   status: {0}; components {1}/{2}; errors {3}" -f $r.status, $r.numberComponentsDeployed, $r.numberComponentsTotal, $r.numberComponentErrors)
    if ($r.details.componentFailures) {
      $r.details.componentFailures | ForEach-Object { Write-Host ("   FAIL {0} {1}: {2}" -f $_.componentType, $_.fullName, $_.problem) }
      if ($Execute) { throw "Phase $n failed; fix before continuing." }
    }
  }
} finally {
  if ($SkipManagedPackages -and (Test-Path $backup)) { Move-Item $backup $ignore -Force }
}
Write-Host 'Done.'
