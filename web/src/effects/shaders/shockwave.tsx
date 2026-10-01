/** shader.shockwave · 冲击波 (Shaders+Shockwave.swift, mlShockwave) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { clamp, hex, spring, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, tapPoint, useScene } from "./_card";
import { drawCity } from "./_scenes";

/** Rings fade out completely by this radius (the card's diagonal is ≈ 397 pt). */
const REACH = 420;

export default function Shockwave({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const rings = useRef([0, 1, 2].map(() => ({ origin: { x: 130, y: 150 }, start: -1e9 })));
  const next = useRef(0);
  const flashAt = useRef<Point>({ x: 130, y: 150 });
  const punch = useMotionValue(0);
  const card = useRef<HTMLDivElement>(null);

  const detonate = (p: Point) => {
    rings.current[next.current] = { origin: p, start: nowSec() };
    next.current = (next.current + 1) % 3;
    flashAt.current = p;
    punch.set(1);
    animate(punch, 0, spring(0.32, 0.42));
  };
  useAutoplay(ctx.isPreview, () => detonate({ x: randIn(50, 210), y: randIn(70, 230) }), { every: 1.7, delay: 0.3 });

  return (
    <CenterStack ctx={ctx} en="Tap anywhere, tap again before it fades" zh="点击任意位置，可在消散前连点">
      <div ref={card} style={{ flexShrink: 0 }}>
        <ShaderCard
          glow={hex(0x7a5cff, 0.35)}
          onClick={tapPoint((p) => {
            haptics.tap("rigid");
            detonate(p);
          })}
        >
          <Shader
            width={CARD_W}
            height={CARD_H}
            fragment={FRAG.Shockwave}
            source={scene.canvas}
            fps={ctx.isPreview ? 30 : undefined}
            uniforms={() => {
              const raw = punch.get();
              // The card recoils: 97.5% at the blast, then the spring overshoots slightly past 100%.
              if (card.current) card.current.style.transform = `scale(${1 - 0.025 * raw})`;
              const p = clamp(raw, 0, 1);
              // White bloom at the blast point; it is part of the layer, so the ring refracts it too.
              scene.ensure(p > 0.001 ? nowSec() : 0, (g) => {
                drawCity(g);
                if (p <= 0.001) return;
                const { x, y } = flashAt.current;
                const r = 40 * (0.4 + (1 - p) * 1.4);
                const bloom = g.createRadialGradient(x, y, 0, x, y, r);
                bloom.addColorStop(0, "rgba(255,255,255,1)");
                bloom.addColorStop(1, "rgba(255,255,255,0)");
                g.globalCompositeOperation = "lighter";
                g.globalAlpha = p * 0.85;
                g.fillStyle = bloom;
                g.beginPath();
                g.arc(x, y, r, 0, Math.PI * 2);
                g.fill();
              });
              const speed = ctx.n("speed");
              const life = REACH / Math.max(speed, 1);
              const now = nowSec();
              const [a, b, c] = rings.current.map((ring) => {
                const age = now - ring.start;
                return { o: [ring.origin.x, ring.origin.y] as [number, number], t: age >= 0 && age < life ? age : -1 };
              });
              return {
                p_o1: a.o, p_t1: a.t, p_o2: b.o, p_t2: b.t, p_o3: c.o, p_t3: c.t,
                p_speed: speed,
                p_width: ctx.n("width"),
                p_strength: ctx.n("strength"),
                p_fringe: ctx.n("fringe"),
                p_reach: REACH,
              };
            }}
          />
        </ShaderCard>
      </div>
    </CenterStack>
  );
}
