/** shader.glass-blocks · 玻璃砖墙 (Shaders+GlassBlocks.swift, mlGlassBlocks) */
import { useRef } from "react";
import { hex, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, rgba, useLayer } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clampTo, clockFrom, useShaderTouch } from "./_card";
import { linear } from "./_scenes";

const clamped = (p: Point): Point => ({ x: clampTo(p.x, 20, CARD_W - 20), y: clampTo(p.y, 20, CARD_H - 20) });

/** `GlassSubjectModel`: the lights behind the wall chase a target with a soft lag; a release throws the target on. */
class GlassSubjectModel {
  private clock = clockFrom(0);
  private position: Point = { x: 130, y: 150 };
  private target: Point = { x: 130, y: 150 };
  private offset: Point = { x: 0, y: 0 };
  /** Until a finger takes over, a simulated one wanders (previews, and the detail stage on arrival). */
  private everTouched = false;

  grab(p: Point) {
    this.everTouched = true;
    this.offset = { x: this.target.x - p.x, y: this.target.y - p.y };
  }
  drag(p: Point) {
    this.target = clamped({ x: p.x + this.offset.x, y: p.y + this.offset.y });
  }
  release(v: Point) {
    this.target = clamped({ x: this.target.x + v.x * 0.22, y: this.target.y + v.y * 0.22 });
  }
  step(now: number) {
    const time = this.clock.advance(now, 1);
    if (!this.everTouched) {
      // Simulated drag on a slow figure-eight, through the same `drag(to:)` as the finger.
      this.drag({ x: 130 + 78 * Math.sin(time * 0.8), y: 150 + 84 * Math.sin(time * 0.53 + 1) });
    }
    const k = this.clock.follow(6);
    this.position.x += (this.target.x - this.position.x) * k;
    this.position.y += (this.target.y - this.position.y) * k;
    return { subject: this.position, time };
  }
}

/** `GlassBackdrop`: a dusk-coloured room with stripes and a cluster of lights that can be moved. */
function drawBackdrop(g: CanvasRenderingContext2D, s: Point, time: number) {
  const W = CARD_W;
  const H = CARD_H;
  g.fillStyle = linear(g, [0x0e2a47, 0x1f6f8b, 0xf2a65a, 0xe4572e], 0, 0, W * 0.3, H);
  g.fillRect(0, 0, W, H);
  g.strokeStyle = "rgba(255,255,255,0.12)";
  g.lineWidth = 7;
  g.beginPath();
  for (let x = -H; x < W; x += 34) {
    g.moveTo(x, H);
    g.lineTo(x + H * 0.6, 0);
  }
  g.stroke();
  g.fillStyle = rgba(0x0b1b2e, 0.75);
  g.fillRect(0, H * 0.78, W, H * 0.22);
  // The movable cluster: a big sun, a moon in orbit and a ring.
  const circle = (x: number, y: number, r: number) => {
    g.beginPath();
    g.arc(x, y, r, 0, Math.PI * 2);
  };
  g.fillStyle = rgba(0xffe9a8, 0.3);
  circle(s.x, s.y, 58);
  g.fill();
  g.fillStyle = linear(g, [0xfff6c8, 0xffb03a], s.x, s.y - 40, s.x, s.y + 40);
  circle(s.x, s.y, 40);
  g.fill();
  g.fillStyle = rgba(0xff3d8b);
  circle(s.x + Math.cos(time * 1.1) * 70, s.y + Math.sin(time * 1.1) * 46, 13);
  g.fill();
  g.strokeStyle = rgba(0x7ff0ff, 0.85);
  g.lineWidth = 4;
  circle(s.x, s.y, 78);
  g.stroke();
}

export default function GlassBlocks({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const layer = useLayer(CARD_W, CARD_H);
  const model = useRef(new GlassSubjectModel()).current;
  const lastVelocity = useRef<Point>({ x: 0, y: 0 });
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.grab(p);
    },
    onMoved: (p, velocity) => {
      lastVelocity.current = velocity;
      model.drag(p);
    },
    onEnded: () => model.release(lastVelocity.current),
  });

  return (
    <CenterStack ctx={ctx} en="Drag the lights behind the wall" zh="拖动墙后的灯光">
      <ShaderCard glow={hex(0x1f6f8b, 0.3)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.GlassBlocks}
          source={layer.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            const s = model.step(nowSec());
            layer.paint((g) => drawBackdrop(g, s.subject, s.time));
            return { p_block: ctx.n("block"), p_refraction: ctx.n("refraction"), p_relief: ctx.n("relief"), p_frost: ctx.n("frost") };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
