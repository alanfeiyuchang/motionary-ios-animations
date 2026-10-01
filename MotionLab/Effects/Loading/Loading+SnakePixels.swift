import SwiftUI

extension Effect {
    static let loadingSnakePixels = Effect(
        id: "loading.snake-pixels",
        category: .loading,
        interaction: .loop,
        name: L("Pixel Snake", "像素贪吃蛇"),
        summary: L("A pixel snake winds through every cell of a grid, eats, grows, and a bulge travels down its fading body.", "像素小蛇绕遍网格的每一格，吃到食物就变长，一个鼓包顺着渐淡的身体滑向尾巴。"),
        prompt: L(
            "A 6 × 6 grid of 28 pt rounded pixels, resting at 7% ink. A snake six cells long crawls along a closed path that visits every cell once, at 9 cells per second. The head cell scales in from 60% and pops to 118% before settling; behind it the body fades and shrinks toward the tail along a mint → sky → violet gradient, and the head carries a soft glow. A coral food pixel pulses a few cells ahead. When the head reaches it the snake grows by one cell, and the meal is visible as a bulge of scale and brightness that slides down the body at twice the crawl speed. Five meals later it sheds the extra length over two cells and starts again. Nostalgic, playful, tidy.",
            "一个 6 × 6 的圆角像素网格，每格 28 pt，静止时只有 7% 的墨色。一条六格长的小蛇沿一条恰好经过每一格一次的闭合路线爬行，速度为每秒 9 格。蛇头所在的格子从 60% 放大出现，冲到 118% 再回落；身后的蛇身沿薄荷绿 → 天蓝 → 紫的渐变向尾部逐渐变淡、变小，蛇头带一圈柔光。前方几格处有一颗珊瑚色的食物像素在搏动。蛇头碰到它时，小蛇变长一格，这顿饭化作一个放大、提亮的鼓包，以两倍爬行速度顺着蛇身滑向尾巴。吃过五次之后，它在两格的距离内甩掉多余的长度，重新开始。怀旧、俏皮、整洁。"
        ),
        implementation: L(
            "The path is a Hamiltonian cycle built for any even grid. A TimelineView hands the head's distance along it to a Canvas, which gives every cell an intensity from how far behind the head it sits; food, growth and the travelling bulge are pure functions of that same distance.",
            "路线是为任意偶数网格构造的哈密顿回路。TimelineView 把蛇头沿路线走过的距离交给 Canvas，Canvas 按每一格落后蛇头多远算出亮度；食物、变长和滑动的鼓包都是这同一个距离的纯函数。"
        ),
        apis: ["Canvas", "TimelineView", "Path(roundedRect:cornerRadius:style:)", "GraphicsContext.drawLayer", "Color.mix(with:by:)"],
        tags: ["snake", "pixel", "grid", "retro", "贪吃蛇", "像素", "网格", "复古"],
        params: [
            .slider("speed", L("Crawl speed", "爬行速度"), 3...18, default: 9, decimals: 0, unit: "/s"),
            .slider("length", L("Body length", "蛇身长度"), 3...10, default: 6, step: 1, decimals: 0),
            .choice("grid", L("Grid", "网格"), [L("4 × 4", "4 × 4"), L("6 × 6", "6 × 6"), L("8 × 8", "8 × 8")], default: 1),
            .toggle("food", L("Food & growth", "食物与成长"), default: true),
        ]
    ) { ctx in
        SnakePixelsDemo(ctx: ctx)
    }
}

/// A closed path through every cell of an even `n × n` grid: along the top row, a serpentine through
/// columns 1…n-1 of the remaining rows, and back up column 0.
private enum SnakePath {
    static func make(_ n: Int) -> [(col: Int, row: Int)] {
        var cells: [(col: Int, row: Int)] = []
        for col in 0..<n { cells.append((col, 0)) }
        for row in 1..<n {
            let leftward: Bool = row % 2 == 1
            for step in 0..<(n - 1) {
                let col: Int = leftward ? n - 1 - step : 1 + step
                cells.append((col, row))
            }
        }
        for row in stride(from: n - 1, through: 1, by: -1) { cells.append((0, row)) }
        return cells
    }
}

private struct SnakePixelsDemo: View {
    let ctx: DemoContext
    @State private var clock = LoadingPhaseClock()

    var body: some View {
        let speed: Double = max(ctx["speed"], 0.5)
        let n: Int = [4, 6, 8][min(max(ctx.int("grid"), 0), 2)]
        let path = SnakePath.make(n)
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: ctx.isPreview))) { timeline in
            let head: Double = ctx.isStill ? 33.6 : clock.phase(at: timeline.date, rate: speed) + 4
            SnakeCanvas(
                head: head,
                n: n,
                path: path,
                baseLength: Double(max(ctx.int("length"), 2)),
                food: ctx.bool("food")
            )
            .frame(width: 198, height: 198)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: ctx["speed"]) { old, _ in
            clock.rebase(at: .now, oldRate: max(old, 0.5))
        }
    }
}

private struct SnakeCanvas: View {
    /// Distance the head has travelled along the path, in cells (unbounded).
    let head: Double
    let n: Int
    let path: [(col: Int, row: Int)]
    let baseLength: Double
    let food: Bool

    /// Cells between two meals.
    private static let foodGap: Double = 11
    private static let firstFood: Double = 7
    private static let meals: Int = 5

    private static func bodyColor(_ u: Double) -> Color {
        let x: Double = min(max(u, 0), 1)
        if x < 0.5 { return Palette.mint.mix(with: Palette.sky, by: x * 2) }
        return Palette.sky.mix(with: Palette.violet, by: (x - 0.5) * 2)
    }

    private func length(afterMeals count: Int) -> Double {
        guard food else { return baseLength }
        let cycle: Int = SnakeCanvas.meals + 1
        return baseLength + Double(((count % cycle) + cycle) % cycle)
    }

    var body: some View {
        Canvas { context, size in
            let total: Int = path.count
            let gap: CGFloat = n <= 4 ? 8 : (n <= 6 ? 6 : 4)
            let cell: CGFloat = (size.width - gap * CGFloat(n - 1)) / CGFloat(n)
            let corner: CGFloat = cell * 0.28

            // Meals so far, and how long ago (in cells) the last one was.
            let eaten: Int = food ? max(Int(floor((head - SnakeCanvas.firstFood) / SnakeCanvas.foodGap)) + 1, 0) : 0
            let lastMeal: Double = SnakeCanvas.firstFood + Double(eaten - 1) * SnakeCanvas.foodGap
            let sinceMeal: Double = eaten > 0 ? head - lastMeal : 1000
            let grow: Double = LoadingCurve.smoothstep(sinceMeal / 2)
            let bodyLength: Double = length(afterMeals: eaten - 1) + (length(afterMeals: eaten) - length(afterMeals: eaten - 1)) * grow
            let bulge: Double = sinceMeal * 2
            let nextFood: Double = SnakeCanvas.firstFood + Double(eaten) * SnakeCanvas.foodGap
            let nextFoodIndex: Int = ((Int(nextFood) % total) + total) % total
            let foodIn: Double = eaten > 0 ? LoadingCurve.smoothstep((sinceMeal - 0.6) / 1.5) : 1

            for index in 0..<total {
                let position = path[index]
                let origin = CGPoint(x: CGFloat(position.col) * (cell + gap), y: CGFloat(position.row) * (cell + gap))
                let rect = CGRect(x: origin.x, y: origin.y, width: cell, height: cell)
                context.fill(Path(roundedRect: rect, cornerRadius: corner, style: .continuous), with: .color(Color.primary.opacity(0.07)))

                // How far behind the head this cell is (0 = the cell the head has just filled).
                var behind: Double = (head - Double(index)).truncatingRemainder(dividingBy: Double(total))
                if behind < 0 { behind += Double(total) }

                var intensity: Double = 0
                var scale: CGFloat = 1
                var along: Double = 0
                if behind > Double(total) - 1 {
                    // The cell the head is entering.
                    let entering: Double = behind - (Double(total) - 1)
                    intensity = entering
                    scale = 0.6 + 0.4 * CGFloat(entering)
                } else if behind < bodyLength {
                    along = behind / bodyLength
                    intensity = pow(1 - along, 1.25)
                    scale = 0.74 + 0.26 * CGFloat(1 - along) + 0.18 * CGFloat(exp(-behind * 2.4))
                    if food, sinceMeal < bodyLength {
                        let hump: Double = exp(-pow(behind - bulge, 2) / 0.9)
                        scale += 0.2 * CGFloat(hump)
                        intensity = min(intensity + 0.5 * hump, 1)
                    }
                }

                if intensity > 0.01 {
                    let side: CGFloat = cell * scale
                    let body = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
                    let shape = Path(roundedRect: body, cornerRadius: corner * scale, style: .continuous)
                    if behind < 1 || behind > Double(total) - 1 {
                        context.drawLayer { layer in
                            layer.addFilter(.blur(radius: 7))
                            layer.fill(shape, with: .color(Palette.mint.opacity(0.55 * intensity)))
                        }
                    }
                    context.fill(shape, with: .color(SnakeCanvas.bodyColor(along).opacity(0.2 + 0.8 * intensity)))
                    if behind < 1.2 || behind > Double(total) - 1 {
                        // A highlight on the head pixel.
                        let glint = CGRect(x: body.minX + side * 0.16, y: body.minY + side * 0.14, width: side * 0.3, height: side * 0.18)
                        context.fill(Path(roundedRect: glint, cornerRadius: side * 0.09), with: .color(.white.opacity(0.5 * intensity)))
                    }
                } else if food, index == nextFoodIndex, nextFood - head < Double(total) - bodyLength - 1 {
                    let pulse: CGFloat = 0.62 + 0.1 * CGFloat(sin(head * 1.4))
                    let side: CGFloat = cell * pulse * CGFloat(foodIn)
                    let body = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
                    let shape = Path(roundedRect: body, cornerRadius: side * 0.34, style: .continuous)
                    context.drawLayer { layer in
                        layer.addFilter(.blur(radius: 6))
                        layer.fill(shape, with: .color(Palette.coral.opacity(0.5 * foodIn)))
                    }
                    context.fill(shape, with: .color(Palette.coral.opacity(foodIn)))
                }
            }
        }
    }
}
