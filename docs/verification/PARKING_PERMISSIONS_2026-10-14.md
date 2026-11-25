# 주차 권한·개인정보·지도 검증 (2026-10-14)

## 변경

- 이메일 전용 `SlotDetail.isOwnedBy`를 다이얼로그·내 슬롯 검색·딥링크·출차 요청에 사용한다.
  이름/닉네임으로 소유권을 추정하지 않는다. 이름 변경 후 같은 이메일로 수정 시
  소유권을 유지하고 표시명을 갱신하는 회귀 테스트를 추가했다.
- 승인 관리자는 타인 등록 수정·출차·차단 전환을 할 수 있다. 수정 시 원래
  차주의 이메일과 표시명을 보존한다. 기존 서버 응답과 실패 롤백을 유지한다.
- `hasParkingRecord`로 차단 상태와 차량 등록을 분리한다. 타인 비공개 연락처는
  입력 컨트롤러에도 원본/마스킹 번호를 넣지 않고 `비공개`로 표시한다.
- 지도 viewer를 전체 화면으로 확장하고 내부 이미지·마커를 함께 변환한다.

## 완료한 검증

- Flutter 3.41.6 / Dart 3.11.4.
- `flutter analyze --no-pub --no-fatal-infos`: No issues found, 14.6초.
- `flutter test --no-pub --concurrency=2`: 119개 통과.
- 신규 권한 회귀 테스트의 최초 4개 실패 후 수정본 통과를 확인했다.
- B1/B2 지도의 전체 viewport 크기, 3배 이미지 확대, 최초 이미지 아래 영역의
  드래그를 widget 테스트로 확인했다.
- 격리된 회원 및 관리자 debug APK 빌드 성공. 운영 서버 요청 없이
  `https://local-test.invalid` 메모리 adapter를 사용한다.
- 초기 Flutter 테스트 엔진 isolate 오류는 TEMP/TMP를 `D:/Temp`로 지정해 해소됐다.
- 로그: `D:/Temp/apt-parking-tests-final.log`, `apt-parking-analyze-final.log`,
  `apt-parking-member-build.log`, `apt-parking-admin-build.log`.

## 화면 검증 상태

최초 시도는 사용자 Escape 입력으로 중지되었고, 사용자의 재개 요청 후
Computer Use로 BlueStacks Android 9/API28에서 아래 항목을 확인했다.
회원/관리자 APK는 같은 격리 패키지에 순서대로 설치했고 모두 로컬 adapter를 사용했다.

| 항목 | 결과·근거 |
| --- | --- |
| 일반 회원의 타인 비공개 연락처 | 상세 입력칸 `비공개`, 입력 비활성화, 차량번호 마스킹 확인. [화면](parking-permissions/member-private-contact.jpg) |
| B1 최초 이미지 밖 드래그 | 초기 이미지 아래 여백에서 드래그해 이미지 이동 확인. [전](parking-permissions/map-b1-before.jpg), [후](parking-permissions/map-b1-pan-outside-image.jpg) |
| B1 확대·축소·이동 | 이미지 자체 확대, 최초 이미지 사각형 밖으로 표시, 확대 후 이동 및 축소 확인. [확대](parking-permissions/map-b1-zoom-full-viewport.jpg), [이동](parking-permissions/map-b1-zoom-pan.jpg), [축소](parking-permissions/map-b1-zoom-out.jpg) |
| B2 확대 | B2 표시와 확대 확인. [전](parking-permissions/map-b2-before.jpg), [확대](parking-permissions/map-b2-zoom-in.jpg) |
| 관리자 타인 차량 수정 | 원본 연락처와 편집 가능한 입력칸, 차단/출차/수정 버튼 확인. 가상 차량번호 `99TEST9999`로 저장 후 재열기에서 유지됨. 타인 등록 안내도 유지됨. [수정 가능](parking-permissions/admin-other-slot-editable.jpg), [저장 후](parking-permissions/admin-saved-vehicle.jpg) |
| 관리자 차단·해제 | 타인 등록을 차단한 후 등록 정보와 관리자 편집/출차 버튼 유지, 주차 가능으로 복원 확인. [차단](parking-permissions/admin-blocked-registration.jpg), [해제](parking-permissions/admin-unblocked-registration.jpg) |
| 관리자 출차 | 로컬 POST 200, 점유 수 `0 / 28` 및 슬롯 재열기에서 회원 기본값과 `주차하기` 표시 확인. 마지막 화면은 다른 사용자 창에 일부 가려져 증거 이미지로 첨부하지 않음 |

관리자 수정·차단·해제·출차의 POST와 이후 GET 200은
[로컬 API 로그](parking-permissions/local-api.log)에 기록했다. API 경로만 저장하고
디버그 VM 서비스 주소 등은 제외했다. 재개 시 관련 테스트
`slot_dialog_permissions_test.dart`, `map_view_zoom_test.dart`,
`local_api_adapter_test.dart` 총 **17개 통과**를 다시 확인했다
(`D:/Temp/apt-parking-resume-tests.log`). 이번 재개 작업에서 앱 소스는 수정하지 않았다.

B2 확대 후 최초 축소 시도 중 BlueStacks가 홈으로 복귀하고 ADB 연결이 잠시 끊겼다.
재연결·앱 재시작 후 B2 표시/확대와 관리자 흐름을 확인했다. 최종 배포 준비 과정에서
B2 확대·이동·축소를 다시 수행했고 종료 없이 정상 표시를 확인했다.
[확대](parking-permissions/map-b2-final-zoom-in.jpg),
[이동](parking-permissions/map-b2-final-pan.jpg),
[축소](parking-permissions/map-b2-final-zoom-out.jpg),
[복귀](parking-permissions/map-b2-final-restored.jpg).
최초 연결 끊김의 원인은 확정하지 않았다. 기존 미완료 항목인 B2 축소 화면 검증은 완료했다.
검증용 핀치 제어는 BlueStacks의 기본 확대 `=`/축소 `-` 키로 생성해 사용했다.
관련 방법은 [BlueStacks 공식 제어 안내](https://support.bluestacks.com/hc/en-us/articles/360058928871-How-to-create-and-edit-controls-in-BlueStacks-5)를 참고했다.

실제 Google 프로필 이름 변경 후 로그인, 운영 서버 권한/저장, Android/iOS
실기기 동작은 미검증이다. 관련 서버 소스는 읽기만 했으며 서버 배포와 DB 변경은
수행하지 않았다. 기존 `ownerEmail`이 없는 기록은 서버에서 별도 확인이 필요하다.

## 재현

```powershell
$env:TEMP='D:\Temp'; $env:TMP='D:\Temp'
flutter test --no-pub --concurrency=2
flutter analyze --no-pub --no-fatal-infos
flutter build apk --debug --no-pub -t lib/main_local_test.dart --dart-define=LOCAL_MEMBER_TEST=true --dart-define=API_BASE_URL=https://local-test.invalid
```

관리자 fixture는 마지막 빌드 명령에 `--dart-define=LOCAL_ADMIN_TEST=true`를 추가한다.
debug 전용·별도 Android 패키지 `apt.ev.service.localtest` 제한을 유지한다.
일반 운영 APK로 배포해서는 안 된다.
