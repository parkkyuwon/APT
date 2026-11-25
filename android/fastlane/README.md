# fastlane — Play Console 자동 배포

## 1회만 하는 셋업

### 1) Ruby + fastlane 설치 (Windows)
1. <https://rubyinstaller.org/downloads/> 에서 **Ruby+Devkit 3.2.x (x64)** 다운로드 후 설치
   - 설치 마지막 단계의 `ridk install` 콘솔에서 `1,3` 엔터로 MSYS2 toolchain 함께 설치
2. PowerShell 재시작 후:
   ```powershell
   ruby --version          # ruby 3.2.x 확인
   gem install bundler
   cd D:\vsCodeProg\APT-APP\android
   bundle install          # Gemfile 의 fastlane 설치
   ```

### 2) Play Developer API 서비스 계정 JSON 키 발급
1. <https://play.google.com/console> → **설정 → API 액세스** (Setup → API access)
2. **새 서비스 계정 만들기** 클릭 → Google Cloud Console 로 이동 → 서비스 계정 생성 (역할은 비워둠)
3. 만든 서비스 계정의 **키 만들기 → JSON** 으로 키 파일 다운로드
4. Play Console 로 돌아와서 **권한 부여** → 앱 액세스에 `APT EV` 추가
   - 최소 권한: "관리자 권한"의 **"릴리스 관리자"** (출시 + 트랙 변경)
5. 다운로드한 JSON 파일을 다음 경로에 저장:
   ```
   D:\vsCodeProg\APT-APP\android\fastlane\play-store-credentials.json
   ```
6. `.gitignore` 에 이미 등록되어 있으므로 커밋되지 않습니다.

### 3) 첫 실행 검증
```powershell
cd D:\vsCodeProg\APT-APP\android
bundle exec fastlane validate          # AAB 빌드 + Play API 인증 확인 (실제 게시 X)
```
정상 통과되면 셋업 완료.

## 일상 사용

```powershell
cd D:\vsCodeProg\APT-APP\android

# 일반 — internal 트랙에 draft 로 업로드
bundle exec fastlane deploy

# 비공개 테스트
bundle exec fastlane deploy track:alpha

# 공개 테스트
bundle exec fastlane deploy track:beta

# 정식 출시 (10% 점진 배포)
bundle exec fastlane deploy track:production release_status:completed rollout:0.1

# AAB 만 빌드 (업로드 안 함)
bundle exec fastlane build

# versionCode +1
bundle exec fastlane bump_build
```

각 lane 은 자동으로:
- `PUB_CACHE / GRADLE_USER_HOME / TEMP` 를 ASCII 경로(`D:\…`)로 강제 (한글 사용자명 회피)
- `flutter build appbundle --release --split-debug-info=build/symbols --obfuscate` 실행
- `--dart-define` 으로 `API_BASE_URL / GOOGLE_CLIENT_ID / APP_ENV` 주입
- 결과 AAB 와 `build/symbols/**/*.map` 매핑 파일을 Play Console 에 업로드

## 트러블슈팅

- **`Could not find json_key_file`**: `play-store-credentials.json` 위치 확인. `android/fastlane/` 직속에 둬야 함.
- **`The caller does not have permission`**: Play Console → 사용자 및 권한에서 서비스계정 이메일에 앱 액세스 권한 부여 확인.
- **`This Edit has been deleted`**: 동일 versionCode 로 다시 업로드 시도. `fastlane bump_build` 후 재시도.
- **첫 출시(production)는 fastlane 으로 불가**: Play Console 정책상 최초 release 는 콘솔에서 수동으로 한 번 게시 후, 이후부터 fastlane 자동화 가능.
