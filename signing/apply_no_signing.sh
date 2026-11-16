#!/bin/bash
#
# apply_no_signing.sh — 自动集成 no_signing.gradle 到 DSH-Go 项目
#
# 用法：
#   ./apply_no_signing.sh [build.gradle 路径]
#
# 默认路径：app/android/build.gradle
#

set -e

TARGET="${1:-app/android/build.gradle}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGNING_FILE="${SCRIPT_DIR}/no_signing.gradle"

# ── 颜色输出 ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ── 前置检查 ─────────────────────────────────────────────────────
log_info "检查前置条件..."

if [ ! -f "${SIGNING_FILE}" ]; then
    log_error "签名配置文件不存在: ${SIGNING_FILE}"
    exit 1
fi

if [ ! -f "${TARGET}" ]; then
    # 尝试查找 .kts 版本
    if [ -f "${TARGET}.kts" ]; then
        TARGET="${TARGET}.kts"
        log_warn "使用 Kotlin DSL 版本: ${TARGET}"
    else
        log_error "目标 build.gradle 不存在: ${TARGET}"
        log_info "可用文件："
        find . -maxdepth 4 -name "build.gradle*" -type f 2>/dev/null | head -10
        exit 1
    fi
fi

# ── 检测是否已注入 ───────────────────────────────────────────────
if grep -q "no_signing.gradle" "${TARGET}"; then
    log_warn "no_signing.gradle 已注入，跳过"
    exit 0
fi

# ── 备份 ─────────────────────────────────────────────────────────
BACKUP="${TARGET}.bak.$(date +%s)"
cp "${TARGET}" "${BACKUP}"
log_info "已备份: ${BACKUP}"

# ── 注入 apply 语句 ──────────────────────────────────────────────
# 在文件顶部（第一行）插入 apply from 语句
# 如果第一行是注释或 buildscript 块，则插到最前面

TEMP_FILE="$(mktemp)"
{
    echo '// ↓↓↓ DSH-Go 无签名构建注入（自动生成，勿手动删除）'
    echo 'apply from: "${projectDir}/signing/no_signing.gradle"'
    echo '// ↑↑↑'
    echo ''
    cat "${TARGET}"
} > "${TEMP_FILE}"

mv "${TEMP_FILE}" "${TARGET}"
log_ok "已注入签名配置到: ${TARGET}"

# ── 复制 signing 目录到项目 ──────────────────────────────────────
SIGNING_DIR="$(dirname "${TARGET}")/signing"
if [ ! -d "${SIGNING_DIR}" ]; then
    mkdir -p "${SIGNING_DIR}"
fi
cp "${SIGNING_FILE}" "${SIGNING_DIR}/no_signing.gradle"
log_ok "已复制 no_signing.gradle 到: ${SIGNING_DIR}/"

# ── 提示 ─────────────────────────────────────────────────────────
echo ""
log_ok "集成完成！"
echo ""
echo "  下一步："
echo "    1. 编译 debug 版本（推荐）："
echo "       ./gradlew :app:android:assembleDebug"
echo ""
echo "    2. 编译 release 版本（debug 签名）："
echo "       先编辑 no_signing.gradle，取消 '备用方案' 注释"
echo "       ./gradlew :app:android:assembleRelease"
echo ""
echo "    3. 安装到设备："
echo "       adb install -r app/android/build/outputs/apk/debug/app-android-debug.apk"
echo ""
echo "  回滚："
echo "    cp ${BACKUP} ${TARGET}"
echo ""
