# APT EV 충전 — 배포 런북 (Play Store 프로덕션)

Phase 6 의 모든 단계를 순차 실행할 수 있는 체크리스트. **상단부터 순서대로 수행**.

---

## 0. 사전 준비 (한 번만)

### 0.1 Google Play Developer 계정
- [ ] [Google Play Console](https://play.google.com/console) 접속
- [ ] **$25 (약 33,000원) 일회성 등록비 결제** — 크레디트 카드 필요
- [ ] 개발자 이름, 연락처 이메일, 주소 입력
- [ ] 본인 인증 (여권/주민등록증 사진)
- [ ] 승인 대기 (보통 48시간 이내)

### 0.2 개인정보 URL 배포
1. Vercel 프로젝트에 다음 파일이 있는지 확인:
   - `D:/vsCodeProg/APT-Prj/privacy.html`  ✅ 생성됨
   - `D:/vsCodeProg/APT-Prj/account-deletion.html`  ✅ 생성됨
2. APT-Prj git push → Vercel 자동 배포
3. 접근 확인:
   - https://apt-ev-charging.vercel.app/privacy.html
   - https://apt-ev-charging.vercel.app/account-deletion.html

### 0.3 앱 아이콘 / 스크린샷
- [ ] `assets/images/app_icon.png` (1024×1024) 생성
- [ ] `assets/images/app_icon_foreground.png` (1024×1024, 투명) 생성
- [ ] `feature_graphic.png` (1024×500) 생성
- [ ] 스크린샷 6장 촬영 (1080×1920)
  - 로그인, 홈, 주차 등록, 내 정보, 대화방, 관리자 허브

→ 상세 가이드: [assets/images/README.md](assets/images/README.md)

---

## 1. 업로드 키스토어 생성

⚠️ **이 파일을 분실하면 앱 업데이트가 영구 불가능합니다. 즉시 백업하세요.**

### 1.1 keytool 설치 확인
```cmd
keytool -help
```
없으면 JDK 17+ 설치 ([Adoptium](https://adoptium.net/))

### 1.2 키스토어 생성 스크립트 실행
```cmd
cd D:\vsCodeProg\APT-APP
scripts\generate-keystore.bat
```

대화형으로 정보 입력:
- **이름·조직**: 본인 또는 단체명
- **스토어 암호 / 키 암호**: 강력한 암호 (동일 가능)
- 결과: `D:\vsCodeProg\APT-APP\apt-upload.jks` 생성됨

### 1.3 key.properties 작성
```cmd
copy android\key.properties.example android\key.properties
```

편집:
```properties
storePassword=위에서_입력한_스토어_암호
keyPassword=위에서_입력한_키_암호
keyAlias=apt
storeFile=../apt-upload.jks
```

### 1.4 백업
- [ ] `apt-upload.jks` 를 외부 저장소에 복사 (암호화 USB + 클라우드 vault)
- [ ] 암호를 비밀번호 관리자에 저장
- [ ] `key.properties` 와 `apt-upload.jks` 가 `.gitignore` 로 제외되는지 확인:
  ```
  git status   # 두 파일이 untracked 혹은 ignored 로 나오면 OK
  ```

---

## 2. 릴리스 AAB 빌드

### 2.1 환경 변수 확인 (한글 사용자명 환경)
```cmd
set PUB_CACHE=C:\pub-cache
set GRADLE_USER_HOME=C:\gradle-user
set ANDROID_SDK_ROOT=C:\android-sdk
set ANDROID_HOME=C:\android-sdk
```

### 2.2 버전 업데이트 (선택)
`pubspec.yaml`:
```yaml
version: 1.0.0+1   # minor: "1.0.0" / versionCode: "+1"
```
신규 빌드마다 `+N` 을 증가시킵니다 (`1.0.0+1` → `1.0.0+2`).

### 2.3 빌드
```cmd
cd D:\vsCodeProg\APT-APP
flutter clean
flutter pub get
flutter build appbundle --release ^
  --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app ^
  --dart-define=GOOGLE_CLIENT_ID=838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0.apps.googleusercontent.com ^
  --dart-define=APP_ENV=prod
```

결과:
```
build\app\outputs\bundle\release\app-release.aab   (~52 MB)
```

### 2.4 로컬 검증 (선택)
```cmd
flutter build apk --release --split-per-abi ^
  --dart-define=API_BASE_URL=https://apt-ev-charging.vercel.app ...
```
생성된 `app-arm64-v8a-release.apk` 를 실기기에 설치해 **골든 플로우 검증**:
1. Google 로그인 → pending
2. 관리자가 웹에서 승인 → approved
3. 주차 등록 → 해제
4. 대화방 메시지 송수신

---

## 3. Google Cloud 콘솔 — Android 클라이언트 ID

Google 로그인이 앱에서 정상 작동하려면 Android 앱의 SHA-1 지문을 등록해야 합니다.

### 3.1 업로드 키 SHA-1 추출
```cmd
keytool -list -v -keystore D:\vsCodeProg\APT-APP\apt-upload.jks -alias apt
```
출력에서 **SHA1** 값 복사 (예: `AB:CD:EF:01:23:...`)

### 3.2 Play Store App Signing SHA-1 추출 (첫 업로드 후)
Play Console 업로드 후 **Play App Signing** 이 자동으로 별도 서명 키를 생성합니다.
- Play Console → 앱 무결성 → 앱 서명 → **업로드 키 인증서 SHA-1** 및 **앱 서명 키 인증서 SHA-1** 모두 복사

### 3.3 Google Cloud Console 등록
1. [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials
2. 기존 웹 클라이언트 (`838650325157-jeblq38cd6i2nln1vvjua8o0set46bo0`)에 **Android 제한 사항 추가**
   - Package name: `com.bluetilelab.apt_ev`
   - SHA-1: 위 두 값 모두 등록

또는 **새 Android OAuth 클라이언트** 생성:
- 패키지명: `com.bluetilelab.apt_ev`
- SHA-1: 업로드 키 SHA-1 + 앱 서명 키 SHA-1

**중요**: Flutter 앱은 `serverClientId` 로 웹 클라이언트 ID 를 사용하므로 백엔드 `GOOGLE_CLIENT_ID` 환경변수는 변경하지 않습니다.

---

## 4. Play Console — 앱 생성

### 4.1 앱 만들기
1. Play Console → **앱 만들기**
2. 앱 이름: `APT EV 충전`
3. 기본 언어: `한국어 - ko-KR`
4. 앱 또는 게임: **앱**
5. 무료 또는 유료: **무료**
6. 개발자 프로그램 정책 동의

### 4.2 앱 콘텐츠 설정
[PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md) 참조하여 입력:

- [ ] **앱 액세스 권한** — 관리자 승인 필요 → 테스트 계정 제공
- [ ] **광고** — 포함 안 됨
- [ ] **콘텐츠 등급** — 설문 → 모든 사용자
- [ ] **대상 사용자층 및 콘텐츠** — 만 18세 이상 (또는 만 14세 이상)
- [ ] **뉴스 앱 여부** — 아니오
- [ ] **COVID-19** — 해당 없음
- [ ] **데이터 보안** — [PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md) 의 Data Safety 표 입력
- [ ] **정부 앱** — 아니오
- [ ] **금융 기능** — 아니오

### 4.3 스토어 등록정보 (Store Listing)
- [ ] 앱 이름: `APT EV 충전` (30자 이내)
- [ ] 짧은 설명: 복사 ([PLAY_STORE_LISTING.md](PLAY_STORE_LISTING.md))
- [ ] 자세한 설명: 복사
- [ ] 앱 아이콘 (512×512)
- [ ] 피처 그래픽 (1024×500)
- [ ] 스크린샷 (휴대전화 최소 2장, 권장 6~8장)
- [ ] 카테고리: `자동차`
- [ ] 태그: 전기차, 주차, 관리
- [ ] 이메일: polkolpk@gmail.com
- [ ] 웹사이트: https://apt-ev-charging.vercel.app
- [ ] 개인정보처리방침: https://apt-ev-charging.vercel.app/privacy.html

### 4.4 메인 스토어 등록정보 검증
- [ ] 실기기 화면만 스크린샷에 사용
- [ ] 과장/허위 문구 없음
- [ ] 저작권 충돌 없음 (Google/Tesla 등 사칭 금지)

---

## 5. 내부 테스트 트랙 업로드

### 5.1 내부 테스트 릴리스 생성
1. Play Console → 앱 → **테스트** → **내부 테스트**
2. **새 릴리스 만들기**
3. **Play 앱 서명** 활성화 (권장) — Google이 앱 서명 키 관리
4. **App Bundle 업로드**: `build\app\outputs\bundle\release\app-release.aab`
5. 출시 이름: `1.0.0` (기본값)
6. 출시 노트:
   ```
   <ko-KR>
   • 최초 출시
   • Google 로그인
   • 실시간 주차 슬롯 조회/등록
   • 입주민 대화방
   • 관리자 기능
   </ko-KR>
   ```

### 5.2 테스터 추가
- 내부 테스트 테스터 목록 작성
  - 본인 Gmail
  - 관리자 Gmail
  - 베타 사용자 3~5명
- 옵트인 URL 공유 → 테스터가 Play Store 에서 설치

### 5.3 심사 제출
**내부 테스트는 심사 없이 바로 배포**됩니다. 설치 가능할 때까지 약 2시간 소요.

### 5.4 골든 플로우 실기기 검증
- [ ] 새 Google 계정으로 로그인 → pending 화면
- [ ] 웹에서 관리자 승인 → 앱에서 자동 approved 전환
- [ ] 프로필 입력 + 차량 사진 업로드
- [ ] 차량 사진 인증
- [ ] 주차 등록
- [ ] 내 차량 출차
- [ ] 대화방 메시지 송수신 + 수정/삭제
- [ ] 마이페이지 이력 조회
- [ ] 탈퇴 → 7일 재가입 차단 검증

---

## 6. 비공개 → 프로덕션 승격

### 6.1 비공개 테스트
1. **테스트 → 비공개 테스트** 트랙으로 AAB 복사
2. 특정 구성원에게만 공개 (최대 수백 명)
3. 1~2주 피드백 수집

### 6.2 프로덕션 트랙
1. **프로덕션 → 새 릴리스 만들기**
2. 비공개 트랙의 AAB 가져오기 또는 새로 업로드
3. 출시 범위: 대한민국 100%
4. **심사 검토 제출**
5. 심사 기간: **1~3일** (첫 앱은 최대 2주)

### 6.3 심사 거부 대응
자주 발생하는 거부 사유:
| 사유 | 대응 |
| --- | --- |
| 개인정보처리방침 URL 접근 불가 | Vercel 배포 확인, 404 없음 |
| 카메라 권한 설명 부족 | AndroidManifest `<uses-feature required="false">` 확인 |
| 데이터 수집 미공개 | Data Safety 표 재검토 |
| 앱 작동 불가 (테스트 계정 미제공) | 앱 액세스 권한 섹션 보완 |

거부되면 이메일로 상세 이유 수신 → 수정 후 재제출 (심사 재개 1~2일).

---

## 7. 배포 후 모니터링

- [ ] Play Console → 통계 → 설치, 크래시, ANR 대시보드 확인
- [ ] 리뷰 모니터링 (일일)
- [ ] Firebase Crashlytics 설정 (선택, v1.1 에서)
- [ ] 버그 리포트 채널 — 이메일 polkolpk@gmail.com

---

## 8. 업데이트 배포

1. 코드 변경 → `flutter analyze` 통과
2. `pubspec.yaml` 의 versionCode `+N` 증가
3. `flutter build appbundle --release` 재빌드
4. Play Console → 프로덕션 → **새 릴리스** → AAB 업로드
5. 출시 노트 작성 → 심사 제출 (1~3일)

---

## 체크리스트 요약

### 출시 전 필수
- [ ] Google Play Developer 계정 ($25 결제)
- [ ] Privacy + Account deletion URL 배포 확인
- [ ] 업로드 키스토어 생성 + 백업
- [ ] `key.properties` 작성 + gitignore 확인
- [ ] 앱 아이콘 (512×512) + 피처 그래픽 (1024×500) + 스크린샷 6장
- [ ] Release AAB 빌드 성공
- [ ] 내부 테스트 실기기 골든 플로우 통과
- [ ] Google Cloud Console 에 SHA-1 등록
- [ ] Data Safety 폼 완성
- [ ] 앱 액세스 권한 테스트 계정 준비

### 출시
- [ ] 비공개 트랙 1~2주 테스트
- [ ] 프로덕션 심사 제출
- [ ] 심사 통과 → 공개

### 출시 후
- [ ] 설치 통계 + 크래시 모니터링
- [ ] 리뷰 대응
- [ ] 버그 리포트 관리
