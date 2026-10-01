/** buttons.clap-accumulate · 连击鼓掌 (Buttons+ClapAccumulate.swift) */
import { motion, useAnimationControls } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, black, fonts, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useSince } from "./_a-kit";
import { useCanvas2D, useFrame } from "./_c-kit";

interface Spark {
  birth: number;
  angle: number;
  reach: number;
  color: string;
  triangle: boolean;
  spin: number;
}

const BASE_TOTAL = 1284;
const now = () => performance.now() / 1000;
const rand = (a: number, b: number) => a + Math.random() * (b - a);

/** Stand-in for SF Symbols `hands.clap` / `hands.clap.fill`. */
function ClapGlyph({ size, filled, color }: { size: number; filled: boolean; color: string }) {
  const hand = "M17.2 10.6V6.4a1.7 1.7 0 0 0-3.4 0V5a1.7 1.7 0 0 0-3.4 0v1.2a1.7 1.7 0 0 0-3.4 0v7.2l-1.3-1.3a1.75 1.75 0 0 0-2.5 2.45l3.3 3.5C8 19.6 9.6 20.5 12.2 20.5h1.3a7 7 0 0 0 7-7V8.6a1.65 1.65 0 0 0-3.3 0Z";
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ overflow: "visible" }}>
      <g fill="none" stroke={color} strokeWidth={1.7} strokeLinecap="round">
        <path d="M5.2 4.6 4 2.6M8.3 3.4 8 1.2M2.6 7.4.7 6.4" />
      </g>
      <g transform="rotate(-28 12 13) translate(1.2 1.2) scale(0.9)">
        <path d={hand} transform="translate(3.2 -2.2)" fill={filled ? color : "none"} stroke={color} strokeWidth={1.7} strokeLinejoin="round" opacity={filled ? 0.55 : 1} />
        <path d={hand} fill={filled ? color : "var(--ml-elevated)"} stroke={color} strokeWidth={1.7} strokeLinejoin="round" />
      </g>
    </svg>
  );
}

export default function ClapAccumulate({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const dismiss = useTimeouts();
  const [count, setCount] = useState(0);
  const countRef = useRef(0);
  const streak = useRef(0);
  const bubblePhase = useRef<"hidden" | "shown" | "leaving">("hidden");
  const bubble = useAnimationControls();
  const sparks = useRef<Spark[]>([]);
  const [sparksLive, setSparksLive] = useState(false);
  const [holding, setHolding] = useState(false);
  const holdTimer = useRef(0);
  const touching = useRef(false);

  const cap = Math.max(ctx.i("cap"), 1);
  const capped = count >= cap;
  const rise = ctx.n("rise");
  const params = useRef({ cap, rise, sparks: ctx.i("sparks"), accel: ctx.n("accel") });
  params.current = { cap, rise, sparks: ctx.i("sparks"), accel: ctx.n("accel") };

  const emitSparks = () => {
    const t = now();
    sparks.current = sparks.current.filter((s) => t - s.birth <= 0.6);
    const amount = params.current.sparks + Math.min(Math.floor(streak.current / 2), 8);
    const reach = 20 + Math.min(streak.current * 1.6, 26);
    const start = rand(0, 2 * Math.PI);
    for (let index = 0; index < amount; index++) {
      sparks.current.push({
        birth: t,
        angle: start + (index / amount) * 2 * Math.PI + rand(-0.16, 0.16),
        reach: reach * rand(0.75, 1),
        color: Palette.spectrum[(index + streak.current) % Palette.spectrum.length],
        triangle: index % 2 === 0,
        spin: rand(-3, 3),
      });
    }
    setSparksLive(true);
  };

  const clap = (buzz: boolean) => {
    const p = params.current;
    if (countRef.current >= p.cap) {
      if (buzz) haptics.tap("rigid");
      return;
    }
    streak.current += 1;
    countRef.current += 1;
    setCount(countRef.current);
    if (buzz) {
      if (countRef.current >= p.cap) haptics.success();
      else haptics.tap(streak.current < 5 ? "light" : streak.current < 12 ? "medium" : "heavy");
    }
    emitSparks();
    if (bubblePhase.current !== "shown") {
      bubblePhase.current = "shown";
      bubble.set({ y: 0, scale: 0.3, opacity: 0 });
      void bubble.start({ y: -p.rise, scale: 1, opacity: 1, transition: spring(0.35, 0.6) });
    }
    dismiss.clearAll();
    dismiss.after(0.9, () => {
      bubblePhase.current = "leaving";
      void bubble.start({ y: -params.current.rise - 34, scale: 0.9, opacity: 0, transition: anim.easeOut(0.45) });
      streak.current = 0;
      setSparksLive(false);
    });
  };

  const beginHold = (buzz: boolean) => {
    window.clearTimeout(holdTimer.current);
    setHolding(true);
    clap(buzz);
    const multiplier = params.current.accel;
    let interval = 0.3;
    const loop = () => {
      clap(buzz);
      interval = Math.max(0.05, interval * multiplier);
      holdTimer.current = window.setTimeout(loop, interval * 1000);
    };
    holdTimer.current = window.setTimeout(loop, 380);
  };
  const endHold = () => {
    window.clearTimeout(holdTimer.current);
    setHolding(false);
  };

  const playScript = () => {
    script.clearAll();
    if (countRef.current >= params.current.cap) {
      countRef.current = 0;
      setCount(0);
    }
    clap(false);
    script.after(0.4, () => clap(false));
    script.after(1.0, () => beginHold(false));
    script.after(2.5, endHold);
  };
  useAutoplay(ctx.isPreview, playScript, { every: 4.6, delay: 0.4 });

  const canvas = useCanvas2D(220, 220);
  useFrame(
    () => {
      const g = canvas.get();
      if (!g) return;
      g.clearRect(0, 0, 220, 220);
      const t = now();
      for (const spark of sparks.current) {
        const age = (t - spark.birth) / 0.55;
        if (age < 0 || age >= 1) continue;
        const eased = 1 - Math.pow(1 - age, 3);
        const distance = 44 + spark.reach * eased;
        const x = 110 + Math.cos(spark.angle) * distance;
        const y = 110 + Math.sin(spark.angle) * distance;
        const dot = 3.4 * (1 - age * 0.6);
        g.globalAlpha = 1 - age * age;
        g.fillStyle = spark.color;
        g.beginPath();
        if (spark.triangle) {
          g.save();
          g.translate(x, y);
          g.rotate(spark.angle + spark.spin * age);
          g.moveTo(0, -dot * 1.4);
          g.lineTo(dot * 1.2, dot);
          g.lineTo(-dot * 1.2, dot);
          g.closePath();
          g.fill();
          g.restore();
        } else {
          g.arc(x, y, dot, 0, Math.PI * 2);
          g.fill();
        }
      }
      g.globalAlpha = 1;
    },
    ctx.isPreview ? 30 : undefined,
    sparksLive,
  );

  const t = useSince(count, 0.5);
  const tilt = track(t, 0, [cubicKF(-10, 0.07), springKF(0, 0.4, BOUNCY)]);
  const pop = track(t, 1, [cubicKF(1.16, 0.07), springKF(1, 0.4, BOUNCY)]);
  const bubblePop = track(t, 1, [cubicKF(1.22, 0.08), springKF(1, 0.35, BOUNCY)]);

  const active = count > 0;
  const tint = capped ? Palette.amber : Palette.green;

  const down = (e: React.PointerEvent<HTMLElement>) => {
    if (touching.current) return;
    touching.current = true;
    e.currentTarget.setPointerCapture(e.pointerId);
    script.clearAll();
    beginHold(true);
  };
  const up = () => {
    if (!touching.current) return;
    touching.current = false;
    endHold();
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16, flexShrink: 0 }}>
        <div style={{ position: "relative", width: 220, height: 96, marginTop: 64 }}>
          <canvas ref={canvas.ref} style={{ ...canvas.style, position: "absolute", left: 0, top: -62 }} />
          <motion.div
            animate={bubble}
            initial={{ y: 0, scale: 0.3, opacity: 0 }}
            style={{ position: "absolute", left: 86, top: 24, width: 48, height: 48, pointerEvents: "none" }}
          >
            <div
              style={{
                width: 48,
                height: 48,
                borderRadius: "50%",
                background: capped ? `linear-gradient(180deg, ${Palette.amber}, ${Palette.coral})` : `linear-gradient(180deg, ${Palette.mint}, ${Palette.green})`,
                boxShadow: `0 5px 10px ${alpha(capped ? Palette.coral : Palette.green, 0.4)}`,
                display: "grid",
                placeItems: "center",
                color: "#fff",
                fontFamily: fonts.rounded,
                fontWeight: 700,
                fontSize: count > 9 ? 16 : 18,
                transform: `scale(${bubblePop})`,
              }}
            >
              <span style={{ display: "inline-flex" }}>
                +<NumericText value={count} />
              </span>
            </div>
          </motion.div>
          <div style={{ position: "absolute", left: 72, top: 10, width: 76, height: 76, transform: `scale(${pop})` }}>
            <motion.div
              role="button"
              onPointerDown={down}
              onPointerUp={up}
              onPointerCancel={up}
              animate={{ scale: holding ? 0.94 : 1 }}
              transition={spring(0.25, 0.7)}
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                background: active ? alpha(tint, 0.16) : Palette.elevated,
                boxShadow: `inset 0 0 0 1.5px ${active ? alpha(tint, 0.9) : Palette.labelAlpha(0.18)}, 0 8px 14px ${active ? alpha(tint, 0.28) : black(0.1)}`,
                display: "grid",
                placeItems: "center",
                touchAction: "none",
                cursor: "pointer",
              }}
            >
              <div style={{ position: "absolute", inset: -10, borderRadius: "50%" }} />
              <div style={{ transform: `rotate(${tilt}deg)`, display: "grid" }}>
                <ClapGlyph size={36} filled={active} color={active ? tint : Palette.labelAlpha(0.75)} />
              </div>
            </motion.div>
          </div>
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 }}>
          <NumericText
            value={count}
            text={(BASE_TOTAL + count).toLocaleString("en-US")}
            style={{ fontFamily: fonts.rounded, fontSize: 22, lineHeight: "26px", fontWeight: 700, color: Palette.label }}
          />
          <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("claps", "次鼓掌")}</span>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap to clap, or hold to keep clapping" zh="点击鼓掌，或按住连续鼓掌" style={{ paddingBottom: 18 }} />
    </div>
  );
}
