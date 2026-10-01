/** gestures.jiggle-grid · 抖动编辑网格 (Gestures+JiggleGrid.swift) */
import { AnimatePresence, motion } from "motion/react";
import { BookOpen, Calendar, Camera, CloudSun, Gamepad2, Heart, Image, Mail, Map as MapIcon, MessageCircle, Music, Zap, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, spring, useAutoplay, useClock, useHaptics, usePan, white, type DemoProps, type Point } from "../../kit";
import { GMath, useGhost } from "./_sim-kit";

const COLS = 4;
const ICON = 54;
const GAP_X = 18;
const GAP_Y = 20;
const INSET = { x: 18, y: 16 };
const SIZE = { w: 306, h: 234 };
const SYMBOLS: LucideIcon[] = [MessageCircle, Camera, MapIcon, Music, Mail, Calendar, CloudSun, Image, Gamepad2, Heart, BookOpen, Zap];
const TINTS = [Palette.green, "#5B6070", Palette.sky, Palette.pink, Palette.blue, Palette.red, Palette.sky, Palette.amber, Palette.violet, Palette.pink, Palette.coral, Palette.indigo];
/** `.fill` symbols whose outline is a closed shape. */
const FILLED = new Set<LucideIcon>([MessageCircle, Heart, Zap]);
const ALL = Array.from({ length: 12 }, (_, i) => i);

const centre = (slot: number): Point => ({
  x: INSET.x + (slot % COLS) * (ICON + GAP_X) + ICON / 2,
  y: INSET.y + Math.floor(slot / COLS) * (ICON + GAP_Y) + ICON / 2,
});

/** The slot whose centre is closest to `point`, among the first `count` slots. */
function slotNear(point: Point, count: number): number {
  let best = 0;
  let bestDistance = Infinity;
  for (let slot = 0; slot < Math.max(count, 1); slot++) {
    const d = GMath.distance(centre(slot), point);
    if (d < bestDistance) {
      best = slot;
      bestDistance = d;
    }
  }
  return best;
}

type Transition = ReturnType<typeof spring>;

export default function JiggleGrid({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const [order, setOrder] = useState<number[]>(ALL);
  const [jiggling, setJiggling] = useState(false);
  const [liftedID, setLiftedID] = useState<number | null>(null);
  const [liftPoint, setLiftPoint] = useState<Point>({ x: 132, y: 112 });
  const [moveSpring, setMoveSpring] = useState<Transition>(() => spring(0.38, 0.72));
  const [modeSpring, setModeSpring] = useState<Transition>(() => spring(0.35, 0.6));
  const s = useRef({
    order: ALL,
    jiggling: false,
    liftedID: null as number | null,
    liftPoint: { x: 132, y: 112 } as Point,
    grabOffset: { x: 0, y: 0 } as Point,
    touching: false,
    touchStart: { x: 0, y: 0 } as Point,
    pendingDelete: null as number | null,
    pendingExit: false,
    pressTimer: 0,
    autoStep: 0,
    scripted: false,
  }).current;
  const time = useClock(jiggling, ctx.isPreview ? 30 : undefined);

  const buzz = (fn: () => void) => {
    if (!s.scripted) fn();
  };
  const setOrderBoth = (next: number[], t: Transition) => {
    s.order = next;
    setMoveSpring(t);
    setOrder(next);
  };
  const setLifted = (id: number | null, t: Transition) => {
    s.liftedID = id;
    setModeSpring(t);
    if (id === null) setMoveSpring(t);
    setLiftedID(id);
  };
  const setJiggle = (v: boolean, t: Transition) => {
    s.jiggling = v;
    setModeSpring(t);
    setJiggling(v);
  };

  const iconAt = (point: Point): number | null => {
    for (let slot = 0; slot < s.order.length; slot++) {
      const c = centre(slot);
      if (Math.abs(point.x - c.x) < ICON / 2 + 7 && Math.abs(point.y - c.y) < ICON / 2 + 8) return s.order[slot];
    }
    return null;
  };

  const lift = (id: number, from: Point, finger: Point) => {
    s.grabOffset = { x: finger.x - from.x, y: finger.y - from.y };
    s.liftPoint = from;
    setLiftPoint(from);
    setLifted(id, spring(0.3, 0.6));
  };

  const exitJiggle = () => {
    if (!s.jiggling) return;
    const t = spring(0.35, 0.75);
    setJiggle(false, t);
    setLifted(null, t);
    buzz(() => haptics.tap("light"));
  };

  // Touch handlers (the scripted finger calls the same three).
  const touchDown = (point: Point) => {
    s.touching = true;
    s.touchStart = point;
    s.pendingDelete = null;
    s.pendingExit = false;
    const id = iconAt(point);
    const slot = id === null ? -1 : s.order.indexOf(id);
    if (id === null || slot < 0) {
      s.pendingExit = s.jiggling;
      return;
    }
    const c = centre(slot);
    if (s.jiggling) {
      const corner = { x: c.x - ICON / 2, y: c.y - ICON / 2 };
      if (GMath.distance(point, corner) < 17) s.pendingDelete = id;
      else lift(id, c, point);
      return;
    }
    window.clearTimeout(s.pressTimer);
    s.pressTimer = window.setTimeout(() => {
      if (!s.touching) return;
      setJiggle(true, spring(0.35, 0.6));
      buzz(() => haptics.tap("medium"));
      const current = s.order.indexOf(id);
      if (current >= 0) lift(id, centre(current), s.touchStart);
    }, 400);
  };

  const touchMove = (point: Point) => {
    if (!s.touching) return;
    const id = s.liftedID;
    if (id === null) {
      if (GMath.distance(point, s.touchStart) > 10) {
        // Moved before the long press fired: not a hold, and not a tap on a badge either.
        window.clearTimeout(s.pressTimer);
        s.pendingDelete = null;
        s.pendingExit = false;
      }
      return;
    }
    const half = ICON / 2;
    s.liftPoint = { x: clamp(point.x - s.grabOffset.x, half, SIZE.w - half), y: clamp(point.y - s.grabOffset.y, half, SIZE.h - half) };
    setLiftPoint(s.liftPoint);
    const target = slotNear(s.liftPoint, s.order.length);
    const current = s.order.indexOf(id);
    if (current < 0 || current === target) return;
    const next = s.order.slice();
    next.splice(current, 1);
    next.splice(target, 0, id);
    setOrderBoth(next, spring(ctx.n("response"), 0.72));
    buzz(() => haptics.selection());
  };

  const remove = (id: number) => {
    setOrderBoth(
      s.order.filter((v) => v !== id),
      spring(ctx.n("response"), 0.78),
    );
    buzz(() => haptics.tap("rigid"));
    if (s.order.length) return;
    // Nothing left to play with: bring the set back.
    window.setTimeout(() => {
      if (s.order.length) return;
      const t = spring(0.5, 0.7);
      setOrderBoth(ALL, t);
      setJiggle(false, t);
    }, 600);
  };

  const touchUp = () => {
    if (!s.touching) return;
    s.touching = false;
    window.clearTimeout(s.pressTimer);
    if (s.liftedID !== null) {
      setLifted(null, spring(0.36, 0.7));
      buzz(() => haptics.tap("soft"));
    } else if (s.pendingDelete !== null) remove(s.pendingDelete);
    else if (s.pendingExit) exitJiggle();
    s.pendingDelete = null;
    s.pendingExit = false;
  };

  const pan = usePan({
    onChange: ({ start, location }) => {
      if (!s.touching || s.scripted) {
        if (s.scripted) {
          // A real finger takes over from the scripted one.
          ghost.touch();
          window.clearTimeout(s.pressTimer);
          s.scripted = false;
          s.touching = false;
          if (s.liftedID !== null) setLifted(null, spring(0.36, 0.7));
        }
        touchDown(start);
      }
      touchMove(location);
    },
    onEnd: () => touchUp(),
  });

  /** A scripted finger holds an icon until the grid jiggles, carries it to another slot, drops it, then leaves edit mode. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.touching || s.liftedID !== null || s.order.length <= 4) return;
      s.scripted = true;
      if (s.jiggling) {
        exitJiggle();
        return;
      }
      s.autoStep += 1;
      const moves = [
        [1, 10],
        [7, 0],
        [4, 11],
        [9, 2],
      ];
      const move = moves[s.autoStep % moves.length];
      const from = centre(Math.min(move[0], s.order.length - 1));
      const to = centre(Math.min(move[1], s.order.length - 1));
      const control = { x: (from.x + to.x) / 2 + 30, y: (from.y + to.y) / 2 - 20 };
      ghost.run(async (g) => {
        touchDown(from);
        if (!(await g.sleep(0.62))) return;
        if (!(await g.drag(from, to, 1.0, touchMove, control))) return;
        if (!(await g.sleep(0.15))) return;
        touchUp();
        if (!(await g.sleep(1.0))) return;
        if (s.touching) return;
        exitJiggle();
      });
    },
    { every: 4.0, delay: 0.6 },
  );

  const angle = ctx.n("angle");
  const speed = ctx.n("speed");

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        <AnimatePresence initial={false}>
          {order.map((id) => {
            const slot = order.indexOf(id);
            const lifted = liftedID === id;
            const phase = GMath.hash(id * 17 + 5) * 2 * Math.PI;
            // Odd and even icons rock in opposite directions, like the real thing.
            const swing = jiggling && !lifted ? Math.sin(time * 2 * Math.PI * speed + phase) * angle * (id % 2 === 0 ? 1 : -1) : 0;
            const drift = jiggling && !lifted ? Math.cos(time * 2 * Math.PI * speed * 0.5 + phase) : 0;
            const at = lifted ? liftPoint : centre(slot);
            const Icon = SYMBOLS[id % SYMBOLS.length];
            const tint = TINTS[id % TINTS.length];
            const badge = jiggling && !lifted;
            return (
              <motion.div
                key={id}
                initial={{ x: at.x, y: at.y, scale: 0.1, opacity: 0 }}
                animate={{ x: at.x, y: at.y, scale: 1, opacity: 1 }}
                exit={{ scale: 0.1, opacity: 0 }}
                transition={lifted ? { x: { duration: 0 }, y: { duration: 0 }, default: moveSpring } : moveSpring}
                style={{ position: "absolute", left: -ICON / 2, top: -ICON / 2, width: ICON, height: ICON, zIndex: lifted ? 10 : 0 }}
              >
                <div style={{ position: "absolute", inset: 0, transform: `translate(${drift}px, ${-drift * 0.6}px) rotate(${swing}deg)` }}>
                  <motion.div
                    initial={false}
                    animate={{ scale: lifted ? ctx.n("lift") : 1, boxShadow: `0 ${lifted ? 12 : 2}px ${lifted ? 16 : 4}px ${black(lifted ? 0.34 : 0.14)}` }}
                    transition={modeSpring}
                    style={{
                      position: "absolute",
                      inset: 0,
                      borderRadius: 14,
                      background: `linear-gradient(180deg, ${tint}, ${alpha(tint, 0.72)})`,
                      display: "grid",
                      placeItems: "center",
                      color: "#fff",
                    }}
                  >
                    <div style={{ position: "absolute", inset: 0, borderRadius: 14, boxShadow: `inset 0 0 0 0.7px ${white(0.28)}` }} />
                    <Icon size={25} strokeWidth={2.2} fill={FILLED.has(Icon) ? "currentColor" : "none"} />
                    <motion.div
                      initial={false}
                      animate={{ scale: badge ? 1 : 0.01, opacity: badge ? 1 : 0 }}
                      transition={modeSpring}
                      style={{ position: "absolute", left: -7, top: -7, width: 20, height: 20, borderRadius: "50%", background: "#C7C9D1", boxShadow: `inset 0 0 0 0.5px ${white(0.5)}`, display: "grid", placeItems: "center", transformOrigin: "7px 7px" }}
                    >
                      <div style={{ width: 9, height: 2.2, borderRadius: 1.1, background: "#2A2C35" }} />
                    </motion.div>
                  </motion.div>
                </div>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>

      <div style={{ position: "relative", height: 30, alignSelf: "stretch", display: "grid", placeItems: "center" }}>
        <motion.div initial={false} animate={{ opacity: jiggling ? 0 : 1 }} transition={modeSpring} style={{ position: "absolute" }}>
          <DemoHint ctx={ctx} en="Touch and hold an icon, then drag it" zh="长按一个图标，然后拖动" />
        </motion.div>
        <AnimatePresence>
          {jiggling && !ctx.isPreview && (
            <motion.button
              key="done"
              initial={{ scale: 0.6, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.6, opacity: 0 }}
              transition={modeSpring}
              onClick={() => {
                ghost.touch();
                s.scripted = false;
                exitJiggle();
              }}
              style={{ position: "absolute", padding: "6px 16px", borderRadius: 999, background: Palette.labelAlpha(0.1), fontSize: 13, lineHeight: "16px", fontWeight: 600, color: Palette.label }}
            >
              {ctx.t("Done", "完成")}
            </motion.button>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
