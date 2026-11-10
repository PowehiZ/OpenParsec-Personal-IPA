import Foundation
import SwiftUI

struct SettingsHandler {
	/// 界面语言，默认英文（与历史行为一致）。可选 English / 中文。
	@AppStorage("appLanguage") public static var appLanguage: AppLanguage = .english
	// public static var renderer:RendererType = .opengl
	@AppStorage("resolution") public static var resolution: ParsecResolution = .client
	@AppStorage("bitrate") public static var bitrate: Int = 0
	@AppStorage("decoder") public static var decoder: DecoderPref = .h264
	@AppStorage("cursorMode") public static var cursorMode: CursorMode = .touchpad
	@AppStorage("cursorScale") public static var cursorScale: Double = 0.5
	@AppStorage("mouseSensitivity") public static var mouseSensitivity: Double = 1.0
	@AppStorage("optionAsCommand") public static var optionAsCommand: Bool = false
	@AppStorage("noOverlay") public static var noOverlay: Bool = false
	@AppStorage("hideStatusBar") public static var hideStatusBar: Bool = true
	@AppStorage("rightClickPosition") public static var rightClickPosition: RightClickPosition = .firstFinger
	@AppStorage("reverseScrollDirection") public static var reverseScrollDirection: Bool = false
	@AppStorage("scrollSensitivity") public static var scrollSensitivity: Double = 1.5
	@AppStorage("preferredFramesPerSecond") public static var preferredFramesPerSecond: Int = 60 // 0 = use device max (ProMotion)
	@AppStorage("decoderCompatibility") public static var decoderCompatibility: Bool = false // Enable for stutter issues on some devices
	@AppStorage("showKeyboardButton") public static var showKeyboardButton: Bool = true
	@AppStorage("alwaysShowStatus") public static var alwaysShowStatus: Bool = false
	@AppStorage("enablePiP") public static var enablePiP: Bool = false
	@AppStorage("startMuted") public static var startMuted: Bool = false
	@AppStorage("autoReconnect") public static var autoReconnect: Bool = true
	@AppStorage("errorPrompts") public static var errorPrompts: Bool = false
	@AppStorage("autoConnectOnLaunch") public static var autoConnectOnLaunch: Bool = false

	@AppStorage("saveSessionSettings") public static var saveSessionSettings: Bool = true
	@AppStorage("savedZoomEnabled") public static var savedZoomEnabled: Bool = false
	@AppStorage("savedConstantFps") public static var savedConstantFps: Bool = false
	@AppStorage("savedMuted") public static var savedMuted: Bool = false

	// 手柄
	@AppStorage("gamepadDeadzone") public static var gamepadDeadzone: Double = 0.0
	@AppStorage("gamepadInvertLeftY") public static var gamepadInvertLeftY: Bool = false
	@AppStorage("gamepadInvertRightY") public static var gamepadInvertRightY: Bool = false
	@AppStorage("gamepadSwapABXY") public static var gamepadSwapABXY: Bool = false
	@AppStorage("gamepadSecondController") public static var gamepadSecondController: Bool = false

	// 陀螺仪（Parsec 协议没有陀螺仪通道，只能是"模拟"输出）
	@AppStorage("gyroEnabled") public static var gyroEnabled: Bool = false
	@AppStorage("gyroTarget") public static var gyroTarget: GyroTarget = .mouse
	@AppStorage("gyroSensitivityH") public static var gyroSensitivityH: Double = 1.0
	@AppStorage("gyroSensitivityV") public static var gyroSensitivityV: Double = 1.0
	@AppStorage("gyroDeadzone") public static var gyroDeadzone: Double = 0.02
	@AppStorage("gyroSmoothing") public static var gyroSmoothing: Double = 0.3
	@AppStorage("gyroInvertH") public static var gyroInvertH: Bool = false
	@AppStorage("gyroInvertV") public static var gyroInvertV: Bool = false

}
