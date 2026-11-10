# OpenParsec · 中文增强版（未签名 IPA）

> 基于 [hugeBlack/OpenParsec](https://github.com/hugeBlack/OpenParsec) 1.4.0 的 iOS/iPadOS Parsec 串流客户端，
> 增加了**中英双语热切换**、**手柄设置面板**、**陀螺仪瞄准**，并修掉了一批画面几何与输入相关的稳定性问题。
> 通过 GitHub Actions 云端 macOS 编译，产出**未签名（fakesign）IPA**，无需 Mac。

**最新构建（不登录即可下载）：**
`https://github.com/PowehiZ/OpenParsec-Personal-IPA/releases/download/nightly/OpenParsec.ipa`

版本指纹在 App 内 **设置页最顶部**：`1.4.0 · build N · <commit> run N`，`N` 即 Actions 的 run 号。

---

## ⚠️ 先读这一段

- **这是非官方客户端**，直连 Parsec 的私有 API（`kessel-api.parsec.app`）与非公开 user-data 协议，账号与合规风险自负。
- **内置的 IPA 是未签名的**，不能直接装进 iPhone，必须自签（见「安装」）。
- 仅用于个人学习与自用，如有侵权请联系删除。

---

## 功能一览

### 一、串流核心

| 功能 | 说明 |
| --- | --- |
| Parsec 协议客户端 | 内嵌 ParsecSDK **6.0**，支持 iOS 14.0+ / iPadOS |
| 解码器 | 默认 H.264；可「优先 H.265」；另有**解码器兼容模式**（个别设备花屏/卡顿时开） |
| 分辨率 | 「主机分辨率」「客户端动态分辨率」+ 14 个固定档位（3840×2160 / 3440×1440 / 2560×1440 / 1920×1080 … 1024×768） |
| 动态客户端分辨率 | 连接前按当前屏幕尺寸、旋转方向、`nativeScale` 刷新，不再拿 3840×2160 去协商 |
| 码率 | 3–50 Mbps，通过 user-data 协议实时下发给主机 |
| 帧率 | 自动（设备最高，ProMotion 最高 120）/ 120 / 60 / 30 |
| 多显示器 | 主机返回显示器列表后可在串流中切换 |
| 画中画 | iOS 15+，用 `AVSampleBufferDisplayLayer` 把 GL 帧送进 PiP |
| 后台保活 | 声明 `audio` 后台模式，切后台短时间不断流 |
| 自动重连 | 可开关；可选「重连失败时弹窗」，否则静默重连 |

### 二、输入

**触屏**
- 鼠标模式：**触控板**（相对移动）/ **直触**（点哪指哪）
- 右键位置：第一根手指 / 中间 / 第二根手指
- 滚轮速度、反转滚动方向、光标缩放、鼠标灵敏度
- 手势：长按拖拽（拖文件）、双指缩放、双指滚动、边缘滚动、松开后的惯性滑动（光标与滚轮各有独立参数）

**键盘**
- 软键盘含修饰键（Shift / Ctrl / Alt / Cmd）与快捷工具条
- 「Option 键当 Command」开关
- 按键重复、组合键发送、虚拟键盘逐字输入（带 20ms 释放延迟，避免游戏漏按）

**物理键鼠**
- USB / 蓝牙鼠标：左/右/中键、滚轮、移动（乘鼠标灵敏度）
- iPad 指针锁定（pointer lock）支持

**手柄**
- 支持标准 / MFi 手柄（DualShock 4、DualSense、Xbox 等），随插随用
- 全键映射：十字键、A/B/X/Y、L1/R1、**L2/R2（模拟轴 0–32767）**、L3/R3、Start/Back
- **摇杆死区**滑杆（解决老手柄漂移）
- 左右摇杆 **Y 轴独立反转**
- **交换 A/B、X/Y**（Nintendo 布局），按下时才判定，切换立即生效
- **支持第二只手柄**（绑定为 controllerId 2）
- **按键测试**：实时显示「物理键 → 实际发出的键」，用来排查键位
- 显示已连接手柄型号与电量
- **震动测试**（CoreHaptics 双脉冲）

### 三、陀螺仪瞄准

Parsec 协议没有陀螺仪通道，所以这里是**模拟输出**（两选一，运行中可切）：

| 输出 | 适用 | 说明 |
| --- | --- | --- |
| **鼠标** | FPS 瞄准 | 转动换算成像素位移，主机把它当无线鼠标 |
| **右摇杆** | 纯手柄游戏 | 转动映射成右摇杆推杆量，**与手柄自己的右摇杆叠加** |

- **零偏自动校准**：启用/归中时静止采样 0.5s 求零偏，抑制「手不动视角自己飘」
- **按住 L2 才启用**（默认开）：平时用触屏/摇杆走位，按住 L2 陀螺仪才接管；L2 本身仍照常发给主机；没接手柄时自动放行
- **轴映射不写死横竖屏**：用重力求世界竖直轴，横屏/竖屏/斜拿方向一致
- 水平/垂直灵敏度独立、死区、平滑、反转水平/垂直
- **优先用手柄自带陀螺仪**（iOS 17+ / DualSense / DualShock 4）；没有 IMU 的手柄（如 GameSir G8+）自动回退手机陀螺仪
- 仅在串流中运行，断开/切后台/退出 app 自动停止，不空转耗电

### 四、界面与设置

- **中英双语，热切换**：设置页第一个分组「通用 → 语言」，并排 `English | 中文`，点一下全界面立即切换（无需重启）
- 设置页共 **6 组 / 43 项**：通用（语言）、交互、手柄、陀螺仪、画质、其他
- **版本指纹**：设置页顶部显示 `1.4.0 · build N · <commit> run N`
- **串流悬浮菜单**：解码 / 编码 / 网络延迟、码率、重传、队列、绘制 FPS，以及解码器与分辨率；第二行还会显示画面几何信息（`view / offset / inset / zoom / host`），便于排查偏移
- 悬浮按钮可隐藏、状态栏可隐藏、「常驻显示状态」开关

### 五、稳定性修复（相对上游 1.4.0）

**画面几何**
- 禁止安全区自动改写 `contentInset`，避免画面被整体推移（「上方缺一块、下方黑边」）
- 未缩放时强制 `contentInset`/`contentOffset` 归零；旋转时同时重置
- 上报给 SDK 的缩放系数与 GL drawable 的真实 `contentScaleFactor` 一致（缩放态不再用 `UIScreen.main.scale`）
- 重连后重新下发流尺寸；`GLKView` 原点钉回 `(0,0)`，避免相对 `contentView` 漂移

**输入与并发**
- 无 Parsec 会话 / 已断开时**不再发送**手柄与陀螺仪输入（修复按任意键闪退）
- `CParsec` 门面从「隐式解包单例」改为**可选 + 锁**，调用点在实例缺失时是 no-op 而非崩溃
- `mouseInfo`（事件线程写、UI 线程读）加锁，避免读到半更新状态
- `ParsecInit` / `audio_init` 失败时不挂载半成品实例，`deinit` 判空后再释放
- **全工程零强制解包**（`try!` / `as!` / `xxx!`），详见 [CODE-REVIEW.md](CODE-REVIEW.md)

---

## 安装

IPA 是**未签名**的（ldid fakesign），所以只能自签安装：

| 方式 | 要求 | 代价 |
| --- | --- | --- |
| **AltStore / SideStore** | 免费 Apple ID + 电脑装 AltServer | 每 **7 天**重签一次，最多 3 个自签 App |
| **TrollStore** | iOS 14.0–16.6.1 / 17.0 特定版本 | 永久免签，但仅限支持的系统 |
| **Sideloadly / 付费证书** | 开发者账号（$99/年） | 证书 1 年有效 |

> 覆盖安装会保留原有设置（`UserDefaults` 不清空）。想要 TestFlight / App Store 必须付费账号 + 证书 + 描述文件。

---

## 下载与版本

- **固定直链**（每次构建自动覆盖，不登录可下）：
  <https://github.com/PowehiZ/OpenParsec-Personal-IPA/releases/download/nightly/OpenParsec.ipa>
- **按次下载**：Actions → 某次运行 → 底部 Artifacts → `OpenParsec-ipa`
- 其他产物：`xcarchive`（想自己重签时用）、`archive-log`（xcodebuild 完整日志）

**怎么确认装的是哪一版**：设置页顶部 `1.4.0 · build N · <hash> run N`，与 Actions 里的 run 号一一对应。

---

## 构建

推送即构建，无需本地 Mac：

| 阶段 | 内容 |
| --- | --- |
| `Archive (unsigned)` | `macos-latest` + 最新稳定版 Xcode，`CODE_SIGNING_ALLOWED=NO` 归档；构建时按 commit 拉取 ParsecSDK **6.0** |
| `Package fakesigned IPA` | Ubuntu 上用 `ldid` 做 fakesign，打成 `Payload/OpenParsec.app` 的 IPA |
| `Publish IPA to release` | 覆盖发布到 `nightly` release |

细节与踩坑记录见 [BUILD.md](BUILD.md)。

---

## 已知限制

1. **陀螺仪只能是模拟输出**：协议无原生通道，所以本质是"鼠标位移"或"摇杆轴"，效果取决于游戏是否支持鼠标/右摇杆。
2. **依赖 Parsec 私有接口**：`kessel-api.parsec.app` 一旦变更，登录/主机列表会失效。
3. **手柄陀螺仪需要 iOS 17+** 且手柄本身带六轴（DualSense / DS4）。
4. 同时只跑一路串流实例。

---

## 许可与致谢

- 本项目继承上游 **GPLv3**（见 [LICENSE](LICENSE)）。
- 上游：[hugeBlack/OpenParsec](https://github.com/hugeBlack/OpenParsec)（Parsec 客户端本体）。
- ParsecSDK 版权归 Parsec 所有，本项目仅按其分发条款在构建时拉取。
