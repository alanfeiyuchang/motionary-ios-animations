/** icons.sun-moon · 日月切换 (Icons+SunMoon.swift) */
import { useId } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { IC, Item, Stage, Svg, Z, sparklePath, useIconNow, usePlayhead } from "./_time-kit";

const NIGHT = 0.9;
const TILE = 176;
const DISC = 62;
const CLOUD = "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z";

function Cloud({ points, opacity, x, y }: { points: number; opacity: number; x: number; y: number }) {
  const size = points * 1.5;
  return (
    <Item w={size} h={size} tf={`translate(${x}px, ${y}px)`}>
      <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }}>
        <path d={CLOUD} fill={`rgb(255 255 255 / ${opacity})`} />
      </svg>
    </Item>
  );
}

export default function SunMoon({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const play = usePlayhead(false);
  const clock = useIconNow(ctx.isPreview);
  const t = play.elapsed(clock);
  const night = play.isOn;

  const rays = Math.max(ctx.i("rays"), 1);
  const stagger = ctx.n("stagger");
  const damping = ctx.n("damping");

  const toggle = () => {
    play.toggle(NIGHT, 0.8 + ctx.i("rays") * stagger);
    haptics.tap("light");
  };
  useAutoplay(ctx.isPreview, toggle, { every: 2.0 });

  const duskP = IC.smooth(IC.seg(t, 0.05, 0.6));
  const dusk = night ? duskP : 1 - duskP;
  const bite = night ? IC.spring(t - 0.18, 0.5, 0.75) : 1 - IC.spring(t - 0.08, 0.45, 0.8);
  const rayLength = (index: number) => {
    const delay = index * stagger;
    if (night) return 1 - IC.easeIn(IC.seg(t, delay, delay + 0.22));
    return IC.spring(t - 0.3 - delay, 0.35, damping);
  };
  const turnP = IC.easeInOut(IC.seg(t, 0, night ? 0.5 : 0.7));
  const ringTurn = night ? 60 * turnP : 60 * (1 - turnP);
  const starScale = (index: number) => {
    const delay = index * 0.09;
    if (night) return IC.spring(t - 0.34 - delay, 0.4, 0.5);
    return 1 - IC.easeIn(IC.seg(t, delay * 0.5, delay * 0.5 + 0.16));
  };
  const press = 0.05 * IC.bump(IC.seg(t, 0, 0.3));
  const drift = Math.sin(clock * 0.6) * 4;

  const clamped = IC.unit(bite);
  const pulse = night ? 0 : 0.08 * IC.bump(IC.seg(t, 0.3, 0.62));
  const discScale = 1 + 0.22 * bite + pulse;
  const shadowX = IC.mix(64, 15, bite);
  const shadowY = IC.mix(-64, -13, bite);

  const popStar = (index: number, x: number, y: number, size: number) => {
    const scale = Math.max(starScale(index), 0);
    const twinkle = 0.86 + 0.14 * Math.sin(clock * 3.1 + index * 2.1);
    return (
      <Svg
        key={index}
        w={size}
        h={size}
        tf={`translate(${x}px, ${y}px) rotate(${30 * (1 - scale)}deg) scale(${scale * twinkle})`}
        style={{ filter: "drop-shadow(0 0 5px rgb(255 255 255 / 0.7))" }}
      >
        <path d={sparklePath(size / 2)} fill="#fff" />
      </Svg>
    );
  };

  return (
    <Stage gap={14}>
      <Z w={210} h={196} onClick={toggle}>
        <Item
          w={TILE}
          h={TILE}
          tf={`scale(${1 - press})`}
          style={{ filter: `drop-shadow(0 10px 18px ${hex(0x3aa0ff, 0.35 * (1 - dusk))}) drop-shadow(0 10px 18px ${hex(0x2b2470, 0.5 * dusk)})` }}
        >
          <Z w={TILE} h={TILE} style={{ borderRadius: 46, overflow: "hidden", background: `linear-gradient(${hex(0x57c1ff)}, ${hex(0x2f86f6)})` }}>
            <Item w={TILE} h={TILE} o={dusk} style={{ background: `linear-gradient(${hex(0x151a45)}, ${hex(0x3c2e86)})` }} />
            <Z style={{ gridArea: "1 / 1", opacity: 1 - dusk }}>
              <Cloud points={58} opacity={0.92} x={-50 + drift - 70 * dusk} y={58} />
              <Cloud points={30} opacity={0.6} x={56 - drift + 60 * dusk} y={-56} />
            </Z>
            <Z style={{ gridArea: "1 / 1", opacity: dusk * 0.8 }}>
              {Array.from({ length: 9 }, (_, index) => {
                const x = (IC.hash(index * 3 + 1) - 0.5) * 150;
                const y = (IC.hash(index * 3 + 2) - 0.5) * 150;
                const twinkle = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(clock * (1.6 + index * 0.3) + index));
                return <Item key={index} w={2.5} h={2.5} o={twinkle} tf={`translate(${x}px, ${y + 14 * (1 - dusk)}px)`} style={{ borderRadius: "50%", background: "#fff" }} />;
              })}
            </Z>
            <Z style={{ gridArea: "1 / 1", transform: `rotate(${ringTurn}deg)`, filter: `drop-shadow(0 0 6px ${hex(0xffd45c, 0.6)})` }}>
              {Array.from({ length: rays }, (_, index) => {
                const length = rayLength(index);
                return (
                  <Item
                    key={index}
                    w={6.5}
                    h={Math.max(15 * length, 0.01)}
                    tf={`rotate(${(index / rays) * 360}deg) translateY(${-(41 + 7.5 * length)}px)`}
                    o={IC.unit(length * 4)}
                    style={{ borderRadius: 3.25, background: hex(0xffe27a) }}
                  />
                );
              })}
            </Z>
            <Svg
              w={DISC}
              h={DISC}
              tf={`scale(${discScale}) rotate(${-18 * (1 - bite)}deg)`}
              style={{ filter: `drop-shadow(0 0 14px ${hex(0xffd45c, 0.75 * (1 - clamped))}) drop-shadow(0 0 12px ${hex(0xfff6d0, 0.55 * clamped)})` }}
            >
              <defs>
                <radialGradient id={`${uid}-sun`} cx={-DISC / 2} cy={-DISC / 2} r={70} gradientUnits="userSpaceOnUse">
                  <stop offset={2 / 70} stopColor={hex(0xfff2a6)} />
                  <stop offset={0.51} stopColor={hex(0xffc83d)} />
                  <stop offset="1" stopColor={hex(0xff9f2e)} />
                </radialGradient>
                <radialGradient id={`${uid}-moon`} cx={-DISC / 2} cy={-DISC / 2} r={70} gradientUnits="userSpaceOnUse">
                  <stop offset={2 / 70} stopColor={hex(0xfffdf0)} />
                  <stop offset={0.51} stopColor={hex(0xf3e9c4)} />
                  <stop offset="1" stopColor={hex(0xd8cfa8)} />
                </radialGradient>
                <mask id={`${uid}-bite`} maskUnits="userSpaceOnUse" x={-DISC} y={-DISC} width={DISC * 2} height={DISC * 2}>
                  <rect x={-DISC} y={-DISC} width={DISC * 2} height={DISC * 2} fill="#fff" />
                  <circle cx={shadowX} cy={shadowY} r={DISC * 0.45} fill="#000" />
                </mask>
              </defs>
              <g mask={`url(#${uid}-bite)`}>
                <circle r={DISC / 2} fill={`url(#${uid}-sun)`} />
                <circle r={DISC / 2} fill={`url(#${uid}-moon)`} opacity={clamped} />
              </g>
            </Svg>
            {popStar(0, 46, -40, 22)}
            {popStar(1, 58, 10, 13)}
            {popStar(2, -52, 44, 16)}
          </Z>
          <div style={{ position: "absolute", inset: 0, borderRadius: 46, boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.22)", pointerEvents: "none" }} />
        </Item>
      </Z>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {[false, true].map((state) => (
          <span key={String(state)} style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap", opacity: night === state ? 1 : 0, transition: "opacity 0.3s ease-in-out" }}>
            {state ? ctx.t("Dark appearance", "深色外观") : ctx.t("Light appearance", "浅色外观")}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to switch" zh="点击切换" />
    </Stage>
  );
}
