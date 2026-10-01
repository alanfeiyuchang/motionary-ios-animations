import SwiftUI

extension Effect {
    static let loadingPayButton = Effect(
        id: "loading.pay-button",
        category: .loading,
        interaction: .tap,
        name: L("Biometric Pay Button", "生物识别支付按钮"),
        summary: L("Pay → spinner → a face or fingerprint scan → a green check that blooms, all inside one morphing button.", "支付 → 转圈 → 面容或指纹扫描 → 绽放的绿色对勾，全程发生在同一枚不断变形的按钮里。"),
        prompt: L(
            "A 236 × 58 pt ink-black pill reads 'Pay $24.00' beside a biometric glyph. On tap the label fades and the pill contracts on a spring (response 0.45 s, damping 0.78) into a 58 pt circle holding a spinning arc for 0.9 s. It then opens into an 84 pt rounded square for the scan: the Face ID glyph sits at 28% opacity while a glowing line sweeps down it in 1.1 s, lighting it fully as it passes; with Touch ID the fingerprint fills from the bottom in pink instead. On recognition the glyph springs from 88% to full size with a clear overshoot. The square snaps to a 64 pt green disc, a white check draws in 0.3 s, and a green bloom swells to 2.6× behind it and fades over 0.85 s with a success haptic. Finally it widens into 'Payment complete' and resets. Secure, quick, reassuring.",
            "一枚 236 × 58 pt 的墨黑胶囊写着“支付 $24.00”。点击后文字淡出，胶囊以弹簧（响应 0.45 秒、阻尼 0.78）收成 58 pt 的圆，转圈 0.9 秒；随后张开成 84 pt 的圆角方块扫描：28% 不透明度的面容 ID 图标被一条光线用 1.1 秒自上而下扫亮（触控 ID 则是指纹自下而上被粉色填满），识别成功时图标从 88% 带过冲弹到原大。方块收成 64 pt 的绿色圆片，白色对勾用 0.3 秒画出，身后绿色光晕放大到 2.6 倍并在 0.85 秒内淡出，伴随成功触感。最后展开为“支付成功”。安全迅速。"
        ),
        implementation: L(
            "A stage enum sets the button's width, height and corner radius, animated with one spring. Each stage's content cross-fades inside; the scan is a bright copy of the glyph revealed by a mask whose height follows an animated 0…1 value, with the scan line riding the mask's edge.",
            "一个阶段枚举决定按钮的宽、高与圆角，用同一组弹簧动画过渡。各阶段的内容在按钮内交叉淡化；扫描是图标的一份亮色副本，由高度随 0…1 动画值变化的遮罩逐步揭开，扫描线贴着遮罩边缘移动。"
        ),
        apis: ["withAnimation(.spring)", "mask(alignment:_:)", "trim(from:to:)", "Task.sleep(for:)", "ButtonStyle"],
        tags: ["pay", "face id", "touch id", "checkout", "支付", "面容", "指纹", "结账"],
        params: [
            .choice("biometric", L("Biometric", "识别方式"), [L("Face ID", "面容 ID"), L("Touch ID", "触控 ID")]),
            .slider("processing", L("Processing time", "处理时长"), 0.3...2.5, default: 0.9, decimals: 1, unit: "s"),
            .slider("scan", L("Scan time", "扫描时长"), 0.5...2.5, default: 1.1, decimals: 1, unit: "s"),
            .slider("bloom", L("Bloom scale", "光晕放大"), 1.4...3.6, default: 2.6, decimals: 1, unit: "×"),
        ]
    ) { ctx in
        PayButtonDemo(ctx: ctx)
    }
}

private enum PayStage {
    case idle
    case processing
    case scanning
    case success
    case receipt

    var size: CGSize {
        switch self {
        case .idle, .receipt: return CGSize(width: 236, height: 58)
        case .processing: return CGSize(width: 58, height: 58)
        case .scanning: return CGSize(width: 84, height: 84)
        case .success: return CGSize(width: 64, height: 64)
        }
    }

    var corner: CGFloat {
        self == .scanning ? 26 : size.height / 2
    }

    var isGreen: Bool { self == .success || self == .receipt }
}

private struct PayButtonDemo: View {
    let ctx: DemoContext
    @State private var stage: PayStage
    @State private var scan: Double
    @State private var recognized = false
    @State private var bloomed = false
    @State private var check: Double = 0
    @State private var task: Task<Void, Never>?

    private static let ink = Color.adaptive(light: 0x111114, dark: 0xF5F5F7)
    private static let onInk = Color.adaptive(light: 0xFFFFFF, dark: 0x111114)
    private static let morph: Animation = .spring(response: 0.45, dampingFraction: 0.78)

    init(ctx: DemoContext) {
        self.ctx = ctx
        // Stills catch the scan half way down the glyph.
        _stage = State(initialValue: ctx.isStill ? .scanning : .idle)
        _scan = State(initialValue: ctx.isStill ? 0.6 : 0)
    }

    private var touchID: Bool { ctx.int("biometric") == 1 }
    private var glyph: String { touchID ? "touchid" : "faceid" }

    var body: some View {
        VStack(spacing: 18) {
            summary
            ZStack {
                bloom
                Button(action: pay) { face }
                    .buttonStyle(PayPressStyle())
            }
            .frame(height: 92)
            DemoHint(text: L("Tap to pay", "点击支付"), ctx: ctx)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Only an idle button is tapped, so a payment is never cut short; it resets itself.
        .autoplay(ctx.isPreview, every: 1.0, delay: 0.6) {
            if stage == .idle { pay() }
        }
        .onDisappear {
            task?.cancel()
            task = nil
        }
    }

    // MARK: Pieces

    private var summary: some View {
        let zh = ctx.language == .zh
        let paid: Bool = stage.isGreen
        return HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.primaryStrong)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .frame(width: 38, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text("Nova •••• 4242")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                Text(paid ? (zh ? "刚刚已支付" : "Paid just now") : (zh ? "馥芮白 × 2" : "Flat White × 2"))
                    .font(.caption)
                    .foregroundStyle(paid ? Palette.green : Color.secondary)
                    .contentTransition(.opacity)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 0)
            Text("$24.00")
                .font(.subheadline.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 13)
        .frame(width: 252, height: 54)
        .background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.stroke))
    }

    private var bloom: some View {
        ZStack {
            Circle()
                .fill(Palette.green)
                .frame(width: 64, height: 64)
                .blur(radius: 10)
                .scaleEffect(bloomed ? ctx.cg("bloom") : 0.9)
                .opacity(bloomed ? 0 : (stage == .success ? 0.6 : 0))
            Circle()
                .stroke(Palette.green, lineWidth: 2)
                .frame(width: 64, height: 64)
                .scaleEffect(bloomed ? ctx.cg("bloom") * 0.8 : 1)
                .opacity(bloomed ? 0 : (stage == .success ? 0.8 : 0))
        }
        .allowsHitTesting(false)
    }

    private var face: some View {
        let zh = ctx.language == .zh
        let size: CGSize = stage.size
        return ZStack {
            RoundedRectangle(cornerRadius: stage.corner, style: .continuous)
                .fill(PayButtonDemo.ink)
            RoundedRectangle(cornerRadius: stage.corner, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2FBF71), Palette.successStrong], startPoint: .top, endPoint: .bottom))
                .opacity(stage.isGreen ? 1 : 0)

            // Idle label.
            HStack(spacing: 8) {
                Image(systemName: glyph)
                    .font(.system(size: 19, weight: .medium))
                Text(zh ? "支付 $24.00" : "Pay $24.00")
                    .font(.headline)
            }
            .foregroundStyle(PayButtonDemo.onInk)
            .fixedSize()
            .opacity(stage == .idle ? 1 : 0)
            .scaleEffect(stage == .idle ? 1 : 0.8)

            // Processing spinner.
            if stage == .processing {
                PaySpinner(color: PayButtonDemo.onInk)
                    .frame(width: 24, height: 24)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            // Biometric scan.
            PayScanGlyph(symbol: glyph, fromBottom: touchID, scan: scan, recognized: recognized, base: PayButtonDemo.onInk)
                .opacity(stage == .scanning ? 1 : 0)
                .scaleEffect(stage == .scanning ? 1 : 0.5)

            // Success check.
            PayCheck()
                .trim(from: 0, to: check)
                .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 24, height: 18)
                .opacity(stage == .success ? 1 : 0)

            // Receipt label.
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                Text(zh ? "支付成功" : "Payment complete")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .fixedSize()
            .opacity(stage == .receipt ? 1 : 0)
            .scaleEffect(stage == .receipt ? 1 : 0.8)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: stage.corner, style: .continuous))
        .shadow(color: (stage.isGreen ? Palette.green : Color.black).opacity(stage.isGreen ? 0.4 : 0.22), radius: 14, y: 8)
    }

    // MARK: Flow

    private func pay() {
        switch stage {
        case .idle:
            break
        case .receipt:
            task?.cancel()
            reset()
            return
        default:
            return
        }
        if !ctx.isPreview { Haptics.tap(.medium) }
        let processing: Double = max(ctx["processing"], 0.1)
        let scanTime: Double = max(ctx["scan"], 0.2)
        // Captured now: false inside the silent intro/autoplay, so delayed feedback stays quiet too.
        let buzz: Bool = !ctx.isPreview && !Haptics.isMuted
        let loops: Bool = ctx.isPreview
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            scan = 0
            recognized = false
            bloomed = false
            check = 0
        }
        withAnimation(PayButtonDemo.morph) { stage = .processing }
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(processing))
            guard !Task.isCancelled else { return }
            withAnimation(PayButtonDemo.morph) { stage = .scanning }
            try? await Task.sleep(for: .seconds(0.25))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: scanTime)) { scan = 1 }
            try? await Task.sleep(for: .seconds(scanTime))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { recognized = true }
            if buzz { Haptics.tap(.light) }
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            withAnimation(PayButtonDemo.morph) { stage = .success }
            withAnimation(.easeOut(duration: 0.85)) { bloomed = true }
            withAnimation(.easeOut(duration: 0.3).delay(0.12)) { check = 1 }
            if buzz { Haptics.success() }
            try? await Task.sleep(for: .seconds(1.15))
            guard !Task.isCancelled else { return }
            withAnimation(PayButtonDemo.morph) { stage = .receipt }
            try? await Task.sleep(for: .seconds(loops ? 1.4 : 2.4))
            guard !Task.isCancelled else { return }
            reset()
        }
    }

    private func reset() {
        withAnimation(PayButtonDemo.morph) { stage = .idle }
    }
}

/// The biometric glyph: a dim base, a bright copy revealed by the scan, and the scan line on the reveal's edge.
private struct PayScanGlyph: View {
    let symbol: String
    let fromBottom: Bool
    let scan: Double
    let recognized: Bool
    let base: Color

    private let side: CGFloat = 46

    var body: some View {
        let bright: LinearGradient = fromBottom
            ? LinearGradient(colors: [Palette.coral, Palette.pink], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Palette.sky, Palette.mint], startPoint: .top, endPoint: .bottom)
        let reveal: CGFloat = side * CGFloat(min(max(scan, 0), 1))
        let lineY: CGFloat = fromBottom ? side / 2 - reveal : reveal - side / 2
        ZStack {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(base.opacity(0.28))
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(bright)
                .frame(width: side, height: side)
                .mask(alignment: fromBottom ? .bottom : .top) {
                    Rectangle().frame(height: reveal)
                }
            Capsule()
                .fill(fromBottom ? Palette.pink : Palette.mint)
                .frame(width: 58, height: 2.5)
                .shadow(color: fromBottom ? Palette.pink : Palette.mint, radius: 5)
                .offset(y: lineY)
                .opacity(scan > 0.01 && scan < 0.99 ? 1 : 0)
        }
        .frame(width: side, height: side)
        .scaleEffect(recognized ? 1.0 : 0.88)
    }
}

private struct PaySpinner: View {
    let color: Color
    @State private var turning = false

    var body: some View {
        Circle()
            .trim(from: 0.05, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 0.75).repeatForever(autoreverses: false), value: turning)
            .onAppear { turning = true }
    }
}

private struct PayCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.37, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct PayPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
