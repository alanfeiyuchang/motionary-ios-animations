/** inputs.color-wheel (Inputs+ColorWheel.swift) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { column, hsb, hsbCss, spacer, useMV, useTask } from "./_c-common";

const DISC = 176;
const RING_RADIUS = 108;
const RING_WIDTH = 12;
const SIDE = 240;
const ARC_START = 135;
const ARC_SWEEP = 270;
const SCRIPT: [number, number, number][] = [[0.9, 0.86, 1], [2.7, 0.55, 0.72], [4.3, 0.9, 1], [5.5, 0.42, 0.9]];
const HUES = Array.from({ length: 13 }, (_, i) => hsbCss(i / 12, 1, 1)).join(", ");

export default function ColorWheel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** Radians, unwrapped so animation takes the short way round. */
  const angleMV = useMotionValue(-0.75);
  const angleTarget = useRef(-0.75);
  const radiusMV = useMotionValue(0.78);
  const brightnessMV = useMotionValue(1);
  const loupeMV = useMotionValue(0);
  const loupeTarget = useRef(0);
  const mode = useRef<"wheel" | "ring" | null>(null);
  const touching = useRef(false);
  const step = useRef(0);
  const playTask = useTask();

  /** Finger and autoplay both land here: move the thumb in polar space. */
  const pick = (theta: number, target: number, animated: boolean) => {
    // Unwrap to the equivalent angle nearest the current one.
    let delta = (theta - angleTarget.current) % (2 * Math.PI);
    if (delta > Math.PI) delta -= 2 * Math.PI;
    if (delta < -Math.PI) delta += 2 * Math.PI;
    const t = animated ? spring(ctx.n("travel"), 0.82) : spring(0.12, 0.9);
    angleTarget.current += delta;
    animate(angleMV, angleTarget.current, t);
    animate(radiusMV, target, t);
  };
  const setBrightness = (dx: number, dy: number, animated: boolean) => {
    let degrees = (Math.atan2(dy, dx) * 180) / Math.PI;
    if (degrees < 0) degrees += 360;
    if (degrees < 90) degrees += 360;
    const value = clamp((degrees - ARC_START) / ARC_SWEEP);
    animate(brightnessMV, Math.max(value, 0.12), animated ? spring(0.35, 0.8) : spring(0.12, 0.9));
  };
  const liftLoupe = () => {
    loupeTarget.current = 1;
    animate(loupeMV, 1, spring(0.3, 0.6));
  };
  const dropLoupe = () => {
    loupeTarget.current = 0;
    animate(loupeMV, 0, spring(0.4, 0.55));
  };
  const release = () => {
    if (mode.current === null && loupeTarget.current === 0) return;
    if (mode.current !== null) haptics.tap("soft");
    mode.current = null;
    dropLoupe();
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ location }) => {
      const dx = location.x - SIDE / 2;
      const dy = location.y - (SIDE + 12) / 2;
      const distance = Math.hypot(dx, dy);
      const first = mode.current === null;
      if (first) {
        playTask.cancel();
        mode.current = distance > DISC / 2 + 8 ? "ring" : "wheel";
        haptics.tap("light");
      }
      if (mode.current === "ring") setBrightness(dx, dy, first);
      else {
        pick(Math.atan2(dy, dx), Math.min(distance / (DISC / 2), 1), first);
        if (first) liftLoupe();
      }
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
      const target = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      playTask.start(async (sleep) => {
        liftLoupe();
        pick(target[0], target[1], true);
        animate(brightnessMV, target[2], anim.smoothD(0.6));
        if (!(await sleep(0.95))) return;
        dropLoupe();
      });
    },
    { every: 1.5, delay: 0.5 },
  );

  // Everything that depends on the picked colour re-derives per frame, so a polar move re-tints along its arc.
  const angle = useMV(angleMV);
  const radius = useMV(radiusMV);
  const brightness = useMV(brightnessMV);
  const loupe = useMV(loupeMV);
  const turns = angle / (2 * Math.PI);
  const hue = turns - Math.floor(turns);
  const saturation = clamp(radius);
  const value = clamp(brightness);
  const picked = hsbCss(hue, saturation, value);
  const rgb = hsb(hue, saturation, value);
  const hexCode = "#" + rgb.map((c) => clamp(Math.round(c * 255), 0, 255).toString(16).padStart(2, "0").toUpperCase()).join("");
  const reach = (DISC / 2) * saturation;
  const point = { x: Math.cos(angle) * reach, y: Math.sin(angle) * reach };
  const lift = ctx.n("lift");
  const size = Math.max(26 + (ctx.n("loupe") - 26) * loupe, 8);
  const cx = SIDE / 2;
  const cy = (SIDE + 12) / 2;
  const at = (x: number, y: number, w: number, h = w) => ({ position: "absolute", left: cx + x - w / 2, top: cy + y - h / 2, width: w, height: h }) as const;

  const dark = hsb(hue, saturation, 0.1);
  const full = hsb(hue, saturation, 1);
  const arcPoint = (deg: number) => [cx + RING_RADIUS * Math.cos((deg * Math.PI) / 180), cy + RING_RADIUS * Math.sin((deg * Math.PI) / 180)];
  const segments = 54;
  const knobAngle = ((ARC_START + ARC_SWEEP * value) * Math.PI) / 180;
  const mixRGB = (t: number) => `rgb(${dark.map((d, i) => Math.round((d + (full[i] - d) * t) * 255)).join(" ")})`;
  const [sx, sy] = arcPoint(ARC_START);
  const [ex, ey] = arcPoint(ARC_START + ARC_SWEEP);
  const l = Math.max(loupe, 0);

  return (
    <div style={column}>
      <div style={spacer} />
      <div {...pan} style={{ ...pan.style, position: "relative", width: SIDE, height: SIDE + 12, flexShrink: 0, cursor: "crosshair" }}>
        {/* wheel */}
        <div style={{ ...at(0, 0, DISC), borderRadius: "50%", background: `radial-gradient(circle, #fff, ${white(0)} 70.7%), conic-gradient(from 90deg, ${HUES})`, boxShadow: `0 8px 21px ${black(0.18)}` }} />
        <div style={{ ...at(0, 0, DISC), borderRadius: "50%", background: black((1 - value) * 0.82) }} />
        {/* brightness ring */}
        <svg width={SIDE} height={SIDE + 12} style={{ position: "absolute", inset: 0, overflow: "visible" }} fill="none">
          <path d={`M${sx} ${sy} A${RING_RADIUS} ${RING_RADIUS} 0 1 1 ${ex} ${ey}`} stroke={Palette.labelAlpha(0.14)} strokeWidth={RING_WIDTH + 3} strokeLinecap="round" />
          {Array.from({ length: segments }, (_, i) => {
            const a0 = ARC_START + (ARC_SWEEP * i) / segments;
            const a1 = ARC_START + Math.min(ARC_SWEEP, (ARC_SWEEP * (i + 1)) / segments + 0.5);
            const [x0, y0] = arcPoint(a0);
            const [x1, y1] = arcPoint(a1);
            return <path key={i} d={`M${x0} ${y0} A${RING_RADIUS} ${RING_RADIUS} 0 0 1 ${x1} ${y1}`} stroke={mixRGB((i + 0.5) / segments)} strokeWidth={RING_WIDTH} />;
          })}
          <circle cx={sx} cy={sy} r={RING_WIDTH / 2} fill={mixRGB(0)} />
          <circle cx={ex} cy={ey} r={RING_WIDTH / 2} fill={mixRGB(1)} />
        </svg>
        <div
          style={{
            ...at(Math.cos(knobAngle) * RING_RADIUS, Math.sin(knobAngle) * RING_RADIUS, 22),
            borderRadius: "50%",
            background: picked,
            border: "3px solid #fff",
            boxShadow: `0 2px 6px ${black(0.3)}`,
          }}
        />
        {/* swatch */}
        <div style={{ position: "absolute", left: 0, right: 0, top: cy + RING_RADIUS + 4 - 15, display: "flex", justifyContent: "center" }}>
          <div
            style={{
              height: 30,
              padding: "0 10px",
              borderRadius: 15,
              background: Palette.elevated,
              boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.1)}, 0 3px 9px ${black(0.1)}`,
              display: "flex",
              alignItems: "center",
              gap: 7,
            }}
          >
            <div style={{ width: 16, height: 16, borderRadius: "50%", background: picked, boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.15)}` }} />
            <span style={{ fontFamily: fonts.mono, fontSize: 13, fontWeight: 600 }}>{hexCode}</span>
          </div>
        </div>
        <div style={{ ...at(point.x, point.y, 10), borderRadius: "50%", border: "2px solid #fff", boxShadow: `0 0 3px ${black(0.4)}`, opacity: clamp(loupe) }} />
        <div
          style={{
            ...at(point.x, point.y - lift * loupe, size),
            borderRadius: "50%",
            background: picked,
            border: "3px solid #fff",
            boxShadow: `0 ${2 + 6 * l}px ${(4 + 8 * l) * 1.5}px ${black(0.28)}`,
          }}
        />
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Drag on the wheel or the outer ring" zh="在色轮或外圈上拖动" style={{ paddingBottom: 14 }} />
    </div>
  );
}
