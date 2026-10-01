/** inputs.center-slider (Inputs+CenterSlider.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, useState } from "react";
import { Headphones } from "lucide-react";
import { DemoHint, NumericText, Palette, anim, black, clamp, fonts, mix, spring, springAt, useAutoplay, useElapsed, useHaptics, usePan, type DemoProps } from "../../kit";
import { column, spacer, useMV, useTask } from "./_c-common";

const WIDTH = 264;
const HALF = WIDTH / 2;
const SCRIPT = [0.62, 0, -0.74, 0, 0.42];

export default function CenterSlider({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** Displayed position = base (jumps with the finger) + offset (the snap spring's remainder). */
  const baseMV = useMotionValue(0.42);
  const offsetMV = useMotionValue(0);
  const raw = useRef(0.42);
  const snappedRef = useRef(false);
  const [snapped, setSnapped] = useState(false);
  const pressMV = useMotionValue(0);
  const pressing = useRef(false);
  const touching = useRef(false);
  const lean = useMotionValue(0);
  const startRaw = useRef(0);
  const [pulse, setPulse] = useState(0);
  const step = useRef(0);
  const playTask = useTask();
  const damping = ctx.n("damping");

  const target = () => (snappedRef.current ? 0 : raw.current);

  /** Finger and autoplay both land here. */
  const move = (to: number, velocity: number) => {
    const before = baseMV.get() + offsetMV.get();
    raw.current = to;
    const inside = Math.abs(to) < ctx.n("detent");
    if (inside !== snappedRef.current) {
      if (inside) {
        haptics.tap("rigid");
        setPulse((p) => p + 1);
      } else haptics.tap("light");
      snappedRef.current = inside;
      setSnapped(inside);
      baseMV.set(target());
      offsetMV.set(before - target());
      animate(offsetMV, 0, spring(0.28, damping));
    } else baseMV.set(target());
    const maxLean = ctx.n("lean");
    animate(lean, clamp(-velocity / 45, -maxLean, maxLean), spring(0.3, 0.6));
  };

  const release = () => {
    if (!pressing.current) return;
    pressing.current = false;
    const t = spring(0.35, damping);
    animate(pressMV, 0, t);
    animate(lean, 0, t);
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ translation, velocity }) => {
      if (!pressing.current) {
        playTask.cancel();
        baseMV.stop();
        startRaw.current = target();
        haptics.tap("light");
        pressing.current = true;
        animate(pressMV, 1, spring(0.3, damping));
      }
      move(clamp(startRaw.current + translation.x / HALF, -1, 1), velocity.x);
    },
    onEnd: () => {
      touching.current = false;
      release();
    },
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      const to = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      playTask.start(async (sleep) => {
        const direction = to > baseMV.get() + offsetMV.get() ? -1 : 1;
        pressing.current = true;
        animate(pressMV, 1, spring(0.3, damping));
        animate(lean, direction * ctx.n("lean"), spring(0.3, damping));
        const inside = Math.abs(to) < ctx.n("detent");
        raw.current = to;
        snappedRef.current = inside;
        setSnapped(inside);
        animate(baseMV, inside ? 0 : to, anim.smoothD(0.5));
        if (!(await sleep(0.38))) return;
        if (inside) setPulse((p) => p + 1);
        animate(lean, 0, spring(0.4, 0.45));
        if (!(await sleep(0.5))) return;
        release();
      });
    },
    { every: 1.5, delay: 0.5 },
  );

  const shown = useMV(baseMV) + useMV(offsetMV);
  const press = useMV(pressMV);
  const p = clamp(press);
  const negative = shown < 0;
  const tint = negative ? Palette.pink : Palette.indigo;
  const amount = Math.round(Math.abs(shown) * 100);
  const label = amount === 0 ? "0" : negative ? `L ${amount}` : `R ${amount}`;

  const pulseT = useElapsed(pulse, 0.55, true);
  const tick = pulseT < 0 ? 1 : pulseT < 0.12 ? mix(1, 1.8, springAt(pulseT, 0.12, 0.85)) : mix(1.8, 1, springAt(pulseT - 0.12, 0.4, 0.7));

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", alignItems: "center", gap: 14, paddingBottom: 62 }}>
        <Meter letter="L" level={1 - Math.max(shown, 0)} tint={Palette.pink} mirrored />
        <Headphones size={34} strokeWidth={2.3} color={Palette.secondaryLabel} />
        <Meter letter="R" level={1 - Math.max(-shown, 0)} tint={Palette.indigo} mirrored={false} />
      </div>
      <div style={{ position: "relative", width: WIDTH, height: 44, flexShrink: 0 }}>
        <div style={{ position: "absolute", left: 0, top: 18, width: WIDTH, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.12) }} />
        <div
          style={{
            position: "absolute",
            left: HALF + Math.min(shown, 0) * HALF,
            top: 18,
            width: Math.max(Math.abs(shown) * HALF, 0.01),
            height: 8,
            borderRadius: 4,
            background: tint,
            transition: "background-color 0.2s ease-out",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: HALF - 1.5,
            top: 13,
            width: 3,
            height: 18,
            borderRadius: 1.5,
            background: snapped ? Palette.label : Palette.labelAlpha(0.35),
            transform: `scale(${tick})`,
            transition: "background-color 0.2s",
          }}
        />
        {/* thumb */}
        <div style={{ position: "absolute", left: HALF + shown * HALF - 14, top: 8, width: 28, height: 28 }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              background: "#fff",
              boxShadow: `0 ${mix(2, 5, p)}px ${mix(6, 13, p)}px ${black(mix(0.2, 0.3, p))}`,
              transform: `scale(${mix(1, 1.15, press)})`,
            }}
          />
          {/* bubble */}
          <motion.div
            style={{
              position: "absolute",
              left: "50%",
              top: -46,
              x: "-50%",
              rotate: lean,
              scale: mix(0.4, 1, press),
              opacity: p,
              transformOrigin: "50% 100%",
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              pointerEvents: "none",
            }}
          >
            <div
              style={{
                minWidth: 46,
                height: 30,
                padding: "0 11px",
                borderRadius: 15,
                background: tint,
                transition: "background-color 0.2s ease-out",
                display: "grid",
                placeItems: "center",
                fontFamily: fonts.rounded,
                fontSize: 15,
                fontWeight: 700,
                color: "#fff",
                whiteSpace: "nowrap",
              }}
            >
              <NumericText value={shown} text={label} />
            </div>
            <svg width={12} height={7} viewBox="0 0 12 7" style={{ marginTop: -1, overflow: "visible" }}>
              <path d="M0 0H12Q6 11.2 0 0Z" style={{ fill: tint, transition: "fill 0.2s ease-out" }} />
            </svg>
          </motion.div>
        </div>
        <div {...pan} style={{ ...pan.style, position: "absolute", inset: -12, cursor: "grab" }} />
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Drag across the centre" zh="拖过中点试试" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function Meter({ letter, level, tint, mirrored }: { letter: string; level: number; tint: string; mirrored: boolean }) {
  const lit = Math.round(level * 5);
  const bars = (
    <div style={{ display: "flex", alignItems: "center", gap: 4, transform: mirrored ? "scaleX(-1)" : undefined }}>
      {[0, 1, 2, 3, 4].map((index) => (
        // The bar nearest the headphones is index 0.
        <div key={index} style={{ width: 5, height: 10 + index * 4, borderRadius: 2.5, background: index < lit ? tint : Palette.labelAlpha(0.12), transition: "background-color 0.2s" }} />
      ))}
    </div>
  );
  const letterView = (
    <motion.span
      initial={false}
      animate={{ scale: 0.85 + 0.25 * level }}
      transition={spring(0.3, 0.7)}
      style={{ width: 18, textAlign: "center", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, color: level > 0.5 ? Palette.label : Palette.secondaryLabel, transition: "color 0.2s" }}
    >
      {letter}
    </motion.span>
  );
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
      {mirrored ? (
        <>
          {letterView}
          {bars}
        </>
      ) : (
        <>
          {bars}
          {letterView}
        </>
      )}
    </div>
  );
}
