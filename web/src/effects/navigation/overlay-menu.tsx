/** navigation.overlay-menu · 幕布全屏菜单 (Navigation+OverlayMenu.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useId, useRef, useState } from "react";
import { DemoHint, Palette, PlaceholderLines, anim, clamp, delayed, fonts, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { useMotionNumber } from "./nav-util";

const WORDS: [string, string][] = [
  ["Work", "作品"],
  ["Studio", "工作室"],
  ["Journal", "日志"],
  ["Contact", "联系"],
];
const W = 250;
const H = 320;

export default function OverlayMenu({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [open, setOpen] = useState(false);
  const openRef = useRef(false);
  const curtain = useMotionValue(0);
  const duration = ctx.n("duration");
  const stagger = ctx.n("stagger");

  const toggle = () => {
    const next = !openRef.current;
    haptics.tap(next ? "medium" : "light");
    openRef.current = next;
    setOpen(next);
    const wordsOut = WORDS.length * stagger * 0.5 + 0.2;
    animate(curtain, next ? 1 : 0, next ? anim.curve(0.16, 1, 0.3, 1, duration) : delayed(anim.curve(0.7, 0, 0.84, 0, duration * 0.8), wordsOut));
  };

  useAutoplay(ctx.isPreview, toggle, { every: 2 });

  const tilt = ctx.b("tilt") ? 6 : 0;
  const burger = spring(0.4, 0.7);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ position: "relative", width: W, height: H, flexShrink: 0, borderRadius: 34, overflow: "hidden", background: Palette.elevated, boxShadow: "0 10px 18px rgb(0 0 0 / 0.18)" }}>
        {/* page */}
        <div style={{ position: "absolute", inset: 0, padding: 18, display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "21px", fontWeight: 800, marginTop: 8 }}>atelier°</div>
          <div style={{ height: 130, borderRadius: 20, background: "linear-gradient(to bottom right, #FFC247, #FF7A5C, #FF5FA2)", flexShrink: 0 }} />
          <PlaceholderLines count={3} />
        </div>
        <Curtain progress={curtain} />
        {/* words */}
        <div style={{ position: "absolute", left: 24, top: 78, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 6, pointerEvents: open ? "auto" : "none" }}>
          {WORDS.map((word, index) => {
            const delay = open ? duration * 0.45 + index * stagger : (WORDS.length - 1 - index) * stagger * 0.5;
            const transition = open ? delayed(spring(0.5, 0.8), delay) : delayed(anim.easeIn(0.18), delay);
            return (
              <div key={index} onClick={toggle} style={{ height: 42, overflow: "hidden", display: "flex", alignItems: "flex-end", cursor: "pointer" }}>
                <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
                  <motion.span
                    initial={false}
                    animate={{ opacity: open ? 1 : 0 }}
                    transition={transition}
                    style={{ fontFamily: fonts.mono, fontSize: 11, lineHeight: "13px", fontWeight: 600, color: white(0.5) }}
                  >
                    {String(index + 1).padStart(2, "0")}
                  </motion.span>
                  <motion.span
                    initial={false}
                    animate={{ y: open ? 0 : 44, rotate: open ? 0 : tilt }}
                    transition={transition}
                    style={{ display: "block", fontSize: 30, lineHeight: "36px", fontWeight: 700, color: "#fff", whiteSpace: "nowrap", transformOrigin: "0% 100%" }}
                  >
                    {ctx.t(...word)}
                  </motion.span>
                </div>
              </div>
            );
          })}
        </div>
        {/* hamburger */}
        <motion.button
          onClick={toggle}
          initial={false}
          animate={{ backgroundColor: open ? "rgba(255,255,255,0.12)" : ctx.scheme === "dark" ? "rgba(28,28,30,1)" : "rgba(242,242,247,1)", color: open ? "#ffffff" : ctx.scheme === "dark" ? "#ffffff" : "#000000" }}
          transition={burger}
          style={{ position: "absolute", right: 16, top: 16, width: 40, height: 40, borderRadius: "50%", display: "grid", placeItems: "center" }}
        >
          <motion.span initial={false} animate={{ y: open ? 0 : -4, rotate: open ? 45 : 0 }} transition={burger} style={{ gridArea: "1 / 1", width: 18, height: 2.2, borderRadius: 1.1, background: "currentColor" }} />
          <motion.span initial={false} animate={{ y: open ? 0 : 4, rotate: open ? -45 : 0 }} transition={burger} style={{ gridArea: "1 / 1", width: 18, height: 2.2, borderRadius: 1.1, background: "currentColor" }} />
        </motion.button>
      </div>
      <DemoHint ctx={ctx} en="Tap the menu button" zh="点击菜单按钮" />
    </div>
  );
}

/** A curtain whose bottom edge reaches `progress × height` and bows downward mid-flight. */
function Curtain({ progress }: { progress: ReturnType<typeof useMotionValue<number>> }) {
  const id = useId();
  const p = clamp(useMotionNumber(progress), 0, 1.05);
  const edge = H * p;
  const bow = 30 * Math.sin(clamp(p) * Math.PI);
  return (
    <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" }} aria-hidden>
      <defs>
        <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={H}>
          <stop offset={0} stopColor="#16162A" />
          <stop offset={1} stopColor="#2A1F4F" />
        </linearGradient>
      </defs>
      {p > 0 && <path d={`M0 0H${W}V${edge}Q${W / 2} ${edge + bow * 2} 0 ${edge}Z`} fill={`url(#${id})`} />}
    </svg>
  );
}
