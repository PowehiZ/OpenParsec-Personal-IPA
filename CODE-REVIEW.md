# 代码审查报告

审查范围：全部 29 个 Swift 文件 + `audio.c`，重点是最近新增的「手柄 / 陀螺仪 / 设置」链路。
结论：**发现 8 个真实缺陷，已全部修复**（见下）；另有若干历史遗留的强制解包和 3 个架构隐患，未改动，列出供参考。

## 一、已修复

| # | 严重度 | 问题 | 位置 |
| --- | --- | --- | --- |
| 1 | **高** | `ownsRightStick` 没判 `running`：设置里选了「右摇杆」输出但陀螺仪没跑起来（未串流 / 设备无陀螺仪 / 已停止）时，手柄右摇杆被完全吞掉，**推了没反应** | `GameController.swift:463` |
| 2 | **高** | 输入在无 Parsec 会话时仍会发送：主界面按键 → `parsecImpl` 为 nil → 闪退；断开后按键 → 往废弃 client 发消息，可能崩在 SDK 内 | `GameController.swift:216,227,249,657` |
| 3 | 中 | `stop()` 里先把 `running` 置 false、再判断 `ownsRightStick`，导致交还控制权时**从不**补发摇杆归零（摇杆可能卡在推满） | `GameController.swift:512` |
| 4 | 中 | 未运行时点「归中」会进入校准态却永远收不到样本，状态行**永久卡在「校准中」** | `GameController.swift:520` |
| 5 | 中 | 没有 IMU 的手柄（如 GameSir G8+）也会返回一个 `GCDeviceMotion`，但数值全 0；「使用手柄陀螺仪」开启时它会把手机陀螺仪顶掉，表现为**陀螺仪完全没反应**。现用重力模长 > 0.3 判定该手柄是否真有传感器 | `GameController.swift:608` |
| 6 | 中 | 输出目标从「右摇杆」切到「鼠标」时不补发归零，主机侧摇杆停在最后的值上 → 视角自己持续漂移 | `GameController.swift:540` |
| 7 | 低 | `bind()` 不重置 `aimTriggerHeld`，换手柄/重连后可能残留「按住 L2」，陀螺仪闸门一直开着 | `GameController.swift:198` |
| 8 | 低 | 打开「支持第二只手柄」要等下一次插拔才生效 | `SettingsView.swift:294` |

## 二、历史遗留（未改，风险已评估）

| 位置 | 代码 | 评估 |
| --- | --- | --- |
| `ParsecSDKBridge.swift:684` | `try! encoder.encode(videoConfig)` | 结构体只有数字字段，实际不会失败 |
| `ParsecSDKBridge.swift:413` | `provider: providerRef!` | `NSData(bytes:length:)` 理论可能返回 nil，概率极低 |
| `ParsecSDKBridge.swift:89` | `String(cString: msg!)` | SDK 日志回调的 C 字符串，理论上可能为空 |
| `ParsecSDKBridge.swift:344,367` | `pointer!` | 上一行已有 `if pointer == nil { return }`，**安全** |
| `MainView.swift:471,526,567` | `clinfo!.session_id` | 前面都有 `if clinfo == nil { return }`，**安全**，只是写法啰嗦 |
| `ParsecViewController.swift:150,172,247` | `u!` | 光标 `UIImageView`，`viewDidLoad` 创建后才使用，**安全** |
| `ParsecSDKBridge` | `video.0/video.1`、`pcs.decoder.0` | SDK 定长 C 数组，无越界风险 |

## 三、架构隐患（改动大，暂不处理）

1. **`CParsec.parsecImpl` 是隐式解包单例**，事件线程写、主线程读，**无锁**。目前靠输入侧的 `hasInstance` / `hasActiveConnection` 两层 guard 兜住，但这是"防崩溃"而不是"线程安全"。
2. **`mouseInfo` 跨线程**：事件线程写、UI 线程读，`MouseInfo` 是 struct，读到的是值拷贝，可能拿到半更新状态（表现为光标偶尔跳一下）。
3. **实例生命周期**：`CParsec.destroy()` 只在 `AppDelegate` 调用；断开连接后实例仍然存活（只是 disconnected）。再次连接会走 `initialize()` 重建，但中间窗口期需要输入路径自己判断，这就是第 2 条 Bug 的来源。

## 四、验证方式

- 每次改动都由 GitHub Actions 全量编译验证（未签名 archive + fakesign IPA），构建产物在 `nightly` release。
- 设置页顶部的版本指纹（`1.4.0 · build N · <hash> run N`）可用于确认设备上装的是哪一次构建。
