/** shader.nebula · 星云穿行 (Shaders+Nebula.swift, mlNebula) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { StageHint, clockFrom, color4, useShaderTouch } from "./_card";

const PALETTES = [
  [0xc42bb8, 0x1fb8c9, 0xffc46b],
  [0x2b6bff, 0x9b4dff, 0xff8ad8],
  [0xc2261c, 0xff7a1a, 0xffe08a],
];

/** `NebulaModel`: pan in view heights with inertia after release, plus one flare per tap. */
class NebulaModel {
  clock = clockFrom(60);
  private pan: Point = { x: 0, y: 0 };
  private velocity: Point = { x: 0, y: 0 };
  private lastTouch: Point | null = null;
  private flare: Point = { x: 170, y: 170 };
  private flareStart = -100;

  drag(p: Point, height: number) {
    if (this.lastTouch) {
      this.pan.x -= (p.x - this.lastTouch.x) / Math.max(height, 1);
      this.pan.y -= (p.y - this.lastTouch.y) / Math.max(height, 1);
    }
    this.lastTouch = p;
    this.velocity = { x: 0, y: 0 };
  }
  release(v: Point, height: number) {
    this.lastTouch = null;
    this.velocity = { x: -v.x / Math.max(height, 1), y: -v.y / Math.max(height, 1) };
  }
  ignite(p: Point, now: number) {
    this.flare = p;
    this.flareStart = now;
  }
  step(now: number, speed: number, auto: boolean) {
    const time = this.clock.advance(now, speed);
    if (!this.lastTouch) {
      this.pan.x += this.velocity.x * this.clock.delta;
      this.pan.y += this.velocity.y * this.clock.delta;
      const keep = Math.exp(-this.clock.delta * 3.5);
      this.velocity.x *= keep;
      this.velocity.y *= keep;
    }
    const shown = { ...this.pan };
    if (auto) {
      // Simulated drag: a slow figure-eight pan that shows the parallax between the layers.
      shown.x += 0.42 * Math.sin(now * 0.42);
      shown.y += 0.24 * Math.sin(now * 0.84);
    }
    const age = now - this.flareStart;
    return { time, pan: shown, flare: this.flare, flareAge: age < 3 ? age : -1 };
  }
}

export default function Nebula({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const W = 340;
  const H = ctx.isPreview ? 340 : 400;
  const model = useRef(new NebulaModel()).current;
  const lastVelocity = useRef<Point>({ x: 0, y: 0 });

  const ignite = (p: Point) => model.ignite(p, nowSec());
  useAutoplay(ctx.isPreview, () => ignite({ x: randIn(0.2, 0.8) * W, y: randIn(0.2, 0.8) * H }), { every: 3.4, delay: 0.9 });
  const touch = useShaderTouch({
    onBegan: (p) => model.drag(p, H),
    onMoved: (p, velocity) => {
      lastVelocity.current = velocity;
      model.drag(p, H);
    },
    onEnded: () => model.release(lastVelocity.current, H),
    onTap: (p) => {
      haptics.tap("soft");
      ignite(p);
    },
  });
  const colors = PALETTES[Math.min(Math.max(ctx.i("palette"), 0), 2)];

  return (
    <div {...touch} style={{ position: "absolute", inset: 0, cursor: "grab", ...touch.style }}>
      <Shader
        width={W}
        height={H}
        fragment={FRAG.Nebula}
        fps={ctx.isPreview ? 30 : undefined}
        scale={2}
        uniforms={() => {
          const s = model.step(nowSec(), ctx.n("speed"), ctx.isPreview);
          return {
            p_time: s.time,
            p_pan: [s.pan.x, s.pan.y],
            p_density: ctx.n("density"),
            p_stars: ctx.n("stars"),
            p_ca: color4(colors[0]),
            p_cb: color4(colors[1]),
            p_cc: color4(colors[2]),
            p_flare: [s.flare.x, s.flare.y],
            p_flareAge: s.flareAge,
          };
        }}
      />
      <StageHint ctx={ctx} en="Drag to fly through · tap to ignite a star" zh="拖动穿行 · 点击点燃一颗星" />
    </div>
  );
}
