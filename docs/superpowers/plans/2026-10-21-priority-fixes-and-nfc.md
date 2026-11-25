# 최우선 안정성 수정과 전경 NFC 구현 계획

> 실행 방식: 기존 역할 에이전트가 독립 파일을 담당하고 PM이 통합·검증한다. 사용자 2026-10-21 응답으로 최우선 개선 5개와 NFC 설계를 승인했다.

**Goal:** 재가입·관리자 상태·앱 상태 경합 및 인증 복구를 보완하고 Android 전경 NFC를 추가한다. iOS는 사용자 후속 지시로 전부 보류한다.

**Architecture:** 기존 Provider·Dio·세대 보호와 SQL 저장 함수를 유지한다. 서버 권위 `stateVersion`을 앱·웹에 전달한다. NFC는 Android Reader Mode와 MethodChannel에서 기존 검증된 DeepLink로 연결한다.

**Tech Stack:** Flutter/Dart, Android Kotlin 기본 NFC API, Node 22, PostgreSQL/PGlite.

## 범위와 작업 배정

- [x] 서버 담당: 탈퇴 정리를 계정 생성 시각/탈퇴 시각 잠금 내 재검사와 단일 SQL 트랜잭션으로 보호. 순서 교차·실패 주입 회귀 통과. 실제 독립 DB 연결 검증은 별도.
- [x] 서버 담당: `state.stateVersion` 정수 초기0, 관리자 예상 버전 필수·불일치409, 모든 성공 저장 현재+1, 일반회원 peer merge 유지. additive migration과 웹 계약 갱신. 운영 적용 금지.
- [x] 모바일 담당: AppState와 provider payload에 stateVersion 보존. 동일계정 응답 순서와 실패 복원 보호. 401/계정제한403 인증 수명 처리. 잘못된 state 성공 응답 거절. legacy 사진 인증 제한과 수신 설정 후 전체 상태 재조회 회귀도 통과.
- [ ] 보류 iOS: 사용자 후속 지시로 iOS 작업 전부 보류. 이번에 추가한 helper·설정·CI·테스트·가이드는 역적용했고 기존 iOS 사용자 변경은 보존했다. 현재 구현 수락 범위에서 제외한다.
- [x] PM: `ForegroundNfc` 채널 수신/검증과 Kotlin ReaderMode 구현. NFC 선택 feature와 NFC permission, onResume/onPause/engine cleanup, NDEF 단일 URI와 크기 상한, 태그 제거 전 억제 경로. 실제 RF 확인은 별도.
- [x] PM: Home route 가시성·resumed와 최신 태그 처리 경계. 다른 탭은 기존 shell 전환 재사용, pushed route에서는 보류하고 복귀 시 처리. 기존 QR 자동 주차·본인 출차·수신OFF 유지.
- [x] PM: 변경 구조도·JSON·분석 문서·NFC 검증 기록 갱신.

최종 로컬 검증: Flutter analyze No issues found, 전체 Flutter216개·서버137개 통과. Android 격리 x64 debug 빌드 종료0과 실제 APK의 선택 NFC·광범위 사진 권한0개를 확인했다. 산출물과 범위는 `docs/verification/PRIORITY_FIXES_NFC_2026-10-21.md`에 기록한다. 독립 교차 리뷰의 생명주기·콜드 seed·처리 token 및 버전/인증 호환 지적을 반영했다. iOS 보류·실제 RF·독립 DB 연결 경합·운영 적용은 완료로 표시하지 않는다.

## 테스트와 검증 순서

1. 각 담당자는 기존 fixture/controlled adapter의 최소 실패 테스트를 먼저 실행하고 해당 실패를 확인한 뒤 수정한다.
2. NFC 플랫폼 수신 테스트는 채널 이벤트의 valid URI·잘못된 origin·중단 이후·미지원 예외를 검증한다. 홈 widget 테스트는 modal에서 쓰기 보류·복귀 처리·지연 조회 중 화면 변경·최신 태그를 검증한다.
3. 작은 테스트는 `flutter test --no-pub --concurrency=1 <관련 test>`를 사용한다. 한글 TEMP 오류를 피하도록 TEMP/TMP는 기존 `D:/Temp/apt-flutter-20261020`을 사용한다.
4. 통합 후 `flutter analyze --no-fatal-infos`, Flutter 전체 테스트, 서버 `npm test`를 자원 상황에 맞게 순차 실행한다. Android 검증 APK의 네이티브 컴파일·manifest 선택 feature를 확인한다. 배포 스크립트를 검증으로 실행하지 않는다.
5. NFC RF/태그 제거 검증에는 실제 NFC 장치가 필요하며 BlueStacks 결과로 대체하지 않는다. iOS는 Mac/Xcode·실제iPhone·실제클라이언트설정이 없으면 미검증으로 남긴다.

## 보존과 제약

기존 작업공간에는 사용자와 이전 작업의 많은 수정·미추적 구현이 있어 HEAD에서 새 worktree를 만들면 현재 구현을 누락한다. 이번에는 기존 작업공간에서 파일 소유권을 나누고 공유 파일 변경을 조율한다. 사용자 변경을 스테이징·커밋·리셋하지 않는다. PM은 `main.dart`·DeepLink·Home·구조도를, 모바일 담당은 provider/model/service를, iOS 담당은 initialize/config/platform 설정을 담당한다. 모델은 기존 에이전트 세션을 재사용하며 실제 모델 정보는 재검증하지 않았다.

운영 DB·회원 데이터 변경, TURN 활성화, 앱/서버 배포는 이번 로컬 구현에서 실행하지 않는다. iOS NFC는 승인된 Android 전경 인식 범위에 포함하지 않는다. 기기/UI 검증은 준비된 격리 테스트 범위로 제한한다.
