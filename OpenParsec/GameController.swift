import UIKit
import GameController
import Combine
import CoreHaptics
import CoreMotion
import simd
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

	/// L2 是否按住（陀螺仪瞄准的激活键）
	private(set) var aimTriggerHeld = false
	/// 手柄右摇杆的当前值（Parsec 坐标：X 右正、Y 上正）。
	/// 陀螺仪接管右摇杆时，由 GyroController 把这两项与陀螺仪贡献叠加后统一发送。
	private(set) var rightStickParsecX: Float = 0
	private(set) var rightStickParsecY: Float = 0

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
		// 没实例（首启还没连过）或已断开时都不能发消息：前者是 nil 崩溃，
		// 后者是往废弃的 client 发消息，可能崩在 SDK 内部。
		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
		CParsec.sendGameControllerButtonMessage(controllerId: id, target, pressed: pressed)
	}

	private func handleTrigger(_ axis: ParsecGamepadAxis, _ value: Float, label: String, id: UInt32) {
		if axis == GAMEPAD_AXIS_TRIGGERL {
			aimTriggerHeld = value > 0.5
		}
		if value > 0.05 {
			lastEvent = "\(label) → \(String(format: "%.2f", value))"
		}
		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
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

		if axisY == GAMEPAD_AXIS_RY {
			rightStickParsecX = ax
			rightStickParsecY = ay
			// 陀螺仪接管右摇杆时只更新快照，由 GyroController 叠加后统一发出（100Hz）
			if GyroController.shared.ownsRightStick { return }
		}

		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
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
			if CParsec.hasInstance {
				CParsec.sendGameControllerUnplugMessage(controllerId: UInt32(index + 1))
			}
			orderedControllers.remove(at: index)
		}
		delegate?.inputManager(self, didDisconnect: controller)
		if orderedControllers.isEmpty {
			// 手柄全拔了：别让 L2 的"按住"状态残留，否则陀螺仪会在没手柄时以为闸门是开的
			aimTriggerHeld = false
			rightStickParsecX = 0
			rightStickParsecY = 0
		}
		registerControllerHandler()
	}
}

protocol InputManagerDelegate: AnyObject {
	func inputManager(_ manager: GamepadController, didConnect controller: GCController)
	func inputManager(_ manager: GamepadController, didDisconnect controller: GCController)
}

// MARK: - 陀螺仪

/// 陀螺仪输出目标
enum GyroTarget: Int, CaseIterable, Hashable {
	case mouse
	case rightStick

	var desc: String {
		switch self {
		case .mouse: return L("Mouse")
		case .rightStick: return L("Right Stick")
		}
	}
}

/// 陀螺仪 -> 鼠标相对移动 / 右摇杆。
///
/// Parsec 协议没有陀螺仪通道，所以只能"模拟"：
/// - `.mouse`：转动换算成像素位移（FPS 瞄准）
/// - `.rightStick`：转动映射成右摇杆推杆量，并与手柄自己的右摇杆**叠加**（混合瞄准）
///
/// 轴映射不写死横竖屏：用重力求世界竖直轴，水平 = 在该轴上的投影，垂直 = 在屏幕水平轴上的投影。
/// 启动时静止采样 0.5s 求零偏；按住 L2 才输出（没接手柄时自动放行）。
final class GyroController: ObservableObject {

	static let shared = GyroController()

	@Published private(set) var statusText: String = "—"

	private let motion = CMMotionManager()
	private let queue: OperationQueue = {
		let q = OperationQueue()
		q.maxConcurrentOperationCount = 1
		q.qualityOfService = .userInteractive
		return q
	}()

	private var running = false
	private var calibrating = false
	private var calibH: Double = 0
	private var calibV: Double = 0
	private var calibCount = 0
	private var biasH: Double = 0
	private var biasV: Double = 0
	private var filteredH: Double = 0
	private var filteredV: Double = 0
	private var samples = 0
	private var lastStickX: Float = 0
	private var lastStickY: Float = 0
	/// 0.5s @ 100Hz
	private let calibrationTarget = 50

	private init() {
		let center = NotificationCenter.default
		center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
			self?.stop()
		}
		center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
			self?.startIfNeeded()
		}
	}

	var isAvailable: Bool {
		return motion.isDeviceMotionAvailable
	}

	/// 是否由陀螺仪接管右摇杆（此时手柄自己的右摇杆由这里统一发送，两者叠加）
	var ownsRightStick: Bool {
		return SettingsHandler.gyroEnabled && SettingsHandler.gyroTarget == .rightStick
	}

	/// 按住 L2 才输出；没接手柄时无法按 L2，直接放行
	private var gateOpen: Bool {
		if !SettingsHandler.gyroRequireL2 { return true }
		if GamepadController.shared.orderedControllers.isEmpty { return true }
		return GamepadController.shared.aimTriggerHeld
	}

	func startIfNeeded() {
		if !Thread.isMainThread {
			DispatchQueue.main.async { [weak self] in self?.startIfNeeded() }
			return
		}
		guard SettingsHandler.gyroEnabled else {
			statusText = L("Off")
			return
		}
		guard motion.isDeviceMotionAvailable else {
			statusText = L("No gyroscope on this device")
			return
		}
		guard ParsecBackgroundManager.shared.hasActiveConnection else {
			statusText = L("Waiting for stream")
			return
		}
		guard !running else { return }

		running = true
		samples = 0
		beginCalibration()

		motion.deviceMotionUpdateInterval = 0.01
		motion.startDeviceMotionUpdates(to: queue) { [weak self] data, _ in
			guard let self = self else { return }
			self.handle(data)
		}
	}

	func stop() {
		if !Thread.isMainThread {
			DispatchQueue.main.async { [weak self] in self?.stop() }
			return
		}
		guard running else { return }
		running = false
		motion.stopDeviceMotionUpdates()
		if ownsRightStick {
			// 交还控制权前先把摇杆归零，避免卡在推满状态
			sendStick(0, 0, force: true)
		}
		statusText = SettingsHandler.gyroEnabled ? L("Stopped") : L("Off")
	}

	/// 「归中」= 重新做一次零偏校准，顺便清掉滤波残量
	func recenter() {
		beginCalibration()
	}

	private func beginCalibration() {
		calibrating = true
		calibH = 0
		calibV = 0
		calibCount = 0
		filteredH = 0
		filteredV = 0
		statusText = L("Calibrating, keep still")
	}

	private func handle(_ data: CMDeviceMotion?) {
		guard running, let d = data else { return }
		guard SettingsHandler.gyroEnabled else { stop(); return }

		guard let frame = rotationFrame(data: d) else { return }
		var h = frame.h
		var v = frame.v

		// 校准阶段：静止采样求零偏，不输出
		if calibrating {
			calibH += h
			calibV += v
			calibCount += 1
			if calibCount >= calibrationTarget {
				biasH = calibH / Double(calibCount)
				biasV = calibV / Double(calibCount)
				calibrating = false
			}
			updateStatus(h: 0)
			return
		}

		h -= biasH
		v -= biasV

		let dz = SettingsHandler.gyroDeadzone
		if abs(h) < dz { h = 0 }
		if abs(v) < dz { v = 0 }

		let a = min(max(SettingsHandler.gyroSmoothing, 0), 0.95)
		filteredH = a * filteredH + (1 - a) * h
		filteredV = a * filteredV + (1 - a) * v
		h = filteredH
		v = filteredV

		if SettingsHandler.gyroInvertH { h = -h }
		if SettingsHandler.gyroInvertV { v = -v }

		// 没按住 L2 时不输出；但右摇杆模式下仍要按 100Hz 把"手柄自己的摇杆"透传出去
		if !gateOpen {
			filteredH = 0
			filteredV = 0
			if ownsRightStick {
				sendStick(0, 0)
			}
			updateStatus(h: 0)
			return
		}

		if SettingsHandler.gyroTarget == .mouse {
			let dx = -h * 0.01 * 900 * SettingsHandler.gyroSensitivityH
			let dy = -v * 0.01 * 900 * SettingsHandler.gyroSensitivityV
			let ix = Int32(dx.rounded())
			let iy = Int32(dy.rounded())
			if ix != 0 || iy != 0 {
				CParsec.sendMouseDelta(ix, iy)
			}
		} else {
			let gain = 4.0
			// 转成 Parsec 摇杆坐标：X 向右为正，Y 向上为正
			let gx = Float(max(-1, min(1, -h * gain * SettingsHandler.gyroSensitivityH)))
			let gy = Float(max(-1, min(1, v * gain * SettingsHandler.gyroSensitivityV)))
			sendStick(gx, gy)
		}

		updateStatus(h: h)
	}

	/// 把转动拆成"世界竖直轴上的分量（水平）"和"屏幕水平轴上的分量（垂直）"，单位 rad/s。
	/// 优先用手柄自带陀螺仪（DualSense / DS4，iOS 17+），否则用手机自己的。
	private func rotationFrame(data d: CMDeviceMotion) -> (h: Double, v: Double)? {
		var rate = SIMD3<Double>(d.rotationRate.x, d.rotationRate.y, d.rotationRate.z)
		var gravity = SIMD3<Double>(d.gravity.x, d.gravity.y, d.gravity.z)

		if #available(iOS 17.0, *), SettingsHandler.gyroUseControllerMotion,
		   let controllerMotion = GamepadController.shared.orderedControllers.first?.motion {
			let r = controllerMotion.rotationRate
			let g = controllerMotion.gravity
			rate = SIMD3<Double>(r.x, r.y, r.z)
			gravity = SIMD3<Double>(g.x, g.y, g.z)
		}

		let up = gravity * -1.0
		let upLen = simd_length(up)
		guard upLen > 0.1 else { return nil }
		let upUnit = up / upLen

		let normal = SIMD3<Double>(0, 0, 1)
		var screenUp = upUnit - normal * simd_dot(upUnit, normal)
		if simd_length(screenUp) < 0.1 {
			screenUp = SIMD3<Double>(0, 1, 0)   // 手机平放时的退化情况
		}
		let screenUpUnit = screenUp / simd_length(screenUp)
		let screenRight = simd_cross(screenUpUnit, normal)

		return (simd_dot(rate, upUnit), simd_dot(rate, screenRight))
	}

	private func updateStatus(h: Double) {
		samples += 1
		guard samples % 20 == 0 else { return }
		let text: String
		if calibrating {
			text = L("Calibrating, keep still")
		} else if !gateOpen {
			text = L("Running") + " · " + L("Hold L2 to Aim")
		} else {
			text = String(format: "%@ · %.0f deg/s", L("Running"), abs(h) * 180.0 / Double.pi)
		}
		DispatchQueue.main.async { [weak self] in
			self?.statusText = text
		}
	}

	/// 右摇杆：把手柄自己的摇杆与陀螺仪贡献叠加后发出（100Hz）
	private func sendStick(_ gyroX: Float, _ gyroY: Float, force: Bool = false) {
		let px = GamepadController.shared.rightStickParsecX
		let py = GamepadController.shared.rightStickParsecY
		let x = min(max(px + gyroX, -1), 1)
		let y = min(max(py + gyroY, -1), 1)
		guard force || abs(x - lastStickX) > 0.02 || abs(y - lastStickY) > 0.02 else { return }
		lastStickX = x
		lastStickY = y
		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
		CParsec.sendGameControllerAxisMessage(controllerId: 1, GAMEPAD_AXIS_RX, toParsec(x))
		CParsec.sendGameControllerAxisMessage(controllerId: 1, GAMEPAD_AXIS_RY, toParsec(y))
	}

	private func toParsec(_ value: Float) -> Int16 {
		let v = min(max(value, -1), 1)
		return Int16((65535.0 * v - 1.0) / 2.0)
	}
}
