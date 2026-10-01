/** icons.link-break · 链接断开 (Icons+LinkBreak.swift) */
import { useId } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { Replace } from "./_icons-kit";
import { CheckCircleFill, IC, Item, Stage, Svg, XCircleFill, Z, useIconNow, useLater, usePlayhead } from "./_time-kit";

const LW = 100;
const LH = 62;
const LINE = 12;
/** Half the distance between the two link centres while linked. */
const REACH = 29;
const SNAP = 0.1;

export default function LinkBreak({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** On = broken. */
  const play = usePlayhead(false);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const broken = play.isOn;

  const gap = ctx.n("gap");
  const damping = ctx.n("damping");
  const ticks = Math.max(ctx.i("ticks"), 0);

  const toggle = (scripted = false) => {
    const on = play.toggle(0.7, 0.6);
    haptics.tap("light");
    later(on ? 0.1 : 0.09, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 1.8 });

  // 0 = linked, 1 = apart. Negative while the links push past each other on the way back.
  const amount = broken
    ? Math.max((3 / Math.max(gap, 1)) * IC.easeOut(IC.seg(t, 0, SNAP)), IC.spring(t - SNAP, 0.3, damping))
    : 1 - IC.spring(t, 0.3, damping);
  const grey = broken ? IC.seg(t, SNAP, SNAP + 0.25) : 1 - IC.seg(t, 0.04, 0.2);
  const jolt = broken ? 3 * IC.shake(t - SNAP, 10, 34) : 0;
  const shift = REACH + gap * amount;
  const twist = 9 * amount;

  const link = (side: number, paint: string, width: number) => (
    <g transform={`translate(${side * shift} 0) rotate(${-twist})`}>
      <rect x={-LW / 2} y={-LH / 2} width={LW} height={LH} rx={LH / 2} fill="none" stroke={paint} strokeWidth={width} />
    </g>
  );
  const chain = (paint: string, opacity?: number) => (
    <g opacity={opacity}>
      <g mask={`url(#${uid}-gap)`}>{link(-1, paint, LINE)}</g>
      {link(1, paint, LINE)}
    </g>
  );

  const tp = IC.seg(t - SNAP, 0, 0.3);
  const tickLive = broken && tp > 0 && tp < 1;
  const rp = IC.seg(t - 0.09, 0, 0.45);
  const ringLive = !broken && rp > 0 && rp < 1;
  const pairs = Math.max(Math.floor((ticks + 1) / 2), 1);

  return (
    <Stage gap={10}>
      <Z w={250} h={200} onClick={() => toggle()}>
        <Z style={{ gridArea: "1 / 1", transform: `translate(${jolt}px, ${-jolt}px) rotate(-45deg)` }}>
          <Svg w={60} h={60} tf={`scale(${0.5 + 1.9 * IC.easeOut(rp)})`} o={ringLive ? 1 : 0}>
            <circle r={30} fill="none" stroke={hex(0x3ac4ff, 0.7 * (1 - rp))} strokeWidth={4 * (1 - rp) + 0.5} />
          </Svg>
          <Svg w={250} h={200} style={{ filter: `drop-shadow(0 7px 12px ${hex(0x4f7cff, 0.32 * (1 - grey))})` }}>
            <defs>
              <linearGradient id={`${uid}-ocean`} x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stopColor={Palette.sky} />
                <stop offset="1" stopColor={Palette.blue} />
              </linearGradient>
              {/* The top link cuts a gap out of the one beneath it. */}
              <mask id={`${uid}-gap`} maskUnits="userSpaceOnUse" x={-200} y={-150} width={400} height={300}>
                <rect x={-200} y={-150} width={400} height={300} fill="#fff" />
                {link(1, "#000", LINE + 10)}
              </mask>
            </defs>
            {chain(`url(#${uid}-ocean)`)}
            {chain(hex(0x8e8e99), grey)}
          </Svg>
          <Z style={{ gridArea: "1 / 1", opacity: tickLive ? 1 - IC.easeIn(tp) : 0 }}>
            {Array.from({ length: ticks }, (_, index) => {
              // Half of the ticks fly to each side of the axis, fanned ±28°.
              const side = index % 2 === 0 ? -90 : 90;
              const fan = pairs > 1 ? (Math.floor(index / 2) / (pairs - 1) - 0.5) * 56 : 0;
              return (
                <Item
                  key={index}
                  w={16 * IC.bump(tp) + 2}
                  h={6}
                  tf={`rotate(${side + fan}deg) translateX(${40 + 22 * IC.easeOut(tp)}px)`}
                  style={{ borderRadius: 3, background: Palette.amber }}
                />
              );
            })}
          </Z>
        </Z>
      </Z>
      <div style={{ display: "flex", alignItems: "center", gap: 6, ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        <Replace k={broken ? "x" : "ok"}>{broken ? <XCircleFill size={18} color="currentColor" /> : <CheckCircleFill size={18} color="currentColor" />}</Replace>
        <span style={{ display: "grid" }}>
          {[false, true].map((state) => (
            <span key={String(state)} style={{ gridArea: "1 / 1", justifySelf: "start", whiteSpace: "nowrap", opacity: broken === state ? 1 : 0, transition: "opacity 0.25s ease-in-out" }}>
              {state ? ctx.t("Link removed", "链接已断开") : ctx.t("Linked", "已链接")}
            </span>
          ))}
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap to break or restore the link" zh="点击断开或恢复链接" />
    </Stage>
  );
}
