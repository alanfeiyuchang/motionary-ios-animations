/** shader.underwater · 水下视界 (Shaders+Underwater.swift, mlUnderwater) */
import { useRef } from "react";
import { hex, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, tapPoint, useScene } from "./_card";
import { drawReef } from "./_scenes";

export default function Underwater({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const clock = useRef(clockFrom(20)).current;
  const burst = useRef({ at: { x: 150, y: 236 }, start: -1e9 });

  const exhale = (p: Point) => (burst.current = { at: p, start: nowSec() });
  useAutoplay(ctx.isPreview, () => exhale({ x: randIn(50, 210), y: randIn(190, 270) }), { every: 2.6, delay: 0.5 });

  return (
    <CenterStack ctx={ctx} en="Tap to breathe out bubbles" zh="点击吐出气泡">
      <ShaderCard
        glow={hex(0x1b7fc4, 0.35)}
        onClick={tapPoint((p) => {
          haptics.tap("soft");
          exhale(p);
        })}
      >
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Underwater}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawReef(g));
            const now = nowSec();
            const since = now - burst.current.start;
            return {
              p_time: clock.advance(now, 1),
              p_wobble: ctx.n("wobble"),
              p_rays: ctx.n("rays"),
              p_depth: ctx.n("depth"),
              p_bubbles: ctx.n("bubbles"),
              p_burst: [burst.current.at.x, burst.current.at.y],
              p_burstAge: since < 3 ? since : -1,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
