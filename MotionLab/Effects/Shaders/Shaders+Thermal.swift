import SwiftUI

extension Effect {
    static let shaderThermal = Effect(
        id: "shader.thermal",
        category: .shaders,
        interaction: .gesture,
        name: L("Thermal Camera", "热成像相机"),
        summary: L(
            "A false-colour thermal view of a room; drag a finger across it and your heat print lingers, then cools.",
            "房间的伪彩色热成像画面；手指划过会留下一道热痕，随后慢慢冷却。"
        ),
        prompt: L(
            "A grayscale room — a lamp, a cat, a steaming mug, a cold window — is seen through a thermal camera: a Metal shader maps luminance onto a five-stop iron palette, near-black through purple, red and orange to pale yellow. The image is softened like a low-resolution sensor and thin isotherm lines trace every eighth of the range. Sensor noise re-rolls 24 times a second, and a faint refresh band rolls down the frame about every 4.5 s. Dragging a finger paints warmth that glows white-hot, then cools through the palette over 2.4 s, so a stroke fades tail-first. A reticle springs to the finger (response 0.3 s, damping 0.7) with a rolling temperature readout, then returns to the cat. Technical, moody and playful.",
            "灰度的房间——台灯、猫、冒着热气的马克杯、冰冷的窗——透过热成像相机呈现：Metal 着色器把亮度映射到五段“铁红”色带上，从近黑经紫、红、橙直到淡黄。画面像低分辨率传感器一样略微发虚，细细的等温线勾出量程的每八分之一。传感器噪点每秒重掷 24 次，一道淡淡的刷新带约每 4.5 秒从上到下滚过。手指拖过之处涂上白热的余温，再在 2.4 秒内沿色带逐级冷却，于是一笔热痕总是从尾部先消退。准星以弹簧（响应 0.3 秒、阻尼 0.7）跳到指尖并滚动显示温度，松手后回到猫身上。专业、有氛围，又带玩心。"
        ),
        implementation: L(
            "The room and the finger's heat trail are drawn in grayscale SwiftUI (the trail is a Canvas of blurred discs whose opacity decays with age); a [[stitchable]] layer shader then maps the four-tap-averaged luminance through five colour stops and adds isotherms sized from the local gradient, noise and a scan band.",
            "房间与手指的热痕先用灰度的 SwiftUI 绘制（热痕是 Canvas 中一串模糊圆点，不透明度随时间衰减）；随后 [[stitchable]] layerEffect 着色器把四点平均后的亮度映射到五个色标上，并叠加按局部梯度确定宽度的等温线、噪点与扫描带。"
        ),
        apis: ["layerEffect", "Canvas", "TimelineView", "DragGesture", "Metal"],
        tags: ["thermal", "infrared", "false colour", "heat map", "camera", "热成像", "红外", "伪彩色", "热力图"],
        params: [
            .choice("palette", L("Palette", "色带"), [L("Iron", "铁红"), L("Rainbow", "彩虹"), L("White hot", "白热")]),
            .slider("cooling", L("Cooling time", "冷却时间"), 0.8...5, default: 2.4, decimals: 1, unit: "s"),
            .slider("shimmer", L("Sensor shimmer", "传感器噪点"), 0...1, default: 0.6),
            .slider("contours", L("Isotherms", "等温线"), 0...1, default: 0.5),
        ]
    ) { ctx in
        ThermalDemo(ctx: ctx)
    }
}

private enum ThermalPalette {
    static let all: [[UInt32]] = [
        [0x05051E, 0x5A0C8C, 0xD8364A, 0xFF9F1A, 0xFFF7C2],
        [0x10106B, 0x1AA7E8, 0x35D07F, 0xFFD23F, 0xF03B2E],
        [0x000000, 0x3A3A3A, 0x7A7A7A, 0xC4C4C4, 0xFFFFFF],
    ]

    static func stops(_ index: Int) -> [Color] {
        all[min(max(index, 0), all.count - 1)].map { Color(hex: $0) }
    }
}

private struct HeatPoint {
    let position: CGPoint
    let time: Double
}

private final class ThermalModel {
    let clock = BackgroundClock(start: 0)
    private(set) var trail: [HeatPoint] = []
    var finger: CGPoint?

    func add(_ point: CGPoint, now: Double) {
        if let last = trail.last, hypot(last.position.x - point.x, last.position.y - point.y) < 5, now - last.time < 0.05 {
            return
        }
        trail.append(HeatPoint(position: point, time: now))
        if trail.count > 90 { trail.removeFirst(trail.count - 90) }
    }

    func step(now: Double, cooling: Double, auto: Bool) -> Double {
        let time = clock.advance(to: now, speed: 1)
        if auto {
            // Simulated finger: a slow figure-eight through the room, through the same `add` as a drag.
            let point = CGPoint(x: 130 + 86 * sin(now * 0.9), y: 160 + 70 * sin(now * 1.8))
            finger = point
            add(point, now: now)
        }
        trail.removeAll { now - $0.time > cooling }
        return time
    }

    /// A settled picture for stills: one stroke, hot at its head.
    func seedStill(now: Double, cooling: Double) {
        trail = (0..<26).map { index in
            let t = Double(index) / 25
            return HeatPoint(
                position: CGPoint(x: 52 + 150 * t, y: 250 - 70 * sin(t * .pi * 0.9)),
                time: now - cooling * 0.85 * (1 - t)
            )
        }
        finger = trail.last?.position
    }
}

private struct ThermalDemo: View {
    let ctx: DemoContext
    @State private var model = ThermalModel()
    @State private var reticle = ThermalDemo.cat
    @State private var touching = false

    fileprivate static let cat = CGPoint(x: 168, y: 150)

    var body: some View {
        let stops = ThermalPalette.stops(ctx.int("palette"))
        let cooling = ctx["cooling"]
        let shimmer = ctx["shimmer"]
        let contours = ctx["contours"]
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                let time = prepare(now: now, cooling: cooling)
                ThermalRoom(time: time, now: now, trail: model.trail, cooling: cooling)
                    .layerEffect(
                        ShaderLibrary.mlThermal(
                            .float2(ShaderKit.card),
                            .float(time),
                            .color(stops[0]), .color(stops[1]), .color(stops[2]), .color(stops[3]), .color(stops[4]),
                            .float(shimmer),
                            .float(contours),
                            .float(1)
                        ),
                        maxSampleOffset: CGSize(width: 2, height: 2)
                    )
                    .overlay { ThermalHUD(stops: stops, reticle: hudPoint, hot: touching || ctx.isPreview, time: time) }
            }
            .shaderCard(glow: Color(hex: 0xD8364A, opacity: 0.3))
            .shaderTouch(
                onBegan: { point in
                    touching = true
                    Haptics.tap(.soft)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { reticle = point }
                },
                onMoved: { point, _ in
                    model.finger = point
                    model.add(point, now: Date().timeIntervalSinceReferenceDate)
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) { reticle = point }
                },
                onEnded: {
                    touching = false
                    model.finger = nil
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { reticle = Self.cat }
                },
                onTap: { point in
                    Haptics.tap(.soft)
                    // A tap leaves a fingertip print: a small cluster through the same `add`.
                    let now = Date().timeIntervalSinceReferenceDate
                    for k in 0..<5 {
                        let angle = Double(k) * 1.2566
                        model.add(CGPoint(x: point.x + CGFloat(cos(angle)) * 7, y: point.y + CGFloat(sin(angle)) * 7), now: now + Double(k) * 0.06)
                    }
                }
            )
            DemoHint(text: L("Drag a finger across the room", "用手指在房间里划过"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// In previews the reticle rides the simulated finger; on the detail stage it follows the spring.
    private var hudPoint: CGPoint {
        if ctx.isPreview, let finger = model.finger { return finger }
        return reticle
    }

    private func prepare(now: Double, cooling: Double) -> Double {
        if ctx.isStill {
            model.seedStill(now: now, cooling: cooling)
            return 2
        }
        return model.step(now: now, cooling: cooling, auto: ctx.isPreview)
    }
}

/// The scene the sensor looks at, drawn so that brightness means temperature.
private struct ThermalRoom: View {
    let time: Double
    let now: Double
    let trail: [HeatPoint]
    let cooling: Double

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.13), Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
            // Cold window pane.
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.0), Color(white: 0.07)], startPoint: .top, endPoint: .bottom))
                .frame(width: 84, height: 96)
                .overlay {
                    Rectangle().fill(Color(white: 0.16)).frame(width: 3)
                    Rectangle().fill(Color(white: 0.16)).frame(height: 3)
                }
                .position(x: 196, y: 62)
            // Table edge, slightly warmer than the wall.
            Rectangle()
                .fill(Color(white: 0.26))
                .frame(height: 64)
                .frame(maxHeight: .infinity, alignment: .bottom)
            glowing("lamp.desk.fill", size: 62, white: 0.5, glow: 0.5, at: CGPoint(x: 56, y: 74))
            // The bulb is the hottest thing in the room.
            Circle()
                .fill(RadialGradient(colors: [.white, Color(white: 1, opacity: 0)], center: .center, startRadius: 0, endRadius: 26))
                .frame(width: 52, height: 52)
                .position(x: 70, y: 66)
            glowing("cat.fill", size: 98, white: 0.6 + 0.03 * sin(time * 2.2), glow: 0.45, at: CGPoint(x: 168, y: 156))
            steam
            glowing("mug.fill", size: 54, white: 0.86, glow: 0.6, at: CGPoint(x: 62, y: 228))
            trailCanvas
        }
        .frame(width: ShaderKit.card.width, height: ShaderKit.card.height)
    }

    private func glowing(_ symbol: String, size: CGFloat, white: Double, glow: Double, at point: CGPoint) -> some View {
        let glyph = Image(systemName: symbol).font(.system(size: size, weight: .regular))
        return ZStack {
            glyph.foregroundStyle(Color(white: white * glow)).blur(radius: 12)
            glyph.foregroundStyle(Color(white: white))
        }
        .position(point)
    }

    private var steam: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let phase = (time * 0.35 + Double(index) * 0.2).truncatingRemainder(dividingBy: 1)
                Circle()
                    .fill(Color(white: 0.75))
                    .frame(width: 16 + 14 * phase, height: 16 + 14 * phase)
                    .blur(radius: 7)
                    .opacity((1 - phase) * 0.6)
                    .position(x: 62 + CGFloat(sin(phase * 5 + Double(index))) * 7, y: 196 - CGFloat(phase) * 62)
            }
        }
    }

    private var trailCanvas: some View {
        Canvas { context, _ in
            context.addFilter(.blur(radius: 9))
            for point in trail {
                let age = now - point.time
                guard age >= 0, age < cooling else { continue }
                let life = 1 - age / cooling
                let radius: CGFloat = 15 + 5 * CGFloat(1 - life)
                let rect = CGRect(x: point.position.x - radius, y: point.position.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: rect), with: .color(Color(white: 1, opacity: pow(life, 1.4) * 0.8)))
            }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

/// Camera chrome drawn above the shader: palette legend, reticle with a spot reading, status line.
private struct ThermalHUD: View {
    let stops: [Color]
    let reticle: CGPoint
    let hot: Bool
    let time: Double

    var body: some View {
        // The spot reading wobbles by a tenth of a degree, like a live sensor.
        let wobble = (sin(time * 3.1) + sin(time * 5.3)) * 0.1
        let reading = (hot ? 34.2 : 38.6) + wobble
        ZStack {
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: "41°")
                Capsule()
                    .fill(LinearGradient(colors: stops.reversed(), startPoint: .top, endPoint: .bottom))
                    .frame(width: 7, height: 132)
                    .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 0.5))
                Text(verbatim: "12°")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 12)
            .offset(y: 30)
            HStack(spacing: 5) {
                Circle().fill(Color(hex: 0xFF4D5E)).frame(width: 6, height: 6).opacity(0.4 + 0.6 * (sin(time * 4) > 0 ? 1 : 0))
                Text(verbatim: "IR  ε 0.95")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(14)
            ZStack {
                Circle().strokeBorder(.white, lineWidth: 1.2).frame(width: 22, height: 22)
                Rectangle().fill(.white).frame(width: 1.2, height: 34)
                Rectangle().fill(.white).frame(width: 34, height: 1.2)
                Text(verbatim: String(format: "%.1f°C", reading))
                    .contentTransition(.numericText())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.5), in: Capsule())
                    .offset(y: 30)
            }
            .position(reticle)
        }
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .monospacedDigit()
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.6), radius: 2)
        .allowsHitTesting(false)
    }
}
