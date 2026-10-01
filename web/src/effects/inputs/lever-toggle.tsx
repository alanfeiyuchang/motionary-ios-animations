/** inputs.lever-toggle (Inputs+LeverToggle.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { GradientBorder, adaptive, column, gray, hexColor, spacer, useLive, useMV, useQuiet } from "./_c-common";

const PLATE = { w: 190, h: 250 };
const RESPONSE = 0.26;
const LENGTH = 86;

export default function LeverToggle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const { wrap, quiet } = useQuiet();
  const [, setIsOn, isOnRef] = useLive(false);
  /** Throw: 0 = off (down), 1 = on (up). The spring may overshoot; the arm folds that back. */
  const throwMV = useMotionValue(0);
  const lampMV = useMotionValue(0);
  const kick = useMotionValue(0);
  const dragBase = useRef<number | null>(null);
  const snapped = useRef(false);
  const clickTask = useRef<(() => void) | null>(null);
  const throwValue = useMV(throwMV);
  const lamp = clamp(useMV(lampMV));

  const lampHex = [0xffb02e, 0x3ddc84, 0xff4d5e][ctx.i("lamp")] ?? 0xffb02e;

  /** The one throw used by tap, over-centre drag and autoplay. */
  const throwLever = (target: boolean) => {
    setIsOn(target);
    animate(throwMV, target ? 1 : 0, spring(RESPONSE, ctx.n("bounce")));
    clickTask.current?.();
    const silent = quiet();
    const warm = ctx.n("warm");
    // The spring first reaches the stop a little before half its response.
    clickTask.current = after(RESPONSE * 0.42, () => {
      if (!silent) haptics.tap("rigid");
      animate(kick, target ? -2 : 2, anim.easeOut(0.05));
      if (target) animate(lampMV, 1, anim.curve(0.35, 0, 0.2, 1, warm));
      else animate(lampMV, 0, anim.easeOut(warm * 1.4));
      clickTask.current = after(0.05, () => animate(kick, 0, spring(0.25, 0.4)));
    });
  };

  const pan = usePan({
    onStart: () => {
      dragBase.current = isOnRef.current ? 1 : 0;
      snapped.current = false;
    },
    onChange: ({ translation }) => {
      const base = dragBase.current;
      if (snapped.current || base === null) return;
      const raw = base - translation.y / 106;
      const crossed = base > 0.5 ? raw < 0.5 : raw > 0.5;
      if (crossed) {
        // Over-centre: the lever takes over and throws itself to the far stop.
        snapped.current = true;
        throwLever(!isOnRef.current);
      } else {
        clickTask.current?.();
        animate(throwMV, clamp(raw), spring(0.12, 0.9));
      }
    },
    onEnd: ({ translation }) => {
      if (dragBase.current === null) return;
      dragBase.current = null;
      if (snapped.current) return;
      if (Math.hypot(translation.x, translation.y) < 6) throwLever(!isOnRef.current);
      // Let go before centre: the spring pulls it back to its own stop.
      else animate(throwMV, isOnRef.current ? 1 : 0, spring(0.2, 0.55));
    },
  });

  useAutoplay(ctx.isPreview, wrap(() => throwLever(!isOnRef.current)), { every: 1.8, delay: 0.5 });

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ transform: ctx.isPreview ? "scale(1.08)" : undefined, flexShrink: 0 }}>
        <motion.div
          {...pan}
          style={{
            ...pan.style,
            position: "relative",
            width: PLATE.w,
            height: PLATE.h,
            borderRadius: 28,
            y: kick,
            background: `linear-gradient(180deg, ${adaptive(ctx.scheme, 0xfafbfd, 0x3c3d45)}, ${adaptive(ctx.scheme, 0xd5d8e0, 0x222328)})`,
            boxShadow: `0 12px 27px ${black(0.22)}`,
            cursor: "pointer",
          }}
        >
          <GradientBorder background={`linear-gradient(180deg, ${white(0.7)}, ${black(0.18)})`} width={1} radius={28} />
          {/* screws */}
          {[0, 1, 2, 3].map((index) => {
            const sx = index % 2 === 0 ? -1 : 1;
            const sy = index < 2 ? -1 : 1;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: PLATE.w / 2 + sx * (PLATE.w / 2 - 20) - 5.5,
                  top: PLATE.h / 2 + sy * (PLATE.h / 2 - 20) - 5.5,
                  width: 11,
                  height: 11,
                  borderRadius: "50%",
                  background: `linear-gradient(180deg, ${white(0.9)}, ${gray(0.55)})`,
                  boxShadow: `0 1px 1.5px ${black(0.3)}`,
                  display: "grid",
                  placeItems: "center",
                }}
              >
                <div style={{ width: 7, height: 1.5, borderRadius: 1, background: black(0.45), transform: `rotate(${index * 37 + 20}deg)` }} />
              </div>
            );
          })}
          <div style={{ position: "absolute", left: PLATE.w / 2, top: PLATE.h / 2 - 92 }}>
            <Lamp level={lamp} color={lampHex} />
          </div>
          {/* marks */}
          <div style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 800, letterSpacing: 1.5, lineHeight: "14px" }}>
            <Mark x={-56} y={-26}>
              <span style={{ color: hexColor(lampHex, 0.35 + 0.65 * lamp), textShadow: `0 0 9px ${hexColor(lampHex, 0.7 * lamp)}` }}>ON</span>
            </Mark>
            <Mark x={-56} y={78}>
              <span style={{ color: Palette.labelAlpha(0.4 - 0.15 * lamp) }}>OFF</span>
            </Mark>
          </div>
          <div style={{ position: "absolute", left: PLATE.w / 2, top: PLATE.h / 2 + 26 }}>
            <Arm throwValue={throwValue} maxAngle={ctx.n("angle")} />
          </div>
        </motion.div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap, or drag the lever past centre" zh="点击，或把拨杆拖过中点" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function Mark({ x, y, children }: { x: number; y: number; children: React.ReactNode }) {
  return (
    <div style={{ position: "absolute", left: PLATE.w / 2 + x, top: PLATE.h / 2 + y, transform: "translate(-50%, -50%)", whiteSpace: "nowrap", pointerEvents: "none" }}>
      {children}
    </div>
  );
}

/** A circle (or any box) centred on the parent's origin, offset by (x, y). */
const centred = (w: number, h: number, x = 0, y = 0) => ({ position: "absolute", left: x - w / 2, top: y - h / 2, width: w, height: h }) as const;

/** Lever seen head-on; every frame of the spring re-derives the projection. Drawn around its pivot (0, 0). */
function Arm({ throwValue, maxAngle }: { throwValue: number; maxAngle: number }) {
  // Fold the spring's overshoot back: the lever cannot pass its stop, it bounces off it.
  const folded = throwValue > 1 ? 1 - (throwValue - 1) * 0.7 : throwValue < 0 ? -throwValue * 0.7 : throwValue;
  const limit = (maxAngle * Math.PI) / 180;
  const phi = (1 - 2 * folded) * limit;
  const tipY = LENGTH * Math.sin(phi);
  const height = LENGTH * Math.cos(phi);
  const near = (Math.cos(phi) - Math.cos(limit)) / Math.max(1 - Math.cos(limit), 0.001);
  const ball = 38 * (1 + 0.14 * near);
  const slot = LENGTH * Math.sin(limit);
  const shadow = { w: height * 0.2, h: height * 0.26 };
  const rod = (tx: number, ty: number, base: number, tip: number) => `M${-base / 2} 0 L${base / 2} 0 L${tx + tip / 2} ${ty} L${tx - tip / 2} ${ty} Z`;
  const slotH = slot * 2 + 34;

  return (
    <div style={{ position: "absolute", left: 0, top: 0, pointerEvents: "none" }}>
      {/* Recessed slot the lever travels in. */}
      <div style={{ ...centred(30, slotH), borderRadius: 15, background: `linear-gradient(180deg, ${gray(0.05)}, ${gray(0.22)})` }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 15, border: `1px solid ${white(0.25)}`, mixBlendMode: "plus-lighter" }} />
      </div>
      {/* Cast shadow: longest when the lever stands straight out of the plate. */}
      <svg width={1} height={1} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", filter: `blur(${5 + near * 3}px)` }}>
        <path d={rod(shadow.w, tipY + shadow.h, 20, 22)} fill={black(0.32)} />
      </svg>
      <div style={{ ...centred(ball, ball, shadow.w, tipY + shadow.h), borderRadius: "50%", background: black(0.3), filter: `blur(${6 + near * 3}px)` }} />
      {/* Collar nut. */}
      <div
        style={{
          ...centred(44, 44),
          borderRadius: "50%",
          background: `conic-gradient(from 90deg, ${gray(0.95)}, ${gray(0.5)}, ${gray(0.85)}, ${gray(0.4)}, ${gray(0.95)})`,
          display: "grid",
          placeItems: "center",
        }}
      >
        <div style={{ width: 24, height: 24, borderRadius: "50%", background: gray(0.12) }} />
      </div>
      <svg width={1} height={1} style={{ position: "absolute", left: 0, top: 0, overflow: "visible" }}>
        <defs>
          <linearGradient id="c-lever-rod" gradientUnits="userSpaceOnUse" x1={-10} y1={0} x2={10} y2={0}>
            <stop offset="0" stopColor="#7C8089" />
            <stop offset="0.333" stopColor="#F6F8FB" />
            <stop offset="0.667" stopColor="#B4B8C1" />
            <stop offset="1" stopColor="#62666F" />
          </linearGradient>
        </defs>
        <path d={rod(0, tipY, 19, 15)} fill="url(#c-lever-rod)" />
      </svg>
      <div
        style={{
          ...centred(ball, ball, 0, tipY),
          borderRadius: "50%",
          background: `radial-gradient(circle ${ball * 0.72}px at 36% ${(0.3 + 0.12 * (phi / Math.max(limit, 0.001))) * 100}%, #fff 1px, #D4D8E0 50%, #7B7F89 100%)`,
          boxShadow: `inset 0 0 0 0.5px ${black(0.25)}`,
        }}
      />
    </div>
  );
}

/** Jewel pilot lamp: dark glass at 0, glowing at 1. Drawn around its centre. */
function Lamp({ level, color }: { level: number; color: number }) {
  return (
    <div style={{ position: "absolute", left: 0, top: 0, pointerEvents: "none" }}>
      <div style={{ ...centred(70, 70), borderRadius: "50%", background: hexColor(color), filter: "blur(22px)", opacity: level * 0.75 }} />
      <div style={{ ...centred(30, 30), borderRadius: "50%", background: `linear-gradient(180deg, ${gray(0.95)}, ${gray(0.45)})` }} />
      <div style={{ ...centred(22, 22), borderRadius: "50%", background: gray(0.1) }} />
      <div style={{ ...centred(22, 22), borderRadius: "50%", background: hexColor(color, 0.22 + 0.78 * level) }} />
      <div style={{ ...centred(22, 22), borderRadius: "50%", background: `radial-gradient(circle 8px at 50% 50%, #fff, ${white(0)})`, opacity: level * 0.85 }} />
      <div style={{ ...centred(6, 4, -4, -5), borderRadius: "50%", background: white(0.5) }} />
    </div>
  );
}
