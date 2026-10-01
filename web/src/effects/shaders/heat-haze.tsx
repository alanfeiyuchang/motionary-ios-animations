/** shader.heat-haze · 热浪蒸腾 (Shaders+HeatHaze.swift, mlHeatHaze) */
import { useRef } from "react";
import { hex, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, useScene, useShaderTouch } from "./_card";
import { drawDesert } from "./_scenes";

/** `HeatModel`: eases the plume's position and gain toward the finger (or a simulated one in previews). */
class HeatModel {
  clock = clockFrom(0);
  touch: Point | null = null;
  pokeUntil = 0;
  private source: Point = { x: 130, y: 236 };
  private gain = 0;

  step(now: number, speed: number, auto: boolean) {
    const time = this.clock.advance(now, speed);
    let target: Point | null = null;
    if (this.touch && (now < this.pokeUntil || this.pokeUntil === 0)) {
      target = this.touch;
    } else if (auto) {
      // Simulated finger: a slow sweep along the road.
      target = { x: 130 + 78 * Math.sin(now * 0.55), y: 232 + 22 * Math.sin(now * 0.9) };
    }
    if (target) {
      const k = this.clock.follow(9);
      this.source.x += (target.x - this.source.x) * k;
      this.source.y += (target.y - this.source.y) * k;
      this.gain += (1 - this.gain) * this.clock.follow(9);
    } else {
      this.gain += (0 - this.gain) * this.clock.follow(4);
    }
    return { time, source: this.source, gain: this.gain };
  }
  hold(p: Point) {
    this.touch = p;
    this.pokeUntil = 0;
  }
  poke(p: Point, now: number) {
    this.touch = p;
    this.pokeUntil = now + 0.9;
  }
  release() {
    this.touch = null;
    this.pokeUntil = 0;
  }
}

export default function HeatHaze({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const model = useRef(new HeatModel()).current;
  const touch = useShaderTouch({
    onBegan: () => haptics.tap("soft"),
    onMoved: (p) => model.hold(p),
    onEnded: () => model.release(),
    onTap: (p) => {
      haptics.tap("soft");
      model.poke(p, nowSec());
    },
  });
  return (
    <CenterStack ctx={ctx} en="Touch and drag to add heat" zh="按住拖动，添加热源">
      <ShaderCard glow={hex(0xff7a3d, 0.32)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.HeatHaze}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawDesert(g));
            const s = model.step(nowSec(), ctx.n("speed"), ctx.isPreview);
            return {
              p_time: s.time,
              p_strength: ctx.n("strength"),
              p_scale: ctx.n("scale"),
              p_falloff: ctx.n("falloff"),
              p_source: [s.source.x, s.source.y],
              p_sourceGain: s.gain,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
