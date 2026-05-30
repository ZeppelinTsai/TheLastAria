@echo off
echo =========================
echo Godot Project Check
echo =========================

C:\Godot\godot.exe --headless --path . --quit-after 1

if %ERRORLEVEL% neq 0 (
    echo FAILED
    exit /b 1
)

echo OK
