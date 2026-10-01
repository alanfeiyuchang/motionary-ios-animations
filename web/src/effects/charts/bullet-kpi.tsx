/** charts.bullet-kpi · 子弹图目标达成 (Charts+BulletKPI.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, delayed, demoCard, spring, textStyle, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { randomIn, useAnimatedNumbers, useChartEntrance } from "./_shared";
import { Stage, gradientOf, rounded } from "./_legacy";

const metrics = [
  { en: "Revenue", zh: "营收", target: 0.72, tint: Palette.indigo },
  { en: "NPS", zh: "NPS", target: 0.64, tint: Palette.violet },
  { en: "Uptime", zh: "可用率", target: 0.86, tint: Palette.sky },
];
const TRACK = 264;

export default function BulletKPI({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const measures = useAnimatedNumbers(3, 0);
  const [finals, setFinals] = useState([0, 0, 0]);
  /** The arrival entrance plays silently; crossing haptics start once the user taps. */
  const userRefreshed = useRef(false);

  const refresh = () => {
    // Mostly on target, sometimes short, occasionally well ahead.
    const targets = metrics.map((m) => Math.min(Math.max(m.target + randomIn(-0.22, 0.2), 0.3), 0.98));
    const duration = ctx.n("duration");
    const stagger = ctx.n("stagger");
    for (let i = 0; i < 3; i++) measures.to(i, 0, anim.easeIn(0.2));
    after(0.25, () => {
      const curve = anim.curve(0.2, 0.8, 0.2, 1, duration);
      targets.forEach((t, i) => measures.to(i, t, delayed(curve, i * stagger)));
      after(targets.length * stagger + duration * 0.6, () => setFinals(targets));
    });
  };

  useChartEntrance(refresh);
  useAutoplay(ctx.isPreview, refresh, { every: ctx.n("duration") + 1.8, delay: ctx.n("duration") + 1.6, intro: false });

  const crossed = metrics.map((m, i) => measures.get(i) >= m.target && measures.get(i) > 0);
  const wasCrossed = useRef(crossed);
  const crossedKey = crossed.join();
  useEffect(() => {
    crossed.forEach((c, i) => {
      if (c && !wasCrossed.current[i] && userRefreshed.current) haptics.tap("light");
    });
    wasCrossed.current = crossed;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [crossedKey]);

  const onTrack = finals.filter((f, i) => f >= metrics[i].target).length;
  const all = onTrack === metrics.length;
  const pillColor = all ? Palette.green : Palette.amber;
  return (
    <Stage ctx={ctx} hint={["Tap to refresh", "点击刷新"]} bottom={10}>
      <div
        onClick={() => {
          userRefreshed.current = true;
          refresh();
        }}
        style={{ ...demoCard(), width: 300, padding: 18, display: "flex", flexDirection: "column", gap: 16, cursor: "pointer" }}
      >
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ ...textStyle.headline, whiteSpace: "nowrap" }}>{ctx.t("Quarter goals", "季度目标")}</div>
          <div style={{ padding: "5px 10px", borderRadius: 999, background: alpha(pillColor, 0.14), color: pillColor, fontSize: 12, lineHeight: "16px", fontWeight: 700, whiteSpace: "nowrap", transition: "color 0.4s, background-color 0.4s" }}>
            <NumericText value={onTrack} text={ctx.lang === "zh" ? `${metrics.length} 项中 ${onTrack} 项达标` : `${onTrack} of ${metrics.length} on track`} />
          </div>
        </div>
        {metrics.map((metric, i) => {
          const measure = measures.get(i);
          const hit = crossed[i];
          const color = hit ? Palette.green : Palette.amber;
          return (
            <div key={i} style={{ display: "flex", flexDirection: "column", gap: 6 }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600 }}>{ctx.t(metric.en, metric.zh)}</div>
                <div style={{ ...rounded(12, 700, 15), color: Palette.secondaryLabel }}>{Math.round(measure * 100)}%</div>
              </div>
              <div style={{ position: "relative", width: TRACK, height: 26 }}>
                {[
                  [1, 0.06],
                  [0.8, 0.09],
                  [0.6, 0.13],
                ].map(([w, a]) => (
                  <div key={w} style={{ position: "absolute", left: 0, top: 4, width: TRACK * w, height: 18, borderRadius: 9, background: Palette.labelAlpha(a) }} />
                ))}
                <div
                  style={{
                    position: "absolute",
                    left: 0,
                    top: 8,
                    height: 10,
                    width: Math.max(TRACK * measure, 10),
                    borderRadius: 5,
                    background: gradientOf(metric.tint),
                    opacity: measure > 0.005 ? 1 : 0,
                  }}
                />
                <motion.div
                  initial={false}
                  animate={{ scale: hit ? 1.5 : 1, backgroundColor: color, boxShadow: `0 0 ${hit ? 12 : 0}px ${alpha(color, 0.5)}` }}
                  transition={spring(0.3, 0.45)}
                  style={{ position: "absolute", left: TRACK * metric.target - 1.5, top: 0, width: 3, height: 26, borderRadius: 1.5 }}
                />
              </div>
            </div>
          );
        })}
      </div>
    </Stage>
  );
}
