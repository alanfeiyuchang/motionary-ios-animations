/** navigation.split-pane · 可拖动分栏 (Navigation+SplitPane.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Film, List } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, rubberBand, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { BlurReplace, SquareGrid2x2Fill } from "./groupA-kit";
import { colorGradient, predicted, useMotionNumber } from "./nav-util";
import { DocTextFill, PhotoFill, TrayFullFill, stageColumn, useNavPan } from "./_r2";

const SECTIONS: { icon: ReactNode; title: [string, string]; subtitle: [string, string]; count: number; color: string }[] = [
  { icon: <TrayFullFill size={14} />, title: ["All", "全部"], subtitle: ["Everything", "所有项目"], count: 24, color: Palette.indigo },
  { icon: <PhotoFill size={14} />, title: ["Images", "图片"], subtitle: ["Shots & art", "截图与插画"], count: 12, color: Palette.pink },
  { icon: <DocTextFill size={14} />, title: ["Docs", "文档"], subtitle: ["Notes & specs", "笔记与规格"], count: 7, color: Palette.mint },
  { icon: <Film size={14} strokeWidth={2.8} />, title: ["Clips", "视频"], subtitle: ["Recordings", "录屏片段"], count: 5, color: Palette.amber },
];
const FRAME = { w: 300, h: 252 };
const SNAPS = [52, 118, 176];
const DIVIDER = 14;
const TILES = 6;

const smooth = (value: number, from: number, to: number) => {
  const t = Math.min(Math.max((value - from) / (to - from), 0), 1);
  return t * t * (3 - 2 * t);
};
const columnsFor = (sidebar: number) => {
  const detail = FRAME.w - sidebar - DIVIDER;
  return detail > 200 ? 3 : detail > 130 ? 2 : 1;
};

function tileRect(index: number, columns: number, width: number, height: number) {
  const gap = 7;
  const rows = Math.ceil(TILES / columns);
  const w = (width - gap * (columns - 1)) / columns;
  const h = (height - gap * (rows - 1)) / rows;
  return { x: (index % columns) * (w + gap), y: Math.floor(index / columns) * (h + gap), w: Math.max(w, 10), h: Math.max(h, 10) };
}

/** `square.grid.3x2.fill` */
const Grid3x2 = () => (
  <svg width={15} height={15} viewBox="0 0 24 24" fill="currentColor">
    {[0, 1, 2].map((c) => [0, 1].map((r) => <rect key={`${c}${r}`} x={1.5 + c * 7.4} y={5 + r * 7.4} width={6.2} height={6.2} rx={1.6} />))}
  </svg>
);

export default function SplitPane({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const sidebarMV = useMotionValue(SNAPS[1]);
  const sidebar = useMotionNumber(sidebarMV);
  /** The sidebar width the model holds (drag value, or the snap an animation heads to). */
  const goal = useRef(SNAPS[1]);
  const dragStart = useRef<number | null>(null);
  const rejected = useRef(false);
  const [held, setHeld] = useState(false);
  const [selection, setSelection] = useState(0);
  const autoStep = useRef(0);
  // Column count and the blend from the previous layout to the current one.
  const [cols, setCols] = useState({ from: 2, to: 2 });
  const colsRef = useRef(2);
  const blendMV = useMotionValue(1);
  const blend = useMotionNumber(blendMV);

  const move = spring(ctx.n("response"), ctx.n("damping"));

  const setGoal = (width: number) => {
    goal.current = width;
    const count = columnsFor(width);
    if (count !== colsRef.current) {
      setCols({ from: colsRef.current, to: count });
      colsRef.current = count;
      blendMV.jump(0);
      animate(blendMV, 1, move);
    }
  };

  const settle = (index: number) => {
    haptics.tap("light");
    setGoal(SNAPS[index]);
    animate(sidebarMV, SNAPS[index], move);
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (rejected.current) return;
        if (dragStart.current === null) {
          if (Math.abs(s.start.x - (goal.current + DIVIDER / 2)) >= 24) {
            rejected.current = true;
            return;
          }
          sidebarMV.stop();
          dragStart.current = sidebarMV.get();
          setHeld(true);
        }
        const low = SNAPS[0];
        const high = SNAPS[SNAPS.length - 1];
        let width = dragStart.current + s.translation.x;
        const band = Math.max(ctx.n("band"), 1);
        if (width < low) width = low - rubberBand(low - width, band * 0.6);
        if (width > high) width = high + rubberBand(width - high, band);
        sidebarMV.set(width);
        setGoal(width);
      },
      onEnd: (s) => {
        rejected.current = false;
        const start = dragStart.current;
        if (start === null) return;
        const projected = s ? start + predicted(s).x : sidebarMV.get();
        const target = SNAPS.reduce((best, snap) => (Math.abs(snap - projected) < Math.abs(best - projected) ? snap : best), SNAPS[0]);
        haptics.tap("light");
        dragStart.current = null;
        setHeld(false);
        setGoal(target);
        animate(sidebarMV, target, move);
      },
    },
    { axis: "horizontal", minimumDistance: 4 },
  );

  /** Tap on the grip: go to the next snap size (wrapping round). */
  const step = () => {
    if (dragStart.current !== null) return;
    let best = 0;
    SNAPS.forEach((snap, index) => {
      if (Math.abs(snap - goal.current) < Math.abs(SNAPS[best] - goal.current)) best = index;
    });
    settle((best + 1) % SNAPS.length);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const tour = [2, 1, 0, 1];
      settle(tour[autoStep.current % tour.length]);
      autoStep.current += 1;
    },
    { every: 1.4 },
  );

  const detailWidth = FRAME.w - sidebar - DIVIDER;
  const labels = smooth(sidebar, 72, 104);
  const wide = smooth(sidebar, 140, 172);
  const section = SECTIONS[selection];
  const gridW = Math.max(detailWidth, 40) - 20;
  const gridH = FRAME.h - 58;
  const list = cols.to === 1;
  const grip = spring(0.28, 0.7);

  return (
    <div style={stageColumn(14)}>
      <div
        {...pan}
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          display: "flex",
          borderRadius: 28,
          background: Palette.elevated,
          boxShadow: `0 10px 18px rgb(0 0 0 / 0.16)`,
          overflow: "hidden",
          touchAction: "pan-y",
        }}
      >
        {/* sidebar */}
        <div style={{ width: Math.max(sidebar, 30), height: "100%", flexShrink: 0, boxSizing: "border-box", padding: "12px 2px 0 8px", display: "flex", flexDirection: "column", gap: 4, background: Palette.labelAlpha(0.035), overflow: "hidden" }}>
          {SECTIONS.map((s, index) => {
            const active = selection === index;
            return (
              <div
                key={index}
                onClick={() => {
                  haptics.selection();
                  setSelection(index);
                }}
                style={{
                  height: 34 + 8 * wide,
                  flexShrink: 0,
                  padding: "0 6px 0 4px",
                  display: "flex",
                  alignItems: "center",
                  gap: 9,
                  borderRadius: 11,
                  background: Palette.labelAlpha(active ? 0.07 * labels : 0),
                  transition: "background 0.25s",
                  overflow: "hidden",
                  cursor: "pointer",
                }}
              >
                <div
                  style={{
                    width: 28,
                    height: 28,
                    borderRadius: 9,
                    flexShrink: 0,
                    display: "grid",
                    placeItems: "center",
                    color: active ? "#fff" : s.color,
                    background: alpha(s.color, active ? 1 : 0.16),
                    transition: "background 0.25s, color 0.25s",
                  }}
                >
                  {s.icon}
                </div>
                <div style={{ display: "flex", flexDirection: "column", gap: 1, opacity: labels, flexShrink: 0 }}>
                  <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...s.title)}</span>
                  {wide > 0.01 && (
                    <span style={{ fontSize: 10, lineHeight: "12px", height: 12 * wide, color: Palette.secondaryLabel, opacity: wide, whiteSpace: "nowrap", overflow: "visible" }}>{ctx.t(...s.subtitle)}</span>
                  )}
                </div>
                <div style={{ flex: 1, minWidth: 0 }} />
                <div
                  style={{
                    height: 18,
                    padding: "0 6px",
                    borderRadius: 9,
                    background: Palette.labelAlpha(0.08),
                    color: Palette.secondaryLabel,
                    fontSize: 10,
                    lineHeight: "18px",
                    fontWeight: 700,
                    fontVariantNumeric: "tabular-nums",
                    flexShrink: 0,
                    opacity: wide,
                    transform: `scale(${0.6 + 0.4 * wide})`,
                  }}
                >
                  {s.count}
                </div>
              </div>
            );
          })}
        </div>
        {/* divider */}
        <div style={{ position: "relative", width: DIVIDER, height: "100%", flexShrink: 0, zIndex: 1 }}>
          <motion.div
            initial={false}
            animate={{ width: held ? 2 : 1, backgroundColor: held ? alpha(Palette.indigo, 0.5) : `rgb(var(--ml-label-rgb) / 0.1)` }}
            transition={grip}
            style={{ position: "absolute", left: "50%", top: 0, bottom: 0, x: "-50%" }}
          />
          <motion.div
            initial={false}
            animate={{
              width: held ? 6 : 5,
              height: held ? 50 : 34,
              backgroundColor: held ? Palette.indigo : `rgb(var(--ml-label-rgb) / 0.3)`,
              boxShadow: `0 0 6px ${alpha(Palette.indigo, held ? 0.5 : 0)}`,
            }}
            transition={grip}
            style={{ position: "absolute", left: "50%", top: "50%", x: "-50%", y: "-50%", borderRadius: 3 }}
          />
          {/* a wider invisible strip makes the divider easy to grab */}
          <div onClick={step} style={{ position: "absolute", left: (DIVIDER - 34) / 2, top: 0, bottom: 0, width: 34, cursor: "col-resize" }} />
        </div>
        {/* detail */}
        <div style={{ width: Math.max(detailWidth, 40), height: "100%", flexShrink: 0, boxSizing: "border-box", padding: "14px 14px 0 6px", display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ height: 22, display: "flex", alignItems: "center", gap: 6, flexShrink: 0 }}>
            <BlurReplace id={selection} transition={spring(0.3, 0.8)} style={{ justifyItems: "start" }}>
              <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...section.title)}</span>
            </BlurReplace>
            <div style={{ flex: 1, minWidth: 0 }} />
            <div style={{ color: Palette.secondaryLabel, display: "grid", flexShrink: 0 }}>
              {cols.to === 1 ? <List size={15} strokeWidth={3} /> : cols.to === 2 ? <SquareGrid2x2Fill size={14} /> : <Grid3x2 />}
            </div>
          </div>
          <div style={{ position: "relative", width: gridW, height: gridH, flexShrink: 0 }}>
            {Array.from({ length: TILES }, (_, index) => {
              const a = tileRect(index, cols.from, gridW, gridH);
              const b = tileRect(index, cols.to, gridW, gridH);
              const mixed = { x: a.x + (b.x - a.x) * blend, y: a.y + (b.y - a.y) * blend, w: a.w + (b.w - a.w) * blend, h: a.h + (b.h - a.h) * blend };
              return (
                <div
                  key={index}
                  style={{
                    position: "absolute",
                    left: mixed.x,
                    top: mixed.y,
                    width: Math.max(mixed.w, 1),
                    height: Math.max(mixed.h, 1),
                    borderRadius: list ? 9 : 13,
                    background: colorGradient(alpha(section.color, 0.9 - index * 0.11)),
                    transition: "border-radius 0.3s",
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      left: list ? 10 : 8,
                      bottom: list ? "calc(50% - 2.5px)" : 8,
                      width: list ? 44 : 26,
                      height: 5,
                      borderRadius: 2.5,
                      background: white(0.6),
                      transition: "width 0.3s, left 0.3s, bottom 0.3s",
                    }}
                  />
                </div>
              );
            })}
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 28, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none", zIndex: 2 }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the divider, or tap its grip" zh="拖动分隔条，或点击把手" />
    </div>
  );
}
