@echo off
echo =========================
echo Godot Project Check
echo =========================

C:\Godot\godot.exe --headless --path .

if %ERRORLEVEL% neq 0 (
    echo FAILED
    exit /b 1
)

echo OK