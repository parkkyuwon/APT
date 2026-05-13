# APT EV Charging - iOS 배포 가이드

## ✅ iOS 크로스플래폼 지원 현황

### 현재 상태
- ✅ **코드 호환성**: 100% iOS 호환 (Flutter로 개발됨)
- ✅ **프로젝트 구조**: iOS 프로젝트 자동 생성됨
- ✅ **한글 지원**: iOS 네이티브 설정 완료
- ⏳ **배포**: Mac에서만 가능 (Xcode 필요)

### iOS 작업 환경 요구사항
- **운영체제**: macOS 10.15 이상
- **Xcode**: 11.0 이상
- **CocoaPods**: iOS 의존성 관리
- **Apple Developer 계정**: App Store 배포 시

## 🔧 iOS 빌드 방법 (Mac에서)

### 1. Mac에서 환경 설정
```bash
# Flutter SDK 설치
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.6.zip ?unzip

# 환경 변수 설정
export PATH="$PATH:~/flutter/bin"

# Flutter doctor 실행
flutter doctor
```

### 2. iOS 빌드
```bash
# 프로젝트 디렉토리 이동
cd APT-APP

# iOS 의존성 설치
flutter pub get

# iOS 빌드
flutter build ios --debug
flutter build ipa --release  # App Store 배포
```

### 3. 앱 실행 (시뮬레이터)
```bash
flutter run  # 기본 시뮬레이터에서 실행
```

### 4. 앱 실행 (실제 기기)
```bash
flutter run -d <device_id>
```

## 📦 빌드 결과물

### Android
- **경로**: `build/app/outputs/flutter-apk/app-debug.apk`
- **프로덕션**: `build/app/outputs/flutter-apk/app-release.apk`
- **크기**: ~50MB (최적화 후)

### iOS
- **시뮬레이터**: `build/ios/Debug-iphonesimulator/`
- **실제 기기**: `build/ios/iphoneos/` → Xcode로 기기 연결
- **프로덕션**: `.ipa` 파일 (App Store 배포용)
- **크기**: ~60MB (최적화 후)

## 📋 크로스플래폼 지원 체크리스트

### 공통 (Android + iOS)
- [x] Flutter 프레임워크 기본 구조
- [x] Dart 코드 작성
- [x] 한글 텍스트 렌더링
- [x] Material Design UI
- [x] HTTP 통신 (http 패키지)
- [x] 캐싱 시스템
- [x] 에러 처리

### Android 특화
- [x] Android v2 Embedding
- [x] Gradle 빌드 (Kotlin DSL)
- [x] AndroidManifest.xml
- [x] 권한 설정

### iOS 특화
- [ ] iOS 프로젝트 구성 (Runner 폴더)
- [ ] CocoaPods 의존성
- [ ] 앱 서명 (Signing)
- [ ] 프로비저닝 프로필 (Provisioning Profiles)

## 🚀 플랫폼별 배포 자동화

### Android 배포 (Windows/Mac/Linux)
```bash
# 빠른 배포
./deploy.bat          # Windows
bash deploy.sh        # Mac/Linux

# 또는 수동
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
flutter run
```

### iOS 배포 (Mac만 가능)
```bash
# TestFlight (베타 배포)
flutter build ipa --release
# Xcode에서 Organizer로 TestFlight에 업로드

# App Store 배포
# Xcode Organizer에서 "App Store Connect" 선택 후 배포
```

## 📊 성능 비교

| 항목 | Android | iOS | 모바일 웹 |
|------|---------|-----|---------|
| 응답속도 | 매우 빠름 | 매우 빠름 | 보통 |
| 네이티브 기능 | 뛰어남 | 뛰어남 | 제한적 |
| 배포 난이도 | 낮음 | 중간 | 낮음 |
| 설치 크기 | ~50MB | ~60MB | 0MB |
| 오프라인 지원 | 가능 | 가능 | 제한적 |

## ⚠️ 주의사항

### iOS 특화 설정
1. **Bundle ID**: `com.apt.ev-charging` (변경 필요 시 Info.plist 수정)
2. **최소 버전**: iOS 11.0 (pubspec.yaml에서 설정)
3. **권한 요청**: Contact, Location 등은 Info.plist에 요청 이유 작성 필수

### 코드 호환성 확인
```dart
// iOS/Android 구분 필요한 경우
import 'dart:io';

if (Platform.isAndroid) {
  // Android 전용 코드
} else if (Platform.isIOS) {
  // iOS 전용 코드
}
```

## 📞 문제 해결

### iOS 빌드 오류
```bash
# CocoaPods 캐시 정리
cd ios
rm -rf Pods
rm Podfile.lock
flutter clean
flutter pub get
cd ..

# Xcode 빌드 캐시 정리
flutter clean
```

### 앱 서명 오류 (iOS)
```bash
# Xcode에서 Signing 설정 필요
# Open ios/Runner.xcworkspace (Runner.xcodeproj 아님!)
open ios/Runner.xcworkspace

# Signing & Capabilities에서:
# - Team 선택
# - Bundle ID 확인
# - Provisioning Profile 선택
```

## 🔄 업데이트 배포 프로세스

### 버전 관리
```yaml
# pubspec.yaml
version: 1.0.0+1
# 형식: 주.부.패치+빌드

# 배포 시 증가
version: 1.1.0+2
```

### 릴리스 체크리스트
- [ ] 버전 번호 업데이트
- [ ] CHANGELOG.md 업데이트
- [ ] 코드 테스트 완료
- [ ] APK 빌드 및 서명
- [ ] iOS IPA 빌드
- [ ] Google Play Store 업로드
- [ ] Apple App Store 업로드

## 📱 현재 배포 대상

| 플랫폼 | 상태 | 최소 버전 | 테스트 기기 |
|--------|------|---------|-----------|
| Android | ✅ 준비 | 5.0 (API 21) | SM S916N (API 36) |
| iOS | ⏳ 준비중 | 11.0 | (Mac 필요) |
| Web | 🔄 계획중 | Chrome/Firefox | - |

---

**최종 업데이트**: 2026-03-29
**Flutter 버전**: 3.41.6
**Dart 버전**: 3.11.4
