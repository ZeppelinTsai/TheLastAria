$ProjectPath = "C:\Users\b131a\Documents\the-last-aria"
$GodotExe = "godot"

Set-Location $ProjectPath

Write-Host "Checking Godot project..."

& $GodotExe --headless --path $ProjectPath --check-only

if ($LASTEXITCODE -ne 0) {
    Write-Host "Godot check failed."
    exit 1
}

Write-Host "Godot check passed."
exit 0