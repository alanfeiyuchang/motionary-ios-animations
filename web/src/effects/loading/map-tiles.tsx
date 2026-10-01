/** loading.map-tiles · 地图瓦片加载 (Loading+MapTiles.swift) */
import { useMemo, useRef } from "react";
import { DemoHint, Palette, black, useHaptics, white, type DemoProps, type Scheme } from "../../kit";
import { previewFps } from "./shared";
import { LoadingCurve, TimeCanvas, blurFill, css, labelRGB, roundRect } from "./round2";

const SIDE = 260;
const LEAD = 0.4;
const FADE_IN = 0.22;
const HOLD = 0.38;
const SHARPEN = 0.3;
const PIN_HOLD = 2.0;
const PIN_TIME = 0.9;
const FADE_OUT = 0.35;
const pinStart = (tiles: number, stagger: number) => LEAD + (tiles - 1) * stagger + HOLD + SHARPEN;
const totalTime = (tiles: number, stagger: number) => pinStart(tiles, stagger) + PIN_TIME + PIN_HOLD + FADE_OUT;

/** Rank of every tile (index = row × n + col) in the loading order. */
function makeRanks(n: number, order: number): number[] {
  const count = n * n;
  const mid = (n - 1) / 2;
  const keyed = Array.from({ length: count }, (_, index) => {
    const col = index % n;
    const row = Math.floor(index / n);
    let key: number;
    if (order === 1) key = index;
    else if (order === 2) key = LoadingCurve.hash(index * 7 + n);
    else {
      // Ring by ring, clockwise from twelve o'clock.
      const dx = col - mid;
      const dy = row - mid;
      const ring = Math.ceil(Math.max(Math.abs(dx), Math.abs(dy)) + 0.01);
      let turn = Math.atan2(dx, -dy) / (2 * Math.PI);
      if (turn < 0) turn += 1;
      key = ring + turn * 0.999;
    }
    return { index, key };
  });
  keyed.sort((a, b) => a.key - b.key || a.index - b.index);
  const ranks = new Array<number>(count).fill(0);
  keyed.forEach((item, rank) => (ranks[item.index] = rank));
  return ranks;
}

const OFFSETS = [
  [-40, -30],
  [-170, -60],
  [-110, -190],
  [-10, -170],
];
const COLORS = {
  light: { land: "#F1EFE7", block: "#E6E2D6", water: "#9CCBF2", park: "#BFE3AC", road: "#FFFFFF", avenue: "#FFD98A", sheet: "#DCDCE4" },
  dark: { land: "#1D262B", block: "#232E34", water: "#1B4E72", park: "#235039", road: "#3B4950", avenue: "#8C6B2B", sheet: "#26262B" },
};

/** A procedural city map, larger than the frame; `variant` picks which part is visible. */
function drawArt(g: CanvasRenderingContext2D, variant: number, scheme: Scheme) {
  const c = COLORS[scheme];
  const [ox, oy] = OFFSETS[((variant % OFFSETS.length) + OFFSETS.length) % OFFSETS.length];
  g.fillStyle = c.land;
  g.fillRect(0, 0, SIDE, SIDE);
  g.save();
  g.translate(ox, oy);
  const extent = 460;
  g.fillStyle = c.block;
  for (let row = 0; row < 10; row++) {
    for (let col = 0; col < 10; col++) {
      if ((row * 3 + col * 5) % 4 === 0) continue;
      g.beginPath();
      roundRect(g, col * 46 + 6, row * 46 + 6, 34, 34, 4);
      g.fill();
    }
  }
  g.fillStyle = c.park;
  for (const [x, y, w, h] of [
    [96, 52, 82, 80],
    [282, 190, 80, 126],
    [52, 282, 126, 80],
  ]) {
    g.beginPath();
    roundRect(g, x, y, w, h, 12);
    g.fill();
  }
  const river = () => {
    g.beginPath();
    g.moveTo(extent + 20, 40);
    g.bezierCurveTo(250, 90, 260, 330, -20, 400);
  };
  g.lineCap = "round";
  river();
  g.strokeStyle = c.water;
  g.lineWidth = 34;
  g.stroke();
  river();
  g.setLineDash([10, 14]);
  g.strokeStyle = white(0.18);
  g.lineWidth = 2;
  g.stroke();
  g.setLineDash([]);

  g.beginPath();
  g.lineCap = "butt";
  for (let line = 0; line <= 10; line++) {
    const at = line * 46;
    g.moveTo(at, -20);
    g.lineTo(at, extent + 20);
    g.moveTo(-20, at);
    g.lineTo(extent + 20, at);
  }
  g.strokeStyle = c.road;
  g.lineWidth = 4.5;
  g.stroke();

  const avenues = () => {
    g.beginPath();
    g.moveTo(-20, 120);
    g.bezierCurveTo(160, 110, 300, 320, extent + 20, 300);
    g.moveTo(210, -20);
    g.lineTo(150, extent + 20);
  };
  g.lineCap = "round";
  avenues();
  g.strokeStyle = c.avenue;
  g.lineWidth = 8;
  g.stroke();
  avenues();
  g.strokeStyle = white(0.35);
  g.lineWidth = 1;
  g.stroke();
  g.restore();
}

/** The sharp art and its blurred copy for one variant, at the canvas' pixel ratio. */
function makeArt(variant: number, scheme: Scheme, blur: number, k: number) {
  const px = Math.round(SIDE * k);
  const sharp = document.createElement("canvas");
  sharp.width = sharp.height = px;
  const g = sharp.getContext("2d")!;
  g.scale(k, k);
  drawArt(g, variant, scheme);

  const soft = document.createElement("canvas");
  soft.width = soft.height = px;
  const b = soft.getContext("2d")!;
  if (blur <= 0.05) {
    b.drawImage(sharp, 0, 0);
  } else if (typeof (b as { filter?: unknown }).filter === "string") {
    b.filter = `blur(${blur * k}px)`;
    b.drawImage(sharp, 0, 0);
  } else {
    // No canvas filter (Safari): approximate the Gaussian by scaling down and back up, twice.
    const small = document.createElement("canvas");
    const size = Math.max(4, Math.round(SIDE / (blur * 0.9)));
    small.width = small.height = size;
    const s = small.getContext("2d")!;
    s.imageSmoothingQuality = "high";
    s.drawImage(sharp, 0, 0, size, size);
    b.imageSmoothingQuality = "high";
    b.drawImage(small, 0, 0, px, px);
  }
  return { sharp, soft };
}

export default function MapTiles({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const n = Math.min(Math.max(ctx.i("grid"), 2), 8);
  const stagger = Math.max(ctx.n("stagger"), 0.005);
  const order = ctx.i("order");
  const blur = ctx.n("blur");
  const ranks = useMemo(() => makeRanks(n, order), [n, order]);
  const total = totalTime(n * n, stagger);
  const started = useRef<number | null>(null);
  const area = useRef(0);
  const art = useRef<{ key: string; sharp: HTMLCanvasElement; soft: HTMLCanvasElement } | null>(null);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={() => {
          haptics.tap();
          area.current += 1;
          started.current = null;
        }}
        style={{ position: "relative", width: SIDE, height: SIDE, borderRadius: 26, overflow: "hidden", boxShadow: `0 9px 32px ${black(0.14)}`, flex: "none" }}
      >
        <TimeCanvas
          width={SIDE}
          height={SIDE}
          fps={previewFps(ctx.isPreview)}
          draw={(g, seconds, _dt, canvas) => {
            if (started.current === null) started.current = seconds;
            const raw = Math.max(seconds - started.current, 0);
            const lap = Math.floor(raw / total);
            const elapsed = raw - lap * total;
            const variant = area.current + lap;
            const k = canvas.width / SIDE;
            const key = `${variant % OFFSETS.length}-${ctx.scheme}-${blur}-${k}`;
            if (!art.current || art.current.key !== key) art.current = { key, ...makeArt(variant, ctx.scheme, blur, k) };
            const pinTime = elapsed - pinStart(n * n, stagger);
            const out = 1 - LoadingCurve.smoothstep((elapsed - (total - FADE_OUT)) / FADE_OUT);

            // The empty map: a grey sheet with the tile grid on it.
            g.fillStyle = COLORS[ctx.scheme].sheet;
            g.fillRect(0, 0, SIDE, SIDE);
            const tile = SIDE / n;
            g.beginPath();
            for (let line = 1; line < n; line++) {
              const at = line * tile;
              g.moveTo(at, 0);
              g.lineTo(at, SIDE);
              g.moveTo(0, at);
              g.lineTo(SIDE, at);
            }
            g.strokeStyle = css(labelRGB(canvas), 0.09);
            g.lineWidth = 1;
            g.stroke();

            // Tile edges snapped to device pixels, so neighbouring tiles meet without seams.
            const edge = (i: number) => Math.round(i * tile * k) / k;
            const levels = ranks.map((rank) => {
              const start = LEAD + rank * stagger;
              return {
                low: LoadingCurve.smoothstep((elapsed - start) / FADE_IN),
                sharp: LoadingCurve.smoothstep((elapsed - start - HOLD) / SHARPEN),
              };
            });
            const paint = (image: HTMLCanvasElement, pick: (l: { low: number; sharp: number }) => number) => {
              for (let index = 0; index < n * n; index++) {
                const a = pick(levels[index]) * out;
                if (a <= 0.001) continue;
                const x = edge(index % n);
                const y = edge(Math.floor(index / n));
                const w = edge((index % n) + 1) - x;
                const h = edge(Math.floor(index / n) + 1) - y;
                g.globalAlpha = a;
                g.drawImage(image, x * k, y * k, w * k, h * k, x, y, w, h);
              }
              g.globalAlpha = 1;
            };
            paint(art.current.soft, (l) => l.low);
            paint(art.current.sharp, (l) => l.sharp);
            for (let index = 0; index < n * n; index++) {
              const alpha = levels[index].low * (1 - levels[index].sharp);
              if (alpha <= 0.001) continue;
              g.strokeStyle = white(0.55 * alpha * out);
              g.lineWidth = 1;
              g.strokeRect((index % n) * tile + 0.5, Math.floor(index / n) * tile + 0.5, tile - 0.5, tile - 0.5);
            }

            // The pin, its shadow and its landing ring.
            if (pinTime >= 0) {
              const t = pinTime;
              const DROP = 150;
              const FIRST = 0.18;
              const height = DROP * Math.exp(-5 * t) * Math.abs(Math.cos((Math.PI * t) / (2 * FIRST)));
              const near = 1 - Math.min(height / DROP, 1);
              const squash = 0.18 * Math.exp(-Math.pow((t - FIRST) / 0.05, 2));
              const ring = (t - FIRST) / 0.6;
              const c = SIDE / 2;
              g.save();
              g.globalAlpha = Math.min(t / 0.08, 1) * out;
              if (ring > 0 && ring < 1) {
                g.save();
                g.translate(c, c);
                g.scale(ring * 0.9 + 0.1, 0.42 * (ring * 0.9 + 0.1));
                g.beginPath();
                g.arc(0, 0, 33, 0, Math.PI * 2);
                g.strokeStyle = css(Palette.red, 0.55 * (1 - ring));
                g.lineWidth = 2;
                g.stroke();
                g.restore();
              }
              blurFill(g, k, black(0.1 + 0.2 * near), 4 - 2.5 * near, () => g.ellipse(c, c, (30 - 12 * near) / 2, (10 - 4 * near) / 2, 0, 0, Math.PI * 2));

              g.translate(c, c - height);
              g.scale(1 + squash * 0.7, 1 - squash);
              const r = 14;
              const fill = g.createLinearGradient(0, -38, 0, 0);
              fill.addColorStop(0, "#FF6B6B");
              fill.addColorStop(1, Palette.red);
              g.beginPath();
              g.moveTo(0, 0);
              g.quadraticCurveTo(-r * 0.25, -r * 0.75, -r * 0.87, -24 + r * 0.5);
              g.arc(0, -24, r, (150 * Math.PI) / 180, (390 * Math.PI) / 180, false);
              g.quadraticCurveTo(r * 0.25, -r * 0.75, 0, 0);
              g.closePath();
              g.shadowColor = css(Palette.red, 0.35);
              g.shadowBlur = 12 * k;
              g.shadowOffsetY = 3 * k;
              g.fillStyle = fill;
              g.fill();
              g.shadowColor = "transparent";
              g.beginPath();
              g.arc(0, -24, 5.5, 0, Math.PI * 2);
              g.fillStyle = "#fff";
              g.fill();
              g.restore();
            }
          }}
        />
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap to reload the map" zh="点击重新加载地图" />
    </div>
  );
}
