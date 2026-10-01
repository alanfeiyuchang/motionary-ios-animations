/** icons.archive-box · 归档入箱 (Icons+ArchiveBox.swift) */
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Z, checkPath, nowSeconds, rotateAt, scaleAt, since, useIconNow, useLater } from "./_time-kit";

const LANDING = 0.56;
const BUSY = 1.35;
const BOX_W = 136;
const BOX_H = 86;
const FLAP = 11;
const BOX_TOP = 10;
const DOC_REST = -64;

function Document() {
  return (
    <div
      style={{
        width: 56,
        height: 70,
        borderRadius: 8,
        background: "#fff",
        boxShadow: "inset 0 0 0 1px rgb(0 0 0 / 0.06), 0 5px 8px rgb(0 0 0 / 0.18)",
        padding: 10,
        boxSizing: "border-box",
        display: "flex",
        flexDirection: "column",
        alignItems: "flex-start",
        gap: 6,
      }}
    >
      <div style={{ width: 26, height: 6, borderRadius: 3, background: Palette.ocean }} />
      <div style={{ width: 36, height: 4, borderRadius: 2, background: "rgb(0 0 0 / 0.14)" }} />
      <div style={{ width: 36, height: 4, borderRadius: 2, background: "rgb(0 0 0 / 0.14)" }} />
      <div style={{ width: 22, height: 4, borderRadius: 2, background: "rgb(0 0 0 / 0.14)" }} />
    </div>
  );
}

export default function ArchiveBox({ ctx }: DemoProps) {
  const { haptics, after, later } = useLater();
  const start = useRef(DISTANT_PAST);
  const [plays, setPlays] = useState(0);
  const [archived, setArchived] = useState(12);
  const clock = useIconNow(ctx.isPreview);
  const t = since(clock, start.current);

  const flap = ctx.n("flap");
  const bounce = ctx.n("bounce");
  const squash = ctx.n("squash");
  const sealedBefore = plays > 1;
  const played = plays > 0;

  const archive = (scripted = false) => {
    // One document at a time: taps are ignored until the box is sealed.
    if (since(nowSeconds(), start.current) <= BUSY) return;
    start.current = nowSeconds();
    setPlays((p) => p + 1);
    haptics.tap("light");
    after(LANDING, () => setArchived((n) => n + 1));
    later(LANDING, scripted, (h) => h.tap("medium"));
    later(0.9, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => archive(true), { every: 2.5 });

  const openAngle = (delay: number) => {
    const opening = IC.spring(t - 0.05 - delay, 0.32, 0.6);
    const closing = IC.spring(t - 0.66 - delay * 1.4, 0.36, 1 - bounce);
    return flap * opening * Math.abs(1 - closing);
  };
  const sq = squash * IC.ring(t - 0.56, 12, 30) + 0.035 * IC.ring(t - 0.92, 14, 32);
  const fresh = IC.easeOut(IC.seg(t, 1.0, 1.22));
  const seal = sealedBefore ? Math.max(1 - IC.easeIn(IC.seg(t, 0, 0.12)), fresh) : played ? fresh : 0;
  const stamp = IC.spring(t - 1.12, 0.34, 0.5);
  const stamped = sealedBefore ? Math.max(1 - IC.seg(t, 0, 0.12), stamp) : played ? stamp : 0;

  const resting = t > 1.9;
  const hop = resting ? 0 : IC.easeOut(IC.seg(t, 0.08, 0.28));
  const fall = resting ? 0 : IC.easeIn(IC.seg(t, 0.28, 0.56));
  const bob = resting ? 3 * Math.sin(clock * 2.2) * IC.seg(t, 1.9, 2.5) : 0;
  const docY = DOC_REST - 14 * hop + 126 * fall + bob;
  const tilt = -7 * hop + 17 * fall;
  const arrive = IC.spring(t - 1.3, 0.4, 0.6);
  const half = BOX_W / 2 + 2;

  const flapStyle = {
    width: half,
    height: FLAP,
    borderRadius: 4,
    background: `linear-gradient(${hex(0xf6d09a)}, ${hex(0xe0a862)})`,
    boxShadow: `inset 0 0 0 1px ${hex(0xb67a3c, 0.55)}`,
  };

  return (
    <Stage gap={8}>
      <Z w={250} h={222} onClick={() => archive()}>
        <Item
          w={BOX_W * (1.02 + sq * 1.2)}
          h={16}
          tf={`translateY(${BOX_TOP + BOX_H + 2}px)`}
          style={{ borderRadius: "50%", background: "rgb(0 0 0 / 0.2)", filter: "blur(7px)" }}
        />
        <Z w={250} h={222} style={{ gridArea: "1 / 1", transform: scaleAt(1 + sq * 0.6, 1 - sq, 0, 0.43 * 222) }}>
          <Item w={BOX_W - 8} h={14} tf={`translateY(${BOX_TOP + 3}px)`} style={{ borderRadius: "4px 4px 0 0", background: hex(0x7a4e26) }} />
          <Item tf={`translateY(${docY}px) rotate(${tilt}deg) scale(${1 - 0.18 * fall})`} o={t < 0.6 || resting ? 1 : 0}>
            <Document />
          </Item>
          <Item
            w={BOX_W}
            h={BOX_H}
            tf={`translateY(${BOX_TOP + BOX_H / 2}px)`}
            style={{ borderRadius: "5px 5px 14px 14px", overflow: "hidden", background: `linear-gradient(${hex(0xedbe7e)}, ${hex(0xcb8d4b)})` }}
          >
            <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 3, background: hex(0xa86c33, 0.5) }} />
            <div
              style={{
                position: "absolute",
                left: BOX_W / 2 - 15,
                top: 0,
                width: 30,
                height: 26 * seal,
                background: "linear-gradient(rgb(255 255 255 / 0.75), rgb(255 255 255 / 0.5))",
              }}
            />
            <div
              style={{
                position: "absolute",
                left: BOX_W / 2 - 32,
                top: BOX_H / 2 - 16 + 12,
                width: 64,
                height: 32,
                borderRadius: 7,
                background: "rgb(255 255 255 / 0.92)",
                boxShadow: `0 1px 2px ${hex(0x7a4e26, 0.3)}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 7,
              }}
            >
              <svg width={17} height={17} viewBox="0 0 17 17" style={{ transform: `scale(${Math.max(stamped, 0)})`, overflow: "visible" }}>
                <circle cx={8.5} cy={8.5} r={8.5} fill={Palette.green} />
                <path d={checkPath(9, 8)} transform="translate(4 4.5)" fill="none" stroke="#fff" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 4 }}>
                <div style={{ width: 26, height: 4, borderRadius: 2, background: hex(0x8a6a45, 0.55) }} />
                <div style={{ width: 18, height: 4, borderRadius: 2, background: hex(0x8a6a45, 0.3) }} />
              </div>
            </div>
          </Item>
          <Item tf={`translateY(${BOX_TOP - FLAP / 2 + 1}px)`} style={{ display: "flex" }}>
            <div style={{ ...flapStyle, transform: rotateAt(-openAngle(0), -half / 2, FLAP / 2) }} />
            <div style={{ ...flapStyle, transform: rotateAt(openAngle(0.06), half / 2, FLAP / 2) }} />
          </Item>
        </Z>
        <Item tf={`translateY(${DOC_REST - 26 * (1 - arrive)}px) scale(${0.5 + 0.5 * arrive})`} o={t >= 1.3 && t <= 1.9 ? IC.seg(t, 1.3, 1.42) : 0}>
          <Document />
        </Item>
      </Z>
      <div style={{ display: "flex", gap: 6, ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        <NumericText value={archived} />
        <span>{ctx.t("documents archived", "份文件已归档")}</span>
      </div>
      <DemoHint ctx={ctx} en="Tap to archive the document" zh="点击归档文件" />
    </Stage>
  );
}
