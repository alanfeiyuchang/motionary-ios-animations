import SwiftUI

extension Effect {
    static let cardsCrumpleDismiss = Effect(
        id: "cards.crumple-dismiss",
        category: .cards,
        interaction: .gesture,
        name: L("Crumple & Toss", "揉成纸团"),
        summary: L("Swipe a note away and it is scrunched into a paper ball in two squeezes, then lobbed into the bin.", "把便签划走，它被两下揉成纸团，再划出一道弧线丢进纸篓。"),
        prompt: L(
            "A 200×150 pt sticky note sits on a small stack beside a waste bin. Dragging it starts to wrinkle it; past 70 pt (or on a tap) it is dismissed. Its outline is a 14-point polygon that collapses toward a rough 26 pt ball in two squeezes: an ease-in to 55%, a 50 ms beat, then a spring to 100%, 0.55 s in total. Points pinch inward unevenly, the note jitters ±4°, the writing fades out by 60%, and 28 triangular facets fade in with random light and dark faces and thin crease lines. The bin's lid swings open, the ball flies a 90 pt parabola in 0.5 s with one and a half turns of spin, shrinking to 80%, and drops in: the lid claps shut, the bin squashes to 90% and springs back with a rigid haptic, and the next note rises from the stack.",
            "一张200×150 pt的便签叠在一小摞上，旁边是纸篓。拖动时纸面起皱；超过70 pt（或点击）就被丢弃。便签轮廓是14个顶点的多边形，分两下收拢成半径约26 pt的粗糙纸团：先缓入到55%，停顿50毫秒，再以弹簧收到100%，共0.55秒。各顶点不均匀地内收，便签抖动±4°，字迹在60%处淡出，28个三角折面带着随机明暗与折线渐显。纸篓掀盖，纸团沿90 pt高的抛物线飞行0.5秒，自转一圈半并缩到80%，落入篓中：盖子合上，纸篓压到90%再弹回，并有一记清脆触感，下一张随即升起。"
        ),
        implementation: L(
            "An Animatable view turns a crumple progress into a mesh: outline points interpolate from the note's rectangle to a noisy circle, an inner ring and a centre give 28 facets drawn in a Canvas, and the same outline masks the note. The toss is a second Animatable modifier that evaluates a parabola and the spin from one linear progress.",
            "Animatable 视图把揉皱进度换算成一张网格：轮廓顶点从便签矩形插值到带噪声的圆，加上内圈和中心点形成28个折面，用 Canvas 绘制，同一轮廓同时作为便签的遮罩。抛掷由另一个 Animatable 修饰器完成，用一个线性进度计算抛物线与自转。"
        ),
        apis: ["Animatable", "Canvas", "Shape", "mask", "DragGesture", "keyframeAnimator"],
        tags: ["crumple", "paper ball", "trash", "dismiss", "揉皱", "纸团", "丢弃", "废纸篓"],
        params: [
            .slider("crumple", L("Crumple time", "揉皱时长"), 0.3...1.1, default: 0.55, unit: "s"),
            .slider("arc", L("Toss arc", "抛物线高度"), 30...150, default: 90, step: 1, decimals: 0, unit: "pt"),
            .slider("spin", L("Spin", "自转圈数"), 0...3, default: 1.5, step: 0.25, decimals: 2),
            .slider("facets", L("Facet contrast", "折面对比"), 0...1, default: 0.7),
        ]
    ) { ctx in
        CardsCrumpleDemo(ctx: ctx)
    }
}

private enum CardsCrumpleLayout {
    static let note = CGSize(width: 200, height: 150)
    static let home = CGPoint(x: -10, y: -52)
    static let bin = CGPoint(x: 112, y: 96)
    /// Where the ball goes in: the mouth of the bin.
    static let mouth = CGPoint(x: 112, y: 70)
    static let ball: CGFloat = 26
}

private struct CardsCrumpleDemo: View {
    let ctx: DemoContext
    @State private var index = 0
    @State private var crumple: CGFloat
    @State private var drag: CGSize = .zero
    @State private var toss: CGFloat = 0
    /// 0 → 1 as the next note rises to the top of the stack.
    @State private var rise: CGFloat = 1
    @State private var busy = false
    @State private var lidOpen = false
    @State private var hits = 0
    @State private var held = false
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        // A still shows the note half scrunched.
        _crumple = State(initialValue: ctx.isStill ? 0.5 : 0)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                CardsCrumpleBin(lidOpen: lidOpen, hits: hits)
                    .offset(x: CardsCrumpleLayout.bin.x, y: CardsCrumpleLayout.bin.y)
                    .onTapGesture { dismiss(haptic: true) }
                ForEach([2, 1], id: \.self) { depth in
                    waiting(depth)
                }
                top
            }
            .frame(width: 320, height: 290)
            DemoHint(text: L("Swipe the note away, or tap it", "把便签划走，或点击它"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 2.5) { dismiss(haptic: false) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if held {
                    held = false
                    relax()
                }
            }
        }
        .onDisappear { script?.cancel() }
    }

    /// Notes waiting underneath: each sits 9 pt lower and 6% smaller than the one above it.
    private func waiting(_ depth: Int) -> some View {
        let level = CGFloat(depth) + (1 - rise)
        return CardsCrumpleNote(crumple: 0, index: index + depth, contrast: 0, language: ctx.language)
            .scaleEffect(1 - 0.06 * level)
            .brightness(-0.05 * Double(level))
            .opacity(Double((3 - level).clamped(to: 0...1)))
            .offset(x: CardsCrumpleLayout.home.x, y: CardsCrumpleLayout.home.y + 10 * level)
    }

    private var top: some View {
        let level = 1 - rise
        let from = CGPoint(x: CardsCrumpleLayout.home.x + drag.width, y: CardsCrumpleLayout.home.y + drag.height)
        return CardsCrumpleNote(crumple: crumple, index: index, contrast: ctx["facets"], language: ctx.language)
            .scaleEffect(1 - 0.06 * level)
            .rotationEffect(.degrees(Double(drag.width) / 16))
            .modifier(CardsCrumpleFlight(t: toss, from: from, to: CardsCrumpleLayout.mouth, arc: ctx.cg("arc"), spin: ctx["spin"]))
            .offset(y: 10 * level)
            .gesture(swipe)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard !busy else { return }
                held = true
                let distance = hypot(value.translation.width, value.translation.height)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    drag = value.translation
                    // The note starts to wrinkle under the finger.
                    crumple = min(distance / 260, 0.28)
                }
            }
            .onEnded { value in
                guard held else { return }
                held = false
                let distance = hypot(value.translation.width, value.translation.height)
                let predicted = hypot(value.predictedEndTranslation.width, value.predictedEndTranslation.height)
                if distance < 8 || distance > 70 || predicted > 150 {
                    dismiss(haptic: true)
                } else {
                    relax()
                }
            }
    }

    private func relax() {
        guard !busy else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            drag = .zero
            crumple = 0
        }
    }

    private func dismiss(haptic: Bool) {
        guard !busy else { return }
        busy = true
        let buzz = haptic && !ctx.isPreview
        let total = ctx["crumple"]
        if buzz { Haptics.tap(.soft) }
        withAnimation(.easeIn(duration: total * 0.4)) { crumple = 0.55 }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(total * 0.4 + 0.05))
            guard !Task.isCancelled else { return }
            if buzz { Haptics.tap(.medium) }
            withAnimation(.spring(response: total * 0.5, dampingFraction: 0.72)) { crumple = 1 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.62)) { lidOpen = true }
            try? await Task.sleep(for: .seconds(total * 0.6))
            guard !Task.isCancelled else { return }
            withAnimation(.linear(duration: 0.5)) { toss = 1 }
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            hits += 1
            if buzz { Haptics.tap(.rigid) }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { lidOpen = false }
            // Swap in the next note underneath, then let it rise.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                index += 1
                crumple = 0
                toss = 0
                drag = .zero
                rise = 0
            }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.68)) { rise = 1 }
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }
            busy = false
        }
    }
}

/// Carries the ball from `from` to `to` along a parabola while it spins and shrinks.
private struct CardsCrumpleFlight: ViewModifier, Animatable {
    var t: CGFloat
    let from: CGPoint
    let to: CGPoint
    let arc: CGFloat
    let spin: Double

    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        let x = from.x + (to.x - from.x) * t
        let y = from.y + (to.y - from.y) * t - arc * 4 * t * (1 - t)
        return content
            .scaleEffect(1 - 0.2 * t)
            .rotationEffect(.degrees(360 * spin * Double(t)))
            .offset(x: x, y: y)
            // Gone the instant it drops into the bin.
            .opacity(t >= 0.999 ? 0 : 1)
    }
}

/// The scrunched outline and its facets for one crumple amount. Coordinates are in the note's own space.
private struct CardsCrumpleMesh {
    let outer: [CGPoint]
    let inner: [CGPoint]
    let centre: CGPoint

    init(crumple: CGFloat, seed: Int) {
        let size = CardsCrumpleLayout.note
        let a = size.width / 2
        let b = size.height / 2
        let c = crumple.clamped(to: 0...1.15)
        let ease = c * c * (3 - 2 * min(c, 1))
        // Outline at rest: the four corners plus points along the edges, clockwise from the top-left.
        let rest: [CGPoint] = [
            CGPoint(x: -a, y: -b), CGPoint(x: -a / 2, y: -b), CGPoint(x: 0, y: -b), CGPoint(x: a / 2, y: -b),
            CGPoint(x: a, y: -b), CGPoint(x: a, y: -b / 3), CGPoint(x: a, y: b / 3),
            CGPoint(x: a, y: b), CGPoint(x: a / 2, y: b), CGPoint(x: 0, y: b), CGPoint(x: -a / 2, y: b),
            CGPoint(x: -a, y: b), CGPoint(x: -a, y: b / 3), CGPoint(x: -a, y: -b / 3),
        ]
        let count = rest.count
        let first = atan2(-b, -a)
        let radius = CardsCrumpleLayout.ball
        let pinch = sin(.pi * min(c, 1))
        var outline: [CGPoint] = []
        for index in 0..<count {
            let angle = first + 2 * .pi * CGFloat(index) / CGFloat(count)
            let ball = radius * (0.84 + 0.36 * Self.noise(seed, index))
            // Mid-squeeze the points cave in by different amounts, so the outline is jagged.
            let cave = 1 - 0.3 * pinch * Self.noise(seed, index + 40)
            let x = (rest[index].x * (1 - ease) + cos(angle) * ball * ease) * cave
            let y = (rest[index].y * (1 - ease) + sin(angle) * ball * ease) * cave
            outline.append(CGPoint(x: x + a, y: y + b))
        }
        var ring: [CGPoint] = []
        for index in 0..<count / 2 {
            let p = rest[index * 2]
            let q = rest[index * 2 + 1]
            let angle = first + 2 * .pi * (CGFloat(index * 2) + 0.5) / CGFloat(count)
            let jitter = 0.38 + 0.24 * Self.noise(seed, index + 80)
            let restX = (p.x + q.x) / 2 * jitter
            let restY = (p.y + q.y) / 2 * jitter
            let x = restX * (1 - ease) + cos(angle) * radius * 0.5 * ease
            let y = restY * (1 - ease) + sin(angle) * radius * 0.5 * ease
            ring.append(CGPoint(x: x + a, y: y + b))
        }
        outer = outline
        inner = ring
        centre = CGPoint(x: a + 8 * (1 - ease) + 2, y: b - 5 * (1 - ease) - 1)
    }

    /// Deterministic 0…1 noise per (note, point).
    static func noise(_ seed: Int, _ index: Int) -> CGFloat {
        var x = UInt64(truncatingIfNeeded: seed &* 7919 &+ index &* 104729 &+ 12345)
        x ^= x >> 33
        x = x &* 0xFF51AFD7ED558CCD
        x ^= x >> 33
        x = x &* 0xC4CEB9FE1A85EC53
        x ^= x >> 33
        return CGFloat(x % 10_000) / 10_000
    }

    var outline: Path {
        var path = Path()
        guard let start = outer.first else { return path }
        path.move(to: start)
        for point in outer.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    /// Triangles between the outline, the inner ring and the centre.
    var facets: [[CGPoint]] {
        var result: [[CGPoint]] = []
        let n = outer.count
        let m = inner.count
        for j in 0..<m {
            let p0 = outer[(2 * j) % n]
            let p1 = outer[(2 * j + 1) % n]
            let p2 = outer[(2 * j + 2) % n]
            let q0 = inner[j]
            let q1 = inner[(j + 1) % m]
            result.append([p0, p1, q0])
            result.append([p1, p2, q0])
            result.append([p2, q1, q0])
            result.append([q0, q1, centre])
        }
        return result
    }
}

private struct CardsCrumpleOutline: Shape {
    let mesh: CardsCrumpleMesh

    func path(in rect: CGRect) -> Path { mesh.outline }
}

private struct CardsCrumpleNote: View, Animatable {
    var crumple: CGFloat
    let index: Int
    let contrast: Double
    let language: AppLanguage

    var animatableData: CGFloat {
        get { crumple }
        set { crumple = newValue }
    }

    private struct Model {
        let title: LocalizedText
        let detail: LocalizedText
        let paper: UInt32
    }

    private static let models: [Model] = [
        Model(title: L("Call the dentist", "给牙医打电话"), detail: L("Before Friday", "周五之前"), paper: 0xFFE27A),
        Model(title: L("Old login flow", "旧版登录流程"), detail: L("Not needed any more", "已经用不上了"), paper: 0xFFB8CC),
        Model(title: L("Buy oat milk", "买燕麦奶"), detail: L("And coffee beans", "还有咖啡豆"), paper: 0xA9DBFF),
        Model(title: L("Idea: a paper bin", "点子：一个纸篓"), detail: L("Too silly?", "会不会太傻？"), paper: 0xB9F2D2),
    ]

    var body: some View {
        let size = CardsCrumpleLayout.note
        let count = Self.models.count
        let model = Self.models[((index % count) + count) % count]
        let mesh = CardsCrumpleMesh(crumple: crumple, seed: index)
        let c = crumple.clamped(to: 0...1)
        let creased = Double(min(c * 2.2, 1))
        ZStack {
            Color(hex: model.paper)
            LinearGradient(colors: [Color.white.opacity(0.25), Color.black.opacity(0.06)], startPoint: .top, endPoint: .bottom)
            writing(model)
                .scaleEffect(1 - 0.7 * c)
                .opacity(Double(1 - c / 0.6).clamped(to: 0...1))
            facets(mesh, strength: creased * contrast)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .mask(CardsCrumpleOutline(mesh: mesh))
        .rotationEffect(.degrees(4 * Double(sin(c * .pi * 3)) * Double(1 - c)))
        .shadow(color: .black.opacity(0.18), radius: 7, y: 5)
    }

    private func writing(_ model: Model) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "circle")
                    .font(.system(size: 17, weight: .semibold))
                Text(model.title, language)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            Text(model.detail, language)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .opacity(0.6)
            Spacer(minLength: 0)
            Capsule().fill(Color.black.opacity(0.12)).frame(width: 120, height: 7)
            Capsule().fill(Color.black.opacity(0.12)).frame(width: 84, height: 7)
        }
        .foregroundStyle(Color(hex: 0x3A3320))
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func facets(_ mesh: CardsCrumpleMesh, strength: Double) -> some View {
        let seed = index
        return Canvas { context, _ in
            guard strength > 0.01 else { return }
            for (number, triangle) in mesh.facets.enumerated() {
                var path = Path()
                path.move(to: triangle[0])
                path.addLine(to: triangle[1])
                path.addLine(to: triangle[2])
                path.closeSubpath()
                let tone = Double(CardsCrumpleMesh.noise(seed, number + 200)) * 2 - 1
                if tone > 0 {
                    context.fill(path, with: .color(.black.opacity(0.3 * tone * strength)))
                } else {
                    context.fill(path, with: .color(.white.opacity(-0.5 * tone * strength)))
                }
                context.stroke(path, with: .color(.black.opacity(0.14 * strength)), lineWidth: 0.6)
            }
        }
    }
}

/// A small pedal bin: the lid swings open for the ball and claps shut when it lands.
private struct CardsCrumpleBin: View {
    let lidOpen: Bool
    let hits: Int

    private struct Bump {
        var squash: CGFloat = 1
    }

    var body: some View {
        VStack(spacing: 2) {
            lid
                .rotationEffect(.degrees(lidOpen ? -62 : 0), anchor: .bottomTrailing)
            can
        }
        .keyframeAnimator(initialValue: Bump(), trigger: hits) { content, bump in
            content.scaleEffect(x: 2 - bump.squash, y: bump.squash, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.squash) {
                CubicKeyframe(0.9, duration: 0.08)
                SpringKeyframe(1, duration: 0.5, spring: Spring(response: 0.28, dampingRatio: 0.42))
            }
        }
        .frame(width: 60, height: 76)
        .contentShape(Rectangle())
    }

    private var lid: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.45))
                .frame(width: 14, height: 4)
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x9AA3B5), Color(hex: 0x6C7488)], startPoint: .top, endPoint: .bottom))
                .frame(width: 52, height: 8)
        }
    }

    private var can: some View {
        CardsCrumpleCan()
            .fill(LinearGradient(colors: [Color(hex: 0x8C95A8), Color(hex: 0x5D6578)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 46, height: 52)
            .overlay {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 2.5, height: 30)
                    }
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
    }
}

/// A tapered can with rounded bottom corners.
private struct CardsCrumpleCan: Shape {
    func path(in rect: CGRect) -> Path {
        let taper: CGFloat = 5
        let radius: CGFloat = 7
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - taper - radius, y: rect.maxY), control: CGPoint(x: rect.maxX - taper - 1, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + taper + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + taper, y: rect.maxY - radius), control: CGPoint(x: rect.minX + taper + 1, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
