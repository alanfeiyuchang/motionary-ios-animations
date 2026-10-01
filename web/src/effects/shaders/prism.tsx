/** shader.prism · 棱镜色散 (Shaders+Prism.swift, mlPrism) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { anim, hex, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clampTo, useScene, useShaderTouch } from "./_card";
import { drawType } from "./_scenes";

export default function Prism({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const x = useMotionValue(92);
  const lean = useMotionValue(0);
  const grab = useRef(0);
  const toRight = useRef(true);
  const settle = useRef(0);

  const limit = (v: number) => clampTo(v, 20, CARD_W - 20);
  /** Tap (and the autoplay): the bar glides to `target`, leaning into the move, then swings upright. */
  const glide = (target: number) => {
    settle.current += 1;
    const token = settle.current;
    const direction = target > x.get() ? 1 : -1;
    animate(x, limit(target), spring(0.7, 0.85));
    animate(lean, 0.2 * direction, anim.easeOut(0.18));
    window.setTimeout(() => {
      if (token !== settle.current) return;
      animate(lean, 0, spring(0.5, 0.4));
    }, 300);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      glide(toRight.current ? 186 : 78);
      toRight.current = !toRight.current;
    },
    { every: 2.3, delay: 0.4 },
  );
  const touch = useShaderTouch({
    onBegan: (p) => {
      settle.current += 1;
      grab.current = x.get() - p.x;
      if (Math.abs(grab.current) > 60) grab.current = 0;
      haptics.tap("soft");
    },
    onMoved: (p, velocity) => {
      animate(x, limit(p.x + grab.current), spring(0.2, 0.82));
      animate(lean, clampTo(velocity.x * 0.0005, -0.25, 0.25), spring(0.2, 0.82));
    },
    onEnded: () => animate(lean, 0, spring(0.5, 0.4)),
    onTap: (p) => {
      haptics.tap("soft");
      glide(p.x);
    },
  });

  return (
    <CenterStack ctx={ctx} en="Drag the prism across the type" zh="拖动棱镜划过文字">
      <ShaderCard glow={hex(0x7a5cff, 0.3)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Prism}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawType(g));
            return {
              p_center: [x.get(), CARD_H / 2],
              p_angle: (ctx.n("angle") * Math.PI) / 180 + lean.get(),
              p_width: ctx.n("width"),
              p_bend: ctx.n("bend"),
              p_dispersion: ctx.n("dispersion"),
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
