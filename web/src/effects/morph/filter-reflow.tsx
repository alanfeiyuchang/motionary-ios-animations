/** morph.filter-reflow · 筛选重排 (Morph+FilterReflow.swift) */
import { motion } from "motion/react";
import { AudioLines, Image as ImageIcon, Play } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, delayed, fonts, hex, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Column, diag, morphScreen } from "./_shared";

const TILE = 66;
const GAP = 9;
const TOP = 66;
const types = [0, 1, 0, 2, 1, 0, 2, 1, 0, 1, 2, 0];
const colors: [string, string][] = [
  [Palette.pink, Palette.coral],
  [Palette.indigo, Palette.violet],
  [Palette.amber, "#FF9A2E"],
];
const filters: [string, string][] = [
  ["All", "全部"],
  ["Photos", "照片"],
  ["Videos", "视频"],
  ["Audio", "音频"],
];
const primaryStrong = diag("#4B57E0", "#7A45D6");
function center(slot: number) {
  const left = (316 - TILE * 4 - GAP * 3) / 2;
  return { x: left + TILE / 2 + (slot % 4) * (TILE + GAP), y: TOP + TILE / 2 + Math.floor(slot / 4) * (TILE + GAP) };
}
/** Slot of every item for `filter` (0 = all); `null` when the item is filtered out. */
function slotsFor(filter: number): (number | null)[] {
  let next = 0;
  return types.map((type) => (filter === 0 || type === filter - 1 ? next++ : null));
}

interface State {
  filter: number;
  /** Current slot of every tile; a hidden tile keeps the last slot it had. */
  slots: number[];
  shown: boolean[];
  /** Tiles that were visible before the last change and still are: only these glide. */
  glides: boolean[];
}

export default function FilterReflow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [state, setState] = useState<State>({ filter: 0, slots: types.map((_, i) => i), shown: types.map(() => true), glides: types.map(() => true) });
  const latest = useRef(state);
  latest.current = state;
  const L = ctx.lang === "zh" ? 1 : 0;

  const select = (value: number) => {
    const s = latest.current;
    if (value === s.filter) return;
    haptics.selection();
    const target = slotsFor(value);
    const slots = [...s.slots];
    const shown = [...s.shown];
    const glides = [...s.glides];
    target.forEach((slot, index) => {
      if (slot !== null) {
        glides[index] = s.shown[index];
        slots[index] = slot;
        shown[index] = true;
      } else {
        glides[index] = false;
        shown[index] = false;
      }
    });
    const next = { filter: value, slots, shown, glides };
    latest.current = next;
    setState(next);
  };
  useAutoplay(ctx.isPreview, () => select((latest.current.filter + 1) % 4), { every: 1.5 });

  const count = state.shown.filter(Boolean).length;
  const pick = spring(0.36, 0.8);

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        <div style={{ position: "absolute", left: 12, right: 12, top: 14, display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ position: "relative", padding: 3, borderRadius: 18, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, display: "flex" }}>
            <motion.div initial={false} animate={{ x: state.filter * 54 }} transition={pick} style={{ position: "absolute", left: 3, top: 3, width: 54, height: 30, borderRadius: 15, background: primaryStrong }} />
            {filters.map((f, index) => (
              <button
                key={index}
                type="button"
                onClick={() => select(index)}
                style={{ position: "relative", width: 54, height: 30, fontSize: f[L].length > 6 ? 11 : 12, fontWeight: 600, whiteSpace: "nowrap", color: index === state.filter ? "#fff" : Palette.secondaryLabel, transition: "color 0.25s" }}
              >
                {f[L]}
              </button>
            ))}
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ paddingRight: 26, fontSize: 20, fontWeight: 700, fontFamily: fonts.rounded }}>
            <NumericText value={count} />
          </span>
        </div>
        {types.map((type, index) => {
          const visible = state.shown[index];
          const slot = state.slots[index];
          const delay = slot * ctx.n("stagger");
          const c = center(slot);
          // A returning tile takes its slot at once (no travel); only tiles that stayed visible glide.
          const glide = state.glides[index] ? delayed(spring(ctx.n("response"), ctx.n("damping")), 0.06 + delay) : { duration: 0 };
          const appear = visible ? delayed(spring(0.42, 0.6), 0.16 + delay) : anim.easeIn(0.18);
          const Icon = [ImageIcon, Play, AudioLines][type];
          return (
            <motion.div
              key={index}
              initial={false}
              animate={{ x: c.x - TILE / 2, y: c.y - TILE / 2, scale: visible ? 1 : ctx.n("exit"), opacity: visible ? 1 : 0, filter: `blur(${visible ? 0 : 4}px)` }}
              transition={{ x: glide, y: glide, default: appear }}
              style={{
                position: "absolute",
                left: 0,
                top: 0,
                width: TILE,
                height: TILE,
                borderRadius: 18,
                background: `linear-gradient(${black((index % 4) * 0.045)}, ${black((index % 4) * 0.045)}), ${diag(...colors[type])}`,
                boxShadow: `inset 0 0 0 1px ${white(0.22)}, 0 4px 6px ${hex(colors[type][1], 0.3)}`,
                color: "#fff",
                display: "grid",
                placeItems: "center",
                pointerEvents: "none",
              }}
            >
              <Icon size={25} strokeWidth={2.4} fill={type === 1 ? "currentColor" : "none"} />
              <span style={{ position: "absolute", right: 7, bottom: 7, fontSize: 10, lineHeight: "12px", fontWeight: 700, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums", color: white(0.8) }}>
                {String(index + 1).padStart(2, "0")}
              </span>
            </motion.div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap a filter" zh="点击筛选项" />
    </Column>
  );
}
