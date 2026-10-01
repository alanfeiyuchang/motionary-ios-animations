/** buttons.gravity-dots · 引力点阵 (Buttons+GravityDots.swift) */
import { motion } from "motion/react";
import { Radio } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useSince } from "./_a-kit";
import { mixRGB, nowSeconds, rgba, useFrame } from "./_c-kit";

const BUTTON = { w: 176, h: 58 };
const PATH = [
  { x: 96, y: -92 },
  { x: -104, y: -70 },
  { x: 0, y: 0 },
  { x: -84, y: 96 },
  { x: 110, y: 84 },
  { x: 0, y: 0 },
];
const HOT = rgba(mixRGB(0x6e7bff, 0xa46bff, 0.35));

export default function GravityDots({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const intro = useTimeouts();
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useRef({ well: { x: 0, y: 0 }, vx: 0, vy: 0, target: null as { x: number; y: number } | null, strength: 0, waves: [] as number[], seeded: false });
  const [pressed, setPressed] = useState(false);
  const pressedRef = useRef(false);
  const [presses, setPresses] = useState(0);
  const step = useRef(0);
  const params = useRef({ pull: 22, radius: 100, spacing: 22, wave: 12, dark: true });
  params.current = { pull: ctx.n("pull"), radius: ctx.n("radius"), spacing: Math.max(ctx.n("spacing"), 4), wave: ctx.n("wave"), dark: ctx.scheme === "dark" };

  const stage = () => ({ w: root.current?.offsetWidth ?? 340, h: root.current?.offsetHeight ?? 400 });
  const isOnButton = (p: { x: number; y: number }) => {
    const s = stage();
    return Math.abs(p.x - s.w / 2) < BUTTON.w / 2 && Math.abs(p.y - s.h / 2) < BUTTON.h / 2;
  };
  const setPress = (p: boolean) => {
    if (pressedRef.current === p) return;
    pressedRef.current = p;
    setPressed(p);
  };
  const pulse = () => {
    model.current.waves.push(nowSeconds());
    setPresses((n) => n + 1);
  };
  const release = () => {
    model.current.target = null;
    setPress(false);
  };
  const stepPreview = () => {
    const s = stage();
    const offset = PATH[step.current % PATH.length];
    step.current += 1;
    model.current.target = { x: s.w / 2 + offset.x, y: s.h / 2 + offset.y };
    if (offset.x === 0 && offset.y === 0) pulse();
  };
  const playIntro = () => {
    intro.clearAll();
    stepPreview();
    intro.after(0.8, stepPreview);
    intro.after(1.6, stepPreview);
    intro.after(2.4, release);
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? stepPreview() : playIntro()), { every: 0.9, delay: 0.3 });

  const pan = usePan({
    onChange: (s) => {
      intro.clearAll();
      model.current.target = s.location;
      setPress(isOnButton(s.location));
    },
    onEnd: (s) => {
      if (isOnButton(s.location)) {
        haptics.tap("medium");
        pulse();
      }
      release();
    },
  });

  useFrame(
    (_, frameDt) => {
      const el = canvas.current;
      if (!el) return;
      const { w, h } = stage();
      const dpr = Math.max(window.devicePixelRatio || 1, 2);
      if (el.width !== Math.round(w * dpr) || el.height !== Math.round(h * dpr)) {
        el.width = Math.round(w * dpr);
        el.height = Math.round(h * dpr);
      }
      const g = el.getContext("2d");
      if (!g) return;
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, w, h);
      const p = params.current;
      const m = model.current;
      const now = nowSeconds();
      const cx = w / 2;
      const cy = h / 2;
      const dt = Math.min(Math.max(frameDt, 0), 1 / 30);
      if (!m.seeded) {
        m.well = { x: cx, y: cy };
        m.seeded = true;
      }
      if (m.target) {
        const ax = (m.target.x - m.well.x) * 170 - m.vx * 20;
        const ay = (m.target.y - m.well.y) * 170 - m.vy * 20;
        m.vx += ax * dt;
        m.vy += ay * dt;
        m.well.x += m.vx * dt;
        m.well.y += m.vy * dt;
      } else {
        m.vx = 0;
        m.vy = 0;
      }
      m.strength += ((m.target ? 1 : 0) - m.strength) * Math.min(1, dt * 12);
      m.waves = m.waves.filter((t) => now - t <= 1.4);
      const ages = m.waves.map((t) => now - t);
      const clearBottom = ctx.isPreview ? 0 : 48;
      const columns = Math.floor(w / 2 / p.spacing) + 1;
      const rows = Math.floor(h / 2 / p.spacing) + 1;
      const base = p.dark ? "rgb(255 255 255 / 0.24)" : "rgb(0 0 0 / 0.24)";
      for (let row = -rows; row <= rows; row++) {
        for (let column = -columns; column <= columns; column++) {
          const hx = cx + column * p.spacing;
          const hy = cy + row * p.spacing;
          if (hy >= h - clearBottom) continue;
          let x = hx;
          let y = hy + Math.sin(now * 1.1 + hx * 0.021 + hy * 0.017) * 0.8;
          const dx = m.well.x - hx;
          const dy = m.well.y - hy;
          const distance = Math.max(Math.hypot(dx, dy), 0.001);
          const unit = distance / (p.radius * 0.45);
          const amount = Math.min(p.pull * unit * Math.exp(0.5 - (unit * unit) / 2) * m.strength, distance * 0.85);
          x += (dx / distance) * amount;
          y += (dy / distance) * amount;
          const reach = distance / p.radius;
          const glow = m.strength * Math.exp(-reach * reach * 2.4);
          let heat = glow;
          let swell = 0.7 * glow;
          const ox = hx - cx;
          const oy = hy - cy;
          const fromCenter = Math.max(Math.hypot(ox, oy), 0.001);
          for (const age of ages) {
            const offset = fromCenter - age * 260;
            const life = Math.max(0, 1 - age / 1.4);
            const bump = Math.exp(-(offset * offset) / (2 * 18 * 18)) * life;
            x += (ox / fromCenter) * p.wave * bump;
            y += (oy / fromCenter) * p.wave * bump;
            heat = Math.max(heat, bump);
            swell = Math.max(swell, 1.4 * bump);
          }
          const r = 1.6 * (1 + swell);
          g.beginPath();
          g.arc(x, y, r, 0, Math.PI * 2);
          if (heat < 0.99) {
            g.globalAlpha = 1 - heat;
            g.fillStyle = base;
            g.fill();
          }
          if (heat > 0.01) {
            g.globalAlpha = Math.min(heat, 1);
            g.fillStyle = HOT;
            g.fill();
          }
        }
      }
      g.globalAlpha = 1;
    },
    ctx.isPreview ? 30 : undefined,
  );

  const kt = useSince(presses, 0.55);
  const pop = track(kt, 1, [cubicKF(0.93, 0.08), springKF(1, 0.45, BOUNCY)]);

  return (
    <div ref={root} {...pan} role="button" style={{ ...pan.style, position: "absolute", inset: 0 }}>
      <canvas ref={canvas} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", display: "block", pointerEvents: "none" }} />
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
        <div style={{ transform: `scale(${pop})` }}>
          <motion.div
            initial={false}
            animate={{ scale: pressed ? 0.95 : 1, boxShadow: pressed ? `0px 4px 8px ${alpha(Palette.indigo, 0.4)}` : `0px 10px 18px ${alpha(Palette.indigo, 0.4)}` }}
            transition={spring(0.25, 0.7)}
            style={{
              width: BUTTON.w,
              height: BUTTON.h,
              borderRadius: BUTTON.h / 2,
              background: Palette.primary,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 8,
              color: "#fff",
              fontSize: 17,
              fontWeight: 600,
              position: "relative",
            }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: BUTTON.h / 2, boxShadow: `inset 0 0 0 1px ${white(0.24)}` }} />
            <Radio size={20} strokeWidth={2.4} />
            <span>{ctx.t("Send pulse", "发送脉冲")}</span>
          </motion.div>
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 18, pointerEvents: "none" }}>
        <DemoHint ctx={ctx} en="Drag around the dots, then tap the button" zh="在点阵上拖动，再点一下按钮" />
      </div>
    </div>
  );
}
