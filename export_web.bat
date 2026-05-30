@echo off
echo =========================
echo Godot Web Export
echo =========================

if exist build\web (
    rmdir /s /q build\web
)

mkdir build\web

C:\Godot\godot.exe --headless --path . --export-release "Web" build/web/index.html

if %ERRORLEVEL% neq 0 (
    echo FAILED
    echo If the error mentions missing export templates, install Godot 4.6.2 Export Templates in the Godot Editor.
    exit /b 1
)

echo export finished
