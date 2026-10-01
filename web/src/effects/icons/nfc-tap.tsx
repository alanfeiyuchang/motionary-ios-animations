/** icons.nfc-tap · 感应支付 (Icons+NfcTap.swift) */
import { useId, useRef } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, arcPath, checkPath, nowSeconds, rr, since, useIconNow, useLater, usePhase } from "./_time-kit";

const CONTACT = 0.26;
const TILE = 128;
const TILE_Y = -46;
const CARD_W = 118;
const CARD_H = 74;
const GREEN = 0x2cc873;
/** Centre of the contactless arcs (the leading edge of their 64 × 90 box, nudged 2 pt right). */
const WAVE_X = -30;

export default function NfcTap({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  const start = useRef(DISTANT_PAST);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);
  const phase = usePhase(now, ctx.n("pulse") * 3.2);

  const bump = ctx.n("bump");
  const hold = ctx.n("hold");
  const total = CONTACT + 0.6 + hold + 0.7;
  const done = t > CONTACT + 0.3 && t < CONTACT + 0.6 + hold;

  const tap = (scripted = false) => {
    // One tap at a time: ignored until the card is back down.
    if (since(nowSeconds(), start.current) <= total) return;
    start.current = nowSeconds();
    haptics.tap("light");
    later(CONTACT, scripted, (h) => h.tap("rigid"));
    later(CONTACT + 0.5, scripted, (h) => h.success());
  };
  useAutoplay(ctx.isPreview, () => tap(true), { every: total + 0.5 });

  /** When the confirmation is cleared and the card leaves. */
  const release = CONTACT + 0.6 + hold;
  const near = IC.spring(t, 0.3, 0.6) * (1 - IC.easeInOut(IC.seg(t, release, release + 0.4)));
  const ok = IC.seg(t, CONTACT + 0.06, CONTACT + 0.3) * (1 - IC.seg(t, release, release + 0.2));
  const s = t - CONTACT;
  const thump = bump * IC.ring(s, 9, 24) * IC.seg(s, 0, 0.03);

  const ring = IC.easeOut(IC.seg(s, 0.2, 0.48));
  const tick = IC.easeOut(IC.seg(s, 0.4, 0.6));
  const pop = 0.26 * IC.shake(s - 0.5, 9, 20);
  const leaving = IC.seg(t, release, release + 0.2);
  const op = IC.seg(s - 0.46, 0, 0.55);
  const nearU = IC.unit(near);
  const green = hex(GREEN);
  const line = { fill: "none", stroke: green, strokeWidth: 8, strokeLinecap: "round" as const, strokeLinejoin: "round" as const, pathLength: 1 };

  return (
    <Stage gap={10}>
      <Z w={250} h={226} onClick={() => tap()}>
        {/* A rounded outline that spreads from the tile as the tick lands. */}
        <Svg w={TILE} h={TILE} tf={`translateY(${TILE_Y}px) scale(${1 + 0.32 * IC.easeOut(op)})`} o={op > 0 && op < 1 ? 1 : 0}>
          <path d={rr(-TILE / 2, -TILE / 2, TILE, TILE, 34)} fill="none" stroke={hex(GREEN, 0.6 * (1 - op))} strokeWidth={4 * (1 - op) + 0.5} />
        </Svg>
        <Item w={TILE} h={TILE} tf={`translateY(${TILE_Y - 5 * thump}px) scale(${1 + 0.05 * thump})`}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 34,
              background: `linear-gradient(${hex(GREEN, 0.12 * ok)}, ${hex(GREEN, 0.12 * ok)}), ${Palette.elevated}`,
              boxShadow: `inset 0 0 0 2px ${hex(GREEN, 0.7 * ok)}, inset 0 0 0 1px ${Palette.labelAlpha(0.08)}, 0 9px 16px rgb(0 0 0 / 0.14)`,
            }}
          />
          <svg width={TILE} height={TILE} viewBox={`${-TILE / 2} ${-TILE / 2} ${TILE} ${TILE}`} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <defs>
              <linearGradient id={`${uid}-ocean`} x1={WAVE_X} y1={-45} x2={WAVE_X + 64} y2={45} gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor={Palette.sky} />
                <stop offset="1" stopColor={Palette.blue} />
              </linearGradient>
            </defs>
            {[0, 1, 2, 3].map((index) => {
              const order = 3 - index;
              const fold = IC.easeIn(IC.seg(s, 0.06 + 0.03 * order, 0.22 + 0.03 * order));
              const back = IC.spring(t - release - 0.12 - 0.06 * index, 0.34, 0.5);
              const amount = t < release ? 1 - fold : back;
              const shown = IC.unit(amount);
              if (shown <= 0.001) return null;
              const idle = 0.4 + 0.6 * Math.max(0, Math.sin(phase - index * 0.9));
              // Every arc lights up at the moment of contact.
              const flash = IC.bump(IC.seg(s, 0, 0.2));
              return (
                <g key={index} transform={`translate(${WAVE_X} 0) scale(${0.84 + 0.16 * amount}) translate(${-WAVE_X} 0)`} opacity={IC.unit(shown * 2) * Math.max(idle, flash)}>
                  <path
                    d={arcPath(WAVE_X, 0, 14 + 15 * index, -40, 40)}
                    fill="none"
                    stroke={`url(#${uid}-ocean)`}
                    strokeWidth={8}
                    strokeLinecap="round"
                    pathLength={1}
                    strokeDasharray={`${shown} 2`}
                    strokeDashoffset={-(0.5 - 0.5 * shown)}
                  />
                </g>
              );
            })}
            {ring > 0 && (
              <g transform={`scale(${(1 + pop) * (1 - 0.3 * leaving)})`} opacity={1 - leaving} style={{ filter: `drop-shadow(0 3px 8px ${hex(GREEN, 0.4)})` }}>
                <circle r={35} transform="rotate(-90)" strokeDasharray={`${ring} 2`} {...line} />
                {tick > 0 && <path d={checkPath(32, 26)} transform="translate(-16 -13)" strokeDasharray={`${tick} 2`} {...line} />}
              </g>
            )}
          </svg>
        </Item>
        <Item
          w={CARD_W}
          h={CARD_H}
          tf={`translate(${IC.mix(10, 4, near)}px, ${IC.mix(62, 24, near)}px) rotate(${IC.mix(-8, -3, near)}deg)`}
          style={{
            borderRadius: 14,
            background: `linear-gradient(135deg, rgb(255 255 255 / 0.28), rgb(255 255 255 / 0) 50%), linear-gradient(to bottom right, ${hex(0x7c83ff)}, ${hex(0xa352f0)})`,
            boxShadow: `inset 0 0 0 1px rgb(255 255 255 / 0.25), 0 ${6 + 6 * nearU}px ${10 + 6 * nearU}px ${hex(0x5a3fd0, 0.3 + 0.15 * nearU)}`,
          }}
        >
          <div style={{ position: "absolute", left: 14, top: 14, width: 22, height: 17, borderRadius: 4, background: `linear-gradient(${hex(0xffe08a)}, ${hex(0xf5a623)})` }} />
          <div style={{ position: "absolute", left: 14, bottom: 13, display: "flex", gap: 5 }}>
            {[0, 1, 2, 3].map((i) => (
              <div key={i} style={{ width: 17, height: 5, borderRadius: 2.5, background: "rgb(255 255 255 / 0.75)" }} />
            ))}
          </div>
        </Item>
      </Z>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600 }}>
        {[false, true].map((state) => (
          <span
            key={String(state)}
            style={{
              gridArea: "1 / 1",
              textAlign: "center",
              whiteSpace: "nowrap",
              color: state ? Palette.green : Palette.secondaryLabel,
              opacity: done === state ? 1 : 0,
              transition: "opacity 0.22s ease-in-out",
            }}
          >
            {state ? ctx.t("Done", "完成") : ctx.t("Hold near the reader", "请靠近读卡器")}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to present the card" zh="点击出示卡片" />
    </Stage>
  );
}
