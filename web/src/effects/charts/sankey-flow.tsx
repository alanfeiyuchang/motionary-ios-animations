/** charts.sankey-flow · 桑基流向图 (Charts+SankeyFlow.swift) */
import { useRef, useState } from "react";
import { Palette, anim, localPoint, spring, useAutoplay, useClock, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, captionSecondary, card, chartHash, circle, clamp01, mono, rrect, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask } from "./_round2";

const sources = [
  { en: "Organic", zh: "自然流量", rgb: RGB.indigo },
  { en: "Paid", zh: "付费", rgb: RGB.pink },
  { en: "Referral", zh: "推荐", rgb: RGB.amber },
];
const targets = [
  { en: "Purchased", zh: "已购买", rgb: RGB.green },
  { en: "Browsed", zh: "仅浏览", rgb: RGB.sky },
  { en: "Bounced", zh: "跳出", rgb: RGB.red },
];
/** value[source][target] */
const values = [
  [22, 18, 6],
  [9, 13, 10],
  [7, 10, 5],
];
const sourceTotal = (i: number) => values[i].reduce((a, b) => a + b, 0);
const targetTotal = (i: number) => values.reduce((sum, row) => sum + row[i], 0);

const PLOT = { w: 268, h: 184 };
const BAR_W = 10;
const DIMMED = 0.18;
type Rect = { x: number; y: number; w: number; h: number };

const layout = (() => {
  const gap = 12;
  const unit = (PLOT.h - gap * 2 - 4) / 100;
  const leftX = 58;
  const rightX = PLOT.w - 58 - 10;
  const sourceRects: Rect[] = [];
  let y = 2;
  for (let i = 0; i < 3; i++) {
    const height = sourceTotal(i) * unit;
    sourceRects.push({ x: leftX, y, w: 10, h: height });
    y += height + gap;
  }
  const targetRects: Rect[] = [];
  y = 2;
  for (let i = 0; i < 3; i++) {
    const height = targetTotal(i) * unit;
    targetRects.push({ x: rightX, y, w: 10, h: height });
    y += height + gap;
  }
  /** (top at the source, top at the target, thickness), indexed source * 3 + target. */
  const ribbons: { from: number; to: number; thickness: number }[] = [];
  const targetFill = [0, 0, 0];
  for (let s = 0; s < 3; s++) {
    let sourceFill = 0;
    for (let t = 0; t < 3; t++) {
      const thickness = values[s][t] * unit;
      ribbons.push({ from: sourceRects[s].y + sourceFill, to: targetRects[t].y + targetFill[t], thickness });
      sourceFill += thickness;
      targetFill[t] += thickness;
    }
  }
  return { leftX, rightX, sourceRects, targetRects, ribbons };
})();

const bezier = (a: number, b: number, c: number, d: number, t: number) => {
  const u = 1 - t;
  return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d;
};

export default function SankeyFlow({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const links = useNums(9, 0);
  /** 0 nodes, 1 focus amount, 2 rolling figure. */
  const v = useNums(3, 0);
  const [focus, setFocus] = useState<number | null>(null);
  const focusRef = useRef<number | null>(null);
  const autoStep = useRef(0);
  useClock(true, ctx.isPreview ? 30 : undefined);

  const pour = () => {
    v.to(0, 1, spring(0.45, 0.7));
    if (focusRef.current === null) v.to(2, 100, anim.easeOut(1.1));
    task.run(async (sleep) => {
      await sleep(0.2);
      for (let step = 0; step < 9; step++) {
        links.to(step, 1, anim.easeOut(0.55));
        await sleep(0.07);
      }
    });
  };

  const select = (node: number | null) => {
    const next = node === focusRef.current ? null : node;
    haptics.selection();
    task.cancel();
    const s = spring(0.4, 0.8);
    if (next !== null) {
      focusRef.current = next;
      setFocus(next);
    }
    v.to(1, next === null ? 0 : 1, s);
    links.toAll(1, s);
    v.to(0, 1, s);
    v.to(2, next === null ? 100 : next < 3 ? sourceTotal(next) : targetTotal(next - 3), anim.easeInOut(0.45));
    if (next === null) {
      task.run(async (sleep) => {
        await sleep(0.4);
        focusRef.current = null;
        setFocus(null);
      });
    }
  };

  const replay = () => {
    haptics.tap("light");
    links.toAll(0, anim.easeIn(0.2));
    task.run(async (sleep) => {
      await sleep(0.25);
      pour();
    });
  };

  const tap = (e: React.MouseEvent<HTMLDivElement>) => {
    const location = localPoint(e, e.currentTarget);
    const hit = (rects: Rect[]) => {
      const i = rects.findIndex((r) => location.y >= r.y - 5 && location.y <= r.y + r.h + 5);
      return i < 0 ? null : i;
    };
    if (location.x < layout.leftX + 24) select(hit(layout.sourceRects));
    else if (location.x > layout.rightX - 14) {
      const i = hit(layout.targetRects);
      select(i === null ? null : i + 3);
    } else if (focusRef.current !== null) select(null);
    else replay();
  };

  /** Autoplay: isolate a source, an outcome, show everything, then pour again. */
  const auto = () => {
    const step = autoStep.current % 5;
    autoStep.current += 1;
    if (step === 0) select(0);
    else if (step === 1) select(3);
    else if (step === 2) select(5);
    else if (step === 3) select(null);
    else replay();
  };

  useChartEntrance(pour);
  useAutoplay(ctx.isPreview, auto, { every: 1.7, delay: 2.4, intro: false });

  const lk = links.all();
  const nodes = v.get(0);
  const focusAmount = clamp01(v.get(1));
  const speed = ctx.n("speed");
  const density = ctx.n("density");
  const curve = ctx.n("curve");
  const time = (Date.now() / 1000) % 100000;

  const emphasis = (source: number, target: number) => {
    if (focus === null) return 1;
    const related = focus < 3 ? focus === source : focus - 3 === target;
    return related ? 1 : 1 - (1 - DIMMED) * focusAmount;
  };
  const nodeEmphasis = (node: number) => {
    if (focus === null || focus === node) return 1;
    // Nodes on the other side stay lit: they receive part of the focused flow.
    return focus < 3 === node < 3 ? 1 - 0.6 * focusAmount : 1;
  };

  const draw = (g: G) => {
    const x0 = layout.leftX + BAR_W;
    const x1 = layout.rightX;
    const dx = x1 - x0;
    const arrived = [0, 0, 0];

    for (let source = 0; source < 3; source++) {
      for (let target = 0; target < 3; target++) {
        const index = source * 3 + target;
        const ribbon = layout.ribbons[index];
        const reveal = clamp01(lk[index]);
        arrived[target] += values[source][target] * smoothstep(0.75, 1, reveal);
        if (!(reveal > 0.002)) continue;
        const path = new Path2D();
        path.moveTo(x0, ribbon.from);
        path.bezierCurveTo(x0 + dx * curve, ribbon.from, x1 - dx * curve, ribbon.to, x1, ribbon.to);
        path.lineTo(x1, ribbon.to + ribbon.thickness);
        path.bezierCurveTo(x1 - dx * curve, ribbon.to + ribbon.thickness, x0 + dx * curve, ribbon.from + ribbon.thickness, x0, ribbon.from + ribbon.thickness);
        path.closePath();

        const from = sources[source].rgb;
        const to = targets[target].rgb;
        const edge = x0 + dx * reveal;
        const clip = new Path2D();
        clip.rect(x0, 0, edge - x0, g.height);
        g.layer(
          () => {
            g.fill(path, g.gradient(x0, 0, x1, 0, [from.color(0.4), to.color(0.4)]));
            // Particles in parallel lanes on the same cubic.
            const count = swiftRound((values[source][target] / 10) * density);
            for (let particle = 0; particle < count; particle++) {
              const seed = index * 31 + particle;
              const pace = speed * (0.8 + 0.4 * chartHash(seed, 41));
              const raw = time * pace + chartHash(seed, 43);
              const u = raw - Math.floor(raw);
              const lane = (particle + 0.5) / count;
              const wobble = ((chartHash(seed, 47) - 0.5) * 0.3) / count;
              const offset = ribbon.thickness * Math.min(Math.max(lane + wobble, 0.12), 0.88);
              const px = bezier(x0, x0 + dx * curve, x1 - dx * curve, x1, u);
              if (!(px <= edge)) continue;
              const py = bezier(ribbon.from, ribbon.from, ribbon.to, ribbon.to, u) + offset;
              const fade = Math.min(u / 0.12, (1 - u) / 0.12, 1);
              g.fill(circle(px, py, 1.7), from.mixed(to, u).mixed(RGB.white, 0.15).color(0.95 * fade));
            }
          },
          { alpha: emphasis(source, target), clip },
        );
      }
    }

    // Node bars and their labels.
    const grown = Math.max(nodes, 0);
    const label = (name: string, value: number, x: number, y: number, leading: boolean, a: number) => {
      g.text(`${swiftRound(value)}`, x, y - 1, { size: 12, weight: 700, rounded: true, color: g.primary(), anchor: leading ? "bottomLeading" : "bottomTrailing", alpha: a });
      g.text(name, x, y + 1, { size: 10, weight: 500, color: g.secondary(), anchor: leading ? "topLeading" : "topTrailing", alpha: a });
    };
    for (let index = 0; index < 3; index++) {
      const source = layout.sourceRects[index];
      const node = sources[index];
      const height = source.h * grown;
      const midY = source.y + source.h / 2;
      g.layer(
        () => {
          g.fill(rrect(source.x, midY - height / 2, source.w, height, Math.min(3, height / 2)), node.rgb.color());
          label(ctx.t(node.en, node.zh), sourceTotal(index), source.x - 7, midY, false, Math.min(grown, 1));
        },
        { alpha: nodeEmphasis(index) },
      );

      const target = layout.targetRects[index];
      const outcome = targets[index];
      const targetHeight = target.h * (arrived[index] / targetTotal(index));
      g.layer(
        () => {
          g.fill(rrect(target.x, target.y, target.w, target.h, 3), g.primary(0.07));
          if (targetHeight > 0.5) g.fill(rrect(target.x, target.y, target.w, targetHeight, Math.min(3, targetHeight / 2)), outcome.rgb.color());
          label(ctx.t(outcome.en, outcome.zh), arrived[index], target.x + target.w + 7, target.y + target.h / 2, true, 1);
        },
        { alpha: nodeEmphasis(index + 3) },
      );
    }
  };

  const node = focus === null ? null : focus < 3 ? sources[focus] : targets[focus - 3];
  return (
    <ChartStage ctx={ctx} hint={["Tap a node to isolate its flows", "点击节点查看它的流向"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={{ ...captionSecondary, color: node ? node.rgb.mixed(RGB.black, 0.12).color() : Palette.secondaryLabel, transition: "color 0.3s" }}>
              {node ? ctx.t(node.en, node.zh) : ctx.t("Visits to outcome", "访问去向")}
            </div>
            <div style={{ ...sys(26, 700, true), ...mono }}>{swiftRound(v.get(2))}k</div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 4, padding: "5px 9px", borderRadius: 999, color: Palette.secondaryLabel, background: Palette.labelAlpha(0.06) }}>
            {/* arrow.triangle.branch */}
            <svg width={11} height={11} viewBox="0 0 11 11" fill="none" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round">
              <path d="M5.500 10.200V6.400M5.500 6.400C5.500 4.600 2.300 4.900 2.300 2.400M5.500 6.400C5.500 4.600 8.700 4.900 8.700 2.400" />
              <path d="M0.900 3.300L2.300 1.500L3.700 3.300M7.300 3.300L8.700 1.500L10.100 3.300" />
            </svg>
            <span style={sys(12, 600)}>{ctx.t("9 flows", "9 条流向")}</span>
          </div>
        </div>
        <div onClick={tap} style={{ width: PLOT.w, height: PLOT.h, cursor: "pointer" }}>
          <Plot ctx={ctx} width={PLOT.w} height={PLOT.h} draw={draw} />
        </div>
      </div>
    </ChartStage>
  );
}
