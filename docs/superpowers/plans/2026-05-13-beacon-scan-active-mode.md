# Beacon Scan — Active Scan Mode 옵션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 관리자 비콘 스캔 화면에 Android BLE scan mode 4단계를 선택할 수 있는 SegmentedButton 옵션을 추가한다.

**Architecture:** 단일 파일(`console_beacon_scan.dart`) 내에서 `AndroidScanMode` 를 상태로 보관하고, 기존 컨트롤 영역 아래에 `SegmentedButton<AndroidScanMode>` 한 개를 노출. `_startScan()` 호출 시 선택된 모드를 그대로 전달.

**Tech Stack:** Flutter 3.x, Dart 3.x, flutter_blue_plus 1.32.12, provider

**Reference spec:** `docs/superpowers/specs/2026-05-13-beacon-scan-active-mode-design.md`

---

## File Structure

**수정:**
- `lib/screens/admin/console_beacon_scan.dart` — 상태 + UI + 콜백 추가

**신규:**
- `test/console_beacon_scan_widget_test.dart` — SegmentedButton 노출 / disable 동작 위젯 테스트

**문서:**
- 이미 작성됨: `docs/superpowers/specs/2026-05-13-beacon-scan-active-mode-design.md`

---

## Task 1: 위젯 테스트 (TDD - 먼저 실패하는 테스트 작성)

**Files:**
- Create: `test/console_beacon_scan_widget_test.dart`

- [ ] **Step 1: 테스트 파일 작성**

`test/console_beacon_scan_widget_test.dart` 생성:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/screens/admin/console_beacon_scan.dart';

class _FakeAppStateProvider extends AppStateProvider {
  _FakeAppStateProvider() : super.testOnly(const AppState.empty());
}

void main() {
  testWidgets('스캔 모드 SegmentedButton 4단계가 노출된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<AppStateProvider>(
          create: (_) => _FakeAppStateProvider(),
          child: const ConsoleBeaconScan(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Passive'), findsOneWidget);
    expect(find.text('LowPower'), findsOneWidget);
    expect(find.text('Balanced'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('스캔 모드'), findsOneWidget);
  });
}
```

> 주의: `AppStateProvider.testOnly` 와 `AppState.empty()` 가 이미 존재하지 않으면 본 단계 전에 기존 패턴 확인 필요. 아래 Step 2 의 분석 결과에 따라 fake provider 방식을 조정한다.

- [ ] **Step 2: 기존 AppStateProvider / AppState 생성자 패턴 확인**

```bash
grep -n "AppStateProvider(" lib/providers/app_state_provider.dart | head -5
grep -n "AppState\." lib/models/app_state.dart | head -10
```

기존 생성자가 `testOnly` 가 아니라 다른 형태(e.g. `AppStateProvider()` 기본 생성자)면, 위 fake 를 그에 맞게 교체. 마찬가지로 `AppState.empty()` 가 없으면 실제 존재하는 생성자(예: `AppState()` 기본값) 로 교체.

- [ ] **Step 3: 테스트 실행해서 실패 확인**

```bash
cd D:\vsCodeProg\APT-APP
flutter test test/console_beacon_scan_widget_test.dart
```

Expected: FAIL — "Passive" 등의 라벨이 화면에 없음 (현재 SegmentedButton 미구현).

---

## Task 2: ScanMode 상태 + UI + 동작 (단일 파일 통합 수정)

**Files:**
- Modify: `lib/screens/admin/console_beacon_scan.dart`

- [ ] **Step 1: import 확인**

상단 import 는 그대로 유지. `AndroidScanMode` 는 이미 `package:flutter_blue_plus/flutter_blue_plus.dart` 에서 가져오고 있으므로 추가 import 불필요.

- [ ] **Step 2: `_ConsoleBeaconScanState` 클래스에 상태 추가**

`bool _bluetoothOn = false;` 다음 줄(현재 약 line 29)에 추가:

```dart
  AndroidScanMode _scanMode = AndroidScanMode.lowLatency;
```

- [ ] **Step 3: 모드 라벨/설명 헬퍼 추가**

`Color _rssiColor(int rssi)` 함수(현재 약 line 258) 위에 다음 두 헬퍼 추가:

```dart
  String _scanModeLabel(AndroidScanMode m) {
    switch (m) {
      case AndroidScanMode.opportunistic:
        return 'Passive';
      case AndroidScanMode.lowPower:
        return 'LowPower';
      case AndroidScanMode.balanced:
        return 'Balanced';
      case AndroidScanMode.lowLatency:
        return 'Active';
    }
  }

  String _scanModeDescription(AndroidScanMode m) {
    switch (m) {
      case AndroidScanMode.opportunistic:
        return '다른 앱이 스캔할 때만 결과 수신. 단독 사용 시 검출이 거의 없음.';
      case AndroidScanMode.lowPower:
        return '배터리 절약. 검출 지연 큼.';
      case AndroidScanMode.balanced:
        return '검출과 전력 균형.';
      case AndroidScanMode.lowLatency:
        return '가장 빠른 검출. 배터리 소모 큼. (기본)';
    }
  }
```

- [ ] **Step 4: `_startScan()` 의 startScan 호출에서 `_scanMode` 사용**

기존(약 line 192-195):

```dart
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
```

다음으로 교체:

```dart
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode: _scanMode,
      );
```

- [ ] **Step 5: `build()` 메서드의 컨트롤 Row 아래에 모드 선택 영역 추가**

기존 컨트롤 `Row` 를 감싸는 `Padding` (약 line 306-328) 의 자식 `Row` 가 끝나는 직후에, 같은 `Padding` 의 자식을 `Row` 단일 → `Column` 으로 바꾸어 모드 선택 영역을 추가한다.

수정 전:
```dart
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                ...
                FilledButton.icon(
                  onPressed: _isScanning ? _stopScan : _startScan,
                  icon: Icon(_isScanning ? Icons.stop : Icons.search),
                  label: Text(_isScanning ? '중지' : '스캔 시작'),
                ),
              ],
            ),
          ),
```

수정 후:
```dart
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(_bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                        size: 18, color: _bluetoothOn ? Colors.blue : Colors.grey),
                    const SizedBox(width: 6),
                    Text(_bluetoothOn ? '블루투스 ON' : '블루투스 OFF',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const Spacer(),
                    Text(_isScanning ? '스캔 중…' : '대기',
                        style: TextStyle(
                            fontSize: 12,
                            color: _isScanning ? Colors.blue : Colors.black54)),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isScanning ? _stopScan : _startScan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.search),
                      label: Text(_isScanning ? '중지' : '스캔 시작'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '스캔 모드 (Android 만 적용)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54),
                ),
                const SizedBox(height: 6),
                SegmentedButton<AndroidScanMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in const [
                      AndroidScanMode.opportunistic,
                      AndroidScanMode.lowPower,
                      AndroidScanMode.balanced,
                      AndroidScanMode.lowLatency,
                    ])
                      ButtonSegment<AndroidScanMode>(
                        value: m,
                        label: Text(
                          _scanModeLabel(m),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                  selected: <AndroidScanMode>{_scanMode},
                  onSelectionChanged: _isScanning
                      ? null
                      : (selected) {
                          setState(() => _scanMode = selected.first);
                        },
                ),
                const SizedBox(height: 4),
                Text(
                  _isScanning
                      ? '${_scanModeDescription(_scanMode)} (스캔 중지 후 변경 가능)'
                      : _scanModeDescription(_scanMode),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
```

- [ ] **Step 6: flutter analyze 실행 (린트/타입 검증)**

```bash
cd D:\vsCodeProg\APT-APP
flutter analyze lib/screens/admin/console_beacon_scan.dart
```

Expected: `No issues found!` 또는 기존 경고만 (새 경고 없음).

- [ ] **Step 7: Task 1 의 위젯 테스트 재실행**

```bash
flutter test test/console_beacon_scan_widget_test.dart
```

Expected: PASS — Passive/LowPower/Balanced/Active 4개 라벨 모두 보임.

만약 권한 / Bluetooth 어댑터 호출이 위젯 마운트 시점에 실패해서 테스트가 깨지면, `expect(find.text('Active'), findsOneWidget)` 가 통과만 한다면 충분하므로 추가 setup 없이 진행. 정 못 통과시키면 테스트 파일에 `FlutterBluePlus.adapterState` 모킹 추가 (별도 작업으로 분리).

---

## Task 3: 수동 검증 체크리스트

**Files:** 없음 — 검증만

- [ ] **Step 1: Android 기기에서 앱 실행**

```bash
cd D:\vsCodeProg\APT-APP
flutter run -d <android_device_id>
```

또는 `android-run.bat` 사용.

- [ ] **Step 2: 관리자 콘솔 → BLE 비콘 스캔 진입**

- [ ] **Step 3: 다음 사항 모두 확인 (체크하며 진행)**

- [ ] 기본 진입 시 `Active` 가 선택된 상태
- [ ] 스캔 시작 전 4개 모드를 자유롭게 전환 가능
- [ ] 모드 변경 시 하단 설명 라인이 즉시 갱신
- [ ] 스캔 시작 → SegmentedButton 이 회색(disabled) 으로 바뀜
- [ ] 설명 라인에 `(스캔 중지 후 변경 가능)` 안내 노출
- [ ] 스캔 중지 후 다른 모드 선택 가능
- [ ] `Active` 에서 디바이스 검출이 빠름
- [ ] `Passive` (opportunistic) 단독 사용 시 검출이 거의 없음

---

## Task 4: Git 저장소 초기화 + 첫 커밋

**Files:** 없음 — git 작업만

- [ ] **Step 1: 기존 git 디렉토리 부재 확인**

```bash
cd D:\vsCodeProg\APT-APP
Test-Path .git
```

Expected: `False` (이미 git 저장소면 이 task 건너뜀)

- [ ] **Step 2: .gitignore 점검**

```bash
Test-Path .gitignore
```

없거나 불완전하면 Flutter 표준 `.gitignore` 작성 — 다음 내용 포함:

```
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
.pub-cache/
.pub/
build/
.idea/
.vscode/
*.iml
*.ipr
*.iws
ios/Pods/
android/.gradle/
android/local.properties
**/GeneratedPluginRegistrant.*
.env
*.log
```

(기존 파일이 있으면 위 항목 누락 여부만 확인하고 부족한 줄만 추가)

- [ ] **Step 3: git init + main branch 설정**

```bash
git init -b main
```

Expected: `Initialized empty Git repository in D:/vsCodeProg/APT-APP/.git/`

- [ ] **Step 4: 사용자에게 secret 파일 확인**

플랜 실행자는 add 전에 다음을 점검:

```bash
ls .env, *.keystore, *.jks, ios/Runner/GoogleService-Info.plist, android/app/google-services.json -ErrorAction SilentlyContinue
```

존재하는 secret 후보는 `.gitignore` 에 추가 후 진행. 사용자에게 한 번 확인받는다.

- [ ] **Step 5: 첫 커밋**

```bash
git add .
git status   # secret 파일이 staged 영역에 없는지 다시 확인
git commit -m "chore: initial commit (apt_ev_charging Flutter app)"
```

Expected: 첫 커밋 생성됨.

- [ ] **Step 6: SegmentedButton 변경분 별도 커밋**

위 Step 5 에서 이미 모든 변경이 합쳐 들어갔으면 이 step 은 스킵. 만약 plan 의 Task 2 변경분만 따로 분리하고 싶다면, Task 4 를 Task 2 보다 먼저 실행하고 Task 2 의 변경분을 별도 커밋으로 만든다.

권장 흐름: **Task 4 를 Task 2 전에 먼저 실행** → 초기 코드를 baseline 커밋 → Task 2 변경분을 다음 커밋으로 분리.

분리 커밋 명령:

```bash
git add lib/screens/admin/console_beacon_scan.dart test/console_beacon_scan_widget_test.dart docs/superpowers/
git commit -m "feat(beacon-scan): add Android scan mode selector (Passive/LowPower/Balanced/Active)"
```

---

## Task 5: 원격 저장소 생성 + push (사용자 결정 필요)

**Files:** 없음 — git/원격 작업만

이 task 는 실행 전에 다음 사항을 사용자에게 확인:

1. 어느 원격 호스트? (GitHub / GitLab / 사내 / 안 함)
2. 저장소 이름 (`apt_ev_charging` 권장)
3. 공개 / 비공개
4. 인증 수단 (`gh auth status` 확인)

- [ ] **Step 1: 사용자 응답에 따라 분기**

GitHub 인 경우:

```bash
gh auth status
gh repo create <name> --private --source=. --remote=origin --push
```

수동 origin 추가만 원할 경우 (사용자가 미리 빈 리포 생성):

```bash
git remote add origin <url>
git push -u origin main
```

- [ ] **Step 2: push 결과 확인**

```bash
git remote -v
git log --oneline -5
```

Expected: origin URL 표시 + 최근 커밋 보임.

---

## 권장 실행 순서

1. **Task 4 Step 1~5** (git init + baseline 첫 커밋) — 변경 전 상태를 보존
2. **Task 1** (실패하는 위젯 테스트)
3. **Task 2** (구현)
4. **Task 4 Step 6** (SegmentedButton 변경분 분리 커밋)
5. **Task 3** (수동 검증)
6. **Task 5** (원격 리포 생성 + push, 사용자 확인 후)
