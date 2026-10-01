/** buttons.keycap · 机械键帽 (Buttons+Keycap.swift) */
import { ArrowBigUp, Command, CornerDownLeft, type LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { useLatchedPress } from "./_a-kit";
import { lerpRGB, roundRect, useAnimatedNumber, useCanvas2D } from "./_c-kit";

interface Spec {
  icon: LucideIcon;
  tint: string;
  accent: boolean;
}
const KEYS: Spec[] = [
  { icon: Command, tint: Palette.sky, accent: false },
  { icon: ArrowBigUp, tint: Palette.violet, accent: false },
  { icon: CornerDownLeft, tint: Palette.coral, accent: true },
];

const W = 88;
const H = 110;
const BASE = { x: 4, y: 24, w: 80, h: 80 };
const BASE_RADIUS = 17;
const TAPER = 10;
const LAYERS = 26;

export default function Keycap({ ctx }: DemoProps) {
  const { after, clearAll } = useTimeouts();
  const [forced, setForced] = useState<number | null>(null);
  const step = useRef(0);
  const dark = ctx.scheme === "dark";

  const strike = (index: number) => {
    step.current = index + 1;
    setForced(index % KEYS.length);
    clearAll();
    after(0.2, () => setForced(null));
  };
  const playIntro = () => {
    clearAll();
    KEYS.forEach((_, index) => {
      after(index * 0.48, () => setForced(index));
      after(index * 0.48 + 0.2, () => setForced(null));
    });
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? strike(step.current) : playIntro()), { every: 0.62, delay: 0.4 });

  const height = ctx.n("height");
  const travel = Math.min(ctx.n("travel"), height - 2);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div
        style={{
          position: "relative",
          flexShrink: 0,
          display: "flex",
          gap: 8,
          padding: "20px 16px 12px",
          borderRadius: 26,
          background: dark ? `linear-gradient(180deg, ${hex(0x0c0c10)}, ${hex(0x17171d)})` : `linear-gradient(180deg, ${hex(0xc9ccd6)}, ${hex(0xdddfe7)})`,
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 26,
            padding: 1.5,
            background: `linear-gradient(180deg, ${black(dark ? 0.6 : 0.16)}, ${white(dark ? 0.1 : 0.7)})`,
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
            pointerEvents: "none",
          }}
        />
        {KEYS.map((spec, index) => (
          <Key key={index} spec={spec} forced={forced === index} travel={travel} height={height} glow={ctx.n("glow")} wobble={ctx.n("wobble")} dark={dark} />
        ))}
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Press the keys" zh="按下这些按键" style={{ paddingBottom: 18 }} />
    </div>
  );
}

function Key({ spec, forced, travel, height, glow, wobble, dark }: { spec: Spec; forced: boolean; travel: number; height: number; glow: number; wobble: number; dark: boolean }) {
  const haptics = useHaptics();
  const { held, handlers } = useLatchedPress({
    minimumHold: 0.12,
    pressDelay: 0.05,
    onPress: () => haptics.tap("rigid"),
    onRelease: () => haptics.tap("soft"),
  });
  const pressed = held || forced;
  const depth = useAnimatedNumber(pressed ? 1 : 0, pressed ? spring(0.13, 0.85) : spring(0.32, 0.42));
  const pressure = clamp(depth);
  const lift = height - travel * depth;
  const midX = BASE.x + BASE.w / 2;
  const midY = BASE.y + BASE.h / 2;
  const canvas = useCanvas2D(W, H);

  useEffect(() => {
    const g = canvas.get();
    if (!g) return;
    g.clearRect(0, 0, W, H);
    roundRect(g, BASE.x + 1, BASE.y + 1, BASE.w - 2, BASE.h - 2, BASE_RADIUS);
    g.fillStyle = black(dark ? 0.7 : 0.3);
    g.fill();
    const sink = travel * depth;
    const low = spec.accent ? 0xa5361f : dark ? 0x17181d : 0xa9acb9;
    const high = spec.accent ? 0xe2553a : dark ? 0x2e3039 : 0xdadce4;
    for (let index = 0; index <= LAYERS; index++) {
      const t = index / LAYERS;
      const z = height * t - sink;
      if (z < -0.5) continue;
      const x = BASE.x + TAPER * t;
      const y = BASE.y + TAPER * t - z;
      const w = BASE.w - 2 * TAPER * t;
      const h = BASE.h - 2 * TAPER * t;
      roundRect(g, x, y, w, h, BASE_RADIUS - 4 * t);
      if (index < LAYERS) {
        g.fillStyle = lerpRGB(low, high, t);
        g.fill();
      } else {
        const top = spec.accent ? hex(0xff8a66) : dark ? hex(0x4a4c58) : hex(0xffffff);
        const bottom = spec.accent ? hex(0xf0603f) : dark ? hex(0x363842) : hex(0xecedf2);
        const fill = g.createLinearGradient(0, y, 0, y + h);
        fill.addColorStop(0, bottom);
        fill.addColorStop(1, top);
        g.fillStyle = fill;
        g.fill();
        const edge = g.createLinearGradient(0, y, 0, y + h);
        edge.addColorStop(0, white(dark ? 0.28 : 0.9));
        edge.addColorStop(1, white(0.02));
        g.strokeStyle = edge;
        g.lineWidth = 1;
        g.stroke();
      }
    }
  });

  const reach = 4 + 9 * (1 - clamp(depth, -0.3, 1));
  const legend = spec.accent ? "#fff" : dark ? alpha(spec.tint, 0.75 + 0.25 * pressure) : hex(0x3c3f4d, 0.85);
  const Icon = spec.icon;

  return (
    <button
      type="button"
      {...handlers}
      style={{
        position: "relative",
        width: W,
        height: H,
        flexShrink: 0,
        touchAction: "none",
        transform: `rotate(${wobble * Math.sin(depth * Math.PI)}deg)`,
        transformOrigin: "50% 100%",
      }}
    >
      <div
        style={{
          position: "absolute",
          left: midX - (BASE.w - 6) / 2,
          top: midY + reach - (BASE.h - 8) / 2,
          width: BASE.w - 6,
          height: BASE.h - 8,
          borderRadius: BASE_RADIUS,
          background: black(dark ? 0.55 : 0.26),
          filter: "blur(5px)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: BASE.x - 2.5,
          top: BASE.y - 2.5,
          width: BASE.w + 5,
          height: BASE.h + 5,
          borderRadius: BASE_RADIUS + 4.5,
          border: `5px solid ${spec.tint}`,
          boxSizing: "border-box",
          filter: "blur(6px)",
          opacity: glow * (0.3 + 0.7 * pressure),
        }}
      />
      <canvas ref={canvas.ref} style={{ ...canvas.style, position: "absolute", left: 0, top: 0 }} />
      <div
        style={{
          position: "absolute",
          left: midX - 15,
          top: midY - lift - 15,
          width: 30,
          height: 30,
          display: "grid",
          placeItems: "center",
          color: legend,
          filter: spec.accent ? undefined : `drop-shadow(0 0 5px ${alpha(spec.tint, clamp(glow * (0.35 + 0.65 * pressure)))})`,
        }}
      >
        <Icon size={27} strokeWidth={2.4} />
      </div>
    </button>
  );
}
