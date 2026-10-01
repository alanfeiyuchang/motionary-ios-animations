/** text.squiggle-underline · 波浪下划线强调 (Text+SquiggleUnderline.swift) */
import { animate, motion, useMotionValue, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, spring, useAutoplay, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { useSize, useTask } from "./_text-kit";
import { squeezed } from "./_fx";

const COLORS = [Palette.coral, Palette.indigo, Palette.mint];
const RAW = {
  zh: [["把", 0], ["重点", 1], ["画出来，", 0], ["一眼", 1], ["就能", 0], ["看见", 1], ["。", 0]],
  en: [["Make", 0], ["the", 0], ["important", 1], ["words", 0], ["impossible", 1], ["to", 0], ["miss.", 1]],
} as const;

/** A marker stroke: a sine centreline thickened into a ribbon that is fuller in the middle than at its ends. */
function ribbonPath(w: number, h: number, fromRaw: number, toRaw: number, amplitude: number, phase: number, crests: number, thickness: number): string {
  const start = Math.min(Math.max(fromRaw, 0), 1);
  const end = Math.min(Math.max(toRaw, 0), 1);
  if (!(end - start > 0.004) || !w) return "M0 0";
  const centre = (p: number) => {
    const envelope = 0.6 + 0.4 * Math.sin(Math.PI * p);
    const main = Math.sin(p * Math.PI * 2 * crests + phase);
    const wander = 0.22 * Math.sin(p * Math.PI * 2 * crests * 0.37 + 1.7);
    const height = h * 0.26 * amplitude;
    // A real stroke climbs a little as the hand moves right.
    return { x: w * p, y: h / 2 + height * envelope * (main + wander) - (p - 0.5) * 2.5 };
  };
  const steps = Math.max(Math.floor((end - start) * 90), 4);
  const upper: { x: number; y: number }[] = [];
  const lower: { x: number; y: number }[] = [];
  for (let step = 0; step <= steps; step++) {
    const p = start + ((end - start) * step) / steps;
    const point = centre(p);
    const ahead = centre(Math.min(p + 0.004, 1));
    const behind = centre(Math.max(p - 0.004, 0));
    const dx = ahead.x - behind.x;
    const dy = ahead.y - behind.y;
    const length = Math.max(Math.hypot(dx, dy), 0.0001);
    // Pressure: fuller in the middle of the whole stroke, lighter where the pen lands and lifts.
    const pressure = 0.5 + 0.5 * Math.pow(Math.sin(Math.PI * p), 0.55);
    const half = (thickness * pressure) / 2;
    const nx = (-dy / length) * half;
    const ny = (dx / length) * half;
    upper.push({ x: point.x + nx, y: point.y + ny });
    lower.push({ x: point.x - nx, y: point.y - ny });
  }
  const f = (n: number) => n.toFixed(2);
  let d = "M" + [...upper, ...lower.reverse()].map((p) => `${f(p.x)} ${f(p.y)}`).join("L") + "Z";
  lower.reverse();
  // Round the two ends.
  for (const index of [0, upper.length - 1]) {
    const a = upper[index];
    const b = lower[index];
    const r = Math.hypot(a.x - b.x, a.y - b.y) / 2;
    const mx = (a.x + b.x) / 2;
    const my = (a.y + b.y) / 2;
    d += `M${f(mx - r)} ${f(my)}a${f(r)} ${f(r)} 0 1 0 ${f(r * 2)} 0a${f(r)} ${f(r)} 0 1 0 ${f(-r * 2)} 0Z`;
  }
  return d;
}

export default function SquiggleUnderline({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [active, setActive] = useState(0);
  /** Completion haptics only for underlines the viewer asked for. */
  const byUser = useRef(false);
  const isCJK = ctx.lang === "zh";
  let key = 0;
  const tokens = RAW[ctx.lang].map(([text, isKey], id) => ({ id, text, key: isKey ? key++ : null }));

  const next = () => setActive((a) => (a + 1) % COLORS.length);
  useAutoplay(
    ctx.isPreview,
    () => {
      byUser.current = false;
      next();
    },
    { every: ctx.n("duration") + 1.9 },
  );

  return (
    <div
      onClick={() => {
        haptics.selection();
        byUser.current = true;
        next();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 34, cursor: "pointer" }}
    >
      <div style={{ width: 304, display: "flex", flexWrap: "wrap", justifyContent: "center", alignItems: "center", columnGap: isCJK ? 0 : 9, rowGap: 20 }}>
        {tokens.map((token) => (
          <Word
            key={`${ctx.lang}${token.id}`}
            ctx={ctx}
            text={token.text}
            tokenKey={token.key}
            isActive={token.key === active}
            color={COLORS[(token.key ?? 0) % COLORS.length]}
            fontSize={isCJK ? 40 : 30}
            byUser={byUser}
            onTap={() => {
              haptics.selection();
              byUser.current = true;
              if (token.key !== null) setActive(token.key);
              else next();
            }}
          />
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap a key word" zh="点击任意关键词" />
    </div>
  );
}

function Word({
  ctx,
  text,
  tokenKey,
  isActive,
  color,
  fontSize,
  byUser,
  onTap,
}: {
  ctx: DemoContext;
  text: string;
  tokenKey: number | null;
  isActive: boolean;
  color: string;
  fontSize: number;
  byUser: { current: boolean };
  onTap: () => void;
}) {
  const haptics = useHaptics();
  const from = useMotionValue(0);
  const to = useMotionValue(isActive ? 1 : 0);
  const amplitude = useMotionValue(1);
  const phase = useMotionValue(0);
  const hop = useMotionValue(0);
  const [tinted, setTinted] = useState(isActive);
  const [tintTime, setTintTime] = useState(0.2);
  const [ref, { w }] = useSize<HTMLSpanElement>([text, fontSize]);
  const crests = ctx.n("crests");
  const thickness = ctx.n("width");
  const duration = ctx.n("duration");
  const damping = ctx.n("damping");
  const d = useTransform([from, to, amplitude, phase], ([f, t, a, p]: number[]) => ribbonPath(w + 6, 13, f, t, a, p, crests, thickness));

  // Erase as soon as the word stops being the active one.
  const wasActive = useRef(isActive);
  useEffect(() => {
    if (wasActive.current === isActive) return;
    wasActive.current = isActive;
    if (isActive) return;
    animate(from, 1, anim.easeIn(0.22));
    animate(hop, 0, anim.easeOut(0.3));
    setTintTime(0.3);
    setTinted(false);
  }, [isActive, from, hop]);

  const drawn = useRef(isActive);
  useTask(isActive, async (sleep) => {
    if (!isActive) {
      drawn.current = false;
      return;
    }
    if (drawn.current) return;
    drawn.current = true;
    from.jump(0);
    to.jump(0);
    amplitude.jump(1);
    const buzz = byUser.current;
    // Let the old underline start leaving first.
    if (!(await sleep(0.12))) return;
    animate(to, 1, anim.easeInOut(duration));
    if (!(await sleep(duration))) return;
    if (buzz) haptics.tap("light");
    // The twang: kick, then release everything on one loose spring.
    animate(amplitude, 1.9, anim.easeOut(0.07));
    animate(hop, -4, anim.easeOut(0.07));
    setTintTime(0.2);
    setTinted(true);
    if (!(await sleep(0.07))) return;
    const loose = spring(0.5, damping);
    animate(amplitude, 1, loose);
    animate(phase, phase.get() + Math.PI, loose);
    animate(hop, 0, loose);
  });

  return (
    <motion.span
      ref={ref}
      onClick={(e) => {
        e.stopPropagation();
        onTap();
      }}
      style={{
        position: "relative",
        display: "inline-block",
        fontSize,
        lineHeight: `${Math.round(fontSize * 1.195)}px`,
        fontWeight: 700,
        whiteSpace: "pre",
        color: tinted ? color : Palette.label,
        transition: `color ${tintTime}s cubic-bezier(0, 0, 0.58, 1)`,
        y: hop,
      }}
    >
      {squeezed(text)}
      {tokenKey !== null && w > 0 && (
        <svg width={w + 6} height={13} style={{ position: "absolute", left: -3, bottom: -10, overflow: "visible", pointerEvents: "none" }}>
          <motion.path d={d} fill={color} />
        </svg>
      )}
    </motion.span>
  );
}
