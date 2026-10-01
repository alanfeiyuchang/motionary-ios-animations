/** charts.radial-bars · 环形柱状图 (Charts+RadialBars.swift) */
import { useRef, useState } from "react";
import { NumericText, Palette, delayed, fonts, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, RGB, swiftRound, useChartHaptics, useNums, useTapPan, type Pt } from "./_round2";

/** Steps per hour over a day: quiet night, commute, lunch and evening peaks. */
const steps = Array.from({ length: 24 }, (_, hour) => {
  const h = hour;
  const peak = (center: number, width: number, amp: number) => amp * Math.exp(-Math.pow((h - center) / width, 2));
  const value = 230 + peak(8, 1.8, 760) + peak(12.5, 1.6, 520) + peak(18.5, 2.4, 900) + peak(15.5, 1.6, 300) + peak(22, 1.5, 160) + 70 * Math.sin(h * 2.1);
  return Math.max(swiftRound(value), 120);
});
const stepsPeak = Math.max(...steps);
const stepsTotal = steps.reduce((a, b) => a + b, 0);

const SIDE = 250;
const MAX_LENGTH = 60;
const script: (number | null)[] = [8, 12, 18, null];

export default function RadialBars({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const grow = useNums(24, 0);
  /** Selected amount (0…1) and dimmed amount (0…1) per bar, moved by the selection spring. */
  const sel = useNums(24, 0);
  const dim = useNums(24, 0);
  const turn = useNums(1, 0);
  const [selected, setSelected] = useState<number | null>(null);
  const selectedRef = useRef<number | null>(null);
  const engaged = useRef(false);
  const autoStep = useRef(0);
  const inner = ctx.n("inner");

  /** Taps, the ring drag and autoplay share this. */
  const select = (index: number | null) => {
    if (index === selectedRef.current) return;
    haptics.selection();
    selectedRef.current = index;
    setSelected(index);
    const s = spring(0.35, 0.7);
    for (let i = 0; i < 24; i++) {
      sel.to(i, i === index ? 1 : 0, s);
      dim.to(i, index !== null && i !== index ? 1 : 0, s);
    }
  };

  /** The hour slot under a point; `strict` also requires the point to be on the ring. */
  const hourAt = (p: Pt, strict: boolean): number | null => {
    const dx = p.x - SIDE / 2;
    const dy = p.y - SIDE / 2;
    const radius = Math.hypot(dx, dy);
    if (radius < inner - 6) return null;
    if (strict && radius > inner + MAX_LENGTH + 22) return null;
    let fraction = (Math.atan2(dy, dx) + Math.PI / 2) / (2 * Math.PI);
    if (fraction < 0) fraction += 1;
    return Math.min(Math.floor(fraction * 24), 23);
  };

  const gesture = useTapPan(
    {
      onTap: (p) => {
        const hit = hourAt(p, true);
        select(hit === selectedRef.current ? null : hit);
      },
      onChange: (s) => {
        if (!engaged.current) {
          if (!(Math.abs(s.translation.x) > Math.abs(s.translation.y))) return;
          engaged.current = true;
        }
        const index = hourAt(s.location, false);
        if (index !== null) select(index);
      },
      onEnd: () => (engaged.current = false),
    },
    8,
  );

  const sweepOut = () => {
    turn.to(0, 1, spring(0.9, 0.82));
    for (let index = 0; index < 24; index++) grow.to(index, 1, delayed(spring(ctx.n("response"), 0.62), index * ctx.n("stagger")));
  };

  useChartEntrance(sweepOut);
  useAutoplay(
    ctx.isPreview,
    () => {
      select(script[autoStep.current % script.length]);
      autoStep.current += 1;
    },
    { every: 1.2, delay: 1.9, intro: false },
  );

  const t = turn.get();
  const value = selected !== null ? steps[selected] : stepsTotal;
  const caption = selected !== null ? `${String(selected).padStart(2, "0")}:00` : ctx.t("Steps today", "今日步数");
  const ring = (radius: number, dashed: boolean) => (
    <div
      style={{
        position: "absolute",
        left: SIDE / 2 - radius,
        top: SIDE / 2 - radius,
        width: radius * 2,
        height: radius * 2,
        borderRadius: "50%",
        border: `1px ${dashed ? "dashed" : "solid"} ${Palette.labelAlpha(0.07)}`,
      }}
    />
  );

  return (
    <ChartStage ctx={ctx} hint={["Tap a bar, or drag around the ring", "点击柱子，或沿圆环拖动"]}>
      <div {...gesture} style={{ ...gesture.style, position: "relative", width: SIDE, height: SIDE, transform: `rotate(${-40 * (1 - t)}deg)`, cursor: "pointer" }}>
        {ring(inner - 5, false)}
        <svg width={SIDE} height={SIDE} style={{ position: "absolute", inset: 0 }}>
          <circle cx={SIDE / 2} cy={SIDE / 2} r={inner + MAX_LENGTH - 0.5} fill="none" stroke={Palette.labelAlpha(0.07)} strokeWidth={1} strokeDasharray="2 4" />
        </svg>
        {steps.map((stepsAt, index) => {
          const fraction = stepsAt / stepsPeak;
          const g = grow.get(index);
          const s = sel.get(index);
          const d = dim.get(index);
          const base = 7 + (MAX_LENGTH - 7) * fraction;
          const length = Math.max((base + 8 * s) * g * (1 - 0.06 * d), 0.01);
          const tip = RGB.indigo.mixed(RGB.pink, 0.25 + 0.75 * fraction);
          return (
            <div
              key={index}
              style={{
                position: "absolute",
                left: SIDE / 2 - 3.5,
                top: SIDE / 2,
                width: 7,
                height: length,
                borderRadius: 3.5,
                background: `linear-gradient(to bottom, ${tip.color()}, ${Palette.indigo})`,
                boxShadow: s > 0.01 ? `0 0 14px ${tip.color(0.7 * Math.min(s, 1))}` : undefined,
                transformOrigin: "50% 0",
                transform: `rotate(${(index / 24) * 360 + 7.5}deg) translateY(${-(inner + length)}px)`,
                opacity: g > 0.01 ? 1 - 0.72 * d : 0,
              }}
            />
          );
        })}
        {[0, 6, 12, 18].map((hour) => {
          const angle = (hour / 24) * 2 * Math.PI - Math.PI / 2;
          const radius = inner + MAX_LENGTH + 11;
          return (
            <div
              key={hour}
              style={{
                position: "absolute",
                left: SIDE / 2 + Math.cos(angle) * radius,
                top: SIDE / 2 + Math.sin(angle) * radius,
                transform: `translate(-50%, -50%) rotate(${40 * (1 - t)}deg)`,
                fontFamily: fonts.rounded,
                fontSize: 10,
                lineHeight: "12px",
                fontWeight: 600,
                color: Palette.secondaryLabel,
                opacity: Math.max(0, Math.min(t, 1)),
              }}
            >
              {hour}
            </div>
          );
        })}
        <div
          style={{
            position: "absolute",
            left: SIDE / 2 - (inner - 8),
            top: 0,
            width: (inner - 8) * 2,
            height: SIDE,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            gap: 1,
            transform: `rotate(${40 * (1 - t)}deg) scale(${0.7 + 0.3 * t})`,
            opacity: Math.max(0, Math.min(t, 1)),
            pointerEvents: "none",
          }}
        >
          <NumericText value={value} text={value.toLocaleString("en-US")} style={{ fontFamily: fonts.rounded, fontSize: inner < 40 ? 17 : 22, lineHeight: "26px", fontWeight: 700 }} />
          <div style={{ fontSize: inner < 40 ? 9 : 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{caption}</div>
        </div>
      </div>
    </ChartStage>
  );
}
