/** charts.line-compare · 双线对比 (Charts+LineCompare.swift) */
import { ArrowUp } from "lucide-react";
import { useRef } from "react";
import { Palette, anim, spring, useAutoplay, usePan, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, captionSecondary, card, circle, clamp01, mono, polyline, resample, rgba, sampleAt, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const compareThis = resample([118, 134, 126, 152, 141, 168, 176], 10);
const compareLast = resample([126, 122, 139, 137, 150, 144, 158], 10);
const RANGE = [105, 185];
const PLOT_W = 268;
const PLOT_H = 150;
const INSET = 10;
const stops = [0.24, 0.7, 0.45, 0.93, 0.1];

const yOf = (value: number) => INSET + (PLOT_H - INSET * 2) * (1 - (value - RANGE[0]) / (RANGE[1] - RANGE[0]));

export default function LineCompare({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  /** 0 position, 1 draw, 2 focus. */
  const v = useNums(3, [1, 0, 0]);
  const target = useRef(1);
  const engaged = useRef(false);
  const autoStep = useRef(0);

  const release = () => {
    if (!engaged.current) return;
    engaged.current = false;
    target.current = 1;
    v.to(0, 1, spring(0.55, 0.8));
  };

  const pan = usePan(
    {
      onChange: (s) => {
        if (!engaged.current) {
          // Horizontal-first, so a vertical swipe on the chart still scrolls the page.
          if (!(Math.abs(s.translation.x) > Math.abs(s.translation.y))) return;
          engaged.current = true;
          haptics.tap("light");
        }
        let next = clamp01(s.location.x / PLOT_W);
        if (ctx.b("snap")) {
          next = swiftRound(next * 6) / 6;
          if (Math.abs(next - target.current) > 0.01) haptics.selection();
        }
        target.current = next;
        const follow = spring(ctx.n("follow"), 0.82);
        v.to(0, next, follow);
        v.to(2, 1, follow);
        v.to(1, 1, follow);
      },
      onEnd: release,
    },
    6,
  );

  const drawOn = () => {
    v.to(1, 1, anim.easeInOut(1));
    task.run(async (sleep) => {
      await sleep(0.85);
      v.to(2, 1, spring(0.45, 0.75));
    });
  };

  /** Autoplay and the arrival play: the crosshair glides between a few days. */
  const glide = () => {
    if (engaged.current) return;
    const next = stops[autoStep.current % stops.length];
    autoStep.current += 1;
    target.current = next;
    v.to(0, next, spring(0.7, 0.85));
    v.to(2, 1, spring(0.7, 0.85));
  };

  useChartEntrance(drawOn);
  useAutoplay(ctx.isPreview, glide, { every: 1.3, delay: 1.7 });

  const x = clamp01(v.get(0));
  const shown = v.get(1);
  const focus = v.get(2);
  const current = sampleAt(compareThis, x);
  const previous = sampleAt(compareLast, x);
  const shade = ctx.n("shade");
  const delta = current - previous;
  const tone = RGB.trend(delta / 8);

  const draw = (g: G) => {
    const count = compareThis.length;
    const step = g.width / (count - 1);
    const top: Pt[] = compareThis.map((value, i) => ({ x: i * step, y: yOf(value) }));
    const bottom: Pt[] = compareLast.map((value, i) => ({ x: i * step, y: yOf(value) }));

    for (let line = 0; line <= 2; line++) {
      const lineY = INSET + ((g.height - INSET * 2) * line) / 2;
      g.line(0, lineY, g.width, lineY, g.primary(0.06), 1);
    }

    const clip = new Path2D();
    clip.rect(0, -20, g.width * shown + 0.5, g.height + 40);
    g.layer(
      () => {
        // Shade between the lines, split at each crossing so every piece has one sign.
        const lead = new Path2D();
        const trail = new Path2D();
        const quad = (path: Path2D, p: Pt[]) => {
          path.moveTo(p[0].x, p[0].y);
          for (const point of p.slice(1)) path.lineTo(point.x, point.y);
          path.closePath();
        };
        for (let index = 0; index < count - 1; index++) {
          const a0 = top[index];
          const a1 = top[index + 1];
          const b0 = bottom[index];
          const b1 = bottom[index + 1];
          const d0 = b0.y - a0.y;
          const d1 = b1.y - a1.y;
          if (d0 * d1 < 0) {
            const t = d0 / (d0 - d1);
            const cross = { x: a0.x + (a1.x - a0.x) * t, y: a0.y + (a1.y - a0.y) * t };
            if (d0 > 0) {
              quad(lead, [a0, cross, b0]);
              quad(trail, [cross, a1, b1]);
            } else {
              quad(trail, [a0, cross, b0]);
              quad(lead, [cross, a1, b1]);
            }
          } else if (d0 + d1 >= 0) quad(lead, [a0, a1, b1, b0]);
          else quad(trail, [a0, a1, b1, b0]);
        }
        g.fill(lead, rgba(Palette.green, shade));
        g.fill(trail, rgba(Palette.red, shade));
        g.stroke(polyline(bottom), g.secondary(0.8), 2, { cap: "round", join: "round" });
        g.stroke(polyline(top), Palette.indigo, 2.5, { cap: "round", join: "round" });
      },
      { clip },
    );

    if (!(focus > 0.01)) return;
    g.layer(
      () => {
        const crossX = g.width * x;
        g.line(crossX, 0, crossX, g.height, g.primary(0.28), 1, { dash: [3, 3] });
        g.line(crossX, yOf(current), crossX, yOf(previous), tone.color(), 4, { cap: "round" });
        const radius = 5.5 * Math.min(focus, 1.2);
        const dots: [number, string][] = [
          [yOf(previous), g.secondary()],
          [yOf(current), Palette.indigo],
        ];
        for (const [pointY, color] of dots) {
          g.fill(circle(crossX, pointY, radius), "#fff");
          g.fill(circle(crossX, pointY, Math.max(radius - 2.2, 0)), color);
        }
      },
      { alpha: Math.min(focus, 1) },
    );
  };

  const dayIndex = Math.min(Math.max(swiftRound(x * 6), 0), 6);
  const dayLabel = (ctx.lang === "zh" ? ["周一", "周二", "周三", "周四", "周五", "周六", "今天"] : ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Today"])[dayIndex];
  const legend = (name: string, value: number, color: string, dashed: boolean) => (
    <div style={{ display: "flex", flexDirection: "column", gap: 1, alignItems: "flex-start" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 5 }}>
        <span style={{ width: 12, height: 3, borderRadius: 1.5, background: color }} />
        <span style={captionSecondary}>{name}</span>
      </div>
      <div style={{ height: 28, display: "flex", alignItems: "flex-end" }}>
        <span style={{ ...sys(dashed ? 20 : 24, 700, true), ...mono, color: dashed ? Palette.secondaryLabel : Palette.label }}>{swiftRound(value)}</span>
      </div>
    </div>
  );

  const side = smoothstep(0.66, 0.8, x);
  const centerY = Math.min(Math.max((yOf(current) + yOf(previous)) / 2, 14), PLOT_H - 14);
  const centerX = Math.min(Math.max(PLOT_W * x + (40 - 80 * side), 28), PLOT_W - 28);
  const labels = ctx.lang === "zh" ? ["一", "二", "三", "四", "五", "六", "今"] : ["M", "T", "W", "T", "F", "S", "T"];

  return (
    <ChartStage ctx={ctx} hint={["Drag across the chart to compare", "在图表上左右滑动对比"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "flex-start", gap: 18 }}>
          {legend(ctx.t("This week", "本周"), current, Palette.indigo, false)}
          {legend(ctx.t("Last week", "上周"), previous, Palette.secondaryLabel, true)}
          <div style={{ flex: 1 }} />
          <div style={{ ...captionSecondary, padding: "5px 9px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>{dayLabel}</div>
        </div>
        <div {...pan} style={{ ...pan.style, position: "relative", width: PLOT_W, height: PLOT_H, cursor: "ew-resize" }}>
          <Plot ctx={ctx} width={PLOT_W} height={PLOT_H} draw={draw} style={{ position: "absolute", left: 0, top: 0 }} />
          <div
            style={{
              position: "absolute",
              left: centerX,
              top: centerY,
              transform: `translate(-50%, -50%) scale(${0.6 + 0.4 * Math.min(focus, 1.15)})`,
              opacity: Math.max(0, Math.min(focus, 1)),
              height: 22,
              padding: "0 8px",
              borderRadius: 11,
              display: "flex",
              alignItems: "center",
              gap: 3,
              color: "#fff",
              background: tone.mixed(RGB.black, 0.12).color(),
              boxShadow: `0 3px 12px ${tone.color(0.4)}`,
              pointerEvents: "none",
            }}
          >
            <ArrowUp size={10} strokeWidth={3.5} style={{ transform: `rotate(${90 - 90 * Math.min(Math.max(delta / 8, -1), 1)}deg)` }} />
            <span style={{ ...sys(12, 700, true), ...mono }}>{Math.abs(swiftRound(delta))}</span>
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", width: PLOT_W, ...sys(10, 500), color: Palette.secondaryLabel }}>
          {labels.map((label, index) => (
            <span key={index}>{label}</span>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
