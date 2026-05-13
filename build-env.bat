@echo off
REM ============================================
REM APT EV Charging - Environment-aware Build Script
REM Usage:
REM   build-env.bat dev       -> dev 환경으로 debug APK
REM   build-env.bat prod      -> prod 환경으로 release appbundle
REM   build-env.bat run-dev   -> dev 환경으로 flutter run (기기 연결 상태)
REM ============================================

chcp 65001 >nul
setlocal

REM --- 환경별 API_BASE_URL 설정 ---
REM 실제 Vercel 프로덕션 URL은 .vercel/.env.production.local 참고
set DEV_API_BASE_URL=http://10.0.2.2:3000
set PROD_API_BASE_URL=https://apt-ev-charging.vercel.app

REM 웹 클라이언트 ID (APT-Prj/GOOGLE_CLIENT_ID 또는 README.md 참조)
set GOOGLE_WEB_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com

if "%1"=="" (
    echo 사용법: build-env.bat ^<dev^|prod^|run-dev^|run-prod^>
    exit /b 1
)

if "%1"=="dev" goto build_dev
if "%1"=="prod" goto build_prod
if "%1"=="run-dev" goto run_dev
if "%1"=="run-prod" goto run_prod
echo 알 수 없는 인자: %1
exit /b 1

:build_dev
echo [DEV] debug APK 빌드...
flutter build apk --debug ^
    --dart-define=API_BASE_URL=%DEV_API_BASE_URL% ^
    --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID% ^
    --dart-define=APP_ENV=dev
goto end

:build_prod
echo [PROD] release App Bundle 빌드...
flutter build appbundle --release ^
    --dart-define=API_BASE_URL=%PROD_API_BASE_URL% ^
    --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID% ^
    --dart-define=APP_ENV=prod
if %errorlevel%==0 (
    echo.
    echo 완료: build\app\outputs\bundle\release\app-release.aab
)
goto end

:run_dev
echo [DEV] flutter run (debug, dev API)...
flutter run ^
    --dart-define=API_BASE_URL=%DEV_API_BASE_URL% ^
    --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID% ^
    --dart-define=APP_ENV=dev
goto end

:run_prod
echo [PROD] flutter run (profile, prod API)...
flutter run --profile ^
    --dart-define=API_BASE_URL=%PROD_API_BASE_URL% ^
    --dart-define=GOOGLE_CLIENT_ID=%GOOGLE_WEB_CLIENT_ID% ^
    --dart-define=APP_ENV=prod
goto end

:end
endlocal
