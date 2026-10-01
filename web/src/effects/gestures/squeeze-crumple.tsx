/** gestures.squeeze-crumple · 捏合揉纸 (Gestures+SqueezeCrumple.swift) */
import { animate, useMotionValue, useMotionValueEvent } from "motion/react";
import { useEffect, useRef } from "react";
import { DemoHint, Palette, alpha, clamp, hex, rubberBand, spring, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { GMath, RGB, drawLayer, useCanvas2D, useGhost, usePinch } from "./_sim-kit";

const STAGE = { w: 300, h: 268 };
const SIZE = { w: 180, h: 220 };
const COLS = 9;
const ROWS = 11;
const TWIST = (50 * Math.PI) / 180;
const PAPER = new RGB(0.972, 0.962, 0.934);
const SHADOW = new RGB(0.3, 0.29, 0.36);

export default function SqueezeCrumple({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  /** 0 = flat sheet, 1 = paper ball. */
  const progress = useMotionValue(0);
  const s = useRef({ base: 0, creased: 0, held: false, crunch: 0, target: 0, pinchEndedAt: 0 }).current;
  const canvas = useCanvas2D(STAGE.w, STAGE.h);
  const ball = ctx.n("ball");
  const contrast = ctx.n("contrast");

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const p = progress.get();
    const creased = s.creased;
    const amount = Math.min(Math.max(p, 0), 1);
    const centre = { x: STAGE.w / 2, y: STAGE.h / 2 };
    const count = COLS * ROWS;

    /** How far vertex `index` is along its own crumple: corners lead, the centre trails. */
    const local = (index: number) => {
      const col = (index % COLS) / (COLS - 1) - 0.5;
      const row = Math.floor(index / COLS) / (ROWS - 1) - 0.5;
      const edge = Math.min(Math.hypot(col, row) / 0.7071, 1);
      const delay = 0.35 * (1 - edge);
      const t = (p - delay) / (1 - delay);
      if (t <= 0) return Math.max(t, -0.1) * 0.3;
      if (t >= 1) return t;
      return t * t * (3 - 2 * t);
    };
    /** Where vertex `index` lies on the flat sheet, relative to its centre. */
    const flat = (index: number): Point => {
      const col = index % COLS;
      const row = Math.floor(index / COLS);
      let u = col / (COLS - 1);
      let v = row / (ROWS - 1);
      if (col > 0 && col < COLS - 1) u += ((GMath.hash(index * 3 + 17) - 0.5) * 0.62) / (COLS - 1);
      if (row > 0 && row < ROWS - 1) v += ((GMath.hash(index * 5 + 29) - 0.5) * 0.62) / (ROWS - 1);
      return { x: (u - 0.5) * SIZE.w, y: (v - 0.5) * SIZE.h };
    };
    /** How far vertex `index` has moved from its flat position. */
    const shift = (index: number, f: Point): Point => {
      const col = index % COLS;
      const row = Math.floor(index / COLS);
      const border = col === 0 || row === 0 || col === COLS - 1 || row === ROWS - 1;
      // Destination inside the ball: border vertices stay near the rim so the silhouette is round.
      const h1 = GMath.hash(index * 7 + 3);
      const h2 = GMath.hash(index * 13 + 11);
      const radius = ball * (border ? 0.8 + 0.2 * h1 : 0.1 + 0.7 * h1);
      const angle = Math.atan2(f.y, f.x) + (h2 - 0.5) * (border ? 0.5 : 2.4) + TWIST;
      const t = local(index);
      // A smoothed sheet never gets perfectly flat again.
      const memory = border ? 0 : creased * 2.2 * (1 - amount);
      return { x: (Math.cos(angle) * radius - f.x) * t + (h1 - 0.5) * memory, y: (Math.sin(angle) * radius - f.y) * t + (h2 - 0.5) * memory };
    };

    const flats: Point[] = [];
    const shifts: Point[] = [];
    const points: Point[] = [];
    const amounts: number[] = [];
    for (let i = 0; i < count; i++) {
      flats.push(flat(i));
      shifts.push(shift(i, flats[i]));
      points.push({ x: centre.x + flats[i].x + shifts[i].x, y: centre.y + flats[i].y + shifts[i].y });
      amounts.push(local(i));
    }

    // Facets
    drawLayer(
      g,
      (layer) => {
        layer.lineJoin = "round";
        for (let row = 0; row < ROWS - 1; row++)
          for (let col = 0; col < COLS - 1; col++) {
            const i = row * COLS + col;
            const quad = [i, i + 1, i + COLS + 1, i + COLS];
            // Alternate the diagonal so the facets do not line up.
            const flip = (row + col) % 2 === 0;
            const triangles = flip
              ? [
                  [quad[0], quad[1], quad[2]],
                  [quad[0], quad[2], quad[3]],
                ]
              : [
                  [quad[0], quad[1], quad[3]],
                  [quad[1], quad[2], quad[3]],
                ];
            triangles.forEach((tri, n) => {
              const a = points[tri[0]];
              const b = points[tri[1]];
              const c = points[tri[2]];
              layer.beginPath();
              layer.moveTo(a.x, a.y);
              layer.lineTo(b.x, b.y);
              layer.lineTo(c.x, c.y);
              layer.closePath();
              const folded = Math.min(Math.max((amounts[tri[0]] + amounts[tri[1]] + amounts[tri[2]]) / 3, 0), 1);
              const noise = GMath.hash(i * 2 + n + 31);
              // On the ball a facet is lit by where it sits relative to a top-left light.
              const mx = ((a.x + b.x + c.x) / 3 - centre.x) / Math.max(ball, 1);
              const my = ((a.y + b.y + c.y) / 3 - centre.y) / Math.max(ball, 1);
              const facing = Math.min(Math.max((mx * 0.6 + my * 0.8) * 0.5 + 0.5, 0), 1);
              const lit = (0.12 + 0.5 * facing) * 0.55 + noise * 0.45 * (0.3 + contrast);
              // A smoothed sheet keeps a few faintly shaded facets.
              const residue = noise > 0.62 ? (creased * 0.07 * (noise - 0.62)) / 0.38 : 0;
              const dim = Math.min(Math.max(folded * lit * (0.5 + contrast), residue), 0.85);
              const color = PAPER.mixed(SHADOW, dim).css();
              layer.fillStyle = color;
              layer.fill();
              layer.strokeStyle = color;
              layer.lineWidth = 0.7;
              layer.stroke();
            });
          }
      },
      { shadow: { color: `rgba(0,0,0,${0.22 + 0.14 * amount})`, radius: 9 - 3 * amount, dy: 6 + 5 * amount } },
    );

    // Creases: fold lines read on the sheet; on the ball the facets take over.
    const strength = Math.max(amount * (1 - 0.75 * amount) * 2, creased * 0.3);
    if (strength > 0.01) {
      g.beginPath();
      for (let row = 0; row < ROWS; row++)
        for (let col = 0; col < COLS; col++) {
          const i = row * COLS + col;
          // Only some edges crease, picked by hash, so the pattern looks irregular.
          if (col < COLS - 1 && row > 0 && row < ROWS - 1 && GMath.hash(i * 5 + 1) > 0.5) {
            g.moveTo(points[i].x, points[i].y);
            g.lineTo(points[i + 1].x, points[i + 1].y);
          }
          if (row < ROWS - 1 && col > 0 && col < COLS - 1 && GMath.hash(i * 5 + 2) > 0.5) {
            g.moveTo(points[i].x, points[i].y);
            g.lineTo(points[i + COLS].x, points[i + COLS].y);
          }
          if (col < COLS - 1 && row < ROWS - 1 && GMath.hash(i * 5 + 3) > 0.55) {
            const flip = (row + col) % 2 === 0;
            const from = points[flip ? i : i + 1];
            const to = points[flip ? i + COLS + 1 : i + COLS];
            g.moveTo(from.x, from.y);
            g.lineTo(to.x, to.y);
          }
        }
      g.strokeStyle = hex(0x3a3840, 0.26 * Math.min(strength, 1));
      g.lineWidth = 0.6;
      g.stroke();
    }

    // Print: a header bar, then text lines of different lengths, carried along by the mesh.
    const mapped = (u: number, v: number): Point => {
      const x = u * (COLS - 1);
      const y = v * (ROWS - 1);
      const col = Math.min(Math.trunc(x), COLS - 2);
      const row = Math.min(Math.trunc(y), ROWS - 2);
      const fx = x - col;
      const fy = y - row;
      const i = row * COLS + col;
      const top = GMath.lerpP(shifts[i], shifts[i + 1], fx);
      const bottom = GMath.lerpP(shifts[i + COLS], shifts[i + COLS + 1], fx);
      const moved = GMath.lerpP(top, bottom, fy);
      return { x: centre.x + (u - 0.5) * SIZE.w + moved.x, y: centre.y + (v - 0.5) * SIZE.h + moved.y };
    };
    const fade = 1 - 0.6 * amount;
    const thin = 1 - 0.45 * amount;
    const rows: [number, number, number, boolean][] = [
      [0.12, 0.12, 0.52, true],
      [0.27, 0.12, 0.88, false],
      [0.35, 0.12, 0.82, false],
      [0.43, 0.12, 0.88, false],
      [0.51, 0.12, 0.6, false],
      [0.64, 0.12, 0.88, false],
      [0.72, 0.12, 0.76, false],
      [0.8, 0.12, 0.86, false],
      [0.88, 0.12, 0.44, false],
    ];
    g.lineCap = "round";
    g.lineJoin = "round";
    for (const [v, from, to, header] of rows) {
      g.beginPath();
      const segments = 18;
      for (let step = 0; step <= segments; step++) {
        const pt = mapped(from + ((to - from) * step) / segments, v);
        if (step === 0) g.moveTo(pt.x, pt.y);
        else g.lineTo(pt.x, pt.y);
      }
      g.strokeStyle = header ? alpha(Palette.indigo, 0.9 * fade) : hex(0x8c8a93, 0.55 * fade);
      g.lineWidth = (header ? 7 : 3) * thin;
      g.stroke();
    }
  };

  useMotionValueEvent(progress, "change", draw);
  useEffect(draw);

  /** Fingers (or the scripted pinch) are at `magnification` relative to where they started. */
  const pinchChanged = (magnification: number, scripted = false) => {
    if (!s.held) {
      s.held = true;
      progress.stop();
      s.base = clamp(progress.get(), 0, 1);
    }
    const raw = magnification < 1 ? s.base + (1 - magnification) * 1.7 : s.base - (magnification - 1) * 1.15;
    const next = raw > 1 ? 1 + rubberBand(raw - 1, 0.1) : raw < 0 ? -rubberBand(-raw, 0.05) : raw;
    s.creased = Math.max(s.creased, Math.min(next, 1));
    progress.set(next);
    s.target = next;
    // A crunch every eighth of the way.
    const step = Math.floor(next * 8);
    if (step !== s.crunch) {
      s.crunch = step;
      if (!scripted) haptics.tap("rigid");
    }
  };

  const settle = (crumpled: boolean, scripted = false) => {
    s.target = crumpled ? 1 : 0;
    if (crumpled) s.creased = 1;
    animate(progress, s.target, spring(ctx.n("response"), ctx.n("damping")));
    if (!scripted) haptics.tap(crumpled ? "medium" : "soft");
  };

  const pinchEnded = (scripted = false) => {
    if (!s.held) return;
    s.held = false;
    settle(progress.get() > 0.5, scripted);
  };

  const pinch = usePinch<HTMLDivElement>({
    onChange: (magnification) => {
      if (ghost.scripted && s.held) s.held = false;
      // `minimumScaleDelta: 0.02`
      if (!s.held && Math.abs(magnification - 1) < 0.02) return;
      ghost.touch();
      pinchChanged(magnification);
    },
    onEnd: () => {
      s.pinchEndedAt = performance.now();
      pinchEnded();
    },
  });

  /** A scripted pinch: squeeze in to crumple, and the next time spread out to smooth. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.held || pinch.active()) return;
      const closing = s.target < 0.5;
      const end = closing ? 0.52 : 1.75;
      ghost.run(async (g) => {
        const finished = await g.drag({ x: 1, y: 0 }, { x: end, y: 0 }, 0.8, (p) => pinchChanged(p.x, true));
        if (!finished) {
          // A real touch took over mid-pinch: leave the hold to it.
          return;
        }
        pinchEnded(true);
      });
    },
    { every: 2.3, delay: 0.5 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div
        ref={pinch.ref}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          pinch.handlers.down(e);
        }}
        onPointerMove={pinch.handlers.move}
        onPointerUp={pinch.handlers.up}
        onPointerCancel={pinch.handlers.up}
        onClick={() => {
          if (performance.now() - s.pinchEndedAt < 350 || pinch.active() || s.held) return;
          ghost.touch();
          settle(progress.get() < 0.5);
        }}
        style={{ position: "relative", width: STAGE.w, height: STAGE.h, flex: "none", touchAction: "none", cursor: "pointer" }}
      >
        <canvas ref={canvas.ref} style={canvas.style} />
      </div>
      <DemoHint ctx={ctx} en="Pinch to crumple, spread to smooth (or tap)" zh="捏合揉皱，张开抹平（也可点击）" />
    </div>
  );
}
