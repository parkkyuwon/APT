@echo off
REM ==================================================================
REM BlueStacks 에서 Google Sign-In 디버그 로그 실시간 모니터링
REM ==================================================================

chcp 65001 >nul
setlocal

set ADB="C:\android-sdk\platform-tools\adb.exe"

%ADB% connect 127.0.0.1:5555 2>nul
%ADB% connect 127.0.0.1:5565 2>nul

echo ▶ Google Sign-In 관련 로그 필터링 (Ctrl+C 로 종료)
echo.

%ADB% logcat -c

REM 로그인 시도하면서 다음 로그를 봅니다:
REM  - GoogleSignIn / GoogleSignInClient
REM  - PlayServices / GMS
REM  - SIGN_IN_FAILED / 12500 / 10
%ADB% logcat -v time ^
    GoogleSignIn:V ^
    GoogleSignInClient:V ^
    GoogleApi:V ^
    PlayServices:V ^
    Auth:V ^
    flutter:V ^
    *:E

endlocal
