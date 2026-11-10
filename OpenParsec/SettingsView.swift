import SwiftUI

struct SettingsView: View {
	@Binding var visible: Bool

	// 语言切换：值存在 SettingsHandler.appLanguage，LanguageStore 负责广播给所有页面
	@ObservedObject private var language = LanguageStore.shared

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

	let resolutionChoices: [Choice<ParsecResolution>]

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
						// 版本指纹：一眼确认装的是哪一次构建（谁编的、哪个 commit）
						Text(getVersionInfo())
							.font(.system(size: 12))
							.multilineTextAlignment(.center)
							.opacity(0.55)
							.padding(.top, 6)

						CatTitle(L("General"))
						CatList {
							// 语言用分段控件直接并排显示，不再藏在菜单里
							CatItem(L("Language")) {
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
							CatItem(L("Mouse Movement")) {
								MultiPicker(selection: $cursorMode, options:
								[
									Choice(L("Touchpad"), CursorMode.touchpad),
									Choice(L("Direct"), CursorMode.direct)
								])
							}
							CatItem(L("Right Click Position")) {
								MultiPicker(selection: $rightClickPosition, options:
								[
									Choice(L("First Finger"), RightClickPosition.firstFinger),
									Choice(L("Middle"), RightClickPosition.middle),
									Choice(L("Second Finger"), RightClickPosition.secondFinger)
								])
							}
							CatItem(L("Scroll Speed")) {
								Slider(value: $scrollSensitivity, in: 0.5...5, step: 0.5)
									.frame(width: 200)
								Text(String(format: "%.1f", scrollSensitivity))
							}
							CatItem(L("Reverse Scroll Direction")) {
								Toggle("", isOn: $reverseScrollDirection)
									.frame(width: 80)
							}
							CatItem(L("Cursor Scale")) {
								Slider(value: $cursorScale, in: 0.1...4, step: 0.1)
									.frame(width: 200)
								Text(String(format: "%.1f", cursorScale))
							}
							CatItem(L("Mouse Sensitivity")) {
								Slider(value: $mouseSensitivity, in: 0.1...4, step: 0.1)
									.frame(width: 200)
								Text(String(format: "%.1f", mouseSensitivity))
							}
							CatItem(L("Option Key as Command")) {
								Toggle("", isOn: $optionAsCommand)
									.frame(width: 80)
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
							CatItem(L("Default Resolution")) {
								MultiPicker(selection: $resolution, options: resolutionChoices)
							}
							CatItem(L("Decoder")) {
								MultiPicker(selection: $decoder, options:
								[
									Choice(L("H.264"), DecoderPref.h264),
									Choice(L("Prefer H.265"), DecoderPref.h265)
								])
							}
							CatItem(L("Frame Rate")) {
								MultiPicker(selection: $preferredFramesPerSecond, options:
								[
									Choice(L("Auto (Device Max)"), 0),
									Choice(L("120 FPS"), 120),
									Choice(L("60 FPS"), 60),
									Choice(L("30 FPS"), 30)
								])
							}
							CatItem(L("Decoder Compatibility")) {
								Toggle("", isOn: $decoderCompatibility)
									.frame(width: 80)
							}
						}
						CatTitle(L("Misc"))
						CatList {
							CatItem(L("Never Show Overlay")) {
								Toggle("", isOn: $noOverlay)
									.frame(width: 80)
							}
							CatItem(L("Hide Status Bar")) {
								Toggle("", isOn: $hideStatusBar)
									.frame(width: 80)
							}
							CatItem(L("Show Keyboard Button")) {
								Toggle("", isOn: $showKeyboardButton)
									.frame(width: 80)
							}
							CatItem(L("Always Show Status")) {
								Toggle("", isOn: $alwaysShowStatus)
									.frame(width: 80)
							}
							CatItem(L("Picture in Picture")) {
								Toggle("", isOn: $enablePiP)
									.frame(width: 80)
							}
							CatItem(L("Start Muted")) {
								Toggle("", isOn: $startMuted)
									.frame(width: 80)
							}
							CatItem(L("Auto Reconnect")) {
								Toggle("", isOn: $autoReconnect)
									.frame(width: 80)
							}
							if autoReconnect {
								CatItem(L("Reconnect Error Prompts")) {
									Toggle("", isOn: $errorPrompts)
										.frame(width: 80)
								}
							}
							CatItem(L("Save Session Settings")) {
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
