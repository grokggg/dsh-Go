#!/bin/bash
#
# build_unrestricted.sh — DSH-Go 无限制版本一键构建脚本
#
# 流程：
#   1. 环境检查（git / gradle / adb / Android SDK）
#   2. 应用 4 个安全模式禁用补丁
#   3. 注入签名配置
#   4. 编译 debug + release
#   5. 输出 APK 路径
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PATCH_DIR="${PROJECT_ROOT}/patches"
SIGNING_DIR="${SCRIPT_DIR}"

# ── 颜色输出 ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${PURPLE}[STEP]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   DSH-Go v0.2.2-rc.1 无限制版本构建脚本                    ║"
echo "║   禁用安全模式 + 清空安全限制 + 跳过签名验证               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 1: 环境检查
# ═══════════════════════════════════════════════════════════════════
log_step "STEP 1/5: 环境检查"

if ! command -v git &> /dev/null; then
    log_error "git 未安装"
    exit 1
fi
log_ok "git: $(git --version)"

if ! command -v gradle &> /dev/null && [ -z "${ANDROID_HOME}" ]; then
    log_warn "gradle 未安装，且 ANDROID_HOME 未设置"
    log_info "请确保 Android Studio 已安装，并设置环境变量："
    echo "  export ANDROID_HOME=\$HOME/Android/Sdk"
    echo "  export PATH=\$PATH:\$ANDROID_HOME/tools:\$ANDROID_HOME/platform-tools"
    exit 1
fi
log_ok "ANDROID_HOME: ${ANDROID_HOME:-未设置（将使用项目内置 Gradle Wrapper）}"

if [ ! -d "${PROJECT_ROOT}/app/android" ]; then
    log_error "未找到 app/android 目录，请在 dsh-Go 项目根目录运行"
    exit 1
fi
log_ok "项目结构: OK"

echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 2: 应用补丁
# ═══════════════════════════════════════════════════════════════════
log_step "STEP 2/5: 应用安全模式禁用补丁"

cd "${PROJECT_ROOT}"

PATCHES=(
    "0001-disable-safemode-SafeMode.kt.patch"
    "0002-disable-safemode-RuntimeController.kt.patch"
    "0003-disable-safemode-DshProcess.kt.patch"
    "0004-disable-safemode-SafetyGate.kt.patch"
)

for patch in "${PATCHES[@]}"; do
    patch_path="${PATCH_DIR}/${patch}"
    if [ ! -f "${patch_path}" ]; then
        log_warn "补丁不存在，跳过: ${patch}"
        continue
    fi
    
    # 检查是否已应用
    if git apply --check "${patch_path}" 2>/dev/null; then
        git apply "${patch_path}"
        log_ok "已应用: ${patch}"
    else
        log_warn "补丁已应用或冲突，跳过: ${patch}"
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 3: 注入签名配置
# ═══════════════════════════════════════════════════════════════════
log_step "STEP 3/5: 注入签名配置"

BUILD_GRADLE="${PROJECT_ROOT}/app/android/build.gradle"

# 优先用 Kotlin DSL
if [ -f "${PROJECT_ROOT}/app/android/build.gradle.kts" ]; then
    BUILD_GRADLE="${PROJECT_ROOT}/app/android/build.gradle.kts"
fi

if [ -f "${BUILD_GRADLE}" ]; then
    # 复制 signing 配置
    mkdir -p "${PROJECT_ROOT}/app/android/signing"
    cp "${SIGNING_DIR}/no_signing.gradle" "${PROJECT_ROOT}/app/android/signing/no_signing.gradle"
    
    # 注入 apply 语句
    if ! grep -q "no_signing.gradle" "${BUILD_GRADLE}"; then
        TEMP="$(mktemp)"
        {
            echo '// ↓↓↓ DSH-Go 无签名构建注入'
            echo 'apply from: "${projectDir}/signing/no_signing.gradle"'
            echo '// ↑↑↑'
            echo ''
            cat "${BUILD_GRADLE}"
        } > "${TEMP}"
        mv "${TEMP}" "${BUILD_GRADLE}"
        log_ok "已注入签名配置: ${BUILD_GRADLE}"
    else
        log_warn "签名配置已注入，跳过"
    fi
else
    log_error "未找到 build.gradle，无法注入签名配置"
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 4: 编译
# ═══════════════════════════════════════════════════════════════════
log_step "STEP 4/5: 编译"

cd "${PROJECT_ROOT}/app/android"

# 使用 Gradle Wrapper
GRADLE_CMD="./gradlew"

if [ ! -x "${GRADLE_CMD}" ]; then
    GRADLE_CMD="gradle"
fi

log_info "开始编译 debug 版本..."
${GRADLE_CMD} assembleDebug --no-daemon --console=plain 2>&1 | tail -20

log_info "开始编译 release 版本..."
${GRADLE_CMD} assembleRelease --no-daemon --console=plain 2>&1 | tail -20

echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 5: 输出结果
# ═══════════════════════════════════════════════════════════════════
log_step "STEP 5/5: 输出结果"

DEBUG_APK=$(find "${PROJECT_ROOT}/app/android/build/outputs/apk/debug" -name "*.apk" 2>/dev/null | head -1)
RELEASE_APK=$(find "${PROJECT_ROOT}/app/android/build/outputs/apk/release" -name "*.apk" 2>/dev/null | head -1)

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  编译结果                                                     │"
echo "├──────────────────────────────────────────────────────────────┤"

if [ -n "${DEBUG_APK}" ]; then
    SIZE=$(du -h "${DEBUG_APK}" | cut -f1)
    echo "│  Debug APK:   ${DEBUG_APK}"
    echo "│  大小:        ${SIZE}"
    echo "│  安装命令:    adb install -r ${DEBUG_APK}"
    echo "│"
else
    echo "│  Debug APK:   未生成 ❌"
fi

if [ -n "${RELEASE_APK}" ]; then
    SIZE=$(du -h "${RELEASE_APK}" | cut -f1)
    echo "│  Release APK: ${RELEASE_APK}"
    echo "│  大小:        ${SIZE}"
    echo "│  安装命令:    adb install -r -t ${RELEASE_APK}"
else
    echo "│  Release APK: 未生成（可能需要用 debug 签名）"
fi

echo "└──────────────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 完成提示
# ═══════════════════════════════════════════════════════════════════
log_ok "构建完成！"

if [ -n "${DEBUG_APK}" ]; then
    echo ""
    echo "  安装到设备："
    echo "    adb install -r \"${DEBUG_APK}\""
    echo ""
    echo "  推送到 GitHub 仓库："
    echo "    使用 git push 或 GitHub Contents API"
fi
