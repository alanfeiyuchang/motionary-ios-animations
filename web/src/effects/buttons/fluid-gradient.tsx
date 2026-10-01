/** buttons.fluid-gradient · 流体渐变 (Buttons+FluidGradient.swift) */
import { motion } from "motion/react";
import { Droplet } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, hex, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { nowSeconds, useCanvas2D, useFrame } from "./_c-kit";

const SIZE = { w: 248, h: 72 };
const PAD = 60;
const CAPACITY = 6;
const SCRIPT_LENGTH = 1.7;
const COLORS = [Palette.pink, Palette.amber, Palette.sky, Palette.mint, Palette.violet, Palette.coral];

const home = (index: number, count: number) => {
  const slots = Math.max(count, 1);
  return { x: (SIZE.w * ((index % slots) + 0.5)) / slots, y: SIZE.h * (index % 2 === 0 ? 0.36 : 0.66) };
};

export default function FluidGradient({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const sim = useRef<{ pos: { x: number; y: number }[]; vel: { x: number; y: number }[] } | null>(null);
  if (!sim.current) {
    sim.current = { pos: Array.from({ length: CAPACITY }, (_, i) => home(i, 4)), vel: Array.from({ length: CAPACITY }, () => ({ x: 0, y: 0 })) };
  }
  const finger = useRef<{ x: number; y: number } | null>(null);
  const scriptStart = useRef<number | null>(null);
  const [touching, setTouching] = useState(false);
  const [scripting, setScripting] = useState(false);
  const count = clamp(ctx.i("count"), 1, CAPACITY);
  const params = useRef({ count, stiffness: 120, ratio: 0.55 });
  params.current = { count, stiffness: ctx.n("stiffness"), ratio: ctx.n("damping") };
  const blur = ctx.n("blur");

  const stopScript = () => {
    script.clearAll();
    scriptStart.current = null;
    setScripting(false);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (finger.current) return;
      scriptStart.current = nowSeconds();
      setScripting(true);
      script.clearAll();
      script.after(SCRIPT_LENGTH, () => setScripting(false));
    },
    { every: 3.1, delay: 0.5 },
  );

  const pan = usePan({
    onChange: (s) => {
      if (!finger.current) {
        stopScript();
        haptics.tap("soft");
        setTouching(true);
      }
      finger.current = { x: clamp(s.location.x, 0, SIZE.w), y: clamp(s.location.y, 0, SIZE.h) };
    },
    onEnd: () => {
      finger.current = null;
      setTouching(false);
      haptics.tap("light");
    },
  });

  const canvas = useCanvas2D(SIZE.w + PAD * 2, SIZE.h + PAD * 2);
  useFrame(
    (_, frameDt) => {
      const s = sim.current!;
      const p = params.current;
      const time = nowSeconds();
      let target: { x: number; y: number } | null = finger.current;
      if (!target && scriptStart.current !== null) {
        const u = (time - scriptStart.current) / SCRIPT_LENGTH;
        if (u >= 0 && u < 1) target = { x: SIZE.w * (0.5 + 0.38 * Math.sin(u * 2 * Math.PI)), y: SIZE.h * (0.5 + 0.22 * Math.sin(u * 4 * Math.PI)) };
      }
      const elapsed = Math.min(frameDt, 1 / 20);
      if (elapsed > 0) {
        const steps = 3;
        const dt = elapsed / steps;
        for (let index = 0; index < Math.min(p.count, CAPACITY); index++) {
          const k = p.stiffness * Math.pow(0.72, index);
          const c = 2 * p.ratio * Math.sqrt(k);
          const phase = index * 1.7;
          let goal: { x: number; y: number };
          if (target) {
            const orbit = time * 1.4 + (index * 2 * Math.PI) / Math.max(p.count, 1);
            goal = { x: target.x + Math.cos(orbit) * 34, y: target.y + Math.sin(orbit) * 15 };
          } else {
            const h = home(index, p.count);
            goal = { x: h.x + Math.sin(time * 0.7 + phase) * 9, y: h.y + Math.cos(time * 0.55 + phase * 1.3) * 6 };
          }
          for (let n = 0; n < steps; n++) {
            const ax = k * (goal.x - s.pos[index].x) - c * s.vel[index].x;
            const ay = k * (goal.y - s.pos[index].y) - c * s.vel[index].y;
            s.vel[index].x += ax * dt;
            s.vel[index].y += ay * dt;
            s.pos[index].x += s.vel[index].x * dt;
            s.pos[index].y += s.vel[index].y * dt;
          }
        }
      }
      const g = canvas.get();
      if (!g) return;
      g.clearRect(0, 0, SIZE.w + PAD * 2, SIZE.h + PAD * 2);
      for (let index = 0; index < p.count; index++) {
        const pos = s.pos[index];
        const vel = s.vel[index];
        const stretch = 1 + Math.min(Math.hypot(vel.x, vel.y) / 600, 0.45);
        const radius = 34 + (index % 3) * 5;
        g.save();
        g.translate(pos.x + PAD, pos.y + PAD);
        g.rotate(Math.atan2(vel.y, vel.x));
        g.scale(stretch, 1 / stretch);
        g.beginPath();
        g.arc(0, 0, radius, 0, Math.PI * 2);
        g.fillStyle = alpha(COLORS[index % COLORS.length], 0.92);
        g.fill();
        g.restore();
      }
    },
    ctx.isPreview ? 30 : undefined,
  );

  const pressed = touching || scripting;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <motion.div
        {...pan}
        role="button"
        initial={false}
        animate={{ scale: pressed ? 0.97 : 1 }}
        transition={spring(0.3, 0.65)}
        style={{ ...pan.style, position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0, borderRadius: SIZE.h / 2, boxShadow: `0 10px 18px ${hex(0x3a1d8f, 0.45)}`, cursor: "pointer" }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: SIZE.h / 2,
            overflow: "hidden",
            background: `linear-gradient(${Math.atan2(SIZE.w, -SIZE.h)}rad, ${hex(0x1a1b45)}, ${hex(0x34186b)})`,
          }}
        >
          <canvas ref={canvas.ref} style={{ ...canvas.style, position: "absolute", left: -PAD, top: -PAD, filter: `blur(${blur * 0.62}px)` }} />
          <div style={{ position: "absolute", left: 8, right: 8, top: 3, bottom: 34, borderRadius: 18, background: `linear-gradient(180deg, ${white(0.26)}, transparent 50%)` }} />
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 8,
              color: "#fff",
              fontSize: 17,
              fontWeight: 600,
              filter: `drop-shadow(0 1px 1.5px ${black(0.35)})`,
            }}
          >
            <Droplet size={18} fill="#fff" strokeWidth={1.5} />
            <span>{ctx.t("Explore", "开始探索")}</span>
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: SIZE.h / 2,
            padding: 1.2,
            background: `linear-gradient(180deg, ${white(0.7)}, ${white(0.08)})`,
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
            pointerEvents: "none",
          }}
        />
      </motion.div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Drag across the button" zh="在按钮上来回拖动" style={{ paddingBottom: 18 }} />
    </div>
  );
}
