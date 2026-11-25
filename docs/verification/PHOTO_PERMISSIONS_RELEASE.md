# 사진·동영상 권한 수정 — 2026-10-09

사용자가 제공한 Play Console 경고와 연결된 Console에서 버전 14·15의 사진 권한 문제를 확인했다. 게시 개요의 심사 제출 버튼은 비활성 상태이며 이 문제를 해결해야 제출할 수 있다.

## 수정 범위

- Android manifest에서 READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE를 tools:node="remove"로 병합 제거한다.
- 프로필 입력/수정 및 차량 사진 재인증은 기존 image_picker 단일 사진 선택을 유지한다. 고정 image_picker_android 0.8.13+16 소스의 launchPickImageFromGalleryIntent는 기본 설정에서 ACTION_GET_CONTENT 시스템 선택 도구를 호출한다. 전체 사진 접근이나 새 의존성을 추가하지 않는다.
- 앱 버전은 1.1.0+16, applicationId apt.ev.service, targetSdk 36을 유지한다. CAMERA와 BLE 권한은 이번 경고 수정에서 변경하지 않았다.
- 실제 서버 요청, API 계약 변경, iOS 변경은 수행하지 않는다.

## 검증

Flutter 3.41.6 / Dart 3.11.4. flutter analyze --no-fatal-infos 종료 코드 0, No issues found. flutter test --no-pub --concurrency=2 종료 코드 0, 97개 모두 통과.

첫 테스트 시도는 Windows 기본 임시 경로에서 Could not prepare isolate 엔진 시작 오류로 중단했다. TEMP/TMP를 D:/Temp로 지정한 재실행에서 전체 테스트가 통과했다. 로그는 D:/Temp/apt-photo-permissions-analyze.log와 apt-photo-permissions-tests-ascii-temp.log에 있다.

## Console 확인

새 AAB 빌드 성공(182.5초), bundletool validate 종료 코드 0, jarsigner verify 종료 코드 0. jarsigner는 일반적인 자체서명 체인/타임스탬프 경고를 출력했으며 jar verified로 완료했다. 실제 base manifest는 package apt.ev.service, versionCode 16이며 금지된 사진/저장소 권한 4개가 모두 없다. 산출물: [apt-ev-service-v1.1.0-16.aab](../../AppBundle/releases/2026-10-09-v1.1.0-16/apt-ev-service-v1.1.0-16.aab). SHA256: `cef02bf28e5a6eef2b16facb312f1b43f37b84ab74739c76808a271f244311dc`. 같은 폴더에 해당 빌드의 symbols·R8 mapping과 검증 로그를 보관했다.

실제 Console 최신 번들 목록의 최고 코드는 15였다. 버전 15는 프로덕션·공개 테스트·내부 테스트, 버전 14는 비공개 테스트 Alpha에 있다. 모든 영향받는 트랙의 번들을 새 권한 수정 버전으로 대체해야 한다. 기존 AAB의 권한은 Console 선언만 수정해서 제거할 수 없다.

버전 16 AAB 업로드와 Console 최적화가 완료됐다. Console에서 실제 versionCode 16, minSdk24, targetSdk36 및 ReTrace 매핑/네이티브 디버그 기호 첨부를 확인했다. 프로덕션 새 릴리스를 저장했으며 버전 15는 새 릴리스에서 제외됐다. 게시 개요에 프로덕션 16 변경사항이 표시되고 빠른 자동 검사가 시작됐다.

Chrome 파일 선택은 최초 두 번 시간 초과됐다. 사용자가 ChatGPT 확장의 파일 URL 접근을 허용한 뒤 새 연결 탭에서 업로드가 성공했다. 이전 연결 탭에서의 미저장 텍스트는 새 탭에 다시 입력했다.

내부 테스트는 기존 15를 제외하고 16으로 저장·출시했다. Console에서 최신 출시 버전 16, 내부 테스터에게 제공됨, 2026-10-09 19:55(KST)를 확인했다. 트랙의 기존 테스터 구성이나 접근 권한은 변경하지 않았다.

공개 테스트도 16으로 저장했으며 Console에서 기존 15와 14가 다른 버전으로 대체됨으로 표시됐다. 비공개 테스트 Alpha는 기존 14를 포함하지 않은 16 릴리스로 저장 완료 알림을 확인했다. 프로덕션·공개·Alpha의 실제 배포는 심사/관리형 게시 완료 이후다.

게시 개요의 변경사항 4개(프로덕션 16, 공개 테스트 16, 기존 공개 트랙 재시작 변경, Alpha 16)를 검토를 위해 전송했다. Console이 **검토 중인 변경사항**으로 전환됐고, 빠른 자동 검사 성공 즉시 검토를 위해 전송된다는 안내를 확인했다. 확인 시 자동 검사 최대 14분 남음이 표시됐다. 전송 요청은 접수됐지만 자동 검사 통과, Google 본 심사 승인, 실제 프로덕션 게시는 아직 확인하지 않았다. 관리형 게시가 켜져 있으며 기존 게시 준비 항목을 무심코 게시하지 않았다.

근거 화면: [심사 전송 접수](../../AppBundle/releases/2026-10-09-v1.1.0-16/console-review-submitted.jpg). 후속 확인용 Console 탭을 유지했다. 요청 시점의 파일 수정·AAB 생성·업로드·모든 영향받는 트랙 새 후보 저장·심사 전송 요청까지 수행했다.

Android 실기기에서 사진 선택·취소·촬영, Android16/16KB 환경 실행은 아직 검증하지 않았다. 로컬 빌드·권한 검사·Console 업로드와 Google 심사 승인·프로덕션 실제 게시를 구분한다.

공식 근거: [Google Play 사진·동영상 권한 정책](https://support.google.com/googleplay/android-developer/answer/14115180), [Android 시스템 사진 선택 도구](https://developer.android.com/training/data-storage/shared/photo-picker).
