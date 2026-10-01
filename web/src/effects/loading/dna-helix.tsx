/** loading.dna-helix · DNA 双螺旋 (Loading+DNAHelix.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Palette, fonts, spring, white, type DemoProps } from "../../kit";
import { previewFps, primary } from "./shared";
import { Caption, TimeCanvas, centerColumn, css, mixColor, type RGB } from "./round2";

const W = 280;
const H = 136;

const strandColor = (strand: number, share: number): RGB =>
  strand === 0 ? mixColor(Palette.mint, Palette.sky, share) : mixColor(Palette.violet, Palette.pink, share);

interface Bead {
  x: number;
  y: number;
  depth: number;
  radius: number;
  color: RGB;
  opacity: number;
}

/** Halos of the near beads; this canvas is blurred with CSS (canvas `filter` is missing in Safari). */
function drawHalos(g: CanvasRenderingContext2D, phase: number, seconds: number, pairs: number, twist: number, pulse: boolean) {
  const pulseHead = ((seconds / 2.2) % 1) * 1.5 - 0.25;
  for (let index = 0; index < pairs; index++) {
    const share = pairs > 1 ? index / (pairs - 1) : 0.5;
    const angle = 2 * Math.PI * (phase + share * twist);
    const distance = (share - pulseHead) / 0.13;
    const bump = pulse ? Math.exp(-distance * distance) : 0;
    const taper = 0.82 + 0.18 * Math.sin(Math.PI * share);
    for (let strand = 0; strand < 2; strand++) {
      const a = angle + strand * Math.PI;
      const depth = Math.cos(a);
      if (depth <= 0.2) continue;
      const r = (3 + 3.5 * ((depth + 1) / 2)) * (1 + 0.35 * bump) * 1.5;
      g.beginPath();
      g.arc((W - 236) / 2 + 236 * share, H / 2 + 40 * taper * Math.sin(a), r, 0, Math.PI * 2);
      g.fillStyle = css(strandColor(strand, share), 0.45 * depth);
      g.fill();
    }
  }
}

function draw(g: CanvasRenderingContext2D, phase: number, seconds: number, pairs: number, twist: number, pulse: boolean) {
  const length = 236;
  const radius = 40;
  const midY = H / 2;
  const startX = (W - length) / 2;
  const pulseHead = ((seconds / 2.2) % 1) * 1.5 - 0.25;

  const beads: Bead[] = [];
  const rungs: { from: [number, number]; to: [number, number]; alpha: number; share: number }[] = [];
  for (let index = 0; index < pairs; index++) {
    const share = pairs > 1 ? index / (pairs - 1) : 0.5;
    const angle = 2 * Math.PI * (phase + share * twist);
    const x = startX + length * share;
    const distance = (share - pulseHead) / 0.13;
    const bump = pulse ? Math.exp(-distance * distance) : 0;
    const taper = 0.82 + 0.18 * Math.sin(Math.PI * share);
    const ends: [number, number][] = [];
    for (let strand = 0; strand < 2; strand++) {
      const a = angle + strand * Math.PI;
      const depth = Math.cos(a);
      const y = midY + radius * taper * Math.sin(a);
      const near = (depth + 1) / 2;
      const r = (3 + 3.5 * near) * (1 + 0.35 * bump);
      ends.push([x, y]);
      beads.push({ x, y, depth, radius: r, color: strandColor(strand, share), opacity: 0.35 + 0.65 * near });
    }
    const facing = Math.abs(Math.sin(angle));
    rungs.push({ from: ends[0], to: ends[1], alpha: 0.06 + 0.16 * facing + 0.45 * bump, share });
  }

  g.lineCap = "round";
  const segments = 72;
  for (let strand = 0; strand < 2; strand++) {
    let previous: [number, number] | null = null;
    for (let step = 0; step <= segments; step++) {
      const share = step / segments;
      const a = 2 * Math.PI * (phase + share * twist) + strand * Math.PI;
      const taper = 0.82 + 0.18 * Math.sin(Math.PI * share);
      const point: [number, number] = [startX + length * share, midY + radius * taper * Math.sin(a)];
      if (previous) {
        const near = (Math.cos(a) + 1) / 2;
        g.beginPath();
        g.moveTo(previous[0], previous[1]);
        g.lineTo(point[0], point[1]);
        g.strokeStyle = css(strandColor(strand, share), 0.12 + 0.38 * near);
        g.lineWidth = 1 + 2 * near;
        g.stroke();
      }
      previous = point;
    }
  }

  for (const rung of rungs) {
    const a = Math.min(rung.alpha, 1);
    let style: string | CanvasGradient = css(strandColor(0, rung.share), a);
    if (Math.hypot(rung.to[0] - rung.from[0], rung.to[1] - rung.from[1]) > 0.01) {
      const grad = g.createLinearGradient(rung.from[0], rung.from[1], rung.to[0], rung.to[1]);
      grad.addColorStop(0, css(strandColor(0, rung.share), a));
      grad.addColorStop(1, css(strandColor(1, rung.share), a));
      style = grad;
    }
    g.beginPath();
    g.moveTo(rung.from[0], rung.from[1]);
    g.lineTo(rung.to[0], rung.to[1]);
    g.strokeStyle = style;
    g.lineWidth = 1.5;
    g.stroke();
  }

  for (const bead of [...beads].sort((a, b) => a.depth - b.depth)) {
    const r = bead.radius;
    g.beginPath();
    g.arc(bead.x, bead.y, r, 0, Math.PI * 2);
    g.fillStyle = css(bead.color, bead.opacity);
    g.fill();
    if (bead.depth > 0) {
      const h = r * 0.36;
      g.beginPath();
      g.arc(bead.x - r * 0.42, bead.y - r * 0.42, h / 2, 0, Math.PI * 2);
      g.fillStyle = white(0.75 * bead.depth);
      g.fill();
    }
  }
}

export default function DNAHelix({ ctx }: DemoProps) {
  const zh = ctx.lang === "zh";
  const period = Math.max(ctx.n("period"), 0.2);
  const pairs = Math.max(ctx.i("pairs"), 2);
  const twist = ctx.n("twist");
  const pulse = ctx.b("pulse");
  const phase = useRef(0);
  return (
    <div style={centerColumn(22)}>
      <div style={{ position: "relative", width: W, height: H, flex: "none" }}>
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          draw={(g, seconds, dt) => {
            phase.current += dt / period;
            draw(g, phase.current, seconds, pairs, twist, pulse);
          }}
        />
        <TimeCanvas
          width={W}
          height={H}
          fps={previewFps(ctx.isPreview)}
          style={{ position: "absolute", inset: 0, filter: "blur(6px)", mixBlendMode: "screen" }}
          draw={(g, seconds) => drawHalos(g, phase.current, seconds, pairs, twist, pulse)}
        />
      </div>
      <Caption title={zh ? "正在测序样本" : "Sequencing sample"} detail={zh ? "比对 3.2 亿个碱基对…" : "Aligning 320 million base pairs…"} />
      <BaseTicker />
    </div>
  );
}

const BASES = ["A", "T", "G", "C"];
const COLORS = [Palette.mint, Palette.sky, Palette.violet, Palette.pink];

/** Four base letters; the one being "read" lights up in turn. */
function BaseTicker() {
  const [step, setStep] = useState(() => Math.floor(Date.now() / 275));
  useEffect(() => {
    const id = window.setInterval(() => setStep(Math.floor(Date.now() / 275)), 275);
    return () => clearInterval(id);
  }, []);
  const active = (step * 7 + Math.floor(step / 3) * 5) % 4;
  return (
    <div style={{ display: "flex", gap: 8 }}>
      {BASES.map((base, index) => {
        const lit = index === active;
        return (
          <motion.div
            key={base}
            animate={{ scale: lit ? 1.08 : 1 }}
            transition={spring(0.25, 0.6)}
            style={{
              width: 26,
              height: 24,
              borderRadius: 8,
              display: "grid",
              placeItems: "center",
              fontFamily: fonts.mono,
              fontSize: 12,
              fontWeight: 700,
              background: lit ? COLORS[index] : primary(0.06),
              color: lit ? "#ffffff" : Palette.secondaryLabel,
              transition: "background 0.18s, color 0.18s",
            }}
          >
            {base}
          </motion.div>
        );
      })}
    </div>
  );
}
