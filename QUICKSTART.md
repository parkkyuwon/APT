# 📱 APT-APP 빠른 시작 가이드

## 🎯 5분 안에 시작하기

### Step 1: 프로젝트 진입
```powershell
cd d:\vsCodeProg\APT-APP
```

### Step 2: 의존성 설치
```powershell
flutter pub get
```
**예상 시간**: 1-2분

### Step 3: 빌드 도구 실행
```powershell
# Windows
.\build.bat

# PowerShell
bash build.sh
```

### Step 4: 메뉴에서 선택

```
1️⃣  의존성 설치 (flutter pub get)
2️⃣  코드 분석 (flutter analyze)
3️⃣  테스트 (flutter test)
4️⃣  ⭐ APK 빌드 (완성된 앱)
5️⃣  App Bundle 빌드 (배포용)
6️⃣  전체 파이프라인 (1 → 2 → 3 → 4)
7️⃣  체크 (필수 도구 확인)
8️⃣  배포 전 확인
9️⃣  정리 (캐시 삭제)
0️⃣  종료
```

---

## 📋 주요 작업별 가이드

### ✅ 앱 빌드하기

#### 옵션 A: 자동 (권장)
```
build.bat 실행 → 옵션 6 선택
```

#### 옵션 B: 수동
```powershell
# 1단계: 코드 확인
flutter analyze

# 2단계: 테스트 실행
flutter test

# 3단계: 앱 빌드
flutter build apk --release
```

**완성된 앱:**
```
📦 d:\vsCodeProg\APT-APP\build\app\outputs\apk\release\app-release.apk
```

---

### 🔍 코드 분석하기

```powershell
flutter analyze
```

**확인사항:**
- ❌ 오류 없음
- ⚠️ 경고 < 10개

---

### 🧪 테스트 실행하기

```powershell
flutter test
```

**확인사항:**
- ✅ 모든 테스트 통과
- ✅ 100% 테스트 완료

---

### 📱 에뮬레이터에서 실행하기

```powershell
# 에뮬레이터 목록 확인
flutter devices

# 앱 실행 (디버그 모드)
flutter run

# 릴리스 모드로 실행 (배포 전 테스트)
flutter run --release

# 로그 보기
flutter logs
```

---

### 🚀 배포용 빌드하기

#### Android
```powershell
# APK (테스트용)
flutter build apk --release
# 출력: build\app\outputs\apk\release\app-release.apk

# App Bundle (Google Play용)
flutter build appbundle --release
# 출력: build\app\outputs\bundle\release\app-release.aab
```

#### iOS (Mac에서만)
```bash
flutter build ios --release
```

---

## 🛠️ 자주 하는 일

### 의존성 업데이트
```powershell
flutter pub upgrade
```

### 캐시 정리
```powershell
flutter clean
flutter pub get
```

### 특정 패키지만 업데이트
```powershell
flutter pub get http:1.1.0
```

### 보안 취약점 확인
```powershell
flutter pub audit
```

---

## ⚠️ 문제 해결

### 문제: "flutter command not found"
**해결**: Flutter 환경 변수 설정 필요
- [WINDOWS_SETUP.md](WINDOWS_SETUP.md) → "1️⃣ Flutter 설치" 섹션 참조

### 문제: "Gradle build failed"
**해결**:
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

### 문제: "Google Sign-In not working"
**해결**: `android/app/google-services.json` 파일 확인
- [SETUP.md](SETUP.md) → "Android 설정" 섹션 참조

### 문제: "API 연결 실패"
**해결**: `lib/config/app_config.dart` 파일 确인
```dart
static const String apiBaseUrl = 'https://your-api-domain.com/api';
```

---

## 📊 빌드 결과

### 성공 시
```
✅ Built build\app\outputs\apk\release\app-release.apk
```

### 실패 시
1. 로그 메시지 읽기
2. 에러 검색: `flutter clean && flutter pub get`
3. [SETUP.md](SETUP.md) 참조

---

## 📦 빌드 산출물

| 파일 | 용도 | 크기 | 위치 |
|------|------|------|------|
| **app-release.apk** | 기기 설치/테스트 | 40-60MB | `build/app/outputs/apk/release/` |
| **app-release.aab** | Google Play 배포 | 30-50MB | `build/app/outputs/bundle/release/` |

---

## 🔐 배포 전 필수 확인

```
□ lib/config/app_config.dart:
  ✅ API 주소 확인
  ✅ Google Client ID 확인
  
□ pubspec.yaml:
  ✅ 버전 업데이트
  ✅ 의존성 최신 버전
  
□ 테스트:
  ✅ flutter test 통과
  ✅ flutter analyze 완료
  ✅ 에뮬레이터/기기 테스트
  
□ 보안:
  ✅ 토큰 안전 저장
  ✅ HTTPS 사용
  ✅ API 키 노출 없음
```

더 자세한 정보는 [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) 참조

---

## 📚 더 알아보기

| 문서 | 내용 |
|------|------|
| [WINDOWS_SETUP.md](WINDOWS_SETUP.md) | Windows PC 상세 설정 |
| [SETUP.md](SETUP.md) | 환경 설정 완전 가이드 |
| [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md) | 배포 체크리스트 |
| [DEVELOPMENT.md](DEVELOPMENT.md) | 개발 진행 상황 |
| [README.md](README.md) | 프로젝트 개요 |

---

## ⏱️ 전체 작업 소요 시간

| 작업 | 시간 |
|------|------|
| 의존성 설치 | 1-2분 |
| 코드 분석 | 30초 |
| 테스트 | 1-2분 |
| **APK 빌드** | **⏱️ 5-10분** |
| App Bundle 빌드 | 3-5분 |
| **전체 프로세스** | **⏱️ 10-20분** |

---

## 🚀 배포 준비 완료!

```
✅ 프로젝트 구조 완성
✅ 개발 도구 준비
✅ 빌드 자동화 스크립트 준비
✅ 배포 가이드 준비
✅ 체크리스트 준비

다음 단계: build.bat 실행 → 옵션 6 선택 → 완료!
```

---

**💡 팁**: 배포 전에 [DEPLOYMENT_CHECKLIST.md](DEPLOYMENT_CHECKLIST.md)의 모든 항목을 확인하세요!

**마지막 업데이트**: 2026년 3월 29일
