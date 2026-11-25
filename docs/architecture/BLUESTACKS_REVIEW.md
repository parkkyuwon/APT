# BlueStacks 실행 확인 PM/QC

검토일: 2026-10-09. PM `gpt-6.1-sol`, Blue Ocean 적용. root가 사용자 승인된 설치·ADB 실행·스크린샷·로그 수집을 수행하며 PM은 읽기 전용 독립 QC와 이 문서를 담당한다.

## 범위와 수락 기준

사용자가 설치된 BlueStacks에서 실행 확인을 요청했고 직접 ADB를 활성화했다. root가 `127.0.0.1:5555`에 연결하고 Android 9/API 28, x86_64 환경임을 확인했다. 이 환경에서 targetSdk36/versionCode15 APK의 하위 Android 호환 실행을 확인한다. Android 16/API36 및 16KB 실제 장치 검증을 대신하지 않는다.

1. 설치된 package/target/version을 최신 debug APK의 `apt.ev.service`/36/15와 대조하고 앱 시작·로그인 루트 진입 및 fatal crash 부재를 확인한다.
2. 게스트 모드에서 `/api/public-dashboard` 읽기와 목록·지도·안내 화면 이동·뒤로가기의 실제 화면 상태를 확인한다. 서버 성공 응답/네트워크 오류는 서로 구분한다.
3. 로그인되지 않은 상태의 cold/warm 슬롯 링크는 로그인/게스트 정책을 유지하고 회원 주차 POST를 수행하지 않는다. link 보관은 코드/단위 검증과 실제 표시·오류 근거를 구분한다.
4. 사용자 자격증명 입력·자동 로그인·관리자 쓰기·실제 주차 변경은 수행하지 않는다. 앱의 기존 운영 서버 기본값을 읽기 검증에 사용하는 사실과 HTTP 요청 범위를 기록한다.
5. 스크린샷·선택된 logcat·설치/기동 결과를 root의 실행 보고와 대조한다. Android16/16KB·BLE·카메라·Google 로그인·스토어 게시 정상 여부를 이 범위의 성공으로 단정하지 않는다.

GUI 레이아웃 변경은 없으므로 이미지 기반 DR는 해당하지 않는다. 기존 컴퓨터 제어 native 경로가 제공되지 않아 사용자 활성화 ADB 목적별 CLI로 확인한 예외를 기록한다. PM은 ADB 조작을 중복 실행하지 않는다.

## QC 상태

PM은 [실행 보고](../verification/BLUESTACKS_RUN.md), 보관된 API 로그와 7개 스크린샷을 직접 확인했다. 로그인·게스트 목록·사용중 필터의 빈 결과·B1/B2 지도·이용안내·로그인 복귀 화면이 보고와 일치한다. 화면 크기/색/탭/지도 마커는 실제 캡처이며 신규 시각 변경을 제안하지 않는다.

| 확인 항목 | 판단과 근거 |
| --- | --- |
| 설치·기동·버전 | root의 ADB install Success, start Status ok 및 dumpsys package의 apt.ev.service/code15/min24/target36 근거 확인. PM이 APK SHA256을 다시 계산해 실행 보고의 값과 대조 |
| 공개 조회 | `bluestacks/api.log`에서 PID 3959 GET `/api/auth` 및 `/api/public-dashboard`, HTTP200 직접 확인 |
| 화면 이동 | 7개 스크린샷을 직접 열어 로그인·목록·빈 필터·B1/B2 지도·안내·로그인 복귀 확인 |
| 뒤로가기·재실행 | root 관찰에서 back 뒤 focus 해제, 명시적 재실행 성공. 전체 back stack 자동 검증을 의미하지 않음 |
| 서버 변경 요청 | 보관한 API 로그의 POST/PUT/PATCH/DELETE 0개 직접 확인. root는 주차·사진·회원 변경을 수행하지 않았다고 보고 |
| 충돌/오류 | root가 관찰 구간 PID 3959 로그의 E/flutter/FATAL EXCEPTION/앱 ANR 0개를 보고. 보관 API 로그는 HTTP 필터본이므로 PM이 그 파일만으로 전체 fatal 부재를 재증명했다고 주장하지 않음 |
| BlueStacks 재시작 | 5.22.168.1001→5.22.280.1025 업데이트와 플레이어 재시작 때 ADB offline, 재연결 뒤 지도 재검증. 이를 앱 crash로 분류하지 않음 |
| 슬롯 링크 | 자동 승인 검토가 ADB VIEW intent 명령을 `blocked by policy`로 거절해 cold/warm 링크 runtime 검증 미수행. 우회하지 않았으며 PM이 검증 예외로 기록 |

지도 첫 진입/층 전환 때 일시적으로 이미지가 비었다가 표시되는 관찰은 알려진 확인 한계로 기록한다. 시간 계측이 없어 성능 수치나 성능 결함 판정은 하지 않는다. 초기 Google 계정 선택 화면은 관찰됐지만 계정을 선택하거나 인증을 완료하지 않아 로그인 검증 통과로 기록하지 않는다.

## 최종 수락

PM은 **BlueStacks Android9/API28의 설치·기동 및 게스트 읽기/화면 이동 확인 결과**를 수락한다. 해당 관찰 범위의 미해결 앱 실행 결함은 없다. 실행 APK SHA256은 `8148bd7d4c70aa09b662f2b30df573d6b1423f60beb7ce90e36f5d6af27b19cd`다. PM은 source/ADB를 변경하거나 조작하지 않았고 문서/증거 변경의 `git diff --check` 종료 코드0을 확인했다.

cold/warm 슬롯 링크는 자동 승인 정책 거절로 미수행이며 이미 존재하는 단위/widget 테스트 성공을 이 OS runtime 검사로 대체하지 않는다. Android16/API36·16KB 장치·release AAB 실행·Google 로그인 완료·카메라/사진·실제 BLE·회원/관리자 쓰기·프로덕션 게시는 계속 미검증이다. 이번 확인은 앱 target36과 실행 OS API28을 분리해 보고한다.
