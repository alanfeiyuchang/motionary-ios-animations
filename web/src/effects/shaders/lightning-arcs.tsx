/** shader.lightning-arcs · 等离子电弧球 (Shaders+LightningArcs.swift, mlPlasmaGlobe) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { StageHint, clockFrom, color4, useShaderTouch } from "./_card";

const GASES = [0xa24bff, 0x2bd9fe, 0xff9a2e];

/** `LightningModel`: arcs are pulled to a held finger and a tap adds one fat bolt. */
class LightningModel {
  private clock = clockFrom(40);
  private touch: Point = { x: 240, y: 120 };
  private held = false;
  private pull = 0;
  private strikeStart = -100;
  private everTouched = false;

  hold(p: Point, scripted = false) {
    if (!scripted) this.everTouched = true;
    this.touch = p;
    this.held = true;
  }
  release() {
    this.held = false;
  }
  strike(p: Point, now: number) {
    if (!this.held) this.touch = p;
    this.strikeStart = now;
  }
  step(now: number, speed: number, w: number, h: number, auto: boolean) {
    const time = this.clock.advance(now, speed);
    if (auto && !this.everTouched) {
      // Simulated finger: rests on the glass and slides round it for 2.6 s of every 4.6 s.
      const cycle = now % 4.6;
      if (cycle < 2.6) {
        const a = now * 0.9;
        const r = Math.min(w, h) * 0.36;
        this.hold({ x: w * 0.5 + Math.cos(a) * r, y: h * 0.41 + Math.sin(a) * r }, true);
      } else if (this.held) {
        this.release();
      }
    }
    this.pull += ((this.held ? 1 : 0) - this.pull) * (this.held ? this.clock.follow(14) : this.clock.follow(5));
    const age = now - this.strikeStart;
    return { time, touch: this.touch, pull: this.pull, strike: age < 1 ? age : -1 };
  }
}

export default function LightningArcs({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const W = 340;
  const H = ctx.isPreview ? 340 : 400;
  const model = useRef(new LightningModel()).current;

  useAutoplay(
    ctx.isPreview,
    () => {
      const angle = Math.random() * 2 * Math.PI;
      const r = Math.min(W, H) * 0.36;
      model.strike({ x: W * 0.5 + Math.cos(angle) * r, y: H * 0.41 + Math.sin(angle) * r }, nowSec());
    },
    { every: 2.3, delay: 1.0 },
  );
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.hold(p);
    },
    onMoved: (p) => model.hold(p),
    onEnded: () => model.release(),
    onTap: (p) => {
      haptics.tap("rigid");
      model.strike(p, nowSec());
    },
  });
  const glow = GASES[Math.min(Math.max(ctx.i("color"), 0), 2)];

  return (
    <div {...touch} style={{ position: "absolute", inset: 0, ...touch.style }}>
      <Shader
        width={W}
        height={H}
        fragment={FRAG.PlasmaGlobe}
        fps={ctx.isPreview ? 30 : undefined}
        scale={2}
        uniforms={() => {
          const s = model.step(nowSec(), ctx.n("speed"), W, H, ctx.isPreview);
          return {
            p_time: s.time,
            p_arcs: Math.round(ctx.n("arcs")),
            p_jag: ctx.n("jag"),
            p_glow: color4(glow),
            p_touch: [s.touch.x, s.touch.y],
            p_pull: s.pull,
            p_strike: s.strike,
          };
        }}
      />
      <StageHint ctx={ctx} en="Touch the glass · tap to strike" zh="触摸玻璃球 · 点击放电" />
    </div>
  );
}
