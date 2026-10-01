import SwiftUI

extension Effect {
    static let loadingFoldingCube = Effect(
        id: "loading.folding-cube",
        category: .loading,
        interaction: .loop,
        name: L("Folding Paper Cube", "折纸方块"),
        summary: L("Four paper squares unfold one after another around a centre, then fold away again.", "四片纸方块绕中心依次展开，再依次折起收走。"),
        prompt: L(
            "Four 44 pt paper squares form a 2 × 2 sheet standing on its corner like a diamond. In a 2.4 s loop each square unfolds from on top of its neighbour: it swings 180° about the edge they share, in 0.4-perspective 3D, over 0.48 s on an ease-in-out cubic, lies flat, then folds forward over its next edge onto the following square and vanishes. The four are staggered 0.6 s apart, so one square always opens while another closes and an L of three chases itself clockwise. A square's face darkens by up to 20% as it tilts away from the light and shows a deeper back side past 90°, and a 1.5 pt gap keeps the creases visible. The soft ground shadow breathes with the open area. Crisp, papery, mechanical.",
            "四片 44 pt 的纸方块拼成 2 × 2 的一张纸，像菱形一样立在一个角上。在 2.4 秒的循环里，每片都从相邻那片的上方翻开：绕两者共用的边转 180°，透视系数 0.4，用时 0.48 秒，缓入缓出三次曲线；平躺片刻后，再绕下一条边向前折到后一片上并消失。四片依次错开 0.6 秒，总有一片在展开、另一片在折起，三片组成的 L 形沿顺时针首尾相追。方块背光倾斜时最多变暗 20%，转过 90° 后露出更深的背面，1.5 pt 的缝隙让折痕清晰。地面投影随展开面积呼吸。利落、有纸感、精确。"
        ),
        implementation: L(
            "A TimelineView gives each quadrant a delayed phase; two chained rotation3DEffects (bottom edge, then trailing edge) fold a square inside a container that is rotated 90° per quadrant, with brightness and zIndex derived from the fold angle.",
            "TimelineView 给每个象限一个带延迟的相位；两次串联的 rotation3DEffect（先绕底边、再绕后缘）在每象限旋转 90° 的容器内折叠方块，亮度与 zIndex 都由折角推导。"
        ),
        apis: ["TimelineView", "rotation3DEffect(_:axis:anchor:perspective:)", "rotationEffect", "zIndex", "brightness"],
        tags: ["fold", "cube", "paper", "3d", "折叠", "方块", "折纸", "加载"],
        params: [
            .slider("period", L("Loop time", "循环周期"), 1.2...5, default: 2.4, decimals: 1, unit: "s"),
            .slider("perspective", L("Perspective", "透视"), 0...1, default: 0.4),
            .slider("gap", L("Crease gap", "折痕缝隙"), 0...6, default: 1.5, decimals: 1, unit: "pt"),
            .choice("stance", L("Stance", "姿态"), [L("Diamond", "菱形"), L("Square", "正方")], default: 0),
        ]
    ) { ctx in
        FoldingCubeDemo(ctx: ctx)
    }
}

private struct FoldClock {
    var anchorDate = Date()
    var anchorPhase: Double = 0

    func phase(at date: Date, rate: Double) -> Double {
        anchorPhase + date.timeIntervalSince(anchorDate) * rate
    }

    mutating func rebase(at date: Date, oldRate: Double) {
        anchorPhase = phase(at: date, rate: oldRate)
        anchorDate = date
    }
}

private struct FoldState {
    /// Degrees about the bottom edge (-180 = lying on the previous square, 0 = flat).
    var unfold: Double
    /// Degrees about the trailing edge (0 = flat, 180 = lying on the next square).
    var fold: Double
    var opacity: Double

    static func ease(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    /// `u` is the quadrant's own phase in 0..<1. Unfold 0…0.2, flat until 0.75, fold 0.75…0.95, hidden after.
    /// With a quarter-loop stagger, a square always unfolds from, and folds onto, a neighbour that is flat.
    static func at(_ u: Double) -> FoldState {
        let opening: Double = ease(u / 0.2)
        let closing: Double = ease((u - 0.75) / 0.2)
        let unfold: Double = -180 * (1 - opening)
        let fold: Double = 180 * closing
        // Coincident with a neighbour when fully folded: fade only across the last 25°.
        let visibleIn: Double = min(max((180 + unfold) / 25, 0), 1)
        let visibleOut: Double = min(max((180 - fold) / 25, 0), 1)
        return FoldState(unfold: unfold, fold: fold, opacity: min(visibleIn, visibleOut))
    }

    var tilt: Double { max(abs(unfold), abs(fold)) }
}

private struct FoldingCubeDemo: View {
    let ctx: DemoContext
    @State private var clock = FoldClock()

    var body: some View {
        let zh = ctx.language == .zh
        let period: Double = max(ctx["period"], 0.3)
        VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                // Stills show the sheet with one square mid-fold.
                let phase: Double = ctx.isStill ? 0.07 : clock.phase(at: timeline.date, rate: 1 / period)
                FoldingCubeView(
                    phase: phase,
                    perspective: ctx.cg("perspective"),
                    gap: ctx.cg("gap"),
                    diamond: ctx.int("stance") == 0
                )
            }
            .frame(width: 200, height: 170)
            VStack(spacing: 4) {
                Text(zh ? "正在解包资源" : "Unpacking assets")
                    .font(.subheadline.weight(.semibold))
                Text(zh ? "展开 4 个资源包中的第 2 个…" : "Unfolding bundle 2 of 4…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["period"]) { old, _ in clock.rebase(at: .now, oldRate: 1 / max(old, 0.3)) }
    }
}

private struct FoldingCubeView: View {
    let phase: Double
    let perspective: CGFloat
    let gap: CGFloat
    let diamond: Bool

    private let side: CGFloat = 44
    private let fronts: [Color] = [Palette.mint, Palette.sky, Palette.indigo, Palette.violet]

    var body: some View {
        let states: [FoldState] = (0..<4).map { quadrant in
            let u: Double = phase - Double(quadrant) * 0.25
            return FoldState.at(u - floor(u))
        }
        // How much of the sheet is open right now (0…1), for the ground shadow.
        let open: Double = states.reduce(0) { $0 + $1.opacity * (1 - $1.tilt / 180) } / 4
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<4, id: \.self) { quadrant in
                    square(quadrant, states[quadrant])
                        // A moving square must pass over its flat neighbours.
                        .zIndex(states[quadrant].tilt > 0.5 ? 2 : 1)
                }
            }
            .frame(width: side * 2, height: side * 2)
            .rotationEffect(.degrees(diamond ? 45 : 0))
            .frame(width: 150, height: 132)
            Ellipse()
                .fill(Color.primary.opacity(0.05 + 0.10 * open))
                .frame(width: CGFloat(52 + 54 * open), height: 9)
                .blur(radius: 4)
        }
    }

    private func square(_ quadrant: Int, _ state: FoldState) -> some View {
        let color: Color = fronts[quadrant]
        let shade: Double = sin(state.tilt * .pi / 180)
        let showsBack: Bool = state.tilt > 90
        let face: Color = showsBack ? color.mix(with: .black, by: 0.24) : color
        let corner: CGFloat = 5
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(face)
            .overlay {
                // A paper sheen that only the front carries.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(showsBack ? 0.04 : 0.30), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .brightness(-0.20 * shade)
            .padding(gap / 2)
            .frame(width: side, height: side)
            .rotation3DEffect(.degrees(state.unfold), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: perspective)
            .rotation3DEffect(.degrees(state.fold), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: perspective)
            .opacity(state.opacity)
            .offset(x: -side / 2, y: -side / 2)
            .rotationEffect(.degrees(Double(quadrant) * 90))
    }
}
