/** inputs.bubble-picker (Inputs+BubblePicker.swift) */
import { useRef, useState } from "react";
import { Check } from "lucide-react";
import { DemoHint, NumericText, Palette, alpha, textStyle, useAutoplay, useClock, useHaptics, type DemoProps } from "../../kit";
import { column, spacer } from "./_c-common";

const GENRES: { name: [string, string]; radius: number; tint: string }[] = [
  { name: ["Indie", "独立"], radius: 33, tint: Palette.indigo },
  { name: ["Jazz", "爵士"], radius: 30, tint: Palette.amber },
  { name: ["Electronic", "电子"], radius: 38, tint: Palette.sky },
  { name: ["Lo-fi", "低保真"], radius: 31, tint: Palette.mint },
  { name: ["Classical", "古典"], radius: 36, tint: Palette.violet },
  { name: ["Rock", "摇滚"], radius: 30, tint: Palette.coral },
  { name: ["Ambient", "氛围"], radius: 34, tint: Palette.blue },
  { name: ["Soul", "灵魂乐"], radius: 30, tint: Palette.pink },
  { name: ["Folk", "民谣"], radius: 29, tint: Palette.green },
];
const SIZE = { w: 316, h: 236 };
const SCRIPT = [2, 7, 4, 0, 2, 5, 7, 4, 0, 5];

interface Body {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  radiusVelocity: number;
  target: number;
}

/** Simulation state, stepped once per drawn frame. */
class Sim {
  bodies: Body[];
  private last: number | null = null;
  private clock = 0;

  constructor(selected: Set<number>, grow: number) {
    const cx = SIZE.w / 2;
    const cy = SIZE.h / 2;
    this.bodies = GENRES.map((genre, index) => {
      // Seed on a 3 × 3 grid so the cluster starts spread out and settles the same way every time.
      const col = (index % 3) - 1;
      const row = Math.floor(index / 3) - 1;
      const radius = genre.radius * (selected.has(index) ? grow : 1);
      return { x: cx + col * 84 + row * 10, y: cy + row * 66 + col * 6, vx: 0, vy: 0, radius, radiusVelocity: 0, target: radius };
    });
    for (let i = 0; i < 240; i++) this.step(1 / 60, 0.6);
  }

  setTargets(selected: Set<number>, grow: number) {
    this.bodies.forEach((body, index) => (body.target = GENRES[index].radius * (selected.has(index) ? grow : 1)));
  }

  /** Radial kick from one bubble to the others, fading with distance. */
  impulse(origin: number, strength: number) {
    const source = this.bodies[origin];
    this.bodies.forEach((body, index) => {
      if (index === origin) return;
      const dx = body.x - source.x;
      const dy = body.y - source.y;
      const distance = Math.max(Math.hypot(dx, dy), 1);
      const falloff = strength / Math.max(distance / 70, 1);
      body.vx += (dx / distance) * falloff;
      body.vy += (dy / distance) * falloff;
    });
  }

  advance(now: number, stiffness: number) {
    const elapsed = this.last === null ? 0 : now - this.last;
    this.last = now;
    const dt = Math.min(Math.max(elapsed, 0), 1 / 30);
    if (dt <= 0) return;
    this.step(dt / 2, stiffness);
    this.step(dt / 2, stiffness);
  }

  private step(h: number, stiffness: number) {
    this.clock += h;
    const cx = SIZE.w / 2;
    const cy = SIZE.h / 2;
    const bodies = this.bodies;
    const fx = bodies.map((body, index) => (cx - body.x) * 1.6 + Math.sin(this.clock * 0.7 + index * 1.9) * 9);
    const fy = bodies.map((body, index) => (cy - body.y) * 4.2 + Math.cos(this.clock * 0.55 + index * 2.3) * 9);
    for (let a = 0; a < bodies.length; a++) {
      for (let b = a + 1; b < bodies.length; b++) {
        const dx = bodies[b].x - bodies[a].x;
        const dy = bodies[b].y - bodies[a].y;
        const distance = Math.max(Math.hypot(dx, dy), 0.01);
        const overlap = bodies[a].radius + bodies[b].radius + 5 - distance;
        if (overlap <= 0) continue;
        const force = overlap * stiffness * 300;
        fx[a] -= (dx / distance) * force;
        fy[a] -= (dy / distance) * force;
        fx[b] += (dx / distance) * force;
        fy[b] += (dy / distance) * force;
      }
    }
    const drag = Math.max(1 - 4.5 * h, 0);
    bodies.forEach((body, index) => {
      body.vx = (body.vx + fx[index] * h) * drag;
      body.vy = (body.vy + fy[index] * h) * drag;
      body.x += body.vx * h;
      body.y += body.vy * h;
      // Sprung radius: stiffness 120, damping 14.
      body.radiusVelocity += ((body.target - body.radius) * 120 - body.radiusVelocity * 14) * h;
      body.radius = Math.max(body.radius + body.radiusVelocity * h, 4);
      const r = body.radius;
      if (body.x < r) {
        body.x = r;
        body.vx = Math.abs(body.vx) * 0.4;
      }
      if (body.x > SIZE.w - r) {
        body.x = SIZE.w - r;
        body.vx = -Math.abs(body.vx) * 0.4;
      }
      if (body.y < r) {
        body.y = r;
        body.vy = Math.abs(body.vy) * 0.4;
      }
      if (body.y > SIZE.h - r) {
        body.y = SIZE.h - r;
        body.vy = -Math.abs(body.vy) * 0.4;
      }
    });
  }
}

export default function BubblePicker({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected] = useState<Set<number>>(() => new Set([4]));
  const selectedRef = useRef(selected);
  const sim = useRef<Sim | null>(null);
  if (!sim.current) sim.current = new Sim(selected, ctx.n("grow"));
  const step = useRef(0);

  /** Finger and autoplay both land here. */
  const toggle = (index: number) => {
    const next = new Set(selectedRef.current);
    if (next.has(index)) {
      haptics.tap("soft");
      next.delete(index);
    } else {
      haptics.tap("light");
      next.add(index);
      sim.current?.impulse(index, ctx.n("push"));
    }
    selectedRef.current = next;
    setSelected(next);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      toggle(SCRIPT[step.current % SCRIPT.length]);
      step.current += 1;
    },
    { every: 1.1, delay: 0.5 },
  );

  // Stepping here keeps the simulation tied to the frames that are actually drawn.
  const now = useClock(true, ctx.isPreview ? 30 : undefined);
  const stepped = useRef(-1);
  if (stepped.current !== now) {
    stepped.current = now;
    sim.current.setTargets(selected, ctx.n("grow"));
    sim.current.advance(now, ctx.n("stiffness"));
  }
  const bodies = sim.current.bodies;

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", alignItems: "center", gap: 6, paddingBottom: 4 }}>
        <span style={{ ...textStyle.subheadline, fontWeight: 600 }}>{ctx.t("Pick your sound", "选出你的口味")}</span>
        <span style={{ ...textStyle.footnote, fontWeight: 600, color: Palette.indigo, padding: "0 9px", height: 24, lineHeight: "24px", borderRadius: 12, background: alpha(Palette.indigo, 0.14), display: "inline-flex", alignItems: "center" }}>
          <NumericText value={selected.size} text={ctx.lang === "zh" ? `已选 ${selected.size}` : `${selected.size} selected`} />
        </span>
      </div>
      <div style={{ position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0 }}>
        {bodies.map((body, index) => {
          const genre = GENRES[index];
          const on = selected.has(index);
          const scale = body.radius / genre.radius;
          const fade = "0.22s ease-out";
          return (
            <div
              key={index}
              onClick={() => toggle(index)}
              style={{
                position: "absolute",
                left: body.x - body.radius,
                top: body.y - body.radius,
                width: body.radius * 2,
                height: body.radius * 2,
                borderRadius: "50%",
                background: alpha(genre.tint, 0.16),
                boxShadow: `0 5px 15px ${alpha(genre.tint, on ? 0.45 : 0)}`,
                transition: `box-shadow ${fade}`,
                cursor: "pointer",
              }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `linear-gradient(135deg, ${genre.tint}, ${alpha(genre.tint, 0.72)})`, opacity: on ? 1 : 0, transition: `opacity ${fade}` }} />
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", border: `1.5px solid ${alpha(genre.tint, 0.55)}`, opacity: on ? 0 : 1, transition: `opacity ${fade}` }} />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 1,
                  color: on ? "#fff" : Palette.labelAlpha(0.85),
                  transition: `color ${fade}`,
                  transform: `scale(${Math.min(scale, 1.25)})`,
                }}
              >
                <div style={{ height: on ? 10 : 0, opacity: on ? 1 : 0, overflow: "hidden", transition: `height ${fade}, opacity ${fade}`, display: "grid", placeItems: "center" }}>
                  <Check size={10} strokeWidth={4.5} />
                </div>
                <span style={{ fontSize: 12, fontWeight: 600, lineHeight: "15px", whiteSpace: "nowrap" }}>{ctx.t(...genre.name)}</span>
              </div>
            </div>
          );
        })}
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the bubbles you like" zh="点选你喜欢的气泡" style={{ paddingBottom: 12 }} />
    </div>
  );
}
