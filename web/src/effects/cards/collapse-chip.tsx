/** cards.collapse-chip · 收起为小圆标 (Cards+CollapseChip.swift) */
import { animate, useMotionValue } from "motion/react";
import { Leaf, Minimize2 } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, black, clamp, fonts, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, useMV } from "./shared";

const CARD = { w: 250, h: 150 };
const DOCK_Y = 54;
const TUCK = 10;
const STAGE = { w: 340, h: 280 };
const TOTAL = 25 * 60;
const ease = (t: number) => t * t * (3 - 2 * t);

export default function CollapseChip({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** 0 card, 1 chip. */
  const morphMV = useMotionValue(0);
  const collapsed = useRef(false);
  const edgeSide = ctx.i("edge") === 1 ? -1 : 1;
  /** −1 left edge, +1 right edge. */
  const [side, setSideState] = useState(edgeSide);
  const sideRef = useRef(edgeSide);
  const dragStart = useRef<number | null>(null);
  const bump = useTimeouts();
  const chip = ctx.n("chip");
  const dock = STAGE.w / 2 - chip / 2 + TUCK;

  const setSide = (s: number) => {
    if (sideRef.current === s) return;
    sideRef.current = s;
    setSideState(s);
  };

  const set = (collapse: boolean, edge: number, buzz: boolean) => {
    const response = ctx.n("response");
    const changed = collapse !== collapsed.current;
    collapsed.current = collapse;
    if (collapse) setSide(edge);
    animate(morphMV, collapse ? 1 : 0, spring(response, ctx.n("damping")));
    bump.clearAll();
    if (!buzz || !changed) return;
    if (!collapse) {
      haptics.tap("light");
      return;
    }
    // The chip reaches the edge a little after half the spring's response.
    bump.after(response * 0.55, () => haptics.tap("rigid"));
  };

  const firstEdge = useRef(edgeSide);
  useEffect(() => {
    if (firstEdge.current === edgeSide) return;
    firstEdge.current = edgeSide;
    if (collapsed.current) set(true, edgeSide, false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [edgeSide]);

  const pan = usePan({
    onChange: ({ translation }) => {
      if (dragStart.current === null) {
        morphMV.stop();
        dragStart.current = morphMV.get();
        bump.clearAll();
      }
      if (Math.abs(translation.x) <= 4) return;
      if (dragStart.current < 0.5) {
        // The card follows the finger toward whichever edge it is dragged to.
        setSide(translation.x >= 0 ? 1 : -1);
        morphMV.set(clamp(Math.abs(translation.x) / dock, 0, 1.05));
      } else {
        // The chip is pulled back inward.
        morphMV.set(clamp(1 - Math.max(-sideRef.current * translation.x, 0) / dock, 0, 1.05));
      }
    },
    onEnd: ({ start: at, translation, velocity }) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      morphMV.jump(morphMV.get());
      if (Math.hypot(translation.x, translation.y) < 8) {
        if (start > 0.5) {
          // A tap restores the chip.
          set(false, sideRef.current, true);
        } else if (at.x > CARD.w - 62 && at.y < 62) {
          // On the card, only the minimise button in its top-right corner collapses it.
          set(true, edgeSide, true);
        }
        return;
      }
      const predicted = translation.x + velocity.x * 0.25;
      if (start < 0.5) {
        set(morphMV.get() > 0.33 || Math.abs(predicted) / dock > 0.6, sideRef.current, true);
      } else {
        set(Math.max(-sideRef.current * predicted, 0) / dock < 0.33, sideRef.current, true);
      }
    },
  });

  useAutoplay(ctx.isPreview, () => set(!collapsed.current, edgeSide, false), { every: 1.9 });

  // A 25-minute session, somewhere in its first half, counting down live.
  const [, setTick] = useState(0);
  useEffect(() => {
    const id = window.setInterval(() => setTick((n) => n + 1), 1000);
    return () => window.clearInterval(id);
  }, []);
  const left = Math.max(TOTAL - (396 + ((Date.now() / 1000) % 600)), 0);

  const morph = useMV(morphMV);
  const m = clamp(morph);
  const over = Math.max(morph - 1, 0);
  // Width leads, height follows: card → pill → circle.
  const wide = ease(clamp(m / 0.75));
  const tall = ease(clamp((m - 0.2) / 0.8));
  const width = CARD.w + (chip - CARD.w) * wide;
  const height = CARD.h + (chip - CARD.h) * tall;
  const radius = Math.min(26 + (chip / 2 - 26) * tall, Math.min(width, height) / 2);
  const content = clamp(1 - m / 0.4);
  const glyph = clamp((m - 0.6) / 0.4);
  const x = side * dock * morph;
  const y = DOCK_Y * ease(m) - 8 * (1 - m);

  return (
    <Stage gap={6}>
      <div style={{ position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0 }}>
        <Page clear={m} />
        <div
          {...pan}
          style={{
            position: "absolute",
            left: STAGE.w / 2 - width / 2 + x,
            top: STAGE.h / 2 - height / 2 + y,
            width,
            height,
            borderRadius: radius,
            // Hitting the edge squashes the chip against it.
            transformOrigin: side > 0 ? "100% 50%" : "0% 50%",
            transform: `scale(${1 - Math.min(over * 2.4, 0.2)}, ${1 + Math.min(over * 1.2, 0.1)})`,
            boxShadow: `0 ${10 - 5 * m}px ${16 - 8 * m}px ${black(0.3)}`,
            touchAction: "none",
            cursor: "pointer",
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, overflow: "hidden", background: diag(["#2B2F45", "#16182A"]) }}>
            {content > 0 && (
              <div style={{ position: "absolute", left: width / 2 - CARD.w / 2, top: height / 2 - CARD.h / 2, width: CARD.w, height: CARD.h, opacity: content, filter: content < 1 ? `blur(${8 * (1 - content)}px)` : undefined }}>
                <TimerCard left={left} ctx={ctx} />
              </div>
            )}
            {glyph > 0 && (
              <div style={{ position: "absolute", left: width / 2 - chip / 2, top: height / 2 - chip / 2, width: chip, height: chip, opacity: glyph, transform: `scale(${0.6 + 0.4 * glyph})`, display: "grid", placeItems: "center" }}>
                <div style={{ position: "absolute", inset: 6 }}>
                  <Ring left={left} width={3.5} size={chip - 12} />
                </div>
                <span style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, color: "#fff", fontVariantNumeric: "tabular-nums" }}>{Math.floor(left / 60)}</span>
              </div>
            )}
          </div>
          <StrokeBorder radius={radius} color={`linear-gradient(${white(0.28)}, ${white(0.05)})`} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Flick the card to an edge, tap the chip to restore" zh="把卡片甩向边缘，点击小圆标还原" />
    </Stage>
  );
}

function Ring({ left, width, size }: { left: number; width: number; size: number }) {
  const id = useId();
  const r = size / 2;
  return (
    <svg width={size} height={size} style={{ display: "block", overflow: "visible" }}>
      <defs>
        <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={size}>
          <stop offset="0" stopColor={Palette.mint} />
          <stop offset="1" stopColor={Palette.sky} />
        </linearGradient>
      </defs>
      <circle cx={r} cy={r} r={r} fill="none" stroke={white(0.14)} strokeWidth={width} />
      <circle cx={r} cy={r} r={r} fill="none" stroke={`url(#${id})`} strokeWidth={width} strokeLinecap="round" pathLength={1} strokeDasharray={`${left / TOTAL} 2`} transform={`rotate(-90 ${r} ${r})`} />
    </svg>
  );
}

function TimerCard({ left, ctx }: { left: number; ctx: DemoContext }) {
  const minutes = Math.floor(left / 60);
  const seconds = Math.floor(left) % 60;
  const text = `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
  return (
    <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
      <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 7 }}>
        <Leaf size={12} fill="currentColor" strokeWidth={1} style={{ color: Palette.mint }} />
        <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 600, color: white(0.75) }}>{ctx.t("Focus session", "专注时段")}</span>
        <span style={{ flex: 1 }} />
        <div style={{ width: 30, height: 30, borderRadius: 15, background: white(0.14), display: "grid", placeItems: "center", color: "#fff" }}>
          <Minimize2 size={13} strokeWidth={2.8} />
        </div>
      </div>
      <span style={{ flex: 1 }} />
      <div style={{ display: "flex", alignItems: "flex-end", gap: 14 }}>
        <Ring left={left} width={6} size={58} />
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
          <NumericText value={-Math.floor(left)} text={text} style={{ fontFamily: fonts.rounded, fontSize: 38, lineHeight: "45px", fontWeight: 700, color: "#fff" }} />
          <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: white(0.55), whiteSpace: "nowrap" }}>{ctx.t("Deep work · round 2 of 4", "深度工作 · 第 2 / 4 轮")}</span>
        </div>
      </div>
    </div>
  );
}

/** The page the card floats over: dimmed and slightly small while the card is up. */
function Page({ clear }: { clear: number }) {
  return (
    <div style={{ position: "absolute", left: 20, top: 8, width: 300, height: 264, paddingTop: 6, display: "flex", flexDirection: "column", gap: 12, transform: `scale(${0.97 + 0.03 * clear})`, opacity: 0.35 + 0.65 * clear }}>
      <div style={{ width: 120, height: 14, borderRadius: 7, background: Palette.labelAlpha(0.22), flexShrink: 0 }} />
      {[0, 1, 2, 3].map((row) => (
        <div key={row} style={{ display: "flex", alignItems: "center", gap: 12, flexShrink: 0 }}>
          <div style={{ width: 44, height: 44, borderRadius: 12, background: alpha(Palette.spectrum[(row * 2) % Palette.spectrum.length], 0.55), flexShrink: 0 }} />
          <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 8 }}>
            <div style={{ height: 9, borderRadius: 5, background: Palette.labelAlpha(0.2) }} />
            <div style={{ width: 110, height: 9, borderRadius: 5, background: Palette.labelAlpha(0.12) }} />
          </div>
        </div>
      ))}
    </div>
  );
}
