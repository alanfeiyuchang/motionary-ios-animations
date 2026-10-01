/** charts.grouped-stacked · 分组 ⇄ 堆叠柱状图 (Charts+GroupedStacked.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, delayed, demoCard, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { Stage, gradientOf, useThumb } from "./_legacy";

const groupedData = [
  [0.22, 0.14, 0.1],
  [0.28, 0.18, 0.12],
  [0.2, 0.26, 0.16],
  [0.34, 0.22, 0.14],
  [0.3, 0.3, 0.22],
];
const colors = [Palette.indigo, Palette.pink, Palette.amber];
const W = 264;
const H = 180;

export default function GroupedStacked({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [lifted, setLifted] = useState(false);
  const [merged, setMerged] = useState(false);
  const [stacked, setStacked] = useState(false);
  const stackedRef = useRef(false);
  const busy = useRef(false);
  const thumb = useThumb(stacked ? 1 : 0, [ctx.lang]);

  const toggle = (haptic: boolean) => {
    if (busy.current) return;
    busy.current = true;
    if (haptic) haptics.tap("light");
    const gap = ctx.n("gap");
    const goingStacked = !stackedRef.current;
    stackedRef.current = goingStacked;
    setStacked(goingStacked);
    if (goingStacked) {
      setLifted(true);
      after(gap, () => setMerged(true));
    } else {
      setMerged(false);
      after(gap, () => setLifted(false));
    }
    after(gap + 0.5, () => (busy.current = false));
  };

  useAutoplay(ctx.isPreview, () => toggle(false), { every: 2.8, delay: 1.0 });

  const slot = W / groupedData.length;
  const labels: [string, string][] = [
    ["Grouped", "分组"],
    ["Stacked", "堆叠"],
  ];
  return (
    <Stage ctx={ctx} hint={["Tap to restack", "点击切换堆叠"]} bottom={6} cue>
      <div onClick={() => toggle(true)} style={{ ...demoCard(), padding: 18, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 12, cursor: "pointer" }}>
        <div style={{ position: "relative", display: "flex", padding: 3, borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
          {thumb.frame && (
            <motion.div
              initial={false}
              animate={{ x: thumb.frame.x, width: thumb.frame.width }}
              transition={spring(0.35, 0.8)}
              style={{ position: "absolute", left: 0, top: thumb.frame.y, height: thumb.frame.height, borderRadius: 999, background: Palette.primary }}
            />
          )}
          {labels.map(([en, zh], i) => (
            <div
              key={i}
              ref={thumb.ref(i)}
              style={{ position: "relative", padding: "5px 12px", fontSize: 12, lineHeight: "16px", fontWeight: 600, whiteSpace: "nowrap", color: (i === 1) === stacked ? "#fff" : Palette.secondaryLabel, transition: "color 0.25s" }}
            >
              {ctx.t(en, zh)}
            </div>
          ))}
        </div>
        <div style={{ position: "relative", width: W, height: H }}>
          <div style={{ position: "absolute", left: 0, bottom: 0, width: W, height: 1, background: Palette.labelAlpha(0.18) }} />
          {groupedData.map((values, quarter) =>
            values.map((value, series) => {
              const height = value * H;
              let below = 0;
              for (let i = 0; i < series; i++) below += values[i] * H;
              const center = slot * (quarter + 0.5);
              const width = merged ? 34 : 12;
              const x = (merged ? center : center + (series - 1) * 14) - width / 2;
              const radius = series === 2 || !lifted ? 4 : 0;
              return (
                <motion.div
                  key={`${quarter}-${series}`}
                  initial={false}
                  animate={{ x, y: lifted ? -below : 0, width, borderTopLeftRadius: radius, borderTopRightRadius: radius }}
                  transition={delayed(spring(0.45, 0.8), quarter * ctx.n("stagger"))}
                  style={{ position: "absolute", left: 0, bottom: 0, height, background: gradientOf(colors[series]) }}
                />
              );
            }),
          )}
        </div>
        <div style={{ width: W, display: "flex" }}>
          {groupedData.map((_, quarter) => (
            <div key={quarter} style={{ flex: 1, textAlign: "center", fontSize: 10, lineHeight: "12px", fontWeight: 600, color: Palette.secondaryLabel }}>
              Q{quarter + 1}
            </div>
          ))}
        </div>
      </div>
    </Stage>
  );
}
