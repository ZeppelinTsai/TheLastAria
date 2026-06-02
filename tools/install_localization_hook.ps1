$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$hookPath = Join-Path $repoRoot ".git\hooks\post-commit"
$hookBody = @'
#!/bin/sh
python tools/extract_localization_keys.py --changed HEAD
'@

if (Test-Path $hookPath) {
    $backupPath = "$hookPath.localization-backup"
    Copy-Item -LiteralPath $hookPath -Destination $backupPath -Force
    Write-Output "Backed up existing post-commit hook to $backupPath"
}

Set-Content -LiteralPath $hookPath -Value $hookBody -Encoding utf8
Write-Output "Installed localization post-commit hook: $hookPath"
