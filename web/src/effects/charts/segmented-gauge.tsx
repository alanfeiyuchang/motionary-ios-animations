/** charts.segmented-gauge · 分段指示灯仪表 (Charts+SegmentedGauge.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, anim, clamp, delayed, useAutoplay, useClock, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { randomInt, useChartEntrance } from "./_shared";
import { FadeText, Stage, captionSecondary, mixColor, rounded } from "./_legacy";

const START = 150;
const SWEEP = 240;

/**
 * One tick cascade: ticks switch one per `step` from `fromLit` toward `toLit` while the readout counts
 * linearly from `fromValue` to `toValue` over `duration`.
 */
interface Cascade {
  fromLit: number;
  toLit: number;
  fromValue: number;
  toValue: number;
  start: number;
  step: number;
  duration: number;
}

const cascadeValue = (c: Cascade, now: number) => c.fromValue + (c.toValue - c.fromValue) * (c.duration > 0 ? clamp((now - c.start) / c.duration) : 1);

/** Ticks switched so far (a tick counts once its 150 ms pop has started). */
function cascadeLit(c: Cascade, now: number): number {
  const elapsed = now - c.start;
  const span = Math.abs(c.toLit - c.fromLit);
  if (!(elapsed >= 0 && span > 0)) return elapsed >= 0 ? c.toLit : c.fromLit;
  const started = Math.min(Math.floor(elapsed / Math.max(c.step, 0.001)) + 1, span);
  return c.fromLit + (c.toLit >= c.fromLit ? started : -started);
}

const litCount = (v: number, count: number) => Math.round((v / 100) * count);

function rampColor(t: number): string {
  if (t < 0.6) return mixColor(Palette.mint, Palette.amber, t / 0.6);
  return mixColor(Palette.amber, Palette.red, (t - 0.6) / 0.4);
}

function status(v: number): { en: string; zh: string; color: string } {
  if (v < 55) return { en: "Normal", zh: "正常", color: Palette.green };
  if (v < 82) return { en: "Busy", zh: "繁忙", color: Palette.amber };
  return { en: "Critical", zh: "过载", color: Palette.red };
}

export default function SegmentedGauge({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [value, setValue] = useState(0);
  const [previousLit, setPreviousLit] = useState(0);
  const [counting, setCounting] = useState(false);
  const live = useRef({ value: 0, counting: false, cascade: { fromLit: 0, toLit: 0, fromValue: 0, toValue: 0, start: -1e9, step: 0.025, duration: 0 } as Cascade });
  const generation = useRef(0);
  useClock(counting);

  const count = Math.max(ctx.i("count"), 4);
  const step = ctx.n("step");

  const setRandom = (haptic: boolean) => {
    const s = live.current;
    const now = performance.now() / 1000;
    // Start from what is on screen: mid-cascade that is the ticks already switched and the number shown now.
    const shownValue = s.counting ? cascadeValue(s.cascade, now) : s.value;
    const shownLit = clamp(s.counting ? cascadeLit(s.cascade, now) : litCount(s.value, count), 0, count);
    let next = randomInt(8, 98);
    if (Math.abs(next - shownValue) < 15) next = shownValue > 50 ? next - 40 : next + 40;
    next = clamp(next, 4, 99);
    const newLit = litCount(next, count);
    const duration = Math.abs(newLit - shownLit) * step + 0.15;
    s.cascade = { fromLit: shownLit, toLit: newLit, fromValue: shownValue, toValue: next, start: now, step, duration };
    s.counting = true;
    s.value = next;
    setPreviousLit(shownLit);
    setCounting(true);
    setValue(next);
    generation.current += 1;
    const token = generation.current;
    after(duration, () => {
      if (token !== generation.current) return;
      s.counting = false;
      setCounting(false);
    });
    if (haptic) haptics.tap("light");
  };

  useChartEntrance(() => setRandom(false));
  useAutoplay(ctx.isPreview, () => setRandom(false), { every: 2.4, delay: 2.2, intro: false });

  const lit = litCount(value, count);
  const delayFor = (index: number) => (lit >= previousLit ? Math.max(index - previousLit, 0) : Math.max(previousLit - 1 - index, 0)) * step;
  const shown = counting ? cascadeValue(live.current.cascade, performance.now() / 1000) : value;
  const state = status(shown);
  return (
    <Stage ctx={ctx} hint={["Tap for a new reading", "点击获取新读数"]}>
      <div onClick={() => setRandom(true)} style={{ position: "relative", width: 240, height: 240, borderRadius: "50%", cursor: "pointer" }}>
        {Array.from({ length: count }, (_, index) => {
          const t = index / Math.max(count - 1, 1);
          const color = rampColor(t);
          const isLit = index < lit;
          const transition = delayed(anim.easeOut(0.15), delayFor(index));
          return (
            <div key={`${count}-${index}`} style={{ position: "absolute", left: 120 - 9, top: 120 - 3, width: 18, height: 6, transform: `rotate(${START + SWEEP * t}deg) translateX(104px)` }}>
              <motion.div initial={false} animate={{ scale: isLit ? 1 : 0.8 }} transition={transition} style={{ position: "absolute", inset: 0, borderRadius: 3, background: Palette.labelAlpha(0.08) }}>
                <motion.div
                  initial={false}
                  animate={{ opacity: isLit ? 1 : 0 }}
                  transition={transition}
                  style={{ position: "absolute", inset: 0, borderRadius: 3, background: color, boxShadow: `0 0 10px color-mix(in srgb, ${color} 60%, transparent)` }}
                />
              </motion.div>
            </div>
          );
        })}
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4, transform: "translateY(8px)" }}>
          <div style={captionSecondary}>{ctx.t("CPU load", "CPU 负载")}</div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 2 }}>
              <span style={rounded(52, 700, 62)}>{Math.round(shown)}</span>
              <span style={{ ...rounded(20, 600, 24), color: Palette.secondaryLabel }}>%</span>
            </div>
            <FadeText text={ctx.t(state.en, state.zh)} style={{ fontSize: 12, lineHeight: "16px", fontWeight: 700, color: state.color }} />
          </div>
        </div>
      </div>
    </Stage>
  );
}
