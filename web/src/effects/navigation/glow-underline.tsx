/** navigation.glow-underline · 发光下划线 (Navigation+GlowUnderline.swift) */
import { animate, useMotionValue } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, spring, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BlurReplace, BookmarkFill, PersonFill, SafariFill } from "./groupA-kit";
import { useMotionNumber } from "./nav-util";
import { fade, mixColor, stageColumn, useAutoplayFlag, useNavPan } from "./_r2";

const Bolt = ({ size, color = "currentColor" }: { size: number; color?: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color} style={{ display: "block" }}>
    <path d="M13.9 1.6c.5-.6 1.400-.1 1.200.6l-1.900 7.300h5.600c.8 0 1.200.9.700 1.500L10.100 22.400c-.5.6-1.400.1-1.200-.6l1.900-7.300H5.200c-.8 0-1.200-.9-.7-1.500Z" />
  </svg>
);

type IconFn = (size: number, color?: string) => ReactNode;
const TABS: { icon: IconFn; label: [string, string]; headline: [string, string]; color: string }[] = [
  { icon: (s, c) => <Bolt size={s} color={c} />, label: ["Feed", "动态"], headline: ["12 new posts", "12 条新动态"], color: Palette.sky },
  { icon: (s, c) => <SafariFill size={s} color={c} />, label: ["Explore", "探索"], headline: ["Trending nearby", "附近热门"], color: Palette.violet },
  { icon: (s, c) => <BookmarkFill size={s} color={c} />, label: ["Saved", "收藏"], headline: ["48 saved items", "48 项收藏"], color: Palette.amber },
  { icon: (s, c) => <PersonFill size={s} color={c} />, label: ["Me", "我的"], headline: ["Profile 80% complete", "资料已完成 80%"], color: Palette.pink },
];
const FRAME = { w: 300, h: 252 };
const CELL = FRAME.w / 4;
const BAR_W = 30;
const BAR_H = 3;
const ROW_H = 64;
const LAST = TABS.length - 1;

function colorAt(x: number): string {
  const clamped = Math.min(Math.max(x, 0), LAST);
  const lower = Math.floor(clamped);
  const upper = Math.min(lower + 1, LAST);
  return mixColor(TABS[lower].color, TABS[upper].color, clamped - lower);
}
const centre = (x: number) => (x + 0.5) * CELL;

export default function GlowUnderline({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const xMV = useMotionValue(0);
  const powerMV = useMotionValue(1);
  const x = useMotionNumber(xMV);
  const power = useMotionNumber(powerMV);
  const [selection, setSelection] = useState(0);
  const selRef = useRef(0);
  const target = useRef(0);
  const cancelIgnite = useRef<(() => void) | null>(null);
  const dragging = useRef(false);

  const pick = (index: number) => {
    selRef.current = index;
    setSelection(index);
  };

  const auto = useAutoplayFlag(ctx.isPreview, () => select((selRef.current + 1) % TABS.length), { every: 1.5 });

  function select(index: number) {
    if (index === selRef.current && target.current === index) return;
    cancelIgnite.current?.();
    haptics.selection();
    const silent = auto.current;
    animate(powerMV, 0.35, anim.easeOut(0.1));
    target.current = index;
    animate(xMV, index, spring(ctx.n("response"), ctx.n("damping")));
    pick(index);
    cancelIgnite.current = after(ctx.n("response") * 0.6, () => {
      animate(powerMV, 1, spring(0.3, 0.45));
      if (!silent) haptics.tap("soft");
    });
  }

  const pan = useNavPan(
    {
      onChange: (s) => {
        cancelIgnite.current?.();
        if (!dragging.current) {
          dragging.current = true;
          animate(powerMV, 0.8, anim.easeOut(0.12));
        }
        const clamped = Math.min(Math.max(s.location.x / CELL - 0.5, -0.2), LAST + 0.2);
        target.current = clamped;
        animate(xMV, clamped, spring(0.18, 0.86));
        const nearest = Math.min(Math.max(Math.round(clamped), 0), LAST);
        if (nearest !== selRef.current) {
          haptics.selection();
          pick(nearest);
        }
      },
      onEnd: () => {
        dragging.current = false;
        const nearest = Math.min(Math.max(Math.round(target.current), 0), LAST);
        target.current = nearest;
        animate(xMV, nearest, spring(ctx.n("response"), ctx.n("damping")));
        pick(nearest);
        animate(powerMV, 1, spring(0.3, 0.45));
      },
    },
    { axis: "horizontal" },
  );

  const color = colorAt(x);
  const cx = centre(x);
  const height = ctx.n("height");
  const spread = ctx.n("spread");
  const tab = TABS[selection];
  const gradId = `glow-underline-${selection}`;
  const p01 = Math.min(Math.max(power, 0), 1);

  return (
    <div style={stageColumn(14)}>
      <div
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          borderRadius: 32,
          overflow: "hidden",
          background: "linear-gradient(to bottom, #15161D, #0A0B0F)",
          boxShadow: `0 12px 20px rgb(0 0 0 / 0.28)`,
          isolation: "isolate",
        }}
      >
        {/* headline */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 34, display: "flex", justifyContent: "center" }}>
          <BlurReplace id={selection} transition={dragging.current ? spring(0.3, 0.85) : spring(ctx.n("response"), ctx.n("damping"))}>
            <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10 }}>
              <div style={{ height: 52, display: "grid", placeItems: "center", filter: `drop-shadow(0 0 16px ${fade(tab.color, 0.6)})` }}>
                <svg width={0} height={0} style={{ position: "absolute" }} aria-hidden>
                  <defs>
                    <linearGradient id={gradId} x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0" stopColor="#fff" />
                      <stop offset="1" stopColor={tab.color} />
                    </linearGradient>
                  </defs>
                </svg>
                {tab.icon(50, `url(#${gradId})`)}
              </div>
              <div style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, color: white(0.92), whiteSpace: "nowrap" }}>{ctx.t(...tab.headline)}</div>
            </div>
          </BlurReplace>
        </div>
        {/* beam: ambient wash + cone, added with plus-lighter */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            transformOrigin: "50% 100%",
            transform: `scaleY(${0.55 + 0.45 * power})`,
            opacity: p01,
            mixBlendMode: "plus-lighter",
            pointerEvents: "none",
          }}
        >
          <div
            style={{
              position: "absolute",
              left: cx - 150,
              top: FRAME.h - 150,
              width: 300,
              height: 300,
              borderRadius: "50%",
              transform: "scaleY(0.72)",
              background: `radial-gradient(circle closest-side, ${fade(color, 0.3)}, ${fade(color, 0)})`,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: cx - BAR_W / 2 - spread,
              bottom: 4,
              width: BAR_W + spread * 2,
              height,
              filter: "blur(7px)",
            }}
          >
            <div
              style={{
                position: "absolute",
                inset: 0,
                clipPath: `polygon(${spread}px 100%, calc(100% - ${spread}px) 100%, 100% 0, 0 0)`,
                background: `linear-gradient(to top, ${fade(color, 0.85)}, ${fade(color, 0.28)}, ${fade(color, 0)})`,
              }}
            />
          </div>
        </div>
        {/* labels lit by their distance to the lamp */}
        <div style={{ position: "absolute", left: 0, bottom: 6, display: "flex", pointerEvents: "none" }}>
          {TABS.map((t, index) => {
            const distance = index - x;
            const lit = Math.exp(-(distance * distance) / (2 * 0.42 * 0.42));
            const g = Math.round(102 + 153 * lit);
            return (
              <div
                key={index}
                style={{
                  width: CELL,
                  height: ROW_H,
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 5,
                  color: `rgb(${g} ${g} ${g})`,
                  filter: `drop-shadow(0 0 9px ${fade(color, 0.9 * lit)})`,
                  transform: `translateY(${-2 * lit}px)`,
                }}
              >
                <div style={{ height: 22, display: "grid", placeItems: "center" }}>{t.icon(21)}</div>
                <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...t.label)}</div>
              </div>
            );
          })}
        </div>
        {/* the lamp */}
        <div
          style={{
            position: "absolute",
            left: cx - BAR_W / 2,
            bottom: 5,
            width: BAR_W,
            height: BAR_H,
            borderRadius: BAR_H / 2,
            background: mixColor("#fff", color, 0.45),
            boxShadow: `0 0 6px ${color}, 0 0 14px ${fade(color, 0.8)}`,
            opacity: 0.55 + 0.45 * Math.min(power, 1),
            pointerEvents: "none",
          }}
        />
        {/* tap targets */}
        <div {...pan} style={{ position: "absolute", left: 0, bottom: 0, display: "flex", touchAction: "pan-y" }}>
          {TABS.map((_, index) => (
            <div key={index} onClick={() => select(index)} style={{ width: CELL, height: ROW_H, cursor: "pointer" }} />
          ))}
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 32, boxShadow: `inset 0 0 0 1px ${white(0.08)}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap a tab, or drag along the bar" zh="点击标签，或沿标签栏拖动" />
    </div>
  );
}
