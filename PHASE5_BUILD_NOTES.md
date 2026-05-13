# Phase 5 — 안정화 & 빌드 검증 결과

## 검증 일자
2026-04-25

## 빌드 결과 요약

| 산출물 | 크기 | 경로 | 비고 |
| --- | --- | --- | --- |
| debug APK | 163 MB | `build/app/outputs/flutter-apk/app-debug.apk` | 3개 아키텍처 + 디버그 심볼 |
| release APK (3-arch) | 67 MB | `build/app/outputs/flutter-apk/app-release.apk` | 설치 파일, 3-arch fat |
| release AAB | 52 MB | `build/app/outputs/bundle/release/app-release.aab` | **Play Store 업로드용** |

### 아키텍처별 네이티브 라이브러리 분포
| ABI | 압축 크기 | 실제 설치 다운로드 |
| --- | --- | --- |
| arm64-v8a | 21.3 MB | 현대 Android 기기 대부분 |
| armeabi-v7a | 17.6 MB | 구형 32-bit |
| x86_64 | 23.9 MB | Android emulator / ChromeOS |

Play Store가 AAB를 업로드받아 **사용자 기기의 ABI에 맞는 APK만 제공**하므로, 실 사용자 다운로드 크기는 약 **22 MB** (arm64 기준). 플랜의 "<40 MB 다운로드" 목표 달성.

### 16KB 페이지 크기 호환성 (Android 15+ 대응)
```
arm64-v8a libapp.so    LOAD align = 0x10000 (64 KB) ✅
arm64-v8a libflutter.so LOAD align = 0x10000 (64 KB) ✅
```
요구되는 `0x4000` (16 KB) 보다 크므로 Android 15의 16KB 페이지 요구사항 충족.

## 단위 테스트
경로: `test/`
| 파일 | 테스트 대상 |
| --- | --- |
| `duration_presets_test.dart` | 충전시간 포맷/파싱 왕복, 프리셋 생성, datetime-local 파싱 |
| `etag_cache_test.dart` | ETag 저장/조회/무효화 + LRU 축출 |
| `errors_test.dart` | `AuthStatus` 파서 + `ApiException` 플래그 |
| `app_state_test.dart` | `AppState.empty()` 기본값, JSON 파싱, 점유 카운팅 |

### 테스트 실행 상태
- **코드 작성**: 완료 (flutter_test 표준 문법)
- **`flutter analyze`**: 통과 (0 issues)
- **`flutter test` 실제 실행**: ⚠️ 한글 사용자명 환경에서 `flutter_tester` 가
  "Could not prepare isolate" 로 isolate 로드 실패 — Android 빌드와 동일한
  한글 경로 이슈 계열. CI (ASCII 사용자) 환경에서는 정상 실행될 예정.
  현재 환경에서 검증하려면 `dart test` 로는 불가 (flutter_test 의존). 대안:
  1. Dart-only 유틸 함수로 리팩터링하여 `package:test` 로 실행
  2. CI 에서만 통합 검증

## 릴리스 로그 가드
- `lib/core/api_client.dart` 의 `_DebugInterceptor` 는 `kDebugMode` 로 가드됨
- 릴리스 빌드에서는 네트워크 요청 로그가 출력되지 않음
- `debugPrint` 호출은 릴리스에서 자동 무음 처리

## ProGuard/R8 규칙
`android/app/proguard-rules.pro`:
- Flutter, Google Sign-In, ML Kit (mobile_scanner), Dio/OkHttp
- flutter_secure_storage (AndroidX Security + Tink + BouncyCastle)
- image_picker, Kotlin metadata

R8 활성화 후 빌드 성공 → 코드 난독화/트리쉐이킹 적용됨.

## Font 최적화
```
Font asset "MaterialIcons-Regular.otf" was tree-shaken,
reducing it from 1,645,184 to 6,192 bytes (99.6% reduction)
```
사용된 아이콘만 번들되어 앱 크기 감소.

---

## ⚠️ Windows + 한글 사용자명 빌드 환경 이슈 (중요)

### 증상
`C:\Users\박규원\...` 처럼 사용자명이 non-ASCII 인 경우 Kotlin 컴파일러가 경로를
`\u` 이스케이프 (`C:\Users박uADDCuC6D0\...`) 로 변환해 **파일을 찾지 못해
Gradle 빌드 실패**. 다음과 같은 에러가 발생:
```
error: source file or directory not found:
C:\Users박uADDCuC6D0\AppData\Local\Pub\Cache\...
```

### 회피 방법 (빌드 성공한 환경 설정)

1. **ASCII pub cache 경로로 이전**
   ```
   setx PUB_CACHE "C:\pub-cache"
   ```
2. **ASCII Gradle user home**
   ```
   setx GRADLE_USER_HOME "C:\gradle-user"
   ```
3. **Android SDK junction (ASCII 경로)**
   ```powershell
   New-Item -ItemType Junction -Path "C:\android-sdk" `
           -Value "C:\Users\박규원\AppData\Local\Android\sdk"
   ```
4. **Flutter 설정**
   ```
   flutter config --android-sdk "C:\android-sdk"
   ```
5. **환경변수 export**
   ```
   setx ANDROID_SDK_ROOT "C:\android-sdk"
   setx ANDROID_HOME     "C:\android-sdk"
   ```
6. **`android/local.properties` 의 `sdk.dir=C:\\android-sdk`**

**최초 1회** Gradle 캐시 완전 삭제 필요:
```
rd /s /q "%GRADLE_USER_HOME%\caches"
rd /s /q "%PROJECT%\android\.gradle"
rd /s /q "%PROJECT%\build"
flutter clean
flutter pub get
flutter build apk --release ...
```

### CI/CD 권고
- GitHub Actions `windows-latest` 러너는 사용자명이 `runneradmin` (ASCII) 이므로
  본 이슈 미발생
- 로컬 개발자가 한글 사용자명을 쓰는 경우 위 회피 방법을 README 에 명시

## 주요 의존성 주의사항
- `mobile_scanner 5.2.3` — Kotlin 2.2 와 조합 시 deprecation 경고 다수 (동작에는
  영향 없음). 7.x 버전 업그레이드 시 `RenderScript` API 변경 필요.
- `appbundle` 빌드 시 `Release app bundle failed to strip debug symbols` 경고
  발생 가능 (NDK 도구 문제) — AAB 자체는 정상 생성됨.

## Phase 5 검증 완료 항목
- [x] debug APK 빌드 성공
- [x] release APK 빌드 성공 (67 MB 3-arch)
- [x] release AAB 빌드 성공 (52 MB → 사용자 다운로드 ~22 MB)
- [x] 16 KB 페이지 정렬 검증
- [x] R8 코드 축소 활성화
- [x] 한글 폰트(Noto Sans KR) 번들링 + MaterialIcons tree-shake
- [x] 단위 테스트 4개 파일 작성 (duration_presets, etag_cache, errors, app_state)
- [x] 릴리스 로그 kDebugMode 가드 검증
- [x] ProGuard 규칙 등록 (google_sign_in, mobile_scanner, flutter_secure_storage 등)
