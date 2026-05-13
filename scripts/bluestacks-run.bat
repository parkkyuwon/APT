@echo off
REM ==================================================================
REM APT EV 충전 — BlueStacks 에서 Flutter 앱 실행 (개발 모드)
REM
REM 사전 준비:
REM   1. BlueStacks 실행
REM   2. BlueStacks 설정 → 고급 → ADB 사용 ON
REM   3. 본 스크립트가 ADB 자동 연결 → flutter run 시작
REM ==================================================================

chcp 65001 >nul
setlocal

set ADB="C:\android-sdk\platform-tools\adb.exe"
set FLUTTER="C:\src\flutter\bin\flutter"

REM Phase 5 에서 정한 한글 사용자명 우회 환경변수
set PUB_CACHE=C:\pub-cache
set GRADLE_USER_HOME=C:\gradle-user
set ANDROID_SDK_ROOT=C:\android-sdk
set ANDROID_HOME=C:\android-sdk

echo ▶ BlueStacks ADB 연결 시도 (5555 포트)...
%ADB% connect 127.0.0.1:5555 2>&1
echo.
%ADB% connect 127.0.0.1:5565 2>&1
echo.

echo ▶ 연결된 기기 목록:
%ADB% devices

echo.
echo ▶ Flutter 디바이스 인식 확인:
%FLUTTER% devices

echo.
echo ▶ APT EV 충전 앱 실행 (debug, hot-reload 가능)
echo    프로덕션 백엔드 사용: https://apt-ev-charging.vercel.app
echo.

%FLUTTER% run ^
    --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app ^
    --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com ^
    --dart-define=APP_ENV=prod

endlocal
