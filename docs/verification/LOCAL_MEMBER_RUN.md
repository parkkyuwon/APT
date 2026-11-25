# 로컬 가상 회원 검증

일반 앱과 분리된 Android 패키지 `apt.ev.service.localtest`에 가상 승인 회원을 사용한다. 테스트 앱의 회원 API는 메모리 adapter에서 처리하며 운영 서버로 전달하지 않는다. 일반 `main.dart` 및 회원·비회원 권한 규칙은 변경하지 않는다.

```powershell
flutter build apk --debug --no-pub -t lib/main_local_test.dart --dart-define=LOCAL_MEMBER_TEST=true --dart-define=API_BASE_URL=https://local-test.invalid
```

release/profile 빌드 또는 필수 설정을 생략한 로컬 진입은 거절한다. 일반 앱은 `flutter build apk --debug --no-pub`로 빌드한다. 로컬 진입점은 정상 배포에 사용하지 않는다.

## 개선 우선순위

1. 회원 화면의 비동기 수명: 내 이용 내역 응답과 채팅 전송 완료가 화면 종료 후 도착하는 오류를 재현한 뒤 mounted 검사로 수정했다.
2. 사진 선택·인코딩·업로드: 화면 종료, 권한 거절, 대용량 사진과 리소스 해제 검증을 추가해야 한다.
3. 개인정보 안내: 사진 삭제 시점 및 탈퇴 데이터 삭제 문구를 실제 서버 정책과 대조해야 한다. 앱 소스만으로 서버 삭제를 보장할 수 없다.
4. 배포: API 36 빌드 외에 Android 16 OS, 실제 Google 로그인, BLE, 카메라, release 설치 및 Play 테스트 트랙 검증이 필요하다.
5. 지도 첫 표시: 빈 화면 관찰에 대해 시간·메모리를 계측하고 로딩 표시/이미지 크기를 검토한다.

## 범위 제한

가상 서버는 실제 백엔드의 권한·동시성 계약을 인증하지 않는다. 이용 이력 날짜 필터, 사진 보관/검증, 대표 현황의 그룹 데이터는 아직 fixture에 구현되지 않았다. 하드웨어 기능과 Google 인증은 이 테스트의 통과 항목으로 보고하지 않는다.

## 실행 결과 (2026-10-09)

BlueStacks Pie64 Android 9/API 28에서 검증했다. Android 16 실행 검증으로 대체하지 않는다. 테스트 패키지와 일반 패키지 모두 versionCode 15 / targetSdk 36이다.

| 항목 | 결과와 근거 |
| --- | --- |
| 승인 회원 홈/지도/목록 | 가상 회원으로 진입, 빈·점유·차단 슬롯 표시 [목록](local-member/list.png) |
| 회원 입차·출차 | fast50-1을 등록해 급속 점유 1/3→2/3, 출차해 1/3 복귀 [입차](local-member/parked.png), [출차](local-member/released.png) |
| 이용 내역 | 하나의 이용 기록에 출차 완료 표시 [이력](local-member/history.png) |
| 채팅 전송·조회 | `local-smoke-test` 전송 후 목록 표시 [화면](local-member/chat-sent.png); 수정·삭제는 adapter 테스트에서 검증 |
| 프로필 수정·자동 갱신 | 닉네임을 FinalMember로 변경, 저장 후 추가 새로고침 없이 반영 [화면](local-member/profile-auto.png) |
| 로그아웃 | 일반 로그인 화면 복귀 [화면](local-member/logout.png) |
| 정상 앱 비회원 복원 | 가상 앱 force-stop 및 그 패키지만 pm clear 성공. 정상 APK 설치·실행 후 비회원 진입 [화면](local-member/restored-guest.png) |
| 비회원 변경 차단 | 슬롯을 누르면 “로그인이 필요합니다.”, 회원 다이얼로그 미노출 [화면](local-member/restored-denied.png). 해당 정상 앱 로그는 GET auth/public-dashboard 200만 있고 쓰기 요청 없음 |

초기 테스트 배너의 Directionality 누락은 실제 실행에서 발견해 layoutDirection 지정으로 수정했다. 가상 출차 이력/전체 상태 삭제 계약도 회귀 검증 후 수정했다. 앱의 회원 화면 오류 3건(내 이용 내역의 늦은 응답, 채팅 전송 후 화면 종료, 프로필 복귀 후 이전 정보 표시)을 수정했다.

- `flutter analyze --no-pub`: No issues found.
- `flutter test --no-pub --concurrency=2`: 97 tests passed. 화면 종료/프로필 복귀 테스트 4개, 가상 API 7개, 진입점 거절 1개 포함.
- 마지막 로컬/일반 debug APK 빌드 성공. 실제 Gradle assembleRelease + LOCAL_MEMBER_TEST define 실행은 `Local member fixtures are debug-only`, exit 1로 의도대로 차단됐다.
- 일반 APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `fe1f9619d950dac139aa820d7afa1b48a0e048fd210bd1648f9dd44ca5dc1992`.
- 로컬 APK: `D:/Temp/apt-local-member-debug.apk`, SHA256 `568b851279b6c4a344b8e088d723177cd3964d89b9dde9b41bf5aa3ee5c623e3`.
- 가상 요청은 [회원 로그](local-member/member-api.log), [최종 로그](local-member/final-api.log)의 `.invalid` adapter에서 처리했다. 정상 복원 구간은 [정상 앱 로그](local-member/normal-api.log)에서 확인한다. 캡처 구간의 E/flutter/FATAL EXCEPTION 없음은 해당 구간에 한정한다.

테스트 앱은 데이터가 비워지고 종료된 상태이며 정상 앱을 비회원 화면에 남겼다. 사진, 실제 서버 회원 권한, 날짜 필터 및 외부 기기 항목을 포함한 모든 기능의 완전 검증은 아직 완료되지 않았다. 이번 변경으로 release AAB를 새로 생성하거나 Play에 게시하지 않았다.
