/** text.echo-trail · 残影拖尾 (Text+EchoTrail.swift) */
import { useRef } from "react";
import { DemoHint, Palette, fonts, useHaptics, usePan, type DemoProps } from "../../kit";
import { now, prepareCanvas, resolveColor, useFrame } from "./_fx";

interface Sample {
  time: number;
  x: number;
  y: number;
  lean: number;
}
const TINTS = [Palette.pink, Palette.violet, Palette.indigo, Palette.sky];
const HEIGHT = 268;

/** The figure-eight the word follows when nobody is touching it. */
const orbit = (clock: number, w: number, h: number) => ({ x: w / 2 + 95 * Math.sin(clock * 1.5), y: h / 2 + 62 * Math.sin(clock * 3.0 + 0.4) });
const leanFor = (vx: number) => Math.min(Math.max(vx * 0.0011, -0.38), 0.38);

/** History lookup with linear interpolation. */
function sampleAt(history: Sample[], time: number): Sample {
  let newer = history[history.length - 1];
  if (!newer) return { time, x: 0, y: 0, lean: 0 };
  for (let i = history.length - 1; i >= 0; i--) {
    const older = history[i];
    if (older.time <= time) {
      const span = newer.time - older.time;
      const u = span > 0 ? (time - older.time) / span : 0;
      return { time, x: older.x + (newer.x - older.x) * u, y: older.y + (newer.y - older.y) * u, lean: older.lean + (newer.lean - older.lean) * u };
    }
    newer = older;
  }
  return newer;
}

export default function EchoTrail({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const sim = useRef({ last: null as number | null, now: 0, orbit: 0, position: null as { x: number; y: number } | null, vx: 0, vy: 0, history: [] as Sample[] });
  const finger = useRef<{ x: number; y: number } | null>(null);
  const ink = useRef<{ key: string; color: string } | null>(null);
  const zh = ctx.lang === "zh";
  const count = Math.max(ctx.i("count"), 1);
  const gap = ctx.n("gap");
  const speed = ctx.n("speed");

  const pan = usePan({
    onChange: (s) => {
      if (!finger.current) haptics.tap("soft");
      finger.current = s.location;
    },
    onEnd: () => {
      finger.current = null;
    },
  });

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = HEIGHT;
    if (!w) return;
    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (ink.current?.key !== ctx.scheme) ink.current = { key: ctx.scheme, color: resolveColor(el, Palette.label) };

    const state = sim.current;
    const time = now();
    const keep = count * gap + 0.3;
    if (state.last === null || !state.position) {
      state.last = time;
      const home = orbit(state.orbit, w, h);
      state.position = home;
      state.history = [{ time: state.now, x: home.x, y: home.y, lean: 0 }];
    } else {
      const dt = Math.min(Math.max(time - state.last, 0), 1 / 20);
      if (dt > 0) {
        state.last = time;
        state.now += dt;
        const held = finger.current !== null;
        if (!held) state.orbit += dt * speed;
        const target = finger.current ?? orbit(state.orbit, w, h);
        // Spring toward the target: tight on the finger, looser when gliding back onto the orbit.
        const response = held ? 0.3 : 0.22;
        const damping = held ? 0.7 : 0.9;
        const omega = (2 * Math.PI) / response;
        let { x: px, y: py } = state.position;
        let { vx, vy } = state;
        const hh = dt / 4;
        for (let i = 0; i < 4; i++) {
          vx += (-omega * omega * (px - target.x) - 2 * damping * omega * vx) * hh;
          vy += (-omega * omega * (py - target.y) - 2 * damping * omega * vy) * hh;
          px += vx * hh;
          py += vy * hh;
        }
        state.position = { x: px, y: py };
        state.vx = vx;
        state.vy = vy;
        state.history.push({ time: state.now, x: px, y: py, lean: leanFor(vx) });
        const cutoff = state.now - keep;
        const firstKept = state.history.findIndex((s) => s.time >= cutoff);
        if (firstKept > 1) state.history.splice(0, firstKept - 1);
      }
    }

    g.font = `italic 900 ${zh ? 70 : 64}px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    const word = zh ? "残影" : "ECHO";
    for (let index = count; index >= 0; index--) {
      const entry = sampleAt(state.history, state.now - index * gap);
      const isHead = index === 0;
      const fade = 1 - index / (count + 1);
      g.save();
      g.translate(entry.x, entry.y);
      g.rotate(entry.lean);
      const scale = isHead ? 1 : Math.max(1 - 0.03 * index, 0.3);
      g.scale(scale, scale);
      g.globalAlpha = isHead ? 1 : 0.62 * Math.pow(fade, 1.4);
      g.fillStyle = isHead ? ink.current.color : TINTS[Math.min(Math.floor(((index - 1) * TINTS.length) / count), TINTS.length - 1)];
      g.fillText(word, 0, 0);
      g.restore();
    }
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "stretch", justifyContent: "center", gap: 4 }}>
      <div ref={host} {...pan} style={{ ...pan.style, height: HEIGHT, cursor: "grab" }}>
        <canvas ref={canvas} style={{ width: "100%", height: HEIGHT, display: "block" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the word around" zh="拖着这个词到处走" />
    </div>
  );
}
