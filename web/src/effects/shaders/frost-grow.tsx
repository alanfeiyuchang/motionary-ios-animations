/** shader.frost-grow · 冰霜蔓延 (Shaders+Frost.swift, mlFrost) */
import { useRef } from "react";
import { hex, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader, type Uniform } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, useScene, useShaderTouch } from "./_card";
import { drawWindow } from "./_scenes";

const CAPACITY = 10;
const RADIUS = 34;

/** `FrostModel`: constant-speed growth toward the chosen coverage and up to ten melt points that fade back. */
class FrostModel {
  clock = clockFrom(0);
  private grow = 0;
  private points: { position: Point; time: number }[] = [];
  private anchor: Point = { x: 0, y: 0 };
  /** A scripted wipe (autoplay): the simulated finger travels `from` → `to` through `add`. */
  private wipe: { start: number; from: Point; to: Point } | null = null;

  add(p: Point, now: number) {
    // The newest point is the moving head under the finger. Once it has travelled 20 pt from where it was
    // dropped it stays behind as part of the trail and a new head starts, so a stroke spends one slot per
    // 20 pt and holding still keeps reheating the same spot.
    const last = this.points[this.points.length - 1];
    if (last && now - last.time < 0.3 && Math.hypot(this.anchor.x - p.x, this.anchor.y - p.y) < 20) {
      last.time = now;
      last.position = p;
      return;
    }
    this.anchor = p;
    this.points.push({ position: p, time: now });
    if (this.points.length > CAPACITY) this.points.splice(0, this.points.length - CAPACITY);
  }
  startWipe(from: Point, to: Point, now: number) {
    this.wipe = { start: now, from, to };
  }
  step(now: number, coverage: number, growTime: number, refreeze: number) {
    const time = this.clock.advance(now, 1);
    // Constant-speed growth toward the chosen coverage (also retreats when the slider is lowered).
    const rate = (this.clock.delta / Math.max(growTime, 0.1)) * Math.max(coverage, 0.3);
    if (this.grow < coverage) this.grow = Math.min(coverage, this.grow + rate);
    else this.grow = Math.max(coverage, this.grow - rate * 2);
    const script = this.wipe;
    if (script) {
      const t = (now - script.start) / 1.1;
      if (t >= 1) {
        this.wipe = null;
      } else if (t >= 0) {
        const e = t * t * (3 - 2 * t);
        const arc = Math.sin(e * Math.PI) * 14;
        this.add({ x: script.from.x + (script.to.x - script.from.x) * e, y: script.from.y + (script.to.y - script.from.y) * e - arc }, now);
      }
    }
    this.points = this.points.filter((p) => now - p.time <= refreeze);
    const packed: [number, number, number][] = this.points.map((p) => [p.position.x, p.position.y, Math.max(0, 1 - (now - p.time) / Math.max(refreeze, 0.1))]);
    while (packed.length < CAPACITY) packed.push([0, 0, 0]);
    return { time, grow: this.grow, points: packed };
  }
}

export default function FrostGrow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const model = useRef(new FrostModel()).current;
  const flip = useRef(false);

  // Waits for the frost to grow in before the first simulated wipe. The detail stage's arrival play is the
  // growth itself (it starts in the first frame), so there is no intro wipe on barely frosted glass.
  useAutoplay(
    ctx.isPreview,
    () => {
      // Simulated finger: an arcing stroke across the pane, alternating direction.
      const now = nowSec();
      if (flip.current) model.startWipe({ x: 236, y: 70 }, { x: 30, y: 44 }, now);
      else model.startWipe({ x: 26, y: 236 }, { x: 232, y: 270 }, now);
      flip.current = !flip.current;
    },
    { every: 3.6, delay: 2.4, intro: false },
  );
  const touch = useShaderTouch({
    onBegan: () => haptics.tap("soft"),
    onMoved: (p) => model.add(p, nowSec()),
    onTap: (p) => {
      haptics.tap("soft");
      model.add(p, nowSec());
    },
  });

  return (
    <CenterStack ctx={ctx} en="Wipe the glass with a finger" zh="用手指擦拭玻璃">
      <ShaderCard glow={hex(0x3ac4ff, 0.28)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Frost}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g, k) => drawWindow(g, k));
            const s = model.step(nowSec(), ctx.n("coverage"), ctx.n("growTime"), ctx.n("refreeze"));
            const out: Record<string, Uniform> = { p_grow: s.grow, p_refraction: ctx.n("refraction"), p_time: s.time, p_meltRadius: RADIUS };
            s.points.forEach((m, i) => (out[`p_m${i}`] = m));
            return out;
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
