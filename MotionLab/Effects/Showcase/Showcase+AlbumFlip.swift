import SwiftUI

extension Effect {
    static let showcaseAlbumFlip = Effect(
        id: "showcase.album-flip",
        category: .showcase,
        interaction: .tap,
        name: L("Album Flip to Tracklist", "专辑翻面看曲目"),
        summary: L(
            "An album cover lifts and flips over to its tracklist; rows stream in and the playing one carries a live equalizer.",
            "专辑封面抬起、翻到背面的曲目表；曲目逐行滑入，正在播放的一行带着跳动的均衡器。"
        ),
        prompt: L(
            "A dark music widget: a 196 pt square album cover (a retro striped sun over ridges) above the current track name and a round flip button. Tapping the cover turns it 180° around its vertical axis on a spring (response 0.7 s, damping 0.72) with perspective 0.55; the faces swap exactly at 90°, where the sleeve is lifted to 108%, its shadow is deepest and a white sheen streaks across. The back is a tracklist: five rows slide in from 14 pt right and fade up, 45 ms apart, starting 0.22 s into the flip. The playing row sits on an orange pill with three equalizer bars dancing on layered sines; tapping another row glides the pill there (response 0.4 s, damping 0.8) with a selection haptic and rolls the track name below. Tapping the header flips back, always turning the same way. Tactile, like a record sleeve.",
            "深色音乐组件：196pt 见方的专辑封面，下方是曲目名与翻面按钮。点击封面，它绕竖轴翻转 180°（弹簧响应 0.7 秒、阻尼 0.72，透视 0.55）；正反面恰在 90° 处切换，此时唱片套抬到 108%，投影最深，一道白色高光掠过。背面是曲目表：五行曲目从右侧 14pt 处滑入并淡显，行间相隔 45 毫秒，翻转开始 0.22 秒后起播。正在播放的一行垫着橙色胶囊，带三根跳动的均衡条；点击另一行，胶囊滑过去（响应 0.4 秒、阻尼 0.8），下方曲目名随之滚动。点击表头朝同一方向翻回。有翻唱片套的手感。"
        ),
        implementation: L(
            "An Animatable container receives the accumulated angle, swaps the two faces at the 90° crossings (the back is pre-rotated 180°), and derives lift, shadow and sheen from |sin(angle)|. Rows animate on the flipped flag with per-index delays, the selection pill is a matchedGeometryEffect, and the equalizer is a TimelineView.",
            "一个 Animatable 容器接收累计角度，在越过 90° 时切换两面（背面预先旋转 180°），并由 |sin(角度)| 推导抬起量、投影与高光。曲目行根据“已翻面”标记按序号延迟播放动画，选中胶囊使用 matchedGeometryEffect，均衡器由 TimelineView 驱动。"
        ),
        apis: ["rotation3DEffect", "Animatable", "matchedGeometryEffect", "TimelineView(.animation)", "spring(response:dampingFraction:)", "transition(.push)"],
        tags: ["album", "flip", "tracklist", "music", "equalizer", "专辑", "翻转", "曲目", "音乐", "均衡器"],
        params: [
            .slider("response", L("Flip response", "翻转响应"), 0.3...1.2, default: 0.7, unit: "s"),
            .slider("damping", L("Flip damping", "翻转阻尼"), 0.5...1.0, default: 0.72),
            .slider("perspective", L("Perspective", "透视"), 0.1...1.0, default: 0.55),
            .slider("lift", L("Lift", "抬起量"), 0...0.16, default: 0.08),
        ]
    ) { ctx in
        AlbumFlipDemo(ctx: ctx)
    }
}

private enum AlbumData {
    static let tracks: [LocalizedText] = [
        L("Low Beams", "近光灯"), L("Highway Glass", "玻璃公路"), L("Neon Mile", "霓虹一英里"), L("Tunnel Light", "隧道的光"), L("Last Exit", "最后一个出口"),
    ]
    static let lengths = ["3:12", "4:05", "3:48", "2:57", "5:21"]
    static let side: CGFloat = 196
}

private struct AlbumFlipDemo: View {
    let ctx: DemoContext
    /// Half turns so far; odd means the tracklist faces us. Only ever grows, so the sleeve keeps turning one way.
    @State private var turns = 0
    @State private var track = 1
    @State private var step = 0
    @Namespace private var pill

    private var zh: Bool { ctx.language == .zh }
    private var flipped: Bool { turns % 2 != 0 }

    var body: some View {
        StudioScene(hint: L("Tap the cover, then pick a track", "点击封面翻面，再选一首曲目"), ctx: ctx) {
            card
        }
        .autoplay(ctx.isPreview, every: 1.6, delay: 0.7) { autoStep() }
    }

    private var card: some View {
        VStack(spacing: 12) {
            AlbumFlipper(
                angle: Double(turns) * 180,
                perspective: ctx.cg("perspective"),
                lift: ctx["lift"],
                front: front,
                back: back
            )
            .frame(width: AlbumData.side, height: AlbumData.side)
            footer
        }
        .padding(16)
        .frame(width: 228)
        .signatureCard()
    }

    // MARK: Faces

    private var front: some View {
        Button(action: { flip(user: true) }) {
            AlbumCover(zh: zh)
        }
        .buttonStyle(SportPressStyle(scale: 0.98, dim: 0.03))
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { flip(user: true) }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .heavy))
                    Text(verbatim: zh ? "A 面 · 5 首" : "Side A · 5 tracks")
                    Spacer(minLength: 0)
                    Text(verbatim: "19:23")
                }
                .signatureEyebrow()
                .frame(height: 22)
                .contentShape(Rectangle())
            }
            .buttonStyle(SportPressStyle(scale: 0.97, dim: 0.03))
            ForEach(AlbumData.tracks.indices, id: \.self) { index in
                row(index)
                    .opacity(flipped ? 1 : 0)
                    .offset(x: flipped ? 0 : 14)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(flipped ? 0.22 + Double(index) * 0.045 : 0), value: flipped)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: AlbumData.side, height: AlbumData.side, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2A2A30), Color(hex: 0x1A1A1E)], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func row(_ index: Int) -> some View {
        let playing = index == track
        return Button {
            guard index != track else { return }
            Haptics.selection()
            select(index)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    if playing {
                        StudioEqualizer(color: Signature.ink, height: 11, preview: ctx.isPreview)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(verbatim: "\(index + 1)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Signature.textSecondary)
                            .transition(.opacity)
                    }
                }
                .frame(width: 16)
                Text(AlbumData.tracks[index], ctx.language)
                    .font(.system(size: 13, weight: playing ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(playing ? Signature.ink : Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(verbatim: AlbumData.lengths[index])
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(playing ? Signature.ink.opacity(0.7) : Signature.textSecondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background {
                if playing {
                    Capsule()
                        .fill(Signature.accentGradient)
                        .matchedGeometryEffect(id: "playing", in: pill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(SportPressStyle(scale: 0.97, dim: 0.03))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                ZStack(alignment: .leading) {
                    Text(AlbumData.tracks[track], ctx.language)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .id(track)
                        .transition(.push(from: .bottom))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                Text(verbatim: zh ? "夜行 · 灯笼乐队" : "Night Drive · The Lanterns")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Signature.textSecondary)
                    .lineLimit(1)
            }
            Button(action: { flip(user: true) }) {
                Image(systemName: flipped ? "photo.fill" : "list.bullet")
                    .font(.system(size: 13, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.1)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(SportPressStyle(scale: 0.9, dim: 0.06))
        }
    }

    // MARK: Actions

    private func flip(user: Bool) {
        if user { Haptics.tap(.medium) }
        withAnimation(.spring(response: ctx["response"], dampingFraction: ctx["damping"])) { turns += 1 }
    }

    private func select(_ index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { track = index }
    }

    private func autoStep() {
        switch step % 3 {
        case 1: select((track + 1) % AlbumData.tracks.count)
        default: flip(user: false)
        }
        step += 1
    }
}

/// Turns its two faces around the vertical axis; lift, shadow and sheen follow the edge-on amount.
private struct AlbumFlipper<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let perspective: CGFloat
    let lift: Double
    let front: Front
    let back: Back

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let turn = (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let showsBack = turn > 90 && turn < 270
        let edge = abs(sin(angle * .pi / 180))
        ZStack {
            front
                .opacity(showsBack ? 0 : 1)
                .allowsHitTesting(!showsBack)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
                .allowsHitTesting(showsBack)
        }
        .overlay {
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.5 * edge), .clear],
                startPoint: UnitPoint(x: edge * 1.3 - 0.5, y: 0),
                endPoint: UnitPoint(x: edge * 1.3, y: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: perspective)
        .scaleEffect(1 + lift * edge)
        .shadow(color: .black.opacity(0.35 + 0.25 * edge), radius: 10 + 14 * edge, y: 7 + 12 * edge)
    }
}

/// Procedural sleeve art: a striped retro sun setting behind dark ridges.
private struct AlbumCover: View {
    let zh: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x241446), Color(hex: 0x8A2B5C), Color(hex: 0xF0703A), Color(hex: 0xFFC27A)], startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(LinearGradient(colors: [Color(hex: 0xFFE9B8), Color(hex: 0xFF9A3D), Color(hex: 0xF0456A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 104, height: 104)
                .mask {
                    VStack(spacing: 0) {
                        Rectangle().frame(height: 50)
                        ForEach(0..<5, id: \.self) { index in
                            Color.clear.frame(height: 2.5 + CGFloat(index) * 1.2)
                            Rectangle().frame(height: 8 - CGFloat(index) * 0.9)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .shadow(color: Color(hex: 0xFF9A3D).opacity(0.7), radius: 18)
                .offset(y: 14)
            RidgeShape(seed: 11, baseline: 0.78, amplitude: 0.16)
                .fill(Color(hex: 0x3A1B46))
            RidgeShape(seed: 5, baseline: 0.9, amplitude: 0.12)
                .fill(Color(hex: 0x160D22))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: zh ? "夜行" : "NIGHT DRIVE")
                    .font(.system(size: zh ? 22 : 17, weight: .black, design: .rounded))
                    .tracking(zh ? 6 : 3)
                    .foregroundStyle(Color.white)
                Text(verbatim: zh ? "灯笼乐队" : "THE LANTERNS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: AlbumData.side, height: AlbumData.side)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
    }
}
