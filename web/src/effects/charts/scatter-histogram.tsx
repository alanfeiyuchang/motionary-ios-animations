/** charts.scatter-histogram · 散点图 ⇄ 直方图 (Charts+ScatterHistogram.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, anim, delayed, demoCard, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Stage, captionSecondary, mixColor } from "./_legacy";

interface ScatterDot {
  id: number;
  x: number;
  y: number;
  bin: number;
  stack: number;
}

const BINS = 6;
const W = 270;
const H = 180;

/** Deterministic dataset (the app's 64-bit LCG): price roughly bell-shaped, rating loosely correlated with price. */
const dots: ScatterDot[] = (() => {
  const mask = (1n << 64n) - 1n;
  let state = 0x2545f4914f6cdd1dn;
  const next = () => {
    state = (state * 6364136223846793005n + 1442695040888963407n) & mask;
    return Number((state >> 33n) & 0xffffffn) / 0xffffff;
  };
  const raw: { x: number; y: number }[] = [];
  for (let i = 0; i < 42; i++) {
    const a = next();
    const b = next();
    const c = next();
    const x = Math.min(Math.max((a + b + c) / 3, 0.02), 0.98);
    const jitter = (next() - 0.5) * 0.45;
    const trend = 0.25 + x * 0.45;
    raw.push({ x, y: Math.min(Math.max(trend + jitter, 0.05), 0.95) });
  }
  const counts = new Array<number>(BINS).fill(0);
  const out: ScatterDot[] = [];
  const order = raw.map((_, i) => i).sort((p, q) => raw[p].y - raw[q].y);
  for (const index of order) {
    const bin = Math.min(Math.floor(raw[index].x * BINS), BINS - 1);
    out.push({ id: index, x: raw[index].x, y: raw[index].y, bin, stack: counts[bin] });
    counts[bin] += 1;
  }
  return out.sort((p, q) => p.id - q.id);
})();

function dotColor(bin: number): string {
  const t = bin / (BINS - 1);
  if (t < 0.5) return mixColor(Palette.mint, Palette.sky, t * 2);
  return mixColor(Palette.indigo, Palette.violet, (t - 0.5) * 2);
}

export default function ScatterHistogram({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [binned, setBinned] = useState(false);
  const binnedRef = useRef(false);

  const toggle = (haptic: boolean) => {
    binnedRef.current = !binnedRef.current;
    setBinned(binnedRef.current);
    if (haptic) haptics.tap("light");
  };

  useAutoplay(ctx.isPreview, () => toggle(false), { every: 2.8, delay: 1.0 });

  const binWidth = W / BINS;
  const fade = anim.easeInOut(0.35);
  return (
    <Stage ctx={ctx} hint={["Tap to bin the dots", "点击将散点分箱"]} cue>
      <div onClick={() => toggle(true)} style={{ ...demoCard(), padding: 15, display: "flex", flexDirection: "column", gap: 10, cursor: "pointer" }}>
        <div style={{ width: W, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "grid", ...captionSecondary }}>
            <motion.span initial={false} animate={{ opacity: binned ? 0 : 1 }} transition={fade} style={{ gridArea: "1 / 1" }}>
              {ctx.t("Rating", "评分")}
            </motion.span>
            <motion.span initial={false} animate={{ opacity: binned ? 1 : 0 }} transition={fade} style={{ gridArea: "1 / 1" }}>
              {ctx.t("Count", "数量")}
            </motion.span>
          </div>
          <div style={captionSecondary}>{ctx.t("Price →", "价格 →")}</div>
        </div>
        <div style={{ position: "relative", width: W, height: H }}>
          {[0, 1, 2, 3].map((i) => (
            <div key={i} style={{ position: "absolute", left: 0, width: W, top: (H / 4) * i, height: 1, background: Palette.labelAlpha(0.12) }} />
          ))}
          <motion.div initial={false} animate={{ opacity: binned ? 1 : 0 }} transition={anim.easeInOut(0.4)} style={{ position: "absolute", inset: 0, display: "flex" }}>
            {Array.from({ length: BINS }, (_, index) => (
              <div key={index} style={{ flex: 1, background: Palette.labelAlpha(index % 2 === 0 ? 0.04 : 0) }} />
            ))}
          </motion.div>
          <motion.svg width={W} height={H} initial={false} animate={{ opacity: binned ? 0 : 1 }} transition={anim.easeInOut(0.3)} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <line x1={0} y1={H * (1 - 0.25)} x2={W} y2={H * (1 - 0.7)} stroke={alpha(Palette.indigo, 0.45)} strokeWidth={2} strokeLinecap="round" strokeDasharray="5 5" />
          </motion.svg>
          {dots.map((dot) => {
            const x = binned ? binWidth * (dot.bin + 0.5) + ((dot.stack % 3) - 1) * 11 : dot.x * W;
            const y = binned ? H - 6 - Math.floor(dot.stack / 3) * 11 : H * (1 - dot.y);
            return (
              <motion.div
                key={dot.id}
                initial={false}
                animate={{ x: x - 5, y: y - 5 }}
                transition={delayed(spring(0.6, ctx.n("damping")), dot.stack * ctx.n("stackDelay") + dot.bin * 0.02)}
                style={{ position: "absolute", left: 0, top: 0, width: 10, height: 10, borderRadius: "50%", background: dotColor(dot.bin), boxShadow: `inset 0 0 0 1px ${white(0.5)}` }}
              />
            );
          })}
          <div style={{ position: "absolute", left: 0, bottom: 0, width: W, height: 1, background: Palette.labelAlpha(0.2) }} />
        </div>
      </div>
    </Stage>
  );
}
