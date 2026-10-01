/** navigation.dock-magnify · 程序坞放大 (Navigation+DockMagnify.swift) */
import { motion } from "motion/react";
import { CalendarDays } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, glass, localPoint, spring, useAutoplay, useClock, useHaptics, useTimeouts, type DemoContext, type DemoProps } from "../../kit";
import { SafariFill } from "./groupA-kit";
import { NoteText, PhotoFill, useNavPan } from "./_r2";
import { GearFill, MessageFill, MusicNote, menuGlass } from "./_stubs-kit";

type L = [string, string];
const APPS: { icon: (size: number) => ReactNode; colors: [string, string]; name: L }[] = [
  { icon: (s) => <MessageFill size={s} />, colors: [Palette.green, Palette.mint], name: ["Messages", "信息"] },
  { icon: (s) => <SafariFill size={s} />, colors: [Palette.sky, Palette.blue], name: ["Safari", "Safari"] },
  { icon: (s) => <MusicNote size={s} />, colors: [Palette.pink, Palette.red], name: ["Music", "音乐"] },
  { icon: (s) => <PhotoFill size={s} />, colors: [Palette.amber, Palette.coral], name: ["Photos", "照片"] },
  { icon: (s) => <CalendarDays size={s} strokeWidth={2.3} />, colors: [Palette.red, Palette.coral], name: ["Calendar", "日历"] },
  { icon: (s) => <NoteText size={s} />, colors: [Palette.amber, "#FFD66B"], name: ["Notes", "备忘录"] },
  { icon: (s) => <GearFill size={s} />, colors: ["#8E8E93", "#5A5A60"], name: ["Settings", "设置"] },
];
const COUNT = APPS.length;
const CANVAS = { w: 330, h: 170 };
const BASE = 32;
const SPACING = 8;
const SWEEP = 1.2;
const now = () => performance.now() / 1000;

const restCenter = (index: number) => (CANVAS.w - (COUNT * BASE + (COUNT - 1) * SPACING)) / 2 + index * (BASE + SPACING) + BASE / 2;
function nearestIndex(x: number) {
  let best = 0;
  let bestDistance = Infinity;
  for (let i = 0; i < COUNT; i++) {
    const d = Math.abs(restCenter(i) - x);
    if (d < bestDistance) {
      bestDistance = d;
      best = i;
    }
  }
  return best;
}
/** Icon sizes for a finger at `x` (cosine falloff), kept inside the canvas by scaling the extra growth down. */
function sizesFor(x: number | null, maxScale: number, range: number): number[] {
  const raw = APPS.map((_, index) => {
    if (x === null) return BASE;
    const d = Math.abs(restCenter(index) - x);
    if (d >= range) return BASE;
    const falloff = (Math.cos((d / range) * Math.PI) + 1) / 2;
    return BASE * (1 + (maxScale - 1) * falloff);
  });
  const available = CANVAS.w - 28 - (COUNT - 1) * SPACING;
  const restTotal = COUNT * BASE;
  const extra = raw.reduce((a, b) => a + b, 0) - restTotal;
  if (!(extra > 0 && restTotal + extra > available)) return raw;
  const factor = Math.max(available - restTotal, 0) / extra;
  return raw.map((s) => BASE + (s - BASE) * factor);
}

const TRACK = { k: (2 * Math.PI / 0.2) ** 2, c: (4 * Math.PI * 0.8) / 0.2 };
const RELEASE = { k: (2 * Math.PI / 0.45) ** 2, c: (4 * Math.PI * 0.75) / 0.45 };

export default function DockMagnify({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const maxScale = ctx.n("scale");
  const range = ctx.n("range");
  const params = useRef({ maxScale, range });
  params.current = { maxScale, range };

  // Preview: a sine sweep drives the finger directly.
  const clock = useClock(ctx.isPreview, 30);

  // Detail: the finger (or the intro's simulated one) sets targets; sizes follow through a spring.
  const model = useRef({
    finger: null as number | null,
    sweepStart: null as number | null,
    spring: RELEASE,
    sizes: APPS.map(() => BASE),
    velocity: APPS.map(() => 0),
    hovered: null as number | null,
    pokeToken: 0,
    sliding: false,
  });
  const [frame, setFrame] = useState<{ sizes: number[]; label: number | null }>({ sizes: APPS.map(() => BASE), label: null });

  useEffect(() => {
    if (ctx.isPreview) return;
    let raf = 0;
    let last = performance.now();
    let shown = "";
    const step = (t: number) => {
      const m = model.current;
      const dt = Math.min((t - last) / 1000, 0.05);
      last = t;
      const { maxScale, range } = params.current;
      let finger = m.finger;
      if (m.sweepStart !== null) {
        const p = Math.min(Math.max((now() - m.sweepStart) / SWEEP, 0), 1);
        const eased = p * p * (3 - 2 * p);
        // Starts one influence range left of the first icon so the wave rolls in from rest.
        const from = restCenter(0) - range;
        finger = from + (restCenter(COUNT - 1) - from) * eased;
        m.sizes = sizesFor(finger, maxScale, range);
        m.velocity = m.velocity.map(() => 0);
      } else {
        const target = sizesFor(finger, maxScale, range);
        const steps = Math.max(1, Math.ceil(dt / (1 / 480)));
        const h = dt / steps;
        for (let n = 0; n < steps; n++) {
          for (let i = 0; i < COUNT; i++) {
            const a = -m.spring.k * (m.sizes[i] - target[i]) - m.spring.c * m.velocity[i];
            m.velocity[i] += a * h;
            m.sizes[i] += m.velocity[i] * h;
          }
        }
        for (let i = 0; i < COUNT; i++) {
          if (Math.abs(m.sizes[i] - target[i]) < 0.005 && Math.abs(m.velocity[i]) < 0.05) {
            m.sizes[i] = target[i];
            m.velocity[i] = 0;
          }
        }
      }
      const label = finger === null ? null : nearestIndex(finger);
      const key = `${label}|${m.sizes.map((s) => s.toFixed(2)).join(",")}`;
      if (key !== shown) {
        shown = key;
        setFrame({ sizes: [...m.sizes], label });
      }
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [ctx.isPreview]);

  const track = (x: number) => {
    const m = model.current;
    m.pokeToken += 1;
    m.sweepStart = null;
    m.finger = x;
    m.spring = TRACK;
    const nearest = nearestIndex(x);
    if (nearest !== m.hovered) {
      m.hovered = nearest;
      haptics.selection();
    }
  };
  /** Normal release or cancellation: settle the row and hide the tooltip. */
  const lift = () => {
    const m = model.current;
    m.hovered = null;
    m.finger = null;
    m.spring = RELEASE;
  };
  /** A tap swells the icons under the finger for a moment, then lets go. */
  const poke = (x: number) => {
    track(x);
    const token = model.current.pokeToken;
    after(0.5, () => {
      if (token === model.current.pokeToken && !model.current.sliding) lift();
    });
  };
  const sweep = () => {
    const m = model.current;
    const started = now();
    m.sweepStart = started;
    after(SWEEP, () => {
      if (m.sweepStart !== started) return;
      // Dropping the simulated finger inside the release spring settles the row like a real lift-off.
      m.sweepStart = null;
      m.finger = null;
      m.spring = RELEASE;
    });
  };
  useAutoplay(false, sweep, { every: 1 });

  const pan = useNavPan(
    {
      onChange: (s) => {
        model.current.sliding = true;
        track(s.location.x);
      },
      onEnd: () => {
        model.current.sliding = false;
        lift();
      },
    },
    { axis: "horizontal", minimumDistance: 6 },
  );

  let sizes = frame.sizes;
  let label = frame.label;
  if (ctx.isPreview) {
    const finger = CANVAS.w / 2 + 120 * Math.sin(clock * 1.3);
    sizes = sizesFor(finger, maxScale, range);
    label = nearestIndex(finger);
  }
  const total = sizes.reduce((a, b) => a + b, 0) + (COUNT - 1) * SPACING;
  const baseline = CANVAS.h - 22;
  const startX = (CANVAS.w - total) / 2;
  let before = 0;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18 }}>
      <div style={{ position: "relative", width: CANVAS.w, height: 250, flexShrink: 0, borderRadius: 26, overflow: "hidden", boxShadow: "0 10px 20px rgb(0 0 0 / 0.14)" }}>
        <DockDesktop ctx={ctx} />
        <div
          {...(ctx.isPreview ? {} : pan)}
          onClick={ctx.isPreview ? undefined : (e) => poke(localPoint(e, e.currentTarget).x)}
          style={{ position: "absolute", left: 0, bottom: 0, width: CANVAS.w, height: CANVAS.h, touchAction: "pan-y", cursor: "pointer", userSelect: "none", WebkitUserSelect: "none" }}
        >
          <div
            style={{
              ...glass("regular"),
              position: "absolute",
              left: (CANVAS.w - (total + 20)) / 2,
              top: baseline - BASE - 10,
              width: total + 20,
              height: BASE + 20,
              borderRadius: 22,
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 16px rgb(0 0 0 / 0.12)`,
            }}
          />
          {APPS.map((app, index) => {
            const size = sizes[index];
            const x = startX + before + index * SPACING;
            before += size;
            const showLabel = label === index;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: x,
                  top: baseline - size,
                  width: size,
                  height: size,
                  borderRadius: size * 0.26,
                  background: `linear-gradient(to bottom, ${app.colors[0]}, ${app.colors[1]})`,
                  boxShadow: "0 2px 4px rgb(0 0 0 / 0.15)",
                  color: "#fff",
                  display: "grid",
                  placeItems: "center",
                }}
              >
                {app.icon(size * 0.58)}
                <motion.div
                  initial={false}
                  animate={{ opacity: showLabel ? 1 : 0, scale: showLabel ? 1 : 0.7 }}
                  transition={spring(0.25, 0.8)}
                  style={{
                    ...menuGlass(),
                    position: "absolute",
                    left: "50%",
                    top: -30,
                    x: "-50%",
                    padding: "4px 9px",
                    borderRadius: 12,
                    fontSize: 12,
                    lineHeight: "16px",
                    fontWeight: 600,
                    color: Palette.label,
                    whiteSpace: "nowrap",
                    transformOrigin: "50% 100%",
                    pointerEvents: "none",
                  }}
                >
                  {ctx.t(...app.name)}
                </motion.div>
              </div>
            );
          })}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Slide along the dock" zh="沿程序坞滑动手指" />
    </div>
  );
}

/** Miniature desktop behind the dock: wallpaper, menu bar and a floating window. */
function DockDesktop({ ctx }: { ctx: DemoContext }) {
  const wallpaper = ctx.scheme === "dark" ? ["#1D2671", "#4B3AA8", "#8A3F7E"] : ["#9CCBFF", "#C3B4FF", "#FFC2D9"];
  return (
    <div style={{ position: "absolute", inset: 0, background: `linear-gradient(to bottom right, ${wallpaper.join(", ")})` }}>
      <div
        style={{
          height: 22,
          padding: "0 14px",
          display: "flex",
          alignItems: "center",
          gap: 12,
          background: "rgb(0 0 0 / 0.12)",
          color: "#fff",
          fontSize: 11,
          lineHeight: "13px",
          whiteSpace: "nowrap",
        }}
      >
        <div style={{ width: 9, height: 9, borderRadius: "50%", background: "rgb(255 255 255 / 0.9)" }} />
        <span style={{ fontWeight: 700 }}>{ctx.t("Finder", "访达")}</span>
        <span>{ctx.t("File", "文件")}</span>
        <span>{ctx.t("Edit", "编辑")}</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>9:41</span>
      </div>
      <div
        style={{
          ...glass("regular"),
          position: "absolute",
          left: 34,
          top: 36,
          width: 170,
          padding: 10,
          borderRadius: 10,
          boxShadow: "0 5px 10px rgb(0 0 0 / 0.12)",
          display: "flex",
          flexDirection: "column",
          gap: 10,
        }}
      >
        <div style={{ display: "flex", gap: 5 }}>
          {[Palette.red, Palette.amber, Palette.green].map((c) => (
            <div key={c} style={{ width: 7, height: 7, borderRadius: "50%", background: c }} />
          ))}
        </div>
        <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
      </div>
    </div>
  );
}
