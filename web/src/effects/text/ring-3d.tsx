/** text.ring-3d · 3D 环绕文字 (Text+Ring3D.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, black, fonts, hex, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { curve, now, useFrame } from "./_fx";

export default function Ring3D({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const sim = useRef({ last: null as number | null, angle: 0.4, velocity: 0 });
  const dragging = useRef(false);
  const grabAngle = useRef(0);
  const began = useRef(now());
  const letters = useRef<(HTMLSpanElement | null)[]>([]);
  const zh = ctx.lang === "zh";
  const glyphs = Array.from(zh ? "MOTIONARY·动效词典·文字环绕·" : "MOTIONARY · KINETIC TYPE · ");
  const speed = ctx.n("speed");
  const tiltParam = ctx.n("tilt");
  const radius = ctx.n("radius");
  const back = ctx.n("back");

  useAutoplay(
    ctx.isPreview,
    () => {
      sim.current.velocity = 6.5;
    },
    { every: 4.4, delay: 1.6 },
  );

  const pan = usePan(
    {
      onChange: (s) => {
        const r = Math.max(radius, 1);
        if (!dragging.current) {
          dragging.current = true;
          grabAngle.current = sim.current.angle;
          haptics.tap("soft");
        }
        sim.current.angle = grabAngle.current + s.translation.x / r;
        sim.current.velocity = s.velocity.x / r;
      },
      onEnd: (s) => {
        dragging.current = false;
        sim.current.velocity = Math.min(Math.max(s.velocity.x / Math.max(radius, 1), -14), 14);
      },
    },
    6,
  );

  useFrame(() => {
    // Advance the spin: friction pulls it back to the cruising speed in about a second.
    const state = sim.current;
    const time = now();
    const cruise = (-speed * Math.PI) / 180;
    if (state.last === null) {
      state.last = time;
      state.velocity = cruise;
    } else {
      const dt = Math.min(Math.max(time - state.last, 0), 1 / 20);
      state.last = time;
      if (!dragging.current) {
        state.velocity += (cruise - state.velocity) * (1 - Math.exp(-dt * 2.6));
        state.angle += state.velocity * dt;
      }
    }
    const tilt = tiltParam + 4 * Math.sin((time - began.current) * 0.7);
    const rise = Math.sin((tilt * Math.PI) / 180);
    const count = glyphs.length;
    for (let index = 0; index < count; index++) {
      const el = letters.current[index];
      if (!el) continue;
      const theta = state.angle + (2 * Math.PI * index) / count;
      const facing = Math.cos(theta);
      const depth = 1 + 0.2 * facing;
      // Edge-on letters would be a sliver: fade them through the turn.
      const edge = curve.smoothstep((Math.abs(facing) - 0.06) / 0.3);
      el.style.opacity = String((facing >= 0 ? 1 : back) * edge);
      el.style.transform = `translate(-50%, -50%) translate(${(radius * Math.sin(theta)).toFixed(2)}px, ${(radius * facing * rise).toFixed(2)}px) scale(${(facing * depth).toFixed(4)}, ${depth.toFixed(4)})`;
      el.style.zIndex = facing >= 0 ? "1" : "-1";
    }
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6 }}>
      <div {...pan} style={{ ...pan.style, position: "relative", width: 330, height: 236, cursor: "grab", isolation: "isolate" }}>
        <div style={{ position: "absolute", left: "50%", top: "50%", width: 0, height: 0, zIndex: 0 }}>
          <div style={{ position: "absolute", left: -48, top: 70 - 8, width: 96, height: 16, borderRadius: "50%", background: black(0.22), filter: "blur(9px)" }} />
          <div
            style={{
              position: "absolute",
              left: -52,
              top: -52,
              width: 104,
              height: 104,
              borderRadius: "50%",
              background: `radial-gradient(circle 92px at 34% 28%, ${hex(0xffe3a8)} 2px, ${Palette.coral} 33.3%, ${hex(0x8b2fc9)} 66.7%, ${hex(0x35105c)} 100%)`,
              boxShadow: `0 0 44px ${alpha(Palette.coral, 0.35)}`,
            }}
          >
            <div style={{ position: "absolute", left: 20, top: 16, width: 30, height: 18, borderRadius: "50%", background: white(0.55), filter: "blur(7px)" }} />
          </div>
        </div>
        {glyphs.map((glyph, index) => (
          <span
            key={`${ctx.lang}${index}`}
            ref={(el) => {
              letters.current[index] = el;
            }}
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              fontFamily: fonts.rounded,
              fontSize: zh ? 31 : 30,
              lineHeight: 1.2,
              fontWeight: 900,
              color: Palette.label,
              whiteSpace: "pre",
              opacity: 0,
              pointerEvents: "none",
            }}
          >
            {glyph}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Drag sideways to spin the ring" zh="横向拖动来拨转文字环" />
    </div>
  );
}
