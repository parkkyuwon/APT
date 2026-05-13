# Flutter 환경 자동 설치 스크립트 (PowerShell)

# UTF-8 인코딩 설정
chcp 65001 >$null

Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         Flutter 개발 환경 자동 설치 (Windows)                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# 1. 관리자 권한 확인
Write-Host "[1/4] 관리자 권한 확인..." -ForegroundColor Yellow
$isAdmin = [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match "S-1-5-32-544")
if (-not $isAdmin) {
    Write-Host "오류: 관리자 권한이 필요합니다!" -ForegroundColor Red
    Write-Host "우클릭 - PowerShell(관리자로)로 이 스크립트를 다시 실행하세요." -ForegroundColor Red
    Read-Host "Enter 키를 누르세요"
    exit
}
Write-Host "✓ 관리자 권한 확인됨" -ForegroundColor Green
Write-Host ""

# 2. JAVA 설치 확인 및 다운로드
Write-Host "[2/4] Java 설치 확인..." -ForegroundColor Yellow
$javaCheck = cmd /c "java -version 2>&1" -ErrorAction SilentlyContinue
if ($javaCheck -like "*version*") {
    Write-Host "✓ Java 이미 설치됨" -ForegroundColor Green
} else {
    Write-Host "✗ Java 미설치 - 자동 설치 중..." -ForegroundColor Red
    Write-Host "브라우저에서 Java를 다운로드하고 설치해주세요:" -ForegroundColor Cyan
    Write-Host "https://www.oracle.com/java/technologies/downloads/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "다운로드 후 이 창으로 돌아와 Enter를 누르세요." -ForegroundColor Yellow
    Start-Process "https://www.oracle.com/java/technologies/downloads/"
    Read-Host "Enter 키를 누르세요"
}
Write-Host ""

# 3. FLUTTER SDK 설치
Write-Host "[3/4] Flutter SDK 설치..." -ForegroundColor Yellow

$flutterDir = "C:\src\flutter"
$flutterBin = "$flutterDir\bin\flutter.bat"

if (Test-Path $flutterBin) {
    Write-Host "✓ Flutter 이미 설치됨: $flutterDir" -ForegroundColor Green
} else {
    Write-Host "Flutter 설치 중... (5-10분 소요)" -ForegroundColor Cyan
    
    # C:\src 디렉토리 생성
    if (-not (Test-Path "C:\src")) {
        New-Item -ItemType Directory -Path "C:\src" -Force | Out-Null
    }
    
    # 기존 Flutter 디렉토리가 있으면 삭제
    if (Test-Path $flutterDir) {
        Remove-Item -Recurse -Force $flutterDir -ErrorAction SilentlyContinue
    }
    
    # Git으로 Flutter 다운로드
    Set-Location "C:\src"
    git clone https://github.com/flutter/flutter.git -b stable flutter
    
    if (Test-Path $flutterBin) {
        Write-Host "✓ Flutter 설치 완료: $flutterDir" -ForegroundColor Green
    } else {
        Write-Host "✗ Flutter 설치 실패!" -ForegroundColor Red
        Read-Host "Enter 키를 눌러 종료"
        exit
    }
}
Write-Host ""

# 4. 환경변수 설정
Write-Host "[4/4] 환경변수 설정..." -ForegroundColor Yellow

# ANDROID_SDK_ROOT 설정
$androidSdkPath = "$($env:LOCALAPPDATA)\Android\sdk"
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidSdkPath, [EnvironmentVariableTarget]::User)

# PATH에 Flutter 추가
$currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
if ($currentPath -notlike "*flutter*") {
    $newPath = "$flutterDir\bin;$currentPath"
    [Environment]::SetEnvironmentVariable("Path", $newPath, [EnvironmentVariableTarget]::User)
    Write-Host "✓ PATH 업데이트 완료" -ForegroundColor Green
} else {
    Write-Host "✓ Flutter PATH 이미 설정됨" -ForegroundColor Green
}

# 현재 세션 PATH 업데이트
$env:PATH = "$flutterDir\bin;$env:PATH"
$env:ANDROID_SDK_ROOT = $androidSdkPath

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                 Flutter 버전 확인                              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Flutter 버전 확인
& $flutterBin --version

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                 Flutter Doctor 실행                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Flutter doctor 실행
& $flutterBin doctor

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                   설치 완료!                                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "다음 명령어로 앱을 실행할 수 있습니다:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  cd d:\vsCodeProg\APT-APP" -ForegroundColor White
Write-Host "  flutter run" -ForegroundColor White
Write-Host ""
Write-Host "또는 자동 도구 사용:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  .\android-run.bat" -ForegroundColor White
Write-Host ""
Write-Host "참고: 새로운 PowerShell 창을 열면 환경변수가 자동 적용됩니다." -ForegroundColor Yellow
Write-Host ""
Read-Host "Enter 키를 눌러 종료"
