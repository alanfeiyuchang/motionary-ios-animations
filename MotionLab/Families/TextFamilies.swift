import Foundation

/// Families (variation groups) of `EffectCategory.text`.
///
/// To add a variation: append the effect to `TextEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum TextFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "text.number",
            category: .text,
            name: L("Number Counter", "数字滚动"),
            summary: L("Digits that roll, tumble on 3D prisms, flip on split-flap boards, drop with gravity, count up or glow as LED segments.", "数字滚动、3D 棱柱翻滚、翻页牌翻动、重力坠落、逐个累加或以数码管点亮。"),
            symbol: "number"
        ),
        EffectFamily(
            id: "text.reveal",
            category: .text,
            name: L("Text Reveal", "文字揭示"),
            summary: L("Words arriving on screen: blur-in, typing, decoding, hinging, rising, popping, sweeping and tracking in.", "文字入场：模糊显现、打字、解码、翻转、升起、弹出、光扫与字距收拢。"),
            symbol: "text.append"
        ),
        EffectFamily(
            id: "text.kinetic",
            category: .text,
            name: L("Kinetic Type", "动态字形"),
            summary: L("Letters that keep moving: waves, weight shifts, orbiting rings, spring chains and squash-and-stretch hops.", "持续运动的字形：波浪、字重变化、环绕文字、弹簧链与挤压弹跳。"),
            symbol: "waveform.path"
        ),
        EffectFamily(
            id: "text.emphasis",
            category: .text,
            name: L("Light & Emphasis", "光效与强调"),
            summary: L("Shimmers, highlighter sweeps, karaoke fills, pen annotations and neon that direct the eye.", "流光、荧光笔、逐字填充、手绘圈注与霓虹，引导视线。"),
            symbol: "highlighter"
        ),
        EffectFamily(
            id: "text.ticker",
            category: .text,
            name: L("Rotating & Ticker", "轮播与跑马灯"),
            summary: L("Words that swap in a slot, roll on a drum, retype themselves or scroll by endlessly.", "在槽位中轮换、在滚筒上转动、反复重打或无尽滚动的文字。"),
            symbol: "arrow.left.arrow.right"
        ),
    ]

    static let membership: [String: String] = [
        // Number counter
        "text.numeric-counter": "text.number",
        "text.odometer": "text.number",
        "text.split-flap": "text.number",
        "text.slot-reel": "text.number",
        "text.gravity-digits": "text.number",
        "text.count-up": "text.number",
        "text.seven-segment": "text.number",
        "text.price-tick": "text.number",
        "text.countdown": "text.number",
        // Text reveal
        "text.blur-reveal": "text.reveal",
        "text.typewriter": "text.reveal",
        "text.scramble": "text.reveal",
        "text.flip-in-3d": "text.reveal",
        "text.masked-lines": "text.reveal",
        "text.elastic-letters": "text.reveal",
        "text.light-sweep": "text.reveal",
        "text.tracking-in": "text.reveal",
        "text.ai-stream": "text.reveal",
        "text.handwriting": "text.reveal",
        "text.liquid-fill": "text.reveal",
        // Kinetic type
        "text.wave": "text.kinetic",
        "text.circular-badge": "text.kinetic",
        "text.variable-weight": "text.kinetic",
        "text.spring-chain": "text.kinetic",
        "text.squash-hop": "text.kinetic",
        "text.path-flow": "text.kinetic",
        "text.magnet-letters": "text.kinetic",
        // Light & emphasis
        "text.shimmer": "text.emphasis",
        "text.highlighter": "text.emphasis",
        "text.synced-lyrics": "text.emphasis",
        "text.scribble-circle": "text.emphasis",
        "text.neon-sign": "text.emphasis",
        "text.gradient-flow": "text.emphasis",
        "text.squiggle-underline": "text.emphasis",
        "text.spotlight-mask": "text.emphasis",
        // Rotating & ticker
        "text.rotating-words": "text.ticker",
        "text.marquee": "text.ticker",
        "text.news-ticker": "text.ticker",
        "text.word-drum": "text.ticker",
        "text.type-cycle": "text.ticker",
        "text.letter-morph": "text.ticker",
    ]
}
