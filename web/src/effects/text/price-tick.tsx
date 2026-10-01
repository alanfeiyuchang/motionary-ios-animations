/** text.price-tick · 实时报价跳动 (Text+PriceTick.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, fonts, forever, spring, springDB, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { RollingText } from "./_text-kit";
import { RollGlyph } from "./_fx";

const OPEN = 18427;
/** Price moves in cents. They sum to zero, so the loop is seamless, and cross the open twice. */
const MOVES = [38, 127, -52, -246, -91, 64, 213, -9, -158, 114];

export default function PriceTick({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [cents, setCents] = useState(OPEN + 71);
  const [direction, setDirection] = useState(1);
  const step = useRef(0);
  const glow = useMotionValue(0);
  const bump = useMotionValue(1);
  const flashHold = ctx.n("flash");

  const delta = cents - OPEN;
  const rising = delta >= 0;
  const tint = rising ? Palette.green : Palette.red;

  const tick = () => {
    const move = MOVES[step.current % MOVES.length];
    step.current += 1;
    setDirection(move >= 0 ? 1 : -1);
    setCents((c) => c + move);
    animate(glow, 0.3, anim.easeOut(0.12));
    animate(bump, 1.08, anim.easeOut(0.12));
    after(0.12, () => animate(bump, 1, spring(0.4, 0.5)));
    after(0.14, () => animate(glow, 0, anim.easeOut(flashHold + 0.2)));
    return move >= 0 ? 1 : -1;
  };
  useAutoplay(ctx.isPreview, tick, { every: 1.5 });

  const text = (cents / 100).toFixed(2);
  const glyphs = Array.from(text);
  const count = glyphs.length;
  const flash = direction > 0 ? Palette.green : Palette.red;
  const amount = `${rising ? "+" : "−"}${(Math.abs(delta) / 100).toFixed(2)}`;
  const percent = `${((Math.abs(delta) / OPEN) * 100).toFixed(2)}%`;
  const chipFont = { fontFamily: fonts.rounded, fontSize: 16, lineHeight: "19px", fontWeight: 700 } as const;
  const snappy = springDB(0.3, 0.15);

  return (
    <div
      onClick={() => haptics.tap(tick() > 0 ? "light" : "rigid")}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18, cursor: "pointer" }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
        <motion.span
          initial={{ opacity: 1, scale: 1 }}
          animate={{ opacity: 0.35, scale: 0.8 }}
          transition={forever(anim.easeInOut(0.9))}
          style={{ width: 7, height: 7, borderRadius: "50%", background: Palette.red }}
        />
        <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 800, letterSpacing: 1.5, marginRight: -1.5, color: Palette.label }}>MTNY</span>
        <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("Motionary Inc.", "动效词典")}</span>
      </div>

      <div style={{ position: "relative", display: "flex", alignItems: "flex-end" }}>
        <motion.div
          style={{
            position: "absolute",
            left: "50%",
            top: "50%",
            width: 250,
            height: 90,
            marginLeft: -125,
            marginTop: -45,
            borderRadius: "50%",
            background: flash,
            filter: "blur(34px)",
            opacity: glow,
            pointerEvents: "none",
          }}
        />
        <span style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 30, lineHeight: "30px", fontWeight: 700, color: Palette.secondaryLabel, paddingRight: 4, marginBottom: 11 }}>$</span>
        {glyphs.map((g, index) => {
          const place = count - 1 - index;
          return (
            <RollGlyph
              key={place}
              glyph={g}
              direction={direction}
              font={{ fontFamily: fonts.rounded, fontSize: 64, fontWeight: 800, fontVariantNumeric: "tabular-nums", lineHeight: "76px" }}
              slot={{ w: g === "." ? 20 : 40, h: 76 }}
              flash={flash}
              flashHold={flashHold}
              response={ctx.n("response")}
              damping={0.78}
              delay={place * ctx.n("stagger")}
              blur={4}
            />
          );
        })}
      </div>

      <motion.div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 7,
          padding: "8px 14px",
          borderRadius: 999,
          color: tint,
          background: alpha(tint, 0.15),
          boxShadow: `inset 0 0 0 1px ${alpha(tint, 0.28)}`,
          transition: "color 0.3s ease-out, background-color 0.3s ease-out, box-shadow 0.3s ease-out",
          scale: bump,
          ...chipFont,
        }}
      >
        <motion.svg width={11} height={10} viewBox="0 0 11 10" animate={{ rotate: rising ? 0 : 180 }} transition={spring(0.45, 0.5)} initial={false}>
          <path d="M5.5 0.9 L10.2 9 L0.8 9 Z" fill="currentColor" stroke="currentColor" strokeWidth={1.2} strokeLinejoin="round" />
        </motion.svg>
        <RollingText value={delta} text={amount} transition={snappy} />
        <RollingText value={delta} text={`(${percent})`} transition={snappy} style={{ opacity: 0.75 }} />
      </motion.div>

      <DemoHint ctx={ctx} en="Tap for the next tick" zh="点击触发下一次跳动" style={{ paddingTop: 14 }} />
    </div>
  );
}
