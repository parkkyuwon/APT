# 📱 Android 앱 실행 가이드 (APT EV Charging)

## 🎯 목표
Windows PC에서 APT-APP을 Android로 빌드하고 실행하기

---

## 📋 필수 요구사항

### 1️⃣ 설치 확인
```powershell
# 다음이 설치되어 있는지 확인
flutter --version
dart --version
flutter doctor
```

**필수 항목:**
- ✅ Flutter 3.0+
- ✅ Dart 3.0+
- ✅ Android SDK
- ✅ Android Studio 또는 에뮬레이터

---

## 🛠️ Android 개발 환경 설정

### Step 1: Android SDK 설정 확인

```powershell
# 환경 변수 확인
$env:ANDROID_HOME
$env:ANDROID_SDK_ROOT

# 설정되지 않았다면 설정
$env:ANDROID_HOME = "C:\Users\[사용자명]\AppData\Local\Android\sdk"
```

### Step 2: Flutter Doctor 실행

```powershell
flutter doctor
```

**확인 사항:**
```
✅ Flutter (Channel stable)
✅ Android toolchain - develop for Android devices
✅ Android SDK
✅ Android Studio
❌ 문제가 있으면 아래 명령어 실행:
```

### Step 3: Android 라이선스 동의

```powershell
flutter doctor --android-licenses
# Y or n 입력 (모두 Y 입력)
```

---

## 🖥️ Android 에뮬레이터 설정

### 방법 1: Android Studio에서 에뮬레이터 생성 (권장)

#### Step 1: Android Studio 열기
```powershell
# Android Studio가 설치되었다면
start "C:\Program Files\Android\Android Studio\bin\studio64.exe"
```

#### Step 2: AVD Manager 열기
1. Android Studio 시작
2. **More Options** → **Virtual Device Manager**
3. 또는 상단 메뉴 **Tools** → **Device Manager**

#### Step 3: 새 에뮬레이터 생성
1. **Create Virtual Device** 클릭
2. **Phone** 카테고리에서 **Pixel 6** 선택
3. **Next** 클릭
4. **Release 이름** 선택: **API 33** (Android 13) 권장
5. **Download** 클릭 (필요시)
6. **Next** → **Finish**

**생성된 에뮬레이터:**
```
Pixel_6_API_33
Pixel_6_API_30  (또는 다른 API 레벨)
```

#### Step 4: 에뮬레이터 실행
```powershell
# Android Studio에서 Device Manager에 표시된 에뮬레이터의 "Play" 버튼 클릭
# 또는 명령어로 실행:

emulator -avd Pixel_6_API_33
```

### 방법 2: 명령어로 에뮬레이터 관리

#### 사용 가능한 에뮬레이터 목록
```powershell
emulator -list-avds
```

**출력 예:**
```
Pixel_5_API_30
Pixel_6_API_33
Nexus_5X_API_29
```

#### 에뮬레이터 실행
```powershell
emulator -avd Pixel_6_API_33
# 또는 백그라운드 실행
emulator -avd Pixel_6_API_33 &
```

#### 에뮬레이터 종료
```powershell
emulator -avd [에뮬레이터_이름] -kill
```

---

## 📲 Flutter 기기 확인

### 현재 연결된 기기 확인

```powershell
flutter devices
```

**출력 예:**
```
2 connected devices:

emulator-5554 (mobile) • Google Pixel 6 API 33 • android • Android 13
```

---

## ▶️ APT-APP 실행하기

### 방법 1: 디버그 모드로 실행

#### Pre-requisite: 에뮬레이터 실행
```powershell
# 터미널 1: 에뮬레이터 실행
emulator -avd Pixel_6_API_33

# 에뮬레이터가 완전히 부팅될 때까지 대기 (1-2분)
# 홈 화면이 나타날 때까지 기다리기
```

#### APT-APP 실행
```powershell
# 터미널 2: 프로젝트 디렉토리로 이동
cd d:\vsCodeProg\APT-APP

# 앱 실행 (자동으로 debug 모드)
flutter run

# 특정 기기에 실행
flutter run -d emulator-5554
```

**첫 실행 시:**
- 의존성 다운로드 (2-3분)
- Gradle 빌드 (3-5분)
- 앱 설치 및 실행 (1-2분)
- **총 소요 시간: 5-10분**

#### 실행 후 명령어

```powershell
# 아래 기능들 사용 가능:

r       # 핫 리로드 (코드 변경 후 빠르게 반영)
R       # 핫 리스타트 (전체 재시작)
h       # 도움말 표시
d       # 기기 해제 (기기 선택 화면)
q       # 앱 종료
```

### 방법 2: 릴리스 모드로 실행 (배포 전 테스트)

```powershell
cd d:\vsCodeProg\APT-APP

# 릴리스 모드로 실행
flutter run --release

# 성능 주의: 디버그 모드보다 훨씬 빠르고 부드러움
```

---

## 📱 실제 Android 기기에서 실행

### Step 1: 기기 준비

#### USB 케이블로 PC에 연결
```
기기 → 개발자 설정 → USB 디버깅 활성화
```

#### 개발자 설정 활성화 방법
1. 기기의 **설정** 앱 열기
2. **정보** → **빌드 번호** 7번 탭
3. **개발자 옵션** 메뉴 나타남
4. **USB 디버깅** 활성화
5. **파일 전송** 모드로 설정 (권장)

### Step 2: 기기 연결 확인

```powershell
flutter devices
```

**출력 예:**
```
2 connected devices:

Galaxy S21             (mobile) • RF8N50FCH1J • android • Android 12
emulator-5554          (mobile) • Google Pixel 6 • android • Android 13
```

### Step 3: 기기에서 실행

```powershell
cd d:\vsCodeProg\APT-APP

# 기기 목록에서 선택
flutter run

# 또는 특정 기기 선택
flutter run -d RF8N50FCH1J
```

---

## 🔍 로그 확인

### 실시간 로그 보기

```powershell
# 연결된 모든 기기의 로그
flutter logs

# 특정 기기의 로그
flutter logs -d emulator-5554
```

### 에러 필터링

```powershell
# ERROR만 보기
flutter logs | findstr "ERROR"

# WARNING만 보기
flutter logs | findstr "WARNING"

# 특정 패키지 로그만 보기
flutter logs | findstr "apt_ev_charging"
```

---

## 🏗️ Android APK 빌드

### 디버그 APK 빌드

```powershell
cd d:\vsCodeProg\APT-APP
flutter build apk --debug
```

**출력:**
```
APK: build/app/outputs/apk/debug/app-debug.apk
크기: 약 50-70MB
```

### 릴리스 APK 빌드

```powershell
flutter build apk --release
```

**출력:**
```
APK: build/app/outputs/apk/release/app-release.apk
크기: 약 40-60MB
```

### APK 직접 설치

```powershell
# 디버그 APK 설치
adb install build\app\outputs\apk\debug\app-debug.apk

# 릴리스 APK 설치
adb install build\app\outputs\apk\release\app-release.apk

# 기존 앱 덮어쓰기
adb install -r build\app\outputs\apk\release\app-release.apk
```

### App Bundle 빌드 (Google Play 배포용)

```powershell
flutter build appbundle --release
```

**출력:**
```
AAB: build/app/outputs/bundle/release/app-release.aab
크기: 약 30-50MB
```

---

## 📊 빌드 프로세스 상세

### Step 1: Gradle 빌드
```
Gradle 프로젝트 구성 → 의존성 다운로드 → 컴파일 → 번들 생성
```

### Step 2: Flutter 리소스 생성
```
Dart 코드 컴파일 → 리소스 병합 → 최적화
```

### Step 3: 패키징
```
APK/AAB 생성 → 서명 (릴리스만) → 최종 확인
```

### 예상 소요 시간
- 첫 빌드: 10-15분
- 이후 빌드: 5-10분 (캐시 활용)

---

## 🐛 문제 해결

### 문제 1: "No devices found"
```powershell
# 해결: 에뮬레이터 실행 확인
emulator -list-avds
emulator -avd Pixel_6_API_33

# 또는 기기 USB 디버깅 확인
adb devices
```

### 문제 2: "Gradle build failed"
```powershell
# 해결: 캐시 정리
flutter clean
flutter pub get
flutter build apk --debug
```

### 문제 3: "ANDROID_SDK_ROOT not set"
```powershell
# 환경 변수 설정
$env:ANDROID_HOME = "C:\Users\[사용자명]\AppData\Local\Android\sdk"

# 또는 flutter config로 설정
flutter config --android-sdk-path "C:\Users\[사용자명]\AppData\Local\Android\sdk"
```

### 문제 4: "Unable to build app in release mode"
```powershell
# 해결: 디버그 모드로 빌드해보기
flutter build apk --debug

# 또는 clean 후 재시도
flutter clean
flutter pub get
flutter build apk --release
```

### 문제 5: "한글이 깨져서 보임"
확인:
- ✅ pubspec.yaml에 google_fonts 추가됨
- ✅ lib/utils/themes.dart에서 GoogleFonts.notoSansKr() 사용
- ✅ build.gradle에서 resConfigs "en", "ko" 설정

---

## 🔐 보안 설정 (배포 전)

### 키 저장소 생성
```powershell
# 첫 배포 시만 실행
keytool -genkey-dsa -keystore release.jks -alias apt_key -validity 10000

# 입력 정보:
# 키 저장소 암호: [강력한 비밀번호]
# 이름과 성: Your Name
# 조직 단위: Engineering
# 조직: APT
# 도시: Seoul
# 국가 코드: KR
```

### Gradle 서명 설정
`android/app/build.gradle`에 추가:
```gradle
signingConfigs {
    release {
        keyAlias 'apt_key'
        keyPassword 'your_key_password'
        storeFile file('release.jks')
        storePassword 'your_store_password'
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

---

## 📝 체크리스트

### 첫 실행 전
- [ ] Flutter 설치 완료
- [ ] Android SDK 설정
- [ ] 에뮬레이터 생성 완료
- [ ] flutter doctor 통과

### 실행
- [ ] 에뮬레이터 실행 (또는 기기 연결)
- [ ] flutter run 또는 build.bat 옵션 4 사용
- [ ] 앱 정상 실행 확인

### 배포
- [ ] 코드 최종 검토
- [ ] flutter analyze 실행
- [ ] flutter test 실행
- [ ] flutter build apk --release 또는 flutter build appbundle --release
- [ ] APK/AAB 파일 생성 확인

---

## 🚀 빠른 실행 명령어

### 한눈에 보기
```powershell
# 1단계: 프로젝트로 이동
cd d:\vsCodeProg\APT-APP

# 2단계: 에뮬레이터 실행 (별도 터미널)
emulator -avd Pixel_6_API_33

# 3단계: 앱 실행
flutter run

# 4단계: 로그 확인
flutter logs

# 5단계: 코드 수정 후 핫 리로드
# flutter run에서 'r' 입력

# 6단계: APK 빌드
flutter build apk --release

# 완성된 APK 위치
# d:\vsCodeProg\APT-APP\build\app\outputs\apk\release\app-release.apk
```

---

## 📦 배포 준비

### Google Play Store 배포
1. App Bundle 빌드
```powershell
flutter build appbundle --release
```

2. [Google Play Console](https://play.google.com/console) 로그인
3. 앱 생성 → APT EV Charging
4. App Bundle 업로드
5. 스크린샷, 설명 추가
6. 검토용 제출

### 직접 배포 (APK)
1. APK 빌드
```powershell
flutter build apk --release
```

2. APK 파일 배포
3. 사용자가 직접 설치

---

## 🔗 유용한 링크

- [Flutter 공식 가이드](https://flutter.dev/docs/deployment/android)
- [Android Studio 다운로드](https://developer.android.com/studio)
- [ADB 명령어](https://developer.android.com/studio/command-line/adb)
- [Google Play Console](https://play.google.com/console)

---

**마지막 업데이트**: 2026년 3월 29일
**상태**: 완전 가이드 작성 완료
