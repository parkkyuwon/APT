# 가입·차량 OCR·게시판·충전기 신고 로컬 검증

> 아래는 최초 로컬 검증 시점의 기록이다. 이후 사용자가 배포·필수 닉네임·단일 차량번호·선택 음성통화를 추가 승인했다. 최신 버전 1.1.4+20, 운영 DB 적용 및 게시 대기 상태는 [후속 배포 검증 기록](RELEASE_1.1.4_20_2026-10-21.md)을 따른다.

## 범위와 실행 환경

사용자가 2026-10-20 승인한 8개 요구와 설계에 따라 Flutter 앱 및 별도 서버 `D:/vsCodeProg/APT-Prj`의 로컬 코드를 변경했다. 기존 미커밋 변경을 보존했다. 운영 마이그레이션, 실제 회원 삭제, 운영 API 쓰기, 배포, Play 게시와 버전 변경은 수행하지 않았다. 현재 앱 버전은 `1.1.3+19`다.

Flutter 3.41.6 / Dart 3.11.4, Windows에서 검증했다. 한국어 OCR 의존성은 MIT 라이선스의 `google_mlkit_text_recognition: 0.15.1`, 한국어 네이티브 모델은 Android `16.0.1`, iOS `~> 9.0.0`이다. iOS 최소 버전은 15.5다. 최신 Flutter OCR 패키지는 현재 Dart SDK 요구조건과 맞지 않아 선택하지 않았다.

## 요구별 결과

| 요구 | 로컬 구현 | 주요 증거 |
| --- | --- | --- |
| 전화번호 수집 제거 | 가입·프로필·세션·직접/QR 주차·관리자 화면에서 제거 | phone-free payload, direct parking, QR tests 및 서버 state/session tests |
| 번호판 OCR 비교 | 휴대폰 한국어 OCR, 입력/사진 변경 시 결과 무효화, 한글 지역명 지원 | plate_recognition, resident_onboarding tests |
| Google 계정 활용 | 별도 닉네임 입력 제거, Google 이름 표시, 별도 차량/서비스 데이터는 동의 안내 | consent_restore tests, profile payload contract |
| 관리자 최종 승인 | 동의/차량 완료 후 대기, 사진 검토 후 최종 승인, 계정·제출 버전 및 실행자 권한 검사 | admin_vehicle_review, server onboarding/Postgres tests |
| 기존 정보 삭제 | 개인정보 정리와 회원 전체 삭제를 구분 | admin_member_management, server cleanup/cascade tests |
| 관리자 OCR 테스트 | 가입과 같은 인식기로 비교하며 회원 저장/승인 호출 없음 | AdminOcrTestScreen, VehicleOcrInput 공유 구조 |
| 아파트 게시판 | 승인 회원 조회/작성/본인 수정·삭제, 관리자 삭제 | community API/widget, server ownership tests |
| 사진 고장 신고 | 최신 충전기 위치 조회, 내용/선택 사진, 본인 조회와 관리자 처리 상태 | charger_report_locations, server report/privacy tests |

OCR 비교는 번호판 글자 일치 판단이며 차량 소유권이나 입주민 신분을 증명하지 않는다. 최종 이용 권한은 서버의 관리자 승인이다. 차량 심사는 선택한 사진을 보관하고 승인/거절 후 사진을 삭제한다. 관리자 OCR 테스트는 저장하지 않는다. 게시판과 고장 신고 사진은 서비스 데이터이며 회원 데이터 완전 삭제 시 외래 키로 삭제한다.

## 자동 검증

- `flutter analyze --no-pub --no-fatal-infos`: 종료 0, `No issues found!`.
- `flutter test --no-pub --concurrency=1`: 종료 0, **153개 통과**, 약 67초. 기존 테스트 전체와 신규 회귀 검사를 포함한다.
- 별도 서버의 순차 Node 전체 테스트: 종료 0, **78개 통과**, 최종 PM 재실행 약 13.2초. 메모리 PGlite와 injected HTTP adapter를 사용하고 실제 서버·DB에 연결하지 않았다.
- `git diff --check`: 종료 0. Mermaid/JSON의 노드 참조 및 색인 파일 존재 검사 통과.
- Android debug APK 빌드: 종료 0, `assembleDebug` 약 197.4초. 한국어 `Kore_ctc` OCR 모델이 APK 자산에 포함됨을 ZIP 검사로 확인했다. 이는 실제 사진 인식 정확도 검증과 다르다.

로그는 `D:/Temp/apt-20261020-analyze-final.log`, `D:/Temp/apt-20261020-tests-final.log`, `D:/Temp/apt-20261020-server-tests-final.log`, `D:/Temp/apt-20261020-android-build.log`에 있다. 테스트 HTTP 로그에 기본 운영 URL이 표시되는 경우에도 ControlledApi/격리 fixture가 요청을 가로채므로 실제 서버에 전송하지 않는다.

산출물: `build/app/outputs/flutter-apk/app-debug.apk`, 196,792,960 bytes. SHA-256: `B8E364F752B12AEC9C7F92676A551E7796764623C6529B6578ED4FDC8B4A0205`.

빌드는 `APP_ENV=dev`, `API_BASE_URL=https://test-api.example.invalid`, `GOOGLE_CLIENT_ID=TEST_WEB_CLIENT_ID`로 운영과 분리했다. 이 APK는 컴파일 검증용이며 운영 로그인/서버 이용용이 아니다. 제한된 메모리를 고려해 Gradle heap 1536MiB/worker 1 및 Kotlin in-process를 해당 프로세스에만 지정했다. 프로젝트의 기존 Gradle 메모리 설정은 변경하지 않았다.

Windows 기본 한글 TEMP 아래에서는 기존 etag 테스트조차 Flutter engine isolate 생성 실패로 멈췄다. 테스트 프로세스의 `TEMP`와 `TMP`를 `D:/Temp/apt-flutter-20261020`로 지정한 뒤 기존 테스트 및 전체 검사가 통과했다. 시스템 영구 환경 변수는 변경하지 않았다.

## QC 수정과 재검토

독립 검토가 제시한 목록 갱신 경쟁을 재현한 뒤 진행 중 GET 종료 후 재조회 예약으로 수정했다. 사진 신고 목록에서 전체 사진을 제외하고 권한이 적용된 상세 조회로 분리했다. 관리자 직접 진입도 기본 슬롯을 신뢰하지 않고 서버 위치를 읽는다.

서버 승인 SQL은 실행자의 승인 관리자 권한과 세션을 같은 SQL에서 검사한다. 사용자 변경 응답의 잔여 전화번호 노출과 관리자 타인 글 수정 권한 확대를 제거했다. 동의 상태의 최상위/중첩 응답과 캐시를 맞췄으며 OCR 주변 한글 접두어를 실제 지역명 허용 목록으로 제한했다. 미검증 회원은 사진 심사를 거쳐야 최종 승인 버튼이 활성화된다. 독립 정적 재검토에서 해당 지적 사항이 수정됐음을 확인했다.

## 운영 반영 전 남은 사항

서버의 `sql/resident-community.sql`, 갱신된 `sql/member-management.sql`은 검토된 대상 DB에 순서대로 반영한 뒤 대응 API를 배포해야 한다. 이번 작업에서는 실행하지 않았다. 구형 웹 `profile.html/profile.js` 및 관리자 클라이언트는 새 OCR/버전 계약과 호환되지 않으므로 웹 클라이언트 갱신 또는 명시적 접근 제한이 필요하다. 모바일 API만 준비된 상태를 전체 웹 서비스 배포 완료로 간주하지 않는다.

개인정보 정리는 알려진 구조화된 전화/연락처/수동 별명/인증 사진 필드를 정리한다. 과거 채팅 본문·임의 로그 자유문·외부 메일·백업에 사용자가 직접 쓴 정보까지 임의 문자열 치환으로 삭제하지 않는다. 계정 전체 삭제와 범위가 다르며 대상 확인 후 관리자가 실행해야 한다.

## 실제 UI·기기 검증 계획

상태: **실행하지 못함**. `adb devices`에 연결 기기가 없었다. 제공된 Computer Use 도구의 `sky.list_apps()`도 두 번 모두 `Computer Use native pipe is unavailable` / OS error 2로 실패하여 제어 가능한 UI를 얻지 못했다. 사용자 승인 없이 임의의 대체 Windows 자동화나 helper 실행을 수행하지 않았다. iOS 빌드·실행은 macOS/Xcode가 필요하다.

재검증 절차:

1. 검토된 테스트 서버/DB 또는 별도 debug 전용 `main_local_test.dart` fixture를 사용한다. 운영 회원을 테스트 대상으로 사용하지 않는다.
2. 신규 테스트 Google 계정으로 동의 → 차량번호 → 카메라/갤러리 OCR → 관리자 대기를 확인한다. 번호/사진 교체, 미인식, 불일치, 취소, 권한 거절을 확인한다.
3. 관리자 사진 검토 → 최종 승인 후 회원 서비스 진입을 확인하고, 심사 중 차량 변경/중복 클릭/세션 만료에서 오래된 승인이 거절되는지 확인한다.
4. 전화번호 없이 직접 주차와 QR 주차를 확인한다. Google 로그인·딥링크·카메라는 OS 기기 검증으로 기록한다.
5. 게시물 작성/수정/삭제, 타인 수정 거절, 관리자 삭제, 저장 실패 후 입력 보존과 지연 목록 갱신을 확인한다.
6. 고장 신고 사진 선택/용량 초과/선택 취소/재시도, 본인 신고만 조회, 관리자 상태 변경을 확인한다. OCR 테스트는 실제 회원 상태를 바꾸지 않아야 한다.
7. 테스트 데이터 정리는 삭제 대상과 범위를 확인한 승인된 테스트 환경에서만 수행한다. iOS 15.5 이상과 Android에서 각각 실행 결과·스크린샷·빌드 식별자를 기록한다.

이 검증 계획은 UI 실행 완료나 권한/실기기 정상 동작의 증거가 아니다.
