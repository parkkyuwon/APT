# 📱 Android 앱 실행 - 완전 정리

## ✅ 생성된 가이드 문서

### 📖 메인 가이드
1. **[ANDROID_RUN.md](ANDROID_RUN.md)** - 상세 가이드 (전체 프로세스)
2. **[ANDROID_QUICK.md](ANDROID_QUICK.md)** - 빠른 참조 (핵심만)

### 🛠️ 실행 도구
1. **android-run.bat** - Windows 자동 도구
2. **android-run.sh** - Unix/Mac 자동 도구
3. **build.bat** - 통합 빌드 도구

---

## 🚀 3가지 실행 방법

### 방법 1️⃣: 명령어로 직접 실행 (가장 빠름)
```powershell
cd d:\vsCodeProg\APT-APP
emulator -avd Pixel_6_API_33  # 터미널 1에서 (에뮬레이터 준비)
flutter run                    # 터미널 2에서 (앱 실행)
```
**소요시간:** 5-10분

### 방법 2️⃣: 자동 도구 사용 (가장 쉬움)
```powershell
cd d:\vsCodeProg\APT-APP
.\android-run.bat
# 메뉴에서 옵션 선택
# 3: 앱 실행 (디버그)
# 4: 앱 실행 (릴리스)
```
**소요시간:** 클릭만 하면 됨

### 방법 3️⃣: 통합 도구 사용 (모든 기능)
```powershell
cd d:\vsCodeProg\APT-APP
.\build.bat
# 메뉴에서 옵션 선택
# 6: 완전 파이프라인 (clean → build → run)
```
**소요시간:** 10-20분

---

## 📋 환경별 체크리스트

### 초기 설정 (한 번만)
```
□ Flutter 설치 (flutter --version 확인)
□ Android SDK 설정 (ANDROID_HOME 환경변수)
□ 에뮬레이터 생성 또는 기기 준비
□ flutter doctor 통과
□ 의존성 설치 (flutter pub get)
```

### 매번 실행 전
```
□ 에뮬레이터 실행 또는 기기 연결
□ flutter devices로 기기 확인
□ 프로젝트 폴더로 이동
□ flutter run 실행
```

### 배포 전
```
□ 코드 검사: flutter analyze
□ 테스트: flutter test
□ APK 빌드: flutter build apk --release
□ 파일 확인: build/app/outputs/apk/release/app-release.apk
```

---

## 🎯 필수 명령어 요약

| 작업 | 명령어 |
|------|--------|
| **기기 확인** | `flutter devices` |
| **앱 실행** | `flutter run` |
| **릴리스 실행** | `flutter run --release` |
| **로그 보기** | `flutter logs` |
| **디버그 APK** | `flutter build apk --debug` |
| **릴리스 APK** | `flutter build apk --release` |
| **App Bundle** | `flutter build appbundle --release` |
| **캐시 정리** | `flutter clean` |
| **핫 리로드** | flutter run 중에 `r` 입력 |
| **핫 리스타트** | flutter run 중에 `R` 입력 |

---

## 🔥 개발 팁

### 핫 리로드로 빠르게 개발
```
1. flutter run 실행
2. 코드 수정
3. r 키 입력 (1초 내에 반영)
4. 반복
```

### 에뮬레이터 유지
```
- 앱 테스트 후 에뮬레이터 끄지 말기
- 재부팅 시간 절약 (1-2분)
- 다시 flutter run 하면 즉시 설치
```

### 문제 시 기본 해결법
```
1. flutter clean
2. flutter pub get
3. flutter build apk --debug
4. flutter run
```

---

## 📊 빌드 시간 비교

| 상황 | 소요시간 |
|------|----------|
| 첫 `flutter run` | 5-10분 |
| 핫 리로드 | 1-2초 |
| 이후 `flutter run` | 30-60초 |
| 디버그 APK 빌드 (첫) | 5-10분 |
| 디버그 APK 빌드 (이후) | 3-5분 |
| 릴리스 APK 빌드 | 5-15분 |
| App Bundle 빌드 | 5-15분 |

---

## 🎬 실행 흐름도

```
시작
  ↓
[에뮬레이터 또는 기기 준비]
  ↓
android-run.bat 또는 build.bat 실행
  ↓
메뉴에서 옵션 선택
  ↓
├─ 3번: 디버그 실행 → 앱 설치 및 실행
├─ 4번: 릴리스 실행 → 앱 설치 및 실행
├─ 5번: 디버그 APK 생성
├─ 6번: 릴리스 APK 생성
└─ 7번: App Bundle 생성
  ↓
[앱 테스트]
  ↓
완료 또는 다시 선택
```

---

## 📱 실행 가능한 상황

| 상황 | 지원 |
|------|------|
| 에뮬레이터 (API 21+) | ✅ |
| 실제 Android 기기 (5.0+) | ✅ |
| USB 연결 기기 | ✅ |
| 무선 연결 | ⚠️ (고급) |

---

## 🔗 참고 자료

**이 폴더의 모든 문서:**
- [ANDROID_RUN.md](ANDROID_RUN.md) - 완전한 안드로이드 가이드
- [ANDROID_QUICK.md](ANDROID_QUICK.md) - 핵심 빠른 참조
- [KOREAN_ENCODING.md](KOREAN_ENCODING.md) - 한글 지원 설정
- [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) - 배포 전 체크
- [QUICKSTART.md](QUICKSTART.md) - 프로젝트 빠른 시작
- [README.md](README.md) - 프로젝트 개요

**외부 자료:**
- [Flutter 공식 문서](https://flutter.dev/docs/deployment/android)
- [Android Studio 다운로드](https://developer.android.com/studio)
- [Google Play Console](https://play.google.com/console)

---

## 🚀 다음 단계

### 지금 바로 실행
```powershell
cd d:\vsCodeProg\APT-APP
.\android-run.bat
```

### 또는 명령어로
```powershell
# 1단계: 프로젝트로 이동
cd d:\vsCodeProg\APT-APP

# 2단계: 에뮬레이터 시작 (별도 터미널)
emulator -avd Pixel_6_API_33

# 3단계: 앱 실행
flutter run

# 4단계: 핫 리로드 (코드 수정 후)
# 터미널에서 'r' 입력
```

---

## ✅ 상태

```
✅ Android 개발 환경 설정 가이드
✅ 자동 실행 도구 (Batch/Bash)
✅ 상세 가이드 문서
✅ 빠른 참조 문서
✅ 문제 해결 가이드
✅ 한글 지원 설정
✅ 배포 체크리스트

🎯 즉시 실행 가능!
```

---

**마지막 업데이트**: 2026년 3월 29일
**준비 상태**: 완벽하게 준비됨 ✅
**다음**: android-run.bat 실행
