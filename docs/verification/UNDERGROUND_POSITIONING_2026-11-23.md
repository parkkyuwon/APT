# 지하 위치 추정·공용 배포 로컬 구현 기록

작성일: 2026-11-23. 운영 앱/서버에 반영되었다는 기록이 아니다.

## 제공한 동작

- 관리자 허브 → `지하 위치 · 신호 지도` → 측정 당시 내 위치 선택 → 15초 정지 측정 → 별도 기록 저장. BLE 스캔의 상단 측정 버튼에서도 진입한다. 기존 비콘 설치 좌표는 변경하지 않는다.
- 측정 기록 화면에서 학습 제외/포함, 서버 측정 자료를 작업 기록으로 불러오기, 비콘 신호 후보 구역 확인, 공용 배포와 이용자 사용 켜기/끄기를 제공한다.
- 공용 배포는 현재 작업 중인 유효한 측정 세션 전체로 서버 자료를 교체한다. 기존 서버 기록을 편집하려면 먼저 `서버 측정 불러오기`를 사용한다. 다른 관리자가 먼저 저장하면 revision 충돌을 안내하고 새로고침을 요구한다.
- 승인 회원은 더보기/지도 화면에서 `지하 내 위치`에 진입한다. 등록 작업은 표시하지 않는다. 관리자가 사용 설정한 서버 공용 자료를 앱 실행/복귀 시 내려받고, 인터넷이 없어도 마지막 정상 캐시를 사용한다.
- 집 주변 반경은 개인 계정의 기기 보안 저장소에 보관한다. 공용 비콘 자료에는 집 위경도·측정자 이메일·기종명·측정 라벨을 배포하지 않는다.
- 집 반경/관찰 조건을 만족하면 네이티브 로컬 알림을 제공하고, 선택 시 현재 계정과 설정 버전을 재검증한 뒤 실내 지도에 진입한다. Firebase 미설정과 독립적인 경로다.
- B1/B2는 SQLite v3의 명시적 층 컬럼과 복합 색인으로 분리 저장·조회한다. 같은 좌표·같은 비콘이라도 별도 측정 세션과 층 정보가 유지된다. 기록 화면의 전체/B1/B2 필터는 조회에만 적용되며 공용 배포는 두 층의 전체 작업 자료를 포함한다. 기존 v1/v2 관측과 공유 캐시를 보존하며 실제 층 값을 백필한다.

## 실제 구현 범위와 한계

`BeaconObserver`는 iBeacon UUID/Major/Minor와 실제 광고 시각으로 표본을 중복 제거하며 5초 이후 신호를 만료한다. 측정 수집과 앱 수명/취소/다른 스캐너의 소유권을 구분한다. `FingerprintPositioner`는 공용 측정 패턴을 비교해 위치/층 후보를 산출한다. `BeaconLocator`는 신호 후보 구역만 제공한다. 물리 도면 보정과 정확한 거리/센서 좌표 역추정은 구현 완료 범위가 아니다.

일반 앱의 사용자 조작 없는 화면 실행은 보장하지 않는다. Android는 영역 진입 근거가 있을 때 OS가 허용한 위치 foreground service를 최대 20분 실행한다. 서비스 시작이 제한되면 관찰 재시도를 위한 별도 도착 안내를 제공한다. iOS는 위치 콜백 부재만으로 GPS 끊김을 판단하지 않고, 실제로 지속된 낮은 정확도 콜백을 받았을 때만 품질 저하를 판정한다. 따라서 모든 GPS 단절 상황의 자동 감지를 보장하지 않는다.

관리자의 공용 사용 중지/새 자료는 서버와 다음 통신이 성공했을 때 반영된다. 오프라인/종료 기기를 즉시 원격 제어하지 않는다. 권한 해제 응답은 메모리와 공용 캐시를 제거하며, 계정/역할/API 환경 변경 시 다른 캐시 범위를 사용한다. 계정 변경 후 이전 설정 화면이 새 계정 감시를 끄지 않도록 네이티브 중지 요청에도 소유 계정을 전달한다.

공용 자료는 SQLite의 원자적 단일 스냅샷으로 저장한다. 모델을 별도 파일에 학습/저장하지 않고 유효한 표본에서 계산한다. 서버에서 받은 비활성화는 저장소 오류가 있어도 현재 메모리 상태에서 먼저 적용한다. 저장 장치 자체의 오류까지 기기 재시작 후 정책 보존을 보장하지는 않는다.

## 서버 코드와 운영 적용 전제

실제 백엔드: `D:/vsCodeProg/APT-Prj` / 운영 주소는 기존 `API_BASE_URL` 설정을 따른다. 이번 작업에서 운영 데이터에 쓰거나 배포하지 않았다.

- 신규 계약: `GET/PUT /api/indoor-positioning`.
- 기존 Vercel 함수 수 제약을 유지하기 위해 rewrite와 profile feature dispatcher를 사용한다.
- `expectedRevision` CAS로 동시 수정 충돌을 409로 반환한다.
- 세션 500개, 총 관측 20,000개, 요청 2MiB 상한과 백분율/시간/식별자/허용 필드를 검증한다.
- 관리자/회원 ETag가 구분되며 회원은 비활성 상태에서 빈 자료를 받는다.
- additive migration: `D:/vsCodeProg/APT-Prj/sql/indoor-positioning.sql`.
- 상세 계약/적용 순서: `D:/vsCodeProg/APT-Prj/docs/indoor-positioning-api.md`.

운영 적용 전에는 별도 검증 환경에서 마이그레이션과 API 배포를 확인해야 한다. 아직 기존 운영 서버에 이 API가 있다고 가정하지 않는다. 처음 사용하는 기기는 서버 API/자료가 준비되기 전 추정할 공용 자료가 없다.

## 지도 SDK 설정

현재 Flutter 3.41.6 / Dart 3.11.4에 맞춰 google_maps_flutter 2.18.1, iOS SDK9 구현 2.19.0을 사용한다. iOS 최소 15.5를 유지한다. sqflite는 2.4.2+1, 테스트 FFI는 2.4.0+3으로 해결되었다.

- Android: `GOOGLE_MAPS_ENABLED=true`와 제한된 Maps SDK용 `GOOGLE_MAPS_API_KEY` dart-define을 빌드에 주입한다.
- iOS: `GOOGLE_MAPS_ENABLED=true` dart-define과 Xcode `GOOGLE_MAPS_API_KEY` build setting을 설정한다.
- 플랫폼별 Maps SDK 활성화와 공급자 이용 설정이 필요하다. 키를 문서/소스에 넣지 않는다.
- 지도 미설정 빌드에서는 현재 위치 또는 위경도 입력으로 집 반경을 저장할 수 있다. 실외 지도 타일을 오프라인으로 배포하는 기능은 포함하지 않는다. 지하 도면은 기존 앱 자산이므로 네트워크와 독립적이다.

## 자동 검증 기록

자동 검증 최종 결과는 이 문서 하단에 실행 증거 확인 후 추가한다. 실제 API 네트워크나 운영 DB를 쓰지 않는 controlled transport/fixture/PGlite로 검증한다.

- 앱 계산·저장·권한/화면/수명·서버 자료 API 테스트를 실행한다.
- `flutter analyze --no-fatal-infos`와 전체 `flutter test`를 실행한다.
- Android Studio JBR로 Kotlin 컴파일과 네이티브 정책 테스트를 실행한다. 시스템 기본 JDK26은 이 프로젝트 Gradle과 호환되지 않아 검증 프로세스에서만 JBR을 지정했다.
- 백엔드 전체 Node 테스트 159개가 통과했다. 실제 핸들러/PGlite CAS·권한·자료 제거·미세초 시간 경계·B1/B2 분리·기능 rewrite 검증을 포함한다.
- Android 네이티브 정책 테스트 2개와 Kotlin 컴파일이 통과했다. 로그: `build/native-indoor-validation.log`.
- iOS 소스와 기존 RunnerTests 연결은 준비했으며 Windows에서는 Xcode 빌드와 iPhone 실행을 수행하지 못했다.

## 실기기 확인 목록

- [ ] B1/B2의 학습과 분리된 기준 지점에서 실제 오차/층 판정/추정 가능 비율 기록.
- [ ] Android/iOS 최소/최신 지원 OS에서 BLE 권한·신호 수집·위치 권한 단계 확인.
- [ ] 실외에서 반경 진입 후 지하 이동, 반경 밖 위치 저하, 경계 흔들림, 오래된 내부 근거의 오탐 확인.
- [ ] 잠금/백그라운드/콜드 실행의 로컬 알림과 중복 억제, 계정/반경 변경 후 오래된 알림 거절.
- [ ] 비행기 모드+Bluetooth ON에서 공용 캐시 추정, 서버 미설정/접근 해제/비활성화/오류 응답 확인.
- [ ] 제조사 절전·강제 중지·재부팅·권한 회수·알림 거절/집중 모드의 제공 범위 기록.
- [ ] 차량 많음/적음·휴대폰 손/주머니·다른 기종에서 위치/배터리 변화를 측정.

위 항목은 실측 없이 통과로 바꾸지 않는다. 앱 서명 후보/스토어 게시/운영 SQL·Vercel 배포는 이번 기록의 완료 항목이 아니다.

## 최종 실행 결과

- `flutter analyze --no-fatal-infos`: 종료 코드 0, `No issues found!` (23.9초). 로그 `build/indoor-analyze-final-floor.log`.
- `flutter test --no-pub --concurrency=2 --timeout=60s`: 종료 코드 0, **286개 전부 통과** (87초). 로그 `build/indoor-full-tests-final-floor.log`.
- 백엔드 `npm test`: 종료 코드 0, **159개 통과 / 실패 0개**. PGlite와 controlled transport를 사용하며 운영 DB/서버 쓰기가 아니다. 로그 `build/indoor-backend-tests.log`.
- Android `flutter build apk --debug`에 테스트 서버 URL `https://test-api.example.invalid`, 테스트 Google client ID, APP_ENV=dev를 명시했다. 종료 코드 0, `build/app/outputs/flutter-apk/app-debug.apk` 생성 (51.9초). 이 APK는 운영 접속용 출시 후보가 아니다. 로그 `build/indoor-debug-build-final.log`.
- 별도 Android Kotlin 컴파일·네이티브 정책 테스트 2개 통과. `build/native-indoor-validation.log`.
- Mermaid/JSON 참조와 Android manifest XML, iOS Info.plist 구문을 확인했다.
- `flutter devices`에는 Windows/Chrome/Edge만 있으며 Android/iOS 실기기가 연결되지 않았다. iOS 빌드도 Windows에서 검증하지 않았다.

통합 검사 과정에서 인증 복원 테스트는 신규 공용 자료 조회 요청도 처리하도록 갱신했다. 저장소 열기 실패 후 dispose가 이미 처리한 예외를 다시 내보내는 문제는 실패 재현 테스트 후 수정했다. 기존 충전기 위치 테스트의 50ms 고정 대기는 실제 응답 UI를 기다리는 제한 시간 방식으로 바꾸어, 병렬 빌드 중 발생하던 시간 의존 실패를 제거했다. 기존 충전기 기능 소스는 이 테스트 보완으로 변경하지 않았다.
