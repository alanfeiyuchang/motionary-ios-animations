/** shader.rain-glass · 雨滴玻璃 (Shaders+RainGlass.swift, mlRainGlass) */
import { useRef } from "react";
import { hex, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, tapPoint, useScene } from "./_card";
import { drawStreet } from "./_scenes";

export default function RainGlass({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const clock = useRef(clockFrom(14)).current;
  const taps = useRef([0, 1, 2].map(() => ({ origin: { x: 0, y: 0 }, start: -1e9 })));
  const next = useRef(0);

  const drop = (p: Point) => {
    taps.current[next.current] = { origin: p, start: nowSec() };
    next.current = (next.current + 1) % 3;
  };
  useAutoplay(ctx.isPreview, () => drop({ x: randIn(40, 220), y: randIn(30, 130) }), { every: 1.8, delay: 0.6 });

  return (
    <CenterStack ctx={ctx} en="Tap the glass to send a drop down" zh="点击玻璃，让一颗水滴滑下">
      <ShaderCard
        glow={hex(0x3a1e55, 0.5)}
        onClick={tapPoint((p) => {
          haptics.tap("soft");
          drop(p);
        })}
      >
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.RainGlass}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g, k) => drawStreet(g, k));
            const now = nowSec();
            const [t1, t2, t3] = taps.current.map((tap): [number, number, number] => {
              const age = now - tap.start;
              return [tap.origin.x, tap.origin.y, age >= 0 && age < 3.2 ? age : -1];
            });
            return {
              p_time: clock.advance(now, ctx.n("speed")),
              p_amount: ctx.n("amount"),
              p_refraction: ctx.n("refraction"),
              p_fog: ctx.n("fog"),
              p_t1: t1,
              p_t2: t2,
              p_t3: t3,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
