/** showcase.moon-phase · 月相拨盘 (Showcase+MoonPhase.swift) */
import { AnimatePresence, motion } from "motion/react";
import { MoonStar } from "lucide-react";
import { useEffect, useId, useRef, useState } from "react";
import { anim, fonts, hex, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { CanvasLayer, SportEyebrowRow, sportHash } from "./_a-sport";
import { StudioScene, sparklePath, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const NAMES: [string, string][] = [
  ["New Moon", "新月"], ["Waxing Crescent", "蛾眉月"], ["First Quarter", "上弦月"], ["Waxing Gibbous", "盈凸月"],
  ["Full Moon", "满月"], ["Waning Gibbous", "亏凸月"], ["Last Quarter", "下弦月"], ["Waning Crescent", "残月"],
];
const wrapped = (phase: number) => ((phase % 1) + 1) % 1;
const MOON = 124;

let textureCache: string | null = null;
function moonTexture(): string {
  if (textureCache) return textureCache;
  const scale = 3;
  const w = MOON;
  const el = document.createElement("canvas");
  el.width = w * scale;
  el.height = w * scale;
  const g = el.getContext("2d")!;
  g.scale(scale, scale);
  const base = g.createRadialGradient(w * 0.42, w * 0.38, 0, w * 0.42, w * 0.38, w * 0.68);
  base.addColorStop(0, "#F4F1EA");
  base.addColorStop(0.5, "#D9D5CC");
  base.addColorStop(1, "#AFAAA0");
  g.fillStyle = base;
  g.beginPath();
  g.arc(w / 2, w / 2, w / 2, 0, Math.PI * 2);
  g.fill();
  const maria = [[0.34, 0.3, 0.3, 0.22], [0.58, 0.44, 0.26, 0.3], [0.4, 0.62, 0.34, 0.2], [0.7, 0.72, 0.16, 0.14], [0.22, 0.52, 0.14, 0.18]];
  for (const [cx, cy, sw, sh] of maria) {
    g.save();
    g.translate(w * cx, w * cy);
    g.scale((w * sw) / 2 + 5, (w * sh) / 2 + 5);
    const soft = g.createRadialGradient(0, 0, 0, 0, 0, 1);
    soft.addColorStop(0, hex(0x7f7b76, 0.5));
    soft.addColorStop(0.45, hex(0x7f7b76, 0.42));
    soft.addColorStop(1, hex(0x7f7b76, 0));
    g.fillStyle = soft;
    g.beginPath();
    g.arc(0, 0, 1, 0, Math.PI * 2);
    g.fill();
    g.restore();
  }
  for (let index = 0; index < 16; index++) {
    const angle = sportHash(index * 2.7) * 2 * Math.PI;
    const distance = Math.sqrt(sportHash(index * 5.1)) * 0.44;
    const cx = w * (0.5 + Math.cos(angle) * distance);
    const cy = w * (0.5 + Math.sin(angle) * distance);
    const radius = w * (0.018 + sportHash(index * 8.3) * 0.04);
    g.fillStyle = hex(0x8c8880, 0.5);
    g.beginPath();
    g.arc(cx, cy, radius, 0, Math.PI * 2);
    g.fill();
    g.strokeStyle = white(0.5);
    g.lineWidth = 0.8;
    g.beginPath();
    g.arc(cx + 0.6, cy + 0.7, radius, 0, Math.PI * 2);
    g.stroke();
  }
  textureCache = el.toDataURL("image/png");
  return textureCache;
}

function litPath(phase: number): string {
  const r = MOON / 2 + 2;
  const c = MOON / 2;
  const side = phase < 0.5 ? 1 : -1;
  const squash = Math.cos(2 * Math.PI * phase);
  const steps = 40;
  let d = "";
  for (let i = 0; i <= steps; i++) {
    const y = -r + (2 * r * i) / steps;
    const half = Math.sqrt(Math.max(r * r - y * y, 0));
    d += `${i === 0 ? "M" : "L"}${(c + side * half).toFixed(2)} ${(c + y).toFixed(2)}`;
  }
  for (let i = 0; i <= steps; i++) {
    const y = r - (2 * r * i) / steps;
    const half = Math.sqrt(Math.max(r * r - y * y, 0));
    d += `L${(c + side * squash * half).toFixed(2)} ${(c + y).toFixed(2)}`;
  }
  return d + "Z";
}

export default function MoonPhase({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [phase, phaseApi] = useAnimatedNumber(0.25);
  const st = useRef({ dragStart: null as number | null, scripting: false });
  const script = useStudioScript();
  const travel = ctx.n("travel");
  const [texture, setTexture] = useState<string | null>(null);
  useEffect(() => setTexture(moonTexture()), []);
  const uid = useId().replace(/:/g, "");

  const scrub = (value: number, user: boolean) => {
    const before = Math.floor(phaseApi.get() * 29.53);
    phaseApi.set(value);
    if (user && Math.floor(value * 29.53) !== before) haptics.selection();
  };
  const release = (target: number) => {
    st.current.dragStart = null;
    const rest = ctx.b("snap") ? Math.round(target * 8) / 8 : target;
    phaseApi.animateTo(rest, spring(0.55, 0.72));
  };
  const runScript = () => {
    if (st.current.dragStart !== null) return;
    script.run(async (task) => {
      st.current.scripting = true;
      const from = phaseApi.get();
      const finished = await task.script(1.5, (t) => scrub(from + 0.31 * studioEase(t), false));
      if (!task.alive()) return;
      st.current.scripting = false;
      if (!finished) return;
      release(phaseApi.get() + 0.05);
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 3.4, delay: 0.7 });

  const pan = usePan(
    {
      onStart: () => {
        script.cancel();
        st.current.scripting = false;
        st.current.dragStart = phaseApi.get();
      },
      onChange: (p) => scrub((st.current.dragStart ?? phaseApi.get()) + p.translation.x / travel, true),
      onEnd: (p) => {
        const start = st.current.dragStart;
        if (start === null) return;
        release(start + (p.translation.x + p.velocity.x * 0.25) / travel);
      },
    },
    4,
  );

  const p = wrapped(phase);
  const lit = (1 - Math.cos(2 * Math.PI * p)) / 2;
  const index = Math.floor(p * 8 + 0.5) % 8;
  const stars = ctx.i("stars");

  const ruler = useRef<HTMLCanvasElement>(null);
  const RW = 256;
  useEffect(() => {
    const el = ruler.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    if (el.width !== RW * dpr) {
      el.width = RW * dpr;
      el.height = 30 * dpr;
    }
    const g = el.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, RW, 30);
    const position = phase * 30;
    const first = Math.floor(position) - 18;
    g.lineCap = "round";
    g.font = `700 9px ${fonts.rounded}`;
    g.textAlign = "center";
    g.textBaseline = "middle";
    for (let tick = first; tick <= first + 36; tick++) {
      const x = RW / 2 + (tick - position) * 9;
      if (!(x > -4 && x < RW + 4)) continue;
      const day = ((tick % 30) + 30) % 30;
      const major = day % 5 === 0;
      const fade = 1 - Math.min(Math.abs(x - RW / 2) / (RW / 2), 1);
      g.globalAlpha = 0.2 + 0.8 * fade;
      g.strokeStyle = white(major ? 0.8 : 0.35);
      g.lineWidth = major ? 1.6 : 1;
      g.beginPath();
      g.moveTo(x, 2);
      g.lineTo(x, major ? 14 : 9);
      g.stroke();
      if (major) {
        g.fillStyle = white(0.6);
        g.fillText(String(day), x, 23.5);
      }
    }
    g.globalAlpha = 1;
    g.strokeStyle = Signature.accent;
    g.lineWidth = 2.4;
    g.beginPath();
    g.moveTo(RW / 2, 1.2);
    g.lineTo(RW / 2, 17);
    g.stroke();
  });

  return (
    <StudioScene ctx={ctx} en="Drag left or right to change the phase" zh="左右拖动，改变月相">
      <div {...pan} style={{ ...signatureCard(), width: 288, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff", touchAction: "none" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "月相" : "Moon phase"} icon={<MoonStar size={13} fill="currentColor" strokeWidth={2} />} trailing={zh ? "十月" : "October"} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{ position: "relative", width: 148, height: 148, borderRadius: 18, overflow: "hidden", background: "linear-gradient(#0A0E22, #161B3A)", flexShrink: 0 }}>
            <CanvasLayer
              width={148}
              height={148}
              fps={20}
              style={{ opacity: 1 - 0.6 * lit }}
              draw={(g, t) => {
                for (let i = 0; i < stars; i++) {
                  const x = 148 * sportHash(i * 3.9);
                  const y = 148 * sportHash(i * 6.7);
                  const twinkle = 0.5 + 0.5 * Math.sin(t * (0.8 + sportHash(i * 1.9) * 2.2) + i * 1.7);
                  const radius = 0.5 + sportHash(i * 9.1) * 1.1;
                  g.globalAlpha = 0.25 + 0.75 * twinkle;
                  g.fillStyle = "#fff";
                  if (i % 7 === 0) sparklePath(g, x, y, radius * 3.2);
                  else {
                    g.beginPath();
                    g.arc(x, y, radius, 0, Math.PI * 2);
                  }
                  g.fill();
                }
              }}
            />
            <div style={{ position: "absolute", left: 15, top: 15, width: 118, height: 118, borderRadius: "50%", background: "#DCE6FF", filter: "blur(22px)", opacity: ctx.n("glow") * (0.06 + 0.5 * lit) }} />
            <div style={{ position: "absolute", left: 12, top: 12, width: MOON, height: MOON, borderRadius: "50%", overflow: "hidden" }}>
              {texture && (
                <svg width={MOON} height={MOON} style={{ position: "absolute", inset: 0 }}>
                  <defs>
                    <filter id={`${uid}-b`} x="-10%" y="-10%" width="120%" height="120%">
                      <feGaussianBlur stdDeviation={1.5} />
                    </filter>
                    <mask id={`${uid}-m`} maskUnits="userSpaceOnUse" x={-4} y={-4} width={MOON + 8} height={MOON + 8}>
                      <path d={litPath(p)} fill="#fff" filter={`url(#${uid}-b)`} />
                    </mask>
                  </defs>
                  <image href={texture} width={MOON} height={MOON} />
                  <rect width={MOON} height={MOON} fill={hex(0x070a16, 0.87)} />
                  <image href={texture} width={MOON} height={MOON} mask={`url(#${uid}-m)`} />
                </svg>
              )}
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1px ${white(0.08)}` }} />
            </div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start", minWidth: 0 }}>
            <span style={{ position: "relative", height: 38, width: 94 }}>
              <AnimatePresence initial={false}>
                <motion.span key={index} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={anim.easeOut(0.2)} style={{ position: "absolute", left: 0, bottom: 0, right: 0, fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, lineHeight: "18px" }}>
                  {NAMES[index][zh ? 1 : 0]}
                </motion.span>
              </AnimatePresence>
            </span>
            <span style={{ display: "flex", alignItems: "baseline", gap: 1, whiteSpace: "nowrap" }}>
              <span style={{ ...signatureNumber(38), lineHeight: "45px" }}>{Math.round(lit * 100)}</span>
              <span style={{ ...signatureNumber(17), color: Signature.accentSoft }}>%</span>
            </span>
            <span style={signatureEyebrow()}>{zh ? "照明度" : "Sunlit"}</span>
            <span style={{ paddingTop: 4, fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "13px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>
              {zh ? `月龄 ${(p * 29.53).toFixed(1)} 天` : `Day ${(p * 29.53).toFixed(1)}`}
            </span>
          </div>
        </div>
        <canvas ref={ruler} style={{ width: RW, height: 30, display: "block" }} />
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
