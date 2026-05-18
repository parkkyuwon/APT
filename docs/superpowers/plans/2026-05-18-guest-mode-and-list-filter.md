# 비회원(게스트) 모드 + 목록 필터 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인 없이 주차 현황을 읽기 전용으로 보는 게스트 모드와, 목록 화면의 전체/사용중/미사용 세그먼트 필터를 추가한다.

**Architecture:** `AuthStage.guest`를 1급 상태로 추가해 `_RootNavigator`가 게스트 전용 3탭 Shell로 분기. 게스트는 `/api/public-dashboard`(점유 여부만)에서 데이터를 받고 영속 캐시를 쓰지 않는다. 필터링 로직은 순수 모듈(`slot_filter.dart`)로 분리해 위젯/프로바이더 없이 단위 테스트한다.

**Tech Stack:** Flutter, provider, Material 3 (`SegmentedButton`, `NavigationBar`), flutter_test.

**작업 브랜치:** `feature/guest-mode-and-list-filter` (이미 생성됨, 설계 문서 커밋 `912f75b` 포함)

**전제:** 모든 명령은 `D:\vsCodeProg\APT-APP` 에서 실행. 한글 사용자 경로 회피용으로 빌드/테스트 전 환경변수 설정:
```powershell
$env:PUB_CACHE = "D:\PubCache"; $env:GRADLE_USER_HOME = "D:\GradleHome"
```
테스트 실행은 네트워크 불필요한 단위/위젯 테스트만 사용한다.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `lib/screens/public/slot_filter.dart` (신규) | `SlotFilter` enum + 순수 필터 술어/섹션 빌더. 위젯·프로바이더 의존성 없음 |
| `lib/providers/auth_provider.dart` (수정) | `AuthStage.guest` + `enterGuestMode()`/`exitGuestMode()` |
| `lib/main.dart` (수정) | `_RootNavigator`에 `AuthStage.guest` 분기 |
| `lib/screens/login_screen.dart` (수정) | "비회원으로 둘러보기" 버튼 |
| `lib/providers/app_state_provider.dart` (수정) | `_guestMode` + `startGuest()` + `refresh()` 데이터 소스 분기 + 게스트 캐시 미저장 |
| `lib/screens/public/guest_shell_screen.dart` (신규) | 게스트 3탭(목록/지도/이용안내) Shell + 로그인 CTA |
| `lib/screens/public/parking_list_screen.dart` (수정) | StatefulWidget 전환 + `SegmentedButton` + `slot_filter.dart` 사용 + 게스트 탭 SnackBar |
| `test/slot_filter_test.dart` (신규) | `slot_filter.dart` 단위 테스트 |
| `test/guest_shell_screen_test.dart` (신규) | 게스트 Shell 위젯 스모크 테스트 |

검증 결과 `lib/core/privacy.dart`의 `vehicleFor(SessionInfo? me, String raw)`는 이미 `me == null`을 안전 처리(`maskVehicle` 반환)하므로 **수정 불필요**.

---

## Task 1: SlotFilter 순수 모듈 + 단위 테스트

목록 필터의 모든 분류 로직을 위젯/프로바이더와 분리된 순수 함수로 만든다. 여기에 버그가 모이므로 TDD로 완전히 덮는다.

**Files:**
- Create: `lib/screens/public/slot_filter.dart`
- Test: `test/slot_filter_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

`test/slot_filter_test.dart`:

```dart
import 'package:apt_ev_charging/models/app_state.dart';
import 'package:apt_ev_charging/models/parking_slot.dart';
import 'package:apt_ev_charging/screens/public/slot_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 점유: vehicleNumber 있음 / 사용가능: 빈 detail / 주차불가: parkingBlocked
  const occupied = SlotDetail(vehicleNumber: '123가4567', startTime: '2026-05-18T00:00:00Z');
  const available = SlotDetail();
  const blocked = SlotDetail(parkingBlocked: true);

  group('slotMatchesFilter', () {
    test('all 은 모든 상태 통과', () {
      expect(slotMatchesFilter(occupied, SlotFilter.all), true);
      expect(slotMatchesFilter(available, SlotFilter.all), true);
      expect(slotMatchesFilter(blocked, SlotFilter.all), true);
    });

    test('occupied 는 점유된 것만', () {
      expect(slotMatchesFilter(occupied, SlotFilter.occupied), true);
      expect(slotMatchesFilter(available, SlotFilter.occupied), false);
      expect(slotMatchesFilter(blocked, SlotFilter.occupied), false);
    });

    test('available 은 점유X·주차불가X 만', () {
      expect(slotMatchesFilter(available, SlotFilter.available), true);
      expect(slotMatchesFilter(occupied, SlotFilter.available), false);
      expect(slotMatchesFilter(blocked, SlotFilter.available), false);
    });
  });

  group('filterSlots', () {
    final state = AppState.fromJson({
      'counts': {'fast50': 0, 'slow7': 0, 'slow3': 0},
      'slots': {
        'fast50': [
          {'id': 'fast50-1', 'typeId': 'fast50'},
          {'id': 'fast50-2', 'typeId': 'fast50'},
          {'id': 'fast50-3', 'typeId': 'fast50'},
        ],
      },
      'slotDetails': {
        'fast50-1': {'vehicleNumber': '123가4567', 'startTime': '2026-05-18T00:00:00Z'},
        'fast50-3': {'parkingBlocked': true},
      },
    });
    final slots = state.slots['fast50']!;

    test('all 은 3개 모두', () {
      expect(filterSlots(slots, state, SlotFilter.all).length, 3);
    });
    test('occupied 는 fast50-1 만', () {
      final r = filterSlots(slots, state, SlotFilter.occupied);
      expect(r.map((s) => s.id), ['fast50-1']);
    });
    test('available 은 fast50-2 만 (주차불가 fast50-3 제외)', () {
      final r = filterSlots(slots, state, SlotFilter.available);
      expect(r.map((s) => s.id), ['fast50-2']);
    });
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/slot_filter_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../slot_filter.dart'` (모듈 미존재)

- [ ] **Step 3: 최소 구현**

`lib/screens/public/slot_filter.dart`:

```dart
import '../../models/app_state.dart';
import '../../models/parking_slot.dart';

/// 목록 화면 세그먼트 필터.
enum SlotFilter { all, occupied, available }

/// 단일 SlotDetail 이 필터에 해당하는지.
/// - all: 항상 true
/// - occupied: 점유됨
/// - available: 점유X 이면서 주차불가X (관리자 차단 슬롯 제외)
bool slotMatchesFilter(SlotDetail detail, SlotFilter filter) {
  switch (filter) {
    case SlotFilter.all:
      return true;
    case SlotFilter.occupied:
      return detail.isOccupied;
    case SlotFilter.available:
      return !detail.isOccupied && !detail.parkingBlocked;
  }
}

/// 한 충전타입 섹션의 슬롯 목록을 필터로 거른다.
/// detail 이 없는 슬롯은 빈 SlotDetail 로 간주(=사용가능).
List<ParkingSlot> filterSlots(
  List<ParkingSlot> slots,
  AppState state,
  SlotFilter filter,
) {
  return slots
      .where((s) => slotMatchesFilter(
            state.slotDetails[s.id] ?? const SlotDetail(),
            filter,
          ))
      .toList(growable: false);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/slot_filter_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/public/slot_filter.dart test/slot_filter_test.dart
git commit -m "feat: SlotFilter 순수 모듈 + 단위 테스트"
```

---

## Task 2: AuthProvider 게스트 상태

**Files:**
- Modify: `lib/providers/auth_provider.dart` (enum at lines 12-39; methods near `markConsentRecorded` ~line 191)

- [ ] **Step 1: `AuthStage` enum 에 guest 추가**

`lib/providers/auth_provider.dart` 의 `enum AuthStage { ... }` 에서 `anonymous` 바로 다음 줄에 추가:

```dart
  /// 비로그인
  anonymous,

  /// 비회원 게스트 — 읽기 전용 주차 현황 모니터링
  guest,
```

- [ ] **Step 2: enter/exit 메서드 추가**

`markConsentRecorded()` 메서드 정의 바로 위(또는 아래)에 추가:

```dart
  /// 로그인 화면에서 "비회원으로 둘러보기" 진입. 비지속(캐시 기록 없음).
  void enterGuestMode() {
    _stage = AuthStage.guest;
    _errorMessage = null;
    notifyListeners();
  }

  /// 게스트 → 로그인 화면 복귀.
  void exitGuestMode() {
    if (_stage == AuthStage.guest) {
      _stage = AuthStage.anonymous;
      notifyListeners();
    }
  }
```

- [ ] **Step 3: 정적 분석 확인**

Run: `flutter analyze lib/providers/auth_provider.dart`
Expected: `No issues found!` (단, 다음 Task 전까지 `main.dart` switch 가 guest 케이스 누락으로 경고날 수 있음 — Task 3에서 해소. 이 단계에서는 auth_provider.dart 자체만 분석)

- [ ] **Step 4: 커밋**

```bash
git add lib/providers/auth_provider.dart
git commit -m "feat: AuthStage.guest + enter/exitGuestMode"
```

---

## Task 3: _RootNavigator 게스트 분기 + 로그인 화면 진입 버튼

**Files:**
- Modify: `lib/main.dart` (`_RootNavigator.build` switch, lines 66-84)
- Modify: `lib/screens/login_screen.dart` (Google 버튼 아래, line 47 이후)

- [ ] **Step 1: main.dart import + switch 분기 추가**

`lib/main.dart` 상단 import 목록에 추가 (기존 `screens/public/shell_screen.dart` import 옆):

```dart
import 'screens/public/guest_shell_screen.dart';
```

`_RootNavigator.build` 의 `switch (auth.stage)` 에서 `case AuthStage.anonymous:` 다음에 추가:

```dart
      case AuthStage.anonymous:
        return const LoginScreen();
      case AuthStage.guest:
        return const GuestShellScreen();
```

- [ ] **Step 2: 로그인 화면에 게스트 버튼 추가**

`lib/screens/login_screen.dart` 의 Google `ElevatedButton.icon(...)` 위젯 닫는 `),` 다음(에러 메시지 `if (err != null ...)` 블록 앞)에 추가:

```dart
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: auth.isBusy
                    ? null
                    : () => context.read<AuthProvider>().enterGuestMode(),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('비회원으로 둘러보기'),
              ),
```

`login_screen.dart` 상단에 `provider` import 가 없으면 추가:

```dart
import 'package:provider/provider.dart';
```

(이미 `import '../providers/auth_provider.dart';` 존재)

- [ ] **Step 3: 정적 분석 확인 (guest_shell 미존재로 실패 예상)**

Run: `flutter analyze lib/main.dart lib/screens/login_screen.dart`
Expected: FAIL — `Target of URI doesn't exist: 'screens/public/guest_shell_screen.dart'`. 다음 Task 4에서 파일 생성 후 해소. (분석 실패는 예상된 중간 상태)

- [ ] **Step 4: 커밋**

```bash
git add lib/main.dart lib/screens/login_screen.dart
git commit -m "feat: _RootNavigator guest 분기 + 로그인 화면 게스트 진입 버튼"
```

---

## Task 4: AppStateProvider 게스트 데이터 소스

**Files:**
- Modify: `lib/providers/app_state_provider.dart` (필드 ~line 24-30, `start()` lines 58-70, `refresh()` lines 77-98)

- [ ] **Step 1: guestMode 필드 추가**

`lib/providers/app_state_provider.dart` 의 `bool _started = false;` 다음 줄에 추가:

```dart
  bool _started = false;
  bool _guestMode = false;
```

게터도 추가 (`DateTime? get lastUpdated => _lastUpdated;` 다음 줄):

```dart
  bool get isGuestMode => _guestMode;
```

- [ ] **Step 2: startGuest() 추가**

`start()` 메서드 정의 전체 다음에 추가:

```dart
  /// 게스트 진입 시 호출. /api/public-dashboard 에서 점유 여부만 받는다.
  /// 영속 캐시는 사용하지 않는다(회원 PII 캐시와 분리).
  Future<void> startGuest() async {
    _guestMode = true;
    _started = true;
    await refresh();
    _startPollTimer();
  }
```

- [ ] **Step 3: refresh() 데이터 소스 분기**

`refresh()` 안의 다음 줄을:

```dart
      _state = await _services.state.fetch();
```

아래로 교체:

```dart
      _state = _guestMode
          ? await _services.publicDashboard.fetch()
          : await _services.state.fetch();
```

그리고 같은 `try` 블록 안의 캐시 저장 줄:

```dart
      unawaited(StateCache.save(_state));
```

을 게스트 가드로 교체:

```dart
      if (!_guestMode) unawaited(StateCache.save(_state));
```

- [ ] **Step 4: reset() 에서 guestMode 해제**

`reset()` 메서드 안 `_started = false;` 다음 줄에 추가:

```dart
    _started = false;
    _guestMode = false;
```

- [ ] **Step 5: 정적 분석 확인**

Run: `flutter analyze lib/providers/app_state_provider.dart`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/providers/app_state_provider.dart
git commit -m "feat: AppStateProvider 게스트 데이터 소스(public-dashboard) + 캐시 분리"
```

---

## Task 5: GuestShellScreen + 위젯 스모크 테스트

**Files:**
- Create: `lib/screens/public/guest_shell_screen.dart`
- Create: `test/guest_shell_screen_test.dart`

- [ ] **Step 1: 실패하는 위젯 테스트 작성**

`test/guest_shell_screen_test.dart`:

```dart
import 'package:apt_ev_charging/providers/app_state_provider.dart';
import 'package:apt_ev_charging/providers/auth_provider.dart';
import 'package:apt_ev_charging/providers/connectivity_provider.dart';
import 'package:apt_ev_charging/screens/public/guest_shell_screen.dart';
import 'package:apt_ev_charging/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('GuestShellScreen 은 3탭(목록/지도/이용안내) + 로그인 CTA 노출', (tester) async {
    final services = ApiServices.from(_FakeClient());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(services)),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(create: (_) => AppStateProvider(services)),
          Provider.value(value: services),
        ],
        child: const MaterialApp(home: GuestShellScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('목록'), findsWidgets);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('이용안내'), findsWidgets);
    expect(find.text('로그인하기'), findsOneWidget);
  });
}
```

> 참고: `_FakeClient` 는 실제 네트워크를 타지 않게 하기 위한 최소 stub. `ApiServices.from` 은 `ApiClient` 를 받지만 위젯 빌드 시점에 네트워크 호출이 일어나지 않도록 `GuestShellScreen.initState` 의 `startGuest()` 는 `addPostFrameCallback` 으로 미루고, 테스트는 `tester.pump()` 1회만 호출해 첫 프레임만 검증한다. `_FakeClient` 가 필요하면 다음 Step 에서 함께 정의.

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/guest_shell_screen_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../guest_shell_screen.dart'`

- [ ] **Step 3: GuestShellScreen 구현**

`lib/screens/public/guest_shell_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import 'guide_screen.dart';
import 'map_view_screen.dart';
import 'parking_list_screen.dart';

/// 비회원 게스트 진입 Shell. 읽기 전용 3탭.
class GuestShellScreen extends StatefulWidget {
  const GuestShellScreen({super.key});

  @override
  State<GuestShellScreen> createState() => _GuestShellScreenState();
}

class _GuestShellScreenState extends State<GuestShellScreen> {
  int _index = 0;

  static const _screens = <Widget>[
    ParkingListScreen(),
    MapViewScreen(),
    GuideScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppStateProvider>().startGuest();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Material(
            color: Colors.blue.shade50,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        '비회원 모드 — 현재 주차 현황만 볼 수 있습니다.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<AuthProvider>().exitGuestMode(),
                      child: const Text('로그인하기'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _screens[_index]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: '목록'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: '지도'),
          NavigationDestination(
              icon: Icon(Icons.help_outline), label: '이용안내'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트의 `_FakeClient` 보강 (네트워크 차단)**

`test/guest_shell_screen_test.dart` 에서 `ApiServices.from(_FakeClient())` 가 컴파일되도록, 실제 `ApiClient` 생성이 어려우면 테스트를 다음과 같이 단순화한다 — Step 1 의 import/본문을 아래로 교체:

```dart
import 'package:apt_ev_charging/screens/public/guest_shell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GuestShellScreen 구조: 3탭 라벨 + 로그인 CTA', (tester) async {
    // Provider 미제공 상태에서 첫 프레임만 검증.
    // initState 의 startGuest 는 addPostFrameCallback 이라 pump 1회 전에는 미실행.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: GuestShellScreen())));
    // 첫 빌드만 — provider 접근(post-frame) 전 프레임 검증.
    expect(find.text('목록'), findsWidgets);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('이용안내'), findsWidgets);
    expect(find.text('로그인하기'), findsOneWidget);
  });
}
```

> 이 테스트는 `context.read` 가 post-frame callback 안에서만 호출되므로 첫 빌드(NavigationBar + 배너)는 Provider 없이 렌더된다. `tester.pump()` 를 호출하지 않아 post-frame callback 이 실행되지 않는다.

- [ ] **Step 5: 테스트 통과 확인**

Run: `flutter test test/guest_shell_screen_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: 전체 정적 분석 (Task 3 경고 해소 확인)**

Run: `flutter analyze lib/main.dart lib/screens/login_screen.dart lib/screens/public/guest_shell_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: 커밋**

```bash
git add lib/screens/public/guest_shell_screen.dart test/guest_shell_screen_test.dart
git commit -m "feat: GuestShellScreen 3탭 + 위젯 스모크 테스트"
```

---

## Task 6: ParkingListScreen 필터 통합 + 게스트 탭 피드백

**Files:**
- Modify: `lib/screens/public/parking_list_screen.dart` (전체 구조 변경: Stateless→Stateful)

- [ ] **Step 1: import 추가**

`lib/screens/public/parking_list_screen.dart` 상단 import 에 추가:

```dart
import 'slot_filter.dart';
```

- [ ] **Step 2: StatelessWidget → StatefulWidget 전환**

`class ParkingListScreen extends StatelessWidget {` 선언부터 `build` 전까지를 아래로 교체 (기존 `_onTap` 메서드 본문은 그대로 `State` 클래스로 이동):

```dart
class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key});

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  SlotFilter _filter = SlotFilter.all;

  Future<void> _onTap(BuildContext context, ParkingSlot slot) async {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppStateProvider>();
    final session = auth.session;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    final detail = app.state.slotDetails[slot.id] ?? const SlotDetail();
    final result = await showSlotDialog(
      context,
      slot: slot,
      currentDetail: detail,
      appState: app.state,
      session: session,
    );
    if (result == null) return;
    try {
      switch (result.action) {
        case SlotDialogAction.park:
          if (result.detail != null) {
            await app.upsertSlotDetail(slotId: slot.id, detail: result.detail!);
          }
          break;
        case SlotDialogAction.checkout:
          await app.clearSlotDetail(slot.id);
          break;
        case SlotDialogAction.toggleBlocked:
          await app.toggleSlotBlocked(slot.id);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
```

> 변경점: `if (session == null) return;` → SnackBar 안내 후 return. 나머지 `_onTap` 로직 동일.

- [ ] **Step 3: build() — SegmentedButton + 필터링 적용**

`build` 메서드 전체를 아래로 교체:

```dart
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppStateProvider>();
    final state = app.state;

    // 필터 적용 후 비어있지 않은 섹션만 노출.
    final visibleTypes = <int>[];
    for (var i = 0; i < chargerTypes.length; i++) {
      final all = state.slots[chargerTypes[i].id] ?? const [];
      if (filterSlots(all, state, _filter).isNotEmpty) visibleTypes.add(i);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('전체 주차칸'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isLoading ? null : app.refresh,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<SlotFilter>(
              segments: const [
                ButtonSegment(value: SlotFilter.all, label: Text('전체')),
                ButtonSegment(value: SlotFilter.occupied, label: Text('사용중')),
                ButtonSegment(value: SlotFilter.available, label: Text('미사용')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: app.refresh,
        child: visibleTypes.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('조건에 맞는 주차칸이 없습니다.')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: visibleTypes.length,
                itemBuilder: (_, idx) {
                  final type = chargerTypes[visibleTypes[idx]];
                  final allSlots = state.slots[type.id] ?? const [];
                  final shown = filterSlots(allSlots, state, _filter);
                  var occupied = 0;
                  for (final s in allSlots) {
                    final d = state.slotDetails[s.id];
                    if (d != null && d.isOccupied) occupied++;
                  }
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: ChargerColors.forBadgeClass(type.badgeClass),
                        width: 3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                type.name,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$occupied / ${allSlots.length}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(type.description,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                          const Divider(),
                          for (final s in shown) _row(context, s, state),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
```

> 섹션 헤더 카운트 `$occupied / ${allSlots.length}` 는 **필터와 무관하게 전체 점유/총량** 유지(설계 §4). 행은 `shown`(필터링됨)만 렌더.

- [ ] **Step 4: 클래스 닫는 괄호 확인**

`_row(...)` 와 `_elapsedSinceStart(...)` 메서드는 그대로 `_ParkingListScreenState` 클래스 안에 위치해야 한다. 파일 끝 클래스 닫는 `}` 가 `_elapsedSinceStart` 다음에 정확히 1개 있는지 확인.

- [ ] **Step 5: 정적 분석**

Run: `flutter analyze lib/screens/public/parking_list_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: 커밋**

```bash
git add lib/screens/public/parking_list_screen.dart
git commit -m "feat: 목록 전체/사용중/미사용 SegmentedButton 필터 + 게스트 탭 안내"
```

---

## Task 7: 전체 검증

**Files:** 없음 (검증 전용)

- [ ] **Step 1: 전체 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: 전체 단위/위젯 테스트**

Run: `flutter test`
Expected: 모든 테스트 PASS (기존 + slot_filter_test 8 + guest_shell_screen_test 1)

- [ ] **Step 3: 수동 검증 시나리오 (디버그 빌드, 기기/에뮬레이터)**

Run: `flutter run --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com --dart-define=APP_ENV=prod`

확인 항목:
- 로그인 화면에 "비회원으로 둘러보기" 노출 → 탭 → 게스트 3탭 Shell 진입
- 게스트 배너 + "로그인하기" → 로그인 화면 복귀
- 게스트 목록: 차량번호/경과시간 미표시(점유 여부만), 슬롯 탭 시 "로그인이 필요합니다" SnackBar
- 게스트 지도/이용안내 탭 정상 렌더 (세션 강제요구 없음 — 요구 시 가드 추가 필요)
- 전체/사용중/미사용 전환 시 행 즉시 갱신, 빈 결과 시 placeholder, 섹션 헤더 카운트는 전체값 유지
- 회원 로그인 후 동일 목록 화면에서 필터 정상 동작 + 슬롯 탭 시 기존 다이얼로그 정상

> Step 3 에서 지도/이용안내가 세션을 강제 요구해 깨지면, 해당 화면에 게스트 가드(읽기전용 분기)를 추가하는 후속 태스크가 필요하다. 깨지지 않으면 추가 작업 없음.

- [ ] **Step 4: 브랜치 푸시**

```bash
git push -u origin feature/guest-mode-and-list-filter
```

---

## Self-Review 결과

- **스펙 커버리지:** 게스트 진입(T2,T3)·범위 3탭(T5)·데이터 소스 public-dashboard+캐시분리(T4)·PII(privacy.dart 무수정 확인)·필터 의미 all/occupied/available(T1)·주차불가 전체에서만(T1 available 술어)·섹션 헤더 전체값(T6 §Step3)·게스트 탭 피드백(T6 §Step2)·테스트(T1,T5,T7) — 스펙 §2~§7 전 항목 태스크 매핑됨.
- **Placeholder:** 없음. 모든 코드 스텝에 실제 코드 포함.
- **타입 일관성:** `SlotFilter`(T1) → 전 태스크 동일 사용. `slotMatchesFilter`/`filterSlots` 시그니처 T1 정의와 T6 호출 일치. `enterGuestMode`/`exitGuestMode`(T2) → main.dart/login_screen/guest_shell 호출 일치. `startGuest()`(T4) → guest_shell initState 호출 일치.
- **엣지:** 지도/이용안내 세션 강제요구 가능성은 T7 Step3 에서 검증·후속조치 명시 (스펙 §5 반영).
