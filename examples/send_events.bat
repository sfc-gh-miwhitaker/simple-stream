@echo off
REM ============================================================================
REM Snowpipe Streaming - Event Sender Demo (Windows)
REM 
REM PURPOSE: Demonstrate end-to-end data ingestion to Snowflake using JWT auth
REM USAGE:   send_events.bat
REM 
REM REQUIREMENTS:
REM   - Python 3.7+
REM   - pip install PyJWT cryptography requests
REM   - rsa_key.p8 file in same directory
REM   - Account credentials (see configuration below)
REM ============================================================================

setlocal enabledelayedexpansion

REM ============================================================================
REM CONFIGURATION - Update these values from sql/07_api_handoff.sql output
REM ============================================================================

set ACCOUNT_ID=YOUR_ORG-YOUR_ACCOUNT
set USERNAME=sfe_ingest_user
set PRIVATE_KEY_PATH=rsa_key.p8

REM Convert underscores to hyphens and to lowercase for URL (Snowflake requires this)
set ACCOUNT_URL=%ACCOUNT_ID:_=-%
call :LCase ACCOUNT_URL
set PIPE_ENDPOINT=https://%ACCOUNT_URL%.snowflakecomputing.com/v1/data/pipes/SNOWFLAKE_EXAMPLE.RAW_INGESTION.sfe_badge_events_pipe/insertRows
goto :skip_lcase

:LCase
for %%L IN (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z) DO SET %1=!%1:%%L=%%L!
exit /b

:skip_lcase

REM ============================================================================
REM Validate prerequisites
REM ============================================================================

echo ================================================================
echo Snowpipe Streaming Event Sender
echo ================================================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.7+
    exit /b 1
)

REM Check private key
if not exist "%PRIVATE_KEY_PATH%" (
    echo ERROR: Private key not found at %PRIVATE_KEY_PATH%
    echo Place rsa_key.p8 in the same directory as this script
    exit /b 1
)

REM Check configuration
if "%ACCOUNT_ID%"=="YOUR_ORG-YOUR_ACCOUNT" (
    echo ERROR: ACCOUNT_ID not configured
    echo Edit this script and update ACCOUNT_ID with your Snowflake account
    exit /b 1
)

echo [OK] Python found
echo [OK] Private key found: %PRIVATE_KEY_PATH%
echo [OK] Account ID: %ACCOUNT_ID%
echo.

REM ============================================================================
REM Check Python dependencies
REM ============================================================================

echo Checking Python dependencies...
python -c "import jwt, cryptography, requests" 2>nul
if errorlevel 1 (
    echo Missing dependencies. Installing...
    pip install PyJWT cryptography requests
)
echo [OK] Dependencies ready
echo.

REM ============================================================================
REM Run Python event sender
REM ============================================================================

python -c "exec(open('send_events_impl.py').read())" "%ACCOUNT_ID%" "%USERNAME%" "%PRIVATE_KEY_PATH%" "%PIPE_ENDPOINT%"
if errorlevel 1 (
    echo.
    echo Demo failed. Check errors above.
    exit /b 1
)

echo.
echo ================================================================
echo Demo Complete
echo ================================================================
exit /b 0

