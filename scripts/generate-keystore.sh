#!/bin/bash
# ==================================================================
# APT EV 충전 — Play Store 업로드 키스토어 생성 스크립트 (Unix/Git Bash)
#
# 한 번만 실행하세요. 생성된 apt-upload.jks 파일과 암호는
# 안전한 곳에 백업하세요. 분실 시 앱 업데이트가 불가능합니다.
# ==================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEYSTORE_PATH="$SCRIPT_DIR/../apt-upload.jks"
KEY_ALIAS="apt"

if [ -f "$KEYSTORE_PATH" ]; then
    echo "[WARN] 이미 키스토어가 존재합니다: $KEYSTORE_PATH"
    echo "재생성하려면 먼저 해당 파일을 이동/백업하세요."
    exit 1
fi

if ! command -v keytool &> /dev/null; then
    echo "[ERROR] keytool 을 찾을 수 없습니다."
    echo "JDK 를 설치하거나 PATH 에 추가하세요."
    exit 1
fi

echo "================================================================"
echo "Play Store 업로드 키스토어 생성"
echo "- 파일: $KEYSTORE_PATH"
echo "- alias: $KEY_ALIAS"
echo "- 유효기간: 약 27년 (10000일)"
echo "================================================================"

keytool -genkeypair -v \
    -keystore "$KEYSTORE_PATH" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storetype JKS

echo ""
echo "================================================================"
echo "✅ 키스토어 생성 완료!"
echo ""
echo "다음 단계:"
echo "1. android/key.properties 파일 생성 (key.properties.example 참조)"
echo "2. 입력한 암호를 password manager 에 저장"
echo "3. apt-upload.jks 를 외부/암호화 클라우드에 백업"
echo "4. 이 파일은 .gitignore 로 Git 에서 제외됩니다"
echo "================================================================"
