Write-Host ""
Write-Host "=== Validate ==="

Set-Location $PSScriptRoot\..

# Optional formatter
if (Test-Path ".\tools\format_gd.py") {
    Write-Host "Running formatter..."
    python .\tools\format_gd.py
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Formatter failed."
        exit 1
    }
}

# Python syntax validation
Write-Host "Checking Python syntax..."
$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    Write-Host "Python not found in PATH. Skipping Python syntax validation."
} else {
    $pyFiles = Get-ChildItem -Path . -Recurse -Include *.py | Where-Object {
        $_.FullName -notmatch '\\(\.git|build|node_modules|\.venv|venv|env)\\'
    }
    foreach ($py in $pyFiles) {
        Write-Host "  $($py.FullName)"
        python -m py_compile $py.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Python syntax failed on $($py.FullName)."
            exit 1
        }
    }
}

# Godot validation
Write-Host "Running Godot validation..."
if (Test-Path ".\tools\check_godot.ps1") {
    .\tools\check_godot.ps1
} elseif (Test-Path ".\check_godot.bat") {
    .\check_godot.bat
} else {
    Write-Host "No Godot validation script found."
    exit 1
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "BLOCKED"
    exit 1
}

Write-Host ""
Write-Host "PASS"
exit 0