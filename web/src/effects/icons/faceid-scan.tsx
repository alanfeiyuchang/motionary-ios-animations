/** icons.faceid-scan · 面容扫描 (Icons+FaceIDScan.swift) */
import { useRef, useState } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, nowSeconds, rr, since, useIconNow, useLater } from "./_time-kit";

const SCAN_START = 0.3;
const FRAME = 138;
const SW = 7.5;

/** Four corner brackets of a rounded square. `close` 0 = brackets, 1 = arms meet and the corners become a circle. */
function brackets(close: number) {
  const half = FRAME / 2;
  const amount = IC.unit(close);
  const radius = half * (0.44 + 0.56 * amount);
  const restArm = half * 0.1;
  const arm = restArm + (half - radius - restArm) * amount;
  let d = "";
  for (const [sx, sy] of [
    [-1, -1],
    [1, -1],
    [1, 1],
    [-1, 1],
  ]) {
    const cx = sx * half;
    const cy = sy * half;
    d += `M${cx - sx * (radius + arm)} ${cy}L${cx - sx * radius} ${cy}A${radius} ${radius} 0 0 ${sx * sy > 0 ? 0 : 1} ${cx} ${cy - sy * radius}L${cx} ${cy - sy * (radius + arm)}`;
  }
  return d;
}

/** The mouth: a smile at `check` 0, a check mark at 1. */
function mouth(check: number) {
  const p = IC.unit(check);
  const smile = [[-22, 24], [-12, 33], [0, 33], [12, 33], [22, 24]];
  const mark = [[-25, 2], [-17, 11], [-9, 20], [9, 0], [27, -20]];
  const pt = smile.map((s, i) => `${s[0] + (mark[i][0] - s[0]) * p} ${s[1] + (mark[i][1] - s[1]) * p}`);
  return `M${pt[0]}Q${pt[1]} ${pt[2]}Q${pt[3]} ${pt[4]}`;
}
const NOSE = "M3 -14L3 4Q3 10 -5 10";

const SEAL =
  "M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z";

export default function FaceIDScan({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const start = useRef(DISTANT_PAST);
  const [runs, setRuns] = useState(0);
  const clock = useIconNow(ctx.isPreview);
  const t = since(clock, start.current);

  const duration = ctx.n("duration");
  const passes = Math.max(ctx.i("passes"), 1);
  const glow = ctx.n("glow");
  const scanEnd = SCAN_START + duration;
  const idle = runs === 0;
  const reopening = runs > 1;
  const after = idle ? -1 : t - scanEnd;

  const scan = (scripted = false) => {
    // A scan already under way finishes first.
    if (since(nowSeconds(), start.current) <= scanEnd + 0.7) return;
    setRuns((r) => r + 1);
    start.current = nowSeconds();
    haptics.tap("light");
    later(scanEnd + 0.12, scripted, (h) => h.success());
  };
  useAutoplay(ctx.isPreview, () => scan(true), { every: scanEnd + 2.0 });

  const reopen = reopening ? 1 - IC.easeInOut(IC.seg(t, 0, 0.28)) : 0;
  const closed = idle ? 0 : t < scanEnd ? reopen : IC.spring(after, 0.5, 0.72);
  const morph = idle ? 0 : t < scanEnd ? reopen : IC.easeInOut(IC.seg(after, 0.05, 0.4));
  const scanningNow = !idle && t >= SCAN_START && t < scanEnd;
  const u = (t - SCAN_START) / Math.max(duration, 0.01);
  const position = scanningNow ? -Math.cos(Math.PI * passes * u) : 0;
  const barOpacity = idle ? 0 : IC.seg(t, SCAN_START, SCAN_START + 0.12) * (1 - IC.seg(t, scanEnd - 0.12, scanEnd));

  const green = IC.unit(closed * 1.4);
  const breathe = idle ? 0.025 * Math.sin(clock * 2.2) : 0;
  const tighten = idle || t >= scanEnd ? 0 : 0.05 * IC.easeOut(IC.seg(t, 0.05, 0.3));
  const pop = 0.115 * IC.shake(after, 8, 15);
  const rippleP = IC.seg(after, 0.12, 0.8);

  const boostAt = (y: number) => {
    if (!scanningNow) return 0;
    const distance = (position * FRAME * 0.42 - y) / 15;
    return Math.exp(-distance * distance) * barOpacity;
  };
  const gone = IC.unit(morph * 2.2);
  const mouthGreen = IC.unit(morph * 1.5);
  const down = Math.sin(Math.PI * passes * u) >= 0;
  const barY = position * FRAME * 0.42;
  const bracketPath = brackets(closed);
  const mouthPath = mouth(morph);
  const mouthW = SW + 1.5 * morph;

  /** A facial feature that lights up as the scan bar crosses height `y`. */
  const feature = (y: number, boostScale: number, outer: number, opacity: number, draw: (color: string, o?: number) => React.ReactNode) => {
    const boost = boostAt(y);
    return (
      <g transform={`scale(${outer})`} opacity={opacity}>
        <g transform={`scale(${1 + boostScale * boost})`} style={{ filter: boost > 0.01 ? `drop-shadow(0 0 8px ${hex(0x3ac4ff, 0.7 * boost * glow)})` : undefined }}>
          {draw(Palette.label)}
          {draw(Palette.sky, boost)}
        </g>
      </g>
    );
  };
  const stroke = { fill: "none", strokeLinecap: "round" as const, strokeLinejoin: "round" as const };

  const scanning = idle ? 0 : IC.seg(t, 0.1, 0.3) * (1 - IC.seg(t, scanEnd, scanEnd + 0.2));
  const done = idle ? 0 : t < scanEnd ? 1 - IC.seg(t, 0, 0.15) : IC.easeOut(IC.seg(t, scanEnd + 0.15, scanEnd + 0.4));
  const verified = runs > 1 || t >= scanEnd;

  return (
    <Stage gap={8}>
      <div onClick={() => scan()} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8, cursor: "pointer" }}>
        <Z w={250} h={200}>
          <Z style={{ gridArea: "1 / 1", transform: `scale(${1 + pop})` }}>
            <Svg w={FRAME} h={FRAME} tf={`scale(${1 + 0.42 * IC.easeOut(rippleP)})`} o={rippleP > 0 && rippleP < 1 ? 1 : 0}>
              <circle r={FRAME / 2} fill="none" stroke={hex(0x34c77b, 0.6 * (1 - rippleP))} strokeWidth={5 * (1 - rippleP) + 0.5} />
            </Svg>
            <Item w={FRAME} h={FRAME} tf={`scale(${0.8 + 0.2 * IC.unit(closed)})`} style={{ borderRadius: "50%", background: hex(0x34c77b, 0.14 * green) }} />
            <Item w={FRAME - 12} h={FRAME - 12} o={barOpacity} style={{ borderRadius: FRAME * 0.22, overflow: "hidden" }}>
              <div
                style={{
                  position: "absolute",
                  left: 3,
                  top: (FRAME - 12) / 2 + barY + (down ? -17 : 17) - 17,
                  width: FRAME - 18,
                  height: 34,
                  background: `linear-gradient(${down ? "to bottom" : "to top"}, ${hex(0x3ac4ff, 0)}, ${hex(0x3ac4ff, 0.32)})`,
                }}
              />
              <div
                style={{
                  position: "absolute",
                  left: 1,
                  top: (FRAME - 12) / 2 + barY - 1.75,
                  width: FRAME - 14,
                  height: 3.5,
                  borderRadius: 1.75,
                  background: `linear-gradient(to right, ${hex(0x3ac4ff, 0.2)}, #fff, ${hex(0x3ac4ff, 0.2)})`,
                  boxShadow: `0 0 ${4 + 8 * glow}px ${hex(0x3ac4ff, glow)}`,
                }}
              />
            </Item>
            <Svg w={FRAME} h={FRAME}>
              {feature(-18, 0.08, 1 - 0.7 * gone, 1 - gone, (color, o) => (
                <g opacity={o} style={{ fill: color }}>
                  <path d={rr(-21.25 - 4.25, -28, 8.5, 20, 4.25)} />
                  <path d={rr(21.25 - 4.25, -28, 8.5, 20, 4.25)} />
                </g>
              ))}
              {feature(-2, 0.08, 1 - 0.7 * gone, 1 - gone, (color, o) => (
                <path d={NOSE} opacity={o} strokeWidth={SW} {...stroke} style={{ stroke: color }} />
              ))}
              {feature(30, 0.08 * (1 - morph), 1, 1, (color, o) => (
                <path d={mouthPath} opacity={o} strokeWidth={mouthW} {...stroke} style={{ stroke: color }} />
              ))}
              <path d={mouthPath} opacity={mouthGreen} strokeWidth={mouthW} {...stroke} stroke={Palette.green} />
            </Svg>
            <Svg w={FRAME} h={FRAME} tf={`scale(${1 + breathe - tighten})`}>
              <g strokeWidth={SW} {...stroke}>
                <path d={bracketPath} style={{ stroke: Palette.label }} />
                <path d={bracketPath} stroke={Palette.sky} opacity={barOpacity} />
                <path d={bracketPath} stroke={Palette.green} opacity={green} />
              </g>
            </Svg>
          </Z>
        </Z>
        <Z h={20} style={{ ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
          <Item o={idle ? 1 : 0}>{ctx.t("Ready to scan", "准备扫描")}</Item>
          <Item o={scanning}>{ctx.t("Scanning…", "正在扫描…")}</Item>
          <Item o={verified ? done : 0} tf={`translateY(${t < scanEnd ? 0 : 8 * (1 - done)}px)`} style={{ display: "flex", alignItems: "center", gap: 5, color: Palette.green }}>
            <svg width={18} height={18} viewBox="0 0 24 24" style={{ display: "block" }}>
              <mask id="faceid-seal" maskUnits="userSpaceOnUse" x={0} y={0} width={24} height={24}>
                <rect width={24} height={24} fill="#fff" />
                <path d="m8.6 12.2 2.4 2.4 4.6-4.9" fill="none" stroke="#000" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" />
              </mask>
              <path d={SEAL} fill="currentColor" stroke="currentColor" strokeWidth={1.4} strokeLinejoin="round" mask="url(#faceid-seal)" />
            </svg>
            <span>{ctx.t("Verified", "验证通过")}</span>
          </Item>
        </Z>
      </div>
      <DemoHint ctx={ctx} en="Tap to scan" zh="点击开始扫描" />
    </Stage>
  );
}
