import SwiftUI

struct SettingsView: View {
	@Binding var visible: Bool

	// 语言切换：值存在 SettingsHandler.appLanguage，LanguageStore 负责广播给所有页面
	@ObservedObject private var language = LanguageStore.shared
	// 手柄状态：已连接设备、电量、最后按下的键
	@ObservedObject private var gamepad = GamepadController.shared
	// 陀螺仪状态
	@ObservedObject private var gyro = GyroController.shared

	/// 正在改的键（非 nil 时弹 ActionSheet）
	@State private var editingControl: GamepadControl?
	/// 改完映射后自增，用来强制刷新映射列表
	@State private var mappingVersion = 0


	// @State var renderer:RendererType = SettingsHandler.renderer
	@AppStorage("resolution") var resolution: ParsecResolution = .client
	@AppStorage("bitrate") var bitrate: Int = 0
	@AppStorage("decoder") var decoder: DecoderPref = .h264
	@AppStorage("cursorMode") var cursorMode: CursorMode = .touchpad
	@AppStorage("cursorScale") var cursorScale: Double = 0.5
	@AppStorage("mouseSensitivity") var mouseSensitivity: Double = 1.0
	@AppStorage("optionAsCommand") var optionAsCommand: Bool = false
	@AppStorage("noOverlay") var noOverlay: Bool = false
	@AppStorage("hideStatusBar") var hideStatusBar: Bool = true
	@AppStorage("rightClickPosition") var rightClickPosition: RightClickPosition = .firstFinger
	@AppStorage("reverseScrollDirection") var reverseScrollDirection: Bool = false
	@AppStorage("scrollSensitivity") var scrollSensitivity: Double = 1.5
	@AppStorage("preferredFramesPerSecond") var preferredFramesPerSecond: Int = 60 // 0 = use device max (ProMotion)
	@AppStorage("decoderCompatibility") var decoderCompatibility: Bool = false // Enable for stutter issues on some devices
	@AppStorage("showKeyboardButton") var showKeyboardButton: Bool = true
	@AppStorage("saveSessionSettings") var saveSessionSettings: Bool = true
	@AppStorage("alwaysShowStatus") var alwaysShowStatus: Bool = false
	@AppStorage("enablePiP") var enablePiP: Bool = false
	@AppStorage("startMuted") var startMuted: Bool = false
	@AppStorage("autoReconnect") var autoReconnect: Bool = true
	@AppStorage("errorPrompts") var errorPrompts: Bool = false
	@AppStorage("gamepadDeadzone") var gamepadDeadzone: Double = 0.0
	@AppStorage("gamepadInvertLeftY") var gamepadInvertLeftY: Bool = false
	@AppStorage("gamepadInvertRightY") var gamepadInvertRightY: Bool = false
	@AppStorage("gamepadSwapABXY") var gamepadSwapABXY: Bool = false
	@AppStorage("gamepadSecondController") var gamepadSecondController: Bool = false
	@AppStorage("gamepadRumble") var gamepadRumble: Bool = true
	@AppStorage("gyroEnabled") var gyroEnabled: Bool = false
	@AppStorage("gyroTarget") var gyroTarget: GyroTarget = .mouse
	@AppStorage("gyroSensitivityH") var gyroSensitivityH: Double = 1.0
	@AppStorage("gyroSensitivityV") var gyroSensitivityV: Double = 1.0
	@AppStorage("gyroDeadzone") var gyroDeadzone: Double = 0.02
	@AppStorage("gyroSmoothing") var gyroSmoothing: Double = 0.3
	@AppStorage("gyroInvertH") var gyroInvertH: Bool = false
	@AppStorage("gyroInvertV") var gyroInvertV: Bool = false
	@AppStorage("gyroRequireL2") var gyroRequireL2: Bool = true
	@AppStorage("gyroUseControllerMotion") var gyroUseControllerMotion: Bool = true

	let resolutionChoices: [Choice<ParsecResolution>]

	/// 把连续值匹配到最接近的图形档位（卡片 id 是离散的）
	private func levelID(_ value: Double, levels: [Double]) -> String {
		var best = levels.first ?? value
		for l in levels where abs(l - value) < abs(best - value) { best = l }
		return String(format: "%.3f", best)
	}

	/// 分辨率预览用的宽高比：从 "3840x2160 (16:9)" 里取括号中的比例
	private var resolutionAspect: CGFloat {
		let text = resolution.rawValue
		guard let open = text.range(of: "("), let close = text.range(of: ")") else {
			return 16.0 / 9.0
		}
		let inner = text[open.upperBound..<close.lowerBound]
		let parts = inner.split(separator: ":")
		if parts.count == 2, let w = Double(parts[0]), let h = Double(parts[1]), h > 0 {
			return CGFloat(w / h)
		}
		return 16.0 / 9.0
	}

	/// 陀螺仪状态胶囊的短文案（完整状态在「陀螺仪」分组里）
	private var gyroChipText: String {
		guard SettingsHandler.gyroEnabled else { return L("Off") }
		return gyro.isRunningNow ? L("Running") : L("Idle")
	}

	/// 语言选项走 LanguageStore 而不是直接写 @AppStorage：这样选完立刻广播，
	/// 当前页和背后的主页会同时换语言，不需要退出重进。
	private var languageBinding: Binding<AppLanguage> {
		return Binding(
			get: { language.language },
			set: { language.set($0) }
		)
	}

	init(visible: Binding<Bool>) {
		_visible = visible
		var tmp: [Choice<ParsecResolution>] = []
		for res in ParsecResolution.resolutions {
			tmp.append(Choice(res.desc, res))
		}
		resolutionChoices = tmp
	}

	var body: some View {
		ZStack {
			if visible {
				// Background
				Rectangle()
					.fill(Color.init(red: 0, green: 0, blue: 0, opacity: 0.67))
					.edgesIgnoringSafeArea(.all)
			}
		}

		ZStack {
			if visible {
				// Main controls
				VStack {
					// Navigation controls
					ZStack {
						Rectangle()
							.fill(Color("BackgroundTab"))
							.frame(height: 52)
							.shadow(color: Color("Shading"), radius: 4, y: 6)
						ZStack {
							HStack {
								Button(action: saveAndExit, label: { Image(systemName: "xmark").scaleEffect(x: -1) })
								 .padding()
								Spacer()
							}
							Text(L("Settings"))
								.multilineTextAlignment(.center)
								.foregroundColor(Color("Foreground"))
								.font(.system(size: 20, weight: .medium))
							Spacer()
						}
						.foregroundColor(Color("AccentColor"))
					}
					.zIndex(1)

					ScrollView {
						// 顶部信息卡：应用标识 + 版本指纹 + 手柄/陀螺仪实时状态
						VStack(alignment: .leading, spacing: 12) {
							HStack(spacing: 12) {
								ZStack {
									RoundedRectangle(cornerRadius: 12, style: .continuous)
										.fill(LinearGradient(gradient: Gradient(colors: [Color("AccentColor"), Color("AccentColor").opacity(0.55)]),
															 startPoint: .topLeading, endPoint: .bottomTrailing))
										.frame(width: 46, height: 46)
									Text("OP")
										.font(.system(size: 17, weight: .heavy))
										.foregroundColor(.white)
								}
								VStack(alignment: .leading, spacing: 3) {
									Text("OpenParsec")
										.font(.system(size: 17, weight: .semibold))
									Text(getVersionInfo())
										.font(.system(size: 10.5, design: .monospaced))
										.foregroundColor(Color("Foreground").opacity(0.5))
										.lineLimit(1)
										.minimumScaleFactor(0.7)
								}
								Spacer(minLength: 0)
							}
							HStack(spacing: 7) {
								StatusChip(icon: "gamecontroller",
										   text: gamepad.orderedControllers.isEmpty ? L("Not connected") : gamepad.statusText,
										   active: !gamepad.orderedControllers.isEmpty)
								StatusChip(icon: "dot.radiowaves.left.and.right",
										   text: gyroChipText,
										   active: SettingsHandler.gyroEnabled)
								Spacer(minLength: 0)
							}
						}
						.padding(14)
						.background(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.fill(Color("BackgroundCard"))
						)
						.overlay(
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.strokeBorder(Color("Foreground").opacity(0.08), lineWidth: 0.8)
						)
						.padding(.horizontal, 20)
						.padding(.top, 10)

						CatTitle(L("General"))
						CatList {
							// 语言用分段控件直接并排显示，不再藏在菜单里
						CatItem(L("Language"), icon: "globe") {
								SegmentPicker(selection: languageBinding, options:
								[
									Choice(AppLanguage.english.displayName, AppLanguage.english),
									Choice(AppLanguage.chinese.displayName, AppLanguage.chinese)
								])
								.frame(width: 170)
							}
						}
						CatTitle(L("Interactivity"))
						CatList {
						CatItem(L("Mouse Movement"), icon: "hand.tap") {
							ChipPicker(selection: String(cursorMode.rawValue), choices: [
								ChipChoice(id: "0", caption: L("Touchpad")),
								ChipChoice(id: "1", caption: L("Direct"))
							], onSelect: { id in
								if let raw = Int(id), let mode = CursorMode(rawValue: raw) { cursorMode = mode }
							})
						}
						CatItem(L("Right Click Position"), icon: "cursorarrow") {
							ChipPicker(selection: String(rightClickPosition.rawValue), choices: [
								ChipChoice(id: "0", caption: L("First Finger")),
								ChipChoice(id: "1", caption: L("Middle")),
								ChipChoice(id: "2", caption: L("Second Finger"))
							], onSelect: { id in
								if let raw = Int(id), let pos = RightClickPosition(rawValue: raw) { rightClickPosition = pos }
							})
						}
						CatItem(L("Scroll Speed"), icon: "arrow.up.arrow.down") {
							TilePicker(selection: levelID(scrollSensitivity, levels: [0.500, 1.000, 2.000, 3.000]), choices: [
								TileChoice(id: "0.500", caption: "0.5×") { ScrollPreview(speed: 0.500, reversed: reverseScrollDirection) },
								TileChoice(id: "1.000", caption: "1.0×") { ScrollPreview(speed: 1.000, reversed: reverseScrollDirection) },
								TileChoice(id: "2.000", caption: "2.0×") { ScrollPreview(speed: 2.000, reversed: reverseScrollDirection) },
								TileChoice(id: "3.000", caption: "3.0×") { ScrollPreview(speed: 3.000, reversed: reverseScrollDirection) }
							], onSelect: { id in
								if let v = Double(id) { scrollSensitivity = v }
							})
						}
						CatItem(L("Reverse Scroll Direction"), icon: "arrow.uturn.backward") {
							Toggle("", isOn: $reverseScrollDirection)
								.frame(width: 80)
						}
						CatItem(L("Cursor Scale"), icon: "cursorarrow") {
							TilePicker(selection: levelID(cursorScale, levels: [0.400, 0.800, 1.200, 2.000]), choices: [
								TileChoice(id: "0.400", caption: "0.4×") { CursorPreview(scale: 0.400, mode: cursorMode) },
								TileChoice(id: "0.800", caption: "0.8×") { CursorPreview(scale: 0.800, mode: cursorMode) },
								TileChoice(id: "1.200", caption: "1.2×") { CursorPreview(scale: 1.200, mode: cursorMode) },
								TileChoice(id: "2.000", caption: "2.0×") { CursorPreview(scale: 2.000, mode: cursorMode) }
							], onSelect: { id in
								if let v = Double(id) { cursorScale = v }
							})
						}
						CatItem(L("Mouse Sensitivity"), icon: "speedometer") {
							TilePicker(selection: levelID(mouseSensitivity, levels: [0.500, 1.000, 2.000, 3.000]), choices: [
								TileChoice(id: "0.500", caption: "0.5×") { SensitivityPreview(value: 0.500) },
								TileChoice(id: "1.000", caption: "1.0×") { SensitivityPreview(value: 1.000) },
								TileChoice(id: "2.000", caption: "2.0×") { SensitivityPreview(value: 2.000) },
								TileChoice(id: "3.000", caption: "3.0×") { SensitivityPreview(value: 3.000) }
							], onSelect: { id in
								if let v = Double(id) { mouseSensitivity = v }
							})
						}
						CatItem(L("Option Key as Command"), icon: "command") {
							Toggle("", isOn: $optionAsCommand)
								.frame(width: 80)
						}
						}
						CatTitle(L("Gamepad"))
						CatList {
						CatItem(L("Status"), icon: "info.circle") {
								Text(gamepad.statusText)
									.lineLimit(1)
									.font(.system(size: 14))
							}
							if !gamepad.batteryText.isEmpty {
						CatItem(L("Battery"), icon: "battery.100") {
									Text(gamepad.batteryText)
										.font(.system(size: 14))
								}
							}
							// 按下手柄任意键，这里会实时显示"物理键 → 实际发出的键"，用来排查键位问题
						CatItem(L("Button Test"), icon: "circle.grid.2x2") {
								Text(gamepad.lastEvent)
									.lineLimit(1)
									.font(.system(size: 13))
									.opacity(0.75)
							}
						CatItem(L("Deadzone"), icon: "circle.dashed") {
							TilePicker(selection: levelID(gamepadDeadzone, levels: [0.000, 0.050, 0.150, 0.300]), choices: [
								TileChoice(id: "0.000", caption: L("Close")) { DeadzonePreview(deadzone: 0.000) },
								TileChoice(id: "0.050", caption: "0.05") { DeadzonePreview(deadzone: 0.050) },
								TileChoice(id: "0.150", caption: "0.15") { DeadzonePreview(deadzone: 0.150) },
								TileChoice(id: "0.300", caption: "0.30") { DeadzonePreview(deadzone: 0.300) }
							], onSelect: { id in
								if let v = Double(id) { gamepadDeadzone = v }
							})
						}
						CatItem(L("Invert Left Y"), icon: "arrow.up.and.down") {
							Toggle("", isOn: $gamepadInvertLeftY)
								.frame(width: 80)
						}
						CatItem(L("Invert Right Y"), icon: "arrow.up.and.down") {
							Toggle("", isOn: $gamepadInvertRightY)
								.frame(width: 80)
						}
						CatItem(L("Swap A/B and X/Y"), icon: "arrow.left.arrow.right") {
							Toggle("", isOn: $gamepadSwapABXY)
								.frame(width: 80)
						}
						CatItem(L("Second Controller"), icon: "gamecontroller") {
							Toggle("", isOn: $gamepadSecondController)
								.frame(width: 80)
								.onChange(of: gamepadSecondController) { _ in
									GamepadController.shared.registerControllerHandler()
								}
						}
						CatItem(L("Vibration"), icon: "bolt.horizontal") {
							Toggle("", isOn: $gamepadRumble)
								.frame(width: 80)
						}
						CatItem(L("Rumble Test"), icon: "waveform") {
								RumbleStrengthPreview(intensity: gamepad.lastRumbleIntensity)
								HStack(spacing: 8) {
									Text(String(format: "%.0f%%", gamepad.lastRumbleIntensity * 100))
										.font(.system(size: 11, design: .monospaced))
										.foregroundColor(Color("Foreground").opacity(0.45))
									Button(L("Test")) { gamepad.testHaptics() }
								}
							}
						CatItem(L("Diagnostics"), icon: "stethoscope") {
							Text(gamepad.rumbleDiagnostic)
								.font(.system(size: 9.5, design: .monospaced))
								.lineLimit(1)
								.foregroundColor(Color("Foreground").opacity(0.45))
						}
						}
						CatTitle(L("Button Mapping"))
						CatList {
							ForEach(GamepadControl.configurable, id: \.self) { control in
								CatItem(control.title, icon: "gamecontroller") {
									Button(action: { editingControl = control }) {
										HStack(spacing: 5) {
											MappingPreview(source: "", target: GamepadMapping.target(for: control).label)
											Image(systemName: "chevron.right")
												.font(.system(size: 10, weight: .semibold))
												.foregroundColor(Color("Foreground").opacity(0.3))
										}
									}
								}
							}
						CatItem(L("Reset"), icon: "arrow.counterclockwise") {
								Button(L("Reset")) {
									GamepadMapping.reset()
									mappingVersion += 1
								}
								.font(.system(size: 13, weight: .semibold))
								.foregroundColor(Color("AccentColor"))
							}
						}
						.id(mappingVersion)
						CatTitle(L("Gyro"))
						CatList {
						CatItem(L("Enable"), icon: "dot.radiowaves.left.and.right") {
							TilePicker(selection: gyroEnabled ? "1" : "0", choices: [
								TileChoice(id: "0", caption: L("OFF")) { GyroTiltPreview(rate: gyro.liveRate, target: gyroTarget, enabled: false) },
								TileChoice(id: "1", caption: L("ON")) { GyroTiltPreview(rate: gyro.liveRate, target: gyroTarget, enabled: true) }
							], onSelect: { id in
								gyroEnabled = (id == "1")
								if gyroEnabled {
									GyroController.shared.startIfNeeded()
								} else {
									GyroController.shared.stop()
								}
							})
						}
						CatItem(L("Output"), icon: "arrow.left.arrow.right") {
							ChipPicker(selection: String(gyroTarget.rawValue), choices: [
								ChipChoice(id: "0", caption: L("Mouse")),
								ChipChoice(id: "1", caption: L("Right Stick"))
							], onSelect: { id in
								if let raw = Int(id), let t = GyroTarget(rawValue: raw) { gyroTarget = t; GyroController.shared.stop(); GyroController.shared.startIfNeeded() }
							})
						}
						CatItem(L("Status"), icon: "dot.radiowaves.left.and.right") {
								VStack(alignment: .trailing, spacing: 5) {
									Text(gyro.statusText)
										.lineLimit(1)
										.font(.system(size: 11.5, design: .monospaced))
										.opacity(0.75)
									MeterBar(value: gyro.liveRate, maxValue: 180)
										.frame(width: 150)
								}
							}
						CatItem(L("Preview"), icon: "waveform.path.ecg") {
							HStack(spacing: 8) {
								Text(String(format: "%.0f / %.0f", gyro.rawRateH, gyro.rawRateV))
									.font(.system(size: 11, design: .monospaced))
									.foregroundColor(Color("Foreground").opacity(0.5))
								Button(gyro.previewRunning ? L("Stop") : L("Start")) {
									if gyro.previewRunning {
										gyro.stopPreview()
									} else {
										gyro.startPreview()
									}
								}
							}
						}
						CatItem(L("Diagnostics"), icon: "stethoscope") {
							Text(gyro.diagnosticText)
								.font(.system(size: 9.5, design: .monospaced))
								.lineLimit(2)
								.foregroundColor(Color("Foreground").opacity(0.45))
						}
						CatItem(L("Horizontal Sensitivity"), icon: "arrow.left.and.right") {
							TilePicker(selection: levelID(gyroSensitivityH, levels: [0.500, 1.000, 2.000, 3.000]), choices: [
								TileChoice(id: "0.500", caption: "0.5×") { SensitivityPreview(value: 0.500) },
								TileChoice(id: "1.000", caption: "1.0×") { SensitivityPreview(value: 1.000) },
								TileChoice(id: "2.000", caption: "2.0×") { SensitivityPreview(value: 2.000) },
								TileChoice(id: "3.000", caption: "3.0×") { SensitivityPreview(value: 3.000) }
							], onSelect: { id in
								if let v = Double(id) { gyroSensitivityH = v }
							})
						}
						CatItem(L("Vertical Sensitivity"), icon: "arrow.up.and.down") {
							TilePicker(selection: levelID(gyroSensitivityV, levels: [0.500, 1.000, 2.000, 3.000]), choices: [
								TileChoice(id: "0.500", caption: "0.5×") { SensitivityPreview(value: 0.500, vertical: true) },
								TileChoice(id: "1.000", caption: "1.0×") { SensitivityPreview(value: 1.000, vertical: true) },
								TileChoice(id: "2.000", caption: "2.0×") { SensitivityPreview(value: 2.000, vertical: true) },
								TileChoice(id: "3.000", caption: "3.0×") { SensitivityPreview(value: 3.000, vertical: true) }
							], onSelect: { id in
								if let v = Double(id) { gyroSensitivityV = v }
							})
						}
						CatItem(L("Deadzone"), icon: "circle.dashed") {
							TilePicker(selection: levelID(gyroDeadzone, levels: [0.000, 0.020, 0.060, 0.120]), choices: [
								TileChoice(id: "0.000", caption: L("Close")) { DeadzonePreview(deadzone: 0.000) },
								TileChoice(id: "0.020", caption: "0.02") { DeadzonePreview(deadzone: 0.120) },
								TileChoice(id: "0.060", caption: "0.06") { DeadzonePreview(deadzone: 0.360) },
								TileChoice(id: "0.120", caption: "0.12") { DeadzonePreview(deadzone: 0.720) }
							], onSelect: { id in
								if let v = Double(id) { gyroDeadzone = v }
							})
						}
						CatItem(L("Smoothing"), icon: "wind") {
							TilePicker(selection: levelID(gyroSmoothing, levels: [0.000, 0.300, 0.600, 0.900]), choices: [
								TileChoice(id: "0.000", caption: L("OFF")) { SensitivityPreview(value: 4.000) },
								TileChoice(id: "0.300", caption: "0.3") { SensitivityPreview(value: 3.100) },
								TileChoice(id: "0.600", caption: "0.6") { SensitivityPreview(value: 2.200) },
								TileChoice(id: "0.900", caption: "0.9") { SensitivityPreview(value: 1.300) }
							], onSelect: { id in
								if let v = Double(id) { gyroSmoothing = v }
							})
						}
						CatItem(L("Invert Horizontal"), icon: "arrow.left.and.right") {
							Toggle("", isOn: $gyroInvertH)
								.frame(width: 80)
						}
						CatItem(L("Invert Vertical"), icon: "arrow.up.and.down") {
							Toggle("", isOn: $gyroInvertV)
								.frame(width: 80)
						}
						CatItem(L("Hold L2 to Aim"), icon: "gamecontroller.fill") {
							Toggle("", isOn: $gyroRequireL2)
								.frame(width: 80)
						}
						CatItem(L("Controller Gyro"), icon: "gamecontroller") {
							Toggle("", isOn: $gyroUseControllerMotion)
								.frame(width: 80)
						}
						CatItem(L("Recenter"), icon: "scope") {
								Button(L("Recenter")) { GyroController.shared.recenter() }
							}
						}
						CatTitle(L("Graphics"))
						CatList {
							/*CatItem("Renderer")
							{
								SegmentPicker(selection:$renderer, options:
								[
									Choice("OpenGL", RendererType.opengl),
									Choice("Metal", RendererType.metal)
								])
								.frame(width:165)
							}*/
						CatItem(L("Default Resolution"), icon: "aspectratio") {
								ScreenPreview(aspect: resolutionAspect)
								MultiPicker(selection: $resolution, options: resolutionChoices)
							}
						CatItem(L("Decoder"), icon: "cpu") {
								MultiPicker(selection: $decoder, options:
								[
									Choice(L("H.264"), DecoderPref.h264),
									Choice(L("Prefer H.265"), DecoderPref.h265)
								])
							}
						CatItem(L("Frame Rate"), icon: "gauge") {
								BarGauge(value: Double(preferredFramesPerSecond == 0 ? 120 : preferredFramesPerSecond), maxValue: 120.0)
								MultiPicker(selection: $preferredFramesPerSecond, options:
								[
									Choice(L("Auto (Device Max)"), 0),
									Choice(L("120 FPS"), 120),
									Choice(L("60 FPS"), 60),
									Choice(L("30 FPS"), 30)
								])
							}
						CatItem(L("Decoder Compatibility"), icon: "gearshape") {
							Toggle("", isOn: $decoderCompatibility)
								.frame(width: 80)
						}
						}
						CatTitle(L("Misc"))
						CatList {
						CatItem(L("Never Show Overlay"), icon: "eye.slash") {
							Toggle("", isOn: $noOverlay)
								.frame(width: 80)
						}
						CatItem(L("Hide Status Bar"), icon: "rectangle") {
							TilePicker(selection: hideStatusBar ? "1" : "0", choices: [
								TileChoice(id: "0", caption: L("OFF")) { MiniLayoutPreview(kind: "status", active: true) },
								TileChoice(id: "1", caption: L("ON")) { MiniLayoutPreview(kind: "status", active: false) }
							], onSelect: { id in
								hideStatusBar = (id == "1")
							})
						}
						CatItem(L("Show Keyboard Button"), icon: "keyboard") {
							TilePicker(selection: showKeyboardButton ? "1" : "0", choices: [
								TileChoice(id: "0", caption: L("OFF")) { MiniLayoutPreview(kind: "keyboard", active: false) },
								TileChoice(id: "1", caption: L("ON")) { MiniLayoutPreview(kind: "keyboard", active: true) }
							], onSelect: { id in
								showKeyboardButton = (id == "1")
							})
						}
						CatItem(L("Always Show Status"), icon: "list.bullet") {
							Toggle("", isOn: $alwaysShowStatus)
								.frame(width: 80)
						}
						CatItem(L("Picture in Picture"), icon: "rectangle.on.rectangle") {
							TilePicker(selection: enablePiP ? "1" : "0", choices: [
								TileChoice(id: "0", caption: L("OFF")) { MiniLayoutPreview(kind: "pip", active: false) },
								TileChoice(id: "1", caption: L("ON")) { MiniLayoutPreview(kind: "pip", active: true) }
							], onSelect: { id in
								enablePiP = (id == "1")
							})
						}
						CatItem(L("Start Muted"), icon: "speaker.slash") {
							Toggle("", isOn: $startMuted)
								.frame(width: 80)
						}
						CatItem(L("Auto Reconnect"), icon: "arrow.triangle.2.circlepath") {
							Toggle("", isOn: $autoReconnect)
								.frame(width: 80)
						}
							if autoReconnect {
						CatItem(L("Reconnect Error Prompts"), icon: "exclamationmark.bubble") {
							Toggle("", isOn: $errorPrompts)
								.frame(width: 80)
						}
							}
						CatItem(L("Save Session Settings"), icon: "square.and.arrow.down") {
							Toggle("", isOn: $saveSessionSettings)
								.frame(width: 80)
						}
						}
					}
					.foregroundColor(Color("Foreground"))
				}
				.background(Rectangle().fill(Color("BackgroundGray")))
				.cornerRadius(8)
				.padding()
				.actionSheet(item: $editingControl) { control in
					var buttons: [Alert.Button] = GamepadTarget.allCases.map { target in
						Alert.Button.default(Text("\(control.label) → \(target.label)")) {
							GamepadMapping.set(target, for: control)
							mappingVersion += 1
						}
					}
					buttons.append(Alert.Button.cancel(Text(L("Cancel"))))
					return ActionSheet(title: Text("\(L("Remap")) \(control.label)"), buttons: buttons)
				}
			}
		}
		.preferredColorScheme(appScheme)
		.scaleEffect(visible ? 1 : 0, anchor: .zero)
	}

	func saveAndExit() {
		// SettingsHandler.renderer = renderer
		withAnimation(.easeInOut(duration: 0.24)) {
			visible = false
		}
	}

	/// 版本指纹：短版本号 + build 号（CI 里取自 run number）+ commit。
	/// 构建时由 CI 把 commit 与 run 号写进 Info.plist 的 GitCommitInfo，
	/// 所以这一行能唯一标识「装的是哪一次构建」。
	func getVersionInfo() -> String {
		let info = Bundle.main.infoDictionary
		let version = info?["CFBundleShortVersionString"] as? String ?? "?"
		let build = info?["CFBundleVersion"] as? String ?? "?"
		let commit = info?["GitCommitInfo"] as? String ?? "unknown"
		return "\(version) · build \(build) · \(commit)"
	}
}

struct SettingsView_Previews: PreviewProvider {
	@State static var value: Bool = true

	static var previews: some View {
		SettingsView(visible: $value)
	}
}
