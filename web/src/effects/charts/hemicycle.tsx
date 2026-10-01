/** charts.hemicycle · 议会席位扫描 (Charts+Hemicycle.swift) */
import { useMemo, useRef, useState } from "react";
import { NumericText, Palette, anim, fonts, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, backOut, captionSecondary, card, circle, clamp01, mono, smoothstep, stagger, swiftRound, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

const parties = [
  { en: "Left", zh: "左翼", rgb: RGB.coral },
  { en: "Greens", zh: "绿党", rgb: RGB.green },
  { en: "Centre", zh: "中间派", rgb: RGB.amber },
  { en: "Right", zh: "右翼", rgb: RGB.indigo },
];
const shares = [
  [0.3, 0.13, 0.2, 0.37],
  [0.42, 0.17, 0.14, 0.27],
  [0.22, 0.09, 0.17, 0.52],
];

/** Unit positions (centre at 0,0; outer radius 1; y up), sorted left to right along the arc. */
function makeLayout(rows: number) {
  const count = Math.min(Math.max(rows, 3), 6);
  const inner = 0.44;
  const gap = (1 - inner) / (count - 1);
  const pitch = gap * 0.8;
  const all: { point: Pt; sweep: number }[] = [];
  for (let row = 0; row < count; row++) {
    const radius = 1 - row * gap;
    const n = Math.max(swiftRound((Math.PI * radius) / pitch), 3);
    for (let seat = 0; seat < n; seat++) {
      const fraction = (seat + 0.5) / n;
      const theta = Math.PI * (1 - fraction);
      all.push({ point: { x: radius * Math.cos(theta), y: radius * Math.sin(theta) }, sweep: fraction });
    }
  }
  // Swift's sort is not stable in general, but equal sweeps only occur across rows at 0.5.
  const seats = all.map((s, i) => ({ ...s, i })).sort((a, b) => a.sweep - b.sweep || a.i - b.i);
  const counts = (share: number[]) => {
    const out = share.map((s) => swiftRound(s * seats.length));
    const last = out.length - 1;
    out[last] = seats.length - out.slice(0, last).reduce((a, b) => a + b, 0);
    return out;
  };
  /** Party index per seat, in sweep order. */
  const assignment = (share: number[]) => {
    const out: number[] = [];
    counts(share).forEach((n, party) => {
      for (let k = 0; k < Math.max(n, 0); k++) out.push(party);
    });
    while (out.length < seats.length) out.push(share.length - 1);
    return out.slice(0, seats.length);
  };
  return { seats, dot: gap * 0.66, counts, assignment };
}

const FRONT = 0.68;
const SPAN = 0.32;

export default function Hemicycle({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const wave = useNums(1, 0);
  const [state, setState] = useState({ from: -1, to: 0 });
  const stateRef = useRef(state);
  const rows = ctx.i("rows");
  const layout = useMemo(() => makeLayout(rows), [rows]);

  const next = () => {
    haptics.tap("light");
    const duration = ctx.n("duration");
    const s = { from: stateRef.current.to, to: (stateRef.current.to + 1) % shares.length };
    stateRef.current = s;
    setState(s);
    wave.jump(0, 0);
    const leader = Math.max(...layout.counts(shares[s.to]));
    const majority = Math.trunc(layout.seats.length / 2) + 1;
    task.run(async (sleep) => {
      await sleep(0.03);
      wave.to(0, 1, anim.linear(duration));
      await sleep(duration);
      if (ctx.isPreview || leader < majority) return;
      haptics.success();
    });
  };

  useChartEntrance(() => wave.to(0, 1, anim.linear(ctx.n("duration"))));
  useAutoplay(ctx.isPreview, next, { every: 2.4, delay: 2.2 });

  const { from, to } = state;
  const w = clamp01(wave.get());
  const toCounts = layout.counts(shares[to]);
  const fromCounts = from >= 0 ? layout.counts(shares[from]) : [0, 0, 0, 0];
  const fromSeats = from >= 0 ? layout.assignment(shares[from]) : null;
  const toSeats = layout.assignment(shares[to]);
  const overshoot = ctx.n("overshoot");
  // A party's wedge has moved once the beam passed its borders; rolling with the wave is close enough.
  const count = (party: number) => fromCounts[party] + (toCounts[party] - fromCounts[party]) * smoothstep(0.05, 0.95, wave.get());
  let leader = 0;
  toCounts.forEach((n, i) => {
    if (n > toCounts[leader]) leader = i;
  });
  const year = 2017 + to * 4;
  const majority = Math.trunc(layout.seats.length / 2) + 1;

  const draw = (g: G) => {
    const radius = Math.min(g.width / 2, g.height) - 14;
    const ox = g.width / 2;
    const oy = g.height - 8;
    const dot = layout.dot * radius;

    // The beam at the front of the sweep.
    const beam = Math.sin(Math.PI * w);
    if (beam > 0.01) {
      const theta = Math.PI * (1 - Math.min(w / FRONT, 1));
      const ray = new Path2D();
      ray.moveTo(ox + radius * 0.34 * Math.cos(theta), oy - radius * 0.34 * Math.sin(theta));
      ray.lineTo(ox + (radius + 10) * Math.cos(theta), oy - (radius + 10) * Math.sin(theta));
      g.blurred(5, g.primary(0.28 * beam), () => g.stroke(ray, "#000", 6, { cap: "round" }));
    }

    layout.seats.forEach((seat, index) => {
      const local = stagger(w, seat.sweep * FRONT, SPAN);
      const cx = ox + radius * seat.point.x;
      const cy = oy - radius * seat.point.y;
      const target = parties[toSeats[index]].rgb;
      let scale: number;
      let colour: string;
      if (fromSeats) {
        const previous = parties[fromSeats[index]].rgb;
        if (fromSeats[index] === toSeats[index]) {
          scale = 1;
          colour = target.color();
        } else {
          scale = 1 + 0.35 * Math.sin(Math.PI * local);
          colour = previous.mixed(target, smoothstep(0.15, 0.7, local)).color();
        }
      } else {
        g.fill(circle(cx, cy, dot / 2), g.primary(0.07));
        scale = local <= 0 ? 0 : backOut(local, overshoot);
        colour = target.color();
      }
      if (!(scale > 0.01)) return;
      g.fill(circle(cx, cy, (dot * scale) / 2), colour);
    });

    // Majority line.
    g.line(ox, oy - radius * 0.36, ox, oy - radius - 12, g.primary(0.5), 1.2, { cap: "round", dash: [3, 3] });
  };

  const zh = ctx.lang === "zh";
  return (
    <ChartStage ctx={ctx} hint={["Tap for the next election result", "点击查看下一次选举结果"]}>
      <div onClick={next} style={{ ...card(12), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Parliament", "议会席位")}</div>
            <div style={{ display: "flex", fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 700, whiteSpace: "pre", ...mono }}>
              <NumericText value={year} />
              <span>{zh ? " 年大选" : " election"}</span>
            </div>
          </div>
          <div style={{ ...sys(12, 600), ...mono, color: Palette.secondaryLabel, padding: "5px 9px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
            {zh ? `过半需 ${majority} 席` : `${majority} for a majority`}
          </div>
        </div>
        <div style={{ position: "relative", width: 268, height: 150 }}>
          <Plot ctx={ctx} width={268} height={150} draw={draw} bleed={12} style={{ position: "absolute", inset: 0 }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: -2, display: "flex", flexDirection: "column", alignItems: "center" }}>
            <div style={{ ...sys(30, 700, true), ...mono, color: parties[leader].rgb.mixed(RGB.black, 0.05).color() }}>{swiftRound(count(leader))}</div>
            <div style={{ ...sys(11, 600), color: Palette.secondaryLabel }}>{ctx.t(parties[leader].en, parties[leader].zh)}</div>
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", width: 268 }}>
          {parties.map((party, index) => (
            <div key={index} style={{ display: "flex", alignItems: "center", gap: 4 }}>
              <span style={{ width: 7, height: 7, borderRadius: "50%", background: party.rgb.color() }} />
              <span style={{ ...sys(11, 500), color: Palette.secondaryLabel }}>{ctx.t(party.en, party.zh)}</span>
              <span style={{ ...sys(11, 700, true), ...mono }}>{swiftRound(count(index))}</span>
            </div>
          ))}
        </div>
      </div>
    </ChartStage>
  );
}
