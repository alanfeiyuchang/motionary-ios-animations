/** buttons.emoji-fountain · 表情喷泉 (Buttons+EmojiFountain.swift) */
import type { Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, clamp, fonts, hash, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { cubicKF, springKF, track, useSince } from "./_a-kit";
import { useAnimatedNumber, useCanvas2D, useFrame } from "./_c-kit";

interface Particle {
  birth: number;
  angle: number;
  speed: number;
  spin: number;
  tilt: number;
  size: number;
  symbol: number;
}

const STAGE = { w: 320, h: 272 };
const LIFE = 1.25;
const ORIGIN = { x: STAGE.w / 2, y: STAGE.h - 44 };
const EMOJI = ["😍", "🔥", "👏", "🎉", "💜", "✨"];
const now = () => performance.now() / 1000;

function makeParticle(seed: number, birth: number, power: number, spread: number): Particle {
  const cone = (spread * Math.PI) / 180;
  return {
    birth,
    angle: (hash(seed, 1) * 2 - 1) * cone,
    speed: power * (0.78 + 0.3 * hash(seed, 2)),
    spin: ((hash(seed, 3) * 2 - 1) * 320 * Math.PI) / 180,
    tilt: (hash(seed, 4) * 2 - 1) * 0.5,
    size: 0.8 + 0.45 * hash(seed, 5),
    symbol: seed,
  };
}

export default function EmojiFountain({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const cool = useTimeouts();
  const idle = useTimeouts();
  const particles = useRef<Particle[]>([]);
  const [total, setTotal] = useState(124);
  const [heatTarget, setHeatTarget] = useState(0);
  const [heatTr, setHeatTr] = useState<Transition>(spring(0.3, 0.6));
  const heatRef = useRef(0);
  const [taps, setTaps] = useState(0);
  const seed = useRef(0);
  const lastTap = useRef(-1e9);
  const [live, setLive] = useState(false);
  const params = useRef({ count: 3, power: 460, spread: 20, gravity: 950 });
  params.current = { count: ctx.i("count"), power: ctx.n("power"), spread: ctx.n("spread"), gravity: ctx.n("gravity") };

  const heat = clamp(useAnimatedNumber(heatTarget, heatTr), 0, 1.3);

  const fire = () => {
    const t = now();
    const chained = t - lastTap.current < 0.5;
    lastTap.current = t;
    const newHeat = chained ? Math.min(heatRef.current + 0.2, 1) : 0;
    heatRef.current = newHeat;
    setHeatTr(spring(0.3, 0.6));
    setHeatTarget(newHeat);
    const p = params.current;
    const amount = clamp(p.count, 1, 8) + Math.round(newHeat * 4);
    const power = p.power * (1 + 0.25 * newHeat);
    const next = particles.current.filter((q) => t - q.birth < LIFE);
    for (let index = 0; index < amount; index++) {
      seed.current += 1;
      next.push(makeParticle(seed.current, t + index * 0.022, power, p.spread));
    }
    particles.current = next;
    setTaps((n) => n + 1);
    setTotal((n) => n + 1);
    haptics.tap(newHeat > 0.7 ? "medium" : "light");
    setLive(true);
    cool.clearAll();
    cool.after(0.7, () => {
      heatRef.current = 0;
      setHeatTr(anim.easeOut(0.5));
      setHeatTarget(0);
    });
    idle.clearAll();
    idle.after(LIFE + 0.4, () => {
      setLive(false);
      particles.current = [];
    });
  };

  const playScript = () => {
    script.clearAll();
    fire();
    for (let k = 0; k < 5; k++) script.after(0.75 + k * 0.15, fire);
  };
  useAutoplay(ctx.isPreview, playScript, { every: 2.7, delay: 0.4 });

  const canvas = useCanvas2D(STAGE.w, STAGE.h);
  useFrame(
    () => {
      const g = canvas.get();
      if (!g) return;
      g.clearRect(0, 0, STAGE.w, STAGE.h);
      const t = now();
      g.font = `26px ${fonts.text}, "Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji"`;
      g.textAlign = "center";
      g.textBaseline = "middle";
      const gravity = params.current.gravity;
      for (const p of particles.current) {
        const age = t - p.birth;
        if (age < 0 || age >= LIFE) continue;
        const x = Math.sin(p.angle) * p.speed * age;
        const y = -Math.cos(p.angle) * p.speed * age + 0.5 * gravity * age * age;
        if (y >= 20) continue;
        const pop = Math.min(age / 0.09, 1);
        const scale = p.size * (0.3 + 0.7 * pop);
        g.save();
        g.translate(ORIGIN.x + x, ORIGIN.y + y);
        g.rotate(p.tilt + p.spin * age);
        g.scale(scale, scale);
        g.globalAlpha = Math.min((LIFE - age) / (LIFE * 0.3), 1);
        g.fillText(EMOJI[Math.abs(p.symbol) % EMOJI.length], 0, 1);
        g.restore();
      }
    },
    ctx.isPreview ? 30 : undefined,
    live,
  );

  const kt = useSince(taps, 0.55);
  const sy = track(kt, 1, [cubicKF(0.88, 0.07), springKF(1, 0.45, [0.3, 0.5])]);
  const sx = track(kt, 1, [cubicKF(1.06, 0.07), springKF(1, 0.45, [0.3, 0.5])]);
  const ring = 84 + 22 * heat;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1, minHeight: 0 }} />
      <div style={{ position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0 }}>
        <canvas ref={canvas.ref} style={{ ...canvas.style, position: "absolute", inset: 0 }} />
        <button
          type="button"
          onClick={() => {
            script.clearAll();
            fire();
          }}
          style={{ position: "absolute", left: ORIGIN.x - 55, top: ORIGIN.y - 55, width: 110, height: 110, borderRadius: "50%", transform: `scale(${sx}, ${sy})` }}
        >
          <div
            style={{
              position: "absolute",
              left: 55 - ring / 2,
              top: 55 - ring / 2,
              width: ring,
              height: ring,
              borderRadius: "50%",
              boxSizing: "border-box",
              border: `${2 + 3 * heat}px solid ${alpha(Palette.amber, clamp(0.25 + 0.6 * heat))}`,
              filter: `blur(${1.5 * heat}px)`,
              opacity: heat > 0.01 ? 1 : 0,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: 19,
              top: 19,
              width: 72,
              height: 72,
              borderRadius: "50%",
              background: Palette.sunset,
              boxShadow: `0 7px ${12 + 8 * heat}px ${alpha(Palette.coral, clamp(0.35 + 0.3 * heat))}`,
            }}
          >
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                padding: 1.2,
                background: `linear-gradient(180deg, ${white(0.6)}, transparent)`,
                WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                WebkitMaskComposite: "xor",
                mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              }}
            />
          </div>
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontSize: 32, lineHeight: 1 }}>🎉</div>
        </button>
        <div style={{ position: "absolute", left: ORIGIN.x + 84 - 35, top: ORIGIN.y - 13, width: 70, pointerEvents: "none" }}>
          <NumericText
            value={total}
            style={{ fontFamily: fonts.rounded, fontSize: 20, lineHeight: "25px", fontWeight: 700, color: heatTarget > 0.5 ? Palette.coral : Palette.secondaryLabel }}
          />
        </div>
      </div>
      <div style={{ flex: 1, minHeight: 0 }} />
      <DemoHint ctx={ctx} en="Tap, then tap faster" zh="点一下，再越点越快" style={{ paddingBottom: 18 }} />
    </div>
  );
}
