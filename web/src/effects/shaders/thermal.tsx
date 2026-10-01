/** shader.thermal · 热成像 (Shaders+Thermal.swift, mlThermal) */
import { animate, useMotionValue } from "motion/react";
import { useMemo, useRef } from "react";
import { fonts, hex, spring, useHaptics, type DemoProps, type Point } from "../../kit";
import { nowSec, rgba, useLayer } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clockFrom, color4, useShaderTouch } from "./_card";
import { blurred, box } from "./_scenes";

const PALETTES = [
  [0x05051e, 0x5a0c8c, 0xd8364a, 0xff9f1a, 0xfff7c2],
  [0x10106b, 0x1aa7e8, 0x35d07f, 0xffd23f, 0xf03b2e],
  [0x000000, 0x3a3a3a, 0x7a7a7a, 0xc4c4c4, 0xffffff],
];
const CAT = { x: 168, y: 150 };
const gray = (w: number, a = 1) => {
  const v = Math.round(Math.min(Math.max(w, 0), 1) * 255);
  return `rgba(${v},${v},${v},${a})`;
};

// The SF Symbols the room is made of (`lamp.desk.fill`, `cat.fill`, `mug.fill`), redrawn as silhouettes.
const CAT_BODY = new Path2D(
  "M16 44C16 32 28 28 40 28L86 24L92 10L100 0L106 10L116 2L122 14C130 18 131 28 126 32C120 37 110 37 104 35L100 60L100 98C100 104 92 104 86 103L82 103L84 70C70 68 50 66 42 66L40 104C40 110 32 109 24 109L20 109L22 80C16 70 14 56 16 44Z",
);
const CAT_TAIL = new Path2D("M18 40C2 34 -2 8 16 3C26 0 36 2 42 6");

function drawLamp(g: CanvasRenderingContext2D, color: string) {
  g.fillStyle = color;
  g.strokeStyle = color;
  g.lineWidth = 4.5;
  g.lineCap = "round";
  g.lineJoin = "round";
  g.beginPath();
  g.roundRect(0, 64, 35, 7, 3);
  g.fill();
  g.beginPath();
  g.moveTo(17.5, 64);
  g.lineTo(17.5, 52);
  g.lineTo(3.5, 38);
  g.lineTo(20, 8);
  g.stroke();
  for (const [x, y] of [[17.5, 52], [3.5, 38]]) {
    g.beginPath();
    g.arc(x, y, 4, 0, Math.PI * 2);
    g.fill();
  }
  g.beginPath();
  g.moveTo(14, 4);
  g.lineTo(25, 0);
  g.lineTo(54, 13);
  g.lineTo(43, 34);
  g.closePath();
  g.fill();
  g.lineWidth = 3;
  g.stroke();
  g.beginPath();
  g.arc(46, 25, 8, 0, Math.PI * 2);
  g.fill();
}

function drawCat(g: CanvasRenderingContext2D, color: string) {
  g.fillStyle = color;
  g.fill(CAT_BODY);
  g.strokeStyle = color;
  g.lineWidth = 7;
  g.lineCap = "round";
  g.stroke(CAT_TAIL);
}

function drawMug(g: CanvasRenderingContext2D, color: string) {
  g.fillStyle = color;
  g.beginPath();
  g.roundRect(0, 0, 40, 56, [5, 5, 12, 12]);
  g.fill();
  g.strokeStyle = color;
  g.lineWidth = 5;
  g.beginPath();
  g.roundRect(34, 14, 15, 24, 8);
  g.stroke();
}

/** `glowing(symbol, …)`: a soft copy at `white × glow` blurred by 12 pt under the glyph at `white`. */
function glowing(g: CanvasRenderingContext2D, k: number, x: number, y: number, white: number, glow: number, draw: (g: CanvasRenderingContext2D, color: string) => void) {
  g.save();
  g.translate(x, y);
  blurred(g, k, 12, () => {
    g.shadowColor = gray(white * glow);
    draw(g, "#000");
  });
  draw(g, gray(white));
  g.restore();
}

interface HeatPoint {
  position: Point;
  time: number;
}

class ThermalModel {
  clock = clockFrom(0);
  trail: HeatPoint[] = [];
  finger: Point | null = null;

  add(p: Point, now: number) {
    const last = this.trail[this.trail.length - 1];
    if (last && Math.hypot(last.position.x - p.x, last.position.y - p.y) < 5 && now - last.time < 0.05) return;
    this.trail.push({ position: p, time: now });
    if (this.trail.length > 90) this.trail.splice(0, this.trail.length - 90);
  }
  step(now: number, cooling: number, auto: boolean) {
    const time = this.clock.advance(now, 1);
    if (auto) {
      // Simulated finger: a slow figure-eight through the room, through the same `add` as a drag.
      const p = { x: 130 + 86 * Math.sin(now * 0.9), y: 160 + 70 * Math.sin(now * 1.8) };
      this.finger = p;
      this.add(p, now);
    }
    this.trail = this.trail.filter((h) => now - h.time <= cooling);
    return time;
  }
}

const hud: React.CSSProperties = {
  position: "absolute",
  inset: 0,
  pointerEvents: "none",
  fontFamily: fonts.mono,
  fontSize: 10,
  lineHeight: "12px",
  fontWeight: 700,
  fontVariantNumeric: "tabular-nums",
  color: "#fff",
  filter: "drop-shadow(0 0 2px rgb(0 0 0 / 0.6))",
};

export default function Thermal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const room = useLayer(CARD_W, CARD_H);
  const still = useLayer(CARD_W, CARD_H);
  const catLayer = useLayer(CARD_W, CARD_H);
  const mugLayer = useLayer(CARD_W, CARD_H);
  const soft = useLayer(CARD_W, CARD_H);
  const cached = useRef(false);
  const model = useRef(new ThermalModel()).current;
  const rx = useMotionValue(CAT.x);
  const ry = useMotionValue(CAT.y);
  const touching = useRef(false);
  const reticle = useRef<HTMLDivElement>(null);
  const reading = useRef<HTMLDivElement>(null);
  const dot = useRef<HTMLDivElement>(null);
  const stops = PALETTES[Math.min(Math.max(ctx.i("palette"), 0), 2)];
  const legend = useMemo(() => `linear-gradient(to bottom, ${[...stops].reverse().map((c) => hex(c)).join(", ")})`, [stops]);

  const aim = (p: Point, t: ReturnType<typeof spring>) => {
    animate(rx, p.x, t);
    animate(ry, p.y, t);
  };
  const touch = useShaderTouch({
    onBegan: (p) => {
      touching.current = true;
      haptics.tap("soft");
      aim(p, spring(0.3, 0.7));
    },
    onMoved: (p) => {
      model.finger = p;
      model.add(p, nowSec());
      aim(p, spring(0.2, 0.8));
    },
    onEnded: () => {
      touching.current = false;
      model.finger = null;
      aim(CAT, spring(0.6, 0.75));
    },
    onTap: (p) => {
      haptics.tap("soft");
      // A tap leaves a fingertip print: a small cluster through the same `add`.
      const now = nowSec();
      for (let i = 0; i < 5; i++) {
        const angle = i * 1.2566;
        model.add({ x: p.x + Math.cos(angle) * 7, y: p.y + Math.sin(angle) * 7 }, now + i * 0.06);
      }
    },
  });

  /** The parts of `ThermalRoom` that never change: wall, window, table, lamp with its bulb, mug. */
  const drawStill = (g: CanvasRenderingContext2D, k: number) => {
    const wall = g.createLinearGradient(0, 0, 0, CARD_H);
    wall.addColorStop(0, gray(0.13));
    wall.addColorStop(1, gray(0.2));
    g.fillStyle = wall;
    g.fillRect(0, 0, CARD_W, CARD_H);
    // Cold window pane.
    const pane = g.createLinearGradient(0, 14, 0, 110);
    pane.addColorStop(0, gray(0));
    pane.addColorStop(1, gray(0.07));
    g.fillStyle = pane;
    g.beginPath();
    g.roundRect(154, 14, 84, 96, 10);
    g.fill();
    box(g, 194.5, 14, 3, 96, gray(0.16));
    box(g, 154, 60.5, 84, 3, gray(0.16));
    // Table edge, slightly warmer than the wall.
    box(g, 0, CARD_H - 64, CARD_W, 64, gray(0.26));
    glowing(g, k, 56 - 27, 74 - 36, 0.5, 0.5, drawLamp);
    // The bulb is the hottest thing in the room.
    const bulb = g.createRadialGradient(70, 66, 0, 70, 66, 26);
    bulb.addColorStop(0, "rgba(255,255,255,1)");
    bulb.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = bulb;
    g.beginPath();
    g.arc(70, 66, 26, 0, Math.PI * 2);
    g.fill();
  };
  /** The cat at its coolest (white 0.57) on a transparent layer; its breathing is added on top of this. */
  const drawCatLayer = (g: CanvasRenderingContext2D, k: number) => {
    glowing(g, k, 168 - 65, 156 - 54, 0.57, 0.45, drawCat);
    g.fillStyle = gray(0.57 * 0.45);
    g.beginPath();
    g.arc(168 - 65 + 115, 156 - 54 + 20, 2.6, 0, Math.PI * 2);
    g.fill();
  };
  const drawMugLayer = (g: CanvasRenderingContext2D, k: number) => glowing(g, k, 62 - 25.5, 228 - 28, 0.86, 0.6, drawMug);

  /** `ThermalRoom`: the scene the sensor looks at, drawn so that brightness means temperature. */
  const drawRoom = (g: CanvasRenderingContext2D, k: number, time: number, now: number, cooling: number) => {
    if (!cached.current) {
      still.paint(drawStill);
      catLayer.paint(drawCatLayer);
      mugLayer.paint(drawMugLayer);
      cached.current = true;
    }
    const blit = (layer: { canvas: HTMLCanvasElement }) => g.drawImage(layer.canvas, 0, 0, CARD_W, CARD_H);
    blit(still);
    // `Color(white: 0.6 + 0.03 · sin(2.2 t))`: the cached 0.57 cat plus the rest of its warmth, added.
    blit(catLayer);
    g.globalCompositeOperation = "lighter";
    g.globalAlpha = (0.6 + 0.03 * Math.sin(time * 2.2)) / 0.57 - 1;
    blit(catLayer);
    g.globalAlpha = 1;
    g.globalCompositeOperation = "source-over";
    // Steam: five soft discs rising from the mug (their alpha, blurred in one pass, casts the 0.75 grey).
    soft.paint((h) => {
      for (let i = 0; i < 5; i++) {
        const phase = (time * 0.35 + i * 0.2) % 1;
        h.fillStyle = `rgba(0,0,0,${(1 - phase) * 0.6})`;
        h.beginPath();
        h.arc(62 + Math.sin(phase * 5 + i) * 7, 196 - phase * 62, (16 + 14 * phase) / 2, 0, Math.PI * 2);
        h.fill();
      }
    });
    blurred(g, k, 7, () => {
      g.shadowColor = gray(0.75);
      g.drawImage(soft.canvas, 0, 90 * k, 130 * k, 150 * k, 0, 90, 130, 150);
    });
    blit(mugLayer);
    // The finger's heat: blurred discs that cool down, added on top of the room.
    if (!model.trail.length) return;
    soft.paint((h) => {
      for (const point of model.trail) {
        const age = now - point.time;
        if (age < 0 || age >= cooling) continue;
        const life = 1 - age / cooling;
        h.fillStyle = `rgba(255,255,255,${Math.pow(life, 1.4) * 0.8})`;
        h.beginPath();
        h.arc(point.position.x, point.position.y, 15 + 5 * (1 - life), 0, Math.PI * 2);
        h.fill();
      }
    });
    g.globalCompositeOperation = "lighter";
    blurred(g, k, 9, () => {
      g.shadowColor = "#fff";
      blit(soft);
    });
  };

  return (
    <CenterStack ctx={ctx} en="Drag a finger across the room" zh="用手指在房间里划过">
      <ShaderCard glow={hex(0xd8364a, 0.3)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Thermal}
          source={room.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            const now = nowSec();
            const cooling = ctx.n("cooling");
            const time = model.step(now, cooling, ctx.isPreview);
            room.paint((g, k) => drawRoom(g, k, time, now, cooling));
            // In previews the reticle rides the simulated finger; on the detail stage it follows the spring.
            const at = ctx.isPreview && model.finger ? model.finger : { x: rx.get(), y: ry.get() };
            if (reticle.current) reticle.current.style.transform = `translate(${at.x}px, ${at.y}px)`;
            // The spot reading wobbles by a tenth of a degree, like a live sensor.
            const wobble = (Math.sin(time * 3.1) + Math.sin(time * 5.3)) * 0.1;
            const value = `${((touching.current || ctx.isPreview ? 34.2 : 38.6) + wobble).toFixed(1)}°C`;
            if (reading.current && reading.current.textContent !== value) reading.current.textContent = value;
            if (dot.current) dot.current.style.opacity = String(0.4 + 0.6 * (Math.sin(time * 4) > 0 ? 1 : 0));
            return {
              p_time: time,
              p_c0: color4(stops[0]),
              p_c1: color4(stops[1]),
              p_c2: color4(stops[2]),
              p_c3: color4(stops[3]),
              p_c4: color4(stops[4]),
              p_shimmer: ctx.n("shimmer"),
              p_contours: ctx.n("contours"),
              p_gain: 1,
            };
          }}
        />
        {/* `ThermalHUD`: palette legend, reticle with a spot reading, status line. */}
        <div style={hud}>
          <div style={{ position: "absolute", right: 12, top: 98, display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 4 }}>
            <span>41°</span>
            <div style={{ width: 7, height: 132, borderRadius: 3.5, background: legend, boxShadow: "inset 0 0 0 0.5px rgb(255 255 255 / 0.5)" }} />
            <span>12°</span>
          </div>
          <div style={{ position: "absolute", left: 14, bottom: 14, display: "flex", alignItems: "center", gap: 5 }}>
            <div ref={dot} style={{ width: 6, height: 6, borderRadius: 3, background: rgba(0xff4d5e) }} />
            <span style={{ whiteSpace: "pre" }}>IR  ε 0.95</span>
          </div>
          <div ref={reticle} style={{ position: "absolute", left: 0, top: 0, width: 0, height: 0, transform: `translate(${CAT.x}px, ${CAT.y}px)` }}>
            <div style={{ position: "absolute", left: -11, top: -11, width: 22, height: 22, borderRadius: 11, boxShadow: "inset 0 0 0 1.2px #fff" }} />
            <div style={{ position: "absolute", left: -0.6, top: -17, width: 1.2, height: 34, background: "#fff" }} />
            <div style={{ position: "absolute", left: -17, top: -0.6, width: 34, height: 1.2, background: "#fff" }} />
            <div style={{ position: "absolute", left: -40, top: 22, width: 80, display: "flex", justifyContent: "center" }}>
              <div ref={reading} style={{ padding: "2px 6px", borderRadius: 999, background: "rgb(0 0 0 / 0.5)", whiteSpace: "nowrap" }}>
                38.6°C
              </div>
            </div>
          </div>
        </div>
      </ShaderCard>
    </CenterStack>
  );
}
