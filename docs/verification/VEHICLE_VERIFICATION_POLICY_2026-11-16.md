# 차량 인증 공통 설정과 관리자 사용성 검증

검증일: 2026-11-16. 앱·별도 서버·웹의 로컬 구현과 격리 테스트 결과다. 운영 DB 적용, 서버/앱 배포, 버전 변경, 커밋은 수행하지 않았다. 기존 미커밋 작업과 iOS 작업 보류를 유지했다.

## 구현 결과

- 관리자 운영 설정에 `차량 사진·OCR 인증 필수` ON/OFF를 추가했다. 서버 정책 `vehicleVerificationRequired`는 기본 true이며 명시적인 boolean false만 OFF로 해석한다.
- OFF에서는 사진·OCR 없이 닉네임과 차량번호 한 개를 제출할 수 있다. 개인정보 동의와 관리자 회원 승인은 유지한다. 제출만으로 승인·면제·보호 API 접근이 허용되지 않는다.
- 최종 관리자 회원 승인에서 서버가 `vehicleVerificationExempt`를 기록한다. 실제 `vehicleVerified`와 OCR 결과를 조작하지 않는다. ON 복원 후에도 승인된 동일 차량의 면제는 유지하며, 차량번호 변경과 명시적 차량 승인 취소는 면제를 해제한다.
- 로그인/bootstrap·profile·회원 목록 계약과 앱 상태 복사·캐시·주차 저장·지도 저장 payload에 정책을 반영했다. 구형 관리자 payload에 정책이 없으면 서버가 저장된 값을 보존한다.
- 관리자 승인 불가 사유, 선택 회원의 사진 바로 검토, 민감한 작업 확인, 처리 중 버튼 잠금, 사진 목록 로딩·조회 오류를 보완했다. 사진 전용 승인은 OFF에서도 OCR 일치와 동의가 필요하다.
- 웹 운영 설정, OFF 가입/차량 변경과 기존 사진 재인증 URL의 복구 흐름을 연결했다. 기존 사진 필수 흐름은 Android OCR 심사를 유지한다.
- 정책 변경의 유효한 이전/이후 값과 회원 승인 시 실제 인증/면제/제출 버전을 서버 활동 이력에 남긴다.

## 검증 결과

Flutter 3.41.6 / Dart 3.11.4 SDK 경로는 `C:/src/flutter/bin/flutter.bat`이다. Windows Flutter 프로세스의 TEMP/TMP는 `D:/Temp/apt-flutter-20261116`을 사용했다. 앱 API 테스트는 controlled adapter 또는 격리 `.invalid` fixture이며 실제 운영 요청을 수행하지 않는다.

| 검증 | 결과 | 증거 |
| --- | --- | --- |
| 앱 정적 분석 | 최종 `flutter analyze --no-pub --no-fatal-infos`, 종료 0, No issues found, 12.2초 | `D:/Temp/apt-policy-analyze-final.log` |
| 앱 전체 회귀 | `flutter test --no-pub --concurrency=2`, 종료 0, 227개 통과, 2분43초 | `D:/Temp/apt-policy-flutter-full.log` |
| 최종 관리자 집중 회귀 | 추가된 테스트와 최종 안내 문구 수정 후 8개 통과, 종료 0 | `D:/Temp/apt-policy-admin-final.log` |
| 가입·차량 변경·정책 복구 | policy/nickname/notices 9개 통과. OFF에서 pending 유지, 저장 중 ON 전환 시 bootstrap 재조회와 입력 번호 보존 포함 | `D:/Temp/apt-policy-mobile-green.log` |
| 로컬 fixture | 14개 통과. 관리자 정책 반영과 일반 회원의 정책 변경 거절 포함 | `D:/Temp/apt-policy-fixture-green.log` |
| 서버 전체 회귀 | `npm test`, 150개 통과, 실패 0, 종료 0, 28.58초 | `D:/vsCodeProg/APT-Prj/docs/verification/2026-11-16-vehicle-policy-npm-test.log` |
| 독립 웹 회귀 | 검토자가 브라우저 VM 회귀 파일 2개를 별도로 실행, 19개 통과 | 코드 품질 검토 결과 |
| 구조 문서 | Mermaid/JSON 시간 일치, JSON 파싱·구성요소 중복·관계 참조 검사 통과 | project-diagram 및 app-server-integration 두 쌍 |

전체 앱 227개 실행 후 관리자 집중 테스트 3개가 추가됐다. 최종 관리자 8개는 별도 실행이며 전체 테스트 수에 합산하지 않는다. 새 테스트가 추가된 뒤 제품 코드 변경은 마지막 확인 문구와 중괄호 정리에 한정된다.

최초 분석에서 작업 중인 관리자 callback 타입 오류와 중괄호 info를 발견해 수정했다. 최종 분석은 위 결과를 따른다. 서버 전체 회귀 중 신규 정책 기본값이 추가된 저장 상태와 기존 fixture 예상값의 불일치를 수정했고, 마지막 전체 150개를 다시 실행했다.

## RED/GREEN 및 독립 검토

새 앱 정책 필드 미보존과 OFF 화면에 OCR 입력이 남는 실패 4개를 확인한 뒤 모델·가입 UI를 수정했다. 저장 중 정책 변경의 복구 부재와 fixture 정책 저장·권한·회원 목록 누락도 실패를 먼저 확인했다. 관리자 UI는 OFF 승인 불가·사유 없음·확인 없는 차단·로딩 없음의 실패를 확인하고 수정했다.

독립 스펙 검토는 정책 이력의 이전/이후 값 및 승인 면제 구분 누락을 지적했고 서버에 반영했다. 코드 품질 검토는 웹 `shared.js`의 정책 직렬화 누락, OFF 상태의 사진 재인증 URL 차단, 차량 변경 후 승인 유지로 잘못 안내하는 문구를 발견했다. 실제 AppStore/프로필 VM 회귀로 RED/GREEN을 확인한 뒤 재검토에서 승인받았다. 변경된 운영 JS의 캐시 참조도 갱신했다.

충전기 수량 편집 보호, 미저장 변경 보호, 회원 검색·페이지 이동, 활동 로그 생명주기와 허브 메뉴 정리는 [관리자 검토안](../superpowers/specs/2026-11-16-admin-vehicle-verification-review.md)의 후속 항목이다.

## 운영 적용과 미검증 범위

서버 계약은 `D:/vsCodeProg/APT-Prj/docs/vehicle-verification-policy-api.md`를 따른다. 기존 resident-community/member-management/departure/parking-voice/state-concurrency 마이그레이션 뒤 `sql/vehicle-verification-policy.sql`을 명시적으로 적용하고 서버·웹을 배포한 다음 새 앱을 배포해야 한다. 새 SQL은 기존 회원을 일괄 면제하지 않는다. 실제 적용 전 기존 회원·주차 보존과 복구 절차를 확인한다.

이번 검증은 PGlite/격리 fixture다. 실제 PostgreSQL 별도 연결의 동시성, 운영에 배포된 앱·웹·API 간 통합, 실기기 Google 로그인·카메라·OCR 및 iOS 실행은 수행하지 않았다. 단위·widget 테스트 결과로 실제 기기 기능의 정상 동작을 단정하지 않는다.

## 주차장 도식화 추가 요청

사용자가 선택한 주차면·통로·동/계단·충전 구역 유지 방향으로 ImageGen 시안 두 장을 만들었다. [원본/시안 비교](parking-map-preview-20261116/compare.html), [B1](parking-map-preview-20261116/B1-simplified-preview.png), [B2](parking-map-preview-20261116/B2-simplified-preview.png)를 제공한다. 생성 지시와 원본/시안 크기·SHA256·한계는 같은 폴더에 있다. 원본 이미지 해시는 유지되며 앱 지도와 마커 좌표를 변경하지 않았다.

시안은 정밀 도면 추적본이 아니다. 주차면 수, 벽체·계단 연결과 충전 마커 위치는 원본과 대조해야 하며 흐릿한 동 번호는 추정해 추가하지 않았다. 실제 앱 적용에는 검증한 원본 기하 구조를 기준으로 정제하고 모든 백분율 마커 좌표를 확인하는 작업이 필요하다.
