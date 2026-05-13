# 🚀 APT EV Charging App - Windows PC 실행 및 배포 가이드

## 1️⃣ Flutter 설치 (Windows)

### 1.1 사전 요구사항
- Windows 10 이상
- 최소 1.64GB 이상의 디스크 공간
- Git for Windows
- Android Studio 또는 Visual Studio Code

### 1.2 Flutter SDK 설치

#### Option 1: 자동 설치 (권장)
```powershell
# Chocolatey 사용 (Windows 패키지 관리자)
choco install flutter
```

#### Option 2: 수동 설치
1. [Flutter 공식 사이트](https://flutter.dev/docs/get-started/install/windows)에서 **flutter_windows_3.x.x-stable.zip** 다운로드
2. C:\ 폴더에 flutter 폴더 생성
3. zip 파일 압축 해제
4. 시스템 환경 변수 설정:
   - 변수명: `FLUTTER_HOME`
   - 변수값: `C:\flutter`
5. PATH에 `C:\flutter\bin` 추가

### 1.3 설치 확인
```powershell
flutter --version
dart --version
flutter doctor
```

**flutter doctor** 출력에서 다음을 확인:
```
✅ Flutter (Channel stable)
✅ Dart
✅ Android toolchain
✅ VS Code
```

---

## 2️⃣ Android Studio 설정 (에뮬레이터 실행용)

### 2.1 Android SDK 설정
```powershell
flutter config --android-studio-path "C:\Program Files\Android\Android Studio"
```

### 2.2 Android 라이선스 동의
```powershell
flutter doctor --android-licenses
# 모든 라이선스에 'Y' 입력
```

### 2.3 Android 에뮬레이터 생성
1. Android Studio 열기
2. **AVD Manager** 열기
3. **Create Virtual Device** 클릭
4. **Pixel 6** 선택
5. **API 33 (Android 13)** 선택
6. **Finish** 클릭

---

## 3️⃣ APT-APP 프로젝트 준비

### 3.1 프로젝트 디렉토리로 이동
```powershell
cd d:\vsCodeProg\APT-APP
```

### 3.2 의존성 설치
```powershell
flutter pub get
```

**예상 출력:**
```
Running "flutter pub get" in APT-APP...
pub get completed, installing 45 packages
```

### 3.3 코드 검사 (선택사항)
```powershell
flutter analyze
```

---

## 4️⃣ PC에서 실행하기

### 방법 1: 빌드 도구 사용 (권장)
```powershell
# Windows
.\build.bat

# Git Bash or PowerShell
bash build.sh
```

메뉴에서 옵션 선택:
- **1**: 의존성 설치
- **2**: 코드 분석
- **3**: 테스트 실행
- **4**: APK 빌드
- **6**: 전체 파이프라인 (모든 검사 → 빌드)

### 방법 2: 직접 명령어 실행

#### 2-1. 에뮬레이터 시작
```powershell
# 사용 가능한 기기 목록 확인
flutter devices

# 에뮬레이터 시작
emulator -avd Pixel_6_API_33

# 또는 Android Studio에서 AVD Manager → 재생 버튼
```

#### 2-2. 앱 실행 (Debug 모드)
```powershell
flutter run

# 특정 기기에서 실행
flutter run -d emulator-5554

# 릴리스 모드 (배포 전 테스트)
flutter run --release
```

#### 2-3. 로그 확인
```powershell
flutter logs
```

---

## 5️⃣ 배포 전 확인 체크리스트

### 5.1 빌드 전 필수 확인
```
□ lib/config/app_config.dart에서:
  □ API_BASE_URL 올바른지 확인
  □ GOOGLE_CLIENT_ID 올바른지 확인

□ pubspec.yaml에서:
  □ 앱 버전 업데이트 (version: 1.0.1+2)
  □ 모든 의존성 최신 버전 확인

□ 코드 품질:
  □ flutter analyze 실행 (경고 없음)
  □ flutter test 실행 (모든 테스트 통과)
```

### 5.2 앱 실행 테스트
```
□ Debug 모드 테스트:
  □ flutter run으로 정상 실행
  □ 로그인 화면 표시
  □ Google Sign-In 작동
  □ 대시보드 로드

□ Release 모드 테스트:
  □ flutter run --release 실행
  □ 앱 성능 확인
  □ 모든 기능 정상 작동
```

### 5.3 보안 검사
```
□ API 통신:
  □ HTTPS 사용 확인
  □ 토큰 안전 저장 확인
  □ 민감한 정보 노출 확인

□ 권한:
  □ AndroidManifest.xml 권한 적절한지 확인
  □ 위치 허가 요청 로직 확인
```

---

## 6️⃣ APK 빌드 및 배포

### 6.1 Release APK 빌드
```powershell
# 방법 1: 빌드 도구 사용
.\build.bat
# 메뉴에서 옵션 4 선택

# 방법 2: 직접 명령어
flutter build apk --release
```

**출력 위치:**
```
build/app/outputs/apk/release/app-release.apk
```

**예상 크기:** 40-60MB

### 6.2 App Bundle 빌드 (Google Play 배포용)
```powershell
# 방법 1: 빌드 도구 사용
.\build.bat
# 메뉴에서 옵션 5 선택

# 방법 2: 직접 명령어
flutter build appbundle --release
```

**출력 위치:**
```
build/app/outputs/bundle/release/app-release.aab
```

### 6.3 빌드 결과 검증
```powershell
# APK 정보 확인
# Windows에서 파일 프로퍼티로 크기, 수정 시간 등 확인

# 또는 PowerShell로
Get-ChildItem build\app\outputs\apk\release\app-release.apk -Recurse
```

---

## 7️⃣ 배포 (Google Play Store)

### 7.1 키 저장소 생성
```powershell
# 첫 배포 시에만 실행
keytool -genkey-dsa -keystore d:\vsCodeProg\APT-APP\key.jks -alias aptkey -validity 10000
```

**정보 입력:**
```
키 저장소 암호: [강력한 비밀번호 입력]
이름과 성: APT EV Charging
조직 단위: Engineering
조직: APT
도시 또는 지역: Seoul
주 또는 도: Seoul
국가 코드: KR
```

### 7.2 서명 설정
1. `android/key.properties` 파일 생성:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=aptkey
storeFile=key.jks
```

2. `android/app/build.gradle` 에 추가:
```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile file(keystoreProperties['storeFile'])
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

### 7.3 Play Store 배포
1. [Google Play Console](https://play.google.com/console) 로그인
2. **앱 만들기** 버튼 클릭
3. 앱 이름: `APT EV Charging`
4. 카테고리: 자동차 또는 생산성
5. App Bundle (`.aab` 파일) 업로드
6. 스크린샷, 설명, 개인정보보호정책 추가
7. **검토용으로 제출**

---

## 8️⃣ 문제 해결

### 문제: "flutter: command not found"
```powershell
# 해결책 1: 환경 변수 다시 설정
# 제어판 → 시스템 → 고급 시스템 설정 → 환경 변수
# PATH에 C:\flutter\bin 추가 후 재부팅

# 해결책 2: PowerShell 재시작 또는 새 터미널 열기
```

### 문제: "Android toolchain not installed"
```powershell
flutter doctor --android-licenses
```

### 문제: "Gradle build failed"
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

### 문제: "Google Sign-In not working"
- `google-services.json` 파일 위치 확인: `android/app/`
- Client ID가 Firebase 설정과 일치하는지 확인

### 문제: "API connection failed"
- `lib/config/app_config.dart`의 `apiBaseUrl` 확인
- API 서버 작동 확인
- 네트워크 연결 확인

---

## 9️⃣ 유용한 명령어

```powershell
# 기기 목록 확인
flutter devices

# 특정 로그 필터링
flutter logs | findstr "ERROR|WARNING"

# 캐시 정리 (문제 발생 시)
flutter clean

# 새로운 버전 확인
flutter upgrade

# 플러그인 업데이트
flutter pub upgrade

# 프로젝트 정보 확인
flutter pub list-package-versions
```

---

## 🔟 GIT 커밋 전 체크리스트

```powershell
# 배포 전에 실행
.\build.bat
# 메뉴에서 옵션 7 선택: 프리플라이트 체크
```

커밋 메시지 예:
```
feat: APT-APP v1.0.0 - Android Release

- 의존성 업데이트
- Google Sign-In 구현
- 대시보드 UI 완성
- 배포 전 테스트 완료
```

---

## 📞 참고 자료

- [Flutter 공식 문서](https://flutter.dev/docs)
- [Dart 문서](https://dart.dev/guides)
- [Google Play 배포 가이드](https://developer.android.com/distribute)
- [Firebase 설정](https://firebase.google.com/docs/auth/android/google-signin)

---

**마지막 업데이트**: 2026년 3월 29일
**작성자**: APT EV Charging Dev Team
