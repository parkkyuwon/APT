@echo off
REM ==================================================================
REM APT EV 충전 — BlueStacks 에 release APK 직접 설치 (Hot reload 없음)
REM ==================================================================

chcp 65001 >nul
setlocal

set ADB="C:\android-sdk\platform-tools\adb.exe"
set APK_PATH=D:\vsCodeProg\APT-APP\build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK_PATH%" (
    echo [ERROR] APK 파일이 없습니다: %APK_PATH%
    echo flutter build apk --release 를 먼저 실행하세요.
    pause
    exit /b 1
)

echo ▶ BlueStacks ADB 연결...
%ADB% connect 127.0.0.1:5555 2>&1
%ADB% connect 127.0.0.1:5565 2>&1

echo.
echo ▶ 연결된 기기:
%ADB% devices

echo.
echo ▶ APK 설치 중... (재설치 -r, 다운그레이드 허용 -d)
%ADB% install -r -d "%APK_PATH%"

if errorlevel 1 (
    echo.
    echo [ERROR] 설치 실패. BlueStacks 가 켜져 있는지 + ADB 가 활성화되었는지 확인하세요.
) else (
    echo.
    echo ✅ 설치 완료. BlueStacks 홈 화면에서 "APT EV 충전" 아이콘 확인.
)

pause
endlocal
