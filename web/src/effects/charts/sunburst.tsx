/** charts.sunburst · 旭日图钻取 (Charts+Sunburst.swift) */
import { ChevronLeft } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, black, fonts, localPoint, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, clamp01, swiftRound, sys, useChartHaptics, useNums } from "./_round2";

type SunNode = { id: number; en: string; zh: string; value: number; depth: number; parent: number | null; start: number; end: number; category: number; sibling: number; tone: number };

const sunColors = [0x6e7bff, 0xff5fa2, 0xf5a623, 0x21c4a0].map((c) => RGB.hex(c));
/** One hue per sub-item, close to its category colour, so a zoomed ring is not a single flat tint. */
const sunRamps = [
  [0x6e7bff, 0x9a6bff, 0x4fa8ff],
  [0xff5fa2, 0xff7c7c, 0xd867e6],
  [0xf5a623, 0xff8648, 0xefc62c],
  [0x21c4a0, 0x35b8e8, 0x6fd36a],
].map((ramp) => ramp.map((c) => RGB.hex(c)));

const sunNodes: SunNode[] = (() => {
  const tree: [string, string, [string, string, number][]][] = [
    ["Photos", "照片", [["Library", "图库", 26], ["Videos", "视频", 14], ["Shared", "共享", 6]]],
    ["Apps", "应用", [["Games", "游戏", 16], ["Social", "社交", 10], ["Tools", "工具", 8]]],
    ["Media", "媒体", [["Music", "音乐", 12], ["Podcasts", "播客", 8], ["Books", "图书", 6]]],
    ["System", "系统", [["iOS", "iOS", 11], ["Cache", "缓存", 7]]],
  ];
  const leafSplit = [0.5, 0.3, 0.2];
  const total = tree.reduce((sum, c) => sum + c[2].reduce((s, x) => s + x[2], 0), 0);
  const nodes: SunNode[] = [{ id: 0, en: "Storage", zh: "存储空间", value: total, depth: 0, parent: null, start: 0, end: 1, category: -1, sibling: 0, tone: 0 }];
  let cursor = 0;
  tree.forEach((category, categoryIndex) => {
    const categoryValue = category[2].reduce((s, x) => s + x[2], 0);
    const categoryID = nodes.length;
    nodes.push({ id: categoryID, en: category[0], zh: category[1], value: categoryValue, depth: 1, parent: 0, start: cursor, end: cursor + categoryValue / total, category: categoryIndex, sibling: categoryIndex, tone: 0 });
    let childCursor = cursor;
    category[2].forEach((child, childIndex) => {
      const childID = nodes.length;
      const childEnd = childCursor + child[2] / total;
      nodes.push({ id: childID, en: child[0], zh: child[1], value: child[2], depth: 2, parent: categoryID, start: childCursor, end: childEnd, category: categoryIndex, sibling: childIndex, tone: childIndex });
      let leafCursor = childCursor;
      leafSplit.forEach((share, leafIndex) => {
        const leafEnd = leafCursor + (childEnd - childCursor) * share;
        nodes.push({ id: nodes.length, en: child[0], zh: child[1], value: child[2] * share, depth: 3, parent: childID, start: leafCursor, end: leafEnd, category: categoryIndex, sibling: leafIndex, tone: childIndex });
        leafCursor = leafEnd;
      });
      childCursor = childEnd;
    });
    cursor += categoryValue / total;
  });
  return nodes;
})();

const SIDE = 250;
const CORE = 38;
const RING_A = [42, 80];
const RING_B = [83, 114];

type Placement = { start: number; end: number; inner: number; outer: number; visible: boolean };

function placement(node: SunNode, focus: number): Placement {
  const target = sunNodes[focus];
  const span = Math.max(target.end - target.start, 0.0001);
  const start = clamp01((node.start - target.start) / span);
  const end = clamp01((node.end - target.start) / span);
  const offset = node.depth - target.depth;
  if (offset === 1) return { start, end, inner: RING_A[0], outer: RING_A[1], visible: true };
  if (offset === 2) return { start, end, inner: RING_B[0], outer: RING_B[1], visible: true };
  if (offset > 2) return { start, end, inner: RING_B[1] + 2, outer: RING_B[1] + 2.5, visible: false };
  return { start, end, inner: CORE - 6, outer: CORE, visible: false };
}

function colorOf(node: SunNode): string {
  const category = Math.max(node.category, 0);
  if (node.depth === 1) return sunColors[category].color();
  const ramp = sunRamps[category];
  if (node.depth === 2) return ramp[node.tone % ramp.length].mixed(RGB.white, 0.16).color();
  return ramp[node.tone % ramp.length].mixed(RGB.white, 0.34 + 0.1 * node.sibling).color();
}

const arcs = sunNodes.slice(1);
const categories = sunNodes.filter((n) => n.depth === 1).map((n) => n.id);

export default function Sunburst({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const [focus, setFocus] = useState(0);
  const [spotlight, setSpotlight] = useState<number | null>(null);
  const focusRef = useRef(0);
  const spotRef = useRef<number | null>(null);
  /** Per arc: start, end, inner, outer, visibility. */
  const geo = useNums(
    arcs.length * 5,
    arcs.flatMap((node) => {
      const p = placement(node, 0);
      return [p.start, p.end, p.inner, p.outer, p.visible ? 1 : 0];
    }),
  );
  const dim = useNums(arcs.length, 0);
  const entrance = useNums(1, 0);
  const autoStep = useRef(0);

  const applyDim = (spot: number | null, t: ReturnType<typeof spring>) => {
    arcs.forEach((node, i) => dim.to(i, spot !== null && spot !== node.id && node.parent !== spot ? 1 : 0, t));
  };

  /** Taps and autoplay share this: every arc re-targets in one spring. */
  const zoom = (node: number) => {
    if (node === focusRef.current) return;
    haptics.tap(node === 0 ? "light" : "medium");
    const s = spring(ctx.n("response"), ctx.n("damping"));
    focusRef.current = node;
    spotRef.current = null;
    setFocus(node);
    setSpotlight(null);
    arcs.forEach((n, i) => {
      const p = placement(n, node);
      [p.start, p.end, p.inner, p.outer, p.visible ? 1 : 0].forEach((value, k) => geo.to(i * 5 + k, value, s));
    });
    applyDim(null, s);
  };

  const highlight = (node: number | null) => {
    if (node === spotRef.current) return;
    haptics.selection();
    spotRef.current = node;
    setSpotlight(node);
    applyDim(node, spring(0.35, 0.75));
  };

  const tap = (e: React.MouseEvent<HTMLDivElement>) => {
    const location = localPoint(e, e.currentTarget);
    const dx = location.x - SIDE / 2;
    const dy = location.y - SIDE / 2;
    const radius = Math.hypot(dx, dy);
    const f = focusRef.current;
    if (radius <= CORE + 2) {
      if (spotRef.current !== null) highlight(null);
      else zoom(sunNodes[f].parent ?? 0);
      return;
    }
    let ring: number;
    if (radius <= RING_A[1] + 1.5) ring = 1;
    else if (radius <= RING_B[1] + 10) ring = 2;
    else {
      highlight(null);
      return;
    }
    let fraction = (Math.atan2(dy, dx) + Math.PI / 2) / (2 * Math.PI);
    if (fraction < 0) fraction += 1;
    const depth = sunNodes[f].depth + ring;
    const hit = sunNodes.find((node) => {
      if (node.depth !== depth) return false;
      const place = placement(node, f);
      return fraction >= place.start && fraction < place.end;
    });
    if (!hit) return;
    if (f === 0) {
      // At the root, either ring drills into the category that owns the tapped arc.
      zoom(ring === 1 ? hit.id : (hit.parent ?? 0));
    } else {
      const item = ring === 1 ? hit.id : (hit.parent ?? hit.id);
      highlight(spotRef.current === item ? null : item);
    }
  };

  const autoAdvance = () => {
    const step = autoStep.current % 6;
    autoStep.current += 1;
    if (step === 0) zoom(categories[0]);
    else if (step === 1) highlight(sunNodes.find((n) => n.parent === categories[0])?.id ?? null);
    else if (step === 2) zoom(0);
    else if (step === 3) zoom(categories[2]);
    else if (step === 4) highlight([...sunNodes].reverse().find((n) => n.parent === categories[2])?.id ?? null);
    else zoom(0);
  };

  useChartEntrance(() => entrance.to(0, 1, spring(0.8, 0.78)));
  // The entrance already plays on arrival; the intro would leave the chart zoomed in.
  useAutoplay(ctx.isPreview, autoAdvance, { every: 1.7, delay: 1.5, intro: false });

  const gap = ctx.n("gap");
  const draw = (g: G) => {
    const cx = g.width / 2;
    const cy = g.height / 2;
    arcs.forEach((node, i) => {
      const start = geo.get(i * 5);
      const end = geo.get(i * 5 + 1);
      const inner = geo.get(i * 5 + 2);
      const outer = geo.get(i * 5 + 3);
      const opacity = clamp01(geo.get(i * 5 + 4)) * (1 - 0.7 * clamp01(dim.get(i)));
      if (opacity <= 0.003) return;
      const sweep = (end - start) * 2 * Math.PI;
      if (!(sweep > 0.004 && outer - inner > 0.5 && outer > 1)) return;
      const from = start * 2 * Math.PI - Math.PI / 2;
      const padOuter = Math.min(gap / 2 / outer, sweep * 0.45);
      const padInner = Math.min(gap / 2 / Math.max(inner, 1), sweep * 0.45);
      const path = new Path2D();
      path.arc(cx, cy, outer, from + padOuter, from + sweep - padOuter, false);
      path.arc(cx, cy, Math.max(inner, 0.5), from + sweep - padInner, from + padInner, true);
      path.closePath();
      g.fill(path, colorOf(node), opacity);
    });
  };

  const e = entrance.get();
  const target = sunNodes[focus];
  const shown = sunNodes[spotlight ?? focus];
  const zoomed = focus !== 0;
  const tint = zoomed ? sunColors[Math.max(sunNodes[focus].category, 0)].color(0.16) : "transparent";
  const labelRadius = (RING_A[0] + RING_A[1]) / 2;

  return (
    <ChartStage ctx={ctx} hint={["Tap a segment to drill in, the centre to go back", "点击扇区钻入，点击中心返回"]}>
      <div
        onClick={tap}
        style={{ position: "relative", width: SIDE, height: SIDE, transform: `rotate(${-50 * (1 - e)}deg) scale(${0.82 + 0.18 * e})`, opacity: clamp01(e), cursor: "pointer" }}
      >
        <Plot ctx={ctx} width={SIDE} height={SIDE} draw={draw} style={{ position: "absolute", inset: 0 }} />
        <AnimatePresence initial={false}>
          <motion.div
            key={focus}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={spring(ctx.n("response"), ctx.n("damping"))}
            style={{ position: "absolute", inset: 0, pointerEvents: "none" }}
          >
            {/* Names on the inner ring, only where the arc is wide enough to carry one. */}
            {sunNodes
              .filter((node) => node.depth === target.depth + 1)
              .map((node) => {
                const place = placement(node, focus);
                if (!(place.end - place.start > 0.1)) return null;
                const mid = ((place.start + place.end) / 2) * 2 * Math.PI - Math.PI / 2;
                return (
                  <div
                    key={node.id}
                    style={{
                      position: "absolute",
                      left: SIDE / 2 + Math.cos(mid) * labelRadius,
                      top: SIDE / 2 + Math.sin(mid) * labelRadius,
                      transform: "translate(-50%, -50%)",
                      ...sys(10, 700),
                      color: "#fff",
                      textShadow: `0 0.5px 2px ${black(0.25)}`,
                    }}
                  >
                    {ctx.t(node.en, node.zh)}
                  </div>
                );
              })}
          </motion.div>
        </AnimatePresence>
        <div
          style={{
            position: "absolute",
            left: SIDE / 2 - CORE,
            top: SIDE / 2 - CORE,
            width: CORE * 2,
            height: CORE * 2,
            borderRadius: "50%",
            background: `linear-gradient(${tint}, ${tint}), ${Palette.elevated}`,
            transition: "background 0.4s",
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 16px ${black(0.1)}`,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            pointerEvents: "none",
          }}
        >
          <AnimatePresence initial={false}>
            {zoomed && (
              <motion.div
                key="back"
                initial={{ scale: 0, opacity: 0, height: 0 }}
                animate={{ scale: 1, opacity: 1, height: 11 }}
                exit={{ scale: 0, opacity: 0, height: 0 }}
                transition={spring(ctx.n("response"), ctx.n("damping"))}
                style={{ display: "grid", placeItems: "center", color: Palette.secondaryLabel }}
              >
                <ChevronLeft size={10} strokeWidth={4.5} />
              </motion.div>
            )}
          </AnimatePresence>
          <NumericText value={swiftRound(shown.value)} style={{ fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 700 }} />
          <div style={{ ...sys(9, 600), color: Palette.secondaryLabel, maxWidth: CORE * 2 - 10 }}>{ctx.t(shown.en, shown.zh)} · GB</div>
        </div>
      </div>
    </ChartStage>
  );
}
