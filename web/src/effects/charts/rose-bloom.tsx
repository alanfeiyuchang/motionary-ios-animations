/** charts.rose-bloom · 南丁格尔玫瑰图绽放 (Charts+RoseBloom.swift) */
import { motion } from "motion/react";
import { useId, useRef, useState } from "react";
import { NumericText, Palette, delayed, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { randomIn, useAnimatedNumbers, useChartEntrance } from "./_shared";
import { Stage, captionSecondary, gradientTop, mixColor, rounded } from "./_legacy";

const HOLE = 22;
const MAX = 118;
const SIDE = 280;
const C = SIDE / 2;
const monthsEN = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"];
const monthsZH = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"];

function petalPath(radius: number, index: number): string {
  const gap = 1.25;
  const start = ((-90 + index * 30 + gap) * Math.PI) / 180;
  const end = ((-90 + (index + 1) * 30 - gap) * Math.PI) / 180;
  const outer = Math.max(radius, HOLE + 0.5);
  const p = (r: number, a: number) => `${(C + r * Math.cos(a)).toFixed(2)},${(C + r * Math.sin(a)).toFixed(2)}`;
  return `M${p(outer, start)} A${outer.toFixed(2)},${outer.toFixed(2)} 0 0 1 ${p(outer, end)} L${p(HOLE, end)} A${HOLE},${HOLE} 0 0 0 ${p(HOLE, start)} Z`;
}

function petalColor(t: number): string {
  if (t < 0.5) return mixColor(Palette.sky, Palette.indigo, t * 2);
  return mixColor(Palette.indigo, Palette.violet, (t - 0.5) * 2);
}

export default function RoseBloom({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const values = useAnimatedNumbers(12, 0);
  const first = useRef(true);
  const [year, setYear] = useState(2021);
  const [turned, setTurned] = useState(false);

  const load = (haptic: boolean) => {
    const sp = spring(0.7, ctx.n("damping"));
    const stagger = ctx.n("stagger");
    // Wetter winters, drier summers, plus noise.
    for (let index = 0; index < 12; index++) {
      const seasonal = 0.55 + 0.3 * Math.cos((index / 12) * 2 * Math.PI);
      values.to(index, Math.min(Math.max(seasonal + randomIn(-0.22, 0.22), 0.12), 1), delayed(sp, index * stagger));
    }
    if (!first.current) setYear((y) => (y >= 2025 ? 2021 : y + 1));
    first.current = false;
    setTurned(true);
    if (haptic) haptics.tap("light");
  };

  useChartEntrance(() => load(false));
  useAutoplay(ctx.isPreview, () => load(false), { every: 2.8, delay: 2.8, intro: false });

  const labels = ctx.lang === "zh" ? monthsZH : monthsEN;
  return (
    <Stage ctx={ctx} hint={["Tap for another year", "点击切换年份"]} bottom={2}>
      <div onClick={() => load(true)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, cursor: "pointer" }}>
        <div style={{ width: 280, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={captionSecondary}>{ctx.t("Monthly rainfall", "月降雨量")}</div>
          <NumericText value={year} style={rounded(18, 700, 22)} />
        </div>
        <motion.div
          initial={false}
          animate={{ rotate: ctx.b("twist") && !turned ? -20 : 0 }}
          transition={spring(0.7, ctx.n("damping"))}
          style={{ position: "relative", width: SIDE, height: SIDE }}
        >
          <svg width={SIDE} height={SIDE} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <defs>
              {labels.map((_, index) => {
                const color = petalColor(index / 11);
                return (
                  <linearGradient key={index} id={`${uid}g${index}`} x1="0" y1="0" x2="0" y2={SIDE} gradientUnits="userSpaceOnUse">
                    <stop offset="0" stopColor={gradientTop(color)} />
                    <stop offset="1" stopColor={color} />
                  </linearGradient>
                );
              })}
            </defs>
            {labels.map((_, index) => (
              <path key={index} d={petalPath(HOLE + (MAX - HOLE) * values.get(index), index)} fill={`url(#${uid}g${index})`} />
            ))}
          </svg>
          {labels.map((label, index) => {
            const radians = ((-90 + (index + 0.5) * 30) * Math.PI) / 180;
            return (
              <div
                key={index}
                style={{ position: "absolute", left: C + 132 * Math.cos(radians), top: C + 132 * Math.sin(radians), transform: "translate(-50%, -50%)", ...rounded(10, 600, 12), color: Palette.secondaryLabel }}
              >
                {label}
              </div>
            );
          })}
        </motion.div>
      </div>
    </Stage>
  );
}
