# APT 안정화 PM 및 독립 QC 검토

검토일: 2026-10-09. PM: `/root/pm_review`, 명시적 사용자 지정 모델 `gpt-6.1-sol`.

## 승인 범위와 구현 원칙

사용자가 승인한 여섯 항목은 로그아웃 상태/캐시/폴링 정리, API 실패 시 쿠키 정리, 회원/게스트 요청 경합 차단, SDK 복구 및 의미 있는 테스트, iOS BLE 및 실행 중 링크, 문서/미사용 의존성 정리다. [설계](../superpowers/specs/2026-10-09-app-stability-design.md) 및 [로드맵](../superpowers/plans/2026-10-09-app-stability.md)을 승인한다.

영향 하위 그래프는 `app → auth/parking/links`, `auth/parking → services → http → storage/backend`, `beacon → platform` 및 `build`다. 초기 Mermaid/JSON은 변경 전 동작만 표현해 실제 변경 소스로 검토했으며 최종 Mermaid/JSON이 새 세대·Navigator·콜드/웜 링크·플랫폼 권한 흐름으로 갱신됐다. 구조는 16개 구성요소와 37개 관계다. 백엔드 변경은 범위에 없다.

적용 스킬은 설치된 Blue Ocean과 project-diagram이다. Flutter/Dart 명명·Provider·Dio·MaterialPageRoute와 기존 위젯을 유지한다. C++/C# 이름 접두사·Mocha·솔루션 재배치는 적용하지 않는다. GUI DR는 시각 배치가 바뀌지 않는 행동/권한 정정이라는 이유로 면제한다. 실제 OS 링크·BLE 동작 검증은 별도다.

## 모델과 검증 소유권

PM은 사용자 요청에 따라 `gpt-6.1-sol`로 새로 생성됐다. root 및 기존 작업자는 지정 전의 상속 모델을 유지한다. 실행 중 모델 변경을 주장하지 않는다. 이후 필요한 소규모 독립 작업자는 Blue Ocean의 `gpt-6-luna` 기본값을 사용한다. 현재 추가 작업자는 생성하지 않는다.

root는 구현 및 직렬 Flutter 검증 담당, PM은 앱 소스를 수정하지 않는 독립 계약/QC 검토 담당이다. 이 문서와 로드맵 역할 배정은 PM이 소유하며 아키텍처 색인/분석 문서는 root가 소유한다.

## 중간 검토 및 결함 정정 기록

| 항목 | 근거 | 판단 및 정정 요구 | 상태 |
| --- | --- | --- | --- |
| 승인 범위/재사용 | 설계, 로드맵, 기존 아키텍처 색인 및 실제 Provider/service | Flutter 구조 유지, 새 앱 구조/라우터/서버 계약 변경 없음 | 로드맵 승인 |
| Provider 응답 경합 | 세대 번호를 확인하는 조회·저장·실패 롤백·finally | 이전 세대의 UI/주차 캐시/연결 상태 변경 차단, 인증 listener 연결 | 소스 및 전체 83개 테스트 근거 확인 |
| HTTP 세션 경합 | CookieManager 앞뒤 SessionInterceptor, secure jar 연산 순서화 | 지연 Set-Cookie/ETag 및 이전 GET 재시도 차단; 중간 async cookie write 경합 RED→GREEN | 소스 및 전체 83개 테스트 근거 확인 |
| 로컬 로그아웃 즉시성 | AuthProvider.logout 시작 시 session/stage 정리, 세대 검사 | 늦은 복원/로그인/finally 차단, MaterialApp identity/stage key로 push된 회원 route 제거 | 소스 및 전체 83개 테스트 근거 확인 |
| 세션 정보 캐시 경합 | SessionInfoCache save/load/clear 순서화 | 지연 secure write/delete 경합 RED 2개 이후 GREEN | 소스 및 전체 83개 테스트 근거 확인 |
| 링크 등록의 인증 연속성 | refresh/다른 슬롯 clear 뒤 auth stage/email 재검사 | 조회 오류가 있으면 자동 POST 중단, cold/warm widget 회귀 | 소스 및 전체 83개 테스트 근거 확인 |
| 권한 및 링크 | DeepLink observer/listener, SDK별 Android BLE/native channel, iOS plist/Podfile | helper·warm/cold 전달 테스트 확인, 실제 native 실행은 별도 | 자동 검증 통과, 실기기/macOS 한계 |
| 주차 캐시 소유자 원자성 | 지연 SharedPreferences 저장 중 이전 owner와 새 payload 혼합 노출 RED | owner/state 단일 envelope 저장, legacy 회원 복원 거절, 지연 플랫폼 쓰기 회귀 GREEN | 최종 소스·전체 84개 테스트 근거 확인 |
| 문서 일관성 | Mermaid/JSON 및 PROJECT_ANALYSIS 현재 흐름으로 갱신 | 최종 85개 테스트·분석·검증용 APK와 envelope/초기 auth 루트 문구 반영 | 최종 통합 확인 |
| 콜드 링크 초기 route | 플랫폼 기본 route가 슬롯 URL일 때 named initial route 오류 RED | 명시적 initial MaterialPageRoute와 routes `/`로 AuthStage 루트 진입, 링크는 DeepLink에 유지 | 최종 소스·전체 85개 테스트 근거 확인 |

## 통합 단계 PM 결정과 새 근거

root가 보고한 새 검증 근거는 core/helper/link 21개 GREEN, 최신 조회 403 뒤에도 자동 등록 POST를 보내던 홈 widget RED 후 수정 GREEN 1개, secure cache 경합 RED 2개 후 직렬화 구현이다. 이 보고는 부분 검증이며 전체 검증 수락을 대신하지 않는다. PM은 SessionInfoCache 및 SecureCookieJar의 순서화 소스를 확인했다. secure cache GREEN은 별도 재검증을 기다린다.

Android BLE 위치 계약 정정은 승인된 플랫폼 BLE 안정화 범위 안이다. `console_beacon_list.dart`의 `_estimate`는 등록 비콘 RSSI로 현재 물리 위치를 추정하므로 기존 `neverForLocation`과 `ACCESS_FINE_LOCATION`의 API 30 상한은 실제 기능과 모순된다. [Android 공식 Bluetooth 권한 문서](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)는 위치 계산 시 fine location 선언을 요구하고 `neverForLocation`이 일부 비콘을 필터링한다고 명시한다. PM은 이 선언 제거, fine/coarse의 OS 계약 정정 및 SDK별 runtime 확인을 승인한다. 기존 UI는 유지하며 실제 권한 요청과 iBeacon 검색은 기기에서 확인해야 한다.

로그아웃 후 push된 관리자 route가 남는 경로는 상태 수명 결함의 직접 범위다. auth identity/stage에 따라 MaterialApp/Navigator 수명을 재설정하는 최소 정정과 widget 회귀 검증을 승인한다.

HTTP 추가 경합 검토: 응답이 첫 `_SessionInterceptor`를 통과한 뒤 async CookieManager가 secure write를 기다리는 동안 세션이 바뀌면 뒤의 ETag 처리도 다시 세대를 확인해야 한다. root에 세대 검사 재배치 또는 ETag 단계 검사를 요구했다. secure storage 지연과 ETag를 함께 포함한 회귀 테스트가 필요하다.

PM은 최종 통합 소스를 직접 읽고 소유자 경합과 콜드 초기 route 정정 이후 `D:/Temp/apt-app-tests-final.log`의 `+85: All tests passed!`를 직접 확인했다. 명령은 `flutter test --no-pub --concurrency=2`다. 마지막 `flutter analyze --no-pub --no-fatal-infos`는 root가 전달한 종료 코드 0과 `D:/Temp/apt-app-analyze-final.log`의 `No issues found!`를 직접 확인했다. Android debug APK의 최종 재빌드는 종료 코드 0, 44.7초였으며 `D:/Temp/apt-app-build-final.log`의 성공 메시지와 `build/app/outputs/flutter-apk/app-debug.apk` 184,468,238바이트 존재를 확인했다. 이 APK는 테스트 자리표시자 dart-define을 사용한 검증용 산출물이다. `git diff --check`도 종료 코드 0이며 줄 끝 변환 경고만 있었다. JSON 구성요소 16개, 관계 37개 및 매핑된 파일 누락 0개를 독립 검사했다.

## 최종 수락

PM은 승인된 여섯 항목의 모바일 안정화 구현을 최종 수락한다. 최종 소스 검토의 미해결 결함은 없고 85개 테스트·분석·Android debug APK 재빌드 및 문서/구조도 반영 근거를 확인했다. 새 기능이나 서버 계약 변경, 자동 커밋·게시·스토어 배포는 수행하지 않았다.

실기기 BLE/Google 로그인/OS 링크 및 macOS iOS 빌드는 실행 환경이 없어 미검증 범위로 유지한다. iOS Universal Links의 Associated Domains 및 서버 association 배포도 별도 조건이다. 이 한계는 구현 검토의 PM 예외로 인정하며 실제 장치 동작·운영 서버 통합·스토어 배포 준비 완료를 의미하지 않는다. 검증용 APK의 테스트 자리표시자 환경은 운영 배포용이 아니다.
