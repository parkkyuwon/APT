# 로컬 가상 회원 검증 PM/QC

검토일: 2026-10-09. PM `gpt-6.1-sol`, Blue Ocean 적용. 사용자는 로컬 가상 회원/데이터로 기존 회원 UI 기능을 검증한 뒤 비회원 제한을 복원하는 방향을 선택했다. root가 테스트 entrypoint/adapter와 실제 앱 조작·검증, PM이 읽기 전용 독립 검토와 이 문서를 담당한다.

## 승인 방향과 우선순위

영향 하위 그래프는 `app/auth → member-ui → services → http/storage`이며 실제 서버는 테스트 범위 밖이다. 기존 Flutter/Provider/Dio 서비스와 회원 화면을 재사용하고 일반 `lib/main.dart`의 인증·게스트 권한을 변경하지 않는다. 시각 배치 변경이 없어 GUI DR는 면제한다.

1. 최우선은 외부 요청 격리다. `lib/main_local_test.dart`의 실제 실행 guard로 debug만 허용한다. release에서 제거되는 assert에만 의존하지 않는다. runApp/인증 bootstrap 전에 in-process Dio adapter와 `.invalid` URL을 연결한다. 알 수 없는 path/method는 오류 응답으로 종료하며 원래 HTTP adapter에 위임하지 않는다.
2. 가상 승인 회원의 session/state/profile/history/chat 계약은 실제 서비스 parser와 UI 요구를 따른다. 입력→가상 저장→재조회→화면 반영을 확인한다. 관리자 계정이나 운영 사용자 자격증명을 사용하지 않는다. mock의 성공은 실제 서버 권한·보존·동시성 계약의 검증으로 주장하지 않는다.
3. 가상 캐시와 정상 앱의 복원 경계를 확인한다. 동일 applicationId를 설치하면 SessionInfoCache/StateCache가 영속화되므로 단순 정상 APK 재설치만으로 가상 세션이 사라진다고 가정하지 않는다. 테스트 종료의 fake logout+모든 캐시 clear 또는 승인된 BlueStacks 테스트 앱 데이터 초기화 후 정상 APK 설치·실행으로 비회원/게스트 권한 복원을 확인한다.
4. 실제 UI는 회원 입출차/목록·지도/프로필·이력·채팅 등 선택한 범위를 스크린샷·로컬 요청 로그·재조회 상태로 검증한다. 외부 네트워크 이미지·Google 인증·URL 실행은 별도 경로일 수 있으므로 가상 fixture는 로컬 데이터/이미지를 사용하고 해당 외부 동작을 자동 실행하지 않는다.

## 수락 기준

- 단위 테스트로 adapter의 정상 read/mutation/re-read 및 unknown route 거절을 확인한다. `.invalid` URL과 로컬 adapter가 모든 해당 API 요청을 처리하며 실제 서버 요청을 보내지 않는다.
- `main_local_test`는 debug-only이며 일반 main의 인증/권한 체크가 유지된다. 비회원 쓰기 허용이나 production AuthProvider bypass를 추가하지 않는다.
- 기존 회원 UI에서 선택한 가상 기능을 실제 BlueStacks 화면과 결과 로그로 확인한다. 취소·저장 실패·중복 입차 등 scope에 포함한 실패 경로를 성공과 구분한다.
- 새로운 source에 대한 분석·전체 테스트·로컬 debug APK 빌드를 root가 직렬 수행한다. Android9/API28 검증을 Android16/16KB 실기기 검증으로 확장하지 않는다.
- 테스트 종료 후 가상 세션/캐시를 제거하고 정상 entrypoint APK로 복원, 로그인/게스트 진입 및 읽기 전용 제한을 재검증한다. 가상 APK·정상 APK 해시/버전과 실행 단계를 구분해 보고한다.

## 구현 중간 독립 QC

별도 entrypoint는 실행 가능한 `kDebugMode`/`LOCAL_MEMBER_TEST`/고정 `.invalid` URL guard를 사용한다. guard 통과 후 adapter를 bootstrap 이전에 설치하고 캐시를 정리한다. Android Gradle은 local flag를 decoded dart-defines에서 읽어 debug applicationIdSuffix `.localtest`를 적용하고 release/profile task를 거절한다. 이 분리 패키지는 정상 앱의 쿠키·세션/주차 캐시 sandbox와 격리된다. 일반 main/AuthProvider/게스트 권한 코드는 변경하지 않는다.

`LocalApiAdapter`는 외부 socket adapter에 위임하지 않고 origin을 확인하며 unknown routes를 404로 거절한다. 가상 role은 승인 `user`이고 관리자 routes는 403, 로그아웃 후 회원 routes는 401이다. source/test 소유자 권한 및 public-dashboard PII 축약 경로를 확인했다. 프로필·이력·채팅과 입출차는 fixture 계약이며 실제 backend 보증이 아니다. fixture의 날짜 필터·사진 처리·대표 그룹 데이터 미구현은 실행 보고의 한계와 일치한다.

회원 내정보 이력 late 200/403과 채팅 전송 완료 후 화면 dispose 결함은 root가 RED로 재현해 mounted guard를 추가했다. source diff는 화면 상태/controller를 만지기 전에 mounted를 확인하며 기존 UI 배치를 유지한다. PM은 이 정정을 승인한다.

| 항목 | 상태/정정 요구 |
| --- | --- |
| 외부 요청·build·storage 격리 | 소스·분리패키지 빌드 및 local `.invalid` API 로그 확인. 실제 Gradle release guard가 debug-only 이유로 exit1, 정상 차단 |
| 일반 앱 권한 유지 | 정상 APK 복원 및 guest 목록·로그인 필요 안내 화면 확인, 정상 요청 로그 GET auth/public-dashboard만, write0 |
| 화면 async 수명 | root RED→GREEN3와 source mounted guard 확인, 최종 전체97개 테스트 통과 |
| fixture 출차 이력 | `_completeHistory`가 현재active를 같은 id의completed로 commit 때 교체. 회귀의 completed 단일 상태 assertion과 실제 출차 완료 화면 확인, 정정 통과 |
| 프로필 수정 복귀의 stale 내정보 | root가 복귀 뒤 GET 없음 RED를 재현. route 완료를 await하고 mounted 상태 `_load()` 재조회. FinalMember 자동반영 screenshot 및 profile→auth→my-history 로그 확인, 정정 통과 |

PM은 `D:/Temp/apt-local-all-tests-final.log`의 `+97 All tests passed!`를 직접 확인했고 root는 마지막 분석 `No issues found`와 local/normal debug build exit0을 전달했다. 실제 입차/출차 목록에서 점유 2/3→1/3 변화, MyPage 단일 출차 완료 기록, local-smoke-test 채팅을 확인했다. 마지막 `profile-auto.png`의 FinalMember 자동반영과 저장 완료, `logout.png`의 로그인 root, `restored-guest.png`의 정상 guest 목록, `restored-denied.png`의 로그인 필요 안내를 직접 확인했다. [실행 보고](../verification/LOCAL_MEMBER_RUN.md)의 범위/미구현 한계와 로그가 일치한다.

`final-api.log`의 회원 수정/로그아웃은 `.invalid` origin만 사용한다. `normal-api.log`의 정상 복원 구간에는 GET auth/public-dashboard HTTP200만 있고 POST/PUT/PATCH/DELETE는 0개임을 직접 확인했다. root는 local package force-stop 및 해당 package만 `pm clear` Success와 PID 부재, 정상 APK install Success/start ok를 보고했다. PM은 ADB를 중복 실행하지 않는다. release Gradle guard 로그는 `Local member fixtures are debug-only`를 확인했으며 exit1은 의도한 안전 경계 검사 성공이다. `git diff --check` 종료 코드0을 확인했다.

PM이 파일 SHA256을 다시 계산해 보고와 일치함을 확인했다. 정상 APK는 `fe1f9619d950dac139aa820d7afa1b48a0e048fd210bd1648f9dd44ca5dc1992`, 보관 local APK는 `568b851279b6c4a344b8e088d723177cd3964d89b9dde9b41bf5aa3ee5c623e3`다. root의 마지막 빌드 시간은 정상18.8초/local17초다. 정상 패키지는 `apt.ev.service`, local은 `apt.ev.service.localtest`이며 둘 다 code15/target36이고 실제 검증 OS는 Android9/API28이다.

## 최종 수락

PM은 **분리된 로컬 가상 회원 UI 검증, 발견된 회원 화면 결함 정정 및 정상 앱의 비회원 제한 복원**을 수락한다. 현 범위 미해결 QC 결함은 없다. 가상 앱 데이터는 비워지고 종료됐으며 정상 앱은 비회원 화면에 남겼다. production main/auth/guest 권한을 완화하지 않았다.

실제 서버 회원 권한·동시성·보존/삭제, 실제 Google 로그인·BLE·카메라/사진·Android16/16KB OS, fixture 날짜 필터·사진 검증·대표 그룹은 미검증 또는 미구현이다. 채팅 수정/삭제는 adapter 테스트 근거이며 실제 UI runtime 통과로 확장하지 않는다. 이번 최종 source 변경을 반영한 release AAB는 새로 생성하지 않았으므로 이전 API36 release 산출물이 현재 회원 화면 수정까지 포함한다고 가정하지 않는다. 스토어 게시도 수행하지 않았다.

현 개선 우선순위는 사진 선택/변환/업로드의 async 수명·거절/오류·리소스 해제, 개인정보 삭제 문구의 실제 서버 정책 대조, Android16/실기기 로그인/BLE/카메라/release 검증, 지도 첫 표시 시간/메모리 계측 순이다. fixture 미구현을 실제 앱 결함으로 혼동하지 않으며 새 작업은 별도 요청 범위에서 진행한다. 이 작업은 운영 계정 승인·실제 주차 변경·스토어 게시를 수행하지 않는다.
