#!/bin/bash
# build_unrestricted.sh — DSH-Go 无限制 APK 一键构建
set -e

echo "══════════════════════════════════════════"
echo "  DSH-Go Unrestricted APK Builder"
echo "══════════════════════════════════════════"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── 1. 环境检查 ──
echo ""
echo "── 1/5 环境检查 ──"
: "${ANDROID_HOME:?请先设置 ANDROID_HOME 环境变量}"
: "${ANDROID_NDK:?请先设置 ANDROID_NDK 环境变量}"

if [ ! -d "$ANDROID_HOME" ]; then
    echo "❌ ANDROID_HOME 不存在: $ANDROID_HOME"
    exit 1
fi
echo "  ANDROID_HOME = $ANDROID_HOME"
echo "  ANDROID_NDK  = $ANDROID_NDK"

# ── 2. 应用补丁 ──
echo ""
echo "── 2/5 应用补丁 ──"
cd "$REPO_ROOT"
PATCH_DIR="$SCRIPT_DIR/../patches"
for p in "$PATCH_DIR"/*.patch; do
    echo "  应用: $(basename "$p")"
    git apply --check "$p" 2>/dev/null && git apply "$p" || echo "    ⚠️  已应用或冲突，跳过"
done

# ── 3. 注入签名 ──
echo ""
echo "── 3/5 注入签名配置 ──"
# 查找 Android 模块的 build.gradle
BUILD_GRADLE=""
for cand in "app/android/build.gradle" "app/build.gradle" "android/app/build.gradle"; do
    if [ -f "$REPO_ROOT/$cand" ]; then
        BUILD_GRADLE="$REPO_ROOT/$cand"
        break
    fi
done

if [ -z "$BUILD_GRADLE" ]; then
    echo "❌ 找不到 build.gradle"
    exit 1
fi
echo "  目标: $BUILD_GRADLE"
"$SCRIPT_DIR/apply_no_signing.sh" "$BUILD_GRADLE"

# ── 4. 编译 ──
echo ""
echo "── 4/5 编译 APK ──"
ANDROID_DIR="$(dirname "$BUILD_GRADLE")"
cd "$ANDROID_DIR"

# 优先 debug（可直接安装），fallback release
if [ -f "gradlew" ]; then
    echo "  执行: ./gradlew assembleDebug"
    ./gradlew assembleDebug || {
        echo "  ⚠️  Debug 失败，尝试 Release..."
        ./gradlew assembleRelease
    }
else
    echo "❌ 找不到 gradlew"
    exit 1
fi

# ── 5. 输出 ──
echo ""
echo "── 5/5 输出 ──"
find "$ANDROID_DIR/build/outputs/apk" -name "*.apk" 2>/dev/null | while read apk; do
    size=$(stat -c%s "$apk")
    echo "  📦 $apk ($(numfmt --to=iec $size))"
done
echo ""
echo "✅ 构建完成"
