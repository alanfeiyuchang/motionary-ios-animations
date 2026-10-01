/** inputs.pattern-lock (Inputs+PatternLock.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, delayed, mix, spring, springAt, textStyle, useAutoplay, useElapsed, useHaptics, usePan, type DemoProps } from "../../kit";
import { FadeText, SymbolSwap } from "./_a-common";
import { LockGlyph } from "./_b-common";
import { column, spacer, useLive, useMV, useTask } from "./_c-common";

type Status = "idle" | "error" | "success";
interface Pt {
  x: number;
  y: number;
}

const SECRET = [0, 1, 2, 4, 6, 7, 8];
const WRONG = [0, 3, 6, 7, 5];
const SPACING = 72;
const SIDE = 216;
const point = (index: number): Pt => ({ x: 36 + (index % 3) * SPACING, y: 36 + Math.floor(index / 3) * SPACING });
const same = (a: number[], b: number[]) => a.length === b.length && a.every((v, i) => v === b[i]);

export default function PatternLock({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [path, setPath, pathRef] = useLive<number[]>([]);
  const [hasFinger, setHasFinger, hasFingerRef] = useLive(false);
  const fx = useMotionValue(0);
  const fy = useMotionValue(0);
  const [status, setStatus] = useState<Status>("idle");
  const [pulses, setPulses] = useState(() => Array<number>(9).fill(0));
  const [retracting, setRetracting, retractingRef] = useLive(false);
  const [traces, setTraces] = useState(0);
  const busy = useRef(false);
  const step = useRef(0);
  const scripting = useRef(false);
  const scriptTask = useTask();
  const resultTask = useTask();
  const shakeX = useMotionValue(0);
  const width = ctx.n("width");

  const tint = status === "idle" ? Palette.indigo : status === "error" ? Palette.red : Palette.green;
  const pulse = (index: number) => setPulses((p) => p.map((v, i) => (i === index ? v + 1 : v)));

  /** A dot is caught, by the finger or the script. */
  const join = (index: number) => {
    if (pathRef.current.includes(index)) return;
    setPath([...pathRef.current, index]);
    pulse(index);
    if (!scripting.current) haptics.selection();
  };

  const capture = (location: Pt) => {
    const radius = ctx.n("capture");
    const current = pathRef.current;
    for (let index = 0; index < 9; index++) {
      if (current.includes(index)) continue;
      const dot = point(index);
      if (Math.hypot(dot.x - location.x, dot.y - location.y) >= radius) continue;
      // Jumping over a free dot in a straight line picks it up on the way, like the real lock.
      if (current.length) {
        const last = current[current.length - 1];
        const rowSum = Math.floor(last / 3) + Math.floor(index / 3);
        const columnSum = (last % 3) + (index % 3);
        if (rowSum % 2 === 0 && columnSum % 2 === 0) {
          const middle = (rowSum / 2) * 3 + columnSum / 2;
          if (middle !== last && middle !== index && !current.includes(middle)) join(middle);
        }
      }
      join(index);
      return;
    }
  };

  const reset = () => {
    // After a reel-in the segments are already gone (invisible), so dropping them shows nothing.
    setRetracting(false);
    setPath([]);
    setStatus("idle");
    busy.current = false;
  };

  /** The finger (or the script) lets go: judge the pattern. */
  const finish = (scripted = false) => {
    if (busy.current || (!hasFingerRef.current && pathRef.current.length === 0)) return;
    setHasFinger(false);
    if (pathRef.current.length <= 1) {
      setPath([]);
      return;
    }
    busy.current = true;
    const order = pathRef.current;
    const correct = same(order, SECRET);
    const quiet = ctx.isPreview || scripted;
    resultTask.start(async (sleep) => {
      if (correct) {
        setStatus("success");
        if (!quiet) haptics.success();
        setTraces((t) => t + 1);
        for (const index of order) {
          pulse(index);
          await sleep(0.06);
        }
        await sleep(1.5);
      } else {
        setStatus("error");
        const d = ctx.n("shake");
        animate(shakeX, [0, d, -d * 0.8, d * 0.5, -d * 0.25, 0], { duration: 0.4, times: [0, 0.175, 0.4, 0.625, 0.825, 1], ease: "easeInOut" });
        if (!quiet) haptics.error();
        await sleep(0.6);
        setRetracting(true);
        await sleep(0.16 + order.length * 0.05);
      }
      if (!(await sleep(0))) return;
      reset();
    });
  };

  /** The first real touch takes over from the script. */
  const stopScript = () => {
    scriptTask.cancel();
    scripting.current = false;
    if (busy.current) return;
    setPath([]);
    setHasFinger(false);
  };

  const pan = usePan({
    onChange: ({ location }) => {
      if (scripting.current) stopScript();
      if (busy.current) return;
      fx.stop();
      fy.stop();
      fx.set(location.x);
      fy.set(location.y);
      setHasFinger(true);
      capture(location);
    },
    onEnd: () => finish(),
  });

  /** A scripted finger: glides dot to dot and goes through the same join / finish as a real drag. */
  const play = (pattern: number[]) => {
    if (busy.current || !pattern.length) return;
    scripting.current = true;
    scriptTask.start(async (sleep) => {
      const first = point(pattern[0]);
      fx.set(first.x);
      fy.set(first.y);
      setHasFinger(true);
      join(pattern[0]);
      for (const index of pattern.slice(1)) {
        const p = point(index);
        animate(fx, p.x, anim.easeInOut(0.2));
        animate(fy, p.y, anim.easeInOut(0.2));
        if (!(await sleep(0.21))) return;
        join(index);
      }
      if (!(await sleep(0.15))) return;
      scripting.current = false;
      finish(true);
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const pattern = step.current % 2 === 0 ? SECRET : WRONG;
      step.current += 1;
      play(pattern);
    },
    { every: 3.6, delay: 0.4 },
  );

  // Highlight sweep along the solved pattern.
  const traceT = useElapsed(traces, 0.7, true);
  const trace = traceT < 0 ? 0 : (traceT / 0.7) * 1.22;
  const from = Math.max(trace - 0.22, 0);
  const to = Math.min(trace, 1);
  const poly = path.map(point).map((p, i) => `${i === 0 ? "M" : "L"}${p.x} ${p.y}`).join(" ");
  const title = status === "idle" ? ctx.t("Draw your pattern", "绘制解锁图案") : status === "error" ? ctx.t("Wrong pattern", "图案错误") : ctx.t("Unlocked", "已解锁");
  const count = Math.max(path.length - 1, 0);

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", alignItems: "center", gap: 8, paddingBottom: 10, ...textStyle.headline }}>
        <span style={{ color: status === "idle" ? Palette.label : tint, transition: "color 0.25s" }}>
          <SymbolSwap k={status === "success" ? "open" : "closed"}>
            <LockGlyph open={status === "success"} size={19} />
          </SymbolSwap>
        </span>
        <FadeText text={title} />
      </div>
      <motion.div {...pan} style={{ ...pan.style, position: "relative", width: SIDE, height: SIDE, flexShrink: 0, x: shakeX }}>
        <svg width={SIDE} height={SIDE} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" }}>
          <g style={{ stroke: tint, transition: "stroke 0.15s ease-out" }}>
          <AnimatePresence>
            {Array.from({ length: count }, (_, index) => (
              <Segment
                key={`${path[index]}-${path[index + 1]}`}
                from={point(path[index])}
                to={point(path[index + 1])}
                width={width}
                amplitude={ctx.n("twang") * (index % 2 === 0 ? 1 : -1)}
                retracting={retracting}
                delay={(count - 1 - index) * 0.05}
                reeled={retractingRef}
              />
            ))}
          </AnimatePresence>
          </g>
          {hasFinger && path.length > 0 && status === "idle" && <Strand from={point(path[path.length - 1])} fx={fx} fy={fy} width={width} fill={alpha(Palette.indigo, 0.8)} />}
          {status === "success" && to > from && (
            <path
              d={poly}
              pathLength={1}
              fill="none"
              stroke="rgb(255 255 255 / 0.9)"
              strokeWidth={width * 0.55}
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeDasharray={`${to - from} 2`}
              strokeDashoffset={-from}
              style={{ filter: "drop-shadow(0 0 6px rgb(255 255 255 / 0.9))" }}
            />
          )}
        </svg>
        {Array.from({ length: 9 }, (_, index) => (
          <Dot key={index} at={point(index)} joined={path.includes(index)} tint={tint} pulse={pulses[index]} />
        ))}
      </motion.div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Draw a Z from the top-left dot" zh="从左上角的点开始画一个 Z" style={{ paddingBottom: 12 }} />
    </div>
  );
}

function Dot({ at, joined, tint, pulse }: { at: Pt; joined: boolean; tint: string; pulse: number }) {
  const t = useElapsed(pulse, 0.5, true);
  let rippleScale = 1.7;
  let rippleOpacity = 0;
  let pop = 1;
  if (t >= 0) {
    const p = Math.min(t / 0.45, 1);
    const e = 1 - (1 - p) * (1 - p);
    rippleScale = mix(0.5, 1.7, e);
    rippleOpacity = mix(0.7, 0, e);
    if (t < 0.09) {
      const q = t / 0.09;
      pop = 1 + 0.45 * (q * q * (3 - 2 * q));
    } else pop = mix(1.45, 1, springAt(t - 0.09, 0.4, 0.7));
  }
  const box = { position: "absolute", left: at.x - 19, top: at.y - 19, width: 38, height: 38, borderRadius: "50%", pointerEvents: "none" } as const;
  return (
    <>
      <div style={{ ...box, border: `2px solid ${tint}`, transform: `scale(${rippleScale})`, opacity: rippleOpacity }} />
      <motion.div initial={false} animate={{ opacity: joined ? 0.18 : 0 }} transition={spring(0.3, 0.5)} style={{ ...box, background: tint, transition: "background-color 0.15s ease-out" }} />
      <motion.div
        initial={false}
        animate={{ scale: joined ? 1.3 : 1 }}
        transition={spring(0.3, 0.5)}
        style={{ position: "absolute", left: at.x - 7, top: at.y - 7, width: 14, height: 14, pointerEvents: "none" }}
      >
        <div
          style={{
            width: 14,
            height: 14,
            borderRadius: "50%",
            background: joined ? tint : Palette.labelAlpha(0.3),
            transform: `scale(${pop})`,
            transition: "background-color 0.15s ease-out",
          }}
        />
      </motion.div>
    </>
  );
}

/** One joined segment. It appears bowed sideways and rings out to a straight line. */
function Segment({
  from,
  to,
  width,
  amplitude,
  retracting,
  delay,
  reeled,
}: {
  from: Pt;
  to: Pt;
  width: number;
  amplitude: number;
  retracting: boolean;
  delay: number;
  reeled: { current: boolean };
}) {
  const bendMV = useMotionValue(amplitude);
  const bend = useMV(bendMV);
  useEffect(() => {
    if (amplitude === 0) return;
    const controls = animate(bendMV, 0, spring(0.22, 0.16));
    return () => controls.stop();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.max(Math.hypot(dx, dy), 0.001);
  // A quad curve peaks at half its control offset, hence the factor 2.
  const cx = (from.x + to.x) / 2 - (dy / length) * bend * 2;
  const cy = (from.y + to.y) / 2 + (dx / length) * bend * 2;
  return (
    <motion.path
      d={`M${from.x} ${from.y} Q${cx} ${cy} ${to.x} ${to.y}`}
      fill="none"
      strokeWidth={width}
      strokeLinecap="round"
      initial={{ pathLength: 1, opacity: 1 }}
      animate={{ pathLength: retracting ? 0 : 1, opacity: retracting ? 0 : 1 }}
      exit={{ opacity: 0, transition: reeled.current ? { duration: 0 } : anim.easeOut(0.25) }}
      transition={delayed(anim.easeIn(0.14), retracting ? delay : 0)}
    />
  );
}

/** The live strand from the last dot to the finger: tapered, and thinner the further it is pulled. */
function Strand({ from, fx, fy, width, fill }: { from: Pt; fx: ReturnType<typeof useMotionValue<number>>; fy: ReturnType<typeof useMotionValue<number>>; width: number; fill: string }) {
  const to = { x: useMV(fx), y: useMV(fy) };
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy);
  if (length <= 0.5) return null;
  const thin = 1 / (1 + length / 160);
  const near = (width / 2) * (0.55 + 0.45 * thin);
  const far = (width / 2) * Math.max(thin, 0.3);
  const nx = -dy / length;
  const ny = dx / length;
  return (
    <g fill={fill}>
      <path d={`M${from.x + nx * near} ${from.y + ny * near} L${to.x + nx * far} ${to.y + ny * far} L${to.x - nx * far} ${to.y - ny * far} L${from.x - nx * near} ${from.y - ny * near} Z`} />
      <circle cx={to.x} cy={to.y} r={far} />
    </g>
  );
}
