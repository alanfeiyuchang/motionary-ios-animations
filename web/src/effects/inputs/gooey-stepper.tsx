/** inputs.gooey-stepper (Inputs+GooeyStepper.swift) */
import { animate, useMotionValue } from "motion/react";
import { useId, useRef, useState } from "react";
import { Minus, Plus } from "lucide-react";
import { DemoHint, NumericText, Palette, alpha, anim, clamp, fonts, mix, spring, springAt, useAutoplay, useElapsed, useHaptics, useSilently, white, type DemoProps } from "../../kit";
import { column, spacer, useLive, useMV, useTask } from "./_c-common";

const TRACK = { w: 232, h: 64 };
const SCRIPT = [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, -1, -1, -1, -1, -1, -1, 0, 0, 0, 0];

export default function GooeyStepper({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const silently = useSilently();
  const [value, setValue, valueRef] = useLive(3);
  /** −1…1: how far the satellite drop is thrown, toward minus or plus. */
  const pullMV = useMotionValue(0);
  const momentumMV = useMotionValue(0);
  const momentumTarget = useRef(0);
  const [kicks, setKicks] = useState([0, 0]);
  const step = useRef(0);
  const recoil = useTask();
  const drain = useTask();
  const burst = useTask();

  /** One tap, real or simulated: throw the drop, change the value, feed momentum. */
  const press = (direction: number) => {
    const momentum = momentumTarget.current;
    const next = valueRef.current + direction;
    const blocked = next < 0 || next > 99;
    const gained = blocked ? momentum : Math.min(momentum + ctx.n("gain"), 1);
    // The throw uses the momentum built up before this tap: 55% of the way from rest, all the way at full.
    const amplitude = blocked ? 0.3 : 0.55 + 0.45 * momentum;
    setKicks((k) => (direction < 0 ? [k[0] + 1, k[1]] : [k[0], k[1] + 1]));
    if (blocked) haptics.tap("rigid");
    else {
      setValue(next);
      haptics.tap(gained >= 1 ? "medium" : "light");
    }
    animate(pullMV, direction * amplitude, anim.easeOut(0.13));
    momentumTarget.current = gained;
    animate(momentumMV, gained, spring(0.35, 0.7));
    recoil.start(async (sleep) => {
      if (!(await sleep(0.12))) return;
      const damping = Math.max(ctx.n("wobble") - 0.15 * gained, 0.2);
      animate(pullMV, 0, spring(0.42, damping));
    });
    drain.start(async (sleep) => {
      if (!(await sleep(0.7))) return;
      momentumTarget.current = 0;
      animate(momentumMV, 0, anim.easeOut(0.6));
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      if (ctx.isPreview) {
        const direction = SCRIPT[step.current % SCRIPT.length];
        step.current += 1;
        if (direction !== 0) press(direction);
      } else {
        // Detail arrival: a quick run of four taps, so the momentum is visible straight away.
        burst.start(async (sleep) => {
          for (let i = 0; i < 4; i++) {
            silently(() => press(1));
            if (!(await sleep(0.26))) return;
          }
        });
      }
    },
    { every: 0.3, delay: 0.5 },
  );

  const pull = useMV(pullMV);
  const momentum = useMV(momentumMV);
  const lit = Math.round(momentum * 5);
  const centre = { position: "absolute", left: "50%", top: "50%" } as const;

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", width: 300, height: 130, flexShrink: 0 }}>
        <div
          style={{
            ...centre,
            width: 90,
            height: 90,
            margin: -45,
            borderRadius: "50%",
            background: Palette.violet,
            filter: "blur(24px)",
            opacity: clamp(momentum) * 0.45,
            transform: `translateY(12px) scale(${1 + momentum * 0.35})`,
          }}
        />
        <div
          style={{
            ...centre,
            width: TRACK.w,
            height: TRACK.h,
            marginLeft: -TRACK.w / 2,
            marginTop: -TRACK.h / 2,
            borderRadius: TRACK.h / 2,
            background: Palette.labelAlpha(0.07),
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
          }}
        />
        <Glyph x={-TRACK.w / 2 + 34} kick={kicks[0]}>
          <Minus size={24} strokeWidth={3.2} />
        </Glyph>
        <Glyph x={TRACK.w / 2 - 34} kick={kicks[1]}>
          <Plus size={24} strokeWidth={3.2} />
        </Glyph>
        <Blob pull={pull} momentum={momentum} reach={(TRACK.w / 2 - 34) * ctx.n("reach")} goo={ctx.n("goo")} />
        {/* Wet highlight riding on the blob. */}
        <div
          style={{
            ...centre,
            width: 44,
            height: 22,
            marginLeft: -22,
            marginTop: -11,
            borderRadius: "50%",
            background: `linear-gradient(180deg, ${white(0.5)}, ${white(0)})`,
            filter: "blur(3px)",
            transformOrigin: `${22 - (pull * 9 - 4)}px ${11 + 22}px`,
            transform: `translate(${pull * 9 - 4}px, -22px) scale(${1 + momentum * 0.1})`,
            pointerEvents: "none",
          }}
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "grid",
            placeItems: "center",
            transform: `translateX(${pull * 9}px)`,
            fontFamily: fonts.rounded,
            fontSize: 30,
            fontWeight: 800,
            color: "#fff",
            pointerEvents: "none",
          }}
        >
          <NumericText value={value} />
        </div>
        <div style={{ ...centre, width: TRACK.w + 24, height: 96, marginLeft: -(TRACK.w + 24) / 2, marginTop: -48, display: "flex" }}>
          <div style={{ flex: 1, cursor: "pointer" }} onClick={() => press(-1)} />
          <div style={{ flex: 1, cursor: "pointer" }} onClick={() => press(1)} />
        </div>
      </div>
      {/* meter */}
      <div style={{ display: "flex", gap: 7, paddingTop: 26, flexShrink: 0 }}>
        {[0, 1, 2, 3, 4].map((index) => (
          <div
            key={index}
            style={{
              width: 7,
              height: 7,
              borderRadius: "50%",
              background: index < lit ? Palette.violet : Palette.labelAlpha(0.12),
              transform: `scale(${index < lit ? 1.25 : 1})`,
              transition: "transform 0.3s cubic-bezier(0.3, 1.6, 0.5, 1), background-color 0.2s",
            }}
          />
        ))}
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap + or − quickly, several times" zh="快速连续点击 + 或 −" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function Glyph({ x, kick, children }: { x: number; kick: number; children: React.ReactNode }) {
  const t = useElapsed(kick, 0.55, true);
  let scale = 1;
  if (t >= 0) {
    const smooth = (p: number) => p * p * (3 - 2 * p);
    if (t < 0.08) scale = mix(1, 0.8, smooth(t / 0.08));
    else if (t < 0.18) scale = mix(0.8, 1.35, smooth((t - 0.08) / 0.1));
    else scale = mix(1.35, 1, springAt(t - 0.18, 0.35, 0.7));
  }
  return (
    <div
      style={{
        position: "absolute",
        left: "50%",
        top: "50%",
        width: 44,
        height: 44,
        marginLeft: -22 + x,
        marginTop: -22,
        display: "grid",
        placeItems: "center",
        color: Palette.secondaryLabel,
        transform: `scale(${scale})`,
      }}
    >
      {children}
    </div>
  );
}

/** The metaball layer: three discs blurred and thresholded into one gooey shape, filled with the gradient. */
function Blob({ pull, momentum, reach, goo }: { pull: number; momentum: number; reach: number; goo: number }) {
  const id = `c-goo-${useId().replace(/:/g, "")}`;
  const swell = 1 + 0.1 * clamp(momentum);
  const mid = { x: 150, y: 65 };
  // The blob leans into the throw and flattens a little, then the drop leaves it.
  const width = 80 * swell * (1 + 0.1 * Math.abs(pull));
  const height = 80 * swell * (1 - 0.07 * Math.abs(pull));
  return (
    <svg width={300} height={130} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none", filter: `drop-shadow(0 6px 10px ${alpha(Palette.indigo, 0.35)})` }}>
      <defs>
        <filter id={`${id}-f`} x="-20%" y="-40%" width="140%" height="180%" colorInterpolationFilters="sRGB">
          <feGaussianBlur stdDeviation={goo / 2} />
          <feColorMatrix type="matrix" values="1 0 0 0 1  0 1 0 0 1  0 0 1 0 1  0 0 0 24 -11.5" />
        </filter>
        <mask id={`${id}-m`} maskUnits="userSpaceOnUse" x={0} y={0} width={300} height={130}>
          <g filter={`url(#${id}-f)`} fill="#fff">
            <ellipse cx={mid.x + pull * 8} cy={mid.y} rx={width / 2} ry={height / 2} />
            <circle cx={mid.x + pull * reach} cy={mid.y} r={23} />
            {/* A bead half-way keeps the neck from pinching off too early. */}
            <circle cx={mid.x + pull * reach * 0.55} cy={mid.y} r={15} />
          </g>
        </mask>
        <linearGradient id={`${id}-g`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={Palette.indigo} />
          <stop offset="1" stopColor={Palette.violet} />
        </linearGradient>
      </defs>
      <rect width={300} height={130} fill={`url(#${id}-g)`} mask={`url(#${id}-m)`} />
    </svg>
  );
}
