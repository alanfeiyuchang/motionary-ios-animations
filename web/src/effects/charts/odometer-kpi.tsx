/** charts.odometer-kpi · 里程表数字 KPI (Charts+OdometerKPI.swift) */
import { motion } from "motion/react";
import { Fragment, useId, useRef, useState } from "react";
import { NumericText, Palette, SymbolBounce, alpha, anim, clamp, delayed, demoCard, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { randomIn, useAnimatedNumbers, useChartEntrance } from "./_shared";
import { DiagonalArrow, Stage, SymbolSwap, captionSecondary, rounded } from "./_legacy";

const WHEEL = 52;
const SW = 264;
const SH = 70;

const sparkPoints = (points: number[]) => points.map((v, i) => `${((SW * i) / Math.max(points.length - 1, 1)).toFixed(2)},${(SH - SH * v).toFixed(2)}`);

export default function OdometerKPI({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const { after } = useTimeouts();
  const [state, setState] = useState({
    value: 48_209,
    previous: 45_830,
    points: [0.32, 0.38, 0.35, 0.44, 0.41, 0.5, 0.47, 0.55, 0.52, 0.6, 0.57, 0.66, 0.63, 0.7, 0.74, 0.8],
  });
  const valueRef = useRef(48_209);
  const drawn = useAnimatedNumbers(1, 0);
  const generation = useRef(0);

  const refresh = (haptic: boolean) => {
    drawn.to(0, 0, anim.easeIn(0.15));
    if (haptic) haptics.tap("light");
    generation.current += 1;
    const current = generation.current;
    after(0.18, () => {
      if (current !== generation.current) return;
      const value = valueRef.current;
      const next = clamp(Math.round(value * randomIn(0.8, 1.25)), 21_000, 98_000);
      const walk: number[] = [];
      let level = randomIn(0.3, 0.6);
      const trend = next >= value ? 0.03 : -0.03;
      for (let i = 0; i < 16; i++) {
        level = clamp(level + trend + randomIn(-0.09, 0.09), 0.08, 0.95);
        walk.push(level);
      }
      valueRef.current = next;
      setState({ value: next, previous: value, points: walk });
      drawn.to(0, 1, anim.easeOut(0.9));
    });
  };

  useChartEntrance(() => refresh(false));
  useAutoplay(ctx.isPreview, () => refresh(false), { every: 2.8, delay: 2.8, intro: false });

  const digits = String(state.value).split("").map(Number);
  const delta = ((state.value - state.previous) / Math.max(state.previous, 1)) * 100;
  const up = delta >= 0;
  const color = up ? Palette.green : Palette.red;
  const pts = sparkPoints(state.points);
  const line = `M${pts.join(" L")}`;
  const d = drawn.get(0);
  return (
    <Stage ctx={ctx} hint={["Tap to refresh", "点击刷新"]}>
      <div onClick={() => refresh(true)} style={{ ...demoCard(), width: 300, padding: 18, display: "flex", flexDirection: "column", gap: 10, cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={captionSecondary}>{ctx.t("Revenue today", "今日营收")}</div>
          <div style={{ display: "flex", alignItems: "center", gap: 3, padding: "4px 8px", borderRadius: 999, background: alpha(color, 0.14), color, ...rounded(12, 700, 15), transition: "color 0.3s, background-color 0.3s" }}>
            <SymbolBounce trigger={up}>
              <SymbolSwap id={up ? "up" : "down"} size={11}>
                <DiagonalArrow up={up} size={11} />
              </SymbolSwap>
            </SymbolBounce>
            <NumericText value={delta} text={`${Math.abs(delta).toFixed(1)}%`} />
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", ...rounded(44, 700, WHEEL) }}>
          <span>$</span>
          {digits.map((digit, index) => (
            <Fragment key={digits.length - index}>
              {index === digits.length - 3 && <span>,</span>}
              <DigitWheel digit={digit} delay={(digits.length - 1 - index) * ctx.n("stagger")} damping={ctx.n("damping")} />
            </Fragment>
          ))}
        </div>
        <svg width={SW} height={SH} style={{ display: "block", overflow: "visible" }}>
          <defs>
            <linearGradient id={`${uid}a`} x1="0" y1="0" x2="0" y2={SH} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={Palette.indigo} stopOpacity={0.25} />
              <stop offset="1" stopColor={Palette.indigo} stopOpacity={0} />
            </linearGradient>
            <linearGradient id={`${uid}l`} x1="0" y1="0" x2={SW} y2={SH} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={Palette.indigo} />
              <stop offset="1" stopColor={Palette.violet} />
            </linearGradient>
          </defs>
          <path d={`${line} L${SW},${SH} L0,${SH} Z`} fill={`url(#${uid}a)`} opacity={d} />
          {d > 0.0005 && <path d={line} fill="none" stroke={`url(#${uid}l)`} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" pathLength={1} strokeDasharray={`${d} 2`} />}
        </svg>
        <div style={{ fontSize: 11, lineHeight: "13px", color: Palette.tertiaryLabel }}>{ctx.t("vs. yesterday", "较昨日")}</div>
      </div>
    </Stage>
  );
}

/** 9 · 0…9 · 0: the padding rows keep a spring overshoot past 0 or 9 from showing a blank cell. */
function DigitWheel({ digit, delay, damping }: { digit: number; delay: number; damping: number }) {
  const fade = "linear-gradient(180deg, transparent 0%, #000 18%, #000 82%, transparent 100%)";
  return (
    <div style={{ width: 27, height: WHEEL, overflow: "hidden", maskImage: fade, WebkitMaskImage: fade }}>
      <motion.div initial={false} animate={{ y: -(digit + 1) * WHEEL }} transition={delayed(spring(0.7, damping), delay)}>
        {Array.from({ length: 12 }, (_, row) => (
          <div key={row} style={{ height: WHEEL, display: "flex", alignItems: "center", justifyContent: "center" }}>
            {(row + 9) % 10}
          </div>
        ))}
      </motion.div>
    </div>
  );
}
