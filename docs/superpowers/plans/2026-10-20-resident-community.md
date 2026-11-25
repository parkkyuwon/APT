# 입주민 가입·OCR·게시판·고장 신고 구현 계획

> **For agentic workers:** Use subagent-driven-development with bounded file ownership; Blue Ocean model allocation takes precedence. No automatic commits or production mutations.

**Goal:** 전화번호 없는 Google 기반 가입, 번호판 OCR 비교 후 관리자 승인, 개인정보 정리, 게시판과 사진 고장 신고를 앱/서버 로컬 코드에 구현한다.

**Architecture:** Flutter Provider/Navigator와 공용 Dio를 유지한다. 별도 서버는 기존 세션/CSRF/DB 구조를 재사용하고 신규 API를 profile feature rewrite로 제공한다. OCR은 한국어 휴대폰 인식기를 가입과 관리자 테스트에서 공유한다.

**Tech Stack:** Flutter/Dart, image_picker, 한국어 ML Kit OCR, Node/Vercel/Neon.

사용자 확인: 2026-10-20 설계·화면 초안 및 `D:/vsCodeProg/APT-Prj`의 로컬 코드 수정을 승인했다. DB 실행·실제 삭제·배포는 제외한다. 현재 dirty tree는 보존하며 별도 worktree에는 미커밋 구현이 없으므로 현재 작업본에서 파일 소유권을 나누어 수정한다.

## 1. 서버 계약과 구현 (서버 담당)

- [x] 기존 auth/profile/users/DB 실제 계약 읽기와 격리 테스트 먼저 작성/실패 확인.
- [x] 전화번호/닉네임 필수 제거, Google 표시 이름 사용, pending 상태에서 프로필 제출 허용, 차단 상태 보호.
- [x] 프로필 입력 `vehicleNumber`, `vehiclePhoto`, `ocrCandidates`; 서버가 후보와 입력을 정규화 비교한다. OCR 후보는 클라이언트의 관찰 결과이며 신분 인증이 아니다. 최종 승인은 서버 관리자 권한으로만 한다. 차량 변경 시 심사를 초기화한다.
- [x] `/api/board` GET/POST/PUT/DELETE: `id`, `title`, `content`, `authorEmail`, `authorName`, `createdAt`, `updatedAt`; 수정/삭제는 본인 또는 승인 관리자, 목록은 승인 회원만.
- [x] `/api/charger-reports` GET/POST/PATCH: `id`, `slotId`, `description`, `photo`, `status`(received/in_progress/resolved), `authorEmail`, `authorName`, `createdAt`; 회원은 본인 신고만, 관리자는 전체 조회/상태 변경. 사진 1장 최대 900KiB의 PNG/JPEG/WebP data URL.
- [x] `/api/admin-members` POST `action: clear-personal-data`, `emails`: 전화번호/수동닉네임/차량사진 정리. 응답 `clearedCount`. 기존 DELETE 회원 삭제 유지.
- [x] SQL migration과 API 문서 작성. 기존 세션/CSRF/rate limit/계정 인스턴스 보호 유지. 로컬 fixture/PGlite 테스트만 실행.

## 2. 가입·OCR·전화번호 제거 (앱 인증 담당)

- [x] 번호판 정규화/후보 비교, 인증 단계 순서와 전화번호 없는 프로필 테스트 작성/실패 확인.
- [x] `lib/core/plate_recognition.dart` 등 공유 OCR 도메인/어댑터와 `lib/widgets/vehicle_ocr_input.dart`를 구현한다. 소비 API는 `PlateRecognitionService.recognize(String path)`와 후보 모델로 명시한다. 상세 인터페이스는 구현 후 PM에게 전달한다.
- [x] `profile_setup_screen`, `photo_verification_screen`, `consent_screen`, `pending_screen`, `auth_provider`, `profile_api`, `session`, `user`에서 입력/전송/검증/화면 순서 변경.
- [x] `home_screen`, `slot_dialog`, `mypage_screen` 및 관리자 회원 화면에서 전화번호 입력/필수조건/표시 제거. 기존 주차 API 호환 필드는 필요한 경우 빈 값으로만 유지하고 더 이상 사용자 전화번호를 수집하지 않는다.
- [x] OCR 후보/사진/번호 변경 시 이전 결과 무효화. 관리자 OCR 테스트 화면 및 기존 차량 승인 UI 변경. 개인정보 정리 버튼을 기존 관리 화면에 추가한다.
- [x] 한국어 OCR 의존성과 플랫폼 최소 조건을 확인해 반영하되 광범위 사진 접근 권한은 추가하지 않는다. Flutter 도구 실행은 PM과 직렬화한다.

## 3. 게시판·사진 고장 신고 (PM/앱 개발)

- [x] 응답 모델과 API 계약 테스트를 먼저 작성한다. 공용 ApiClient 오류 변환을 사용한다.
- [x] `lib/models/community.dart`, `lib/services/community_api.dart`, `lib/screens/public/board_screen.dart`, `lib/screens/public/charger_reports_screen.dart`에 목록·상세·게시글 작성/수정/삭제와 사진 신고/상태 표시를 구현한다. 서버 계약은 1번과 동일하다.
- [x] `ApiServices`에 `community`를 조립하고 `shell_screen` 더보기와 `admin_dashboard`에 진입점을 추가한다. 관리자 OCR 화면 진입점은 인증 담당 산출물에 맞춰 PM이 통합한다.
- [x] 중복 제출·화면 종료·재시도와 입력 유지, 사진 검증, 사용자별 접근 권한 관련 위젯/API 테스트를 실행한다.

## 4. 검증·검토·문서 (PM/QC)

- [x] `flutter analyze --no-fatal-infos`, 관련 테스트, `flutter test --concurrency=1` 실행. 서버는 `npm test`를 Flutter와 직렬 실행.
- [x] 독립 QC가 요청 8개 충족 여부와 코드 품질을 각각 검토하고 결함을 수정 후 재검증한다.
- [x] Mermaid/JSON 색인과 PROJECT_ANALYSIS, 서버 API 문서 및 검증 기록을 갱신한다.
- [x] 실제 기기와 macOS가 없으면 OCR/카메라/iOS/로그인 미검증을 명시한다. 실행 가능한 UI 검증안과 빌드를 준비한 후 사용자가 이미 허용한 동일 범위가 아니면 Computer Use 검증 여부를 확인한다.

서버/앱 담당은 반복 편집의 타이핑 역할을 겸임한다. 별도 타이핑 에이전트를 실행했다고 주장하지 않는다. 현재 메모리 제한으로 빌드/테스트는 동시 실행하지 않는다. 외부 서비스 연결·운영 데이터 변경은 수행하지 않는다.

## 검증 잔여 범위

- [ ] Android/iOS 실기기에서 실제 한글 OCR·카메라·Google 로그인·QR 실행: 연결 기기 및 UI 제어 도구 부재로 미수행.
- [ ] 운영 마이그레이션·배포: 승인 범위 밖이며 미수행. 기존 웹 클라이언트 갱신/접근 제한이 선행되어야 한다.

자동 검증 결과와 Android 빌드 최종 상태는 docs/verification/RESIDENT_COMMUNITY_2026-10-20.md를 기준으로 한다.
