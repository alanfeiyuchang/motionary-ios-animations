/** shader.touch-trail · 触摸凝胶轨迹 (Shaders+TouchTrail.swift, mlTouchTrail) */
import { useRef } from "react";
import { hex, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader, type Uniform } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, useScene, useShaderTouch } from "./_card";
import { drawFlow } from "./_scenes";

const CAPACITY = 12;
const SPACING = 22;
type Packed = [number, number, number, number];

/** Simulated finger paths: an S-curve, a loop and a diagonal swoop. */
function path(t: number, variant: number): Point {
  const e = t * t * (3 - 2 * t);
  switch (variant % 3) {
    case 1: {
      const a = e * 2 * Math.PI - 1.2;
      return { x: 130 + Math.cos(a) * 78, y: 160 + Math.sin(a) * 86 };
    }
    case 2:
      return { x: 226 - e * 190, y: 60 + e * 190 + Math.sin(e * Math.PI * 2) * 34 };
    default:
      return { x: 32 + e * 196, y: 150 + Math.sin(e * Math.PI * 2) * 92 };
  }
}

/** `TrailModel`: twelve points (x, y, life, linked), one slot per 22 pt of stroke. */
class TrailModel {
  private points: { position: Point; time: number; linked: boolean }[] = [];
  private anchor: Point = { x: 0, y: 0 };
  private fresh = true;
  /** A scripted stroke (autoplay / intro): the simulated finger goes through `add` like a real one. */
  private script: { start: number; variant: number } | null = null;

  lift() {
    this.fresh = true;
  }
  add(p: Point, now: number) {
    // The newest point is the head under the finger; once it is `spacing` away from where it was dropped
    // it stays behind and a new head starts, so a stroke spends one slot per 22 pt.
    const last = this.points[this.points.length - 1];
    if (!this.fresh && last && Math.hypot(this.anchor.x - p.x, this.anchor.y - p.y) < SPACING) {
      last.position = p;
      last.time = now;
      return;
    }
    this.anchor = !this.fresh && last ? last.position : p;
    this.points.push({ position: p, time: now, linked: !this.fresh });
    this.fresh = false;
    if (this.points.length > CAPACITY) this.points.splice(0, this.points.length - CAPACITY);
  }
  startStroke(variant: number, now: number) {
    this.lift();
    this.script = { start: now, variant };
  }
  step(now: number, heal: number): Packed[] {
    if (this.script) {
      const t = (now - this.script.start) / 1.5;
      if (t >= 1) {
        this.script = null;
        this.lift();
      } else if (t >= 0) {
        this.add(path(t, this.script.variant), now);
      }
    }
    this.points = this.points.filter((p) => now - p.time <= heal);
    // Besides ageing, the tail tapers over the last 70 pt of the length the twelve slots can hold, so a
    // fast stroke never loses its oldest point with a visible jump.
    const reach = SPACING * (CAPACITY - 2);
    let fromHead = 0;
    const entries: Packed[] = [];
    for (let index = this.points.length - 1; index >= 0; index--) {
      const point = this.points[index];
      if (index < this.points.length - 1) {
        const next = this.points[index + 1];
        fromHead += next.linked ? Math.hypot(next.position.x - point.position.x, next.position.y - point.position.y) : SPACING;
      }
      const age = Math.max(0, 1 - (now - point.time) / Math.max(heal, 0.1));
      const taper = Math.min(Math.max((reach - fromHead) / 70, 0), 1);
      entries.push([point.position.x, point.position.y, age * taper, point.linked ? 1 : 0]);
    }
    entries.reverse();
    if (entries.length) entries[0][3] = 0;
    const padding: Packed[] = Array.from({ length: CAPACITY - entries.length }, () => [0, 0, 0, 0]);
    return [...padding, ...entries];
  }
}

export default function TouchTrail({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const model = useRef(new TrailModel()).current;
  const turn = useRef(0);

  useAutoplay(
    ctx.isPreview,
    () => {
      model.startStroke(turn.current, nowSec());
      turn.current += 1;
    },
    { every: 2.3, delay: 0.3 },
  );
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.lift();
      model.add(p, nowSec());
    },
    onMoved: (p) => model.add(p, nowSec()),
    onEnded: () => model.lift(),
    onTap: (p) => {
      model.lift();
      model.add(p, nowSec());
      model.lift();
    },
  });

  return (
    <CenterStack ctx={ctx} en="Draw on the poster with a finger" zh="用手指在海报上划动">
      <ShaderCard glow={hex(0x5b2ad0, 0.32)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.TouchTrail}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawFlow(g));
            const out: Record<string, Uniform> = { p_radius: ctx.n("width"), p_strength: ctx.n("strength"), p_fringe: ctx.n("fringe"), p_gloss: 0.85 };
            model.step(nowSec(), ctx.n("heal")).forEach((p, i) => (out[`p_p${i}`] = p));
            return out;
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
