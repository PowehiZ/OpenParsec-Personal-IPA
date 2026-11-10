# 代码审查报告

审查范围：全部 29 个 Swift 文件 + `audio.c`。
结论：**发现的问题已全部修复**（含 8 个功能缺陷、7 类强制解包、2 处并发/生命周期隐患），
仅保留 2 项「按 SDK 契约安全」的写法与若干架构性建议。

---

## 一、功能缺陷（已修）

| # | 严重度 | 问题 | 位置 |
| --- | --- | --- | --- |
| 1 | **高** | `ownsRightStick` 没判 `running`：选「右摇杆」输出但陀螺仪没跑起来时，手柄右摇杆被吞掉、推了没反应 | `GameController.swift` |
| 2 | **高** | 无 Parsec 会话时仍发送输入：主界面按键 → 实例为 nil → 闪退；断开后按键 → 往废弃 client 发消息 | `GameController.swift` |
| 3 | 中 | `stop()` 先置 `running=false` 再判 `ownsRightStick`，交还控制权时从不补发摇杆归零 | `GameController.swift` |
| 4 | 中 | 未运行时点「归中」会卡在「校准中」且永不结束 | `GameController.swift` |
| 5 | 中 | 无 IMU 的手柄返回全零 `GCDeviceMotion`，会顶掉手机陀螺仪（表现为完全没反应）；改用重力模长 > 0.3 判定 | `GameController.swift` |
| 6 | 中 | 输出目标从右摇杆切到鼠标时不补发归零，主机侧摇杆停在最后值 → 视角持续漂移 | `GameController.swift` |
| 7 | 低 | `bind()` 不重置 `aimTriggerHeld`，换手柄后可能残留「按住 L2」 | `GameController.swift` |
| 8 | 低 | 打开「支持第二只手柄」需等下次插拔才生效 | `SettingsView.swift` |

## 二、强制解包（已全部清理）

| 位置 | 原写法 | 现在 |
| --- | --- | --- |
| `ParsecSDKBridge.swift` | `String(cString: msg!)` | `guard let msg = msg else { return }` |
| `ParsecSDKBridge.swift` | `pointer!`（user data）×4 | 改为 `guard let pointer = ParsecGetBuffer(...)` |
| `ParsecSDKBridge.swift` | `provider: providerRef!` | `guard let providerRef = CGDataProvider(...)`，失败先 `ParsecFree` 再返回 |
| `ParsecSDKBridge.swift` | `try! encoder.encode(videoConfig)` | `guard let data = try? encoder.encode(...) else { return }` |
| `ParsecViewController.swift` | `u!`、`currentImg!` ×5 | `if let img = currentImg`、`if let cursor = u`、局部 `cursorView` 再赋值 |
| `MainView.swift` | `clinfo!` ×3 | `guard let clinfo = NetworkHandler.clinfo else { ... }` |
| `ParsecView.swift` | `networkFailureSince!` | `networkFailureSince ?? Date()` |

## 三、并发与生命周期（已改）

| 问题 | 改法 |
| --- | --- |
| `CParsec.parsecImpl` 是 `ParsecService!` 隐式解包单例，事件线程读、主线程写，无同步 | 改为**可选 + `NSLock` 保护**，所有转发方法 `impl?.` 短路；另加 `hasInstance` 供输入侧判空。任何调用点在实例缺失时只是 no-op，不再崩溃 |
| 断开连接后实例仍存活（`destroy()` 只在 AppDelegate），残留输入可能打到废弃 client | 同上：指针为 nil 时短路；且输入侧再加 `hasActiveConnection` 双保险 |
| `mouseInfo` 事件线程写、UI 线程读，多字段 struct 可能读到半更新状态（光标偶发跳动） | `ParsecSDKBridge.mouseInfo` 改为**锁保护的 get/set**，读写都是完整快照 |
| `ParsecSDKBridge._parsec/_audio` 初始化失败时仍是 IUO，`deinit` 直接传给 C 函数会崩 | 新增 `isUsable`（两个指针都非空才算成功）；`CParsec.initialize()` 只挂可用实例；`deinit` 里判空后再 `ParsecDestroy` / `audio_destroy` |

## 四、保留未改（已确认安全或属架构建议）

| 位置 | 说明 |
| --- | --- |
| `ParsecSDKBridge._parsec/_audio` 仍声明为 `OpaquePointer!` | 已由 `isUsable` + `deinit` 判空兜住；改成 `Optional` 会给 20 多处 SDK 调用加噪声，收益低 |
| `video.0/video.1`、`pcs.decoder.0` | SDK 的定长 C 数组（固定 2 个解码器），无越界风险 |
| `ParsecViewController` 1366 行 | 架构问题（上帝对象），不是 bug；拆分风险大于收益 |
| `CParsec` 的锁只保护实例指针 | SDK 本身仍要求调用线程相对固定；这是封装层的边界，不是本次能消除的 |

## 五、验证方式

- 每次提交都由 GitHub Actions 全量编译（未签名 archive + fakesign IPA）后发布到 `nightly` release。
- 设置页顶部版本指纹 `1.4.0 · build N · <hash> run N` 可用于确认设备上装的是哪一次构建。
