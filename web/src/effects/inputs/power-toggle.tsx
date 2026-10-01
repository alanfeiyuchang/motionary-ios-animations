/** inputs.power-toggle (Inputs+PowerToggle.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { DemoHint, Palette, alpha, anim, black, clamp, delayed, spring, textStyle, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { GradientBorder, column, spacer, useLatchedPress, useLive, useMV } from "./_c-common";
import { useRef } from "react";

const SIZE = 136;
const TINTS = [Palette.mint, Palette.sky, Palette.amber, Palette.pink];

export default function PowerToggle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const press = useLatchedPress();
  const [isOn, setIsOn, isOnRef] = useLive(false);
  /** Crisp lit stroke, 0...1. */
  const litMV = useMotionValue(0);
  /** Bloom and halo, 0...1. Fades slower than `lit` when powering off. */
  const glowMV = useMotionValue(0);
  const barMV = useMotionValue(0);
  const arcMV = useMotionValue(0);
  const ringA = useMotionValue(0);
  const ringB = useMotionValue(0);
  const resetTask = useRef<(() => void) | null>(null);
  const tint = TINTS[clamp(ctx.i("tint"), 0, TINTS.length - 1)];

  const powerOn = () => {
    setIsOn(true);
    haptics.tap("medium");
    animate(barMV, 1, anim.easeOut(0.18));
    animate(arcMV, 1, delayed(anim.easeInOut(0.42), 0.14));
    animate(litMV, 1, spring(0.5, 0.7));
    animate(glowMV, 1, spring(0.5, 0.7));
    animate(ringA, 1, delayed(anim.easeOut(0.8), 0.1));
    animate(ringB, 1, delayed(anim.easeOut(0.8), 0.22));
  };
  const powerOff = () => {
    setIsOn(false);
    haptics.tap("soft");
    const afterglow = ctx.n("afterglow");
    animate(litMV, 0, anim.easeOut(afterglow * 0.4));
    animate(glowMV, 0, anim.easeOut(afterglow));
    // Rings are invisible at both ends of their travel, so they can jump home now.
    ringA.jump(0);
    ringB.jump(0);
    // Once dark, un-draw the stroke so the next power-on lights it again.
    resetTask.current = after(afterglow + 0.05, () => {
      if (isOnRef.current) return;
      barMV.jump(0);
      arcMV.jump(0);
    });
  };
  const toggle = () => {
    press.bump();
    resetTask.current?.();
    if (isOnRef.current) powerOff();
    else powerOn();
  };
  useAutoplay(ctx.isPreview, toggle, { every: 1.9, delay: 0.5 });

  const lit = clamp(useMV(litMV));
  const glowRaw = useMV(glowMV);
  const glow = clamp(glowRaw);
  const bar = clamp(useMV(barMV));
  const arc = clamp(useMV(arcMV));

  // Power symbol: a bar drawn top-down and an open arc drawn from both ends of its gap.
  const cx = 28;
  const cy = 28 + 56 * 0.06;
  const r = 56 * 0.42;
  const pt = (deg: number) => `${cx + r * Math.sin((deg * Math.PI) / 180)} ${cy - r * Math.cos((deg * Math.PI) / 180)}`;
  const glyph = (b: number, a: number) => {
    let d = "";
    if (b > 0.001) d += `M${cx} 0 L${cx} ${56 * 0.46 * b}`;
    if (a > 0.001) {
      const end = 32 + 148 * a;
      d += ` M${pt(32)} A${r} ${r} 0 ${end - 32 > 180 ? 1 : 0} 1 ${pt(end)}`;
      d += ` M${pt(-32)} A${r} ${r} 0 ${end - 32 > 180 ? 1 : 0} 0 ${pt(-end)}`;
    }
    return d;
  };
  const drawn = glyph(bar, arc);
  const centre = { position: "absolute", left: "50%", top: "50%" } as const;

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", width: 300, height: 208, flexShrink: 0 }}>
        {/* halo */}
        <div
          style={{
            ...centre,
            width: 264,
            height: 264,
            margin: -132,
            borderRadius: "50%",
            background: `radial-gradient(circle, ${alpha(tint, 0.5)} 50px, ${alpha(tint, 0.16)} 91px, ${alpha(tint, 0)} 132px)`,
            opacity: glow,
            transform: `scale(${0.86 + 0.14 * glowRaw})`,
            pointerEvents: "none",
          }}
        />
        <Ring progress={ringA} reach={ctx.n("ring")} tint={tint} />
        <Ring progress={ringB} reach={ctx.n("ring")} tint={tint} />
        <motion.button
          type="button"
          onClick={toggle}
          {...press.handlers}
          animate={{ scale: press.pressed ? 0.95 : 1, filter: `brightness(${press.pressed ? 0.97 : 1})` }}
          transition={spring(0.3, 0.6)}
          style={{ ...centre, width: SIZE, height: SIZE, margin: -SIZE / 2, borderRadius: "50%" }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              background: `linear-gradient(180deg, ${Palette.elevated}, ${Palette.surface})`,
              boxShadow: `0 12px 24px ${black(0.2)}, 0 0 33px ${alpha(tint, 0.35 * glow)}`,
            }}
          />
          <GradientBorder background={`linear-gradient(180deg, ${white(0.55)}, ${black(0.1)})`} width={1} radius="50%" />
          <div style={{ position: "absolute", inset: 11, borderRadius: "50%", border: `5px solid ${Palette.labelAlpha(0.07)}` }} />
          <div style={{ position: "absolute", inset: 13, borderRadius: "50%", border: `1.5px solid ${alpha(tint, 0.9 * lit)}`, boxShadow: `0 0 7px ${alpha(tint, glow)}, inset 0 0 7px ${alpha(tint, glow * 0.6)}` }} />
          <svg width={56} height={56} style={{ position: "absolute", left: (SIZE - 56) / 2, top: (SIZE - 56) / 2, overflow: "visible" }} fill="none" strokeLinecap="round">
            <path d={glyph(1, 1)} stroke={Palette.labelAlpha(0.2)} strokeWidth={7} />
            {drawn && (
              <>
                <path d={drawn} stroke={tint} strokeWidth={7} opacity={glow} style={{ filter: "blur(9px)" }} />
                <path d={drawn} stroke={tint} strokeWidth={7} opacity={lit} />
                <path d={drawn} stroke={white(0.75)} strokeWidth={2} opacity={lit} />
              </>
            )}
          </svg>
        </motion.button>
      </div>
      {/* status */}
      <div style={{ display: "flex", alignItems: "center", gap: 7, padding: "0 12px", height: 30, borderRadius: 15, background: Palette.labelAlpha(0.06), flexShrink: 0 }}>
        <div
          style={{
            width: 7,
            height: 7,
            borderRadius: "50%",
            background: isOn ? tint : Palette.labelAlpha(0.25),
            boxShadow: `0 0 6px ${alpha(tint, isOn ? 0.9 : 0)}`,
            transition: "background-color 0.35s, box-shadow 0.35s",
          }}
        />
        <span style={{ display: "inline-grid", ...textStyle.footnote, fontWeight: 600 }}>
          <AnimatePresence initial={false} mode="popLayout">
            <motion.span
              key={isOn ? "on" : "off"}
              initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
              exit={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              transition={anim.easeInOut(0.35)}
              style={{ gridArea: "1 / 1", whiteSpace: "nowrap", color: isOn ? Palette.label : Palette.secondaryLabel }}
            >
              {isOn ? ctx.t("Powered on", "已开机") : ctx.t("Standby", "待机")}
            </motion.span>
          </AnimatePresence>
        </span>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the power button" zh="点按电源键" style={{ paddingBottom: 14 }} />
    </div>
  );
}

/** One expanding ring: its opacity and width follow the travel instead of its end points. */
function Ring({ progress, reach, tint }: { progress: ReturnType<typeof useMotionValue<number>>; reach: number; tint: string }) {
  const p = useMV(progress);
  const scale = 1 + (reach - 1) * p;
  const line = 0.8 + 4 * (1 - p);
  const opacity = (1 - p) * Math.min(p * 10, 1);
  if (opacity <= 0.001) return null;
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        top: "50%",
        width: SIZE,
        height: SIZE,
        margin: -SIZE / 2,
        borderRadius: "50%",
        border: `${line}px solid color-mix(in srgb, ${tint}, white 50%)`,
        transform: `scale(${scale})`,
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}
