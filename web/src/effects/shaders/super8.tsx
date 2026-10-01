/** shader.super8 · 超 8 胶片 (Shaders+Super8.swift, mlSuper8) */
import { useRef } from "react";
import { hex, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { nowSec } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, useScene } from "./_card";
import { drawHoliday } from "./_scenes";

export default function Super8({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const clock = useRef(clockFrom(3)).current;
  const slipStart = useRef(-1e9);

  const slipFilm = () => (slipStart.current = nowSec());
  useAutoplay(ctx.isPreview, slipFilm, { every: 3.0, delay: 0.8 });

  return (
    <CenterStack ctx={ctx} en="Tap to make the film slip" zh="点击让胶片打滑">
      <ShaderCard
        glow={hex(0xff8a3d, 0.25)}
        onClick={() => {
          haptics.tap("rigid");
          slipFilm();
        }}
      >
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Super8}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawHoliday(g));
            const now = nowSec();
            const since = now - slipStart.current;
            return {
              p_time: clock.advance(now, 1),
              p_grain: ctx.n("grain"),
              p_wear: ctx.n("wear"),
              p_flicker: ctx.n("flicker"),
              p_stock: ctx.i("stock"),
              p_slip: since < 2 ? since : -1,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
