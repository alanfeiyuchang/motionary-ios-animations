/** icons.mute-slash · 静音斜杠 (Icons+MuteSlash.swift) */
import { useId } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Stage, arcPath, roundedPolygon, useIconNow, useLater, usePlayhead } from "./_time-kit";

const SW = 9;
const FIRST = 22;
const STEP = 20;
// HStack(spacing: 10) of the 62 × 84 speaker and the 88 × 150 wave box, centred on the origin.
const SPK_L = -80;
const SPK_R = -18;
const WAVE_X = -8;
const SPEAKER = roundedPolygon(
  [
    [SPK_L, -42 + 84 * 0.3],
    [SPK_L + 62 * 0.4, -42 + 84 * 0.3],
    [SPK_R, -42],
    [SPK_R, 42],
    [SPK_L + 62 * 0.4, -42 + 84 * 0.7],
    [SPK_L, -42 + 84 * 0.7],
  ],
  (i) => (i === 1 || i === 4 ? 62 * 0.06 : 62 * 0.14),
);
const SLASH = "M-47.5 -47.5L47.5 47.5";

export default function MuteSlash({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** On = muted. */
  const play = usePlayhead(false);
  const clock = useIconNow(ctx.isPreview);
  const t = play.elapsed(clock);
  const muted = play.isOn;

  const count = Math.max(ctx.i("waves"), 1);
  const stagger = ctx.n("stagger");
  const damping = ctx.n("damping");

  const toggle = (scripted = false) => {
    const base = ctx.i("waves") * stagger;
    if (play.toggle(base + 0.5, base + 0.7)) {
      haptics.tap("light");
      later(base + 0.3, scripted, (h) => h.tap("rigid"));
    } else {
      haptics.tap("medium");
    }
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.0 });

  const slashStart = count * stagger + 0.04;
  const waveAmount = (index: number) => {
    if (muted) {
      const order = count - 1 - index;
      return 1 - IC.easeIn(IC.seg(t, order * stagger, order * stagger + 0.18));
    }
    return IC.spring(t - 0.14 - index * stagger, 0.34, damping);
  };
  const cut = muted ? IC.easeOut(IC.seg(t, slashStart, slashStart + 0.26)) : 1 - IC.easeIn(IC.seg(t, 0, 0.16));
  const grey = muted ? IC.seg(t, 0, slashStart + 0.2) : 1 - IC.seg(t, 0, 0.2);
  const centred = muted ? IC.spring(t - count * stagger * 0.4, 0.45, 0.8) : 1 - IC.spring(t, 0.4, 0.75);
  const rock = muted ? -5 * IC.shake(t - slashStart - 0.2, 9, 24) : 0;
  const thump = muted ? 0 : 0.16 * IC.shake(t - 0.1, 9, 22);
  const dash = { pathLength: 1, strokeDasharray: `${cut} 2`, strokeLinecap: "round" as const, fill: "none" };

  return (
    <Stage gap={12}>
      <svg
        width={250}
        height={190}
        viewBox="-125 -95 250 190"
        onClick={() => toggle()}
        style={{ display: "block", overflow: "visible", cursor: "pointer", transform: `rotate(${rock}deg)` }}
      >
        <defs>
          <linearGradient id={`${uid}-spk`} x1={SPK_L} y1={-42} x2={SPK_R} y2={42} gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor={Palette.sky} />
            <stop offset="1" stopColor={Palette.blue} />
          </linearGradient>
          <linearGradient id={`${uid}-wave`} x1={WAVE_X} y1={-75} x2={WAVE_X + 88} y2={75} gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor={Palette.sky} />
            <stop offset="1" stopColor={Palette.blue} />
          </linearGradient>
          <mask id={`${uid}-cut`} maskUnits="userSpaceOnUse" x={-200} y={-150} width={400} height={300}>
            <rect x={-200} y={-150} width={400} height={300} fill="#fff" />
            {cut > 0.001 && <path d={SLASH} stroke="#000" strokeWidth={SW * 2.3} {...dash} />}
          </mask>
        </defs>
        <g mask={`url(#${uid}-cut)`}>
          <g transform={`translate(${6 + 43 * centred} 0)`} style={{ filter: `drop-shadow(0 7px 12px ${hex(0x4f7cff, 0.3 * (1 - grey))})` }}>
            <g transform={`translate(${SPK_R} 0) scale(${1 + thump}) translate(${-SPK_R} 0)`}>
              <path d={SPEAKER} fill={`url(#${uid}-spk)`} />
            </g>
            {Array.from({ length: count }, (_, index) => {
              const amount = waveAmount(index);
              const shown = IC.unit(amount);
              const pulse = 0.7 + 0.3 * Math.max(0, Math.sin(clock * 3.4 - index * 0.95));
              if (shown <= 0.001) return null;
              return (
                <g key={index} transform={`translate(${-10 * (1 - shown)} 0) translate(${WAVE_X} 0) scale(${0.82 + 0.18 * amount}) translate(${-WAVE_X} 0)`} opacity={IC.unit(shown * 2.2) * pulse}>
                  <path
                    d={arcPath(WAVE_X, 0, FIRST + STEP * index, -40, 40)}
                    fill="none"
                    stroke={`url(#${uid}-wave)`}
                    strokeWidth={SW}
                    strokeLinecap="round"
                    pathLength={1}
                    strokeDasharray={`${shown} 2`}
                    strokeDashoffset={-(0.5 - 0.5 * shown)}
                  />
                </g>
              );
            })}
            <path d={SPEAKER} fill={hex(0x8e8e99)} opacity={grey} />
          </g>
        </g>
        {cut > 0.001 && <path d={SLASH} stroke={Palette.red} strokeWidth={SW} {...dash} style={{ filter: `drop-shadow(0 3px 6px ${hex(0xff4d5e, 0.4)})` }} />}
      </svg>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {[false, true].map((state) => (
          <span key={String(state)} style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap", opacity: muted === state ? 1 : 0, transition: "opacity 0.25s ease-in-out" }}>
            {state ? ctx.t("Muted", "已静音") : ctx.t("Sound on", "声音已开启")}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to mute or unmute" zh="点击静音或取消静音" />
    </Stage>
  );
}
