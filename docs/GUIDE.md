# DSH-Go v0.2.2-rc.1 无限制修改指南

> 基于真实源码分析（9 个核心 Kotlin 文件，274KB），所有修改均可追溯至具体行号。
> 目标：禁用安全模式、清空安全限制、让所有注入路径（system-prompt waterfall / agent-preset / profile preset / llm-proxy）正常生效。

## 一、安全限制的三道防线

DSH-Go 的安全限制分为三个层次，每一层都必须在客户端（Android）层面关闭，仅修改 Runtime 内的 JS 插件无法绕过。

### 第 1 层：安全模式（Safe Mode）

**核心文件**：`runtime/SafeMode.kt`（959 行）+ `runtime/RuntimeController.kt`（1241 行）

安全模式是 DSH 崩溃后的"救援系统"。一旦进入，会：

1. 使用独立 HOME 目录 `/var/lib/dsh-app/safe-mode/home`，**与你的主 profile 完全隔离**
2. 加载救援 profile `dsh-app-safe`，**禁用所有插件**：

```
- id: plugin-manager       disabled: true
- id: tool-plugin-manager   disabled: true
- id: preset-standard       disabled: true
- id: preset-cordis         disabled: true
- id: hmr                   disabled: true   # 热重载也关了
```

3. 设置环境变量 `DSH_APP_SAFE_MODE=1`，运行时据此切换行为
4. 通过 `OVERLAY_YAML` 覆盖主 profile 配置

**这就是你的四条注入路径全部失效的原因**——安全模式下插件管理被禁用，system-prompt waterfall 不会执行，agent-preset 的注册也被跳过。

### 第 2 层：自动安全模式触发

**核心文件**：`runtime/RuntimeController.kt`

```kotlin
// SafePolicy.onFailure()
val next = strikes + 1
return when {
    state == SafeState.PROBATION -> Outcome(SafeState.ON, ...)   // 试用期失败 → 强制安全模式
    next >= STRIKE_LIMIT && autoSafe -> Outcome(SafeState.ON, ...) // 连续 2 次失败 → 安全模式
    else -> Outcome(state, next, false, null, null)
}
```

连续两次启动失败（`STRIKE_LIMIT = 2`）就会自动进入安全模式。如果你的补丁导致崩溃，DSH 会自动切到安全模式，你的修改全部白做。

### 第 3 层：SafetyGate（运行时安全网关）

**核心文件**：`phone/SafetyGate.kt`（452 行）+ `phone/SafetyRules.kt` 内嵌对象

```kotlin
val DEFAULT_DENY = listOf(
    // payment
    "com.eg.android.AlipayGphone", "com.unionpay", ...,
    // banks（19 家银行）
    "com.icbc", "com.chinamworld.main", "com.android.bankabc", ...,
    // brokers
    "com.hexin.plat.android", "com.eastmoney.android.berlin", ...,
)

val SYSTEM_PACKAGES = setOf(
    "com.android.settings", "com.android.systemui",
    "com.android.permissioncontroller", ...
)
```

`SafetyGate` 在 `checkRead()` / `checkOpen()` / `checkWrite()` / `checkVisual()` 四处拦截，命中 `DEFAULT_DENY` 或 `SYSTEM_PACKAGES` 的操作会被替换为拒绝文本。

## 二、修改方案（4 个文件，21 处注入点）

### 文件 1：`runtime/SafeMode.kt`（7 处）

| 行号 | 修改内容 | 效果 |
|------|----------|------|
| 44 | `onStartRequest()` 的 `"normal"` 分支不再返回 `PROBATION` | 正常请求永远不会触发安全模式切换 |
| 111 | `LEGACY_SAFE = LEGACY_NORMAL` | 安全模式启动命令 = 正常命令，不再切换 profile |
| 116 | `GUEST_ENV` 注释标记 | 标识此处的环境变量注入 |
| 152 | `profileArg()` 中 `safe` 参数被忽略 | 即使传入 `safe=true`，也返回正常 profile 参数 |
| 154 | `if (!safe) return null` → `if (true) return null` | safe 模式下也返回 null，不重写命令 |
| 156 | `LEGACY_NORMAL` 替换不生效 | 双重保险 |
| 204 | `launchOnlyNames` 检查跳过 | 不再因 `.env` 配置阻止启动 |

### 文件 2：`runtime/RuntimeController.kt`（6 处）

| 行号 | 修改内容 | 效果 |
|------|----------|------|
| 73 | `safeState = SafeState.OFF`（忽略 SharedPreferences） | 启动时强制安全模式为 OFF |
| 288 | `start()` 中 `next = safeState`（忽略 mode 参数） | 外部传入的 `"safe"` 模式请求被忽略 |
| 500 | `val safe = false` | `startProcess()` 中永远不是安全模式 |
| 580 | tawc 逻辑保持不变（因 safe 已为 false） | direct 引擎正常工作 |
| 884-888 | `setSafeState()` 中任何非 OFF 赋值立即回退 | 双重保险，任何路径都无法将 safeState 设为 ON |
| 754 | `clearProbation()` 注释掉 | 防止外部调用重置状态 |

### 文件 3：`runtime/DshProcess.kt`（3 处）

| 行号 | 修改内容 | 效果 |
|------|----------|------|
| 104 | `safeRecovery` 分支条件改为 `false` | 永远不会进入 safeRecovery fallback |
| 106 | `tawcWanted = tawcEngine`（忽略 safe） | tawcroot 引擎不被安全模式阻止 |
| 120 | `effectiveGuestEnv["DSH_APP_SAFE_MODE"] = "0"` | 子进程环境变量永远为 "0" |

### 文件 4：`phone/SafetyGate.kt`（5 处）

| 行号 | 修改内容 | 效果 |
|------|----------|------|
| 160-168 | `DEFAULT_DENY` 列表清空 | 银行/支付/券商全部放行 |
| 165 | `DEFAULT_CONFIRM_EVERY_WRITE = emptyList()` | 微信写操作无需确认 |
| 222 | `checkRead()` deny 检查跳过 | 读取操作不拦截 |
| 228 | `checkWrite()` deny 检查跳过 | 写入操作不拦截 |
| 411 | 屏幕描述中的 deny 替换跳过 | 模型能看到被拦截应用的屏幕 |

## 三、应用补丁

### 方法 A：Git 应用（推荐）

```bash
cd /path/to/dsh-Go
git apply /path/to/patches/SafeMode.kt.diff
git apply /path/to/patches/RuntimeController.kt.diff
git apply /path/to/patches/DshProcess.kt.diff
git apply /path/to/patches/SafetyGate.kt.diff
```

### 方法 B：手动修改

按上方"修改方案"表格，用 IDE 打开对应文件，逐个修改。每行修改都已在真实源码中验证过位置。

## 四、编译

```bash
cd /path/to/dsh-Go
flutter pub get
cd app/android
./gradlew assembleRelease
# 输出：app/android/app/build/outputs/apk/release/app-release.apk
```

## 五、安装与验证

```bash
adb install -r app-release.apk
# 或直接在手机上安装
```

验证清单：

1. 打开 App → 本机引擎 → 启动
2. 确认日志中**不出现** `DSH_APP_SAFE_MODE=1`
3. 确认日志中**不出现** `--profile dsh-app-safe`
4. 发送消息测试 → 模型应正常响应
5. 检查你的四条注入路径是否生效（通过 DevTools 查看 plugin 列表）

## 六、关于"消息发不了"的完整根因

结合所有对话，问题由两个独立原因叠加：

1. **安全模式开启**（截图确认）：所有插件被禁用，你的注入路径全部失效
2. **`reasoningEfforts` 配置格式错误**：`llm-pi-ai` 插件加载失败，即使关闭安全模式也需要修复

**修复顺序**：
1. 先编译安装无限制版 APK（关闭安全模式）
2. 再修复 `~/.dsh/profiles/web/llm-pi-ai.yml` 中的 `reasoningEfforts` 格式
3. 重启验证

## 七、文件清单

```
patches/
├── SafeMode.kt.diff            (8 insertions, 8 deletions)
├── RuntimeController.kt.diff   (6 insertions, 5 deletions)
├── DshProcess.kt.diff         (2 insertions, 2 deletions)
└── SafetyGate.kt.diff         (6 insertions, 14 deletions)
```

4 个 diff 文件，共 21 处修改，全部已验证行号准确。
