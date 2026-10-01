/** shader.night-vision · 夜视仪 (Shaders+NightVision.swift, mlNightVision) */
import { useRef } from "react";
import { fonts, hex, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { LayerView, nowSec, rgba, useLayer } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clampTo, clockFrom, useScene, useShaderTouch } from "./_card";
import { drawForest, text } from "./_scenes";

/** Where the simulated operator looks: deer, owl, tent, moon, undergrowth. */
const SWEEP: Point[] = [
  { x: 176, y: 204 },
  { x: 168, y: 82 },
  { x: 64, y: 232 },
  { x: 198, y: 50 },
  { x: 120, y: 262 },
];

class NightVisionModel {
  private clock = clockFrom(2);
  private beam: Point = { x: 150, y: 200 };
  private target: Point = { x: 150, y: 200 };
  private flashStart = -100;

  aim(p: Point) {
    this.target = { x: clampTo(p.x, 10, CARD_W - 10), y: clampTo(p.y, 10, CARD_H - 10) };
  }
  overload(now: number) {
    this.flashStart = now;
  }
  step(now: number) {
    const time = this.clock.advance(now, 1);
    const k = this.clock.follow(7);
    this.beam.x += (this.target.x - this.beam.x) * k;
    this.beam.y += (this.target.y - this.beam.y) * k;
    const age = now - this.flashStart;
    return { time, beam: this.beam, flash: age < 3 ? age : -1 };
  }
}

/** `NightVisionHUD`: reticle and read-outs in phosphor green, drawn over the tube. */
function drawHUD(g: CanvasRenderingContext2D, beam: Point, gain: number, time: number) {
  const green = rgba(0xb8ffc4, 0.85);
  g.strokeStyle = green;
  g.lineWidth = 1.2;
  g.beginPath();
  g.arc(beam.x, beam.y, 16, 0, Math.PI * 2);
  for (let i = 0; i < 4; i++) {
    const a = (i * Math.PI) / 2;
    g.moveTo(beam.x + Math.cos(a) * 22, beam.y + Math.sin(a) * 22);
    g.lineTo(beam.x + Math.cos(a) * 34, beam.y + Math.sin(a) * 34);
  }
  g.stroke();
  g.fillStyle = green;
  g.beginPath();
  g.arc(beam.x, beam.y, 1.5, 0, Math.PI * 2);
  g.fill();
  const font = `700 9px ${fonts.mono}`;
  text(g, "IR 850 nm", 44, 46, font, green);
  text(g, `GAIN ×${gain.toFixed(1)}`, CARD_W - 44, 46, font, green, "right");
  if (time % 1 < 0.5) {
    g.fillStyle = green;
    g.beginPath();
    g.arc(47, CARD_H - 47, 3, 0, Math.PI * 2);
    g.fill();
  }
  text(g, "REC", 55, CARD_H - 47, font, green);
}

export default function NightVision({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const scene = useScene();
  const hud = useLayer(CARD_W, CARD_H);
  const model = useRef(new NightVisionModel()).current;
  const turn = useRef(0);

  useAutoplay(
    ctx.isPreview,
    () => {
      // Simulated operator: aims at the next subject, and overloads the tube on every fourth look.
      model.aim(SWEEP[turn.current % SWEEP.length]);
      if (turn.current % 4 === 3) model.overload(nowSec());
      turn.current += 1;
    },
    { every: 1.5, delay: 0.4 },
  );
  const touch = useShaderTouch({
    onBegan: (p) => {
      haptics.tap("soft");
      model.aim(p);
    },
    onMoved: (p) => model.aim(p),
    onTap: (p) => {
      haptics.tap("rigid");
      model.aim(p);
      model.overload(nowSec());
    },
  });

  return (
    <CenterStack ctx={ctx} en="Drag the beam · tap to overload" zh="拖动光束 · 点击过曝">
      <ShaderCard glow={hex(0x21d45a, 0.22)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.NightVision}
          source={scene.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            scene.ensure(0, (g) => drawForest(g));
            const s = model.step(nowSec());
            const gain = ctx.n("gain");
            hud.paint((g) => drawHUD(g, s.beam, gain, s.time));
            return {
              p_time: s.time,
              p_gain: gain,
              p_noise: ctx.n("noise"),
              p_beam: [s.beam.x, s.beam.y],
              p_radius: ctx.n("radius"),
              p_bloom: ctx.n("bloom"),
              p_flash: s.flash,
            };
          }}
        />
        <LayerView layer={hud} width={CARD_W} height={CARD_H} style={{ position: "absolute", inset: 0, pointerEvents: "none" }} />
      </ShaderCard>
    </CenterStack>
  );
}
