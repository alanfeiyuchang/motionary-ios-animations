/** morph.split-doors · 双开门转场 (Morph+SplitDoors.swift) */
import { animate, useMotionValue } from "motion/react";
import { Box, Palette as PaletteIcon, Sun, type LucideIcon } from "lucide-react";
import { memo, useRef, useState } from "react";
import { DemoHint, black, fonts, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Column, diag, mixN, morphScreen, smooth, unit, useMV } from "./_shared";

const W = 316;
const H = 306;
const HALF = W / 2;
interface DoorPage {
  number: string;
  title: [string, string];
  caption: [string, string];
  Icon: LucideIcon;
  colors: [string, string];
}
const pages: DoorPage[] = [
  { number: "01", title: ["Light", "光"], caption: ["Hall of daylight studies", "日光研究展厅"], Icon: Sun, colors: ["#1B1848", "#5A3FD6"] },
  { number: "02", title: ["Colour", "色"], caption: ["Pigments and gradients", "颜料与渐变展厅"], Icon: PaletteIcon, colors: ["#FF8A5C", "#F0437A"] },
  { number: "03", title: ["Form", "形"], caption: ["Solids, voids and edges", "体块、留白与边线"], Icon: Box, colors: ["#0B6B5C", "#1FC79E"] },
];

export default function SplitDoors({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [index, setIndex] = useState(0);
  const progressMV = useMotionValue(0);
  const progress = useMV(progressMV);
  const opening = useRef(false);
  const L = ctx.lang === "zh" ? 1 : 0;

  const open = (buzz = true) => {
    if (opening.current) return;
    opening.current = true;
    haptics.tap("medium");
    const response = ctx.n("response");
    animate(progressMV, 1, spring(response, 0.86));
    // The spring's logical end (its response), while the last sliver of travel is still settling out of sight.
    after(response, () => {
      progressMV.stop();
      setIndex((i) => (i + 1) % pages.length);
      progressMV.jump(0);
      opening.current = false;
      if (buzz) haptics.tap("soft");
    });
  };
  useAutoplay(ctx.isPreview, () => open(false), { every: 1.9 });

  const slide = ctx.i("style") === 1;
  const angle = ctx.n("angle");
  const depth = ctx.n("depth");
  const p = unit(progress);
  const next = (index + 1) % pages.length;
  const theta = angle * progress;
  // Where each door's free edge sits on screen (flat approximation, good enough for the shadows).
  const edge = slide ? HALF * (1 - p) : HALF * Math.max(Math.cos((theta * Math.PI) / 180), 0);
  const fade = 1 - smooth(p, 0.82, 1);
  const strength = 1 - p;
  const turned = slide ? 0 : p;

  const door = (leading: boolean) => (
    <div
      style={{
        position: "absolute",
        top: 0,
        left: leading ? 0 : HALF,
        width: HALF,
        height: H,
        overflow: "hidden",
        opacity: fade,
        pointerEvents: "none",
        transformOrigin: leading ? "0% 50%" : "100% 50%",
        transform: slide ? `translateX(${(leading ? -1 : 1) * (HALF + 8) * progress}px)` : `perspective(${H / 0.7}px) rotateY(${leading ? theta : -theta}deg)`,
      }}
    >
      <div style={{ position: "absolute", top: 0, left: leading ? 0 : -HALF, width: W, height: H }}>
        <PageView page={pages[index]} L={L} />
      </div>
      <div style={{ position: "absolute", inset: 0, background: black(0.55 * turned) }} />
      {/* Free edge catching the light from the next room. */}
      <div
        style={{
          position: "absolute",
          top: 0,
          bottom: 0,
          width: 10,
          ...(leading ? { right: 0 } : { left: 0 }),
          background: `linear-gradient(to ${leading ? "left" : "right"}, ${white(0.65)}, ${white(0)})`,
          opacity: smooth(p, 0.02, 0.25),
        }}
      />
    </div>
  );

  return (
    <Column gap={10}>
      <div onClick={() => open()} style={{ ...morphScreen(), background: "#000", cursor: "pointer" }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${mixN(depth, 1, p)})` }}>
          <PageView page={pages[next]} L={L} />
        </div>
        <div style={{ position: "absolute", inset: 0, background: black(0.5 * Math.pow(1 - p, 1.4)) }} />
        <div style={{ position: "absolute", top: 0, left: HALF - edge, width: 56, height: H, background: `linear-gradient(to right, ${black(0.55 * strength)}, transparent)`, pointerEvents: "none" }} />
        <div style={{ position: "absolute", top: 0, left: HALF + edge - 56, width: 56, height: H, background: `linear-gradient(to right, transparent, ${black(0.55 * strength)})`, pointerEvents: "none" }} />
        {door(true)}
        {door(false)}
        {/* The crack of light as the seam opens. */}
        <div
          style={{
            position: "absolute",
            left: HALF - 1,
            top: 0,
            width: 2,
            height: H,
            background: "#fff",
            boxShadow: `0 0 10px #fff, 0 0 24px ${white(0.7)}`,
            opacity: Math.sin(Math.PI * unit(p / 0.3)),
            pointerEvents: "none",
          }}
        />
      </div>
      <DemoHint ctx={ctx} en="Tap the doors" zh="点击这扇门" />
    </Column>
  );
}

const PageView = memo(function PageView({ page, L }: { page: DoorPage; L: number }) {
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, color: "#fff", background: `radial-gradient(240px circle at 85% 10%, ${white(0.22)}, transparent), ${diag(...page.colors)}` }}>
      <page.Icon size={132} strokeWidth={2.2} fill="currentColor" fillOpacity={page.Icon === Sun ? 1 : 0.35} style={{ position: "absolute", left: W - 70 - 66, top: 96 - 66, color: white(0.16) }} />
      <div style={{ position: "absolute", inset: 0, padding: 20, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 700, letterSpacing: L ? 4 : 2, opacity: 0.75 }}>{L ? "展厅" : "GALLERY"}</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 76, lineHeight: "90px", fontWeight: 800, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums" }}>{page.number}</span>
        <span style={{ fontSize: 26, lineHeight: "31px", fontWeight: 700 }}>{page.title[L]}</span>
        <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 500, opacity: 0.8, paddingTop: 2 }}>{page.caption[L]}</span>
      </div>
      {/* Seam and handles: it reads as a pair of doors before anything moves. */}
      <div style={{ position: "absolute", left: HALF - 0.5, top: 0, width: 1, height: H, background: black(0.28) }} />
      <div style={{ position: "absolute", left: HALF - 14, top: H / 2 - 18, display: "flex", gap: 20, filter: `drop-shadow(0 1px 2px ${black(0.3)})` }}>
        <div style={{ width: 4, height: 36, borderRadius: 2, background: white(0.8) }} />
        <div style={{ width: 4, height: 36, borderRadius: 2, background: white(0.8) }} />
      </div>
    </div>
  );
});
