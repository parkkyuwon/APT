# 최우선 안정성 수정과 Android 전경 NFC 검증

## 구현 범위

사용자는 최우선 개선 5개와 NFC 설계를 승인한 뒤 iOS 작업 전체를 보류했다. 이번 범위는 서버 재가입 정리, 관리자 상태 버전 비교, 앱 주차 경합 보호, 인증 상태 반영, Android 전경 NFC다. 이번에 추가했던 iOS 변경은 모두 역적용했고 기존 iOS 사용자 변경을 보존했다.

앱·서버 로컬 소스를 수정했다. 운영 DB 마이그레이션·회원 삭제·운영 주차 쓰기·TURN 활성화·서버 배포·Play 업로드는 실행하지 않았다. 기존 서명21 AAB를 수정하거나 교체하지 않았다.

## NFC 동작과 경계

- Android 전경 Reader Mode에서 4KiB 이하 NDEF 메시지의 단일 URI를 읽어 `apt_ev/foreground_nfc` 채널로 전달한다. Flutter는 기존 HTTPS origin·경로·단일 슬롯 검사를 재사용한다. 상대 URL은 NFC 채널에서 허용하지 않는다.
- NFC hardware는 선택 feature다. 미지원·비활성·채널 부재 시 앱의 기존 실행을 막지 않는다. NFC 태그 ID와 원문을 로그·서버에 추가 수집하지 않는다.
- `NfcAdapter.ignore`로 실제 제거 전 접촉을 억제한다. OS 콜드/웜 인텐트의 NFC Tag도 억제에 연결한다. scanId 중복과 처리 중 같은 슬롯 재입력을 차단하며, 오래된 홈의 완료가 새 홈의 처리 token을 해제하지 못한다.
- 제거 감지 등록 실패 시 OS 전달 태그는 보수적으로 계속 억제한다. 다음 접촉에서 제거 감지를 재시도하므로 기기에 따라 태그를 떼고 추가로 다시 접촉해야 할 수 있다. 실제 하드웨어 검증 없이 RF 중복 억제 완료로 판정하지 않는다.
- 홈 route가 현재이고 앱이 resumed일 때만 처리한다. 다이얼로그·다른 화면·백그라운드에서는 보류하며 복귀 시 재처리한다. 서버 조회를 기다리는 사이 가시성·최신 태그가 바뀌었는지도 확인한다.
- 기존 자동 입차·본인 슬롯 출차·타인 점유/차단/조회 실패 안내를 유지한다. NFC는 차주 인증을 대체하지 않으며 통화 수신을 켜지 않는다.

## 회귀 검증

| 검증 | 결과 |
| --- | --- |
| NFC 수신 RED | 기존 구현에서 플랫폼 태그 미수신과 stop 명령 미전달로 3개 실패 확인. |
| 가려진 홈 RED | 다이얼로그 뒤 홈이 pending을 소비하는 실패 확인 후 route 가시성·복귀 처리 적용. |
| 백그라운드 RED | GET 대기 중 pause 후 pending이 소비되는 실패 확인 후 resumed 가드 적용. |
| NFC·기존 링크 집중 GREEN | 최초 14개 통과. pause 경계 추가 후 홈/NFC/기존 링크 8개 통과. token 회귀를 포함한 최종 결과는 전체 회귀 결과를 따른다. |
| 모바일 안정성 RED/GREEN | 동일계정 응답 역전·쓰기 직렬화·401/차단403·필수 state·version·지도 편집 시작 버전 회귀. 담당 집중 검증 29개 통과. |
| 서버 전체 테스트 | `npm test` 종료0, **137개 통과**, 실패0. `D:/Temp/apt-priority-server-tests.log`. PGlite·격리 fixture만 사용. |
| 앱 전체 정적 분석 | 최초 스타일 info 1건 수정 후 최종 `flutter analyze --no-pub --no-fatal-infos` **No issues found**, 종료0, 12초. `D:/Temp/apt-nfc-priority-analyze-final.log`. |
| 앱 전체 테스트 | 최종 **216개 통과**, 실패0, 2분44초. `D:/Temp/apt-nfc-priority-flutter-tests-final.log`. NFC 채널→격리 API 입차·동일 이벤트 무시·재접촉 출차도 포함. |
| Android 네이티브 컴파일·manifest | 격리 x64 debug APK 빌드 **종료0**, Gradle166.3초. 최종 package `apt.ev.service.localtest`, NFC permission 존재·feature `required=false`, 광범위 사진·저장소 권한0개 확인. |
| 실제 NFC RF·기기/UI | 미수행. NFC 실장 기기와 충전기 태그가 필요하며 BlueStacks는 RF 검증을 대체하지 못한다. |
| 실제 별도 DB 연결 경합 | 미수행. PGlite의 순서 교차·실패 주입 검증과 별도로 필요하다. |
| iOS | 사용자 지시로 전체 보류. |

모바일 집중 로그는 `D:/Temp/apt-parking-consistency-red.log`, `apt-parking-consistency-final-green.log`, `apt-map-version-red.log`다. 최초 전체 앱 회귀는 `D:/Temp/apt-nfc-priority-flutter-tests.log`에서211개 통과했다. 교차 리뷰에서 수신 설정 후 전체 stateVersion 동기화와 기존 사진 재인증403 문자열 처리를 추가로 보완했으므로 최종 전체 회귀는 `D:/Temp/apt-nfc-priority-flutter-tests-final.log`를 따른다. 관련 신규 회귀4개는 RED→GREEN을 확인했다. 수신 설정 뒤에는 큐 내부에서 전체 상태를 직접 다시 조회해 최신 버전만 오래된 snapshot에 붙이지 않으며, 재조회 실패 시 저장된 수신 설정과 이전 버전을 유지하고 사용자에게 경고한다.

## Android 검증 산출물

`flutter build apk --debug --no-pub --target-platform android-x64 -t lib/main_local_test.dart --dart-define=LOCAL_MEMBER_TEST=true --dart-define=API_BASE_URL=https://local-test.invalid --dart-define=APP_ENV=dev`로 빌드했다. 운영 서버에 접속하지 않는 fixture이며 `.localtest` 패키지와 LOCAL TEST 배너를 사용한다. x64 전용이므로 일반 ARM 휴대폰 설치용 또는 Play 배포용 APK가 아니다. 이번 작업에서 APK 설치·앱 UI 조작·물리 태깅은 실행하지 않았다.

- 파일: `D:/Temp/apt-nfc-priority-local-x64-debug.apk`
- 크기:148,686,942 bytes, versionCode21
- SHA256:`28b33e915cdc786e185c2be12aeba3222cc856587fe69e6a1f293791750e9873`
- 빌드 로그:`D:/Temp/apt-nfc-priority-android-build.log`
- 매니페스트:`D:/Temp/apt-nfc-priority-debug-manifest.xml`
- 검사 결과:`D:/Temp/apt-nfc-priority-apk-verification.json`

최초 apkanalyzer 실행은 기본 JDK26의 버전 문자열 검사와 시스템 DEBUG echo 때문에 XML 추출에 실패했다. 프로세스에 Android Studio JBR와 DEBUG 비활성 환경을 지정해 재실행했고 최종 XML 파싱·선택 NFC·권한 회귀 검사가 종료0으로 통과했다. 프로젝트 또는 시스템 Java 설정을 변경하지 않았다.

기존 Play 서명21 AAB의 SHA256을 다시 확인했으며 `207a8a7fdb4531da22952183af62314f18b403e32826c3ed603dad99cc5b9284`로 유지된다. 새로운 NFC 코드는 그 AAB에 포함됐다고 주장하지 않는다. 이번 debug 검증 버전21은 업로드 가능한 새 versionCode를 준비한 것이 아니다.

## 배포 전 조건

새 서버는 `sql/state-concurrency.sql`의 versioned writer와 계정 정리 함수를 요구한다. 기존 전체 기능 마이그레이션 뒤 이 SQL을 명시적으로 적용해야 하며, 누락 시 기존의 무보호 writer로 우회하지 않는다. 기존 관리자 클라이언트가 버전을 전송하지 않으면409를 받으므로 앱·웹·API·DB 적용 순서를 함께 계획한다. 자세한 계약과 보존 guard는 서버 저장소 `docs/state-concurrency-api.md`를 따른다.

Android 실제 장치에서 앱 시작·다른 탭·편집창·다이얼로그·로그인 전·백그라운드 복귀, NFC OFF/ON, 태그 장시간 접촉·제거·재접촉, 다른 태그, 외부 URL, 타인 점유·차단·서버 오류를 확인한다. 운영 회원·주차 데이터를 쓰지 않는 검증 서버나 격리 fixture를 사용한다.

플랫폼 동작 기준은 [Android Reader Mode와 ignore](https://developer.android.com/reference/android/nfc/NfcAdapter), [NDEF와 전경 NFC](https://developer.android.com/develop/connectivity/nfc/advanced-nfc)를 따른다. 기기 검증이 끝나기 전에는 실제 태그 인식 정상 동작을 단정하지 않는다.
