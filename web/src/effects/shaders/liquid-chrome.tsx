/** shader.liquid-chrome · 液态金属 (Shaders+LiquidChrome.swift, mlLiquidChrome) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, randIn } from "./_shared";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { StageHint, clockFrom, color4, useShaderTouch } from "./_card";

/** `ChromeModel`: a dent that eases toward the finger and one ring per tap. */
class ChromeModel {
  clock = clockFrom(40);
  finger: Point | null = null;
  private touch: Point = { x: 170, y: 170 };
  private press = 0;
  private ripple: Point = { x: 170, y: 170 };
  private rippleStart = -100;

  drop(p: Point, now: number) {
    this.ripple = p;
    this.rippleStart = now;
  }
  step(now: number, speed: number, w: number, h: number, auto: boolean) {
    const time = this.clock.advance(now, speed);
    let target: Point | null = null;
    if (this.finger) {
      target = this.finger;
    } else if (auto) {
      // Simulated finger: a slow orbit that keeps a dent travelling through the metal.
      target = { x: w / 2 + w * 0.26 * Math.cos(now * 0.6), y: h / 2 + h * 0.22 * Math.sin(now * 0.85) };
    }
    if (target) {
      const k = this.clock.follow(12);
      this.touch.x += (target.x - this.touch.x) * k;
      this.touch.y += (target.y - this.touch.y) * k;
      this.press += ((auto && !this.finger ? 0.7 : 1) - this.press) * this.clock.follow(11);
    } else {
      this.press += (0 - this.press) * this.clock.follow(6);
    }
    const age = now - this.rippleStart;
    return { time, touch: this.touch, press: this.press, ripple: this.ripple, rippleAge: age < 3 ? age : -1 };
  }
}

export default function LiquidChrome({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const W = 340;
  const H = ctx.isPreview ? 340 : 400;
  const model = useRef(new ChromeModel()).current;
  const last = useRef<Point>({ x: 170, y: 170 });

  const drop = (p: Point) => model.drop(p, nowSec());
  useAutoplay(ctx.isPreview, () => drop({ x: randIn(0.25, 0.75) * W, y: randIn(0.25, 0.75) * H }), { every: 3.2, delay: 0.8 });
  const touch = useShaderTouch({
    onBegan: (p) => {
      last.current = p;
      haptics.tap("soft");
    },
    onMoved: (p) => {
      last.current = p;
      model.finger = p;
    },
    onEnded: () => {
      model.finger = null;
      drop(last.current);
    },
    onTap: (p) => {
      haptics.tap("soft");
      drop(p);
    },
  });
  const finish = ctx.i("finish");

  return (
    <div {...touch} style={{ position: "absolute", inset: 0, ...touch.style }}>
      <Shader
        width={W}
        height={H}
        fragment={FRAG.LiquidChrome}
        fps={ctx.isPreview ? 30 : undefined}
        scale={2}
        uniforms={() => {
          const s = model.step(nowSec(), ctx.n("speed"), W, H, ctx.isPreview);
          return {
            p_time: s.time,
            p_scale: ctx.n("scale"),
            p_relief: ctx.n("relief"),
            p_tint: color4(finish === 1 ? 0xffc861 : 0xf4f7ff),
            p_iridescence: finish === 2 ? 0.75 : 0,
            p_touch: [s.touch.x, s.touch.y],
            p_press: s.press,
            p_ripple: [s.ripple.x, s.ripple.y],
            p_rippleAge: s.rippleAge,
          };
        }}
      />
      <StageHint ctx={ctx} en="Press and drag the metal, let go for a ripple" zh="按住拖动金属，松手荡开波纹" />
    </div>
  );
}
