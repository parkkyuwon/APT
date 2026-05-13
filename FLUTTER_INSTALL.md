# ⚠️ Flutter 설치 필수 가이드

`flutter run` 명령어를 실행하기 전에 **Flutter SDK를 먼저 설치해야 합니다.**

## 🚀 3가지 설치 방법

### 방법 1️⃣: 자동 설치 (권장 - Git 사용)

PowerShell에서 **관리자 권한**으로 실행:

```powershell
# 1. Git 설치 확인
git --version

# 2. Flutter 설치 디렉토리 생성
New-Item -ItemType Directory -Path C:\src -Force

# 3. Flutter 다운로드 (5-10분 소요)
git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter

# 4. PATH에 추가 (현재 세션)
$env:Path += ';C:\src\flutter\bin'

# 5. 확인
flutter --version
```

### 방법 2️⃣: 수동 설치 (GUI)

1. **Flutter SDK 다운로드**
   - 사이트: https://flutter.dev/docs/get-started/install/windows
   - 버전: Stable (최신 안정 버전)

2. **압축 해제**
   - 다운로드: `flutter_windows_x.x.x-stable.zip`
   - 해제 위치: `C:\src\flutter`

3. **환경변수 설정**
   - `Win + X` → "시스템" 선택
   - "고급 시스템 설정" 클릭
   - "환경변수" 클릭
   - `Path` 클릭 후 편집
   - 새로 추가: `C:\src\flutter\bin`
   - 확인 및 저장
   - **PowerShell/CMD 완전 재시작**

4. **설치 확인**
   ```powershell
   flutter --version
   ```

### 방법 3️⃣: 초고속 설치 (Chocolatey)

**관리자 권한**으로 PowerShell 실행:

```powershell
# Chocolatey 설치 (처음 1회만)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Flutter 설치
choco install flutter -y
```

---

## ✅ 설치 후 필수 확인

```powershell
# 1. Flutter 버전 확인
flutter --version

# 2. 의존성 확인 (중요!)
flutter doctor

# 3. 권장: 의존성 설치
flutter doctor --android-licenses  # Accept all
```

---

## 🔧 Android 환경 설정 (앱 실행 전)

```powershell
# Flutter의 Android 환경 확인
flutter doctor -v

# 필요시 설치
flutter pub get

# 프로젝트로 이동
cd d:\vsCodeProg\APT-APP
```

---

## 🎯 설치 후 앱 실행

```powershell
# 1. 프로젝트 폴더로 이동
cd d:\vsCodeProg\APT-APP

# 2. 기기/에뮬레이터 확인
flutter devices

# 3. 앱 실행
flutter run

# 또는 릴리스 모드
flutter run --release
```

---

## 📋 체크리스트

```
기본 설정:
□ Flutter SDK 설치 (C:\src\flutter)
□ PATH 추가 (C:\src\flutter\bin)
□ PowerShell/CMD 재시작
□ flutter --version 확인

Android 설정:
□ Android Studio 설치
□ SDK Platform 설치 (API 21, 33, 34)
□ flutter doctor 통과
□ 에뮬레이터 또는 기기 준비

프로젝트 준비:
□ flutter pub get (의존성 설치)
□ flutter devices (기기 확인)
□ 데이터 연결 확인

실행:
□ flutter run (디버그)
□ 또는 flutter run --release (릴리스)
```

---

## 🚨 주요 문제 해결

### "flutter is not found"
→ PATH 설정 재확인 및 PowerShell 재시작

### "No devices found"
→ 에뮬레이터 시작 또는 USB로 기기 연결
```powershell
emulator -list-avds              # 에뮬레이터 목록
emulator -avd Pixel_6_API_33     # 에뮬레이터 시작
flutter devices                   # 기기 확인
```

### "Doctor summary says not ready"
→ flutter doctor -v 로 문제 확인 후 해결

```powershell
# Android licenses 승인 (자동)
flutter doctor --android-licenses
```

### "ANDROID_SDK_ROOT not set"
→ Android SDK 경로 설정 필요
```powershell
# PowerShell 프로필에 추가
$env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\sdk"
```

---

## 📞 지원 문서

- [ANDROID_RUN.md](ANDROID_RUN.md) - Android 실행 가이드
- [ANDROID_QUICK.md](ANDROID_QUICK.md) - 빠른 참조
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - 배포 체크리스트
- [build.bat](build.bat) - 통합 빌드 도구
- [android-run.bat](android-run.bat) - Android 자동 도구

---

## 🔗 공식 자료

- [Flutter 설치 가이드](https://flutter.dev/docs/get-started/install/windows)
- [Android Studio 다운로드](https://developer.android.com/studio)
- [Flutter 문서](https://flutter.dev/docs)

---

**다음 단계:**
1. 위 방법 중 하나로 Flutter 설치
2. `flutter doctor` 실행하여 모든 항목 확인
3. `cd d:\vsCodeProg\APT-APP && flutter run` 실행

**준비되셨으면 알려주세요!** 🚀
