/** morph.masonry-shuffle · 瀑布流洗牌 (Morph+MasonryShuffle.swift) */
import { motion } from "motion/react";
import { Building2, Flower2, Sun, TreePine, Waves } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, delayed, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Column, diag, morphScreen } from "./_shared";
import { Mountain2, type SymbolComponent } from "./_symbols";

const S = (I: unknown) => I as SymbolComponent;
const tiles: { title: [string, string]; caption: [string, string]; Icon: SymbolComponent; colors: [string, string] }[] = [
  { title: ["Coast", "海岸"], caption: ["42 photos", "42 张照片"], Icon: S(Waves), colors: [Palette.sky, Palette.blue] },
  { title: ["Forest", "森林"], caption: ["18 photos", "18 张照片"], Icon: S(TreePine), colors: [Palette.mint, "#1B9E77"] },
  { title: ["Dunes", "沙丘"], caption: ["27 photos", "27 张照片"], Icon: S(Sun), colors: [Palette.amber, Palette.coral] },
  { title: ["City", "城市"], caption: ["64 photos", "64 张照片"], Icon: S(Building2), colors: [Palette.indigo, Palette.violet] },
  { title: ["Peaks", "雪峰"], caption: ["31 photos", "31 张照片"], Icon: Mountain2, colors: ["#8E9BB8", "#4B5878"] },
  { title: ["Bloom", "花季"], caption: ["12 photos", "12 张照片"], Icon: S(Flower2), colors: [Palette.pink, "#D9358A"] },
];
const W = 316;
const H = 306;
const INSET = 12;
/** (column, row, column span, row span) on a 6 × 6 grid; slot 0 is always the hero. */
const layouts: [number, number, number, number][][] = [
  [[0, 0, 4, 3], [4, 0, 2, 2], [4, 2, 2, 4], [0, 3, 2, 3], [2, 3, 2, 2], [2, 5, 2, 1]],
  [[2, 0, 4, 2], [0, 0, 2, 4], [2, 2, 2, 2], [4, 2, 2, 3], [0, 4, 4, 2], [4, 5, 2, 1]],
  [[2, 2, 4, 4], [0, 0, 3, 2], [3, 0, 3, 2], [0, 2, 2, 2], [0, 4, 2, 1], [0, 5, 2, 1]],
  [[3, 0, 3, 3], [0, 0, 3, 2], [0, 2, 3, 1], [0, 3, 2, 3], [2, 3, 2, 3], [4, 3, 2, 3]],
];
function rectFor(layout: number, slot: number, gap: number) {
  const u = layouts[layout % layouts.length][slot];
  const width = (W - INSET * 2 - gap * 5) / 6;
  const height = (H - INSET * 2 - gap * 5) / 6;
  return { x: INSET + u[0] * (width + gap), y: INSET + u[1] * (height + gap), w: u[2] * width + (u[2] - 1) * gap, h: u[3] * height + (u[3] - 1) * gap };
}

export default function MasonryShuffle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [state, setState] = useState({ layout: 0, slots: [0, 1, 2, 3, 4, 5] });
  const latest = useRef(state);
  latest.current = state;
  const autoIndex = useRef(0);
  const L = ctx.lang === "zh" ? 1 : 0;

  /** Promote `index` to the hero slot of the next layout and deal the others around it. */
  const feature = (index: number) => {
    haptics.tap("light");
    const { slots, layout } = latest.current;
    // The others keep their relative order, shifted by one so every tile moves.
    const others = [0, 1, 2, 3, 4, 5].filter((i) => i !== index).sort((a, b) => slots[a] - slots[b]);
    const next = [...slots];
    next[index] = 0;
    others.forEach((tile, rank) => {
      next[tile] = 1 + ((rank + 1) % 5);
    });
    const value = { layout: (layout + 1) % layouts.length, slots: next };
    latest.current = value;
    setState(value);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const order = [3, 1, 5, 0, 4, 2];
      feature(order[autoIndex.current % order.length]);
      autoIndex.current += 1;
    },
    { every: 1.5 },
  );

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        {tiles.map((info, index) => {
          const slot = state.slots[index];
          const rect = rectFor(state.layout, slot, ctx.n("gap"));
          const move = delayed(spring(ctx.n("response"), ctx.n("damping")), slot * ctx.n("stagger"));
          const roomy = rect.w > 120 && rect.h > 80;
          const slim = rect.h < 56;
          const tall = roomy && rect.h > 110;
          return (
            <motion.div
              key={index}
              onClick={() => feature(index)}
              initial={false}
              animate={{ left: rect.x, top: rect.y, width: rect.w, height: rect.h }}
              transition={move}
              style={{ position: "absolute", zIndex: index, borderRadius: 20, overflow: "hidden", background: diag(...info.colors), boxShadow: `0 4px 8px ${black(0.16)}`, color: "#fff", cursor: "pointer" }}
            >
              <motion.div
                initial={false}
                animate={{ scale: tall ? 1.6 : 1, opacity: slim ? 0 : roomy ? 0.95 : 0.9 }}
                transition={move}
                style={{ position: "absolute", left: 12, top: 12, transformOrigin: "0 0" }}
              >
                <info.Icon size={25} strokeWidth={2.3} />
              </motion.div>
              <motion.div
                initial={false}
                animate={{ bottom: slim ? rect.h / 2 - 8.5 : 10 }}
                transition={move}
                style={{ position: "absolute", left: 12, right: 12, display: "flex", flexDirection: "column", gap: 1 }}
              >
                <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 700, whiteSpace: "nowrap" }}>{info.title[L]}</span>
                <motion.span
                  initial={false}
                  animate={{ opacity: roomy ? 0.85 : 0, height: roomy ? 13 : 0 }}
                  transition={move}
                  style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", marginTop: roomy ? 0 : -1 }}
                >
                  {info.caption[L]}
                </motion.span>
              </motion.div>
              <div style={{ position: "absolute", inset: 0, borderRadius: 20, boxShadow: `inset 0 0 0 1px ${white(0.2)}`, pointerEvents: "none" }} />
            </motion.div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap a tile to feature it" zh="点一块砖，把它设为主角" />
    </Column>
  );
}
