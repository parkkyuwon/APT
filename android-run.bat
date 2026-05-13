@echo off
REM ============================================
REM APT-APP Android Quick Run Script
REM ============================================
REM This script simplifies running the app on Android emulator or device

chcp 65001 >nul
setlocal enabledelayedexpansion

:main
cls
echo.
echo ============================================================
echo     APT EV Charging - Android Quick Run Tool
echo ============================================================
echo.
echo === Android Run Options ===
echo.
echo 1. Check connected devices and emulators
echo 2. Start emulator (Pixel_6_API_33)
echo 3. Run app in debug mode
echo 4. Run app in release mode
echo 5. Build debug APK
echo 6. Build release APK
echo 7. Build App Bundle (Play Store)
echo 8. Install APK on connected device
echo 9. View logs
echo 10. Full workflow (clean, build, run)
echo 11. Exit
echo.
set /p choice="Select: "

if "%choice%"=="1" goto devices
if "%choice%"=="2" goto start_emulator
if "%choice%"=="3" goto run_debug
if "%choice%"=="4" goto run_release
if "%choice%"=="5" goto build_debug
if "%choice%"=="6" goto build_release
if "%choice%"=="7" goto build_bundle
if "%choice%"=="8" goto install_apk
if "%choice%"=="9" goto view_logs
if "%choice%"=="10" goto full_workflow
if "%choice%"=="11" goto end
goto invalid

:devices
echo.
echo Checking connected devices and emulators...
echo.
flutter devices
echo.
adb devices
pause
goto main

:start_emulator
echo.
echo Emulator list:
emulator -list-avds
echo.
set /p emulator_name="Enter emulator name (default: Pixel_6_API_33): "
if "!emulator_name!"=="" set emulator_name=Pixel_6_API_33
echo.
echo Starting emulator: !emulator_name!
start emulator -avd !emulator_name!
echo.
echo Emulator started. Please wait 30-60 seconds for boot...
echo.
pause
goto main

:run_debug
echo.
echo Running app in debug mode...
echo.
cd d:\vsCodeProg\APT-APP
flutter run
pause
goto main

:run_release
echo.
echo Running app in release mode...
echo.
cd d:\vsCodeProg\APT-APP
flutter run --release
pause
goto main

:build_debug
echo.
echo Building debug APK...
echo.
cd d:\vsCodeProg\APT-APP
flutter build apk --debug
if %errorlevel% equ 0 (
    echo.
    echo Build successful!
    echo APK: build\app\outputs\apk\debug\app-debug.apk
) else (
    echo.
    echo Build failed! Check log above.
)
pause
goto main

:build_release
echo.
echo Building release APK...
echo.
cd d:\vsCodeProg\APT-APP
flutter build apk --release
if %errorlevel% equ 0 (
    echo.
    echo Build successful!
    echo APK: build\app\outputs\apk\release\app-release.apk
) else (
    echo.
    echo Build failed! Check log above.
)
pause
goto main

:build_bundle
echo.
echo Building App Bundle for Google Play...
echo.
cd d:\vsCodeProg\APT-APP
flutter build appbundle --release
if %errorlevel% equ 0 (
    echo.
    echo Build successful!
    echo AAB: build\app\outputs\bundle\release\app-release.aab
) else (
    echo.
    echo Build failed! Check log above.
)
pause
goto main

:install_apk
echo.
echo Installing APK on connected device...
echo.
echo Available APKs:
if exist "d:\vsCodeProg\APT-APP\build\app\outputs\apk\debug\app-debug.apk" (
    echo 1. Debug APK: d:\vsCodeProg\APT-APP\build\app\outputs\apk\debug\app-debug.apk
)
if exist "d:\vsCodeProg\APT-APP\build\app\outputs\apk\release\app-release.apk" (
    echo 2. Release APK: d:\vsCodeProg\APT-APP\build\app\outputs\apk\release\app-release.apk
)
echo.
set /p apk_choice="Select APK (1 or 2): "
echo.
if "%apk_choice%"=="1" (
    adb install -r d:\vsCodeProg\APT-APP\build\app\outputs\apk\debug\app-debug.apk
) else if "%apk_choice%"=="2" (
    adb install -r d:\vsCodeProg\APT-APP\build\app\outputs\apk\release\app-release.apk
) else (
    echo Invalid selection!
)
pause
goto main

:view_logs
echo.
echo Viewing logs from connected device...
echo.
echo (Press Ctrl+C to stop)
echo.
flutter logs
pause
goto main

:full_workflow
echo.
echo === Full Workflow: Clean, Build, and Run ===
echo.
echo [1/4] Cleaning...
cd d:\vsCodeProg\APT-APP
flutter clean
echo.
echo [2/4] Getting dependencies...
flutter pub get
echo.
echo [3/4] Building debug APK...
flutter build apk --debug
if %errorlevel% neq 0 (
    echo.
    echo Build failed!
    pause
    goto main
)
echo.
echo [4/4] Running app...
flutter run
pause
goto main

:invalid
echo.
echo Invalid selection!
pause
goto main

:end
echo.
echo Program terminated
exit /b 0
