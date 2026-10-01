/** showcase.ride-eta · 叫车到达 (Showcase+RideETA.swift) */
import { AnimatePresence, motion } from "motion/react";
import { CarFront, Check, CircleCheck, PersonStanding, Phone, Star } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { NumericText, anim, black, delayed, fonts, hex, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportEyebrowRow, SportLiveDot, SportPress, sportHash } from "./_a-sport";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const MW = 258;
const MH = 178;
const COLUMNS = [34, 100, 168, 226];
const ROWS = [30, 80, 130, 172];
const START = { x: 34, y: 160 };
const PICKUP = { x: 222, y: 30 };
const ROUTE = "M34 160 L34 90 A10 10 0 0 1 44 80 L158 80 A10 10 0 0 0 168 70 L168 40 A10 10 0 0 1 178 30 L222 30";

let routeEl: SVGPathElement | null = null;
let routeLen = 0;
function routePoint(progress: number) {
  if (!routeEl) {
    routeEl = document.createElementNS("http://www.w3.org/2000/svg", "path");
    routeEl.setAttribute("d", ROUTE);
    routeLen = routeEl.getTotalLength();
  }
  const p = Math.min(Math.max(progress, 0), 1);
  if (p <= 0.0005) return START;
  const pt = routeEl.getPointAtLength(routeLen * p);
  return { x: pt.x, y: pt.y };
}
function heading(progress: number) {
  const a = routePoint(Math.max(progress - 0.012, 0));
  const b = routePoint(Math.min(progress + 0.012, 1));
  return Math.atan2(b.y - a.y, b.x - a.x);
}

export default function RideETA({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [progress, progressApi] = useAnimatedNumber(0);
  const [eta, setEta] = useState(5);
  const [arrived, setArrived] = useState(false);
  const [arrivals, setArrivals] = useState(0);
  const st = useRef({ arrived: false });
  const run = useStudioScript();
  const trip = ctx.n("trip");
  const cardSpring = spring(ctx.n("response"), ctx.n("damping"));
  const [len, setLen] = useState(0);
  useEffect(() => {
    routePoint(0.5);
    setLen(routeLen);
  }, []);

  const request = (user: boolean) => {
    run.cancel();
    if (user) haptics.tap("light");
    const rewind = st.current.arrived || progressApi.get() > 0;
    if (rewind) {
      st.current.arrived = false;
      setArrived(false);
      progressApi.animateTo(0, spring(0.5, 0.86));
      setEta(5);
    }
    run.run(async (task) => {
      if (rewind && !(await task.pause(0.6))) return;
      progressApi.animateTo(1, anim.curve(0.4, 0, 0.2, 1, trip));
      for (let step = 1; step <= 4; step++) {
        if (!(await task.pause((trip * 0.94) / 5))) return;
        setEta(5 - step);
      }
      if (!(await task.pause(trip * (0.94 / 5 + 0.06)))) return;
      setArrivals((n) => n + 1);
      st.current.arrived = true;
      setArrived(true);
      setEta(0);
      if (user) haptics.success();
    });
  };
  useAutoplay(ctx.isPreview, () => request(false), { every: trip + 3.4, delay: 0.7 });

  const p = Math.min(Math.max(progress, 0), 1);
  const car = len ? routePoint(p) : START;
  const head = len ? heading(p) : -Math.PI / 2;
  const ae = useElapsed(arrivals, 0.65, true);
  const carScale = ae < 0 ? 1 : ae < 0.12 ? 1 + 0.25 * studioEase(ae / 0.12) : 1.25 - 0.25 * springAt(ae - 0.12, 0.3, 0.5);
  const ripple = ae < 0 ? 0 : ae < 0.3 ? 0.7 * studioEase(ae / 0.3) : 0.7 + 0.3 * studioEase(Math.min((ae - 0.3) / 0.35, 1));
  const pinColor = arrived ? Signature.lime : Signature.accent;

  const blocks = useMemo(() => {
    const xs = [-20, ...COLUMNS, MW + 20];
    const ys = [-20, ...ROWS, MH + 20];
    const out = [];
    for (let c = 0; c < xs.length - 1; c++) {
      for (let r = 0; r < ys.length - 1; r++) {
        const x = xs[c] + 7;
        const y = ys[r] + 7;
        const w = xs[c + 1] - xs[c] - 14;
        const h = ys[r + 1] - ys[r] - 14;
        if (w <= 0 || h <= 0) continue;
        const park = c === 2 && r === 2;
        const pond = c === 3 && r === 3;
        out.push(<rect key={`${c}-${r}`} x={x} y={y} width={w} height={h} rx={6} fill={park ? "#1E3B2B" : pond ? "#1A3350" : "#262930"} />);
        if (park) {
          for (let tree = 0; tree < 7; tree++) out.push(<circle key={`t${tree}`} cx={x + w * (0.12 + sportHash(tree * 3.1) * 0.76)} cy={y + h * (0.18 + sportHash(tree * 7.7) * 0.64)} r={4} fill="#2F6B45" />);
        } else if (!pond) {
          out.push(<rect key={`${c}-${r}-roof`} x={x + w * 0.18} y={y + h * 0.22} width={w * 0.64} height={h * 0.56} rx={3} fill="none" stroke={white(0.04)} />);
        }
      }
    }
    return out;
  }, []);

  return (
    <StudioScene ctx={ctx} en="Tap to request the ride" zh="点击叫车">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => request(true)}>
        <div style={{ ...signatureCard(), width: 290, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff", textAlign: "left" }}>
          <div style={{ display: "flex" }}>
            <SportEyebrowRow title={zh ? "行程 · 快车" : "Ride · Standard"} icon={<CarFront size={14} strokeWidth={2.6} />} trailing={arrived ? (zh ? "司机已到达" : "Arrived") : zh ? "司机正在赶来" : "On the way"} />
          </div>
          <div style={{ position: "relative", width: MW, height: MH, borderRadius: 18, overflow: "hidden", background: "#16181D" }}>
            <svg width={MW} height={MH} style={{ position: "absolute", inset: 0 }}>
              <defs>
                <linearGradient id="ride-route" gradientUnits="userSpaceOnUse" x1={34} y1={30} x2={222} y2={160}>
                  <stop offset="0" stopColor="#FFB45C" />
                  <stop offset="0.5" stopColor="#FF8A1F" />
                  <stop offset="1" stopColor="#FF5A1F" />
                </linearGradient>
              </defs>
              {blocks}
              <path d={ROUTE} fill="none" stroke={white(0.1)} strokeWidth={5} strokeLinecap="round" strokeLinejoin="round" />
              {len > 0 && (
                <motion.path
                  d={ROUTE}
                  fill="none"
                  stroke="url(#ride-route)"
                  strokeWidth={4}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeDasharray={`${len * (1 - Math.min(p, 0.999))} ${len}`}
                  strokeDashoffset={-len * Math.min(p, 0.999)}
                  initial={false}
                  animate={{ opacity: arrived ? 0 : 1 }}
                  transition={arrived ? cardSpring : spring(0.5, 0.86)}
                  style={{ filter: `drop-shadow(0 0 6px ${hex(0xff8a1f, 0.6)})` }}
                />
              )}
            </svg>
            <div style={{ position: "absolute", left: PICKUP.x - 22, top: PICKUP.y - 22, width: 44, height: 44, display: "grid", placeItems: "center" }}>
              <AnimatePresence>
                {!arrived && (
                  <motion.span key="live" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={cardSpring} style={{ position: "absolute", display: "grid" }}>
                    <SportLiveDot color={Signature.accent} size={14} period={1.5} preview={ctx.isPreview} />
                  </motion.span>
                )}
              </AnimatePresence>
              <span style={{ position: "absolute", width: 22, height: 22, borderRadius: "50%", boxShadow: `0 0 0 1px ${Signature.lime}, inset 0 0 0 1px ${Signature.lime}`, transform: `scale(${1 + 1.8 * ripple})`, opacity: ripple > 0 && ripple < 1 ? 1 - ripple : 0 }} />
              <motion.span initial={false} animate={{ backgroundColor: pinColor, boxShadow: `inset 0 0 0 2px #fff, 0 0 6px ${arrived ? hex(0xc8f560, 0.7) : hex(0xff8a1f, 0.7)}` }} transition={cardSpring} style={{ position: "absolute", width: 22, height: 22, borderRadius: "50%", display: "grid", placeItems: "center", color: Signature.ink }}>
                {arrived ? <Check size={11} strokeWidth={4.5} /> : <PersonStanding size={12} strokeWidth={3} />}
              </motion.span>
            </div>
            <motion.div initial={false} animate={{ x: arrived ? -27 : 0 }} transition={arrived ? cardSpring : spring(0.5, 0.86)} style={{ position: "absolute", left: car.x - 15, top: car.y - 15, width: 30, height: 30 }}>
              <div style={{ position: "relative", width: 30, height: 30, transform: `scale(${carScale}) rotate(${head + Math.PI / 2}rad)` }}>
                <div style={{ position: "absolute", left: 3, top: 15 - 20 - 11, width: 24, height: 22, borderRadius: "50%", background: `radial-gradient(13px circle, ${hex(0xfff1c1, 0.75)}, transparent)` }} />
                <div style={{ position: "absolute", left: 8, top: 2.5, width: 14, height: 25, borderRadius: 5, background: "linear-gradient(90deg, #fff, #D9DCE3)", boxShadow: `0 2px 4px ${black(0.6)}` }} />
                <div style={{ position: "absolute", left: 10, top: 15 - 4.5 - 3, width: 10, height: 6, borderRadius: 2, background: "#23262C" }} />
                <div style={{ position: "absolute", left: 10, top: 15 + 6.5 - 2, width: 10, height: 4, borderRadius: 1.5, background: "#23262C" }} />
                <div style={{ position: "absolute", left: 9, top: 15 - 11.5 - 1, width: 3, height: 2, borderRadius: 1, background: "#FFE9A8" }} />
                <div style={{ position: "absolute", left: 18, top: 15 - 11.5 - 1, width: 3, height: 2, borderRadius: 1, background: "#FFE9A8" }} />
              </div>
            </motion.div>
            <div style={{ position: "absolute", left: 8, top: 8, padding: "6px 10px", borderRadius: 12, background: hex(0x0e0f12, 0.86), boxShadow: `inset 0 0 0 1px ${white(0.1)}`, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
              <span style={{ fontFamily: fonts.rounded, fontSize: 9, fontWeight: 700, letterSpacing: 0.8, textTransform: "uppercase", lineHeight: "11px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>{zh ? "预计到达" : "Arriving in"}</span>
              <span style={{ position: "relative", height: 28, minWidth: zh ? 64 : 58, display: "block" }}>
                <AnimatePresence initial={false}>
                  {arrived ? (
                    <motion.span key="here" initial={{ scale: 0.7, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.7, opacity: 0 }} transition={cardSpring} style={{ position: "absolute", left: 0, top: 0, height: 28, display: "flex", alignItems: "center", gap: 4, color: Signature.lime, transformOrigin: "0% 50%", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, whiteSpace: "nowrap" }}>
                      <CircleCheck size={15} strokeWidth={2.8} />
                      {zh ? "已到达" : "Here"}
                    </motion.span>
                  ) : (
                    <motion.span key="eta" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={cardSpring} style={{ position: "absolute", left: 0, top: 0, height: 28, display: "flex", alignItems: "baseline", gap: 3, whiteSpace: "nowrap" }}>
                      <span style={{ ...signatureNumber(24), lineHeight: "28px" }}>
                        <NumericText value={eta} />
                      </span>
                      <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, color: Signature.textSecondary }}>{zh ? "分钟" : "min"}</span>
                    </motion.span>
                  )}
                </AnimatePresence>
              </span>
            </div>
            <motion.div initial={false} animate={{ y: arrived ? 0 : 84 }} transition={arrived ? cardSpring : spring(0.5, 0.86)} style={{ position: "absolute", left: 8, right: 8, bottom: 8 }}>
              <div style={{ height: 60, padding: "0 10px", borderRadius: 15, background: "linear-gradient(#2C2D33, #1D1E22)", boxShadow: `inset 0 0 0 1px ${white(0.14)}, 0 -2px 12px ${black(0.5)}`, display: "flex", alignItems: "center", gap: 10 }}>
                <motion.span initial={false} animate={{ scale: arrived ? 1 : 0.4 }} transition={delayed(spring(0.4, 0.55), arrived ? 0.1 : 0)} style={{ width: 40, height: 40, borderRadius: "50%", background: "linear-gradient(135deg, #FFB45C, #E0559A)", boxShadow: `inset 0 0 0 1.5px ${white(0.5)}`, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 14, fontWeight: 800, flexShrink: 0 }}>
                  LM
                </motion.span>
                <span style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start", whiteSpace: "nowrap" }}>
                  <span style={{ display: "flex", alignItems: "center", gap: 5 }}>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 14, fontWeight: 700, lineHeight: "17px" }}>{zh ? "林师傅" : "Leo M."}</span>
                    <span style={{ display: "grid", color: Signature.accent }}>
                      <Star size={10} fill="currentColor" strokeWidth={0} />
                    </span>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 700, color: Signature.textSecondary }}>4.9</span>
                  </span>
                  <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 500, color: Signature.textSecondary }}>{zh ? "白色轿车" : "White sedan"}</span>
                    <span style={{ fontFamily: fonts.rounded, fontSize: 10, fontWeight: 800, fontVariantNumeric: "tabular-nums", lineHeight: "12px", padding: "1.5px 5px", borderRadius: 4, background: white(0.14) }}>7KL·284</span>
                  </span>
                </span>
                <span style={{ flex: 1 }} />
                <motion.span initial={false} animate={{ scale: arrived ? 1 : 0.4 }} transition={delayed(spring(0.4, 0.55), arrived ? 0.16 : 0)} style={{ width: 32, height: 32, borderRadius: "50%", background: Signature.lime, color: Signature.ink, display: "grid", placeItems: "center", flexShrink: 0 }}>
                  <Phone size={13} fill="currentColor" strokeWidth={1} />
                </motion.span>
              </div>
            </motion.div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 1px ${white(0.1)}`, pointerEvents: "none" }} />
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10, height: 30 }}>
            <span style={{ width: 26, height: 26, borderRadius: "50%", background: Signature.accentGradient, color: Signature.ink, display: "grid", placeItems: "center", flexShrink: 0 }}>
              <PersonStanding size={14} strokeWidth={2.8} />
            </span>
            <span style={{ display: "flex", flexDirection: "column", gap: 1, alignItems: "flex-start", minWidth: 0 }}>
              <span style={signatureEyebrow()}>{zh ? "上车点" : "Pickup"}</span>
              <span style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: 600, lineHeight: "16px", whiteSpace: "nowrap" }}>{zh ? "松林路 28 号 · 东门" : "28 Pine Street · East gate"}</span>
            </span>
            <span style={{ flex: 1 }} />
            <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: Signature.textSecondary, whiteSpace: "nowrap" }}>
              <NumericText value={eta} text={`${(eta * 0.4).toFixed(1)} km`} />
            </span>
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}
