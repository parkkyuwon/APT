# BlueStacks 실행 확인

검증일: 2026-10-09. Blue Ocean PM은 사용자 지정 GPT-6.1-sol이며 root가 ADB 설치·실행·화면 관찰을 담당했다. Windows Computer Use 도구는 native pipe 연결 오류로 사용할 수 없어 기존 Android SDK ADB를 사용했다. ADB 설정은 사용자가 직접 활성화했다.

## 환경과 산출물

- BlueStacks Pie64, Android 9/API 28, x86_64, 화면 1080×1920.
- 테스트 중 BlueStacks 실행 파일 버전이 5.22.168.1001에서 5.22.280.1025로 바뀌고 플레이어가 재시작돼 ADB가 끊겼다. 업데이트 후 재연결해 지도를 포함한 테스트를 이어갔다. 앱 충돌로 단정하지 않는다.
- 설치한 APK: `build/app/outputs/flutter-apk/app-debug.apk`, SHA256 `8148bd7d4c70aa09b662f2b30df573d6b1423f60beb7ce90e36f5d6af27b19cd`.
- 설치 패키지 `apt.ev.service`, versionName 1.1.0, versionCode 15, minSdk 24, targetSdk 36을 기기 `dumpsys package`로 확인했다.
- 운영 환경 기본값을 사용하는 debug APK다. release AAB 런타임 검증이나 Android 16 동작 검증으로 대체할 수 없다.

## 결과

| 항목 | 결과 | 근거 |
| --- | --- | --- |
| APK 설치·앱 실행·로그인 화면 | 통과 | ADB install Success, am start Status ok, [화면](bluestacks/login.png) |
| 비회원 진입·공개 목록 | 통과 | `/api/auth`, `/api/public-dashboard` HTTP 200, [목록](bluestacks/guest-list.png) |
| 사용 중 필터 | 통과 | 선택된 필터 및 해당 슬롯 없음 안내 [화면](bluestacks/filter.png); 이 화면은 업데이트 전 캡처 |
| B1·B2 지도 표시·층 전환 | 통과 | [B1](bluestacks/map-b1.png), [B2](bluestacks/map-b2.png), 업데이트 후 재검증 |
| 이용안내 탭 | 통과 | [화면](bluestacks/guide.png) |
| 게스트에서 로그인 화면 복귀 | 통과 | [화면](bluestacks/return-login.png) |
| Android 뒤로가기 및 재진입 | 확인 | 로그인 화면에서 back 후 전면 앱 focus가 해제됐고, 명시적 앱 재실행 Status ok |
| 슬롯 링크 실행 | 미수행 | ADB VIEW intent 실행 명령이 자동 승인 검토에서 `blocked by policy`로 거절됨. 우회 재시도 없음 |

업데이트 후 앱 PID 3959의 [필터링한 실행 로그](bluestacks/api.log)에서 GET 요청과 HTTP 200을 확인했다. 관찰 구간의 POST/PUT/PATCH/DELETE 요청은 0개, `E/flutter`·`FATAL EXCEPTION`·앱 ANR 기록도 0개다. 이는 해당 관찰 구간의 결과이며 모든 기능에 대한 무결점 보장이 아니다. 주차 등록·사진 전송·회원 변경은 수행하지 않았다.

지도 첫 진입/층 전환 직후 이미지가 잠시 빈 화면이었다가 표시되는 현상이 관찰됐다. 로딩 시간을 계측하지 않아 성능 수치로 보고하지 않는다. 초기 Google 계정 선택 화면도 관찰됐지만 계정 선택·인증 완료는 수행하지 않았고, 재실행 뒤 일반 로그인 화면과 게스트 흐름을 검사했다. Google 로그인 통과로 판단하지 않는다.

## 미검증 범위

Android 16/API 36의 edge-to-edge·predictive back·대화면 변경, 실제 16KB OS 실행, release AAB 설치 동작, Google 계정 로그인 완료, 회원/관리자 쓰기 기능, 카메라·사진 업로드·BLE 실장치, OS에 의한 링크 연결 및 cold/warm 슬롯 처리는 별도 검증이 필요하다. APK의 대상 API 36과 BlueStacks의 실행 OS API 28은 서로 다르다.

PM 독립 검토는 [BLUESTACKS_REVIEW.md](../architecture/BLUESTACKS_REVIEW.md)에 기록한다.
