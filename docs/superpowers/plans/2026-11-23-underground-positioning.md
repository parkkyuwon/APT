# 지하 위치 추정과 집 주변 자동 안내 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 2026-11-23 사용자의 `진행` 요청으로 로컬 구현을 시작했다. 코드 구현·실기기 검증·운영 반영을 구분하며 최신 상태는 아래 실행 기록과 검증 문서를 따른다.

**Goal:** 여러 지점의 BLE 측정 기록으로 비콘 설치 위치와 지하의 내 위치를 추정하고, 등록한 집 주변에서 실외 위치 품질이 나빠지면 휴대폰 알림을 통해 실내 지도로 안내한다.

**Architecture:** 기존 Flutter/Provider/Navigator와 BLE 탐색을 재사용한다. 측정 지점, 비콘의 설치/추정 위치, 실시간 내 위치를 분리한다. 전경의 정밀 측정·추정과 OS 네이티브의 영역 감시·알림 처리를 분리하고, 지도·측정 기록을 기기에 저장해 지하에서도 서버 연결 없이 추정한다.

**Tech Stack:** Flutter/Dart, 기존 flutter_blue_plus·permission_handler·flutter_local_notifications·flutter_secure_storage, 신규 로컬 SQLite 저장소(sqflite), Android Kotlin Location/Geofencing/BLE API, iOS Swift Core Location, 실외 지도용 google_maps_flutter. 신규 패키지의 실제 버전은 현재 Flutter 및 Android/iOS 최소 지원 버전과 맞춰 의존성 도입 작업에서 고정한다.

작성일: 2026-11-23 / 기준 저장소: APT-APP / 플랫폼 우선순위: Android 먼저, iOS 별도 실기기 검증.

## 실행 중 확정된 추가 요구와 반영 상태

- 비콘 관련 등록·수정·공용 사용 설정은 관리자 전용이다. 승인된 일반 회원은 관리자가 사용 설정한 공용 등록 정보를 내려받아 이용한다.
- 추가 지시한 B1/B2 분리 저장은 측정 당시 선택한 층의 명시적 저장·층별 SQL 조회·관리자 기록 필터·서버 배포의 층 보존으로 반영했다. SQLite v3는 기존 v1/v2 자료의 층과 관측·공유 캐시를 보존한다. 필터에서 B1만 조회해도 공용 배포에서 B2 자료를 누락시키지 않는다.
- 서버는 기존 문서에서 확인한 `D:/vsCodeProg/APT-Prj`의 Vercel/Neon 구현을 확장한다. 앱 실행/복귀 때 `/api/indoor-positioning`의 최신 revision을 확인하고 계정·API 환경·역할별 로컬 캐시를 교체한다. 개인 집 반경 위경도는 공유 자료에 포함하지 않는다.
- 서버는 GET의 승인 회원 확인, PUT의 관리자·Origin 확인, expectedRevision 비교, 허용 필드만 배포를 수행한다. 비활성화된 공용 자료는 일반 회원에게 빈 자료로 내려보낸다. 오프라인 기기의 사용 중지는 다음 갱신 시 반영된다.
- 계산 방식은 별도 학습 모델 파일을 만들지 않고 사용 가능한 원본 지문에서 즉시 계산한다. 제외/새 배포 반영을 단순하게 유지하는 구현 조정이다.
- 기존 도식화의 물리 보정이 없어 비콘의 정확한 설치 좌표 역추정은 완료로 처리하지 않는다. 이번 구현은 신호가 강한 후보 구역을 제공하며 자동 설치 좌표 확정/서버 쓰기를 하지 않는다.

| 단계 | 로컬 구현 상태 | 남은 검증/작업 |
|---|---|---|
| A | SDK 호환 의존성 고정, 플랫폼 브리지·권한 코드 | Maps 키/서비스 설정, OS별 실기기 가능 범위 실측 |
| B | 불변 모델, SQLite v3 층별 저장·조회·마이그레이션·공유 캐시, BLE 수집/소유권/만료 | 실제 광고 수신·기종별 권한 확인 |
| C | 관리자 측정 위치 선택, 15초 기록, 반복 저장, 기록 제외·서버 자료 불러오기 | 현장 수집, 기록별 좌표 수정/삭제 UI는 후속 보완 |
| D | 가중 지문 비교, 층 모호성 처리, 공유 자료 기반 이용자 위치 화면 | 지하 현장 정확도·기종 편향 평가 |
| E | 미확정 비콘 신호 후보 구역 | 물리 지도 보정, 미터 기반 강건 역추정, 별도 현장 확정 UI |
| F | 개인 집 중심/반경·보안 저장, 공용 사용 설정 검사, 순수 판정 테스트 | 지도 키를 사용하는 지도 선택 실기기 확인 |
| G | Android 영역 감시·20분 관찰 서비스·권한/재부팅/계정별 알림 | 제조사 절전·강제 중지·실제 진입/지하 전환 검증 |
| H | iOS Core Location 코드·권한 설정·XCTest 등록 | macOS/Xcode 빌드·iPhone 실기기 검증 |
| I | Firebase 독립 네이티브 알림, 계정/설정 버전 재확인 후 지도 진입 | 잠금/콜드/웜 실기기 알림 검증; 기존 출차 알림 초기화는 변경하지 않음 |
| J | 앱/서버 자동 테스트와 구조도·구현 기록 | 실제 지하 측정, 오차/성공률/배터리 검증 |

아래 초기 체크박스는 원래 세부 계획이다. 위 표는 일부 작업이 구현 조정되었거나 실기기 검증과 함께 묶인 항목을 구분하기 위한 최신 기록이며, 체크되지 않은 모든 항목이 미작성 코드라는 의미는 아니다. 운영 SQL 적용과 배포는 아직 수행하지 않았다.

## 1. 요구사항과 제공 범위

| 번호 | 요청 | 계획한 동작 | 확인 기준 |
|---|---|---|---|
| 1 | 여러 위치를 돌아다니며 반복 등록 | 지도에서 측정 당시 내 위치를 선택하고 주변 비콘 전체의 시간별 신호를 누적 | 같은 지점 재측정도 독립 기록으로 남고 과거 기록을 덮어쓰지 않음 |
| 2 | 센서 위치 추정 | 고정된 비콘별로 여러 알려진 측정 지점에서 수신한 신호를 역추정 | 추정 좌표·품질·근거 측정 수 표시, 수동 확정 좌표와 구분 |
| 3 | 내 위치 추정 | 저장한 신호 지도와 현재 신호를 비교하는 핑거프린팅 우선, 거리 기반 추정은 보조 | 미등록 지점 현장 평가, 오래된 신호만 있으면 현위치 표시 해제 |
| 4 | 지하 공간에서 사용 | B1/B2 도면·모델·측정 기록을 로컬에 유지 | 비행기 모드에서 Bluetooth만 켠 상태로 전경 추정 가능 |
| 5 | 집 주변 반경 등록 | 실외 지도에서 중심점·미터 단위 반경 지정, 대상 주차장과 연결 | 저장·수정·삭제·감시 켜기/끄기, 앱 재시작 후 복원 |
| 6 | 반경 내부에서 GPS 끊김 시 동작 | 최근 반경 내부 진입 근거와 관찰 가능한 실외 위치 품질 저하를 조합 | 반경 밖·권한 해제·단순 앱 중단을 지하 진입으로 오인하지 않음 |
| 7 | 조건 충족 시 팝업·앱 실행 | 조건 감지 → 로컬 알림 → 알림 선택 시 앱 실내 지도 진입. 앱 전경에서는 실내 모드 전환 안내 | 앱 종료/백그라운드/전경별 검증, OS 허용 범위와 미지원 상태 명시 |

**7번의 플랫폼 제약:** 일반 앱이 다른 앱 위나 잠금 화면에서 지도 화면을 무조건 자동 실행하는 것은 보장할 수 없다. 기본 제공안은 알림 배너/잠금 화면 알림과 사용자의 선택에 의한 앱 실행이다. 배너 노출도 알림 권한·집중 모드·사용자 채널 설정에 영향을 받는다. 사용자 조작 없는 화면 실행이 필수라면 본 계획의 기본안으로 충족되지 않는 요구사항으로 남겨야 한다. 전체 화면 알림·다른 앱 위 표시 권한을 우회 수단으로 추가하지 않는다.

## 2. 현재 구현에서 확인한 사실

- `ConsoleBeaconScan`은 iBeacon의 UUID/Major/Minor/Measured Power와 RSSI를 읽으며, `ib:UUID:major:minor` 식별자를 이미 사용한다.
- `BeaconPositionEditor`는 측정 당시 휴대폰 위치가 아니라 비콘 자체의 단일 설치 좌표를 저장한다. 여러 측정 위치를 이 필드에 넣으면 같은 비콘 좌표를 덮어쓴다.
- `AppState.beaconPositions`와 `AppStateProvider.upsertBeaconPosition`은 기존 서버 상태 계약이다. 서버 기준 저장과 낙관적 반영/실패 롤백을 보존한다.
- `ConsoleBeaconList`의 `_LivePositionView`는 등록된 비콘 좌표의 RSSI 가중평균이다. 핑거프린팅·비콘 위치 역추정은 없다. 현재 샘플 정리는 새 수신 때 수행되므로 수신이 끊긴 이후의 만료 판단도 추정 시점에 보완해야 한다.
- 지도 좌표는 0~100% 표현과 0~1 호환 처리가 공존한다. 신규 데이터는 명시적인 0~100% 형식으로 저장하고, 기존 데이터 호환 변환은 경계에서 수행한다. 수치만 보고 새 좌표의 단위를 추측하지 않는다.
- B1/B2 도식화 이미지는 물리적인 축척·기하 정확도가 검증되지 않았다. 화면 좌표를 그대로 미터 거리로 사용하지 않는다.
- 현재 실외 지도 SDK·집 주변 geofence·실외 위치 관찰 서비스는 없다. Android 위치 권한은 기존 BLE 용도의 사용 중 권한이며, iOS BLE 권한과 Core Location 권한은 별도다.
- 기존 `PushNotifications`는 Firebase 설정을 조건으로 초기화하고 정수 출차 요청 ID payload를 처리한다. 지하 안내 로컬 알림이 Firebase나 네트워크에 의존하지 않도록 공통 라우팅을 분리해야 한다.
- 구조 색인의 영향 범위: `beacon`, `platform`, `member-ui`, `app`, `links`, `storage`, `push`, `build`; 기존 비콘 확정 좌표 반영만 `parking`과 연결한다.
- 작업 시작 시 기존 수정·미추적 파일이 다수 있었다. 이 계획 파일 외의 기존 변경을 되돌리거나 일괄 커밋하지 않는다.

## 3. 선택한 방식과 대안

| 방식 | 장점 | 한계 | 적용 |
|---|---|---|---|
| 신호 지도/핑거프린팅 | 비콘 위치를 몰라도 알려진 측정 지점으로 내 위치 추정 가능, 반복 등록에 적합 | 현장 수집과 재학습 필요, 차량/기종 변화 영향 | 1차 위치 추정 |
| RSSI 거리 기반 삼변측량·최적화 | 비콘 위치와 측정점의 물리 좌표를 활용 | 반사·차폐·출력 보정 오차에 민감, 축척 필요 | 비콘 위치 추정 및 보조 추정 |
| BLE+보행 센서+통로 지도 융합 | 이동 중 연속성 개선 가능 | 자세·자기장·누적 오차와 추가 검증 부담 | 핵심 기능 검증 후 후속 단계 |

각도 정보가 없으므로 엄밀한 의미의 삼각측량을 구현하는 것이 아니다. RSSI만으로 정밀 거리를 보장하지 않는다. iBeacon의 Tx 표시값은 Measured Power로 취급하며 원시 무선 송신 출력으로 해석하지 않는다.

## 4. 사용자 흐름

### 4.1 관리자 측정

1. 관리자 비콘 메뉴 → `측정 지점 등록` → B1/B2와 도면상 현재 위치 선택.
2. 기둥/주차면 이름을 선택적으로 적고 정지 상태에서 기본 15초 측정. 시간은 10~30초 조정 가능.
3. 주변 비콘 전체의 새 광고 패킷을 기록. 측정 시간은 수신 개수를 보장하지 않으므로 실제 패킷 수·흔들림을 표시.
4. 품질 확인 후 로컬 저장. 취소한 기록은 학습에 사용하지 않음. 같은 지점 재측정도 별도 세션.
5. 측정점은 공간적으로 분산해 수집. 초기 현장 시험은 층별 10~20개 지점, 주요 통로 약 5m 간격을 출발값으로 사용하고 사각지대에서 보강한다. 보장된 최소 개수나 정확도 기준이 아니다.
6. `신호 지도 만들기`로 새 모델 생성. 비콘 추정 위치는 별도 화면에서 확인하고, 관리자가 확정한 경우에만 기존 비콘 위치 저장 흐름에 반영.

관리자가 선택한 측정 위치는 정답 기준점이다. 위치를 알 수 없다면 대략적인 구역 분류까지만 제공하고 정밀 추정 학습의 정답 좌표로 사용하지 않는다. 고정 설치 비콘을 전제로 하며 차량/휴대폰처럼 이동하는 송신기는 제외한다.

### 4.2 집 주변 설정과 자동 안내

1. 더보기 → `지하 위치 안내` → 실외 지도에서 집/단지 중심점 선택.
2. 원형 반경 기본 200m, 설정 범위 100~1000m. 원과 실제 반경 수치를 미리 표시한다. 첫 버전은 계정당 이 기기의 집 영역 1개.
3. 대상 주차장·사용 가능한 층과 연결. 정밀 위치·백그라운드 위치·Bluetooth·알림 권한을 기능 단계별로 요청한다.
4. 실외에서 영역 진입 근거를 확보하면 `주변 도착` 상태. 허용된 관찰 세션에서 실외 위치 품질 저하가 지속되면 `실내 위치 안내` 알림.
5. 알림의 `실내 지도 열기` 선택 → 앱 실행/복귀 → 인증 상태 확인 → 저장한 신호 지도로 추정. 모델이 없으면 자료 부족 안내와 수동 층 선택.
6. 앱이 이미 전경이면 상태 표시와 `실내 지도로 전환` 안내를 제공. 사용자가 다른 작업 중일 때 지도 화면으로 반복 강제 이동하지 않는다.
7. 종료/일시 중지/설정 삭제 시 감시·스캔·관련 알림 정리. 위치 권한 없이도 기본 주차 앱 기능은 사용 가능.

집 반경은 실외 위경도이고, B1/B2 측정점은 실내 도면 좌표다. 두 좌표계를 직접 섞지 않는다. 반경이 도면의 정확한 건물 경계를 의미하지도 않는다.

## 5. 상태 판정과 오작동 방지

초기 시험값이며 현장 기록으로 조정한다. 서비스가 실행되지 않거나 위치 관찰 권한이 없을 때 타이머 경과만으로 GPS 끊김 판정을 만들지 않는다.

| 상태 | 진입 근거 | 동작/종료 |
|---|---|---|
| `disabled` | 기능 꺼짐 또는 필수 설정 없음 | 영역 감시·관련 세션 중지 |
| `outside` | 신선하고 신뢰 가능한 외부 좌표 | geofence/비콘 영역 저전력 감시 |
| `armed` | OS 영역 내부 이벤트 또는 신뢰 가능한 내부 위치 | 방문 ID·근거 시각 보관, OS가 허용한 관찰 세션 시작 |
| `locationDegraded` | 실제 관찰 중 위치 품질 저하가 30초 지속 | 안내 조건 평가, 신호/권한 오류는 별도 상태 |
| `notified` | 유효한 내부 근거 AND 저하 판정 AND 알림 허용 | 방문별 알림 1회, 선택 시 지도 진입 |
| `indoor` | 앱 전경/허용 세션에서 유효한 BLE 추정 | 신호 부족이면 마지막 위치와 경과 시간만 표시 |
| `unavailable` | 권한 철회·위치 서비스 OFF·관찰 중단·OS 실행 제한 | 원인 표시, 이를 지하 진입으로 판정하지 않음 |

판정 규칙:

- 실외 위치의 신선도 기준은 측정 시각으로 15초, 신뢰 가능한 수평 정확도 출발값은 30m. 전송/콜백 도착 시각을 원본 측정 시각으로 바꾸지 않는다.
- 반경 내부 근거는 위치 불확실도 원이 등록 원 안에 포함되거나 OS가 내부 상태를 보고했을 때 확보한다. 불확실도 원이 경계에 걸치면 불명확 상태다.
- 새 좌표의 정확도가 50m보다 나쁜 상태가 지속되거나, 정상 위치 요청이 실제로 진행 중인데 신뢰 가능한 위치가 30초 이상 없으면 위치 품질 저하 후보. 중간에 정상 수신되면 지속 시간을 초기화한다.
- Android GNSS 위성 정보는 보조 근거이며 `onStopped()` 단독으로 신호 단절을 판단하지 않는다. iOS는 GPS만의 상실을 동일하게 판정할 수 없으므로 공통 제품 용어는 `실외 위치 품질 저하`로 한다.
- 내부 근거는 새 내부 위치로 갱신하고 마지막 근거 이후 최대 20분 유지한다. 이는 GPS가 없는 시점에도 반경 내부임을 증명하는 것이 아니라 최근 방문에 기반한 제한된 추론이다. 유효 시간 경과/설정 변경/계정 변경 시 자동 안내를 해제한다.
- 확실한 외부 좌표가 `반경+50m` 밖에 연속 2회 있고 10초 이상 떨어져 있으면 이탈 확정. 지하에서 도착한 단일 geofence EXIT나 부정확한 좌표는 바로 이탈 확정으로 쓰지 않는다.
- BLE가 미리 등록된 해당 장소의 것인지 알 수 있으면 안내 신뢰도를 높인다. 다만 수신 가능성이 보장되지 않으므로 기본 AND 조건에 숨겨 추가하지 않는다.
- 같은 방문에서는 알림을 한 번만 표시한다. 확실한 이탈 후 재진입할 때 새 방문을 만들고, 무시한 뒤 10분이 지났다는 이유만으로 재알림하지 않는다.
- 재시작 시 내부 근거가 오래됐거나 관찰 연속성을 입증할 수 없으면 저하 타이머를 복원하지 않는다. 미래 시각/시계 변경/재부팅은 안전하게 불명확 상태로 복구한다.
- 알림 선택 시에도 영역 설정 버전·계정·대상 지도 존재 여부를 재확인하고 유효하지 않으면 설정 화면으로 보낸다.

## 6. 플랫폼별 실행 범위

### Android

- 실외 영역은 Google Play services Geofencing API로 감시한다. GMS 미지원 기기는 자동 영역 감시 불가 상태와 수동 실내 모드를 제공한다.
- 백그라운드 위치 권한과 알림 권한을 따로 안내한다. Android 12+ BLE 권한과 실제 위치 추정 목적을 유지한다.
- 영역 진입 이벤트 뒤 위치 관찰용 foreground service를 시작할 수 있는지, 위치 권한과 해당 OS의 시작 예외를 네이티브에서 확인한다. 허용되면 사용자에게 보이는 서비스 알림과 함께 최대 20분의 관찰 세션을 운영한다.
- foreground service 시작이 거절되면 관찰 중이라고 표시하지 않는다. 해당 기기에서는 `주변 도착 · 감시 시작` 안내를 선택한 뒤 세션을 시작하는 보조 경로를 제공한다. 이 안내는 두 조건 충족 알림과 명확히 구분한다.
- 프로세스가 없을 때 등록 비콘을 감지하는 경로가 필요하면 필터를 적용한 BLE PendingIntent scan을 별도로 구현한다. Flutter 화면의 스캔 스트림이 앱 종료 상태에서도 유지된다고 가정하지 않는다.
- geofence 이벤트는 지연될 수 있고 데이터 연결 등에 의존한다. 진입 직후 GPS가 끊기는 경우를 항상 감지한다는 보장은 하지 않는다. 자동 감시 검증 결과를 제품 제공 범위에 반영한다.
- 앱 강제 중지, 제조사 절전, 재부팅, 권한 자동 회수, Bluetooth OFF 각각을 구분한다. 재부팅 후 영역 재등록은 OS 허용 시 수행하며 사용자 강제 중지를 우회하지 않는다.

### iOS

- Core Location의 지리 영역/등록한 iBeacon 식별자 감시를 사용한다. 지원 OS에 맞는 최신 조건 감시 API 또는 호환 region API를 네이티브 어댑터 안에 둔다.
- 영역 이벤트로 백그라운드 처리 기회를 받을 수 있지만, 무제한 타이머·고빈도 BLE ranging·자동 화면 실행을 보장하지 않는다.
- 필요한 위치 권한과 background location capability를 설정한다. 기능 켜기 동의 후에도 OS의 실제 관찰 가능 여부를 상태로 반영한다. 정지/유예된 상태에서 새 위치가 없다는 사실만으로 GPS 상실로 판정하지 않는다.
- 두 조건의 관찰이 실제로 가능할 때 로컬 알림을 표시한다. 관찰할 수 없으면 자동 안내 불가/제한 상태로 두고, 영역/비콘 도착 안내 또는 수동 진입으로 보완한다. 이를 6·7번의 완전 충족으로 보고하지 않는다.
- 정밀한 신호 수집·현재 위치 추정은 앱 전경을 기본 제공 범위로 한다. 백그라운드에서도 가능한 범위는 실기기 증거로 확정한다.

## 7. 데이터와 위치 추정 설계

### 저장 모델

| 모델 | 필수 필드 및 정책 |
|---|---|
| `HomeArea` | id, accountScope, latitude, longitude, radiusMeters, siteId, enabled, revision |
| `IndoorMap` | siteId, floor, mapVersion, assetPath, 좌표 단위, 물리좌표 보정 유무/변환 |
| `SurveySession` | id, siteId, floor, mapVersion, xPct, yPct, start/end, 기종 그룹, quality, excluded |
| `BeaconObservation` | surveyId, beaconId, 실제 수신 시각, RSSI, measuredPower 선택값 |
| `FingerprintModel` | siteId, mapVersion, modelVersion, 지점별 비콘 median/MAD/count/검출률, 학습 지점 목록 |
| `BeaconEstimate` | beaconId, 층 후보/좌표, 추정 품질, 공간 분포, 잔차, modelVersion, confirmed=false |
| `PositionEstimate` | floor, xPct, yPct, source, observedAt, 공통 비콘 수, score, 표시 품질 |
| `VisitState` | areaRevision, visitId, lastInsideEvidence, evidenceSource, notificationSent, observationAvailable |

측정 기록은 SQLite 트랜잭션으로 세션과 관측을 묶어 저장한다. 측정 원본을 SharedPreferences나 서버의 전체 AppState에 계속 추가하지 않는다. 계정/단지별 격리와 삭제를 구현하고, 집 좌표는 암호화된 설정 저장소에 둔다. 모델 교체는 성공한 새 버전만 활성화하며 이전 모델을 보존한다.

첫 버전은 한 기기에서 수집·학습·사용한다. 다른 주민에게 학습 자료를 배포하려면 별도의 서버 저장·권한·버전 API가 필요하다. 이 저장소에 백엔드가 없으므로 존재하지 않는 API를 호출하지 않는다. 향후 공유가 필요하면 계약을 별도 확정한 후 공용 ApiClient와 서비스 계층에 추가한다.

### 핑거프린팅

- 실제로 새로 수신한 광고만 수집한다. `scanResults`가 기존 항목을 다시 포함하는 경우를 수신 시각/광고 이벤트로 구분해 중복 표본을 만들지 않는다.
- 추정 시 현재 시각 기준 5초 이내 관측만 사용하고, 해당 비콘 신호가 더 오지 않아도 만료시킨다. 세션 교체/스캔 재시작 시 이전 표본을 섞지 않는다.
- 신호 중앙값과 MAD로 이상치를 완화한다. 측정 지점별 지문을 만들고 현재 RSSI 벡터와 비교한다.
- 초기 알고리즘은 가중 kNN(k=3). 공통 비콘 3개 이상인 후보를 사용하고 비콘 누락에도 패널티를 적용한다. 정확히 같은 지문 거리 0은 별도 처리한다. 비콘 개수만으로 위치 품질을 확정하지 않는다.
- 층 점수를 먼저 비교한다. 층 후보 차이가 작으면 `층 확인 필요`로 두고 이전 층을 근거 없이 확정하지 않는다. 약한 신호 하나나 이웃 층 누설을 층 결정의 정답으로 쓰지 않는다.
- 서로 떨어진 통로의 동점 후보를 평균해 벽 안으로 표시하지 않는다. 모호하면 후보 영역/가장 가까운 측정 지점으로 표시한다. 연속 위치 간 급격한 점프는 저품질로 처리한다.
- 신뢰도 점수는 보정 전에는 통계적 확률/95% 신뢰반경이라고 표시하지 않는다. 미터 단위 오차 범위는 현장 오차 데이터와 물리 좌표 보정이 확보된 후 표시한다.

### 비콘 위치 역추정

- 초기 후보는 여러 측정점의 신호 세기 분포로 구한다. 가장 강한 측정점을 설치 좌표로 확정하지 않는다.
- 물리 축척과 형상이 유효한 지도에서 후보 위치에 대한 `RSSI = A - 10*n*log10(distanceMeters)` 잔차를 Huber loss로 최소화한다. 천장 높이 영향은 수직 거리 또는 추가 불확실성으로 반영한다.
- A는 Measured Power를 초기값으로 하되 실제 기종/환경 보정이 필요하다. 공간 분포가 부족한 자료에서 A·n·좌표를 모두 자유롭게 맞추지 않는다. 초기에는 현장 보정한 층/환경의 n을 고정하고 좌표를 추정한다.
- 최소 6개의 서로 다른 측정점은 초기 품질 검사 출발값이다. 비공선 분포·비콘 주위를 둘러싼 정도·잔차·재표본화 안정성도 통과해야 `위치 후보`를 제시한다. 점 개수만 충족해도 식별 가능한 것은 아니다.
- 물리 보정이 없는 도식화에서는 `신호가 강한 후보 구역`까지만 제공한다. 층별 식별이 불명확하면 층 후보도 표시한다. 자료 부족 시 정밀 좌표를 억지로 생성하지 않는다.
- 추정값은 `BeaconEstimate`에 저장한다. 관리자가 확인/수정해 확정할 때만 기존 `upsertBeaconPosition`을 호출한다.

### 지도 보정

- 원본 도면의 알려진 실제 거리·기준점과 도식화의 기하 왜곡 여부를 먼저 대조한다.
- 물리 도면과의 대응이 유효하면 3개 이상의 비공선 기준점을 이용해 변환을 구하고 별도 기준점으로 잔차를 검사한다. 그림이 비선형으로 왜곡되었다면 단순 affine 변환으로 정확해졌다고 간주하지 않는다.
- 도식화는 표시용, 물리 지도 좌표는 계산용으로 나눌 수 있다. 기준점 변경 또는 지도 버전 변경 시 기존 모델을 자동 혼합하지 않는다.

## 8. 구현 작업과 파일

아래 체크박스는 아직 수행하지 않은 구현 작업이다. 기존 파일은 필요한 부분만 변경하며 큰 BLE 화면에서 공통 로직을 추출한다. 각 단계는 실패하는 핵심 동작 테스트 → 구현 → 해당 테스트 통과 → 변경 파일만 검토하는 순서로 수행한다.

### 단계 A — 플랫폼 가능성 검증과 의존성 도입

**대상:** `pubspec.yaml`, `pubspec.lock`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Podfile`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`.

- [ ] 현재 SDK와 Android/iOS 최소 지원 버전을 확인하고 sqflite·google_maps_flutter의 호환 버전을 고정한다. 기존 최소 지원 OS를 임의로 올리지 않는다. SDK 공식 구성 조건과 맞지 않으면 도입 작업을 별도 변경으로 보고한다.
- [ ] 실외 지도 표시에는 플랫폼별 Maps SDK 활성화·제한된 API 키와 공급자 이용 설정이 필요함을 설정 문서에 기록한다. 키가 없으면 설정 필요 상태를 표시하며 키를 저장소에 넣지 않는다. 실내 모드는 이 외부 설정과 독립적으로 동작한다.
- [ ] Android API 36 기기에서 geofence → 위치 관찰 서비스 → 로컬 알림을 최소 실험으로 확인한다. iOS는 지원 최소/최신 OS 기기로 영역 이벤트와 실행 시간을 확인한다.
- [ ] 결과를 `docs/verification/UNDERGROUND_PLATFORM_FEASIBILITY_2026-11-23.md`에 기기/OS/권한/앱 상태/관찰 시간/지연과 함께 기록한다. 실패한 상태를 제외한 제공 범위를 확정한다. 이후 단계 개발과 별개로 자동 안내 출시의 필수 관문이다.

### 단계 B — 모델·저장소·BLE 수집 분리

**신규:** `lib/models/indoor_positioning.dart`, `lib/services/indoor_survey_store.dart`, `lib/services/beacon_observer.dart`, `test/indoor_survey_store_test.dart`, `test/beacon_observer_test.dart`.
**수정:** `lib/screens/admin/console_beacon_scan.dart`, `lib/screens/admin/console_beacon_list.dart`.

- [ ] 모델에 지도/좌표 단위/버전을 명시하고 변환 경계 테스트를 작성한다. 0.5%를 자동으로 50%로 해석하지 않아야 한다.
- [ ] 세션 저장/조회/제외/삭제/원자성/계정 격리와 스키마 마이그레이션을 구현한다. 중단된 세션은 미완료로 두고 학습에서 제외한다.
- [ ] iBeacon 파싱과 안정 ID를 공통 수집기로 옮기고 기존 helper 회귀를 보존한다. 실제 수신 시각 중복 제거와 5초 만료를 주입 가능한 clock으로 검증한다.
- [ ] 전경 측정/위치 화면과 백그라운드 감시가 BLE를 동시에 시작/중지하지 않도록 소유권을 관리한다. 수집기 해제 시 구독·스캔·타이머를 정리한다.

### 단계 C — 반복 측정 화면

**신규:** `lib/screens/admin/indoor_survey_screen.dart`, `lib/screens/admin/indoor_survey_history_screen.dart`, `test/indoor_survey_screen_test.dart`.
**수정:** `lib/screens/admin/console_beacon_scan.dart`, `lib/screens/admin/console_beacon_list.dart`.

- [ ] 기존 `비콘 설치 위치 지정`과 별개로 `이 위치에서 신호 측정` 진입을 추가한다. 기존 설치 위치 편집은 유지한다.
- [ ] 측정 당시 내 위치·층·지도 버전 지정, 진행/취소, 품질 요약, 저장을 구현한다. 이동 중 수집은 첫 버전의 측정 UX에서 제외한다.
- [ ] 같은 지점 2회 등록은 세션 2개가 되고 `beaconPositions`는 바뀌지 않는 위젯/저장소 결합 테스트를 추가한다.
- [ ] 기록 제외/삭제 후 모델 재생성이 필요함을 표시한다. 측정 0개/수신 부족/저장 실패에서 성공 메시지를 내지 않는다.

### 단계 D — 신호 지도와 내 위치 추정

**신규:** `lib/services/fingerprint_positioner.dart`, `lib/providers/indoor_position_provider.dart`, `test/fingerprint_positioner_test.dart`, `test/indoor_position_provider_test.dart`.
**수정:** `lib/main.dart`, `lib/screens/admin/console_beacon_list.dart`, `lib/screens/public/map_view_screen.dart`.

- [ ] 학습/비교/층 판정/품질 반환을 순수 Dart 계산으로 구현한다. 원시 관측, 모델 생성, 실시간 위치 상태를 분리한다.
- [ ] 알려진 합성 지문에서 정답 후보 선택, 동점/서로 다른 통로, 누락 비콘, 교차 층, 기종 편향, NaN/무한대 방지를 테스트한다.
- [ ] 마지막 패킷 이후 5초가 지나면 현재 위치 마커를 해제하는 provider 테스트를 작성한다. 타이머는 화면 수명과 명시적 관찰 세션에 묶는다.
- [ ] 회원 지도에 내 위치·추정 품질·최근 수신 시각·수동 층 선택을 제공한다. 기존 주차 마커·확대·터치 동작을 보존한다.
- [ ] 모델 없음/미지원 지도 버전/저장 자료 손상 시 추정 불가 상태를 표시한다. 오프라인 추정은 서버 인증 재조회가 없어도 이미 허용된 로컬 범위에서 작동하도록 인증 화면 흐름과 조정한다. 인증을 우회해 회원 서버 데이터를 노출하지 않는다.

### 단계 E — 물리 지도 보정과 비콘 위치 후보

**신규:** `lib/services/beacon_locator.dart`, `lib/services/indoor_map_calibration.dart`, `lib/screens/admin/beacon_estimate_screen.dart`, `test/beacon_locator_test.dart`, `test/indoor_map_calibration_test.dart`.
**수정:** `lib/screens/admin/beacon_position_editor.dart`.

- [ ] 지도 기준점 보정과 교차 검증 잔차를 구현한다. 유효한 물리 지도가 없으면 후보 구역 모드만 허용한다.
- [ ] 합성 좌표와 고정 n으로 생성한 RSSI에서 위치 복원, 이상치 강건성, 공선점/한쪽 측정/동일 지점 반복을 자료 부족으로 판정하는 테스트를 추가한다.
- [ ] 후보 지도·근거·품질과 `현장 확인 후 설치 위치로 저장` 동작을 제공한다. 자동 후보 생성만으로 서버 쓰기를 하지 않는다.
- [ ] 확정 저장 실패 시 기존 provider 롤백과 오류 안내가 유지되는지 확인한다.

### 단계 F — 집 반경 설정과 순수 상태 판정

**신규:** `lib/screens/public/home_area_settings_screen.dart`, `lib/services/home_area_store.dart`, `lib/services/indoor_entry_policy.dart`, `lib/core/indoor_location_bridge.dart`, `test/home_area_store_test.dart`, `test/home_area_settings_test.dart`, `test/indoor_entry_policy_test.dart`.
**수정:** `lib/screens/public/mypage_screen.dart`.

- [ ] 실외 지도 중심 선택/원형 반경/설정 저장/감시 스위치와 현재 권한 상태를 구현한다. 설정 변경은 이전 geofence 등록을 교체하고 실패 시 상태를 명시한다.
- [ ] 상태 판정은 OS API 없이 시간·영역 근거·위치 품질·관찰 가능 여부를 입력받도록 분리한다. 30초/20분/중복 억제와 이탈 히스테리시스를 테스트한다.
- [ ] 권한 OFF, 서비스 OFF, 오래된 위치, 프로세스 유예, 앱 최초 실행부터 위치 없음, 시간 역행, 재부팅을 신호 단절로 오인하지 않는 테스트를 추가한다.
- [ ] 계정 전환/로그아웃 시 감시를 중지하고 방문/알림 상태를 폐기한다. 집 설정은 해당 계정에만 남기며 다른 계정으로 넘기지 않는다.

핵심 상태 테스트 표:

| 입력 | 기대 결과 |
|---|---|
| 외부 위치 + 품질 저하 60초 | 실내 전환 알림 없음 |
| 내부 근거 + 관찰 가능 + 29초 저하 | 알림 없음 |
| 내부 근거 + 관찰 가능 + 30초 저하 | 해당 방문 알림 1회 |
| 같은 방문에서 추가 저하 | 재알림 없음 |
| 20분 넘은 내부 근거 + 저하 | 알림 없음, 새 영역 근거 필요 |
| 위치 권한 철회/관찰 세션 중지 | unavailable, 저하로 처리하지 않음 |
| GPS 손실 중 불명확한 EXIT 이벤트 | 즉시 이탈로 확정하지 않음 |
| 확실한 이탈 2회 후 재진입·저하 | 새 방문 알림 가능 |

### 단계 G — Android 영역 감시와 관찰 서비스

**신규:** `android/app/src/main/kotlin/com/bluetilelab/apt_ev/IndoorLocationMonitor.kt`, `IndoorLocationService.kt`, `IndoorGeofenceReceiver.kt`, `IndoorBootReceiver.kt`, `android/app/src/test/kotlin/com/bluetilelab/apt_ev/IndoorEntryPolicyTest.kt`.
**수정:** 같은 폴더의 `MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `lib/core/bluetooth_permissions.dart`, `test/bluetooth_permissions_test.dart`.

- [ ] 등록/해제/권한 상태/이벤트 저장/복원을 MethodChannel 계약으로 연결한다. 이벤트에는 원본 시각·관찰 상태·영역 revision을 포함한다.
- [ ] GeofencingClient와 bounded location foreground service를 구현한다. FGS 종류·권한·시작 예외를 target API 36에서 확인하며 네이티브 초기화 실패를 Flutter에서 감시 중으로 표시하지 않는다.
- [ ] Dart 엔진이 없어도 필요한 방문 상태와 이벤트를 저장할 수 있게 네이티브 저장소를 사용한다. 순수 판정 규칙은 공통 JSON 시나리오로 Dart/Kotlin 결과를 대조해 중복 구현의 차이를 검출한다.
- [ ] 서비스 시작 거절·알림 거절·GMS 없음·재부팅·절전·권한 자동 회수·강제 중지 시 기대 동작을 실기기로 기록한다.
- [ ] BLE 필터 기반 대기 감시가 필요한 기기는 광고 수신 중복/시간과 스캔 소유권까지 확인한다. 영역 밖 상시 고빈도 스캔은 하지 않는다.

### 단계 H — iOS 조건 감시

**신규:** `ios/Runner/IndoorLocationMonitor.swift`, `ios/RunnerTests/IndoorEntryPolicyTests.swift`.
**수정:** `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj`.

- [ ] 지원 OS별 Core Location 지리/비콘 조건 감시를 구성하고 이벤트를 로컬 보관한다. 암묵적 Flutter engine 초기화 및 scene 수명에 맞춰 브리지를 연결한다.
- [ ] 위치 권한 단계와 background capability, 알림 권한 및 사용자가 감시를 끈 경우를 연결한다. 정밀 위치 제한/Background App Refresh 제한 상태를 표시한다.
- [ ] Android/Dart와 동일한 공통 상태 시나리오를 Swift에서 검증한다. iOS 관찰 불가 상태는 저하 판정을 생성하지 않아야 한다.
- [ ] Xcode 테스트 타깃이 없으면 이 단계에서 추가한다. 실기기에서 앱 전경/잠금/백그라운드/사용자 종료/재부팅의 감지 가능 범위와 지연을 기록한다.

### 단계 I — 로컬 알림과 지도 진입 통합

**신규:** `lib/services/local_notification_router.dart`, `lib/services/indoor_entry_notifications.dart`, `test/local_notification_router_test.dart`, `test/indoor_entry_notification_test.dart`.
**수정:** `lib/services/push_notifications.dart`, `lib/main.dart`, `lib/screens/public/shell_screen.dart`, 네이티브 알림 응답 브리지.

- [ ] 로컬 알림 초기화와 응답 처리를 Firebase 독립 공통 계층으로 이동한다. 플러그인 중복 초기화로 한쪽 콜백이 덮이지 않게 한다.
- [ ] 기존 정수 payload를 계속 수용하면서 신규 타입 지정 payload를 라우팅한다. 예: `{"type":"indoorEntry","version":1,"siteId":"local-site","visitId":"visit-1","areaRevision":1}`. 집 좌표를 알림 payload나 잠금 화면 문구에 넣지 않는다.
- [ ] Android 네이티브 감지와 iOS 네이티브 감지에서도 Flutter 종료 상태의 로컬 알림을 생성할 수 있게 한다. 로컬 알림 ID/채널을 기존 출차 알림과 분리한다.
- [ ] 초기 실행·실행 중 선택·로그인 전 선택·계정 변경·오래된 방문·반복 선택에서 정확한 단일 진입을 테스트한다. 기존 출차 요청 상세 진입 회귀도 검증한다.
- [ ] `Firebase 미설정 + 인터넷 없음`에서도 지하 알림 처리와 캐시된 실내 지도 진입이 가능한지 확인한다. 외부 지도 타일의 오프라인 제공은 이번 범위가 아니다.

### 단계 J — 현장 평가·문서·출시 판단

**신규:** `docs/verification/UNDERGROUND_POSITIONING_FIELD_TEST.md`, 테스트용 비식별 고정 fixture `test/fixtures/indoor_positioning/`.
**수정:** `docs/architecture/PROJECT_ANALYSIS.md`, `docs/architecture/project-diagram.mmd`, `docs/architecture/project-diagram.index.json`.

- [ ] B1/B2 각각 학습에서 제외한 최소 10개 정지 지점과 층 이동 경로를 준비한다. 동일 위치 재측정만 학습/평가에 나눠 넣지 않고 지점/방문/기종으로 분리한다.
- [ ] 초기 출시 판단 목표는 보정된 실제 좌표 기준 중앙 오차 5m 이하, 90백분위 10m 이하, 층 판정 정확도 95% 이상이다. 이는 달성 보장이 아닌 시험 목표다. 달성하지 못하면 제공 범위를 구역 안내로 제한하고 숫자를 실제 결과로 대체한다.
- [ ] 정확도와 함께 추정 가능 비율·자료 부족 비율·잘못된 층 표시 비율·초기 추정 시간·자동 안내 성공 비율/지연/오탐·시간당 배터리 변화를 기록한다. 추정 불가를 제외한 오차 수치만으로 품질을 주장하지 않는다.
- [ ] 차량 적음/많음, 휴대폰 손/주머니, Android/iPhone 각 기종, GPS 유지 실내, 지하 인터넷 단절, 영역 밖 GPS 저하, Wi-Fi OFF를 비교한다. 정지 측정 모델의 차량 이동 중 사용 정확도는 별도 검증 전 보장하지 않는다.
- [ ] 자동 안내는 지원 상태별 실제 시도 수와 성공 수를 공개하고, 유예/강제 중지/권한 부족처럼 보장할 수 없는 상태를 UI와 기록에 남긴다.
- [ ] 실제로 추가한 모듈/파일/심볼/의존 관계와 데이터 흐름만 Mermaid/JSON에 함께 반영한다. 계획 단계에서는 아직 없는 모듈을 구현 현황 구조도에 넣지 않는다.

## 9. 검증 명령과 실행 조건

현재 확인한 Flutter 실행 경로: `C:/src/flutter/bin/flutter.bat`. 아래는 구현 단계에서 실행할 명령이며, 계획 작성만으로 실행/통과했다고 간주하지 않는다. 운영 서버 호출이 필요한 테스트는 대상 서버 확인 후 별도 실행한다. 계산/저장소/위젯 테스트는 fake transport와 fixture로 네트워크 없이 수행한다.

```powershell
& 'C:/src/flutter/bin/flutter.bat' --version
& 'C:/src/flutter/bin/flutter.bat' analyze --no-fatal-infos
& 'C:/src/flutter/bin/flutter.bat' test test/beacon_observer_test.dart test/fingerprint_positioner_test.dart test/beacon_locator_test.dart test/indoor_entry_policy_test.dart
& 'C:/src/flutter/bin/flutter.bat' test test/indoor_survey_store_test.dart test/indoor_survey_screen_test.dart test/home_area_settings_test.dart test/indoor_position_provider_test.dart test/local_notification_router_test.dart test/indoor_entry_notification_test.dart
& 'C:/src/flutter/bin/flutter.bat' test test/bluetooth_permissions_test.dart test/console_beacon_scan_helpers_test.dart test/map_view_zoom_test.dart test/map_editor_version_test.dart test/deep_link_test.dart test/departure_request_test.dart
& 'C:/src/flutter/bin/flutter.bat' test
```

각 단계에서 작성한 나머지 테스트도 대상에 추가한다. Android 네이티브 테스트는 Android 폴더에서 `./gradlew.bat :app:testDebugUnitTest`를 실행한다. iOS 네이티브 테스트와 빌드는 macOS/Xcode와 연결된 실기기에서 수행한다. 실행 불가능하면 원인과 미검증 기능을 기록한다. BLE/위치/권한/알림/OS 백그라운드 동작은 단위 테스트만으로 합격 처리하지 않는다.

Windows 임시 디렉터리 문제가 재현되면 기존 프로젝트 방침에 따라 검증 프로세스의 TEMP/TMP에 전용 ASCII 경로를 사용한다. 배포 스크립트, 버전 변경, Play/App Store 게시는 검증 명령에 포함하지 않는다.

## 10. 실행 순서와 완료 조건

1. **A → B → C → D:** 플랫폼 제약을 먼저 시험하고 반복 측정과 오프라인 내 위치 추정을 사용할 수 있게 한다.
2. **E:** 물리 지도 보정이 성립한 범위에서 비콘 위치를 추정하고, 성립하지 않으면 후보 구역 표시로 제한한다.
3. **F → G → H → I:** 집 반경, 방문/위치 품질 판정, OS별 감시, 알림에서 지도 진입을 연결한다.
4. **J:** 지하 현장에서 정확도와 자동 안내 동작을 측정하고 Android/iOS별 제공 범위를 확정한다.

구현 완료 조건은 1~6번 기능이 지원 범위에서 검증되고, 7번의 '알림 선택에 의한 실행'과 '사용자 조작 없는 화면 실행의 비보장'이 구분되는 것이다. 계획·시뮬레이션·단위 테스트만으로 실기기 자동 실행이나 지하 위치 정확도를 달성했다고 보고하지 않는다.

## 11. 공식 근거

- [Android geofencing](https://developer.android.com/develop/sensors-and-location/location/geofencing): 원형 영역, 백그라운드 위치 권한, 이벤트 지연과 통신 조건.
- [Android background activity launch restrictions](https://developer.android.com/guide/components/activities/secure-bal): 백그라운드 화면 실행 제한, 알림 선택에 의한 실행.
- [Android foreground service start restrictions](https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start): 영역 이벤트의 예외와 위치 권한 조건.
- [Android BLE background](https://developer.android.com/develop/connectivity/bluetooth/ble/background): 프로세스가 없을 때 필터 기반 PendingIntent scan.
- [Android GnssStatus.Callback](https://developer.android.com/reference/kotlin/android/location/GnssStatus.Callback): GNSS 중지 알림은 위치 측정 불가 자체를 의미하지 않음.
- [Apple geographic conditions](https://developer.apple.com/documentation/corelocation/monitoring-the-user-s-proximity-to-geographic-regions): 영역 변화 시 백그라운드 처리 기회.
- [Apple background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background): 실행 유예·권한·background capability.
- [Apple iBeacon ranging](https://developer.apple.com/documentation/corelocation/determining-the-proximity-to-an-ibeacon-device): 영역 감지와 ranging 분리, 거리 추정의 한계.
- [Apple Core Location](https://developer.apple.com/documentation/corelocation): GPS 외 여러 위치 정보원을 사용.
- [Google Maps Flutter](https://pub.dev/packages/google_maps_flutter): 플랫폼 요구사항, Maps SDK와 키 설정.

확인일: 2026-11-23. 구현 시작 시 대상 OS/SDK의 공식 요구사항을 다시 확인한다.
