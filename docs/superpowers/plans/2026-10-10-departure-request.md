# 출차 요청 Implementation Plan

> Agentic workers: subagent-driven-development로 서버 구현과 검토를 분리한다. 모바일 통합은 root가 진행한다.

**Goal:** 사용 중인 다른 차량 차주에게 요청 차량을 식별할 수 있는 출차 요청 및 휴대폰 알림을 제공한다.
**Architecture:** Vercel CommonJS/Neon에 요청·기기 토큰을 저장하고 FCM으로 전달한다. Flutter Provider/Dio와 기존 공통 슬롯 상세를 확장한다. Firebase 설정이 없으면 앱은 정상 기동하며 알림 설정 상태를 표시한다.
**Tech Stack:** Flutter 3.41.6, Node 22+, Neon, Firebase Messaging/Admin.

현재 두 저장소의 사용자 변경은 보존한다. 기존 모바일 미커밋 구현이 필수이므로 HEAD만 복제한 worktree에서 구현하지 않는다. 작업을 별도 feature 브랜치로 분리하고 사용자 변경을 커밋하거나 배포하지 않는다.

## API 계약

- POST `/api/departure-requests`: `{slotId, expectedOwnerEmail?, expectedStartTime}`. 승인 회원·등록 차량·실제 슬롯을 검증. 응답 `{ok:true, request:{id,slotId,slotName,requesterVehicleNumber,createdAt,readAt,pushStatus},retryAfterSeconds:300}`. 동일 요청자/주차 건 5분 제한, 충돌 HTTP409, 과다 요청429.
- GET 동일 경로 `?before=<id>&limit=30`: 현재 계정의 수신 요청만, `{ok:true,requests:[...]}`.
- PATCH 동일 경로 `{id}`: 수신자의 읽음 처리만, `{ok:true,request:{...}}`.
- POST `/api/push-tokens`: `{token,platform}`. 현재 세션에 토큰 연결. DELETE 동일 경로 `{token}`. 기존 로그아웃의 서버 세션 해제 때 연관 토큰을 제거한다.
- 푸시 data: `{type:'departure_request',requestId:'<id>'}`. 제목 출차 요청, 본문 요청 차량번호·슬롯 위치. 푸시 상세 진입 시 서버 권한으로 재조회한다.

## Task 1 서버

- [x] `APT-Prj/test/departure-requests.test.js`에 불일치 차주/시작 시각, 본인/빈 슬롯, 차량 없는 요청자, 수신자 제한, 실패 푸시 요청 유지 테스트 추가.
- [x] `node --test test/*.test.js`로 실패 확인.
- [x] `api/_lib/departure-service.js`, `departure-store.js`, `departure-http.js`, `departure-push.js`, `api/departure-requests.js`, `push-tokens.js` 구현. Neon 원자적 저장과 요청 제한, 공유 주차 상태 행 잠금, 안전한 오류 응답, 대기한 FCM 발송 결과 저장. 테스트에서 메모리 저장소 주입.
- [x] firebase-admin 의존성 설치. 실제 키는 환경 변수로만 읽는다. 환경 설정 누락은 skipped 상태로 보존.
- [x] 서버 테스트 통과·spec 및 코드 검토.

## Task 2 모바일 요청 및 목록

- [x] `test/departure_request_test.dart`에 모델과 요청 payload/수신 목록 API, `test/slot_departure_request_test.dart`에 타인 슬롯 버튼과 확인 취소 테스트 추가. 실패 확인.
- [x] `lib/models/departure_request.dart`, `lib/services/departure_requests_api.dart` 구현 및 ApiServices 등록.
- [x] 공통 슬롯 상세에 요청 확인 및 API 전송 추가. 본인/게스트/빈 슬롯 차단. 전송 중 중복 클릭 금지. 서버 접수와 푸시 수신 구분.
- [x] `lib/screens/public/departure_requests_screen.dart`에 요청 목록·상세·읽음 처리·새로고침 추가. 더보기에서 접근.

## Task 3 푸시

- [x] `test/push_identity_test.dart`로 잘못된 계정/알림 종류 및 늦은 계정 응답 차단 확인.
- [x] Firebase core/messaging 의존성 설치. 명시적 dart-define 설정 또는 네이티브 설정으로 초기화, 미설정이면 앱 기동 유지.
- [x] `lib/services/push_notifications.dart`에서 알림 권한·기기 토큰 갱신·전경 알림·알림 선택 이벤트 처리. 세션 계정 토큰 연결/해제를 직렬화한다.
- [x] ShellScreen 회원 수명에 연결. 알림 선택 후 해당 requestId만 서버 재조회하여 화면 표시. local fixture에서는 실제 푸시 초기화 없음.
- [x] Android 권한/채널 및 iOS 설정 안내 추가. Firebase 프로젝트 확보 후 실제 설정 및 기기 검증.

## Task 4 검증과 전체 구조도

- [x] Flutter analyze 및 관련/전체 test. Node 전체 test. Android debug 빌드.
- [x] 두 저장소 변경 diff 검토. 실제 서버 호출·DB 쓰기·테스터 알림은 테스트 환경 확보 전 하지 않는다.
- [x] `docs/architecture/project-diagram.mmd`와 index를 갱신.
- [x] 전체 앱 ↔ APT-Prj 연동을 `docs/architecture/app-server-integration.mmd`와 JSON 색인으로 작성하고 SVG로 렌더링. 서버에도 동일 구조도와 API·설정 문서를 제공한다.
- [x] 완료 보고에서 코드·검증 완료와 Firebase/실기기/배포 미완료를 명시한다.

## 남은 운영 작업
- [x] 운영 Neon 마이그레이션 및 Vercel API 배포.
- [x] Firebase 프로젝트·서버 자격증명·Android 앱 설정.
- [ ] iOS APNs 설정 및 macOS 빌드·배포.
- [ ] 실제 두 휴대폰으로 종료 상태 알림·계정 전환 검증, Neon 독립 연결 동시성 검증.
- [x] 새 앱 빌드 번호 17로 Play 프로덕션 검토 전송. 사전 검사·Google 심사 대기.
- [ ] Google 심사 승인 후 관리형 게시에서 게시.

검증: Flutter 전체 109개, 최종 inbox 2개, Node 22 31개 통과. 정적 분석 이상 없음. Android 테스트 설정 debug APK 빌드 성공. 최종 결과는 docs/verification/DEPARTURE_REQUESTS.md 참고.
