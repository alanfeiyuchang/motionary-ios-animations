/** charts.dot-matrix-morph · 点阵重新分组 (Charts+DotMatrixMorph.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { ChartStage, G, Plot, RGB, backOut, captionSecondary, card, chartHash, circle, clamp01, lerpPt, smoothstep, stagger, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

type Group = { en: string; zh: string; rgb: RGB; count: number };

const plans: Group[] = [
  { en: "Free", zh: "免费版", rgb: RGB.sky, count: 54 },
  { en: "Pro", zh: "专业版", rgb: RGB.indigo, count: 31 },
  { en: "Team", zh: "团队版", rgb: RGB.pink, count: 15 },
];
const regions: Group[] = [
  { en: "Americas", zh: "美洲", rgb: RGB.amber, count: 38 },
  { en: "Europe", zh: "欧洲", rgb: RGB.mint, count: 29 },
  { en: "Asia", zh: "亚洲", rgb: RGB.coral, count: 24 },
  { en: "Other", zh: "其他", rgb: RGB.violet, count: 9 },
];

/** Plan per dot: the grid's reading order. Region per dot: an independent shuffle. */
const planOf = plans.flatMap((g, i) => Array.from({ length: g.count }, () => i));
const regionOf = (() => {
  const shuffled = Array.from({ length: 100 }, (_, i) => i).sort((a, b) => chartHash(a, 21) - chartHash(b, 21) || a - b);
  const flat = regions.flatMap((g, i) => Array.from({ length: g.count }, () => i));
  const out = new Array<number>(100).fill(0);
  shuffled.forEach((dot, slot) => (out[dot] = flat[slot]));
  return out;
})();

const SIZE = { w: 268, h: 186 };
const FLOOR = 150;
type Layout = { points: Pt[]; colours: RGB[]; labels: { x: number; group: Group }[] };

function grid(): Layout {
  const pitch = 14.6;
  const left = (SIZE.w - pitch * 9) / 2;
  const top = 9;
  const third = SIZE.w / 3;
  return {
    points: Array.from({ length: 100 }, (_, i) => ({ x: left + (i % 10) * pitch, y: top + Math.floor(i / 10) * pitch })),
    colours: planOf.map((p) => plans[p].rgb),
    labels: plans.map((group, i) => ({ x: third * (i + 0.5), group })),
  };
}

function columns(groups: Group[], membership: number[], across: number, gap: number): Layout {
  const pitch = 13;
  const groupWidth = pitch * (across - 1);
  const advance = groupWidth + gap;
  const left = (SIZE.w - (groupWidth * groups.length + gap * (groups.length - 1))) / 2;
  const filled = groups.map(() => 0);
  const pts: Pt[] = [];
  for (let dot = 0; dot < 100; dot++) {
    const group = membership[dot];
    const slot = filled[group];
    filled[group] += 1;
    pts.push({ x: left + group * advance + (slot % across) * pitch, y: FLOOR - 6 - Math.floor(slot / across) * pitch });
  }
  return { points: pts, colours: membership.map((m) => groups[m].rgb), labels: groups.map((group, i) => ({ x: left + i * advance + groupWidth / 2, group })) };
}

const layouts = [grid(), columns(plans, planOf, 5, 34), columns(regions, regionOf, 4, 28)];
const titles: [string, string][] = [
  ["All customers", "全部客户"],
  ["By plan", "按套餐"],
  ["By region", "按地区"],
];

export default function DotMatrixMorph({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const progress = useNums(1, 1);
  const [state, setState] = useState({ from: 0, to: 0 });
  const stateRef = useRef(state);

  const next = () => {
    haptics.tap("light");
    const duration = ctx.n("duration");
    stateRef.current = { from: stateRef.current.to, to: (stateRef.current.to + 1) % 3 };
    setState(stateRef.current);
    progress.jump(0, 0);
    task.run(async (sleep) => {
      await sleep(0.03);
      progress.to(0, 1, anim.linear(duration));
      await sleep(duration * 0.9);
      if (ctx.isPreview) return;
      haptics.tap("soft");
    });
  };

  useAutoplay(ctx.isPreview, next, { every: 2.2, delay: 0.8 });

  const { from, to } = state;
  const t = clamp01(progress.get());
  const spread = ctx.n("stagger");
  const arc = ctx.n("arc");

  const draw = (g: G) => {
    const a = layouts[from];
    const b = layouts[to];
    const span = 1 - spread;
    for (let dot = 0; dot < 100; dot++) {
      const local = stagger(t, chartHash(dot, 31) * spread, span);
      const eased = backOut(local, 0.9);
      const start = a.points[dot];
      const end = b.points[dot];
      const centre = lerpPt(start, end, eased);
      const dx = end.x - start.x;
      const dy = end.y - start.y;
      const length = Math.hypot(dx, dy);
      if (length > 1) {
        // Bulge sideways, alternating direction, more for longer trips.
        const side = dot % 2 === 0 ? 1 : -1;
        const bulge = arc * side * Math.sin(Math.PI * local) * Math.min(length / 90, 1);
        centre.x += (-dy / length) * bulge;
        centre.y += (dx / length) * bulge;
      }
      const colour = a.colours[dot].mixed(b.colours[dot], smoothstep(0.25, 0.75, local));
      g.fill(circle(centre.x, centre.y, 5 * (1 + 0.18 * Math.sin(Math.PI * local))), colour.color());
    }
    const captions = (layout: Layout, alpha: number, shift: number) => {
      if (!(alpha > 0.01)) return;
      for (const label of layout.labels) {
        g.text(`${label.group.count}`, label.x, SIZE.h - 30 + shift, { size: 13, weight: 700, rounded: true, color: label.group.rgb.mixed(RGB.black, 0.12).color(), anchor: "top", alpha });
        g.text(ctx.t(label.group.en, label.group.zh), label.x, SIZE.h - 14 + shift, { size: 10, weight: 500, color: g.secondary(), anchor: "top", alpha });
      }
    };
    if (from !== to) captions(a, 1 - smoothstep(0, 0.25, t), 0);
    const landed = from === to ? 1 : smoothstep(0.7, 1, t);
    captions(b, landed, (1 - landed) * 6);
  };

  const pager = spring(0.4, 0.75);
  return (
    <ChartStage ctx={ctx} hint={["Tap to regroup the dots", "点击重新分组"]}>
      <div onClick={next} style={{ ...card(10), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("1 dot = 1 customer", "1 个点 = 1 位客户")}</div>
            <div style={{ position: "relative", height: 26, ...sys(22, 700, true) }}>
              <AnimatePresence initial={false}>
                <motion.div key={to} initial={{ y: 8, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -8, opacity: 0 }} transition={pager} style={{ position: "absolute", left: 0, top: 0 }}>
                  {ctx.t(titles[to][0], titles[to][1])}
                </motion.div>
              </AnimatePresence>
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 5, alignSelf: "center" }}>
            {[0, 1, 2].map((index) => (
              <motion.div
                key={index}
                initial={false}
                animate={{ width: index === to ? 16 : 6 }}
                transition={pager}
                style={{ height: 6, borderRadius: 3, background: index === to ? Palette.indigo : Palette.labelAlpha(0.14), transition: "background 0.3s" }}
              />
            ))}
          </div>
        </div>
        <Plot ctx={ctx} width={SIZE.w} height={SIZE.h} draw={draw} />
      </div>
    </ChartStage>
  );
}
