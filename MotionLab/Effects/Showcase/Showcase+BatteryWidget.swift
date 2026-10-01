import SwiftUI

extension Effect {
    static let showcaseBatteryWidget = Effect(
        id: "showcase.battery-widget",
        category: .showcase,
        interaction: .tap,
        name: L("Battery Rings", "设备电量环"),
        summary: L(
            "Four device rings fill one after another; a low one turns red and wobbles, and tapping plugs a device in under a pulsing bolt.",
            "四个设备电量环依次填充；电量低的变红并晃动，点一下给设备接上电，闪电标记随之脉动。"
        ),
        prompt: L(
            "A dark batteries widget: a 2 × 2 grid of 72 pt rings (7 pt stroke, rounded caps), each with a device glyph inside and its percentage below. On appearing, the rings sweep from zero to their level one after another, 0.12 s apart, on a spring (response 0.8 s, damping 0.8) while the percentages count up. A device at or below 20% draws its ring in red and wobbles: the glyph rocks ±8° three times with decaying amplitude every 2.6 s. Tapping a device plugs it in: the ring cross-fades to lime, a bolt badge pops onto the top of the ring from 30% on a bouncy spring (response 0.35 s, damping 0.5) and breathes between 100% and 118% each second, a soft lime halo pulses behind the ring and the level climbs a percent at a time with rolling digits. Tapping again unplugs it. Glanceable and alive.",
            "深色电量组件：2 × 2 排列的 72pt 圆环（描边 7pt、圆头），环内是设备图标，环下是百分比。出现时四个环依次从零扫到各自电量，间隔 0.12 秒，以弹簧（响应 0.8 秒、阻尼 0.8）落定。电量不高于 20% 的设备圆环为红色，图标每 2.6 秒摇摆 ±8° 三次，幅度逐次衰减。点击设备即接上电源：圆环变为青柠色，闪电角标以弹性弹簧（响应 0.35 秒、阻尼 0.5）从 30% 弹到环顶，并每秒在 100% 与 118% 之间呼吸，环后一圈青柠色柔光脉动，电量逐个百分点上涨、数字滚动。再点一次拔掉电源。一眼可读。"
        ),
        implementation: L(
            "Each ring is Circle().trim driven by a level that is zero until the grid appears, animated with a per-index delayed spring; numericText rolls the percentage. The wobble is a keyframeAnimator fired by a repeating task, the bolt uses a scale transition plus a phaseAnimator pulse, and a task(id:) raises charging levels one percent per tick.",
            "每个圆环是 Circle().trim，出现前电量为零，再按序号延迟的弹簧动画填充；百分比用 numericText 滚动。晃动是由循环 task 触发的 keyframeAnimator，闪电角标用缩放转场加 phaseAnimator 脉动，task(id:) 让充电中的设备每拍涨一个百分点。"
        ),
        apis: ["Circle().trim", "keyframeAnimator", "phaseAnimator", "contentTransition(.numericText)", "task(id:)", "spring(response:dampingFraction:)"],
        tags: ["battery", "ring", "charging", "widget", "devices", "电量", "电池", "充电", "圆环", "小组件"],
        params: [
            .slider("stagger", L("Fill stagger", "填充间隔"), 0...0.4, default: 0.12, unit: "s"),
            .slider("wobble", L("Wobble angle", "晃动角度"), 0...20, default: 8, decimals: 0, unit: "°"),
            .slider("low", L("Low threshold", "低电量阈值"), 5...50, default: 20, step: 5, decimals: 0, unit: "%"),
        ]
    ) { ctx in
        BatteryWidgetDemo(ctx: ctx)
    }
}

private struct BatteryDevice {
    let symbol: String
    let name: LocalizedText
    let level: Double

    static let all: [BatteryDevice] = [
        BatteryDevice(symbol: "iphone", name: L("Phone", "手机"), level: 78),
        BatteryDevice(symbol: "applewatch", name: L("Watch", "手表"), level: 54),
        BatteryDevice(symbol: "earbuds", name: L("Earbuds", "耳机"), level: 14),
        BatteryDevice(symbol: "earbuds.case.fill", name: L("Case", "充电盒"), level: 91),
    ]
}

private struct BatteryWidgetDemo: View {
    let ctx: DemoContext
    @State private var levels: [Double] = BatteryDevice.all.map(\.level)
    @State private var filled: Bool
    @State private var charging: Set<Int> = []
    @State private var wobbles = 0
    @State private var step = 0
    @State private var refill: Task<Void, Never>?

    init(ctx: DemoContext) {
        self.ctx = ctx
        _filled = State(initialValue: ctx.isStill)
    }

    private var zh: Bool { ctx.language == .zh }

    var body: some View {
        StudioScene(hint: L("Tap a device to plug it in", "点击设备，给它接上电源"), ctx: ctx) {
            card
        }
        .onAppear {
            guard !ctx.isStill else { return }
            filled = true
        }
        .onDisappear { refill?.cancel() }
        .task(id: charging) {
            guard !charging.isEmpty, !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.3))
                guard !Task.isCancelled else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    for index in charging { levels[index] = min(100, levels[index] + 1) }
                }
            }
        }
        .task {
            guard !ctx.isStill else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.6))
                guard !Task.isCancelled else { return }
                wobbles += 1
            }
        }
        .autoplay(ctx.isPreview, every: 2.3, delay: 1.6, intro: false) { autoStep() }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            SportEyebrowRow(
                title: zh ? "电池" : "Batteries",
                symbol: "battery.75percent",
                trailing: charging.isEmpty ? (zh ? "4 台设备" : "4 devices") : (zh ? "\(charging.count) 台充电中" : "\(charging.count) charging")
            )
            VStack(spacing: 12) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<2, id: \.self) { column in
                            cell(row * 2 + column)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 256)
        .signatureCard()
    }

    private func cell(_ index: Int) -> some View {
        let device = BatteryDevice.all[index]
        let isCharging = charging.contains(index)
        return Button {
            Haptics.tap(isCharging ? .light : .medium)
            toggle(index)
        } label: {
            BatteryCell(
                device: device,
                level: levels[index],
                filled: filled,
                charging: isCharging,
                low: levels[index] <= ctx["low"] && !isCharging,
                delay: Double(index) * ctx["stagger"],
                wobble: ctx["wobble"],
                wobbles: wobbles,
                language: ctx.language
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(SportPressStyle(scale: 0.94, dim: 0.04))
    }

    private func toggle(_ index: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
            if charging.contains(index) { charging.remove(index) } else { charging.insert(index) }
        }
    }

    /// Preview loop: plug in the low device, plug in the phone, then unplug everything and replay the fill.
    private func autoStep() {
        switch step % 3 {
        case 0:
            toggle(2)
        case 1:
            toggle(0)
        default:
            refill?.cancel()
            withAnimation(.easeIn(duration: 0.3)) {
                charging = []
                filled = false
            }
            refill = Task { @MainActor in
                guard await studioPause(0.4) else { return }
                levels = BatteryDevice.all.map(\.level)
                filled = true
            }
        }
        step += 1
    }
}

private struct BatteryCell: View {
    let device: BatteryDevice
    let level: Double
    let filled: Bool
    let charging: Bool
    let low: Bool
    let delay: Double
    let wobble: Double
    let wobbles: Int
    let language: AppLanguage
    @Environment(\.demoIsStill) private var isStill

    private var color: Color {
        if charging { return Signature.lime }
        return low ? Color(hex: 0xFF4D3D) : Signature.accent
    }

    var body: some View {
        let shown = filled ? level : 0
        VStack(spacing: 5) {
            ZStack {
                if charging && !isStill {
                    Circle()
                        .fill(Signature.lime)
                        .frame(width: 60, height: 60)
                        .blur(radius: 18)
                        .phaseAnimator([0.12, 0.34]) { content, glow in
                            content.opacity(glow)
                        } animation: { _ in .easeInOut(duration: 1) }
                        .transition(.opacity)
                }
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: max(shown / 100, 0.0001))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.55), radius: 5)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(filled ? delay : 0), value: filled)
                Image(systemName: device.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(low ? Color(hex: 0xFF8A7E) : Color.white)
                    .keyframeAnimator(initialValue: 0.0, trigger: wobbles) { content, angle in
                        content.rotationEffect(.degrees(low ? angle * wobble : 0))
                    } keyframes: { _ in
                        KeyframeTrack(\.self) {
                            CubicKeyframe(1.0, duration: 0.09)
                            CubicKeyframe(-0.85, duration: 0.14)
                            CubicKeyframe(0.6, duration: 0.13)
                            CubicKeyframe(-0.4, duration: 0.12)
                            CubicKeyframe(0.2, duration: 0.11)
                            SpringKeyframe(0.0, duration: 0.3, spring: .init(response: 0.25, dampingRatio: 0.6))
                        }
                    }
                if charging {
                    bolt
                        .offset(y: -36)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: 72, height: 72)
            HStack(spacing: 4) {
                Text(verbatim: "\(Int(shown.rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(charging ? Signature.lime : (low ? Color(hex: 0xFF6B5E) : Color.white))
                    .contentTransition(.numericText(value: shown))
                    .animation(.spring(response: 0.8, dampingFraction: 0.9).delay(filled ? delay : 0), value: filled)
                Text(device.name, language)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
            }
            .fixedSize()
        }
        .animation(.smooth(duration: 0.3), value: low)
    }

    private var bolt: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(Signature.ink)
            .frame(width: 17, height: 17)
            .background(Circle().fill(Signature.lime))
            .overlay(Circle().strokeBorder(Signature.card, lineWidth: 2))
            .phaseAnimator([1.0, 1.18]) { content, scale in
                content.scaleEffect(isStill ? 1 : scale)
            } animation: { _ in .easeInOut(duration: 0.5) }
    }
}
