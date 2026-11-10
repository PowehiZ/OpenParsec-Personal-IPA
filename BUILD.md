# OpenParsec（中文版）自动构建未签名 IPA

这个仓库是 **OpenParsec 1.4.0 的中文汉化 + 修补版**，配了一条
「push → GitHub Actions 用 macOS 编译 → 下载 `OpenParsec.ipa`」的流水线。

你不需要 Mac，编译在 GitHub 提供的 macOS 机器上完成。

---

## 1. 前提条件

| 项 | 要求 |
| --- | --- |
| ParsecSDK.framework | **不需要手动准备**，流水线会按 commit 自动拉取（见下文） |
| Apple 开发者账号 | **不需要**，产出的是未签名（fakesign）IPA |
| 仓库可见性 | 公开仓库 Actions 免费不限时长；私有仓库 macOS 按 10 倍计费 |

## 2. 怎么触发

- 推到 `main` 自动构建；
- 或手动：仓库页面 → **Actions** → `Build unsigned IPA` → **Run workflow**。

## 3. 怎么拿 IPA

**Actions → 该次运行 → 页面底部 Artifacts → `OpenParsec-ipa`**，下载解压得到 `OpenParsec.ipa`。

同时还有两个旁产物：

- `xcarchive` —— 想自己重新签名时用（14 天）
- `archive-log` —— xcodebuild 完整日志（7 天），排查失败时看这个

## 3.5 怎么确认装的是哪一版

设置页**最顶部**有一行灰色版本指纹：

```
1.4.0 · build 14 · 8408c87 run 14
```

- `1.4.0` —— `CFBundleShortVersionString`
- `build N` —— CI 的 run 号，每构建一次 +1
- `hash run N` —— 构建时的 commit 与 run 号，由 CI 写进 `Info.plist` 的 `GitCommitInfo`

**语言开关**在设置页第一组「通用 / General」的第一行，是并排的 `English | 中文` 分段按钮，
点一下即时切换，不用重启。

## 4. 这个 IPA 能直接装吗

**不能。** 它是未签名包，拖进 iPhone 装不上。三条路：

| 方式 | 条件 | 代价 |
| --- | --- | --- |
| **AltStore / SideStore** | 免费 Apple ID + 电脑装 AltServer | 每 **7 天**重签 |
| **TrollStore** | iOS 14.0–16.6.1 / 17.0 特定版本 | 永久免签 |
| **Sideloadly / 付费证书** | $99/年开发者账号 | 证书 1 年有效 |

想上 TestFlight / App Store 必须付费账号 + 证书 + 描述文件，是另一套流程。

## 5. 为什么不能直接用上游的 build.yml

上游那条流水线在这个工程上会连续失败，实际踩到的五个坑：

1. **ParsecSDK.framework 取不到（致命）**
   `.gitmodules` 指向 `MalfoyJW/parsec-sdk` 的 `sdk/ios/ParsecSDK.framework` 分支，该分支已被删除。
   → 删除 `.gitmodules`，改为构建时按 commit
   `bb336699ee7acd7a4eb0c460410a65c23d7f3879` 取（分支虽删、commit 还在，且其 tree 根目录就是 framework）。

2. **不能用 `parsec-sdk` 的 `master`**
   `master` 是 2019 年的 **SDK 1.0**：modulemap 叫 `Parsec`，`ParsecClientConfig` 没有
   `video[2]`/`decoderH265`，也缺 `PARSEC_CONNECTING`、`WS_ERR_TEAM_DEACTIVATED` 等状态码。
   会依次报 `Unable to resolve module dependency: 'ParsecSDK'`、`cannot find 'PARSEC_CONNECTING' in scope`、
   `has no member 'video'`。
   → 本项目配套的是 **SDK 6.0**，用对版本后源码一行不改就能编过。

3. **Xcode 版本写死 `26.2`** → 改为 `latest-stable`。

4. **`| xcpretty` 管道** → 镜像里没装它，会让 archive 以 127 退出；去掉管道，输出写进 `build-archive.log`。

5. **artifact 目录层级**：`upload-artifact` 上传目录时只保留内容、丢掉目录名，下载后
   `.xcarchive` 层级变了 → 上传 `build` 整层，打包 job 里按 `.app` 名字 `find` 定位。

## 6. 出错怎么查（不用登录也能看）

流水线失败时会把 `xxx.swift:行:列: error: ...` 这样的原始编译错误写成 **annotation**，
GitHub 的 annotation 接口公开可读，打开运行页面就能看到，不用翻日志。

> 坑中坑：`run:` 在 macOS 上默认是 `bash -e`，xcodebuild 一失败 shell 立即退出，
> 写在后面的「打印错误日志」逻辑永远执行不到，于是只看得到 `exit code 65`。
> 所以 archive 那一步必须开头 `set +e`。

## 7. 工程要点（维护时容易踩）

- `Frameworks/` 是**空目录**（framework 不进仓库），靠 `SYSTEM_FRAMEWORK_SEARCH_PATHS = $(PROJECT_DIR)/Frameworks` 查找；
- `DEVELOPMENT_TEAM = 3C3YHUUV75` 是原作者团队号，未签名构建不影响，但要真机自签需改成你自己的；
- deployment target 同时存在 13.0 与 14.0 两个配置；
- `Info.plist` 的 `UIRequiredDeviceCapabilities` 仍写着 `armv7`（只出 arm64 时无实际作用）；
- 本工程依赖 Parsec 私有服务端（`kessel-api.parsec.app`）与非公开的 user-data 协议，
  属于非官方客户端，账号与合规风险自负。
