import SwiftUI

/// Frame-delta clock for the stepped physics demos: clamps long gaps (a paused timeline, a dropped
/// frame) so a simulation never jumps when it wakes up.
struct GestureStepClock {
    private var last: Date?

    mutating func delta(to date: Date, limit: Double = 1.0 / 30.0) -> Double {
        let raw: Double = last.map { date.timeIntervalSince($0) } ?? 0
        last = date
        return min(max(raw, 0), limit)
    }

    mutating func reset() {
        last = nil
    }
}

/// Small math helpers shared by the gesture demos.
enum GestureMath {
    static func smoothstep(_ x: Double) -> Double {
        let u: Double = min(max(x, 0), 1)
        return u * u * (3 - 2 * u)
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 != edge0 else { return x < edge0 ? 0 : 1 }
        return smoothstep((x - edge0) / (edge1 - edge0))
    }

    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx: CGFloat = a.x - b.x
        let dy: CGFloat = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }

    static func length(_ v: CGVector) -> CGFloat {
        (v.dx * v.dx + v.dy * v.dy).squareRoot()
    }

    /// A stable pseudo-random number in 0…1 for an integer seed.
    static func hash(_ seed: Int) -> Double {
        let x: Double = sin(Double(seed) * 12.9898 + 4.1414) * 43758.5453
        return x - floor(x)
    }
}

/// A scripted finger for previews and the detail intro: walks from `from` to `to` (optionally bowed
/// through `control`) with an ease-in-out, calling `onMove` about 60 times a second, so a demo can
/// feed it to the very handlers its DragGesture calls.
@MainActor
enum GhostFinger {
    /// Returns `false` when the task was cancelled mid-way (a real finger took over).
    static func drag(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint? = nil,
        duration: Double,
        onMove: @MainActor (CGPoint) -> Void
    ) async -> Bool {
        let frames: Int = max(Int(duration * 60), 2)
        for frame in 0...frames {
            if Task.isCancelled { return false }
            let t: CGFloat = CGFloat(GestureMath.smoothstep(Double(frame) / Double(frames)))
            let point: CGPoint
            if let control {
                let a: CGPoint = GestureMath.lerp(from, control, t)
                let b: CGPoint = GestureMath.lerp(control, to, t)
                point = GestureMath.lerp(a, b, t)
            } else {
                point = GestureMath.lerp(from, to, t)
            }
            onMove(point)
            try? await Task.sleep(for: .milliseconds(16))
        }
        return !Task.isCancelled
    }
}

/// Runs a stepped simulation inside a `TimelineView` that sleeps once `isSettled()` holds, and wakes
/// whenever `wake` changes (bump it from gestures, autoplay and parameter changes).
struct GestureSimulation<Content: View>: View {
    let isPreview: Bool
    let wake: Int
    let isSettled: () -> Bool
    @ViewBuilder let content: (Date) -> Content

    @State private var awake = true
    @State private var watcher: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: MotionFrameRate.interval(preview: isPreview), paused: !awake)) { timeline in
            content(timeline.date)
        }
        .onAppear { start() }
        .onChange(of: wake) { start() }
        .onDisappear { watcher?.cancel() }
    }

    private func start() {
        if !awake { awake = true }
        watcher?.cancel()
        watcher = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.4))
                if isSettled() {
                    awake = false
                    return
                }
            }
        }
    }
}
