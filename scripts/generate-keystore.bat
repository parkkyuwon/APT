@echo off
REM ==================================================================
REM APT EV 충전 — Play Store 업로드 키스토어 생성 스크립트
REM
REM 한 번만 실행하세요. 생성된 apt-upload.jks 파일과 암호는
REM 안전한 곳에 백업하세요. 분실 시 앱 업데이트가 불가능합니다.
REM ==================================================================

chcp 65001 >nul
setlocal

set KEYSTORE_PATH=%~dp0..\apt-upload.jks
set KEY_ALIAS=apt

if exist "%KEYSTORE_PATH%" (
    echo [WARN] 이미 키스토어가 존재합니다: %KEYSTORE_PATH%
    echo 재생성하려면 먼저 해당 파일을 이동/백업하세요.
    pause
    exit /b 1
)

echo ================================================================
echo Play Store 업로드 키스토어를 생성합니다.
echo - 파일 위치: %KEYSTORE_PATH%
echo - alias:    %KEY_ALIAS%
echo - 유효기간:   약 27년 (10000일)
echo ================================================================
echo.
echo 아래 정보를 입력하세요. 엔터만 누르면 기본값이 사용됩니다.
echo.

where keytool >nul 2>&1
if errorlevel 1 (
    echo [ERROR] keytool 을 찾을 수 없습니다.
    echo JDK 를 설치하거나 PATH 에 추가하세요.
    echo 예: C:\Program Files\Java\jdk-17\bin
    pause
    exit /b 1
)

keytool -genkeypair -v ^
    -keystore "%KEYSTORE_PATH%" ^
    -alias %KEY_ALIAS% ^
    -keyalg RSA ^
    -keysize 2048 ^
    -validity 10000 ^
    -storetype JKS

if errorlevel 1 (
    echo [ERROR] 키스토어 생성 실패
    pause
    exit /b 1
)

echo.
echo ================================================================
echo 키스토어 생성 완료!
echo.
echo 다음 단계:
echo 1. %~dp0..\android\key.properties 파일 생성
echo    (android\key.properties.example 참조)
echo 2. 위에 입력한 암호를 password manager 에 저장
echo 3. apt-upload.jks 파일을 외부 드라이브/암호화 클라우드에 백업
echo 4. .gitignore 에 의해 Git 커밋되지 않습니다
echo ================================================================

pause
