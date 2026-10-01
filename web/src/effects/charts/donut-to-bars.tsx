/** charts.donut-to-bars · 环形图 ⇄ 柱状图形变 (Charts+ChartMorph.swift) */
import { motion } from "motion/react";
import { useId, useRef, useState } from "react";
import { Palette, alpha, anim, delayed, demoCard, spring, textStyle, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { useAnimatedNumbers } from "./_shared";
import { BarsGlyph, FadeText, PieGlyph, Stage, SymbolSwap, captionSecondary, gradientTop, rounded } from "./_legacy";

/** Weekly sessions, in thousands. */
const data = [
  { en: "iOS", zh: "iOS", value: 4.2, color: Palette.indigo },
  { en: "Web", zh: "网页", value: 2.7, color: Palette.pink },
  { en: "Android", zh: "安卓", value: 1.9, color: Palette.amber },
  { en: "Mac", zh: "Mac", value: 1.4, color: Palette.mint },
  { en: "Other", zh: "其他", value: 0.9, color: Palette.sky },
];
const total = data.reduce((a, d) => a + d.value, 0);
const maxValue = Math.max(...data.map((d) => d.value));
const W = 264;
const H = 200;
const BASELINE = 0.94;
const SAMPLES = 24;
const SLOT = W / data.length;

const barTop = (height: number) => H * BASELINE - height * H * 0.72;

/** One segment between a donut arc (progress 0) and a bar (progress 1), both outlines sampled alike. */
function segmentPath(progress: number, start: number, end: number, slot: number, height: number): string {
  const t = Math.min(Math.max(progress, -0.08), 1.08);
  const cx = W / 2;
  const cy = H / 2;
  const outerR = Math.min(W, H) * 0.46;
  const innerR = outerR * 0.6;
  const gap = 0.008;
  const a0 = (start + gap) * 2 * Math.PI - Math.PI / 2;
  const a1 = (end - gap) * 2 * Math.PI - Math.PI / 2;
  const barWidth = SLOT * 0.58;
  const x0 = SLOT * slot + (SLOT - barWidth) / 2;
  const bottom = H * BASELINE;
  const top = barTop(height);
  const corner = Math.min(6, barWidth / 2, Math.max(bottom - top, 0));
  const pts: string[] = [];
  const lerp = (a: number, b: number) => a + (b - a) * t;
  for (let k = 0; k <= SAMPLES; k++) {
    const u = k / SAMPLES;
    const angle = a0 + (a1 - a0) * u;
    const x = barWidth * u;
    const edge = Math.min(x, barWidth - x);
    const drop = edge < corner ? corner - Math.sqrt(corner * corner - (corner - edge) * (corner - edge)) : 0;
    pts.push(`${lerp(cx + outerR * Math.cos(angle), x0 + x).toFixed(2)},${lerp(cy + outerR * Math.sin(angle), top + drop).toFixed(2)}`);
  }
  for (let k = SAMPLES; k >= 0; k--) {
    const u = k / SAMPLES;
    const angle = a0 + (a1 - a0) * u;
    pts.push(`${lerp(cx + innerR * Math.cos(angle), x0 + barWidth * u).toFixed(2)},${lerp(cy + innerR * Math.sin(angle), bottom).toFixed(2)}`);
  }
  return `M${pts.join(" L")} Z`;
}

export default function DonutToBars({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const [isBars, setIsBars] = useState(false);
  const isBarsRef = useRef(false);
  const progress = useAnimatedNumbers(data.length, 0);

  const toggle = () => {
    const next = !isBarsRef.current;
    isBarsRef.current = next;
    setIsBars(next);
    const sp = spring(ctx.n("response"), ctx.n("damping"));
    data.forEach((_, index) => progress.to(index, next ? 1 : 0, delayed(sp, (next ? index : data.length - 1 - index) * ctx.n("stagger"))));
    haptics.tap("light");
  };

  useAutoplay(ctx.isPreview, toggle, { every: 2.4, delay: 1.0 });

  let start = 0;
  return (
    <Stage ctx={ctx} hint={["Tap to switch chart type", "点击切换图表类型"]} cue>
      <div onClick={toggle} style={{ ...demoCard(), padding: 18, display: "flex", flexDirection: "column", gap: 12, cursor: "pointer" }}>
        <div style={{ width: W, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={captionSecondary}>{ctx.t("Sessions by platform", "各平台会话")}</div>
            <FadeText text={isBars ? ctx.t("Bars", "柱状图") : ctx.t("Donut", "环形图")} style={textStyle.headline} />
          </div>
          <div style={{ width: 34, height: 34, borderRadius: "50%", background: alpha(Palette.indigo, 0.12), color: Palette.indigo, display: "grid", placeItems: "center" }}>
            <SymbolSwap id={isBars ? "bars" : "pie"} size={19}>
              {isBars ? <BarsGlyph size={18} /> : <PieGlyph size={19} />}
            </SymbolSwap>
          </div>
        </div>
        <div style={{ position: "relative", width: W, height: H }}>
          <motion.div
            initial={false}
            animate={{ opacity: isBars ? 1 : 0 }}
            transition={delayed(anim.easeInOut(0.3), isBars ? 0.25 : 0)}
            style={{ position: "absolute", left: 0, width: W, top: H * BASELINE - 1, height: 1, background: Palette.labelAlpha(0.12) }}
          />
          <svg width={W} height={H} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <defs>
              {data.map((d, i) => (
                <linearGradient key={i} id={`${uid}g${i}`} x1="0" y1="0" x2="0" y2={H} gradientUnits="userSpaceOnUse">
                  <stop offset="0" stopColor={gradientTop(d.color)} />
                  <stop offset="1" stopColor={d.color} />
                </linearGradient>
              ))}
            </defs>
            {data.map((d, index) => {
              const from = start;
              start += d.value / total;
              return <path key={index} d={segmentPath(progress.get(index), from, start, index, d.value / maxValue)} fill={`url(#${uid}g${index})`} />;
            })}
          </svg>
          <motion.div
            initial={false}
            animate={{ scale: isBars ? 0.7 : 1, opacity: isBars ? 0 : 1 }}
            transition={delayed(spring(0.4, 0.85), isBars ? 0 : 0.3)}
            style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}
          >
            <div style={rounded(26, 700, 31)}>{total.toFixed(1)}k</div>
            <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t("sessions this week", "本周会话")}</div>
          </motion.div>
          {data.map((d, index) => (
            <motion.div
              key={index}
              initial={false}
              animate={{ opacity: isBars ? 1 : 0, y: isBars ? 0 : 8 }}
              transition={delayed(spring(0.45, 0.8), isBars ? 0.3 + index * ctx.n("stagger") : 0)}
              style={{ position: "absolute", left: SLOT * index, top: barTop(d.value / maxValue) - 30, width: SLOT, display: "flex", flexDirection: "column", alignItems: "center", gap: 1 }}
            >
              <div style={rounded(11, 700, 13)}>{d.value.toFixed(1)}k</div>
              <div style={{ fontSize: 9, lineHeight: "11px", fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(d.en, d.zh)}</div>
            </motion.div>
          ))}
        </div>
      </div>
    </Stage>
  );
}
