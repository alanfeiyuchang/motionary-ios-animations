/** charts.sparkline-stream · 实时数据流迷你图 (Charts+Sparkline.swift) */
import { useId, useRef } from "react";
import { Palette, alpha, clamp, demoCard, useClock, useHaptics, type DemoProps } from "../../kit";
import { randomIn } from "./_shared";
import { Stage, captionSecondary, rounded } from "./_legacy";

const VISIBLE = 24;

class StreamModel {
  series: number[][];
  private lastTick: number | null = null;
  /** Extra height the next sample of each row receives (set by a tap, consumed by `push`). */
  private pendingSpike = [0, 0, 0];

  constructor() {
    this.series = [0, 1, 2].map((index) => {
      let value = 0.35 + 0.15 * index;
      return Array.from({ length: VISIBLE + 2 }, () => (value = clamp(value + randomIn(-0.08, 0.08), 0.05, 0.95)));
    });
  }

  spike(index: number) {
    this.pendingSpike[index] = 0.38;
  }

  /** Returns the fractional progress (0…1) toward the next sample. */
  advance(date: number, interval: number, volatility: number): number {
    if (this.lastTick === null) {
      this.lastTick = date;
      return 0;
    }
    let elapsed = date - this.lastTick;
    if (elapsed > 2) {
      this.lastTick = date;
      return 0;
    }
    let tick = this.lastTick;
    while (elapsed >= interval) {
      this.push(volatility);
      tick += interval;
      elapsed -= interval;
    }
    this.lastTick = tick;
    return clamp(elapsed / interval);
  }

  private push(volatility: number) {
    this.series.forEach((row, index) => {
      const last = row[row.length - 1] ?? 0.5;
      const next = last + randomIn(-volatility, volatility) + (0.5 - last) * 0.08 + this.pendingSpike[index];
      this.pendingSpike[index] = 0;
      row.push(clamp(next, 0.04, 0.96));
      if (row.length > VISIBLE + 2) row.splice(0, row.length - (VISIBLE + 2));
    });
  }
}

const styles = [
  { en: "CPU", zh: "CPU", color: Palette.indigo },
  { en: "Memory", zh: "内存", color: Palette.mint },
  { en: "Network", zh: "网络", color: Palette.coral },
];

const CW = 300 - 24 - 76 - 12;
const CH = 54;
const PLOT_W = CW - 8;

export default function SparklineStream({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const modelRef = useRef<StreamModel | null>(null);
  if (!modelRef.current) modelRef.current = new StreamModel();
  const model = modelRef.current;
  const lastFrame = useRef(-1);
  const phaseRef = useRef(0);
  const frame = useClock(true, ctx.isPreview ? 30 : undefined);
  if (frame !== lastFrame.current) {
    lastFrame.current = frame;
    phaseRef.current = model.advance(performance.now() / 1000, Math.max(ctx.n("interval"), 0.05), ctx.n("volatility"));
  }
  const phase = phaseRef.current;
  const showFill = ctx.b("fill");

  return (
    <Stage ctx={ctx} hint={["Tap a card to spike it", "点击卡片制造峰值"]} bottom={6}>
      <div style={{ width: 300, display: "flex", flexDirection: "column", gap: 10 }}>
        {styles.map((style, index) => {
          const values = model.series[index];
          const n = values.length;
          const head = values[n - 2] + (values[n - 1] - values[n - 2]) * phase;
          const step = PLOT_W / (n - 2);
          const y = (v: number) => CH - 4 - v * (CH - 8);
          const pts = values.map((v, i) => `${((i - phase) * step).toFixed(2)},${y(v).toFixed(2)}`);
          const line = `M${pts.join(" L")}`;
          const headY = y(head);
          return (
            <div
              key={index}
              onClick={() => {
                model.spike(index);
                haptics.tap("light");
              }}
              style={{ ...demoCard(18), padding: 12, display: "flex", alignItems: "center", gap: 12, cursor: "pointer" }}
            >
              <div style={{ width: 76, flex: "none", display: "flex", flexDirection: "column", gap: 2 }}>
                <div style={captionSecondary}>{ctx.t(style.en, style.zh)}</div>
                <div style={rounded(22, 700, 26)}>{Math.round(head * 100)}%</div>
              </div>
              <svg width={CW} height={CH} style={{ display: "block", flex: "none" }}>
                <defs>
                  <clipPath id={`${uid}c${index}`}>
                    <rect x={0} y={0} width={PLOT_W} height={CH} />
                  </clipPath>
                  <linearGradient id={`${uid}g${index}`} x1="0" y1="0" x2="0" y2={CH} gradientUnits="userSpaceOnUse">
                    <stop offset="0" stopColor={style.color} stopOpacity={0.3} />
                    <stop offset="1" stopColor={style.color} stopOpacity={0} />
                  </linearGradient>
                </defs>
                <g clipPath={`url(#${uid}c${index})`}>
                  {showFill && <path d={`${line} L${((n - 1 - phase) * step).toFixed(2)},${CH} L${(-phase * step).toFixed(2)},${CH} Z`} fill={`url(#${uid}g${index})`} />}
                  <path d={line} fill="none" stroke={style.color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
                </g>
                <circle cx={PLOT_W} cy={headY} r={7} fill={alpha(style.color, 0.25)} />
                <circle cx={PLOT_W} cy={headY} r={3.5} fill={style.color} />
              </svg>
            </div>
          );
        })}
      </div>
    </Stage>
  );
}
