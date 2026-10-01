/** buttons.mesh-breath · 网格呼吸 (Buttons+MeshBreath.swift) */
import { motion } from "motion/react";
import { ArrowRight } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, black, clamp, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { MeshRenderer, acquire, release } from "../backgrounds/_gl";
import { pointIn } from "./_a-kit";
import { mixRGB, nowSeconds, useFrame } from "./_c-kit";

const SIZE = { w: 244, h: 72 };
const LIFE = 0.9;
const SPEED = 320;
const SCRIPT = [
  { x: 52, y: 40 },
  { x: 196, y: 30 },
  { x: 122, y: 36 },
];
const BASE = [0x6e7bff, 0xa46bff, 0xff5fa2, 0xff7a5c, 0x4f7cff, 0x8f5bff, 0xff6fa8, 0xffc247, 0x3ac4ff, 0x6e7bff, 0xa46bff, 0xff5fa2];

interface Pulse {
  x: number;
  y: number;
  start: number;
}

function meshColors(breath: number): number[] {
  const lean = 0.3 * (0.5 + 0.5 * breath);
  const out: number[] = [];
  for (let index = 0; index < 12; index++) {
    const row = Math.floor(index / 4);
    const neighbour = row * 4 + (((index % 4) + 1) % 4);
    out.push(...mixRGB(BASE[index], BASE[neighbour], lean).map((c) => c / 255));
  }
  return out;
}

function meshPoints(time: number, drift: number, breath: number, pulses: Pulse[], strength: number): number[] {
  const out: number[] = [];
  for (let row = 0; row < 3; row++) {
    for (let column = 0; column < 4; column++) {
      const vEdge = column === 0 || column === 3;
      const hEdge = row === 0 || row === 2;
      const phase = column * 1.9 + row * 2.7;
      let x = column / 3;
      let y = row / 2;
      if (!vEdge) x += drift * Math.sin(time * 0.9 + phase);
      if (!hEdge) y += drift * 1.8 * Math.cos(time * 0.7 + phase * 1.3) + 0.06 * breath * (column % 2 === 0 ? 1 : -1);
      let px = x * SIZE.w;
      let py = y * SIZE.h;
      for (const pulse of pulses) {
        const age = time - pulse.start;
        if (age < 0 || age >= LIFE) continue;
        const dx = px - pulse.x;
        const dy = py - pulse.y;
        const distance = Math.max(Math.hypot(dx, dy), 0.001);
        const offset = distance - age * SPEED;
        const push = strength * 27 * Math.exp(-(offset * offset) / (46 * 46)) * (1 - age / LIFE);
        px += (dx / distance) * push;
        py += (dy / distance) * push;
      }
      out.push(vEdge ? column / 3 : clamp(px / SIZE.w, 0.04, 0.96), hEdge ? row / 2 : clamp(py / SIZE.h, 0.06, 0.94));
    }
  }
  return out;
}

export default function MeshBreath({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const pulses = useRef<Pulse[]>([]);
  const [pressed, setPressedState] = useState(false);
  const pressedRef = useRef(false);
  const step = useRef(0);
  const gl = useRef<HTMLCanvasElement>(null);
  const bloom = useRef<HTMLCanvasElement>(null);
  const bloomWrap = useRef<HTMLDivElement>(null);
  const ringLayer = useRef<HTMLDivElement>(null);
  const renderer = useRef<MeshRenderer | null>(null);
  const params = useRef({ period: 4.5, drift: 0.1, bloom: 0.6, pulse: 0.6 });
  params.current = { period: ctx.n("period"), drift: ctx.n("drift"), bloom: ctx.n("bloom"), pulse: ctx.n("pulse") };

  const setPressed = (p: boolean) => {
    pressedRef.current = p;
    setPressedState(p);
  };
  const pulse = (x: number, y: number) => {
    const t = nowSeconds();
    pulses.current = [...pulses.current.filter((p) => t - p.start < LIFE), { x: clamp(x, 0, SIZE.w), y: clamp(y, 0, SIZE.h), start: t }];
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (pressedRef.current) return;
      const origin = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      script.clearAll();
      setPressed(true);
      pulse(origin.x, origin.y);
      script.after(0.22, () => setPressed(false));
    },
    { every: 2.3, delay: 0.8 },
  );

  useEffect(() => {
    const el = gl.current;
    if (!el) return;
    const r = acquire(el, () => new MeshRenderer(el));
    renderer.current = r;
    return () => {
      release(el, r);
      renderer.current = null;
    };
  }, []);

  useFrame(
    () => {
      const p = params.current;
      const time = nowSeconds();
      const breath = Math.sin((time * 2 * Math.PI) / Math.max(p.period, 0.5));
      const strength = p.pulse;
      renderer.current?.draw(SIZE.w, SIZE.h, 2, 4, 3, meshPoints(time, p.drift, breath, pulses.current, strength), meshColors(breath));
      let flash = 0;
      for (const q of pulses.current) {
        const u = (time - q.start) / LIFE;
        if (u >= 0 && u < 1) flash = Math.max(flash, (1 - u) * (1 - u) * strength);
      }
      const b = bloom.current;
      const src = gl.current;
      if (b && src && src.width > 0) {
        if (b.width !== src.width || b.height !== src.height) {
          b.width = src.width;
          b.height = src.height;
        }
        const g = b.getContext("2d");
        g?.drawImage(src, 0, 0);
      }
      if (bloomWrap.current) {
        bloomWrap.current.style.transform = `scale(${1.085 + 0.025 * breath + 0.1 * flash})`;
        bloomWrap.current.style.opacity = String(Math.min(p.bloom * (0.7 + 0.2 * breath) + 0.5 * flash, 1));
      }
      const layer = ringLayer.current;
      if (layer) {
        const live = pulses.current.filter((q) => time - q.start < LIFE);
        while (layer.children.length < live.length) {
          const ring = document.createElement("div");
          ring.style.cssText = "position:absolute;border-radius:50%;box-sizing:border-box;filter:blur(7px);mix-blend-mode:plus-lighter;pointer-events:none";
          layer.appendChild(ring);
        }
        Array.from(layer.children).forEach((node, i) => {
          const ring = node as HTMLDivElement;
          const q = live[i];
          if (!q) {
            ring.style.display = "none";
            return;
          }
          const age = time - q.start;
          const u = age / LIFE;
          const outer = age * SPEED + 6;
          ring.style.display = "block";
          ring.style.left = `${q.x - outer}px`;
          ring.style.top = `${q.y - outer}px`;
          ring.style.width = ring.style.height = `${outer * 2}px`;
          ring.style.border = `${Math.min(12, outer)}px solid ${white(0.6 * strength * (1 - u))}`;
        });
      }
    },
    ctx.isPreview ? 30 : undefined,
  );

  const down = (e: React.PointerEvent<HTMLElement>) => {
    if (pressedRef.current) return;
    e.currentTarget.setPointerCapture(e.pointerId);
    script.clearAll();
    setPressed(true);
    haptics.tap("soft");
    const p = pointIn(e, e.currentTarget);
    pulse(p.x, p.y);
  };
  const up = () => {
    if (!pressedRef.current) return;
    setPressed(false);
    haptics.tap("light");
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <motion.div
        role="button"
        onPointerDown={down}
        onPointerUp={up}
        onPointerCancel={up}
        initial={false}
        animate={{ scale: pressed ? 0.965 : 1 }}
        transition={spring(0.35, 0.6)}
        style={{ position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0, borderRadius: SIZE.h / 2, touchAction: "none", cursor: "pointer" }}
      >
        <div ref={bloomWrap} style={{ position: "absolute", inset: 0, filter: "blur(15px)", pointerEvents: "none" }}>
          <canvas ref={bloom} style={{ width: SIZE.w, height: SIZE.h, display: "block", borderRadius: SIZE.h / 2 }} />
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: SIZE.h / 2, overflow: "hidden", isolation: "isolate" }}>
          <canvas ref={gl} style={{ width: SIZE.w, height: SIZE.h, display: "block" }} />
          <div ref={ringLayer} style={{ position: "absolute", inset: 0 }} />
          <div style={{ position: "absolute", inset: 0, background: `linear-gradient(180deg, ${white(0.22)}, transparent 50%)` }} />
        </div>
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: SIZE.h / 2,
            padding: 1.2,
            background: `linear-gradient(180deg, ${white(0.65)}, ${white(0.1)})`,
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
            pointerEvents: "none",
          }}
        />
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
            filter: `drop-shadow(0 1px 1.5px ${black(0.3)})`,
            pointerEvents: "none",
          }}
        >
          <span>{ctx.t("Get started", "立即开始")}</span>
          <ArrowRight size={19} strokeWidth={2.5} />
        </div>
      </motion.div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap anywhere on the button" zh="点击按钮任意位置" style={{ paddingBottom: 18 }} />
    </div>
  );
}
