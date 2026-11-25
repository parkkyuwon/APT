# APT 앱 구현 분석 및 수정 안내

## 집 반경 OpenStreetMap·권한 설정 안내 (2026-11-23 후속)

집 반경 화면은 Google Maps 키 없이 `HomeAreaMap`의 OpenStreetMap 도로 지도를 표시한다. 현재 위치·좌표 입력·지도 터치로 중심점을 지정하고 반경을 미터 단위 원으로 표시한다. `flutter_map`의 기본 HTTP 캐시와 앱 User-Agent, 출처 링크를 사용하며 화면 밖 일괄 다운로드는 하지 않는다. 지도 요청에는 지도 영역·IP 등이 포함될 수 있다. 서버 비콘 데이터나 지하 B1/B2 도면은 이 지도와 별개다.

감시 켜기에서 사전 안내 동의 후 필요한 권한을 요청한다. 부족한 정확한 위치·백그라운드 위치·알림 또는 기기 위치 OFF는 팝업의 설정 이동으로 해결한다. Android 네이티브 채널의 `openSettings`는 위치 서비스/앱 상세/알림 설정을 열며 설정 복귀 시 실제 권한을 다시 확인한다. 사용자가 시작한 활성화만 이어가고 취소·관리자 사용 중지 시 감시를 시작하지 않는다. 변경 전 24번과 새 1.1.7+25 산출물을 구분한다. OpenStreetMap 개인정보 설명은 별도 서버 `privacy.html` 1.5에 준비했으며 서버 게시 상태는 검증 기록을 따른다.

## 지하 위치 추정·관리자 공용 배포 로컬 구현 (2026-11-23)

관리자 허브의 `지하 위치 · 신호 지도`에서 측정 당시 휴대폰 위치를 선택해 15초 BLE 표본을 반복 저장한다. 기존 `beaconPositions` 설치 좌표와 별도 SQLite 기록이다. 관리자가 기록 화면에서 배포/이용자 사용 설정을 적용하면 별도 서버 `D:/vsCodeProg/APT-Prj`의 `/api/indoor-positioning`에 공용 버전을 저장한다. 서버는 관리자 쓰기·승인 회원 읽기를 구분하고 expectedRevision CAS, 개인정보 제거, 비활성화된 회원 응답 자료 제거를 적용한다. 앱 실행/복귀 시 공용 자료를 갱신하고 API 환경·계정·역할별 SQLite 캐시로 오프라인 추정한다. 일반 이용자는 비콘 등록 UI가 없으며 관리자의 공용 사용 설정이 필요하다.

주요 진입은 관리자 `IndoorSurveyScreen`, 회원 `IndoorPositionScreen`, 개인 `HomeAreaSettingsScreen`이다. `BeaconObserver`는 광고 원본 시각의 중복과 5초 만료를 처리한다. `FingerprintPositioner`는 신호 패턴으로 후보 지점을 찾으며 `BeaconLocator`는 미확정 신호 후보 구역을 표시한다. 물리 축척/기하 보정과 정밀 비콘 역추정은 아직 구현 완료로 보지 않는다. `IndoorAccessController`는 인증·앱 수명과 공유 자료 동기화를, `IndoorDatasetProvider`는 서버 응답/버전/오프라인/접근 해제를 담당한다.

B1/B2 측정은 SQLite v3의 `floor` 컬럼·복합 색인과 `IndoorSurveyStore.loadFloor`로 구분한다. 기존 v1/v2 자료의 실제 층·관측·공유 캐시는 유지된다. 기록 화면의 층 필터는 조회용이며 공용 배포는 두 층 전체를 보존한다. 같은 비콘이 다른 층에서도 관측되는 경우를 서버 PUT/GET과 로컬 저장소에서 검증한다.

집 반경은 기기·계정별 개인 설정이며 서버 공용 비콘 자료에 포함하지 않는다. Android/iOS 네이티브 `apt_ev/indoor_location` 채널은 반경 진입 근거와 실제 위치 관찰 중 품질 저하를 조합해 로컬 알림을 제공하고 선택 시 실내 지도에 진입한다. 사용자 조작 없는 화면 실행은 보장하지 않는다. Android는 최대 20분 관찰 foreground service와 시작 제한 시 별도 재시도 안내를 제공한다. iOS는 콜백이 끊긴 것만으로 GPS 상실을 추정하지 않으며 지속된 낮은 정확도의 실제 콜백에서만 안내한다. 관리자 사용 중지는 다음 공용 자료 갱신 때 적용되며 오프라인 기기를 즉시 원격 중지하지 않는다.

서버 additive migration `sql/indoor-positioning.sql`과 API 배포, Google Maps SDK 키/활성화, Android/iOS 실기기 검증은 별도 필요하다. 이번 로컬 소스는 기존 출시 산출물과 구분한다. 설계·상태·검증·후속 항목은 [구현 기록](../verification/UNDERGROUND_POSITIONING_2026-11-23.md)과 [계획](../superpowers/plans/2026-11-23-underground-positioning.md)을 따른다.

## 도식화 지도 앱 적용 (2026-11-16 후속)

사용자가 주차장 도식화 적용을 명시하여 회원 지도와 관리자 지도 편집기를 `assets/images/B1-simplified.png`, `B2-simplified.png`로 전환했다. 원본 `B1.png`, `B2.png`와 서버 좌표는 보존한다. 기존 지도 영역 비율과 백분율 좌표·확대·터치 처리는 유지한다. 관련 지도/편집/홈 가시성 회귀 4개와 분석을 통과했다. 도식화 포함 새 서명 후보는 `AppBundle/releases/2026-11-16-v1.1.5-22-maps/`에 별도로 준비하며 최초 22 AAB와 구분한다. 세부 기하 구조와 실제 마커별 현장 대조는 미수행이다. [적용 기록](../verification/SIMPLIFIED_PARKING_MAPS_2026-11-16.md)을 따른다.

## 서버 운영 반영과 Android 배포 준비 (2026-11-16)

사용자의 검증 후 배포 지시에 따라 상태 버전·차량 인증 정책 SQL을 운영에 적용하고 서버/웹 배포 `dpl_3A5VznwniVJYhiFVu1p3QiBGph2E`를 운영 주소로 전환했다. 회원 56명, 주차 상태 1개, 주차 이력 72개와 15개 테이블 건수 및 기존 회원·주차 데이터의 보존을 확인했다. 정책은 ON, 기존 회원 면제는 0명으로 유지한다. 최신 Flutter 전체 230개·서버 150개 테스트와 분석을 통과했고 Android 후보 버전은 `1.1.5+22`다. Play Console 최고 코드·업로드·게시 상태는 아직 확인하지 못했으며 브라우저 연결 문제가 있다. 앞선 로컬 구현 기록의 운영 미적용 설명은 당시 상태다.

## 차량 사진·OCR 인증 공통 설정 로컬 구현 (2026-11-16)

운영 설정의 `차량 사진·OCR 인증 필수`는 서버 `vehicleVerificationRequired`를 사용하며 기본값은 true다. OFF에서는 사진/OCR 없이 닉네임과 차량번호를 제출하지만 개인정보 동의와 관리자 회원 승인은 유지한다. 서버가 면제로 승인한 동일 차량은 ON 복원 후에도 유지하고 차량 변경 시 재승인을 요구한다. 실제 사진 인증과 `vehicleVerificationExempt`는 별도 상태다. bootstrap 정책을 가입·차량 변경 화면에 전달하고 전체 상태 복사·저장·캐시에 정책을 보존한다.

회원 승인 화면은 승인 불가 사유·선택 회원 사진 검토·처리 중 제어·민감한 작업 확인을 보완한다. 별도 서버 저장소 `D:/vsCodeProg/APT-Prj`에 API·DB·웹 변경과 additive migration을 준비하며 운영 적용·앱 배포는 별도다. 상세 범위는 [검토안](../superpowers/specs/2026-11-16-admin-vehicle-verification-review.md), [구현 계획](../superpowers/plans/2026-11-16-vehicle-verification-policy.md)을 참고한다. 기존 iOS 보류를 유지한다.

추가 요청한 주차장 도면은 `docs/verification/parking-map-preview-20261116/`에 B1/B2 별도 시안으로 준비한다. 주차면·통로·코어/계단·충전 구역을 유지하는 방향이며 원본 이미지와 앱 마커 좌표는 변경하지 않는다. 생성 시안은 정확한 도면 추적본이 아니므로 실제 적용 전에 원본·좌표 대조가 필요하다.

## 전경 NFC와 최우선 안정성 수정 로컬 구현 2026-10-21

이번 로컬 소스는 기존 서명21 배포 산출물과 구분한다. 서버 재가입 정리는 계정 생성·탈퇴 시각을 DB 잠금 안에서 재확인하고 연결 데이터 삭제를 하나의 SQL 트랜잭션으로 처리한다. 관리자 상태 저장은 서버 발급 `stateVersion` 비교를 요구하고 오래된 전체 상태·버전 누락을409로 거절한다. 일반 회원의 타인 슬롯 병합은 유지한다. 별도 서버의 `sql/state-concurrency.sql`과 API·웹 변경은 아직 운영에 적용하지 않았다. 계약·적용 순서는 서버 `docs/state-concurrency-api.md`를 따른다.

앱 `AppStateProvider`는 같은 계정의 변경을 직렬화하고 읽기 revision으로 늦은 조회·오류가 최신 상태를 덮지 않게 한다. `AuthProvider.handleApiError`는 주차·bootstrap의401 및 계정 제한을 인증 단계와 캐시에 반영하며, 일반 작업403은 구분한다. `StateApi`는 필수 state가 없는 성공 응답을 거절한다. AppState와 관리자 payload는 `stateVersion`을 보존하고 지도 편집은 편집 시작 버전을 전달한다.

Android `ForegroundNfcReader`는 Activity 전경에서만 기본 Reader Mode로 NDEF 단일 URI를 읽는다. 선택 NFC 권한·feature를 사용해 NFC 없는 기기의 설치를 막지 않는다. Flutter `ForegroundNfc`가 `apt_ev/foreground_nfc` 이벤트를 기존 DeepLink 검증으로 전달하며 실제 태그 ID는 로그·서버로 보내지 않는다. 태그 제거 전 억제·중복 scanId 차단·처리 소유권 token으로 반복 입출차를 방지한다. OS가 전달한 NFC Tag도 초기 억제 상태에 연결한다. 제거 감지 실패 시 보수적으로 해당 태그를 계속 억제할 수 있으며 실제 기기에서 제거·재접촉을 확인해야 한다.

홈은 현재 route이면서 앱이 resumed일 때만 태그를 처리하고, 편집 화면·다이얼로그·백그라운드에서는 보관한다. route 복귀와 앱 복귀 시 재처리하고 서버 조회 후에도 가시성을 확인한다. 대기 태그는 최신 하나를 사용하며 기존 입차·본인 출차·점유/차단/조회 오류 정책을 유지한다. NFC 검증을 위해 격리 로컬 테스트 진입점도 DeepLink를 시작한다.

iOS 관련 신규 작업은 사용자 지시로 전부 보류했으며 이번에 추가한 iOS 설정·코드·테스트는 되돌렸다. Android NFC RF와 실제 별도 DB 연결 경합은 기기·환경 검증이 남는다. [작업 계획](../superpowers/plans/2026-10-21-priority-fixes-and-nfc.md)과 [설계](../superpowers/specs/2026-10-21-foreground-nfc-design.md)를 참고한다.

## 선택적 주차 음성통화 (2026-10-21)

Android `1.1.4+21`은 선택 통화의 마이크 기능을 `required=false`로 명시해 마이크 없는 기기의 기존 기능 설치를 유지한다. 서명·manifest·16KB 정렬과 산출물은 [21 검증 기록](../verification/RELEASE_1.1.4_21_2026-10-21.md)을 따른다.

최종 21 AAB의 서명·16KB 정렬·선택적 마이크와 BlueStacks의 정확한 21 설치본 기동·게스트·지도 실행을 확인했다. Play에서 기존 기기 감소 0개를 확인한 후 21 전체 출시와 데이터 보안을 검토 전송했다. 이후 공개·Alpha의 활성 구14 사진 권한 차단을 같은21 교체로 수정하고 총4개 변경을 재전송했다. 실제 사전 검사가 완료돼 Google 심사 단계로 전환됐으며, 관리형 게시 ON으로 Google 승인·최종 실제 게시는 아직 남아 있다. [데이터 보안 기록](../verification/PLAY_DATA_SAFETY_2026-10-21.md)과 [사전 검사 완료 증거](../verification/PLAY_PHOTO_PERMISSION_BLOCKER_2026-10-21.md)를 참고한다.

주차 건별 `callAllowed`는 기본 false이며 서버 발급 `parkingRegistrationId`에 연결한다. 일반 주차 저장으로 동의를 변경할 수 없고 저장 완료 후 차주 전용 `/api/parking-voice` 설정 요청을 사용한다. QR 자동 등록은 수신을 켜지 않는다. `ParkingVoiceController`는 승인 계정 전경에서 수신 요청을 확인하고, `MaterialApp.builder`의 `ParkingVoicePanel`이 pushed 화면 위에서도 수락/거절·종료를 제공한다.

`ParkingVoiceApi`는 기존 공용 Dio/쿠키/오류 변환을 사용한다. `WebRtcVoicePeer`는 `flutter_webrtc: 1.6.2+hotfix.4`의 audio-only/relay-only 연결을 사용하며 수락 후 마이크를 연다. 백그라운드·로그아웃·짧은 서버 lease 만료 시 트랙을 비활성화하고 연결을 해제한다. 음성은 앱에서 녹음하지 않는다. TURN 설정 전 capability가 꺼져 있으며 통화 가능 상태로 표시하지 않는다. 실제 Android/iOS 기기 2대의 Wi-Fi/LTE 음성과 마이크 권한 검증은 별도다. 설계와 실행 계획은 `docs/superpowers/specs/2026-10-20-parking-voice-design.md`, `docs/superpowers/plans/2026-10-21-parking-voice.md`를 참고한다.

## 가입·OCR·게시판·고장 신고 (2026-10-20 로컬 변경)

전화번호 입력을 제거한다. 배포 전 추가 지시에 따라 닉네임은 필수 1~30자로 수집한다. QR·직접 주차도 연락처 없이 가능하다. 차량번호 입력값 전체가 번호판 하나에만 일치해야 하며 쉼표·공백·줄바꿈 등으로 두 번호를 넣으면 앱과 서버에서 거절한다. 차량 변경은 단일 기존 값을 교체하고 새 OCR·재승인을 요구한다. 같은 차량에서 닉네임만 수정하면 기존 승인을 유지한다. 가입 순서는 동의 → 닉네임/차량번호/사진 OCR 비교 → 관리자 최종 승인이다. OCR 일치는 신분 증명이 아니며 자동 승인하지 않는다. 거절·차단·탈퇴 계정은 입력 단계보다 먼저 차단한다. 관리자 승인은 계정 생성 시각과 차량 제출 버전을 확인한다.

`VehicleOcrInput`과 `PlateRecognitionService`는 가입·재인증·관리자 `AdminOcrTestScreen`에서 같은 한국어 ML Kit 인식기를 사용한다. 사진이나 입력 번호가 바뀌면 기존 결과를 무효화한다. `google_mlkit_text_recognition: 0.15.1`을 사용하며 iOS 최소 버전은 15.5다. 최신 패키지는 현재 Dart와 맞지 않아 사용하지 않았다. 카메라/갤러리는 기존 image_picker를 유지한다.

`BoardScreen`은 승인 회원 이슈 게시판, `ChargerReportsScreen`/`ChargerReportEditor`는 선택 사진 1장과 위치·내용을 받는 신고 및 상태 조회다. 회원 더보기와 관리자 허브에서 진입한다. API는 `CommunityApi`를 통해 `/api/board`, `/api/charger-reports`를 호출한다. 신고 목록은 사진 유무만 받고 상세에서 사진을 읽는다. 서버가 본인 신고 조회와 관리자 상태 변경을 제한한다. 신고는 충전기를 자동 차단하지 않는다.

관리자 회원 정리에는 기존 회원 전체 삭제와 별도로 개인정보 정리가 있다. 전화번호·인증 사진을 정리하면서 계정·수집한 닉네임·차량번호·이력을 유지한다. 실행 전에 대상과 범위를 확인하고 서버 성공 후 갱신한다. 기존 운영 데이터는 이번 개발 중 삭제하지 않았다.

별도 서버 `D:/vsCodeProg/APT-Prj`의 `resident-community.sql`, 변경된 `member-management.sql`, `parking-voice.sql`은 운영 DB 보존 검사를 거쳐 적용했다(회원 53개·주차 상태 1개 유지). 최종 `j5m89f1ez` (`dpl_FLZLaE3zbhejK4NpU4gL1PXZ9MhF`)를 운영 도메인에 연결하고 canonical ID, dashboard 200·보호 API 401·privacy/계정삭제 페이지 200을 확인했다. 기존 EW12 배포는 복구 대상이다. 검증용 운영 데이터 쓰기·회원 삭제·통화는 실행하지 않았고 TURN은 비활성이다. 서버 계약은 해당 저장소 `docs/resident-community-api.md`, 설계·작업 목록은 `docs/superpowers/specs/2026-10-20-resident-community-design.md` 및 `docs/superpowers/plans/2026-10-20-resident-community.md`를 참고한다.

Windows 테스트에서 한글 TEMP 경로의 Flutter isolate 생성 실패가 재현되어 검증 프로세스의 TEMP/TMP를 `D:/Temp/apt-flutter-20261020`로 지정한다. 기기 OCR·카메라·Google 로그인·QR 및 macOS/iOS 실행 검증은 별도다. 최초 로컬 검증은 `docs/verification/RESIDENT_COMMUNITY_2026-10-20.md`, 187개 Flutter/124개 서버 테스트와 20 산출물은 `docs/verification/RELEASE_1.1.4_20_2026-10-21.md`, 후속 집중 테스트 20개·21 서명 AAB·운영 전환·Play 검토 요청은 `docs/verification/RELEASE_1.1.4_21_2026-10-21.md`에 기록한다.

## 주차 권한·개인정보·지도 수정 (2026-10-14)

`SlotDetail.isOwnedBy`로 이메일 비교를 통일한다. Google 이름/닉네임은 표시용이며
이메일이 없는 기존 기록의 소유자를 이름으로 추정하지 않는다. `hasParkingRecord`는
차단된 슬롯에서도 등록 정보가 남아 있음을 구분한다. 공통 슬롯 다이얼로그는 관리자에게
타인 등록 수정·출차·차단 전환을 제공하며 타인 수정 시 소유자 정보를 유지한다.
타인 비공개 연락처는 입력칸에 `비공개`로 표시한다. 공개 연락처·차량번호는 기존
마스킹을 사용하고 본인/승인 관리자는 편집할 원본을 표시한다.

지도 `InteractiveViewer`는 전체 화면 영역을 사용하고 내부 이미지와 마커를 함께
변환해 최초 이미지 사각형에 확대 결과가 잘리는 문제를 해소한다. 관련 회귀 테스트는
`slot_dialog_permissions_test.dart`, `map_view_zoom_test.dart`다.
격리된 `main_local_test.dart`는 `LOCAL_ADMIN_TEST=true`를 추가하면 가상 관리자로
실행할 수 있다. 기존 debug 전용·별도 패키지·`.invalid` 서버 제한은 유지한다.

이번 변경은 운영용 `1.1.2+18` AAB로 빌드해 Play 프로덕션 검토 전송을 접수했다.
자동 검사·Google 승인·관리형 최종 게시가 남았다. 실제 배포 상태와 산출물은
[Play 제출 기록](../verification/PARKING_PERMISSIONS_RELEASE.md)을 기준으로 확인한다.

기준일: 2026-10-09. 이 문서는 저장소의 현재 Flutter 구현을 기준으로 수정 위치와 검증 범위를 안내한다. 초기 README와 체크리스트에는 더 이상 맞지 않는 설명이 남아 있을 수 있다. 구조와 파일 관계는 [Mermaid 구조도](project-diagram.mmd) 및 [JSON 색인](project-diagram.index.json)을 함께 본다.

## 앱과 실행 환경

APT EV Charging은 Android·iOS Flutter 앱이다. 앱 초기화와 Provider 등록은 `lib/main.dart`, 인증 단계에 따른 루트 화면은 `AuthStage`가 관리한다. 화면 전환에는 Flutter `Navigator`와 `MaterialPageRoute`를 사용한다. 백엔드 구현은 이 저장소에 없으며, 모바일 변경만으로 API 계약이 바뀌었다고 간주하지 않는다.

| 항목 | 구현 |
| --- | --- |
| 앱 버전 | `1.1.5+22` 후보 (`pubspec.yaml`), Play 미제출 |
| CI Flutter | `3.41.6` (`.github/workflows/flutter-ci.yml`) |
| 상태 관리 | Provider, ChangeNotifier |
| HTTP | 공용 Dio, `dio_cookie_manager`, 쿠키 jar, 오류 변환, GET ETag/304 복원 및 GET 재시도 |
| 세션/상태 저장 | `flutter_secure_storage`의 쿠키·세션 정보, `SharedPreferences`의 회원 주차 상태 캐시 |
| 주요 플러그인 | `google_sign_in`, `image_picker`, `qr_flutter`, `flutter_blue_plus`, `permission_handler` |

개발 시작 전 `git status --short`로 기존 변경을 보존하고, 설치된 Flutter 경로와 대상 API 서버를 확인한다. 현재 작업 환경에는 Flutter `3.41.6` / Dart `3.11.4`가 `C:/src/flutter`에 있고 Android SDK command-line tools 22가 `C:/android-sdk`에 복구되어 있다. Android SDK 라이선스 일부는 아직 수락되지 않았고 연결된 Android 기기도 없으므로, 분석·테스트·기기 검증 가능 여부는 작업별 실제 결과로 판단한다. iOS 빌드에는 macOS와 Xcode가 필요하다.

## 주요 데이터와 화면 흐름

1. `main()`은 `DeepLink.start()`, `AppConfig.init()`, `ApiClient.init()` 후 `ApiServices`와 `AptEvApp`을 준비한다. 앱 루트는 인증 상태에 맞는 화면을 선택하며, 인증 stage 또는 계정 정체성이 바뀌면 `MaterialApp`의 상태 수명이 바뀌어 이전 Navigator 화면을 제거한다.
2. `AuthProvider`는 저장된 세션을 복원하고 `/api/auth`로 서버 세션을 확인한다. Google 로그인은 ID 토큰을 서버에 전달한 뒤 HTTP 쿠키 세션을 사용한다. 로그아웃은 로컬 인증 상태와 세대를 먼저 무효화하고, 원격 로그아웃 결과와 관계없이 쿠키·캐시를 정리한다.
3. 세션 세대 번호는 인증 요청과 응답을 보호한다. 오래된 응답 및 재시도는 현재 사용자 상태에 반영되지 않는다. 쿠키 저장/삭제는 직렬화되고, 공용 HTTP 인터셉터는 CookieManager 처리 전후의 세션 세대를 검사해 로그아웃 뒤 쿠키나 ETag가 되살아나지 않게 한다.
4. 회원 홈은 `AppStateProvider.start()`로 회원 상태를 불러온다. 게스트는 `startGuest()`와 `/api/public-dashboard`를 통해 공개 데이터를 읽으며 회원 캐시와 분리된다. 주차 상태 저장 성공 시 서버 응답을 기준으로 하고 기존 낙관적 변경과 실패 롤백 동작을 유지한다. 회원 캐시는 소유자와 상태를 단일 JSON 값으로 저장해 지연 쓰기 중 계정이 섞이지 않게 한다. 소유자를 증명할 수 없는 구형 캐시는 회원 복원에 사용하지 않으며 비동기 요청은 세대 확인을 거친다.
5. QR/NFC URL의 슬롯 링크는 앱 시작 때와 실행 중 모두 `DeepLink` observer가 수신한다. 초기 Navigator route는 인증 루트로 명시적으로 생성해 플랫폼 슬롯 URL의 이름 기반 라우팅 오류를 방지한다. 인증 후 홈이 링크를 처리하기 전에 서버에서 주차 상태를 새로 읽는다. 조회 오류가 있으면 자동 등록을 진행하지 않는다. 유효성 검증 및 자동 등록 흐름은 앱 기능이며, iOS Universal Links를 사용하려면 Associated Domains와 서버의 apple-app-site-association 배포 등 별도 설정이 필요하다.
6. BLE 관리자 흐름은 비콘을 스캔하고 RSSI 기반 실내 위치를 표시한다. Android SDK 버전에 따라 BLE와 위치 권한을 요청하며 `MainActivity` MethodChannel이 Android API 수준을 제공한다. iOS에는 Bluetooth 사용 설명이 설정되어 있다. 권한과 실제 비콘 동작은 OS 실기기 확인이 필요하다.

## 기능별 수정 위치

| 변경 영역 | 주요 코드 | 관련 테스트와 확인 |
| --- | --- | --- |
| 초기화·인증·로그아웃·화면 수명 | `lib/main.dart`, `lib/providers/auth_provider.dart`, `lib/services/auth_api.dart`, `lib/core/session_store.dart` | `auth_provider_guest_test.dart`, `session_lifecycle_test.dart`, `secure_session_storage_test.dart`, `auth_navigation_test.dart` |
| HTTP 쿠키·ETag·세대·재시도 | `lib/core/api_client.dart`, `lib/core/etag_cache.dart`, `lib/core/errors.dart` | `etag_cache_test.dart`, `errors_test.dart`, `secure_session_storage_test.dart`, `session_lifecycle_test.dart` |
| 회원·게스트 주차 상태와 캐시 | `lib/providers/app_state_provider.dart`, `lib/core/state_cache.dart`, `lib/core/session_info_cache.dart`, `lib/services/state_api.dart`, `lib/services/public_api.dart` | `app_state_test.dart`, `app_state_provider_guest_test.dart`, `state_cache_test.dart`, `session_lifecycle_test.dart` |
| 게스트 화면·공개 조회 | `lib/screens/public/guest_shell_screen.dart`, `lib/services/public_api.dart` | `guest_shell_screen_test.dart`, `app_state_provider_guest_test.dart`; 공개 API 흐름 확인 |
| 목록·필터·지도·주차 입력 | `lib/screens/public/parking_list_screen.dart`, `slot_filter.dart`, `map_view_screen.dart`, `lib/widgets/slot_tile.dart`, `slot_dialog.dart`, `lib/models/` | `slot_filter_test.dart`, `app_state_test.dart`; 서버 성공·실패 응답 확인 |
| QR·NFC·딥링크 자동 등록 | `lib/core/deep_link.dart`, `qr_payload.dart`, `lib/screens/public/home_screen.dart`, `shell_screen.dart`, Android manifest, iOS SceneDelegate 설정 | `deep_link_test.dart`, `home_deep_link_test.dart`, `auth_navigation_test.dart`; 종료/실행 중 진입 및 OS 설정은 실기기 검증 |
| 관리자 BLE·비콘 좌표 | `lib/core/bluetooth_permissions.dart`, `lib/screens/admin/console_beacon_scan.dart`, `console_beacon_list.dart`, `beacon_position_editor.dart`, `lib/providers/app_state_provider.dart`, Android `MainActivity.kt`, manifest, iOS `Info.plist` | `bluetooth_permissions_test.dart`, `console_beacon_scan_helpers_test.dart`; 실제 권한·스캔은 Android/iOS 기기에서 확인 |
| 충전 시간 선택 | `lib/core/duration_presets.dart`, `lib/screens/public/home_screen.dart` | `duration_presets_test.dart` |
| 프로필·회원·대화·이력·관리 API | 대응하는 `lib/services/*_api.dart`와 `lib/screens/` | 서비스 요청/응답 계약과 권한을 서버 환경에서 확인 |
| 환경·의존성·플랫폼 빌드 | `lib/config/env.dart`, `pubspec.yaml`, `android/`, `ios/`, `.github/workflows/flutter-ci.yml` | SDK 버전 및 플랫폼별 빌드 확인. 배포 스크립트는 검증 명령이 아님 |

## 환경과 검증

Android는 `compileSdk=36`, `targetSdk=36`이며 Google Play 대상 API 갱신 대응으로 빌드 번호를 14에서 15로 올렸다. 기존 Play 최고 versionCode가 15 이상이면 더 큰 번호로 다시 빌드해야 한다. 최종 산출물·서명과 게시 조건은 [Android API36 검토](ANDROID_API36_REVIEW.md)에 기록한다. 사용자가 제공한 이번 안내는 카메라 사용 제재가 아니며 카메라 권한은 이 API 갱신에서 변경하지 않았다.

`API_BASE_URL`, `GOOGLE_CLIENT_ID`, `APP_ENV`는 `--dart-define`으로 주입한다. 기본 서버 설정은 운영 환경이므로 수동 실행 전 대상 서버를 명시적으로 확인한다. `APP_ENV=dev`만 바꿔서는 서버 주소가 바뀌지 않는다. 예시 주소와 클라이언트 ID는 자리표시자다.

```powershell
flutter --version
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

대상 테스트 예시는 `flutter test test/session_lifecycle_test.dart`, `flutter test test/home_deep_link_test.dart`, `flutter test test/bluetooth_permissions_test.dart`다. SDK 또는 Android 라이선스가 막으면 실제 오류와 미검증 범위를 구분해 기록한다. Google 로그인, QR/NFC 링크, BLE 권한과 스캔은 단위 테스트만으로 정상 동작을 단정할 수 없으며 OS 실기기 확인이 필요하다. iOS 빌드는 macOS/Xcode에서 별도로 수행한다.

Android debug 빌드는 확인된 테스트 서버 값을 지정해 실행한다. 이 저장소의 `android/deploy.bat`과 `android/fastlane/`은 배포 설정을 포함할 수 있으므로 일반 검증 명령으로 호출하지 않는다.

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://test-api.example.invalid --dart-define=GOOGLE_CLIENT_ID=TEST_WEB_CLIENT_ID --dart-define=APP_ENV=dev
```

2026-10-09 안정화 및 API36 전환 검증은 Flutter 3.41.6 / Dart 3.11.4에서 수행했다. `flutter analyze --no-pub --no-fatal-infos`는 종료 코드 0, `No issues found`이며 `flutter test --no-pub --concurrency=2`는 85개 모두 통과했다. API36 전환 후 기존 운영 환경 기본값으로 debug APK와 난독화 release AAB도 빌드했다. AAB 실제 manifest의 대상 API36·빌드15, 서명과 16KB 정렬을 검사했다. 상세 산출물 및 게시 조건은 [API36 릴리스 안내](../ANDROID_API36_RELEASE.md)에 있다. 이전 안정화 과정의 자리표시자 APK는 최신 APK로 대체됐다. BLE·Google 로그인·OS 링크의 실기기 검증 및 macOS iOS 빌드는 미수행이다.

안정화 로그는 로컬 `D:/Temp/apt-app-tests-final.log`, `D:/Temp/apt-app-analyze-final.log`, `D:/Temp/apt-app-build-final.log`에 있으며 API36의 새 검증 로그는 `D:/Temp/apt-api36-tests.log`, `apt-api36-analyze.log`, `apt-api36-build.log`, `apt-api36-debug.log`다. 변경 수락과 남은 검증 조건은 [안정화 PM 검토](PM_REVIEW.md) 및 [API36 PM 검토](ANDROID_API36_REVIEW.md)에 기록했다.

구조·의존성·주요 데이터 흐름이 바뀌면 이 안내와 Mermaid/JSON 색인을 함께 갱신한다. 민감한 값은 코드, 문서, 로그에 복사하지 않는다.

추가로 API36 대상 debug APK를 BlueStacks Android 9/API28에 설치해 앱 실행·게스트 공개 조회·필터·B1/B2 지도·이용안내·로그인 화면 복귀를 확인했다. [실행 보고서](../verification/BLUESTACKS_RUN.md)에 화면·로그와 미검증 범위를 기록했다. Android16 실행 또는 release AAB의 런타임 검증을 의미하지 않는다.

## 사진·동영상 권한 경고 대응 (2026-10-09)

추가로 제공된 Play Console 경고는 버전 14·15의 광범위 사진 권한 문제다. 기존 `image_picker_android 0.8.13+16`의 `ACTION_GET_CONTENT` 시스템 단일 사진 선택 흐름을 유지하고 Android manifest에서 `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`를 병합 제거한다. 새 후보는 `1.1.0+16`이며 전체 트랙의 기존 문제 번들을 교체해야 한다. 상세 검증·Console 작업은 `docs/verification/PHOTO_PERMISSIONS_RELEASE.md`에 기록한다. 구성요소·의존성·API 데이터 흐름 변경은 없다.

## 출차 요청 및 전체 서버 연동 (2026-10-10)

`DepartureRequestsApi`, `DepartureRequestButton`, `DepartureRequestsScreen`으로 타인 차량 출차 요청과 수신 목록을 추가했다. 예상 시간과 무관하게 현장에서 충전 완료 확인 후 요청하며 슬롯은 차주가 직접 출차 처리한다. `PushNotifications`는 계정 수명·기기 토큰·알림 진입을 담당한다. 실제 서버는 `D:/vsCodeProg/APT-Prj`의 Vercel Node/Neon 구현이며 원자적 주차 건 검증·5분 제한·수신자 권한·세션별 푸시 토큰을 구현했다. Firebase/Neon 마이그레이션·운영 배포·실기기 전달은 미완료다. iOS 최소 버전은 Firebase 의존성에 맞춰 15로 변경했다.

전체 앱·웹·서버·DB 연동은 [통합 구조도](app-server-integration.mmd)와 [통합 색인](app-server-integration.index.json)을 확인한다. 상세 결과·설정·미검증 범위는 [출차 요청 검증 기록](../verification/DEPARTURE_REQUESTS.md)에 있다.

## 로컬 회원 검증 추가 (2026-10-09)

별도 debug 진입점과 `apt.ev.service.localtest` 패키지에서 가상 회원으로 입출차, 이용 이력, 채팅, 프로필을 확인하고 일반 앱 비회원 제한을 복원했다. 검증 중 발견한 내정보 응답/채팅 전송의 화면 종료 오류와 프로필 복귀 시 정보 미갱신을 수정했다. 전체 테스트는 97개 통과했고 정적 분석은 이상 없음이다. 재현 방법·증거·남은 범위는 [LOCAL_MEMBER_RUN.md](../verification/LOCAL_MEMBER_RUN.md)에 기록한다.

# 관리자 회원 정리 확장 (2026-10-14)

`MemberManagementScreen`은 승인 콘솔의 회원 정리 버튼 및 회원 사용 정보 메뉴에서 진입한다.
`UsersApi.listMembers`의 `/api/admin-members` 서버 필터로 프로필 미완료와 마지막 주차·충전
사용일의 일/달력 개월 조회를 수행한다. 현재 페이지 선택, 관리자/본인 제외, 대상·영구 삭제 확인,
미입력 회원에게 기본 안내와 최대 2000자의 추가 메시지 입력 및 발송 확인을 제공한다.
`MemberNoticesApi`의 `/api/member-notices`는 `ProfileSetupScreen`에서 본인 안내만 조회한다.
프로필 입력은 안내 조회 실패와 독립적으로 가능하고 앱 복귀 시 안내를 다시 조회한다.

별도 서버 `D:/vsCodeProg/APT-Prj`의 `sql/member-management.sql` 및 API 배포가 필수다.
Google 계정 자체는 삭제하지 않는다. 앱 회원 데이터·연결·세션을 실제 삭제한 뒤 같은 이메일의
Google 로그인은 신규 가입과 관리자 승인으로 진행한다. 테스트는 격리된 fixture/PGlite만 사용한다.
운영 회원 삭제나 안내 발송은 개발·검증 중 자동 실행하지 않는다.

2026-10-14 당시 적용 결과: 운영 스키마와 Vercel API 배포 완료, 당시 회원67명 및 기존주차정보 보존 확인.
Flutter131/Node56 테스트와 정적분석 통과. 정상 release `1.1.3+19` AAB 준비 완료.
당시 새 Play 업로드는 Chrome 확장 연결 해제로 재연결 대기였다. 후속 21의 검토 요청 완료 상태는 문서 상단을 따르며, 당시 상세 기록은
`docs/verification/MEMBER_MANAGEMENT_2026-10-14.md`를 참고한다.

