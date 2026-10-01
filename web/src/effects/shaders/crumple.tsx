/** shader.crumple · 揉皱纸张 (Shaders+Crumple.swift, mlCrumple) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { anim, clamp, delayed, spring, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, useScene, useShaderTouch } from "./_card";
import { drawFlyer } from "./_scenes";

export default function Crumple({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const amount = useMotionValue(0);
  const crease = useMotionValue(0);
  const centre = useRef<Point>({ x: 150, y: 170 });
  const seed = useRef(4.2);
  const pressing = useRef(false);
  const token = useRef(0);
  const sheet = useRef<HTMLDivElement>(null);

  const crush = (p: Point) => {
    token.current += 1;
    // Keep the fold pattern while old creases are still visible, so they never jump.
    if (crease.get() < 0.02) seed.current = randIn(0, 40);
    centre.current = p;
    animate(amount, 1, spring(0.5, 0.7));
    animate(crease, 1, spring(0.5, 0.7));
  };
  const unfold = () => {
    token.current += 1;
    haptics.tap("light");
    animate(amount, 0, spring(0.6, ctx.n("damping")));
    animate(crease, 0, delayed(anim.easeOut(2.4), 0.4));
  };
  /** A quick tap (and the autoplay): crush, hold for a moment, let go. */
  const squeeze = (p: Point) => {
    crush(p);
    const current = token.current;
    window.setTimeout(() => {
      if (current !== token.current || pressing.current) return;
      unfold();
    }, 1100);
  };
  useAutoplay(ctx.isPreview, () => squeeze({ x: randIn(70, 190), y: randIn(90, 210) }), { every: 4.2, delay: 0.4 });
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("rigid");
      pressing.current = true;
      crush(p);
    },
    onMoved: () => {},
    onEnded: () => {
      pressing.current = false;
      unfold();
    },
    onTap: squeeze,
  });

  return (
    <CenterStack ctx={ctx} en="Press and hold to crumple" zh="按住揉皱">
      <div ref={sheet} {...touch} style={{ width: CARD_W, height: CARD_H, flexShrink: 0, cursor: "pointer", ...touch.style }}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Crumple}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawFlyer(g));
            const a = amount.get();
            const c = crease.get();
            const flat = clamp(a, 0, 1);
            if (sheet.current) sheet.current.style.filter = `drop-shadow(0 10px ${16 - 6 * flat}px rgb(0 0 0 / ${0.22 + 0.12 * flat}))`;
            return {
              p_bypass: Math.abs(a) > 0.0005 || c > 0.0005 ? 0 : 1,
              p_centre: [centre.current.x, centre.current.y],
              p_amount: a,
              p_crease: c,
              p_cell: ctx.n("cell"),
              p_depth: ctx.n("depth"),
              p_shade: ctx.n("shade"),
              p_seed: seed.current,
            };
          }}
        />
      </div>
    </CenterStack>
  );
}
