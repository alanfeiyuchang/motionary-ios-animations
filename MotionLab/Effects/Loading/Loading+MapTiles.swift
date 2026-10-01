import SwiftUI

extension Effect {
    static let loadingMapTiles = Effect(
        id: "loading.map-tiles",
        category: .loading,
        interaction: .loop,
        name: L("Map Tiles Loading", "地图瓦片加载"),
        summary: L("Map tiles arrive blurry, then sharp, spiralling out from the centre until a pin drops on the finished map.", "地图瓦片先模糊后清晰，从中心螺旋向外铺开，最后一枚图钉落在加载完成的地图上。"),
        prompt: L(
            "A 260 pt rounded map starts as an empty grey grid of 5 × 5 tiles. Tiles load in a clockwise spiral from the centre, 70 ms apart. Each tile first fades in over 0.22 s as a low-resolution version of itself, blurred 9 pt and outlined by a hairline so it reads as a square, holds for 0.38 s, then cross-fades over 0.3 s to the sharp map of roads, river and parks. The outline disappears and neighbours join seamlessly. When the last corner is sharp, a red pin falls 150 pt onto the centre, squashes 18% on impact, bounces twice with decaying height (about 25 pt, then 4 pt) and sends out one ring while its shadow tightens. After a 2 s hold the map pans to a new area and reloads; a tap reloads immediately. Familiar, progressive, satisfying.",
            "一张 260 pt 的圆角地图起初是 5 × 5 的灰色空网格。瓦片从中心沿顺时针螺旋依次加载，间隔 70 毫秒。每块瓦片先用 0.22 秒淡入低清版本：带 9 pt 模糊，四周一圈细线让它看起来是个方块；停留 0.38 秒后，再用 0.3 秒交叉淡化成清晰的道路、河流与公园，细线消失，与相邻瓦片无缝拼合。最后一块变清晰后，一枚红色图钉从 150 pt 高处落向中心，触地时压扁 18%，弹跳两次且高度衰减（约 25 pt、4 pt），荡开一圈圆环，影子随之收紧。停留 2 秒后地图平移到新区域重新加载；点击可重载。熟悉、渐进。"
        ),
        implementation: L(
            "The map art is one static Canvas shown twice: a blurred copy and a sharp copy, each masked by a Canvas that fills every tile with an opacity computed from elapsed time and the tile's spiral rank. The pin's height is a decaying |cos| bounce of the same clock.",
            "地图图案是一张静态 Canvas，显示两份：一份模糊、一份清晰，各自由一张遮罩 Canvas 控制，遮罩按已过时间与瓦片的螺旋序号为每块瓦片填入不透明度。图钉高度是同一时钟下衰减的 |cos| 弹跳。"
        ),
        apis: ["Canvas", "TimelineView", "mask(_:)", "blur(radius:)", "Shape"],
        tags: ["map", "tiles", "progressive", "pin", "地图", "瓦片", "渐进加载", "图钉"],
        params: [
            .slider("grid", L("Tiles per side", "每边瓦片数"), 3...7, default: 5, step: 1, decimals: 0),
            .slider("stagger", L("Tile interval", "瓦片间隔"), 0.02...0.2, default: 0.07, unit: "s"),
            .slider("blur", L("Low-res blur", "低清模糊"), 3...18, default: 9, decimals: 0, unit: "pt"),
            .choice("order", L("Order", "顺序"), [L("Spiral", "螺旋"), L("Rows", "逐行"), L("Random", "随机")]),
        ]
    ) { ctx in
        MapTilesDemo(ctx: ctx)
    }
}

private enum MapTileTiming {
    static let lead: Double = 0.4
    static let fadeIn: Double = 0.22
    static let hold: Double = 0.38
    static let sharpen: Double = 0.3
    static let pinHold: Double = 2.0
    static let pinTime: Double = 0.9
    static let fadeOut: Double = 0.35

    static func pinStart(tiles: Int, stagger: Double) -> Double {
        lead + Double(tiles - 1) * stagger + hold + sharpen
    }

    static func total(tiles: Int, stagger: Double) -> Double {
        pinStart(tiles: tiles, stagger: stagger) + pinTime + pinHold + fadeOut
    }

    /// Rank of every tile (index = row × n + col) in the loading order.
    static func ranks(n: Int, order: Int) -> [Int] {
        let count: Int = n * n
        var keyed: [(index: Int, key: Double)] = []
        let mid: Double = Double(n - 1) / 2
        for index in 0..<count {
            let col: Double = Double(index % n)
            let row: Double = Double(index / n)
            let key: Double
            switch order {
            case 1:
                key = Double(index)
            case 2:
                key = LoadingCurve.hash(index * 7 + n)
            default:
                // Ring by ring, clockwise from twelve o'clock.
                let dx: Double = col - mid
                let dy: Double = row - mid
                let ring: Double = (max(abs(dx), abs(dy)) + 0.01).rounded(.up)
                var turn: Double = atan2(dx, -dy) / (2 * .pi)
                if turn < 0 { turn += 1 }
                key = ring + turn * 0.999
            }
            keyed.append((index, key))
        }
        keyed.sort { $0.key < $1.key }
        var ranks: [Int] = Array(repeating: 0, count: count)
        for (rank, item) in keyed.enumerated() { ranks[item.index] = rank }
        return ranks
    }
}

private struct MapTilesDemo: View {
    let ctx: DemoContext
    @State private var started = Date()
    /// Bumped on every reload so the map pans to another area.
    @State private var area = 0

    private let side: CGFloat = 260

    var body: some View {
        let n: Int = min(max(ctx.int("grid"), 2), 8)
        let stagger: Double = max(ctx["stagger"], 0.005)
        let ranks: [Int] = MapTileTiming.ranks(n: n, order: ctx.int("order"))
        let total: Double = MapTileTiming.total(tiles: n * n, stagger: stagger)
        VStack(spacing: 14) {
            TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
                let raw: Double = max(timeline.date.timeIntervalSince(started), 0)
                let lap: Int = ctx.isStill ? 0 : Int(raw / total)
                let elapsed: Double = ctx.isStill ? total - MapTileTiming.fadeOut - 0.6 : raw - Double(lap) * total
                let variant: Int = area + lap
                let pinTime: Double = elapsed - MapTileTiming.pinStart(tiles: n * n, stagger: stagger)
                let out: Double = 1 - LoadingCurve.smoothstep((elapsed - (total - MapTileTiming.fadeOut)) / MapTileTiming.fadeOut)
                ZStack {
                    MapPlaceholder(n: n)
                    MapArt(variant: variant)
                        .blur(radius: ctx.cg("blur"))
                        .mask(MapTileMask(n: n, ranks: ranks, elapsed: elapsed, stagger: stagger, stage: 0))
                        .opacity(out)
                    MapArt(variant: variant)
                        .mask(MapTileMask(n: n, ranks: ranks, elapsed: elapsed, stagger: stagger, stage: 1))
                        .opacity(out)
                    MapTileMask(n: n, ranks: ranks, elapsed: elapsed, stagger: stagger, stage: 2)
                        .opacity(out)
                    MapPin(time: pinTime)
                        .opacity(out)
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.stroke))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 9)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.tap()
                area += 1
                started = .now
            }
            DemoHint(text: L("Tap to reload the map", "点击重新加载地图"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Draws per-tile opacity. `stage` 0 = the low-res layer's mask, 1 = the sharp layer's mask,
/// 2 = the hairline outlines that show while a tile is still low-res.
private struct MapTileMask: View {
    let n: Int
    let ranks: [Int]
    let elapsed: Double
    let stagger: Double
    let stage: Int

    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = size.width / CGFloat(n)
            for index in 0..<min(ranks.count, n * n) {
                let start: Double = MapTileTiming.lead + Double(ranks[index]) * stagger
                let lowRes: Double = LoadingCurve.smoothstep((elapsed - start) / MapTileTiming.fadeIn)
                let sharp: Double = LoadingCurve.smoothstep((elapsed - start - MapTileTiming.hold) / MapTileTiming.sharpen)
                let rect = CGRect(
                    x: CGFloat(index % n) * tile,
                    y: CGFloat(index / n) * tile,
                    width: tile + 0.5,
                    height: tile + 0.5
                )
                switch stage {
                case 0:
                    if lowRes > 0.001 { context.fill(Path(rect), with: .color(.white.opacity(lowRes))) }
                case 1:
                    if sharp > 0.001 { context.fill(Path(rect), with: .color(.white.opacity(sharp))) }
                default:
                    let alpha: Double = lowRes * (1 - sharp)
                    if alpha > 0.001 {
                        context.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.55 * alpha)), lineWidth: 1)
                    }
                }
            }
        }
    }
}

/// The empty map: a grey sheet with the tile grid on it.
private struct MapPlaceholder: View {
    let n: Int

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.adaptive(light: 0xDCDCE4, dark: 0x26262B)))
            let tile: CGFloat = size.width / CGFloat(n)
            var grid = Path()
            for line in 1..<n {
                let at: CGFloat = CGFloat(line) * tile
                grid.move(to: CGPoint(x: at, y: 0))
                grid.addLine(to: CGPoint(x: at, y: size.height))
                grid.move(to: CGPoint(x: 0, y: at))
                grid.addLine(to: CGPoint(x: size.width, y: at))
            }
            context.stroke(grid, with: .color(Color.primary.opacity(0.09)), lineWidth: 1)
        }
    }
}

/// A procedural city map. It is larger than the frame; `variant` picks which part is visible.
private struct MapArt: View {
    let variant: Int

    private static let offsets: [CGSize] = [
        CGSize(width: -40, height: -30),
        CGSize(width: -170, height: -60),
        CGSize(width: -110, height: -190),
        CGSize(width: -10, height: -170),
    ]

    private static let land = Color.adaptive(light: 0xF1EFE7, dark: 0x1D262B)
    private static let block = Color.adaptive(light: 0xE6E2D6, dark: 0x232E34)
    private static let water = Color.adaptive(light: 0x9CCBF2, dark: 0x1B4E72)
    private static let park = Color.adaptive(light: 0xBFE3AC, dark: 0x235039)
    private static let road = Color.adaptive(light: 0xFFFFFF, dark: 0x3B4950)
    private static let avenue = Color.adaptive(light: 0xFFD98A, dark: 0x8C6B2B)

    var body: some View {
        let count: Int = MapArt.offsets.count
        let offset: CGSize = MapArt.offsets[((variant % count) + count) % count]
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(MapArt.land))
            context.translateBy(x: offset.width, y: offset.height)
            let extent: CGFloat = 460

            // City blocks.
            for row in 0..<10 {
                for col in 0..<10 where (row * 3 + col * 5) % 4 != 0 {
                    let rect = CGRect(x: CGFloat(col) * 46 + 6, y: CGFloat(row) * 46 + 6, width: 34, height: 34)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(MapArt.block))
                }
            }
            // Parks.
            let parks: [CGRect] = [
                CGRect(x: 96, y: 52, width: 82, height: 80),
                CGRect(x: 282, y: 190, width: 80, height: 126),
                CGRect(x: 52, y: 282, width: 126, height: 80),
            ]
            for rect in parks {
                context.fill(Path(roundedRect: rect, cornerRadius: 12, style: .continuous), with: .color(MapArt.park))
            }
            // The river, with a lighter bank line.
            var river = Path()
            river.move(to: CGPoint(x: extent + 20, y: 40))
            river.addCurve(
                to: CGPoint(x: -20, y: 400),
                control1: CGPoint(x: 250, y: 90),
                control2: CGPoint(x: 260, y: 330)
            )
            context.stroke(river, with: .color(MapArt.water), style: StrokeStyle(lineWidth: 34, lineCap: .round))
            context.stroke(river, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 14]))

            // Streets.
            var streets = Path()
            for line in 0...10 {
                let at: CGFloat = CGFloat(line) * 46
                streets.move(to: CGPoint(x: at, y: -20))
                streets.addLine(to: CGPoint(x: at, y: extent + 20))
                streets.move(to: CGPoint(x: -20, y: at))
                streets.addLine(to: CGPoint(x: extent + 20, y: at))
            }
            context.stroke(streets, with: .color(MapArt.road), lineWidth: 4.5)

            // Two avenues.
            var avenues = Path()
            avenues.move(to: CGPoint(x: -20, y: 120))
            avenues.addCurve(to: CGPoint(x: extent + 20, y: 300), control1: CGPoint(x: 160, y: 110), control2: CGPoint(x: 300, y: 320))
            avenues.move(to: CGPoint(x: 210, y: -20))
            avenues.addLine(to: CGPoint(x: 150, y: extent + 20))
            context.stroke(avenues, with: .color(MapArt.avenue), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            context.stroke(avenues, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }
}

private struct MapPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        // A circle on top of a point, as one outline.
        let r: CGFloat = rect.width / 2
        let centre = CGPoint(x: rect.midX, y: rect.minY + r)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: centre.x - r * 0.87, y: centre.y + r * 0.5),
            control: CGPoint(x: rect.midX - r * 0.25, y: rect.maxY - r * 0.75)
        )
        path.addArc(center: centre, radius: r, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.midX + r * 0.25, y: rect.maxY - r * 0.75)
        )
        path.closeSubpath()
        return path
    }
}

/// The pin, its shadow and its landing ring, all placed from the time since the pin was released.
private struct MapPin: View {
    let time: Double

    private static let drop: Double = 150
    private static let firstHit: Double = 0.18

    var body: some View {
        let t: Double = max(time, 0)
        // Decaying bounce: starts at full height, touches down at 0.18 s, 0.54 s, 0.9 s.
        let height: Double = time < 0 ? MapPin.drop : MapPin.drop * exp(-5 * t) * abs(cos(.pi * t / (2 * MapPin.firstHit)))
        let near: Double = 1 - min(height / MapPin.drop, 1)
        let squash: Double = 0.18 * exp(-pow((t - MapPin.firstHit) / 0.05, 2))
        let ring: Double = (t - MapPin.firstHit) / 0.6
        ZStack {
            Circle()
                .strokeBorder(Palette.red.opacity(0.55 * (1 - min(max(ring, 0), 1))), lineWidth: 2)
                .frame(width: 68, height: 68)
                .scaleEffect(x: 1, y: 0.42)
                .scaleEffect(CGFloat(min(max(ring, 0), 1)) * 0.9 + 0.1)
                .opacity(ring > 0 && ring < 1 ? 1 : 0)
            Ellipse()
                .fill(.black.opacity(0.1 + 0.2 * near))
                .frame(width: 30 - 12 * near, height: 10 - 4 * near)
                .blur(radius: 4 - 2.5 * near)
            MapPinShape()
                .fill(LinearGradient(colors: [Color(hex: 0xFF6B6B), Palette.red], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Circle()
                        .fill(.white)
                        .frame(width: 11, height: 11)
                        .padding(.top, 8.5)
                }
                .frame(width: 28, height: 38)
                .shadow(color: Palette.red.opacity(0.35), radius: 6, y: 3)
                .scaleEffect(x: 1 + squash * 0.7, y: 1 - squash, anchor: .bottom)
                .offset(y: -19 - height)
        }
        .opacity(time < 0 ? 0 : min(t / 0.08, 1))
    }
}
