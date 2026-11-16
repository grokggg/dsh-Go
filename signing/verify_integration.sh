#!/bin/bash
# verify_integration.sh — 验证无限制构建环境是否就绪
set -e

echo "══════════════════════════════════════════"
echo "  DSH-Go 无限制构建 — 环境验证"
echo "══════════════════════════════════════════"
echo ""

pass=0
fail=0

check() {
    local name="$1"; shift
    if eval "$@" > /dev/null 2>&1; then
        echo "  ✅ $name"
        pass=$((pass+1))
    else
        echo "  ❌ $name"
        fail=$((fail+1))
    fi
}

echo "── 工具链 ──"
check "ANDROID_HOME 已设置"       "test -n \"$ANDROID_HOME\""
check "ANDROID_HOME 目录存在"     "test -d \"$ANDROID_HOME\""
check "ANDROID_NDK 已设置"        "test -n \"$ANDROID_NDK\""
check "gradle 可用"               "which gradle"
check "java 可用"                 "which java"
check "git 可用"                  "which git"

echo ""
echo "── 签名配置 ──"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
check "no_signing.gradle 存在"    "test -f \"$SCRIPT_DIR/no_signing.gradle\""
check "apply 脚本存在"            "test -f \"$SCRIPT_DIR/apply_no_signing.sh\""
check "build 脚本存在"            "test -f \"$SCRIPT_DIR/build_unrestricted.sh\""
check "apply 脚本可执行"          "test -x \"$SCRIPT_DIR/apply_no_signing.sh\""
check "build 脚本可执行"          "test -x \"$SCRIPT_DIR/build_unrestricted.sh\""

echo ""
echo "── 补丁 ──"
PATCH_DIR="$SCRIPT_DIR/../patches"
if [ -d "$PATCH_DIR" ]; then
    for p in "$PATCH_DIR"/*.patch; do
        [ -f "$p" ] && check "$(basename "$p")" "test -f \"$p\""
    done
fi

echo ""
echo "── 结果 ──"
echo "  通过: $pass / 失败: $fail"
[ $fail -eq 0 ] && echo "✅ 全部通过" || echo "❌ 有失败项"
