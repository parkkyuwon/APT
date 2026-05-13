@echo off
REM Setup Flutter Environment Script

chcp 65001 >nul
setlocal enabledelayedexpansion

cls
color 0A

echo.
echo ================================================================
echo    Flutter PC Environment Setup Script
echo ================================================================
echo.

REM Check Admin Rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Admin privileges required!
    echo Run this script as Administrator.
    pause
    exit /b 1
)

echo [CHECK] PC Environment Status
echo.

REM 1. Git Check
echo [1/3] Git Status...
git --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=3" %%i in ('git --version') do set GIT_VER=%%i
    echo    OK: Git !GIT_VER!
) else (
    echo    FAIL: Git not installed
    echo    Download: https://git-scm.com/download/win
    pause
)
echo.

REM 2. Java Check
echo [2/3] Java Status...
java -version >nul 2>&1
if %errorlevel% equ 0 (
    echo    OK: Java installed
) else (
    echo    FAIL: Java not installed
    echo    Download: https://www.oracle.com/java/technologies/downloads/
    echo    Please install Java 17 or later
    pause
)
echo.

REM 3. Flutter Check
echo [3/3] Flutter Status...
if exist "C:\src\flutter\bin\flutter.bat" (
    echo    OK: Flutter installed
    echo    Path: C:\src\flutter
) else (
    echo    FAIL: Flutter not installed
    echo    Starting automatic installation... ^(5-10 min^)
    echo.
    
    REM Create C:\src directory
    if not exist "C:\src" mkdir C:\src
    
    REM Download Flutter
    cd /d C:\src
    echo    Downloading Flutter SDK...
    git clone https://github.com/flutter/flutter.git -b stable flutter
    
    if !errorlevel! equ 0 (
        echo    SUCCESS: Flutter installed
    ) else (
        echo    ERROR: Flutter installation failed
        pause
        exit /b 1
    )
)
echo.

REM Set Environment Variables
echo [SETUP] Setting environment variables...

setx ANDROID_SDK_ROOT "%LOCALAPPDATA%\Android\sdk"
echo    ANDROID_SDK_ROOT set

REM Add Flutter to PATH
set "CURRENT_PATH=%PATH%"
echo !CURRENT_PATH! | findstr "flutter" >nul
if %errorlevel% neq 0 (
    setx PATH "C:\src\flutter\bin;!CURRENT_PATH!"
    echo    Flutter PATH added
) else (
    echo    Flutter PATH already set
)

REM Update current session PATH
set "PATH=C:\src\flutter\bin;!PATH!"

echo.
echo ================================================================
echo    Verification
echo ================================================================
echo.

echo Checking Flutter version...
C:\src\flutter\bin\flutter.bat --version
echo.

echo Running Flutter doctor...
echo.
C:\src\flutter\bin\flutter.bat doctor

echo.
echo ================================================================
echo    Setup Complete!
echo ================================================================
echo.
echo Next steps:
echo   1. Open a new PowerShell window
echo   2. Navigate to project: cd d:\vsCodeProg\APT-APP
echo   3. Run app: flutter run
echo.
echo Or use auto tool:
echo   .\android-run.bat
echo.

pause
