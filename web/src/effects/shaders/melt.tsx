/** shader.melt · 蜡质融化 (Shaders+WaxMelt.swift, mlWaxMelt) */
import { useRef } from "react";
import { anim, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { LayerView, randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, tapPoint, useRun, useScene } from "./_card";
import { drawPoster } from "./_scenes";

export default function WaxMelt({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const top = useScene();
  const bottom = useScene();
  const current = useRef(0);
  const originX = useRef(150);
  const seed = useRef(3.7);
  const { progress, busy, run } = useRun();

  const melt = (x: number) => {
    if (busy.current) return;
    originX.current = x;
    seed.current = randIn(0, 40);
    haptics.tap("soft");
    // Linear: every column applies its own gravity curve to this progress.
    run(anim.linear(ctx.n("duration")), () => (current.current += 1));
  };
  useAutoplay(ctx.isPreview, () => melt(randIn(40, 220)), { every: ctx.n("duration") + 1.0, delay: 0.4 });

  return (
    <CenterStack ctx={ctx} en="Tap to melt the poster" zh="点击让海报融化">
      <ShaderCard onClick={tapPoint((p) => melt(p.x))}>
        <LayerView layer={bottom.layer} width={CARD_W} height={CARD_H} style={{ position: "absolute", inset: 0 }} />
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.WaxMelt}
          source={top.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current;
            top.ensure(c, (g, k) => drawPoster(g, k, c));
            bottom.ensure(c + 1, (g, k) => drawPoster(g, k, c + 1));
            const p = progress.get();
            return {
              p_bypass: p > 0.0001 ? 0 : 1,
              p_progress: p,
              p_originX: originX.current,
              p_drip: ctx.n("drip"),
              p_goo: ctx.n("goo"),
              p_seed: seed.current,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
