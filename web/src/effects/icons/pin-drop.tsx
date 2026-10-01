/** icons.pin-drop · 大头针落点 (Icons+PinDrop.swift) */
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, nowSeconds, scaleAt, since, useIconNow, useLater } from "./_time-kit";

const GROUND = 60;
const PIN_W = 54;
const PIN_H = 78;
const PLACES: [number, number][] = [
  [47.6101, 122.2015],
  [47.6205, 122.3493],
  [47.674, 122.1215],
  [47.5301, 122.0326],
];

const pinTimes = (bounce: number) => {
  const root = Math.sqrt(bounce);
  return { fall: 0.66, second: 0.66 + 0.3 * root, third: 0.66 + 0.46 * root };
};

/** The teardrop pin in a 54 × 78 box centred on the origin. */
const PIN = (() => {
  const r = PIN_W / 2;
  const cy = -PIN_H / 2 + r;
  const a = (145 * Math.PI) / 180;
  const b = (35 * Math.PI) / 180;
  const sx = r * Math.cos(a);
  const sy = cy + r * Math.sin(a);
  const ex = r * Math.cos(b);
  const ey = cy + r * Math.sin(b);
  const qy = -PIN_H / 2 + PIN_H * 0.8;
  return `M${sx} ${sy}A${r} ${r} 0 1 1 ${ex} ${ey}Q${r * 0.42} ${qy} 0 ${PIN_H / 2}Q${-r * 0.42} ${qy} ${sx} ${sy}Z`;
})();

function pose(t: number, height: number, bounce: number, times: ReturnType<typeof pinTimes>) {
  const p = { height: 0, squash: 0, opacity: 1 };
  if (t < 0.07) {
    p.squash = 0.1 * IC.easeOut(t / 0.07);
  } else if (t < 0.26) {
    const u = (t - 0.07) / 0.19;
    p.height = height * u * u * u;
    p.squash = 0.1 - 0.24 * IC.unit(u * 2.5);
    p.opacity = 1 - IC.seg(u, 0.45, 1);
  } else if (t < 0.36) {
    p.height = height;
    p.opacity = 0;
  } else if (t < times.fall) {
    const u = (t - 0.36) / 0.3;
    p.height = height * (1 - u * u);
    p.squash = -0.12 * u;
    p.opacity = IC.seg(u, 0, 0.3);
  } else if (t < times.second) {
    const u = (t - times.fall) / Math.max(times.second - times.fall, 0.001);
    p.height = 30 * bounce * 4 * u * (1 - u);
  } else if (t < times.third) {
    const u = (t - times.second) / Math.max(times.third - times.second, 0.001);
    p.height = 8 * bounce * 4 * u * (1 - u);
  }
  if (t >= times.fall) p.squash += 0.26 * IC.ring(t - times.fall, 14, 34);
  if (t >= times.second) p.squash += 0.12 * bounce * IC.ring(t - times.second, 16, 36);
  if (t >= times.third) p.squash += 0.05 * bounce * IC.ring(t - times.third, 18, 38);
  return p;
}

export default function PinDrop({ ctx }: DemoProps) {
  const { haptics, after, later } = useLater();
  const start = useRef(DISTANT_PAST);
  const [place, setPlace] = useState(0);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const height = ctx.n("height");
  const bounce = ctx.n("bounce");
  const rings = Math.max(ctx.i("rings"), 1);
  const times = pinTimes(bounce);

  const drop = (scripted = false) => {
    // One drop at a time: a tap during the flight is ignored.
    if (since(nowSeconds(), start.current) <= 0.9) return;
    start.current = nowSeconds();
    haptics.tap("light");
    after(times.fall, () => setPlace((p) => p + 1));
    later(times.fall, scripted, (h) => h.tap("medium"));
    if (bounce > 0.15) later(times.second, scripted, (h) => h.tap("soft"));
  };
  useAutoplay(ctx.isPreview, () => drop(true), { every: 2.3 });

  const p = pose(t, height, bounce, times);
  const pulse = IC.bump(IC.seg(t, times.fall, times.fall + 0.3));
  const near = 1 - IC.unit(p.height / Math.max(height, 1));
  const shadowW = 16 + 26 * near + 36 * Math.max(p.squash, 0);

  const ripple = (key: string, s: number, reach: number, strength: number) => {
    const q = IC.seg(s, 0, 0.75);
    const w = 30 + reach * IC.easeOut(q);
    return (
      <Svg key={key} w={w} h={w * 0.36} o={q > 0 && q < 1 ? 1 : 0}>
        <ellipse rx={w / 2} ry={w * 0.18} fill="none" stroke={hex(0xff4d5e, strength * (1 - q))} strokeWidth={3 * (1 - q) + 0.6} />
      </Svg>
    );
  };

  const dustP = IC.seg(t - times.fall, 0, 0.5);
  const dustE = IC.easeOut(dustP);
  const spot = PLACES[place % PLACES.length];
  const line = (x0: number, y0: number, x1: number, y1: number, a: number, w: number) => (
    <line x1={-111 + 222 * x0} y1={-42 + 84 * y0} x2={-111 + 222 * x1} y2={-42 + 84 * y1} strokeWidth={w} strokeLinecap="butt" style={{ stroke: Palette.labelAlpha(a) }} />
  );

  return (
    <Stage gap={10}>
      <Z w={250} h={226} onClick={() => drop()}>
        <Svg w={222} h={84} tf={`translateY(${GROUND + 6}px) scale(${1 + 0.03 * pulse})`} style={{ overflow: "hidden" }}>
          <defs>
            <clipPath id="pin-disc">
              <ellipse rx={111} ry={42} />
            </clipPath>
          </defs>
          <g clipPath="url(#pin-disc)">
            <ellipse rx={111} ry={42} style={{ fill: Palette.labelAlpha(0.07) }} />
            <ellipse cx={-52} cy={-12} rx={35} ry={13} fill={hex(0x21d4a8, 0.3)} />
            <ellipse cx={78} cy={30} rx={45} ry={20} fill={hex(0x3ac4ff, 0.3)} />
            {line(-0.05, 0.78, 1.05, 0.3, 0.11, 7)}
            {line(0.3, -0.1, 0.62, 1.1, 0.09, 5)}
            {line(0.62, -0.1, 0.95, 0.75, 0.07, 4)}
          </g>
          <ellipse rx={110.5} ry={41.5} fill="none" strokeWidth={1} style={{ stroke: Palette.labelAlpha(0.1) }} />
        </Svg>
        <Z style={{ gridArea: "1 / 1", transform: `translateY(${GROUND}px)` }}>
          {Array.from({ length: rings }, (_, i) => ripple(`r${i}`, t - times.fall - i * 0.13, 170, 0.6))}
          {ripple("second", t - times.second, 70, bounce > 0.15 ? 0.45 : 0)}
        </Z>
        <Item
          w={shadowW}
          h={shadowW * 0.36}
          tf={`translateY(${GROUND}px)`}
          o={p.opacity}
          style={{ borderRadius: "50%", background: `rgb(0 0 0 / ${0.1 + 0.3 * near})`, filter: `blur(${1.5 + 5 * (1 - near)}px)` }}
        />
        <Z style={{ gridArea: "1 / 1", transform: `translateY(${GROUND}px)`, opacity: dustP > 0 && dustP < 1 ? 1 : 0 }}>
          {[0, 1, 2, 3, 4, 5].map((i) => {
            const side = i % 2 === 0 ? 1 : -1;
            const k = Math.floor(i / 2);
            const size = 4 * (1 - dustP) + 1;
            return (
              <Item
                key={i}
                w={size}
                h={size}
                tf={`translate(${side * (30 + 14 * k) * dustE}px, ${-(7 + 5 * k) * IC.bump(dustP)}px)`}
                style={{ borderRadius: "50%", background: hex(0xff4d5e, 0.5 * (1 - dustP)) }}
              />
            );
          })}
        </Z>
        <Svg
          w={PIN_W}
          h={PIN_H}
          tf={`translateY(${GROUND - PIN_H / 2 - p.height}px) ${scaleAt(1 + p.squash * 0.8, 1 - p.squash, 0, PIN_H / 2)}`}
          o={p.opacity}
          style={{ filter: `drop-shadow(0 6px 10px ${hex(0xff4d5e, 0.35)})` }}
        >
          <defs>
            <linearGradient id="pin-body" x1="0" y1={-PIN_H / 2} x2="0" y2={PIN_H / 2} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={hex(0xff8088)} />
              <stop offset="0.5" stopColor={Palette.red} />
              <stop offset="1" stopColor={hex(0xe2334a)} />
            </linearGradient>
            <linearGradient id="pin-sheen" x1={-PIN_W / 2} y1={-PIN_H / 2} x2="0" y2="0" gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor="#fff" stopOpacity={0.45} />
              <stop offset="1" stopColor="#fff" stopOpacity={0} />
            </linearGradient>
          </defs>
          <path d={PIN} fill="url(#pin-body)" />
          <path d={PIN} fill="url(#pin-sheen)" />
          <circle cy={-PIN_H / 2 + PIN_W / 2 + p.squash * 16} r={10} fill="#fff" style={{ filter: `drop-shadow(0 1px 2px ${hex(0xb01e33, 0.5)})` }} />
        </Svg>
      </Z>
      <div style={{ display: "flex", alignItems: "center", gap: 6, ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        <svg width={16} height={17} viewBox="0 0 16 17" style={{ color: Palette.red }}>
          <circle cx={8} cy={3.6} r={2.9} fill="currentColor" />
          <path d="M8 6v7.4" stroke="currentColor" strokeWidth={1.7} strokeLinecap="round" />
          <path d="M5 10.6c-2.2.5-3.6 1.4-3.6 2.5 0 1.6 3 2.7 6.6 2.7s6.6-1.1 6.6-2.7c0-1.1-1.4-2-3.6-2.5" fill="none" stroke="currentColor" strokeWidth={1.5} strokeLinecap="round" />
        </svg>
        <NumericText value={place} text={`${spot[0].toFixed(4)}° N, ${spot[1].toFixed(4)}° W`} />
      </div>
      <DemoHint ctx={ctx} en="Tap to drop the pin again" zh="点击重新放下大头针" />
    </Stage>
  );
}
