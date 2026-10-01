/** loading.launch-button · 纸飞机发送按钮 (Loading+LaunchButton.swift) */
import { motion, useAnimationControls } from "motion/react";
import { Check, Send } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import {
  DemoHint,
  NumericText,
  Palette,
  alpha,
  anim,
  cubicBezier,
  delayed,
  ease,
  pressHandlers,
  spring,
  springAt,
  useAutoplay,
  useElapsed,
  useHaptics,
  white,
  type DemoProps,
} from "../../kit";
import { popScale } from "./bar-shared";
import { makeRun, springSmooth, useAnimatedNumber, useTriggerElapsed, type Run } from "./shared";
import { WHITE, css, mixColor } from "./round2";

const WIDTH = 230;
const HEIGHT = 58;
const SLOT = 86;
type State = "idle" | "flying" | "done";

/** The flight path, in points relative to the button's centre. */
function flight(arc: number) {
  const p0 = [-SLOT, 0];
  const p1 = [-46, (-arc * 4) / 3];
  const p2 = [52, (-arc * 4) / 3];
  const p3 = [SLOT, 0];
  return {
    point(t: number): [number, number] {
      const u = Math.min(Math.max(t, 0), 1);
      const v = 1 - u;
      const a = v * v * v;
      const b = 3 * v * v * u;
      const c = 3 * v * u * u;
      const d = u * u * u;
      return [a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]];
    },
    /** Heading in degrees (0 = right, positive = clockwise on screen). */
    heading(t: number) {
      const u = Math.min(Math.max(t, 0), 1);
      const v = 1 - u;
      const dx = 3 * v * v * (p1[0] - p0[0]) + 6 * v * u * (p2[0] - p1[0]) + 3 * u * u * (p3[0] - p2[0]);
      const dy = 3 * v * v * (p1[1] - p0[1]) + 6 * v * u * (p2[1] - p1[1]) + 3 * u * u * (p3[1] - p2[1]);
      return (Math.atan2(dy, dx) * 180) / Math.PI;
    },
  };
}

const cubic = cubicBezier(0.42, 0, 0.58, 1);
/** Tap kick: 0.96 in 0.09 s, then a springy return through a small overshoot. */
function kickScale(t: number) {
  if (t < 0) return 1;
  if (t < 0.09) return 1 - 0.04 * cubic(t / 0.09);
  return 0.96 + 0.04 * springAt(t - 0.09, 0.3, 0.3);
}

export default function LaunchButton({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [state, setState] = useState<State>("idle");
  const stateRef = useRef<State>("idle");
  const t = useAnimatedNumber(0);
  const aim = useAnimatedNumber(0);
  const [sparks, setSparks] = useState(0);
  const [kicks, setKicks] = useState(0);
  const [pops, setPops] = useState(0);
  const [pressed, setPressed] = useState(false);
  const plane = useAnimationControls();
  const task = useRef<Run | null>(null);
  const muted = useRef(false);
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  const go = (next: State) => {
    stateRef.current = next;
    setState(next);
  };

  /** Back to idle: the check leaves and a fresh plane springs into the leading slot. */
  const reset = () => {
    t.mv.stop();
    t.mv.set(0);
    t.target.current = 0;
    aim.mv.stop();
    aim.mv.set(0);
    plane.stop();
    plane.set({ x: -28, scale: 0.2, opacity: 0 });
    go("idle");
    void plane.start({ scale: 0.5 }, springSmooth(0.3));
    void plane.start({ x: 0, scale: 1, opacity: 1 }, delayed(spring(0.45, 0.6), 0.1));
  };

  const tap = () => {
    if (stateRef.current === "flying") return;
    if (stateRef.current === "done") {
      task.current?.cancel();
      reset();
      return;
    }
    const c = latest.current;
    const buzz = !c.isPreview && !muted.current;
    haptics.tap("medium");
    setKicks((v) => v + 1);
    setSparks(0);
    go("flying");
    aim.to(1, spring(0.25, 0.6));
    const duration = Math.max(c.n("flight"), 0.3);
    const loops = c.isPreview;
    task.current?.cancel();
    const run = makeRun();
    task.current = run;
    (async () => {
      await run.sleep(0.16);
      t.to(1, anim.curve(0.45, 0, 0.55, 1, duration));
      await run.sleep(duration - 0.06);
      go("done");
      void plane.start({ scale: 0.2, opacity: 0 }, spring(0.38, 0.6));
      setSparks((v) => v + 1);
      setPops((v) => v + 1);
      if (buzz) haptics.success();
      await run.sleep(loops ? 1.5 : 2.2);
      reset();
    })().catch(() => {});
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      if (stateRef.current !== "idle") return;
      muted.current = true;
      tap();
      muted.current = false;
    },
    { every: 1.0, delay: 0.6 },
  );

  const arc = ctx.n("arc");
  const path = flight(arc);
  const tv = t.value;
  const point = path.point(tv);
  const turn = (path.heading(tv) + 45) * aim.value;
  const outside = Math.min(Math.max((-point[1] - 24) / 12, 0), 1);
  const done = state === "done";
  const title = state === "idle" ? (zh ? "发送" : "Send") : state === "flying" ? (zh ? "发送中…" : "Sending…") : zh ? "已发送" : "Sent";
  const scale = kickScale(useTriggerElapsed(kicks, 1)) * popScale(useTriggerElapsed(pops, 0.8), 1.05, 0.12);
  const fade = state === "flying" ? Math.min(tv * 8, 1) * Math.min((1 - tv) * 6, 1) : 0;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 22 }}>
      <div style={{ position: "relative", width: WIDTH, height: HEIGHT, marginTop: 118, flex: "none" }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${scale})` }}>
          <motion.button
            type="button"
            onClick={tap}
            {...pressHandlers(setPressed)}
            animate={{ scale: pressed ? 0.96 : 1 }}
            transition={spring(0.28, 0.6)}
            style={{
              position: "absolute",
              inset: 0,
              display: "block",
              borderRadius: HEIGHT / 2,
              boxShadow: `0 8px 28px ${alpha(done ? Palette.green : Palette.indigo, 0.35)}`,
              transition: "box-shadow 0.35s",
            }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: HEIGHT / 2, overflow: "hidden", background: "linear-gradient(135deg, #4B57E0, #7A45D6)" }}>
              <motion.div
                initial={false}
                animate={{ opacity: state === "flying" ? 1 : 0 }}
                transition={springSmooth(0.3)}
                style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: WIDTH * Math.min(Math.max(tv, 0), 1), background: white(0.2) }}
              />
              <motion.div initial={false} animate={{ opacity: done ? 1 : 0 }} transition={done ? spring(0.38, 0.6) : springSmooth(0.3)} style={{ position: "absolute", inset: 0, background: Palette.successStrong }} />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: HEIGHT / 2,
                  padding: 1,
                  background: `linear-gradient(${white(0.4)}, ${white(0)})`,
                  WebkitMask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                  mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                }}
              />
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff", fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>
                <NumericText value={state === "idle" ? 0 : state === "flying" ? 1 : 2} text={title} />
              </div>
              <motion.div
                initial={false}
                animate={{ scale: done ? 1 : 0.2, opacity: done ? 1 : 0 }}
                transition={done ? spring(0.38, 0.6) : springSmooth(0.3)}
                style={{ position: "absolute", left: WIDTH / 2 + SLOT - 12, top: HEIGHT / 2 - 12, width: 24, height: 24, display: "grid", placeItems: "center", color: "#fff" }}
              >
                <Check size={19} strokeWidth={3.4} />
              </motion.div>
            </div>
          </motion.button>
        </div>
        {ctx.b("trail") && fade > 0.001 && (
          <svg width={WIDTH} height={HEIGHT} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none", opacity: fade }}>
            {[0, 1, 2].map((index) => {
              const to = Math.max(tv - (0.04 + 0.12 * index), 0);
              const from = Math.max(to - 0.12, 0);
              if (to - from <= 0.004) return null;
              let d = "";
              for (let step = 0; step <= 14; step++) {
                const p = path.point(from + ((to - from) * step) / 14);
                d += `${step === 0 ? "M" : "L"}${WIDTH / 2 + p[0]} ${HEIGHT / 2 + p[1]} `;
              }
              return (
                <path
                  key={index}
                  d={d}
                  fill="none"
                  stroke={index === 0 ? Palette.pink : Palette.violet}
                  strokeWidth={3 - 0.5 * index}
                  strokeLinecap="round"
                  strokeDasharray="0.5 7"
                  opacity={0.95 - 0.3 * index}
                />
              );
            })}
          </svg>
        )}
        {/* The plane: the outer scale is applied after the flight offset, about the button's centre. */}
        <motion.div animate={plane} initial={false} style={{ position: "absolute", left: WIDTH / 2, top: HEIGHT / 2, width: 0, height: 0, pointerEvents: "none" }}>
          <div
            style={{
              position: "absolute",
              left: -12,
              top: -12,
              width: 24,
              height: 24,
              display: "grid",
              placeItems: "center",
              transform: `translate(${point[0]}px, ${point[1]}px) scale(${1 + 0.35 * Math.sin(Math.PI * Math.min(Math.max(tv, 0), 1))}) rotate(${turn}deg)`,
              color: css(mixColor(WHITE, Palette.violet, outside)),
              filter: `drop-shadow(0 3px 6px ${alpha(Palette.violet, 0.5 * outside)})`,
            }}
          >
            <Send size={20} fill="currentColor" strokeWidth={1.2} />
          </div>
        </motion.div>
        {sparks > 0 && <Sparks key={sparks} />}
      </div>
      <DemoHint ctx={ctx} en="Tap the button" zh="点击按钮" />
    </div>
  );
}

/** Six sparks that fly out of the landing slot (opacity: a spring toward 1 plus an ease-out back to 0). */
function Sparks() {
  const e = useElapsed(0, 0.9);
  const progress = ease.out(e / 0.55);
  const eased = 1 - Math.pow(1 - progress, 3);
  const r = 2.6 * (1 - progress) + 0.4;
  const opacity = Math.min(Math.max(springAt(e, 0.38, 0.6) - progress, 0), 1);
  return (
    <svg width={100} height={100} style={{ position: "absolute", left: WIDTH / 2 + SLOT - 50, top: HEIGHT / 2 - 50, overflow: "visible", pointerEvents: "none", opacity }}>
      {[0, 1, 2, 3, 4, 5].map((index) => {
        const angle = -Math.PI * (0.12 + (0.76 * index) / 5);
        const distance = 16 + 26 * eased * (index % 2 === 0 ? 1 : 0.7);
        return <circle key={index} cx={50 + distance * Math.cos(angle)} cy={50 + distance * Math.sin(angle)} r={r} fill={Palette.amber} />;
      })}
    </svg>
  );
}
