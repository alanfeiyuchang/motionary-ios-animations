import SwiftUI

extension Effect {
    static let scrollWeatherCollapse = Effect(
        id: "scroll.weather-collapse",
        category: .scroll,
        interaction: .scroll,
        name: L("Weather Header Collapse", "天气头部折叠"),
        summary: L("The giant temperature shrinks into a one-line bar under the city name while the summary lines leave one by one and the cards slide beneath.", "巨大的温度数字缩进城市名下方的一行小字里，摘要逐行退场，卡片从头部下方滑过。"),
        prompt: L(
            "A weather screen on a sky gradient: city name, a 76 pt thin temperature, a condition line and a high/low line, above translucent forecast cards. The first 128 pt of scroll scrubs the header from 196 pt down to a 68 pt bar. The summary leaves in sequence: the high/low line fades and rises over the first 30%, the condition line over 15–50%. Meanwhile the temperature itself shrinks, scaling about its top to 26% and sliding left into a compact line under the city, where a divider and the condition fade in beside it over the last 35%. The sun glow drifts up at half speed and dims. Cards never show through the header: a mask fades them out 14 pt under its current bottom edge. Pulling down stretches the header and swells the number by up to 12%. Lifting mid-way settles to the nearer state in 0.35 s.",
            "天空渐变上的天气界面：城市名、76 pt 细体温度、天气状况与最高最低温两行摘要，下面是半透明预报卡片。前 128 pt 的滚动把头部从 196 pt 连续压成 68 pt 的窄条。摘要按顺序退场：最高最低温在前 30% 内上移淡出，天气状况在 15%–50% 间淡出。温度数字本身在缩小：以顶部为锚点缩到 26%，向左滑入城市名下方的一行，分隔线与天气状况在最后 35% 里在旁边淡入。遮罩让卡片在头部下沿以下 14 pt 内淡出。下拉时头部拉长，数字最多放大 12%。半途松手，0.35 秒内停到更近的状态。"
        ),
        implementation: L(
            "onScrollGeometryChange publishes the offset; a 0…1 progress with a separate eased sub-range per element positions the header overlay. The temperature is one Text that is scaled and moved (not cross-faded) into the compact line, and the ScrollView is masked by a gradient that starts at the header's current height.",
            "onScrollGeometryChange 发布偏移量；由 0…1 的进度按各元素自己的缓动子区间摆放头部叠加层。温度是同一个 Text，靠缩放和位移（而不是交叉淡化）落进紧凑的那一行；ScrollView 被一个从头部当前高度开始的渐变遮罩。"
        ),
        apis: ["onScrollGeometryChange", "ScrollPosition", "mask", "scaleEffect(_:anchor:)", "onScrollPhaseChange"],
        tags: ["weather", "header", "collapse", "temperature", "large title", "天气", "头部", "折叠", "温度", "大标题"],
        params: [
            .slider("range", L("Collapse distance", "折叠距离"), 90...180, default: 128, step: 2, decimals: 0, unit: "pt"),
            .choice("sky", L("Sky", "天空"), [L("Day", "白天"), L("Dusk", "黄昏"), L("Night", "夜晚")], default: 0),
            .toggle("snap", L("Snap to state", "自动吸附"), default: true),
        ]
    ) { ctx in
        ScrollWeatherDemo(ctx: ctx)
    }
}

private let scrollWeatherExpanded: CGFloat = 196
private let scrollWeatherBar: CGFloat = 68

private struct ScrollWeatherDemo: View {
    let ctx: DemoContext
    @State private var offset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var down = false
    @State private var fingerPull: CGFloat = 0

    private var range: CGFloat { max(ctx.cg("range"), 1) }

    var body: some View {
        let progress: CGFloat = (offset / range).clamped(to: 0...1)
        let pull: CGFloat = max(-offset, 0) + fingerPull
        let headerHeight: CGFloat = ScrollMath.lerp(scrollWeatherExpanded, scrollWeatherBar, progress) + pull
        return ScrollView {
            VStack(spacing: 10) {
                // At the default distance (expanded − bar) the header gives back exactly the space the
                // scroll consumes, so the cards stay glued to its bottom edge while it collapses.
                Color.clear.frame(height: scrollWeatherExpanded + fingerPull)
                ScrollWeatherHourly(sky: ctx.int("sky"), language: ctx.language)
                ScrollWeatherDaily(language: ctx.language)
                ScrollWeatherTiles(language: ctx.language)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }, action: { _, newValue in
            offset = newValue
        })
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .idle { snapIfNeeded() }
        }
        .mask {
            VStack(spacing: 0) {
                Color.clear.frame(height: max(headerHeight - 4, 0))
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 14)
                Color.black
            }
        }
        .overlay(alignment: .top) {
            ScrollWeatherHeader(progress: progress, pull: pull, language: ctx.language)
                .frame(height: headerHeight, alignment: .top)
                .allowsHitTesting(false)
        }
        .background {
            ScrollWeatherSky(sky: ctx.int("sky"), drift: min(offset, range) * 0.5 - pull * 0.3, dim: progress)
        }
        .clipped()
        .environment(\.colorScheme, .dark)
        .modifier(ScrollTopPull(isEnabled: !ctx.isPreview && offset <= 0.5, pull: $fingerPull))
        .autoplay(ctx.isPreview, every: 2.4) {
            down.toggle()
            withAnimation(.smooth(duration: 1.6)) {
                position.scrollTo(y: down ? 250 : 0)
            }
        }
    }

    private func snapIfNeeded() {
        guard ctx.bool("snap"), offset > 0, offset < range else { return }
        withAnimation(.smooth(duration: 0.35)) {
            position.scrollTo(y: offset < range / 2 ? 0 : range)
        }
    }
}

// MARK: - Header

private struct ScrollWeatherHeader: View {
    /// 0 expanded … 1 compact bar.
    let progress: CGFloat
    let pull: CGFloat
    let language: AppLanguage

    private let temperature = 21

    var body: some View {
        let p = progress
        let stretch: CGFloat = min(pull / 160, 1)
        // Sequenced exits and the late arrival of the compact line.
        let highLow: CGFloat = 1 - ScrollMath.unit(p, 0, 0.3)
        let condition: CGFloat = 1 - ScrollMath.unit(p, 0.15, 0.5)
        let compact: CGFloat = ScrollMath.smooth(ScrollMath.unit(p, 0.65, 1))
        let travel: CGFloat = ScrollMath.smooth(p)
        return ZStack(alignment: .top) {
            Text(L("Lisbon", "里斯本"), language)
                .font(.system(size: ScrollMath.lerp(24, 20, p), weight: .semibold))
                .offset(y: ScrollMath.lerp(18, 12, p) + pull * 0.35)
            // One number: it shrinks about its top and slides left into the compact line.
            ZStack {
                // Thin at display size; it gains weight as it shrinks so it stays legible in the bar.
                Text(verbatim: "\(temperature)°")
                    .font(.system(size: 76, weight: .thin))
                    .opacity(Double(1 - compact))
                Text(verbatim: "\(temperature)°")
                    .font(.system(size: 76, weight: .regular))
                    .opacity(Double(compact))
            }
                .monospacedDigit()
                .fixedSize()
                .scaleEffect(ScrollMath.lerp(1 + 0.12 * stretch, 0.26, travel), anchor: .top)
                .offset(x: ScrollMath.lerp(8, compactShift, travel), y: ScrollMath.lerp(44, 39, travel) + pull * 0.55)
            Text(L("Mostly Clear", "晴间多云"), language)
                .font(.system(size: 17, weight: .medium))
                .opacity(Double(condition) * 0.9)
                .offset(y: 136 - 30 * (1 - condition) + pull * 0.7)
            Text(L("H:24°  L:15°", "最高 24°  最低 15°"), language)
                .font(.system(size: 17, weight: .medium).monospacedDigit())
                .opacity(Double(highLow))
                .offset(y: 160 - 26 * (1 - highLow) + pull * 0.8)
            compactTail
                .opacity(Double(compact))
                .offset(x: 12 + 8 * (1 - compact), y: 41)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// How far left the shrunken number sits, so that "21° | Mostly Clear" reads as one centred line.
    private var compactShift: CGFloat { language == .zh ? -44 : -58 }

    private var compactTail: some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1, height: 13)
            Text(L("Mostly Clear", "晴间多云"), language)
                .font(.system(size: 15, weight: .medium))
                .opacity(0.9)
        }
        .fixedSize()
    }
}

// MARK: - Sky

private struct ScrollWeatherSky: View {
    let sky: Int
    /// Points the glow has drifted upward.
    let drift: CGFloat
    let dim: CGFloat

    private var colors: [Color] {
        switch sky {
        case 1: return [Color(hex: 0x3B2F7A), Color(hex: 0xC2557E), Color(hex: 0xF7A45C)]
        case 2: return [Color(hex: 0x070B24), Color(hex: 0x1A2460), Color(hex: 0x3A3F8F)]
        default: return [Color(hex: 0x2F7FD8), Color(hex: 0x5FA9EE), Color(hex: 0x9CCBF5)]
        }
    }

    private var glow: Color {
        switch sky {
        case 1: return Color(hex: 0xFFD08A)
        case 2: return Color(hex: 0xDCE4FF)
        default: return Color(hex: 0xFFF3C4)
        }
    }

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(glow.opacity(0.55))
                        .frame(width: 190, height: 190)
                        .blur(radius: 44)
                    Circle()
                        .fill(glow.opacity(sky == 2 ? 0.95 : 0.9))
                        .frame(width: sky == 2 ? 30 : 46, height: sky == 2 ? 30 : 46)
                        .blur(radius: sky == 2 ? 0.5 : 5)
                }
                .offset(x: 40, y: 10 - drift)
                .opacity(1 - 0.55 * Double(dim))
            }
            .overlay {
                if sky == 2 { ScrollWeatherStars().opacity(1 - 0.4 * Double(dim)).offset(y: -drift * 0.4) }
            }
            // The collapsed bar reads better on a slightly deeper sky.
            .overlay(Color.black.opacity(0.14 * Double(dim)))
    }
}

private struct ScrollWeatherStars: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<34 {
                let x = CGFloat((i * 73 + 19) % 101) / 101 * size.width
                let y = CGFloat((i * 47 + 7) % 89) / 89 * size.height * 0.75
                let r = CGFloat(i % 3) * 0.35 + 0.6
                let rect = CGRect(x: x, y: y, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.35 + Double(i % 4) * 0.15)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Cards

private struct ScrollWeatherCard<Content: View>: View {
    let icon: String
    let title: LocalizedText
    let language: AppLanguage
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(title, language)
            }
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(Color.white.opacity(0.62))
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.5))
    }
}

private struct ScrollWeatherHourly: View {
    let sky: Int
    let language: AppLanguage

    private let icons = ["sun.max.fill", "sun.max.fill", "cloud.sun.fill", "cloud.sun.fill", "cloud.fill", "moon.stars.fill"]
    private let temps = [21, 22, 24, 23, 20, 17]

    var body: some View {
        ScrollWeatherCard(icon: "clock", title: L("Hourly forecast", "每小时预报"), language: language) {
            HStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { i in
                    VStack(spacing: 7) {
                        Text(verbatim: i == 0 ? (language == .zh ? "现在" : "Now") : String(format: "%02d", (13 + i * 2) % 24))
                            .font(.caption.weight(.semibold).monospacedDigit())
                        Image(systemName: icons[i])
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 17))
                            .frame(height: 20)
                        Text(verbatim: "\(temps[i])°")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
        }
    }
}

private struct ScrollWeatherDaily: View {
    let language: AppLanguage

    private let days: [(en: String, zh: String, icon: String, low: Int, high: Int)] = [
        ("Today", "今天", "sun.max.fill", 15, 24), ("Thu", "周四", "cloud.sun.fill", 14, 22),
        ("Fri", "周五", "cloud.rain.fill", 12, 18), ("Sat", "周六", "cloud.bolt.rain.fill", 11, 17),
        ("Sun", "周日", "cloud.sun.fill", 13, 21), ("Mon", "周一", "sun.max.fill", 16, 26),
        ("Tue", "周二", "sun.max.fill", 17, 27),
    ]

    var body: some View {
        ScrollWeatherCard(icon: "calendar", title: L("7-day forecast", "7 日预报"), language: language) {
            VStack(spacing: 0) {
                ForEach(days.indices, id: \.self) { i in
                    let day = days[i]
                    HStack(spacing: 8) {
                        Text(verbatim: language == .zh ? day.zh : day.en)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 46, alignment: .leading)
                        Image(systemName: day.icon)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 15))
                            .frame(width: 26)
                        Text(verbatim: "\(day.low)°")
                            .font(.subheadline.weight(.medium).monospacedDigit())
                            .foregroundStyle(Color.white.opacity(0.6))
                            .frame(width: 30, alignment: .trailing)
                        ScrollWeatherRange(low: day.low, high: day.high)
                        Text(verbatim: "\(day.high)°")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .frame(width: 30, alignment: .trailing)
                    }
                    .foregroundStyle(.white)
                    .frame(height: 34)
                    .overlay(alignment: .top) {
                        if i > 0 { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 0.5) }
                    }
                }
            }
        }
    }
}

/// The week's temperature span as a track, with this day's low…high as a gradient segment.
private struct ScrollWeatherRange: View {
    let low: Int
    let high: Int

    var body: some View {
        let a = CGFloat(low - 10) / 18
        let b = CGFloat(high - 10) / 18
        return Capsule()
            .fill(Color.black.opacity(0.18))
            .frame(height: 4)
            .overlay {
                GeometryReader { proxy in
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.mint, Palette.amber, Palette.coral], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width)
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: max((b - a) * proxy.size.width, 6))
                                .offset(x: a * proxy.size.width)
                        }
                }
            }
    }
}

private struct ScrollWeatherTiles: View {
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 10) {
            ScrollWeatherCard(icon: "wind", title: L("Wind", "风"), language: language) {
                Text(verbatim: language == .zh ? "14 公里/时" : "14 km/h")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            ScrollWeatherCard(icon: "humidity.fill", title: L("Humidity", "湿度"), language: language) {
                Text(verbatim: "62%")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
    }
}
