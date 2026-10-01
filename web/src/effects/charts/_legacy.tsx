/**
 * Small pieces shared by the sixteen first-round chart ports (bar-race … waffle-kpi): the stage
 * frame, colour helpers and a few SF Symbol stand-ins.
 */
import { AnimatePresence, motion } from "motion/react";
import { useLayoutEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { DemoHint, Palette, anim, fonts, type DemoContext } from "../../kit";
import { ChartTapCue } from "./_shared";

/**
 * `.frame(maxWidth: .infinity, maxHeight: .infinity)` with the bottom-overlaid hint
 * (`DemoHint` or, with `cue`, `ChartTapCue`).
 */
export function Stage({
  ctx,
  hint,
  bottom = 8,
  cue = false,
  children,
}: {
  ctx: DemoContext;
  hint?: [en: string, zh: string];
  bottom?: number;
  cue?: boolean;
  children: ReactNode;
}) {
  const style: CSSProperties = { position: "absolute", left: 0, right: 0, bottom };
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
      {children}
      {hint && (cue ? <ChartTapCue ctx={ctx} en={hint[0]} zh={hint[1]} style={style} /> : <DemoHint ctx={ctx} en={hint[0]} zh={hint[1]} style={style} />)}
    </div>
  );
}

/** `Color.mix(with:by:)` (perceptual, i.e. OKLab). */
export const mixColor = (a: string, b: string, t: number) => {
  const p = Math.min(Math.max(t, 0), 1) * 100;
  return `color-mix(in oklab, ${a} ${(100 - p).toFixed(2)}%, ${b} ${p.toFixed(2)}%)`;
};

/** The lighter top stop of `Color.gradient`. */
export const gradientTop = (c: string) => `color-mix(in srgb, ${c} 82%, white)`;
/** `Color.gradient` as a CSS background. */
export const gradientOf = (c: string) => `linear-gradient(180deg, ${gradientTop(c)}, ${c})`;

/** `.font(.caption.weight(.semibold)).foregroundStyle(.secondary)`. */
export const captionSecondary: CSSProperties = { fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" };

/** `.font(.system(size:, weight:, design: .rounded)).monospacedDigit()`. */
export const rounded = (size: number, weight: number, lineHeight = Math.round(size * 1.2)): CSSProperties => ({
  fontFamily: fonts.rounded,
  fontSize: size,
  lineHeight: `${lineHeight}px`,
  fontWeight: weight,
  fontVariantNumeric: "tabular-nums",
  whiteSpace: "nowrap",
});

/** Swift's `String(format: "%+.2f")`. */
export const signed = (v: number, digits = 2) => (v >= 0 ? "+" : "-") + Math.abs(v).toFixed(digits);

/**
 * `matchedGeometryEffect` for a segmented pill: measures the active label (layout px, so the canvas
 * scale does not matter) and returns the thumb's frame inside the positioned container.
 */
export function useThumb(active: number, deps: unknown[] = []) {
  const refs = useRef<(HTMLElement | null)[]>([]);
  const [frame, setFrame] = useState<{ x: number; y: number; width: number; height: number } | null>(null);
  useLayoutEffect(() => {
    const el = refs.current[active];
    if (!el) return;
    const next = { x: el.offsetLeft, y: el.offsetTop, width: el.offsetWidth, height: el.offsetHeight };
    setFrame((f) => (f && f.x === next.x && f.y === next.y && f.width === next.width && f.height === next.height ? f : next));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active, ...deps]);
  const ref = (i: number) => (el: HTMLElement | null) => {
    refs.current[i] = el;
  };
  return { ref, frame };
}

/** `.contentTransition(.opacity)` on a text that changes: the old string fades out under the new one. */
export function FadeText({ text, style }: { text: string; style?: CSSProperties }) {
  return (
    <span style={{ position: "relative", display: "inline-block", whiteSpace: "nowrap", ...style }}>
      <AnimatePresence initial={false} mode="popLayout">
        <motion.span key={text} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={anim.easeInOut(0.25)} style={{ display: "inline-block", color: style?.color }}>
          {text}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}

/** `.contentTransition(.symbolEffect(.replace))`: keyed glyphs swap with scale + blur. */
export function SymbolSwap({ id, size, children }: { id: string; size: number; children: ReactNode }) {
  return (
    <span style={{ position: "relative", width: size, height: size, display: "inline-grid", placeItems: "center", flex: "none" }}>
      <AnimatePresence initial={false} mode="popLayout">
        <motion.span
          key={id}
          initial={{ opacity: 0, scale: 0.5, filter: "blur(3px)" }}
          animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
          exit={{ opacity: 0, scale: 0.5, filter: "blur(3px)" }}
          transition={{ type: "spring", stiffness: 320, damping: 26 }}
          style={{ display: "grid", placeItems: "center" }}
        >
          {children}
        </motion.span>
      </AnimatePresence>
    </span>
  );
}

/** `chart.bar.fill` */
export function BarsGlyph({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="currentColor">
      <rect x={1} y={10} width={5.2} height={8.5} rx={1.2} />
      <rect x={7.4} y={6} width={5.2} height={12.5} rx={1.2} />
      <rect x={13.8} y={2} width={5.2} height={16.5} rx={1.2} />
    </svg>
  );
}

/** `chart.xyaxis.line` */
export function LineGlyph({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth={2.1} strokeLinecap="round" strokeLinejoin="round">
      <path d="M2.2 2.2v13.4a2.2 2.2 0 0 0 2.2 2.2h13.4" />
      <path d="M6.2 12.4l3.3-4.2 2.9 2.4 4.6-5.9" />
    </svg>
  );
}

/** `chart.pie.fill` */
export function PieGlyph({ size }: { size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 20 20" fill="currentColor">
      <path d="M8.6 3.1a8 8 0 1 0 8.3 8.3.6.6 0 0 0-.6-.6H9.2V3.700a.6.6 0 0 0-.6-.6z" />
      <path d="M11.300 1.100a.6.6 0 0 0-.6.6v6.400c0 .3.3.6.6.6h6.400c.3 0 .6-.3.6-.6a7.400 7.400 0 0 0-7-7z" />
    </svg>
  );
}

/** `arrow.up.right` / `arrow.down.right` */
export function DiagonalArrow({ up, size }: { up: boolean; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" style={{ transform: up ? undefined : "scaleY(-1)" }}>
      <path d="M2.4 9.6l7.200-7.200M4 2.400h5.600v5.600" />
    </svg>
  );
}

/** `arrowtriangle.up.fill` / `arrowtriangle.down.fill` */
export function Triangle({ up, size }: { up: boolean; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 10 10" fill="currentColor" style={{ transform: up ? undefined : "scaleY(-1)" }}>
      <path d="M5 1.100c.3 0 .6.150.75.450l3.500 6.200c.3.550-.1 1.250-.75 1.250h-7c-.65 0-1.050-.7-.75-1.250l3.500-6.200c.15-.3.450-.450.75-.450z" />
    </svg>
  );
}
