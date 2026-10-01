/** navigation.scrolling-dots · 滚动窗口页码点 (Navigation+ScrollingDots.swift) */
import { animate, motion, useMotionValue, useTransform } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, clamp, fonts, rubberBand, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { predicted } from "./nav-util";
import { fade, useNavPan } from "./_r2";

const COUNT = 12;
const CARD = 220;
const GAP = 14;
const PITCH = CARD + GAP;
const DOT_STEP = 14;

export default function ScrollingDots({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [page, setPageState] = useState(0);
  const pageRef = useRef(0);
  const autoForward = useRef(true);
  /** `-page × pitch` (springs between pages) and the live drag translation. */
  const base = useMotionValue(0);
  const drag = useMotionValue(0);
  const x = useTransform(() => base.get() + drag.get());

  const rawVisible = clamp(ctx.i("visible"), 3, 7);
  const visible = rawVisible % 2 === 0 ? rawVisible + 1 : rawVisible;
  const windowStart = clamp(page - Math.floor(visible / 2), 0, Math.max(COUNT - visible, 0));
  const move = spring(ctx.n("response"), 0.8);

  const go = (target: number) => {
    const clamped = clamp(target, 0, COUNT - 1);
    if (clamped !== pageRef.current) haptics.selection();
    pageRef.current = clamped;
    setPageState(clamped);
    animate(base, -clamped * PITCH, move);
    animate(drag, 0, move);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      if (pageRef.current === COUNT - 1) autoForward.current = false;
      if (pageRef.current === 0) autoForward.current = true;
      go(pageRef.current + (autoForward.current ? 1 : -1));
    },
    { every: 0.9 },
  );

  const pan = useNavPan(
    {
      onChange: (s) => {
        const raw = s.translation.x;
        const atStart = pageRef.current === 0 && raw > 0;
        const atEnd = pageRef.current === COUNT - 1 && raw < 0;
        drag.stop();
        drag.set(atStart || atEnd ? rubberBand(raw, 60) : raw);
      },
      onEnd: (s) => {
        // A cancelled drag snaps to the card nearest the current offset.
        const end = s ? predicted(s).x : drag.get();
        const pages = Math.round(-end / PITCH);
        go(pageRef.current + clamp(pages, -2, 2));
      },
    },
    { axis: "horizontal" },
  );

  const dotScale = (index: number) => {
    if (index === page) return 1.25;
    const first = windowStart;
    const last = windowStart + visible - 1;
    if (index < first || index > last) return 0.3;
    if (!ctx.b("shrink")) return 1;
    if (index === first && first > 0) return 0.55;
    if (index === last && last < COUNT - 1) return 0.55;
    return 1;
  };
  const dotOpacity = (index: number) => (index < windowStart || index > windowStart + visible - 1 ? 0 : 1);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 22 }}>
      <div {...pan} style={{ position: "relative", width: 300, height: 190, overflow: "hidden", flexShrink: 0, cursor: "grab", touchAction: "pan-y", userSelect: "none", WebkitUserSelect: "none" }}>
        <motion.div style={{ position: "absolute", left: (300 - CARD) / 2, top: 10, display: "flex", gap: GAP, x }}>
          {Array.from({ length: COUNT }, (_, index) => {
            const color = Palette.spectrum[index % Palette.spectrum.length];
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{ scale: index === page ? 1 : 0.92 }}
                transition={move}
                style={{
                  position: "relative",
                  width: CARD,
                  height: 170,
                  flexShrink: 0,
                  borderRadius: 24,
                  background: `linear-gradient(to bottom right, ${color}, ${fade(color, 0.6)})`,
                }}
              >
                <span
                  style={{
                    position: "absolute",
                    left: 18,
                    bottom: 18,
                    fontFamily: fonts.rounded,
                    fontSize: 30,
                    lineHeight: "36px",
                    fontWeight: 700,
                    fontVariantNumeric: "tabular-nums",
                    color: "#fff",
                  }}
                >
                  {String(index + 1).padStart(2, "0")}
                </span>
              </motion.div>
            );
          })}
        </motion.div>
      </div>
      <div style={{ width: visible * DOT_STEP, height: 14, overflow: "hidden", flexShrink: 0 }}>
        <motion.div initial={false} animate={{ x: -windowStart * DOT_STEP }} transition={move} style={{ display: "flex", width: COUNT * DOT_STEP }}>
          {Array.from({ length: COUNT }, (_, index) => (
            <div key={index} style={{ width: DOT_STEP, height: 14, display: "grid", placeItems: "center", flexShrink: 0 }}>
              <motion.div
                initial={false}
                animate={{ scale: dotScale(index), opacity: dotOpacity(index) }}
                transition={move}
                style={{ position: "relative", width: 7, height: 7, borderRadius: "50%", background: Palette.labelAlpha(0.25), overflow: "hidden" }}
              >
                <motion.div initial={false} animate={{ opacity: index === page ? 1 : 0 }} transition={move} style={{ position: "absolute", inset: 0, background: Palette.primary }} />
              </motion.div>
            </div>
          ))}
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Swipe the cards" zh="左右滑动卡片" />
    </div>
  );
}
