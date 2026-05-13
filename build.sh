#!/bin/bash

# ============================================
# APT EV Charging App - Flutter 빌드 & 배포 도구
# ============================================

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로고
print_logo() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║     APT EV Charging Mobile App - Build & Deploy Tool     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 메뉴 표시
show_menu() {
    echo ""
    echo -e "${YELLOW}=== 빌드 및 배포 옵션 ===${NC}"
    echo ""
    echo "1. 의존성 설치 (flutter pub get)"
    echo "2. 코드 분석 (flutter analyze)"
    echo "3. 단위 테스트 (flutter test)"
    echo "4. Android 빌드 - APK"
    echo "5. Android 빌드 - App Bundle"
    echo "6. 모든 검사 후 빌드 (1 → 2 → 3 → 4)"
    echo "7. 전체 프리플라이트 체크"
    echo "8. 배포 전 최종 확인"
    echo "9. 종료"
    echo ""
    echo -n "선택: "
}

# 1. 의존성 설치
run_get_dependencies() {
    echo -e "\n${BLUE}[1/1] 의존성 설치 중...${NC}"
    flutter pub get
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 의존성 설치 완료${NC}"
        return 0
    else
        echo -e "${RED}❌ 의존성 설치 실패${NC}"
        return 1
    fi
}

# 2. 코드 분석
run_analyze() {
    echo -e "\n${BLUE}[1/1] 코드 분석 중...${NC}"
    flutter analyze
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 코드 분석 완료${NC}"
        return 0
    else
        echo -e "${RED}⚠️  코드 분석 경고 발생 (위 내용 확인)${NC}"
        return 1
    fi
}

# 3. 단위 테스트
run_tests() {
    echo -e "\n${BLUE}[1/1] 단위 테스트 실행 중...${NC}"
    flutter test
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 테스트 완료${NC}"
        return 0
    else
        echo -e "${RED}❌ 테스트 실패${NC}"
        return 1
    fi
}

# 4. Android APK 빌드
build_apk() {
    echo -e "\n${BLUE}[1/1] Android APK 빌드 중 (이 과정은 몇 분이 소요될 수 있습니다)...${NC}"
    flutter build apk --release
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ APK 빌드 완료${NC}"
        echo -e "${BLUE}📦 출력: build/app/outputs/apk/release/app-release.apk${NC}"
        return 0
    else
        echo -e "${RED}❌ APK 빌드 실패${NC}"
        return 1
    fi
}

# 5. Android App Bundle 빌드
build_app_bundle() {
    echo -e "\n${BLUE}[1/1] Android App Bundle 빌드 중...${NC}"
    flutter build appbundle --release
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ App Bundle 빌드 완료${NC}"
        echo -e "${BLUE}📦 출력: build/app/outputs/bundle/release/app-release.aab${NC}"
        return 0
    else
        echo -e "${RED}❌ App Bundle 빌드 실패${NC}"
        return 1
    fi
}

# 6. 완전한 빌드 파이프라인
run_full_build_pipeline() {
    echo -e "\n${YELLOW}=== 완전한 빌드 파이프라인 시작 ===${NC}"
    
    local steps=(
        "run_get_dependencies"
        "run_analyze"
        "run_tests"
        "build_apk"
    )
    
    local failed_steps=()
    
    for step in "${steps[@]}"; do
        $step
        if [ $? -ne 0 ]; then
            failed_steps+=("$step")
        fi
    done
    
    echo -e "\n${YELLOW}=== 파이프라인 완료 ===${NC}"
    
    if [ ${#failed_steps[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ 모든 단계 성공${NC}"
        return 0
    else
        echo -e "${RED}❌ 실패한 단계:${NC}"
        for step in "${failed_steps[@]}"; do
            echo -e "  - $step"
        done
        return 1
    fi
}

# 7. 프리플라이트 체크
run_preflight_check() {
    echo -e "\n${YELLOW}=== 배포 전 프리플라이트 체크 ===${NC}\n"
    
    local checks_passed=0
    local checks_failed=0
    
    # Flutter SDK 확인
    echo -n "Flutter SDK: "
    if command -v flutter &> /dev/null; then
        flutter_version=$(flutter --version | head -n1)
        echo -e "${GREEN}✅ $flutter_version${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ Flutter 설치 안 됨${NC}"
        ((checks_failed++))
    fi
    
    # Dart SDK 확인
    echo -n "Dart SDK: "
    if command -v dart &> /dev/null; then
        dart_version=$(dart --version)
        echo -e "${GREEN}✅ $dart_version${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ Dart 설치 안 됨${NC}"
        ((checks_failed++))
    fi
    
    # Android SDK 확인
    echo -n "Android SDK: "
    if [ ! -z "$ANDROID_SDK_ROOT" ] || [ ! -z "$ANDROID_HOME" ]; then
        echo -e "${GREEN}✅ 설치됨${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ Android SDK 설정 안 됨${NC}"
        ((checks_failed++))
    fi
    
    # 프로젝트 파일 확인
    echo -n "pubspec.yaml: "
    if [ -f "pubspec.yaml" ]; then
        echo -e "${GREEN}✅ 있음${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ 없음${NC}"
        ((checks_failed++))
    fi
    
    # lib/main.dart 확인
    echo -n "lib/main.dart: "
    if [ -f "lib/main.dart" ]; then
        echo -e "${GREEN}✅ 있음${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ 없음${NC}"
        ((checks_failed++))
    fi
    
    # android/ 폴더 확인
    echo -n "android/ 폴더: "
    if [ -d "android" ]; then
        echo -e "${GREEN}✅ 있음${NC}"
        ((checks_passed++))
    else
        echo -e "${RED}❌ 없음${NC}"
        ((checks_failed++))
    fi
    
    # pubspec.lock 확인
    echo -n "pubspec.lock: "
    if [ -f "pubspec.lock" ]; then
        echo -e "${GREEN}✅ 있음${NC}"
        ((checks_passed++))
    else
        echo -e "${YELLOW}⚠️  없음 (flutter pub get 실행 필요)${NC}"
        ((checks_failed++))
    fi
    
    echo ""
    echo -e "${BLUE}체크 결과: ${GREEN}$checks_passed 통과${NC} / ${RED}$checks_failed 실패${NC}"
    
    if [ $checks_failed -eq 0 ]; then
        echo -e "\n${GREEN}✅ 모든 필수 요소가 설정되었습니다${NC}"
        return 0
    else
        echo -e "\n${RED}❌ 일부 필수 요소가 누락되었습니다${NC}"
        return 1
    fi
}

# 8. 배포 전 최종 확인
pre_deployment_check() {
    echo -e "\n${YELLOW}=== 배포 전 최종 확인 ===${NC}\n"
    
    echo "다음 항목들을 확인하세요:\n"
    
    echo "📱 앱 설정:"
    echo "  [ ] API 서버 주소 확인 (lib/config/app_config.dart)"
    echo "  [ ] Google OAuth Client ID 설정"
    echo "  [ ] 앱 버전 업데이트 (pubspec.yaml)"
    echo ""
    
    echo "🔐 보안:"
    echo "  [ ] API 서버가 HTTPS 사용"
    echo "  [ ] 민감한 정보가 코드에 노출되지 않았는지 확인"
    echo "  [ ] 토큰이 안전하게 저장되는지 확인"
    echo ""
    
    echo "🧪 테스트:"
    echo "  [ ] 단위 테스트 통과 (flutter test)"
    echo "  [ ] 코드 분석 완료 (flutter analyze)"
    echo "  [ ] 에뮬레이터/기기에서 수동 테스트"
    echo ""
    
    echo "🔗 플랫폼별 설정:"
    echo "  [ ] Android:"
    echo "      - google-services.json 추가"
    echo "      - AndroidManifest.xml 권한 확인"
    echo "  [ ] iOS (Mac에서 빌드 시):"
    echo "      - GoogleService-Info.plist 추가"
    echo "      - 프로비저닝 프로필 설정"
    echo ""
    
    echo "📤 배포:"
    echo "  [ ] Play Store 개발자 계정 활성화"
    echo "  [ ] App Store Connect 계정 활성화"
    echo "  [ ] 스크린샷 및 설명 준비"
    echo ""
    
    echo -e "${BLUE}위 항목을 모두 확인 후 배포하세요.${NC}"
}

# 메인 루프
main() {
    cd "$(dirname "$0")"
    
    while true; do
        print_logo
        show_menu
        read choice
        
        case $choice in
            1)
                run_get_dependencies
                ;;
            2)
                run_analyze
                ;;
            3)
                run_tests
                ;;
            4)
                build_apk
                ;;
            5)
                build_app_bundle
                ;;
            6)
                run_full_build_pipeline
                ;;
            7)
                run_preflight_check
                ;;
            8)
                pre_deployment_check
                ;;
            9)
                echo -e "\n${GREEN}프로그램 종료${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ 잘못된 선택입니다${NC}"
                ;;
        esac
    done
}

main
