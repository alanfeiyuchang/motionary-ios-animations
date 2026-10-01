/** text.focus-pull · 景深移焦 (Text+FocusPull.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, fonts, spring, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { GradientText } from "./_text-kit";
import { useMV } from "./_fx";

/** Near, middle, far. */
const DEPTHS = [0, 0.5, 1];
const TOUR = [0, 1, 2, 1];
const RULER = 250;
const LIGHTS: { x: number; y: number; color: string; size: number }[] = [
  { x: -118, y: -80, color: Palette.amber, size: 1.0 },
  { x: -62, y: -98, color: Palette.pink, size: 0.7 },
  { x: -20, y: -70, color: Palette.sky, size: 0.85 },
  { x: 120, y: -40, color: Palette.violet, size: 0.9 },
  { x: 132, y: 30, color: Palette.amber, size: 0.6 },
  { x: 84, y: 6, color: Palette.mint, size: 0.75 },
  { x: -136, y: -18, color: Palette.sky, size: 0.55 },
];

export default function FocusPull({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const focusMV = useMotionValue(0.5);
  const focus = useMV(focusMV);
  const [target, setTarget] = useState<number | null>(1);
  const targetRef = useRef<number | null>(1);
  const step = useRef(0);
  const aperture = ctx.n("aperture");
  const zh = ctx.lang === "zh";

  const pick = (index: number) => {
    targetRef.current = index;
    setTarget(index);
    animate(focusMV, DEPTHS[index], spring(ctx.n("response"), ctx.n("damping")));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      pick(TOUR[step.current % TOUR.length]);
      step.current += 1;
    },
    { every: 1.9 },
  );

  const scrub = (value: number) => {
    const clamped = Math.min(Math.max(value, 0), 1);
    focusMV.stop();
    focusMV.set(clamped);
    let nearest = 0;
    DEPTHS.forEach((d, i) => {
      if (Math.abs(d - clamped) < Math.abs(DEPTHS[nearest] - clamped)) nearest = i;
    });
    const next = Math.abs(DEPTHS[nearest] - clamped) < 0.12 ? nearest : null;
    if (next === targetRef.current) return;
    targetRef.current = next;
    setTarget(next);
    if (next !== null) haptics.selection();
  };
  const pan = usePan({ onChange: (s) => scrub((s.location.x - 14 - 12) / RULER) });

  const breathe = ctx.b("breathing") ? 1 + 0.08 * (focus - 0.5) : 1;
  const labels: ReactNode[] = [
    <GradientText key={0} fill={Palette.sunset} style={{ fontFamily: fonts.rounded, fontSize: zh ? 84 : 78, lineHeight: `${zh ? 100 : 93}px`, fontWeight: 900 }}>
      {zh ? "近景" : "NEAR"}
    </GradientText>,
    <span key={1} style={{ fontSize: zh ? 32 : 34, lineHeight: `${zh ? 38 : 41}px`, fontWeight: 800, color: Palette.label }}>{zh ? "把焦点拉到这里" : "Pull focus here"}</span>,
    <span key={2} style={{ fontSize: 17, lineHeight: "20px", fontWeight: 600, color: Palette.labelAlpha(0.8) }}>{zh ? "远处亮着几盏灯" : "lights in the distance"}</span>,
  ];
  const offsets = [
    { x: -40, y: 58 },
    { x: 4, y: -22 },
    { x: 58, y: -84 },
  ];

  const plane = (index: number) => {
    const defocus = Math.abs(focus - DEPTHS[index]);
    const locked = defocus < 0.035;
    const picked = target === index;
    const stroke = locked ? Palette.green : Palette.amber;
    const arm = index === 2 ? 10.6 : 12;
    return (
      <div key={index} style={{ position: "absolute", left: "50%", top: "50%", width: 0, height: 0, display: "flex", alignItems: "center", justifyContent: "center", transform: `translate(${offsets[index].x}px, ${offsets[index].y}px)` }}>
        <div
          onClick={() => {
            haptics.tap("light");
            pick(index);
          }}
          style={{ position: "relative", flex: "none", padding: "6px 12px", whiteSpace: "pre", cursor: "pointer" }}
        >
          <div style={{ filter: `blur(${(aperture * defocus * 2).toFixed(2)}px)`, opacity: 1 - 0.4 * Math.min(defocus, 1), transform: `scale(${1 + 0.05 * Math.min(defocus, 1)})`, display: "flex" }}>{labels[index]}</div>
          <motion.div initial={false} animate={{ opacity: picked ? 1 : 0, scale: picked ? 1 : 1.25 }} transition={spring(0.35, 0.65)} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
            {(["tl", "tr", "br", "bl"] as const).map((corner) => (
              <span
                key={corner}
                style={{
                  position: "absolute",
                  width: arm,
                  height: arm,
                  [corner[0] === "t" ? "top" : "bottom"]: -1,
                  [corner[1] === "l" ? "left" : "right"]: -1,
                  [corner[0] === "t" ? "borderTop" : "borderBottom"]: `2px solid ${stroke}`,
                  [corner[1] === "l" ? "borderLeft" : "borderRight"]: `2px solid ${stroke}`,
                  borderRadius: 1,
                }}
              />
            ))}
          </motion.div>
        </div>
      </div>
    );
  };

  // The lights sit behind the far line, so they are never fully sharp.
  const bokehDefocus = Math.abs(focus - 1.3);
  const diameter = 6 + aperture * bokehDefocus * 2.6;
  const bokehAlpha = 0.8 / (1 + bokehDefocus * 2.4);
  const x = Math.min(Math.max(focus, -0.05), 1.05) * RULER;
  const marks = ["0.5 m", "2 m", "∞"];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
        <div style={{ position: "relative", width: 330, height: 228, transform: `scale(${breathe})` }}>
          {LIGHTS.map((light, index) => (
            <span
              key={index}
              style={{
                position: "absolute",
                left: "50%",
                top: "50%",
                width: diameter * light.size,
                height: diameter * light.size,
                marginLeft: (-diameter * light.size) / 2,
                marginTop: (-diameter * light.size) / 2,
                borderRadius: "50%",
                background: alpha(light.color, bokehAlpha),
                boxShadow: `inset 0 0 0 1px ${alpha(light.color, bokehAlpha * 0.9)}`,
                transform: `translate(${light.x}px, ${light.y}px)`,
                pointerEvents: "none",
              }}
            />
          ))}
          {plane(2)}
          {plane(1)}
          {plane(0)}
        </div>
        <div {...pan} style={{ ...pan.style, padding: "0 14px", display: "flex", flexDirection: "column", alignItems: "center", gap: 3, cursor: "ew-resize" }}>
          <div style={{ position: "relative", width: RULER, height: 26 }}>
            <svg width={RULER} height={14} style={{ position: "absolute", left: 0, top: 6, overflow: "visible" }}>
              {Array.from({ length: 25 }, (_, index) => {
                const height = index % 12 === 0 ? 14 : index % 6 === 0 ? 14 * 0.7 : 14 * 0.4;
                const tx = (RULER * index) / 24;
                return <line key={index} x1={tx} x2={tx} y1={7 - height / 2} y2={7 + height / 2} stroke={Palette.labelAlpha(0.3)} strokeWidth={1} />;
              })}
            </svg>
            <div style={{ position: "absolute", left: 0, top: 1, width: 3, height: 24, borderRadius: 1.5, background: Palette.amber, boxShadow: `0 0 10px ${alpha(Palette.amber, 0.6)}`, transform: `translateX(${x - 1.5}px)` }} />
          </div>
          <div style={{ width: RULER + 24, display: "flex" }}>
            {marks.map((mark, index) => (
              <span
                key={index}
                style={{
                  flex: 1,
                  textAlign: index === 0 ? "left" : index === 1 ? "center" : "right",
                  fontFamily: fonts.rounded,
                  fontSize: 11,
                  lineHeight: "13px",
                  fontWeight: 700,
                  fontVariantNumeric: "tabular-nums",
                  color: Math.abs(focus - DEPTHS[index]) < 0.035 ? Palette.label : Palette.secondaryLabel,
                }}
              >
                {mark}
              </span>
            ))}
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap a line, or drag the focus scale" zh="点击某一行，或拖动对焦刻度" />
    </div>
  );
}
