/** cards.scatter-gather · 散开与收拢 (Cards+ScatterGather.swift) */
import { animate, motionValue, type MotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, black, clamp, delayed, fonts, localPoint, spring, useAutoplay, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, deckItem, diag, tr, useMV } from "./shared";
import { track } from "./_kit";

const PHOTO = { w: 80, h: 96 };
const AREA = { w: 330, h: 290 };
const COUNT = 6;
const PILE = { x: 0, y: -4 };
/** Rest tilt of each photo in the pile. */
const PILE_TILT = [-4, 3, -2, 5, -3, 1.5];
const PILE_SHIFT = [
  [-2, 2], [2, 1], [-1, -1],
  [1, -2], [-2, 0], [0, 0],
];
type P = { x: number; y: number };

const clampPoint = (p: P): P => {
  const x = (AREA.w - PHOTO.w) / 2 - 14;
  const y = (AREA.h - PHOTO.h) / 2 - 10;
  return { x: clamp(p.x, -x, x), y: clamp(p.y, -y, y) };
};

const M64 = (1n << 64n) - 1n;
/** Deterministic 0…1 value. */
function noise(a: number, b: number): number {
  let x = BigInt(a * 92821 + b * 689287 + 4099) & M64;
  x ^= x >> 31n;
  x = (x * 0x7fb5d329728ea185n) & M64;
  x ^= x >> 27n;
  x = (x * 0x81dadef4bc2dd44dn) & M64;
  x ^= x >> 33n;
  return Number(x % 10000n) / 10000;
}

/** Where each photo lands: evenly around a ring, pushed away from the tap, with fresh rotations. */
function plan(round: number, tap: P, spread: number, rotation: number) {
  const start = noise(round, 1) * 2 * Math.PI;
  // Tapping one side of the pile throws the photos toward the other.
  const push = { x: clamp(-tap.x * 0.5, -24, 24), y: clamp(-tap.y * 0.5, -18, 18) };
  const points: P[] = [];
  const turns: number[] = [];
  for (let index = 0; index < COUNT; index++) {
    const angle = start + (2 * Math.PI * index) / COUNT + (noise(round * 31 + index, 2) - 0.5) * 0.4;
    const distance = spread * (96 + 18 * noise(round * 17 + index, 3));
    points.push(clampPoint({ x: PILE.x + push.x + Math.cos(angle) * distance * 1.14, y: PILE.y + push.y + Math.sin(angle) * distance * 0.9 }));
    turns.push((noise(round * 13 + index, 4) * 2 - 1) * rotation);
  }
  return { points, turns };
}

interface PhotoValues {
  t: MotionValue<number>;
  x: MotionValue<number>;
  y: MotionValue<number>;
  turn: MotionValue<number>;
}

export default function ScatterGather({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const values = useRef<PhotoValues[] | null>(null);
  if (!values.current) {
    const first = plan(0, { x: 0, y: 0 }, ctx.n("spread"), ctx.n("rotation"));
    values.current = first.points.map((p, i) => ({ t: motionValue(0), x: motionValue(p.x), y: motionValue(p.y), turn: motionValue(first.turns[i]) }));
  }
  const photos = values.current;
  const scattered = useRef(false);
  /** Stacking order, back to front. */
  const [order, setOrder] = useState(() => Array.from({ length: COUNT }, (_, i) => i));
  const [dragging, setDragging] = useState<number | null>(null);
  const draggingRef = useRef<number | null>(null);
  const dragOrigin = useRef<P>({ x: 0, y: 0 });
  const round = useRef(0);
  const [squeezes, setSqueezes] = useState(0);
  const ticks = useTimeouts();
  const area = useRef<HTMLDivElement>(null);
  const downAt = useRef<P>({ x: 0, y: 0 });
  const tableDown = useRef<P>({ x: 0, y: 0 });

  const flight = (index: number) => {
    // The top of the pile leaves first.
    const rank = COUNT - 1 - index;
    const personal = 0.85 + 0.3 * noise(index, 7);
    return delayed(spring(ctx.n("response") * personal, 0.74), rank * ctx.n("stagger"));
  };

  const toggle = (location: P, buzz: boolean) => {
    ticks.clearAll();
    if (scattered.current) {
      scattered.current = false;
      photos.forEach((p, index) => animate(p.t, 0, flight(index)));
      const stagger = Math.max(ctx.n("stagger"), 0.02);
      const landing = ctx.n("response") * 0.6;
      for (let i = 0; i < COUNT; i++) ticks.after(landing + i * stagger, () => buzz && haptics.tap("light"));
      ticks.after(landing + COUNT * stagger, () => setSqueezes((s) => s + 1));
    } else {
      round.current += 1;
      const tap = { x: location.x - AREA.w / 2 - PILE.x, y: location.y - AREA.h / 2 - PILE.y };
      const next = plan(round.current, tap, ctx.n("spread"), ctx.n("rotation"));
      photos.forEach((p, index) => {
        const t = flight(index);
        animate(p.x, next.points[index].x, t);
        animate(p.y, next.points[index].y, t);
        animate(p.turn, next.turns[index], t);
        animate(p.t, 1, t);
      });
      setOrder(Array.from({ length: COUNT }, (_, i) => i));
      scattered.current = true;
      if (buzz) haptics.tap("medium");
    }
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const spots = [{ x: 150, y: 150 }, { x: 190, y: 120 }, { x: 140, y: 170 }];
      toggle(spots[round.current % spots.length], false);
    },
    { every: 1.9 },
  );

  const dragHandlers = (index: number) => ({
    onChange: ({ translation }: { translation: P }) => {
      if (!scattered.current) return;
      const p = photos[index];
      if (draggingRef.current !== index) {
        draggingRef.current = index;
        setDragging(index);
        [p.x, p.y, p.turn].forEach((mv) => mv.stop());
        dragOrigin.current = { x: p.x.get(), y: p.y.get() };
        setOrder((o) => [...o.filter((i) => i !== index), index]);
      }
      if (Math.hypot(translation.x, translation.y) <= 3) return;
      p.x.set(dragOrigin.current.x + translation.x);
      p.y.set(dragOrigin.current.y + translation.y);
    },
    onEnd: ({ translation, velocity }: { translation: P; velocity: P }) => {
      const moved = Math.hypot(translation.x, translation.y);
      const wasDragging = draggingRef.current === index;
      draggingRef.current = null;
      setDragging(null);
      if (moved < 8 || !wasDragging) {
        // A tap on a photo counts like a tap on the table.
        toggle(downAt.current, true);
        return;
      }
      const p = photos[index];
      p.x.jump(p.x.get());
      p.y.jump(p.y.get());
      const landing = clampPoint({ x: dragOrigin.current.x + translation.x + velocity.x * 0.25, y: dragOrigin.current.y + translation.y + velocity.y * 0.25 });
      const t = spring(0.45, 0.8);
      animate(p.x, landing.x, t);
      animate(p.y, landing.y, t);
      animate(p.turn, p.turn.get() + (velocity.x * 0.25) / 14, t);
    },
  });

  const e = useElapsed(squeezes, 0.6, true);
  const squeeze = e < 0 ? 1 : track(e, 1, [{ cubic: 0.96, d: 0.09 }, { spring: 1, d: 0.4, response: 0.28, damping: 0.5 }]);

  return (
    <Stage>
      <div
        ref={area}
        onPointerDown={(ev) => {
          if (ev.target === ev.currentTarget) tableDown.current = { x: ev.clientX, y: ev.clientY };
        }}
        onClick={(ev) => {
          // A tap on the table, not the end of a drag across it.
          if (ev.target !== ev.currentTarget || Math.hypot(ev.clientX - tableDown.current.x, ev.clientY - tableDown.current.y) > 10) return;
          toggle(localPoint(ev, ev.currentTarget), true);
        }}
        style={{ position: "relative", width: AREA.w, height: AREA.h, flexShrink: 0, transform: `scale(${squeeze})` }}
      >
        {photos.map((p, index) => (
          <Photo
            key={index}
            index={index}
            values={p}
            z={order.indexOf(index) + (dragging === index ? 10 : 0)}
            handlers={dragHandlers(index)}
            onDown={(ev) => {
              if (area.current) downAt.current = localPoint(ev, area.current);
            }}
            ctx={ctx}
          />
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to scatter or gather, drag a photo" zh="点击散开或收拢，可拖动照片" />
    </Stage>
  );
}

/** One photo. `t` is its flight from the pile (0) to its place on the table (1). */
function Photo({ index, values, z, handlers, onDown, ctx }: { index: number; values: PhotoValues; z: number; handlers: Parameters<typeof usePan>[0]; onDown: (e: React.PointerEvent<HTMLElement>) => void; ctx: DemoContext }) {
  const pan = usePan(handlers);
  const t = useMV(values.t);
  const target = { x: useMV(values.x), y: useMV(values.y) };
  const turn = useMV(values.turn);
  const shift = PILE_SHIFT[index % COUNT];
  const home = { x: PILE.x + shift[0], y: PILE.y + shift[1] };
  const x = home.x + (target.x - home.x) * t;
  const y = home.y + (target.y - home.y) * t;
  const air = Math.sin(Math.PI * clamp(t));
  const side = index % 2 === 0 ? 1 : -1;
  const pileTilt = PILE_TILT[index % COUNT];
  const angle = pileTilt + (turn - pileTilt) * t + side * 16 * air;
  const scale = 1 + 0.1 * air;
  const item = deckItem(index);
  return (
    <div
      {...pan}
      onPointerDown={(ev) => {
        onDown(ev);
        pan.onPointerDown(ev);
      }}
      style={{
        position: "absolute",
        left: AREA.w / 2 - PHOTO.w / 2,
        top: AREA.h / 2 - PHOTO.h / 2,
        width: PHOTO.w,
        height: PHOTO.h,
        zIndex: z,
        transform: `translate(${x}px, ${y}px) rotate(${angle}deg) scale(${scale})`,
        borderRadius: 6,
        background: "linear-gradient(#FFFFFF, #F0EEE9)",
        boxShadow: `0 ${(2 + 7 * air) / scale}px ${(4 + 9 * air) / scale}px ${black(0.16 + 0.1 * air)}, inset 0 0 0 0.6px ${black(0.08)}`,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        touchAction: "none",
        cursor: "grab",
      }}
    >
      <div style={{ position: "relative", width: PHOTO.w - 12, height: 66, marginTop: 6, borderRadius: 3, overflow: "hidden", background: diag(item.colors), flexShrink: 0, display: "grid", placeItems: "center", color: white(0.95) }}>
        <div style={{ position: "absolute", left: 34 - 30 + 22, top: 33 - 30 - 22, width: 60, height: 60, borderRadius: 30, background: white(0.22) }} />
        <item.Icon size={27} fill={item.filled ? "currentColor" : "none"} strokeWidth={item.filled ? 0.6 : 1.5} style={{ position: "relative" }} />
      </div>
      <div style={{ flex: 1, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 10, lineHeight: "12px", fontWeight: 600, color: "#4A4A52", whiteSpace: "nowrap" }}>{tr(ctx, item.title)}</div>
    </div>
  );
}
