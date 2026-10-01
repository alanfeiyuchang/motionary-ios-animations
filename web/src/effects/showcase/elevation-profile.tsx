/** showcase.elevation-profile · 骑行海拔剖面 (Showcase+ElevationProfile.swift) */
import { motion } from "motion/react";
import { Bike, Flag } from "lucide-react";
import { useEffect, useRef } from "react";
import { anim, black, clamp, delayed, fonts, localPoint, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportEyebrowRow } from "./_a-sport";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const DISTANCE = 42;
const FLOOR = 600;
const CEILING = 2100;
const PW = 264;
const PH = 120;

function altitude(t: number): number {
  const x = clamp(t);
  const warp = x < 0.68 ? (x / 0.68) * 0.5 : 0.5 + ((x - 0.68) / 0.32) * 0.5;
  const hill = Math.pow(Math.sin(Math.PI * warp), 1.3);
  return 720 + 1240 * hill + 70 * Math.sin(x * 17) + 25 * Math.sin(x * 41 + 1);
}
function gradeAt(t: number): number {
  const e = 0.004;
  return ((altitude(t + e) - altitude(t - e)) / (2 * e * DISTANCE * 1000)) * 100;
}
const SUMMIT = (() => {
  let best = 0;
  let top = -Infinity;
  for (let i = 0; i <= 400; i++) {
    const t = i / 400;
    if (altitude(t) > top) {
      top = altitude(t);
      best = t;
    }
  }
  return best;
})();
const KEYS: [number, number][] = [[-2, 0x5ac8fa], [1.5, 0xc8f560], [4.5, 0xffd24a], [7.5, 0xff8a1f], [10.5, 0xff4d5e]];
function gradeRGB(grade: number): [number, number, number] {
  const rgb = (v: number): [number, number, number] => [(v >> 16) & 255, (v >> 8) & 255, v & 255];
  if (grade <= KEYS[0][0]) return rgb(KEYS[0][1]);
  for (let i = 1; i < KEYS.length; i++) {
    if (grade <= KEYS[i][0]) {
      const a = rgb(KEYS[i - 1][1]);
      const b = rgb(KEYS[i][1]);
      const k = (grade - KEYS[i - 1][0]) / (KEYS[i][0] - KEYS[i - 1][0]);
      return [0, 1, 2].map((c) => Math.round(a[c] + (b[c] - a[c]) * k)) as [number, number, number];
    }
  }
  return rgb(KEYS[KEYS.length - 1][1]);
}
const css = (c: [number, number, number], a = 1) => `rgb(${c[0]} ${c[1]} ${c[2]} / ${a})`;

export default function ElevationProfile({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [reveal, revealApi] = useAnimatedNumber(0);
  const [progress, progressApi] = useAnimatedNumber(0);
  const [touch, touchApi] = useAnimatedNumber(0);
  const st = useRef({ touching: false, scripting: false, lastMarker: 0, atSummit: false });
  const script = useStudioScript();
  const slices = Math.max(ctx.i("slices"), 4);
  const relief = ctx.n("relief");
  const ahead = ctx.n("ahead");

  useEffect(() => {
    revealApi.animateTo(1, anim.easeOut(0.9));
    progressApi.animateTo(0.38, delayed(spring(0.9, 0.85), 0.25));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const buzz = (f: () => void) => {
    if (!st.current.scripting) f();
  };
  const ride = (fraction: number) => {
    const s = st.current;
    const next = clamp(fraction);
    if (!s.touching) {
      s.touching = true;
      touchApi.animateTo(1, spring(0.3, 0.7));
      buzz(() => haptics.tap("light"));
    }
    const marker = Math.trunc((next * DISTANCE) / 5);
    if (marker !== s.lastMarker) {
      s.lastMarker = marker;
      buzz(() => haptics.selection());
    }
    const summit = Math.abs(next - SUMMIT) < 0.02;
    if (summit !== s.atSummit) {
      s.atSummit = summit;
      if (summit) buzz(() => haptics.tap("medium"));
    }
    progressApi.set(next);
  };
  const lift = () => {
    if (!st.current.touching) return;
    st.current.touching = false;
    touchApi.animateTo(0, spring(0.35, 0.7));
  };
  const runScript = () => {
    script.run(async (s) => {
      st.current.scripting = true;
      const legs: [number, number][] = [[0.94, 2.6], [0.38, 1.3]];
      let from = progressApi.get();
      for (const [target, duration] of legs) {
        const origin = from;
        if (!(await s.script(duration, (t) => ride(origin + (target - origin) * studioEase(t))))) {
          if (s.alive()) lift();
          return;
        }
        from = target;
      }
      lift();
      st.current.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 6.4, delay: 1.6 });

  const down = useRef(false);
  const drag = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      script.cancel();
      st.current.scripting = false;
      ride(localPoint(e, e.currentTarget).x / PW);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current) ride(localPoint(e, e.currentTarget).x / PW);
    },
    onPointerUp: () => {
      down.current = false;
      lift();
    },
    onPointerCancel: () => {
      down.current = false;
      lift();
    },
  };

  const y = (t: number) => PH - 4 - ((altitude(t) - FLOOR) / (CEILING - FLOOR)) * relief * (PH - 30);
  const grade = gradeAt(progress);
  const tint = gradeRGB(grade);
  const riderX = PW * progress;
  const riderY = y(progress);
  const tilt = (Math.atan2(y(progress + 0.01) - y(progress - 0.01), PW * 0.02) * 180) / Math.PI;
  const nearSummit = Math.abs(progress - SUMMIT) < 0.02;

  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    const CW = PW + 8;
    const CH = PH + 8;
    if (el.width !== CW * dpr) {
      el.width = CW * dpr;
      el.height = CH * dpr;
    }
    const g = el.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 4 * dpr, 4 * dpr);
    g.clearRect(-4, -4, CW, CH);
    const revealX = PW * reveal;
    const paint = () => {
      for (let slice = 0; slice < slices; slice++) {
        const t0 = slice / slices;
        const t1 = (slice + 1) / slices;
        g.beginPath();
        g.moveTo(PW * t0, PH);
        let top = PH;
        for (let sub = 0; sub <= 4; sub++) {
          const t = t0 + ((t1 - t0) * sub) / 4;
          const py = y(t);
          top = Math.min(top, py);
          g.lineTo(PW * t, py);
        }
        g.lineTo(PW * t1, PH);
        g.closePath();
        const c = gradeRGB(gradeAt((t0 + t1) / 2));
        const grad = g.createLinearGradient(0, top, 0, PH);
        grad.addColorStop(0, css(c, 0.95));
        grad.addColorStop(1, css(c, 0.12));
        g.fillStyle = grad;
        g.fill();
      }
      g.beginPath();
      for (let i = 0; i <= 132; i++) {
        const t = i / 132;
        if (i === 0) g.moveTo(PW * t, y(t));
        else g.lineTo(PW * t, y(t));
      }
      g.strokeStyle = white(0.95);
      g.lineWidth = 2;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke();
    };
    const layer = (w: number, alpha: number) => {
      g.save();
      g.beginPath();
      g.rect(0, -4, w, PH + 8);
      g.clip();
      g.globalAlpha = alpha;
      paint();
      g.restore();
    };
    layer(revealX, ahead);
    layer(Math.min(revealX, riderX), 1);
  });

  const stat = (label: string, value: string, unit: string) => (
    <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
      <span style={signatureEyebrow()}>{label}</span>
      <span style={{ display: "flex", alignItems: "baseline", gap: 3 }}>
        <span style={{ ...signatureNumber(24), lineHeight: "29px", color: "#fff" }}>{value}</span>
        <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, color: Signature.textSecondary }}>{unit}</span>
      </span>
    </div>
  );
  const gradeText = ((grade >= 0 ? "+" : "") + grade.toFixed(1) + "%").replace("-", "−");

  return (
    <StudioScene ctx={ctx} en="Drag across the profile" zh="在剖面上左右拖动">
      <div style={{ ...signatureCard(), width: PW + 36, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 14, color: "#fff" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "骑行 · 加利比耶山口" : "Ride · Col du Galibier"} icon={<Bike size={15} strokeWidth={2.6} />} trailing="42 km" />
        </div>
        <div style={{ display: "flex", alignItems: "flex-end" }}>
          {stat(zh ? "距离" : "Distance", (progress * DISTANCE).toFixed(1), "km")}
          <span style={{ flex: 1 }} />
          {stat(zh ? "海拔" : "Altitude", String(Math.round(altitude(progress))), "m")}
          <span style={{ flex: 1 }} />
          <div style={{ display: "flex", flexDirection: "column", gap: 4, alignItems: "flex-end" }}>
            <span style={signatureEyebrow()}>{zh ? "坡度" : "Grade"}</span>
            <span style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 9px", borderRadius: 14, background: css(tint), boxShadow: `0 2px 8px ${css(tint, 0.45)}` }}>
              <span style={{ width: 14, height: 2.5, borderRadius: 1.25, background: Signature.ink, transform: `rotate(${-clamp(grade * 3, -40, 40)}deg)` }} />
              <span style={{ fontFamily: fonts.rounded, fontSize: 14, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "17px", color: Signature.ink, whiteSpace: "nowrap" }}>{gradeText}</span>
            </span>
          </div>
        </div>
        <div {...drag} style={{ position: "relative", width: PW, height: PH, touchAction: "none", opacity: reveal > 0.001 ? 1 : 0 }}>
          <canvas ref={canvas} style={{ position: "absolute", left: -4, top: -4, width: PW + 8, height: PH + 8 }} />
          <motion.span
            initial={false}
            animate={{ scale: nearSummit ? 1.35 : 1, color: nearSummit ? Signature.accent : white(0.6) }}
            transition={spring(0.3, 0.5)}
            style={{ position: "absolute", left: PW * SUMMIT + 4 - 6, top: y(SUMMIT) - 11 - 6, display: "grid", transformOrigin: "50% 100%", opacity: reveal > SUMMIT ? 1 : 0 }}
          >
            <Flag size={12} fill="currentColor" strokeWidth={2.4} />
          </motion.span>
          <div style={{ position: "absolute", left: riderX - 0.5, top: riderY, width: 1, height: Math.max(PH - riderY, 0), background: `linear-gradient(${white(0.8)}, ${white(0.05)})` }} />
          <div style={{ position: "absolute", left: riderX, top: riderY, width: 0, height: 0, transform: `scale(${1 + 0.25 * touch})` }}>
            <div style={{ position: "absolute", left: -7.5, top: -7.5, width: 15, height: 15, borderRadius: "50%", boxShadow: `inset 0 0 0 2.5px ${css(tint)}, 0 0 12px ${css(tint, 0.9)}` }} />
            <div style={{ position: "absolute", left: -4.5, top: -4.5, width: 9, height: 9, borderRadius: "50%", background: "#fff" }} />
          </div>
          <div style={{ position: "absolute", left: riderX, top: riderY, width: 0, height: 0, transform: `scale(${1 + 0.15 * touch}) rotate(${tilt}deg)` }}>
            <span style={{ position: "absolute", left: -10, top: -17 - 10, display: "grid", color: "#fff", filter: `drop-shadow(0 1px 3px ${black(0.5)})` }}>
              <Bike size={20} strokeWidth={2.4} />
            </span>
          </div>
        </div>
        <div style={{ display: "flex", width: PW, overflow: "hidden", marginTop: -8, fontFamily: fonts.rounded, fontSize: 10, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "12px", color: Signature.textSecondary }}>
          {[0, 10, 20, 30, 40].map((km) => (
            <span key={km} style={{ width: (PW * 10) / 42, flexShrink: 0 }}>{km}</span>
          ))}
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
