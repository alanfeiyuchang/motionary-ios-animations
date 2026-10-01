/** charts.waffle-kpi · 华夫格百分比 KPI (Charts+WaffleKPI.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, clamp, delayed, demoCard, spring, useAutoplay, useClock, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { randomInt, useChartEntrance } from "./_shared";
import { Stage, mixColor, rounded } from "./_legacy";

/**
 * One fill cascade: squares switch one per `step` from `from` toward `to`, and the number counts
 * linearly from the value it showed (`fromValue`) to `to` over `duration`.
 */
interface Cascade {
  from: number;
  to: number;
  fromValue: number;
  start: number;
  step: number;
  duration: number;
}

const cascadeValue = (c: Cascade, now: number) => c.fromValue + (c.to - c.fromValue) * (c.duration > 0 ? clamp((now - c.start) / c.duration) : 1);

/** Squares switched so far (a square counts once its pop has started). */
function cascadeFilled(c: Cascade, now: number): number {
  const elapsed = now - c.start;
  const span = Math.abs(c.to - c.from);
  if (!(elapsed >= 0 && span > 0)) return elapsed >= 0 ? c.to : c.from;
  const started = Math.min(Math.floor(elapsed / Math.max(c.step, 0.001)) + 1, span);
  return c.from + (c.to >= c.from ? started : -started);
}

function cellColor(order: number): string {
  const t = order / 99;
  if (t < 0.5) return mixColor(Palette.mint, Palette.sky, t * 2);
  return mixColor(Palette.sky, Palette.indigo, (t - 0.5) * 2);
}

const rowsTopDown = [9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
const columns = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

export default function WaffleKPI({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [percent, setPercent] = useState(0);
  const [previous, setPrevious] = useState(0);
  const [counting, setCounting] = useState(false);
  const live = useRef({ percent: 0, counting: false, cascade: { from: 0, to: 0, fromValue: 0, start: -1e9, step: 0.012, duration: 0 } as Cascade });
  const generation = useRef(0);
  useClock(counting);

  const step = ctx.n("step");
  const update = (haptic: boolean) => {
    const s = live.current;
    const now = performance.now() / 1000;
    // Start from what is on screen: mid-cascade that is the squares already switched, not the previous target.
    const shown = s.counting ? cascadeFilled(s.cascade, now) : s.percent;
    const shownValue = s.counting ? cascadeValue(s.cascade, now) : s.percent;
    let next = randomInt(18, 96);
    if (Math.abs(next - shown) < 12) next = shown > 55 ? next - 30 : next + 30;
    next = clamp(next, 5, 99);
    const duration = Math.abs(next - shown) * step + 0.2;
    s.cascade = { from: shown, to: next, fromValue: shownValue, start: now, step, duration };
    s.counting = true;
    s.percent = next;
    setPrevious(shown);
    setCounting(true);
    setPercent(next);
    generation.current += 1;
    const token = generation.current;
    after(duration, () => {
      if (token !== generation.current) return;
      s.counting = false;
      setCounting(false);
    });
    if (haptic) haptics.tap("light");
  };

  useChartEntrance(() => update(false));
  useAutoplay(ctx.isPreview, () => update(false), { every: 2.8, delay: 2.6, intro: false });

  const delayFor = (order: number) => (percent >= previous ? Math.max(order - previous, 0) : Math.max(previous - 1 - order, 0)) * step;
  const shownValue = counting ? cascadeValue(live.current.cascade, performance.now() / 1000) : percent;
  const damping = ctx.n("damping");
  return (
    <Stage ctx={ctx} hint={["Tap for a new value", "点击更新数值"]} bottom={2}>
      <div onClick={() => update(true)} style={{ ...demoCard(), width: 280, padding: 18, display: "flex", justifyContent: "center", cursor: "pointer" }}>
        <div style={{ maxWidth: 244, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 12 }}>
          <div style={{ display: "flex", alignItems: "last baseline", gap: 8 }}>
            <div style={{ display: "flex", alignItems: "baseline", gap: 1, flex: "none" }}>
              <span style={rounded(46, 700, 55)}>{Math.round(shownValue)}</span>
              <span style={{ ...rounded(20, 700, 24), color: Palette.secondaryLabel }}>%</span>
            </div>
            <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("of new users finished onboarding", "的新用户完成了引导")}</div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            {rowsTopDown.map((row) => (
              <div key={row} style={{ display: "flex", gap: 4 }}>
                {columns.map((column) => {
                  const order = row * 10 + (row % 2 === 0 ? column : 9 - column);
                  const filled = order < percent;
                  return (
                    <div key={column} style={{ position: "relative", width: 18, height: 18, borderRadius: 5, background: Palette.labelAlpha(0.07) }}>
                      <motion.div
                        initial={false}
                        animate={{ scale: filled ? 1 : 0.01, opacity: filled ? 1 : 0 }}
                        transition={delayed(spring(0.3, damping), delayFor(order))}
                        style={{ position: "absolute", inset: 0, borderRadius: 5, background: cellColor(order) }}
                      />
                    </div>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      </div>
    </Stage>
  );
}
