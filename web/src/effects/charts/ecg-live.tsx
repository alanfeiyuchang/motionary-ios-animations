/** charts.ecg-live · 实时心电波形 (Charts+ECGLive.swift) */
import { useRef } from "react";
import { Palette, alpha, fonts, useAutoplay, useClock, type DemoProps } from "../../kit";
import { ChartStage, G, Plot, captionSecondary, card, circle, mono, rgba, sys, useChartHaptics } from "./_round2";

const SAMPLES = 240;
const SWEEP = 3.2;

/** One heartbeat, `x` in 0…1: baseline 0, R peak 1. */
function wave(x: number): number {
  const bump = (center: number, width: number, amp: number) => amp * Math.exp(-Math.pow((x - center) / width, 2));
  return bump(0.14, 0.035, 0.12) + bump(0.272, 0.011, -0.13) + bump(0.3, 0.013, 1) + bump(0.334, 0.013, -0.24) + bump(0.56, 0.06, 0.28);
}

class ECGModel {
  levels = new Array<number>(SAMPLES).fill(0);
  stamps = new Array<number>(SAMPLES).fill(-100);
  clock = 0;
  phase = 0;
  bpm = 72;
  boost = 0;
  lastBeat = -10;
  head = 0;
  private last: number | null = null;

  advance(now: number, resting: number) {
    if (this.last === null) {
      this.last = now;
      return;
    }
    let elapsed = now - this.last;
    this.last = now;
    if (elapsed > 0.25) elapsed = 1 / 60;
    if (elapsed <= 0) return;
    this.run(elapsed, resting);
  }

  /** Fills the buffer as if the monitor had already been running. */
  run(seconds: number, resting: number) {
    const perSample = SWEEP / SAMPLES;
    let remaining = seconds;
    while (remaining > 0) {
      const step = Math.min(remaining, perSample);
      remaining -= step;
      this.clock += step;
      this.boost *= Math.exp(-step / 2.4);
      this.bpm = resting + this.boost;
      const before = this.phase;
      this.phase += (step * this.bpm) / 60;
      if (Math.floor(this.phase - 0.3) > Math.floor(before - 0.3)) this.lastBeat = this.clock;
      this.head += step / perSample;
      if (this.head >= SAMPLES) this.head -= SAMPLES;
      const index = Math.min(Math.floor(this.head), SAMPLES - 1);
      this.levels[index] = wave(this.phase - Math.floor(this.phase));
      this.stamps[index] = this.clock;
    }
  }
}

export default function ECGLive({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const modelRef = useRef<ECGModel | null>(null);
  if (!modelRef.current) {
    modelRef.current = new ECGModel();
    modelRef.current.run(1.2, ctx.n("bpm"));
  }
  const model = modelRef.current;
  const lastFrame = useRef(-1);
  const frame = useClock(true, ctx.isPreview ? 30 : undefined);
  if (frame !== lastFrame.current) {
    lastFrame.current = frame;
    model.advance(performance.now() / 1000, ctx.n("bpm"));
  }

  /** Tap and autoplay: a burst of exertion that decays back to the resting rate. */
  const exert = () => {
    haptics.tap("medium");
    model.boost = Math.min(model.boost + 45, 80);
  };
  useAutoplay(ctx.isPreview, exert, { every: 4.5, delay: 1.2 });

  const now = model.clock;
  const pulse = Math.exp(-Math.max(now - model.lastBeat, 0) / 0.18);
  const trail = ctx.n("trail");
  const glow = ctx.b("glow");
  const grid = ctx.b("grid");

  const draw = (g: G) => {
    const c = g.c;
    c.save();
    const clip = new Path2D();
    clip.roundRect(0, 0, g.width, g.height, 12);
    c.clip(clip);
    g.fill(clip, g.primary(0.035));

    if (grid) {
      const lines = new Path2D();
      const cell = 23;
      for (let x = cell; x < g.width; x += cell) {
        lines.moveTo(x, 0);
        lines.lineTo(x, g.height);
      }
      for (let y = cell; y < g.height; y += cell) {
        lines.moveTo(0, y);
        lines.lineTo(g.width, y);
      }
      g.stroke(lines, rgba(Palette.pink, 0.13), 0.5);
    }

    const count = SAMPLES;
    const window = SWEEP * trail;
    const baseline = g.height * 0.68;
    const amplitude = g.height * 0.5;
    const px = (index: number) => (g.width * index) / (count - 1);
    const py = (index: number) => baseline - model.levels[index] * amplitude;

    const bands = 10;
    const paths = Array.from({ length: bands }, () => new Path2D());
    const fresh = new Path2D();
    for (let index = 0; index < count - 1; index++) {
      const newer = Math.max(model.stamps[index], model.stamps[index + 1]);
      const older = Math.min(model.stamps[index], model.stamps[index + 1]);
      // Skip the seam where the head meets the oldest samples.
      if (!(newer - older < 0.1)) continue;
      const age = now - newer;
      const a = 1 - age / window;
      if (!(a > 0.02)) continue;
      const band = Math.min(Math.floor(a * bands), bands - 1);
      paths[band].moveTo(px(index), py(index));
      paths[band].lineTo(px(index + 1), py(index + 1));
      if (age < 0.55) {
        fresh.moveTo(px(index), py(index));
        fresh.lineTo(px(index + 1), py(index + 1));
      }
    }

    if (glow) {
      g.blurred(5, rgba(Palette.pink, 0.85), () => g.stroke(fresh, "#000", 5, { cap: "round", join: "round" }));
    }
    for (let band = 0; band < bands; band++) {
      g.stroke(paths[band], rgba(Palette.pink, (band + 0.5) / bands), 2, { cap: "round", join: "round" });
    }

    const headIndex = Math.min(Math.floor(model.head), count - 1);
    const tx = px(headIndex);
    const ty = py(headIndex);
    if (glow) g.fill(circle(tx, ty, 11), g.radial(tx, ty, 0, 11, [rgba(Palette.pink, 0.55), rgba(Palette.pink, 0)]));
    g.fill(circle(tx, ty, 4), Palette.pink);
    g.fill(circle(tx, ty, 2), "#fff");
    c.restore();
  };

  return (
    <ChartStage ctx={ctx} hint={["Tap to raise the heart rate", "点击让心率加快"]}>
      <div onClick={exert} style={{ ...card(12), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ position: "relative", width: 44, height: 44, display: "grid", placeItems: "center", flex: "none" }}>
            <div style={{ position: "absolute", left: 2, top: 2, width: 40, height: 40, borderRadius: "50%", background: alpha(Palette.pink, 0.14 + 0.18 * pulse), transform: `scale(${1 + 0.2 * pulse})` }} />
            <svg width={22} height={20} viewBox="0 0 24 22" style={{ position: "relative", transform: `scale(${1 + 0.18 * pulse})`, overflow: "visible" }}>
              <defs>
                <linearGradient id="ecg-heart" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0" stopColor={Palette.pink} />
                  <stop offset="1" stopColor={Palette.red} />
                </linearGradient>
              </defs>
              <path
                fill="url(#ecg-heart)"
                d="M12 21.2c-.4 0-.8-.2-1.3-.5C5 16.9 1 12.900 1 8.200 1 4.500 3.700 1.800 7 1.800c2.100 0 3.900 1.100 5 2.800 1.100-1.700 2.900-2.800 5-2.800 3.300 0 6 2.700 6 6.400 0 4.700-4 8.700-9.700 12.500-.5.300-.9.500-1.300.500z"
              />
            </svg>
          </div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Heart rate", "心率")}</div>
            <div style={{ display: "flex", alignItems: "baseline", gap: 4 }}>
              <span style={{ ...sys(28, 700, true), ...mono, display: "inline-block", transform: `scale(${1 + 0.05 * pulse})`, transformOrigin: "0% 100%" }}>{Math.round(model.bpm)}</span>
              <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 700, color: Palette.pink }}>BPM</span>
            </div>
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 8px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: Palette.red, opacity: 0.35 + 0.65 * pulse }} />
            <span style={{ fontFamily: fonts.rounded, fontSize: 10, lineHeight: "12px", fontWeight: 800, color: Palette.secondaryLabel }}>LIVE</span>
          </div>
        </div>
        <Plot ctx={ctx} width={268} height={138} draw={draw} />
      </div>
    </ChartStage>
  );
}
