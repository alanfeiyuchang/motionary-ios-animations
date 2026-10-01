/** text.spotlight-mask · 聚光灯揭示文字 (Text+SpotlightMask.swift) */
import { useRef, type CSSProperties } from "react";
import { DemoHint, Palette, alpha, useHaptics, usePan, type DemoProps } from "../../kit";
import { FXSpring, now, squeezed, useFrame } from "./_fx";

const STAGE = { w: 304, h: 250 };

/** The figure-eight the light follows on its own. */
const wander = (theta: number) => ({ x: STAGE.w / 2 + Math.sin(theta) * STAGE.w * 0.36, y: STAGE.h / 2 + Math.sin(theta * 2) * STAGE.h * 0.26 });

export default function SpotlightMask({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const sim = useRef({ last: null as number | null, theta: 0.9, x: new FXSpring(), y: new FXSpring(), grow: new FXSpring(), started: false });
  const finger = useRef({ x: 0, y: 0 });
  const held = useRef(false);
  const glow = useRef<HTMLDivElement>(null);
  const lit = useRef<HTMLDivElement>(null);
  const tint = useRef<HTMLDivElement>(null);
  const zh = ctx.lang === "zh";
  const radiusParam = ctx.n("radius");
  const softness = ctx.n("softness");
  const speed = ctx.n("speed");

  const pan = usePan({
    onStart: () => haptics.tap("soft"),
    onChange: (s) => {
      held.current = true;
      finger.current = s.location;
    },
    onEnd: () => {
      held.current = false;
    },
  });

  useFrame(() => {
    const state = sim.current;
    if (!state.started) {
      const start = wander(state.theta);
      state.x.value = start.x;
      state.y.value = start.y;
      state.started = true;
    }
    const time = now();
    if (state.last !== null) {
      const dt = Math.min(Math.max(time - state.last, 0), 0.1);
      if (dt > 0) {
        if (!held.current) state.theta += speed * dt * 1.6;
        const target = held.current ? finger.current : wander(state.theta);
        const response = held.current ? 0.22 : 0.7;
        const damping = held.current ? 0.8 : 0.9;
        state.x.step(target.x, dt, response, damping);
        state.y.step(target.y, dt, response, damping);
        state.grow.step(held.current ? 1 : 0, dt, 0.35, 0.6);
        state.last = time;
      }
    } else state.last = time;

    const x = state.x.value;
    const y = state.y.value;
    const radius = Math.max(radiusParam * (1 + 0.15 * state.grow.value), 1);
    const light = (r: number, soft: number) => `radial-gradient(circle at ${x.toFixed(2)}px ${y.toFixed(2)}px, #000 ${(r * (1 - soft)).toFixed(2)}px, transparent ${r.toFixed(2)}px)`;
    if (glow.current) {
      const size = radius * 2.3;
      glow.current.style.width = glow.current.style.height = `${size}px`;
      glow.current.style.transform = `translate(${x - size / 2}px, ${y - size / 2}px)`;
    }
    if (lit.current) lit.current.style.maskImage = lit.current.style.webkitMaskImage = light(radius, softness);
    if (tint.current) tint.current.style.maskImage = tint.current.style.webkitMaskImage = light(radius * 0.62, 0.9);
  }, ctx.isPreview ? 30 : undefined);

  const fontSize = zh ? 26 : 22;
  const paragraph: CSSProperties = {
    position: "absolute",
    inset: 0,
    display: "flex",
    alignItems: "center",
    fontSize,
    lineHeight: `${Math.round(fontSize * 1.195) + (zh ? 8 : 6)}px`,
    fontWeight: 700,
    textAlign: "left",
    pointerEvents: "none",
  };
  const text = ctx.t(
    "Look closer. The best details hide in plain sight: a softer shadow, a spring that settles, a pause before the reveal. Light finds them one at a time.",
    "凑近一点看。最好的细节都藏在明处：柔一点的阴影，恰好停稳的弹簧，揭晓前的那一下停顿。光一次只照亮一处。",
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: STAGE.w, height: STAGE.h, cursor: "grab" }}>
        <div
          ref={glow}
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            borderRadius: "50%",
            background: `radial-gradient(circle closest-side, ${alpha(Palette.coral, 0.2)}, ${alpha(Palette.violet, 0.08)} 50%, ${alpha(Palette.violet, 0)} 100%)`,
            pointerEvents: "none",
          }}
        />
        <div style={{ ...paragraph, color: Palette.labelAlpha(ctx.n("dim")) }}>
          <span>{squeezed(text)}</span>
        </div>
        <div ref={lit} style={{ ...paragraph, color: Palette.label }}>
          <span>{squeezed(text)}</span>
        </div>
        <div ref={tint} style={paragraph}>
          <span
            style={{
              backgroundImage: `linear-gradient(to bottom right, ${Palette.coral}, ${Palette.pink}, ${Palette.violet})`,
              WebkitBackgroundClip: "text",
              backgroundClip: "text",
              color: "transparent",
              WebkitTextFillColor: "transparent",
            }}
          >
            {squeezed(text)}
          </span>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag the light across the text" zh="拖动光圈扫过文字" />
    </div>
  );
}
