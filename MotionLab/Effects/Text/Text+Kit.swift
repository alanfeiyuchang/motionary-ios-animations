import SwiftUI

// Small helpers shared by the text demos (rolling glyph slots, a wrapping word layout, a stepped spring).

// MARK: - Rolling glyph

/// One glyph in a clipped slot. When `glyph` changes the old one rolls out and the new one rolls in:
/// `direction` +1 sends them upward (value rising), -1 downward. An optional `flash` colour tints the
/// arriving glyph and fades back to `color`.
struct TextFXRollGlyph: View {
    let glyph: String
    let direction: Int
    let font: Font
    let slot: CGSize
    var color: Color = .primary
    var flash: Color? = nil
    var flashHold: Double = 0.7
    var response: Double = 0.42
    var damping: Double = 0.78
    var delay: Double = 0
    var blur: CGFloat = 4

    @State private var shown: String
    @State private var leaving = ""
    @State private var turns = 0
    @State private var rollDirection = 1
    @State private var flashing = false
    @State private var flashTask: Task<Void, Never>?

    init(
        glyph: String,
        direction: Int,
        font: Font,
        slot: CGSize,
        color: Color = .primary,
        flash: Color? = nil,
        flashHold: Double = 0.7,
        response: Double = 0.42,
        damping: Double = 0.78,
        delay: Double = 0,
        blur: CGFloat = 4
    ) {
        self.glyph = glyph
        self.direction = direction
        self.font = font
        self.slot = slot
        self.color = color
        self.flash = flash
        self.flashHold = flashHold
        self.response = response
        self.damping = damping
        self.delay = delay
        self.blur = blur
        _shown = State(initialValue: glyph)
    }

    var body: some View {
        TextFXRollFaces(
            turn: CGFloat(turns),
            target: turns,
            shown: shown,
            leaving: leaving,
            direction: rollDirection,
            font: font,
            slot: slot,
            color: color,
            shownColor: flashing ? (flash ?? color) : color,
            blur: blur
        )
        .onChange(of: glyph) { _, new in roll(to: new) }
        .onDisappear { flashTask?.cancel() }
    }

    private func roll(to new: String) {
        leaving = shown
        shown = new
        rollDirection = direction >= 0 ? 1 : -1
        withAnimation(.spring(response: response, dampingFraction: damping).delay(delay)) {
            turns += 1
        }
        guard flash != nil else { return }
        flashing = true
        flashTask?.cancel()
        let wait: Double = delay + response * 0.6
        let fade: Double = flashHold
        flashTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: fade)) { flashing = false }
        }
    }
}

/// The two faces of a roll. `turn` animates toward `target`; the last unit of that travel is the roll.
private struct TextFXRollFaces: View, Animatable {
    var turn: CGFloat
    let target: Int
    let shown: String
    let leaving: String
    let direction: Int
    let font: Font
    let slot: CGSize
    let color: Color
    let shownColor: Color
    let blur: CGFloat

    var animatableData: CGFloat {
        get { turn }
        set { turn = newValue }
    }

    var body: some View {
        // 0 = the old glyph rests in the slot, 1 = the new one does (a spring may overshoot past 1).
        let p: CGFloat = target == 0 ? 1 : turn - CGFloat(target - 1)
        let dir = CGFloat(direction)
        let out: CGFloat = min(max(p, 0), 1)
        ZStack {
            if out < 1 {
                Text(verbatim: leaving)
                    .font(font)
                    .foregroundStyle(color)
                    .scaleEffect(1 - 0.25 * out)
                    .blur(radius: blur * out)
                    .opacity(Double(1 - out))
                    .offset(y: -dir * slot.height * 0.9 * p)
            }
            Text(verbatim: shown)
                .font(font)
                .foregroundStyle(shownColor)
                .blur(radius: blur * (1 - out))
                .opacity(Double(min(max(p * 1.6, 0), 1)))
                .offset(y: dir * slot.height * 0.9 * (1 - p))
        }
        .frame(width: slot.width, height: slot.height)
        .clipped()
    }
}

// MARK: - Flow layout

/// Wraps its subviews like words in a paragraph. With `markerAfter` set, the LAST subview is not part of
/// the flow: it is placed right after the subview at that index (a caret that follows the text).
struct TextFXFlow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    var centered = false
    var markerAfter: Int? = nil

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(_ sizes: [CGSize], maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for (index, size) in sizes.enumerated() {
            var row = rows[rows.count - 1]
            let extra: CGFloat = row.indices.isEmpty ? 0 : spacing
            if !row.indices.isEmpty && row.width + extra + size.width > maxWidth + 0.5 {
                rows.append(Row())
                row = Row()
            }
            let gap: CGFloat = row.indices.isEmpty ? 0 : spacing
            row.indices.append(index)
            row.width += gap + size.width
            row.height = max(row.height, size.height)
            rows[rows.count - 1] = row
        }
        return rows
    }

    private func flowSizes(_ subviews: Subviews) -> [CGSize] {
        let count = markerAfter == nil ? subviews.count : max(subviews.count - 1, 0)
        return (0..<count).map { subviews[$0].sizeThatFits(.unspecified) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth: CGFloat = proposal.width ?? .greatestFiniteMagnitude
        let rows = rows(flowSizes(subviews), maxWidth: maxWidth)
        let width: CGFloat = rows.map(\.width).max() ?? 0
        let height: CGFloat = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, max(width, 0)) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = flowSizes(subviews)
        let rows = rows(sizes, maxWidth: bounds.width)
        var y: CGFloat = bounds.minY
        var marker = CGPoint(x: bounds.minX, y: bounds.minY + (rows.first?.height ?? 0) / 2)
        for row in rows {
            var x: CGFloat = bounds.minX + (centered ? (bounds.width - row.width) / 2 : 0)
            for index in row.indices {
                let size = sizes[index]
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                if let markerAfter, index == markerAfter {
                    marker = CGPoint(x: x + size.width, y: y + row.height / 2)
                }
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
        if markerAfter != nil, let last = subviews.last {
            last.place(at: marker, anchor: .leading, proposal: .unspecified)
        }
    }
}

// MARK: - Stepped spring

/// A damped spring advanced by hand, for values drawn inside `TimelineView`/`Canvas` (where SwiftUI
/// animations do not interpolate).
struct TextFXSpring {
    var value: Double = 0
    var velocity: Double = 0

    mutating func step(to target: Double, dt: Double, response: Double, damping: Double) {
        let clamped: Double = min(max(dt, 0), 1.0 / 20.0)
        guard clamped > 0 else { return }
        let omega: Double = 2 * Double.pi / max(response, 0.05)
        let stiffness: Double = omega * omega
        let friction: Double = 2 * damping * omega
        let steps = 4
        let h: Double = clamped / Double(steps)
        for _ in 0..<steps {
            let force: Double = -stiffness * (value - target) - friction * velocity
            velocity += force * h
            value += velocity * h
        }
    }
}

/// Mutable storage for simulation state kept in `@State` and advanced from a timeline.
final class TextFXBox<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}

enum TextFXCurve {
    static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }
    static func smoothstep(_ x: Double) -> Double {
        let u: Double = clamp01(x)
        return u * u * (3 - 2 * u)
    }
    static func easeOutCubic(_ x: Double) -> Double {
        let u: Double = 1 - clamp01(x)
        return 1 - u * u * u
    }
    static func easeInOut(_ x: Double) -> Double {
        let u: Double = clamp01(x)
        return u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
    }
}
