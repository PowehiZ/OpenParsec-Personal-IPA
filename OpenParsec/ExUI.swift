import SwiftUI

/**
 * Category Title
 *
 * Displays a title before the start of a list.
 */
struct CatTitle: View {
	var text: String

	init(_ text: String) {
		self.text = text
	}

	var body: some View {
		HStack(spacing: 6) {
			Text(text.uppercased())
				.font(.system(size: 11.5, weight: .semibold))
				.tracking(1.1)
				.foregroundColor(Color("Foreground").opacity(0.55))
			Spacer()
		}
		.padding(.horizontal, 30)
		.padding(.top, 16)
		.padding(.bottom, 6)
	}
}

/**
 * Category List
 *
 * Displays a list of items. Acts as a container.
 * Use of `CatItem`s is recommended.
 */
struct CatList<Content: View>: View {
	var content: () -> Content

	init(@ViewBuilder content: @escaping () -> Content) {
		self.content = content
	}

	var body: some View {
		VStack(spacing: 0, content: content)
			.padding(.vertical, 4)
			.background(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.fill(Color("BackgroundCard"))
			)
			.overlay(
				RoundedRectangle(cornerRadius: 14, style: .continuous)
					.strokeBorder(Color("Foreground").opacity(0.08), lineWidth: 0.8)
			)
			.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
			.padding(.horizontal, 20)
	}
}

/**
 * Category Item
 *
 * Displays a new item with a label in a list.
 * Should be used within `CatList`s.
 *
 * `icon` 是可选的 SF Symbol 名，给了就在左侧显示一个着色小方块图标。
 */
struct CatItem<Content: View>: View {
	var title: String
	var icon: String?
	var content: () -> Content

	init(_ title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.icon = icon
		self.content = content
	}

	var body: some View {
		HStack(spacing: 11) {
			if let icon = icon {
				Image(systemName: icon)
					.font(.system(size: 12.5, weight: .semibold))
					.foregroundColor(Color("AccentColor"))
					.frame(width: 26, height: 26)
					.background(
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(Color("AccentColor").opacity(0.16))
					)
			}
			Text(title)
				.font(.system(size: 15))
				.lineLimit(1)
				.minimumScaleFactor(0.75)
			Spacer(minLength: 8)
			content()
		}
		.padding(.horizontal, 12)
		.frame(minHeight: 44)
	}
}

/**
 * 数值徽章：滑杆旁的数值，等宽字体 + 半透明胶囊，避免排版跳动。
 */
struct ValueBadge: View {
	var text: String

	init(_ text: String) {
		self.text = text
	}

	var body: some View {
		Text(text)
			.font(.system(size: 12, weight: .medium, design: .monospaced))
			.foregroundColor(Color("Foreground").opacity(0.75))
			.padding(.horizontal, 7)
			.padding(.vertical, 3)
			.background(
				Capsule().fill(Color("Foreground").opacity(0.09))
			)
			.frame(minWidth: 42)
	}
}

/**
 * 细长进度条：用来把陀螺仪/电量这类标量画成直观的条。
 */
struct MeterBar: View {
	var value: Double
	var maxValue: Double
	var tint: Color = Color("AccentColor")

	var body: some View {
		GeometryReader { geo in
			ZStack(alignment: .leading) {
				Capsule().fill(Color("Foreground").opacity(0.12))
				Capsule()
					.fill(tint)
					.frame(width: max(3, geo.size.width * CGFloat(fraction)))
			}
		}
		.frame(height: 5)
	}

	private var fraction: Double {
		guard maxValue > 0 else { return 0 }
		return min(1, max(0, value / maxValue))
	}
}

/**
 * 状态胶囊：顶部信息卡里显示「手柄 / 陀螺仪」这类开关状态。
 */
struct StatusChip: View {
	var icon: String
	var text: String
	var active: Bool

	var body: some View {
		HStack(spacing: 5) {
			Image(systemName: icon)
				.font(.system(size: 10, weight: .bold))
			Text(text)
				.font(.system(size: 11, weight: .medium))
				.lineLimit(1)
		}
		.padding(.horizontal, 9)
		.padding(.vertical, 5)
		.background(
			Capsule().fill((active ? Color("AccentColor") : Color("Foreground")).opacity(active ? 0.16 : 0.07))
		)
		.foregroundColor(active ? Color("AccentColor") : Color("Foreground").opacity(0.55))
	}
}

/**
 * Choice
 *
 * Used to depict a single choice with a given label and value.
 */
struct Choice<T: Hashable> {
	var label: String
	var value: T

	init(_ label: String, _ value: T) {
		self.label = label
		self.value = value
	}
}

/**
 * Segmented Picker
 *
 * Displays a segmented picker with a given list of choices.
 */
struct SegmentPicker<SelectionValue: Hashable>: View {
	var selection: Binding<SelectionValue>
	var options: [Choice<SelectionValue>]

	init(selection: Binding<SelectionValue>, options: [Choice<SelectionValue>]) {
		self.selection = selection
		self.options = options
	}

	var body: some View {
		Picker("", selection: selection) {
			ForEach(options.indices, id: \.self) { i in
				Text(options[i].label).tag(options[i].value)
			}
		}
		.pickerStyle(.segmented)
	}
}

/**
 * Multiple Choice Picker
 *
 * Displays a button that opens a menu to pick from a given list of choices.
 */
struct MultiPicker<SelectionValue: Hashable>: View {
	var selection: Binding<SelectionValue>
	var options: [Choice<SelectionValue>]

	@State var showChoices: Bool = false
	@State var valueText: String = "Choose..."

	init(selection: Binding<SelectionValue>, options: [Choice<SelectionValue>]) {
		self.selection = selection
		self.options = options
	}

	var body: some View {
		if #available(iOS 15, *) {
			Picker("", selection: selection) {
				ForEach(options.indices, id: \.self) { i in
					Text(options[i].label).tag(options[i].value)
				}
			}
			.pickerStyle(.menu)
		} else {
			// Dumb workaround for older iOS versions. -Angel
			Button(action: {showChoices.toggle()}) {
				HStack(spacing: 3) {
					Text(valueText)
						.multilineTextAlignment(.center)
						.font(.system(size: 14))
						.foregroundColor(Color("AccentColor"))
					Image(systemName: "chevron.up.chevron.down")
						.font(.system(size: 10, weight: .semibold))
						.foregroundColor(Color("AccentColor").opacity(0.8))
				}
			}
			.actionSheet(isPresented: $showChoices) {
				genActionSheet()
			}
			.onAppear {
				for option in options {
					if option.value == selection.wrappedValue {
						valueText = option.label
						break
					}
				}
			}
		}
	}

	func genActionSheet() -> ActionSheet {
		let buttons = options.map { option in
			Alert.Button.default(Text(option.value == selection.wrappedValue ? "    \(option.label)  ✓" : option.label), action: {select(option)})
		}
		return ActionSheet(title: Text(L("Pick your preference:")), buttons: buttons + [Alert.Button.cancel()])
	}

	func select(_ option: Choice<SelectionValue>) {
		valueText = option.label
		selection.wrappedValue = option.value
	}
}


/**
 * 手柄线稿：把手柄画成线框，每个可改的键都是可点区域，
 * 键面上显示它「当前发出的是什么」。
 */
// MARK: - 设置项示意图（每项设置一个专属图形，而不是只有图标）

/// 光标大小预览：外框是屏幕，箭头按 cursorScale 缩放
struct CursorPreview: View {
	var scale: Double
	var mode: CursorMode

	var body: some View {
		let s = CGFloat(max(0.3, min(scale, 1.6)))
		return ZStack {
			RoundedRectangle(cornerRadius: 4, style: .continuous)
				.fill(Color("BackgroundField"))
				.frame(width: 58, height: 30)
			if mode == .touchpad {
				Circle()
					.strokeBorder(Color("Foreground").opacity(0.25), lineWidth: 1)
					.frame(width: 16, height: 16)
					.offset(x: -14, y: 0)
			}
			Image(systemName: "cursorarrow")
				.font(.system(size: 7 + 11 * s, weight: .semibold))
				.foregroundColor(Color("Foreground"))
				.offset(x: 8, y: 0)
		}
		.frame(width: 58, height: 30)
	}
}

/// 滚轮速度预览：竖条 + 滑块位置表示速度，箭头表示方向
struct ScrollPreview: View {
	var speed: Double
	var reversed: Bool

	var body: some View {
		let f = CGFloat(max(0.05, min(speed / 4.0, 1)))
		return ZStack(alignment: reversed ? .top : .bottom) {
			Capsule()
				.fill(Color("BackgroundField"))
				.frame(width: 7, height: 30)
			Capsule()
				.fill(Color("AccentColor"))
				.frame(width: 7, height: max(6, 26 * f))
			Image(systemName: reversed ? "arrow.up" : "arrow.down")
				.font(.system(size: 7, weight: .bold))
				.foregroundColor(Color("Foreground").opacity(0.55))
				.offset(x: 11)
		}
		.frame(width: 24, height: 30)
	}
}

/// 摇杆死区预览：外圈是摇杆行程，内圈是死区，点表示当前推动位置
struct DeadzonePreview: View {
	var deadzone: Double

	var body: some View {
		let r: CGFloat = 13
		let dz = CGFloat(max(0.0, min(deadzone * 2.0, 0.9)))
		return ZStack {
			Circle()
				.strokeBorder(Color("Foreground").opacity(0.22), lineWidth: 1)
				.frame(width: r * 2, height: r * 2)
			Circle()
				.fill(Color("AccentColor").opacity(0.28))
				.frame(width: r * 2 * dz, height: r * 2 * dz)
			Circle()
				.fill(Color("Foreground"))
				.frame(width: 4, height: 4)
				.offset(x: r * 0.62, y: -r * 0.5)
		}
		.frame(width: r * 2, height: r * 2)
	}
}

/// 灵敏度预览：水平/垂直刻度条，填充长度表示当前倍率
struct SensitivityPreview: View {
	var value: Double
	var vertical: Bool = false

	var body: some View {
		let f = CGFloat(max(0.04, min(value / 4.0, 1)))
		return ZStack(alignment: vertical ? .bottom : .leading) {
			RoundedRectangle(cornerRadius: 3, style: .continuous)
				.fill(Color("BackgroundField"))
				.frame(width: vertical ? 10 : 56, height: vertical ? 30 : 10)
			RoundedRectangle(cornerRadius: 3, style: .continuous)
				.fill(Color("AccentColor").opacity(0.75))
				.frame(width: vertical ? 10 : max(4, 56 * f), height: vertical ? max(4, 30 * f) : 10)
			ForEach(0..<3, id: \.self) { i in
				Rectangle()
					.fill(Color("Foreground").opacity(0.2))
					.frame(width: vertical ? 10 : 1, height: vertical ? 1 : 10)
					.offset(x: vertical ? 0 : CGFloat(i + 1) * 14 - 28,
							y: vertical ? 30 - CGFloat(i + 1) * 7.5 : 0)
			}
		}
		.frame(width: vertical ? 10 : 56, height: vertical ? 30 : 10)
	}
}

/// 陀螺仪预览：屏幕随实时角速度倾斜，右上角标出输出目标
struct GyroTiltPreview: View {
	var rate: Double
	var target: GyroTarget
	var enabled: Bool

	var body: some View {
		let tilt = CGFloat(max(-16, min(16, rate / 10)))
		return ZStack {
			RoundedRectangle(cornerRadius: 5, style: .continuous)
				.fill(Color("BackgroundField"))
				.frame(width: 40, height: 30)
			RoundedRectangle(cornerRadius: 3, style: .continuous)
				.fill(enabled ? Color("AccentColor").opacity(0.85) : Color("Foreground").opacity(0.22))
				.frame(width: 22, height: 26)
				.rotationEffect(.degrees(Double(tilt)))
			Image(systemName: target == .mouse ? "cursorarrow" : "circle.grid.cross")
				.font(.system(size: 8, weight: .bold))
				.foregroundColor(Color("Foreground"))
				.offset(x: 19, y: -10)
		}
		.frame(width: 58, height: 30)
	}
}

/// 分辨率预览：按比例画出画面矩形
struct ScreenPreview: View {
	var aspect: CGFloat

	var body: some View {
		let w: CGFloat = 48
		let h: CGFloat = min(26, max(10, w / max(aspect, 0.4)))
		return RoundedRectangle(cornerRadius: 3, style: .continuous)
			.fill(Color("BackgroundField"))
			.overlay(
				RoundedRectangle(cornerRadius: 3, style: .continuous)
					.strokeBorder(Color("AccentColor").opacity(0.7), lineWidth: 1)
			)
			.frame(width: w, height: h)
	}
}

/// 柱状仪表：帧率、码率这类"越大越满"的数值
struct BarGauge: View {
	var value: Double
	var maxValue: Double

	var body: some View {
		let f = CGFloat(max(0, min(value / max(maxValue, 1), 1)))
		return HStack(alignment: .bottom, spacing: 3) {
			ForEach(0..<5, id: \.self) { i in
				Capsule()
					.fill(CGFloat(i + 1) / 5.0 <= f ? Color("AccentColor") : Color("Foreground").opacity(0.18))
					.frame(width: 4, height: 8 + CGFloat(i) * 4)
			}
		}
		.frame(height: 26)
	}
}

/// 布局缩略图：画中画 / 状态栏 / 键盘这类开关，用一个小示意
struct MiniLayoutPreview: View {
	var kind: String
	var active: Bool

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 3, style: .continuous)
				.fill(Color("BackgroundField"))
				.frame(width: 48, height: 28)
			if kind == "pip" {
				RoundedRectangle(cornerRadius: 2, style: .continuous)
					.fill(active ? Color("AccentColor").opacity(0.85) : Color("Foreground").opacity(0.18))
					.frame(width: 16, height: 10)
					.offset(x: 12, y: 6)
			} else if kind == "status" {
				Capsule()
					.fill(active ? Color("AccentColor") : Color("Foreground").opacity(0.18))
					.frame(width: 26, height: 3)
					.offset(y: -9)
			} else {
				HStack(spacing: 2) {
					ForEach(0..<4, id: \.self) { _ in
						RoundedRectangle(cornerRadius: 1, style: .continuous)
							.fill(active ? Color("AccentColor").opacity(0.75) : Color("Foreground").opacity(0.18))
							.frame(width: 7, height: 6)
					}
				}
				.offset(y: 7)
			}
		}
		.frame(width: 48, height: 28)
	}
}

/// 按键映射预览：物理键 → 目标，两个胶囊 + 箭头
struct MappingPreview: View {
	var source: String
	var target: String

	var body: some View {
		HStack(spacing: 5) {
			if !source.isEmpty {
				Text(source)
					.font(.system(size: 10, weight: .semibold))
					.foregroundColor(Color("Foreground").opacity(0.85))
					.padding(.horizontal, 5)
					.padding(.vertical, 2)
					.background(Capsule().fill(Color("Foreground").opacity(0.12)))
				Image(systemName: "arrow.right")
					.font(.system(size: 7, weight: .bold))
					.foregroundColor(Color("Foreground").opacity(0.4))
			}
			Text(target)
				.font(.system(size: 10, weight: .semibold))
				.foregroundColor(Color("AccentColor"))
				.padding(.horizontal, 5)
				.padding(.vertical, 2)
				.background(Capsule().fill(Color("AccentColor").opacity(0.18)))
		}
	}
}

/// 震动强度预览：五格柱 + 实时值
struct RumbleStrengthPreview: View {
	var intensity: Double

	var body: some View {
		let f = CGFloat(max(0, min(intensity, 1)))
		return HStack(alignment: .bottom, spacing: 3) {
			ForEach(0..<5, id: \.self) { i in
				Capsule()
					.fill(CGFloat(i + 1) / 5.0 <= f ? Color("AccentColor") : Color("Foreground").opacity(0.18))
					.frame(width: 4, height: 8 + CGFloat(i) * 4)
			}
		}
		.frame(height: 26)
	}
}


/// 右键位置预览：两根手指，被选中的那根高亮
struct FingersPreview: View {
	var secondFinger: Bool
	var middle: Bool = false

	var body: some View {
		HStack(spacing: 4) {
			Circle()
				.fill(!secondFinger && !middle ? Color("AccentColor") : Color("Foreground").opacity(0.2))
				.frame(width: 8, height: 8)
			Circle()
				.fill(middle ? Color("AccentColor") : Color("Foreground").opacity(0.2))
				.frame(width: 8, height: 8)
			Circle()
				.fill(secondFinger ? Color("AccentColor") : Color("Foreground").opacity(0.2))
				.frame(width: 8, height: 8)
		}
		.frame(width: 40, height: 20)
	}
}

/// 一个可点选的图形选项：缩略图 + 文字
struct TileChoice: Identifiable {
	let id: String
	let caption: String
	let thumb: AnyView

	init<V: View>(id: String, caption: String, @ViewBuilder thumb: () -> V) {
		self.id = id
		self.caption = caption
		self.thumb = AnyView(thumb())
	}
}

/// 图形化单选：一排小卡片，每张卡就是该选项的示意，点一下即选中
struct TilePicker: View {
	let selection: String
	let choices: [TileChoice]
	let onSelect: (String) -> Void

	var body: some View {
		HStack(spacing: 4) {
			ForEach(choices) { choice in
				let active = choice.id == selection
				VStack(spacing: 1) {
					choice.thumb.scaleEffect(0.55).frame(width: 30, height: 17)
					Text(choice.caption)
						.font(.system(size: 8, weight: .medium))
						.foregroundColor(active ? Color("AccentColor") : Color("Foreground").opacity(0.55))
						.lineLimit(1)
						.minimumScaleFactor(0.7)
				}
				.frame(width: 40, height: 34)
				.background(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.fill(active ? Color("AccentColor").opacity(0.16) : Color("Foreground").opacity(0.05))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 8, style: .continuous)
						.strokeBorder(active ? Color("AccentColor").opacity(0.9) : Color("Foreground").opacity(0.10),
									  lineWidth: 1)
				)
				.contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
				.onTapGesture { onSelect(choice.id) }
			}
		}
	}
}

/// 带图形选项的行：标题在上，选项卡整行铺开（卡片式选择放不进右侧窄条）
struct CatSelectRow<Content: View>: View {
	let title: String
	let icon: String?
	private let content: () -> Content

	init(_ title: String, icon: String? = nil, @ViewBuilder content: @escaping () -> Content) {
		self.title = title
		self.icon = icon
		self.content = content
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 10) {
				if let icon = icon {
					ZStack {
						RoundedRectangle(cornerRadius: 8, style: .continuous)
							.fill(Color("AccentColor").opacity(0.16))
							.frame(width: 26, height: 26)
						Image(systemName: icon)
							.font(.system(size: 12, weight: .semibold))
							.foregroundColor(Color("AccentColor"))
					}
				}
				Text(title)
					.font(.system(size: 14))
				Spacer(minLength: 0)
			}
			content()
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
}


/// 开关类选项的缩略图：同一枚符号，开=主题色、关=压暗并加一道斜线
struct IconThumb: View {
	var symbol: String
	var active: Bool

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 5, style: .continuous)
				.fill(Color("BackgroundField"))
				.frame(width: 44, height: 26)
			Image(systemName: symbol)
				.font(.system(size: 13, weight: .semibold))
				.foregroundColor(active ? Color("AccentColor") : Color("Foreground").opacity(0.28))
			if !active {
				Path { p in
					p.move(to: CGPoint(x: 12, y: 20))
					p.addLine(to: CGPoint(x: 32, y: 6))
				}
				.stroke(Color("Foreground").opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
				.frame(width: 44, height: 26)
			}
		}
		.frame(width: 44, height: 26)
	}
}


/// 扁平胶囊单选：纯文字选项用，一行就能放下
struct ChipChoice: Identifiable {
	let id: String
	let caption: String
}

struct ChipPicker: View {
	let selection: String
	let choices: [ChipChoice]
	let onSelect: (String) -> Void

	var body: some View {
		HStack(spacing: 5) {
			ForEach(choices) { c in
				let active = c.id == selection
				Text(c.caption)
					.font(.system(size: 11, weight: .medium))
					.foregroundColor(active ? Color.white : Color("Foreground").opacity(0.62))
					.padding(.horizontal, 9)
					.padding(.vertical, 4)
					.background(
						Capsule().fill(active ? Color("AccentColor").opacity(0.85) : Color("Foreground").opacity(0.07))
					)
					.contentShape(Capsule())
					.onTapGesture { onSelect(c.id) }
			}
		}
	}
}

struct ExUI_Previews: PreviewProvider {
	@State static var value1 = false
	@State static var value2 = true

	static var previews: some View {
		VStack {
			CatTitle("Category Title")
			CatList {
				CatItem("Category Item", icon: "hand.tap") {
					Toggle("", isOn: .constant(true))
						.frame(width: 60)
				}
				CatItem("With Badge", icon: "speedometer") {
					ValueBadge("1.50")
				}
				CatItem("With Meter", icon: "dot.radiowaves.left.and.right") {
					MeterBar(value: 42, maxValue: 180)
						.frame(width: 90)
				}
			}
			CatTitle("Other Controls")
			CatList {
				CatItem("Segmented Picker") {
					SegmentPicker(selection: $value1, options:
					[
						Choice("False", false),
						Choice("True", true)
					])
					.frame(width: 180)
				}
				CatItem("Multiple Choice Picker") {
					MultiPicker(selection: $value2, options:
					[
						Choice("False", false),
						Choice("True", true)
					])
				}
			}
			HStack {
				StatusChip(icon: "gamecontroller", text: "Xbox Controller", active: true)
				StatusChip(icon: "dot.radiowaves.left.and.right", text: "Gyro Off", active: false)
			}
			Spacer()
		}
		.background(Rectangle().fill(Color("BackgroundGray")).edgesIgnoringSafeArea(.all))
		.foregroundColor(Color("Foreground"))
		.colorScheme(appScheme)
	}
}
