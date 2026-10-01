/** navigation.context-toolbar · 上下文工具栏 (Navigation+ContextToolbar.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Blend, Bold, Ellipsis, ImagePlus, Italic, Mic, RotateCwSquare, TextCursor, TextCursorInput, Underline } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, anim, delayed, fonts, glass, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { BlurReplace, useTextWidths } from "./groupA-kit";
import { colorGradient } from "./nav-util";
import { PhotoFill, SealFill, SunHorizonFill, stageColumn } from "./_r2";

interface Tool {
  id: string;
  icon?: ReactNode;
  swatch?: number;
}
const ti = { size: 17, strokeWidth: 2.6 } as const;
const MORE: Tool = { id: "more", icon: <Ellipsis {...ti} /> };
/** `square.on.circle` */
const SquareOnCircle = (
  <svg width={18} height={18} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.4}>
    <rect x={2.5} y={2.5} width={12} height={12} rx={2.5} />
    <path d="M17.6 9.300a6.200 6.200 0 1 1-8.300 8.300" strokeLinecap="round" />
  </svg>
);

function toolsFor(selection: number | null): Tool[] {
  if (selection === 0) return [{ id: "bold", icon: <Bold {...ti} strokeWidth={3} /> }, { id: "italic", icon: <Italic {...ti} /> }, { id: "underline", icon: <Underline {...ti} /> }, MORE];
  if (selection === 1) return [{ id: "rotate", icon: <RotateCwSquare {...ti} /> }, { id: "filter", icon: <Blend {...ti} /> }, MORE];
  if (selection === 2) return [...SWATCHES.map((_, k) => ({ id: `swatch${k}`, swatch: k })), MORE];
  return [
    { id: "addText", icon: <TextCursorInput {...ti} /> },
    { id: "addPhoto", icon: <ImagePlus {...ti} /> },
    { id: "addShape", icon: SquareOnCircle },
    { id: "mic", icon: <Mic {...ti} fill="currentColor" /> },
    MORE,
  ];
}

const CONTEXTS: { icon: ReactNode; label: [string, string]; color: string }[] = [
  { icon: <TextCursor size={15} strokeWidth={3} />, label: ["Text", "文字"], color: Palette.indigo },
  { icon: <PhotoFill size={15} />, label: ["Photo", "照片"], color: Palette.coral },
  { icon: <SealFill size={15} />, label: ["Shape", "图形"], color: Palette.mint },
];
const SWATCHES = [Palette.mint, Palette.amber, Palette.pink, Palette.sky];
/** Selection frames: each object's box with its 8 pt padding. */
const FRAMES = [
  { x: 22, y: 24, w: 156, h: 78 },
  { x: 186, y: 22, w: 108, h: 108 },
  { x: 30, y: 112, w: 80, h: 80 },
];
const CHIP_FONT = { fontSize: 13, lineHeight: "18px", fontWeight: 600 } as const;

export default function ContextToolbar({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selection, setSelection] = useState<number | null>(null);
  const selRef = useRef<number | null>(null);
  const lastSelection = useRef(0);
  const [bold, setBold] = useState(false);
  const [italic, setItalic] = useState(false);
  const [underline, setUnderline] = useState(false);
  const [quarterTurns, setQuarterTurns] = useState(0);
  const [filtered, setFiltered] = useState(false);
  const [swatch, setSwatch] = useState(0);
  const swatchRef = useRef(0);
  const autoStep = useRef(0);
  const [labelWidths, probe] = useTextWidths(CONTEXTS.map((c) => ctx.t(...c.label)), CHIP_FONT);

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const act = spring(0.35, 0.7);
  const blur = ctx.n("blur");

  const select = (index: number | null) => {
    if (index === selRef.current) return;
    haptics.selection();
    selRef.current = index;
    if (index !== null) lastSelection.current = index;
    setSelection(index);
  };
  const perform = (id: string) => {
    haptics.tap("light");
    if (id === "bold") setBold((v) => !v);
    else if (id === "italic") setItalic((v) => !v);
    else if (id === "underline") setUnderline((v) => !v);
    else if (id === "rotate") setQuarterTurns((v) => v + 1);
    else if (id === "filter") setFiltered((v) => !v);
    else if (id.startsWith("swatch")) {
      swatchRef.current = Number(id.slice(6));
      setSwatch(swatchRef.current);
    }
    // Insert tools pick the matching object, so the empty-state bar is useful too.
    else if (id === "addText") select(0);
    else if (id === "addPhoto") select(1);
    else if (id === "addShape") select(2);
  };
  const isActive = (id: string) => (id === "bold" ? bold : id === "italic" ? italic : id === "underline" ? underline : id === "filter" ? filtered : false);

  // Preview loop: select each object in turn and use one of its tools, then clear the selection.
  useAutoplay(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 7;
      autoStep.current += 1;
      if (phase === 0) select(0);
      else if (phase === 1) perform("bold");
      else if (phase === 2) select(1);
      else if (phase === 3) perform("rotate");
      else if (phase === 4) select(2);
      else if (phase === 5) perform(`swatch${(swatchRef.current + 1) % SWATCHES.length}`);
      else select(null);
    },
    { every: 1.2 },
  );

  // Toolbar layout (an HStack with 4 pt spacing inside 8 pt padding), resolved by hand so every item can spring.
  const tools = toolsFor(selection);
  const shown = selection ?? lastSelection.current;
  const chipWidth = 22 + 18 + 6 + labelWidths[shown];
  let x = 8;
  const chipX = x;
  if (selection !== null) x += chipWidth + 4 + 9 + 4;
  const dividerX = chipX + chipWidth + 4;
  const toolX: Record<string, number> = {};
  tools.forEach((tool) => {
    toolX[tool.id] = x;
    x += (tool.swatch !== undefined ? 34 : 36) + 4;
  });
  const barWidth = x - 4 + 8;
  const frame = FRAMES[shown];
  const context = CONTEXTS[shown];

  return (
    <div style={stageColumn(18)}>
      {probe}
      {/* canvas */}
      <div style={{ position: "relative", width: 300, height: 196, flexShrink: 0 }}>
        <div onClick={() => select(null)} style={{ position: "absolute", inset: 0, borderRadius: 24, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 14px rgb(0 0 0 / 0.08)` }} />
        {/* the shared selection frame */}
        <motion.div
          initial={false}
          animate={{ left: frame.x, top: frame.y, width: frame.w, height: frame.h, opacity: selection === null ? 0 : 1 }}
          transition={move}
          style={{ position: "absolute", borderRadius: 12, boxShadow: `inset 0 0 0 2px ${Palette.indigo}`, pointerEvents: "none", zIndex: 2 }}
        >
          {[
            { left: -4, top: -4 },
            { right: -4, top: -4 },
            { left: -4, bottom: -4 },
            { right: -4, bottom: -4 },
          ].map((pos, k) => (
            <div key={k} style={{ position: "absolute", ...pos, width: 10, height: 10, boxSizing: "border-box", borderRadius: "50%", background: "#fff", border: `2px solid ${Palette.indigo}`, boxShadow: "0 1px 2px rgb(0 0 0 / 0.15)" }} />
          ))}
        </motion.div>
        {/* text */}
        <div onClick={() => select(0)} style={{ position: "absolute", left: FRAMES[0].x, top: FRAMES[0].y, width: FRAMES[0].w, height: FRAMES[0].h, boxSizing: "border-box", padding: 8, display: "flex", alignItems: "center", cursor: "pointer" }}>
          <div
            style={{
              fontFamily: fonts.rounded,
              fontSize: 22,
              lineHeight: "28px",
              fontWeight: bold ? 800 : 400,
              fontStyle: italic ? "italic" : "normal",
              textDecoration: underline ? "underline" : "none",
              textDecorationColor: Palette.indigo,
              whiteSpace: "pre",
            }}
          >
            {ctx.t("Motion\nfeels alive", "动效\n让界面活起来")}
          </div>
        </div>
        {/* photo */}
        <div onClick={() => select(1)} style={{ position: "absolute", left: FRAMES[1].x, top: FRAMES[1].y, width: FRAMES[1].w, height: FRAMES[1].h, boxSizing: "border-box", padding: 8, cursor: "pointer" }}>
          <motion.div
            initial={false}
            animate={{ rotate: quarterTurns * 90, filter: filtered ? "saturate(0) contrast(1.2)" : "saturate(1) contrast(1)" }}
            transition={act}
            style={{ width: 92, height: 92, borderRadius: 16, background: `linear-gradient(to bottom right, ${Palette.amber}, ${Palette.coral}, ${Palette.pink})`, color: white(0.92), display: "grid", placeItems: "center" }}
          >
            <SunHorizonFill size={40} />
          </motion.div>
        </div>
        {/* shape */}
        <div onClick={() => select(2)} style={{ position: "absolute", left: FRAMES[2].x, top: FRAMES[2].y, width: FRAMES[2].w, height: FRAMES[2].h, display: "grid", placeItems: "center", cursor: "pointer" }}>
          <div style={{ position: "relative", width: 64, height: 64 }}>
            {SWATCHES.map((color, k) => (
              <motion.div
                key={k}
                initial={false}
                animate={{ opacity: swatch === k ? 1 : 0 }}
                transition={act}
                style={{ position: "absolute", inset: -2, background: colorGradient(color), maskImage: SEAL_MASK, WebkitMaskImage: SEAL_MASK, maskSize: "100% 100%", WebkitMaskSize: "100% 100%" }}
              />
            ))}
          </div>
        </div>
        <div style={{ position: "absolute", left: 124, top: 136, width: 150, pointerEvents: "none" }}>
          <PlaceholderLines count={2} color={Palette.labelAlpha(0.09)} />
        </div>
      </div>
      {/* toolbar */}
      <motion.div
        initial={false}
        animate={{ width: barWidth }}
        transition={move}
        style={{ position: "relative", height: 52, flexShrink: 0, borderRadius: 26, ...glass("regular"), boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 18px rgb(0 0 0 / 0.16)` }}
      >
        <AnimatePresence initial={false}>
          {selection !== null && (
            <motion.div
              key="chip"
              onClick={() => select(null)}
              initial={{ opacity: 0, scale: 0.5, width: chipWidth }}
              animate={{ opacity: 1, scale: 1, width: chipWidth }}
              exit={{ opacity: 0, scale: 0.5 }}
              transition={move}
              style={{
                position: "absolute",
                left: chipX,
                top: 8,
                height: 36,
                boxSizing: "border-box",
                padding: "0 11px",
                display: "flex",
                alignItems: "center",
                gap: 6,
                borderRadius: 18,
                color: context.color,
                background: alpha(context.color, 0.16),
                transformOrigin: "0% 50%",
                cursor: "pointer",
                overflow: "hidden",
              }}
            >
              <BlurReplace id={`i${shown}`} transition={move} style={{ width: 18, flexShrink: 0 }}>
                {context.icon}
              </BlurReplace>
              <BlurReplace id={shown} transition={move} style={{ justifyItems: "start" }}>
                <span style={{ ...CHIP_FONT, whiteSpace: "nowrap" }}>{ctx.t(...context.label)}</span>
              </BlurReplace>
            </motion.div>
          )}
          {selection !== null && (
            <motion.div
              key="divider"
              initial={{ opacity: 0, x: dividerX + 4 }}
              animate={{ opacity: 1, x: dividerX + 4 }}
              exit={{ opacity: 0 }}
              transition={move}
              style={{ position: "absolute", left: 0, top: 15, width: 1, height: 22, background: Palette.labelAlpha(0.12) }}
            />
          )}
          {selection === 2 && (
            <motion.div
              key="ring"
              initial={{ opacity: 0, x: toolX[`swatch${swatch}`] + 1.5 }}
              animate={{ opacity: 1, x: toolX[`swatch${swatch}`] + 1.5, transition: { x: act, opacity: delayed(move, 0.04 + swatch * ctx.n("stagger")) } }}
              exit={{ opacity: 0, transition: anim.easeIn(0.14) }}
              style={{ position: "absolute", left: 0, top: 10.5, width: 31, height: 31, boxSizing: "border-box", borderRadius: "50%", border: `2px solid ${Palette.labelAlpha(0.75)}`, pointerEvents: "none" }}
            />
          )}
          {tools.map((tool, index) => {
            const isMore = tool.id === "more";
            const width = tool.swatch !== undefined ? 34 : 36;
            const active = isActive(tool.id);
            return (
              <motion.div
                key={tool.id}
                onClick={() => perform(tool.id)}
                // The shared "more" button has no transition of its own: it only ever slides.
                initial={isMore ? false : { opacity: 0, scale: 0.5, filter: `blur(${blur}px)`, x: toolX[tool.id] }}
                animate={{
                  opacity: 1,
                  scale: 1,
                  filter: "blur(0px)",
                  x: toolX[tool.id],
                  transition: isMore ? move : { default: delayed(move, 0.04 + index * ctx.n("stagger")), x: move },
                }}
                exit={{ opacity: 0, scale: 0.5, filter: `blur(${blur}px)`, transition: anim.easeIn(0.14) }}
                style={{ position: "absolute", left: 0, top: 8, width, height: 36, display: "grid", placeItems: "center", cursor: "pointer", color: active ? "#fff" : Palette.labelAlpha(0.8) }}
              >
                {tool.swatch !== undefined ? (
                  <div style={{ width: 22, height: 22, borderRadius: "50%", background: colorGradient(SWATCHES[tool.swatch]) }} />
                ) : (
                  <>
                    <motion.div
                      initial={false}
                      animate={{ opacity: active ? 1 : 0, scale: active ? 1 : 0.6 }}
                      transition={act}
                      style={{ position: "absolute", inset: 0, borderRadius: 11, background: Palette.indigo }}
                    />
                    <span style={{ position: "relative", display: "grid" }}>{tool.icon}</span>
                  </>
                )}
              </motion.div>
            );
          })}
        </AnimatePresence>
      </motion.div>
      <DemoHint ctx={ctx} en="Tap an object, then its tools" zh="点击对象，再点它的工具" />
    </div>
  );
}

const SEAL_MASK = (() => {
  const pts: string[] = [];
  for (let i = 0; i <= 96; i++) {
    const a = (i / 96) * Math.PI * 2;
    const r = 10.2 + 1.1 * Math.cos(8 * a);
    pts.push(`${i === 0 ? "M" : "L"}${(12 + r * Math.sin(a)).toFixed(2)} ${(12 - r * Math.cos(a)).toFixed(2)}`);
  }
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path d='${pts.join("")}Z'/></svg>`;
  return `url("data:image/svg+xml,${encodeURIComponent(svg)}")`;
})();
