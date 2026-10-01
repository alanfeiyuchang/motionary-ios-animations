/** charts.brick-bars · 积木堆叠柱状图 (Charts+BrickBars.swift) */
import { motion, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, anim, delayed, demoCard, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { randomInt, useChartEntrance } from "./_shared";
import { Stage, captionSecondary, mixColor, rounded } from "./_legacy";

const ROWS = 10;
const COLUMNS = 7;
const rowsTopDown = Array.from({ length: ROWS }, (_, i) => ROWS - 1 - i);

function brickColor(t: number): string {
  if (t < 0.5) return mixColor(Palette.mint, Palette.sky, t * 2);
  return mixColor(Palette.sky, Palette.indigo, (t - 0.5) * 2);
}

/** `shown` + `dropping`: bricks sit in place, are falling out, or wait (invisible) above the chart. */
type Phase = "shown" | "dropping" | "parked";

export default function BrickBars({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [counts, setCounts] = useState([5, 8, 6, 10, 7, 4, 9]);
  const [phase, setPhase] = useState<Phase>("parked");
  const generation = useRef(0);

  const play = (haptic: boolean) => {
    setPhase("dropping");
    if (haptic) haptics.tap("light");
    generation.current += 1;
    const current = generation.current;
    after(0.22, () => {
      if (current !== generation.current) return;
      // Park the (invisible) bricks above the chart in a separate, unanimated update…
      setCounts(Array.from({ length: COLUMNS }, () => randomInt(3, ROWS)));
      setPhase("parked");
      after(0.03, () => {
        if (current !== generation.current) return;
        // …so they rain in from there.
        setPhase("shown");
      });
    });
  };

  useChartEntrance(() => play(false));
  useAutoplay(ctx.isPreview, () => play(false), { every: 3.4, delay: 3.4, intro: false });

  const shown = phase === "shown";
  const total = counts.reduce((a, b) => a + b, 0);
  const columnDelay = ctx.n("columnDelay");
  const rowDelay = ctx.n("rowDelay");
  const damping = ctx.n("damping");
  return (
    <Stage ctx={ctx} hint={["Tap to rebuild", "点击重新搭建"]} bottom={6}>
      <div onClick={() => play(true)} style={{ ...demoCard(), width: 300, padding: 18, display: "flex", flexDirection: "column", gap: 14, cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={captionSecondary}>{ctx.t("Tasks shipped", "本周完成任务")}</div>
          <NumericText value={shown ? total : 0} style={rounded(22, 700, 26)} />
        </div>
        <div style={{ display: "flex", justifyContent: "center", alignItems: "flex-end", gap: 5 }}>
          {Array.from({ length: COLUMNS }, (_, column) => (
            <div key={column} style={{ display: "flex", flexDirection: "column", gap: 5 }}>
              {rowsTopDown.map((row) => {
                const visible = row < counts[column] && shown;
                const motionFor: Transition = shown
                  ? delayed(spring(0.5, damping), column * columnDelay + row * rowDelay)
                  : phase === "dropping"
                    ? anim.easeIn(0.18)
                    : { duration: 0 };
                return (
                  <div key={row} style={{ position: "relative", width: 30, height: 16, borderRadius: 5, background: Palette.labelAlpha(0.06) }}>
                    <motion.div
                      initial={false}
                      animate={{ y: visible ? 0 : phase === "dropping" ? 14 : -220, opacity: visible ? 1 : 0 }}
                      transition={motionFor}
                      style={{ position: "absolute", inset: 0, borderRadius: 5, background: brickColor(row / (ROWS - 1)) }}
                    />
                  </div>
                );
              })}
            </div>
          ))}
        </div>
      </div>
    </Stage>
  );
}
