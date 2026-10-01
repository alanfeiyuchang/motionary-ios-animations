/** inputs.clock-picker (Inputs+ClockPicker.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useId, useRef } from "react";
import type { Transition } from "motion/react";
import { DemoHint, NumericText, Palette, alpha, anim, clamp, fonts, mix, spring, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { column, spacer, useLive, useMV, useQuiet, useTask } from "./_c-common";

type Mode = "hour" | "minute";
const DIAL = 224;
const RADIUS = 85;
const DISC = 40;

const shortest = (current: number, target: number) => {
  let delta = (target - current) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return delta;
};

export default function ClockPicker({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  const advanceTask = useTask();
  const scriptTask = useTask();
  const [mode, setModeState, modeRef] = useLive<Mode>("hour");
  const [hour, setHour, hourRef] = useLive(10);
  const [minute, setMinute, minuteRef] = useLive(30);
  /** Hand angle in degrees, clockwise from 12. Unbounded, so animations take the short way round. */
  const angleMV = useMotionValue(300);
  const angleTarget = useRef(300);
  const morphMV = useMotionValue(0);
  const liftMV = useMotionValue(0);
  const dragging = useRef(false);
  const touching = useRef(false);
  const step = useRef(0);

  const swing = (to: number, t: Transition) => {
    angleTarget.current += shortest(angleTarget.current, to);
    animate(angleMV, angleTarget.current, t);
  };
  const restAngle = () => (modeRef.current === "hour" ? (hourRef.current % 12) * 30 : minuteRef.current * 6);

  /** Finger or script: read the value at `theta` and swing the hand there, pulled toward the nearest detent. */
  const point = (theta: number, t: Transition, silent: boolean) => {
    const hourMode = modeRef.current === "hour";
    const unit = hourMode ? 30 : 6;
    const pull = hourMode ? 0.65 : 0.5;
    const snapped = Math.round(theta / unit) * unit;
    const shown = theta + (snapped - theta) * pull;
    if (hourMode) {
      const index = Math.round(snapped / 30) % 12;
      const value = index === 0 ? 12 : index;
      if (value !== hourRef.current) {
        setHour(value);
        if (!silent) haptics.selection();
      }
    } else {
      const value = Math.round(snapped / 6) % 60;
      if (value !== minuteRef.current) {
        setMinute(value);
        if (!silent) haptics.selection();
      }
    }
    swing(shown, t);
  };

  const setMode = (target: Mode) => {
    if (target === modeRef.current) return;
    setModeState(target);
    const t = spring(ctx.n("sweep"), 0.78);
    swing(restAngle(), t);
    animate(morphMV, target === "minute" ? 1 : 0, t);
  };

  /** Finger lifted, gesture cancelled, or the script letting go. */
  const release = (silent: boolean) => {
    if (!dragging.current) return;
    if (!silent) haptics.tap("light");
    dragging.current = false;
    const t = spring(0.3, 0.6);
    animate(liftMV, 0, t);
    swing(restAngle(), t);
    if (modeRef.current !== "hour" || !ctx.b("auto")) return;
    advanceTask.start(async (sleep) => {
      if (!(await sleep(0.35))) return;
      setMode("minute");
    });
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ location }) => {
      const dx = location.x - DIAL / 2;
      const dy = location.y - DIAL / 2;
      if (Math.hypot(dx, dy) <= 14) return;
      advanceTask.cancel();
      if (!dragging.current) {
        dragging.current = true;
        animate(liftMV, 1, spring(0.25, 0.7));
      }
      let theta = (Math.atan2(dx, -dy) * 180) / Math.PI;
      if (theta < 0) theta += 360;
      point(theta, spring(0.14, 0.85), false);
    },
    onEnd: () => {
      touching.current = false;
      release(false);
    },
  });

  const scriptDrag = (theta: number, silent: boolean) => {
    dragging.current = true;
    animate(liftMV, 1, spring(0.25, 0.7));
    point(theta, anim.smoothD(0.6), silent);
    scriptTask.start(async (sleep) => {
      if (!(await sleep(0.7)) || touching.current) return;
      release(silent);
    });
  };

  const previewTick = () => {
    const silent = quiet();
    const phase = step.current % 3;
    const round = Math.floor(step.current / 3);
    step.current += 1;
    if (phase === 0) {
      if (modeRef.current !== "hour") setMode("hour");
      scriptDrag([210, 60, 330][round % 3], silent);
    } else if (phase === 1) {
      if (modeRef.current !== "minute") setMode("minute");
      scriptDrag([270, 48, 162][round % 3], silent);
    } else {
      // The detail intro only plays the first drag; previews go back to hours for the next round.
      setMode("hour");
    }
  };
  useAutoplay(ctx.isPreview, wrap(previewTick), { every: 1.5, delay: 0.4 });

  const segment = (text: string, value: number, active: boolean, action: () => void) => (
    <motion.button
      type="button"
      onClick={() => {
        advanceTask.cancel();
        action();
      }}
      initial={false}
      animate={{ scale: active ? 1 : 0.94, backgroundColor: active ? alpha(Palette.indigo, 0.16) : "rgb(128 128 128 / 0.1)" }}
      transition={spring(0.35, 0.7)}
      style={{
        width: 78,
        height: 52,
        borderRadius: 15,
        display: "grid",
        placeItems: "center",
        fontFamily: fonts.rounded,
        fontSize: 38,
        fontWeight: 700,
        lineHeight: "46px",
        color: active ? Palette.indigo : Palette.labelAlpha(0.55),
        transition: "color 0.25s",
      }}
    >
      <NumericText value={value} text={text} />
    </motion.button>
  );

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 10, flexShrink: 0, transform: ctx.isPreview ? "scale(1.04)" : undefined }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          {segment(String(hour), hour, mode === "hour", () => setMode("hour"))}
          <span style={{ fontFamily: fonts.rounded, fontSize: 34, fontWeight: 700, lineHeight: "41px", color: Palette.secondaryLabel, transform: "translateY(-2px)" }}>:</span>
          {segment(String(minute).padStart(2, "0"), minute, mode === "minute", () => setMode("minute"))}
        </div>
        <div {...pan} style={{ ...pan.style, width: DIAL, height: DIAL, borderRadius: "50%", cursor: "grab" }}>
          <Face angleMV={angleMV} morphMV={morphMV} liftMV={liftMV} magnify={ctx.n("magnify")} spread={ctx.n("stagger")} />
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Drag the hand; tap the hour or minutes to switch" zh="拖动指针；点击小时或分钟切换" style={{ paddingBottom: 12 }} />
    </div>
  );
}

type MV = ReturnType<typeof useMotionValue<number>>;

/** Dial, numerals, hand: re-derived from (angle, morph) every frame so magnification and the ring morph track the springs. */
function Face({ angleMV, morphMV, liftMV, magnify, spread }: { angleMV: MV; morphMV: MV; liftMV: MV; magnify: number; spread: number }) {
  const angle = useMV(angleMV);
  const morph = useMV(morphMV);
  const lift = useMV(liftMV);
  const clipId = `c-clock-${useId().replace(/:/g, "")}`;
  const clamped = clamp(morph);
  // How far the hand is from a five-minute mark (0 on a numeral, 1 half-way between two).
  const offGrid = Math.abs(Math.round(angle / 30) * 30 - angle) / 15;
  const dot = clamped * clamp((offGrid - 0.25) * 2.5);
  const c = DIAL / 2;
  const rad = (angle * Math.PI) / 180;
  const sel = { x: c + RADIUS * Math.sin(rad), y: c - RADIUS * Math.cos(rad), r: (DISC / 2) * mix(1, 1.12, lift) };
  const liftC = clamp(lift);

  const distance = (position: number) => {
    let delta = (angle - position) % 360;
    if (delta < 0) delta += 360;
    return delta > 180 ? 360 - delta : delta;
  };

  const numerals = (color: string) =>
    Array.from({ length: 12 }, (_, index) => {
      const position = index * 30;
      const apart = distance(position);
      const near = Math.max(0, 1 - apart / 60);
      const grow = 1 + magnify * near * near * (3 - 2 * near);
      // The morph starts at the hand and reaches the far side last.
      const local = clamp(clamped * (1 + spread) - (spread * apart) / 180);
      const radians = (position * Math.PI) / 180;
      const hourRadius = RADIUS - 22 * local;
      const minuteRadius = RADIUS + 22 * (1 - local);
      const text = (label: string, r: number, scale: number, opacity: number) =>
        opacity <= 0.001 ? null : (
          <text
            key={label + (r === hourRadius ? "h" : "m")}
            transform={`translate(${c + r * Math.sin(radians)} ${c - r * Math.cos(radians)}) scale(${scale})`}
            opacity={opacity}
            fill={color}
            textAnchor="middle"
            dominantBaseline="central"
          >
            {label}
          </text>
        );
      return (
        <g key={index}>
          {text(index === 0 ? "12" : String(index), hourRadius, grow * (1 - 0.4 * local), 1 - local)}
          {text(String(index * 5).padStart(2, "0"), minuteRadius, grow * (0.6 + 0.4 * local), local)}
        </g>
      );
    });

  const svgStyle = {
    position: "absolute",
    inset: 0,
    overflow: "visible",
    fontFamily: fonts.rounded,
    fontSize: 17,
    fontWeight: 600,
    fontVariantNumeric: "tabular-nums",
    pointerEvents: "none",
  } as const;
  const handLength = RADIUS - DISC / 2 + 2;

  return (
    <div style={{ position: "relative", width: DIAL, height: DIAL, borderRadius: "50%", background: Palette.labelAlpha(0.06), boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.06)}` }}>
      <svg width={DIAL} height={DIAL} style={svgStyle}>
        <g opacity={clamped} style={{ color: Palette.label }}>
          {Array.from({ length: 60 }, (_, i) =>
            i % 5 === 0 ? null : (
              <circle key={i} cx={c + RADIUS * Math.sin((i * 6 * Math.PI) / 180)} cy={c - RADIUS * Math.cos((i * 6 * Math.PI) / 180)} r={1.25} fill="currentColor" opacity={0.22} />
            ),
          )}
        </g>
        {numerals(Palette.label)}
      </svg>
      {/* hand */}
      <div
        style={{
          position: "absolute",
          left: c - 1.25,
          top: c - handLength,
          width: 2.5,
          height: handLength,
          borderRadius: 1.25,
          background: Palette.indigo,
          transformOrigin: "50% 100%",
          transform: `rotate(${angle}deg)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: sel.x - sel.r,
          top: sel.y - sel.r,
          width: sel.r * 2,
          height: sel.r * 2,
          borderRadius: "50%",
          background: `linear-gradient(${angle + 180}deg, ${Palette.indigo}, ${Palette.violet})`,
          boxShadow: `0 4px ${mix(9, 18, liftC)}px ${alpha(Palette.indigo, mix(0.3, 0.55, liftC))}`,
        }}
      />
      <svg width={DIAL} height={DIAL} style={{ ...svgStyle, opacity: 1 - dot }}>
        <defs>
          <clipPath id={clipId}>
            <circle cx={sel.x} cy={sel.y} r={sel.r} />
          </clipPath>
        </defs>
        <g clipPath={`url(#${clipId})`}>{numerals("#fff")}</g>
      </svg>
      <div style={{ position: "absolute", left: sel.x - 3, top: sel.y - 3, width: 6, height: 6, borderRadius: "50%", background: "#fff", opacity: dot }} />
      <div style={{ position: "absolute", left: c - 4, top: c - 4, width: 8, height: 8, borderRadius: "50%", background: Palette.indigo }} />
    </div>
  );
}
