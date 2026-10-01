/** cards.slide-door · 滑门揭示 (Cards+SlideDoor.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { KeyRound, Lock, LockOpen } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, clamp, delayed, fonts, hex, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, linearPoints, useMV } from "./shared";

const OUTER = { w: 264, h: 172 };
const INNER = { w: 246, h: 154 };
/** What stays visible of a leaf when it is fully open (it carries the grip). */
const SINGLE_STUB = 38;
const DOUBLE_STUB = 24;
const DIGITS = ["7", "4", "2", "9"];

export default function SlideDoor({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const openMV = useMotionValue(0);
  const [isOpen, setIsOpen] = useState(false);
  const isOpenRef = useRef(false);
  const dragStart = useRef<number | null>(null);
  const dragSign = useRef(1);
  const latch = useTimeouts();

  const double = ctx.i("leaves") === 1;
  const travel = double ? INNER.w / 2 - DOUBLE_STUB : INNER.w - SINGLE_STUB;

  const settle = (target: boolean, velocity: number, haptic: boolean) => {
    const response = ctx.n("response");
    const goal = target ? 1 : 0;
    const distance = goal - openMV.get();
    // SwiftUI wants the velocity relative to the remaining distance.
    const relative = Math.abs(distance) > 0.01 ? clamp(velocity / distance, -12, 12) : 0;
    animate(openMV, goal, { ...spring(response, ctx.n("damping")), velocity: relative * distance });
    isOpenRef.current = target;
    setIsOpen(target);
    latch.clearAll();
    if (!haptic) return;
    latch.after(response * 0.55, () => haptics.tap("rigid"));
  };

  const banded = (value: number) => {
    if (value < 0) return rubberBand(value * travel, 30) / travel;
    if (value > 1) return 1 + rubberBand((value - 1) * travel, 30) / travel;
    return value;
  };

  const pan = usePan({
    onChange: ({ start, translation }) => {
      if (dragStart.current === null) {
        openMV.stop();
        dragStart.current = openMV.get();
        latch.clearAll();
        // A double door is pulled outward from whichever leaf the finger is on.
        dragSign.current = double && start.x < OUTER.w / 2 ? -1 : 1;
      }
      openMV.set(banded(dragStart.current + (dragSign.current * translation.x) / travel));
    },
    onEnd: ({ translation, velocity }) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      if (Math.hypot(translation.x, translation.y) < 8) {
        settle(!isOpenRef.current, 0, true);
        return;
      }
      const projected = start + (dragSign.current * (translation.x + velocity.x * 0.25)) / travel;
      settle(projected > 0.5, (dragSign.current * velocity.x) / travel, true);
    },
  });

  useAutoplay(ctx.isPreview, () => settle(!isOpenRef.current, 0, false), { every: 1.8 });

  const open = useMV(openMV);
  const depth = ctx.n("depth");
  const wellOpen = clamp(open);
  const shift = double ? 0 : -SINGLE_STUB / 2;

  return (
    <Stage gap={16}>
      <div {...pan} style={{ position: "relative", width: OUTER.w, height: OUTER.h, flexShrink: 0, touchAction: "none", cursor: "grab" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 27, background: `linear-gradient(${Palette.elevated}, ${Palette.surface})`, boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.1)}, 0 10px 18px ${black(0.16)}` }} />
        <div style={{ position: "absolute", left: 9, top: 9, width: INNER.w, height: INNER.h, borderRadius: 18, overflow: "hidden", pointerEvents: "none" }}>
          {/* well */}
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(#10121C, #1B2032)", boxShadow: `inset 0 6px 9px ${black(0.7 * depth)}` }} />
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              gap: 10,
              transform: `translateX(${shift * wellOpen}px) scale(${0.94 + 0.06 * wellOpen})`,
              filter: `brightness(${1 - 0.55 * (1 - wellOpen)})`,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 6, color: white(0.55) }}>
              <KeyRound size={11} strokeWidth={3} />
              <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 700, letterSpacing: 1.6 }}>{ctx.t("DOOR CODE", "门禁密码")}</span>
            </div>
            <div style={{ display: "flex", gap: 8 }}>
              {DIGITS.map((d, index) => (
                <div key={index} style={{ width: 38, height: 46, borderRadius: 10, background: white(0.06), boxShadow: `inset 0 0 0 1px ${white(0.08)}`, display: "grid", placeItems: "center" }}>
                  <motion.span
                    initial={false}
                    animate={{ y: isOpen ? 0 : 10, opacity: isOpen ? 1 : 0.25, textShadow: `0px 0px 8px ${hex(0x21d4a8, isOpen ? 0.6 : 0)}` }}
                    transition={delayed(spring(0.4, 0.7), isOpen ? 0.06 * index : 0)}
                    style={{ fontFamily: fonts.rounded, fontSize: 28, lineHeight: "34px", fontWeight: 700, fontVariantNumeric: "tabular-nums", color: "#7DF3D0" }}
                  >
                    {d}
                  </motion.span>
                </div>
              ))}
            </div>
            <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 500, color: white(0.4) }}>{ctx.t("Valid for 10 minutes", "10 分钟内有效")}</span>
          </div>
          {/* leaves */}
          {double ? (
            <>
              <Leaf sign={-1} from={0} to={0.5} open={open} travel={travel} unlocked={isOpen} depth={depth} ctx={ctx} />
              <Leaf sign={1} from={0.5} to={1} open={open} travel={travel} unlocked={isOpen} depth={depth} ctx={ctx} />
            </>
          ) : (
            <Leaf sign={1} from={0} to={1} open={open} travel={travel} unlocked={isOpen} depth={depth} ctx={ctx} />
          )}
          {/* The well's rim shades whatever sits inside it, door included. */}
          <div style={{ position: "absolute", inset: -2.5, top: 0, bottom: -5, borderRadius: 20.5, border: `5px solid ${black(0.5 * depth)}`, filter: "blur(4px)" }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 1px ${black(0.28)}` }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Slide the cover, or tap" zh="滑动盖板，或点击" />
    </Stage>
  );
}

/** One leaf: the part of the cover between `from` and `to` (fractions of the width), moving toward `sign`. */
function Leaf({ sign, from, to, open, travel, unlocked, depth, ctx }: { sign: number; from: number; to: number; open: number; travel: number; unlocked: boolean; depth: number; ctx: DemoContext }) {
  const left = from * INNER.w;
  const width = (to - from) * INNER.w;
  // The edge that uncovers the content: the left edge of a leaf moving right, and vice versa.
  const edge = sign > 0 ? left : left + width;
  const Icon = unlocked ? LockOpen : Lock;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: INNER.w, height: INNER.h, transform: `translateX(${sign * open * travel}px)` }}>
      <div
        style={{
          position: "absolute",
          left: sign > 0 ? edge - 28 : edge,
          top: 0,
          width: 28,
          height: INNER.h,
          background: `linear-gradient(to ${sign > 0 ? "left" : "right"}, ${black(0.55 * depth)}, ${black(0)})`,
          opacity: clamp(open * 8),
        }}
      />
      <div style={{ position: "absolute", inset: 0, clipPath: `inset(0 ${INNER.w - left - width}px 0 ${left}px)` }}>
        <div style={{ position: "absolute", inset: 0, background: "linear-gradient(to bottom right, #6C63FF, #8F5BFF, #4B3FD9)" }} />
        <div style={{ position: "absolute", inset: 0, background: linearPoints(INNER.w, INNER.h, [0, 0], [1, 1], [[white(0), 0.2], [white(0.22), 0.45], [white(0), 0.7]]) }} />
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8, color: "#fff" }}>
          <div style={{ height: 30, display: "grid", placeItems: "center" }}>
            <Icon size={26} strokeWidth={2.4} />
          </div>
          <span style={{ fontFamily: fonts.rounded, fontSize: 13, lineHeight: "16px", fontWeight: 600, opacity: 0.85 }}>{ctx.t("Slide to reveal", "滑动查看")}</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: sign > 0 ? edge + 9 : edge - 9 - 12, top: (INNER.h - 44) / 2, width: 12, display: "flex", gap: 3 }}>
        {[0, 1, 2].map((i) => (
          <div key={i} style={{ width: 2, height: 44, borderRadius: 1, background: `linear-gradient(to right, ${black(0.3)}, ${white(0.45)})` }} />
        ))}
      </div>
      <div style={{ position: "absolute", left: sign > 0 ? edge : edge - 1, top: 0, width: 1, height: INNER.h, background: white(0.5) }} />
    </div>
  );
}
