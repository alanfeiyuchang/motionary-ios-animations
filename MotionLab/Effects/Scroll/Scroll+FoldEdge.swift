import SwiftUI

extension Effect {
    static let scrollFoldEdge = Effect(
        id: "scroll.fold-edge",
        category: .scroll,
        interaction: .scroll,
        name: L("Accordion Fold Edges", "边缘风琴折叠"),
        summary: L("The list is one strip of paper that pleats like an accordion as rows near the top and bottom edges.", "整个列表像一条纸带，行靠近上下边缘时像手风琴一样折成一道道褶。"),
        prompt: L(
            "A list of 50 pt rows joined edge to edge like one strip of paper. In the middle the strip lies flat. Within 90 pt of the top or bottom edge it pleats: neighbouring rows hinge on alternate edges, one tipping back from its top and the next from its bottom, so they meet in ridges and valleys. The fold angle grows continuously from 0° at the zone boundary to 72° at the edge, and each row's projected height shrinks by the cosine of its angle, so the strip compresses toward the edge and more rows stay in view. Faces turned away from the light darken by about 12%, the others brighten slightly, and mild perspective narrows the receding edges. Everything is a pure function of position, so it scrubs with the finger. Crisp, like folding a paper map.",
            "列表由一条条50 pt高的行首尾相接而成，像一整条纸带。中间区域纸带平铺。在距离上下边缘90 pt以内，它开始起褶：相邻两行以交替的边为铰链，一行从上沿向后倒，下一行从下沿向后倒，于是相接处形成一道道山脊和谷线。折叠角度从区域边界的0°连续增大到边缘处的72°，每一行的投影高度按该角度的余弦缩短，纸带因此向边缘压缩，视野内能留下更多的行。背光的折面压暗约12%，迎光的折面略微提亮，轻微的透视让后退的边变窄。所有变化都只取决于位置，因此完全跟手。干脆利落，像在折一张纸质地图。"
        ),
        implementation: L(
            "Each row's visualEffect maps its top and bottom edges (in the .scrollView space) through a compression curve, the integral of cos θ across the fold zone. The mapped height gives the row's angle; rotation3DEffect hinges it on its top or bottom edge by row parity, an offset moves the hinge to its mapped position and brightness shades the face.",
            "每一行的 visualEffect 把自己的上沿和下沿（.scrollView 坐标空间）送入一条压缩曲线，也就是折叠区域内 cos θ 的积分。由映射后的高度反推出该行的角度；rotation3DEffect 按行的奇偶以上沿或下沿为铰链旋转，再用 offset 把铰链移到映射后的位置，brightness 负责折面的明暗。"
        ),
        apis: ["visualEffect", "rotation3DEffect", "coordinateSpace(.scrollView)", "brightness", "ScrollPosition"],
        tags: ["fold", "accordion", "pleat", "paper", "3D", "折叠", "手风琴", "褶皱", "纸", "三维"],
        params: [
            .slider("zone", L("Fold zone", "折叠区域"), 50...130, default: 90, step: 5, decimals: 0, unit: "pt"),
            .slider("angle", L("Max fold angle", "最大折角"), 40...84, default: 72, step: 1, decimals: 0, unit: "°"),
            .slider("shade", L("Shading", "明暗强度"), 0...1, default: 0.6),
        ]
    ) { ctx in
        ScrollFoldEdgeDemo(ctx: ctx)
    }
}

/// The accordion's geometry: where a point of the flat strip lands once the edge zones are pleated.
private struct ScrollFoldCurve {
    let viewport: CGFloat
    let zone: CGFloat
    /// Fold angle at the very edge, in radians.
    let maxAngle: CGFloat

    /// Compressed position of a point `y` measured from an edge (the integral of cos θ over the zone).
    private func fromEdge(_ y: CGFloat) -> CGFloat {
        guard y < zone else { return y }
        let u: CGFloat = (zone - y) / zone
        let k: CGFloat = zone / maxAngle
        if u <= 1 { return zone - k * sin(maxAngle * u) }
        // Beyond the edge the strip stays folded at the maximum angle.
        return zone - k * sin(maxAngle) - (u - 1) * zone * cos(maxAngle)
    }

    func map(_ y: CGFloat) -> CGFloat {
        if y < viewport / 2 { return fromEdge(y) }
        return viewport - fromEdge(viewport - y)
    }
}

private struct ScrollFoldEdgeDemo: View {
    let ctx: DemoContext
    @State private var position = ScrollPosition(edge: .top)
    @State private var viewport: CGFloat = 340
    @State private var down = false

    private let rowHeight: CGFloat = 50
    private let count = 26

    var body: some View {
        let rowHeight = self.rowHeight
        let curve = ScrollFoldCurve(
            viewport: max(viewport, 1),
            zone: min(ctx.cg("zone"), max(viewport, 1) / 2),
            maxAngle: max(ctx.cg("angle") * .pi / 180, 0.01)
        )
        let shade = ctx["shade"]
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    let hingesOnTop = i % 2 == 0
                    ScrollFoldRow(index: i, language: ctx.language, isLast: i == count - 1)
                        .frame(height: rowHeight)
                        .visualEffect { content, proxy in
                            let frame = proxy.frame(in: .scrollView)
                            let top: CGFloat = curve.map(frame.minY)
                            let bottom: CGFloat = curve.map(frame.maxY)
                            let ratio: CGFloat = ((bottom - top) / rowHeight).clamped(to: 0...1)
                            let angle: CGFloat = acos(ratio)
                            let tilt: Double = Double(sin(angle))
                            // Top-hinged rows tip their lower edge back and face the floor: darker.
                            let light: Double = hingesOnTop ? -0.2 * tilt * shade : 0.05 * tilt * shade
                            return content
                                .brightness(light)
                                .rotation3DEffect(
                                    .radians(Double(hingesOnTop ? -angle : angle)),
                                    axis: (x: 1, y: 0, z: 0),
                                    anchor: hingesOnTop ? .top : .bottom,
                                    perspective: 0.3
                                )
                                .offset(y: hingesOnTop ? top - frame.minY : bottom - frame.maxY)
                        }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onGeometryChange(for: CGFloat.self, of: { proxy in proxy.size.height }, action: { newHeight in
            viewport = newHeight
        })
        .clipped()
        .autoplay(ctx.isPreview, every: 2.8) {
            down.toggle()
            withAnimation(.smooth(duration: 2.3)) {
                position.scrollTo(y: down ? 620 : 0)
            }
        }
    }
}

private struct ScrollFoldRow: View {
    let index: Int
    let language: AppLanguage
    let isLast: Bool

    var body: some View {
        HStack(spacing: 12) {
            ScrollKitIcon(index: index, size: 32)
            Text(ScrollKit.title(index), language)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Text(verbatim: ScrollKit.time(index))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.elevated)
        .overlay(alignment: .bottom) {
            // The crease between two panels of the strip.
            Rectangle()
                .fill(Color.primary.opacity(isLast ? 0 : 0.1))
                .frame(height: 0.5)
        }
        .overlay {
            Rectangle().strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }
}
