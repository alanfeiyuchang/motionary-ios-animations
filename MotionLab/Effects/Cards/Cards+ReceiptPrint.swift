import SwiftUI

extension Effect {
    static let cardsReceiptPrint = Effect(
        id: "cards.receipt-print",
        category: .cards,
        interaction: .tap,
        name: L("Receipt Print", "打印小票"),
        summary: L("A receipt feeds out of a printer slot one line at a time, each line typed as it appears; swipe it sideways to tear it off.", "小票从打印机出纸口一行一行吐出，每行随出纸打上文字；横向一划就把它撕下来。"),
        prompt: L(
            "A dark printer body with a slot along its top edge. On tap a 172 pt wide paper strip feeds upward in stepper-motor jerks: every 220 ms it advances one 19 pt line in 110 ms (ease-out), and that line's text is revealed left to right in 140 ms as it clears the slot: header, order number, items with prices, total, barcode, thanks. Each feed kicks the strip about 1.6° sideways around the slot, alternating direction and growing with the paper's length, and a loose spring lets it shiver back upright; a green lamp blinks and a light tick marks every line. When the last line is out the paper feeds a little further and rests. Dragging it sideways pivots it about the far corner of the slot; past 40 pt it tears with a rigid haptic and is carried off, turning 24° and fading, showing its serrated edge.",
            "深色打印机的顶部有一道出纸口。点击后172 pt宽的纸带像步进电机那样一顿一顿地向上送出：每220毫秒前进一行（19 pt），用时110毫秒（缓出），这一行文字在离开出纸口时用140毫秒从左到右显现：店名、单号、商品与价格、合计、条形码、致谢。每次送纸把纸带绕出纸口踢开约1.6°，左右交替，纸越长幅度越大，再由松弹簧抖回直立；绿灯闪烁，每行一记轻触感。出完后再送一小段便停住。横向拖动，纸带绕出纸口另一端的角转动；超过40 pt就被撕下，伴随清脆触感，转过24°并淡出，露出锯齿撕口。"
        ),
        implementation: L(
            "The whole receipt is laid out once and offset upward by the number of lines fed, under a mask that ends at the slot. A task steps the feed with a short eased animation per line; each line has its own leading mask for the typing, and a keyframeAnimator plays the wobble around the slot.",
            "整张小票一次排好，按已送出的行数向上偏移，并用一个止于出纸口的遮罩裁切。一个 task 逐行推进送纸，每行一段短促的缓出动画；每行文字各有一个从左展开的遮罩表现打字，keyframeAnimator 负责绕出纸口的晃动。"
        ),
        apis: ["mask", "keyframeAnimator", "Task.sleep", "DragGesture", "Shape", "rotationEffect"],
        tags: ["receipt", "printer", "tear", "paper", "小票", "打印", "撕下", "收据"],
        params: [
            .slider("interval", L("Line interval", "出纸间隔"), 0.12...0.5, default: 0.22, unit: "s"),
            .slider("wobble", L("Paper wobble", "纸带晃动"), 0...4, default: 1.6, step: 0.1, decimals: 1, unit: "°"),
            .slider("items", L("Items", "商品数"), 2...4, default: 3, step: 1, decimals: 0),
        ]
    ) { ctx in
        CardsReceiptDemo(ctx: ctx)
    }
}

private enum CardsReceiptLayout {
    static let area = CGSize(width: 320, height: 292)
    static let paperWidth: CGFloat = 172
    static let line: CGFloat = 19
    static let margin: CGFloat = 12
    /// The slot, measured from the top of the area.
    static let slotY: CGFloat = 238
    static let ink = Color(hex: 0x2B2B33)
}

private enum CardsReceiptLine {
    case header
    case meta
    case rule
    case item(Int)
    case total(String)
    case barcode
    case thanks
}

private struct CardsReceiptItem {
    let name: LocalizedText
    let price: String

    static let all: [CardsReceiptItem] = [
        CardsReceiptItem(name: L("Flat white", "馥芮白"), price: "4.50"),
        CardsReceiptItem(name: L("Croissant", "可颂"), price: "3.80"),
        CardsReceiptItem(name: L("Oat cookie", "燕麦曲奇"), price: "2.90"),
        CardsReceiptItem(name: L("Cold brew", "冷萃咖啡"), price: "5.20"),
    ]

    static let totals = ["0.00", "4.50", "8.30", "11.20", "16.40"]
}

private struct CardsReceiptDemo: View {
    let ctx: DemoContext
    /// Lines pushed out of the slot (fractional while a line is moving).
    @State private var feed: CGFloat
    /// Lines whose text has been printed.
    @State private var typed: Int
    @State private var printing = false
    @State private var ready: Bool
    @State private var kicks = 0
    @State private var lamp = false
    /// Sideways pull on the hanging paper, in points.
    @State private var pull: CGFloat = 0
    /// −1 / +1 once torn: the paper is carried off that way.
    @State private var carried: CGFloat = 0
    @State private var gone = false
    @State private var held = false
    @State private var script: Task<Void, Never>?
    @GestureState private var pressing = false

    init(ctx: DemoContext) {
        self.ctx = ctx
        let count = CGFloat(Self.lines(items: ctx.int("items")).count)
        // A still shows the finished receipt.
        _feed = State(initialValue: ctx.isStill ? count + 0.7 : 0)
        _typed = State(initialValue: ctx.isStill ? Int(count) : 0)
        _ready = State(initialValue: ctx.isStill)
    }

    private static func lines(items: Int) -> [CardsReceiptLine] {
        let count = items.clamped(to: 2...4)
        var result: [CardsReceiptLine] = [.header, .meta, .rule]
        for index in 0..<count { result.append(.item(index)) }
        result.append(contentsOf: [.rule, .total(CardsReceiptItem.totals[count]), .barcode, .thanks])
        return result
    }

    private var lines: [CardsReceiptLine] { Self.lines(items: ctx.int("items")) }

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .top) {
                printer
                paper
            }
            .frame(width: CardsReceiptLayout.area.width, height: CardsReceiptLayout.area.height, alignment: .top)
            DemoHint(text: L("Tap the printer, then swipe the receipt off", "点击打印机，再把小票横向撕下"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .autoplay(ctx.isPreview, every: 5.4, delay: 0.4) { run(autoTear: ctx.isPreview) }
        .onChange(of: pressing) { _, isPressing in
            guard !isPressing else { return }
            // onEnded can arrive just after the gesture state resets, so this fallback waits a tick:
            // by then only a cancelled touch still has something to clean up.
            Task { @MainActor in
                if held {
                    held = false
                    letGo(velocity: 0)
                }
            }
        }
        .onChange(of: ctx.int("items")) { _, _ in reset() }
        .onDisappear { script?.cancel() }
    }

    // MARK: Printer

    private var printer: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .top) {
            shape
                .fill(LinearGradient(colors: [Color(hex: 0x454B59), Color(hex: 0x24272F)], startPoint: .top, endPoint: .bottom))
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: .black.opacity(0.28), radius: 12, y: 8)
            Capsule()
                .fill(Color.black.opacity(0.85))
                .frame(width: CardsReceiptLayout.paperWidth + 16, height: 7)
                .padding(.top, 7)
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: 0x4BE38A))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(hex: 0x4BE38A).opacity(0.9), radius: lamp ? 5 : 1)
                    .opacity(lamp ? 1 : 0.35)
                Text(L("PRINT", "打印"), ctx.language)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.white.opacity(0.55))
                Spacer(minLength: 0)
                Image(systemName: "printer.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(width: 34, height: 24)
                    .background(Color.white.opacity(0.1), in: Capsule())
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
        }
        .frame(width: 236, height: 54)
        .contentShape(Rectangle())
        .onTapGesture { tapPrinter() }
        .offset(y: CardsReceiptLayout.slotY - 10)
    }

    // MARK: Paper

    private var paper: some View {
        let all = lines
        let fullHeight = CardsReceiptLayout.margin + (CGFloat(all.count) + 0.7) * CardsReceiptLayout.line
        let out = CardsReceiptLayout.margin + feed * CardsReceiptLayout.line
        let slot = CardsReceiptLayout.slotY
        let area = CardsReceiptLayout.area
        // The paper leans as it is pulled, pivoting on the corner of the slot it is pulled away from.
        let lean = Double((pull / 90).clamped(to: -1...1)) * 9
        let pivotX: CGFloat = pull >= 0 ? (area.width - CardsReceiptLayout.paperWidth) / 2 : (area.width + CardsReceiptLayout.paperWidth) / 2
        let amplitude = ctx["wobble"] * Double(min(feed / CGFloat(max(all.count, 1)), 1))
        return CardsReceiptSheet(lines: all, typed: typed, language: ctx.language)
            .frame(width: CardsReceiptLayout.paperWidth, height: fullHeight, alignment: .top)
            .offset(y: slot - out)
            .frame(width: area.width, height: area.height, alignment: .top)
            .keyframeAnimator(initialValue: 0.0, trigger: kicks) { content, angle in
                content.rotationEffect(.degrees(angle), anchor: UnitPoint(x: 0.5, y: slot / area.height))
            } keyframes: { _ in
                CubicKeyframe(kicks % 2 == 0 ? amplitude : -amplitude, duration: 0.07)
                SpringKeyframe(0, duration: 0.55, spring: Spring(response: 0.3, dampingRatio: 0.28))
            }
            .rotationEffect(.degrees(lean + Double(carried) * 24), anchor: UnitPoint(x: pivotX / area.width, y: slot / area.height))
            .offset(x: carried * 120 + pull * 0.25, y: -abs(carried) * 46)
            .opacity(gone ? 0 : 1)
            // Everything still inside the printer is hidden; once torn the whole sheet shows.
            .mask(alignment: .top) {
                Rectangle().frame(height: carried == 0 ? slot : area.height * 2).offset(y: carried == 0 ? 0 : -area.height / 2)
            }
            .overlay(alignment: .top) { slotLip }
            .contentShape(Rectangle().size(width: CardsReceiptLayout.paperWidth, height: max(out, 1)).offset(x: (area.width - CardsReceiptLayout.paperWidth) / 2, y: slot - out))
            .gesture(tear)
            .allowsHitTesting(ready)
    }

    /// Shade where the paper leaves the slot.
    private var slotLip: some View {
        LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            .frame(width: CardsReceiptLayout.paperWidth, height: 9)
            .offset(y: CardsReceiptLayout.slotY - 9)
            .opacity(feed > 0.2 && carried == 0 ? 1 : 0)
            .allowsHitTesting(false)
    }

    private var tear: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressing) { _, state, _ in state = true }
            .onChanged { value in
                guard ready, carried == 0 else { return }
                held = true
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { pull = value.translation.width }
                if abs(value.translation.width) > 40 {
                    held = false
                    tearOff(direction: value.translation.width > 0 ? 1 : -1, haptic: true)
                }
            }
            .onEnded { value in
                guard held else { return }
                held = false
                letGo(velocity: value.predictedEndTranslation.width)
            }
    }

    private func letGo(velocity: CGFloat) {
        guard ready, carried == 0 else { return }
        if abs(velocity) > 90 {
            tearOff(direction: velocity > 0 ? 1 : -1, haptic: true)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { pull = 0 }
        }
    }

    // MARK: Actions

    private func tapPrinter() {
        if ready {
            tearOff(direction: 1, haptic: true)
        } else {
            run(autoTear: false)
        }
    }

    private func reset() {
        script?.cancel()
        printing = false
        ready = false
        lamp = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            feed = 0
            typed = 0
            pull = 0
            carried = 0
            gone = false
        }
    }

    private func run(autoTear: Bool) {
        guard !printing, !ready, carried == 0 else { return }
        printing = true
        let buzz = !ctx.isPreview && !Haptics.isMuted
        let interval = ctx["interval"]
        let count = lines.count
        script?.cancel()
        script = Task { @MainActor in
            for line in 0..<count {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: min(0.11, interval * 0.6))) { feed = CGFloat(line + 1) }
                withAnimation(.linear(duration: 0.14)) { typed = line + 1 }
                kicks += 1
                lamp.toggle()
                if buzz { Haptics.tap(.light) }
                try? await Task.sleep(for: .seconds(interval))
            }
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { feed = CGFloat(count) + 0.7 }
            kicks += 1
            lamp = true
            printing = false
            ready = true
            guard autoTear else { return }
            try? await Task.sleep(for: .seconds(1.3))
            guard !Task.isCancelled else { return }
            tearOff(direction: 1, haptic: false)
        }
    }

    private func tearOff(direction: CGFloat, haptic: Bool) {
        guard ready, carried == 0 else { return }
        ready = false
        lamp = false
        if haptic && !ctx.isPreview { Haptics.tap(.rigid) }
        withAnimation(.timingCurve(0.3, 0, 0.7, 1, duration: 0.5)) { carried = direction }
        withAnimation(.easeIn(duration: 0.3).delay(0.2)) { gone = true }
        script?.cancel()
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            reset()
        }
    }
}

/// The printed strip: every line at a fixed height, text revealed left to right as it is printed.
private struct CardsReceiptSheet: View {
    let lines: [CardsReceiptLine]
    let typed: Int
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: CardsReceiptLayout.margin)
            ForEach(0..<lines.count, id: \.self) { index in
                row(lines[index])
                    .frame(height: CardsReceiptLayout.line)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: index < typed ? CardsReceiptLayout.paperWidth : 0)
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .foregroundStyle(CardsReceiptLayout.ink)
        .background {
            CardsReceiptPaper()
                .fill(LinearGradient(colors: [Color(hex: 0xF4F1EA), Color(hex: 0xFFFFFF), Color(hex: 0xF1EEE6)], startPoint: .leading, endPoint: .trailing))
                .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        }
    }

    @ViewBuilder
    private func row(_ line: CardsReceiptLine) -> some View {
        switch line {
        case .header:
            Text(L("CORNER CAFÉ", "街角咖啡"), language)
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .frame(maxWidth: .infinity)
        case .meta:
            Text(verbatim: "No. 0428   10:24")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .opacity(0.6)
                .frame(maxWidth: .infinity)
        case .rule:
            Line()
                .stroke(CardsReceiptLayout.ink.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(height: 1)
        case .item(let index):
            let item = CardsReceiptItem.all[index % CardsReceiptItem.all.count]
            HStack {
                Text(item.name, language)
                Spacer(minLength: 0)
                Text(verbatim: item.price)
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
        case .total(let amount):
            HStack {
                Text(L("TOTAL", "合计"), language)
                Spacer(minLength: 0)
                Text(verbatim: amount)
            }
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
        case .barcode:
            CardsReceiptBarcode()
                .frame(height: 14)
        case .thanks:
            Text(L("THANK YOU", "谢谢惠顾"), language)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(2)
                .opacity(0.6)
                .frame(maxWidth: .infinity)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Receipt paper: straight top, serrated bottom where the cutter tears it.
private struct CardsReceiptPaper: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = 14
        let step = rect.width / CGFloat(teeth)
        let depth: CGFloat = 4
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        for tooth in 0..<teeth {
            let x = rect.maxX - CGFloat(tooth) * step
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: x - step, y: rect.maxY - depth))
        }
        path.closeSubpath()
        return path
    }
}

private struct CardsReceiptBarcode: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = 0
            var seed: UInt64 = 0xC0FFEE
            while x < size.width {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let width = CGFloat(1 + (seed >> 40) % 3)
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                let gap = CGFloat(1 + (seed >> 40) % 3)
                context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(CardsReceiptLayout.ink))
                x += width + gap
            }
        }
    }
}
