/** showcase.battery-widget · 多设备电量 (Showcase+BatteryWidget.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { BatteryMedium, Smartphone, Watch, Zap } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { NumericText, anim, delayed, fonts, forever, hex, spring, springAt, springDB, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioScene, studioEase } from "./_studio";

const Earbuds = (
  <svg width={26} height={24} viewBox="0 0 26 24" fill="currentColor">
    <path d="M8.2 2.5a5 5 0 0 0-5 5c0 2.2 1.3 4 3.2 4.7V20a1.9 1.9 0 0 0 3.8 0V7.5a2 2 0 0 0-2-5Z" />
    <path d="M17.8 2.5a5 5 0 0 1 5 5c0 2.2-1.3 4-3.2 4.7V20a1.9 1.9 0 0 1-3.8 0V7.5a2 2 0 0 1 2-5Z" />
  </svg>
);
const CaseIcon = (
  <svg width={28} height={22} viewBox="0 0 28 22" fill="currentColor" fillRule="evenodd">
    <path d="M6 1h16a5 5 0 0 1 5 5v10a5 5 0 0 1-5 5H6a5 5 0 0 1-5-5V6a5 5 0 0 1 5-5Zm-5 8.2v1.4h10.3a1.2 1.2 0 0 0 1.2 1h3a1.2 1.2 0 0 0 1.2-1H27V9.2Z" />
  </svg>
);
const DEVICES: { icon: ReactNode; name: [string, string]; level: number }[] = [
  { icon: <Smartphone size={24} strokeWidth={2} />, name: ["Phone", "手机"], level: 78 },
  { icon: <Watch size={24} strokeWidth={2} />, name: ["Watch", "手表"], level: 54 },
  { icon: Earbuds, name: ["Earbuds", "耳机"], level: 14 },
  { icon: CaseIcon, name: ["Case", "充电盒"], level: 91 },
];

export default function BatteryWidget({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [levels, setLevels] = useState(DEVICES.map((d) => d.level));
  const [filled, setFilled] = useState(false);
  const [charging, setCharging] = useState<number[]>([]);
  const [wobbles, setWobbles] = useState(0);
  const [reason, setReason] = useState<"fill" | "charge" | "drain">("fill");
  const st = useRef({ step: 0, charging: [] as number[], refill: 0 });

  useEffect(() => {
    setFilled(true);
    const id = window.setInterval(() => setWobbles((n) => n + 1), 2600);
    return () => {
      window.clearInterval(id);
      window.clearTimeout(st.current.refill);
    };
  }, []);
  const key = charging.join(",");
  useEffect(() => {
    if (!charging.length) return;
    const id = window.setInterval(() => {
      setReason("charge");
      setLevels((l) => l.map((v, i) => (st.current.charging.includes(i) ? Math.min(100, v + 1) : v)));
    }, 300);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  const toggle = (index: number) => {
    const s = st.current;
    s.charging = s.charging.includes(index) ? s.charging.filter((i) => i !== index) : [...s.charging, index];
    setCharging(s.charging);
  };
  const autoStep = () => {
    const s = st.current;
    const k = s.step % 3;
    if (k === 0) toggle(2);
    else if (k === 1) toggle(0);
    else {
      window.clearTimeout(s.refill);
      s.charging = [];
      setCharging([]);
      setReason("drain");
      setFilled(false);
      s.refill = window.setTimeout(() => {
        setLevels(DEVICES.map((d) => d.level));
        setReason("fill");
        setFilled(true);
      }, 400);
    }
    s.step += 1;
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 2.3, delay: 1.6, intro: false });

  return (
    <StudioScene ctx={ctx} en="Tap a device to plug it in" zh="点击设备，给它接上电源">
      <div style={{ ...signatureCard(), width: 256, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 12, color: "#fff" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "电池" : "Batteries"} icon={<BatteryMedium size={16} strokeWidth={2.6} />} trailing={charging.length === 0 ? (zh ? "4 台设备" : "4 devices") : zh ? `${charging.length} 台充电中` : `${charging.length} charging`} />
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", rowGap: 12 }}>
          {DEVICES.map((device, index) => {
            const isCharging = charging.includes(index);
            const delay = index * ctx.n("stagger");
            const ring: Transition = reason === "fill" ? delayed(spring(0.8, 0.8), filled ? delay : 0) : reason === "drain" ? anim.easeIn(0.3) : springDB(0.25, 0.15);
            return (
              <div key={index} style={{ display: "grid", placeItems: "center" }}>
                <SportPress
                  scale={0.94}
                  dim={0.04}
                  onClick={() => {
                    haptics.tap(isCharging ? "light" : "medium");
                    toggle(index);
                  }}
                >
                  <Cell icon={device.icon} name={device.name[zh ? 1 : 0]} level={levels[index]} filled={filled} charging={isCharging} low={levels[index] <= ctx.n("low") && !isCharging} ring={ring} wobble={ctx.n("wobble")} wobbles={wobbles} />
                </SportPress>
              </div>
            );
          })}
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}

function wobbleAt(e: number): number {
  if (e < 0) return 0;
  const frames: [number, number][] = [[1, 0.09], [-0.85, 0.14], [0.6, 0.13], [-0.4, 0.12], [0.2, 0.11]];
  let t = e;
  let v = 0;
  for (const [to, d] of frames) {
    if (t < d) return v + (to - v) * studioEase(t / d);
    t -= d;
    v = to;
  }
  return 0.2 * (1 - springAt(t, 0.25, 0.6));
}

function Cell({ icon, name, level, filled, charging, low, ring, wobble, wobbles }: { icon: ReactNode; name: string; level: number; filled: boolean; charging: boolean; low: boolean; ring: Transition; wobble: number; wobbles: number }) {
  const shown = filled ? level : 0;
  const color = charging ? Signature.lime : low ? "#FF4D3D" : Signature.accent;
  const glow = charging ? hex(0xc8f560, 0.55) : low ? hex(0xff4d3d, 0.55) : hex(0xff8a1f, 0.55);
  const C = 2 * Math.PI * 36;
  const pop = spring(0.35, 0.5);
  const we = useElapsed(wobbles, 0.9, true);
  const angle = low ? wobbleAt(we) * wobble : 0;
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 5, padding: "0 3.5px" }}>
      <div style={{ position: "relative", width: 72, height: 72, margin: "3.5px 0" }}>
        <AnimatePresence>
          {charging && (
            <motion.div key="glow" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={pop} style={{ position: "absolute", left: 6, top: 6, width: 60, height: 60 }}>
              <motion.div animate={{ opacity: [0.12, 0.34] }} transition={forever(anim.easeInOut(1))} style={{ width: 60, height: 60, borderRadius: "50%", background: Signature.lime, filter: "blur(18px)" }} />
            </motion.div>
          )}
        </AnimatePresence>
        <svg width={72} height={72} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
          <circle cx={36} cy={36} r={36} fill="none" stroke={white(0.08)} strokeWidth={7} />
          <motion.circle
            cx={36}
            cy={36}
            r={36}
            fill="none"
            strokeWidth={7}
            strokeLinecap="round"
            strokeDasharray={C}
            transform="rotate(-90 36 36)"
            initial={false}
            animate={{ strokeDashoffset: C * (1 - Math.max(shown / 100, 0.0001)), stroke: color, filter: `drop-shadow(0 0 5px ${glow})` }}
            transition={{ strokeDashoffset: ring, default: pop }}
          />
        </svg>
        <motion.div initial={false} animate={{ color: low ? "#FF8A7E" : "#FFFFFF" }} transition={springDB(0.3, 0)} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", transform: `rotate(${angle}deg)` }}>
          {icon}
        </motion.div>
        <AnimatePresence>
          {charging && (
            <motion.div key="bolt" initial={{ scale: 0.3, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.3, opacity: 0 }} transition={pop} style={{ position: "absolute", left: 36 - 8.5, top: -8.5, width: 17, height: 17 }}>
              <motion.div animate={{ scale: [1, 1.18] }} transition={forever(anim.easeInOut(0.5))} style={{ width: 17, height: 17, borderRadius: "50%", background: Signature.lime, boxShadow: `inset 0 0 0 2px ${Signature.card}`, display: "grid", placeItems: "center", color: Signature.ink }}>
                <Zap size={9} fill="currentColor" strokeWidth={0} />
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      <div style={{ display: "flex", alignItems: "baseline", gap: 4, whiteSpace: "nowrap" }}>
        <motion.span initial={false} animate={{ color: charging ? Signature.lime : low ? "#FF6B5E" : "#FFFFFF" }} transition={pop} style={{ fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "18px" }}>
          <NumericText value={Math.round(shown)} text={`${Math.round(shown)}%`} />
        </motion.span>
        <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, color: Signature.textSecondary }}>{name}</span>
      </div>
    </div>
  );
}
