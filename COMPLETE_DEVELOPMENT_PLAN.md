# 📋 APT EV Charging 앱 - 완전한 개발 계획

## 🎯 프로젝트 개요

**목표**: 웹사이트의 모든 기능을 Android/iOS 앱에서 구현
**기술 스택**: Flutter, Dart, REST API
**개발 기간**: 4-6주(예상)

---

## 📊 Phase별 상세 계획

### **Phase 1: 기본 구조 및 인증 (1-2주)**

#### 1.1 프로젝트 기본 설정
- ✅ 소스 통합 관리 (pubspec.yaml)
- ✅ 패키지 설정
- ✅ 스크린 네비게이션 구조

#### 1.2 테마 및 UI 기본설정
```dart
주요 색상:
- 초록: #4CAF50 (사용 가능)
- 파란색: #2196F3 (사용 중)
- 주황: #FF9800 (유지보수)
- 빨강: #F44336 (에러)

폰트:
- 한글: Noto Sans KR (비 굵기)
- 스케일: 1.0 - 1.5배율
```

#### 1.3 라우팅 설정
```
화면 구조:
├── SplashScreen (로딩)
├── LoginScreen (Google OAuth)
├── HomeScreen (메인 - 탭 네비게이션)
│   ├── MapTab (주차 지도)
│   ├── StatsTab (통계)
│   ├── HistoryTab (이력)
│   ├── ProfileTab (프로필)
│   └── SettingsTab (설정)
├── AdminScreen (관리자)
│   ├── DashboardTab
│   ├── UsersTab
│   ├── ParkingTab
│   └── StatsTab
└── ParkingDetailScreen (주차 등록)
```

---

### **Phase 2: 사용자 인증 및 프로필 (1주)**

#### 2.1 Google OAuth 구현
```dart
패키지: google_sign_in: ^7.1.0
- Google 로그인 버튼
- 세션 관리
- 토큰 갱신
- 로그아웃
```

#### 2.2 사용자 정보 관리
```dart
class User {
  String email;
  String? nickname;
  String? vehicleNumber;
  String? contact;
  bool contactVisible;
  UserRole role; // pending, approved, admin, rejected, blocked
  DateTime? approvedAt;
  DateTime createdAt;
}

enum UserRole {
  pending,      // 승인 대기
  approved,     // 일반 사용자
  admin,        // 관리자
  rejected,     // 거절
  blocked       // 차단
}
```

#### 2.3 프로필 수정 화면
- 필드: 닉네임, 차량번호, 연락처, 공개 여부
- 유효성 검사
- 저장 기능

---

### **Phase 3: 주차 관리 기능 (2주)**

#### 3.1 주차 지도 화면
```dart
// 기능
- B1, B2 층 선택
- 주차칸 시각화 (그리드 또는 지도)
- 실시간 상태 표시
- 탭해서 주차 등록

// 상태 표시
🟢 사용 가능
🔵 사용 중
🟠 유지보수
```

#### 3.2 주차 등록 폼
```dart
필수 입력:
- 차량번호
- 연락처
- 연락처 공개 여부 (선택)
- 시작 시간
- 예상 출차 시간
- 충전 시간 (50분, 1시간, 1.5시간, 2시간 등)

유효성:
- 한 계정당 1개 주차만 등록 가능
- 시간 형식 검증
- 필수 필드 확인
```

#### 3.3 충전소 정보 데이터
```dart
const CHARGERS = {
  'B1': {
    'fast50': {'count': 1, 'name': '50kW 급속'}, // slots: B1-50kW-1
    'mid7': {'count': 2, 'name': '7kW 완속'},    // slots: B1-7kW-1, B1-7kW-2
    'slow3': {'count': 2, 'name': '3kW 완속'},   // slots: B1-3kW-1, B1-3kW-2
  },
  'B2': {
    'fast50': {'count': 2, 'name': '50kW 급속'}, // B2-50kW-1, B2-50kW-2
    'mid7': {'count': 9, 'name': '7kW 완속'},    // B2-7kW-1 ~ B2-7kW-9
    'slow3': {'count': 12, 'name': '3kW 완속'},  // B2-3kW-1 ~ B2-3kW-12
  },
};
```

#### 3.4 예약 이력 화면
- 현재 주차
- 과거 주차 이력
- 예약된 주차
- 취소된 주차

---

### **Phase 4: 관리자 기능 (2주)**

#### 4.1 관리자 대시보드
```dart
화면 구성:
┌─────────────────────┐
│  주차 현황 통계       │
│  B1: 3/5 사용 중     │
│  B2: 12/23 사용 중   │
│  총: 15/28 사용 중    │
└─────────────────────┘

차트:
- 시간별 점유율
- 층별 비교
- 충전기 유형별 현황
```

#### 4.2 사용자 관리
```dart
기능:
- 사용자 목록 조회
- 상태별 필터링
  - 승인 대기 (pending)
  - 승인됨 (approved)
  - 관리자 (admin)
  - 거절 (rejected)
  - 차단 (blocked)

액션:
- 승인하기 → approved
- 관리자 승인 → admin
- 거절하기 → rejected
- 차단하기 → blocked
- 차단 해제
```

#### 4.3 주차 관리
```dart
기능:
- 모든 주차칸 조회
- 상태 변경 (사용가능 ↔ 유지보수)
- 사진 업로드
- 강제 취소

필드 수정:
- 차량번호
- 연락처
- 시작 시간
- 출차 시간
- 충전 시간
```

#### 4.4 공지사항 관리
```dart
필드:
- 제목
- 내용
- 자동 닫기 시간
- 활성화 여부

기능:
- 작성
- 수정
- 삭제
- 미리보기
```

---

### **Phase 5: 데이터 동기화 및 실시간 기능 (2주)**

#### 5.1 데이터 모델
```dart
Parking (주차 정보)
├── id: String
├── slotId: String
├── userEmail: String
├── vehicleNumber: String
├── startTime: DateTime
├── departureTime: DateTime
├── chargeDuration: String
├── contact: String
├── contactVisible: bool
├── status: ParkingStatus
├── createdAt: DateTime
└── updatedAt: DateTime

ParkingSlot (주차칸)
├── id: String (예: "B1-50kW-1")
├── floor: String (B1, B2)
├── chargerType: String (fast50, mid7, slow3)
├── position: Map<String, dynamic> {x, y}
├── imageUrl: String
├── status: SlotStatus
└── unavailable: bool (유지보수)
```

#### 5.2 실시간 업데이트
```dart
// WebSocket 또는 Polling
- 60초마다 자동 동기화
- 충전소 상태 값 실시간 갱신
- 새 사용자 추가 알림 (관리자)
```

#### 5.3 로컬 캐싱
```dart
- 사용자 정보 캐시 (30분)
- 주차 정보 캐시 (5분)
- 오프라인 모드 (캐시 데이터 표시)
```

---

### **Phase 6: 배포 (1주)**

#### 6.1 성능 최적화
- 번들 크기 최소화
- 이미지 최적화
- 렌더링 성능 개선

#### 6.2 보안 강화
- API 토큰 암호화
- 민감 정보 보호
- HTTPS 적용

#### 6.3 플랫폼 배포
- Google Play Store (Android)
- Apple App Store (iOS)
- 버전 관리

---

## 🏗️ 기술 아키텍처

### 폴더 구조
```
lib/
├── main.dart
├── models/
│   ├── user.dart
│   ├── parking.dart
│   ├── slot.dart
│   └── statistics.dart
├── screens/
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── admin_screen.dart
│   ├── profile_screen.dart
│   └── parking_detail_screen.dart
├── services/
│   ├── api_service.dart
│   ├── auth_service.dart
│   ├── cache_service.dart
│   └── realtime_service.dart
├── widgets/
│   ├── parking_grid.dart
│   ├── stats_card.dart
│   ├── user_table.dart
│   └── parking_form.dart
├── providers/
│   ├── auth_provider.dart
│   ├── parking_provider.dart
│   └── user_provider.dart
└── utils/
    ├── constants.dart
    ├── validators.dart
    └── formatters.dart
```

### 상태 관리
```dart
사용 도구: Provider 또는 Riverpod
- AuthProvider: 로그인, 로그아웃, 권한 관리
- ParkingProvider: 주차 정보 조회, 등록, 수정
- UserProvider: 사용자 정보, 프로필 수정
- StatisticsProvider: 통계 데이터
```

### API 엔드포인트
```
POST /api/auth/login           # 로그인
POST /api/auth/logout          # 로그아웃

GET /api/users/profile         # 내 정보 조회
PATCH /api/users/profile       # 내 정보 수정

GET /api/parking               # 주차 정보 조회
POST /api/parking              # 주차 등록
PATCH /api/parking/{id}        # 주차 수정
DELETE /api/parking/{id}       # 주차 취소

GET /api/admin/users           # 사용자 목록 (관리자)
PATCH /api/admin/users/{email} # 사용자 승인 (관리자)
GET /api/admin/statistics      # 통계 (관리자)
```

---

## 📱 화면별 상세 설계

### 1. 로그인 화면 (LoginScreen)
```
┌──────────────────────────┐
│   APT EV Charging        │
│                          │
│                          │
│   [Google 로그인]        │
│   [로그인 비스]          │
│                          │
│  처음 접속한 계정은      │
│  관리자 승인 후 이용     │
│  가능합니다.             │
└──────────────────────────┘
```

### 2. 홈 화면 - 지도 탭 (MapScreen)
```
┌──────────────────────────┐
│ ◀ 홈  B1   B2   ⟳       │
├──────────────────────────┤
│  3/5 사용 중             │
├──────────────────────────┤
│  [🟢][🟢][🔵]           │
│  [🟠][🟢][🔵]           │
│  [🔵][🟢][🟢]           │
├──────────────────────────┤
│ 🏠 지도 📊 통계 ⚙ 설정 │
└──────────────────────────┘
```

### 3. 주차 등록 다이얼로그
```
┌──────────────────────────┐
│ 주차 등록하기              │
├──────────────────────────┤
│ 차량번호:  [입력]         │
│ 연락처:    [입력]         │
│ 공개여부:  [토글]         │
│                          │
│ 시작시간:  [시간선택]     │
│ 출차시간:  [시간선택]     │
│ 충전시간:  [선택]         │
│    • 30분                │
│    • 1시간               │
│    • 1.5시간             │
│                          │
│  [취소]  [주차하기]      │
└──────────────────────────┘
```

### 4. 관리자 대시보드 (AdminDashboard)
```
┌──────────────────────────┐
│ 관리자 대시보드            │
├──────────────────────────┤
│ 📊 주차 현황              │
│ B1: 3/5 (60%)           │
│ B2: 12/23 (52%)         │
│ 계: 15/28 (54%)         │
├──────────────────────────┤
│ 📈 시간별 점유율          │
│ [그래프]                 │
├──────────────────────────┤
│ 👥 사용자 관리            │
│ 승인대기: 3건             │
│ 승인됨: 25건              │
│ 관리자: 2건               │
├──────────────────────────┤
│ 📋 주차 관리              │
│ [주차칸 목록]            │
└──────────────────────────┘
```

---

## 🔄 개발 순서 (추천)

1. ✅ **기본 구조 완성** (이미 진행 중)
2. ⏳ **로그인 & 인증** (Phase 1)
3. ⏳ **사용자 프로필** (Phase 2)
4. ⏳ **주차 등록/조회** (Phase 3)
5. ⏳ **지도 화면** (Phase 3)
6. ⏳ **관리자 기능** (Phase 4)
7. ⏳ **실시간 동기화** (Phase 5)
8. ⏳ **배포** (Phase 6)

---

## 📈 예상 일정

| Phase | 기간 | 현황 |
|-------|------|------|
| 1 | 1-2주 | ⏳ 계획 중 |
| 2 | 1주   | ⏳ 계획 중 |
| 3 | 2주   | ⏳ 계획 중 |
| 4 | 2주   | ⏳ 계획 중 |
| 5 | 2주   | ⏳ 계획 중 |
| 6 | 1주   | ⏳ 계획 중 |
| **총** | **9-11주** | **✅ 준비 완료** |

---

## ✅ 체크리스트

### 시작 전
- [ ] Google Cloud OAuth 설정
- [ ] Firebase (선택사항) 설정
- [ ] API 서버 준비
- [ ] 디자인 시안 확정

### 개발 중
- [ ] 단위 테스트 작성
- [ ] 통합 테스트
- [ ] UI/UX 검증
- [ ] 보안 감시

### 배포 전
- [ ] 성능 최적화
- [ ] 보안 심사
- [ ] 스토어 심사
- [ ] 문서 작성

---

**준비 완료! 🚀 이제 Phase 1 개발을 시작할 수 있습니다!**
