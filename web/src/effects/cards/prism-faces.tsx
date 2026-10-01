/** cards.prism-faces · 三棱柱卡片 (Cards+PrismFaces.swift) */
import { animate, useMotionValue } from "motion/react";
import { CreditCard as CreditCardIcon, Leaf, TrendingUp, type LucideIcon } from "lucide-react";
import { memo, useRef } from "react";
import { DemoHint, Palette, black, clamp, fonts, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, themeColors, useMV, type LText } from "./shared";
import { Projected, projection } from "./_kit";

const FACE = { w: 250, h: 150 };
/** Distance from a face to the prism's axis (inradius of the equilateral cross-section). */
const INRADIUS = 150 / (2 * 1.7320508);

const MODELS: { title: LText; amount: string; delta: string; Icon: LucideIcon; filled: boolean; theme: number }[] = [
  { title: ["Everyday", "日常账户"], amount: "4,280.16", delta: "+2.4%", Icon: CreditCardIcon, filled: false, theme: 0 },
  { title: ["Savings", "储蓄"], amount: "18,905.00", delta: "+0.8%", Icon: Leaf, filled: true, theme: 4 },
  { title: ["Invest", "投资"], amount: "9,612.47", delta: "+6.1%", Icon: TrendingUp, filled: false, theme: 2 },
];

export default function PrismFaces({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const angleMV = useMotionValue(0);
  const dragStart = useRef<number | null>(null);
  const settle = useTimeouts();

  const roll = (target: number, haptic: boolean) => {
    const response = ctx.n("response");
    animate(angleMV, target, spring(response, ctx.n("damping")));
    settle.clearAll();
    if (!haptic) return;
    settle.after(response * 0.6, () => haptics.tap("rigid"));
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (dragStart.current === null) {
        angleMV.stop();
        dragStart.current = angleMV.get();
        settle.clearAll();
      }
      angleMV.set(dragStart.current - (translation.y / 150) * 120);
    },
    onEnd: ({ translation, velocity }) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      angleMV.jump(angleMV.get());
      const home = Math.round(start / 120) * 120;
      if (Math.hypot(translation.x, translation.y) < 8) {
        // A tap rolls one face forward.
        roll(home + 120, true);
        return;
      }
      const projected = start - ((translation.y + velocity.y * 0.25) / 150) * 120;
      roll(home + clamp(Math.round((projected - home) / 120), -1, 1) * 120, true);
    },
  });

  useAutoplay(ctx.isPreview, () => roll(Math.round(angleMV.get() / 120) * 120 + 120, false), { every: 1.9 });

  const angle = useMV(angleMV);
  const depth = ctx.n("depth");
  const shade = ctx.n("shade");
  const offEdge = Math.abs(Math.sin((angle * Math.PI) / 120));
  const active = (((Math.round(angle / 120) % 3) + 3) % 3);
  const shadowW = FACE.w * (0.86 + 0.06 * offEdge);
  const shadowH = 26 + 10 * offEdge;
  const zh = ctx.lang === "zh";

  return (
    <Stage gap={4}>
      <div {...pan} style={{ position: "relative", width: 300, height: 262, flexShrink: 0, touchAction: "none", cursor: "grab" }}>
        <div style={{ position: "absolute", left: 25.5, top: 56, width: FACE.w, height: FACE.h }}>
          <div
            style={{
              position: "absolute",
              left: FACE.w / 2 - shadowW / 2,
              top: FACE.h / 2 - shadowH / 2 + FACE.h / 2 + 18,
              width: shadowW,
              height: shadowH,
              borderRadius: "50%",
              background: "#000",
              filter: "blur(14px)",
              opacity: 0.32 - 0.08 * offEdge,
            }}
          />
          {[0, 1, 2].map((index) => {
            let degrees = (angle - index * 120) % 360;
            if (degrees > 180) degrees -= 360;
            if (degrees < -180) degrees += 360;
            const a = (degrees * Math.PI) / 180;
            const r = INRADIUS;
            // Only faces whose front is turned toward the eye are drawn.
            if (!(Math.cos(a) * (depth + r) - r > 0)) return null;
            const half = FACE.h / 2;
            const plane = {
              origin: [0, half - half * Math.cos(a) - r * Math.sin(a), -half * Math.sin(a) + r * Math.cos(a) - r] as [number, number, number],
              u: [1, 0, 0] as [number, number, number],
              v: [0, Math.cos(a), Math.sin(a)] as [number, number, number],
            };
            // Light from above and in front of the prism.
            const lit = 0.5 * Math.sin(a) + 0.87 * Math.cos(a);
            const dark = clamp((0.87 - lit) / 0.87) * 0.75 * shade;
            const bright = clamp((lit - 0.87) / 0.13) * 0.22 * shade;
            return (
              <Projected key={index} w={FACE.w} h={FACE.h} transform={projection(plane, { x: FACE.w / 2, y: half }, depth)} style={{ zIndex: Math.round(Math.cos(a) * 100) + 100 }}>
                <PrismFace index={index} zh={zh} />
                <div style={{ position: "absolute", inset: 0, borderRadius: 16, background: black(dark) }} />
                <div style={{ position: "absolute", inset: 0, borderRadius: 16, background: white(bright) }} />
              </Projected>
            );
          })}
        </div>
        <div style={{ position: "absolute", left: 25.5 + FACE.w + 14, top: 0, bottom: 0, width: 5, display: "flex", flexDirection: "column", justifyContent: "center", gap: 7 }}>
          {[0, 1, 2].map((index) => (
            <div key={index} style={{ width: 5, height: index === active ? 16 : 5, borderRadius: 2.5, background: Palette.labelAlpha(index === active ? 0.7 : 0.2), transition: "height 0.3s cubic-bezier(0.3, 1.3, 0.6, 1), background 0.3s" }} />
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag up or down, or tap" zh="上下拖动，或点击" />
    </Stage>
  );
}

const PrismFace = memo(function PrismFace({ index, zh }: { index: number; zh: boolean }) {
  const model = MODELS[index % MODELS.length];
  return (
    <div style={{ position: "relative", width: FACE.w, height: FACE.h }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 16, overflow: "hidden", background: diag(themeColors(model.theme)) }}>
        <div style={{ position: "absolute", right: -60, top: -96, width: 170, height: 170, borderRadius: "50%", background: white(0.14) }} />
        <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", alignItems: "flex-start", color: "#fff" }}>
          <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 7 }}>
            <div style={{ width: 28, height: 28, borderRadius: 14, background: white(0.2), display: "grid", placeItems: "center", flexShrink: 0 }}>
              <model.Icon size={14} fill={model.filled ? "currentColor" : "none"} strokeWidth={model.filled ? 1 : 2.6} />
            </div>
            <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>{zh ? model.title[1] : model.title[0]}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontFamily: fonts.rounded, fontSize: 11, lineHeight: "13px", fontWeight: 700, fontVariantNumeric: "tabular-nums", padding: "4px 8px", borderRadius: 99, background: black(0.18) }}>{model.delta}</span>
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ fontSize: 9, lineHeight: "11px", fontWeight: 600, letterSpacing: 1.2, opacity: 0.75 }}>{zh ? "余额" : "BALANCE"}</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 32, lineHeight: "38px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{model.amount}</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: 14, right: 14, top: 0, height: 1.2, borderRadius: 1, background: white(0.55) }} />
      <StrokeBorder radius={16} color={white(0.16)} />
    </div>
  );
});
