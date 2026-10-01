import SwiftUI

extension Effect {
    static let textRing3D = Effect(
        id: "text.ring-3d",
        category: .text,
        interaction: .gesture,
        name: L("Orbiting Type Ring", "立体文字环"),
        summary: L("A band of letters orbits a glossy sphere in 3D, passing in front and behind; drag to spin it with inertia.", "一圈字母在三维空间里环绕一颗光亮的球，从前面绕到背后；拖动可带惯性地拨转。"),
        prompt: L(
            "A sentence is printed on an invisible band circling a glossy sphere, like a planet's ring seen from 20° above. Each letter sits at its own angle on a 124 pt radius: its horizontal position is radius × sin(angle), it sinks or rises with cos(angle) for the tilt, grows up to 20% toward the viewer and narrows to an edge as it turns sideways. Behind the sphere the letters appear mirrored at 28% opacity and are hidden where the sphere covers them. The ring turns steadily at 36° per second and its tilt wobbles 4° on a slow sine. Dragging sideways grabs the ring and turns it with the finger; a flick releases it with that angular velocity, which then eases back to the cruising speed over about a second. Calm, dimensional and endlessly watchable.",
            "一句话印在一条看不见的环带上，绕着一颗光亮的球转动，像从上方20°俯看的行星环。每个字母在半径124pt的环上各占一个角度：水平位置为半径× sin(角度)，并随cos(角度)按倾角下沉或上浮，朝向观众时最多放大20%，转到侧面时收窄成一条边。绕到球后面的字母以镜像显示、透明度28%，被球体挡住的部分看不见。文字环以每秒36°匀速转动，倾角以缓慢的正弦摆动4°。横向拖动可以抓住文字环随手指转动；甩出后它带着那一刻的角速度继续转，再用约一秒缓缓回到巡航速度。安静而有空间感。"
        ),
        implementation: L(
            "A TimelineView advances an angle by hand (direct while dragging, exponential return to the idle speed afterwards); each glyph is a Text placed with offset, a signed horizontal scaleEffect of cos(angle) and a zIndex of cos(angle), so the sphere at zIndex 0 occludes the back half.",
            "TimelineView 手动推进一个角度（拖动时直接跟手，松手后按指数回到巡航速度）；每个字形是一个 Text，用 offset 定位，横向 scaleEffect 取带符号的 cos(角度)，zIndex 也取 cos(角度)，于是 zIndex 为 0 的球体自然遮住后半圈。"
        ),
        apis: ["TimelineView(.animation)", "scaleEffect(x:y:)", "zIndex", "DragGesture", "RadialGradient"],
        tags: ["ring", "orbit", "3d", "carousel", "inertia", "文字环", "环绕", "三维", "轨道", "惯性"],
        params: [
            .slider("speed", L("Cruise speed", "巡航速度"), 0...120, default: 36, decimals: 0, unit: "°/s"),
            .slider("tilt", L("Tilt", "倾角"), 0...50, default: 20, decimals: 0, unit: "°"),
            .slider("radius", L("Radius", "半径"), 80...140, default: 124, decimals: 0, unit: "pt"),
            .slider("back", L("Back opacity", "背面透明度"), 0...0.8, default: 0.28),
        ]
    ) { ctx in
        TextRing3DDemo(ctx: ctx)
    }
}

private struct RingSim {
    var last: Date?
    var angle: Double = 0.4
    var velocity: Double = 0
}

private struct TextRing3DDemo: View {
    let ctx: DemoContext
    @State private var sim = TextFXBox(RingSim())
    @State private var dragging = false
    @State private var grabAngle: Double = 0
    @State private var began = Date()

    private var glyphs: [String] {
        let text = ctx.language == .zh ? "MOTIONARY·动效词典·文字环绕·" : "MOTIONARY · KINETIC TYPE · "
        return text.map { String($0) }
    }

    var body: some View {
        VStack(spacing: 6) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let angle: Double = ctx.isStill ? 0.4 : advance(to: timeline.date)
                let wobble: Double = ctx.isStill ? 0 : 4 * sin(timeline.date.timeIntervalSince(began) * 0.7)
                ring(angle: angle, tilt: ctx["tilt"] + wobble)
            }
            .frame(width: 330, height: 236)
            .contentShape(Rectangle())
            .gesture(drag)
            DemoHint(text: L("Drag sideways to spin the ring", "横向拖动来拨转文字环"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 4.4, delay: 1.6) { sim.value.velocity = 6.5 }
    }

    // MARK: Ring

    private func ring(angle: Double, tilt: Double) -> some View {
        let letters = glyphs
        let count: Double = Double(letters.count)
        let radius: Double = ctx["radius"]
        let rise: Double = sin(tilt * Double.pi / 180)
        let back: Double = ctx["back"]
        let font: Font = .system(size: ctx.language == .zh ? 31 : 30, weight: .black, design: .rounded)
        return ZStack {
            orb
                .zIndex(0)
            ForEach(letters.indices, id: \.self) { index in
                let theta: Double = angle + 2 * Double.pi * Double(index) / count
                let facing: Double = cos(theta)
                let depth: Double = 1 + 0.2 * facing
                // Edge-on letters would be a sliver: fade them through the turn.
                let edge: Double = TextFXCurve.smoothstep((abs(facing) - 0.06) / 0.3)
                Text(verbatim: letters[index])
                    .font(font)
                    .foregroundStyle(Color.primary)
                    .opacity((facing >= 0 ? 1 : back) * edge)
                    .scaleEffect(x: CGFloat(facing * depth), y: CGFloat(depth))
                    .offset(x: CGFloat(radius * sin(theta)), y: CGFloat(radius * facing * rise))
                    .zIndex(facing >= 0 ? 1 : -1)
            }
        }
        .frame(width: 330, height: 236)
    }

    private var orb: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.22))
                .frame(width: 96, height: 16)
                .blur(radius: 9)
                .offset(y: 70)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xFFE3A8), Palette.coral, Color(hex: 0x8B2FC9), Color(hex: 0x35105C)],
                        center: UnitPoint(x: 0.34, y: 0.28),
                        startRadius: 2,
                        endRadius: 92
                    )
                )
                .frame(width: 104, height: 104)
                .overlay(alignment: .topLeading) {
                    Ellipse()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 30, height: 18)
                        .blur(radius: 7)
                        .offset(x: 20, y: 16)
                }
                .shadow(color: Palette.coral.opacity(0.35), radius: 22)
        }
    }

    // MARK: Motion

    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let radius: Double = max(ctx["radius"], 1)
                if !dragging {
                    dragging = true
                    grabAngle = sim.value.angle
                    Haptics.tap(.soft)
                }
                sim.value.angle = grabAngle + Double(value.translation.width) / radius
                sim.value.velocity = Double(value.velocity.width) / radius
            }
            .onEnded { value in
                let radius: Double = max(ctx["radius"], 1)
                dragging = false
                sim.value.velocity = min(max(Double(value.velocity.width) / radius, -14), 14)
            }
    }

    /// Advances the spin and returns the current angle (radians).
    private func advance(to date: Date) -> Double {
        var state = sim.value
        let cruise: Double = -ctx["speed"] * Double.pi / 180
        defer { sim.value = state }
        guard let last = state.last else {
            state.last = date
            state.velocity = cruise
            return state.angle
        }
        let dt: Double = min(max(date.timeIntervalSince(last), 0), 1.0 / 20.0)
        state.last = date
        guard !dragging else { return state.angle }
        // Friction pulls the spin back to the cruising speed in about a second.
        state.velocity += (cruise - state.velocity) * (1 - exp(-dt * 2.6))
        state.angle += state.velocity * dt
        return state.angle
    }
}
