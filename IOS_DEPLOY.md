# iOS 빌드·배포 가이드 (Phase 7)

본 앱은 코드 수준에서 iOS 호환이 보장되어 있으나 실제 빌드/심사는 **macOS + Xcode 환경**이 필요합니다. 본 문서는 Mac 환경이 생겼을 때 수행할 절차를 정리한 런북입니다.

---

## 호환성 현황

### 공통 (Android + iOS)
- ✅ Flutter 3.0+ 프레임워크 기본 구조
- ✅ Dart 코드 100% 공유
- ✅ 한글 텍스트 렌더링 (Noto Sans KR + iOS 내장)
- ✅ HTTP 통신 (`dio` + `cookie_jar`)
- ✅ 보안 저장소 (`flutter_secure_storage` → iOS Keychain)
- ✅ Google 로그인 (`google_sign_in` 7.x)
- ✅ 이미지 피커 (카메라 + 갤러리)
- ✅ QR 생성 (`qr_flutter`) / 스캔 (`mobile_scanner`)
- ✅ URL 열기, 외부 링크

### iOS 특화 설정 완료 (Phase 0)
- ✅ Xcode 프로젝트 스캐폴딩 (`flutter create --platforms=ios` 완료)
- ✅ 번들 ID: `com.bluetilelab.aptEvCharging` (iOS 자동 생성)
- ✅ `CFBundleDisplayName = APT EV 충전` (한글 앱명)
- ✅ `CFBundleDevelopmentRegion = ko`, `CFBundleLocalizations = [ko, en]`
- ✅ 카메라 권한 설명: `NSCameraUsageDescription`
- ✅ 사진 라이브러리: `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription`
- ✅ `NSAllowsArbitraryLoads = false` (HTTPS 강제)

### iOS 전용 추가 작업 (Mac에서 수행)
- ⏳ CocoaPods 의존성 설치 (`pod install`)
- ⏳ Xcode 서명 프로필 설정
- ⏳ Apple Developer 계정 등록 ($99/년)
- ⏳ App Store Connect 앱 생성
- ⏳ TestFlight / App Store 심사 제출

---

## 사전 준비 (Mac 1회)

### 필수 도구
| 도구 | 최소 버전 | 설치 방법 |
| --- | --- | --- |
| macOS | 12 Monterey | — |
| Xcode | 15.0+ | App Store |
| Command Line Tools | — | `xcode-select --install` |
| CocoaPods | 1.13+ | `sudo gem install cocoapods` |
| Flutter | 3.0+ | [flutter.dev/setup](https://docs.flutter.dev/get-started/install/macos) |

### Apple Developer 계정
- [ ] [developer.apple.com](https://developer.apple.com) 가입
- [ ] **개인 $99/년** 또는 조직 $99/년 결제
- [ ] 본인 인증 + 2FA 설정

---

## 프로젝트 이전

### Git으로 옮기기 (권장)
```bash
# Mac 에서
git clone <이 저장소>
cd APT-APP
flutter pub get
cd ios
pod install
cd ..
```

### 파일 복사로 옮기기
`D:/vsCodeProg/APT-APP/` 전체를 복사. **제외 필수**:
- `build/`
- `.dart_tool/`
- `android/.gradle/`
- `ios/Pods/` (첫 빌드 시 재생성)
- `ios/Podfile.lock` (빌드 시 재생성)

---

## iOS 로컬 빌드

### 시뮬레이터 실행
```bash
cd APT-APP
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app \
  --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com
```

Xcode Simulator 자동 기동 → iPhone 15 등에서 확인.

### 실기기 빌드 (디버그)
1. iPhone을 Mac에 USB 연결 → 신뢰
2. Xcode: `Runner.xcworkspace` 열기
3. **Signing & Capabilities** → Team 선택 → Bundle ID 유일화 (자동 프로비저닝)
4. `flutter run` 실행

### 릴리스 빌드 (심사용)
```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app \
  --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com \
  --export-options-plist=ios/ExportOptions.plist
```

결과: `build/ios/ipa/apt_ev_charging.ipa` (~40-50 MB 예상)

---

## Google 로그인 설정 (iOS 전용)

### REVERSED_CLIENT_ID 추가
Google Cloud Console 에서 **iOS OAuth 클라이언트** 생성:
- 번들 ID: `com.bluetilelab.aptEvCharging`
- 클라이언트 ID 확인

`ios/Runner/Info.plist` 에 URL scheme 추가:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- iOS OAuth 클라이언트 ID를 역순으로 붙여넣기 -->
      <!-- 예: com.googleusercontent.apps.838650325157-xxxx -->
      <string>com.googleusercontent.apps.YOUR_IOS_CLIENT_ID_REVERSED</string>
    </array>
  </dict>
</array>
```

**중요**: Flutter 의 `google_sign_in` 7.x 는 `serverClientId: <웹 클라이언트 ID>` 를 사용하므로 idToken audience 는 그대로 웹 ID. 백엔드 `GOOGLE_CLIENT_ID` 변경 불요.

---

## App Store Connect 등록

### 새 앱 만들기
1. [App Store Connect](https://appstoreconnect.apple.com) → 내 앱 → **+**
2. 플랫폼: iOS
3. 이름: `APT EV 충전`
4. 기본 언어: 한국어
5. 번들 ID: `com.bluetilelab.aptEvCharging` (Apple Developer 에서 먼저 등록)
6. SKU: `APT-EV-001`
7. 사용자 액세스: 전체 액세스

### 앱 정보 입력
| 항목 | 값 |
| --- | --- |
| 카테고리 (기본) | 자동차 (Auto & Vehicles) |
| 카테고리 (보조) | 생산성 (Productivity) |
| 콘텐츠 권한 | 없음 |
| 연령 등급 | 4+ |
| 가격 | 무료 |

### 스크린샷 (iOS)
iOS 는 여러 기기 크기 필요:
- **6.7인치** (iPhone 15 Pro Max, 1290×2796): 필수
- **5.5인치** (iPhone 8 Plus, 1242×2208): 필수 (v17 이전 호환)
- **iPad Pro 12.9인치** (2048×2732): 선택

→ Android 스크린샷 1080×1920 → **이미지 리사이즈/크롭 도구**로 변환 권장 (Figma, Sketch)

### 개인정보 정책
- 개인정보처리방침 URL: `https://apt-ev-charging.vercel.app/privacy.html`
- 데이터 수집 설문 (App Privacy): Android Data Safety 와 동일 답변

### 앱 심사 정보
- 연락처: 이름, 전화번호, 이메일
- **심사용 로그인 계정**: 관리자 승인된 테스트 Google 계정 제공
- 메모: "관리자 승인이 필요한 아파트 입주민 전용 앱. 제공된 테스트 계정은 사전 승인되어 있음"

---

## TestFlight 배포

### 업로드
```bash
# Xcode Organizer 로 업로드
# 또는 Transporter 앱 사용
```

1. Xcode → **Product → Archive** (Release 구성)
2. Organizer → **Distribute App** → App Store Connect
3. 업로드 완료 후 App Store Connect → TestFlight → 빌드 처리 완료 대기 (10~30분)

### 테스터 초대
- 내부 테스터: Apple 개발자 계정 구성원만 (즉시 설치)
- 외부 테스터: 이메일 초대 + **Apple 심사 필요** (1~2일)

### 검증 항목
TestFlight 는 Play Store 내부 테스트와 동일 역할.
→ [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md#54-골든-플로우-실기기-검증) 의 골든 플로우 10개 항목 재수행.

---

## App Store 프로덕션 심사

### 제출
1. App Store Connect → 앱 → **버전 정보** 에서 빌드 선택
2. 모든 필드 작성 완료 확인
3. **심사용 제출** 클릭
4. 심사 대기: **24~48시간** (신규 앱은 최대 1주)

### 심사 거부 빈발 사유
| 사유 | 대응 |
| --- | --- |
| Guideline 5.1.1 — 개인정보처리방침 문제 | URL 접근 가능 확인 |
| Guideline 4.0 — 최소 기능 | 실제 기능 시연 동영상 첨부 |
| Guideline 2.1 — 앱 정보 부정확 | 스크린샷/설명 재확인 |
| Guideline 5.1.2 — 계정 삭제 | 앱 내 탈퇴 버튼 위치 안내 |

거부 시 Resolution Center 에서 답변 → 24시간 내 재검토.

---

## Windows에서 준비 가능한 항목

Mac이 없어도 Windows에서 미리 준비 가능:

- [x] iOS 프로젝트 스캐폴드 (완료)
- [x] Info.plist 한글 + 권한 설명 (완료)
- [x] pubspec.yaml 의존성이 iOS 모두 지원하는지 확인 (완료)
- [ ] 아이콘 / 스크린샷 이미지 자산 (Android와 공유)
- [ ] 개인정보처리방침 / 계정 삭제 URL (완료, Vercel 배포 대기)
- [ ] 심사용 테스트 Google 계정 (Play Store 와 공유 가능)

---

## CI 스모크 빌드 (GitHub Actions)

iOS 코드 변경이 빌드 깨지지 않는지 조기 감지.

`.github/workflows/ios-smoke.yml` (신규 생성):
```yaml
name: iOS Smoke Build

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.41.6'
          channel: 'stable'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter build ios --no-codesign \
          --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app \
          --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com \
          --dart-define=APP_ENV=prod
```

서명 없이 컴파일만 검증. 실제 심사/배포는 수동 Xcode 절차 필요.

---

## 요약 — iOS 로드맵

| 단계 | 소요 | Mac 필요 | 비용 |
| --- | --- | --- | --- |
| 0. 사전 준비 | 1일 | ✅ | $99 |
| 1. 프로젝트 이전 + pod install | 1시간 | ✅ | — |
| 2. 로컬 시뮬레이터 검증 | 2~4시간 | ✅ | — |
| 3. 실기기 디버그 빌드 | 1시간 | ✅ | — |
| 4. Google 로그인 iOS 설정 | 1시간 | ✅ | — |
| 5. App Store Connect 앱 생성 | 2시간 | 🖥 | — |
| 6. 스크린샷 준비 (iOS 크기) | 반나절 | 🖥 | — |
| 7. TestFlight 업로드 | 1시간 | ✅ | — |
| 8. 내부·외부 테스트 | 1~2주 | — | — |
| 9. App Store 심사 제출 | 1일 | ✅ | — |
| 10. 심사 대기 | 1~7일 | — | — |

**Mac 확보 시 총 소요**: 실작업 **2주**, 심사 대기 포함 **3~4주**.
