/** charts.bars-to-line · 柱状图 ⇄ 折线图形变 (Charts+BarsToLine.swift) */
import { motion } from "motion/react";
import { useId, useRef, useState } from "react";
import { Palette, alpha, anim, delayed, demoCard, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { useAnimatedNumbers } from "./_shared";
import { BarsGlyph, FadeText, LineGlyph, Stage, SymbolSwap, captionSecondary } from "./_legacy";

const values = [0.42, 0.55, 0.48, 0.7, 0.62, 0.84, 0.76, 0.92];
const monthsEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"];
const monthsZH = ["1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月"];
const W = 264;
const H = 170;

const point = (index: number) => ({ x: (W / values.length) * (index + 0.5), y: H * (1 - values[index]) });
const linePath = values.map((_, i) => `${i === 0 ? "M" : "L"}${point(i).x},${point(i).y}`).join(" ");
const areaPath = `${linePath} L${point(values.length - 1).x},${H} L${point(0).x},${H} Z`;

export default function BarsToLine({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const { after } = useTimeouts();
  const [toLine, setToLine] = useState(false);
  const toLineRef = useRef(false);
  const drawn = useAnimatedNumbers(1, 0);
  const busy = useRef(false);

  const toggle = (haptic: boolean) => {
    if (busy.current) return;
    busy.current = true;
    if (haptic) haptics.tap("light");
    const stagger = ctx.n("stagger");
    const settle = 0.35 + values.length * stagger;
    if (!toLineRef.current) {
      toLineRef.current = true;
      setToLine(true);
      drawn.to(0, 1, delayed(anim.easeInOut(ctx.n("draw")), settle));
    } else {
      drawn.to(0, 0, anim.easeInOut(0.4));
      toLineRef.current = false;
      setToLine(false);
    }
    after(settle + 0.2, () => (busy.current = false));
  };

  useAutoplay(ctx.isPreview, () => toggle(false), { every: 2.6, delay: 1.0 });

  const stagger = ctx.n("stagger");
  const d = drawn.get(0);
  const labels = ctx.lang === "zh" ? monthsZH : monthsEN;
  return (
    <Stage ctx={ctx} hint={["Tap to switch chart type", "点击切换图表类型"]} bottom={6} cue>
      <div onClick={() => toggle(true)} style={{ ...demoCard(), padding: 18, display: "flex", flexDirection: "column", gap: 12, cursor: "pointer" }}>
        <div style={{ width: W, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={captionSecondary}>{ctx.t("Monthly revenue", "月度营收")}</div>
          <div style={{ display: "flex", alignItems: "center", gap: 4, padding: "5px 10px", borderRadius: 999, background: alpha(Palette.indigo, 0.12), color: Palette.indigo, fontSize: 12, lineHeight: "16px", fontWeight: 700 }}>
            <SymbolSwap id={toLine ? "line" : "bars"} size={13}>
              {toLine ? <LineGlyph size={13} /> : <BarsGlyph size={13} />}
            </SymbolSwap>
            <FadeText text={toLine ? ctx.t("Line", "折线") : ctx.t("Bars", "柱状")} />
          </div>
        </div>
        <div style={{ position: "relative", width: W, height: H }}>
          {[0, 1, 2, 3, 4].map((i) => (
            <div key={i} style={{ position: "absolute", left: 0, width: W, top: i * ((H - 5) / 4 + 1), height: 1, background: Palette.labelAlpha(i === 4 ? 0.18 : 0.07) }} />
          ))}
          <svg width={W} height={H} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <defs>
              <linearGradient id={`${uid}a`} x1="0" y1="0" x2="0" y2={H} gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor={Palette.indigo} stopOpacity={0.22} />
                <stop offset="1" stopColor={Palette.indigo} stopOpacity={0} />
              </linearGradient>
            </defs>
            <path d={areaPath} fill={`url(#${uid}a)`} opacity={d} />
            {d > 0.0005 && (
              <path d={linePath} fill="none" stroke={Palette.indigo} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" pathLength={1} strokeDasharray={`${d} 2`} />
            )}
          </svg>
          {values.map((_, index) => {
            const top = point(index);
            const barHeight = H - top.y;
            const width = toLine ? 10 : 22;
            const height = toLine ? 10 : barHeight;
            const centerY = toLine ? top.y : top.y + barHeight / 2;
            const delay = toLine ? index * stagger : 0.4 + index * stagger;
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{
                  left: top.x - width / 2,
                  top: centerY - height / 2,
                  width,
                  height,
                  borderRadius: toLine ? 5 : 6,
                  boxShadow: `inset 0 0 0 ${toLine ? 2 : 0}px #fff`,
                }}
                transition={delayed(spring(0.5, 0.75), delay)}
                style={{ position: "absolute", background: `linear-gradient(180deg, ${Palette.sky}, ${Palette.indigo})` }}
              />
            );
          })}
        </div>
        <div style={{ width: W, display: "flex" }}>
          {labels.map((label, i) => (
            <div key={i} style={{ flex: 1, textAlign: "center", fontSize: 9, lineHeight: "11px", fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
              {label}
            </div>
          ))}
        </div>
      </div>
    </Stage>
  );
}
