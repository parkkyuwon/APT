# 비회원(게스트) 모드 + 목록 필터 설계

작성일: 2026-05-18
대상: APT-APP (Flutter)

## 1. 목표

1. **비회원 모드**: 로그인 없이 현재 주차 현황을 **읽기 전용**으로 모니터링.
2. **목록 필터**: 주차 목록 화면에 **전체 / 사용중 / 미사용** 3분할 세그먼트 필터 추가 (회원·게스트 공용).

## 2. 요구사항 (확정)

| 항목 | 결정 |
|---|---|
| 게스트 접근 범위 | 목록 + 지도 + 이용안내 (읽기 전용) |
| 게스트 정보 수위 | 점유 여부만 — 차량번호·연락처·소유자·경과시간 등 PII 전부 비표시 |
| 게스트 데이터 소스 | `/api/public-dashboard` (PublicDashboardApi) |
| 필터 적용 대상 | 회원 + 게스트 모두 (공용 `ParkingListScreen`) |
| 필터 의미 | 전체=모든 슬롯 / 사용중=점유됨 / 미사용=사용가능만(주차불가 제외) |
| 주차불가 슬롯 | "전체"에서만 표시 |
| 게스트 지속성 | 비지속 — 앱 재시작 시 로그인 화면부터. 등록 회원만 기존 세션으로 자동 로그인 |

## 3. 아키텍처 (접근법 A: `AuthStage.guest` 1급 상태)

기존 `_RootNavigator`가 `AuthStage` 기반으로 화면을 분기하므로, 게스트를 enum 1급 상태로 추가하는 것이 기존 패턴과 일관되고 데이터 소스 분기를 한 곳에 모은다.

### 3.1 인증 & 라우팅

**`lib/providers/auth_provider.dart`**
- `enum AuthStage`에 `guest` 추가.
- `enterGuestMode()`: `_stage = AuthStage.guest; notifyListeners();` — `SessionInfoCache` 기록 없음(비지속).
- `exitGuestMode()`: `_stage = AuthStage.anonymous; notifyListeners();`.
- `bootstrap()` 무변경. 등록 회원은 기존 세션 쿠키 + `SessionInfoCache`로 자동 로그인. 게스트는 인메모리 상태라 재시작 시 소멸.

**`lib/main.dart` `_RootNavigator`**
- `case AuthStage.guest: return const GuestShellScreen();` 추가.

**`lib/screens/login_screen.dart`**
- Google 로그인 버튼 아래 `TextButton` "비회원으로 둘러보기" → `context.read<AuthProvider>().enterGuestMode()`.

### 3.2 게스트 Shell

**`lib/screens/public/guest_shell_screen.dart` (신규)**
- `StatefulWidget`. `initState`에서 `context.read<AppStateProvider>().startGuest()` 호출.
- 하단 3탭 `NavigationBar`: 목록(`ParkingListScreen`) · 지도(`MapViewScreen`) · 이용안내(`GuideScreen`).
- 상단 안내 배너 + "로그인하기" 액션 → `auth.exitGuestMode()`.
- 회원용 `ShellScreen`(5탭)은 무변경 — 별도 위젯으로 분리해 책임 분리.

### 3.3 데이터 소스 전환

**`lib/providers/app_state_provider.dart`**
- `bool _guestMode = false` 필드 추가.
- `startGuest()`: `_guestMode = true` 설정 후 캐시 로드 생략, `refresh()` + 폴링 시작.
- `refresh()` 분기:
  - `_guestMode == true` → `_services.publicDashboard.fetch()`
  - else → 기존 `_services.state.fetch()`
  - 둘 다 `AppState` 반환 → 화면단 무변경.
- 게스트 모드에서는 `StateCache.save()` 호출 안 함 (회원 PII 캐시와 분리, 인메모리 + 30초 폴링만).
- `stop()`/lifecycle 폴링 로직 재사용.

## 4. 목록 필터

**`lib/screens/public/parking_list_screen.dart`**
- `StatelessWidget` → `StatefulWidget` 전환 (필터 상태 보유).
- `enum SlotFilter { all, occupied, available }`.
- AppBar `bottom`에 `PreferredSize`로 `SegmentedButton<SlotFilter>` 배치 — 라벨 전체/사용중/미사용. (스크롤과 무관하게 항상 고정 노출)
- 필터 술어:
  - `all`: 전체
  - `occupied`: `detail.isOccupied`
  - `available`: `!detail.isOccupied && !detail.parkingBlocked`
- 섹션(충전타입 카드):
  - 각 섹션 슬롯을 필터링 후 행 렌더.
  - 필터 적용 시 매칭 0개 섹션 카드 숨김 ("전체"는 모든 섹션 표시).
  - 전 섹션 비면 "조건에 맞는 주차칸이 없습니다" placeholder.
- 섹션 헤더 카운트 `점유 / 총개수`: 필터와 무관하게 실제 점유/총량 유지 (전체 현황 파악용).
- 게스트 슬롯 탭: `_onTap`이 `session == null`이면 무시 → "로그인이 필요합니다" SnackBar로 피드백. 회원 동작 무변경.

## 5. 개인정보 · 엣지 케이스

- 게스트 데이터(`/api/public-dashboard`)에는 `vehicleNumber`/`contact`/`ownerEmail`/`startTime` 부재 → `_row`에서 자연히 미표시.
- `core/privacy.dart`의 `vehicleFor(session, ...)`가 `session == null`을 안전 처리하는지 구현 시 검증, 미흡하면 보강.
- `MapViewScreen`·`GuideScreen`이 세션을 강제 요구하지 않는지 구현 시 점검, 요구 시 게스트 가드 추가.
- 게스트 데이터 fetch 실패: 기존 `AppStateProvider.errorMessage` + 당겨서 새로고침 재시도.
- 게스트 → "로그인하기" → 로그인 성공: 기존 `_applyBootstrap` 흐름으로 stage 전환.

## 6. 테스트

- 단위:
  - `SlotFilter` 술어 분류 (사용중/미사용/주차불가).
  - `AuthProvider.enterGuestMode/exitGuestMode` 상태 전이.
  - `AppStateProvider`가 `_guestMode`에 따라 올바른 서비스(`publicDashboard` vs `state`) 호출.
- 위젯:
  - `ParkingListScreen` 필터별 행 렌더링 + 빈 상태 placeholder.
  - `GuestShellScreen` 3탭 + 로그인 CTA 노출.

## 7. 범위 제외 (YAGNI)

- 게스트 모드 지속(SharedPreferences).
- 게스트용 별도 영속 캐시.
- 4번째 필터(주차불가 단독) — 3분할 유지.

## 8. 변경 파일 요약

| 파일 | 변경 |
|---|---|
| `lib/providers/auth_provider.dart` | `AuthStage.guest` + enter/exitGuestMode |
| `lib/main.dart` | `_RootNavigator`에 guest 분기 |
| `lib/screens/login_screen.dart` | "비회원으로 둘러보기" 버튼 |
| `lib/screens/public/guest_shell_screen.dart` | 신규 — 3탭 게스트 Shell |
| `lib/providers/app_state_provider.dart` | `_guestMode` + `startGuest()` + `refresh()` 분기 + 캐시 분리 |
| `lib/screens/public/parking_list_screen.dart` | StatefulWidget 전환 + `SlotFilter` 세그먼트 + 필터링 + 게스트 탭 피드백 |
| `core/privacy.dart` (조건부) | `vehicleFor` null 세션 안전 처리 보강 (검증 후) |
| `test/` | 단위·위젯 테스트 추가 |
