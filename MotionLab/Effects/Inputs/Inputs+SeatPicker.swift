import SwiftUI

extension Effect {
    static let inputsSeatPicker = Effect(
        id: "inputs.seat-picker",
        category: .inputs,
        interaction: .tap,
        name: L("Seat Map Picker", "选座地图"),
        summary: L("Tap a seat: it pops and fills with colour, a ripple nudges its neighbours outward, and the summary bar counts seats and price.", "点一个座位：它弹起并填上颜色，涟漪把周围的座位向外轻推，底部汇总栏同步计数与计价。"),
        prompt: L(
            "A cinema seat map: a glowing curved screen at the top and five gently arced rows of eight seats with a centre aisle; taken seats are dimmed. Tapping a free seat pops it to 128% and back on a bouncy spring and fills it with an indigo-to-violet gradient and a soft glow within 200 ms. A ripple leaves the seat at the same instant: a thin ring expands to 60 pt and fades over 0.5 s, and every seat within 2.5 seats dips to 86% and is pushed 3 pt away from the origin, each delayed 50 ms per seat of distance and weaker the farther it is, then springs back. A summary bar rises from the bottom on a spring (response 0.45 s, damping 0.78) listing the seat labels, with the count and the total price rolling digit by digit. Tapping a selected seat deflates it.",
            "影院选座图：顶部一道发光的弧形银幕，下面五排略带弧度的座位，每排八个，中间留过道；已售座位变暗。点击空座位，它以带弹跳的弹簧鼓到 128% 再回落，并在 200 毫秒内填上靛蓝到紫色的渐变和一圈柔光。同时涟漪从这里出发：一道细圆环扩散到 60pt，在 0.5 秒内淡出；2.5 个座位范围内的每个座位都缩到 86%，并被朝远离中心的方向推开 3pt，每远一个座位延迟 50 毫秒、力度更弱，随后弹回。底部汇总栏以弹簧（响应 0.45 秒、阻尼 0.78）升起，列出座位号，座位数与总价逐位滚动。再点则瘪回去。"
        ),
        implementation: L(
            "Seats are placed on computed coordinates. A pulse value (origin + counter) triggers a keyframe animator on every seat; the keyframes start with a hold proportional to the seat's distance from the origin, and the content closure turns the 0→1→0 wave into a scale dip and a push along the direction away from it.",
            "座位按计算出的坐标摆放。一个脉冲值（起点与计数）触发每个座位上的关键帧动画；关键帧先停顿一段与到起点距离成正比的时间，内容闭包再把 0→1→0 的波形变成缩放下陷与沿远离方向的推移。"
        ),
        apis: ["keyframeAnimator", "UnevenRoundedRectangle", "contentTransition(.numericText)", "spring(response:dampingFraction:)", "transition(.move)"],
        tags: ["seat", "cinema", "picker", "ripple", "selection", "booking", "选座", "影院", "涟漪", "多选", "订票"],
        params: [
            .slider("radius", L("Ripple radius", "涟漪半径"), 1...4, default: 2.5, decimals: 1),
            .slider("delay", L("Wave delay per seat", "逐座延迟"), 0.02...0.15, default: 0.05, unit: "s"),
            .slider("push", L("Push distance", "推开距离"), 0...8, default: 3, decimals: 0, unit: "pt"),
        ]
    ) { ctx in
        InputSeatPickerDemo(ctx: ctx)
    }
}

private enum InputSeatMap {
    static let rows = 5
    static let columns = 8
    static let seat = CGSize(width: 22, height: 20)
    static let pitch = CGSize(width: 30, height: 28)
    static let aisle: CGFloat = 14
    static let size = CGSize(width: 8 * 30 - 8 + 14, height: 5 * 28 + 10)
    static let taken: Set<Int> = [2, 3, 13, 22, 26, 27, 33, 38]

    static func center(_ index: Int) -> CGPoint {
        let row = index / columns
        let column = index % columns
        let x = CGFloat(column) * pitch.width + seat.width / 2 + (column >= columns / 2 ? aisle : 0)
        let dx = x - size.width / 2
        let y = CGFloat(row) * pitch.height + seat.height / 2 + dx * dx * 0.0009
        return CGPoint(x: x, y: y)
    }

    static func label(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E"]
        return letters[index / columns] + "\(index % columns + 1)"
    }
}

private struct InputSeatPulse: Equatable {
    var origin = 0
    var id = 0
    var selecting = true
}

private struct InputSeatPickerDemo: View {
    let ctx: DemoContext
    @State private var selected: [Int]
    @State private var pulse = InputSeatPulse()
    @State private var step = 0

    private let price = 14

    init(ctx: DemoContext) {
        self.ctx = ctx
        _selected = State(initialValue: ctx.isStill ? [19, 20, 21] : [])
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            screen
            map
                .padding(.top, 14)
            summary
                .offset(y: selected.isEmpty ? 30 : 0)
                .opacity(selected.isEmpty ? 0 : 1)
                .scaleEffect(selected.isEmpty ? 0.94 : 1)
                .padding(.top, 10)
            Spacer(minLength: 0)
            DemoHint(text: L("Tap free seats", "点选空座位"), ctx: ctx)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 0.75, delay: 0.4) { autoTick() }
    }

    // MARK: Pieces

    private var screen: some View {
        ZStack(alignment: .top) {
            InputSeatScreenArc()
                .fill(LinearGradient(colors: [Palette.sky.opacity(0.35), Palette.sky.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 236, height: 34)
            InputSeatScreenArc(edgeOnly: true)
                .stroke(LinearGradient(colors: [Palette.sky, Palette.indigo], startPoint: .leading, endPoint: .trailing), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .frame(width: 236, height: 34)
                .shadow(color: Palette.sky.opacity(0.7), radius: 6)
            Text(L("SCREEN", "银幕"), ctx.language)
                .font(.system(size: 9, weight: .bold))
                .kerning(2)
                .foregroundStyle(.secondary)
                .offset(y: 15)
        }
    }

    private var map: some View {
        ZStack(alignment: .topLeading) {
            InputSeatRing(pulse: pulse)
                .position(InputSeatMap.center(pulse.origin))
            ForEach(0..<(InputSeatMap.rows * InputSeatMap.columns), id: \.self) { index in
                InputSeatView(
                    index: index,
                    state: InputSeatMap.taken.contains(index) ? .taken : (selected.contains(index) ? .selected : .free),
                    pulse: pulse,
                    radius: ctx.cg("radius"),
                    delay: ctx["delay"],
                    push: ctx.cg("push")
                )
                .onTapGesture { toggle(index) }
                .position(InputSeatMap.center(index))
            }
        }
        .frame(width: InputSeatMap.size.width, height: InputSeatMap.size.height)
    }

    private var summary: some View {
        let labels = selected.sorted().map(InputSeatMap.label)
        let listed = labels.prefix(3).joined(separator: ", ") + (labels.count > 3 ? " +\(labels.count - 3)" : "")
        let count = max(selected.count, 1)
        let total = count * price
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: ctx.language == .zh ? "\(count) 个座位" : (count == 1 ? "1 seat" : "\(count) seats"))
                    .font(.subheadline.weight(.bold))
                    .contentTransition(.numericText(value: Double(count)))
                Text(verbatim: listed)
                    .font(.caption.weight(.medium))
                    .opacity(0.8)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
            Text(verbatim: (ctx.language == .zh ? "¥" : "$") + "\(total * (ctx.language == .zh ? 5 : 1))")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(total)))
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(Color.white.opacity(0.2), in: Capsule())
        }
        .foregroundStyle(Color.white)
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .frame(width: 290, height: 50)
        .background(Palette.primaryStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Palette.indigo.opacity(0.3), radius: 10, y: 5)
    }

    // MARK: Actions

    /// Finger and autoplay both land here.
    private func toggle(_ index: Int) {
        guard !InputSeatMap.taken.contains(index) else { return }
        let selecting = !selected.contains(index)
        Haptics.tap(selecting ? .light : .soft)
        pulse = InputSeatPulse(origin: index, id: pulse.id + 1, selecting: selecting)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            if selecting {
                selected.append(index)
            } else {
                selected.removeAll { $0 == index }
            }
        }
    }

    private func autoTick() {
        let script = [19, 20, 21, 12, 20, 19, 21, 12]
        toggle(script[step % script.count])
        step += 1
    }
}

private enum InputSeatState { case free, taken, selected }

private struct InputSeatView: View {
    let index: Int
    let state: InputSeatState
    let pulse: InputSeatPulse
    let radius: CGFloat
    let delay: Double
    let push: CGFloat

    /// Distance to the ripple origin, in seats, and the unit direction away from it.
    private var relation: (distance: CGFloat, direction: CGSize) {
        let here = InputSeatMap.center(index)
        let origin = InputSeatMap.center(pulse.origin)
        let dx = here.x - origin.x
        let dy = here.y - origin.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0.5 else { return (0, .zero) }
        return (length / InputSeatMap.pitch.width, CGSize(width: dx / length, height: dy / length))
    }

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 4, bottomTrailingRadius: 4, topTrailingRadius: 8, style: .continuous)
        let isSelected = state == .selected
        let info = relation
        let radius = radius
        let push = push
        let selecting = pulse.selecting
        let hold = 0.005 + Double(info.distance) * delay
        return ZStack {
            shape
                .fill(Color.primary.opacity(state == .taken ? 0.1 : 0.05))
            shape
                .strokeBorder(Color.primary.opacity(state == .taken ? 0 : 0.3), lineWidth: 1.4)
            shape
                .fill(LinearGradient(colors: [Palette.indigo, Palette.violet], startPoint: .top, endPoint: .bottom))
                .opacity(isSelected ? 1 : 0)
                .shadow(color: Palette.indigo.opacity(isSelected ? 0.6 : 0), radius: 5, y: 2)
        }
        .frame(width: InputSeatMap.seat.width, height: InputSeatMap.seat.height)
        .animation(.easeOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle().inset(by: -3))
        .keyframeAnimator(initialValue: CGFloat(0), trigger: pulse.id) { view, wave in
            let isOrigin = info.distance == 0
            let strength: CGFloat = isOrigin ? 1 : max(1 - info.distance / max(radius, 0.1), 0)
            let scale: CGFloat = isOrigin ? 1 + (selecting ? 0.28 : -0.18) * wave : 1 - 0.14 * wave * strength
            view
                .scaleEffect(scale)
                .offset(x: info.direction.width * push * wave * strength, y: info.direction.height * push * wave * strength)
        } keyframes: { _ in
            LinearKeyframe(0, duration: hold)
            SpringKeyframe(1, duration: 0.12, spring: .snappy)
            SpringKeyframe(0, duration: 0.5, spring: .bouncy)
        }
    }
}

/// The ring that leaves a freshly selected seat.
private struct InputSeatRing: View {
    let pulse: InputSeatPulse

    var body: some View {
        Circle()
            .strokeBorder(Palette.violet, lineWidth: 1.5)
            .frame(width: 120, height: 120)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: pulse.id) { view, progress in
                view
                    .scaleEffect(0.12 + 0.88 * progress)
                    .opacity(pulse.selecting ? Double(1 - progress) * 0.7 : 0)
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: 0.5, timingCurve: .easeOut)
            }
            .allowsHitTesting(false)
    }
}

/// A shallow arc, thick in the middle: the cinema screen seen from the seats.
private struct InputSeatScreenArc: Shape {
    var edgeOnly = false

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + 12))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 12), control: CGPoint(x: rect.midX, y: rect.minY - 10))
        if edgeOnly { return path }
        path.addLine(to: CGPoint(x: rect.maxX - 22, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + 22, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
