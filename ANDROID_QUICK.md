# 🚀 Android 빠른 시작 (Quick Reference)

## ⏱️ 5분 안에 시작하기

### Step 1: 에뮬레이터 또는 기기 준비

#### 옵션 A: 에뮬레이터 사용 (권장)
```powershell
# 터미널 1: Android Studio 또는 명령어로 에뮬레이터 실행
emulator -avd Pixel_6_API_33

# 에뮬레이터 부팅 대기 (1-2분)
```

#### 옵션 B: 실제 기기 사용
```powershell
# USB로 기기 연결
# 기기: 설정 → 개발자 옵션 → USB 디버깅 활성화
```

### Step 2: 기기 확인
```powershell
flutter devices
```

**출력:**
```
2 connected devices:
emulator-5554          (mobile) • Google Pixel 6 • android • Android 13
```

### Step 3: 앱 실행
```powershell
cd d:\vsCodeProg\APT-APP
flutter run
```

**끝! 앱이 실행됩니다** ✅

---

## 🎯 자주 사용하는 명령어

### 앱 실행
```powershell
flutter run                 # 디버그 모드
flutter run --release       # 릴리스 모드
flutter run -d <device_id>  # 특정 기기
```

### APK 빌드
```powershell
flutter build apk --debug           # 디버그 APK
flutter build apk --release         # 릴리스 APK
flutter build appbundle --release   # Google Play용 AAB
```

### 로그 확인
```powershell
flutter logs                    # 실시간 로그
flutter logs | findstr "ERROR"  # 에러만 보기
```

### 정리 및 초기화
```powershell
flutter clean       # 캐시 정리
flutter pub get     # 의존성 재설치
flutter doctor      # 환경 확인
```

---

## 🛠️ 도구별 사용법

### 빠른 실행 도구
```powershell
# Windows
.\android-run.bat

# Unix/Mac
bash android-run.sh
```

메뉴에서 선택:
- 1: 기기 확인
- 2: 에뮬레이터 시작
- 3: 앱 실행 (디버그)
- 4: 앱 실행 (릴리스)
- 5-7: APK/AAB 빌드
- 10: 전체 워크플로우

### 자동 빌드 도구
```powershell
.\build.bat    # 옵션 4 또는 6 선택
```

---

## 🔥 실행 중 활용

터미널에서 **flutter run** 실행 중:

```
r       - 핫 리로드 (코드 변경 반영)
R       - 핫 리스타트 (전체 재시작)
h       - 도움말
d       - 기기 해제
q       - 종료
```

---

## 📊 빌드 속도

| 작업 | 첫 실행 | 이후 |
|------|--------|------|
| flutter run | 5-10분 | 30초 |
| APK 빌드 (debug) | 5-10분 | 3-5분 |
| APK 빌드 (release) | 5-10분 | 5-10분 |

---

## 📁 출력 파일

| 파일 | 크기 | 배포용 이름 | 위치 |
|------|------|-----------|------|
| **Debug APK** | 50-70MB | app-debug.apk | `build/app/outputs/apk/debug/` |
| **Release APK** | 40-60MB | app-release.apk | `build/app/outputs/apk/release/` |
| **App Bundle** | 30-50MB | app-release.aab | `build/app/outputs/bundle/release/` |

---

## ❌ 문제 해결

| 문제 | 해결 |
|------|------|
| "No devices found" | `emulator -avd Pixel_6_API_33` 실행 |
| "Gradle build failed" | `flutter clean && flutter pub get` |
| "Permission denied" | `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned` (PowerShell Admin) |
| "한글 깨짐" | [KOREAN_ENCODING.md](KOREAN_ENCODING.md) 참조 |

---

## ✅ 배포 준비 체크리스트

```
디버그:
  [ ] flutter run 정상 작동
  [ ] 앱 기능 테스트
  [ ] 한글 표시 확인

빌드:
  [ ] flutter analyze (코드 검사)
  [ ] flutter test (테스트)
  [ ] flutter build apk --release (APK 생성)

배포:
  [ ] APK 크기 확인 (< 100MB)
  [ ] PlayStore/GitHub releases 업로드
  [ ] 버전 번호 업데이트
```

---

## 📱 앱 구조 확인

```
lib/
├── main.dart                    # 앱 시작점
├── models/                      # User, ChargingStation, Reservation
├── services/                    # API, Auth, Database
├── providers/                   # 상태 관리 (AuthProvider)
├── screens/                     # Login, Dashboard
└── utils/                       # Themes, Constants, Validators

android/
├── app/
│   ├── build.gradle            # 한글 리소스 설정
│   ├── AndroidManifest.xml
│   ├── src/main/kotlin/        # MainActivity (한국어 로케일)
│   └── src/main/res/values/    # 문자열 리소스
```

---

## 🌐 네트워크 정보

앱이 연결할 서버:
- API Base URL: `lib/config/app_config.dart`에서 설정
- Google OAuth: GOOGLE_CLIENT_ID 설정 필요

**현재 상태:** 로컬 개발 환경 설정
**배포 시:** 프로덕션 서버 주소로 변경 필요

---

## 📚 더 보기

- [전체 Android 가이드](ANDROID_RUN.md)
- [한글 깨짐 해결](KOREAN_ENCODING.md)
- [배포 체크리스트](DEPLOYMENT_CHECKLIST.md)
- [프로젝트 구조](README.md)

---

## 💡 팁

1. **에뮬레이터는 계속 실행 상태 유지** - 재부팅 시간 절약
2. **핫 리로드 사용** - r 키로 빠른 개발
3. **큰 변경은 핫 리스타트** - R 키로 전체 재시작
4. **로그 확인** - `flutter logs | findstr "ERROR"`
5. **배포 전 릴리스 모드로 테스트** - `flutter run --release`

---

**마지막 업데이트**: 2026년 3월 29일
**다음 단계**: `.\android-run.bat` 실행 후 옵션 선택
