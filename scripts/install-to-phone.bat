@echo off
REM ==================================================================
REM 실제 휴대폰에 APT EV 충전 release APK 설치 (USB 디버깅 필요)
REM ==================================================================

chcp 65001 >nul
setlocal

set ADB="C:\android-sdk\platform-tools\adb.exe"
set APK_PATH=D:\vsCodeProg\APT-APP\build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK_PATH%" (
    echo [ERROR] APK 파일이 없습니다: %APK_PATH%
    pause
    exit /b 1
)

echo ▶ 충돌 방지: 기존 ADB daemon 종료...
taskkill /F /IM adb.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo ▶ ADB 시작...
%ADB% start-server

echo ▶ 연결된 기기:
%ADB% devices
echo.

echo ▶ 휴대폰 모델 확인:
%ADB% shell getprop ro.product.model 2>nul
%ADB% shell getprop ro.product.manufacturer 2>nul
echo.

echo ▶ APK 설치 중 (재설치 -r, 다운그레이드 허용 -d)...
echo    파일: %APK_PATH%
echo    크기:
dir /-c "%APK_PATH%" | findstr /R /C:"app-release"
echo.

%ADB% install -r -d "%APK_PATH%"

if errorlevel 1 (
    echo.
    echo [ERROR] 설치 실패. 다음을 확인:
    echo  1. USB 디버깅 ON ^(설정 → 개발자 옵션^)
    echo  2. PC 신뢰 허용 다이얼로그가 휴대폰에 떴을 때 "허용" 터치
    echo  3. USB 연결 모드: "파일 전송" 또는 "MTP"
) else (
    echo.
    echo ✅ 설치 완료. 휴대폰 홈 화면에서 "APT EV 충전" 아이콘 확인.
)

echo.
pause
endlocal
