/** text.glitch-in · 故障入场 (Text+GlitchIn.swift) */
import { useRef } from "react";
import { DemoHint, Palette, alpha, fonts, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { curve, now, prepareCanvas, resolveColor, useFrame } from "./_fx";

export default function GlitchIn({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const host = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const start = useRef(now());
  const runs = useRef(0);
  const secondary = useRef<{ key: string; color: string } | null>(null);
  const dark = ctx.scheme === "dark";
  const zh = ctx.lang === "zh";
  const duration = Math.max(ctx.n("duration"), 0.1);
  const count = Math.max(ctx.i("slices"), 1);
  const split = ctx.n("split");
  const idle = ctx.b("idle");

  const replay = () => {
    runs.current += 1;
    start.current = now();
  };
  useAutoplay(ctx.isPreview, replay, { every: 3.4, delay: 3.0, intro: false });

  useFrame(() => {
    const el = canvas.current;
    const box = host.current;
    if (!el || !box) return;
    const w = box.offsetWidth;
    const h = box.offsetHeight;
    if (!w || !h) return;
    const g = prepareCanvas(el, w, h);
    if (!g) return;
    if (secondary.current?.key !== ctx.scheme) secondary.current = { key: ctx.scheme, color: resolveColor(el, Palette.secondaryLabel) };
    const time = now() - start.current;
    /** Deterministic noise in 0..<1, different on every run. */
    const noise = (a: number, b: number) => {
      const v = Math.sin(a * 127.1 + b * 311.7 + runs.current * 74.7) * 43758.5453;
      return v - Math.floor(v);
    };

    const lines = zh ? ["信号", "已锁定"] : ["SIGNAL", "LOCKED"];
    const fontSize = zh ? 66 : 62;
    const font = `900 ${fontSize}px ${fonts.text}`;
    // Additive RGB on dark, subtractive CMY on light: aligned channels give white or black text.
    const channelColors = dark ? ["rgb(255 0 0)", "rgb(0 255 0)", "rgb(0 0 255)"] : ["rgb(0 255 255)", "rgb(255 0 255)", "rgb(255 255 0)"];
    g.font = font;
    g.textAlign = "center";
    g.textBaseline = "middle";
    const widths = lines.map((line) => g.measureText(line).width);
    const lineHeight = fontSize * 1.193 * 0.96;
    const block = { w: Math.max(...widths), h: lineHeight * lines.length };
    const center = { x: w / 2, y: h / 2 - 14 };
    const top = center.y - block.h / 2 - 4;
    const height = block.h + 8;
    const frame = Math.floor(time * 24);

    // The confirming jolt right after the last slice locks, and the idle glitches later on.
    const jolt = time > duration + 0.12 && time < duration + 0.2;
    const idleClock = time - duration - 2.2;
    const idleBurst = idle && idleClock > 0 && idleClock % 2.6 < 0.14;
    const idleRound = Math.floor(Math.max(idleClock, 0) / 2.6);

    // Uneven slice heights.
    const weights = Array.from({ length: count }, (_, i) => 0.5 + noise(i, 999));
    const total = weights.reduce((a, b) => a + b, 0);
    let y = top;
    for (let index = 0; index < count; index++) {
      const sliceHeight = height * (weights[index] / total);
      const band = { y, h: sliceHeight + 0.5 };
      y += sliceHeight;

      const order = (index + noise(index, 500) * 2.2 - 1.1) / Math.max(count - 1, 1);
      const lock = duration * (0.3 + 0.7 * curve.clamp01(order));
      let dx = 0;
      let spread = 0;
      let visible = true;
      let flashAlpha = 0;
      if (time < lock) {
        const u = time / lock;
        const amplitude = 46 * Math.pow(1 - u, 0.7) + 4;
        dx = (noise(index, frame) * 2 - 1) * amplitude;
        spread = split * (0.4 + 0.6 * (1 - u)) * (noise(index, frame + 13) > 0.7 ? 2.2 : 1);
        visible = noise(index, frame + 77) < 0.3 + 0.7 * u;
      } else {
        const u = curve.clamp01((time - lock) / 0.18);
        const decay = (1 - u) * (1 - u);
        dx = -7 * decay * Math.sin(u * Math.PI * 2) * (index % 2 === 0 ? 1 : -1);
        spread = split * 0.35 * decay;
        flashAlpha = time - lock < 0.16 ? 1 - (time - lock) / 0.16 : 0;
      }
      if (jolt) {
        dx += 5;
        spread = split * 0.5;
      }
      if (idleBurst && (index === Math.floor(noise(idleRound, 31) * count) || index === Math.floor(noise(idleRound, 57) * count))) {
        dx = (noise(index, frame + 5) * 2 - 1) * 16;
        spread = split * 0.8;
      }

      if (visible) {
        g.save();
        g.beginPath();
        g.rect(0, band.y, w, band.h);
        g.clip();
        g.globalCompositeOperation = dark ? "lighter" : "multiply";
        const offsets = [dx - spread, dx, dx + spread];
        lines.forEach((line, li) => {
          const lineY = center.y - block.h / 2 + lineHeight * (li + 0.5);
          for (let channel = 0; channel < 3; channel++) {
            g.fillStyle = channelColors[channel];
            g.fillText(line, center.x + offsets[channel], lineY);
          }
        });
        g.restore();
      }
      if (flashAlpha > 0) {
        g.fillStyle = alpha(Palette.mint, 0.9 * flashAlpha);
        g.fillRect(center.x - block.w / 2 - 14, band.y + band.h - 1, block.w + 28, 1.5);
      }
    }

    // Stray noise bars while the signal is unstable.
    if (time < duration) {
      const fade = 1 - time / duration;
      for (let bar = 0; bar < 4; bar++) {
        if (!(noise(bar + 40, frame) < 0.25 + 0.5 * fade)) continue;
        const barWidth = 30 + 130 * noise(bar + 60, frame);
        const barX = (w - barWidth) * noise(bar + 80, frame);
        const barY = top - 14 + (height + 28) * noise(bar + 100, frame);
        g.fillStyle = alpha(bar % 2 === 0 ? Palette.red : Palette.sky, 0.55 * fade);
        g.fillRect(barX, barY, barWidth, 2 + 4 * noise(bar + 120, frame));
      }
    }

    // Status line.
    const locked = time >= duration;
    const label = locked
      ? zh ? "● 已锁定 100%" : "● LOCKED 100%"
      : (zh ? "○ 搜索信号 " : "○ SEARCHING ") + String(Math.floor((time / duration) * 100)).padStart(2, "0") + "%";
    g.globalAlpha = locked ? 1 : Math.floor(time * 8) % 2 === 0 ? 0.9 : 0.45;
    g.fillStyle = locked ? (dark ? "#21D4A8" : "#0B8F6E") : secondary.current.color;
    g.font = `700 13px ${fonts.mono}`;
    g.fillText(label, center.x, top + height + 22);
    g.globalAlpha = 1;
  }, ctx.isPreview ? 30 : undefined);

  return (
    <div
      ref={host}
      onClick={() => {
        haptics.tap("rigid");
        replay();
      }}
      style={{ position: "absolute", inset: 0, cursor: "pointer" }}
    >
      <canvas ref={canvas} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block" }} />
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Tap to replay" zh="点击重播" />
      </div>
    </div>
  );
}
