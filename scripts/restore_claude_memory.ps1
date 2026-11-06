<#
Restores the Claude Code project memory saved in .claude/memory into the memory folder
Claude Code uses on THIS machine for THIS project path.

Usage (PowerShell, from the repo root):
  .\scripts\restore_claude_memory.ps1

Claude Code stores project memory in:  ~\.claude\projects\<project-path-with-separators-replaced-by-dashes>\memory
For C:\dev\spx-demo that folder is     C--dev-spx-demo. If you clone to another path, the folder name changes;
this script derives it from the repo location, so just run it from the clone.
Existing files with the same name are overwritten (a .bak copy is kept).
#>
$repo = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repo '.claude\memory'
if (-not (Test-Path $src)) { throw "Not found: $src" }

# Claude Code encodes the absolute path by replacing ':' '\' '/' '.' with '-' (C:\dev\spx-demo -> C--dev-spx-demo)
$encoded = ($repo -replace '[:\\/\.]', '-')
$dest = Join-Path $HOME ".claude\projects\$encoded\memory"
New-Item -ItemType Directory -Force $dest | Out-Null

Get-ChildItem $src -File | ForEach-Object {
  $target = Join-Path $dest $_.Name
  if (Test-Path $target) { Copy-Item $target "$target.bak" -Force }
  Copy-Item $_.FullName $target -Force
  Write-Host "restored $($_.Name)"
}
Write-Host "Memory restored to $dest"
Write-Host "Start Claude Code from $repo. If it does not show the memory, open /memory to check the folder name it uses."
