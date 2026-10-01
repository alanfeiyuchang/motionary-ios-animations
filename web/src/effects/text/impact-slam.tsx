/** text.impact-slam · 重击落字 (Text+ImpactSlam.swift) */
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, useAutoplay, useClock, useHaptics, type DemoProps } from "../../kit";
import { curve, now } from "./_fx";

const FALL = 0.16;
const TILTS = [-2, 1.2, 1.6, -1.4];

interface Pose {
  scale: number;
  squash: number;
  blur: number;
  opacity: number;
  x: number;
  y: number;
  flash: number;
  /** Time since this word's impact, null before it. */
  sinceImpact: number | null;
}

export default function ImpactSlam({ ctx }: DemoProps) {
  const haptics = useHaptics();
  useClock(true, ctx.isPreview ? 30 : undefined);
  const [start, setStart] = useState(() => now());
  const buzz = useRef<number[]>([]);
  useEffect(() => () => buzz.current.forEach((t) => window.clearTimeout(t)), []);
  const zh = ctx.lang === "zh";
  const lines = zh
    ? [["字字", "落地"], ["掷地", "有声"]]
    : [["MAKE", "IT"], ["LAND", "HARD"]];
  const count = 4;
  const interval = ctx.n("interval");
  const drop = ctx.n("drop");
  const shake = ctx.n("shake");
  const ring = ctx.b("ring");
  const time = now() - start;

  const replay = (byHand: boolean) => {
    setStart(now());
    buzz.current.forEach((t) => window.clearTimeout(t));
    buzz.current = [];
    if (!byHand || ctx.isPreview) return;
    for (let index = 0; index < count; index++) {
      buzz.current.push(window.setTimeout(() => haptics.tap(index === count - 1 ? "heavy" : "rigid"), (FALL + index * interval) * 1000));
    }
  };
  useAutoplay(ctx.isPreview, () => replay(false), { every: interval * 4 + 2.4, delay: 2.6, intro: false });

  const pose = (index: number): Pose => {
    const local = time - index * interval;
    const p: Pose = { scale: 1, squash: 0, blur: 0, opacity: 1, x: 0, y: 0, flash: 0, sinceImpact: null };
    if (local < 0) {
      p.opacity = 0;
      return p;
    }
    if (local < FALL) {
      // Falling: accelerating toward the page.
      const u = local / FALL;
      p.scale = drop + (1 - drop) * u * u;
      p.blur = 10 * (1 - u);
      p.opacity = Math.min(u * 2.5, 1);
      return p;
    }
    const since = local - FALL;
    p.sinceImpact = since;
    p.squash = 0.1 * Math.exp(-since * 13) * Math.cos(since * 36);
    p.flash = since < 0.08 ? 1 - since / 0.08 : 0;
    // Jolts from every later impact.
    for (let other = index + 1; other < count; other++) {
      const hit = time - (other * interval + FALL);
      if (!(hit >= 0 && hit < 0.6)) continue;
      const strength = shake * (other === count - 1 ? 1.7 : 1);
      const wave = Math.exp(-hit * 12) * Math.cos(hit * 58);
      const side = (other + index) % 2 === 0 ? 1 : -1;
      p.x += strength * 0.45 * wave * side;
      p.y += strength * wave * (Math.floor(other / 2) >= Math.floor(index / 2) ? -1 : 1);
    }
    return p;
  };

  const size = zh ? 62 : 56;
  return (
    <div onClick={() => replay(true)} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: -2, paddingBottom: 16 }}>
        {lines.map((row, r) => (
          <div key={r} style={{ display: "flex", gap: 14, marginTop: r ? -2 : 0 }}>
            {row.map((text, column) => {
              const index = r * 2 + column;
              const p = pose(index);
              const last = index === count - 1;
              const since = p.sinceImpact;
              const u = since !== null ? since / 0.35 : 1;
              return (
                <div
                  key={column}
                  style={{
                    position: "relative",
                    whiteSpace: "pre",
                    fontSize: size,
                    lineHeight: `${Math.round(size * 1.193)}px`,
                    fontWeight: 900,
                    color: Palette.label,
                    opacity: p.opacity,
                    filter: p.blur > 0.01 ? `blur(${p.blur.toFixed(2)}px)` : undefined,
                    transform: `translate(${p.x.toFixed(2)}px, ${p.y.toFixed(2)}px) rotate(${TILTS[index % TILTS.length]}deg) scale(${p.scale * (1 + p.squash * 0.6)}, ${p.scale * (1 - p.squash)})`,
                  }}
                >
                  {ring && since !== null && since < 0.35 && (
                    <div
                      style={{
                        position: "absolute",
                        left: -10,
                        right: -10,
                        top: 0,
                        bottom: 0,
                        borderRadius: 999,
                        border: `${3 * (1 - u) + 0.5}px solid ${last ? Palette.coral : Palette.label}`,
                        opacity: 0.55 * (1 - u),
                        transform: `scale(${(0.4 + 1.1 * curve.easeOutCubic(u)) * (last ? 1.35 : 1)})`,
                        pointerEvents: "none",
                      }}
                    />
                  )}
                  <span
                    style={{
                      position: "relative",
                      display: "inline-block",
                      filter: p.flash > 0 ? `brightness(${1 + p.flash * 0.35})` : undefined,
                      ...(last ? { backgroundImage: Palette.sunset, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent", WebkitTextFillColor: "transparent" } : null),
                    }}
                  >
                    {text}
                  </span>
                </div>
              );
            })}
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Tap to slam again" zh="点击再砸一次" />
      </div>
    </div>
  );
}
