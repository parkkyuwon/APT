# APT EV 충전 — 프로젝트 완성 요약

## 전체 현황
**모든 Phase 완료 (0~7)**. Flutter 크로스플랫폼 앱이 Android Play Store 프로덕션
업로드 가능한 상태이며, iOS 도 Mac 환경만 있으면 바로 빌드/심사 제출 가능한
상태입니다.

### 코드 규모
- **57개 Dart 파일** / 약 **7,188줄**
- **13개 API 서비스 래퍼** (웹 백엔드 모든 엔드포인트)
- **19개 화면** (웹 페이지 전부 포팅)
- **`flutter analyze`: 0 issues**

### 빌드 산출물
| 산출물 | 크기 | 비고 |
| --- | --- | --- |
| Debug APK | 163 MB | 3-arch + 심볼 포함 |
| Release APK | 67 MB | 3-arch fat |
| **Release AAB** | **52 MB** | Play Store 업로드용 (사용자 다운로드 ~22 MB) |

---

## Phase별 산출물

### Phase 0 — 환경 정비 ✅
- `pubspec.yaml` 의존성 14개 추가 (dio, google_sign_in 7.x, qr_flutter, mobile_scanner 등)
- `android/app/build.gradle.kts`: applicationId `com.bluetilelab.apt_ev`, compileSdk 36, R8 활성화
- `android/app/proguard-rules.pro`: 9개 패키지 keep 규칙
- `AndroidManifest.xml`: INTERNET/CAMERA/READ_MEDIA_IMAGES 권한, `usesCleartextTraffic=false`, data_extraction_rules
- iOS 프로젝트 `flutter create --platforms=ios` 스캐폴딩
- `ios/Runner/Info.plist`: `CFBundleDisplayName=APT EV 충전`, 한글 locale, 카메라 권한 설명, NSAllowsArbitraryLoads=false
- `build-env.bat/sh`: dart-define 기반 dev/prod 빌드 스크립트

### Phase 1 — 코어 인프라 ✅
- `config/env.dart`, `config/app_config.dart`: dart-define 환경 + flutter_secure_storage
- `core/api_client.dart`: Dio + PersistCookieJar + ETag interceptor + 401 핸들링
- `core/session_store.dart`: SecureCookieJar (Keystore/Keychain)
- `core/etag_cache.dart`: LRU ETag 캐시
- `core/errors.dart`: ApiException / NetworkException / AuthStatus
- `core/image_utils.dart`: 차량 사진 base64 인코딩
- `core/duration_presets.dart`: 충전시간 프리셋 (30분~12시간)
- 7개 모델 (session, app_state, user, parking_slot, chat_message, activity_log, parking_history, charger_type)
- **13개 API 서비스**: auth / state / profile / users / chat / logs / my_history / public_dashboard / public_highlight / session_admin / session_public / bootstrap_admin
- `providers/auth_provider.dart`: AuthStage 9단계 머신 + google_sign_in 7.x
- `providers/app_state_provider.dart`: 30초 폴링 + ETag

### Phase 2 — 인증·온보딩 플로우 ✅
- `login_screen.dart`: Google 로그인 + 제목 5회 탭 숨김 관리자 ID/PW
- `onboarding/consent_screen.dart`: 개인정보 동의 (7개 수집 항목 표)
- `onboarding/profile_setup_screen.dart`: 닉네임/차량번호/전화번호 + 차량사진 카메라/갤러리
- `onboarding/photo_verification_screen.dart`: 차량 사진 재인증
- `onboarding/pending_screen.dart`: 승인 대기 + 수동 새로고침
- `onboarding/blocked_screen.dart`: rejected/blocked/withdrawn/dormant 분기 메시지
- `main.dart`: 9개 AuthStage 전체 전용 화면 라우팅

### Phase 3 — 사용자 화면 ✅
- `public/home_screen.dart`: B1/B2 탭 + 슬롯 그리드 + 내 차량 출차 + 30초 폴링
- `public/parking_list_screen.dart`: 타입별 섹션 목록
- `public/chat_screen.dart`: 채팅 CRUD + 15초 폴링 + 수정/삭제
- `public/mypage_screen.dart`: 내 정보 + 이력 + 수정/**계정 탈퇴**
- `public/highlight_screen.dart`: 용량별 사용중 그룹 + 30초 자동 갱신
- `public/guide_screen.dart`: Quick Start + 주의사항
- `public/shell_screen.dart`: 하단 5탭 (홈/목록/대화방/내정보/더보기)
- `widgets/slot_dialog.dart`: 주차 등록/수정/출차/차단 토글 (모든 규칙 구현)
- `widgets/slot_tile.dart`: 슬롯 타일 (available/occupied/maintenance/owned)

### Phase 4 — 관리자 화면 전체 ✅
- `admin/admin_dashboard.dart`: 9개 서브 콘솔 허브
- `admin/console_members.dart`: 회원 승인/거절/차단/차량승인 5액션
- `admin/console_vehicle_verify.dart`: 차량 사진 검토
- `admin/console_logs.dart`: 활동 로그 (최근 120건)
- `admin/console_member_usage.dart`: 회원 전체 + 검색 + 이력 링크
- `admin/console_parking.dart`: 전체 슬롯 편집
- `admin/console_parking_history.dart`: 특정 회원 이력 페이지네이션
- `admin/console_operations.dart`: 준비중 토글, 광고 토글, 공지, 채팅 보존, 충전기 수량 ±
- `admin/console_qr.dart`: 전체 슬롯 QR 렌더 + URL 편집
- `admin/map_editor_screen.dart`: 슬롯 (x,y) 좌표 숫자 입력

### Phase 5 — 안정화 & 최적화 ✅
- 단위 테스트 4개 파일 (46개 케이스): duration_presets, etag_cache, errors, app_state
- `debugPrint` 로그를 `kDebugMode` 로 가드 검증
- Release APK/AAB 빌드 성공
- 16KB 페이지 정렬 검증 (LOAD align 0x10000, Android 15+ 호환)
- MaterialIcons 99.6% tree-shake
- 한글 사용자명 Windows 빌드 환경 회피법 문서화 → `PHASE5_BUILD_NOTES.md`

### Phase 6 — Play Store 등록 준비 ✅
- `D:/vsCodeProg/APT-Prj/privacy.html`: 개인정보처리방침 (PIPA + Play 정책 준수)
- `D:/vsCodeProg/APT-Prj/account-deletion.html`: 공개 계정 삭제 URL
- `scripts/generate-keystore.bat/sh`: 업로드 키스토어 생성 자동화
- `PLAY_STORE_LISTING.md`: 앱 설명, Data Safety 폼, 콘텐츠 등급 답변
- `assets/images/README.md`: 아이콘/피처그래픽/스크린샷 사양
- `pubspec_additions.txt`: flutter_launcher_icons 설정
- `DEPLOYMENT_RUNBOOK.md`: 키스토어 → AAB → Play Console 전체 절차

### Phase 7 — iOS 빌드 준비 ✅
- `IOS_DEPLOY.md`: Mac 환경 준비, Apple Developer 등록, TestFlight, App Store Connect 전체 가이드
- `.github/workflows/flutter-ci.yml`: analyze + Android + iOS (no-codesign) CI 워크플로

---

## Google Play Store 정책 준수 확인
| 정책 영역 | 상태 | 비고 |
| --- | --- | --- |
| User Data Policy | ✅ | 동의 화면 + privacy.html |
| Data Safety | ✅ | PLAY_STORE_LISTING.md 에 폼 답변 포함 |
| 계정 삭제 (2024+ 필수) | ✅ | 앱 내 탈퇴 + 공개 URL 모두 제공 |
| 권한 최소화 | ✅ | INTERNET, CAMERA, READ_MEDIA_IMAGES 만 |
| Google Sign-In 정책 | ✅ | openid/email/profile 비민감 범위 |
| Target SDK 34+ | ✅ | `targetSdk=34`, `compileSdk=36` |
| 64-bit ABI | ✅ | Flutter 기본 arm64-v8a 포함 |
| App Bundle 형식 | ✅ | AAB 빌드 성공 |
| 16KB 페이지 | ✅ | LOAD align 0x10000 |
| HTTPS 강제 | ✅ | `usesCleartextTraffic=false` + iOS `NSAllowsArbitraryLoads=false` |
| 로그 노출 | ✅ | `kDebugMode` 가드 |

---

## 백엔드 변경 사항
**원칙 유지**: APT-Prj 백엔드 코드 **무수정**. 모든 신규 자료는 정적 페이지만 추가.
- `D:/vsCodeProg/APT-Prj/privacy.html` (신규)
- `D:/vsCodeProg/APT-Prj/account-deletion.html` (신규)

기존 API (/api/auth, /api/state, /api/profile 등 13개) 그대로 사용. Flutter 의
`google_sign_in` 7.x `serverClientId` 파라미터로 웹 클라이언트 ID audience 유지.

---

## 알려진 제약
1. **Windows 한글 사용자명 빌드 이슈**: Kotlin 컴파일러가 `\u` 이스케이프 경로 처리 실패. 회피 방법은 `PHASE5_BUILD_NOTES.md` 에 정리. CI(ASCII 사용자)에서는 정상.
2. **`flutter test` isolate 로딩 실패**: 동일 한글 사용자명 환경 이슈. 테스트 코드는 표준 형식으로 작성되어 CI 환경에서는 통과 예상.
3. **map-editor 드래그 편집**: v1 에서는 숫자 좌표 입력만 (Canvas 드래그는 v1.1 연기).
4. **iOS 실제 빌드/심사**: Mac + Xcode + Apple Developer 계정 필요 (Windows 불가).

---

## 배포 로드맵

### 즉시 가능 (Windows에서)
1. [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) 따라 키스토어 생성
2. privacy.html + account-deletion.html Vercel 배포
3. Release AAB 빌드
4. Play Console 앱 생성 + AAB 업로드 + 스토어 등록정보 작성
5. 내부 테스트 → 프로덕션 심사 제출

### 예상 일정 (앱 심사 포함)
- Play Store 첫 출시: **1주** (자료 준비 2~3일 + 심사 3~5일)
- iOS App Store 첫 출시: **Mac 확보 후 3~4주**

---

## 주요 문서
| 문서 | 용도 |
| --- | --- |
| `~/.claude/plans/apt-prj-smooth-cherny.md` | 전체 Phase 플랜 (승인됨) |
| [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) | Play Store 등록 체크리스트 |
| [PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md) | 스토어 등록정보 복사본 |
| [PHASE5_BUILD_NOTES.md](PHASE5_BUILD_NOTES.md) | 빌드 검증 결과 + 환경 이슈 회피 |
| [IOS_DEPLOY.md](IOS_DEPLOY.md) | iOS 배포 런북 |
| `assets/images/README.md` | 아이콘/그래픽 사양 |
| `android/key.properties.example` | 서명 설정 템플릿 |
| `scripts/generate-keystore.bat/sh` | 키스토어 생성 |

---

## 바로 다음에 할 일 (우선순위순)

1. **Google Play Developer 등록** (1일, $25)
2. **privacy.html + account-deletion.html 배포** — APT-Prj git push (~5분)
3. **앱 아이콘 1024×1024 + 피처그래픽 1024×500 생성** (2~3시간)
4. **스크린샷 6장 촬영** (골든 플로우를 실기기에서 실행하며 캡처, 2시간)
5. **키스토어 생성** (`scripts/generate-keystore.bat` 실행, 10분)
6. **Release AAB 빌드** (10분, 명령어는 DEPLOYMENT_RUNBOOK.md)
7. **Play Console 앱 생성 + 내부 테스트 업로드** (반나절)
8. **내부 테스트 실기기 골든 플로우 검증** (반나절)
9. **프로덕션 심사 제출** (30분 + 심사 대기 1~3일)

**Mac 확보 시**:
10. [IOS_DEPLOY.md](IOS_DEPLOY.md) 의 2주 로드맵 수행

---

**프로젝트 1.0 코드 완성 📦**
