/** shader.fire · 火焰 (Shaders+Fire.swift, mlFire) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { StageHint, clockFrom, color4, useShaderTouch } from "./_card";

const FUELS = [
  [0x8c0d00, 0xff5a0a, 0xffd23f],
  [0x0a1e8c, 0x1e7bff, 0x9ae8ff],
  [0x064d2a, 0x1fbf5a, 0xd6ff7a],
];

/** `FireModel`: a torch that follows the finger, wind from the hand's travel and a flare per tap. */
class FireModel {
  private clock = clockFrom(30);
  private touch: Point = { x: 170, y: 190 };
  private last: { point: Point; time: number } | null = null;
  private held = false;
  private press = 0;
  private wind = 0;
  private gust = 0;
  private flareStart = -100;
  private everTouched = false;

  hold(p: Point, now: number, scripted = false) {
    if (!scripted) this.everTouched = true;
    if (this.last && now > this.last.time) {
      // The flame lags behind the hand: wind blows against the direction of travel.
      const vx = (p.x - this.last.point.x) / Math.max(now - this.last.time, 1 / 120);
      this.gust = Math.min(Math.max(-vx / 500, -1), 1);
    }
    this.last = { point: p, time: now };
    this.touch = p;
    this.held = true;
  }
  release() {
    this.held = false;
    this.last = null;
  }
  flare(now: number) {
    this.flareStart = now;
  }
  step(now: number, speed: number, w: number, h: number, auto: boolean) {
    const time = this.clock.advance(now, speed);
    if (auto && !this.everTouched) {
      // Simulated finger: carries the torch across for 3.2 s of every 5 s, then lets go.
      const cycle = now % 5;
      if (cycle < 3.2) {
        const t = cycle / 3.2;
        this.hold({ x: w * (0.5 - 0.3 * Math.cos(t * 2 * Math.PI)), y: h * (0.5 + 0.1 * Math.sin(t * 4 * Math.PI)) }, now, true);
      } else if (this.held) {
        this.release();
      }
    }
    this.press += ((this.held ? 1 : 0) - this.press) * (this.held ? this.clock.follow(12) : this.clock.follow(5));
    this.gust *= Math.exp(-this.clock.delta * 5);
    this.wind += (this.gust - this.wind) * this.clock.follow(8);
    const age = now - this.flareStart;
    return { time, touch: this.touch, press: this.press, wind: this.wind, flare: age < 2 ? age : -1 };
  }
}

export default function Fire({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const W = 340;
  const H = ctx.isPreview ? 340 : 400;
  const model = useRef(new FireModel()).current;

  useAutoplay(ctx.isPreview, () => model.flare(nowSec()), { every: 3.7, delay: 1.2 });
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.hold(p, nowSec());
    },
    onMoved: (p) => model.hold(p, nowSec()),
    onEnded: () => model.release(),
    onTap: () => {
      haptics.tap("rigid");
      model.flare(nowSec());
    },
  });
  const colors = FUELS[Math.min(Math.max(ctx.i("palette"), 0), 2)];

  return (
    <div {...touch} style={{ position: "absolute", inset: 0, ...touch.style }}>
      <Shader
        width={W}
        height={H}
        fragment={FRAG.Fire}
        fps={ctx.isPreview ? 30 : undefined}
        scale={2}
        uniforms={() => {
          const s = model.step(nowSec(), ctx.n("speed"), W, H, ctx.isPreview);
          return {
            p_time: s.time,
            p_height: ctx.n("height"),
            p_turbulence: ctx.n("turbulence"),
            p_c0: color4(colors[0]),
            p_c1: color4(colors[1]),
            p_c2: color4(colors[2]),
            p_touch: [s.touch.x, s.touch.y],
            p_press: s.press,
            p_wind: s.wind,
            p_flare: s.flare,
          };
        }}
      />
      <StageHint ctx={ctx} en="Hold and move a torch · tap to flare" zh="按住移动火把 · 点击蹿火" />
    </div>
  );
}
