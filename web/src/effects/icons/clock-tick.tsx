/** icons.clock-tick · 时钟跳秒 (Icons+ClockTick.swift) */
import { useId, useRef } from "react";
import { DemoHint, Palette, fonts, hex, useAutoplay, type DemoProps } from "../../kit";
import { Glyph, Replace } from "./_icons-kit";
import { CHAIN_GLYPHS } from "./symbol-chain";
import { DISTANT_PAST, IC, Stage, nowSeconds, rr, since, useIconNow, useLater } from "./_time-kit";

const spinDuration = (hours: number) => Math.min(0.86 + 0.08 * hours, 1.7);

export default function ClockTick({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** Hours already added by finished spins / hours the running (or last) spin adds / when it began. */
  const state = useRef({ banked: 0, spinning: 0, start: DISTANT_PAST });
  const now = useIconNow(ctx.isPreview);
  const { banked, spinning, start } = state.current;
  const t = since(now, start);
  const length = spinDuration(spinning);

  const damping = ctx.n("damping");
  const sweep = ctx.b("sweep");

  const spin = (scripted = false) => {
    const s = state.current;
    // One spin at a time.
    if (since(nowSeconds(), s.start) <= spinDuration(s.spinning) + 0.45) return;
    const hours = Math.max(ctx.i("hours"), 1);
    state.current = { banked: (s.banked + s.spinning) % 24, spinning: hours, start: nowSeconds() };
    haptics.tap("light");
    const len = spinDuration(hours);
    for (let hour = 1; hour < hours; hour++) later(len * (0.2 + (0.6 * hour) / hours), scripted, (h) => h.selection());
    later(len, scripted, (h) => h.tap("soft"));
  };
  useAutoplay(ctx.isPreview, () => spin(true), { every: 3.6 });

  // The time the clock shows: wall time plus the hours added by taps.
  const date = new Date();
  const base = date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds() + date.getMilliseconds() / 1000;
  const seconds = base % 60;
  const hoursAt = (time: number) => base / 3600 + banked + spinning * IC.easeInOut(IC.seg(time, 0, length));
  /** The landing wobble, in units of "hours of minute-hand travel". */
  const wobble = (time: number) => 0.022 * IC.shake(time - length, 9, 20);
  const minuteAngle = (time: number) => (hoursAt(time) + wobble(time)) * 360;
  const hourAngle = (hoursAt(t) + wobble(t) * 4) * 30;
  const blur = t < length ? IC.bump(IC.seg(t, 0, length)) : 0;
  const whole = Math.floor(seconds);
  const secondAngle = sweep ? seconds * 6 : 6 * (whole - 1 + IC.spring(seconds - whole, 0.2, damping));
  const total = Math.floor(hoursAt(t) * 60) % 1440;
  const minutes = total < 0 ? total + 1440 : total;
  const isDay = minutes >= 6 * 60 && minutes < 18 * 60;

  /** A hand pointing at 12 o'clock, pivoting on the face's centre. */
  const hand = (width: number, len: number, tail: number) => rr(-width / 2, -len, width, len + tail, width / 2);

  return (
    <Stage gap={12}>
      <svg width={196} height={196} viewBox="-98 -98 196 196" onClick={() => spin()} style={{ display: "block", overflow: "visible", cursor: "pointer", flexShrink: 0, borderRadius: "50%" }}>
        <defs>
          <radialGradient id={`${uid}-sheen`} cx={-98 + 196 * 0.35} cy={-98 + 196 * 0.25} r={150} gradientUnits="userSpaceOnUse">
            <stop offset={4 / 150} stopColor="#fff" stopOpacity={0.1} />
            <stop offset="1" stopColor="#fff" stopOpacity={0} />
          </radialGradient>
          <linearGradient id={`${uid}-rim`} x1={-98} y1={-98} x2={98} y2={98} gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor={hex(0x8a93ff)} />
            <stop offset="1" stopColor={hex(0xa352f0)} />
          </linearGradient>
        </defs>
        <g style={{ filter: `drop-shadow(0 10px 18px ${hex(0x6e7bff, 0.28)})` }}>
          <circle r={98} style={{ fill: Palette.elevated }} />
          <circle r={98} fill={`url(#${uid}-sheen)`} />
          <circle r={95} fill="none" stroke={`url(#${uid}-rim)`} strokeWidth={6} />
        </g>
        {Array.from({ length: 12 }, (_, index) => {
          const major = index % 3 === 0;
          const w = major ? 4 : 3;
          const h = major ? 13 : 8;
          const y = -76 + (major ? 0 : -2.5);
          return <path key={index} d={rr(-w / 2, y - h / 2, w, h, w / 2)} transform={`rotate(${index * 30})`} style={{ fill: Palette.labelAlpha(major ? 0.75 : 0.3) }} />;
        })}
        {[1, 2, 3, 4].map((k, offset) => (
          <path key={k} d={hand(6, 68, 0)} transform={`rotate(${minuteAngle(t - 0.022 * k)})`} style={{ fill: Palette.labelAlpha(0.22 * blur * (1 - offset * 0.2)) }} />
        ))}
        <g style={{ filter: "drop-shadow(0 2px 2px rgb(0 0 0 / 0.18))" }}>
          <path d={hand(8, 46, 0)} transform={`rotate(${hourAngle})`} style={{ fill: Palette.labelAlpha(0.92) }} />
        </g>
        <g style={{ filter: "drop-shadow(0 2px 2px rgb(0 0 0 / 0.18))" }}>
          <path d={hand(6, 68, 0)} transform={`rotate(${minuteAngle(t)})`} style={{ fill: Palette.labelAlpha(0.92) }} />
        </g>
        <g style={{ filter: `drop-shadow(0 2px 3px ${hex(0xff4d5e, 0.35)})` }}>
          <path d={hand(2.5, 76, 18)} transform={`rotate(${secondAngle})`} fill={Palette.red} />
        </g>
        <circle r={5.5} fill={Palette.red} />
        <circle r={2} style={{ fill: Palette.background }} />
      </svg>
      <div style={{ display: "flex", alignItems: "center", gap: 7, color: Palette.label }}>
        <Replace k={isDay ? "day" : "night"}>
          <Glyph def={isDay ? CHAIN_GLYPHS.sunMax : CHAIN_GLYPHS.moonStars.map((l) => ({ ...l, alpha: undefined }))} size={22} color={isDay ? Palette.amber : Palette.indigo} />
        </Replace>
        <span style={{ fontFamily: fonts.rounded, fontSize: 20, lineHeight: "25px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
          {String(Math.floor(minutes / 60)).padStart(2, "0")}:{String(minutes % 60).padStart(2, "0")}
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap to spin time forward" zh="点击让时间向前飞转" />
    </Stage>
  );
}
