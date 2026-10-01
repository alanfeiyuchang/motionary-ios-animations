/** text.letter-drop · 字母坠落堆叠 (Text+LetterDrop.swift) */
import { useRef, useState } from "react";
import { DemoHint, Palette, fonts, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { randIn } from "./_text-kit";
import { now, prepareCanvas, resolveColor, useFrame } from "./_fx";

interface Body {
  x: number;
  y: number;
  vx: number;
  vy: number;
  angle: number;
  spin: number;
  radius: number;
  delay: number;
  free: boolean;
}
/** The tray the letters fall into: a flat floor at `base` between walls at `center ± half` that start at `rim`. */
interface Bowl {
  base: number;
  center: number;
  half: number;
  rim: number;
}
const ACCENTS = [Palette.coral, Palette.amber, Palette.mint, Palette.sky, Palette.indigo, Palette.violet, Palette.pink];

export default function LetterDrop({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sim = useRef({ last: null as number | null, now: 0, modeStart: 0, dropped: false, bodies: [] as Body[], key: "" });
  const [dropped, setDropped] = useState(false);
  const droppedRef = useRef(false);
  const colors = useRef<{ key: string; ink: string; tray: string } | null>(null);
  const zh = ctx.lang === "zh";
  const letters = Array.from(zh ? "文字也有重量" : "GRAVITY");
  const gravity = ctx.n("gravity");
  const bounce = ctx.n("bounce");
  const stagger = ctx.n("stagger");

  const toggle = () => {
    droppedRef.current = !droppedRef.current;
    setDropped(droppedRef.current);
    const state = sim.current;
    state.dropped = droppedRef.current;
    state.modeStart = state.now;
    const order = state.bodies.map((_, i) => i);
    for (let i = order.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [order[i], order[j]] = [order[j], order[i]];
    }
    order.forEach((index, slot) => {
      if (droppedRef.current) {
        state.bodies[index].delay = slot * stagger;
        state.bodies[index].free = false;
      } else {
        state.bodies[index].delay = index * stagger;
      }
    });
  };
  useAutoplay(ctx.isPreview, toggle, { every: 2.7, delay: 0.9 });

  const collide = (bodies: Body[], restitution: number, bowl: Bowl) => {
    const count = bodies.length;
    for (let first = 0; first < count - 1; first++) {
      if (!bodies[first].free) continue;
      for (let second = first + 1; second < count; second++) {
        if (!bodies[second].free) continue;
        const a = bodies[first];
        const b = bodies[second];
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        const distance = Math.max(Math.hypot(dx, dy), 0.001);
        const overlap = a.radius + b.radius - distance;
        if (!(overlap > 0)) continue;
        const nx = dx / distance;
        const ny = dy / distance;
        a.x -= nx * overlap * 0.5;
        a.y -= ny * overlap * 0.5;
        b.x += nx * overlap * 0.5;
        b.y += ny * overlap * 0.5;
        const approach = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny;
        if (approach < 0) {
          const impulse = (-(1 + restitution) * approach) / 2;
          a.vx -= impulse * nx;
          a.vy -= impulse * ny;
          b.vx += impulse * nx;
          b.vy += impulse * ny;
          // Resting contacts bleed energy so the pile settles.
          a.vx *= 0.99;
          b.vx *= 0.99;
        }
        a.y = Math.min(a.y, bowl.base - a.radius);
        b.y = Math.min(b.y, bowl.base - b.radius);
        if (a.y + a.radius * 0.5 > bowl.rim) a.x = Math.min(Math.max(a.x, bowl.center - bowl.half + a.radius), bowl.center + bowl.half - a.radius);
        if (b.y + b.radius * 0.5 > bowl.rim) b.x = Math.min(Math.max(b.x, bowl.center - bowl.half + b.radius), bowl.center + bowl.half - b.radius);
      }
    }
  };

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = box.offsetHeight;
    if (!w || !h) return;
    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (colors.current?.key !== ctx.scheme) colors.current = { key: ctx.scheme, ink: resolveColor(el, Palette.label), tray: resolveColor(el, Palette.labelAlpha(0.18)) };

    const fontSize = zh ? 44 : 50;
    g.font = `900 ${fontSize}px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    const widths = letters.map((letter) => g.measureText(letter).width);
    const total = widths.reduce((a, b) => a + b, 0);
    const floor = h - 46;
    const homeY = h * 0.34;
    const homes: { x: number; y: number }[] = [];
    let cursor = (w - total) / 2;
    for (const width of widths) {
      homes.push({ x: cursor + width / 2, y: homeY });
      cursor += width;
    }

    // The letters land in a tray narrower than the word, so they have to pile up.
    const bowl: Bowl = { base: floor, center: w / 2, half: 112, rim: floor - 60 };
    const left = bowl.center - bowl.half - 1;
    const right = bowl.center + bowl.half + 1;
    const bottom = floor + 1;
    const corner = 16;
    g.beginPath();
    g.moveTo(left, bowl.rim);
    g.lineTo(left, bottom - corner);
    g.quadraticCurveTo(left, bottom, left + corner, bottom);
    g.lineTo(right - corner, bottom);
    g.quadraticCurveTo(right, bottom, right, bottom - corner);
    g.lineTo(right, bowl.rim);
    g.strokeStyle = colors.current.tray;
    g.lineWidth = 2;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.stroke();

    const state = sim.current;
    const key = `${ctx.lang}`;
    if (state.bodies.length !== letters.length || state.key !== key) {
      state.key = key;
      state.bodies = homes.map((home) => ({ x: home.x, y: home.y, vx: 0, vy: 0, angle: 0, spin: 0, radius: 0, delay: 0, free: false }));
    }
    state.bodies.forEach((body, index) => {
      body.radius = Math.max(widths[index], fontSize * 0.74) * 0.56;
      // Until the first drop the letters sit exactly on their homes (the canvas height can change).
      if (!state.dropped && state.now === 0) {
        body.x = homes[index].x;
        body.y = homes[index].y;
      }
    });
    const time = now();
    if (state.last === null) state.last = time;
    else {
      const dt = Math.min(Math.max(time - state.last, 0), 1 / 20);
      if (dt > 0) {
        state.last = time;
        state.now += dt;
        const sinceMode = state.now - state.modeStart;
        if (state.dropped) {
          for (const body of state.bodies) {
            if (body.free || sinceMode < body.delay) continue;
            body.free = true;
            // A push toward the middle, so every letter clears the rim of the tray.
            body.vx = -(body.x - bowl.center) * 1.7 + randIn(-30, 30);
            body.vy = randIn(-120, 0);
            body.spin = randIn(-4, 4);
          }
          const hh = dt / 4;
          for (let s = 0; s < 4; s++) {
            for (const body of state.bodies) {
              if (!body.free) continue;
              body.vy += gravity * hh;
              body.x += body.vx * hh;
              body.y += body.vy * hh;
              body.angle += body.spin * hh;
              // Floor: bounce, then roll.
              if (body.y + body.radius > bowl.base) {
                body.y = bowl.base - body.radius;
                if (body.vy > 0) body.vy = body.vy > 60 ? -body.vy * bounce : 0;
                body.vx *= 0.975;
                body.spin += (body.vx / body.radius - body.spin) * 0.25;
                if (Math.abs(body.vx) < 4) body.vx = 0;
              }
              // Tray walls, below the rim.
              if (body.y + body.radius * 0.5 > bowl.rim) {
                if (body.x - body.radius < bowl.center - bowl.half) {
                  body.x = bowl.center - bowl.half + body.radius;
                  body.vx = Math.abs(body.vx) * bounce;
                } else if (body.x + body.radius > bowl.center + bowl.half) {
                  body.x = bowl.center + bowl.half - body.radius;
                  body.vx = -Math.abs(body.vx) * bounce;
                }
              }
              body.spin *= 0.997;
            }
            collide(state.bodies, bounce * 0.5, bowl);
          }
        } else {
          const omega = (2 * Math.PI) / 0.5;
          const damping = 0.7;
          const hh = dt / 3;
          state.bodies.forEach((body, index) => {
            if (sinceMode < body.delay) return;
            body.free = false;
            const home = homes[index];
            // Unwind to the nearest upright orientation.
            const upright = Math.round(body.angle / (2 * Math.PI)) * 2 * Math.PI;
            for (let s = 0; s < 3; s++) {
              body.vx += (-omega * omega * (body.x - home.x) - 2 * damping * omega * body.vx) * hh;
              body.vy += (-omega * omega * (body.y - home.y) - 2 * damping * omega * body.vy) * hh;
              body.spin += (-omega * omega * (body.angle - upright) - 2 * damping * omega * body.spin) * hh;
              body.x += body.vx * hh;
              body.y += body.vy * hh;
              body.angle += body.spin * hh;
            }
          });
        }
      }
    }

    state.bodies.forEach((body, index) => {
      const home = homes[index];
      const away = Math.min(Math.hypot(body.x - home.x, body.y - home.y) / 50, 1);
      g.save();
      g.translate(body.x, body.y);
      g.rotate(body.angle);
      g.fillStyle = colors.current!.ink;
      g.fillText(letters[index], 0, 0);
      if (away > 0.01) {
        g.globalAlpha = away;
        g.fillStyle = ACCENTS[index % ACCENTS.length];
        g.fillText(letters[index], 0, 0);
      }
      g.restore();
    });
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div
      ref={host}
      onClick={() => {
        haptics.tap(droppedRef.current ? "light" : "medium");
        toggle();
      }}
      style={{ position: "absolute", inset: 0, cursor: "pointer" }}
    >
      <canvas ref={canvas} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 12 }}>
        {dropped ? <DemoHint ctx={ctx} en="Tap to lift them back" zh="点击把它们拉回去" /> : <DemoHint ctx={ctx} en="Tap to let go" zh="点击松手" />}
      </div>
    </div>
  );
}
