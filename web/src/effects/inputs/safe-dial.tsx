/** inputs.safe-dial (Inputs+SafeDial.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { memo, useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, delayed, fonts, spring, useAutoplay, useHaptics, useLatest, usePan, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { LockGlyph } from "./_b-common";
import { column, gray, spacer, useLive, useTask } from "./_c-common";

const COMBINATION = [30, 70, 15];
const FACE = 196;
const BEZEL = FACE + 22;

export default function SafeDial({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const params = useLatest({ lag: ctx.n("lag"), friction: ctx.n("friction"), dwell: ctx.n("dwell"), tolerance: ctx.i("tolerance") });
  /** Dial rotation in degrees, clockwise positive. The number under the pointer is -angle / 3.6. */
  const [angle, setAngle] = useState(0);
  const angleRef = useRef(0);
  const flick = useMotionValue(0);
  const [number, setNumber, numberRef] = useLive(0);
  const [pins, setPins, pinsRef] = useLive(0);
  const [unlocked, setUnlocked, unlockedRef] = useLive(false);
  const step = useRef(0);
  /** Values the physics loop needs between frames but that never drive rendering directly. */
  const physics = useRef({ omega: 0, target: null as number | null, scriptedRate: null as number | null, lastTheta: 0, loop: 0, last: 0 });
  /** Scripted spins (previews, the intro) stay silent until a finger takes over. */
  const scripted = useRef(false);
  const dwellTask = useTask();
  const relockTask = useTask();
  const unlockTask = useTask();

  useEffect(() => () => cancelAnimationFrame(physics.current.loop), []);

  const relock = () => {
    setUnlocked(false);
    setPins(0);
  };
  const scheduleRelock = () =>
    relockTask.start(async (sleep) => {
      if (!(await sleep(2.6))) return;
      relock();
    });

  const setPin = () => {
    setPins(pinsRef.current + 1);
    const quiet = scripted.current;
    if (!quiet) haptics.tap("rigid");
    if (pinsRef.current !== COMBINATION.length) return;
    unlockTask.start(async (sleep) => {
      if (!(await sleep(0.28))) return;
      setUnlocked(true);
      if (!quiet) haptics.success();
      if (!ctx.isPreview) scheduleRelock();
    });
  };

  const scheduleDwell = () =>
    dwellTask.start(async (sleep) => {
      if (!(await sleep(params.current.dwell))) return;
      if (unlockedRef.current || pinsRef.current >= COMBINATION.length) return;
      const apart = Math.abs(numberRef.current - COMBINATION[pinsRef.current]);
      if (Math.min(apart, 100 - apart) > params.current.tolerance) return;
      setPin();
    });

  /** One physics step. Returns false once the dial has come to rest. */
  const advance = (dt: number) => {
    const p = physics.current;
    const current = angleRef.current;
    let next = current;
    let resting = false;
    if (p.target !== null) {
      const rate = p.scriptedRate ?? 1 / Math.max(params.current.lag, 0.01);
      next += (p.target - current) * (1 - Math.exp(-dt * rate));
      p.omega = (next - current) / dt;
      if (p.scriptedRate !== null && Math.abs(p.target - next) < 0.2) {
        next = p.target;
        p.target = null;
        p.scriptedRate = null;
        p.omega = 0;
        resting = true;
      }
    } else {
      p.omega *= Math.exp(-params.current.friction * dt);
      next += p.omega * dt;
      if (Math.abs(p.omega) < 60) {
        // Slow enough: the detent spring takes over and seats the dial on a number.
        const detent = Math.round(next / 3.6) * 3.6;
        next += (detent - next) * (1 - Math.exp(-dt * 18));
        if (Math.abs(detent - next) < 0.05 && Math.abs(p.omega) < 8) {
          next = detent;
          p.omega = 0;
          resting = true;
        }
      }
    }
    angleRef.current = next;
    setAngle(next);
    const target = clamp(p.omega / 40, -16, 16);
    flick.stop();
    flick.set(flick.get() + (target - flick.get()) * (1 - Math.exp(-dt * 30)));
    if (resting) animate(flick, 0, spring(0.25, 0.4));
    const raw = Math.round(-next / 3.6) % 100;
    const value = raw < 0 ? raw + 100 : raw;
    if (value !== numberRef.current) {
      setNumber(value);
      if (!scripted.current) haptics.selection();
      scheduleDwell();
    }
    return !resting;
  };

  /** Starts the physics loop if it is not already running. */
  const run = () => {
    const p = physics.current;
    if (p.loop) return;
    p.last = performance.now();
    const frame = (now: number) => {
      const dt = Math.min((now - p.last) / 1000, 1 / 30);
      p.last = now;
      if (dt > 0 && !advance(dt)) {
        p.loop = 0;
        return;
      }
      p.loop = requestAnimationFrame(frame);
    };
    p.loop = requestAnimationFrame(frame);
  };

  /** Finger lifted or gesture cancelled: the dial keeps its angular velocity and coasts. */
  const letGo = () => {
    const p = physics.current;
    if (p.target === null || p.scriptedRate !== null) return;
    p.target = null;
    run();
    if (unlockedRef.current) scheduleRelock();
  };

  const pan = usePan({
    onChange: ({ location }) => {
      const p = physics.current;
      const center = BEZEL / 2;
      const dx = location.x - center;
      const dy = location.y - (center + 4);
      if (Math.hypot(dx, dy) <= 16) return;
      const theta = (Math.atan2(dy, dx) * 180) / Math.PI;
      if (p.target === null || p.scriptedRate !== null) {
        p.scriptedRate = null;
        scripted.current = false;
        p.target = angleRef.current;
        p.lastTheta = theta;
        relockTask.cancel();
      }
      let delta = theta - p.lastTheta;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      p.lastTheta = theta;
      p.target = (p.target ?? angleRef.current) + delta;
      run();
    },
    onEnd: letGo,
  });

  /** Turns the dial to `value` in the given direction through the same follow path a finger uses. */
  const spin = (value: number, clockwise: boolean) => {
    const wanted = -value * 3.6;
    let delta = (wanted - angleRef.current) % 360;
    if (clockwise) while (delta < 90) delta += 360;
    else while (delta > -90) delta -= 360;
    physics.current.target = angleRef.current + delta;
    physics.current.scriptedRate = 5.5;
    scripted.current = true;
    run();
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const phase = step.current % 5;
      step.current += 1;
      if (phase === 0) spin(30, true);
      else if (phase === 1) spin(70, false);
      else if (phase === 2) spin(15, true);
      else if (phase === 4) {
        relock();
        spin(0, false);
      }
    },
    { every: 1.5, delay: 0.4 },
  );

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12, flexShrink: 0, transform: ctx.isPreview ? "scale(1.04)" : undefined }}>
        {/* Lock case: the bolt leaves it on the left. */}
        <div
          style={{
            width: 256,
            height: 48,
            borderRadius: 16,
            background: Palette.labelAlpha(0.06),
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
            display: "flex",
            alignItems: "center",
            justifyContent: "flex-end",
            gap: 8,
            paddingRight: 10,
          }}
        >
          <div style={{ position: "relative", width: 62, height: 20, borderRadius: 10, background: black(0.28), flexShrink: 0 }}>
            <motion.div
              initial={false}
              animate={{ x: unlocked ? -3 : -33 }}
              transition={spring(0.5, 0.62)}
              style={{
                position: "absolute",
                right: 0,
                top: 2,
                width: 56,
                height: 16,
                borderRadius: 5,
                background: "linear-gradient(180deg, #F2F4F8, #9EA3AD, #D8DBE2)",
                boxShadow: `inset 0 0 0 0.5px ${black(0.2)}, 0 1px 3px ${black(0.3)}`,
              }}
            />
          </div>
          <div style={{ width: 24, marginRight: 2, display: "grid", placeItems: "center", color: unlocked ? Palette.green : Palette.secondaryLabel, flexShrink: 0 }}>
            <SymbolSwap k={unlocked ? "open" : "closed"}>
              <LockGlyph open={unlocked} size={18} />
            </SymbolSwap>
          </div>
          {COMBINATION.map((value, index) => {
            const set = index < pins;
            const current = index === pins && !unlocked;
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{ y: set ? -5 : 0, backgroundColor: set ? Palette.green : "rgb(128 128 128 / 0.16)", boxShadow: `0 2px 12px ${alpha(Palette.green, set ? 0.5 : 0)}` }}
                transition={delayed(spring(0.3, 0.5), set ? 0 : index * 0.06)}
                style={{
                  position: "relative",
                  width: 40,
                  height: 30,
                  borderRadius: 10,
                  flexShrink: 0,
                  display: "grid",
                  placeItems: "center",
                  fontFamily: fonts.rounded,
                  fontSize: 15,
                  fontWeight: 700,
                  fontVariantNumeric: "tabular-nums",
                  color: set ? "#fff" : current ? Palette.label : Palette.secondaryLabel,
                  transition: "color 0.2s ease-out",
                }}
              >
                {value}
                <div style={{ position: "absolute", inset: 0, borderRadius: 10, border: `1.5px solid ${Palette.labelAlpha(0.5)}`, opacity: current ? 1 : 0, transition: "opacity 0.2s ease-out" }} />
              </motion.div>
            );
          })}
        </div>
        {/* Dial */}
        <div {...pan} style={{ ...pan.style, position: "relative", width: BEZEL, height: FACE + 30, borderRadius: "50%", cursor: "grab" }}>
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 4,
              width: BEZEL,
              height: BEZEL,
              borderRadius: "50%",
              background: `conic-gradient(from 90deg, ${gray(0.92)}, ${gray(0.55)}, ${gray(0.85)}, ${gray(0.5)}, ${gray(0.92)})`,
              boxShadow: `0 10px 24px ${black(0.3)}`,
            }}
          />
          <div style={{ position: "absolute", left: 11, top: 15, width: FACE, height: FACE, transform: `rotate(${angle}deg)` }}>
            <SafeFace />
          </div>
          {/* knob */}
          <div style={{ position: "absolute", left: (BEZEL - 94) / 2, top: 4 + (BEZEL - 94) / 2, width: 94, height: 94 }}>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                background: `conic-gradient(from 50deg, ${gray(0.96)}, ${gray(0.5)}, ${gray(0.88)}, ${gray(0.42)}, ${gray(0.96)})`,
                boxShadow: `0 5px 12px ${black(0.5)}`,
              }}
            />
            {/* Grip ridges and the index line turn with the dial; the metal's highlights stay with the light. */}
            <div style={{ position: "absolute", inset: 0, transform: `rotate(${angle}deg)` }}>
              <Ridges />
            </div>
            <div style={{ position: "absolute", left: 33, top: 33, width: 28, height: 28, borderRadius: "50%", background: `linear-gradient(180deg, ${gray(0.98)}, ${gray(0.62)})` }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                display: "grid",
                placeItems: "center",
                fontFamily: fonts.rounded,
                fontSize: 13,
                fontWeight: 800,
                fontVariantNumeric: "tabular-nums",
                color: gray(0.15),
              }}
            >
              {String(number).padStart(2, "0")}
            </div>
          </div>
          {/* pointer */}
          <motion.svg
            width={14}
            height={16}
            style={{ position: "absolute", left: BEZEL / 2 - 7, top: (FACE + 30) / 2 - BEZEL / 2 - 2 - 8, rotate: flick, originX: 0.5, originY: 0, filter: `drop-shadow(0 1px 2px ${black(0.35)})`, overflow: "visible" }}
          >
            <path d="M0 0H14L7 16Z" fill="#FF4D5E" />
          </motion.svg>
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Turn the dial and rest on 30, then 70, then 15" zh="转动转盘，依次停在 30、70、15" style={{ paddingBottom: 12 }} />
    </div>
  );
}

const Ridges = memo(function Ridges() {
  return (
    <>
      {Array.from({ length: 30 }, (_, i) => (
        <div key={i} style={{ position: "absolute", left: 46, top: 47 - 41 - 4, width: 2, height: 8, borderRadius: 1, background: black(0.28), transformOrigin: "1px 45px", transform: `rotate(${i * 12}deg)` }} />
      ))}
      <div style={{ position: "absolute", left: 45.5, top: 47 - 22 - 7.5, width: 3, height: 15, borderRadius: 1.5, background: "#FF4D5E" }} />
    </>
  );
});

/** Static dial face: 100 ticks and a numeral every ten, drawn once and rotated as a layer. */
const SafeFace = memo(function SafeFace() {
  const c = FACE / 2;
  const outer = FACE / 2;
  return (
    <svg width={FACE} height={FACE} style={{ display: "block" }}>
      <circle cx={c} cy={c} r={outer} fill={gray(0.07)} />
      {Array.from({ length: 100 }, (_, index) => {
        const major = index % 10 === 0;
        const mid = index % 5 === 0;
        const length = major ? 15 : mid ? 11 : 7;
        return (
          <g key={index} transform={`rotate(${index * 3.6} ${c} ${c})`}>
            <line x1={c} y1={c - (outer - 4)} x2={c} y2={c - (outer - 4 - length)} stroke="#fff" strokeOpacity={major ? 0.95 : 0.6} strokeWidth={major ? 2 : 1} />
            {major && (
              <text x={c} y={c - (outer - 29)} fill="#fff" fillOpacity={0.92} fontFamily={fonts.rounded} fontSize={13} fontWeight={700} textAnchor="middle" dominantBaseline="central">
                {index}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
});
