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
/// 手柄上的一个物理控件（重映射的「来源」）
enum GamepadControl: String, CaseIterable, Codable, Identifiable {
	case a, b, x, y
	case l1, r1, l2, r2, l3, r3
	case start, back
	case dpadUp, dpadDown, dpadLeft, dpadRight

	var id: String { return rawValue }

	var label: String {
		switch self {
		case .a: return "A"
		case .b: return "B"
		case .x: return "X"
		case .y: return "Y"
		case .l1: return "LB"
		case .r1: return "RB"
		case .l2: return "LT"
		case .r2: return "RT"
		case .l3: return "L3"
		case .r3: return "R3"
		case .start: return "START"
		case .back: return "BACK"
		case .dpadUp: return "↑"
		case .dpadDown: return "↓"
		case .dpadLeft: return "←"
		case .dpadRight: return "→"
		}
	}

	/// 列表里用的名字：十字键加前缀，避免只看到一个箭头不知道是什么键
	var title: String {
		switch self {
		case .dpadUp: return "D-Pad ↑"
		case .dpadDown: return "D-Pad ↓"
		case .dpadLeft: return "D-Pad ←"
		case .dpadRight: return "D-Pad →"
		default: return label
		}
	}

	/// 扳机是模拟量，需要自己合成「按下 / 抬起」边沿
	var isAnalog: Bool {
		return self == .l2 || self == .r2
	}

	static var configurable: [GamepadControl] {
		return [.a, .b, .x, .y, .l1, .r1, .l2, .r2, .l3, .r3, .start, .back,
				.dpadUp, .dpadDown, .dpadLeft, .dpadRight]
	}
}

/// 一个控件最终发出的东西：按钮、轴，或「禁用」
enum GamepadTarget: String, CaseIterable, Codable, Identifiable {
	case none
	case a, b, x, y
	case lb, rb, l3, r3, start, back
	case dpadUp, dpadDown, dpadLeft, dpadRight
	case lx, ly, rx, ry, lt, rt

	var id: String { return rawValue }

	var label: String {
		switch self {
		case .none: return "—"
		case .a: return "A"
		case .b: return "B"
		case .x: return "X"
		case .y: return "Y"
		case .lb: return "LB"
		case .rb: return "RB"
		case .l3: return "L3"
		case .r3: return "R3"
		case .start: return "START"
		case .back: return "BACK"
		case .dpadUp: return "↑"
		case .dpadDown: return "↓"
		case .dpadLeft: return "←"
		case .dpadRight: return "→"
		case .lx: return "LX"
		case .ly: return "LY"
		case .rx: return "RX"
		case .ry: return "RY"
		case .lt: return "LT"
		case .rt: return "RT"
		}
	}

	var isButton: Bool {
		switch self {
		case .none, .lx, .ly, .rx, .ry, .lt, .rt: return false
		default: return true
		}
	}

	/// 按钮目标对应的 Parsec 按钮
	var parsecButton: ParsecGamepadButton? {
		switch self {
		case .a: return GAMEPAD_BUTTON_A
		case .b: return GAMEPAD_BUTTON_B
		case .x: return GAMEPAD_BUTTON_X
		case .y: return GAMEPAD_BUTTON_Y
		case .lb: return GAMEPAD_BUTTON_LSHOULDER
		case .rb: return GAMEPAD_BUTTON_RSHOULDER
		case .l3: return GAMEPAD_BUTTON_LSTICK
		case .r3: return GAMEPAD_BUTTON_RSTICK
		case .start: return GAMEPAD_BUTTON_START
		case .back: return GAMEPAD_BUTTON_BACK
		case .dpadUp: return GAMEPAD_BUTTON_DPAD_UP
		case .dpadDown: return GAMEPAD_BUTTON_DPAD_DOWN
		case .dpadLeft: return GAMEPAD_BUTTON_DPAD_LEFT
		case .dpadRight: return GAMEPAD_BUTTON_DPAD_RIGHT
		default: return nil
		}
	}

	/// 轴目标对应的 Parsec 轴
	var parsecAxis: ParsecGamepadAxis? {
		switch self {
		case .lx: return GAMEPAD_AXIS_LX
		case .ly: return GAMEPAD_AXIS_LY
		case .rx: return GAMEPAD_AXIS_RX
		case .ry: return GAMEPAD_AXIS_RY
		case .lt: return GAMEPAD_AXIS_TRIGGERL
		case .rt: return GAMEPAD_AXIS_TRIGGERR
		default: return nil
		}
	}
}

/// 按键映射的持久化：JSON（`[来源: 目标]`）存在 UserDefaults 里
enum GamepadMapping {
	/// 解码结果缓存。原来每次按键/摇杆事件都读一次 UserDefaults 再 JSON 解码，
	/// 摇杆 100Hz 时等于每秒上百次解码，会拖慢输入。现在只在 set/reset 后失效。
	private static var cache: [GamepadControl: GamepadTarget]?

	static var current: [GamepadControl: GamepadTarget] {
		if let cache = cache { return cache }
		let map = decode()
		cache = map
		return map
	}

	private static func decode() -> [GamepadControl: GamepadTarget] {
		let data = SettingsHandler.gamepadMappingData
		guard data.count > 0,
			  let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
			return [:]
		}
		var map: [GamepadControl: GamepadTarget] = [:]
		for (k, v) in decoded {
			if let c = GamepadControl(rawValue: k), let t = GamepadTarget(rawValue: v) {
				map[c] = t
			}
		}
		return map
	}

	static func target(for control: GamepadControl) -> GamepadTarget {
		if let t = current[control] { return t }
		return defaultTarget(for: control)
	}

	static func set(_ target: GamepadTarget, for control: GamepadControl) {
		var map = current
		map[control] = target
		persist(map)
		cache = map
	}

	static func reset() {
		persist([:])
		cache = [:]
	}

	/// 默认映射 = 同名对应（LT/RT 是轴）；「交换 A/B、X/Y」开关只影响默认值，
	/// 一旦用户手动改过某个键，就以映射表为准。
	static func defaultTarget(for control: GamepadControl) -> GamepadTarget {
		let swap = SettingsHandler.gamepadSwapABXY
		switch control {
		case .a: return swap ? .b : .a
		case .b: return swap ? .a : .b
		case .x: return swap ? .y : .x
		case .y: return swap ? .x : .y
		case .l1: return .lb
		case .r1: return .rb
		case .l2: return .lt
		case .r2: return .rt
		case .l3: return .l3
		case .r3: return .r3
		case .start: return .start
		case .back: return .back
		case .dpadUp: return .dpadUp
		case .dpadDown: return .dpadDown
		case .dpadLeft: return .dpadLeft
		case .dpadRight: return .dpadRight
		}
	}

	private static func persist(_ map: [GamepadControl: GamepadTarget]) {
		var raw: [String: String] = [:]
		for (c, t) in map { raw[c.rawValue] = t.rawValue }
		if let data = try? JSONEncoder().encode(raw) {
			SettingsHandler.gamepadMappingData = data
		}
	}
}

/// 单个手柄的震动引擎：一个常驻的连续事件 + 动态参数调制度，
/// 避免每次 rumble 事件都重建 pattern（会咔哒、也费 CPU）。
///
/// 注意：引擎和 player 必须被强引用住。之前"震动测试没反应"就是因为
/// 二者都是局部变量，函数返回即被 ARC 释放，震动还没输出就被掐断。
@available(iOS 14.0, *)
private final class RumbleEngine {
	private let engine: CHHapticEngine
	private let player: CHHapticAdvancedPatternPlayer
	private var lastIntensity: Double = -1
	private var lastSharpness: Double = -1

	init(haptics: GCControllerHaptics) throws {
		// 不同手柄支持的震动区域不同，`.default` 不一定在列表里，逐个试
		var created: CHHapticEngine?
		var failure: Error?
		for locality in RumbleEngine.candidates(haptics) {
			do {
				created = try haptics.createEngine(withLocality: locality)
				break
			} catch {
				failure = error
			}
		}
		guard let engine = created else {
			throw failure ?? NSError(domain: "OpenParsecRumble", code: -1,
									 userInfo: [NSLocalizedDescriptionKey: "no supported haptics locality"])
		}
		self.engine = engine

		let event = CHHapticEvent(eventType: .hapticContinuous,
								  parameters: [
									CHHapticEventParameter(parameterID: .hapticIntensity, value: 0),
									CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
								  ],
								  relativeTime: 0,
								  duration: 3600)
		let pattern = try CHHapticPattern(events: [event], parameters: [])
		let advancedPlayer = try engine.makeAdvancedPlayer(with: pattern)
		self.player = advancedPlayer
		try engine.start()
		try advancedPlayer.start(atTime: 0)
	}

	/// 优先 default，其次手柄声明支持的区域；列表为空时仍然试 default
	private static func candidates(_ haptics: GCControllerHaptics) -> [GCHapticsLocality] {
		let supported = haptics.supportedLocalities
		let preferred: [GCHapticsLocality] = [.default, .leftHandle, .rightHandle, .leftTrigger, .rightTrigger]
		if supported.isEmpty { return preferred }
		let filtered = preferred.filter { supported.contains($0) }
		return filtered.isEmpty ? preferred : filtered
	}

	func set(intensity: Double, sharpness: Double) {
		let i = min(max(intensity, 0), 1)
		let sh = min(max(sharpness, 0), 1)
		guard abs(i - lastIntensity) > 0.02 || abs(sh - lastSharpness) > 0.1 else { return }
		lastIntensity = i
		lastSharpness = sh
		do {
			// 系统可能因为静音/切后台把引擎停了，这里每次唤醒一下再改参数
			try engine.start()
			try player.sendParameters([
				CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(i), relativeTime: 0),
				CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(sh), relativeTime: 0)
			], atTime: 0)
		} catch {
			// 引擎不可用时忽略：手柄本身可能不支持震动
		}
	}

	func shutdown() {
		try? player.stop(atTime: 0)
		engine.stop(completionHandler: nil)
	}
}

final class GamepadController: ObservableObject {

	static let shared = GamepadController()

	// MARK: - 供设置页绑定的状态
	@Published private(set) var statusText: String = L("Not connected")
	@Published private(set) var batteryText: String = ""
	@Published private(set) var lastEvent: String = "—"


	/// L2 是否按住（陀螺仪瞄准的激活键）
	private(set) var aimTriggerHeld = false
	/// 扳机映射成按钮时的「上一次按下状态」，用来合成边沿。
	/// 键里带手柄 id：两只手柄同时按 L2 时互不干扰。
	private var triggerButtonState: [String: Bool] = [:]

	private func triggerKey(_ control: GamepadControl, _ id: UInt32) -> String {
		return "\(control.rawValue)#\(id)"
	}

	/// 手柄右摇杆的当前值（Parsec 坐标：X 右正、Y 上正）。
	/// 陀螺仪接管右摇杆时，由 GyroController 把这两项与陀螺仪贡献叠加后统一发送。
	private(set) var rightStickParsecX: Float = 0
	private(set) var rightStickParsecY: Float = 0

	private(set) var orderedControllers: [GCController] = []
	private(set) var mice = Set<GCMouse>()
	weak var delegate: InputManagerDelegate?

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
		aimTriggerHeld = false

		func button(_ control: GamepadControl, _ input: GCControllerButtonInput?) {
			input?.pressedChangedHandler = { [weak self] _, _, pressed in
				self?.handleButton(control, pressed, id: id)
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
			self?.handleTrigger(.l2, value, id: id)
		}
		// 有些手柄/模式把扳机当数字按钮报，value 不一定给，press 事件也认
		pad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
			self?.handleTrigger(.l2, pressed ? 1 : 0, id: id)
		}
		pad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
			self?.handleTrigger(.r2, value, id: id)
		}
		pad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
			self?.handleTrigger(.r2, pressed ? 1 : 0, id: id)
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

	private func handleButton(_ control: GamepadControl, _ pressed: Bool, id: UInt32) {
		let target = GamepadMapping.target(for: control)
		if pressed {
			lastEvent = "\(control.label) → \(target.label) #\(id)"
		}
		// 没实例（首启还没连过）或已断开时都不能发消息：前者是 nil 崩溃，
		// 后者是往废弃的 client 发消息，可能崩在 SDK 内部。
		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
		dispatch(target: target, pressed: pressed, analog: pressed ? 1 : 0, id: id)
	}

	private func handleTrigger(_ control: GamepadControl, _ value: Float, id: UInt32) {
		// L2 永远兼任「陀螺仪激活键」，与它被映射成什么无关
		if control == .l2 {
			aimTriggerHeld = value > 0.5
		}
		let target = GamepadMapping.target(for: control)
		if value > 0.05 {
			lastEvent = "\(control.label) → \(String(format: "%.2f", value))"
		}
		guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }

		if target.isButton {
			// 目标改成了按钮：用 0.5 阈值合成按下/抬起边沿，避免每帧重复发
			let nowPressed = value > 0.5
			let key = triggerKey(control, id)
			if triggerButtonState[key] != nowPressed {
				triggerButtonState[key] = nowPressed
				dispatch(target: target, pressed: nowPressed, analog: nowPressed ? 1 : 0, id: id)
			}
		} else {
			// 目标从按钮切回轴时清掉边沿状态，否则下次切回按钮会误判为"未变化"
			triggerButtonState[triggerKey(control, id)] = nil
			dispatch(target: target, pressed: value > 0.5, analog: value, id: id)
		}
	}

	/// 把「目标」真正落到 Parsec 消息上：按钮走按钮通道，轴走轴通道
	private func dispatch(target: GamepadTarget, pressed: Bool, analog: Float, id: UInt32) {
		if let button = target.parsecButton {
			CParsec.sendGameControllerButtonMessage(controllerId: id, button, pressed: pressed)
			return
		}
		guard let axis = target.parsecAxis else { return }
		var value: Float = 0
		switch target {
		case .lt, .rt:
			value = max(0, min(1, analog))
		case .lx, .ly, .rx, .ry:
			let signed = pressed ? analog : 0
			// 与摇杆处理保持一致：Y 轴取反
			value = max(-1, min(1, (target == .ly || target == .ry) ? -signed : signed))
		default:
			value = 0
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

	// MARK: - 主机震动（CLIENT_EVENT_RUMBLE → 手柄）

	/// 每个手柄一个震动引擎（类型擦除：RumbleEngine 需要 iOS 14 的可用性标注）
	private var rumbleEngines: [UInt32: Any] = [:]
	/// 最近一次收到的震动强度，供设置页显示（0 说明主机没下发 rumble）
	@Published private(set) var lastRumbleIntensity: Double = 0

	/// 由事件轮询线程调用，内部切回主线程
	func applyRumble(gamepadID: UInt32, motorBig: UInt8, motorSmall: UInt8) {
		if !Thread.isMainThread {
			DispatchQueue.main.async { [weak self] in
				self?.applyRumble(gamepadID: gamepadID, motorBig: motorBig, motorSmall: motorSmall)
			}
			return
		}
		guard SettingsHandler.gamepadRumble else { return }
		guard #available(iOS 14.0, *) else { return }
		applyRumbleOnMain(gamepadID: gamepadID, motorBig: motorBig, motorSmall: motorSmall)
	}

	@available(iOS 14.0, *)
	private func applyRumbleOnMain(gamepadID: UInt32, motorBig: UInt8, motorSmall: UInt8) {
		// Parsec 的 gamepadID 是我们发消息时用的 controllerId（1 起）
		let index = Int(gamepadID) - 1
		guard index >= 0, index < orderedControllers.count else { return }
		let controller = orderedControllers[index]

		let big = Double(motorBig) / 255.0
		let small = Double(motorSmall) / 255.0
		let intensity = min(1.0, max(big, small))
		let total = big + small
		// 大马达 = 低沉（sharpness 低），小马达 = 清脆（sharpness 高）
		let sharpness = total > 0.001 ? small / total : 0.5
		lastRumbleIntensity = intensity

		if let existing = rumbleEngines[gamepadID] as? RumbleEngine {
			existing.set(intensity: intensity, sharpness: sharpness)
			return
		}
		guard intensity > 0.02 else { return }
		guard let haptics = controller.haptics else { return }
		do {
			let engine = try RumbleEngine(haptics: haptics)
			rumbleEngines[gamepadID] = engine
			engine.set(intensity: intensity, sharpness: sharpness)
		} catch {
			lastEvent = L("Rumble failed") + ": \(error.localizedDescription)"
		}
	}

	/// 断开连接时把引擎全停掉，避免连续事件一直占着
	func stopRumble() {
		guard #available(iOS 14.0, *) else { return }
		for (_, engine) in rumbleEngines {
			(engine as? RumbleEngine)?.shutdown()
		}
		rumbleEngines.removeAll()
		lastRumbleIntensity = 0
	}

	// MARK: - 震动测试

	func testHaptics() {
		if !Thread.isMainThread {
			DispatchQueue.main.async { [weak self] in self?.testHaptics() }
			return
		}
		guard #available(iOS 14.0, *) else {
			lastEvent = L("Rumble is not supported")
			return
		}
		guard let controller = orderedControllers.first else {
			lastEvent = L("No controller connected")
			return
		}
		guard let haptics = controller.haptics else {
			lastEvent = L("This controller has no rumble")
			return
		}

		// 手柄支持哪些震动区域（空表 = 系统认为这只手柄不能震）
		let supported = haptics.supportedLocalities.map { $0.rawValue }.sorted()

		do {
			// 复用常驻引擎：原来的写法把 engine/player 放在局部变量里，
			// 函数一返回就被 ARC 释放，震动还没输出就被掐断 —— 这就是"测试没反应"的原因。
			let engine: RumbleEngine
			if let existing = rumbleEngines[1] as? RumbleEngine {
				engine = existing
			} else {
				engine = try RumbleEngine(haptics: haptics)
				rumbleEngines[1] = engine
			}
			engine.set(intensity: 1.0, sharpness: 0.7)
			lastEvent = L("Rumble Test") + " ✓ " + (supported.isEmpty ? "no-locality" : supported.joined(separator: "/"))
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				(self?.rumbleEngines[1] as? RumbleEngine)?.set(intensity: 0, sharpness: 0.7)
			}
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
			triggerButtonState.removeAll()
			DispatchQueue.main.async { [weak self] in self?.stopRumble() }
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
	/// 实时角速度（deg/s），给设置页的状态条用
	@Published private(set) var liveRate: Double = 0

	/// 是否正在运行（设置页顶部状态胶囊用）
	var isRunningNow: Bool {
		return running
	}

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
	/// 上一次的输出目标，用于"从右摇杆切走时补发一次归零"
	private var lastTarget: GyroTarget = .mouse
	/// 鼠标模式的亚像素余量
	private var residualX: Double = 0
	private var residualY: Double = 0
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

	/// 是否由陀螺仪接管右摇杆（此时手柄自己的右摇杆由这里统一发送，两者叠加）。
	/// 必须带上 running：陀螺仪没真正跑起来时（未串流 / 设备无陀螺仪 / 已停止），
	/// 否则手柄右摇杆会被吞掉、完全不响应。
	var ownsRightStick: Bool {
		return running && SettingsHandler.gyroEnabled && SettingsHandler.gyroTarget == .rightStick
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

		// 看门狗：1.5s 内一个样本都没收到就在状态行直说，避免"看起来开着但没数据"
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
			guard let self = self, self.running, self.samples == 0 else { return }
			self.statusText = L("No motion data")
		}
	}

	func stop() {
		if !Thread.isMainThread {
			DispatchQueue.main.async { [weak self] in self?.stop() }
			return
		}
		guard running else { return }
		// 注意顺序：running 置 false 后 ownsRightStick 就会变 false，所以先记下来
		let wasOwningRightStick = SettingsHandler.gyroEnabled && SettingsHandler.gyroTarget == .rightStick
		running = false
		motion.stopDeviceMotionUpdates()
		if wasOwningRightStick {
			// 交还控制权前先把摇杆归零，避免卡在推满状态
			sendStick(0, 0, force: true)
		}
		statusText = SettingsHandler.gyroEnabled ? L("Stopped") : L("Off")
	}

	/// 「归中」= 重新做一次零偏校准，顺便清掉滤波残量。
	/// 没在运行时不要进入校准状态，否则会一直显示"校准中"且永远凑不满样本。
	func recenter() {
		guard running else {
			statusText = SettingsHandler.gyroEnabled ? L("Waiting for stream") : L("Off")
			return
		}
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

		// 输出目标从"右摇杆"切到"鼠标"时，主机侧的右摇杆会停在最后一个值上，
		// 这里补发一次归零，否则视角会自己一直飘。
		if SettingsHandler.gyroTarget != lastTarget {
			if lastTarget == .rightStick {
				sendStick(0, 0, force: true)
			}
			lastTarget = SettingsHandler.gyroTarget
		}

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
			// 累积余量：慢速转动的位移可能不到 1px，直接取整会变成"完全不响应"，
			// 余量留到下一个采样一起发出去。
			residualX += dx
			residualY += dy
			let ix = Int32(residualX.rounded(.towardZero))
			let iy = Int32(residualY.rounded(.towardZero))
			residualX -= Double(ix)
			residualY -= Double(iy)
			if ix != 0 || iy != 0 {
				// ParsecSDK 不是线程安全的：采样在后台队列，发送统一切回主线程
				DispatchQueue.main.async {
					guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
					CParsec.sendMouseDelta(ix, iy)
				}
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
			// 没有 IMU 的手柄（例如 GameSir G8+）也会返回一个 GCDeviceMotion，但数值全是 0。
			// 重力模长能区分：真实 IMU 静止时重力也有约 1g，全零说明这只手柄没有传感器。
			let gravityMagnitude = simd_length(SIMD3<Double>(g.x, g.y, g.z))
			if gravityMagnitude > 0.3 {
				rate = SIMD3<Double>(r.x, r.y, r.z)
				gravity = SIMD3<Double>(g.x, g.y, g.z)
			}
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
			text = String(format: "%@ · %d", L("Calibrating, keep still"), samples)
		} else {
			let gateText: String
			if !SettingsHandler.gyroRequireL2 {
				gateText = L("L2 not required")
			} else {
				gateText = gateOpen ? L("L2 held") : L("L2 hold to aim")
			}
			// 样本数能证明传感器回调有没有在跑；角速度能证明数值是不是 0
			text = String(format: "%@ · %d · %.0f deg/s · %@",
						  L("Running"), samples, abs(h) * 180.0 / Double.pi, gateText)
		}
		let rateDeg = abs(h) * 180.0 / Double.pi
		DispatchQueue.main.async { [weak self] in
			self?.statusText = text
			self?.liveRate = rateDeg
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
		let vx = toParsec(x)
		let vy = toParsec(y)
		// 同上：发送回到主线程，与手柄输入路径保持同一线程
		DispatchQueue.main.async {
			guard CParsec.hasInstance, ParsecBackgroundManager.shared.hasActiveConnection else { return }
			CParsec.sendGameControllerAxisMessage(controllerId: 1, GAMEPAD_AXIS_RX, vx)
			CParsec.sendGameControllerAxisMessage(controllerId: 1, GAMEPAD_AXIS_RY, vy)
		}
	}

	private func toParsec(_ value: Float) -> Int16 {
		let v = min(max(value, -1), 1)
		return Int16((65535.0 * v - 1.0) / 2.0)
	}
}
