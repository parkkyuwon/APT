# 🌍 한글 깨짐 해결 가이드 (Korean Text Encoding Fix)

## 🔍 문제 분석

한글 텍스트가 제대로 표시되지 않는 원인:

1. **파일 인코딩** - UTF-8이 아닌 다른 인코딩 사용
2. **한글 폰트 미지원** - 기본 시스템 폰트가 한글을 지원하지 않음
3. **Locale 설정** - 앱 로케일이 한국어로 설정되지 않음
4. **텍스트 렌더링** - 특정 환경에서의 문자 렌더링 문제

---

## ✅ 적용된 해결책

### 1️⃣ **Google Fonts 패키지 추가**
✅ `pubspec.yaml`에 `google_fonts: ^6.1.0` 추가
- Noto Sans KR 한글 폰트 자동 다운로드
- 네트워크에서 실시간 폰트 로딩
- iOS/Android 모두 지원

### 2️⃣ **Dart 코드에 한글 폰트 적용**
✅ `lib/utils/themes.dart` 업데이트
```dart
import 'package:google_fonts/google_fonts.dart';

// 모든 TextStyle에 GoogleFonts.notoSansKr() 적용
titleTextStyle: GoogleFonts.notoSansKr(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: Colors.white,
)
```

### 3️⃣ **Windows 배치 파일 인코딩**
✅ `build.bat` UTF-8 지원 추가
```bat
@echo off
chcp 65001 >nul  # UTF-8 인코딩 활성화
```

### 4️⃣ **Android 한글 지원**
✅ 파일 생성/수정:
- `android/app/src/main/AndroidManifest.xml` - UTF-8 선언
- `android/app/src/main/kotlin/MainActivity.kt` - 한국어 로케일 설정
- `android/app/build.gradle` - 한글 리소스 설정
- `android/app/src/main/res/values/strings.xml` - 문자열 리소스

### 5️⃣ **iOS 한글 지원**
✅ 파일 추가:
- `ios/ios_ko_config.plist` - iOS 로케일 및 폰트 설정
- `ios/Runner/GeneratedPluginRegistrant.swift` - 설정 가이드

---

## 🚀 빠른 적용 방법

### Step 1: 의존성 설치
```powershell
cd d:\vsCodeProg\APT-APP
flutter pub get
```

### Step 2: 캐시 정리
```powershell
flutter clean
flutter pub get
```

### Step 3: 앱 실행
```powershell
# 디버그 모드
flutter run

# 릴리스 모드 (배포 전)
flutter run --release
```

---

## 📋 확인 체크리스트

### ✅ 코드 레벨
- [ ] `pubspec.yaml`에 `google_fonts` 패키지 추가됨
- [ ] `lib/utils/themes.dart`에서 `GoogleFonts.notoSansKr()` 사용
- [ ] 모든 Text 위젯이 테마 스타일 적용

### ✅ Android 설정
- [ ] `android/app/build.gradle`에서 `resConfigs "en", "ko"` 설정
- [ ] `MainActivity.kt`에서 한글 로케일 처리
- [ ] `AndroidManifest.xml`에서 UTF-8 인코딩 명시

### ✅ iOS 설정
- [ ] `ios/ios_ko_config.plist` 생성됨
- [ ] Xcode에서 한글 폰트 추가됨
- [ ] `Info.plist`에 폰트 리스트 추가됨

### ✅ Windows 설정
- [ ] `build.bat` 파일에 `chcp 65001` 명령 추가됨
- [ ] 배치 파일이 UTF-8로 인코딩됨

---

## 🔧 추가 트러블슈팅

### 문제: "Noto Sans KR 폰트 다운로드 실패"
**해결**: 인터넷 연결 확인
```powershell
# 캐시 정리 후 재시도
flutter clean
flutter pub get
flutter run
```

### 문제: "특정 화면에서만 한글이 깨짐"
**해결**: 해당 Widget의 TextStyle 확인
```dart
// 반드시 GoogleFonts.notoSansKr() 사용
Text(
  'Hello World',
  style: GoogleFonts.notoSansKr(),  // 추가
)
```

### 문제: "Android 에뮬레이터에서 한글 깨짐"
**해결**: 에뮬레이터 로케일 설정
1. AVD Manager 열기
2. Virtual Device 선택
3. 설정에서 Language를 Korean으로 변경

### 문제: "iOS 시뮬레이터에서 한글 깨짐"
**해결**: Xcode 프로젝트 설정 확인
1. Xcode에서 `ios/Runner.xcworkspace` 열기
2. Runner → Build Phases → Copy Bundle Resources
3. 폰트 파일이 추가되었는지 확인

---

## 📊 파일 목록

### 수정/추가된 파일

| 파일 | 용도 | 상태 |
|------|------|------|
| `pubspec.yaml` | Google Fonts 의존성 추가 | ✅ |
| `lib/utils/themes.dart` | 한글 폰트 적용 | ✅ |
| `build.bat` | UTF-8 인코딩 명령 추가 | ✅ |
| `android/app/build.gradle` | 한글 리소스 설정 | ✅ |
| `android/app/AndroidManifest.xml` | UTF-8 지원 선언 | ✅ |
| `android/app/MainActivity.kt` | 한국어 로케일 설정 | ✅ |
| `android/app/strings.xml` | 문자열 리소스 | ✅ |
| `ios/ios_ko_config.plist` | iOS 폰트 설정 | ✅ |
| `ios/GeneratedPluginRegistrant.swift` | iOS 설정 가이드 | ✅ |

---

## ⚙️ 추가 설정 (선택사항)

### Google Fonts 오프라인 모드
인터넷 없이 한글을 표시하려면 로컬 폰트 파일 필요:

1. [Google Fonts](https://fonts.google.com/?query=noto+sans+korean) 방문
2. "Noto Sans KR" 다운로드
3. `assets/fonts/` 폴더에 TTF 파일 저장
4. `pubspec.yaml` 수정:
```yaml
flutter:
  fonts:
    - family: NotoSansKR
      fonts:
        - asset: assets/fonts/NotoSansKR-Regular.ttf
```

5. 테마에서 사용:
```dart
textStyle: TextStyle(
  fontFamily: 'NotoSansKR',
  fontSize: 16,
)
```

---

## 🧪 테스트 코드

한글 텍스트가 제대로 표시되는지 테스트:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:apt_ev_charging/main.dart';

void main() {
  testWidgets('Korean text display test', (WidgetTester tester) async {
    await tester.pumpWidget(const AptEVChargingApp());
    
    // 한글 텍스트 찾기
    expect(find.text('APT EV Charging'), findsOneWidget);
    expect(find.text('로그인'), findsOneWidget);
    expect(find.text('대시보드'), findsOneWidget);
  });
}
```

---

## 📞 추가 도움

더 자세한 정보:
- [Google Fonts 문서](https://pub.dev/packages/google_fonts)
- [Flutter 로케일 설정](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)
- [Android 다국어 지원](https://developer.android.com/guide/topics/resources/localization)
- [iOS 다국어 지원](https://developer.apple.com/localization/)

---

**마지막 업데이트**: 2026년 3월 29일
**상태**: 한글 지원 완료 ✅
