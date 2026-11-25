# 선택적 주차 음성통화 Implementation Plan

> For agentic workers: 실행은 기존 Blue Ocean 담당자를 재사용하며 각 단계의 실패 테스트와 통과 결과를 기록한다. 사용자 변경이 있는 현재 작업공간을 보존하며 커밋하지 않는다.

**Goal:** 현재 주차 차주가 주차 건별 수신을 허용한 경우에만 앱 전경 음성통화를 제공한다.

**Architecture:** 기존 ApiClient/Dio 세션과 서버 REST 신호 교환, 서버 발급 주차 식별자, flutter_webrtc 음성을 사용한다. TURN 설정 전 capability는 false이며 연결을 시작하지 않는다. 수신 동의와 통화 수락을 구분하고 백그라운드/로그아웃/lease 만료 시 마이크와 연결을 해제한다.

**Tech Stack:** Flutter/Dart, flutter_webrtc, 기존 Node/Vercel/PostgreSQL. 프로젝트 기존 Dart/JS 명명 방식을 유지한다.

사용자 방향: 2026-10-21 ‘권장 설계로 구현하고 TURN 설정 후 활성화’. 기본 OFF와 주차 차주 한정. PM 스킬 선택 권한은 cfg/blue-ocean.preferences.json의 pm. blue-ocean upstream 점검 결과 기존 e0f597af83f59a83e769d8836b3960184c04e40a 유지. 기존 agents(server_implementation, mobile_auth, design_review)의 모델은 기존 배정 gpt-6.1-sol을 재사용한다. Gradle 빌드와 Flutter 테스트는 메모리 때문에 직렬 실행한다.

## 1. 서버 계약과 권한 (server_implementation)

- [x] D:/vsCodeProg/APT-Prj의 state/profile 라우팅·계정 수명·DB 기존 계약을 확인하고 API 계약을 먼저 공유한다. /api/parking-voice를 기존 profile 함수로 rewrite하여 함수 수를 늘리지 않는다.
- [x] 테스트: 기본 수신 거절, 타인 동의 변경 차단, generic state 변조 차단, 주차 교체 시 ID 교체, 현재 주차/차주 인스턴스 불일치 거절, 비참가자의 SDP 접근 거절, 만료·중복·동시 통화 제한을 실패로 확인한다.
- [x] 전용 owner opt-in, capability, 요청/수락/거절/신호/heartbeat/종료 API와 임시 신호 테이블을 구현한다. 모든 동작이 현재 세션·현재 등록·수신 동의를 확인한다. payload 크기를 제한하고 종료·만료 신호를 정리한다.
- [x] TURN 설정은 서버 환경으로만 받고 HMAC 단기 자격 증명을 발급한다. 잘못된 설정·미설정은 capability=false로 닫는다. 실제 운영 설정 생성은 수행하지 않는다.
- [x] Node 테스트와 계약 문서를 갱신한다. 추가 SQL은 root가 기존 보존 검증 절차에 편입한 뒤 운영 반영한다.

## 2. 주차 모델과 선택 UI (mobile_auth)

- [x] lib/models/parking_slot.dart, lib/providers/app_state_provider.dart, lib/widgets/slot_dialog.dart의 연결된 색인과 소스를 읽는다.
- [x] 기본 OFF/서버 roundtrip/타인 수정 보존/서버 설정 실패 시 OFF 유지에 관한 실패 테스트를 작성한다.
- [x] 새 주차 저장 → 서버 ID 확인 → 전용 소유자 수신 설정 성공 후 ON 표시 순서를 구현한다. QR 자동 등록은 OFF다. TURN 미설정이면 선택과 통화 시작을 비활성 표시한다.
- [x] 기존 주차 차주만 수신을 끄거나 켤 수 있게 한다. 타인 현재 주차의 허용된 경우에만 통화 시작 버튼을 연결한다.
- [x] 테스트는 root의 Gradle 종료 통보 후 ASCII TEMP 경로로 실행한다.

## 3. 모바일 통화 수명 (root)

- [x] lib/services/parking_voice_api.dart, lib/services/parking_voice_controller.dart, lib/screens/public/parking_voice_screen.dart로 역할을 분리한다. API 계약은 서버 담당과 확정한 뒤 작성한다.
- [x] 가짜 transport/peer를 통한 요청·수락 전 마이크 금지·거절·취소·lease 만료·로그아웃·백그라운드 해제의 실패 테스트를 작성한다.
- [x] capability가 허용된 승인 회원의 전경에서만 수신을 조회한다. 통화 화면에 수락/거절, 음소거, 스피커, 종료를 둔다. 수락 전에는 마이크를 켜지 않는다.
- [x] pubspec.yaml/lock과 Android/iOS 마이크 권한을 갱신한다. 기존 Provider/AuthStage/Navigator 구조에 연결한다. 앱이 녹음하지 않음과 연결 정보 사용을 안내하며 완전 익명을 주장하지 않는다.

## 4. 통합 검증과 배포 (root + design_review)

- [x] Flutter analyze --no-fatal-infos, 전체 flutter test, 전체 서버 테스트를 직렬 검증하고 독립 리뷰의 결함을 해결한다.
- [x] docs/architecture/project-diagram.mmd 및 project-diagram.index.json을 함께 갱신하고 운영 배포 계획/검증 기록을 최신화한다.
- [x] TURN 없는 운영은 비활성 상태임을 확인한다. Android/iOS 2대 Wi-Fi/LTE 음성 및 실제 권한 검증은 실기기 접근 전까지 미검증으로 명시한다.
- [x] 추가 SQL 보존 검증과 서버 준비 배포, 20 signed AAB 재빌드·서명·manifest·16KB 정렬 확인을 완료했다.
- [x] 브라우저 연결 후 20을 Play에 업로드했다. 마이크 하드웨어 요구로 기존 20개 기기가 제외되는 경고를 확인해 출시 초안에서 제외했으며 아티팩트 라이브러리에 복구 가능한 상태로 유지했다.
- [x] Play 데이터 보안 변경을 저장하고 21과 함께 검토 요청했다. [신고·전송 기록](../../verification/PLAY_DATA_SAFETY_2026-10-21.md)을 따른다.
- [x] 선택적 마이크 하드웨어 선언·동의 문구를 포함하는 21 빌드·서명·16KB 정렬을 검증했다. 정확한 21 설치본의 기동·게스트·지도와 관찰 PID 4453의 필터 오류 0건을 확인했다.
- [x] 최종 21을 Play에 업로드·검토 전송하고 FLZ 배포를 운영 도메인에 연결했다. 기존 기기 감소는 0개이며 차단하지 않는 크기 경고 1개만 남았다.
- [ ] Google 승인과 관리형 게시 최종 실행을 확인한다.
- [x] 공개 테스트·Alpha의 활성 구14 사진 권한 차단을 같은21 라이브러리 교체로 수정했다. 4개 변경 재전송 후 실제 사전 검사 완료와 Google 심사 중 전환을 확인했다. [QC 증거](../../verification/PLAY_PHOTO_PERMISSION_BLOCKER_2026-10-21.md). 기존 AAB 해시를 보존했고 무시 버튼을 사용하지 않았다.

현재 기록: Flutter 분석 0건/전체 187개, 서버 전체 124개 통과. 최신 동의·가입·로컬 adapter 집중 테스트 20개도 별도로 통과했다. 최종 21 AAB SHA256은 `207a8a7fdb4531da22952183af62314f18b403e32826c3ed603dad99cc5b9284`이며 서명·16KB 정렬·선택적 마이크를 확인했다. 통화 SQL 적용은 53회원/1상태를 보존했고 그 외 검증용 운영 데이터 쓰기·삭제·실제 통화·수신 허용을 실행하지 않았다. 운영 canonical은 `apt-ev-charging-j5m89f1ez-polkolpk-7667s-projects.vercel.app` (`dpl_FLZLaE3zbhejK4NpU4gL1PXZ9MhF`)로 전환됐다. 정확한 ID와 dashboard 200·보호 API 401·privacy/계정삭제 페이지 200을 확인했다. 기존 EW12 배포는 복구 대상으로 남긴다. 공개·Alpha 구14의 사진 권한 차단을 같은21 교체로 수정하고 총4개 변경을 재전송했다. 실제 사전 검사 완료 후 Google 심사 단계 전환을 확인했다. 관리형 게시 ON, Google 승인·최종 게시 미완료이며 TURN은 비활성이다.

BlueStacks 20 공개 화면과 별도 localtest 20의 단일 번호판 거절·합성 PNG 한국어 ML Kit 일치·게시판/신고/관리자 화면을 확인했다. 실제 두 기기 음성·실사진 정확도·Google 로그인 완료를 증명하지 않는다. [BlueStacks 증거](../../verification/BLUESTACKS_RELEASE_2026-10-21.md), [최종 21 산출물·검토 요청 기록](../../verification/RELEASE_1.1.4_21_2026-10-21.md)을 참고한다.
