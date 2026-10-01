/** loading.countdown-ring · 倒计时环 (Loading+CountdownRing.swift) */
import { AnimatePresence, animate, motion, useIsPresent, useMotionValue, useTransform, type Transition } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, ease, fonts, spring, springAt, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { popScale } from "./bar-shared";
import { TrimCircle, primary, useAnimatedNumber, useTask, useTriggerElapsed } from "./shared";

const DIAMETER = 170;
const BOX_W = 270;
const BOX_H = 232;

const colorFor = (n: number) => [Palette.green, Palette.pink, Palette.violet, Palette.sky, Palette.mint][n] ?? Palette.amber;

export default function CountdownRing({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [count, setCount] = useState(-1);
  const sweep = useAnimatedNumber(0);
  const [kicks, setKicks] = useState(0);
  const [burst, setBurst] = useState(0);
  const [run, setRun] = useState(0);
  const [enter, setEnter] = useState<Transition>(spring(0.34, 0.62));
  const latest = useRef(ctx);
  latest.current = ctx;
  const from = Math.max(ctx.i("from"), 1);

  useTask(`${run}-${from}`, async (task) => {
    const live = !ctx.isPreview && run > 0;
    setBurst(0);
    setCount(-1);
    let number = from;
    // Let the cleared stage render once, so the first numeral punches in like the others.
    await task.sleep(0);
    while (number >= 1) {
      const beat = Math.max(latest.current.n("beat"), 0.3);
      sweep.to(0, anim.easeOut(0.16));
      setEnter(spring(0.34, 0.62));
      setCount(number);
      setKicks((v) => v + 1);
      if (live) haptics.tap("rigid");
      await task.sleep(0.16);
      sweep.to(1, anim.linear(beat - 0.16));
      await task.sleep(beat - 0.16);
      number -= 1;
    }
    sweep.to(0, anim.easeOut(0.2));
    setEnter(spring(0.38, 0.55));
    setCount(0);
    setBurst((v) => v + 1);
    setKicks((v) => v + 1);
    if (live) haptics.success();
    if (!ctx.isPreview) return;
    await task.sleep(1.5);
    setRun((v) => v + 1);
  });

  const tint = colorFor(count < 0 ? from : count);
  const end = Math.min(Math.max(sweep.value, 0), 1);
  const kick = popScale(useTriggerElapsed(kicks, 0.8), count === 0 ? 1.12 : 1.06, 0.09);
  const punch = ctx.n("punch");

  return (
    <div
      onClick={() => setRun((v) => v + 1)}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}
    >
      <div style={{ position: "relative", width: BOX_W, height: BOX_H, flex: "none" }}>
        {burst > 0 && <Rays key={burst} />}
        <motion.div
          key={kicks}
          initial={{ scale: 1, opacity: 0.55 }}
          animate={kicks > 0 ? { scale: 1.28, opacity: 0 } : undefined}
          transition={anim.easeOut(0.5)}
          style={{
            position: "absolute",
            left: (BOX_W - DIAMETER) / 2,
            top: (BOX_H - DIAMETER) / 2,
            width: DIAMETER,
            height: DIAMETER,
            borderRadius: "50%",
            boxShadow: `0 0 0 0.75px ${tint}, inset 0 0 0 0.75px ${tint}`,
          }}
        />
        <div style={{ position: "absolute", left: (BOX_W - DIAMETER) / 2, top: (BOX_H - DIAMETER) / 2, width: DIAMETER, height: DIAMETER, transform: `scale(${kick})` }}>
          <TrimCircle size={DIAMETER} lineWidth={10} color={primary(0.08)} />
          <TrimCircle size={DIAMETER} lineWidth={10} from={end} to={1} color={tint} rotate={-90} style={{ filter: `drop-shadow(0 0 8px ${alpha(tint, 0.5)})` }} />
          <div style={{ position: "absolute", inset: 0, transform: `rotate(${360 * end}deg)`, opacity: count === 0 || end > 0.985 ? 0 : 1 }}>
            <div style={{ position: "absolute", left: DIAMETER / 2 - 3, top: -3, width: 6, height: 6, borderRadius: "50%", background: "#fff", boxShadow: `0 0 12px ${tint}` }} />
          </div>
        </div>
        <div style={{ position: "absolute", left: (BOX_W - 150) / 2, top: (BOX_H - 110) / 2, width: 150, height: 110, display: "grid", placeItems: "center" }}>
          <AnimatePresence>
            {count >= 0 && <Numeral key={count} count={count} tint={tint} from={count === 0 ? punch * 1.15 : punch} enter={enter} />}
          </AnimatePresence>
        </div>
      </div>
      <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{count === 0 ? (zh ? "训练已开始" : "Workout started") : zh ? "训练即将开始" : "Workout starts in"}</span>
      <DemoHint ctx={ctx} en="Tap to restart" zh="点击重新开始" />
    </div>
  );
}

/** A numeral that punches in (big, blurred → sharp, on a spring) and leaves small and blurred. */
function Numeral({ count, tint, from, enter }: { count: number; tint: string; from: number; enter: Transition }) {
  const present = useIsPresent();
  const v = useMotionValue(0);
  const out = useMotionValue(0);
  const start = useRef({ from, enter });
  useEffect(() => {
    const c = animate(v, 1, start.current.enter);
    return () => c.stop();
  }, [v]);
  useEffect(() => {
    if (!present) animate(out, 1, anim.easeIn(0.18));
  }, [present, out]);
  const scale = useTransform([v, out], ([a, b]: number[]) => (start.current.from + (1 - start.current.from) * a) * (1 - 0.4 * b));
  const filter = useTransform([v, out], ([a, b]: number[]) => `blur(${Math.max(0, 14 * (1 - a)) + 8 * b}px)`);
  const opacity = useTransform([v, out], ([a, b]: number[]) => Math.min(Math.max(a, 0), 1) * (1 - b));
  return (
    <motion.span
      exit={{ x: 0.01 }}
      transition={{ duration: 0.18 }}
      style={{
        gridArea: "1 / 1",
        scale,
        filter,
        opacity,
        fontFamily: fonts.rounded,
        fontSize: count === 0 ? 60 : 86,
        lineHeight: 1.2,
        fontWeight: 800,
        color: tint,
        textShadow: `0 4px 24px ${alpha(tint, 0.35)}`,
        whiteSpace: "nowrap",
      }}
    >
      {count === 0 ? "GO" : String(count)}
    </motion.span>
  );
}

/**
 * `CountdownRays`: short rays that fly outward and thin out over 0.6 s (ease-out). Their opacity springs
 * toward 1 with the numeral while the burst fades it to 0, and SwiftUI adds the two animations.
 */
function Rays() {
  const e = useElapsed(0, 0.6);
  const progress = ease.out(e / 0.6);
  const eased = 1 - Math.pow(1 - progress, 3);
  const length = 16 * (1 - progress) + 2;
  const cx = BOX_W / 2;
  const cy = BOX_H / 2;
  let d = "";
  for (let index = 0; index < 14; index++) {
    const angle = (2 * Math.PI * index) / 14;
    const near = DIAMETER / 2 + 10 + 40 * eased;
    const far = near + length * (index % 2 === 0 ? 1 : 0.6);
    d += `M${cx + near * Math.cos(angle)} ${cy + near * Math.sin(angle)} L${cx + far * Math.cos(angle)} ${cy + far * Math.sin(angle)} `;
  }
  return (
    <svg width={BOX_W} height={BOX_H} style={{ position: "absolute", inset: 0, overflow: "visible", opacity: Math.min(Math.max(springAt(e, 0.38, 0.55) - progress, 0), 1) }}>
      <path d={d} stroke={Palette.green} strokeWidth={3} strokeLinecap="round" fill="none" />
    </svg>
  );
}
