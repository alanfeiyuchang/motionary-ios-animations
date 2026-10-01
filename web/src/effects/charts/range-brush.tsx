/** charts.range-brush · 直方图区间刷选 (Charts+RangeBrush.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, anim, black, spring, useAutoplay, usePan, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, card, captionSecondary, mono, rrect, smoothstep, swiftRound, sys, useChartHaptics, useNums } from "./_round2";

/** Stays per $20 bin, $40 … $560: a right-skewed distribution. */
const bins = Array.from({ length: 26 }, (_, index) => {
  const x = index;
  const main = 62 * Math.exp(-Math.pow((x - 7.5) / 4.2, 2));
  const tail = 20 * Math.exp(-Math.pow((x - 16) / 5.5, 2));
  const wiggle = 5 * Math.sin(x * 1.9) + 3 * Math.cos(x * 0.7);
  return Math.max(swiftRound(main + tail + wiggle + 6), 3);
});
const peak = Math.max(...bins);

type Grab = "low" | "high" | "band";

const PLOT_W = 268;
const PLOT_H = 132;
const presets: [number, number][] = [
  [9, 20],
  [3, 10],
  [12, 23],
  [5, 14],
];

export default function RangeBrush({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  /** 0 low, 1 high, 2 grow: the interpolated values the card draws from. */
  const v = useNums(3, [5, 14, 0]);
  const model = useRef({ low: 5, high: 14 });
  const [grab, setGrab] = useState<Grab | null>(null);
  const grabRef = useRef<Grab | null>(null);
  const grabOffset = useRef(0);
  const autoStep = useRef(0);

  const binAt = (x: number) => (x / PLOT_W) * bins.length;

  const release = () => {
    if (!grabRef.current) return;
    grabRef.current = null;
    setGrab(null);
    if (ctx.b("snap")) {
      const m = model.current;
      m.low = swiftRound(m.low);
      m.high = Math.max(swiftRound(m.high), m.low + 2);
      const s = spring(ctx.n("response"), 0.72);
      v.to(0, m.low, s);
      v.to(1, m.high, s);
    }
    haptics.tap("rigid");
  };

  const pan = usePan(
    {
      onChange: (s) => {
        const m = model.current;
        const position = binAt(s.location.x);
        if (!grabRef.current) {
          // Horizontal-first: a mostly vertical swipe is left to the page.
          if (!(Math.abs(s.translation.x) > Math.abs(s.translation.y))) return;
          const start = binAt(s.start.x);
          const reach = (26 / PLOT_W) * bins.length;
          const toLow = Math.abs(start - m.low);
          const toHigh = Math.abs(start - m.high);
          const picked: Grab = Math.min(toLow, toHigh) <= reach || start < m.low || start > m.high ? (toLow <= toHigh ? "low" : "high") : "band";
          grabOffset.current = start - m.low;
          grabRef.current = picked;
          setGrab(picked);
          haptics.tap("light");
        }
        const count = bins.length;
        let newLow = m.low;
        let newHigh = m.high;
        if (grabRef.current === "low") newLow = Math.min(Math.max(position, 0), m.high - 2);
        else if (grabRef.current === "high") newHigh = Math.max(Math.min(position, count), m.low + 2);
        else {
          const width = m.high - m.low;
          newLow = Math.min(Math.max(position - grabOffset.current, 0), count - width);
          newHigh = newLow + width;
        }
        if (swiftRound(newLow) !== swiftRound(m.low) || swiftRound(newHigh) !== swiftRound(m.high)) haptics.selection();
        m.low = newLow;
        m.high = newHigh;
        v.to(0, newLow, spring(0.16, 0.86));
        v.to(1, newHigh, spring(0.16, 0.86));
      },
      onEnd: release,
    },
    6,
  );

  /** Autoplay and the arrival play: both edges glide to the next preset, lighting bars as they pass. */
  const glide = () => {
    const preset = presets[autoStep.current % presets.length];
    autoStep.current += 1;
    model.current = { low: preset[0], high: preset[1] };
    const s = spring(ctx.n("response") * 1.5, 0.82);
    v.to(0, preset[0], s);
    v.to(1, preset[1], s);
  };

  useChartEntrance(() => v.to(2, 1, anim.easeOut(0.9)));
  useAutoplay(ctx.isPreview, glide, { every: 1.9, delay: 1.3 });

  const low = v.get(0);
  const high = v.get(1);
  const grow = v.get(2);
  const pop = ctx.n("pop");
  const coverage = (index: number) => Math.min(Math.max(Math.min(high, index + 1) - Math.max(low, index), 0), 1);
  const matching = swiftRound(bins.reduce((sum, b, i) => sum + b * coverage(i), 0));
  const price = (edge: number) => swiftRound(40 + edge * 20);
  const x = (edge: number) => PLOT_W * (edge / bins.length);

  const draw = (g: G) => {
    const count = bins.length;
    const slot = g.width / count;
    const barWidth = slot - 3;
    const room = g.height / 1.2;
    for (let index = 0; index < count; index++) {
      const st = smoothstep(0, 1, grow * 1.7 - (index / count) * 0.7);
      const lit = coverage(index);
      const height = room * (bins[index] / peak) * (1 + pop * lit) * st;
      if (height <= 0.5) continue;
      const rx = slot * index + 1.5;
      const ry = g.height - height;
      const path = rrect(rx, ry, barWidth, height, Math.min(3, height / 2));
      g.fill(path, g.primary(0.13));
      if (lit <= 0.004) continue;
      const t = index / (count - 1);
      const tint = t < 0.5 ? RGB.indigo.mixed(RGB.violet, t * 2) : RGB.violet.mixed(RGB.pink, (t - 0.5) * 2);
      g.fill(path, g.gradient(0, ry, 0, ry + height, [tint.color(lit), tint.color(lit * 0.72)]));
    }
  };

  const grabSpring = spring(0.3, 0.6);
  const handle = (edge: number, active: boolean) => (
    <div style={{ position: "absolute", left: x(edge) - 11, top: 0, width: 22, height: PLOT_H + 18 }}>
      <div style={{ position: "absolute", left: 10.25, top: 0, width: 1.5, height: PLOT_H, background: alpha(Palette.violet, 0.55) }} />
      <motion.div
        initial={false}
        animate={{ scale: active ? 1.12 : 1, boxShadow: active ? `0 5px 18px ${black(0.28)}` : `0 3px 10px ${black(0.18)}` }}
        transition={grabSpring}
        style={{
          position: "absolute",
          left: 0,
          top: PLOT_H - 17,
          width: 22,
          height: 34,
          borderRadius: 9,
          background: "#fff",
          outline: `0.5px solid ${black(0.08)}`,
          outlineOffset: -0.5,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 3,
        }}
      >
        {[0, 1].map((i) => (
          <div key={i} style={{ width: 2, height: 12, borderRadius: 1, background: alpha(Palette.violet, 0.8) }} />
        ))}
      </motion.div>
    </div>
  );

  return (
    <ChartStage ctx={ctx} hint={["Drag a handle or the band", "拖动手柄或整条区间带"]}>
      <div style={card(12)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Price per night", "每晚价格")}</div>
            <div style={{ ...sys(24, 700, true), ...mono }}>
              ${price(low)} – ${price(high)}
            </div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-end" }}>
            <div style={{ ...sys(18, 700, true), ...mono, color: Palette.violet }}>{matching}</div>
            <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t("stays", "套房源")}</div>
          </div>
        </div>
        <div {...pan} style={{ ...pan.style, position: "relative", width: PLOT_W, height: PLOT_H + 18, cursor: "ew-resize" }}>
          <Plot ctx={ctx} width={PLOT_W} height={PLOT_H} draw={draw} style={{ position: "absolute", left: 0, top: 0 }} />
          <div
            style={{
              position: "absolute",
              left: x(low),
              top: 0,
              width: Math.max(x(high) - x(low), 0),
              height: PLOT_H + 1.5,
              borderRadius: 6,
              background: alpha(Palette.violet, grab === "band" ? 0.16 : 0.09),
              transition: "background 0.3s",
              overflow: "hidden",
            }}
          >
            <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 3, borderRadius: 1.5, background: Palette.violet }} />
          </div>
          {handle(low, grab === "low" || grab === "band")}
          {handle(high, grab === "high" || grab === "band")}
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", width: PLOT_W, ...sys(10, 500), color: Palette.secondaryLabel }}>
          {[40, 170, 300, 430, 560].map((value) => (
            <span key={value}>${value}</span>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
