/** shader.wind-smear · 风吹拖影 (Shaders+WindSmear.swift, mlWindSmear) */
import { useRef } from "react";
import { useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, useScene, useShaderTouch } from "./_card";
import { drawPaint } from "./_scenes";

/** `SmearModel`: follows the finger while it is down, then a damped 2D spring pulls the smear back to zero. */
class SmearModel {
  private clock = clockFrom(0);
  private smear: Point = { x: 0, y: 0 };
  private velocity: Point = { x: 0, y: 0 };
  private target: Point | null = null;
  private start: Point | null = null;
  /** A scripted gust (autoplay / intro): a simulated finger travels `vector` through `begin`/`drag`/`release`. */
  private gust: { start: number; vector: Point } | null = null;

  begin(p: Point) {
    // A real touch takes over from a scripted gust.
    this.gust = null;
    this.start = p;
    this.target = { ...this.smear };
  }
  drag(p: Point, limit: number) {
    if (!this.start) return;
    const v = { x: p.x - this.start.x, y: p.y - this.start.y };
    const length = Math.hypot(v.x, v.y);
    if (length > limit) {
      v.x *= limit / length;
      v.y *= limit / length;
    }
    this.target = v;
  }
  release() {
    this.target = null;
    this.start = null;
  }
  startGust(vector: Point, now: number) {
    this.begin({ x: 0, y: 0 });
    this.gust = { start: now, vector };
  }
  step(now: number, response: number, damping: number, limit: number): Point {
    this.clock.advance(now, 1);
    const dt = this.clock.delta;
    const script = this.gust;
    if (script) {
      const t = (now - script.start) / 0.5;
      if (t >= 1.25) {
        this.gust = null;
        this.release();
      } else {
        const e = Math.min(Math.max(t, 0), 1);
        const eased = e * e * (3 - 2 * e);
        this.drag({ x: script.vector.x * eased, y: script.vector.y * eased }, limit);
      }
    }
    if (!(dt > 0)) return this.smear;
    if (this.target) {
      const k = 1 - Math.exp(-dt * 20);
      const dx = (this.target.x - this.smear.x) * k;
      const dy = (this.target.y - this.smear.y) * k;
      this.smear.x += dx;
      this.smear.y += dy;
      this.velocity = { x: dx / dt, y: dy / dt };
    } else {
      const omega = (2 * Math.PI) / Math.max(response, 0.05);
      const steps = 4;
      const h = dt / steps;
      for (let i = 0; i < steps; i++) {
        const ax = -omega * omega * this.smear.x - 2 * damping * omega * this.velocity.x;
        const ay = -omega * omega * this.smear.y - 2 * damping * omega * this.velocity.y;
        this.velocity.x += ax * h;
        this.velocity.y += ay * h;
        this.smear.x += this.velocity.x * h;
        this.smear.y += this.velocity.y * h;
      }
    }
    return this.smear;
  }
}

export default function WindSmear({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const model = useRef(new SmearModel()).current;
  const turn = useRef(0);
  const limit = ctx.n("length");

  useAutoplay(
    ctx.isPreview,
    () => {
      // Simulated drag: gusts from a rotating set of directions.
      const angle = [-0.3, 2.6, 1.2, -2.2][turn.current % 4];
      turn.current += 1;
      model.startGust({ x: Math.cos(angle) * limit, y: Math.sin(angle) * limit }, nowSec());
    },
    { every: 2.1, delay: 0.4 },
  );
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.begin(p);
    },
    onMoved: (p) => model.drag(p, limit),
    onEnded: () => model.release(),
  });

  return (
    <CenterStack ctx={ctx} en="Drag in any direction, then let go" zh="朝任意方向拖动，再松手">
      <ShaderCard {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.WindSmear}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawPaint(g));
            const smear = model.step(nowSec(), ctx.n("response"), ctx.n("damping"), limit);
            return { p_smear: [smear.x, smear.y], p_streak: ctx.n("streak"), p_rag: 1, p_seed: 3.1 };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
