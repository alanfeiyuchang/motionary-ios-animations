/** cards.time-machine · 时光机层叠 (Cards+TimeMachine.swift) */
import { animate, useMotionValue, useMotionValueEvent } from "motion/react";
import { ChevronDown, ChevronUp, type LucideIcon } from "lucide-react";
import { useRef } from "react";
import { NumericText, Palette, alpha, black, clamp, fonts, spring, useAutoplay, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { Stage, tr, useMV, type LText } from "./shared";
import { usePageSafePan } from "./_kit";

const SNAPSHOTS: { stamp: LText; lines: number }[] = [
  { stamp: ["Now", "现在"], lines: 4 },
  { stamp: ["1 hour ago", "1 小时前"], lines: 4 },
  { stamp: ["Today 9:41", "今天 9:41"], lines: 3 },
  { stamp: ["Yesterday", "昨天"], lines: 3 },
  { stamp: ["Monday", "周一"], lines: 3 },
  { stamp: ["Last week", "上周"], lines: 2 },
  { stamp: ["Sep 12", "9 月 12 日"], lines: 2 },
  { stamp: ["August", "八月"], lines: 1 },
];
const COUNT = SNAPSHOTS.length;
/** Finger travel that moves the stack by one layer. */
const PITCH = 110;
const FRONT_Y = 48;

const depthOf = (index: number, position: number) => {
  let d = (index - position) % COUNT;
  if (d < -1) d += COUNT;
  if (d >= COUNT - 1) d -= COUNT;
  return d;
};

export default function TimeMachine({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const positionMV = useMotionValue(0);
  const dragStart = useRef<number | null>(null);
  const dragged = useRef(false);
  const silent = useRef(false);
  const lastDetent = useRef(0);

  useMotionValueEvent(positionMV, "change", (v) => {
    const d = Math.round(v);
    if (d !== lastDetent.current) {
      lastDetent.current = d;
      if (!silent.current) haptics.selection();
    }
  });

  const snap = (target: number) => animate(positionMV, target, spring(ctx.n("response"), 0.82));
  const step = (amount: number) => {
    if (dragStart.current !== null) return;
    snap(Math.round(positionMV.get()) + amount);
  };
  /** The window under the finger at touch-down (the pan captures the pointer, so the click lands on the stack). */
  const pressedDepth = useRef(0);
  const select = (depth: number) => {
    if (dragStart.current !== null || depth <= 0 || dragged.current) return;
    silent.current = false;
    snap(Math.round(positionMV.get()) + depth);
  };

  const pan = usePageSafePan(["up", "down"], {
    onChange: (translation) => {
      if (dragStart.current === null) {
        dragStart.current = positionMV.get();
        dragged.current = true;
        silent.current = false;
        positionMV.stop();
      }
      positionMV.set(dragStart.current + translation.y / PITCH);
    },
    onEnd: (end) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      const position = positionMV.get();
      positionMV.jump(position);
      if (!end) {
        snap(Math.round(position));
        return;
      }
      snap(Math.round(clamp(start + end.predicted.y / PITCH, position - 2, position + 2)));
    },
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      silent.current = true;
      step(1);
    },
    { every: 1.3 },
  );

  const position = useMV(positionMV);
  const spacing = ctx.n("spacing");
  const visible = Math.max(ctx.i("visible"), 1);
  const blurs = ctx.b("blur");
  const currentIndex = (((Math.round(position) % COUNT) + COUNT) % COUNT);

  const arrow = (Icon: LucideIcon, amount: number) => (
    <button
      onClick={() => {
        silent.current = false;
        step(amount);
      }}
      style={{ width: 34, height: 34, borderRadius: 17, display: "grid", placeItems: "center", background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, color: Palette.label }}
    >
      <Icon size={16} strokeWidth={3} />
    </button>
  );

  return (
    <Stage gap={10}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          select(pressedDepth.current);
          pressedDepth.current = 0;
        }}
        style={{ position: "relative", width: 300, height: 262, flexShrink: 0, touchAction: "none" }}
      >
        {SNAPSHOTS.map((_, index) => {
          const d = depthOf(index, position);
          let scale: number, y: number, opacity: number, blur: number;
          if (d >= 0) {
            scale = Math.pow(0.86, d);
            y = FRONT_Y - (spacing * (1 - Math.pow(0.8, d))) / 0.2;
            opacity = clamp(Math.min(visible - d, 1)) * (1 - 0.07 * d);
            blur = blurs ? 0.6 * d : 0;
          } else {
            const e = -d;
            scale = 1 + 0.3 * e;
            y = FRONT_Y + 80 * e;
            opacity = Math.pow(Math.max(1 - e, 0), 1.5);
            blur = 8 * e;
          }
          return (
            <div
              key={index}
              onPointerDown={() => (pressedDepth.current = Math.round(d))}
              style={{
                position: "absolute",
                left: 32,
                top: 56,
                width: 236,
                height: 150,
                transform: `translateY(${y}px) scale(${scale})`,
                opacity,
                zIndex: Math.round(-d * 100) + 1000,
                pointerEvents: opacity < 0.02 ? "none" : undefined,
              }}
            >
              <div style={{ filter: blur > 0.01 ? `blur(${blur}px)` : undefined }}>
                <Window index={index} ctx={ctx} />
              </div>
            </div>
          );
        })}
        {/* ruler */}
        <div style={{ position: "absolute", right: 2, top: 131 - 8 - 59, width: 20, display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 14, zIndex: 3000, pointerEvents: "none" }}>
          {Array.from({ length: COUNT }, (_, k) => COUNT - 1 - k).map((index) => {
            const near = Math.max(0, 1 - Math.abs(depthOf(index, position)));
            return (
              <div key={index} style={{ position: "relative", width: 7 + 11 * near, height: 2.5, borderRadius: 2, background: Palette.labelAlpha(0.22), overflow: "hidden", flexShrink: 0 }}>
                <div style={{ position: "absolute", inset: 0, background: Palette.indigo, opacity: near }} />
              </div>
            );
          })}
        </div>
      </div>
      {!ctx.isPreview && (
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          {arrow(ChevronUp, 1)}
          <div style={{ width: 110, display: "flex", justifyContent: "center", fontSize: 13, lineHeight: "18px", fontWeight: 600 }}>
            <NumericText value={currentIndex} text={tr(ctx, SNAPSHOTS[currentIndex].stamp)} />
          </div>
          {arrow(ChevronDown, -1)}
        </div>
      )}
    </Stage>
  );
}

/** One document window; older snapshots have a lower version and less text. */
function Window({ index, ctx }: { index: number; ctx: DemoContext }) {
  const snapshot = SNAPSHOTS[index];
  const accent = Palette.spectrum[index % Palette.spectrum.length];
  return (
    <div style={{ position: "relative", width: 236, height: 150, borderRadius: 16, background: Palette.elevated, boxShadow: `0 6px 12px ${black(0.16)}`, overflow: "hidden", display: "flex", flexDirection: "column" }}>
      <div style={{ height: 28, flexShrink: 0, padding: "0 12px", display: "flex", alignItems: "center", gap: 5, background: Palette.labelAlpha(0.045) }}>
        {[Palette.red, Palette.amber, Palette.green].map((c) => (
          <div key={c} style={{ width: 7, height: 7, borderRadius: 4, background: c }} />
        ))}
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 10.5, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel }}>{tr(ctx, snapshot.stamp)}</span>
      </div>
      <div style={{ padding: 14, display: "flex", flexDirection: "column", gap: 9 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ width: 4, height: 18, borderRadius: 2, background: accent }} />
          <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>{ctx.t("Launch plan", "发布计划")}</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 10.5, lineHeight: "13px", fontWeight: 700, color: accent, padding: "2px 6px", borderRadius: 99, background: alpha(accent, 0.16) }}>{`v${COUNT - index}`}</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          {Array.from({ length: snapshot.lines }, (_, i) => (
            <div key={i} style={{ height: 10, borderRadius: 5, background: Palette.labelAlpha(0.11), maxWidth: i === snapshot.lines - 1 ? 120 : undefined }} />
          ))}
        </div>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 16, boxShadow: `inset 0 0 0 0.8px ${Palette.labelAlpha(0.1)}`, pointerEvents: "none" }} />
    </div>
  );
}
