/** icons.flag-wave · 旗帜飘扬 (Icons+FlagWave.swift) */
import { useId } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Stage, rr, useIconNow, useLater, usePhase, usePlayhead } from "./_time-kit";

const POLE_X = 62;
const POLE_TOP = 22;
const POLE_BOTTOM = 190;
const CLOTH_W = 126;
const CLOTH_H = 74;
const SLICES = 28;

export default function FlagWave({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** On = raised. */
  const play = usePlayhead(false);
  const clock = useIconNow(ctx.isPreview);
  const t = play.elapsed(clock);
  const raised = play.isOn;
  const phase = usePhase(clock, ctx.n("speed") * 4.2);

  const amplitude = ctx.n("amplitude");
  const wavelengths = ctx.n("waves");

  const toggle = (scripted = false) => {
    const on = play.toggle(1.3, 0.6);
    haptics.tap("light");
    if (on) later(0.42, scripted, (h) => h.tap("soft"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.8 });

  const lift = raised ? IC.spring(t, 0.6, 0.8) : 1 - IC.easeInOut(IC.seg(t, 0.1, 0.6));
  const open = raised ? IC.spring(t - 0.25, 0.5, 0.6) : 1 - IC.easeInOut(IC.seg(t, 0, 0.35));
  const gust = raised && t > 0.3 ? Math.exp(-2.6 * (t - 0.3)) : 0;
  const sway = raised ? 1.5 * IC.shake(t - 0.3, 3, 9) : 0;

  const flying = IC.unit(open);
  const amp = amplitude * flying * (1 + 1.1 * gust);
  const top = IC.mix(POLE_BOTTOM - CLOTH_H - 30, POLE_TOP + 8, lift);
  const width = CLOTH_W * (0.55 + 0.45 * open);
  const droop = 24 * (1 - flying);
  const originX = POLE_X + 3;

  // The top edge: the wave grows from nothing at the pole to its full height at the free edge.
  const edge: [number, number][] = [];
  const heights: number[] = [];
  const stops: { color: string; at: number }[] = [];
  for (let index = 0; index <= SLICES; index++) {
    const u = index / SLICES;
    const envelope = Math.pow(u, 0.8);
    const angle = u * wavelengths * 2 * Math.PI - phase;
    const sag = droop * Math.pow(u, 1.4) + 2.5 * Math.sin(phase * 0.5) * u * (1 - flying);
    edge.push([originX + width * u, top + amp * envelope * Math.sin(angle) + sag]);
    // The free edge is a little shorter, as cloth pulled by the wind is.
    heights.push(CLOTH_H * (1 - 0.06 * u));
    // Shade by slope: faces turned to the light brighten, the folds darken.
    const light = Math.cos(angle) * envelope * flying * Math.min(amp / 8, 1.6);
    stops.push({ color: light > 0 ? `rgb(255 255 255 / ${0.3 * light})` : hex(0x7a1f00, -0.4 * light), at: u });
  }
  const band = (from: number, to: number) => {
    let d = "";
    for (let i = 0; i <= SLICES; i++) d += `${i === 0 ? "M" : "L"}${edge[i][0].toFixed(2)} ${(edge[i][1] + heights[i] * from).toFixed(2)}`;
    for (let i = SLICES; i >= 0; i--) d += `L${edge[i][0].toFixed(2)} ${(edge[i][1] + heights[i] * to).toFixed(2)}`;
    return d + "Z";
  };
  const cloth = band(0, 1);

  return (
    <Stage gap={10}>
      <svg width={250} height={214} viewBox="0 0 250 214" onClick={() => toggle()} style={{ display: "block", overflow: "visible", cursor: "pointer", flexShrink: 0 }}>
        <defs>
          <linearGradient id={`${uid}-base`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={hex(0xb9bbc9)} />
            <stop offset="1" stopColor={hex(0x8c8fa3)} />
          </linearGradient>
          <linearGradient id={`${uid}-pole`} x1="0" y1="0" x2="1" y2="0">
            <stop offset="0" stopColor={hex(0xe3e4ec)} />
            <stop offset="1" stopColor={hex(0x9ea1b4)} />
          </linearGradient>
          <radialGradient id={`${uid}-knob`} cx={POLE_X - 7.5 + 15 * 0.35} cy={POLE_TOP - 4 - 7.5 + 15 * 0.3} r={9} gradientUnits="userSpaceOnUse">
            <stop offset={1 / 9} stopColor={hex(0xffe9a0)} />
            <stop offset="1" stopColor={hex(0xf0a92a)} />
          </radialGradient>
          <linearGradient id={`${uid}-cloth`} x1="0" y1={top} x2="0" y2={top + CLOTH_H} gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor={hex(0xff8a4a)} />
            <stop offset="1" stopColor={hex(0xf5622a)} />
          </linearGradient>
          <linearGradient id={`${uid}-shade`} x1={originX} y1="0" x2={originX + width} y2="0" gradientUnits="userSpaceOnUse">
            {stops.map((s, i) => (
              <stop key={i} offset={s.at} stopColor={s.color} />
            ))}
          </linearGradient>
        </defs>
        <ellipse cx={POLE_X + 14} cy={POLE_BOTTOM + 6} rx={48} ry={6} fill="rgb(0 0 0 / 0.16)" style={{ filter: "blur(6px)" }} />
        <ellipse cx={POLE_X} cy={POLE_BOTTOM + 1} rx={22} ry={7} fill={`url(#${uid}-base)`} />
        <g transform={`rotate(${sway} ${POLE_X} ${POLE_BOTTOM})`}>
          <g style={{ filter: `drop-shadow(0 6px 10px ${hex(0xff7a3d, 0.3)})` }}>
            <path d={cloth} fill={`url(#${uid}-cloth)`} />
            <path d={band(0.38, 0.62)} fill="rgb(255 255 255 / 0.95)" />
            <path d={cloth} fill={`url(#${uid}-shade)`} />
            {/* The sleeve where the cloth meets the pole. */}
            <path d={rr(originX - 4, top - 2, 5, CLOTH_H + 4, 2.5)} fill={hex(0xd9571f)} />
          </g>
          <path d={rr(POLE_X - 3.5, POLE_TOP, 7, POLE_BOTTOM - POLE_TOP, 3.5)} fill={`url(#${uid}-pole)`} />
          <circle cx={POLE_X} cy={POLE_TOP - 4} r={7.5} fill={`url(#${uid}-knob)`} style={{ filter: `drop-shadow(0 0 5px ${hex(0xffc247, 0.5)})` }} />
        </g>
      </svg>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {[false, true].map((state) => (
          <span key={String(state)} style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap", opacity: raised === state ? 1 : 0, transition: "opacity 0.25s ease-in-out" }}>
            {state ? ctx.t("Flagged", "已标记") : ctx.t("Not flagged", "未标记")}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to raise or lower the flag" zh="点击升起或降下旗帜" />
    </Stage>
  );
}
