@echo off
REM Flutter 자동 설치 스크립트 (Windows)
REM 이 스크립트는 Flutter SDK를 다운로드하고 PATH에 추가합니다

chcp 65001 >nul
setlocal enabledelayedexpansion

echo.
echo ================================================
echo   Flutter 자동 설치 스크립트
echo ================================================
echo.

REM 1. Flutter 설치 디렉토리 확인
set FLUTTER_INSTALL_DIR=C:\src\flutter

if exist "%FLUTTER_INSTALL_DIR%" (
    echo [OK] Flutter이 이미 설치되어 있습니다: %FLUTTER_INSTALL_DIR%
    echo.
    
    REM PATH에 추가
    set "PATH=%FLUTTER_INSTALL_DIR%\bin;!PATH!"
    
    REM 버전 확인
    echo [INFO] Flutter 버전 확인 중...
    call "%FLUTTER_INSTALL_DIR%\bin\flutter.bat" --version
    
    if errorlevel 0 (
        echo.
        echo [SUCCESS] Flutter 준비 완료!
        echo.
        echo 다음 명령어를 실행하세요:
        echo   cd d:\vsCodeProg\APT-APP
        echo   flutter run
        echo.
    )
) else (
    echo [INFO] Flutter이 설치되지 않았습니다.
    echo [INFO] Flutter을 설치하려면 다음 단계를 따르세요:
    echo.
    echo 단계 1: https://flutter.dev/docs/get-started/install/windows 방문
    echo 단계 2: Flutter SDK 다운로드 (안정 버전)
    echo 단계 3: C:\src\flutter 에 압축 해제
    echo 단계 4: 환경변수 PATH에 C:\src\flutter\bin 추가
    echo 단계 5: PowerShell/CMD 재시작
    echo 단계 6: 다시 이 스크립트 실행
    echo.
    echo 또는 Git으로 설치:
    echo   git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
    echo.
    
    goto :ask_install
)

goto :end

:ask_install
echo.
set /p install="자동으로 설치하시겠습니까? (y/n): "
if /i "%install%"=="y" (
    echo [INFO] Git으로 Flutter 설치 중...
    
    REM Git 확인
    git --version >nul 2>&1
    if errorlevel 1 (
        echo [ERROR] Git이 설치되지 않았습니다.
        echo Git 설치: https://git-scm.com/download/win
        pause
        goto :end
    )
    
    REM C:\src 디렉토리 생성
    if not exist "C:\src" mkdir C:\src
    
    REM Flutter 다운로드
    echo [INFO] Flutter 저장소 복제 중... (5-10분 소요)
    git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
    
    if errorlevel 0 (
        echo [SUCCESS] Flutter 다운로드 완료!
        echo.
        echo [INFO] PATH 환경변수에 추가하려면:
        echo   1. Win + X를 누르고 "시스템" 선택
        echo   2. "고급 시스템 설정" 클릭
        echo   3. "환경 변수" 클릭
        echo   4. Path 선택 후 편집
        echo   5. 새로 추가: C:\src\flutter\bin
        echo   6. 확인 후 PowerShell/CMD 재시작
        echo.
        echo 또는 PowerShell에서 다음 명령 실행:
        echo   $env:Path += ';C:\src\flutter\bin'
        echo.
    ) else (
        echo [ERROR] Flutter 다운로드 실패!
    )
) else (
    echo [INFO] 설치 취소됨.
)

:end
echo.
echo 완료. Enter를 누르세요...
pause >nul
