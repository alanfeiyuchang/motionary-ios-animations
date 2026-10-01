/** charts.funnel-flow · 漏斗粒子流 (Charts+FunnelFlow.swift) */
import { Palette, alpha, anim, spring, useAutoplay, useClock, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, card, circle, clamp01, mono, polyline, rgba, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const stages = [
  { en: "Visits", zh: "访问", count: 12400, colors: [Palette.indigo, "#7F74FF"] },
  { en: "Sign-ups", zh: "注册", count: 7690, colors: ["#8A6FFF", Palette.violet] },
  { en: "Trials", zh: "试用", count: 4710, colors: ["#C566E8", Palette.pink] },
  { en: "Paid", zh: "付费", count: 2600, colors: ["#FF6A8E", Palette.coral] },
];

const BAND = 42;
const GAP = 2;
const TOP_WIDTH = 156;
const HEIGHT = stages.length * BAND + (stages.length - 1) * GAP;

const rate = (stage: number) => (stage >= 0 && stage < stages.length ? stages[stage].count / stages[0].count : (stages[stages.length - 1].count / stages[0].count) * 0.78);
const topOf = (stage: number) => stage * (BAND + GAP);

/** Half width of the funnel at depth `y` (walls ease between a stage's rate and the next one's). */
function halfWidth(y: number): number {
  const pitch = BAND + GAP;
  const stage = Math.min(Math.max(Math.trunc(y / pitch), 0), stages.length - 1);
  const local = clamp01((y - stage * pitch) / BAND);
  const eased = local * local * (3 - 2 * local);
  const from = rate(stage);
  const to = rate(stage + 1);
  return (TOP_WIDTH / 2) * (from + (to - from) * eased);
}

/** Depth at which a lane (half-width fraction `m`) meets the wall, or null if it survives. */
function hitDepth(m: number): number | null {
  const laneX = (m * TOP_WIDTH) / 2;
  for (let y = 0; y <= HEIGHT; y += 1.5) if (halfWidth(y) < laneX) return y;
  return null;
}

const particles = Array.from({ length: 120 }, (_, index) => {
  // Golden-ratio scrambling: lanes cover the width evenly for any prefix of the array.
  const lane = (index * 0.6180339887) % 1;
  const phase = (index * 0.7548776662) % 1;
  const jitter = (index * 0.569840291) % 1;
  const m = 0.04 + lane * 0.92;
  return { lane: m, side: index % 2 === 0 ? 1 : -1, phase, speed: 0.85 + 0.3 * jitter, hit: hitDepth(m) };
});

function bandPath(stage: number, centerX: number, depth: number): Path2D {
  const top = topOf(stage);
  const bottom = top + Math.min(Math.max(depth, 0), BAND);
  const left: Pt[] = [];
  const right: Pt[] = [];
  for (let y = top; y < bottom; y += 3) {
    const half = halfWidth(y);
    left.push({ x: centerX - half, y });
    right.push({ x: centerX + half, y });
  }
  const half = halfWidth(Math.min(bottom, top + BAND - 0.01));
  left.push({ x: centerX - half, y: bottom });
  right.push({ x: centerX + half, y: bottom });
  return polyline([...left, ...right.reverse()], true);
}

export default function FunnelFlow({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const fill = useNums(stages.length, 0);
  useClock(true, ctx.isPreview ? 30 : undefined);
  const now = (Date.now() / 1000) % 3600;

  const pour = (delay = 0) => {
    const silent = ctx.isPreview;
    const gap = ctx.n("stagger");
    task.run(async (sleep) => {
      if (delay > 0) await sleep(delay);
      for (let stage = 0; stage < stages.length; stage++) {
        fill.to(stage, 1, spring(0.6, 0.86));
        if (!silent) haptics.tap("soft");
        if (gap > 0) await sleep(gap);
      }
    });
  };

  /** Tap and autoplay: drain, then fill stage by stage again. */
  const replay = () => {
    fill.toAll(0, anim.easeIn(0.22));
    pour(0.3);
  };

  useChartEntrance(() => pour());
  useAutoplay(ctx.isPreview, replay, { every: 4.6, delay: 4.2, intro: false });

  const progress = fill.all();
  const speed = ctx.n("flow");
  const active = Math.min(Math.max(ctx.i("count"), 0), particles.length);

  const draw = (g: G) => {
    const centerX = g.width / 2;
    // How deep the fill has reached: particles only travel that far.
    let front = 0;
    stages.forEach((_, stage) => {
      const p = clamp01(progress[stage]);
      front = Math.max(front, p > 0.001 ? topOf(stage) + BAND * p : 0);
    });

    stages.forEach((s, stage) => {
      g.fill(bandPath(stage, centerX, BAND), g.primary(0.06));
      const p = Math.min(Math.max(progress[stage], 0), 1.05);
      if (!(p > 0.002)) return;
      const top = topOf(stage);
      g.fill(bandPath(stage, centerX, BAND * p), g.gradient(0, top, 0, top + BAND, s.colors));
    });

    const travel = HEIGHT + 24;
    for (let index = 0; index < active; index++) {
      const particle = particles[index];
      const cycle = (now * 0.3 * speed * particle.speed + particle.phase) % 1;
      const depth = cycle * travel - 12;
      const laneX = (particle.lane * particle.side * TOP_WIDTH) / 2;
      let x = centerX + laneX;
      let y = depth;
      let a = 0.9;
      // Inside the funnel a particle is white; once squeezed out it takes its stage's colour.
      let tint = "#FFFFFF";
      if (particle.hit !== null && depth > particle.hit) {
        const stage = Math.min(Math.max(Math.trunc(particle.hit / (BAND + GAP)), 0), stages.length - 1);
        tint = stages[stage].colors[1];
        const escape = (depth - particle.hit) / 26;
        if (!(escape < 1)) continue;
        x += particle.side * 14 * escape;
        y = particle.hit + (depth - particle.hit) * 0.35;
        a *= 1 - escape;
      }
      // Fade in at the mouth, out at the fill front and at the bottom.
      a *= smoothstep(-12, 2, depth);
      a *= 1 - smoothstep(front - 10, front + 4, y);
      if (!(a > 0.02)) continue;
      g.fill(circle(x, y, 1.7), rgba(tint, a));
    }
  };

  const last = stages.length - 1;
  return (
    <ChartStage ctx={ctx} hint={["Tap to replay the funnel", "点击重播漏斗"]}>
      <div
        onClick={() => {
          haptics.tap("light");
          replay();
        }}
        style={{ ...card(12), cursor: "pointer" }}
      >
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Conversion · last 30 days", "转化漏斗 · 近 30 天")}</div>
          <div style={{ ...sys(13, 700, true), ...mono, color: Palette.coral, padding: "5px 9px", borderRadius: 999, background: alpha(Palette.coral, 0.14) }}>
            {(rate(last) * 100 * progress[last]).toFixed(0)}%
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 14, height: HEIGHT }}>
          <Plot ctx={ctx} width={TOP_WIDTH + 32} height={HEIGHT} draw={draw} />
          <div style={{ display: "flex", flexDirection: "column", gap: GAP, alignItems: "flex-start" }}>
            {stages.map((s, stage) => {
              const p = clamp01(progress[stage]);
              return (
                <div key={stage} style={{ height: BAND, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "flex-start", gap: 1, opacity: 0.35 + 0.65 * p }}>
                  <div style={{ ...sys(10, 600), color: Palette.secondaryLabel }}>{ctx.t(s.en, s.zh)}</div>
                  <div style={{ ...sys(14, 700, true), ...mono }}>{swiftRound(s.count * p).toLocaleString("en-US")}</div>
                  <div style={{ ...sys(10, 700, true), ...mono, color: s.colors[1] }}>{swiftRound(rate(stage) * 100 * p)}%</div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </ChartStage>
  );
}
