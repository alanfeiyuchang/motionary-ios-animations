/** shader.sketch-edges · 铅笔速写 (Shaders+Sketch.swift, mlSketch) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { anim, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, color4, tapPoint, useScene } from "./_card";
import { drawCottage } from "./_scenes";

/** Paper and pencil per choice: cream, blueprint, chalkboard. */
const INKS = [
  [0xf5eedd, 0x34353f],
  [0x1d4e9e, 0xeaf3ff],
  [0x23362e, 0xf3f1e4],
];

export default function SketchEdges({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const clock = useRef(clockFrom(1)).current;
  // Live demos start as the photo (the far end of a sketch → photo run), so the first play draws the sketch.
  const progress = useMotionValue(1);
  const toSketch = useRef(false);
  const origin = useRef<Point>({ x: 40, y: 60 });
  const busy = useRef(false);

  const redraw = (p: Point) => {
    if (busy.current) return;
    busy.current = true;
    haptics.tap("soft");
    // Same picture, expressed from the other end: fully "there" in the old direction is 0 in the new one.
    toSketch.current = !toSketch.current;
    origin.current = p;
    progress.set(0);
    // Linear: the front crosses the picture at a steady pace and each pixel stages itself behind it.
    animate(progress, 1, { ...anim.linear(ctx.n("duration")), onComplete: () => (busy.current = false) });
  };
  useAutoplay(ctx.isPreview, () => redraw({ x: randIn(40, 220), y: randIn(60, 240) }), { every: ctx.n("duration") + 1.3, delay: 0.5 });
  const inks = INKS[Math.min(Math.max(ctx.i("paper"), 0), 2)];

  return (
    <CenterStack ctx={ctx} en="Tap to redraw · tap again for colour" zh="点击重画 · 再点恢复色彩">
      <ShaderCard onClick={tapPoint(redraw)}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Sketch}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawCottage(g));
            return {
              p_time: clock.advance(nowSec(), 1),
              p_weight: ctx.n("weight"),
              p_hatch: ctx.n("hatch"),
              p_boil: 0.9,
              p_paper: color4(inks[0]),
              p_pencil: color4(inks[1]),
              p_origin: [origin.current.x, origin.current.y],
              p_progress: progress.get(),
              p_toSketch: toSketch.current ? 1 : 0,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
