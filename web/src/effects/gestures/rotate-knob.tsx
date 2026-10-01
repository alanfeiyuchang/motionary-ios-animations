/** gestures.rotate-knob · 旋钮档位 (Gestures+RotateKnob.swift) */
import { animate, motion, useMotionValue, useMotionValueEvent } from "motion/react";
import { Volume, Volume2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, black, clamp, fonts, rubberBand, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { labelColor, setShadow, useCanvas2D, useGhost, usePinch } from "./_sim-kit";

const STAGE = 252;
const SIZE = 150;
const SWEEP = 270;
const TRACK = 104;
const COLORS = [Palette.mint, Palette.sky, Palette.indigo, Palette.violet, Palette.pink];

export default function RotateKnob({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const detents = Math.max(ctx.i("detents"), 1);
  const spacing = SWEEP / detents;
  const snap = ctx.n("snap");
  const start = Math.round(detents * 0.42);
  /** Raw rotation in degrees from the minimum, before the detent pull. 0…270. */
  const raw = useMotionValue(start * spacing);
  const [rawShown, setRawShown] = useState(raw.get());
  const [notch, setNotch] = useState(start);
  const [held, setHeld] = useState(false);
  const s = useRef({ lastTouchAngle: null as number | null, lastTwist: 0, twisting: false, held: false, notch: start, pressing: false, twistingNow: false, autoStep: 0, target: raw.get() }).current;
  const canvas = useCanvas2D(STAGE, STAGE);
  const dark = ctx.scheme === "dark";

  useMotionValueEvent(raw, "change", setRawShown);

  /** The angle the knob shows: raw, rubber-banded past the ends and pulled into the detents. */
  const shown = (r: number) => {
    if (r < 0) return -rubberBand(-r, 18);
    if (r > SWEEP) return SWEEP + rubberBand(r - SWEEP, 18);
    return r - ((snap * spacing) / (2 * Math.PI)) * Math.sin((2 * Math.PI * r) / spacing);
  };

  // Changing the detent count re-seats the knob on the nearest new detent.
  const lastDetents = useRef(detents);
  useEffect(() => {
    if (lastDetents.current === detents) return;
    lastDetents.current = detents;
    const seated = Math.round(s.target / spacing) * spacing;
    raw.stop();
    raw.set(seated);
    s.target = seated;
    s.notch = Math.round(seated / spacing);
    setNotch(s.notch);
  }, [detents, spacing, raw, s]);

  const beginHold = () => {
    if (s.held) return;
    s.held = true;
    setHeld(true);
  };

  /** Finger and ghost finger both land here. */
  const turn = (newRaw: number, scripted = false) => {
    raw.stop();
    const r = clamp(newRaw, -90, SWEEP + 90);
    raw.set(r);
    s.target = r;
    const nearest = clamp(Math.round(shown(r) / spacing), 0, detents);
    if (nearest !== s.notch) {
      s.notch = nearest;
      setNotch(nearest);
      if (!scripted) haptics.selection();
    }
  };

  const release = (scripted = false) => {
    if (!s.held) return;
    s.lastTouchAngle = null;
    const target = clamp(Math.round(raw.get() / spacing), 0, detents) * spacing;
    animate(raw, target, spring(ctx.n("response"), ctx.n("damping")));
    s.target = target;
    s.held = false;
    setHeld(false);
    s.notch = Math.round(target / spacing);
    setNotch(s.notch);
    if (!scripted) haptics.tap("soft");
  };

  const pan = usePan({
    onChange: ({ start: at, location }) => {
      if (!s.pressing) {
        if (Math.hypot(at.x - STAGE / 2, at.y - STAGE / 2) > STAGE / 2) return;
        s.pressing = true;
      }
      if (!s.held) ghost.touch();
      beginHold();
      if (s.twisting) {
        s.lastTouchAngle = null;
        return;
      }
      const dx = location.x - STAGE / 2;
      const dy = location.y - STAGE / 2;
      // Too close to the centre the angle is noise.
      if (!(dx * dx + dy * dy > 18 * 18)) {
        s.lastTouchAngle = null;
        return;
      }
      const touch = (Math.atan2(dy, dx) * 180) / Math.PI;
      if (s.lastTouchAngle !== null) {
        let delta = touch - s.lastTouchAngle;
        if (delta > 180) delta -= 360;
        if (delta < -180) delta += 360;
        turn(raw.get() + delta);
      }
      s.lastTouchAngle = touch;
    },
    onEnd: () => {
      s.lastTouchAngle = null;
      if (!s.pressing) return;
      s.pressing = false;
      if (!s.twistingNow) release();
    },
  });

  const pinch = usePinch<HTMLDivElement>({
    onChange: (magnification, rotation, _anchor, source) => {
      // A trackpad pinch (ctrl + wheel) stands in for the two-finger twist on desktop.
      const degrees = source === "wheel" ? Math.log(magnification) * 120 : rotation;
      if (!s.twistingNow && Math.abs(degrees) < 2) return;
      s.twistingNow = true;
      if (!s.held) ghost.touch();
      beginHold();
      if (!s.twisting) {
        s.twisting = true;
        s.lastTwist = degrees;
      }
      turn(raw.get() + degrees - s.lastTwist);
      s.lastTwist = degrees;
    },
    onEnd: () => {
      s.twistingNow = false;
      s.twisting = false;
      if (!s.pressing) release();
    },
  });

  /** A scripted finger sweeps the knob to another detent and lets go. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.pressing || s.twistingNow) return;
      s.autoStep += 1;
      const stops = [0.83, 0.25, 0.58, 1.0, 0.08, 0.5];
      const goal = Math.round(stops[s.autoStep % stops.length] * detents) * spacing;
      // Stop a little short or long, so the release visibly snaps.
      const end = goal + spacing * (s.autoStep % 2 === 0 ? 0.32 : -0.32);
      const from = raw.get();
      ghost.run(async (g) => {
        beginHold();
        if (!(await g.drag({ x: from, y: 0 }, { x: end, y: 0 }, 0.75, (p) => turn(p.x, true)))) return;
        if (!(await g.sleep(0.1))) return;
        release(true);
      });
    },
    { every: 1.9, delay: 0.5 },
  );

  const angle = shown(rawShown);
  const fraction = clamp(angle / SWEEP, 0, 1);

  // Value arc: an angular gradient trimmed to the fraction, with a glow.
  useEffect(() => {
    const g = canvas.begin();
    if (!g) return;
    const c = STAGE / 2;
    const a0 = (135 * Math.PI) / 180;
    g.lineCap = "round";
    g.lineWidth = 8;
    g.beginPath();
    g.arc(c, c, TRACK, a0, a0 + (SWEEP * Math.PI) / 180);
    g.strokeStyle = labelColor(ctx.scheme, 0.09);
    g.stroke();
    if (fraction > 0.0005 && typeof g.createConicGradient === "function") {
      const grad = g.createConicGradient(a0, c, c);
      COLORS.forEach((color, i) => grad.addColorStop((i / (COLORS.length - 1)) * 0.75, color));
      grad.addColorStop(0.875, Palette.pink);
      grad.addColorStop(0.8751, Palette.mint);
      grad.addColorStop(1, Palette.mint);
      g.save();
      setShadow(g, alpha(Palette.violet, 0.15 + 0.45 * fraction), 4 + 8 * fraction);
      g.beginPath();
      g.arc(c, c, TRACK, a0, a0 + ((SWEEP * Math.PI) / 180) * fraction);
      g.strokeStyle = grad;
      g.stroke();
      g.restore();
    }
  });

  const hi = dark ? 0.42 : 1.0;
  const lo = dark ? 0.15 : 0.7;
  const gray = (w: number) => `rgb(${Math.round(w * 255)} ${Math.round(w * 255)} ${Math.round(w * 255)})`;
  const metal = [hi, lo, hi * 0.92, lo * 0.9, hi, lo, hi * 0.92, lo * 0.9, hi].map(gray).join(", ");
  const knobAngle = angle - 135;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div
        ref={pinch.ref}
        onPointerDown={(e) => {
          pinch.handlers.down(e);
          pan.onPointerDown(e);
        }}
        onPointerMove={(e) => {
          pinch.handlers.move(e);
          pan.onPointerMove(e);
        }}
        onPointerUp={(e) => {
          pinch.handlers.up(e);
          pan.onPointerUp(e);
        }}
        onPointerCancel={(e) => {
          pinch.handlers.up(e);
          pan.onPointerCancel(e);
        }}
        style={{ position: "relative", width: STAGE, height: STAGE, flex: "none", touchAction: "none", borderRadius: "50%", cursor: "grab" }}
      >
        <canvas ref={canvas.ref} style={canvas.style} />
        {Array.from({ length: detents + 1 }, (_, index) => {
          const lit = index <= notch;
          return (
            <div
              key={index}
              style={{ position: "absolute", left: STAGE / 2 - 1.25, top: STAGE / 2 - 3.5, width: 2.5, height: 7, transform: `rotate(${-135 + (SWEEP * index) / detents}deg) translateY(${-(TRACK + 14)}px)`, transformOrigin: "50% 50%" }}
            >
              <motion.div
                initial={false}
                animate={{ scaleY: index === notch ? 1.6 : 1, backgroundColor: labelColor(ctx.scheme, lit ? 0.75 : 0.2) }}
                transition={spring(0.25, 0.5)}
                style={{ width: "100%", height: "100%", borderRadius: 1.25, transformOrigin: "50% 100%" }}
              />
            </div>
          );
        })}

        <motion.div
          initial={false}
          animate={{ scale: held ? 1.03 : 1, boxShadow: `0 ${held ? 14 : 9}px ${held ? 20 : 14}px ${black(dark ? 0.5 : 0.22)}` }}
          transition={held ? anim.easeOut(0.15) : spring(ctx.n("response"), ctx.n("damping"))}
          style={{ position: "absolute", left: (STAGE - SIZE) / 2, top: (STAGE - SIZE) / 2, width: SIZE, height: SIZE, borderRadius: "50%" }}
        >
          {/* Knurled rim: turns with the knob. */}
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `conic-gradient(from 90deg, ${metal})` }} />
          <svg width={SIZE} height={SIZE} style={{ position: "absolute", inset: 0, transform: `rotate(${knobAngle}deg)` }}>
            {Array.from({ length: 60 }, (_, i) => {
              const a = (i / 60) * 2 * Math.PI;
              const outer = SIZE / 2 - 1;
              const inner = outer - 11;
              return (
                <line
                  key={i}
                  x1={SIZE / 2 + Math.cos(a) * inner}
                  y1={SIZE / 2 + Math.sin(a) * inner}
                  x2={SIZE / 2 + Math.cos(a) * outer}
                  y2={SIZE / 2 + Math.sin(a) * outer}
                  stroke={black(dark ? 0.55 : 0.22)}
                  strokeWidth={1.6}
                />
              );
            })}
          </svg>
          {/* Face: its highlights stay with the light. */}
          <div style={{ position: "absolute", inset: 14, borderRadius: "50%", background: `conic-gradient(from 114deg, ${metal})` }}>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                padding: 1.5,
                background: `linear-gradient(180deg, ${white(dark ? 0.35 : 0.95)}, ${black(dark ? 0.5 : 0.18)})`,
                WebkitMask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              }}
            />
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: dark ? black(0.25) : white(0.35) }} />
          </div>
          {/* Indicator dot. */}
          <div style={{ position: "absolute", inset: 0, transform: `rotate(${knobAngle}deg)` }}>
            <div
              style={{
                position: "absolute",
                left: SIZE / 2 - 4.5,
                top: SIZE / 2 - 4.5 - (SIZE / 2 - 26),
                width: 9,
                height: 9,
                borderRadius: "50%",
                background: Palette.mint,
                boxShadow: `0 0 ${3 + 5 * fraction}px ${alpha(Palette.mint, 0.9)}`,
              }}
            />
          </div>
        </motion.div>

        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none", fontFamily: fonts.rounded, fontSize: 40, fontWeight: 600, color: Palette.labelAlpha(0.85) }}>
          <NumericText value={notch} />
        </div>
        <div
          style={{
            position: "absolute",
            left: (STAGE - 150) / 2,
            width: 150,
            top: STAGE / 2 + TRACK + 4 - 8,
            display: "flex",
            justifyContent: "space-between",
            color: Palette.secondaryLabel,
            pointerEvents: "none",
          }}
        >
          <Volume size={15} fill="currentColor" strokeWidth={2} />
          <Volume2 size={15} fill="currentColor" strokeWidth={2} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag around the knob, or twist with two fingers" zh="绕着旋钮拖动，或双指拧转" />
    </div>
  );
}
