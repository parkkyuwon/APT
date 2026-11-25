# 앱 활성 상태 NFC 인식 설계

## 목적과 범위

Android 앱이 화면에 열린 상태에서 충전기 NFC 태그의 NDEF URI를 직접 읽고 기존 슬롯 링크 처리로 연결한다. 현재 배포 대상인 Android를 우선한다. iOS는 사용자 시작 NFC 세션과 별도 entitlement가 필요한 독립 작업이므로 자동 상시 읽기와 동일하게 취급하지 않는다.

유효 태그는 기존 `https://apt-ev-charging.vercel.app/index.html?slot=<슬롯ID>&mode=smart` 형식을 사용한다. 앱이 꺼진 상태의 기존 OS 링크 진입은 보존한다. 태그 기록·수정·차주 인증 수단으로의 사용·새 서버 API는 추가하지 않는다.

## 검토한 방식

1. **Android 기본 Reader Mode와 기존 MethodChannel 재사용을 권장한다.** 앱이 전경일 때만 읽고 브라우저 선택 없이 Flutter에 전달한다. 추가 패키지가 필요 없다.
2. Foreground dispatch로 기존 intent를 재사용할 수도 있으나 Android 버전별 URL dispatch와 Flutter 라우팅의 중복 전달을 더 신경 써야 한다.
3. NFC 플러그인은 iOS 세션까지 확장하기 편하지만 현재 Android 범위에는 새 의존성과 플랫폼 설정이 늘어난다.

## 동작

- Android Activity가 resumed이며 Flutter가 수신 준비를 마쳤을 때 NFC Reader Mode를 활성화한다. pause·엔진 해제 시 해제한다.
- NDEF URI만 읽는다. 승인된 HTTPS origin·정확한 경로·하나의 유효 slot만 기존 DeepLink 검증을 통과한다. 태그 ID나 원문을 로그·서버에 추가 수집하지 않는다.
- 동일 태그는 Android 태그 제거 감지(`NfcAdapter.ignore`)와 처리 중 보호를 사용해 한 번만 전달한다. 시간 제한만으로 장시간 접촉 후 재실행되게 하지 않는다. 기존 흐름은 본인 점유 태그를 다시 처리하면 출차하므로 중복 읽기가 입차 직후 출차로 이어지지 않아야 한다. 사용자가 태그를 떼고 다시 접촉하면 새로운 동작으로 처리한다.
- 승인 회원은 최신 주차 상태 확인 후 기존 정책을 사용한다. 빈 슬롯은 입차, 본인 슬롯은 출차, 타인 점유·차단·조회 실패는 안내 후 중단한다. 통화 수신 선택은 켜지지 않는다.
- 다른 탭에서 읽으면 홈으로 전환한다. 편집·확인 다이얼로그 등 pushed route가 있으면 화면을 임의 종료하지 않고 홈으로 돌아왔을 때 보관한 태그를 처리한다. 홈 route 복귀를 관찰하고, 소비 전과 서버 조회 후 쓰기 직전에 현재 route인지 확인한다. 대기 중 태그는 최신 하나를 보관하며, 조회 중 다른 태그가 들어오면 아직 쓰지 않은 이전 태그를 대체한다. 이미 전송한 쓰기는 임의로 취소하지 않는다.
- 로그인·승인 전에는 NFC로 권한을 우회하지 않고 기존 링크 보관 정책을 따른다. 미지원 기기·NFC 꺼짐·플러그인 부재에서 앱 초기화와 기존 기능은 정상 유지한다.

NFC 권한과 hardware feature는 선택 기능으로 선언해 NFC 없는 기기의 설치를 제한하지 않는다. 새 화면·스캔 버튼·자동 NFC 설정 변경은 추가하지 않는다.

## 검증

- Dart: 플랫폼 채널 이벤트 → 검증 → 슬롯 보관, 잘못된 origin/path/중복 slot 거절, 반복 스캔 억제, 중단 후 이벤트 무시, 미지원·예외 처리.
- Widget: 기존 홈/다른 탭/다른 route, 로그인 전 대기, 입차·출차·타인 점유·네트워크 실패 및 기존 QR/콜드 링크 회귀.
- Android: 네이티브 컴파일과 최종 manifest의 NFC 선택 feature 확인. 테스트 산출물은 검증 서버 또는 격리 fixture를 사용한다.
- 실제 NFC 장치: 앱 전경·복귀·NFC OFF·다른 태그·반복 접촉·태그 제거 후 재접촉을 확인한다. BlueStacks는 NFC RF 인식을 증명하지 못한다.

## 근거

- 기존 코드: `lib/core/deep_link.dart`, `lib/core/qr_payload.dart`, `lib/screens/public/home_screen.dart`, `lib/screens/public/shell_screen.dart`, Android MainActivity·manifest.
- Android Reader Mode: https://developer.android.com/reference/android/nfc/NfcAdapter
- Android NFC: https://developer.android.com/develop/connectivity/nfc/advanced-nfc
- iOS 세션: https://developer.apple.com/documentation/corenfc/nfcndefreadersession

## 검토 상태

사용자는 이 설계와 최우선 개선 5개 동시 진행을 승인한 뒤 iOS 작업은 전부 보류했다. Android 전경 NFC와 최우선 네 가지 안정성 변경을 로컬에서 구현·검증한다. 기존 사용자 변경을 보존하며 커밋·배포·운영 데이터 검증 쓰기를 자동 수행하지 않는다. 최종 결과는 `docs/verification/PRIORITY_FIXES_NFC_2026-10-21.md`를 따른다.
