/** buttons.hold-liquid · 液体注满 (Buttons+HoldLiquid.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Send } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import type { Transition } from "motion/react";
import { DemoHint, Palette, alpha, anim, hex, spring, useAutoplay, useClock, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useLongPress, useSince, useSvgID } from "./_a-kit";
import { clockValue, nowSeconds, type RateClock } from "./_c-kit";

const W = 236;
const H = 64;
type Phase = "idle" | "filling" | "draining" | "done";

/** Everything below a tilted, travelling sine surface, as an SVG path; `open` leaves only the surface line. */
function liquidPath(level: number, phase: number, amplitude: number, tilt: number, wavelength: number, surfaceOnly = false): string {
  if (level <= 0.0005) return "";
  const slack = amplitude * 1.3 + Math.abs(tilt) + 2;
  const waterline = H + slack - (H + slack * 2) * level;
  let d = surfaceOnly ? "" : `M0 ${H + 2}`;
  for (let x = 0; x <= W + 3; x += 3) {
    const wave = amplitude * Math.sin((x / wavelength) * 2 * Math.PI + phase);
    const lean = (tilt * (x - W / 2)) / (W / 2);
    d += `${d === "" ? "M" : "L"}${x} ${(waterline + wave + lean).toFixed(2)}`;
  }
  return surfaceOnly ? d : `${d}L${W} ${H + 2}Z`;
}

/** `checkmark.circle.fill` with the check cut out, in `currentColor`. */
function CheckCut({ size }: { size: number }) {
  const id = useSvgID("cut");
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} style={{ flexShrink: 0 }}>
      <mask id={id}>
        <rect width="24" height="24" fill="#fff" />
        <path d="M7.4 12.3l3.1 3.1 6.1-6.5" fill="none" stroke="#000" strokeWidth={2.3} strokeLinecap="round" strokeLinejoin="round" />
      </mask>
      <circle cx="12" cy="12" r="10.5" fill="currentColor" mask={`url(#${id})`} />
    </svg>
  );
}

function Label({ done, color, transition, sent, hold }: { done: boolean; color: string; transition: Transition; sent: string; hold: string }) {
  const row = (key: string, children: ReactNode) => (
    <motion.div
      key={key}
      initial={{ y: 16, opacity: 0, filter: "blur(5px)" }}
      animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
      exit={{ y: -16, opacity: 0, filter: "blur(5px)" }}
      transition={transition}
      style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 7, fontSize: 17, fontWeight: 600, color, whiteSpace: "nowrap" }}
    >
      {children}
    </motion.div>
  );
  return (
    <AnimatePresence initial={false}>
      {done
        ? row(
            "done",
            <>
              <CheckCut size={20} />
              <span>{sent}</span>
            </>,
          )
        : row(
            "hold",
            <>
              <Send size={18} fill="currentColor" strokeWidth={1.5} />
              <span>{hold}</span>
            </>,
          )}
    </AnimatePresence>
  );
}

export default function HoldLiquid({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const finishT = useTimeouts();
  const script = useTimeouts();
  const clock = useRef<RateClock>({ base: 0, rate: 0, since: -1e9 });
  const phaseRef = useRef<Phase>("idle");
  const [phase, setPhaseState] = useState<Phase>("idle");
  const kick = useRef({ at: -1e9, sign: 1 });
  const [pops, setPops] = useState(0);
  const [labelTr, setLabelTr] = useState<Transition>(spring(0.4, 0.8));
  const id = useSvgID("liquid");
  const duration = Math.max(ctx.n("duration"), 0.2);
  const params = useRef({ duration, drain: 2 });
  params.current = { duration, drain: ctx.n("drain") };

  const setPhase = (p: Phase) => {
    phaseRef.current = p;
    setPhaseState(p);
  };
  const drain = (speed: number, sign: number) => {
    finishT.clearAll();
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    clock.current = { base: current, rate: -speed / d, since: t };
    kick.current = { at: t, sign };
    setLabelTr(anim.smoothD(0.3));
    setPhase("draining");
    finishT.after((current * d) / speed + 0.05, () => {
      if (phaseRef.current === "draining") setPhase("idle");
    });
  };
  const finish = (buzz: boolean) => {
    const t = nowSeconds();
    clock.current = { base: 1, rate: 0, since: t };
    kick.current = { at: t, sign: -0.6 };
    setPops((p) => p + 1);
    setLabelTr(spring(0.4, 0.8));
    setPhase("done");
    if (buzz) haptics.success();
    finishT.clearAll();
    finishT.after(1.6, () => drain(2.4, 1));
  };
  const begin = (buzz: boolean) => {
    if (phaseRef.current === "done") return;
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    clock.current = { base: current, rate: 1 / d, since: t };
    kick.current = { at: t, sign: 1 };
    setPhase("filling");
    if (buzz) haptics.tap("soft");
    finishT.clearAll();
    finishT.after((1 - current) * d, () => finish(buzz));
  };
  const cancel = () => {
    if (phaseRef.current !== "filling") return;
    drain(Math.max(params.current.drain, 0.5), -1);
  };
  const playScript = () => {
    if (phaseRef.current !== "idle") return;
    script.clearAll();
    const fill = params.current.duration;
    begin(false);
    if (!ctx.isPreview) return;
    const next = fill + 1.6 + fill / 2.4 + 0.5;
    script.after(next, () => begin(false));
    script.after(next + fill * 0.55, cancel);
  };
  useAutoplay(ctx.isPreview, playScript, { every: duration * 1.8 + 3.6, delay: 0.4 });

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
  const level = clockValue(clock.current, time);
  const since = time - kick.current.at;
  const moving = phase === "filling" || phase === "draining";
  const tilt = ctx.n("slosh") * kick.current.sign * Math.exp(-2.6 * since) * Math.cos(since * 2 * Math.PI * 1.4);
  const amplitude = ctx.n("wave") * (moving ? 1 : Math.max(Math.exp(-6 * since), 0));
  const done = phase === "done";

  const front = liquidPath(level, time * 4.2, amplitude, tilt, 132);
  const surface = liquidPath(level, time * 4.2, amplitude, tilt, 132, true);
  const back = liquidPath(level, -time * 3.1 + 2.1, amplitude * 1.25, -tilt * 0.6, 96);
  const submerged = ctx.scheme === "dark" ? hex(0x04193a) : "#fff";
  const pt = useSince(pops, 0.65);
  const pop = track(pt, 1, [cubicKF(1.04, 0.1), springKF(1, 0.5, BOUNCY)]);

  const bubbles = [];
  if (level > 0.02 && !done) {
    const fr = (v: number) => v - Math.floor(v);
    for (let index = 0; index < 9; index++) {
      const seed = index * 0.618;
      const speed = 0.5 + 0.35 * fr(seed);
      const rise = fr(time * speed + seed * 3);
      const x = W * (0.08 + 0.84 * fr(seed * 7.3)) + Math.sin(time * 3 + seed * 9) * 3;
      const y = H * (1.05 - rise * 1.1);
      bubbles.push(<circle key={index} cx={x} cy={y} r={1.4 + 1.8 * fr(seed * 3.7)} fill={white(0.32 * (1 - rise * 0.5))} />);
    }
  }
  const sent = ctx.t("Sent", "已发送");
  const hold = ctx.t("Hold to send", "按住发送");

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div {...longPress} role="button" style={{ ...longPress.style, width: W, height: H, flexShrink: 0, transform: `scale(${pop})`, borderRadius: H / 2 }}>
        <motion.div
          initial={false}
          animate={{ scale: phase === "filling" ? 0.97 : 1 }}
          transition={spring(0.3, 0.7)}
          style={{ position: "relative", width: W, height: H, borderRadius: H / 2, boxShadow: `0 9px 16px ${alpha(Palette.blue, 0.12 + 0.24 * level)}` }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: H / 2, overflow: "hidden", background: Palette.elevated }}>
            <Label done={done} color={Palette.label} transition={labelTr} sent={sent} hold={hold} />
            <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{ position: "absolute", inset: 0 }}>
              <defs>
                <linearGradient id={`${id}-g`} x1="0" y1="0" x2="0" y2={H} gradientUnits="userSpaceOnUse">
                  <stop offset="0" stopColor={Palette.sky} />
                  <stop offset="1" stopColor={Palette.blue} />
                </linearGradient>
                <clipPath id={`${id}-c`}>
                  <path d={front} />
                </clipPath>
              </defs>
              {back && <path d={back} fill={alpha(Palette.sky, 0.5)} transform="translate(0 -3)" />}
              {front && <path d={front} fill={`url(#${id}-g)`} />}
              <g clipPath={`url(#${id}-c)`}>{bubbles}</g>
              {surface && <path d={surface} fill="none" stroke={white(0.55)} strokeWidth={1.2} />}
            </svg>
            <div style={{ position: "absolute", inset: 0, clipPath: front ? `path("${front}")` : "inset(100%)" }}>
              <Label done={done} color={submerged} transition={labelTr} sent={sent} hold={hold} />
            </div>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: H / 2, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
        </motion.div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Hold until the button is full" zh="一直按住，直到注满" style={{ paddingBottom: 18 }} />
    </div>
  );
}
