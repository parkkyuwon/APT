# 출차 요청 구현 및 앱·서버 연동

> 운영 배포를 진행했다. 최신 적용·Play 상태와 남은 기기 검증은 [운영 배포 기록](DEPARTURE_REQUESTS_RELEASE.md)을 기준으로 확인한다. 아래 내용은 배포 전 구현 검증 기록이며 ‘미적용’ 설명은 당시 상태다.

기준: 2026-10-10. 앱은 `D:/vsCodeProg/APT-APP`, 웹·서버는 `D:/vsCodeProg/APT-Prj`에서 수정했다. 두 저장소 모두 `feature/departure-requests-20261010` 브랜치이며 기존 사용자 변경을 보존했다. 자동 커밋·push·Vercel 배포·운영 DB 쓰기·Play 업로드는 수행하지 않았다.

## 구현된 동작

- 사용 중인 다른 차량의 상세 화면에서 ‘출차 요청하기’를 제공한다. 예상 출차 시간이 남아 있어도 이용자가 실제 충전 완료를 확인한 뒤 요청할 수 있다.
- 본인 차량·미승인 회원·차량 미등록 회원·빈 슬롯·주차 불가 슬롯·비등록 사용자 차량은 요청할 수 없다. 다른 회원의 이메일이 서버에서 숨겨진 경우에도 슬롯과 원본 입차 시각을 전달해 서버가 현재 차주를 찾는다.
- 상대방의 받은 출차 요청 목록에 요청 차량번호, 주차 위치, 요청 시간, 확인 여부를 표시한다. 더보기에서 목록으로 이동한다. 요청만으로 슬롯을 비우거나 충전 완료로 바꾸지 않는다.
- 전송 중 중복 클릭을 막고 서버의 재요청 가능 시간을 표시한다. 같은 요청자/주차 건에는 서버가 5분 제한을 적용한다.
- 알림 권한·전경 알림·백그라운드/종료 후 알림 선택 경로를 구현했다. 알림 선택과 전경 표시 전에 현재 계정의 수신 요청인지 서버에서 다시 확인한다.
- FCM 토큰은 서버 세션에 연결한다. 성공한 서버 로그아웃은 FK로 토큰을 제거하며, 만료·차단 계정의 토큰은 발송 대상에서 제외한다. 모바일은 알림 삭제·auto-init 해제·토큰 삭제를 각각 시도하고 실패한 정리는 앱이 살아 있는 동안 재시도한다. 앱 종료 전에 실패한 로컬 정리는 다음 기동까지 영속화하지 않는다. 오프라인 로그아웃과 종료·재로그인 조합은 실기기 검증 항목이다.
- 서버 요청 저장 성공과 FCM 발송 접수·상대방 확인을 구분한다. Firebase가 없거나 발송에 실패해도 요청 목록에는 저장된다. 저장 후 서버 실행이 중단되면 pending 상태가 남을 수 있으며 자동 발송 재시도 작업은 포함하지 않았다.

## 검증 결과

| 확인 | 결과 |
|---|---|
| Flutter 전체 테스트 | 109개 통과, `D:/Temp/apt-departure-all-tests-final.log` |
| Flutter 정적 분석 | No issues found, 종료 코드 0. `D:/Temp/apt-departure-analyze-verified.log` |
| 서버 Node 22 테스트 | 31개 통과. 실제 마이그레이션 SQL을 PGlite에서 실행하는 오프라인 테스트 포함 |
| Android debug APK | 빌드 성공. `build/app/outputs/flutter-apk/app-debug.apk`, 아래 테스트 전용 설정 |
| 설계·코드 검토 | PATCH ID 형식, 재요청 시간 표시, APNs 등록, 실패한 로그아웃 정리, dispose 후 구독, 중복 목록 조회를 정정 후 재검토 승인 |
| 전체 연동 구조도 | Mermaid·JSON 색인과 SVG 생성. 파일 경로 검증 |

Android 빌드에는 `API_BASE_URL=https://test-api.example.invalid`, `APP_ENV=dev`를 사용했다. 실제 테스트 서버 주소가 아닌 의도적으로 연결 불가한 주소이며 운영 주차 데이터를 변경하지 않는다. Firebase 설정 없는 빌드다. 이 APK를 정상 운영용으로 배포하지 않는다. 외부 플러그인의 deprecated API 컴파일 안내는 있지만 빌드 종료 코드는 0이다.

초기 전체 테스트에서는 새 inbox 테스트가 고정 30ms 후에 응답 표시를 검사하여 병렬 실행 때 실패했다. 응답 처리 뒤 실제 표시 상태를 기다리도록 수정했으며 전체 109개가 통과했다. 알림 실제 도착을 이 테스트로 검증한 것은 아니다.

## 실제 사용을 위한 남은 설정

1. 대상 Vercel/Neon 프로젝트를 확인한 뒤 서버의 `sql/departure-requests.sql`을 적용한다. 서버 기존 세션·회원·주차 테이블이 먼저 있어야 한다. 현재 운영에는 미적용이다.
2. Firebase Console에서 사용 중인 프로젝트를 확인하거나 프로젝트를 준비하고 Android 앱 `apt.ev.service`를 등록한다. 로컬 서버 소스·로컬 배포 환경 변수 이름에서는 Firebase 설정을 찾지 못했다. Vercel 원격 환경 변수는 조회하지 않았다.
3. 서버에는 `FIREBASE_SERVICE_ACCOUNT_JSON` 또는 `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`를 설정한다. 값은 Vercel 비밀 환경 변수에 두며 모바일 앱이나 Git에 넣지 않는다.
4. Flutter 앱은 `flutterfire configure`의 네이티브 설정 또는 아래 dart-define을 사용한다. 이 앱에는 Google Services Gradle 플러그인이 없으므로 Android JSON만 복사하지 말고 명시적 FirebaseOptions 경로를 사용하거나 FlutterFire 구성 절차를 완료한다.

```text
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
FIREBASE_IOS_BUNDLE_ID  (iOS 사용 시)
```

5. iOS는 현재 Firebase 의존성에 맞춰 최소 iOS 15로 갱신했고 remote-notification background mode와 `Runner.entitlements`를 추가했다. Debug는 development, Release/Profile은 production APNs 환경이다. macOS/Xcode에서 팀·Push Notifications capability·프로비저닝 프로필·Firebase APNs 키를 설정하고 빌드해야 한다. Windows에서는 iOS 빌드를 수행하지 않았다.
6. 서버를 검증 환경에 배포한 뒤 두 회원 계정·두 실제 휴대폰으로 전경/백그라운드/종료 후 알림과 차량 표시, 알림 권한 거절, 차주 교체, 중복 요청, 읽음, 로그아웃·계정 전환을 검증한다. Neon 독립 연결 간 잠금 경합은 PGlite 단일 엔진 테스트로 대체하지 않는다.
7. 검증 후 운영 서버 적용과 앱 새 버전 배포를 진행한다. 현재 Play에 게시된 버전 16에는 이번 기능이 들어 있지 않으며 새 Play 제출은 더 높은 빌드 번호가 필요하다.

푸시는 네트워크·OS 설정·사용자 알림 허용에 영향을 받으며 Android 강제 중지나 iOS 종료 조건에서는 다시 앱을 열어야 할 수 있다. 이미 FCM에 접수된 이전 계정의 OS 알림은 서버에서 취소할 수 없다. 앱 안의 상세 정보는 현재 수신자 권한으로 검사한다.

## 구조도와 계약

- [전체 연동 구조도 SVG](../architecture/generated/app-server-integration.svg)
- [전체 연동 Mermaid](../architecture/app-server-integration.mmd)
- [전체 연동 JSON 색인](../architecture/app-server-integration.index.json)
- [앱 구조도](../architecture/project-diagram.mmd)
- 서버 API·마이그레이션 안내: `D:/vsCodeProg/APT-Prj/docs/departure-requests-api.md`.

주요 기존 기능은 앱과 웹에서 Vercel API·Neon DB를 공유한다. 이번 UI 추가는 Flutter 앱의 슬롯 상세·더보기이며 기존 웹 화면에는 출차 요청 버튼을 추가하지 않았다. 웹·서버의 기존 기능 파일은 전체 구조도에 포함했다.
