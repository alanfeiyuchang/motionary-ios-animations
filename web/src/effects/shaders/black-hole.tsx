/** shader.black-hole · 黑洞引力透镜 (Shaders+BlackHole.swift, mlBlackHole) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { hex, spring, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn, useSpeedClock } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clampTo, useScene, useShaderTouch } from "./_card";
import { drawSpace } from "./_scenes";

const HOME = { x: 130, y: 150 };
const clampPoint = (p: Point): Point => ({ x: clampTo(p.x, 10, CARD_W - 10), y: clampTo(p.y, 10, CARD_H - 10) });

export default function BlackHole({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const clock = useSpeedClock();
  const cx = useMotionValue(HOME.x);
  const cy = useMotionValue(HOME.y);
  const mass = useMotionValue(1);
  const grab = useRef({ x: 0, y: 0 });
  const holding = useRef(false);
  const visit = useRef(0);

  const moveTo = (p: Point, m: number | null, t: ReturnType<typeof spring>) => {
    animate(cx, p.x, t);
    animate(cy, p.y, t);
    if (m !== null) animate(mass, m, t);
  };
  /** Tap (and the autoplay): the hole swells, flies to the point, then falls back home. */
  const travel = (p: Point) => {
    if (holding.current) return;
    visit.current += 1;
    const token = visit.current;
    moveTo(clampPoint(p), 1.25, spring(0.6, 0.7));
    window.setTimeout(() => {
      if (token !== visit.current || holding.current) return;
      moveTo(HOME, 1, spring(0.7, 0.55));
    }, 1100);
  };
  useAutoplay(ctx.isPreview, () => travel({ x: randIn(50, 210), y: randIn(60, 240) }), { every: 2.6, delay: 0.3 });

  const touch = useShaderTouch({
    onBegan: (p) => {
      holding.current = true;
      grab.current = { x: cx.get() - p.x, y: cy.get() - p.y };
      // Grabbing from far away pulls the hole to the finger instead of keeping a long offset.
      if (Math.hypot(grab.current.x, grab.current.y) > 70) grab.current = { x: 0, y: 0 };
      haptics.tap("soft");
      animate(mass, 1.25, spring(0.35, 0.6));
    },
    onMoved: (p) => moveTo(clampPoint({ x: p.x + grab.current.x, y: p.y + grab.current.y }), null, spring(0.25, 0.8)),
    onEnded: () => {
      holding.current = false;
      visit.current += 1;
      moveTo(HOME, 1, spring(0.7, 0.55));
    },
    onTap: (p) => {
      haptics.tap("soft");
      travel(p);
    },
  });

  return (
    <CenterStack ctx={ctx} en="Drag the black hole, or tap to send it" zh="拖动黑洞，或点击让它飞过去">
      <ShaderCard glow={hex(0xff8a3d, 0.25)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.BlackHole}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g, k) => drawSpace(g, k));
            const time = clock.advance(nowSec(), 1);
            // A slow idle drift, so the lensing is alive even when nobody touches it.
            return {
              p_center: [cx.get() + 5 * Math.sin(time * 0.7), cy.get() + 4 * Math.cos(time * 0.9)],
              p_radius: ctx.n("radius") * mass.get(),
              p_bend: ctx.n("bend"),
              p_glow: ctx.n("glow"),
              p_time: time,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
