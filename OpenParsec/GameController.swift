import UIKit
import GameController
import Combine
import CoreHaptics
import ParsecSDK

/// 手柄输入 + 手柄设置的可观察载体。
///
/// 做成单例：设置页需要实时看到「已连接 / 电量 / 最后按下的键」，
/// 而串流页里那个实例是随 ParsecViewController 创建的，设置页拿不到。
final class GamepadController: ObservableObject {

	static let shared = GamepadController()

	// MARK: - 供设置页绑定的状态
	@Published private(set) var statusText: String = L("Not connected")
	@Published private(set) var batteryText: String = ""
	@Published private(set) var lastEvent: String = "—"

	private(set) var orderedControllers: [GCController] = []
	private(set) var mice = Set<GCMouse>()
	weak var delegate: InputManagerDelegate?

	/// A/B、X/Y 对应的物理按键（是否互换在按下时才判定，改设置立刻生效）
	private enum PhysicalButton {
		case a, b, x, y, l1, r1, l3, r3, start, back
		case dpadUp, dpadDown, dpadLeft, dpadRight

		var label: String {
			switch self {
			case .a: return "A"
			case .b: return "B"
			case .x: return "X"
			case .y: return "Y"
			case .l1: return "L1"
			case .r1: return "R1"
			case .l3: return "L3"
			case .r3: return "R3"
			case .start: return "Start"
			case .back: return "Back"
			case .dpadUp: return "D-Pad ↑"
			case .dpadDown: return "D-Pad ↓"
			case .dpadLeft: return "D-Pad ←"
			case .dpadRight: return "D-Pad →"
			}
		}

		/// 解析成实际发给主机的 Parsec 按钮；A/B、X/Y 是否互换由设置决定。
		var parsec: ParsecGamepadButton {
			let swap = SettingsHandler.gamepadSwapABXY
			switch self {
			case .a: return swap ? GAMEPAD_BUTTON_B : GAMEPAD_BUTTON_A
			case .b: return swap ? GAMEPAD_BUTTON_A : GAMEPAD_BUTTON_B
			case .x: return swap ? GAMEPAD_BUTTON_Y : GAMEPAD_BUTTON_X
			case .y: return swap ? GAMEPAD_BUTTON_X : GAMEPAD_BUTTON_Y
			case .l1: return GAMEPAD_BUTTON_LSHOULDER
			case .r1: return GAMEPAD_BUTTON_RSHOULDER
			case .l3: return GAMEPAD_BUTTON_LSTICK
			case .r3: return GAMEPAD_BUTTON_RSTICK
			case .start: return GAMEPAD_BUTTON_START
			case .back: return GAMEPAD_BUTTON_BACK
			case .dpadUp: return GAMEPAD_BUTTON_DPAD_UP
			case .dpadDown: return GAMEPAD_BUTTON_DPAD_DOWN
			case .dpadLeft: return GAMEPAD_BUTTON_DPAD_LEFT
			case .dpadRight: return GAMEPAD_BUTTON_DPAD_RIGHT
			}
		}
	}

	private var didSetup = false

	private var maxControllerCount: Int {
		return SettingsHandler.gamepadSecondController ? 2 : 1
	}

	init() {
		setup()
	}

	/// 保留旧调用点（ParsecViewController.viewDidLoad 会调它），重复调用安全。
	public func viewDidLoad() {
		setup()
	}

	private func setup() {
		guard !didSetup else { return }
		didSetup = true

		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.didConnectController),
											   name: NSNotification.Name.GCControllerDidConnect,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.didDisconnectController),
											   name: NSNotification.Name.GCControllerDidDisconnect,
											   object: nil)

		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.didMouseConnectController),
											   name: NSNotification.Name.GCMouseDidConnect,
											   object: nil)
		NotificationCenter.default.addObserver(self,
											   selector: #selector(self.didMouseDisconnectController),
											   name: NSNotification.Name.GCMouseDidDisconnect,
											   object: nil)

		for controller in GCController.controllers() where !orderedControllers.contains(where: { $0 === controller }) {
			orderedControllers.append(controller)
		}

		GCController.startWirelessControllerDiscovery {}
		registerControllerHandler()
		registerMouseHandler()
		refreshStatus()
	}

	// MARK: - 状态

	func refreshStatus() {
		guard let first = orderedControllers.first else {
			statusText = L("Not connected")
			batteryText = ""
			return
		}
		var text = (first.vendorName ?? "Gamepad")
		if orderedControllers.count > 1 {
			text += " ×\(min(orderedControllers.count, maxControllerCount))"
		}
		statusText = text

		if let battery = first.battery {
			if battery.batteryLevel >= 0 {
				batteryText = String(format: "%.0f%%", battery.batteryLevel * 100)
			} else if battery.batteryState == .full {
				batteryText = L("Full")
			} else {
				batteryText = ""
			}
		} else {
			batteryText = ""
		}
	}

	// MARK: - 绑定

	func registerControllerHandler() {
		for (index, controller) in orderedControllers.enumerated() {
			if index >= maxControllerCount { break }
			let id = UInt32(index + 1)
			delegate?.inputManager(self, didConnect: controller)
			bind(controller, id: id)
		}
		refreshStatus()
	}

	private func bind(_ controller: GCController, id: UInt32) {
		guard let pad = controller.extendedGamepad else { return }

		func button(_ physical: PhysicalButton, _ input: GCControllerButtonInput?) {
			input?.pressedChangedHandler = { [weak self] _, _, pressed in
				self?.handleButton(physical, pressed, id: id)
			}
		}

		button(.a, pad.buttonA)
		button(.b, pad.buttonB)
		button(.x, pad.buttonX)
		button(.y, pad.buttonY)
		button(.l1, pad.leftShoulder)
		button(.r1, pad.rightShoulder)
		button(.l3, pad.leftThumbstickButton)
		button(.r3, pad.rightThumbstickButton)
		button(.back, pad.buttonOptions)
		button(.start, pad.buttonMenu)
		button(.dpadUp, pad.dpad.up)
		button(.dpadDown, pad.dpad.down)
		button(.dpadLeft, pad.dpad.left)
		button(.dpadRight, pad.dpad.right)

		// 扳机走模拟轴（0~1 → 0~32767），很多游戏只认按钮，这是历史行为，保持不变
		pad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
			self?.handleTrigger(GAMEPAD_AXIS_TRIGGERL, value, label: "L2", id: id)
		}
		pad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
			self?.handleTrigger(GAMEPAD_AXIS_TRIGGERR, value, label: "R2", id: id)
		}

		pad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
			self?.handleStick(x: x, y: y, axisX: GAMEPAD_AXIS_LX, axisY: GAMEPAD_AXIS_LY,
							  invertY: SettingsHandler.gamepadInvertLeftY, label: "左摇杆", id: id)
		}
		pad.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
			self?.handleStick(x: x, y: y, axisX: GAMEPAD_AXIS_RX, axisY: GAMEPAD_AXIS_RY,
							  invertY: SettingsHandler.gamepadInvertRightY, label: "右摇杆", id: id)
		}
	}

	// MARK: - 输入处理

	private func handleButton(_ physical: PhysicalButton, _ pressed: Bool, id: UInt32) {
		let target = physical.parsec
		if pressed {
			lastEvent = "\(physical.label) → \(Self.label(for: target)) #\(id)"
		}
		CParsec.sendGameControllerButtonMessage(controllerId: id, target, pressed: pressed)
	}

	private func handleTrigger(_ axis: ParsecGamepadAxis, _ value: Float, label: String, id: UInt32) {
		if value > 0.05 {
			lastEvent = "\(label) → \(String(format: "%.2f", value))"
		}
		CParsec.sendGameControllerAxisMessage(controllerId: id, axis, ButtonFloatToParsecInt(value))
	}

	private func handleStick(x: Float, y: Float, axisX: ParsecGamepadAxis, axisY: ParsecGamepadAxis,
							 invertY: Bool, label: String, id: UInt32) {
		let dz = Float(SettingsHandler.gamepadDeadzone)
		let ax = Self.applyDeadzone(x, dz)
		var ay = -Self.applyDeadzone(y, dz)   // Parsec 的 Y 轴方向与 GameController 相反
		if invertY { ay = -ay }

		if abs(ax) > 0.3 || abs(ay) > 0.3 {
			lastEvent = "\(label) → \(String(format: "%.2f", ax)), \(String(format: "%.2f", ay))"
		}
		CParsec.sendGameControllerAxisMessage(controllerId: id, axisX, ButtonFloatToParsecInt(ax))
		CParsec.sendGameControllerAxisMessage(controllerId: id, axisY, ButtonFloatToParsecInt(ay))
	}

	/// 死区：小于阈值的值归零，超出的部分重新映射到 0~1，避免"跳一下"
	private static func applyDeadzone(_ v: Float, _ dz: Float) -> Float {
		guard dz > 0.001 else { return v }
		let a = abs(v)
		if a <= dz { return 0 }
		let scaled = (a - dz) / (1 - dz)
		return v < 0 ? -scaled : scaled
	}

	func ButtonFloatToParsecInt(_ value: Float) -> Int16 {
		let newval: Float = (65535.0 * min(max(value, -1), 1) - 1.0) / 2.0
		return Int16(newval)
	}

	private static func label(for button: ParsecGamepadButton) -> String {
		switch button {
		case GAMEPAD_BUTTON_A: return "A"
		case GAMEPAD_BUTTON_B: return "B"
		case GAMEPAD_BUTTON_X: return "X"
		case GAMEPAD_BUTTON_Y: return "Y"
		case GAMEPAD_BUTTON_LSHOULDER: return "LB"
		case GAMEPAD_BUTTON_RSHOULDER: return "RB"
		case GAMEPAD_BUTTON_LSTICK: return "L3"
		case GAMEPAD_BUTTON_RSTICK: return "R3"
		case GAMEPAD_BUTTON_START: return "START"
		case GAMEPAD_BUTTON_BACK: return "BACK"
		case GAMEPAD_BUTTON_DPAD_UP: return "D↑"
		case GAMEPAD_BUTTON_DPAD_DOWN: return "D↓"
		case GAMEPAD_BUTTON_DPAD_LEFT: return "D←"
		case GAMEPAD_BUTTON_DPAD_RIGHT: return "D→"
		default: return "BTN \(button.rawValue)"
		}
	}

	// MARK: - 震动测试

	func testHaptics() {
		guard #available(iOS 14.0, *) else {
			lastEvent = L("Rumble is not supported")
			return
		}
		guard let controller = orderedControllers.first, let haptics = controller.haptics else {
			lastEvent = L("This controller has no rumble")
			return
		}
		do {
			let engine = try haptics.createEngine(withLocality: GCHapticsLocality.default)
			try engine?.start()
			let events = [
				CHHapticEvent(eventType: .hapticTransient, parameters: [
					CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
					CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
				], relativeTime: 0),
				CHHapticEvent(eventType: .hapticTransient, parameters: [
					CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
					CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
				], relativeTime: 0.18)
			]
			let pattern = try CHHapticPattern(events: events, parameters: [])
			let player = try engine?.makePlayer(with: pattern)
			try player?.start(atTime: 0)
			lastEvent = L("Rumble Test") + " ✓"
		} catch {
			lastEvent = L("Rumble failed") + ": \(error.localizedDescription)"
		}
	}

	// MARK: - 鼠标（USB / 蓝牙鼠标，保持原行为）

	func registerMouseHandler() {
		for mouse in GCMouse.mice() {
			mice.insert(mouse)
			mouse.mouseInput?.leftButton.pressedChangedHandler = { (_: GCControllerButtonInput, _: Float, pressed: Bool) in
				guard ParsecBackgroundManager.shared.hasActiveConnection else { return }
				CParsec.sendMouseClickMessage(MOUSE_L, pressed)
			}
			mouse.mouseInput?.rightButton?.pressedChangedHandler = { (_: GCControllerButtonInput, _: Float, pressed: Bool) in
				// pointer-lock toggles on the connect/disconnect view swap can synthesize a button edge
				// with no real input — dont forward it unless a session is actually live
				guard ParsecBackgroundManager.shared.hasActiveConnection else { return }
				CParsec.sendMouseClickMessage(MOUSE_R, pressed)
			}
			mouse.mouseInput?.middleButton?.pressedChangedHandler = { (_: GCControllerButtonInput, _: Float, pressed: Bool) in
				guard ParsecBackgroundManager.shared.hasActiveConnection else { return }
				CParsec.sendMouseClickMessage(MOUSE_MIDDLE, pressed)
			}
			mouse.mouseInput?.mouseMovedHandler = { (_: GCMouseInput, v: Float, v2: Float) in
				CParsec.sendMouseDelta(Int32(v / 1.25 * Float(SettingsHandler.mouseSensitivity)),
									   Int32(-v2 / 1.25 * Float(SettingsHandler.mouseSensitivity)))
			}
			mouse.mouseInput?.scroll.yAxis.valueChangedHandler = { (_: GCControllerAxisInput, value: Float) in
				CParsec.sendWheelMsg(x: Int32(value), y: 0)
			}
			mouse.mouseInput?.scroll.xAxis.valueChangedHandler = { (_: GCControllerAxisInput, value: Float) in
				CParsec.sendWheelMsg(x: 0, y: Int32(value))
			}
		}
	}

	@objc func didMouseConnectController(_ notification: Notification) {
		self.registerMouseHandler()
	}

	@objc func didMouseDisconnectController(_ notification: Notification) {
		guard let mouse = notification.object as? GCMouse else { return }
		mice.remove(mouse)
	}

	// MARK: - 连接变化

	@objc func didConnectController(_ notification: Notification) {
		if let controller = notification.object as? GCController,
		   !orderedControllers.contains(where: { $0 === controller }) {
			orderedControllers.append(controller)
		}
		registerControllerHandler()
	}

	@objc func didDisconnectController(_ notification: Notification) {
		guard let controller = notification.object as? GCController else { return }
		if let index = orderedControllers.firstIndex(where: { $0 === controller }) {
			CParsec.sendGameControllerUnplugMessage(controllerId: UInt32(index + 1))
			orderedControllers.remove(at: index)
		}
		delegate?.inputManager(self, didDisconnect: controller)
		registerControllerHandler()
	}
}

protocol InputManagerDelegate: AnyObject {
	func inputManager(_ manager: GamepadController, didConnect controller: GCController)
	func inputManager(_ manager: GamepadController, didDisconnect controller: GCController)
}
