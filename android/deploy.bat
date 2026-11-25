@echo off
REM ============================================
REM fastlane Play Console 업로드 래퍼
REM 사용:
REM   deploy.bat              -> internal 트랙
REM   deploy.bat alpha        -> 비공개 테스트
REM   deploy.bat beta         -> 공개 테스트
REM   deploy.bat production   -> 정식 출시 (draft)
REM   deploy.bat validate     -> dry-run (실제 게시 X)
REM   deploy.bat build        -> AAB 만 빌드
REM ============================================

chcp 65001 >nul
setlocal

REM 한글 사용자명 회피 — Kotlin/Gradle 캐시를 ASCII 경로로 강제
set PUB_CACHE=D:\PubCache
set GRADLE_USER_HOME=D:\GradleHome
if exist D:\Temp set TEMP=D:\Temp
if exist D:\Temp set TMP=D:\Temp

cd /d "%~dp0"

if "%1"=="" goto internal
if "%1"=="validate" goto validate
if "%1"=="build" goto build_only
if "%1"=="alpha" goto alpha
if "%1"=="beta" goto beta
if "%1"=="production" goto production
if "%1"=="internal" goto internal
echo Unknown track: %1
exit /b 1

:internal
bundle exec fastlane deploy
goto end

:alpha
bundle exec fastlane deploy track:alpha
goto end

:beta
bundle exec fastlane deploy track:beta
goto end

:production
bundle exec fastlane deploy track:production
goto end

:validate
bundle exec fastlane validate
goto end

:build_only
bundle exec fastlane build
goto end

:end
endlocal
