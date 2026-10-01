/** text.gradient-flow · 流动渐变文字 (Text+GradientFlow.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, type CSSProperties } from "react";
import { DemoHint, Palette, anim, fonts, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { unitGradient, useSize } from "./_text-kit";
import { now, useFrame } from "./_fx";

const COLORS = [Palette.indigo, Palette.violet, Palette.pink, Palette.coral, Palette.amber, Palette.mint, Palette.sky];
/** Two periods of the palette, so shifting by one period loops seamlessly. */
const STOPS = Array.from({ length: COLORS.length * 2 + 1 }, (_, index) => ({ color: COLORS[index % COLORS.length], location: index / (COLORS.length * 2) }));

export default function GradientFlow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const sim = useRef({ last: null as number | null, phase: 0.18, boost: 0 });
  const swell = useMotionValue(1);
  const flare = useMotionValue(0);
  const glowRef = useRef<HTMLSpanElement>(null);
  const flareRef = useRef<HTMLSpanElement>(null);
  const crispRef = useRef<HTMLSpanElement>(null);
  const zh = ctx.lang === "zh";
  const fontSize = zh ? 58 : 54;
  const [sizeRef, size] = useSize<HTMLSpanElement>([ctx.lang]);
  const speed = ctx.n("speed");
  const angle = (ctx.n("angle") * Math.PI) / 180;
  const glow = ctx.n("glow");
  const breathPeriod = Math.max(ctx.n("breath"), 0.2);

  const pulse = () => {
    sim.current.boost = 1;
    animate(swell, 1.04, anim.easeOut(0.12));
    animate(flare, 0.9, anim.easeOut(0.12));
    after(0.12, () => animate(swell, 1, spring(0.4, 0.5)));
    after(0.14, () => animate(flare, 0, anim.easeOut(0.9)));
  };
  useAutoplay(ctx.isPreview, pulse, { every: 4.2, delay: 1.6 });

  useFrame(() => {
    const state = sim.current;
    const time = now();
    if (state.last !== null) {
      const dt = Math.min(Math.max(time - state.last, 0), 0.1);
      if (dt > 0) {
        state.phase += speed * (1 + 3 * state.boost) * dt;
        state.boost *= Math.exp(-dt * 2.4);
        state.last = time;
      }
    } else state.last = time;
    if (!size.w) return;
    const breath = 0.5 + 0.5 * Math.sin((time * 2 * Math.PI) / breathPeriod);
    const dx = Math.cos(angle);
    const dy = Math.sin(angle);
    const period = 1.5;
    const fraction = state.phase - Math.floor(state.phase);
    const startOffset = -0.75 - fraction * period;
    const endOffset = startOffset + 2 * period;
    const image = unitGradient(size.w, size.h, { x: 0.5 + dx * startOffset, y: 0.5 + dy * startOffset }, { x: 0.5 + dx * endOffset, y: 0.5 + dy * endOffset }, STOPS);
    for (const el of [glowRef.current, flareRef.current, crispRef.current]) if (el) el.style.backgroundImage = image;
    if (glowRef.current) {
      glowRef.current.style.filter = `blur(${(glow * (0.75 + 0.33 * breath)).toFixed(2)}px)`;
      glowRef.current.style.opacity = String(0.35 + 0.4 * breath);
    }
  }, ctx.isPreview ? 30 : undefined);

  const heading: CSSProperties = {
    display: "block",
    fontFamily: fonts.rounded,
    fontSize,
    lineHeight: `${Math.round(fontSize * 1.19) + 2}px`,
    fontWeight: 900,
    textAlign: "center",
    whiteSpace: "pre",
    WebkitBackgroundClip: "text",
    backgroundClip: "text",
    color: "transparent",
    WebkitTextFillColor: "transparent",
    // Room for the glow: a blurred clipped background is cut at the element's box.
    padding: "50px 60px",
    backgroundOrigin: "content-box",
    backgroundRepeat: "no-repeat",
  };
  const text = ctx.t("Colour\nin motion", "让色彩\n流动起来");
  const layer: CSSProperties = { ...heading, position: "absolute", left: -60, top: -50, pointerEvents: "none" };

  return (
    <div
      onClick={() => {
        haptics.tap("soft");
        pulse();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 26, cursor: "pointer" }}
    >
      <motion.div style={{ position: "relative", padding: "24px 30px", scale: swell }}>
        <div style={{ position: "relative" }}>
          {/* Sizer: the text's own frame, which the gradient spans. */}
          <span ref={sizeRef} style={{ ...heading, padding: 0, visibility: "hidden" }}>{text}</span>
          <span ref={glowRef} style={layer}>{text}</span>
          <motion.span style={{ position: "absolute", left: 0, top: 0, opacity: flare }}>
            <span ref={flareRef} style={{ ...layer, filter: `blur(${glow * 1.5}px)` }}>{text}</span>
          </motion.span>
          <span ref={crispRef} style={layer}>{text}</span>
        </div>
      </motion.div>
      <DemoHint ctx={ctx} en="Tap to send a pulse" zh="点击送出一次脉冲" />
    </div>
  );
}
