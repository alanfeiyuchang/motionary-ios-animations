/** charts.candlestick-live · 实时 K 线 (Charts+Candlestick.swift) */
import { useId, useRef } from "react";
import { Palette, alpha, clamp, demoCard, fonts, useClock, useHaptics, type DemoProps } from "../../kit";
import { randomIn } from "./_shared";
import { Stage, captionSecondary, rounded, signed } from "./_legacy";

interface Candle {
  open: number;
  high: number;
  low: number;
  close: number;
}

const VISIBLE = 18;

class CandleModel {
  candles: Candle[] = [];
  live: Candle;
  low: number;
  high: number;
  phase = 0;
  impulse = 0;
  private target: number;
  private lastTick: number | null = null;
  private lastCommit: number | null = null;
  private lastDate: number | null = null;

  constructor() {
    let price = 182.0;
    for (let i = 0; i < VISIBLE; i++) {
      const open = price;
      const close = open + randomIn(-1.1, 1.25);
      this.candles.push({ open, high: Math.max(open, close) + randomIn(0.1, 0.7), low: Math.min(open, close) - randomIn(0.1, 0.7), close });
      price = close;
    }
    this.live = { open: price, high: price, low: price, close: price };
    this.target = price;
    this.low = Math.min(...this.candles.map((c) => c.low)) - 1;
    this.high = Math.max(...this.candles.map((c) => c.high)) + 1;
  }

  step(date: number, interval: number, volatility: number) {
    const dt = Math.min(Math.max(this.lastDate === null ? 0 : date - this.lastDate, 0), 1 / 20);
    this.lastDate = date;
    if (this.lastCommit === null) this.lastCommit = date;

    const sinceTick = this.lastTick === null ? Infinity : date - this.lastTick;
    if (sinceTick > 0.14) {
      this.lastTick = date;
      this.target = this.live.close + randomIn(-0.75, 0.8) * volatility + this.impulse;
      this.impulse *= 0.45;
    }
    this.live.close += (this.target - this.live.close) * (1 - Math.exp(-dt * 14));
    this.live.high = Math.max(this.live.high, this.live.close);
    this.live.low = Math.min(this.live.low, this.live.close);

    let elapsed = date - this.lastCommit;
    if (elapsed >= interval) {
      this.candles.push(this.live);
      if (this.candles.length > VISIBLE) this.candles.splice(0, this.candles.length - VISIBLE);
      const c = this.live.close;
      this.live = { open: c, high: c, low: c, close: c };
      this.lastCommit = date;
      elapsed = 0;
    }
    this.phase = clamp(elapsed / Math.max(interval, 0.1));

    let lo = this.live.low;
    let hi = this.live.high;
    for (const candle of this.candles) {
      lo = Math.min(lo, candle.low);
      hi = Math.max(hi, candle.high);
    }
    const pad = (hi - lo) * 0.12 + 0.3;
    const k = 1 - Math.exp(-dt * 5);
    this.low += (lo - pad - this.low) * k;
    this.high += (hi + pad - this.high) * k;
  }
}

const W = 268;
const H = 176;
const TAG = 50;
const PLOT_W = W - TAG - 6;
const STEP = PLOT_W / (VISIBLE + 1.2);
const BODY_W = STEP * 0.62;

export default function CandlestickLive({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const uid = useId().replace(/:/g, "");
  const modelRef = useRef<CandleModel | null>(null);
  if (!modelRef.current) modelRef.current = new CandleModel();
  const model = modelRef.current;
  const lastFrame = useRef(-1);
  const frame = useClock(true, ctx.isPreview ? 30 : undefined);
  if (frame !== lastFrame.current) {
    lastFrame.current = frame;
    model.step(performance.now() / 1000, ctx.n("interval"), ctx.n("volatility"));
  }
  const hollow = ctx.i("style") === 1;

  const spike = () => {
    model.impulse = (Math.random() < 0.5 ? 1 : -1) * randomIn(2.5, 4.5) * ctx.n("volatility");
    haptics.tap("rigid");
  };

  const { live, candles, phase, low, high } = model;
  const up = live.close >= live.open;
  const tint = up ? Palette.green : Palette.red;
  const span = Math.max(high - low, 0.0001);
  const y = (value: number) => H * (1 - (value - low) / span);
  const priceY = clamp(y(live.close), 9, Math.max(H - 9, 9));

  const candle = (c: Candle, x: number, glow: boolean, key: number | string) => {
    const isUp = c.close >= c.open;
    const color = isUp ? Palette.green : Palette.red;
    const top = y(Math.max(c.open, c.close));
    const bottom = Math.max(y(Math.min(c.open, c.close)), top + 1.5);
    return (
      <g key={key}>
        {glow && <rect x={x - BODY_W / 2 - 3} y={top - 3} width={BODY_W + 6} height={bottom - top + 6} rx={4} fill={alpha(color, 0.18)} />}
        <line x1={x} x2={x} y1={y(c.high)} y2={y(c.low)} stroke={color} strokeWidth={1.2} />
        <rect
          x={x - BODY_W / 2}
          y={top}
          width={BODY_W}
          height={bottom - top}
          rx={Math.min(1.5, (bottom - top) / 2)}
          fill={hollow && isUp ? Palette.elevated : color}
          stroke={hollow && isUp ? color : "none"}
          strokeWidth={1.2}
        />
      </g>
    );
  };

  return (
    <Stage ctx={ctx} hint={["Tap to inject volatility", "点击注入一次波动"]}>
      <div onClick={spike} style={{ ...demoCard(), width: 304, padding: 18, display: "flex", flexDirection: "column", gap: 10, cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={captionSecondary}>{ctx.t("MLX / USD · Live", "MLX / USD · 实时")}</div>
            <div style={{ ...rounded(26, 700, 31), color: tint }}>{live.close.toFixed(2)}</div>
          </div>
          <div style={{ ...rounded(13, 600, 16), color: tint, padding: "5px 9px", borderRadius: 999, background: alpha(tint, 0.14) }}>{signed(live.close - live.open)}</div>
        </div>
        <svg width={W} height={H} style={{ display: "block" }}>
          <defs>
            <clipPath id={`${uid}p`}>
              <rect x={0} y={0} width={PLOT_W} height={H} />
            </clipPath>
          </defs>
          {[0.25, 0.5, 0.75].map((f) => (
            <line key={f} x1={0} x2={PLOT_W} y1={H * f} y2={H * f} stroke={Palette.labelAlpha(0.07)} strokeWidth={0.5} />
          ))}
          <g clipPath={`url(#${uid}p)`}>
            {candles.map((c, index) => candle(c, (index - phase) * STEP + STEP / 2, false, index))}
            {candle(live, (candles.length - phase) * STEP + STEP / 2, true, "live")}
          </g>
          <line x1={0} x2={PLOT_W + 6} y1={priceY} y2={priceY} stroke={alpha(tint, 0.7)} strokeWidth={1} strokeDasharray="3 3" />
          {[0.25, 0.5, 0.75].map((f) => {
            const guideY = H * f;
            if (!(Math.abs(guideY - priceY) > 14)) return null;
            return (
              <text key={f} x={W - TAG / 2} y={guideY} textAnchor="middle" dominantBaseline="central" fill={Palette.secondaryLabel} style={{ fontFamily: fonts.rounded, fontSize: 9, fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
                {(low + (1 - f) * span).toFixed(2)}
              </text>
            );
          })}
          <rect x={W - TAG} y={priceY - 9} width={TAG} height={18} rx={5} fill={tint} />
          <text x={W - TAG / 2} y={priceY} textAnchor="middle" dominantBaseline="central" fill="#fff" style={{ fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>
            {live.close.toFixed(2)}
          </text>
        </svg>
      </div>
    </Stage>
  );
}
