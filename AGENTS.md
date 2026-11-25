# APT APP 작업 안내

이 저장소는 Flutter/Dart 기반 Android·iOS 모바일 앱이다. 실제 구현을 기준으로 작업하며, 초기 README와 개발 체크리스트에는 현재 코드와 다른 설명이 있다.

## 수정 전 참고 자료

- `docs/architecture/PROJECT_ANALYSIS.md`: 구현 현황, 기능별 수정 위치, 검증 명령과 확인할 문제.
- `docs/architecture/project-diagram.mmd`: 전체 구조도.
- `docs/architecture/project-diagram.index.json`: 구성요소별 파일·심볼·테스트와 의존 관계.
- 변경 대상의 색인과 직접 연결된 구성요소부터 확인한 뒤 실제 소스와 API 계약을 읽는다. 구조도가 오래되었으면 관련 변경과 코드로 확인한다.

## 프로젝트의 구현 방식

- `lib/main.dart`에서 초기화와 Provider 등록을 수행한다. `AuthStage`에 따른 루트 화면 전환과 `Navigator`/`MaterialPageRoute`를 사용한다.
- HTTP는 `ApiClient`의 공용 Dio, 쿠키 세션, ETag, 오류 변환을 사용한다. 서비스는 `lib/services/`, 주차 상태는 `AppStateProvider`에 있다.
- 상태 저장 응답은 서버를 기준으로 한다. 기존 낙관적 변경과 실패 롤백을 보존한다.
- 게스트 조회는 `/api/public-dashboard`를 사용한다. 회원 상태 캐시와 게스트 데이터 흐름을 구분한다.
- 환경 설정은 `--dart-define`의 `API_BASE_URL`, `GOOGLE_CLIENT_ID`, `APP_ENV`로 주입한다. 개발·검증 전에 대상 서버를 확인한다.
- 백엔드 소스는 이 저장소에 없다. 모바일 변경만으로 서버 API 계약을 변경했다고 가정하지 않는다.
- 기존 UI, 모델 변환 함수, 공통 위젯과 의존성을 먼저 활용한다. 다른 언어용 스킬의 프로젝트 구조를 Flutter에 적용하지 않는다.

## 변경과 검증

- 시작 시 `git status --short`를 확인하고 기존 사용자 변경을 보존한다. 민감한 파일의 내용이나 키를 문서·로그에 복사하지 않는다.
- 실행 가능한 Flutter SDK 경로를 확인한 후 `flutter analyze --no-fatal-infos`와 변경 범위에 맞는 `flutter test`를 실행한다. 실행할 수 없으면 이유와 미검증 범위를 명시한다.
- BLE, Google 로그인, QR/딥링크, 플랫폼 권한 변경은 해당 OS의 실기기 검증이 필요하다. 단위 테스트만으로 해당 기능의 정상 동작을 단정하지 않는다.
- 배포 스크립트는 앱 게시나 버전 변경을 수행할 수 있으므로 검증 명령으로 무심코 실행하지 않는다.
- 구조·의존성·주요 데이터 흐름이 변경되면 Mermaid와 JSON 색인을 함께 갱신한다.

## 배포 방식 — 사용자 지시 (2026-11-23)

- 앞으로 배포 관련 작업은 서비스의 공식 API 또는 공식 API를 사용하는 CLI로 수행한다. Play Console은 Google Play Android Developer API/fastlane, Vercel은 Vercel API/CLI를 사용한다.
- 배포 상태·기존 버전 확인, 업로드, 출시 변경과 결과 검증에도 이 방식을 적용한다. 사용자가 별도로 요청하지 않는 한 배포를 위해 브라우저나 컴퓨터 UI 자동화로 전환하지 않는다.
- API 인증·권한이 없거나 API에서 지원하지 않는 필수 단계가 있으면 구체적인 제약과 필요한 설정을 안내한다. 인증서·서비스 계정 키·토큰을 임의로 생성하거나 권한을 확대하지 않는다.
- 자격 증명은 승인된 로컬 보안 설정에서 읽고 저장소·문서·로그·채팅에 노출하지 않는다. API 접근 설정과 실제 배포 완료를 구분하고, 서비스 응답으로 업로드·심사 제출·게시 상태를 각각 확인한다.
