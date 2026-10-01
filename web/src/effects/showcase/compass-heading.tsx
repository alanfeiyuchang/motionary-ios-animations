/** showcase.compass-heading · 指南针航向盘 (Showcase+CompassHeading.swift) */
import { useEffect, useMemo, useRef } from "react";
import { clamp, fonts, hex, localPoint, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { StudioScene, useAnimatedNumber } from "./_studio";

const DIAL = 178;
const TARGETS = [12, 138, 301, 64, 355, 190, 247];

export default function CompassHeading({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [heading, headingApi] = useAnimatedNumber(247);
  const st = useRef({ step: 0, dragging: false, moved: 0, lastAngle: 0, lastMove: 0, omega: 0, userDriven: false, start: { x: 0, y: 0 } });
  const swingSpring = spring(ctx.n("response"), ctx.n("damping"));
  const upright = ctx.b("upright");
  const glow = ctx.n("glow");

  const swing = () => {
    const s = st.current;
    const target = TARGETS[s.step % TARGETS.length];
    s.step += 1;
    const current = headingApi.get() % 360;
    let delta = (target - current) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    headingApi.animateTo(headingApi.get() + delta, swingSpring);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      st.current.userDriven = false;
      swing();
    },
    { every: 2.4, delay: 0.6 },
  );

  const sector30 = Math.floor(heading / 30);
  const prevSector = useRef(sector30);
  useEffect(() => {
    if (prevSector.current !== sector30) {
      prevSector.current = sector30;
      if (st.current.userDriven) haptics.tap("light");
    }
  }, [sector30, haptics]);

  const release = () => {
    const s = st.current;
    if (!s.dragging) return;
    s.dragging = false;
    if (s.moved <= 6) return;
    const coast = performance.now() - s.lastMove > 90 ? 0 : clamp(s.omega, -900, 900) * 0.3;
    headingApi.animateTo(Math.round(headingApi.get() - coast), swingSpring);
  };
  const gesture = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      const p = localPoint(e, e.currentTarget);
      const s = st.current;
      s.dragging = true;
      s.userDriven = true;
      s.moved = 0;
      s.omega = 0;
      s.start = p;
      s.lastAngle = (Math.atan2(p.y - DIAL / 2, p.x - DIAL / 2) * 180) / Math.PI;
      s.lastMove = performance.now();
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      const s = st.current;
      if (!s.dragging) return;
      const p = localPoint(e, e.currentTarget);
      const angle = (Math.atan2(p.y - DIAL / 2, p.x - DIAL / 2) * 180) / Math.PI;
      let delta = angle - s.lastAngle;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      s.lastAngle = angle;
      s.moved = Math.max(s.moved, Math.abs(p.x - s.start.x) + Math.abs(p.y - s.start.y));
      if (s.moved <= 6) return;
      const now = performance.now();
      const dt = Math.max((now - s.lastMove) / 1000, 1 / 240);
      s.lastMove = now;
      s.omega = s.omega * 0.6 + (delta / dt) * 0.4;
      headingApi.set(headingApi.get() - delta);
    },
    onPointerUp: () => {
      const s = st.current;
      if (!s.dragging) return;
      if (s.moved <= 6) {
        s.dragging = false;
        haptics.tap("light");
        swing();
      } else release();
    },
    onPointerCancel: release,
  };

  const normalized = ((heading % 360) + 360) % 360;
  const northness = Math.max(0, 1 - Math.min(normalized, 360 - normalized) / 24);
  const degrees = Math.round(normalized) % 360;
  const en = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
  const cn = ["北", "东北", "东", "东南", "南", "西南", "西", "西北"];
  const si = Math.trunc((degrees + 22.5) / 45) % 8;
  const sector = zh ? cn[si] + " " + en[si] : en[si];
  const north = northness * glow;

  const ticks = useMemo(() => {
    const c = DIAL / 2;
    const outer = DIAL / 2 - 5;
    const out = [];
    for (let index = 1; index < 180; index++) {
      const deg = index * 2;
      const major = deg % 30 === 0;
      const mid = deg % 10 === 0;
      const length = major ? 10 : mid ? 7 : 4;
      const a = (deg * Math.PI) / 180 - Math.PI / 2;
      out.push(<line key={index} x1={c + Math.cos(a) * (outer - length)} y1={c + Math.sin(a) * (outer - length)} x2={c + Math.cos(a) * outer} y2={c + Math.sin(a) * outer} stroke="#fff" strokeOpacity={major ? 0.9 : mid ? 0.5 : 0.24} strokeWidth={major ? 2 : 1} strokeLinecap="round" />);
    }
    return out;
  }, []);
  const label = (text: string, size: number, weight: number, color: string, angle: number, radius: number) => (
    <span key={`${text}-${angle}`} style={{ position: "absolute", left: DIAL / 2, top: DIAL / 2, width: 0, height: 0, transform: `rotate(${angle}deg) translateY(${-radius}px) rotate(${upright ? heading - angle : 0}deg)` }}>
      <span style={{ position: "absolute", left: 0, top: 0, transform: "translate(-50%, -50%)", fontFamily: fonts.rounded, fontSize: size, fontWeight: weight, fontVariantNumeric: "tabular-nums", color, whiteSpace: "nowrap", lineHeight: 1.2 }}>{text}</span>
    </span>
  );
  const letters = zh ? ["北", "东", "南", "西"] : ["N", "E", "S", "W"];

  return (
    <StudioScene ctx={ctx} en="Tap for a new heading · drag to turn" zh="点击换一个航向 · 拖动转盘">
      <div style={{ ...signatureCard(), width: 280, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", alignItems: "center", gap: 6, color: "#fff" }}>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8, alignSelf: "stretch" }}>
          <span style={{ ...signatureNumber(38), lineHeight: "45px", whiteSpace: "nowrap" }}>{degrees}°</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, color: Signature.accent, whiteSpace: "nowrap" }}>{sector}</span>
          <span style={{ flex: 1 }} />
          <span style={{ ...signatureEyebrow(), display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-end", whiteSpace: "nowrap" }}>
            <span>31.23°N</span>
            <span>121.47°E</span>
          </span>
        </div>
        <div {...gesture} style={{ position: "relative", width: DIAL, height: DIAL, marginTop: 8, borderRadius: "50%", touchAction: "none", cursor: "grab" }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `radial-gradient(circle, #26262B 30px, #0C0C0F ${DIAL / 2}px)` }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", padding: 1.5, background: `linear-gradient(${white(0.22)}, ${white(0.03)})`, WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)", WebkitMaskComposite: "xor", maskComposite: "exclude" }} />
          <div style={{ position: "absolute", inset: 0, transform: `rotate(${-heading}deg)` }}>
            <svg width={DIAL} height={DIAL} style={{ position: "absolute", inset: 0 }}>{ticks}</svg>
            {Array.from({ length: 12 }, (_, index) => (index % 3 !== 0 ? label(String(index * 30), 10, 600, white(0.6), index * 30, DIAL / 2 - 26) : null))}
            {letters.map((l, index) => label(l, 16, 800, index === 0 ? Signature.accent : "#fff", index * 90, DIAL / 2 - 30))}
            <svg width={9} height={10} style={{ position: "absolute", left: DIAL / 2 - 4.5, top: 9 - 5, overflow: "visible", filter: `drop-shadow(0 0 ${3 + 9 * north}px ${hex(0xff8a1f, Math.min(north, 1))}) drop-shadow(0 0 ${14 * north}px ${hex(0xffb45c, Math.min(north * 0.8, 1))})` }}>
              <path d="M0 10 L9 10 L4.5 0 Z" fill={Signature.accentHot} />
            </svg>
          </div>
          <div style={{ position: "absolute", left: DIAL / 2 - 17, top: DIAL / 2 - 0.5, width: 34, height: 1, background: white(0.2), pointerEvents: "none" }} />
          <div style={{ position: "absolute", left: DIAL / 2 - 0.5, top: DIAL / 2 - 17, width: 1, height: 34, background: white(0.2), pointerEvents: "none" }} />
          <div style={{ position: "absolute", left: DIAL / 2 - 6, top: DIAL / 2 - 6, width: 12, height: 12, borderRadius: "50%", background: Signature.cardHigh, boxShadow: `inset 0 0 0 1px ${white(0.35)}`, pointerEvents: "none" }} />
          <div style={{ position: "absolute", inset: 3, borderRadius: "50%", background: `linear-gradient(135deg, ${white(0.1)}, transparent 50%)`, pointerEvents: "none" }} />
          <svg width={16} height={13} style={{ position: "absolute", left: DIAL / 2 - 8, top: -1 - 6.5, overflow: "visible", filter: `drop-shadow(0 0 ${4 + 8 * north}px ${hex(0xff8a1f, 0.4 + 0.6 * Math.min(north, 1))})` }}>
            <defs>
              <linearGradient id="compass-lubber" x1="0" y1="0" x2="1" y2="1">
                <stop offset="0" stopColor="#FFB45C" />
                <stop offset="0.5" stopColor="#FF8A1F" />
                <stop offset="1" stopColor="#FF5A1F" />
              </linearGradient>
            </defs>
            <path d="M0 0 L16 0 L8 13 Z" fill="url(#compass-lubber)" />
          </svg>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
