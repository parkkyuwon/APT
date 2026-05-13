@echo off
REM ========================================
REM APT EV Charging Mobile App - Deploy Script
REM 자동 배포 스크립트
REM ========================================

setlocal enabledelayedexpansion

echo.
echo ============================================
echo APT EV Charging - 배포 자동화 스크립트
echo ============================================
echo.

REM Check Flutter installation
C:\src\flutter\bin\flutter.bat --version > nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter가 설치되지 않았습니다.
    echo C:\src\flutter에 Flutter를 설치해주세요.
    exit /b 1
)

echo [OK] Flutter 설치됨
echo.

REM Project directory
set PROJECT_DIR=d:\vsCodeProg\APT-APP
cd /d %PROJECT_DIR%

REM ========================================
REM 1. 의존성 설치
REM ========================================
echo [STEP 1] 의존성 설치 중...
C:\src\flutter\bin\flutter.bat pub get
if errorlevel 1 (
    echo [ERROR] 의존성 설치 실패
    exit /b 1
)
echo [OK] 의존성 설치 완료
echo.

REM ========================================
REM 2. 코드 검증
REM ========================================
echo [STEP 2] 코드 검증 중...
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos
if errorlevel 1 (
    echo [ERROR] 코드 검증 실패
    exit /b 1
)
echo [OK] 코드 검증 완료
echo.

REM ========================================
REM 3. APK 빌드
REM ========================================
echo [STEP 3] APK 빌드 중... (5-10분 소요)
C:\src\flutter\bin\flutter.bat build apk --debug
if errorlevel 1 (
    echo [ERROR] APK 빌드 실패
    exit /b 1
)
echo [OK] APK 빌드 완료
echo.

REM ========================================
REM 4. 기기 연결 확인
REM ========================================
echo [STEP 4] 기기 연결 확인 중...
set ADB_PATH=%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe
if not exist "%ADB_PATH%" (
    echo [ERROR] ADB를 찾을 수 없습니다
    exit /b 1
)

%ADB_PATH% devices > devices_list.txt
findstr /R "device" devices_list.txt | findstr /V "devices" > nul
if errorlevel 1 (
    echo [ERROR] 연결된 기기가 없습니다
    echo 기기를 USB로 연결하고 다시 시도해주세요.
    exit /b 1
)
echo [OK] 기기가 연결되어 있습니다
echo.

REM ========================================
REM 5. APK 설치
REM ========================================
echo [STEP 5] APK 설치 중...
"%ADB_PATH%" install -r "build\app\outputs\flutter-apk\app-debug.apk"
if errorlevel 1 (
    echo [ERROR] APK 설치 실패
    exit /b 1
)
echo [OK] APK 설치 완료
echo.

REM ========================================
REM 6. 앱 실행
REM ========================================
echo [STEP 6] 앱 실행 중...
C:\src\flutter\bin\flutter.bat run
if errorlevel 1 (
    echo [ERROR] 앱 실행 실패
    exit /b 1
)

echo.
echo ============================================
echo [SUCCESS] 배포 완료!
echo ============================================
echo.
echo 폰에서 APT EV Charging 앱을 확인해주세요.
echo 핫 리로드: r 입력
echo 전체 재시작: R 입력
echo 종료: q 입력
echo.

del /f /q devices_list.txt 2>nul
endlocal
