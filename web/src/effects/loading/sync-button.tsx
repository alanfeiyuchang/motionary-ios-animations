/** loading.sync-button · 同步按钮 (Loading+SyncButton.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, delayed, pressHandlers, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { popScale } from "./bar-shared";
import { TrimPath, makeRun, springSmooth, useAnimatedNumber, useTriggerElapsed, type Run } from "./shared";

type State = "idle" | "syncing" | "done";
const WIDTH = 204;
const HEIGHT = 56;
const ITEMS = 128;

/** Two arc arrows that shorten into nothing as `merge` goes to 1. */
function arrowsPath(merge: number): string {
  const keep = 1 - Math.min(Math.max(merge, 0), 1);
  if (keep <= 0.01) return "";
  const c = 12;
  const radius = 12 - 2.5;
  const sweep = ((126 * Math.PI) / 180) * keep;
  let d = "";
  for (let half = 0; half < 2; half++) {
    // The head stays where it is; the tail catches up with it.
    const end = ((half === 0 ? -28 : 152) * Math.PI) / 180;
    for (let step = 0; step <= 14; step++) {
      const angle = end - sweep + (sweep * step) / 14;
      d += `${step === 0 ? "M" : "L"}${(c + radius * Math.cos(angle)).toFixed(2)} ${(c + radius * Math.sin(angle)).toFixed(2)} `;
    }
    const tx = c + radius * Math.cos(end);
    const ty = c + radius * Math.sin(end);
    const tanX = -Math.sin(end);
    const tanY = Math.cos(end);
    const nx = Math.cos(end);
    const ny = Math.sin(end);
    const length = 5 * keep;
    const spread = 4.2 * keep;
    d += `M${tx - tanX * length + nx * spread} ${ty - tanY * length + ny * spread} L${tx} ${ty} L${tx - tanX * length - nx * spread} ${ty - tanY * length - ny * spread} `;
  }
  return d;
}

export default function SyncButton({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [state, setStateValue] = useState<State>("idle");
  const stateRef = useRef<State>("idle");
  const rotation = useAnimatedNumber(0);
  const merge = useAnimatedNumber(0);
  const check = useAnimatedNumber(0);
  const items = useAnimatedNumber(0);
  const [pops, setPops] = useState(0);
  const [pressed, setPressed] = useState(false);
  const task = useRef<Run | null>(null);
  const muted = useRef(false);
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  const setState = (s: State) => {
    stateRef.current = s;
    setStateValue(s);
  };

  /** The check retracts and the arrows grow back, unspinning one turn. */
  const reset = () => {
    const back = spring(0.6, 0.68);
    check.to(0, anim.easeIn(0.16));
    merge.to(0, back);
    setState("idle");
    if (latest.current.b("unspin")) rotation.to(rotation.target.current - 360, back);
  };

  const sync = () => {
    if (stateRef.current === "syncing") return;
    if (stateRef.current === "done") {
      task.current?.cancel();
      reset();
      return;
    }
    const c = latest.current;
    haptics.tap("medium");
    const duration = Math.max(c.n("duration"), 0.3);
    const turns = Math.max(Math.round(duration * c.n("speed")), 1);
    const buzz = !c.isPreview && !muted.current;
    const loops = c.isPreview;
    items.mv.stop();
    items.mv.set(0);
    items.target.current = 0;
    setState("syncing");
    // Wind-up: a short turn against the spin.
    rotation.to(rotation.target.current - 28, anim.easeOut(0.16));
    task.current?.cancel();
    const run = makeRun();
    task.current = run;
    (async () => {
      await run.sleep(0.16);
      rotation.to(rotation.target.current + 28 + 360 * turns, anim.curve(0.5, 0, 0.2, 1, duration));
      items.to(ITEMS, anim.easeInOut(duration * 0.92));
      await run.sleep(duration - 0.08);
      setState("done");
      merge.to(1, spring(0.4, 0.6));
      check.to(1, delayed(anim.easeOut(0.28), 0.1));
      setPops((v) => v + 1);
      if (buzz) haptics.success();
      await run.sleep(loops ? 1.5 : 2.2);
      reset();
    })().catch(() => {});
  };

  // Only an idle button is tapped, so a sync is never cut short; it resets itself.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (stateRef.current !== "idle") return;
      muted.current = true;
      sync();
      muted.current = false;
    },
    { every: 1.0, delay: 0.6 },
  );

  const done = state === "done";
  const title = state === "idle" ? (zh ? "立即同步" : "Sync now") : state === "syncing" ? (zh ? "同步中…" : "Syncing…") : zh ? "已是最新" : "Up to date";
  const pop = popScale(useTriggerElapsed(pops, 0.8), 1.05, 0.12);
  const count = Math.round(Math.min(Math.max(items.value, 0), ITEMS));
  const arrows = arrowsPath(merge.value);
  const fade = { initial: { opacity: 0 }, animate: { opacity: 1 }, exit: { opacity: 0 } };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ transform: `scale(${pop})`, flex: "none" }}>
        <motion.button
          type="button"
          onClick={sync}
          {...pressHandlers(setPressed)}
          animate={{ scale: pressed ? 0.96 : 1 }}
          transition={spring(0.28, 0.6)}
          style={{
            display: "block",
            position: "relative",
            width: WIDTH,
            height: HEIGHT,
            borderRadius: HEIGHT / 2,
            boxShadow: `0 8px 28px ${alpha(done ? Palette.green : Palette.blue, 0.38)}`,
            transition: "box-shadow 0.4s",
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: HEIGHT / 2, overflow: "hidden", background: "linear-gradient(135deg, #3D8BFF, #3F55E0)" }}>
            <motion.div initial={false} animate={{ opacity: done ? 1 : 0 }} transition={done ? spring(0.4, 0.6) : spring(0.6, 0.68)} style={{ position: "absolute", inset: 0, background: Palette.successStrong }} />
            <AnimatePresence>
              {state === "syncing" && (
                <motion.div key="sheen" {...fade} transition={springSmooth(0.25)} style={{ position: "absolute", inset: 0 }}>
                  {/* A band of light that crosses the pill for as long as it is on screen. */}
                  <motion.div
                    initial={{ x: -WIDTH / 2 - 60 }}
                    animate={{ x: WIDTH / 2 + 60 }}
                    transition={{ duration: 1.1, ease: "linear", repeat: Infinity }}
                    style={{
                      position: "absolute",
                      left: WIDTH / 2 - 45,
                      top: HEIGHT / 2 - 70,
                      width: 90,
                      height: 140,
                      rotate: 18,
                      background: `linear-gradient(90deg, ${white(0)}, ${white(0.28)}, ${white(0)})`,
                    }}
                  />
                </motion.div>
              )}
            </AnimatePresence>
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
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 10, color: "#fff" }}>
              <div style={{ position: "relative", width: 24, height: 24, flex: "none" }}>
                <svg width={24} height={24} viewBox="0 0 24 24" style={{ position: "absolute", inset: 0, overflow: "visible", transform: `rotate(${rotation.value}deg)` }}>
                  {arrows && <path d={arrows} fill="none" stroke="#fff" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round" />}
                </svg>
                {check.value > 0.001 && (
                  <TrimPath
                    d={`M ${24 * 0.2} ${12 + 24 * 0.04} L ${24 * 0.43} ${24 * 0.74} L ${24 * 0.82} ${24 * 0.28}`}
                    width={24}
                    height={24}
                    trim={check.value}
                    color="#fff"
                    lineWidth={3}
                    style={{ position: "absolute", inset: 0 }}
                  />
                )}
              </div>
              <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>
                <NumericText value={state === "idle" ? 0 : state === "syncing" ? 1 : 2} text={title} />
              </span>
            </div>
          </div>
        </motion.button>
      </div>
      <div style={{ height: 18, display: "grid", placeItems: "center", fontSize: 13, lineHeight: "18px", fontWeight: 500, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>
        <AnimatePresence initial={false}>
          <motion.span key={state} {...fade} transition={state === "idle" ? spring(0.6, 0.68) : state === "done" ? spring(0.4, 0.6) : springSmooth(0.25)} style={{ gridArea: "1 / 1", color: done ? Palette.green : Palette.secondaryLabel }}>
            {state === "idle"
              ? zh
                ? "上次同步：2 分钟前"
                : "Last synced 2 min ago"
              : state === "syncing"
                ? zh
                  ? `正在同步 ${count} / ${ITEMS} 项`
                  : `Syncing ${count} of ${ITEMS} items`
                : zh
                  ? "刚刚同步了 128 项"
                  : "128 items synced just now"}
          </motion.span>
        </AnimatePresence>
      </div>
      <DemoHint ctx={ctx} en="Tap to sync" zh="点击同步" />
    </div>
  );
}
