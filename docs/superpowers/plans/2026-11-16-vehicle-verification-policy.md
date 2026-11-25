# 차량 인증 공통 설정 구현 계획

> 실행: subagent-driven-development로 서버와 관리자 UI를 나누고 주 에이전트가 모바일 데이터·가입 흐름을 통합한다. 기존 미커밋 작업을 보존하며 커밋·배포하지 않는다.

**Goal:** 운영 설정에서 사진/OCR 필수 여부를 바꾸고 가입·차량 변경·회원 승인·서버 접근 제어가 같은 정책을 사용하게 한다.

**Architecture:** 서버 app_state의 `vehicleVerificationRequired`를 권위값으로 사용한다(기본 true). 인증 정책은 인증 bootstrap·profile·관리자 회원 응답에도 포함한다. 서버는 면제 승인 차량을 실제 사진 인증과 구분하고, 차량 변경 시 면제를 해제한다. 기존 인증·제출 버전과 상태 버전 검사를 보존한다.

**Tech Stack:** Flutter/Dart Provider/Dio, Node/PostgreSQL/PGlite, 기존 웹 JS.

## 1. 서버·웹 계약

- [x] `D:/vsCodeProg/APT-Prj/test/resident-onboarding.test.js` 및 웹 회귀 테스트에 OFF 제출·승인, ON 거절, 면제 승인 후 ON 전환, 차량 변경 재심사, 일반회원 정책 수정 거절을 검증하는 실패 테스트를 먼저 작성·실행한다.
- [x] `api/_lib/db.js`, `auth.js`, resident-community/voice/departure 관련 실제 접근 검사, `api/auth.js`, `profile.js`, `users.js`, session endpoints, `state.js`, SQL migration을 함께 수정한다.
- [x] OFF에서 번호만 제출해도 프로필 완료가 되며 pending은 유지한다. 관리자 승인 시 exemption을 저장하고 verified/OCR을 조작하지 않는다. 정책 ON에서 사진 없는 새 승인을 거절한다. 구형 전체 상태 저장이 정책을 덮지 않게 누락 필드를 보존한다.
- [x] 웹 운영 설정·가입·회원 승인·안내도 정책에 맞춘다. 정책 변경은 활동 이력에 남긴다.
- [x] 집중 테스트와 `npm test`를 실행한다. migration·배포·운영 데이터 변경은 실행하지 않는다.

## 2. 모바일 모델·가입·fixture

- [x] `test/vehicle_verification_policy_test.dart`에 필드 기본 true·false 왕복, OFF에서 사진 없이 가입/변경 제출과 pending 유지, ON에서 기존 요구 유지의 실패 테스트를 작성·실행한다.
- [x] `AppState.vehicleVerificationRequired`, `SessionInfo.vehicleVerificationRequired`, `AppUser.vehicleVerificationRequired`, `AppUser.vehicleVerificationExempt`를 추가한다. bootstrap top-level 정책은 session으로 전달한다. 구형 응답은 true다.
- [x] `ProfileSetupScreen`에서 OFF일 때 번호 입력만 표시하고 OCR payload를 보내지 않는다. ON은 기존 `VehicleOcrInput`을 재사용한다. 인증 재시도 화면도 같은 정책을 따른다.
- [x] 전체 상태 복사·payload 작성 위치와 로컬 adapter를 갱신해 정책을 보존한다. 서버 정책 변경 뒤 bootstrap 재조회 결과를 사용하며 정책 오류 시 저장 실패를 표시한다.
- [x] 집중 Flutter 테스트를 실행한다.

## 3. 관리자 UI

- [x] `console_operations.dart`에 '차량 사진·OCR 인증 필수' 스위치와 적용 범위 설명을 추가한다. stateVersion을 포함해 저장하며 성공 응답으로 갱신한다.
- [x] `console_members.dart`, `console_vehicle_verify.dart`의 승인 조건·표시를 정책과 면제 필드에 맞춘다. 승인 불가 사유, 선택 회원 사진 바로가기, 중복 요청 방지, 차단·거절·권한 변경 확인을 추가한다.
- [x] `test/admin_vehicle_review_test.dart` 및 관련 widget 테스트에서 OFF 승인·사유·취소·중복 요청·조회 실패를 RED/GREEN으로 확인한다.
- [x] 수량 감소 보호·미저장 편집·검색 등 별도 개선은 검토안으로 남기며 이 인증 구현과 섞지 않는다.

## 4. 통합 검증·문서

- [x] `flutter analyze --no-fatal-infos`, `flutter test --no-pub --concurrency=2`와 서버 전체 테스트 결과를 확인한다. TEMP/TMP는 ASCII 경로를 사용한다.
- [x] 스펙 일치 검토 후 코드 품질 검토를 수행하고 지적을 수정한다.
- [x] `docs/architecture/project-diagram.mmd`, JSON 색인, PROJECT_ANALYSIS 및 검증 기록을 갱신한다. 배포 전 SQL·앱·웹·서버 적용 순서와 기기 미검증 범위를 명시한다.

## 추가 사용자 요청

주차장 이미지 확인·선명도 개선 또는 필요한 내용만 도식화하는 요청이 추가됐다. 먼저 앱이 사용하는 원본·좌표 의존성을 확인하고 원본을 보존한 별도 시안을 만든다. 도면 기하 구조 변경으로 마커 좌표가 어긋나지 않도록 적용 여부는 시안과 함께 판단한다.

Final evidence: docs/verification/VEHICLE_VERIFICATION_POLICY_2026-11-16.md. Local implementation and validation complete; production migration/deployment and map replacement were not performed.
