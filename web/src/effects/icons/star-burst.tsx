/** icons.star-burst · 星标迸发 (Icons+StarBurst.swift) */
import { useState } from "react";
import { DemoHint, NumericText, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Item, Stage, Svg, Z, roundedPolygon, scaleAt, sparklePath, useIconNow, useLater, usePlayhead, type Pt } from "./_time-kit";

const ON = 1.1;
const OFF = 0.5;
const BURST = 0.14;
const ORIGIN = 62;

export function starPath(outer: number): string {
  const pts: Pt[] = [];
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? outer : outer * 0.5;
    const a = -Math.PI / 2 + (i * Math.PI) / 5;
    pts.push([r * Math.cos(a), r * Math.sin(a)]);
  }
  return roundedPolygon(pts, (i) => (i % 2 === 0 ? outer * 0.13 : outer * 0.06));
}
const STAR = starPath(56);
const STAR_OUTLINE = starPath(53);

export default function StarBurst({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const play = usePlayhead(false);
  const [count, setCount] = useState(128);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const on = play.isOn;

  const toggle = (scripted = false) => {
    const next = play.toggle(ON, OFF);
    setCount((c) => c + (next ? 1 : -1));
    if (next) {
      haptics.tap("medium");
      later(0.96, scripted, (h) => h.tap("soft"));
    } else {
      haptics.selection();
    }
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 1.9 });

  const spin = ctx.n("spin");
  const rays = Math.max(ctx.i("rays"), 2);
  const distance = ctx.n("distance");
  const damping = ctx.n("damping");

  let scale = 1;
  let rotation = 0;
  let lift = 0;
  let squash = 0;
  let fill = 0;
  let flash = 0;
  if (on) {
    const wind = IC.easeOut(IC.seg(t, 0, 0.1));
    const pop = IC.spring(t - 0.1, 0.42, damping);
    const turn = IC.spring(t - 0.1, 0.6, Math.min(damping + 0.27, 1));
    scale = t < 0.1 ? 1 - 0.28 * wind : 0.72 + 0.28 * pop;
    rotation = t < 0.1 ? -18 * wind : -18 + (spin + 18) * turn;
    fill = IC.seg(t, 0.08, 0.2);
    flash = IC.seg(t, 0.08, 0.13) * (1 - IC.seg(t, 0.13, 0.45));
    lift = 8 * IC.bump(IC.seg(t, 0.74, 0.96));
    squash = 0.07 * IC.bump(IC.seg(t, 0.94, 1.1));
  } else {
    const dip = IC.easeOut(IC.seg(t, 0, 0.1));
    const back = IC.spring(t - 0.1, 0.35, 0.55);
    scale = t < 0.1 ? 1 - 0.16 * dip : 0.84 + 0.16 * back;
    rotation = -72 * IC.easeInOut(IC.seg(t, 0, 0.42));
    fill = 1 - IC.seg(t, 0, 0.16);
  }

  const ringP = on ? IC.seg(t, 0.1, 0.46) : 0;
  const ringE = IC.easeOut(ringP);
  const ringD = 64 + 120 * ringE;

  const sparkle = (x: number, y: number, size: number, delay: number) => {
    const p = IC.seg(t, delay, delay + 0.5);
    return (
      <Svg key={delay} w={size} h={size} tf={`translate(${x}px, ${y}px) rotate(${60 * p}deg) scale(${IC.bump(p)})`}>
        <path d={sparklePath(size / 2)} fill={hex(0xffc83d)} />
      </Svg>
    );
  };

  return (
    <Stage gap={8}>
      <Z w={250} h={216} onClick={() => toggle()}>
        <Item
          w={200}
          h={200}
          tf={`translateY(4px) scale(${0.7 + 0.3 * scale})`}
          o={0.5 * fill + 0.5 * flash}
          style={{ borderRadius: "50%", background: `radial-gradient(circle, ${hex(0xffc247, 0.55)} 8px, ${hex(0xffc247, 0)} 100px)` }}
        />
        <Svg w={ringD} h={ringD} tf="translateY(4px)" o={ringP > 0 && ringP < 1 ? 1 : 0}>
          <circle r={ringD / 2} fill="none" stroke={hex(0xffc247, 0.75 * (1 - ringP * ringP))} strokeWidth={14 * (1 - ringE)} />
        </Svg>
        <Z style={{ gridArea: "1 / 1", transform: "translateY(4px)", opacity: on ? 1 : 0 }}>
          {Array.from({ length: rays }, (_, index) => {
            const angle = (index / rays) * 360;
            if (index % 2 === 0) {
              const head = IC.easeOut(IC.seg(t, BURST, BURST + 0.3));
              const tail = IC.easeOut(IC.seg(t, BURST + 0.12, BURST + 0.5));
              const near = ORIGIN + distance * tail;
              const far = ORIGIN + distance * head;
              const w = 5.5 - 3 * tail;
              return (
                <Item
                  key={index}
                  w={w}
                  h={Math.max(far - near, 0.5)}
                  tf={`rotate(${angle}deg) translateY(${-(near + far) / 2}px)`}
                  o={head > 0 && tail < 1 ? 1 : 0}
                  style={{ borderRadius: w / 2, background: Palette.amber }}
                />
              );
            }
            const start = BURST + 0.02;
            const p = IC.easeOut(IC.seg(t, start, start + 0.54));
            const radius = ORIGIN - 6 + distance * 1.25 * p;
            const size = 9 * (1 - p) + 1.5;
            const fade = IC.seg(t, start, start + 0.04) * (1 - IC.seg(t, start + 0.34, start + 0.54));
            return (
              <Item
                key={index}
                w={size}
                h={size}
                tf={`rotate(${angle}deg) translateY(${-radius}px)`}
                o={fade}
                style={{ borderRadius: "50%", background: Palette.spectrum[Math.floor(index / 2) % Palette.spectrum.length] }}
              />
            );
          })}
        </Z>
        <Svg
          w={112}
          h={112}
          tf={`translateY(${4 - lift}px) scale(${scale}) ${scaleAt(1 + squash * 0.7, 1 - squash, 0, 56)} rotate(${rotation}deg)`}
          style={{ filter: `drop-shadow(0 6px 16px ${hex(0xffc247, 0.5 * fill)})` }}
        >
          <defs>
            <linearGradient id="star-gold" x1="0" y1="-56" x2="0" y2="56" gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={hex(0xffe680)} />
              <stop offset="0.5" stopColor={Palette.amber} />
              <stop offset="1" stopColor={hex(0xff9a2e)} />
            </linearGradient>
            <linearGradient id="star-sheen" x1="-56" y1="-56" x2="0" y2="0" gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor="#fff" stopOpacity={0.55} />
              <stop offset="1" stopColor="#fff" stopOpacity={0} />
            </linearGradient>
          </defs>
          <path d={STAR_OUTLINE} fill="none" strokeWidth={6} strokeLinejoin="round" opacity={(1 - fill) * 0.75} style={{ stroke: Palette.secondaryLabel }} />
          <g opacity={fill}>
            <path d={STAR} fill="url(#star-gold)" />
            <path d={STAR} fill="url(#star-sheen)" />
            <path d={STAR} fill="none" stroke={hex(0xf08a12, 0.55)} strokeWidth={1.5} />
          </g>
          <path d={STAR} fill="#fff" opacity={flash * 0.85} />
        </Svg>
        <Z style={{ gridArea: "1 / 1", opacity: on ? 1 : 0 }}>
          {sparkle(80, -66, 30, 0.3)}
          {sparkle(-88, -34, 20, 0.38)}
          {sparkle(72, 70, 17, 0.46)}
        </Z>
      </Z>
      <div style={{ display: "flex", alignItems: "center", gap: 6, ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        <svg width={15} height={15} viewBox="-60 -60 120 120" style={{ transition: "opacity 0.3s" }}>
          <path d={STAR} style={{ fill: on ? Palette.amber : Palette.secondaryLabel, opacity: on ? 1 : 0.6, transition: "fill 0.3s, opacity 0.3s" }} />
        </svg>
        <NumericText value={count} />
        <span>{ctx.t("favourites", "次收藏")}</span>
      </div>
      <DemoHint ctx={ctx} en="Tap the star" zh="点击星标" />
    </Stage>
  );
}
