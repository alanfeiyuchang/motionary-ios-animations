/** feedback.notch-drop · 灵动岛滴落通知 (Feedback+NotchDrop.swift) */
import { motion, useMotionValueEvent, type Transition } from "motion/react";
import { useId, useRef, useState } from "react";
import { DemoHint, anim, black, delayed, fonts, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { useAnimated } from "./shared";

const ISLAND = { width: 112, height: 32, centre: 28 };
const BANNER = { width: 268, height: 62, centre: 90 };

export default function NotchDrop({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [dropMV, dropTo] = useAnimated(0);
  const [widenMV, widenTo] = useAnimated(0);
  const [swellMV, swellTo] = useAnimated(0);
  const [, setFrame] = useState(0);
  const redraw = () => setFrame((n) => n + 1);
  useMotionValueEvent(dropMV, "change", redraw);
  useMotionValueEvent(widenMV, "change", redraw);
  useMotionValueEvent(swellMV, "change", redraw);
  const [content, setContent] = useState<{ on: boolean; t: Transition }>({ on: false, t: { duration: 0 } });
  const shown = useRef(false);
  const token = useRef(0);

  const retract = () => {
    if (!shown.current) return;
    const current = ++token.current;
    shown.current = false;
    setContent({ on: false, t: anim.easeIn(0.12) });
    widenTo(0, delayed(spring(0.36, 0.92), 0.08));
    dropTo(0, delayed(spring(0.4, 0.86), 0.16));
    // The island swallows the drop: a quick swell, then it settles.
    after(0.4, () => {
      if (token.current !== current) return;
      swellTo(1, anim.easeOut(0.1));
      after(0.1, () => swellTo(0, spring(0.38, 0.5)));
    });
  };

  const present = (buzz: boolean) => {
    if (shown.current) return;
    const current = ++token.current;
    const damping = ctx.n("damping");
    const hold = ctx.n("hold");
    shown.current = true;
    dropTo(1, spring(0.5, damping));
    widenTo(1, delayed(spring(0.5, Math.min(damping + 0.14, 1)), 0.09));
    setContent({ on: true, t: delayed(anim.easeOut(0.26), 0.3) });
    after(0.3, () => {
      if (token.current !== current) return;
      if (buzz) haptics.tap("light");
      after(hold + 0.3, () => {
        if (token.current !== current) return;
        retract();
      });
    });
  };

  useAutoplay(ctx.isPreview, () => present(false), { every: ctx.n("hold") + 2.4, delay: 0.6 });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={ctx.isPreview ? undefined : () => (shown.current ? retract() : present(!ctx.isPreview))}
        style={{ position: "relative", width: 300, height: 270, flexShrink: 0, borderRadius: 34, boxShadow: `0 10px 36px ${black(0.22)}`, cursor: "pointer" }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, overflow: "hidden" }}>
          <Wallpaper zh={zh} />
          <Goo drop={dropMV.get()} widen={widenMV.get()} swell={swellMV.get()} goo={ctx.n("goo")} />
          {/* Banner content, laid over the banner's final frame. */}
          <motion.div
            initial={false}
            animate={{ opacity: content.on ? 1 : 0, filter: `blur(${content.on ? 0 : 6}px)`, scale: content.on ? 1 : 0.92 }}
            transition={content.t}
            style={{ position: "absolute", left: 16, top: BANNER.centre - BANNER.height / 2, width: BANNER.width, height: BANNER.height, padding: "0 13px", display: "flex", alignItems: "center", gap: 11, pointerEvents: "none" }}
          >
            <div style={{ width: 38, height: 38, flexShrink: 0, borderRadius: 11, background: `linear-gradient(${hex(0x5fe37f)}, ${hex(0x1fb24a)})`, color: "#fff", display: "grid", placeItems: "center" }}>
              {/* SF `message.fill` */}
              <svg width={22} height={22} viewBox="0 0 24 24" fill="currentColor">
                <ellipse cx={12} cy={11} rx={10} ry={8.2} />
                <path d="M6.6 16.2c-.2 1.8-1.200 3.200-2.700 4.200 2.700.1 5-.9 6.400-2.600z" />
              </svg>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center" }}>
                <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff" }}>Mia</span>
                <div style={{ flex: 1 }} />
                <span style={{ fontSize: 11, lineHeight: "13px", color: white(0.5) }}>{zh ? "现在" : "now"}</span>
              </div>
              <span style={{ fontSize: 13, lineHeight: "18px", color: white(0.78), whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{zh ? "飞机落地了，十分钟后出口见" : "Just landed. See you at arrivals in 10"}</span>
            </div>
          </motion.div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, boxShadow: `inset 0 0 0 1px ${white(0.14)}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap the screen" zh="点击屏幕" />
    </div>
  );
}

/** The island, the banner and the neck between them, fused by blur + alpha threshold. */
function Goo({ drop, widen: rawWiden, swell, goo }: { drop: number; widen: number; swell: number; goo: number }) {
  const filterId = `notch-goo-${useId().replace(/[^a-zA-Z0-9]/g, "")}`;
  const widen = Math.min(Math.max(rawWiden, 0), 1.2);
  const midX = 150;
  const islandWidth = ISLAND.width * (1 + 0.08 * swell);
  const islandHeight = ISLAND.height * (1 + 0.1 * swell);
  const width = ISLAND.width + (BANNER.width - ISLAND.width) * widen;
  const height = ISLAND.height + (BANNER.height - ISLAND.height) * widen;
  const centre = ISLAND.centre + (BANNER.centre - ISLAND.centre) * drop;
  const radius = Math.min(ISLAND.height / 2 + (22 - ISLAND.height / 2) * widen, height / 2);
  // The neck: wide while the drop is still close, gone before it lands.
  const neck = Math.max(0, 1 - drop / 0.82);
  const neckWidth = 54 * neck * neck;
  const neckHeight = Math.max(centre - ISLAND.centre, 0);
  const fused = goo >= 0.5;
  return (
    <svg width={300} height={150} viewBox="0 0 300 150" style={{ position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" }}>
      <defs>
        <filter id={filterId} x={-40} y={-40} width={380} height={260} filterUnits="userSpaceOnUse" colorInterpolationFilters="sRGB">
          <feGaussianBlur in="SourceGraphic" stdDeviation={Math.max(goo, 0.01)} />
          {/* alphaThreshold(min: 0.5): a steep ramp around 50% keeps the edge anti-aliased. */}
          <feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 36 -18" />
        </filter>
      </defs>
      <g filter={fused ? `url(#${filterId})` : undefined} fill="#000">
        <rect x={midX - islandWidth / 2} y={ISLAND.centre - islandHeight / 2} width={islandWidth} height={islandHeight} rx={islandHeight / 2} />
        {neckWidth > 1 && <rect x={midX - neckWidth / 2} y={ISLAND.centre} width={neckWidth} height={neckHeight} />}
        <rect x={midX - width / 2} y={centre - height / 2} width={width} height={Math.max(height, 0)} rx={Math.max(radius, 0)} />
      </g>
    </svg>
  );
}

/** A lock screen: wallpaper, time and date. */
function Wallpaper({ zh }: { zh: boolean }) {
  return (
    <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${hex(0x1d2671)}, ${hex(0x6b3fa0)}, ${hex(0xe0627a)}, ${hex(0xffb36b)})` }}>
      <div style={{ position: "absolute", left: 150 + 60 - 75, top: 135 + 110 - 75, width: 150, height: 150, borderRadius: "50%", background: hex(0xffd9a0, 0.55), filter: "blur(40px)" }} />
      <div style={{ position: "absolute", left: 150 - 90 - 85, top: 135 - 40 - 85, width: 170, height: 170, borderRadius: "50%", background: hex(0x3a6bff, 0.45), filter: "blur(50px)" }} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 135 + 62, transform: "translateY(-50%)", display: "flex", flexDirection: "column", alignItems: "center" }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: white(0.85) }}>{zh ? "10月1日 星期四" : "Thursday, October 1"}</span>
        <span style={{ fontFamily: fonts.rounded, fontSize: 70, lineHeight: "83.5px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: white(0.92) }}>9:41</span>
      </div>
      <div style={{ position: "absolute", left: 95, top: 135 + 125 - 2, width: 110, height: 4, borderRadius: 2, background: white(0.7) }} />
    </div>
  );
}
