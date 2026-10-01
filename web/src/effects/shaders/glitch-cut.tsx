/** shader.glitch-cut · 故障硬切 (Shaders+GlitchCut.swift, mlGlitchCut) */
import { useRef } from "react";
import { anim, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, useRun, useScene } from "./_card";
import { drawPoster } from "./_scenes";

export default function GlitchCut({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const outgoing = useScene();
  const incoming = useScene();
  const current = useRef(2);
  const seed = useRef(5.3);
  const { progress, busy, run } = useRun();

  const cut = () => {
    if (busy.current) return;
    seed.current = randIn(1, 40);
    haptics.tap("light");
    // Linear: the shader quantises this progress into twelve frames itself.
    run(anim.linear(ctx.n("duration")), () => {
      current.current += 1;
      haptics.tap("rigid");
    });
  };
  useAutoplay(ctx.isPreview, cut, { every: ctx.n("duration") + 1.2, delay: 0.5 });

  const uniforms = (role: number) => {
    const p = progress.get();
    const resting = p <= 0.0001;
    return {
      p_bypass: resting && role === 0 ? 1 : 0,
      // The incoming scene is fully transparent at rest: it is simply not drawn then.
      p_hidden: resting && role === 1 ? 1 : 0,
      p_progress: p,
      p_slices: Math.round(ctx.n("slices")),
      p_split: ctx.n("split"),
      p_noise: ctx.n("noise"),
      p_seed: seed.current,
      p_role: role,
    };
  };

  return (
    <CenterStack ctx={ctx} en="Tap to cut" zh="点击切换">
      <ShaderCard onClick={cut}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.GlitchCut}
          source={outgoing.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current;
            outgoing.ensure(c, (g, k) => drawPoster(g, k, c));
            return uniforms(0);
          }}
        />
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.GlitchCut}
          source={incoming.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current + 1;
            incoming.ensure(c, (g, k) => drawPoster(g, k, c));
            return uniforms(1);
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
