/** charts.scatter-cluster · 散点聚类 (Charts+ScatterCluster.swift) */
import { useRef, useState } from "react";
import { Palette, alpha, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartHeadline, ChartStage, Crossfade, G, Plot, RGB, backOut, card, chartHash, circle, convexHull, lerpPt, smoothLoop, smoothstep, stagger, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const centres: Pt[] = [
  { x: 0.25, y: 0.34 },
  { x: 0.74, y: 0.3 },
  { x: 0.5, y: 0.76 },
];
const colours = [RGB.indigo, RGB.pink, RGB.mint];
const names = ["A", "B", "C"];
const clampTo = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);

const points = Array.from({ length: 48 }, (_, index) => {
  const cluster = index % 3;
  const centre = centres[cluster];
  const sx = clampTo(centre.x + (chartHash(index, 1) - 0.5) * 0.92, 0.04, 0.96);
  const sy = clampTo(centre.y + (chartHash(index, 2) - 0.5) * 0.98, 0.05, 0.95);
  const radius = 0.035 + Math.sqrt(chartHash(index, 3)) * 0.105;
  const theta = chartHash(index, 4) * 2 * Math.PI;
  return {
    cluster,
    scattered: { x: sx, y: sy },
    /** Offset from the centroid in the clustered state (unit space). */
    offset: { x: radius * Math.cos(theta), y: radius * Math.sin(theta) * 1.25 },
    delay: chartHash(index, 5) * 0.25,
  };
});

export default function ScatterCluster({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  /** 0 gather, 1 hull, 2 appear, 3 score. */
  const v = useNums(4, 0);
  const [clustered, setClustered] = useState(false);
  const clusteredRef = useRef(false);

  const toggle = () => {
    haptics.tap("light");
    const response = ctx.n("response");
    const target = !clusteredRef.current;
    clusteredRef.current = target;
    setClustered(target);
    v.to(2, 1, anim.easeOut(0.25));
    if (target) {
      v.to(0, 1, spring(response, 0.72));
      v.to(3, 71, anim.easeInOut(0.8));
      task.run(async (sleep) => {
        await sleep(0.25);
        v.to(1, 1, spring(0.45, 0.62));
        if (!ctx.isPreview) haptics.tap("soft");
      });
    } else {
      v.to(1, 0, anim.easeIn(0.2));
      v.to(3, 0, anim.easeInOut(0.6));
      task.run(async (sleep) => {
        await sleep(0.14);
        v.to(0, 0, spring(response * 1.1, 0.8));
      });
    }
  };

  useChartEntrance(() => v.to(2, 1, anim.easeOut(0.7)));
  useAutoplay(ctx.isPreview, toggle, { every: 2.1, delay: 1.0 });

  const gather = v.get(0);
  const hull = v.get(1);
  const appear = v.get(2);
  const tight = ctx.n("tight");
  const pad = ctx.n("pad");

  const draw = (g: G) => {
    const plot = { x: 14, y: 4, w: g.width - 18, h: g.height - 20 };
    const maxX = plot.x + plot.w;
    const maxY = plot.y + plot.h;
    const place = (unit: Pt): Pt => ({ x: plot.x + plot.w * unit.x, y: plot.y + plot.h * unit.y });

    // Axes and a light grid.
    for (let line = 1; line <= 3; line++) {
      const lineY = plot.y + (plot.h * line) / 4;
      g.line(plot.x, lineY, maxX, lineY, g.primary(0.05), 1);
      const lineX = plot.x + (plot.w * line) / 4;
      g.line(lineX, plot.y, lineX, maxY, g.primary(0.05), 1);
    }
    const axes = new Path2D();
    axes.moveTo(plot.x, plot.y);
    axes.lineTo(plot.x, maxY);
    axes.lineTo(maxX, maxY);
    g.stroke(axes, g.primary(0.18), 1, { cap: "round", join: "round" });

    // Current dot positions.
    const locals = points.map((p) => Math.min(Math.max(gather * 1.25 - p.delay, 0), 1.2));
    const positions = points.map((p, i) => {
      const centre = centres[p.cluster];
      const home = { x: centre.x + p.offset.x * tight, y: centre.y + p.offset.y * tight };
      return place(lerpPt(p.scattered, home, locals[i]));
    });

    // Hulls, inflating from each centroid.
    const inflate = Math.max(hull, 0);
    if (inflate > 0.01) {
      for (let cluster = 0; cluster < 3; cluster++) {
        const members = positions.filter((_, i) => points[i].cluster === cluster);
        if (members.length <= 2) continue;
        const centroid = { x: members.reduce((s, p) => s + p.x, 0) / members.length, y: members.reduce((s, p) => s + p.y, 0) / members.length };
        const padded = convexHull(members).map((vertex) => {
          const dx = vertex.x - centroid.x;
          const dy = vertex.y - centroid.y;
          const length = Math.max(Math.hypot(dx, dy), 0.001);
          const reach = (length + pad) * inflate;
          return { x: centroid.x + (dx / length) * reach, y: centroid.y + (dy / length) * reach };
        });
        const shape = smoothLoop(padded);
        const colour = colours[cluster];
        const a = Math.min(inflate, 1);
        g.fill(shape, colour.color(0.14 * a));
        g.stroke(shape, colour.color(0.55 * a), 1.5);

        const cross = new Path2D();
        cross.moveTo(centroid.x - 4, centroid.y);
        cross.lineTo(centroid.x + 4, centroid.y);
        cross.moveTo(centroid.x, centroid.y - 4);
        cross.lineTo(centroid.x, centroid.y + 4);
        g.stroke(cross, colour.mixed(RGB.black, 0.25).color(a), 1.5, { cap: "round" });

        const top = Math.min(...padded.map((p) => p.y));
        g.text(`${names[cluster]} · ${members.length}`, centroid.x, Math.max(top - 3, 9), { size: 10.5, weight: 700, rounded: true, color: colour.mixed(RGB.black, 0.15).color(), anchor: "bottom", alpha: a });
      }
    }

    // Dots.
    points.forEach((point, index) => {
      const born = backOut(stagger(appear, chartHash(index, 6) * 0.6, 0.4), 2);
      if (!(born > 0.01)) return;
      const tint = smoothstep(0.1, 0.7, locals[index]);
      const colour = RGB.grey.mixed(colours[point.cluster], tint);
      const dot = circle(positions[index].x, positions[index].y, 3.5 * born);
      g.fill(dot, colour.color(0.55 + 0.4 * tint));
      g.stroke(dot, colour.mixed(RGB.black, 0.2).color(0.5), 0.5);
    });
  };

  return (
    <ChartStage ctx={ctx} hint={["Tap to cluster and disperse", "点击聚类 / 散开"]}>
      <div onClick={toggle} style={{ ...card(10), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <ChartHeadline title={ctx.t("Separation", "分离度")} text={`${swiftRound(v.get(3))}%`} />
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 5,
              padding: "5px 9px",
              borderRadius: 999,
              color: clustered ? Palette.indigo : Palette.secondaryLabel,
              background: clustered ? alpha(Palette.indigo, 0.14) : Palette.labelAlpha(0.06),
              transition: "color 0.3s, background 0.3s",
            }}
          >
            <Crossfade id={clustered ? "hex" : "dots"} symbol>
              <svg width={13} height={13} viewBox="0 0 13 13">
                {clustered ? (
                  // circle.hexagongrid.fill
                  [[6.5, 6.5], [6.5, 2.3], [6.5, 10.7], [2.9, 4.4], [10.1, 4.4], [2.9, 8.6], [10.1, 8.6]].map(([x, y], i) => <circle key={i} cx={x} cy={y} r={1.75} fill="currentColor" />)
                ) : (
                  // circle.dotted
                  <circle cx={6.5} cy={6.5} r={5} fill="none" stroke="currentColor" strokeWidth={1.8} strokeLinecap="round" strokeDasharray="0.1 3.04" />
                )}
              </svg>
            </Crossfade>
            <Crossfade id={clustered ? "c" : "p"} style={sys(12, 600)} align="start">
              {clustered ? ctx.t("3 clusters", "3 个分群") : ctx.t("48 points", "48 个点")}
            </Crossfade>
          </div>
        </div>
        <Plot ctx={ctx} width={268} height={190} draw={draw} />
      </div>
    </ChartStage>
  );
}
