/** buttons.hold-bloom · 长按绽放 (Buttons+HoldBloom.swift) */
import { motion, type Transition } from "motion/react";
import { MoonStar, Pointer, Sun, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, hex, spring, useAutoplay, useClock, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useLongPress, useSince } from "./_a-kit";
import { clockValue, nowSeconds, type RateClock } from "./_c-kit";

interface Theme {
  background: [string, string];
  text: string;
  textSoft: string;
  secondary: string;
  accent: string;
  icon: LucideIcon;
  title: [string, string];
  subtitle: [string, string];
}
const DAY: Theme = {
  background: [hex(0xfffdf8), hex(0xf1eadd)],
  text: hex(0x1f1b2d),
  textSoft: hex(0x1f1b2d, 0.6),
  secondary: hex(0x1f1b2d, 0.14),
  accent: Palette.amber,
  icon: Sun,
  title: ["Day", "日间"],
  subtitle: ["Bright and warm", "明亮温暖"],
};
const NIGHT: Theme = {
  background: [hex(0x1a1740), hex(0x0e0c24)],
  text: hex(0xf4f2ff),
  textSoft: hex(0xf4f2ff, 0.6),
  secondary: hex(0xf4f2ff, 0.16),
  accent: Palette.violet,
  icon: MoonStar,
  title: ["Night", "夜间"],
  subtitle: ["Calm and dim", "沉静柔和"],
};

const CARD = { w: 300, h: 212 };
const ORIGIN = { x: CARD.w / 2, y: CARD.h - 40 };
type Phase = "idle" | "growing" | "retracting";

function blob(radius: number, wobble: number, time: number): string {
  if (radius <= 0.5) return "M0 0Z";
  const count = 72;
  const amount = Math.min(wobble, radius * 0.07);
  let d = "";
  for (let index = 0; index < count; index++) {
    const angle = (index / count) * 2 * Math.PI;
    const ripple = Math.sin(angle * 5 + time * 3) + 0.5 * Math.sin(angle * 3 - time * 2.1);
    const r = radius + amount * ripple;
    d += `${index === 0 ? "M" : "L"}${(ORIGIN.x + r * Math.cos(angle)).toFixed(1)} ${(ORIGIN.y + r * Math.sin(angle)).toFixed(1)}`;
  }
  return d + "Z";
}

function Card({ theme, holding, tr, t }: { theme: Theme; holding: boolean; tr: Transition; t: (x: [string, string]) => string }) {
  const Icon = theme.icon;
  return (
    <div style={{ position: "absolute", inset: 0, background: `linear-gradient(180deg, ${theme.background[0]}, ${theme.background[1]})` }}>
      <div style={{ position: "absolute", inset: 0, padding: "20px 20px 17px", display: "flex", flexDirection: "column", alignItems: "stretch" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 44, height: 44, borderRadius: 22, background: alpha(theme.accent, 0.18), display: "grid", placeItems: "center", color: theme.accent, flexShrink: 0 }}>
            <Icon size={22} strokeWidth={2.4} fill="currentColor" />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, color: theme.text }}>{t(theme.title)}</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: theme.textSoft }}>{t(theme.subtitle)}</span>
          </div>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, paddingTop: 18 }}>
          <div style={{ height: 9, borderRadius: 4.5, background: theme.secondary }} />
          <div style={{ height: 9, width: 170, borderRadius: 4.5, background: theme.secondary }} />
        </div>
        <div style={{ flex: 1 }} />
        <motion.div
          initial={false}
          animate={{ scale: holding ? 0.95 : 1 }}
          transition={tr}
          style={{
            alignSelf: "center",
            width: 176,
            height: 46,
            borderRadius: 23,
            background: theme.text,
            color: theme.background[0],
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            fontSize: 15,
            fontWeight: 600,
          }}
        >
          <Pointer size={16} strokeWidth={2.4} />
          <span>{t(["Hold to switch", "按住切换"])}</span>
        </motion.div>
      </div>
    </div>
  );
}

export default function HoldBloom({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const finishT = useTimeouts();
  const script = useTimeouts();
  const tick = useRef(0);
  const clock = useRef<RateClock>({ base: 0, rate: 0, since: -1e9 });
  const phaseRef = useRef<Phase>("idle");
  const [phase, setPhaseState] = useState<Phase>("idle");
  const [tr, setTr] = useState<Transition>(spring(0.3, 0.7));
  const [isNight, setIsNight] = useState(false);
  const [pops, setPops] = useState(0);
  const duration = Math.max(ctx.n("duration"), 0.2);
  const band = ctx.n("band");
  const wobble = ctx.n("wobble");
  const params = useRef({ duration, retract: 2.5 });
  params.current = { duration, retract: ctx.n("retract") };
  const fullRadius = Math.hypot(CARD.w / 2, ORIGIN.y) + band + wobble * 1.5 + 2;

  const setPhase = (p: Phase, t: Transition) => {
    phaseRef.current = p;
    setTr(t);
    setPhaseState(p);
  };
  const commit = (buzz: boolean) => {
    window.clearInterval(tick.current);
    setIsNight((n) => !n);
    clock.current = { base: 0, rate: 0, since: -1e9 };
    setPops((p) => p + 1);
    setPhase("idle", spring(0.35, 0.55));
    if (buzz) haptics.success();
  };
  const begin = (buzz: boolean) => {
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    clock.current = { base: current, rate: 1 / d, since: t };
    setPhase("growing", spring(0.3, 0.7));
    if (buzz) haptics.tap("soft");
    finishT.clearAll();
    finishT.after((1 - current) * d, () => commit(buzz));
    window.clearInterval(tick.current);
    if (!buzz) return;
    tick.current = window.setInterval(() => haptics.tap("soft"), 160);
  };
  const cancel = () => {
    if (phaseRef.current !== "growing") return;
    finishT.clearAll();
    window.clearInterval(tick.current);
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    const speed = Math.max(params.current.retract, 0.5);
    clock.current = { base: current, rate: -speed / d, since: t };
    setPhase("retracting", spring(0.3, 0.6));
    finishT.after((current * d) / speed + 0.05, () => {
      if (phaseRef.current === "retracting") setPhase("idle", spring(0.3, 0.6));
    });
  };
  const playScript = () => {
    if (phaseRef.current !== "idle") return;
    script.clearAll();
    const hold = params.current.duration;
    begin(false);
    if (!ctx.isPreview) return;
    script.after(hold + 1.2, () => begin(false));
    script.after(hold + 1.2 + hold * 0.62, cancel);
  };
  useAutoplay(ctx.isPreview, playScript, { every: duration * 1.7 + 2.6, delay: 0.4 });

  const longPress = useLongPress({
    duration: 600,
    maximumDistance: 60,
    onComplete: () => {},
    onPressingChanged: (pressing) => {
      script.clearAll();
      if (pressing) begin(true);
      else cancel();
    },
  });

  useClock(phase !== "idle", ctx.isPreview ? 30 : undefined);
  const time = nowSeconds();
  const progress = clockValue(clock.current, time);
  const radius = fullRadius * Math.pow(progress, 1.5);
  const current = isNight ? NIGHT : DAY;
  const next = isNight ? DAY : NIGHT;
  const holding = phase === "growing";
  const t = (x: [string, string]) => ctx.t(x[0], x[1]);
  const pt = useSince(pops, 0.65);
  const pop = track(pt, 1, [cubicKF(1.03, 0.1), springKF(1, 0.5, BOUNCY)]);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div role="button" style={{ position: "relative", width: CARD.w, height: CARD.h, flexShrink: 0, transform: `scale(${pop})`, borderRadius: 28, boxShadow: `0 12px 20px ${black(0.18)}` }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 28, overflow: "hidden" }}>
          <Card theme={current} holding={holding} tr={tr} t={t} />
          {progress > 0.001 && (
            <>
              <div style={{ position: "absolute", inset: 0, background: next.accent, clipPath: `path("${blob(radius, wobble, time)}")` }} />
              <div style={{ position: "absolute", inset: 0, clipPath: `path("${blob(Math.max(radius - band, 0), wobble, time + 1.3)}")` }}>
                <Card theme={next} holding={holding} tr={tr} t={t} />
              </div>
            </>
          )}
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 28, boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}`, pointerEvents: "none" }} />
        <div {...longPress} style={{ ...longPress.style, position: "absolute", left: ORIGIN.x - 95, top: ORIGIN.y - 30, width: 190, height: 60 }} />
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Hold the button until the colour fills the card" zh="按住按钮，直到色彩漫满卡片" style={{ paddingBottom: 18 }} />
    </div>
  );
}
