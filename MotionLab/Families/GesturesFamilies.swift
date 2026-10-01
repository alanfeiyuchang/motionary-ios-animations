import Foundation

/// Families (variation groups) of `EffectCategory.gestures`.
///
/// To add a variation: append the effect to `GestureEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum GesturesFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "gestures.drag-spring",
            category: .gestures,
            name: L("Drag & Spring", "拖拽与弹簧"),
            summary: L("Objects that resist, stretch, trail and snap back while dragged.", "拖动时产生阻力、拉伸、拖尾并回弹的物体。"),
            symbol: "hand.draw.fill"
        ),
        EffectFamily(
            id: "gestures.throw",
            category: .gestures,
            name: L("Throw & Snap", "抛掷与吸附"),
            summary: L("Flick with velocity: glide, arc under gravity, snap to corners or detents, or dismiss.", "带速度甩出：滑行、受重力划出抛物线、吸附角落或档位，或直接关闭。"),
            symbol: "arrow.up.forward.circle.fill"
        ),
        EffectFamily(
            id: "gestures.physics",
            category: .gestures,
            name: L("Physics Toys", "物理模拟"),
            summary: L("Simulated ropes, pendulums, springs, orbits and charge-ups you can play with.", "可以把玩的绳索、摆球、弹簧、轨道与蓄力模拟。"),
            symbol: "atom"
        ),
        EffectFamily(
            id: "gestures.list",
            category: .gestures,
            name: L("List Gestures", "列表手势"),
            summary: L("Swipe actions, swipe-to-complete, drag-select and reorder on list rows.", "列表行上的滑动操作、滑动完成、滑动多选与拖拽排序。"),
            symbol: "arrow.up.arrow.down"
        ),
        EffectFamily(
            id: "gestures.pinch",
            category: .gestures,
            name: L("Pinch, Zoom & Loupe", "捏合缩放与放大镜"),
            summary: L("Two-finger zoom, rotate and magnify with soft limits.", "带柔性边界的双指缩放、旋转与放大。"),
            symbol: "plus.magnifyingglass"
        ),
        EffectFamily(
            id: "gestures.slide-confirm",
            category: .gestures,
            name: L("Slide to Confirm", "滑动确认"),
            summary: L("Tracks, arcs and cords that must be pulled all the way to commit.", "必须完整拖到底才会执行的滑轨、弧线与拉绳。"),
            symbol: "chevron.right.2"
        ),
    ]

    static let membership: [String: String] = [
        // Drag & spring
        "gestures.rubber-band": "gestures.drag-spring",
        "gestures.jelly-stretch": "gestures.drag-spring",
        "gestures.spring-chain": "gestures.drag-spring",
        "gestures.gooey-blobs": "gestures.drag-spring",
        "gestures.magnetic-snap": "gestures.drag-spring",
        "gestures.elastic-tether": "gestures.drag-spring",
        "gestures.pendulum-swing": "gestures.drag-spring",
        "gestures.joystick": "gestures.drag-spring",
        "gestures.sticky-goo": "gestures.drag-spring",
        "gestures.mesh-warp": "gestures.drag-spring",
        "gestures.balloon-tether": "gestures.drag-spring",
        "gestures.slinky": "gestures.drag-spring",
        // Throw & snap
        "gestures.fling-inertia": "gestures.throw",
        "gestures.pip-snap": "gestures.throw",
        "gestures.drag-dismiss": "gestures.throw",
        "gestures.gravity-toss": "gestures.throw",
        "gestures.detent-sheet": "gestures.throw",
        "gestures.paper-toss": "gestures.throw",
        "gestures.spin-wheel": "gestures.throw",
        "gestures.curling-target": "gestures.throw",
        "gestures.air-hockey": "gestures.throw",
        // Physics toys
        "gestures.charge-burst": "gestures.physics",
        "gestures.verlet-rope": "gestures.physics",
        "gestures.newtons-cradle": "gestures.physics",
        "gestures.coil-spring": "gestures.physics",
        "gestures.orbit-slingshot": "gestures.physics",
        "gestures.ball-pit": "gestures.physics",
        "gestures.soft-body": "gestures.physics",
        "gestures.cloth-grid": "gestures.physics",
        "gestures.double-pendulum": "gestures.physics",
        "gestures.sand-fall": "gestures.physics",
        "gestures.bubble-wrap": "gestures.physics",
        "gestures.wave-string": "gestures.physics",
        // List gestures
        "gestures.swipe-actions": "gestures.list",
        "gestures.drag-reorder": "gestures.list",
        "gestures.swipe-complete": "gestures.list",
        "gestures.staged-swipe": "gestures.list",
        "gestures.drag-select": "gestures.list",
        "gestures.pull-to-create": "gestures.list",
        "gestures.kanban-drag": "gestures.list",
        "gestures.swipe-reply": "gestures.list",
        "gestures.jiggle-grid": "gestures.list",
        // Pinch, zoom & loupe
        "gestures.pinch-rotate": "gestures.pinch",
        "gestures.magnifier-loupe": "gestures.pinch",
        "gestures.photo-viewer": "gestures.pinch",
        "gestures.pinch-grid": "gestures.pinch",
        "gestures.pinch-open": "gestures.pinch",
        "gestures.zoom-timeline": "gestures.pinch",
        "gestures.rotate-knob": "gestures.pinch",
        "gestures.squeeze-crumple": "gestures.pinch",
        // Slide to confirm
        "gestures.slide-to-confirm": "gestures.slide-confirm",
        "gestures.stretch-slide": "gestures.slide-confirm",
        "gestures.notch-slide": "gestures.slide-confirm",
        "gestures.arc-slide": "gestures.slide-confirm",
        "gestures.pull-cord": "gestures.slide-confirm",
        "gestures.swipe-up-unlock": "gestures.slide-confirm",
        "gestures.answer-call": "gestures.slide-confirm",
    ]
}
