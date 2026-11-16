# DSH-Go 无限制构建指南

## 概述

本方案通过修改 DSH-Go (v0.2.2-rc.1) Android 端源码，实现：
1. **禁用安全模式** — SafeMode.kt / RuntimeController.kt / DshProcess.kt
2. **清空 SafetyGate 黑名单** — SafetyGate.kt
3. **跳过签名验证** — no_signing.gradle

## 前置条件

- Android Studio (Hedgehog 2023.1.1 或更高)
- Android SDK 26 (Android 8.0)
- Android NDK 25.2.9519653
- JDK 17+

## 快速开始

```bash
# 1. 设置环境变量
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK=$ANDROID_HOME/ndk/25.2.9519653

# 2. 克隆源码
git clone https://github.com/grokggg/dsh-Go.git
cd dsh-Go

# 3. 应用补丁
git apply patches/0001-disable-safemode-SafeMode.kt.patch
git apply patches/0002-disable-safemode-RuntimeController.kt.patch
git apply patches/0003-disable-safemode-DshProcess.kt.patch
git apply patches/0004-disable-safemode-SafetyGate.kt.patch

# 4. 注入签名
signing/apply_no_signing.sh app/android/build.gradle

# 5. 一键构建
signing/build_unrestricted.sh

# 6. 输出 APK
# app/android/build/outputs/apk/debug/app-android-debug.apk
```

## 签名说明

`no_signing.gradle` 做了两件事：
1. debug → 使用 androiddebugkey 签名（可直接 adb install）
2. release → signingConfig = null，跳过签名验证

## 验证

```bash
signing/verify_integration.sh
```
