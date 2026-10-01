import SwiftUI

extension Effect {
    static let iconsMicRecord = Effect(
        id: "icons.mic-record",
        category: .icons,
        interaction: .tap,
        name: L("Mic Record", "麦克风录音"),
        summary: L("The mic morphs into a stop square on a red disc while level rings pulse with the voice.", "麦克风在红色圆盘上形变为停止方块，电平光环随人声脉动。"),
        prompt: L(
            "A white microphone glyph on a 96 pt indigo disc. On tap the disc dips to 90% and springs back while turning red within 0.3 s; the mic capsule (24 × 42 pt) morphs into a 32 pt rounded stop square on a spring (response 0.38 s, damping 0.62) as its U-shaped stand retracts from both ends and the stem and base shrink away. Three translucent red rings bloom behind the disc and breathe with the input level, each one lagging the previous by 0.09 s so loud moments travel outward as a ripple; a red dot blinks beside a timer that rolls up every second. Tapping stop reverses the morph, the rings collapse into the disc, and one indigo ring expands and fades as confirmation. Alive and attentive while it listens.",
            "96 pt靛蓝圆盘上是白色麦克风图标。点击后圆盘下沉到90%再回弹，并在0.3秒内变红；麦克风的胶囊头（24 × 42 pt）以弹簧（响应0.38秒、阻尼0.62）形变为32 pt的圆角停止方块，U形支架从两端向中间收回，立杆与底座随之缩没。三层半透明红色光环在圆盘后绽开，随输入电平呼吸，每层比前一层滞后0.09秒，响亮的瞬间像涟漪般向外传递；计时器旁红点闪烁，数字每秒滚动。点击停止时形变反向，光环收拢，一道靛蓝光环扩散淡出作为确认。聆听时鲜活而专注。"
        ),
        implementation: L(
            "A TimelineView drives everything from the seconds since the tap: an analytic spring morphs the capsule's size and corner radius and trims the stand, and the rings sample one layered-sine level signal at staggered times.",
            "TimelineView 用点击后的秒数驱动一切：解析弹簧改变胶囊的尺寸与圆角并裁剪支架，光环在错开的时间点采样同一条多层正弦电平信号。"
        ),
        apis: ["TimelineView(.animation)", "RoundedRectangle", "Shape.trim(from:to:)", "scaleEffect", "contentTransition(.numericText(value:))"],
        tags: ["microphone", "mic", "record", "voice", "stop", "level", "麦克风", "录音", "语音", "停止", "电平"],
        params: [
            .slider("gain", L("Level reactivity", "电平灵敏度"), 0...1.5, default: 0.8),
            .slider("rings", L("Level rings", "光环层数"), 1...4, default: 3, step: 1, decimals: 0),
            .slider("response", L("Morph response", "形变响应"), 0.2...0.8, default: 0.38, unit: "s"),
        ]
    ) { ctx in
        IconsMicRecordDemo(ctx: ctx)
    }
}

/// The U-shaped cradle under the microphone capsule: the lower half of a circle.
private struct IconsMicStand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        return path
    }
}

private struct IconsMicRecordDemo: View {
    let ctx: DemoContext
    @State private var play: IconsPlayhead
    @State private var recordingSince: Date = .distantPast
    @State private var lastLength: Int = 0

    private static let duration: Double = 0.6

    init(ctx: DemoContext) {
        self.ctx = ctx
        _play = State(initialValue: IconsPlayhead(isOn: ctx.isStill))
    }

    var body: some View {
        VStack(spacing: 6) {
            IconsTimeline(preview: ctx.isPreview) { date in
                let clock: Double = ctx.isStill ? 2.4 : date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3_600)
                VStack(spacing: 4) {
                    IconsMicScene(
                        on: play.isOn,
                        t: play.elapsed(at: date),
                        clock: clock,
                        gain: ctx["gain"],
                        rings: ctx.int("rings"),
                        response: ctx["response"]
                    )
                    .frame(width: 250, height: 210)
                    timer(seconds: seconds(at: date), clock: clock)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { toggle() }
            DemoHint(text: L("Tap to record, tap again to stop", "点击开始录音，再点一次停止"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.6) { toggle() }
    }

    private func seconds(at date: Date) -> Int {
        if ctx.isStill { return 7 }
        guard play.isOn else { return lastLength }
        return max(Int(date.timeIntervalSince(recordingSince)), 0)
    }

    private func timer(seconds: Int, clock: Double) -> some View {
        let blink: Double = play.isOn ? 0.35 + 0.65 * (0.5 + 0.5 * cos(clock * 2 * .pi)) : 0
        return HStack(spacing: 7) {
            Circle()
                .fill(Palette.red)
                .frame(width: 8, height: 8)
                .opacity(blink)
            Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(play.isOn ? Color.primary : Color.secondary)
                .contentTransition(.numericText(value: Double(seconds)))
                .animation(.snappy(duration: 0.3), value: seconds)
        }
        .padding(.trailing, 15)
    }

    private func toggle() {
        let now = Date()
        if play.isOn {
            lastLength = max(Int(now.timeIntervalSince(recordingSince)), 0)
        } else {
            recordingSince = now
        }
        play.toggle(onDuration: Self.duration, offDuration: Self.duration, at: now)
        if play.isOn {
            Haptics.tap(.medium)
        } else {
            Haptics.tap(.rigid)
        }
    }
}

private struct IconsMicScene: View {
    let on: Bool
    let t: Double
    let clock: Double
    let gain: Double
    let rings: Int
    let response: Double

    private static let discSize: CGFloat = 96

    /// A voice-like level in 0…1: three sines of unrelated rates, sharpened so peaks stand out.
    static func level(_ time: Double) -> Double {
        let a: Double = 0.5 + 0.5 * sin(time * 7.3)
        let b: Double = 0.5 + 0.5 * sin(time * 12.7 + 1.3)
        let c: Double = 0.5 + 0.5 * sin(time * 3.1 + 0.6)
        return pow(a * 0.5 + b * 0.3 + c * 0.2, 1.6)
    }

    /// 0 = idle microphone, 1 = recording.
    private var amount: Double {
        let p: Double = IconsCurve.easeOut(IconsCurve.seg(t, 0, 0.3))
        return on ? p : 1 - p
    }

    /// Glyph morph, 0 = microphone, 1 = stop square; overshoots on the spring.
    private var morph: Double {
        let p: Double = IconsCurve.spring(t - 0.05, response: response, damping: 0.62)
        return on ? p : 1 - p
    }

    private var discScale: Double {
        if t < 0.07 { return 1 - 0.1 * IconsCurve.easeOut(t / 0.07) }
        return 0.9 + 0.1 * IconsCurve.spring(t - 0.07, response: 0.36, damping: 0.5)
    }

    var body: some View {
        let amount: Double = self.amount
        ZStack {
            ForEach((0..<max(rings, 1)).reversed(), id: \.self) { index in
                ring(index, amount: amount)
            }
            confirmRing
            disc(amount: amount)
                .scaleEffect(CGFloat(discScale))
        }
    }

    private func ring(_ index: Int, amount: Double) -> some View {
        let level: Double = Self.level(clock - Double(index) * 0.09)
        let rest: Double = 0.22 + 0.2 * Double(index)
        let scale: Double = 1 + amount * min(rest + level * gain * (0.3 + 0.1 * Double(index)), 1.15)
        return Circle()
            .fill(Palette.red.opacity(0.26 - 0.06 * Double(index)))
            .frame(width: Self.discSize, height: Self.discSize)
            .scaleEffect(CGFloat(scale))
            .opacity(IconsCurve.unit(amount * 1.6))
    }

    /// One ring that leaves the disc when the recording stops.
    private var confirmRing: some View {
        let p: Double = on ? 0 : IconsCurve.seg(t, 0.05, 0.65)
        let live: Bool = p > 0 && p < 1
        return Circle()
            .stroke(Palette.indigo.opacity(0.6 * (1 - p)), lineWidth: 5 * CGFloat(1 - p) + 0.5)
            .frame(width: Self.discSize, height: Self.discSize)
            .scaleEffect(CGFloat(1 + 0.9 * IconsCurve.easeOut(p)))
            .opacity(live ? 1 : 0)
    }

    private func disc(amount: Double) -> some View {
        let level: Double = Self.level(clock)
        return ZStack {
            Circle().fill(Palette.primary)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFF7A80), Palette.red, Color(hex: 0xE22D48)], startPoint: .top, endPoint: .bottom))
                .opacity(amount)
            Circle()
                .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0)], startPoint: .top, endPoint: .center))
            Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1)
            IconsMicGlyph(morph: morph)
        }
        .frame(width: Self.discSize, height: Self.discSize)
        .shadow(color: Palette.indigo.opacity(0.4 * (1 - amount)), radius: 14, y: 8)
        .shadow(color: Palette.red.opacity(amount * (0.35 + 0.3 * level * min(gain, 1))), radius: 14 + 8 * CGFloat(level), y: 6)
    }
}

private struct IconsMicGlyph: View {
    /// 0 = microphone, 1 = stop square.
    let morph: Double

    var body: some View {
        let p: Double = morph
        let gone: Double = IconsCurve.unit(p)
        let left: Double = 1 - gone
        ZStack {
            IconsMicStand()
                .trim(from: CGFloat(0.5 * gone), to: CGFloat(1 - 0.5 * gone))
                .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 38, height: 19)
                .offset(y: 5.5)
                .opacity(left > 0.02 ? 1 : 0)
            Capsule()
                .fill(.white)
                .frame(width: 5, height: CGFloat(12 * left))
                .offset(y: CGFloat(15 + 6 * left))
                .opacity(left > 0.02 ? 1 : 0)
            Capsule()
                .fill(.white)
                .frame(width: CGFloat(22 * left), height: 5)
                .offset(y: 27)
                .opacity(left > 0.02 ? 1 : 0)
            RoundedRectangle(cornerRadius: CGFloat(IconsCurve.mix(12, 8, gone)), style: .continuous)
                .fill(.white)
                .frame(width: CGFloat(IconsCurve.mix(24, 32, p)), height: CGFloat(IconsCurve.mix(42, 32, p)))
                .offset(y: CGFloat(IconsCurve.mix(-9, 0, gone)))
        }
    }
}
