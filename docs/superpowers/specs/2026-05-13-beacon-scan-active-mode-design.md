# Beacon Scan — Active Scan Mode 옵션 추가 설계

**Date:** 2026-05-13
**Target file:** `lib/screens/admin/console_beacon_scan.dart`
**Scope:** UI에서 Android BLE 스캔 모드를 4단계로 선택 가능하게 노출

## 1. 배경

현재 관리자 콘솔의 BLE 비콘 스캔 화면은 `FlutterBluePlus.startScan(androidScanMode: AndroidScanMode.lowLatency)` 로 고정되어 있다. 비콘 위치 매핑 작업 환경에 따라 검출 우선 / 배터리 우선 / 다른 앱 의존(=거의 passive) 모드를 골라 쓸 수 있도록 UI 옵션을 추가한다.

flutter_blue_plus 1.32.x 에는 BLE 라디오 레벨의 active/passive 직접 토글이 없으므로, 라이브러리가 제공하는 `androidScanMode` enum (`opportunistic`, `lowPower`, `balanced`, `lowLatency`) 을 UI 에 그대로 노출하는 것이 가장 정직하고 실용적인 절충안이다.

## 2. 목표 (Goals)

- 관리자가 스캔 화면 내에서 4단계 스캔 모드를 선택할 수 있다.
- 선택한 모드가 `_startScan()` 호출 시 그대로 `FlutterBluePlus.startScan` 에 전달된다.
- 스캔 중에는 모드 변경이 비활성화되어 라이브러리/OS 자원 충돌이 발생하지 않는다.
- iOS 사용자에게도 토글이 보이지만 효과가 없음을 명확히 안내한다.

## 3. 비목표 (Non-Goals)

- BLE 라디오 active/passive 의 OS 레벨 강제 제어 (불가능)
- 디바이스별 GATT 연결 후 characteristic 읽기 (별도 작업으로 분리)
- 모드 선택의 영속화 (SharedPreferences 저장) — 앱 세션 동안만 유지
- iOS Core Bluetooth scan 옵션의 별도 노출

## 4. 사용자 시나리오

1. 관리자가 BLE 비콘 스캔 화면 진입.
2. 화면 상단 컨트롤 영역에서 스캔 모드를 고를 수 있는 SegmentedButton 4개 노출 (기본: Active).
3. 환경에 맞게 모드 선택 → "스캔 시작" 클릭.
4. 스캔 중에는 모드 버튼이 disabled (회색) 처리. tooltip / 보조 텍스트로 "스캔 중지 후 변경" 안내.
5. "중지" 누른 뒤 다른 모드 선택 → 재시작.

## 5. UI 명세

### 5.1 위치

기존 컨트롤 `Row` (블루투스 상태 · 스캔 상태 · 스캔 시작 버튼) 의 **아래쪽 Padding 블록 안**에 새 영역을 추가한다.

### 5.2 구성요소

```
스캔 모드 (Android 만 적용)
[ Passive ] [ LowPower ] [ Balanced ] [ Active ]
↑ 현재 선택 모드의 설명 한 줄
```

- 제목 텍스트: `"스캔 모드 (Android)"` (font 12, w600, black54)
- `SegmentedButton<AndroidScanMode>`
  - segments: 4개 — opportunistic / lowPower / balanced / lowLatency
  - 라벨 표시명: `Passive` / `LowPower` / `Balanced` / `Active`
  - `showSelectedIcon: false`
  - `style` : compact (densityCompact equivalent, fontSize 11)
- 설명 라인 (font 11, black54, italic): 선택된 모드에 따라 동적으로 변경
  - `opportunistic`: "다른 앱이 스캔할 때만 결과 수신. 단독 사용 시 검출이 거의 없음."
  - `lowPower`: "배터리 절약. 검출 지연 큼."
  - `balanced`: "검출과 전력 균형."
  - `lowLatency`: "가장 빠른 검출. 배터리 소모 큼. (현재 기본)"

### 5.3 상태 표시

- `_isScanning == true` 일 때 `SegmentedButton.onSelectionChanged = null` → disabled
- 추가로 설명 라인 옆에 `(스캔 중지 후 변경 가능)` 안내 텍스트

### 5.4 iOS 처리

- 토글은 그대로 노출 (UI 통일)
- 제목에 `(Android 만 적용)` 명시 — 사용자가 무효함을 즉시 인지

## 6. 데이터 흐름

### 6.1 신규 상태

`_ConsoleBeaconScanState` 에 추가:
```dart
AndroidScanMode _scanMode = AndroidScanMode.lowLatency;
```

### 6.2 변경 지점

`_startScan()` 내 기존 호출:
```dart
await FlutterBluePlus.startScan(
  timeout: const Duration(seconds: 15),
  androidScanMode: AndroidScanMode.lowLatency,
);
```
↓
```dart
await FlutterBluePlus.startScan(
  timeout: const Duration(seconds: 15),
  androidScanMode: _scanMode,
);
```

### 6.3 UI 콜백

```dart
onSelectionChanged: _isScanning
    ? null
    : (Set<AndroidScanMode> selected) {
        setState(() => _scanMode = selected.first);
      }
```

## 7. 오류 처리

- 추가 오류 경로 없음. 기존 `_startScan` 의 try/catch 와 권한 처리가 그대로 적용됨.
- `opportunistic` 모드에서 결과가 없는 것은 정상 동작 — 별도 메시지 불필요 (설명 라인이 사용자에게 미리 안내).

## 8. 테스트 계획

flutter_test 단위 테스트는 BLE 의존성이 무거워 비효율적이므로, 수동 검증 체크리스트로 대신한다.

수동 검증 (Android 기기):
- [ ] 기본 진입 시 Active 가 선택되어 있다.
- [ ] 스캔 시작 전 4개 모드를 자유롭게 전환 가능하다.
- [ ] 모드 변경 시 설명 라인이 즉시 갱신된다.
- [ ] 스캔 시작하면 SegmentedButton 이 회색(disabled) 으로 바뀐다.
- [ ] 스캔 중지 후 다시 다른 모드 선택 가능.
- [ ] Active 모드에서 디바이스 검출이 가장 빠르다 (체감).
- [ ] Opportunistic 모드 단독 사용 시 검출 빈도가 현저히 낮다.

수동 검증 (iOS 기기):
- [ ] 토글이 노출되고 동작은 하지만, 어떤 모드를 골라도 검출 결과는 동일함을 확인.
- [ ] 제목의 `(Android 만 적용)` 안내가 보인다.

## 9. 위험 / 알려진 제약

| 위험 | 영향 | 완화 |
|------|------|------|
| flutter_blue_plus 후속 버전에서 `AndroidScanMode` enum 변경 | 컴파일 오류 | 현재 버전(1.32.12) 고정 |
| `opportunistic` 모드에서 검출 0건이 버그처럼 보일 수 있음 | 사용자 혼란 | 설명 라인에 "다른 앱이 스캔할 때만" 명시 |
| iOS 사용자에게 무효한 옵션 노출 | UX 혼동 | 제목에 `(Android 만 적용)` 명시 |

## 10. 영속화 결정

스캔 모드 선택은 **앱 세션 동안만 유지**한다. 앱 재시작 시 `lowLatency` 로 복귀.

이유: 관리자 콘솔 한정 기능이고 빈번하지 않은 작업이라 영속화의 가치가 작으며, SharedPreferences 의존성을 추가하지 않아 변경 범위를 단일 파일로 유지할 수 있다.

## 11. 변경 파일 목록

- `lib/screens/admin/console_beacon_scan.dart` (단일 파일)

새 파일이나 의존성 추가 없음.
