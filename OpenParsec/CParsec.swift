import ParsecSDK
import SwiftUI
import UIKit
import CoreGraphics
import GLKit

enum ParsecResolution: String, CaseIterable, Hashable {
	case host = "Host Resolution"
	case client = "Client Resolution" // updated dynamically during connection
	case r3840x2160_16_9 = "3840x2160 (16:9)"
	case r3840x1600_21_9 = "3840x1600 (21:9)"
	case r3440x1440_21_9 = "3440x1440 (21:9)"
	case r2560x1600_16_10 = "2560x1600 (16:10)"
	case r2560x1440_16_9 = "2560x1440 (16:9)"
	case r2560x1080_21_9 = "2560x1080 (21:9)"
	case r1920x1200_16_10 = "1920x1200 (16:10)"
	case r1920x1080_16_9 = "1920x1080 (16:9)"
	case r1680x1050_16_10 = "1680x1050 (16:10)"
	case r1600x1200_4_3 = "1600x1200 (4:3)"
	case r1366x768_16_9 = "1366x768 (16:9)"
	case r1280x1024_5_4 = "1280x1024 (5:4)"
	case r1280x800_16_10 = "1280x800 (16:10)"
	case r1280x720_16_9 = "1280x720 (16:9)"
	case r1024x768_4_3 = "1024x768 (4:3)"

	private static var clientSize: (width: Int, height: Int) = (3840, 2160)

	var width: Int {
		switch self {
		case .host:
			return 0
		case .client:
			return ParsecResolution.clientSize.width
		case .r3840x2160_16_9:
			return 3840
		case .r3840x1600_21_9:
			return 3840
		case .r3440x1440_21_9:
			return 3440
		case .r2560x1600_16_10:
			return 2560
		case .r2560x1440_16_9:
			return 2560
		case .r2560x1080_21_9:
			return 2560
		case .r1920x1200_16_10:
			return 1920
		case .r1920x1080_16_9:
			return 1920
		case .r1680x1050_16_10:
			return 1680
		case .r1600x1200_4_3:
			return 1600
		case .r1366x768_16_9:
			return 1366
		case .r1280x1024_5_4:
			return 1280
		case .r1280x800_16_10:
			return 1280
		case .r1280x720_16_9:
			return 1280
		case .r1024x768_4_3:
			return 1024
		}
	}

	var height: Int {
		switch self {
		case .host:
			return 0
		case .client:
			return ParsecResolution.clientSize.height
		case .r3840x2160_16_9:
			return 2160
		case .r3840x1600_21_9:
			return 1600
		case .r3440x1440_21_9:
			return 1440
		case .r2560x1600_16_10:
			return 1600
		case .r2560x1440_16_9:
			return 1440
		case .r2560x1080_21_9:
			return 1080
		case .r1920x1200_16_10:
			return 1200
		case .r1920x1080_16_9:
			return 1080
		case .r1680x1050_16_10:
			return 1050
		case .r1600x1200_4_3:
			return 1200
		case .r1366x768_16_9:
			return 768
		case .r1280x1024_5_4:
			return 1024
		case .r1280x800_16_10:
			return 800
		case .r1280x720_16_9:
			return 720
		case .r1024x768_4_3:
			return 768
		}
	}

	var desc: String {
		return L(rawValue)
	}

	static var resolutions: [ParsecResolution] {
		return Array(Self.allCases)
	}

	static var bitrates = [3, 5, 7, 10, 15, 20, 25, 30, 35, 40, 45, 50]

	static func updateClientResolution(width: Int, height: Int) {
		clientSize = (width, height)
	}

	/// 按当前屏幕（含旋转方向与 nativeScale）刷新 `.client` 的尺寸。
	/// `.client` 是一个"动态"档位：旧实现只在串流页 onAppear 时刷新一次，
	/// 而 `connect()` 在那之前就会读取它，第一次连接会带着 3840x2160 的
	/// 初始值去协商，连上后再纠正 —— 这里让连接发起前就能拿到真实尺寸。
	static func refreshClientResolution() {
		let bounds = UIScreen.main.bounds.size
		let scale = UIScreen.main.nativeScale
		let width = Int((bounds.width * scale).rounded())
		let height = Int((bounds.height * scale).rounded())
		guard width > 0, height > 0 else { return }
		updateClientResolution(width: width, height: height)
	}
}

struct MouseInfo {
	var pngCursor: Bool = false
	var mouseX: Int32 = 1
	var mouseY: Int32 = 1
	var cursorWidth = 0
	var cursorHeight = 0
	var cursorHotX = 0
	var cursorHotY = 0
	var cursorImg: CGImage?
	var cursorHidden = false
	var mousePositionRelative = false
}

protocol ParsecService {
	var clientWidth: Float { get }
	var clientHeight: Float { get }
	var hostWidth: Float { get }
	var hostHeight: Float { get }
	var mouseInfo: MouseInfo { get }

	func connect(_ peerID: String) -> ParsecStatus
	func disconnect()
	func getStatus() -> ParsecStatus
	func getStatusEx(_ pcs: inout ParsecClientStatus) -> ParsecStatus
	func setFrame(_ width: CGFloat, _ height: CGFloat, _ scale: CGFloat)
	func renderGLFrame(timeout: UInt32)
	func glDestroy()
	func setMuted(_ muted: Bool)
	func applyConfig()
	func sendMouseMessage(_ button: ParsecMouseButton, _ x: Int32, _ y: Int32, _ pressed: Bool)
	func sendMouseClickMessage(_ button: ParsecMouseButton, _ pressed: Bool)
	func sendMouseDelta(_ dx: Int32, _ dy: Int32)
	func sendMousePosition(_ x: Int32, _ y: Int32)
	func sendKeyboardMessage(event: KeyBoardKeyEvent)
	func sendKeyboardMessage(keyCode: UInt32, pressed: Bool)
	func sendVirtualKeyboardInput(text: String)
	func sendVirtualKeyboardInput(text: String, isOn: Bool)
	func sendGameControllerButtonMessage(controllerId: UInt32, _ button: ParsecGamepadButton, pressed: Bool)
	func sendGameControllerAxisMessage(controllerId: UInt32, _ button: ParsecGamepadAxis, _ value: Int16)
	func sendGameControllerUnplugMessage(controllerId: UInt32)
	func sendWheelMsg(x: Int32, y: Int32)
	func sendUserData(type: ParsecUserDataType, message: Data)
	func sendReleaseMessage()
	func reconnect(_ peerID: String) -> ParsecStatus
	func pause(video: Bool, audio: Bool) -> ParsecStatus
	func resume() -> ParsecStatus
	func updateHostVideoConfig()
	/// 停掉后台轮询并断开连接。释放实现之前必须调用，否则轮询线程会一直持有实例。
	func shutdown()
}

class CParsec {
	public static var hostWidth: Float {
		return parsecImpl.hostWidth
	}
	public static var hostHeight: Float {
		return parsecImpl.hostHeight
	}

	public static var clientWidth: Float {
		return parsecImpl.clientWidth
	}
	public static var clientHeight: Float {
		return parsecImpl.clientHeight
	}

	public static var mouseInfo: MouseInfo {
		return parsecImpl.mouseInfo
	}

	static var drawRate: Double = 0

	static var parsecImpl: ParsecService!

	/// 是否已创建 Parsec 实例。输入事件（手柄/键盘/鼠标）可能早于连接到达，
	/// 这时 `parsecImpl` 还是 nil，直接发消息会崩，必须先判空。
	static var hasInstance: Bool {
		return parsecImpl != nil
	}

	/// 创建（或重建）Parsec 实例。
	///
	/// 旧实例必须先显式 shutdown：`ParsecSDKBridge` 的 audio / event 两条轮询循环
	/// 用 `let self = self` 持有实例，只有 generation 变了才会退出。直接覆盖
	/// `parsecImpl` 会让旧实例既无法 deinit（ParsecDestroy / audio_destroy 不会执行），
	/// 两条循环还会继续轮询一个已"属于过去"的 client。
	static func initialize() {
		destroy()
		parsecImpl = ParsecSDKBridge()
	}

	/// 释放 Parsec 实例，重复调用安全。
	static func destroy() {
		guard let impl = parsecImpl else { return }
		parsecImpl = nil   // 先摘掉门面，之后的 CParsec 调用不会落到旧实例上
		impl.shutdown()    // 主动停轮询；deinit 里的 ParsecDestroy 才能真的被执行
	}

	static func connect(_ peerID: String) -> ParsecStatus {
		parsecImpl.connect(peerID)
	}

	static func disconnect() {
		parsecImpl.disconnect()
	}

	static func getStatus() -> ParsecStatus {
		return parsecImpl.getStatus()
	}

    static func getStatusEx(_ pcs: inout ParsecClientStatus) -> ParsecStatus {
		return parsecImpl.getStatusEx(&pcs)
	}

	static func setFrame(_ width: CGFloat, _ height: CGFloat, _ scale: CGFloat ) {
		parsecImpl.setFrame(width, height, scale)
	}

	static func renderGLFrame(timeout: UInt32 = 16) { // timeout in ms, 16 == 60 FPS, 8 == 120 FPS, etc.
		parsecImpl.renderGLFrame(timeout: timeout)
	}

	static func glDestroy() {
		parsecImpl.glDestroy()
	}

	static func setMuted(_ muted: Bool) {
		parsecImpl.setMuted(muted)
	}

	static func applyConfig() {
		parsecImpl.applyConfig()
	}

	static func updateHostVideoConfig() {
		parsecImpl.updateHostVideoConfig()
	}

	static func sendMouseMessage(_ button: ParsecMouseButton, _ x: Int32, _ y: Int32, _ pressed: Bool) {
		parsecImpl.sendMouseMessage(button, x, y, pressed)
	}

	static func sendMouseClickMessage(_ button: ParsecMouseButton, _ pressed: Bool) {
		parsecImpl.sendMouseClickMessage(button, pressed)
	}

	static func sendMouseDelta(_ dx: Int32, _ dy: Int32) {
		parsecImpl.sendMouseDelta(dx, dy)
	}

	static func sendMousePosition(_ x: Int32, _ y: Int32) {
		parsecImpl.sendMousePosition(x, y)
	}

	static func sendKeyboardMessage(event: KeyBoardKeyEvent) {
		parsecImpl.sendKeyboardMessage(event: event)
	}

	static func sendKeyboardMessage(keyCode: UInt32, pressed: Bool)
	{
		parsecImpl.sendKeyboardMessage(keyCode: keyCode, pressed: pressed)
	}

	static func sendVirtualKeyboardInput(text: String) {
		parsecImpl.sendVirtualKeyboardInput(text: text)
	}

	static func sendVirtualKeyboardInput(text: String, isOn: Bool) {
		parsecImpl.sendVirtualKeyboardInput(text: text, isOn: isOn)
	}

	static func sendGameControllerButtonMessage(controllerId: UInt32, _ button: ParsecGamepadButton, pressed: Bool) {
		parsecImpl.sendGameControllerButtonMessage(controllerId: controllerId, button, pressed: pressed)
	}

	static func sendGameControllerAxisMessage(controllerId: UInt32, _ button: ParsecGamepadAxis, _ value: Int16) {
		parsecImpl.sendGameControllerAxisMessage(controllerId: controllerId, button, value)
	}

	static func sendGameControllerUnplugMessage(controllerId: UInt32) {
		parsecImpl.sendGameControllerUnplugMessage(controllerId: controllerId)
	}

	static func sendWheelMsg(x: Int32, y: Int32) {
		parsecImpl.sendWheelMsg(x: x, y: y)
	}

	static func sendUserData(type: ParsecUserDataType, message: Data) {
		parsecImpl.sendUserData(type: type, message: message)
	}

	static func sendReleaseMessage() {
		parsecImpl.sendReleaseMessage()
	}

	@discardableResult
	static func reconnect(_ peerID: String) -> ParsecStatus {
		return parsecImpl.reconnect(peerID)
	}

	@discardableResult
	static func pause(video: Bool = true, audio: Bool = true) -> ParsecStatus {
		return parsecImpl.pause(video: video, audio: audio)
	}

	@discardableResult
	static func resume() -> ParsecStatus {
		return parsecImpl.resume()
	}

	static func getImpl() -> ParsecService {
		return parsecImpl
	}
}
