/** buttons.comet-border · 彗星描边 (Buttons+CometBorder.swift) */
import { motion } from "motion/react";
import { Sparkles } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { DemoHint, Palette, alpha, clamp, hash, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { mixRGB, nowSeconds, rgba, roundedLoop, useCanvas2D, useFrame } from "./_c-kit";

const STAGE = { w: 320, h: 150 };
const FACE = { w: 240, h: 66 };
const RECT = { x: (STAGE.w - FACE.w) / 2, y: (STAGE.h - FACE.h) / 2, w: FACE.w, h: FACE.h };
const PINK = 0xff5fa2;
const VIOLET = 0xa46bff;
const SKY = 0x3ac4ff;
const WHITE = [255, 255, 255];
const wrap = (v: number) => ((v % 1) + 1) % 1;

export default function CometBorder({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const [pressed, setPressedState] = useState(false);
  const pressedRef = useRef(false);
  const motionState = useRef({ phase: 0, speed: 0, flare: 0, started: false });
  const params = useRef({ lap: 3.2, boost: 3.5, tail: 0.32, comets: 1 });
  params.current = { lap: Math.max(ctx.n("lap"), 0.3), boost: ctx.n("boost"), tail: ctx.n("tail"), comets: clamp(ctx.i("comets"), 1, 3) };
  const loop = useMemo(() => roundedLoop(RECT.x + 1.5, RECT.y + 1.5, RECT.w - 3, RECT.h - 3, 20.5), []);

  const setPressed = (p: boolean) => {
    pressedRef.current = p;
    setPressedState(p);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (pressedRef.current) return;
      script.clearAll();
      setPressed(true);
      script.after(0.85, () => setPressed(false));
    },
    { every: 3.4, delay: 1.2 },
  );

  const glow = useCanvas2D(STAGE.w, STAGE.h);
  const main = useCanvas2D(STAGE.w, STAGE.h);

  const piece = (g: CanvasRenderingContext2D, from: number, to: number) => {
    const a = wrap(from);
    const b = a + (to - from);
    if (b <= 1) {
      loop.trace(g, a, b);
      return;
    }
    const first = loop.slice(a, 1);
    const second = loop.slice(0, b - 1);
    g.beginPath();
    g.moveTo(first[0].x, first[0].y);
    for (const p of [...first.slice(1), ...second]) g.lineTo(p.x, p.y);
  };

  useFrame(
    (_, dt) => {
      const g = main.get();
      const gg = glow.get();
      if (!g || !gg) return;
      const p = params.current;
      const m = motionState.current;
      const isPressed = pressedRef.current;
      const cruise = 1 / p.lap;
      if (!m.started) {
        m.started = true;
        m.speed = cruise;
      } else if (dt > 0) {
        const target = cruise * (isPressed ? p.boost : 1);
        m.speed += (target - m.speed) * (1 - Math.exp(-dt * (isPressed ? 9 : 2.4)));
        m.flare += ((isPressed ? 1 : 0) - m.flare) * (1 - Math.exp(-dt * (isPressed ? 10 : 3)));
        m.phase = (m.phase + m.speed * dt) % 1;
      }
      const flare = m.flare;
      const time = nowSeconds();
      g.clearRect(0, 0, STAGE.w, STAGE.h);
      gg.clearRect(0, 0, STAGE.w, STAGE.h);
      const length = Math.min(p.tail * (1 + 0.5 * flare), 0.9);

      if (flare > 0.01) {
        loop.trace(gg, 0, 1);
        gg.strokeStyle = alpha(Palette.sky, 0.4 * flare);
        gg.lineWidth = 4;
        gg.stroke();
      }
      for (let index = 0; index < p.comets; index++) {
        const head = (m.phase + index / p.comets) % 1;
        const point = loop.at(Math.max(wrap(head), 0.0001));

        // Reflection on the face.
        g.save();
        g.beginPath();
        g.roundRect(RECT.x, RECT.y, RECT.w, RECT.h, 22);
        g.clip();
        const radius = 58 * (1 + 0.3 * flare);
        const pool = g.createRadialGradient(point.x, point.y, 0, point.x, point.y, radius);
        pool.addColorStop(0, alpha(Palette.sky, 0.2 + 0.18 * flare));
        pool.addColorStop(0.5, alpha(Palette.violet, 0.07));
        pool.addColorStop(1, alpha(Palette.violet, 0));
        g.fillStyle = pool;
        g.beginPath();
        g.arc(point.x, point.y, radius, 0, Math.PI * 2);
        g.fill();
        g.restore();

        // Sparkles.
        const rate = 12 + 22 * flare;
        const life = 0.6;
        const newest = Math.floor(time * rate);
        for (let k = 0; k < Math.floor(life * rate); k++) {
          const n = newest - k;
          const age = time - n / rate;
          if (age < 0 || age >= life) continue;
          const home = loop.at(Math.max(wrap(head - m.speed * age - 0.01), 0.0001));
          const angle = hash(n + index * 97, 1) * 2 * Math.PI;
          const drift = 4 + 12 * hash(n + index * 97, 2);
          const x = home.x + (Math.cos(angle) * drift * age) / life;
          const y = home.y + (Math.sin(angle) * drift * age) / life;
          const fade = 1 - age / life;
          const twinkle = 0.6 + 0.4 * Math.sin(time * 30 + n);
          const r = (0.5 + 0.9 * hash(n, 3)) * (0.4 + 0.6 * fade);
          g.beginPath();
          g.arc(x, y, r, 0, Math.PI * 2);
          g.fillStyle = rgba(mixRGB(SKY, WHITE, 0.6), fade * twinkle);
          g.fill();
        }

        // Tail.
        const segments = 18;
        const strokeSegments = (target: CanvasRenderingContext2D, width: number) => {
          target.lineCap = "round";
          for (let s = 0; s < segments; s++) {
            const a = head - length + (length * s) / segments;
            const b = head - length + (length * (s + 1)) / segments;
            const heat = (s + 1) / segments;
            let color = mixRGB(PINK, VIOLET, Math.min(heat * 2.2, 1));
            color = mixRGB(color, SKY, clamp((heat - 0.4) * 2.5));
            color = mixRGB(color, WHITE, Math.max(heat - 0.8, 0) * 5);
            piece(target, a, b);
            target.strokeStyle = rgba(color, heat * heat);
            target.lineWidth = width * (0.3 + 0.7 * heat);
            target.stroke();
          }
        };
        strokeSegments(gg, 8 + 4 * flare);
        strokeSegments(g, 3);

        // Head.
        const halo = 13 * (1 + 0.8 * flare);
        const hg = g.createRadialGradient(point.x, point.y, 0, point.x, point.y, halo);
        hg.addColorStop(0, white(0.9));
        hg.addColorStop(0.5, alpha(Palette.sky, 0.45));
        hg.addColorStop(1, alpha(Palette.sky, 0));
        g.fillStyle = hg;
        g.beginPath();
        g.arc(point.x, point.y, halo, 0, Math.PI * 2);
        g.fill();
        g.beginPath();
        g.arc(point.x, point.y, 2.6 * (1 + 0.5 * flare), 0, Math.PI * 2);
        g.fillStyle = "#fff";
        g.fill();
      }
    },
    ctx.isPreview ? 30 : undefined,
  );

  const down = (e: React.PointerEvent<HTMLElement>) => {
    if (pressedRef.current) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    script.clearAll();
    setPressed(true);
    haptics.tap("medium");
  };
  const up = () => {
    if (!pressedRef.current) return;
    setPressed(false);
    haptics.tap("light");
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <motion.div initial={false} animate={{ scale: pressed ? 0.97 : 1 }} transition={spring(0.3, 0.65)} style={{ position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            left: RECT.x,
            top: RECT.y,
            width: FACE.w,
            height: FACE.h,
            borderRadius: 22,
            background: `linear-gradient(180deg, ${hex(0x23213f)}, ${hex(0x121124)})`,
            boxShadow: `inset 0 0 0 1px ${white(0.14)}, 0 8px 14px ${hex(0x1b1740, 0.35)}`,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            gap: 8,
            color: "#fff",
            fontSize: 17,
            fontWeight: 600,
          }}
        >
          <Sparkles size={19} color={hex(0xc4a0ff)} fill={hex(0xc4a0ff)} strokeWidth={1.6} />
          <span>{ctx.t("Upgrade to Pro", "升级专业版")}</span>
        </div>
        <canvas ref={glow.ref} style={{ ...glow.style, position: "absolute", inset: 0, filter: "blur(4.5px)" }} />
        <canvas ref={main.ref} style={{ ...main.style, position: "absolute", inset: 0 }} />
        <div role="button" onPointerDown={down} onPointerUp={up} onPointerCancel={up} style={{ position: "absolute", inset: 30, touchAction: "none", cursor: "pointer" }} />
      </motion.div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Press and hold to make it race" zh="按住按钮，让它加速" style={{ paddingBottom: 18 }} />
    </div>
  );
}
