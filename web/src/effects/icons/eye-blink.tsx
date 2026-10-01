/** icons.eye-blink · 眨眼显隐 (Icons+EyeBlink.swift) */
import { useId } from "react";
import { DemoHint, Palette, fonts, hex, useAutoplay, type DemoProps } from "../../kit";
import { Glyph, SYM, sym } from "./_icons-kit";
import { IC, Stage, useIconNow, useLater, usePlayhead } from "./_time-kit";

const HIDE = 0.75;
const SHOW = 0.95;
const W = 132;
const H = 74;
const SW = 8;
const SAG = 0.2;
const LIFT = 0.92;
const CHARS = ["M", "o", "t", "i", "o", "n", "2", "6"];

function eyePath(open: number) {
  const closed = H * SAG;
  const reach = H * LIFT;
  const upper = closed + (-reach - closed) * open;
  const lower = closed + (reach - closed) * open;
  return `M${-W / 2} 0Q0 ${upper} ${W / 2} 0Q0 ${lower} ${-W / 2} 0Z`;
}

function lashPath(lengths: number[]) {
  const count = lengths.length;
  let d = "";
  for (let i = 0; i < count; i++) {
    const length = lengths[i];
    if (!(length > 0.02)) continue;
    const u = count === 1 ? 0.5 : 0.2 + (0.6 * i) / (count - 1);
    const x = (1 - u) * (1 - u) * (-W / 2) + u * u * (W / 2);
    const y = 2 * u * (1 - u) * H * SAG;
    const fan = (u - 0.5) * 1.1;
    const rx = x + Math.sin(fan) * 7;
    const ry = y + Math.cos(fan) * 7;
    d += `M${rx} ${ry}L${rx + Math.sin(fan) * 12 * length} ${ry + Math.cos(fan) * 12 * length}`;
  }
  return d;
}

export default function EyeBlink({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** On = hidden (eye shut and slashed). */
  const play = usePlayhead(false);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const hidden = play.isOn;

  const toggle = (scripted = false) => {
    const on = play.toggle(HIDE, SHOW);
    haptics.tap("light");
    if (on) later(0.5, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.1 });

  const lashes = Math.max(ctx.i("lashes"), 0);
  const blink = ctx.b("blink");
  const response = ctx.n("response");
  const stagger = ctx.n("stagger");

  let open: number;
  if (hidden) open = 1 - IC.spring(t, response, 0.8);
  else open = IC.spring(t - 0.1, response, 0.55) * (1 - (blink ? IC.bump(IC.seg(t, 0.52, 0.72)) : 0));
  const lengths = Array.from({ length: lashes }, (_, i) =>
    hidden ? IC.spring(t - 0.16 - i * 0.035, 0.3, 0.55) : 1 - IC.easeIn(IC.seg(t, 0, 0.14)),
  );
  const cut = hidden ? IC.easeOut(IC.seg(t, 0.28, 0.55)) : 1 - IC.easeIn(IC.seg(t, 0, 0.16));
  const glance = hidden ? 0 : IC.bump(IC.seg(t, 0.76, 1.3));
  const dim = hidden ? IC.seg(t, 0, 0.3) : 1 - IC.seg(t, 0, 0.3);
  const nudge = hidden ? 3 * IC.bump(IC.seg(t, 0.05, 0.4)) : 0;
  const shown = IC.unit(open);
  const eye = eyePath(open);
  const slash = `M${-90 + 180 * 0.21} ${-61 + 122 * 0.17}L${-90 + 180 * 0.79} ${-61 + 122 * 0.83}`;
  const dash = { pathLength: 1, strokeDasharray: `${cut} 2`, strokeLinecap: "round" as const, fill: "none" };

  const reveal = (index: number) => {
    const delay = index * stagger;
    if (hidden) return 1 - IC.easeOut(IC.seg(t, 0.1 + delay, 0.3 + delay));
    return IC.easeOut(IC.seg(t, 0.2 + delay, 0.42 + delay));
  };

  return (
    <Stage gap={12}>
      <div onClick={() => toggle()} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18, cursor: "pointer" }}>
        <svg width={180} height={122} viewBox="-90 -61 180 122" style={{ display: "block", overflow: "visible", opacity: 1 - 0.35 * dim, transform: `translateY(${nudge}px)` }}>
          <defs>
            <linearGradient id={`${uid}-iris`} x1={-20} y1={-20} x2={20} y2={20} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={Palette.indigo} />
              <stop offset="1" stopColor={Palette.violet} />
            </linearGradient>
            <clipPath id={`${uid}-eye`}>
              <path d={eye} />
            </clipPath>
            <mask id={`${uid}-cut`} maskUnits="userSpaceOnUse" x={-120} y={-100} width={240} height={200}>
              <rect x={-120} y={-100} width={240} height={200} fill="#fff" />
              {cut > 0.001 && <path d={slash} stroke="#000" strokeWidth={SW * 2.3} {...dash} />}
            </mask>
          </defs>
          <g mask={`url(#${uid}-cut)`}>
            <g clipPath={`url(#${uid}-eye)`} opacity={IC.unit(shown * 3)}>
              <g transform={`translate(0 ${7 * glance + 10 * (1 - shown)}) scale(${0.55 + 0.45 * Math.min(open, 1.15)})`}>
                <circle r={20} fill={`url(#${uid}-iris)`} />
                <circle r={8} fill={hex(0x1b1640)} />
                <circle cx={-8} cy={-9} r={4} fill="rgb(255 255 255 / 0.9)" />
              </g>
            </g>
            <g fill="none" strokeLinecap="round" strokeLinejoin="round" style={{ stroke: Palette.label }}>
              <path d={eye} strokeWidth={SW} />
              <path d={lashPath(lengths)} strokeWidth={SW * 0.8} />
            </g>
          </g>
          {cut > 0.001 && <path d={slash} strokeWidth={SW} {...dash} style={{ stroke: Palette.label }} />}
        </svg>
        <div
          style={{
            width: 236,
            height: 52,
            boxSizing: "border-box",
            padding: "0 18px",
            display: "flex",
            alignItems: "center",
            gap: 10,
            borderRadius: 16,
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 5px 10px rgb(0 0 0 / 0.08)`,
          }}
        >
          <Glyph def={SYM.lockFill} size={sym(15)} color={Palette.secondaryLabel} />
          <div style={{ display: "flex" }}>
            {CHARS.map((c, index) => {
              const s = reveal(index);
              return (
                <div key={index} style={{ position: "relative", width: 19, height: 28, display: "grid", placeItems: "center" }}>
                  <div style={{ gridArea: "1 / 1", width: 9, height: 9, borderRadius: "50%", background: Palette.label, transform: `scale(${1 - 0.6 * s})`, opacity: 1 - s }} />
                  <span
                    style={{
                      gridArea: "1 / 1",
                      fontFamily: fonts.mono,
                      fontSize: 20,
                      lineHeight: "24px",
                      fontWeight: 600,
                      color: Palette.label,
                      filter: s < 0.999 ? `blur(${5 * (1 - s)}px)` : undefined,
                      transform: `translateY(${6 * (1 - s)}px)`,
                      opacity: s,
                    }}
                  >
                    {c}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to hide or show the password" zh="点击隐藏或显示密码" />
    </Stage>
  );
}
