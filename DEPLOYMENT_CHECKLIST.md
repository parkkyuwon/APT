# 📋 배포 체크리스트 (Pre-Deployment Checklist)

## Phase 1: 개발 환경 확인 ✅

### 1.1 필수 도구
- [ ] Flutter 3.0 이상 설치
- [ ] Dart 3.0 이상 설치
- [ ] Android SDK 설치
- [ ] Git 설치
- [ ] 의존성 모두 설치 (`flutter pub get`)

### 1.2 프로젝트 구조
- [ ] `pubspec.yaml` 파일 존재
- [ ] `lib/main.dart` 파일 존재
- [ ] `android/` 디렉토리 존재
- [ ] `ios/` 디렉토리 존재 (Mac에서 빌드 시)

---

## Phase 2: 코드 품질 검사 ✅

### 2.1 정적 분석
```bash
flutter analyze
```
- [ ] 오류 없음
- [ ] 경고 최소화 (<5개)

### 2.2 테스트
```bash
flutter test
```
- [ ] 모든 테스트 통과
- [ ] 커버리지 >70%

### 2.3 의존성 보안
```bash
flutter pub audit
```
- [ ] 보안 취약점 없음

---

## Phase 3: 앱 설정 확인 ✅

### 3.1 Config 파일 검토
파일: `lib/config/app_config.dart`

```dart
// ✅ 필수 확인 사항:

1. API 서버 주소
   - [ ] const String apiBaseUrl = 'https://your-api.com/api';
   - [ ] HTTPS 사용 (HTTP 아님)
   - [ ] 프로덕션 주소로 변경

2. Google OAuth
   - [ ] googleClientId 올바름
   - [ ] Firebase에 등록된 ID와 일치
```

### 3.2 앱 메타데이터
파일: `pubspec.yaml`

```yaml
name: apt_ev_charging
description: APT EV Charging mobile app
version: 1.0.0+1      # ✅ 버전 확인

environment:
  sdk: ^3.0.0
```

- [ ] 앱 이름 확인
- [ ] 버전 번호 업데이트
- [ ] 설명 작성

### 3.3 플랫폼별 설정

#### Android
파일 위치: `android/app/`

- [ ] `google-services.json` 추가됨
- [ ] `build.gradle`에서:
  ```gradle
  compileSdkVersion 34
  minSdkVersion 21
  targetSdkVersion 34
  ```

- [ ] `AndroidManifest.xml`에서:
  ```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  ```

#### iOS (Mac에서만)
파일 위치: `ios/Runner.xcodeproj`

- [ ] `GoogleService-Info.plist` 추가됨
- [ ] Info.plist에서:
  ```xml
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  ```

---

## Phase 4: 보안 검사 🔒

### 4.1 코드 보안
- [ ] API 키가 코드에 노출되지 않음
- [ ] 비밀번호/토큰이 하드코딩되지 않음
- [ ] 민감한 정보가 로그에 출력되지 않음
- [ ] 예외 처리 충분함

### 4.2 데이터 보안
- [ ] 토큰이 `secure_storage`에 안전히 저장됨
- [ ] API 통신이 모두 HTTPS 사용
- [ ] CORS 설정이 적절함

### 4.3 권한 관리
- [ ] 위치 권한: 필요할 때만 요청
- [ ] 연락처 권한: 필요할 때만 요청
- [ ] 권한 거부 후에도 앱 작동 (graceful degradation)

### 4.4 로그인 보안
- [ ] Google OAuth 2.0 사용
- [ ] 자동 로그아웃 구현
- [ ] 세션 타임아웃 설정
- [ ] 재로그인 처리 논리 있음

---

## Phase 5: 기능 테스트 ✅

### 5.1 핵심 기능
- [ ] 앱 시작 (스플래시 화면)
- [ ] 로그인 (Google Sign-In)
- [ ] 대시보드 로드
- [ ] 로그아웃

### 5.2 네트워크 테스트
- [ ] API 요청/응답 정상
- [ ] 에러 처리 (타임아웃, 500 에러 etc.)
- [ ] 오프라인 모드 동작 (캐시)
- [ ] 느린 네트워크 환경에서 동작

### 5.3 UI/UX 테스트
- [ ] 모든 화면 로드 정상
- [ ] 텍스트 깨짐 없음
- [ ] 이미지 로드 정상
- [ ] 버튼/입력 필드 정상 작동
- [ ] 네비게이션 정상 작동

### 5.4 기기별 테스트
- [ ] 세로 모드 정상
- [ ] 가로 모드 정상
- [ ] 다양한 화면 크기 대응 (5" ~ 7")
- [ ] 다크 모드 대응

---

## Phase 6: 성능 검사 🚀

### 6.1 앱 크기
```bash
flutter build appbundle --release
```
- [ ] APK 크기: < 50MB
- [ ] App Bundle 크기: < 40MB

### 6.2 시작 속도
- [ ] 콜드 스타트: < 3초
- [ ] 핫 스타트: < 1초

### 6.3 메모리 사용
- [ ] 메모리 누수 없음
- [ ] 사용 메모리: < 150MB

### 6.4 배터리 효율
- [ ] 불필요한 백그라운드 작업 없음
- [ ] 위치 서비스 필요할 때만 활성화

---

## Phase 7: 에뮬레이터/기기 테스트 📱

### 7.1 Android 테스트
```bash
flutter run -d <device_id>
flutter run --release
```

테스트 환경:
- [ ] Android 8.0 (API 26)
- [ ] Android 10 (API 29)
- [ ] Android 13 (API 33)
- [ ] 최신 버전

필수 테스트:
- [ ] 로그인 → 대시보드
- [ ] 충전소 목록 로드
- [ ] 예약 기능
- [ ] 로그아웃

### 7.2 iOS 테스트 (Mac에서)
```bash
flutter build ios --release
```

- [ ] iOS 12.0 이상
- [ ] iPhone SE (5")
- [ ] iPhone 14 (6.1")
- [ ] iPad

---

## Phase 8: 배포 준비 📦

### 8.1 키 저장소 생성 (처음 배포 시)
```bash
keytool -genkey-dsa -keystore key.jks -alias aptkey -validity 10000
```
- [ ] 키 저장소 생성됨
- [ ] 암호 안전하게 보관

### 8.2 Release APK 빌드
```bash
flutter build apk --release
```
- [ ] 빌드 성공
- [ ] APK 파일 생성됨: `build/app/outputs/apk/release/app-release.apk`
- [ ] 파일 크기 확인

### 8.3 App Bundle 빌드
```bash
flutter build appbundle --release
```
- [ ] 빌드 성공
- [ ] AAB 파일 생성됨: `build/app/outputs/bundle/release/app-release.aab`

### 8.4 스크린샷 준비
다음 화면의 스크린샷 준비:
- [ ] 로그인 화면
- [ ] 대시보드
- [ ] 충전소 목록
- [ ] 예약 화면
- [ ] 프로필 화면
- [ ] 관리자 패널 (관리자용)

### 8.5 설명 작성
- [ ] 짧은 설명 (80자 이내)
- [ ] 긴 설명 (4,000자 이내)
- [ ] 개선사항 (문장형)

---

## Phase 9: 스토어 배포 🚀

### 9.1 Google Play Store

1. [Google Play Console](https://play.google.com/console) 로그인
2. **앱 만들기** → `APT EV Charging`

필수 정보:
- [ ] 앱 이름
- [ ] 카테고리: `자동차` 또는 `생산성`
- [ ] 콘텐츠 등급 (자동 채우기)
- [ ] 대상 국가/지역
- [ ] 가격: 무료

팀:
- [ ] 개인정보 보호정책 링크
- [ ] 이용약관 링크

스크린샷:
- [ ] 최소 2개 (최대 8개)
- [ ] 해상도: 1080x1920px
- [ ] 포맷: PNG 또는 JPEG

배포:
- [ ] App Bundle (`.aab`) 업로드
- [ ] 모든 필드 완성
- [ ] **검토용으로 제출**

### 9.2 Apple App Store (Mac에서)

1. [App Store Connect](https://appstoreconnect.apple.com) 로그인
2. **앱 만들기** → `APT EV Charging`

필수 정보:
- [ ] 앱 이름 및 번들 ID
- [ ] 카테고리
- [ ] 심사 정보 (연락처, 로그인!)
- [ ] 개인정보보호정책
- [ ] 스크린샷 (6가지 크기)

---

## Phase 10: 배포 후 모니터링 📊

### 10.1 Crash Reporting
- [ ] Firebase Crashlytics 설정
- [ ] 크래시 디버그 심볼 업로드
- [ ] 일일 크래시 리포트 모니터링

### 10.2 사용자 분석
- [ ] Firebase Analytics 활성화
- [ ] 주요 이벤트 추적:
  - 앱 시작
  - 로그인
  - 대시보드 로드
  - 예약 완료

### 10.3 성능 모니터링
- [ ] 느린 네트워크 모니터링
- [ ] 크래시 추적
- [ ] ANR (앱 응답 없음) 모니터링

### 10.4 사용자 피드백
- [ ] 스토어 리뷰 모니터링
- [ ] 사용자 피드백 시스템 구축
- [ ] 버그 신고 채널 운영

---

## 최종 체크리스트

배포 직전 최종 확인:

- [ ] 모든 Phase 완료
- [ ] 테스트 기기에서 정상 작동
- [ ] 보안 검사 완료
- [ ] 성능 최적화 완료
- [ ] 스토어 정보 모두 작성
- [ ] 첫 배포인 경우 개발자 계정 활성화
- [ ] 결제 정보 등록 (필요시)
- [ ] 법률 검토 (개인정보보호정책 등)

---

## 배포 명령어 한눈에

```bash
# 전체 검사 및 빌드
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release

# 생성된 파일 확인
ls -la build/app/outputs/apk/release/
ls -la build/app/outputs/bundle/release/
```

---

**마지막 업데이트**: 2026년 3월 29일
**상태**: 배포 준비 완료 ✅
