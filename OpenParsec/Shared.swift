import Foundation
import SwiftUI
import ParsecSDK
import os
import Combine

var appScheme: ColorScheme = .dark

// MARK: - 本地化
//
// 约定：英文原文本身就是 key。
//   L("Settings")            → 英文界面返回 "Settings"，中文界面返回「设置」
//   L("%d hosts", count)     → 带参数字面量按 String(format:) 填充
// 查不到的词条回退英文原文，所以漏翻只会露出英文，不会出现空白。

enum AppLanguage: String, CaseIterable, Hashable {
	case english = "en"
	case chinese = "zh-Hans"

	/// 语言名按各自写法显示，不跟随界面语言翻译。
	var displayName: String {
		switch self {
		case .english:
			return "English"
		case .chinese:
			return "中文"
		}
	}
}

/// 语言设置的运行时载体。
///
/// 值仍然存在 `SettingsHandler.appLanguage`（@AppStorage）里，这里只负责把变更
/// 广播给订阅了它的视图 —— 否则改完设置，其它页面要等下一次重绘才会换语言。
final class LanguageStore: ObservableObject {
	static let shared = LanguageStore()

	@Published private(set) var language: AppLanguage

	private init() {
		// 首次启动（还没存过设置）跟随系统语言，之后一律以设置为准。
		if UserDefaults.standard.object(forKey: "appLanguage") == nil {
			let prefersChinese = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
			SettingsHandler.appLanguage = prefersChinese ? .chinese : .english
		}
		language = SettingsHandler.appLanguage
	}

	func set(_ language: AppLanguage) {
		guard language != self.language else { return }
		self.language = language            // 先广播：界面立刻换语言
		SettingsHandler.appLanguage = language   // 再落盘
	}
}

enum Localization {
	static var current: AppLanguage {
		return LanguageStore.shared.language
	}

	static func text(_ key: String) -> String {
		guard current == .chinese else { return key }
		return chinese[key] ?? key
	}

	/// 英文 → 简体中文。只收录界面上真的会出现的句子。
	/// 键名必须与代码里 `L("…")` 里的英文原文完全一致（大小写、标点都算）。
	static let chinese: [String: String] = [
		// 通用
		"ON": "开",
		"OFF": "关",
		"Cancel": "取消",
		"Close": "关闭",
		"Done": "完成",
		"Enter": "确认",
		"Auto": "自动",
		"Loading...": "加载中…",
		"Settings": "设置",
		"General": "通用",
		"Language": "语言",
		"Pick your preference:": "请选择：",
		"Version %@-%@": "版本 %@-%@",

		// 登录
		"Email": "邮箱",
		"Password": "密码",
		"Login": "登录",
		"Logout": "退出登录",
		"Login Failed": "登录失败",
		"Login failed (HTTP %d)": "登录失败（HTTP %d）",
		"Bad response from the server": "服务器返回异常",
		"Could not reach the server": "无法连接服务器",
		"Error: %@": "错误：%@",
		"2FA Code": "两步验证码",
		"Please enter your 2FA code from your authenticator app": "请输入验证器中的两步验证码",

		// 主页
		"Hosts": "主机",
		"Friends": "好友",
		"You": "我",
		"Connect": "连接",
		"Reconnect": "重新连接",
		"Sign in": "登录",
		"Last connected": "上次连接",
		"Last refreshed at %@": "上次刷新：%@",
		"Auto connect on launch": "启动时自动连接",
		"Your Parsec session expired": "Parsec 会话已过期",
		"Are you sure you want to logout?": "确定要退出登录吗？",
		"Invalid session": "会话无效",
		"Error gathering hosts: %@": "获取主机失败：%@",
		"Error gathering user info: %@": "获取账号信息失败：%@",
		"Error gathering friends: %@": "获取好友失败：%@",
		"Refreshing hosts...": "正在刷新主机…",
		"Requesting connection to %@...": "正在连接 %@…",
		"Waiting for %@ to approve you...": "等待 %@ 同意连接…",
		"%d host": "%d 台主机",
		"%d hosts": "%d 台主机",
		"%d friend": "%d 位好友",
		"%d friends": "%d 位好友",

		// 设置页
		"Interactivity": "交互",
		"Graphics": "画质",
		"Misc": "其他",
		"Gamepad": "手柄",
		"Status": "状态",
		"Battery": "电量",
		"Button Test": "按键测试",
		"Deadzone": "摇杆死区",
		"Invert Left Y": "左摇杆 Y 反转",
		"Invert Right Y": "右摇杆 Y 反转",
		"Swap A/B and X/Y": "交换 A/B、X/Y",
		"Second Controller": "支持第二只手柄",
		"Rumble Test": "震动测试",
		"Test": "测试",
		"Not connected": "未连接",
		"Full": "已满",
		"Rumble is not supported": "系统不支持震动",
		"This controller has no rumble": "该手柄不支持震动",
		"Rumble failed": "震动失败",
		"Mouse Movement": "鼠标移动",
		"Touchpad": "触控板",
		"Direct": "直接",
		"Right Click Position": "右键位置",
		"First Finger": "第一根手指",
		"Middle": "中间",
		"Second Finger": "第二根手指",
		"Scroll Speed": "滚轮速度",
		"Reverse Scroll Direction": "反转滚轮方向",
		"Cursor Scale": "光标大小",
		"Mouse Sensitivity": "鼠标灵敏度",
		"Option Key as Command": "Option 键当 Command",
		"Default Resolution": "默认分辨率",
		"Decoder": "解码器",
		"H.264": "H.264",
		"Prefer H.265": "优先 H.265",
		"Frame Rate": "帧率",
		"Auto (Device Max)": "自动（设备最高）",
		"120 FPS": "120 帧",
		"60 FPS": "60 帧",
		"30 FPS": "30 帧",
		"Decoder Compatibility": "解码器兼容模式",
		"Never Show Overlay": "不显示悬浮按钮",
		"Hide Status Bar": "隐藏状态栏",
		"Show Keyboard Button": "显示键盘按钮",
		"Always Show Status": "常驻显示状态",
		"Picture in Picture": "画中画",
		"Start Muted": "启动时静音",
		"Auto Reconnect": "自动重连",
		"Reconnect Error Prompts": "重连失败时弹窗",
		"Save Session Settings": "记住本次会话设置",

		// 分辨率档位
		"Host Resolution": "主机分辨率",
		"Client Resolution": "客户端分辨率",

		// 串流页
		"Hide Overlay": "隐藏悬浮按钮",
		"Sound: %@": "声音：%@",
		"Resolution": "分辨率",
		"Bitrate": "码率",
		"Switch Display": "切换显示器",
		"Select a Display:": "选择显示器：",
		"Constant FPS: %@": "恒定帧率：%@",
		"Zoom: %@": "缩放：%@",
		"Disconnect": "断开连接",
		"Host is using the machine": "主机正在使用中",
		"Reconnecting...": "正在重新连接…",
		"Reconnecting to %@...": "正在重新连接 %@…",
		"Connection lost...": "连接已断开…",
		"Disconnected (reason unknown)": "已断开（原因未知）",

		// 状态栏指标
		"Decode": "解码",
		"Encode": "编码",
		"Network": "网络",
		"RTx": "重传",
		"Queue": "队列",
		"Draw": "绘制",

		// Parsec 状态码
		"Authentication failed": "认证失败",
		"Can't reach Parsec": "无法连接 Parsec",
		"Team account deactivated": "团队账号已停用",
		"Couldn't reach the host": "无法连接主机",
		"Timed out in the background": "后台超时",
		"Network not supported": "网络不支持",
		"Host declined the connection": "主机拒绝了连接",
		"No permission to connect": "没有连接权限",
		"Host is full": "主机已满",
		"Connection canceled": "连接已取消",
		"Host is offline": "主机离线",
		"Kicked by the host": "被主机踢出",
		"Host shut down": "主机关机",
		"Host has no display": "主机没有显示器",
		"Host resolution problem": "主机分辨率异常",
		"Host capture failed": "主机采集失败",
		"Host didn't approve the connection": "主机未同意连接",
		"Confirm your Parsec account email first": "请先验证 Parsec 账号邮箱",
		"Still connecting to the host": "仍在连接主机",
		"Connection didn't start": "连接未启动",
		"Network timed out": "网络超时",
		"Host ended the connection": "主机结束了连接",
		"Connection was interrupted": "连接中断",
		"Parsec closed the connection": "Parsec 关闭了连接",
		"Lost the connection to Parsec": "与 Parsec 的连接已断开",
		"No network path to the host": "没有可用的网络路径",
		"Couldn't reach Parsec's network service": "无法连接 Parsec 网络服务",
		"No one is signed in on the host": "主机上没有用户登录",
		"Host can't stream at this resolution": "主机无法以该分辨率串流",
		"Host dropped the connection": "主机断开了连接",
		"Couldn't connect": "无法连接",
		"Disconnected": "已断开",
		"%@ (code %d)": "%@（代码 %d）"
	]
}

/// 取当前语言的文案；带参数时按 `String(format:)` 填充。
func L(_ key: String, _ args: CVarArg...) -> String {
	let template = Localization.text(key)
	guard !args.isEmpty else { return template }
	return String(format: template, arguments: args)
}

struct GLBData {
	let SessionKeyChainKey = "OPStoredAuthData"
}

class GLBDataModel {
	static let shared = GLBData()
}

extension String {
	static func fromBuffer(_ ptr: UnsafeMutablePointer<CChar>, length len: Int) -> String {
		// convert C char bytes using the UTF8 encoding
		let nsstr = NSString(bytes: ptr, length: len, encoding: NSUTF8StringEncoding)
		return nsstr! as String
	}
}

class CursorPositionHelper {
	static func toHost(_ xp: Int, _ yp: Int) -> (Int, Int) {
		let xh = CParsec.hostWidth
		let yh = CParsec.hostHeight
		let xc = CParsec.clientWidth
		let yc = CParsec.clientHeight

		let tc = yc / xc
		let th = yh / xh

		var xa: Float
		var ya: Float
		if th < tc {
			xa = Float(xp) * xh / xc
			ya = (Float(yp) - 0.5 * (yc - xc*th)) * xh / xc
		} else {
			ya = Float(yp) * yh / yc
			xa = (Float(xp) - 0.5 * (xc - yc/th)) * yh / yc
		}

		return (Int(ParsecSDKBridge.clamp(xa, minValue: 0, maxValue: CParsec.hostWidth)), Int(ParsecSDKBridge.clamp(ya, minValue: 0, maxValue: CParsec.hostHeight)))
	}

	static func toClient(_ xa: Int, _ ya: Int) -> (Int, Int) {
		let xh = CParsec.hostWidth
		let yh = CParsec.hostHeight
		let xc = CParsec.clientWidth
		let yc = CParsec.clientHeight

		let tc = yc / xc
		let th = yh / xh

		var xp: Float
		var yp: Float
		if th < tc {
			xp = Float(xa) * xc / xh
			yp = Float(ya) * xc / xh + 0.5 * (yc - xc*th)
		} else {
			yp = Float(ya) * yc / yh
			xp = Float(xa) * yc / yh + 0.5 * (xc - yc/th)
		}

		return (Int(ParsecSDKBridge.clamp(xp, minValue: 0, maxValue: CParsec.clientWidth)), Int(ParsecSDKBridge.clamp(yp, minValue: 0, maxValue: CParsec.clientHeight)))
	}
}

class SharedModel: ObservableObject {
	@Published var resolutionX = 0
	@Published var resolutionY = 0
	@Published var bitrate = 0
	@Published var constantFps = false
	@Published var output = "none"
	@Published var displayConfigs: [ParsecDisplayConfig] = []
	@Published var isBlocked = false

}

class DataManager {
	static let model = SharedModel()
}

extension ParsecStatus {
	func readable(connecting: Bool = false) -> String {
		switch self {
		case WS_ERR_AUTH:               return L("Authentication failed")
		case WS_ERR_CONNECT:            return L("Can't reach Parsec")
		case WS_ERR_TEAM_DEACTIVATED:   return L("Team account deactivated")
		case NAT_ERR_PEER_PHASE:        return L("Couldn't reach the host")
		case NETWORK_ERR_BG_TIMEOUT:    return L("Timed out in the background")
		case NETWORK_ERR_UNSUPPORTED:   return L("Network not supported")
		case CONNECT_WRN_DECLINED:      return L("Host declined the connection")
		case CONNECT_WRN_NO_PERMISSION: return L("No permission to connect")
		case CONNECT_WRN_NO_ROOM:       return L("Host is full")
		case CONNECT_WRN_CANCELED:      return L("Connection canceled")
		case CONNECT_WRN_PEER_GONE:     return L("Host is offline")
		case HOST_WRN_KICKED:           return L("Kicked by the host")
		case HOST_WRN_SHUTDOWN:         return L("Host shut down")
		case SERVER_ERR_DISPLAY:        return L("Host has no display")
		case SERVER_ERR_RESOLUTION:     return L("Host resolution problem")
		case CAPTURE_ERR_INIT:          return L("Host capture failed")
		case CONNECT_WRN_APPROVAL:      return L("Host didn't approve the connection")
		case CONNECT_WRN_UNCONFIRMED:   return L("Confirm your Parsec account email first")
		case PARSEC_CONNECTING:         return L("Still connecting to the host")
		case PARSEC_NOT_RUNNING:        return L("Connection didn't start")
		case NETWORK_WRN_TIMEOUT:       return L("Network timed out")
		case NETWORK_ERR_SHUTDOWN:      return L("Host ended the connection")
		case NETWORK_ERR_INTERRUPTED:   return L("Connection was interrupted")
		case WS_ERR_GOING_AWAY, WS_ERR_CLOSE: return L("Parsec closed the connection")
		case WS_ERR_READ, WS_ERR_WRITE: return L("Lost the connection to Parsec")
		case NAT_ERR_NO_CANDIDATES:     return L("No network path to the host")
		case NAT_ERR_STUN_PHASE:        return L("Couldn't reach Parsec's network service")
		case SERVER_ERR_NO_USER:        return L("No one is signed in on the host")
		case SERVER_ERR_MAX_RESOLUTION: return L("Host can't stream at this resolution")
		case SERVER_ERR_CLIENT_GONE, SERVER_ERR_CLIENT_ABORT: return L("Host dropped the connection")
		default:
			os_log("%{public}@", "[status] no text for \(rawValue)")
			return L("%@ (code %d)", connecting ? L("Couldn't connect") : L("Disconnected"), rawValue)
		}
	}

	var isPermanentFailure: Bool {
		switch self {
		case WS_ERR_AUTH, WS_ERR_TEAM_DEACTIVATED,
			 CONNECT_WRN_DECLINED, CONNECT_WRN_NO_PERMISSION, CONNECT_WRN_NO_ROOM,
			 CONNECT_WRN_CANCELED,
			 HOST_WRN_KICKED, HOST_WRN_SHUTDOWN,
			 NETWORK_ERR_UNSUPPORTED, SERVER_ERR_DISPLAY, SERVER_ERR_RESOLUTION,
			 CONNECT_WRN_UNCONFIRMED, SERVER_ERR_NO_USER, CONNECT_WRN_APPROVAL:
			return true
		default:
			return false
		}
	}
}
