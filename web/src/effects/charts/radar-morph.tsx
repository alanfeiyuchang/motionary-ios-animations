/** charts.radar-morph · 雷达图形变 (Charts+Radar.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { ChartTapCue, useAnimatedNumbers } from "./_shared";
import { useThumb } from "./_legacy";

const datasets = [
  { name: "v1.0", color: Palette.indigo, values: [0.55, 0.4, 0.7, 0.45, 0.6, 0.35] },
  { name: "v2.0", color: Palette.pink, values: [0.75, 0.68, 0.5, 0.82, 0.55, 0.62] },
  { name: "v3.0", color: Palette.mint, values: [0.92, 0.85, 0.88, 0.7, 0.95, 0.9] },
];
const axes: [string, string][] = [
  ["Speed", "速度"],
  ["Craft", "质感"],
  ["Motion", "动效"],
  ["Clarity", "清晰"],
  ["Delight", "愉悦"],
  ["Access", "无障碍"],
];
const SIZE = 196;
const PAD = 24;
const C = PAD + SIZE / 2;

function point(index: number, count: number, radius: number) {
  const angle = -Math.PI / 2 + (2 * Math.PI * index) / count;
  return { x: C + Math.cos(angle) * radius, y: C + Math.sin(angle) * radius };
}

const polygon = (values: number[]) =>
  values
    .map((v, i) => {
      const p = point(i, values.length, (SIZE / 2) * Math.max(v, 0));
      return `${i === 0 ? "M" : "L"}${p.x.toFixed(2)},${p.y.toFixed(2)}`;
    })
    .join(" ") + " Z";

export default function RadarMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selection, setSelection] = useState(0);
  const selectionRef = useRef(0);
  const values = useAnimatedNumbers(6, datasets[0].values);
  const thumb = useThumb(selection);

  /** Pills and autoplay share this; the haptic is muted inside autoplay, so only real taps tick. */
  const select = (index: number) => {
    if (index !== selectionRef.current) haptics.selection();
    selectionRef.current = index;
    const sp = spring(ctx.n("response"), ctx.n("damping"));
    datasets[index].values.forEach((v, i) => values.to(i, v, sp));
    setSelection(index);
  };

  useAutoplay(ctx.isPreview, () => select((selectionRef.current + 1) % datasets.length), { every: 1.8 });

  const sp = spring(ctx.n("response"), ctx.n("damping"));
  const dataset = datasets[selection];
  const current = values.all();
  const shape = polygon(current);
  const side = SIZE + PAD * 2;
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 20 }}>
      <div style={{ position: "relative", width: side, height: side, flex: "none" }}>
        <svg width={side} height={side} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
          {[1, 2, 3, 4].map((level) => (
            <path key={level} d={polygon(new Array(axes.length).fill(level / 4))} fill="none" stroke={Palette.labelAlpha(level === 4 ? 0.12 : 0.08)} strokeWidth={1} />
          ))}
          {axes.map((_, index) => {
            const p = point(index, axes.length, SIZE / 2);
            return <line key={index} x1={C} y1={C} x2={p.x} y2={p.y} stroke={Palette.labelAlpha(0.08)} strokeWidth={1} />;
          })}
          <motion.path d={shape} initial={false} animate={{ fill: alpha(dataset.color, 0.25) }} transition={sp} />
          <motion.path d={shape} fill="none" strokeWidth={2} strokeLinejoin="round" initial={false} animate={{ stroke: dataset.color }} transition={sp} />
          {ctx.b("dots") && (
            <motion.g initial={false} animate={{ fill: dataset.color, filter: `drop-shadow(0px 0px 3px ${alpha(dataset.color, 0.5)})` }} transition={sp}>
              {current.map((v, index) => {
                const p = point(index, current.length, (SIZE / 2) * Math.max(v, 0));
                return <circle key={index} cx={p.x} cy={p.y} r={3.5} />;
              })}
            </motion.g>
          )}
        </svg>
        {axes.map(([en, zh], index) => {
          const p = point(index, axes.length, SIZE / 2 + 18);
          return (
            <div key={index} style={{ position: "absolute", left: p.x, top: p.y, transform: "translate(-50%, -50%)", fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
              {ctx.t(en, zh)}
            </div>
          );
        })}
      </div>
      <div style={{ position: "relative", display: "flex", gap: 4, padding: 4, borderRadius: 999, background: Palette.surface, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, flex: "none" }}>
        {thumb.frame && (
          <motion.div
            initial={false}
            animate={{ x: thumb.frame.x, width: thumb.frame.width, backgroundColor: dataset.color }}
            transition={sp}
            style={{ position: "absolute", left: 0, top: thumb.frame.y, height: thumb.frame.height, borderRadius: 999, backgroundImage: `linear-gradient(180deg, ${white(0.18)}, ${white(0)})` }}
          />
        )}
        {datasets.map((d, index) => (
          <button
            key={index}
            type="button"
            ref={thumb.ref(index)}
            onClick={() => select(index)}
            style={{ position: "relative", padding: "8px 16px", fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap", color: selection === index ? "#fff" : Palette.label, transition: "color 0.25s", cursor: "pointer" }}
          >
            {d.name}
          </button>
        ))}
      </div>
      <ChartTapCue ctx={ctx} en="Pick a product to compare" zh="选择产品进行对比" />
    </div>
  );
}
