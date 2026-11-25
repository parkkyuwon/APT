# 1.1.5+22 검증과 배포 진행

**후속 변경:** 사용자가 주차장 도식화 적용을 명시했다. 원본 B1/B2 파일은 보존하고 앱 회원/관리자 지도는 새 `B1-simplified.png`, `B2-simplified.png`를 사용한다. 이 문서의 최초 AAB `2026-11-16-v1.1.5-22/`에는 도식화가 없다. 도식화 포함 후속 후보는 별도 `2026-11-16-v1.1.5-22-maps/`를 기준으로 확인한다. 후속 근거는 `SIMPLIFIED_PARKING_MAPS_2026-11-16.md`를 따른다.

**현재 업로드 대상 후보:** `AppBundle/releases/2026-11-16-v1.1.5-22-maps/apt-ev-service-v1.1.5-22-maps.aab`. 도식화 포함 ZIP 자산·서명·권한·16KB 검증 통과, SHA256 `00a1e14f29afae44639072522422d098b8485463fda7f3931acc9b1544bc43c8`. 최초 22 AAB가 아닌 이 새 후보를 사용하되, 업로드 전 Console 최고 코드 확인 조건은 유지한다.

## 작업 재개 시 적용할 주의사항

사용자가 아래 주의사항 적용을 명시했다. 다른 대화나 Chrome에서 이어갈 때도 먼저 이 기록을 읽는다.

- 서버·DB 배포는 완료됐다. 기존 배포를 확인하고 동일한 서버 배포나 마이그레이션을 반복하지 않는다.
- Play Console 업로드·심사 제출·게시는 아직 수행하지 않았다. 현재 출시 상태와 최고 versionCode를 확인한 뒤 진행하며, 22가 이미 사용됐다면 기존 AAB를 그대로 업로드하지 않는다.
- 업로드 직전에 대상 패키지 `apt.ev.service`, AAB 버전과 SHA256을 이 기록의 최종 검증 결과와 대조한다. 연결된 PC의 실제 파일 접근 가능 여부도 확인한다.
- 실기기 Google 로그인·카메라/OCR·NFC·BLE·푸시·통화는 미검증이다. 자동 테스트 통과나 빌드 성공을 실기기 동작 검증으로 표현하지 않는다.
- 사용자 후속 지시로 도식화를 앱에 적용한다. 원본 B1/B2 파일과 기존 백분율 마커 좌표는 보존하고 표시 자산만 새 파일로 전환한다. 정밀 도면·실제 마커별 위치 정확도는 미검증임을 명시한다.
- 기존 미커밋 변경, 회원·주차 데이터, 인증 필수 ON, TURN 미설정 및 iOS 보류 상태를 보존한다. 배포 검증을 위해 운영 회원·주차 데이터를 생성·수정·삭제하지 않는다.
- 브라우저 연결 또는 URL 정책 검사로 제어가 차단되면 우회하지 않는다. 업로드·심사 제출·실제 게시를 각각 관찰한 증거에 따라 구분해 기록한다.

사용자는 완료한 작업을 검증한 뒤 Play Console 배포를 요청했다. 후보 버전은 `1.1.5+22`, 패키지는 `apt.ev.service`다. Console 최고 versionCode를 아직 확인하지 못했으므로 22의 원격 사용 여부는 미확인이다. 주차장 도식화는 시안으로 유지하고 기존 B1/B2 앱 이미지는 보존했다.

## 최신 검증

- `flutter analyze --no-fatal-infos`: 종료 0, No issues found, 20.2초.
- `flutter test --no-pub --concurrency=2`: 종료 0, 전체 **230개 통과**, 1분54초. 이전 227개와 추가 집중 회귀 기록을 최신 전체 실행으로 갱신한다.
- 별도 서버 `npm test`: **150개 통과**, 실패 0.
- 로그는 `AppBundle/releases/2026-11-16-v1.1.5-22/`에 보관한다. 실제 번들 검증 결과는 아래에 추가한다.
- adb 연결 기기는 0대였고 BlueStacks 플레이어도 실행 중이 아니었다. 실기기 Google 로그인·카메라/OCR·NFC RF·BLE·푸시·2대 음성통화는 검증하지 않았다. 자동 테스트와 빌드만으로 해당 하드웨어 동작을 보장하지 않는다.

## 서버·DB 운영 반영 완료

`state-concurrency.sql` 다음 `vehicle-verification-policy.sql`을 한 트랜잭션에서 적용했다. 기존 회원 전체 행과 주차 상태 전체 행을 비교하여 새 기본 false 면제 컬럼과 초기 `stateVersion:0` 외 변경이 없음을 확인했다. 15개 테이블 건수도 유지됐다(회원 56명, 주차 상태 1개, 주차 상세 4개, 주차 이력 72개, 세션 7개). 테스트용 운영 데이터나 계정 삭제는 수행하지 않았다.

운영 `https://apt-ev-charging.vercel.app`를 READY 배포 `dpl_3A5VznwniVJYhiFVu1p3QiBGph2E`로 전환했다. 공개 조회·정책 ON·로그인 가능 설정·공개 개인정보 비노출과 보호 API 제한·개인정보/계정 삭제 안내 등 12개 직접 HTTP 검사가 통과했다. 이전 `dpl_FLZLaE3zbhejK4NpU4gL1PXZ9MhF`를 복구 참조로 보존했다. 정책을 OFF로 바꾸거나 기존 회원을 면제하지 않았으며 TURN도 미설정 상태를 유지한다.

상세: `D:/vsCodeProg/APT-Prj/docs/backend-cutover-2026-11-16.md`. 구형 관리자 앱의 버전 없는 상태 저장은 409로 거절될 수 있으므로 웹 새로고침 또는 새 앱으로 갱신해야 한다.

## Play Console 접근 차단

브라우저 목록이 비어 있고 `The browser access host is unavailable`로 반환됐다. Chrome을 연 뒤에도 Windows 현재 URL을 확실히 판별할 수 없다는 정책 검사로 Computer Use가 중단됐다. 사용자가 Chrome 연결을 알린 뒤 다시 확인했으나 같은 차단이 반복됐다. 우회 입력이나 다른 기술로 브라우저 제어를 강행하지 않았다.

따라서 Console 앱/현재 출시/최고 버전 코드 조회, AAB 업로드, 심사 제출, 관리형 게시 최종 실행은 수행하지 않았다. Chrome 로그인 상태와 도구가 인식하는 브라우저 연결은 구분해야 한다. 연결이 복구되면 새 번들의 최고 코드 중복 확인부터 재개한다.

릴리스 노트 초안: `docs/verification/PLAY_RELEASE_NOTES_1.1.5_2026-11-16.txt`. APK/AAB 업로드나 Google 심사 요청 완료를 주장하지 않는다.

## 최종 서명 번들 검증 완료

release 빌드 종료 0, Gradle 613.3초로 완료했다. 원본 업로드 산출물은 `AppBundle/releases/2026-11-16-v1.1.5-22/apt-ev-service-v1.1.5-22.aab`이며 크기는 84,934,215바이트다.

SHA256: `aa32096ce37a6f11970e99d9f9fb7d88a778db29327f8fed64df5c8af0d15992`.

실제 manifest의 패키지 `apt.ev.service`, 버전 `1.1.5+22`, minSdk24, targetSdk36을 확인했다. NFC와 마이크 hardware는 모두 선택 사항이며 광범위 사진/저장소·전화·연락처 권한은 없다. bundletool 유효성 및 jarsigner 서명 검증을 통과했다. 실제 이전 21 AAB와 업로드 인증서가 동일하다(SHA256 `95:BE:C2:53:15:AD:1C:A4:7D:79:03:9E:33:E7:CB:1C:59:E6:96:F0:95:BD:AE:3B:70:9C:51:BE:D3:F2:6F:A8`). 64비트 네이티브 라이브러리 10개의 ELF LOAD 16KB 이상 정렬과 `PAGE_ALIGNMENT_16K`도 확인했다.

`release-metadata.json`, manifest, bundletool/jarsigner 검증 로그, R8 mapping과 ABI별 Dart symbols 3개를 릴리스 폴더에 보관했다. 주 에이전트가 최종 AAB SHA256을 별도로 재확인했다. 후보 코드는 원격 최고 코드 확인 후 사용하며, 이 검증 결과는 Play 업로드·검토 제출·실제 게시 또는 실기기 실행 성공을 의미하지 않는다.
