/** charts.range-morph · 时间区间折线形变 (Charts+RangeMorph.swift) */
import { motion } from "motion/react";
import { useId, useRef, useState } from "react";
import { NumericText, Palette, alpha, black, clamp, demoCard, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { ChartTapCue, useAnimatedNumbers } from "./_shared";
import { SymbolSwap, Triangle, captionSecondary, rounded } from "./_legacy";

function makeSeries(seed: number, trend: number, wiggle: number): number[] {
  const count = 36;
  const raw = Array.from({ length: count }, (_, index) => {
    const x = index / (count - 1);
    const noise = Math.sin(x * 9 + seed) * 0.6 + Math.sin(x * 23 + seed * 2.1) * 0.25 + Math.sin(x * 47 + seed * 0.7) * 0.12;
    return trend * x + wiggle * noise;
  });
  const low = Math.min(...raw);
  const high = Math.max(...raw);
  const span = Math.max(high - low, 0.0001);
  return raw.map((v) => 0.08 + (0.84 * (v - low)) / span);
}

const rangeData = [
  { en: "1D", zh: "1天", values: makeSeries(1.3, 0.5, 0.55), change: 1.26, price: 182.4 },
  { en: "1W", zh: "1周", values: makeSeries(4.1, -0.9, 0.45), change: -2.14, price: 178.91 },
  { en: "1M", zh: "1月", values: makeSeries(2.7, 1.3, 0.5), change: 8.72, price: 186.35 },
  { en: "1Y", zh: "1年", values: makeSeries(5.9, 2.2, 0.6), change: 41.3, price: 204.18 },
];

const W = 264;
const H = 150;
const INSET = 10;
const COUNT = 36;
const SEG = (W - 6 - 4 * 3) / 4;

export default function RangeMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const [selection, setSelection] = useState(0);
  const selectionRef = useRef(0);
  // The 36 samples plus the tone (1 green … 0 red), all on the same spring.
  const vector = useAnimatedNumbers(COUNT + 1, [...rangeData[0].values, 1]);

  /** Pills and autoplay share this; the haptic is muted inside autoplay, so only real taps tick. */
  const select = (index: number) => {
    if (index === selectionRef.current) return;
    haptics.selection();
    selectionRef.current = index;
    const sp = spring(ctx.n("response"), ctx.n("damping"));
    rangeData[index].values.forEach((v, i) => vector.to(i, v, sp));
    vector.to(COUNT, rangeData[index].change >= 0 ? 1 : 0, sp);
    setSelection(index);
  };

  useAutoplay(ctx.isPreview, () => select((selectionRef.current + 1) % rangeData.length), { every: 1.8, delay: 0.8 });

  const data = rangeData[selection];
  const up = data.change >= 0;
  const pillTint = up ? Palette.green : Palette.red;

  // Green (1) ⇄ red (0), blended in sRGB so the colour travels with the spring.
  const all = vector.all();
  const tone = clamp(all[COUNT]);
  const tint = `rgb(${Math.round(0xff + (0x34 - 0xff) * tone)} ${Math.round(0x4d + (0xc7 - 0x4d) * tone)} ${Math.round(0x5e + (0x7b - 0x5e) * tone)})`;
  const plotW = W - INSET;
  const plotH = H - INSET * 2;
  const step = plotW / (COUNT - 1);
  const pts = all.slice(0, COUNT).map((v, i) => ({ x: i * step, y: INSET + plotH * (1 - v) }));
  // Quadratic curves through midpoints: smooth, never overshoots the data.
  let line = `M${pts[0].x},${pts[0].y.toFixed(2)}`;
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1];
    const b = pts[i];
    line += ` Q${a.x.toFixed(2)},${a.y.toFixed(2)} ${((a.x + b.x) / 2).toFixed(2)},${((a.y + b.y) / 2).toFixed(2)}`;
  }
  const last = pts[pts.length - 1];
  line += ` L${last.x.toFixed(2)},${last.y.toFixed(2)}`;

  const sp = spring(ctx.n("response"), ctx.n("damping"));
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ ...demoCard(), width: 300, padding: 18, display: "flex", flexDirection: "column", gap: 12 }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={captionSecondary}>{ctx.t("Motion Labs · MLX", "动效科技 · MLX")}</div>
            <NumericText value={data.price} text={`$${data.price.toFixed(2)}`} style={rounded(26, 700, 31)} />
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 3, padding: "5px 9px", borderRadius: 999, background: alpha(pillTint, 0.14), color: pillTint, ...rounded(13, 600, 16), transition: "color 0.3s, background-color 0.3s" }}>
            <SymbolSwap id={up ? "up" : "down"} size={9}>
              <Triangle up={up} size={9} />
            </SymbolSwap>
            <NumericText value={data.change} text={`${Math.abs(data.change).toFixed(2)}%`} />
          </div>
        </div>
        <svg width={W} height={H} style={{ display: "block" }}>
          <defs>
            <linearGradient id={`${uid}a`} x1="0" y1="0" x2="0" y2={H} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={tint} stopOpacity={0.28} />
              <stop offset="1" stopColor={tint} stopOpacity={0} />
            </linearGradient>
          </defs>
          <path d={`${line} L${plotW},${H} L0,${H} Z`} fill={`url(#${uid}a)`} />
          {ctx.b("baseline") && <line x1={0} x2={W} y1={pts[0].y} y2={pts[0].y} stroke={Palette.secondaryLabel} strokeOpacity={0.6} strokeWidth={1} strokeDasharray="3 4" />}
          <path d={line} fill="none" stroke={tint} strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" />
          <circle cx={last.x} cy={last.y} r={9} fill={tint} fillOpacity={0.22} />
          <circle cx={last.x} cy={last.y} r={4} fill={tint} />
        </svg>
        <div style={{ position: "relative", display: "flex", gap: 4, padding: 3, borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
          <motion.div
            initial={false}
            animate={{ x: selection * (SEG + 4) }}
            transition={sp}
            style={{ position: "absolute", left: 3, top: 3, width: SEG, height: 30, borderRadius: 15, background: Palette.elevated, boxShadow: `0 2px 8px ${black(0.12)}` }}
          />
          {rangeData.map((r, index) => (
            <button
              key={index}
              type="button"
              onClick={() => select(index)}
              style={{ position: "relative", width: SEG, height: 30, fontSize: 13, lineHeight: "18px", fontWeight: 600, color: index === selection ? Palette.label : Palette.secondaryLabel, transition: "color 0.25s", cursor: "pointer" }}
            >
              {ctx.t(r.en, r.zh)}
            </button>
          ))}
        </div>
      </div>
      <ChartTapCue ctx={ctx} en="Switch the time range" zh="切换时间区间" style={{ position: "absolute", left: 0, right: 0, bottom: 8 }} />
    </div>
  );
}
