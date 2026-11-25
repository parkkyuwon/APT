# APT App Stability Implementation Plan

**Goal:** 승인된 여섯 개선 항목을 기존 사용자 변경과 서버 계약을 보존하면서 구현하고 검증한다.

**Architecture:** 인증 변화에 주차 Provider의 데이터 수명과 요청 세대를 연결한다. 소유자별 영속 캐시, 공통 HTTP 정리, Flutter 링크 observer와 플랫폼 권한 선택을 이용한다.

**Tech Stack:** Flutter 3.41.6, Dart, Provider, Dio, flutter_secure_storage, SharedPreferences.

## PM 승인과 역할 배정

사용자가 여섯 개선 항목 전체와 Blue Ocean 사용을 승인했고 PM 모델을 `gpt-6.1-sol`로 명시했다. PM은 `/root/pm_review`이며 이 모델로 새 세션을 생성했다. root는 기존 세션의 모델을 유지하는 시스템 설계자·통합 개발자다. 이미 수행한 `flutter_environment`, `platform_links`, `docs_dependencies` 작업자는 모델 지정 요청 전에 root의 모델을 상속해 실행했으며 실행 중 모델이 변경되었다고 주장하지 않는다. 이후 필요한 독립적인 소규모 작업자는 Blue Ocean 기본값인 `gpt-6-luna`로 배정한다.

| 역할 | 책임자 | 검토/검증 범위 |
| --- | --- | --- |
| PM | pm_review (`gpt-6.1-sol`) | 범위·수락 기준·로드맵 승인, 독립 검토, 최종 수락 |
| 시스템 설계·통합 개발 | root (기존 세션) | 인증/HTTP/Provider 통합, Mermaid/JSON 갱신, 직렬 Flutter 검증 |
| 환경 복구 | flutter_environment (기존 상속 모델) | SDK/Android 도구 경로·설치 근거·환경 한계 |
| 플랫폼 개발·기존 UI 연속성 검토 | platform_links (기존 상속 모델) | BLE/링크 helper와 설정; 시각 배치 유지 |
| 문서·의존성 검토 | docs_dependencies (기존 상속 모델) | import/manifest 사용 근거, 현재 구현 문서 |
| 독립 QC | pm_review | 구현자와 분리된 계약/소스/테스트 검토, 결함 재검증 |

에이전트 최대 4개 슬롯에서 독립 파일만 병렬 작업한다. 메모리 압력 때문에 Flutter 테스트·분석·빌드는 root가 직렬 수행한다. 소스 공유 파일과 아키텍처 색인 수정은 root가 통합한다. 최종 검증은 재사용한 완료 작업자의 독립 검토와 PM 검토를 거친다.

Blue Ocean/project-diagram은 PM·설계/QC에 적용하고 기존 Flutter/Dart 구조·명명·Provider/Dio 패턴을 보존한다. C++/C# 타입 접두사, Mocha 및 .sln 폴더 규칙은 이 프로젝트에 적용하지 않는다. GUI DR 면제: 이번 작업은 승인된 상태 수명·링크 수신·권한/설정 정정이며 기존 화면 배치·색상·타이포그래피를 유지한다. 시각 개편은 범위에 없다. 이 면제는 권한 요청과 OS 링크 진입의 실기기 검증을 면제하지 않는다.

## 수락 기준

1. 로그아웃/회원 변경/게스트 전환은 이전 회원 상태·폴링·캐시를 정리하고 이전 응답·오류·롤백·finally가 새 상태를 덮어쓰지 않는다.
2. 서버 거절 및 네트워크 실패에서도 로그아웃은 로컬 인증을 즉시 종료하고 쿠키·ETag를 정리한다. 이전 HTTP 응답과 GET 재시도가 세션을 되살리지 않는다.
3. 영속 주차 캐시는 회원 소유자를 확인하고 게스트에서 읽거나 저장하지 않는다. 저장/삭제와 세션 복원 경합을 검사한다.
4. 실행 중 링크는 기존 링크 계약을 검증한 후 같은 대기 슬롯 경로에 전달한다. 홈 초기화 및 현재 회원 조건을 충족하기 전에 등록하지 않는다.
5. iOS Bluetooth 권한 helper와 native 사용 설명/permission_handler 컴파일 설정이 일치한다. Android 11 이하 호환을 보존하고 실제 현위치 추정 기능에 맞게 Android 위치 선언·runtime 권한 계약을 정정한다.
6. 복구한 Flutter SDK에서 의미 있는 회귀 테스트와 전체 분석·테스트를 실행한다. Android debug 빌드는 시도하고 결과를 기록한다. 실기기/macOS/외부 서버 부재는 검증 한계로 명시한다.
7. README/DEVELOPMENT와 Mermaid/JSON을 실제 구현·의존성·검증 결과에 맞춘다. 기존 사용자 변경·서버 API 계약을 보존하며 커밋·게시를 수행하지 않는다.

PM은 이 로드맵을 승인한다. 최종 구현 수락은 [PM_REVIEW](../../architecture/PM_REVIEW.md)의 검증 근거와 결함 정정 상태를 확인한 뒤 기록한다.

### 승인된 통합 정정

- Android BLE는 `console_beacon_list.dart`의 RSSI 기반 현위치 추정에 사용되므로 `neverForLocation` 선언 제거와 모든 지원 Android 버전의 위치 권한 계약 정정을 PM이 승인했다. Android 12 이상 근처 기기+위치, Android 11 이하 위치 권한을 실제 OS 버전에 맞춰 확인하며 새 패키지보다 기존 플랫폼 기능을 재사용한다. 근거: [Android Bluetooth permissions](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions). 권한 거절 및 실제 비콘 검색은 기기 검증 한계로 명시한다.
- 로그아웃 후 Navigator에 push된 관리자 화면이 남는 경로는 기존 인증 상태 수명 결함이다. 인증 stage/identity에 따라 Navigator 수명을 재설정하고 widget RED→GREEN 검증하는 정정을 승인했다. 배치·내비게이션 방식 자체를 개편하지 않는다.
- 주차 캐시의 owner/state 별도 쓰기는 지연 저장 중 다른 회원 payload를 이전 회원이 읽는 RED로 재현됐다. 단일 JSON envelope로 소유자와 상태를 원자적으로 저장하고 legacy 캐시의 회원 복원을 거절하는 최소 정정을 승인했다. `state_cache_test.dart`의 지연 SharedPreferences 회귀와 최종 전체 테스트에서 GREEN을 확인했다.
- 콜드 링크를 받은 플랫폼 기본 route가 named initial route 오류를 만들던 RED를 재현했다. `onGenerateInitialRoutes`가 명시적 `/` MaterialPageRoute를 만들고 `routes['/']`로 인증 루트를 제공하도록 정정했다. DeepLink가 슬롯을 보관하고 AuthStage가 첫 화면을 결정하는 책임은 유지한다. 초기 루트 예외 없음/슬롯 보관과 로그아웃 pushed route 제거 widget 회귀가 GREEN이다.

## 작업 1 개발 환경 복구

담당: flutter_environment. 기존 SDK 위치를 확인한 뒤 없으면 공식 Windows SDK를 검증해 비어 있는 `C:/src/flutter`에 설치한다. 삭제형 기존 설치 스크립트는 실행하지 않는다.

- [x] `flutter --version`, `flutter doctor -v`로 경로와 필수 도구 확인.
- [x] 루트 작업자가 `flutter pub get` 실행 및 lockfile 변경 확인.

## 작업 2 인증과 주차 상태 수명

담당: root. 파일: `lib/providers/auth_provider.dart`, `lib/providers/app_state_provider.dart`, `lib/core/state_cache.dart`, `lib/services/auth_api.dart`, `lib/main.dart`. 테스트: `test/session_lifecycle_test.dart`, `test/state_cache_test.dart`.

- [x] 제어 가능한 HTTP 어댑터에서 지연 응답을 보내고 `startGuest()` 또는 `reset()` 뒤 이전 응답이 적용되지 않는 테스트 작성. `expect(provider.state.maintenanceMode, false)`와 공개 요청 경로를 검사.
- [x] `flutter test test/session_lifecycle_test.dart test/state_cache_test.dart`에서 기존 문제로 실패하는지 확인.
- [x] 요청 세대를 추가하고 `if (generation != currentGeneration) return`으로 응답·오류·finally·롤백의 적용을 보호. 인증 listener가 세대를 전환하고 캐시 소유자를 검사.
- [x] 로그아웃 `finally`에서 HTTP 세션을 정리하고 인증 복원 응답의 세대를 검사.
- [x] 같은 테스트 및 기존 게스트 테스트를 실행해 통과 확인.

## 작업 3 플랫폼 권한과 실행 중 링크

담당: platform_links, root가 main/home/기존 사용자 수정 scan 화면에 통합. 파일: `lib/core/deep_link.dart`, 새 BLE 권한 helper, `ios/Runner/Info.plist`, 비콘 목록, 홈·초기화. 테스트: 링크 파싱·warm route 및 권한 선택.

- [x] 정상/잘못된 URI와 warm route를 테스트하고 기존 실패 확인.
- [x] Flutter observer/알림으로 링크를 전달하고 iOS BLE 요청 분기를 연결.
- [x] 구조·테스트 검사 후 실제 OS 링크 association·BLE는 기기 검증 범위로 명시.

## 작업 4 문서와 의존성

담당: docs_dependencies. 파일: `README.md`, `DEVELOPMENT.md`, `pubspec.yaml`; root가 lockfile 생성.

- [x] 직접 import·실제 사용을 검색해 미사용 후보를 확인하고 필요한 패키지만 유지.
- [x] 실행·환경·화면·테스트·배포 설명을 현재 코드에 맞춰 수정.
- [x] 아키텍처 Mermaid/JSON과 분석 문서를 변경된 데이터 흐름에 맞춰 갱신.

## 작업 5 통합 검증과 독립 검토

담당: root, 완료 작업자를 검토자로 재사용한다.

- [x] `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build apk --debug` 실행.
- [x] 테스트·설정·문서와 변경 diff를 검토하고 범위 내 결함 수정.
- [x] 검증 결과와 실기기·macOS·외부 서버 조건을 구분해 보고. 자동 커밋·푸시·스토어 배포는 수행하지 않는다.

## 최종 완료 근거

PM은 승인된 여섯 항목의 구현을 최종 수락했다. Flutter 3.41.6/Dart 3.11.4 SDK 복구와 pub get, RED→GREEN 회귀, 전체 테스트 85개(종료 코드 0), 분석 No issues found(종료 코드 0), 최종 Android debug APK 재빌드 44.7초(종료 코드 0), git diff --check 및 아키텍처 JSON 16개 구성요소/37개 관계/파일 누락0 검사를 확인했다. 로그는 D:/Temp/apt-app-tests-final.log, D:/Temp/apt-app-analyze-final.log, D:/Temp/apt-app-build-final.log이다. APK는 build/app/outputs/flutter-apk/app-debug.apk(184,468,238바이트)이며 테스트 자리표시자 환경의 검증용 산출물이다.

실기기 BLE·Google 로그인·OS 링크, macOS iOS 빌드, 외부 서버 통합은 미검증 범위로 명시했다. 구조도/색인/분석과 README/DEVELOPMENT를 현재 구현에 맞췄으며 자동 커밋·푸시·스토어 배포는 하지 않았다. 상세 수락 및 QC 기록은 docs/architecture/PM_REVIEW.md를 참조한다.
