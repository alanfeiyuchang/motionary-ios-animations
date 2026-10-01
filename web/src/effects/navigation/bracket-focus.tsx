/** navigation.bracket-focus · 对焦框标签 (Navigation+BracketFocus.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, spring, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { useTextWidths } from "./groupA-kit";
import { diag, stageColumn, useAutoplayFlag, useNavPan } from "./_r2";

const glyph = (children: ReactNode) => (
  <svg width={46} height={46} viewBox="0 0 24 24" fill="currentColor" style={{ display: "block" }}>
    {children}
  </svg>
);
const ICONS = [
  // camera.fill
  glyph(<path fillRule="evenodd" d="M8.6 4.2a1.6 1.6 0 0 0-1.4.8L6.4 6.5H4.6A2.6 2.6 0 0 0 2 9.1v8.3A2.6 2.6 0 0 0 4.6 20h14.8a2.6 2.6 0 0 0 2.6-2.6V9.1a2.6 2.6 0 0 0-2.6-2.6h-1.8L16.8 5a1.6 1.6 0 0 0-1.4-.8ZM12 8.6a4.4 4.4 0 1 1 0 8.8 4.4 4.4 0 0 1 0-8.8Zm0 1.7a2.7 2.7 0 1 0 0 5.4 2.7 2.7 0 0 0 0-5.4Zm6.6-1.2a.9.9 0 1 1 0 1.8.9.9 0 0 1 0-1.8Z" />),
  // video.fill
  glyph(<path d="M3.8 6h9.4A2.8 2.8 0 0 1 16 8.8v6.4a2.8 2.8 0 0 1-2.8 2.8H3.8A2.8 2.8 0 0 1 1 15.200V8.8A2.8 2.8 0 0 1 3.8 6Zm13.700 4.300 3.900-2.800a1 1 0 0 1 1.600.8v7.400a1 1 0 0 1-1.600.8l-3.900-2.800Z" />),
  // person.crop.square.fill
  glyph(<path fillRule="evenodd" d="M6 2.500h12A3.500 3.500 0 0 1 21.500 6v12a3.500 3.500 0 0 1-3.500 3.500H6A3.500 3.500 0 0 1 2.500 18V6A3.500 3.500 0 0 1 6 2.500Zm6 3.900a3.400 3.400 0 1 0 0 6.800 3.400 3.400 0 0 0 0-6.800ZM5.600 19.600h12.800c-.6-3-3.200-4.800-6.400-4.800s-5.800 1.800-6.400 4.800Z" />),
  // pano.fill
  glyph(<path d="M2 6.600c0-.8.800-1.300 1.500-1 2.700 1 5.500 1.500 8.500 1.500s5.800-.5 8.500-1.500c.700-.3 1.500.2 1.500 1v10.800c0 .8-.800 1.300-1.500 1-2.700-1-5.500-1.500-8.500-1.500s-5.800.5-8.500 1.500c-.700.3-1.500-.2-1.500-1Z" />),
];

const MODES: { title: [string, string]; colors: [string, string]; size: [number, number] }[] = [
  { title: ["PHOTO", "照片"], colors: [Palette.indigo, Palette.violet], size: [216, 162] },
  { title: ["VIDEO", "视频"], colors: [Palette.coral, Palette.pink], size: [280, 158] },
  { title: ["PORTRAIT", "人像"], colors: [Palette.mint, Palette.sky], size: [132, 172] },
  { title: ["PANO", "全景"], colors: [Palette.amber, Palette.coral], size: [300, 104] },
];
const ROW_H = 36;
const INSET = { w: 3, h: 4 };
const LABEL = { fontSize: 13, lineHeight: "16px", fontWeight: 600, letterSpacing: 0.8 } as const;

/** One L-shaped corner; mirrored copies make the other three. */
function Corner({ arm, flipX, flipY, x, y }: { arm: number; flipX: boolean; flipY: boolean; x: MotionValue<number>; y: MotionValue<number> }) {
  const r = Math.min(4, arm * 0.45);
  return (
    <motion.svg width={arm} height={arm} style={{ position: "absolute", left: 0, top: 0, x, y, overflow: "visible" }}>
      <path
        d={`M0 ${arm}L0 ${r}Q0 0 ${r} 0L${arm} 0`}
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
        transform={`translate(${flipX ? arm : 0} ${flipY ? arm : 0}) scale(${flipX ? -1 : 1} ${flipY ? -1 : 1})`}
      />
    </motion.svg>
  );
}

export default function BracketFocus({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [selection, setSelection] = useState(0);
  const [gripped, setGripped] = useState<number | null>(0);
  const cancelClamp = useRef<(() => void) | null>(null);

  const zh = ctx.lang === "zh";
  const padding = zh ? 20 : 13;
  const [widths, probe] = useTextWidths(MODES.map((m) => ctx.t(...m.title)), LABEL);
  let run = 0;
  const cells = widths.map((w) => {
    const cell = { minX: run, maxX: run + w + padding * 2, width: w + padding * 2 };
    run = cell.maxX;
    return cell;
  });
  const total = run;
  const cellsRef = useRef(cells);
  cellsRef.current = cells;

  // Edge positions and the two pairs' openness (each pair rides its own spring), plus the tint's.
  const leftX = useMotionValue(0);
  const rightX = useMotionValue(0);
  const openL = useMotionValue(0);
  const openR = useMotionValue(0);
  const openTint = useMotionValue(0);
  const settled = useRef({ index: -1, key: "" });
  const key = cells.map((c) => c.maxX).join(",");
  if (settled.current.key !== key && widths[0] > 0) {
    // First layout / language switch: sit on the current cell without animating.
    settled.current = { index: selection, key };
    leftX.jump(cells[selection].minX);
    rightX.jump(cells[selection].maxX);
  }

  const arm = ctx.n("arm");
  const openBy = ctx.n("open");
  const lx = useTransform(() => leftX.get() + INSET.w - openL.get() * openBy);
  const rx = useTransform(() => rightX.get() - INSET.w + openR.get() * openBy - arm);
  const topL = useTransform(() => INSET.h - openL.get() * openBy);
  const botL = useTransform(() => ROW_H - INSET.h + openL.get() * openBy - arm);
  const topR = useTransform(() => INSET.h - openR.get() * openBy);
  const botR = useTransform(() => ROW_H - INSET.h + openR.get() * openBy - arm);
  const tintOpacity = useTransform(openTint, (o) => 1 - 0.45 * o);

  const auto = useAutoplayFlag(ctx.isPreview, () => select((selection + 1) % MODES.length), { every: 1.5 });

  function select(index: number) {
    if (index === selection) return;
    const movingRight = index > selection;
    cancelClamp.current?.();
    haptics.selection();
    const silent = auto.current;
    const response = ctx.n("response");
    const edge = (front: boolean) => spring(response * (front ? 0.7 : 1.3), front ? 0.78 : 0.86);
    setSelection(index);
    setGripped(null);
    const target = cellsRef.current[index];
    animate(leftX, target.minX, edge(!movingRight));
    animate(openL, 1, edge(!movingRight));
    animate(rightX, target.maxX, edge(movingRight));
    animate(openR, 1, edge(movingRight));
    animate(openTint, 1, anim.easeOut(0.12));
    const grip = ctx.n("grip");
    cancelClamp.current = after(response * 0.62, () => {
      const clamp = spring(0.28, grip);
      animate(openL, 0, clamp);
      animate(openR, 0, clamp);
      animate(openTint, 0, clamp);
      setGripped(index);
      if (!silent) haptics.tap("light");
    });
  }

  const swipe = useNavPan(
    {
      onEnd: (s) => {
        if (!s || Math.abs(s.translation.x) <= 30) return;
        const next = selection + (s.translation.x < 0 ? 1 : -1);
        if (next >= 0 && next < MODES.length) select(next);
      },
    },
    { axis: "horizontal" },
  );

  const mode = MODES[selection];
  const move = spring(ctx.n("response"), 0.8);

  return (
    <div style={stageColumn(16)}>
      {probe}
      {/* viewfinder */}
      <div {...swipe} style={{ width: 300, height: 174, display: "grid", placeItems: "center", flexShrink: 0, touchAction: "pan-y" }}>
        <motion.div
          initial={false}
          animate={{ width: mode.size[0], height: mode.size[1], boxShadow: `0 10px 18px ${alpha(mode.colors[0], 0.35)}` }}
          transition={move}
          style={{ position: "relative", borderRadius: 22, overflow: "hidden" }}
        >
          {MODES.map((m, index) => (
            <motion.div key={index} initial={false} animate={{ opacity: index === selection ? 1 : 0 }} transition={move} style={{ position: "absolute", inset: 0, background: diag(...m.colors) }} />
          ))}
          {/* rule of thirds */}
          {[1, 2].map((k) => (
            <div key={`v${k}`} style={{ position: "absolute", left: `${(k * 100) / 3}%`, top: 0, bottom: 0, width: 0.5, background: white(0.28) }} />
          ))}
          {[1, 2].map((k) => (
            <div key={`h${k}`} style={{ position: "absolute", top: `${(k * 100) / 3}%`, left: 0, right: 0, height: 0.5, background: white(0.28) }} />
          ))}
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: white(0.94), filter: "drop-shadow(0 4px 8px rgb(0 0 0 / 0.18))" }}>
            <AnimatePresence initial={false}>
              <motion.div
                key={selection}
                initial={{ opacity: 0, scale: 0.6, filter: "blur(4px)" }}
                animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                exit={{ opacity: 0, scale: 0.6, filter: "blur(4px)" }}
                transition={move}
                style={{ gridArea: "1 / 1" }}
              >
                {ICONS[selection]}
              </motion.div>
            </AnimatePresence>
          </div>
        </motion.div>
      </div>
      {/* mode row */}
      <div style={{ position: "relative", width: total, height: ROW_H, flexShrink: 0 }}>
        <div style={{ display: "flex" }}>
          {MODES.map((m, index) => {
            const active = gripped === index;
            return (
              <div key={index} onClick={() => select(index)} style={{ width: cells[index].width, height: ROW_H, display: "grid", placeItems: "center", cursor: "pointer" }}>
                <motion.span
                  initial={false}
                  animate={{ scale: active ? 1.06 : 1 }}
                  transition={active ? spring(0.28, ctx.n("grip")) : anim.easeOut(0.12)}
                  style={{
                    ...LABEL,
                    whiteSpace: "nowrap",
                    display: "block",
                    color: active ? Palette.label : ctx.scheme === "dark" ? "rgb(235 235 245 / 0.45)" : "rgb(60 60 67 / 0.45)",
                    transition: active ? "color 0.25s ease-out" : "color 0.12s ease-out",
                  }}
                >
                  {ctx.t(...m.title)}
                </motion.span>
              </div>
            );
          })}
        </div>
        <motion.div style={{ position: "absolute", inset: 0, color: Palette.indigo, opacity: tintOpacity, pointerEvents: "none" }}>
          <Corner arm={arm} flipX={false} flipY={false} x={lx} y={topL} />
          <Corner arm={arm} flipX={false} flipY x={lx} y={botL} />
          <Corner arm={arm} flipX flipY={false} x={rx} y={topR} />
          <Corner arm={arm} flipX flipY x={rx} y={botR} />
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap a mode, or swipe the viewfinder" zh="点击模式，或左右滑动取景器" />
    </div>
  );
}
