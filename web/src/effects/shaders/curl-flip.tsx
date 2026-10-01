/** shader.curl-flip · 卷页翻页 (Shaders+CurlFlip.swift, mlPageCurl) */
import { animate, useMotionValue } from "motion/react";
import { useEffect, useRef } from "react";
import { anim, clamp, spring, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { LayerView } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, color4, useScene, useShaderTouch } from "./_card";
import { drawPage } from "./_scenes";

export default function CurlFlip({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const top = useScene();
  const bottom = useScene();
  const current = useRef(0);
  const progress = useMotionValue(0);
  const lean = useMotionValue(0);
  const start = useRef({ point: { x: 0, y: 0 }, progress: 0 });
  const lastVelocity = useRef<Point>({ x: 0, y: 0 });
  const dragging = useRef(false);
  const token = useRef(0);
  const finishing = useRef(false);
  const sim = useRef(0);
  useEffect(() => () => cancelAnimationFrame(sim.current), []);

  const grab = (p: Point) => {
    token.current += 1;
    dragging.current = true;
    progress.stop();
    lean.stop();
    start.current = { point: p, progress: progress.get() };
    lastVelocity.current = { x: 0, y: 0 };
  };
  /** The finger's leftward travel is the peel; its vertical travel leans the fold line. */
  const peel = (p: Point) => {
    if (!dragging.current) return;
    progress.set(clamp(start.current.progress + (start.current.point.x - p.x) / (CARD_W * 0.9), 0, 1));
    lean.set(clamp((start.current.point.y - p.y) / 240, -0.25, 0.25));
  };
  const finish = (turn: boolean) => {
    if (turn) {
      finishing.current = true;
      const now = token.current;
      const remaining = 0.18 + 0.3 * (1 - progress.get());
      animate(lean, 0, anim.easeOut(remaining));
      animate(progress, 1, {
        ...anim.easeOut(remaining),
        onComplete: () => {
          finishing.current = false;
          if (now !== token.current) return;
          current.current += 1;
          progress.set(0);
          haptics.tap("light");
        },
      });
    } else {
      animate(progress, 0, spring(ctx.n("response"), 0.8));
      animate(lean, 0, spring(ctx.n("response"), 0.8));
    }
  };
  const settle = (velocityX: number) => {
    if (!dragging.current) return;
    dragging.current = false;
    finish(progress.get() > 0.45 || velocityX < -500);
  };
  /** Simulated finger: grabs the right edge, drags 62% of the way across with a slight lift, lets go. */
  const simulateDrag = () => {
    if (dragging.current || finishing.current || progress.get() >= 0.001) return;
    grab({ x: 236, y: 250 });
    const now = token.current;
    const began = performance.now();
    const frame = () => {
      if (now !== token.current) return;
      // 42 frames, 16 ms apart.
      const t = Math.min((performance.now() - began) / (42 * 16), 1);
      const e = t * t * (3 - 2 * t);
      lastVelocity.current = { x: -260, y: 0 };
      peel({ x: 236 - 145 * e, y: 250 - 34 * e });
      if (t < 1) sim.current = requestAnimationFrame(frame);
      else settle(lastVelocity.current.x);
    };
    sim.current = requestAnimationFrame(frame);
  };
  useAutoplay(ctx.isPreview, simulateDrag, { every: 2.6, delay: 0.5 });

  const touch = useShaderTouch({
    onBegan: (p) => {
      if (finishing.current) return;
      haptics.tap("soft");
      grab(p);
    },
    onMoved: (p, velocity) => {
      lastVelocity.current = velocity;
      peel(p);
    },
    onEnded: () => settle(lastVelocity.current.x),
    onTap: () => {
      if (finishing.current || dragging.current) return;
      token.current += 1;
      finish(true);
    },
  });

  return (
    <CenterStack ctx={ctx} en="Drag left to peel the page" zh="向左拖动揭开书页">
      <ShaderCard {...touch}>
        <LayerView layer={bottom.layer} width={CARD_W} height={CARD_H} style={{ position: "absolute", inset: 0 }} />
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.PageCurl}
          source={top.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current;
            top.ensure(c, (g) => drawPage(g, c));
            bottom.ensure(c + 1, (g) => drawPage(g, c + 1));
            const p = clamp(progress.get(), 0, 1);
            const radius = ctx.n("radius");
            // The fold line pivots on the bottom edge: it starts just outside the bottom-right corner, tilted,
            // and ends upright just past the left edge, where the whole page has been lifted away.
            const tilt = ((ctx.n("angle") * Math.PI) / 180 + lean.get()) * Math.pow(1 - p, 0.8);
            const foldX = CARD_W + 1 - p * (CARD_W + radius + 4);
            return {
              p_bypass: p > 0.0005 ? 0 : 1,
              p_fold: [foldX, CARD_H],
              p_dir: [Math.cos(tilt), Math.sin(tilt)],
              p_radius: radius,
              p_shadow: ctx.n("shadow") * Math.min(p * 8, 1),
              p_paper: color4(0xf4eedf),
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
