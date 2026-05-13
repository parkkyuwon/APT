# APT EV Charging Mobile App

Flutter 기반의 크로스 플래폼(iOS/Android) 모바일 애플리케이션입니다.

## 개요

이 프로젝트는 APT EV 충전 관리 시스템의 모바일 버전으로, 주차장의 EV 충전소 관리 및 사용자 예약 시스템을 제공합니다.

### 주요 기능

#### 공용 기능 (Public User)
- 구글 OAuth 기반 로그인/로그아웃
- EV 충전소 목록 조회 (지도/리스트)
- 충전소 예약
- 사용자 프로필 관리
- 예약 내역 확인
- 활동 로그 조회

#### 관리자 기능 (Admin)
- 사용자 승인/거부 관리
- 통계 및 분석
- 충전소 모니터링
- 활동 로그 조회 및 검색
- QR 코드 관리
- 주차 공간 관리

## 기술 스택

- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **State Management**: Provider
- **API Communication**: HTTP
- **Local Storage**: SQLite, SharedPreferences
- **Authentication**: Google Sign-In
- **Logging**: Logger
- **Security**: flutter_secure_storage

## 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── config/                   # 앱 설정
│   └── app_config.dart
├── models/                   # 데이터 모델
│   └── user.dart
├── services/                 # 비즈니스 로직 및 API
│   ├── api_service.dart
│   ├── auth_service.dart
│   └── ...
├── providers/                # 상태 관리 (Provider)
│   └── auth_provider.dart
├── screens/                  # 화면/페이지
│   ├── auth/
│   ├── public/
│   └── admin/
├── widgets/                  # 재사용 가능 위젯
├── utils/                    # 유틸리티 함수
│   ├── constants.dart
│   ├── themes.dart
│   └── validators.dart
└── config/                   # 설정 파일
    └── app_config.dart
```

## 설치 및 실행

### 필수 요구사항

- Flutter SDK 3.0 이상
- Dart SDK 3.0 이상
- Android Studio 또는 Xcode
- 개발 기기 또는 에뮬레이터

### 설치 단계

1. 저장소 클론
```bash
cd APT-APP
```

2. 의존성 설치
```bash
flutter pub get
```

3. 개발 기기 연결 또는 에뮬레이터 실행

4. 앱 실행
```bash
flutter run
```

## 환경 설정

### 필수 환경 변수

`lib/config/app_config.dart` 파일에서 다음 정보를 설정하세요:

- `API_BASE_URL`: 백엔드 API 주소
- `GOOGLE_CLIENT_ID`: Google OAuth Client ID

### Google Sign-In 설정

#### iOS
1. `ios/Runner/GoogleService-Info.plist` 파일 추가
2. Podfile 업데이트

#### Android
1. `android/app/google-services.json` 파일 추가
2. `android/build.gradle` 업데이트

## 개발 가이드

### 새로운 화면 추가

1. `lib/screens/` 폴더에 새 화면 파일 생성
2. `StatefulWidget` 또는 `StatelessWidget` 상속
3. 필요한 provider 추가

### 새로운 API 엔드포인트 추가

1. `lib/services/api_service.dart`에 메서드 추가
2. 필요시 새로운 모델 생성
3. Provider에서 API 호출

### 상태 관리 추가

1. `lib/providers/` 폴더에 새 provider 클래스 생성
2. `ChangeNotifier` 상속
3. `main.dart`에 Provider 등록

## 테스팅

### 단위 테스트 실행

```bash
flutter test
```

### 특정 테스트 실행

```bash
flutter test test/models/user_test.dart
```

### 통합 테스트 실행

```bash
flutter test integration_test
```

## 빌드 및 배포

### iOS Build
```bash
flutter build ios
```

### Android Build
```bash
flutter build apk
flutter build appbundle
```

## 성능 최적화

- ListView/GridView에 `const` constructor 사용
- 불필요한 재빌드 방지
- 이미지 캐싱 활성화
- 번들 크기 최소화

## 문제 해결

### Google Sign-In이 작동하지 않음
- 클라이언트 ID 확인
- iOS: GoogleService-Info.plist 확인
- Android: google-services.json 확인

### API 연결 오류
- API 서버 상태 확인
- API_BASE_URL 확인
- 네트워크 연결 상태 확인

## 기여 가이드

1. 새로운 기능은 별도의 브랜치에서 개발
2. 커밋 메시지는 명확하게 작성
3. 테스트 코드 추가
4. Pull Request 생성

## 라이선스

이 프로젝트는 개인 프로젝트입니다.

## 연락처

문제나 제안사항이 있으시면 이슈를 생성해주세요.

## 로드맵

- [ ] Phase 1: 기본 프로젝트 구조 (완료)
- [ ] Phase 2: API 레이어 구현
- [ ] Phase 3: 인증 시스템
- [ ] Phase 4: UI/UX 개발
- [ ] Phase 5: 성능 최적화
- [ ] Phase 6: 테스트
- [ ] Phase 7: CI/CD 구축
- [ ] Phase 8: 배포

## 마지막 업데이트

2026년 3월 29일
