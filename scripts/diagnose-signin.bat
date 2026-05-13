@echo off
REM ==================================================================
REM Google Sign-In 실시간 진단
REM
REM 실행 방법:
REM   1. BlueStacks 가 실행 중이고 ADB 가 활성화 (설정 → 고급 → ADB)
REM   2. 본 스크립트를 cmd 또는 PowerShell 에서 실행
REM   3. 화면이 "지금 로그인 시도하세요" 로 멈추면 BlueStacks 의 APT 앱에서
REM      "Google 로그인" 버튼 터치
REM   4. 콘솔에 출력되는 에러 코드 확인
REM ==================================================================

chcp 65001 >nul
setlocal enabledelayedexpansion

set ADB="C:\android-sdk\platform-tools\adb.exe"

echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║  Google Sign-In 진단 도구                                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

echo ▶ ADB 정리 (기존 daemon 종료 + BlueStacks 충돌 회피)...
taskkill /F /IM adb.exe >nul 2>&1
timeout /t 2 /nobreak >nul

echo ▶ ADB 시작...
%ADB% start-server
echo.

echo ▶ BlueStacks 다중 포트 시도...
%ADB% connect 127.0.0.1:5555
%ADB% connect 127.0.0.1:5565
%ADB% connect 127.0.0.1:5575
echo.

echo ▶ 연결된 기기:
%ADB% devices
echo.

set DEVICE=127.0.0.1:5555

echo ▶ 진단 1: 앱 설치 확인
%ADB% -s %DEVICE% shell "dumpsys package com.bluetilelab.apt_ev | head -2" 2>nul
echo.

echo ▶ 진단 2: APK 의 SHA-1 (Google Cloud 에 등록할 값)
echo    SHA-1 ^(현재 빌드된 release APK^):
echo    BC:E7:5D:31:AF:66:7A:EE:66:E7:4C:6E:34:99:08:4B:03:EF:32:7C
echo.

echo ▶ 진단 3: BlueStacks 의 ABI / Android 버전 / Play Services
echo    ABI:
%ADB% -s %DEVICE% shell getprop ro.product.cpu.abi 2>nul
echo    Android:
%ADB% -s %DEVICE% shell getprop ro.build.version.release 2>nul
echo    Play Services 버전:
%ADB% -s %DEVICE% shell "dumpsys package com.google.android.gms | grep versionName | head -1" 2>nul
echo.

echo ▶ 진단 4: BlueStacks 의 Google 계정 등록 여부
%ADB% -s %DEVICE% shell "dumpsys account | grep type=" 2>nul | findstr "google"
echo.

echo ▶ 앱 강제 재시작...
%ADB% -s %DEVICE% shell am force-stop com.bluetilelab.apt_ev
timeout /t 1 /nobreak >nul
%ADB% -s %DEVICE% shell am start -n com.bluetilelab.apt_ev/.MainActivity
echo.

echo ▶ logcat 클리어...
%ADB% -s %DEVICE% logcat -c
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║  지금 BlueStacks 의 APT 앱에서 "Google 로그인" 을 눌러주세요!     ║
echo ║  로그인 결과 (성공 또는 실패) 가 아래에 5초 내 출력됩니다.        ║
echo ║  완료 후 Ctrl+C 로 종료.                                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

REM Google Sign-In, GMS Auth, Flutter, Activity 모두 캡처
%ADB% -s %DEVICE% logcat -v time ^
    GoogleSignInClient:V GoogleSignInActivity:V SignInActivity:V ^
    Auth:V GMS_AUTH:V Auth.SignIn:V ^
    flutter:V FlutterActivity:V FlutterEngine:V ^
    System.err:E AndroidRuntime:E *:S

endlocal
