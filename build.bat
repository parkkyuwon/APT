@echo off
REM ============================================
REM APT EV Charging App - Build Deploy Tool (Windows)
REM UTF-8 Korean Text Support
REM ============================================

chcp 65001 >nul
setlocal enabledelayedexpansion

:menu
cls
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║     APT EV Charging Mobile App - Build ^& Deploy Tool     ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.
echo === 빌드 및 배포 옵션 ===
echo.
echo 1. 의존성 설치 (flutter pub get)
echo 2. 코드 분석 (flutter analyze)
echo 3. 단위 테스트 (flutter test)
echo 4. Android 빌드 - APK
echo 5. Android 빌드 - App Bundle
echo 6. 모든 검사 후 빌드 (1 → 2 → 3 → 4)
echo 7. 전체 프리플라이트 체크
echo 8. 배포 전 최종 확인
echo 9. 용량 정리 (flutter clean)
echo 10. 종료
echo.
set /p choice="선택: "

if "%choice%"=="1" goto install_deps
if "%choice%"=="2" goto analyze
if "%choice%"=="3" goto test
if "%choice%"=="4" goto build_apk
if "%choice%"=="5" goto build_bundle
if "%choice%"=="6" goto full_pipeline
if "%choice%"=="7" goto preflight
if "%choice%"=="8" goto pre_deploy
if "%choice%"=="9" goto clean
if "%choice%"=="10" goto end
goto invalid

:install_deps
echo.
echo [1/1] 의존성 설치 중...
flutter pub get
if %errorlevel% equ 0 (
    echo.
    echo ✅ 의존성 설치 완료
) else (
    echo.
    echo ❌ 의존성 설치 실패
)
pause
goto menu

:analyze
echo.
echo [1/1] 코드 분석 중...
flutter analyze
if %errorlevel% equ 0 (
    echo.
    echo ✅ 코드 분석 완료
) else (
    echo.
    echo ⚠️  코드 분석 경고 발생 (위 내용 확인)
)
pause
goto menu

:test
echo.
echo [1/1] 단위 테스트 실행 중...
flutter test
if %errorlevel% equ 0 (
    echo.
    echo ✅ 테스트 완료
) else (
    echo.
    echo ❌ 테스트 실패
)
pause
goto menu

:build_apk
echo.
echo [1/1] Android APK 빌드 중 (이 과정은 몇 분이 소요될 수 있습니다)...
flutter build apk --release
if %errorlevel% equ 0 (
    echo.
    echo ✅ APK 빌드 완료
    echo 📦 출력: build\app\outputs\apk\release\app-release.apk
) else (
    echo.
    echo ❌ APK 빌드 실패
)
pause
goto menu

:build_bundle
echo.
echo [1/1] Android App Bundle 빌드 중...
flutter build appbundle --release
if %errorlevel% equ 0 (
    echo.
    echo ✅ App Bundle 빌드 완료
    echo 📦 출력: build\app\outputs\bundle\release\app-release.aab
) else (
    echo.
    echo ❌ App Bundle 빌드 실패
)
pause
goto menu

:full_pipeline
echo.
echo === 완전한 빌드 파이프라인 시작 ===
echo.
echo [1/4] 의존성 설치...
flutter pub get
if %errorlevel% neq 0 goto pipeline_fail
echo.
echo [2/4] 코드 분석...
flutter analyze
if %errorlevel% neq 0 goto pipeline_fail
echo.
echo [3/4] 테스트 실행...
flutter test
if %errorlevel% neq 0 goto pipeline_fail
echo.
echo [4/4] APK 빌드...
flutter build apk --release
if %errorlevel% neq 0 goto pipeline_fail

echo.
echo ✅ 모든 단계 성공
pause
goto menu

:pipeline_fail
echo.
echo ❌ 빌드 파이프라인 실패
pause
goto menu

:preflight
echo.
echo === 배포 전 프리플라이트 체크 ===
echo.

set passed=0
set failed=0

echo Flutter SDK:
where flutter >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 설치됨
    set /a passed+=1
) else (
    echo ❌ 설치 안 됨
    set /a failed+=1
)

echo.
echo Dart SDK:
where dart >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ 설치됨
    set /a passed+=1
) else (
    echo ❌ 설치 안 됨
    set /a failed+=1
)

echo.
echo Android SDK:
if defined ANDROID_SDK_ROOT (
    echo ✅ 설치됨
    set /a passed+=1
) else if defined ANDROID_HOME (
    echo ✅ 설치됨
    set /a passed+=1
) else (
    echo ❌ 설정 안 됨
    set /a failed+=1
)

echo.
echo pubspec.yaml:
if exist "pubspec.yaml" (
    echo ✅ 있음
    set /a passed+=1
) else (
    echo ❌ 없음
    set /a failed+=1
)

echo.
echo lib\main.dart:
if exist "lib\main.dart" (
    echo ✅ 있음
    set /a passed+=1
) else (
    echo ❌ 없음
    set /a failed+=1
)

echo.
echo android\ 폴더:
if exist "android" (
    echo ✅ 있음
    set /a passed+=1
) else (
    echo ❌ 없음
    set /a failed+=1
)

echo.
echo pubspec.lock:
if exist "pubspec.lock" (
    echo ✅ 있음
    set /a passed+=1
) else (
    echo ⚠️  없음 ^(flutter pub get 실행 필요^)
    set /a failed+=1
)

echo.
echo 체크 결과: !passed! 통과 / !failed! 실패
echo.
if !failed! equ 0 (
    echo ✅ 모든 필수 요소가 설정되었습니다
) else (
    echo ❌ 일부 필수 요소가 누락되었습니다
)

pause
goto menu

:pre_deploy
cls
echo.
echo === 배포 전 최종 확인 ===
echo.
echo 다음 항목들을 확인하세요:
echo.
echo 📱 앱 설정:
echo   [ ] API 서버 주소 확인 (lib/config/app_config.dart)
echo   [ ] Google OAuth Client ID 설정
echo   [ ] 앱 버전 업데이트 (pubspec.yaml)
echo.
echo 🔐 보안:
echo   [ ] API 서버가 HTTPS 사용
echo   [ ] 민감한 정보가 코드에 노출되지 않았는지 확인
echo   [ ] 토큰이 안전하게 저장되는지 확인
echo.
echo 🧪 테스트:
echo   [ ] 단위 테스트 통과 (flutter test)
echo   [ ] 코드 분석 완료 (flutter analyze)
echo   [ ] 에뮬레이터/기기에서 수동 테스트
echo.
echo 🔗 플랫폼별 설정:
echo   [ ] Android:
echo       - google-services.json 추가
echo       - AndroidManifest.xml 권한 확인
echo   [ ] iOS (Mac에서 빌드 시):
echo       - GoogleService-Info.plist 추가
echo       - 프로비저닝 프로필 설정
echo.
echo 📤 배포:
echo   [ ] Play Store 개발자 계정 활성화
echo   [ ] App Store Connect 계정 활성화
echo   [ ] 스크린샷 및 설명 준비
echo.
echo 위 항목을 모두 확인 후 배포하세요.
echo.
pause
goto menu

:clean
echo.
echo 용량 정리 중...
flutter clean
echo.
echo ✅ 용량 정리 완료
pause
goto menu

:invalid
echo.
echo ❌ 잘못된 선택입니다
pause
goto menu

:end
echo.
echo 프로그램 종료
exit /b 0
