@echo off
REM ============================================
REM Flutter 개발 환경 자동 구성 스크립트
REM Windows 10/11 용
REM ============================================

chcp 65001 >nul
setlocal enabledelayedexpansion

color 0A
cls

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                                                                ║
echo ║     Flutter 개발 환경 자동 구성 및 설치 도구                      ║
echo ║                                                                ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM 관리자 권한 확인
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [경고] 이 스크립트는 관리자 권한이 필요합니다.
    echo 우클릭 - 관리자로 실행 해주세요.
    echo.
    pause
    exit /b 1
)

echo [정보] PC 환경 체크 중...
echo.

REM ============================================
REM 1. Git 설치 확인
REM ============================================
echo [1/6] Git 상태 확인...
git --version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%i in ('git --version') do set GIT_VERSION=%%i
    echo    ✓ Git 설치됨: !GIT_VERSION!
) else (
    echo    ✗ Git 미설치
    set NEED_GIT=1
)
echo.

REM ============================================
REM 2. Java/JDK 확인
REM ============================================
echo [2/6] Java 상태 확인...
java -version >nul 2>&1
if %errorlevel% equ 0 (
    for /f "skip=2 tokens=*" %%i in ('java -version 2^>^&1') do (
        if "!JAVA_VERSION!"=="" set JAVA_VERSION=%%i
    )
    echo    ✓ Java 설치됨
) else (
    echo    ✗ Java 미설치
    set NEED_JAVA=1
)
echo.

REM ============================================
REM 3. Flutter 설치 확인
REM ============================================
echo [3/6] Flutter 상태 확인...
if exist "C:\src\flutter\bin\flutter.bat" (
    for /f "tokens=*" %%i in ('C:\src\flutter\bin\flutter.bat --version ^| findstr /R "Flutter 3"') do set FLUTTER_VERSION=%%i
    echo    ✓ Flutter 설치됨: C:\src\flutter
) else (
    echo    ✗ Flutter 미설치
    set NEED_FLUTTER=1
)
echo.

REM ============================================
REM 4. Android SDK 확인
REM ============================================
echo [4/6] Android SDK 상태 확인...
if exist "%LOCALAPPDATA%\Android\sdk" (
    echo    ✓ Android SDK 설치됨: %LOCALAPPDATA%\Android\sdk
    set ANDROID_SDK_PATH=%LOCALAPPDATA%\Android\sdk
) else (
    echo    ✗ Android SDK 미설치
    set NEED_ANDROID=1
    set ANDROID_SDK_PATH=%LOCALAPPDATA%\Android\sdk
)
echo.

REM ============================================
REM 5. Android Studio 확인
REM ============================================
echo [5/6] Android Studio 상태 확인...
if exist "C:\Program Files\Android\Android Studio" (
    echo    ✓ Android Studio 설치됨
    set HAS_ANDROID_STUDIO=1
) else (
    if exist "C:\Program Files (x86)\Android\Android Studio" (
        echo    ✓ Android Studio 설치됨
        set HAS_ANDROID_STUDIO=1
    ) else (
        echo    ✗ Android Studio 미설치 (선택사항)
        set NEED_ANDROID_STUDIO=1
    )
)
echo.

REM ============================================
REM 6. 환경변수 확인
REM ============================================
echo [6/6] 환경변수 상태 확인...
echo %PATH% | findstr "flutter" >nul
if %errorlevel% equ 0 (
    echo    ✓ Flutter PATH 등록됨
) else (
    echo    ✗ Flutter PATH 미등록
    set NEED_PATH=1
)
echo.

REM ============================================
REM 설치 필요 항목 정리
REM ============================================
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                   설치 필요 항목                               ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

if "!NEED_GIT!"=="1" echo   • Git
if "!NEED_JAVA!"=="1" echo   • Java/JDK 17 이상
if "!NEED_FLUTTER!"=="1" echo   • Flutter SDK
if "!NEED_ANDROID!"=="1" echo   • Android SDK
if "!NEED_ANDROID_STUDIO!"=="1" echo   • Android Studio (선택)
if "!NEED_PATH!"=="1" echo   • 환경변수 설정

if not "!NEED_GIT!"=="1" if not "!NEED_JAVA!"=="1" if not "!NEED_FLUTTER!"=="1" if not "!NEED_ANDROID!"=="1" if not "!NEED_PATH!"=="1" (
    echo   ✓ 모든 필수 항목이 설치되어 있습니다!
    goto :ready_to_run
)

echo.
set /p CONTINUE="설치를 계속하시겠습니까? (y/n): "
if /i not "%CONTINUE%"=="y" goto :end

REM ============================================
REM 자동 설치 시작
REM ============================================
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                   자동 설치 시작                               ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM Git 설치
if "!NEED_GIT!"=="1" (
    echo [설치중] Git 설치 중...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Write-Host 'Git 자동 설치를 위해 브라우저가 열립니다.' -ForegroundColor Green; Start-Process 'https://git-scm.com/download/win'"
    echo [안내] Git 설치 후 이 창을 다시 실행하세요.
    pause
)

REM Java 설치
if "!NEED_JAVA!"=="1" (
    echo [설치중] Java 설치 중...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Write-Host 'Java 다운로드 페이지가 열립니다.' -ForegroundColor Green; Start-Process 'https://www.oracle.com/java/technologies/downloads/'"
    echo [안내] Java를 설치하고 이 창을 다시 실행하세요.
    pause
)

REM Flutter 설치
if "!NEED_FLUTTER!"=="1" (
    echo [설치중] Flutter 설치 중...
    
    if not exist "C:\src" mkdir C:\src
    
    if exist "C:\src\flutter" (
        echo [정보] 기존 Flutter 폴더를 제거 중...
        rmdir /s /q "C:\src\flutter" >nul 2>&1
    )
    
    echo [정보] Git으로 Flutter 설치 중... (5-10분 소요)
    cd /d C:\src
    git clone https://github.com/flutter/flutter.git -b stable flutter
    
    if !errorlevel! equ 0 (
        echo [성공] Flutter 설치 완료!
        set NEED_PATH=1
    ) else (
        echo [오류] Flutter 설치 실패
    )
)

REM 환경변수 설정
if "!NEED_PATH!"=="1" (
    echo [설정중] 환경변수 설정 중...
    
    setx ANDROID_SDK_ROOT "%LOCALAPPDATA%\Android\sdk"
    
    set "PATH=%PATH%;C:\src\flutter\bin"
    setx PATH "!PATH!"
    
    echo [성공] 환경변수 설정 완료!
)

REM Android SDK 설치 여부 확인
if "!NEED_ANDROID!"=="1" (
    echo [안내] Android SDK는 Android Studio를 통해 설치됩니다.
)

REM Android Studio 설치 안내
if "!NEED_ANDROID_STUDIO!"=="1" (
    echo [설치중] Android Studio 설치 중...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Write-Host 'Android Studio 다운로드 페이지가 열립니다.' -ForegroundColor Green; Start-Process 'https://developer.android.com/studio'"
    echo [안내] Android Studio 설치 후 이 창을 다시 실행하세요.
    pause
)

REM ============================================
REM 준비 완료
REM ============================================
:ready_to_run
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                   환경 구성 완료!                              ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

echo [확인중] Flutter 재설정 중...
C:\src\flutter\bin\flutter.bat --version >nul 2>&1

echo [확인중] Flutter doctor 실행 중...
echo.

C:\src\flutter\bin\flutter.bat doctor

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                   다음 단계                                    ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.
echo PowerShell을 다시 열고 다음 명령어를 실행하세요:
echo.
echo   cd d:\vsCodeProg\APT-APP
echo   flutter run
echo.
echo 또는 자동 도구를 사용하세요:
echo.
echo   .\android-run.bat
echo.

:end
echo.
echo Enter를 눌러 닫기...
pause >nul
