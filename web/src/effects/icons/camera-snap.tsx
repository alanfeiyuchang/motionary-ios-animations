/** icons.camera-snap · 相机快门 (Icons+CameraSnap.swift) */
import { Images } from "lucide-react";
import { useId, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, nowSeconds, since, sparklePath, useIconNow, useLater } from "./_time-kit";

const BW = 184;
const BH = 122;
const FIRE = 0.15;
const FLASH_X = -58;
const FLASH_Y = -22;

/** The iris polygon's vertices and the seams between its blades (centre at the origin, rim radius 30). */
function iris(blades: number, opening: number, turn: number) {
  const count = Math.max(blades, 3);
  const outer = 30;
  const radius = outer * 0.9 * Math.max(opening, 0.001);
  const pts = Array.from({ length: count }, (_, i) => {
    const a = turn + (i / count) * 2 * Math.PI;
    return [radius * Math.cos(a), radius * Math.sin(a)];
  });
  const hole = `M${-outer} 0a${outer} ${outer} 0 1 0 ${outer * 2} 0a${outer} ${outer} 0 1 0 ${-outer * 2} 0ZM${pts.map((p) => `${p[0]} ${p[1]}`).join("L")}Z`;
  let seams = "";
  pts.forEach((from, i) => {
    const prev = pts[(i + count - 1) % count];
    let dx = from[0] - prev[0];
    let dy = from[1] - prev[1];
    const len = Math.max(Math.hypot(dx, dy), 0.001);
    dx /= len;
    dy /= len;
    seams += `M${from[0]} ${from[1]}L${from[0] + dx * outer * 2} ${from[1] + dy * outer * 2}`;
  });
  return { hole, seams };
}

export default function CameraSnap({ ctx }: DemoProps) {
  const { haptics, after, later } = useLater();
  const uid = useId().replace(/:/g, "");
  const start = useRef(DISTANT_PAST);
  const [shots, setShots] = useState(24);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const blades = ctx.i("blades");
  const flash = ctx.n("flash");
  const recoil = ctx.n("recoil");

  const snap = (scripted = false) => {
    if (since(nowSeconds(), start.current) <= 0.7) return;
    start.current = nowSeconds();
    haptics.tap("light");
    after(0.5, () => setShots((s) => s + 1));
    later(0.15, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => snap(true), { every: 2.2 });

  const closing = IC.easeIn(IC.seg(t, 0.05, 0.17));
  const opening = t < 0.24 ? 1 - closing : IC.spring(t - 0.24, 0.36, 0.6);
  const kick = recoil * IC.ring(t - FIRE, 9, 24) * IC.seg(t, FIRE, FIRE + 0.03);
  const press = 4 * IC.bump(IC.seg(t, 0, 0.22));
  const lit = flash * (1 - IC.easeOut(IC.seg(t, FIRE, FIRE + 0.4))) * (t >= FIRE ? 1 : 0);
  const { hole, seams } = iris(blades, 0.8 * opening, ((1 - IC.unit(opening)) * 50 * Math.PI) / 180);

  const s = t - FIRE;
  const star = IC.easeOut(IC.seg(s, 0, 0.3));
  const veil = flash * (1 - IC.easeOut(IC.seg(s, 0, 0.45)));

  const rise = IC.spring(t - 0.4, 0.4, 0.62);
  const leave = IC.easeIn(IC.seg(t, 1.0, 1.4));
  const printColors = [Palette.spectrum[((shots % 7) + 7) % 7], Palette.spectrum[((shots % 7) + 10) % 7]];

  return (
    <Stage gap={8}>
      <Z w={250} h={216} onClick={() => snap()}>
        <Item w={170} h={14} tf="translateY(92px)" style={{ borderRadius: "50%", background: "rgb(0 0 0 / 0.18)", filter: "blur(8px)" }} />
        <Z style={{ gridArea: "1 / 1", transform: `translateY(${20 + 5 * kick}px) rotate(${-6 * kick}deg) scale(${1 - 0.07 * kick})` }}>
          {/* The print that slides out of the top after the shot (behind the body). */}
          <Item
            w={44}
            h={50}
            tf={`translate(-58px, ${-BH / 2 + 26 - 44 * rise - 22 * leave}px) rotate(${8 * rise}deg)`}
            o={t >= 0.4 && t < 1.4 ? 1 - leave : 0}
            style={{ borderRadius: 6, background: "#fff", boxShadow: "0 2px 4px rgb(0 0 0 / 0.2)" }}
          >
            <div style={{ position: "absolute", left: 5, top: 5, width: 34, height: 30, borderRadius: 3, background: `linear-gradient(135deg, ${printColors[0]}, ${printColors[1]})` }} />
          </Item>
          <Z w={BW} h={BH} style={{ gridArea: "1 / 1" }}>
            <Item
              w={30}
              h={16}
              tf={`translate(52px, ${-BH / 2 - 3 + press}px)`}
              style={{ borderRadius: 8, background: `linear-gradient(${hex(0xff7a85)}, ${hex(0xe8334a)})` }}
            />
            <Item w={66} h={18} tf={`translate(-6px, ${-BH / 2 - 6}px)`} style={{ borderRadius: "10px 10px 0 0", background: hex(0xc9cad6) }} />
            <Item
              w={BW}
              h={BH}
              style={{ borderRadius: 28, overflow: "hidden", background: `linear-gradient(${hex(0x7c83ff)}, ${hex(0x5a54e0)})`, boxShadow: `0 8px 14px ${hex(0x4a44c8, 0.4)}` }}
            >
              <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 34, background: `linear-gradient(${hex(0xfafafd)}, ${hex(0xd9dae4)})` }} />
              <div style={{ position: "absolute", left: 0, right: 0, top: 34, height: 1.5, background: "rgb(0 0 0 / 0.14)" }} />
              <div style={{ position: "absolute", inset: 0, borderRadius: 28, boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.3)" }} />
            </Item>
            <Item
              w={30}
              h={16}
              tf={`translate(${FLASH_X}px, ${FLASH_Y - 20}px)`}
              style={{ borderRadius: 5, background: hex(0xfff3c4), boxShadow: `inset 0 0 0 1px rgb(0 0 0 / 0.18), 0 0 10px rgb(255 255 255 / ${lit})` }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: 5, background: `rgb(255 255 255 / ${lit})` }} />
            </Item>
            <Svg w={88} h={88} tf="translate(14px, 12px)" style={{ filter: "drop-shadow(0 4px 6px rgb(0 0 0 / 0.3))" }}>
              <defs>
                <linearGradient id={`${uid}-barrel`} x1="0" y1="-44" x2="0" y2="44" gradientUnits="userSpaceOnUse">
                  <stop offset="0" stopColor={hex(0x4a4b5c)} />
                  <stop offset="1" stopColor={hex(0x1d1d28)} />
                </linearGradient>
                <radialGradient id={`${uid}-glass`} cx={-6} cy={-9} r={34} gradientUnits="userSpaceOnUse">
                  <stop offset={2 / 34} stopColor={hex(0x7cc6ff)} />
                  <stop offset="0.53" stopColor={hex(0x3550e0)} />
                  <stop offset="1" stopColor={hex(0x141a5a)} />
                </radialGradient>
                <clipPath id={`${uid}-lens`}>
                  <circle r={30} />
                </clipPath>
              </defs>
              <circle r={44} fill={`url(#${uid}-barrel)`} />
              <circle r={43} fill="none" stroke="rgb(255 255 255 / 0.28)" strokeWidth={2} />
              <g clipPath={`url(#${uid}-lens)`}>
                <circle r={30} fill={`url(#${uid}-glass)`} />
                <circle cx={-9} cy={-10} r={5} fill="rgb(255 255 255 / 0.75)" />
                <circle cx={8} cy={9} r={2.5} fill="rgb(255 255 255 / 0.4)" />
                <path d={hole} fill={hex(0x2a2b38)} fillRule="evenodd" />
                <path d={seams} fill="none" stroke="rgb(255 255 255 / 0.16)" strokeWidth={1} />
              </g>
              <circle r={30} fill="none" stroke="rgb(0 0 0 / 0.5)" strokeWidth={2} />
            </Svg>
          </Z>
        </Z>
        <Z style={{ gridArea: "1 / 1", transform: `translate(${FLASH_X}px, ${FLASH_Y}px)`, opacity: s >= 0 && s < 0.5 ? 1 : 0, pointerEvents: "none" }}>
          <Item
            w={300}
            h={300}
            style={{ borderRadius: "50%", background: `radial-gradient(circle, rgb(255 255 255 / ${0.95 * veil}), rgb(255 255 255 / ${0.4 * veil}) 50%, rgb(255 255 255 / 0) 100%)` }}
          />
          <Svg
            w={60}
            h={60}
            tf={`rotate(${30 * star}deg) scale(${0.2 + 2.2 * star})`}
            o={flash > 0.02 ? 1 - star : 0}
            style={{ filter: `drop-shadow(0 0 8px ${hex(0xffc247, 0.8)})` }}
          >
            <path d={sparklePath(30)} fill="#fff" />
          </Svg>
        </Z>
      </Z>
      <div style={{ display: "flex", alignItems: "center", gap: 6, ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        <Images size={18} strokeWidth={2.2} />
        <NumericText value={shots} />
        <span>{ctx.t("photos", "张照片")}</span>
      </div>
      <DemoHint ctx={ctx} en="Tap to take a photo" zh="点击拍一张" />
    </Stage>
  );
}
