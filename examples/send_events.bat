@echo off
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set CONFIG_PATH=%SCRIPT_DIR%config.json

if not exist "%CONFIG_PATH%" (
    echo Config file not found at %CONFIG_PATH%
    echo Copy config.example.json to config.json and update placeholders.
    exit /b 1
)

if exist "%SCRIPT_DIR%\.venv\Scripts\activate.bat" (
    call "%SCRIPT_DIR%\.venv\Scripts\activate.bat"
)

python "%SCRIPT_DIR%send_events_stream.py" --config "%CONFIG_PATH%" %*
