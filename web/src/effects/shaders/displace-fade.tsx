/** shader.displace-fade · 置换溶接 (Shaders+DisplaceFade.swift, mlDisplaceFade) */
import { useRef } from "react";
import { anim, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, tapPoint, useRun, useScene } from "./_card";
import { drawLandscape } from "./_scenes";

export default function DisplaceFade({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const outgoing = useScene();
  const incoming = useScene();
  const current = useRef(0);
  const origin = useRef<Point>({ x: 130, y: 150 });
  const { progress, busy, run } = useRun();

  const fade = (p: Point) => {
    if (busy.current) return;
    origin.current = p;
    haptics.tap("soft");
    run(anim.easeInOut(ctx.n("duration")), () => (current.current += 1));
  };
  useAutoplay(ctx.isPreview, () => fade({ x: randIn(60, 200), y: randIn(80, 220) }), { every: ctx.n("duration") + 1.0, delay: 0.4 });

  const uniforms = (role: number) => {
    const p = progress.get();
    const resting = p <= 0.0001;
    return {
      p_bypass: resting && role === 0 ? 1 : 0,
      // The incoming scene is fully transparent at rest: it is simply not drawn then.
      p_hidden: resting && role === 1 ? 1 : 0,
      p_progress: p,
      p_strength: ctx.n("strength"),
      p_scale: ctx.n("scale"),
      p_kind: ctx.i("map"),
      p_origin: [origin.current.x, origin.current.y] as [number, number],
      p_role: role,
    };
  };

  return (
    <CenterStack ctx={ctx} en="Tap to fade to the next view" zh="点击溶接到下一幅">
      <ShaderCard onClick={tapPoint(fade)}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.DisplaceFade}
          source={outgoing.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current;
            outgoing.ensure(c, (g) => drawLandscape(g, c));
            return uniforms(0);
          }}
        />
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.DisplaceFade}
          source={incoming.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current + 1;
            incoming.ensure(c, (g) => drawLandscape(g, c));
            return uniforms(1);
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
