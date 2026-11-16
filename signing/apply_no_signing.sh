#!/bin/bash
# apply_no_signing.sh — 自动将 no_signing.gradle 注入到 Android 模块的 build.gradle
# 用法：apply_no_signing.sh <path/to/app/build.gradle[.kts]>

set -e
TARGET="${1:?用法: $0 <build.gradle 或 build.gradle.kts>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRADLE_FRAG="$SCRIPT_DIR/no_signing.gradle"

if [ ! -f "$TARGET" ]; then
    echo "❌ 目标文件不存在: $TARGET"
    exit 1
fi

if [ ! -f "$GRADLE_FRAG" ]; then
    echo "❌ no_signing.gradle 不存在: $GRADLE_FRAG"
    exit 1
fi

# 检测是否已注入
if grep -q "no_signing.gradle" "$TARGET"; then
    echo "⚠️  已注入过，跳过"
    exit 0
fi

# 复制签名配置到模块目录
cp "$GRADLE_FRAG" "$(dirname "$TARGET")/no_signing.gradle"

# 注入 apply from
if [[ "$TARGET" == *.kts ]]; then
    echo 'apply(from = "no_signing.gradle")' >> "$TARGET"
else
    echo 'apply from: "no_signing.gradle"' >> "$TARGET"
fi

echo "✅ 已注入签名配置到 $TARGET"
