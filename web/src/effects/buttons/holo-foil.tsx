/** buttons.holo-foil · 镭射箔面 (Buttons+HoloFoil.swift) */
import type { Transition } from "motion/react";
import { Sparkles } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, hex, spring, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, moveKF, springKF, track, useSince } from "./_a-kit";
import { nowSeconds, useAnimatedNumber, useCanvas2D } from "./_c-kit";

const SIZE = { w: 244, h: 68 };
const AREA = { w: 312, h: 150 };
const PATH = [
  { x: 0.9, y: -0.7 },
  { x: 0.2, y: 0.8 },
  { x: -0.9, y: 0.3 },
  { x: -0.3, y: -0.9 },
];
const COLORS = ["#FF5FA2", "#FFC247", "#9BE86B", "#21D4A8", "#3AC4FF", "#A46BFF"];

const noise = (seed: number, channel: number) => {
  const v = Math.sin(seed * 12.9898 + channel * 78.233) * 43758.5453;
  return v - Math.floor(v);
};

/** A seamless periodic gradient (SwiftUI strip rotated by `angle`, slid by `shift` periods) as a CSS repeating gradient. */
function strip(colors: string[], period: number, angle: number, shift: number): string {
  const cycles = Math.ceil(420 / period) + 2;
  const wrapped = shift - Math.floor(shift);
  const theta = ((90 + angle) * Math.PI) / 180;
  const L = Math.abs(SIZE.w * Math.sin(theta)) + Math.abs(SIZE.h * Math.cos(theta));
  let o = L / 2 + (-cycles / 2 + wrapped - 0.5) * period;
  o = ((o % period) + period) % period;
  const stops = [...colors, colors[0]].map((c, i) => `${c} ${(o + (period * i) / colors.length).toFixed(2)}px`);
  return `repeating-linear-gradient(${90 + angle}deg, ${stops.join(", ")})`;
}

export default function HoloFoil({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const intro = useTimeouts();
  const [light, setLight] = useState({ x: 0, y: 0 });
  const [energyTarget, setEnergyTarget] = useState(0);
  const target = useRef({ x: 0, y: 0, e: 0 });
  const [tr, setTr] = useState<Transition>(spring(0.3, 0.75));
  const [flashes, setFlashes] = useState(0);
  const step = useRef(0);

  const go = (x: number, y: number, e: number, t: Transition) => {
    target.current = { x, y, e };
    setTr(t);
    setLight({ x, y });
    setEnergyTarget(e);
  };
  const release = () => {
    const c = target.current;
    if (c.e === 0 && c.x === 0 && c.y === 0) return;
    go(0, 0, 0, spring(0.7, 0.7));
  };
  const stepPreview = () => {
    const next = PATH[step.current % PATH.length];
    step.current += 1;
    go(next.x, next.y, 1, spring(0.8, 0.8));
    if (step.current % 3 === 0) setFlashes((f) => f + 1);
  };
  const playIntro = () => {
    intro.clearAll();
    stepPreview();
    intro.after(0.85, stepPreview);
    intro.after(1.7, stepPreview);
    intro.after(2.55, release);
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? stepPreview() : playIntro()), { every: 0.9, delay: 0.3 });

  const pan = usePan({
    onChange: (s) => {
      intro.clearAll();
      if (target.current.e < 1) haptics.tap("soft");
      go(clamp((s.location.x - AREA.w / 2) / (SIZE.w / 2), -1, 1), clamp((s.location.y - AREA.h / 2) / (SIZE.h / 2), -1, 1), 1, spring(0.3, 0.75));
    },
    onEnd: (s) => {
      if (Math.abs(s.location.x - AREA.w / 2) < SIZE.w / 2 && Math.abs(s.location.y - AREA.h / 2) < SIZE.h / 2) {
        haptics.tap("medium");
        setFlashes((f) => f + 1);
      }
      release();
    },
  });

  const lx = useAnimatedNumber(light.x, tr);
  const ly = useAnimatedNumber(light.y, tr);
  const energy = useAnimatedNumber(energyTarget, tr);
  useClock(true, ctx.isPreview ? 30 : undefined);
  const time = nowSeconds() % 3600;

  const bands = ctx.n("bands");
  const intensity = ctx.n("intensity");
  const tilt = ctx.n("tilt");
  const flow = time * ctx.n("drift") * 0.14;
  const e = clamp(energy, 0, 1.2);

  const streaks = (period: number, angle: number, shift: number) => {
    const mask = strip(["transparent", "#fff"], period * 1.7, angle + 9, shift * 0.55 + 0.2);
    return { background: strip(COLORS, period, angle, shift), WebkitMaskImage: mask, maskImage: mask };
  };

  const glints = useCanvas2D(SIZE.w, SIZE.h);
  useEffect(() => {
    const g = glints.get();
    if (!g) return;
    g.clearRect(0, 0, SIZE.w, SIZE.h);
    const lightPhase = lx * 3.1 + ly * 2.3 + flow * 9;
    for (let index = 0; index < 60; index++) {
      const x = SIZE.w * noise(index, 1);
      const y = SIZE.h * noise(index, 2);
      const facing = Math.sin(noise(index, 3) * 2 * Math.PI + lightPhase * (0.6 + noise(index, 4)));
      const brightness = Math.pow(Math.max(facing, 0), 6) * (0.45 + 0.55 * e);
      if (brightness <= 0.03) continue;
      const reach = (1.6 + 3.2 * noise(index, 5)) * (0.6 + 0.4 * brightness);
      g.beginPath();
      g.moveTo(x, y - reach);
      g.quadraticCurveTo(x, y, x + reach, y);
      g.quadraticCurveTo(x, y, x, y + reach);
      g.quadraticCurveTo(x, y, x - reach, y);
      g.quadraticCurveTo(x, y, x, y - reach);
      g.fillStyle = white(clamp(brightness * intensity));
      g.fill();
    }
  });

  const ft = useSince(flashes, 0.6);
  const travel = ft < 0 ? 1 : track(ft, 1, [moveKF(-1), cubicKF(1, 0.55)]);
  const glow = track(ft, 0, [cubicKF(0.16, 0.12), cubicKF(0, 0.43)]);
  const scale = track(ft, 1, [cubicKF(0.96, 0.09), springKF(1, 0.5, BOUNCY)]);
  const bar = (peak: number) => `linear-gradient(90deg, transparent, ${white(peak)}, transparent)`;
  const barStyle = (width: number, x: number) =>
    ({ position: "absolute", left: SIZE.w / 2 - width / 2, top: SIZE.h / 2 - SIZE.h * 1.2, width, height: SIZE.h * 2.4, transform: `translateX(${x}px) rotate(22deg)`, mixBlendMode: "plus-lighter" }) as const;
  const rimAngle = lx * 120 + ly * 60 + flow * 360 + 90;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div {...pan} role="button" style={{ ...pan.style, position: "relative", width: AREA.w, height: AREA.h, flexShrink: 0, cursor: "pointer", perspective: SIZE.w / 0.6 }}>
        <div
          style={{
            position: "absolute",
            left: (AREA.w - SIZE.w) / 2,
            top: (AREA.h - SIZE.h) / 2,
            width: SIZE.w,
            height: SIZE.h,
            borderRadius: SIZE.h / 2,
            transform: `rotateY(${tilt * lx}deg) rotateX(${-tilt * ly}deg) scale(${scale})`,
            boxShadow: `0 10px 18px ${alpha(Palette.violet, clamp(0.25 + 0.25 * e))}`,
            filter: glow > 0.001 ? `brightness(${1 + glow * 1.6})` : undefined,
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: SIZE.h / 2, overflow: "hidden", isolation: "isolate", background: `linear-gradient(180deg, ${hex(0x2a2c3a)}, ${hex(0x0d0e13)})` }}>
            <div style={{ position: "absolute", inset: 0, opacity: clamp(intensity * (0.55 + 0.45 * e)), ...streaks(SIZE.w / bands, 24 + ly * 35 + lx * 8, lx * 0.5 + flow) }} />
            <div style={{ position: "absolute", inset: 0, opacity: intensity * 0.5, mixBlendMode: "plus-lighter", ...streaks((SIZE.w / bands) * 0.46, -38 - ly * 22, -lx * 0.8 - flow * 1.7) }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                mixBlendMode: "plus-lighter",
                background: `repeating-linear-gradient(135deg, ${white(0.07)} 0 0.5px, transparent 0.5px 2.12px)`,
              }}
            />
            <canvas ref={glints.ref} style={{ ...glints.style, position: "absolute", inset: 0, mixBlendMode: "plus-lighter" }} />
            <div
              style={{
                ...barStyle(84, lx * (SIZE.w / 2 - 20) + Math.sin(flow * 5) * 30 * (1 - e)),
                background: bar(0.5),
                opacity: clamp(0.28 + 0.34 * e),
              }}
            />
            <div style={{ position: "absolute", inset: 1.5, borderRadius: SIZE.h / 2, background: `linear-gradient(180deg, ${white(0.2)}, transparent 50%)` }} />
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
                fontWeight: 700,
                filter: `drop-shadow(0 1px 1.5px ${black(0.55)})`,
                transform: `translate(${-lx * 2}px, ${-ly * 1.5}px)`,
                whiteSpace: "nowrap",
              }}
            >
              <Sparkles size={19} fill="#fff" strokeWidth={1.6} />
              <span>{ctx.t("Claim reward", "领取奖励")}</span>
            </div>
            {travel < 0.999 && <div style={{ ...barStyle(110, travel * (SIZE.w / 2 + 90)), background: bar(0.85) }} />}
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: SIZE.h / 2,
              padding: 1.5,
              background: `conic-gradient(from ${rimAngle}deg, ${[...COLORS, COLORS[0]].join(", ")})`,
              WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
              WebkitMaskComposite: "xor",
              mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              opacity: clamp(0.55 + 0.45 * e),
              pointerEvents: "none",
            }}
          />
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Drag across the foil, then tap it" zh="在箔面上拖动，再点一下" style={{ paddingBottom: 18 }} />
    </div>
  );
}
