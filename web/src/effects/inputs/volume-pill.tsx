/** inputs.volume-pill (Inputs+VolumePill.swift) */
import { animate, motion, useMotionValue, useMotionValueEvent, useTransform, type MotionValue } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, anim, black, clamp, fonts, mix, rubberBand, spring, useAutoplay, useHaptics, useLatest, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { column, spacer } from "./_c-common";

const SIZE = { w: 80, h: 196 };
type Kind = "brightness" | "volume";

/** Autoplay script, one entry per tick (null = rest). */
const SCRIPT: Record<Kind, (number | null)[]> = {
  brightness: [null, 0.9, null, null, -1, 0.72],
  volume: [2, null, null, 0.3, null, null],
};

export default function VolumePill({ ctx }: DemoProps) {
  const brightness = useMotionValue(0.72);
  const volume = useMotionValue(0.46);
  const [tick, setTick] = useState(0);
  const dim = useTransform(brightness, (b) => (1 - clamp(b)) * 0.5);

  useAutoplay(
    ctx.isPreview,
    () => setTick((t) => t + 1),
    { every: 1.0, delay: 0.4 },
  );

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", width: 276, height: 280, flexShrink: 0 }}>
        {/* wallpaper */}
        <div style={{ position: "absolute", inset: 0, borderRadius: 38, boxShadow: `0 10px 27px ${black(0.2)}` }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: 38, overflow: "hidden", background: "linear-gradient(135deg, #3B2A8C, #B0407F, #F39A4A)" }}>
            <div style={{ position: "absolute", left: 138 - 90 - 100, top: 140 + 90 - 100, width: 200, height: 200, borderRadius: "50%", background: "#39D0D8", filter: "blur(60px)" }} />
            <div style={{ position: "absolute", left: 138 + 100 - 80, top: 140 - 90 - 80, width: 160, height: 160, borderRadius: "50%", background: "#FF5FA2", filter: "blur(55px)" }} />
            <motion.div style={{ position: "absolute", inset: 0, background: "#000", opacity: dim }} />
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: 38, border: `1px solid ${white(0.14)}` }} />
        </div>
        <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 24, transform: "translateY(10px)" }}>
          <Pill kind="brightness" level={brightness} tick={tick} ctx={ctx} />
          <Pill kind="volume" level={volume} tick={tick} ctx={ctx} />
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Drag a pill past its top or bottom" zh="把药丸拖过顶端或底端" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function symbolFor(kind: Kind, level: number): string {
  if (kind === "brightness") {
    if (level <= 0.001) return "sun.min";
    return level < 0.5 ? "sun.min.fill" : "sun.max.fill";
  }
  if (level <= 0.001) return "speaker.slash.fill";
  if (level < 0.34) return "speaker.wave.1.fill";
  return level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill";
}

function Pill({ kind, level, tick, ctx }: { kind: Kind; level: MotionValue<number>; tick: number; ctx: DemoContext }) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const params = useLatest({ press: ctx.n("press") });
  /** Positive = pulled past the top, negative = past the bottom (the release spring overshoots through 0). */
  const stretch = useMotionValue(0);
  const pressing = useMotionValue(0);
  const isPressing = useRef(false);
  const touching = useRef(false);
  const startLevel = useRef(0);
  const atEdge = useRef(false);
  /** Which end is being pulled. Stored so the wobbling release keeps its anchor. */
  const [pullingUp, setPullingUp] = useState(true);
  const pullingUpRef = useRef(true);
  const [shown, setShown] = useState(level.get());
  useMotionValueEvent(level, "change", (v) => setShown(clamp(v)));

  const setPulling = (up: boolean) => {
    pullingUpRef.current = up;
    setPullingUp(up);
  };

  const amount = useTransform(() => (pullingUpRef.current ? stretch.get() : -stretch.get()));
  const scaleX = useTransform(amount, (a) => 1 - (a / SIZE.w) * 0.28);
  const scaleY = useTransform(amount, (a) => 1 + a / SIZE.h);
  const pressScale = useTransform(pressing, (p) => 1 + (params.current.press - 1) * p);
  const shadow = useTransform(pressing, (p) => {
    const c = clamp(p);
    return `0 ${mix(6, 12, c)}px ${mix(15, 27, c)}px ${black(mix(0.2, 0.35, c))}`;
  });
  const fillHeight = useTransform(level, (l) => SIZE.h * clamp(l));
  const readoutOpacity = useTransform(pressing, (p) => clamp(p));
  const readoutY = useTransform(() => mix(-22, -34 - Math.max(pullingUpRef.current ? stretch.get() : 0, 0), pressing.get()));

  /** Finger and autoplay both land here: clamp the value, send the overflow into the rubber band. */
  const apply = (raw: number) => {
    const limit = ctx.n("limit");
    animate(level, clamp(raw), spring(0.12, 0.9));
    stretch.stop();
    if (raw > 1) {
      setPulling(true);
      stretch.set(rubberBand((raw - 1) * SIZE.h, limit));
    } else if (raw < 0) {
      setPulling(false);
      stretch.set(rubberBand(raw * SIZE.h, limit));
    } else stretch.set(0);
    const edge = raw >= 1 || raw <= 0;
    if (edge && !atEdge.current) haptics.tap("medium");
    atEdge.current = edge;
  };

  /** Single cleanup for a lifted or cancelled finger and for autoplay. */
  const release = () => {
    if (!isPressing.current && stretch.get() === 0) return;
    atEdge.current = false;
    isPressing.current = false;
    const t = spring(0.35, ctx.n("damping"));
    animate(stretch, 0, t);
    animate(pressing, 0, t);
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
      if (!isPressing.current) {
        startLevel.current = level.get();
        isPressing.current = true;
        animate(pressing, 1, spring(0.3, 0.7));
      }
    },
    onChange: ({ translation }) => apply(startLevel.current - translation.y / SIZE.h),
    onEnd: () => {
      touching.current = false;
      release();
    },
  });

  // Autoplay
  useEffect(() => {
    if (tick === 0 || touching.current) return;
    const script = SCRIPT[kind];
    const target = script[(tick - 1 + script.length) % script.length];
    if (target === null) return;
    isPressing.current = true;
    animate(pressing, 1, spring(0.3, 0.7));
    const overflow = target > 1 || target < 0;
    animate(level, clamp(target), anim.smoothD(overflow ? 0.3 : 0.5));
    if (overflow) {
      after(0.26, () => {
        setPulling(target > 1);
        const pull = ctx.n("limit") * 0.85;
        animate(stretch, target > 1 ? pull : -pull, anim.easeOut(0.2));
        after(0.3, release);
      });
    } else after(0.6, release);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick]);

  const symbol = symbolFor(kind, shown);
  const dark = shown > 0.17;

  return (
    <div {...pan} style={{ ...pan.style, position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0, cursor: "grab" }}>
      <motion.div style={{ position: "absolute", inset: 0, scale: pressScale }}>
        <motion.div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 30,
            overflow: "hidden",
            scaleX,
            scaleY,
            originY: pullingUp ? 1 : 0,
            boxShadow: shadow,
            background: `linear-gradient(${white(0.1)}, ${white(0.1)}), ${black(0.34)}`,
          }}
        >
          <motion.div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: fillHeight, background: white(0.94) }} />
          <div
            style={{
              position: "absolute",
              left: 0,
              right: 0,
              bottom: 20,
              height: 30,
              display: "grid",
              placeItems: "center",
              color: dark ? "#2B2B30" : "#fff",
              transition: "color 0.2s ease-out",
            }}
          >
            <SymbolSwap k={symbol}>
              <Glyph name={symbol} />
            </SymbolSwap>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: 30, border: `1px solid ${white(0.22)}` }} />
        </motion.div>
      </motion.div>
      {/* readout */}
      <motion.div style={{ position: "absolute", left: -20, right: -20, top: 0, display: "flex", justifyContent: "center", opacity: readoutOpacity, y: readoutY, pointerEvents: "none" }}>
        <span style={{ fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, lineHeight: "18px", color: "#fff", display: "inline-flex" }}>
          <NumericText value={Math.round(shown * 100)} />%
        </span>
      </motion.div>
    </div>
  );
}

/** The SF Symbols this demo steps through, hand-drawn at 24 pt semibold. */
function Glyph({ name }: { name: string }) {
  if (name.startsWith("sun")) {
    const max = name === "sun.max.fill";
    const filled = name !== "sun.min";
    const r = max ? 5.6 : 5;
    return (
      <svg width={30} height={30} viewBox="-15 -15 30 30" style={{ overflow: "visible" }}>
        <circle r={filled ? r : r - 1.1} fill={filled ? "currentColor" : "none"} stroke="currentColor" strokeWidth={filled ? 0 : 2.2} />
        {Array.from({ length: 8 }, (_, i) => {
          const a = (i * Math.PI) / 4;
          const r0 = max ? 9.2 : 9.6;
          const r1 = max ? 12.6 : 10.2;
          return (
            <line key={i} x1={Math.cos(a) * r0} y1={Math.sin(a) * r0} x2={Math.cos(a) * r1} y2={Math.sin(a) * r1} stroke="currentColor" strokeWidth={max ? 2.4 : 2.6} strokeLinecap="round" />
          );
        })}
      </svg>
    );
  }
  const waves = name === "speaker.wave.1.fill" ? 1 : name === "speaker.wave.2.fill" ? 2 : name === "speaker.wave.3.fill" ? 3 : 0;
  const slash = name === "speaker.slash.fill";
  const shift = slash ? 4 : (3 - waves) * 2.4;
  return (
    <svg width={34} height={26} viewBox="0 0 34 26" style={{ overflow: "visible" }}>
      <g transform={`translate(${shift} 3)`} fill="none" stroke="currentColor" strokeLinecap="round" strokeWidth={2.3}>
        <path d="M1.5 6.6h3.6L10.4 2.2c.8-.7 2.1-.1 2.1 1v13.6c0 1.1-1.3 1.7-2.1 1l-5.3-4.4H1.5A1.5 1.5 0 0 1 0 11.9V8.1a1.5 1.5 0 0 1 1.5-1.5Z" fill="currentColor" stroke="none" />
        {waves >= 1 && <path d="M16.2 6.4a5 5 0 0 1 0 7.2" />}
        {waves >= 2 && <path d="M19.9 3.4a9.2 9.2 0 0 1 0 13.2" />}
        {waves >= 3 && <path d="M23.6 0.4a13.4 13.4 0 0 1 0 19.2" />}
        {slash && <path d="M-0.5 0.5L19 19.5" strokeWidth={2.6} />}
      </g>
    </svg>
  );
}
