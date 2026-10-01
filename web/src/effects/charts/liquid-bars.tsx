/** charts.liquid-bars · 液体柱状图 (Charts+LiquidBars.swift) */
import { useId, useRef, useState } from "react";
import { NumericText, Palette, delayed, demoCard, spring, useAutoplay, useClock, useHaptics, white, type DemoProps } from "../../kit";
import { randomIn, useAnimatedNumbers, useChartEntrance } from "./_shared";
import { Stage, captionSecondary, rounded } from "./_legacy";

const daysEN = ["M", "T", "W", "T", "F", "S", "S"];
const daysZH = ["一", "二", "三", "四", "五", "六", "日"];
const TW = 28;
const TH = 170;

/** `LiquidSurface`: everything below a travelling sine surface. */
function surfacePath(level: number, phase: number, amplitude: number): string {
  const surface = TH - TH * Math.min(Math.max(level, 0), 1.05);
  const wavelength = TW * 1.6;
  let d = `M0,${TH}`;
  for (let x = 0; x <= TW; x += 2) d += ` L${x},${(surface + amplitude * Math.sin((x / wavelength) * 2 * Math.PI + phase)).toFixed(2)}`;
  return `${d} L${TW},${surface.toFixed(2)} L${TW},${TH} Z`;
}

export default function LiquidBars({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const levels = useAnimatedNumbers(7, 0);
  const [targets, setTargets] = useState<number[]>(() => new Array(7).fill(0));
  const kick = useRef(-1e9);
  useClock(true, ctx.isPreview ? 30 : undefined);
  const now = performance.now() / 1000;

  const refill = (haptic: boolean) => {
    kick.current = performance.now() / 1000;
    const stagger = ctx.n("stagger");
    const sp = spring(0.9, ctx.n("damping"));
    const next = Array.from({ length: 7 }, () => randomIn(0.25, 0.95));
    next.forEach((level, index) => levels.to(index, level, delayed(sp, index * stagger)));
    setTargets(next);
    if (haptic) haptics.tap("soft");
  };

  useChartEntrance(() => refill(false));
  useAutoplay(ctx.isPreview, () => refill(false), { every: 3.0, delay: 3.0, intro: false });

  const since = Math.max(now - kick.current, 0);
  const amplitude = Math.max(1.5, ctx.n("wave") * Math.exp(-since * 2.5));
  const total = targets.reduce((a, b) => a + b, 0) * 3;
  const labels = ctx.lang === "zh" ? daysZH : daysEN;
  return (
    <Stage ctx={ctx} hint={["Tap to pour new data", "点击倒入新数据"]} bottom={6}>
      <div onClick={() => refill(true)} style={{ ...demoCard(), width: 300, padding: 18, display: "flex", flexDirection: "column", gap: 12, cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={captionSecondary}>{ctx.t("Water intake", "每日饮水")}</div>
          <NumericText value={total} text={`${total.toFixed(1)} L`} style={rounded(20, 700, 24)} />
        </div>
        <div style={{ height: 214, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 10 }}>
            {labels.map((label, index) => (
              <div key={index} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
                <NumericText value={targets[index]} text={(targets[index] * 3).toFixed(1)} style={{ ...rounded(9, 600, 11), color: Palette.secondaryLabel }} />
                <div style={{ position: "relative", width: TW, height: TH, borderRadius: TW / 2, overflow: "hidden", background: Palette.labelAlpha(0.05) }}>
                  <svg width={TW} height={TH} style={{ position: "absolute", inset: 0 }}>
                    <defs>
                      <linearGradient id={`${uid}l`} x1="0" y1="0" x2="0" y2={TH} gradientUnits="userSpaceOnUse">
                        <stop offset="0" stopColor={Palette.sky} />
                        <stop offset="1" stopColor={Palette.blue} />
                      </linearGradient>
                    </defs>
                    <path d={surfacePath(levels.get(index), now * 3 + index * 0.9, amplitude)} fill={`url(#${uid}l)`} />
                  </svg>
                  <div style={{ position: "absolute", left: TW / 2 - 4 - 7, top: 6, width: 8, height: TH - 12, borderRadius: 4, background: `linear-gradient(90deg, ${white(0.35)}, ${white(0)} 50%)` }} />
                  <div style={{ position: "absolute", inset: 0, borderRadius: TW / 2, boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.12)}` }} />
                </div>
                <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </Stage>
  );
}
