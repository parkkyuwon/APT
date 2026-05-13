# APT EV Charging Mobile App - 환경 설정 가이드

## 1. 필수 환경 변수 설정

### API 서버 주소
`lib/config/app_config.dart` 파일의 `apiBaseUrl` 상수를 업데이트하세요:

```dart
static const String apiBaseUrl = 'https://your-api-domain.com/api';
```

### Google OAuth 클라이언트 ID
```dart
static const String googleClientId = 'your-client-id.apps.googleusercontent.com';
```

---

## 2. Android 플랫폼 설정

### 2.1 Google Sign-In 설정

1. [Google Cloud Console](https://console.cloud.google.com)에서 프로젝트 생성
2. OAuth 2.0 클라이언트 ID 생성 (Android)
3. `android/app/google-services.json` 파일 추가

### 2.2 Gradle 설정

`android/build.gradle`에 다음 추가:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

`android/app/build.gradle`에 다음 추가:
```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation 'com.google.android.gms:play-services-auth:20.5.0'
}
```

### 2.3 AndroidManifest.xml 확인

`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

---

## 3. iOS 플랫폼 설정

### 3.1 Google Sign-In 설정

1. [Google Cloud Console](https://console.cloud.google.com)에서 OAuth 2.0 클라이언트 ID 생성 (iOS)
2. `ios/Runner/GoogleService-Info.plist` 파일 추가
3. URL Scheme 구성

### 3.2 Info.plist 업데이트

`ios/Runner/Info.plist`에 다음 추가:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>your-reversed-client-id</string>
            <string>com.googleusercontent.apps.your-client-id</string>
        </array>
    </dict>
</array>

<key>GIDClientID</key>
<string>YOUR_CLIENT_ID</string>
```

### 3.3 Podfile 업데이트

`ios/Podfile`의 `post_install` 블록:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_LOCATION=1',
      ]
    end
  end
end
```

---

## 4. 로컬 개발 환경 설정

### 4.1 Flutter 버전 확인

```bash
flutter --version
```

최소 요구사항: Flutter 3.0+

### 4.2 의존성 설치

```bash
cd APT-APP
flutter pub get
```

### 4.3 Android 에뮬레이터 실행 (선택사항)

```bash
flutter emulators --launch Pixel_4_API_30
```

### 4.4 iOS 시뮬레이터 실행 (Mac만 해당)

```bash
open -a Simulator
```

### 4.5 먹거리 실행

```bash
flutter run
```

---

## 5. 빌드 설정

### 5.1 안드로이드 APK 빌드

```bash
flutter build apk --release
```

출력 위치: `build/app/outputs/apk/release/app-release.apk`

### 5.2 안드로이드 App Bundle 빌드

```bash
flutter build appbundle --release
```

출력 위치: `build/app/outputs/bundle/release/app-release.aab`

### 5.3 iOS IPA 빌드

```bash
flutter build ios --release
```

---

## 6. 데이터베이스 설정

### 6.1 SQLite 초기화

앱 시작 시 자동으로 초기화됩니다:

```dart
await AppConfig.init();
```

### 6.2 캐시 초기화

```bash
flutter clean
flutter pub get
flutter run
```

---

## 7. 문제 해결

### Google Sign-In 작동 안 함

1. 클라이언트 ID 확인
2. iOS: GoogleService-Info.plist 확인
3. Android: google-services.json 확인
4. URL Scheme 설정 확인

### API 연결 오류

1. API 서버 상태 확인
2. apiBaseUrl 설정 확인
3. 네트워크 연결 상태 확인
4. 요청 타임아웃 확인

### 빌드 오류

```bash
flutter clean
flutter pub get
flutter pub run build_runner clean
flutter pub run build_runner build
```

---

## 8. 보안 체크리스트

- [ ] API 서버 HTTPS 사용
- [ ] Google Client ID 보호
- [ ] 토큰 secure_storage에 저장
- [ ] 위치 권한 요청 시 설명 표시
- [ ] 사용자 동의 확인

---

**마지막 업데이트**: 2026년 3월 29일
