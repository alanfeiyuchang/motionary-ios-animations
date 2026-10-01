/** showcase.parcel-tracker · 包裹物流追踪 (Showcase+ParcelTracker.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Building2, House, Package, Truck } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { NumericText, anim, black, delayed, fonts, hex, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress, sportHash } from "./_a-sport";
import { StudioScene, WalkGlyph, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const RW = 264;
const RH = 112;
const STOPS = [{ x: 18, y: 70 }, { x: 94, y: 30 }, { x: 172, y: 66 }, { x: 246, y: 28 }];

function roadPoint(travel: number) {
  const c = Math.min(Math.max(travel, 0), STOPS.length - 1);
  const segment = Math.min(Math.trunc(c), STOPS.length - 2);
  const u = c - segment;
  const a = STOPS[segment];
  const b = STOPS[segment + 1];
  const reach = (b.x - a.x) * 0.5;
  const v = 1 - u;
  return {
    x: v * v * v * a.x + 3 * v * v * u * (a.x + reach) + 3 * v * u * u * (b.x - reach) + u * u * u * b.x,
    y: v * v * v * a.y + 3 * v * v * u * a.y + 3 * v * u * u * b.y + u * u * u * b.y,
  };
}
function heading(travel: number) {
  const a = roadPoint(travel - 0.02);
  const b = roadPoint(travel + 0.02);
  return (Math.atan2(b.y - a.y, b.x - a.x) * 180) / Math.PI;
}
function roadPath(travel: number) {
  const steps = Math.max(Math.trunc(travel * 28), 1);
  let d = "";
  for (let i = 0; i <= steps; i++) {
    const p = roadPoint((travel * i) / steps);
    d += `${i === 0 ? "M" : "L"}${p.x.toFixed(2)} ${p.y.toFixed(2)}`;
  }
  return d;
}
const WHOLE = roadPath(STOPS.length - 1);

interface Stage {
  title: [string, string];
  detail: [string, string];
  label: [string, string];
  icon: (size: number) => ReactNode;
  eta: number;
}
const STAGES: Stage[] = [
  { title: ["Picked up", "已揽收"], detail: ["Shenzhen Bao'an hub", "深圳宝安集散中心"], label: ["Pickup", "揽收"], icon: (s) => <Package size={s} strokeWidth={2.6} />, eta: 28 },
  { title: ["In transit", "运输中"], detail: ["Arrived at Hangzhou sorting centre", "已到达杭州转运中心"], label: ["Transit", "转运"], icon: (s) => <Building2 size={s} strokeWidth={2.6} />, eta: 17 },
  { title: ["Out for delivery", "派送中"], detail: ["Your courier is 6 minutes away", "快递员距你还有 6 分钟"], label: ["Courier", "派送"], icon: (s) => <WalkGlyph size={s + 2} />, eta: 6 },
  { title: ["Delivered", "已送达"], detail: ["Left at the front desk", "已由前台代收"], label: ["Home", "到家"], icon: (s) => <House size={s} strokeWidth={2.6} />, eta: 0 },
];

export default function ParcelTracker({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [travel, travelApi] = useAnimatedNumber(0);
  const [lit, setLit] = useState(0);
  const [eta, setEta] = useState(STAGES[0].eta);
  const [arrivals, setArrivals] = useState(0);
  const [delivered, setDelivered] = useState(false);
  const st = useRef({ stage: 0, lit: 0, eta: STAGES[0].eta });
  const run = useStudioScript();
  const setLitBoth = (v: number) => {
    st.current.lit = v;
    setLit(v);
  };
  const setEtaBoth = (v: number) => {
    st.current.eta = v;
    setEta(v);
  };

  const advance = (user: boolean) => {
    run.cancel();
    const s = st.current;
    const count = STAGES.length;
    if (s.stage >= count - 1) {
      if (user) haptics.tap("light");
      s.stage = 0;
      travelApi.animateTo(0, spring(0.55, 0.85));
      setLitBoth(0);
      setDelivered(false);
      setEtaBoth(STAGES[0].eta);
      return;
    }
    if (user) haptics.tap("light");
    const from = s.stage;
    const target = s.stage + 1;
    const leg = ctx.n("leg");
    s.stage = target;
    if (s.lit !== from) setLitBoth(from);
    travelApi.animateTo(target, anim.curve(0.45, 0, 0.2, 1, leg));
    const startEta = s.eta;
    const endEta = STAGES[target].eta;
    run.run(async (task) => {
      const steps = Math.max(startEta - endEta, 1);
      for (let step = 1; step <= steps; step++) {
        if (!(await task.pause((leg * 0.92) / steps))) return;
        setEtaBoth(startEta - step);
      }
      if (!(await task.pause(leg * 0.08))) return;
      setArrivals((n) => n + 1);
      setLitBoth(target);
      setEtaBoth(endEta);
      setDelivered(target === count - 1);
      if (user) {
        if (target === count - 1) haptics.success();
        else haptics.tap("medium");
      }
    });
  };
  useAutoplay(ctx.isPreview, () => advance(false), { every: Math.max(ctx.n("leg") + 0.9, 1.9), delay: 0.7 });

  const van = roadPoint(travel);
  const bump = useElapsed(arrivals, 0.6, true);
  const vanScale = bump < 0 ? 1 : bump < 0.12 ? 1 + 0.18 * studioEase(bump / 0.12) : 1.18 - 0.18 * springAt(bump - 0.12, 0.3, 0.5);
  const info = STAGES[lit];
  const arrive = spring(0.4, 0.75);

  return (
    <StudioScene ctx={ctx} en="Tap to send the van to the next stop" zh="点击，让货车驶向下一站">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => advance(true)}>
        <div style={{ ...signatureCard(), width: 300, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 12, color: "#fff", textAlign: "left" }}>
          <div style={{ display: "flex" }}>
            <SportEyebrowRow title={zh ? "包裹 · SF 2841 0937" : "Parcel · SF 2841 0937"} icon={<Package size={13} strokeWidth={2.6} />} />
          </div>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
            <div style={{ position: "relative", flex: 1, minWidth: 0, minHeight: 46, overflow: "hidden" }}>
              <AnimatePresence initial={false}>
                <motion.div
                  key={lit}
                  initial={{ y: 46, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  exit={{ y: -46, opacity: 0 }}
                  transition={arrive}
                  style={{ position: "absolute", left: 0, top: 0, right: 0, display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}
                >
                  <motion.span initial={false} animate={{ color: delivered ? Signature.lime : "#FFFFFF" }} transition={arrive} style={{ fontFamily: fonts.rounded, fontSize: 22, fontWeight: 700, lineHeight: "26px", whiteSpace: "nowrap" }}>
                    {info.title[zh ? 1 : 0]}
                  </motion.span>
                  <span style={{ fontFamily: fonts.rounded, fontSize: info.detail[zh ? 1 : 0].length > 30 ? 10.5 : 12, fontWeight: 500, lineHeight: "15px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>{info.detail[zh ? 1 : 0]}</span>
                </motion.div>
              </AnimatePresence>
            </div>
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end" }}>
              <span style={signatureEyebrow()}>{zh ? "预计" : "ETA"}</span>
              <span style={{ display: "flex", alignItems: "baseline", gap: 3 }}>
                <motion.span initial={false} animate={{ color: delivered ? Signature.lime : "#FFFFFF" }} transition={arrive} style={{ ...signatureNumber(30), lineHeight: "36px" }}>
                  <NumericText value={eta} />
                </motion.span>
                <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, color: Signature.textSecondary, whiteSpace: "nowrap" }}>{zh ? "分钟" : "min"}</span>
              </span>
            </div>
          </div>
          <div style={{ position: "relative", width: RW, height: RH }}>
            <svg width={RW} height={RH} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
              <defs>
                <linearGradient id="parcel-road" gradientUnits="userSpaceOnUse" x1={12} y1={22} x2={van.x + 6} y2={76}>
                  <stop offset="0" stopColor="#FFB45C" />
                  <stop offset="0.5" stopColor="#FF8A1F" />
                  <stop offset="1" stopColor="#FF5A1F" />
                </linearGradient>
              </defs>
              <path d={WHOLE} fill="none" stroke={white(0.09)} strokeWidth={11} strokeLinecap="round" strokeLinejoin="round" />
              <path d={WHOLE} fill="none" stroke={white(0.28)} strokeWidth={1.2} strokeLinecap="round" strokeDasharray="4 7" />
              <path d={roadPath(Math.max(travel, 0.001))} fill="none" stroke="url(#parcel-road)" strokeWidth={11} strokeLinecap="round" strokeLinejoin="round" style={{ filter: `drop-shadow(0 0 8px ${hex(0xff8a1f, 0.55)})` }} />
              <path d={roadPath(Math.max(travel, 0.001))} fill="none" stroke={hex(0x0b0b0d, 0.35)} strokeWidth={1.2} strokeLinecap="round" strokeDasharray="4 7" />
            </svg>
            <div style={{ position: "absolute", left: van.x - 15, top: van.y - 15, width: 30, height: 30 }}>
              <motion.div initial={false} animate={{ scale: delivered ? 0.3 : 1, opacity: delivered ? 0 : 1 }} transition={delivered ? arrive : spring(0.55, 0.85)} style={{ width: 30, height: 30 }}>
                <div
                  style={{
                    width: 30,
                    height: 30,
                    borderRadius: "50%",
                    background: "linear-gradient(#fff, #FFD9B0)",
                    boxShadow: `inset 0 0 0 2px ${Signature.accent}, 0 3px 5px ${black(0.5)}`,
                    display: "grid",
                    placeItems: "center",
                    color: Signature.ink,
                    transform: `scale(${vanScale}) rotate(${heading(travel)}deg)`,
                  }}
                >
                  <Truck size={15} strokeWidth={2.6} />
                </div>
              </motion.div>
            </div>
            {STAGES.map((stage, index) => {
              const last = index === STAGES.length - 1;
              return (
                <div key={index} style={{ position: "absolute", left: STOPS[index].x, top: STOPS[index].y, width: 0, height: 0 }}>
                  <Stop info={stage} reached={index <= lit} current={index === lit} done={last && delivered} ripple={ctx.n("ripple")} confetti={last ? ctx.i("confetti") : 0} zh={zh} />
                </div>
              );
            })}
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}

const FLECK_COLORS = [Signature.lime, Signature.accent, "#FFFFFF", Signature.accentSoft];

function Stop({ info, reached, current, done, ripple, confetti, zh }: { info: Stage; reached: boolean; current: boolean; done: boolean; ripple: number; confetti: number; zh: boolean }) {
  const [ripples, setRipples] = useState(0);
  const [bursts, setBursts] = useState(0);
  const prev = useRef({ current, done });
  useEffect(() => {
    if (current && !prev.current.current) setRipples((n) => n + 1);
    if (done && !prev.current.done) setBursts((n) => n + 1);
    prev.current = { current, done };
  }, [current, done]);
  const re = useElapsed(ripples, 0.7, true);
  const rp = re < 0 ? 0 : re < 0.3 ? 0.7 * studioEase(re / 0.3) : 0.7 + 0.3 * studioEase((re - 0.3) / 0.4);
  const be = useElapsed(bursts, 0.8, true);
  const bp = be < 0 ? 0 : be < 0.3 ? 0.82 * studioEase(be / 0.3) : 0.82 + 0.18 * studioEase((be - 0.3) / 0.5);
  const tint = done ? Signature.lime : Signature.accent;
  const pop = done ? spring(0.45, 0.6) : spring(0.4, 0.6);
  const size = done ? 30 : 24;
  return (
    <motion.div initial={false} animate={{ scale: current && !done ? 1.08 : 1 }} transition={pop} style={{ position: "absolute", left: 0, top: 0, width: 0, height: 0, pointerEvents: "none" }}>
      {confetti > 0 && bp > 0 && bp < 1 &&
        Array.from({ length: confetti }, (_, index) => {
          const angle = (index / Math.max(confetti, 1)) * 2 * Math.PI + sportHash(index) * 0.5;
          const reach = 26 + sportHash(index * 3.7) * 24;
          const h = index % 2 === 0 ? 8 : 4;
          return (
            <span
              key={index}
              style={{
                position: "absolute",
                left: -2,
                top: -h / 2,
                width: 4,
                height: h,
                borderRadius: 1.5,
                background: FLECK_COLORS[index % FLECK_COLORS.length],
                opacity: Math.min(1, (1 - bp) * 3),
                transform: `translate(${Math.cos(angle) * reach * bp}px, ${Math.sin(angle) * reach * bp + 10 * bp * bp}px) rotate(${sportHash(index * 9.1) * 540 * bp}deg)`,
              }}
            />
          );
        })}
      <span style={{ position: "absolute", left: -12, top: -12, width: 24, height: 24, borderRadius: "50%", boxShadow: `0 0 0 1px ${tint}, inset 0 0 0 1px ${tint}`, transform: `scale(${1 + (ripple - 1) * rp})`, opacity: rp > 0 && rp < 1 ? 1 - rp : 0 }} />
      <motion.span
        initial={false}
        animate={{
          width: size,
          height: size,
          x: -size / 2,
          y: -size / 2,
          backgroundColor: done ? Signature.lime : reached ? Signature.cardHigh : Signature.card,
          boxShadow: `inset 0 0 0 1.5px ${reached ? tint : white(0.18)}, 0 0 7px ${done ? hex(0xc8f560, reached ? 0.5 : 0) : hex(0xff8a1f, reached ? 0.5 : 0)}`,
        }}
        transition={pop}
        style={{ position: "absolute", left: 0, top: 0, borderRadius: "50%" }}
      />
      <motion.span initial={false} animate={{ color: reached ? white(1) : white(0.4), opacity: done ? 0 : 1 }} transition={pop} style={{ position: "absolute", left: -6, top: -6, width: 12, height: 12, display: "grid", placeItems: "center" }}>
        {info.icon(11)}
      </motion.span>
      <svg width={13} height={10} style={{ position: "absolute", left: -6.5, top: -5, overflow: "visible" }}>
        <motion.path
          d="M0 5 L4.68 10 L13 0"
          fill="none"
          stroke={Signature.ink}
          strokeWidth={3}
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={false}
          animate={{ pathLength: done ? 1 : 0, opacity: done ? 1 : 0 }}
          transition={{ pathLength: delayed(anim.easeOut(0.35), done ? 0.12 : 0), opacity: { duration: 0.01, delay: done ? 0.12 : 0.3 } }}
        />
      </svg>
      <motion.span
        initial={false}
        animate={{ color: reached ? white(0.9) : white(0.55) }}
        transition={pop}
        style={{ position: "absolute", left: 0, top: 27, transform: "translate(-50%, -50%)", fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700, lineHeight: "12px", whiteSpace: "nowrap" }}
      >
        {info.label[zh ? 1 : 0]}
      </motion.span>
    </motion.div>
  );
}
