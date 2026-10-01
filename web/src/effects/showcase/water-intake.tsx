/** showcase.water-intake · 饮水杯 (Showcase+WaterIntake.swift) */
import { motion } from "motion/react";
import { Check, Droplet, Flag, Plus } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, fonts, hex, spring, springDB, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureNumber } from "./signature";
import { CanvasLayer, SportEyebrowRow, SportPress, sportHash } from "./_a-sport";
import { StudioScene, studioMix, useAnimatedNumber } from "./_studio";

const GW = 112;
const GH = 172;
const GOAL = 2000;
const CAPACITY = 2400;

function tumbler(g: CanvasRenderingContext2D, inset: number) {
  const x0 = inset;
  const y0 = inset;
  const x1 = GW - inset;
  const y1 = GH - inset;
  const taper = GW * 0.13;
  const corner = Math.max(16 - inset, 6);
  g.beginPath();
  g.moveTo(x0, y0);
  g.lineTo(x1, y0);
  g.arcTo(x1 - taper, y1, x0 + taper, y1, corner);
  g.arcTo(x0 + taper, y1, x0, y0, corner);
  g.closePath();
}
function water(g: CanvasRenderingContext2D, level: number, phase: number, amplitude: number, cycles: number) {
  const surface = GH - GH * level;
  g.beginPath();
  g.moveTo(0, GH);
  for (let i = 0; i <= 28; i++) {
    const u = i / 28;
    g.lineTo(GW * u, surface + amplitude * Math.sin(u * 2 * Math.PI * cycles + phase));
  }
  g.lineTo(GW, GH);
  g.closePath();
}

export default function WaterIntake({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [ml, mlApi] = useAnimatedNumber(500);
  const [target, setTarget] = useState(500);
  const [mix, mixApi] = useAnimatedNumber(0);
  const [drops, setDrops] = useState(0);
  const st = useRef({ ml: 500, splash: -1e9, splashLevel: 0, pending: 0, landing: GH });
  const cup = Math.max(ctx.n("cup"), 50);
  const amplitude = ctx.n("wave");
  const reached = ml >= GOAL;
  const live = useRef({ ml, mix, amplitude });
  live.current = { ml, mix, amplitude };
  useEffect(() => () => window.clearTimeout(st.current.pending), []);
  const wasReached = useRef(false);
  useEffect(() => {
    if (reached !== wasReached.current) {
      wasReached.current = reached;
      mixApi.animateTo(reached ? 1 : 0, springDB(0.5, 0));
    }
  }, [reached, mixApi]);

  const addCup = (user: boolean) => {
    const s = st.current;
    window.clearTimeout(s.pending);
    if (s.ml + cup > CAPACITY + 1) {
      if (user) haptics.tap("light");
      s.ml = 0;
      setTarget(0);
      mlApi.animateTo(0, spring(0.8, 0.9));
      return;
    }
    if (user) haptics.tap("light");
    s.landing = GH * (1 - Math.min(mlApi.get() / CAPACITY, 1)) + 4;
    setDrops((n) => n + 1);
    const was = s.ml >= GOAL;
    s.pending = window.setTimeout(() => {
      s.splashLevel = Math.min(mlApi.get() / CAPACITY, 1);
      s.splash = performance.now();
      s.ml += cup;
      setTarget(s.ml);
      mlApi.animateTo(s.ml, spring(ctx.n("response"), 0.6));
      if (user) {
        if (!was && s.ml >= GOAL) haptics.success();
        else haptics.tap("soft");
      }
    }, 300);
  };
  useAutoplay(ctx.isPreview, () => addCup(false), { every: 1.35, delay: 0.7 });

  const de = useElapsed(drops, 0.32, true);
  const landing = st.current.landing;
  const dropY = de < 0 ? 0 : de < 0.16 ? -10 + (landing + 10) * 0.26 * (de / 0.16) ** 2 : -10 + (landing + 10) * 0.26 + (landing - (-10 + (landing + 10) * 0.26)) * Math.min((de - 0.16) / 0.14, 1);
  const stretch = de < 0 ? 0 : 0.5 * Math.min(de / 0.3, 1);
  const dropOpacity = de < 0 || de >= 0.31 ? 0 : de < 0.28 ? 1 : 1 - (de - 0.28) / 0.03;

  const cups = Math.min(Math.ceil(GOAL / cup), 14);
  const done = Math.trunc(target / cup + 0.001);
  const targetReached = target >= GOAL;
  const goalY = GH * (1 - GOAL / CAPACITY);
  const fmt = (n: number) => Math.trunc(n).toLocaleString("en-US");

  const glass = (
    <div style={{ position: "relative", width: GW, height: GH }}>
      <CanvasLayer
        width={GW}
        height={GH}
        fps={ctx.isPreview ? 30 : undefined}
        draw={(g, t) => {
          const { ml: liveMl, mix: k, amplitude: amp } = live.current;
          const level = Math.min(Math.max(liveMl, 0) / CAPACITY, 1);
          const since = (performance.now() - st.current.splash) / 1000;
          const kick = since >= 0 ? 7 * Math.exp(-2.6 * since) : 0;
          tumbler(g, 0);
          g.fillStyle = white(0.05);
          g.fill();
          g.save();
          tumbler(g, 5);
          g.clip();
          water(g, level, -t * 1.7 + 1.3, amp * 0.7 + kick * 0.6, 1.7);
          g.fillStyle = studioMix(0x8fd8ff, 0x9be86a, k, 0.45 + 0.05 * k);
          g.fill();
          water(g, level, t * 2.3, amp + kick, 1.2);
          const top = GH - GH * level - (amp + kick);
          const grad = g.createLinearGradient(0, top, 0, GH);
          grad.addColorStop(0, studioMix(0x6fd3ff, 0xc8f560, k));
          grad.addColorStop(1, studioMix(0x2a6ff0, 0x2fb98c, k));
          g.fillStyle = grad;
          g.fill();
          const depth = GH * level;
          if (depth > 14) {
            for (let index = 0; index < 7; index++) {
              const rise = (t * (0.16 + sportHash(index * 2.3) * 0.2) + sportHash(index * 7.1)) % 1;
              const x = GW * (0.22 + sportHash(index * 4.9) * 0.56) + Math.sin(t * 2 + index) * 2;
              const y = GH - depth * rise;
              const radius = 1.2 + sportHash(index * 1.3) * 1.8;
              g.globalAlpha = 0.4 * (1 - rise * 0.6);
              g.strokeStyle = "#fff";
              g.lineWidth = 0.9;
              g.beginPath();
              g.arc(x, y, radius, 0, Math.PI * 2);
              g.stroke();
            }
          }
          if (since >= 0 && since < 0.7) {
            const ox = GW / 2;
            const oy = GH * (1 - st.current.splashLevel);
            for (let index = 0; index < 6; index++) {
              const side = index % 2 === 0 ? 1 : -1;
              const vx = side * (16 + sportHash(index * 3.3) * 46);
              const vy = 95 + sportHash(index * 5.7) * 70;
              const radius = 2.6 - since * 2;
              if (radius <= 0.4) continue;
              g.globalAlpha = Math.min(1, (0.7 - since) * 4);
              g.fillStyle = "#CDEFFF";
              g.beginPath();
              g.arc(ox + vx * since, oy - (vy * since - 0.5 * 420 * since * since), radius, 0, Math.PI * 2);
              g.fill();
            }
          }
          g.restore();
          g.globalAlpha = 1;
          tumbler(g, 0);
          const rim = g.createLinearGradient(0, 0, 0, GH);
          rim.addColorStop(0, white(0.55));
          rim.addColorStop(1, white(0.14));
          g.strokeStyle = rim;
          g.lineWidth = 1.6;
          g.stroke();
        }}
        style={{ overflow: "visible" }}
      />
      <div style={{ position: "absolute", left: 12, right: 12, top: goalY - 5, height: 10, display: "flex", alignItems: "center", gap: 4, color: reached ? hex(0x0b0b0d, 0.7) : white(0.75) }}>
        <span style={{ flex: 1, height: 0, borderTop: `1.2px dashed ${reached ? hex(0x0b0b0d, 0.55) : white(0.6)}` }} />
        {reached ? <Check size={9} strokeWidth={4.5} /> : <Flag size={9} fill="currentColor" strokeWidth={2.5} />}
      </div>
      <div style={{ position: "absolute", left: GW / 2 - GW * 0.33 - 2.5, top: GH / 2 - 8 - (GH * 0.62) / 2, width: 5, height: GH * 0.62, borderRadius: 2.5, background: `linear-gradient(${white(0.34)}, ${white(0.02)})`, transform: "rotate(-4.6deg)" }} />
      <div style={{ position: "absolute", left: GW / 2 - 8, top: -9, width: 16, height: 18, display: "grid", placeItems: "center", color: "#7CC6FF", opacity: dropOpacity, transformOrigin: "50% 100%", transform: `translateY(${dropY}px) scale(${1 - stretch * 0.25}, ${1 + stretch})`, pointerEvents: "none" }}>
        <Droplet size={22} fill="currentColor" strokeWidth={0} style={{ margin: -3 }} />
      </div>
    </div>
  );

  return (
    <StudioScene ctx={ctx} en="Tap the glass to add a cup" zh="点击水杯，添一杯水">
      <div style={{ ...signatureCard(), width: 292, padding: 18, boxSizing: "border-box", display: "flex", alignItems: "center", gap: 18, color: "#fff" }}>
        <SportPress scale={0.97} dim={0.02} onClick={() => addCup(true)} style={{ flexShrink: 0 }}>
          {glass}
        </SportPress>
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 8, alignItems: "stretch" }}>
          <div style={{ display: "flex" }}>
            <SportEyebrowRow title={zh ? "今日饮水" : "Water today"} icon={<Droplet size={15} fill="currentColor" strokeWidth={0} />} />
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: 3 }}>
            <motion.span initial={false} animate={{ color: targetReached ? Signature.lime : "#FFFFFF" }} transition={springDB(0.5, 0)} style={{ ...signatureNumber(36), lineHeight: "43px" }}>
              <NumericText value={target} text={fmt(target)} />
            </motion.span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 700, color: Signature.textSecondary }}>ml</span>
          </div>
          <motion.span initial={false} animate={{ color: targetReached ? Signature.lime : "rgba(255,255,255,0.55)" }} transition={springDB(0.5, 0)} style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 600, lineHeight: "14px", whiteSpace: "nowrap" }}>
            {targetReached ? (zh ? "目标达成" : "Goal reached") : zh ? "目标 2,000 ml" : "Goal 2,000 ml"}
          </motion.span>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(8, 12px)", columnGap: 3, rowGap: 5, height: 30, alignContent: "start" }}>
            {Array.from({ length: cups }, (_, index) => (
              <motion.span key={index} initial={false} animate={{ scale: index < done ? 1 : 0.8, color: index < done ? (targetReached ? Signature.lime : "#5FC4FF") : "rgba(255,255,255,0.14)" }} transition={spring(0.3, 0.45)} style={{ display: "grid", placeItems: "center", width: 12, height: 13 }}>
                <Droplet size={17} style={{ flexShrink: 0, margin: -3 }} fill="currentColor" strokeWidth={0} />
              </motion.span>
            ))}
          </div>
          <SportPress scale={0.95} dim={0.05} radius={18} onClick={() => addCup(true)}>
            <span style={{ height: 36, borderRadius: 18, background: "linear-gradient(#8FDCFF, #4FA8FF)", boxShadow: `0 4px 8px ${hex(0x4fa8ff, 0.4)}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 5, fontFamily: fonts.rounded, fontSize: 13, fontWeight: 700, color: Signature.ink, whiteSpace: "nowrap" }}>
              <Plus size={13} strokeWidth={3.4} />
              {Math.trunc(cup)} ml
            </span>
          </SportPress>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
