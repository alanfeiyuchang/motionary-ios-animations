/** charts.bar-drilldown · 柱状图下钻 (Charts+BarDrilldown.swift) */
import { ChevronRight, Maximize2, Minimize2 } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, anim, localPoint, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, Crossfade, G, Plot, RGB, captionSecondary, card, clamp01, lerp, mono, rrect, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask } from "./_round2";

const months = [
  [42, 38, 51],
  [55, 61, 48],
  [66, 72, 59],
  [58, 80, 91],
];
const monthNamesEN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const totalOf = (quarter: number) => months[quarter].reduce((a, b) => a + b, 0);
const yearTotal = [0, 1, 2, 3].reduce((sum, q) => sum + totalOf(q), 0);

const PLOT_W = 268;
const QUARTER_W = 34;
const MONTH_W = 44;
const OVERVIEW_TOP = 260;
const SLIDE = 26;
/** Room on the left for the grid values. */
const INSET = 16;

export default function BarDrilldown({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const grow = useNums(4, 0);
  const open = useNums(3, 0);
  /** 0 away, 1 rolling figure. */
  const v = useNums(2, 0);
  const [selected, setSelected] = useState(2);
  const [drilled, setDrilled] = useState(false);
  const drilledRef = useRef(false);
  const autoStep = useRef(0);

  const enter = () => {
    v.to(1, yearTotal, anim.easeOut(0.8));
    task.run(async (sleep) => {
      for (let step = 0; step < 4; step++) {
        grow.to(step, 1, spring(0.5, 0.72));
        await sleep(0.08);
      }
    });
  };

  const drill = (quarter: number) => {
    haptics.tap("light");
    const response = ctx.n("response");
    const damping = ctx.n("damping");
    const stagger = ctx.n("stagger");
    setSelected(quarter);
    grow.jumpAll(1);
    open.jumpAll(0);
    v.to(0, 1, anim.easeOut(0.3));
    drilledRef.current = true;
    setDrilled(true);
    v.to(1, totalOf(quarter), anim.easeInOut(0.5));
    task.run(async (sleep) => {
      await sleep(0.12);
      for (let step = 0; step < 3; step++) {
        // The top segment leaves first.
        open.to(2 - step, 1, spring(response, damping));
        if (!ctx.isPreview) haptics.tap("soft");
        if (stagger > 0) await sleep(stagger);
      }
    });
  };

  const collapse = () => {
    haptics.tap("light");
    const response = ctx.n("response");
    const stagger = ctx.n("stagger");
    drilledRef.current = false;
    setDrilled(false);
    v.to(1, yearTotal, anim.easeInOut(0.5));
    task.run(async (sleep) => {
      for (let step = 0; step < 3; step++) {
        open.to(step, 0, spring(response * 0.9, 0.86));
        if (stagger > 0) await sleep(stagger);
      }
      await sleep(0.1);
      v.to(0, 0, spring(0.45, 0.82));
    });
  };

  const tap = (e: React.MouseEvent<HTMLDivElement>) => {
    if (drilledRef.current) collapse();
    else drill(Math.min(Math.max(Math.trunc((localPoint(e, e.currentTarget).x - INSET) / ((PLOT_W - INSET) / 4)), 0), 3));
  };

  const auto = () => {
    if (drilledRef.current) collapse();
    else {
      drill([2, 0, 3, 1][autoStep.current % 4]);
      autoStep.current += 1;
    }
  };

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, auto, { every: 2.0, delay: 1.6 });

  const gr = grow.all();
  const op = open.all();
  const away = v.get(0);

  const draw = (g: G) => {
    const plot = { y: 18, w: g.width, h: g.height - 18 - 20 };
    const maxY = plot.y + plot.h;
    const sel = months[selected];
    const detailTop = Math.max(...sel) * 1.22;
    const mix = clamp01(away);
    const zoom = (op[0] + op[1] + op[2]) / 3;
    const top = OVERVIEW_TOP + (detailTop - OVERVIEW_TOP) * clamp01(zoom);

    // Two grid scales share the interpolated top, so the lines travel as the scale re-fits.
    const rule = (value: number, a: number) => {
      const lineY = maxY - plot.h * (value / top);
      if (!(lineY > plot.y - 12 && a > 0.01)) return;
      g.line(0, lineY, plot.w, lineY, g.primary(0.07 * a), 1);
      g.text(`${value}`, 0, lineY - 2, { size: 9, weight: 500, color: g.secondary(0.8), anchor: "bottomLeading", alpha: a });
    };
    const detailAlpha = clamp01(zoom);
    for (const value of [100, 200]) rule(value, 1 - detailAlpha);
    for (const value of [25, 50, 75]) rule(value, detailAlpha);
    g.line(0, maxY, plot.w, maxY, g.primary(0.16), 1);

    const slot = (plot.w - INSET) / 4;
    const shades = [RGB.indigo, RGB.indigo.mixed(RGB.violet, 0.5), RGB.violet];
    const fill = (x: number, y: number, w: number, h: number, radius: number, tone: RGB) => {
      if (!(h > 0.5)) return;
      g.fill(rrect(x, y, w, h, radius), g.gradient(0, y, 0, y + h, [tone.mixed(RGB.white, 0.18).color(), tone.color()]));
    };
    const label = (text: string, x: number, y: number, a: number, bold: boolean, atTop = false) => {
      if (!(a > 0.01)) return;
      g.text(text, x, y, { size: 10, weight: bold ? 700 : 500, rounded: bold, color: bold ? g.primary() : g.secondary(), anchor: atTop ? "top" : "bottom", alpha: Math.min(a, 1) });
    };

    for (let quarter = 0; quarter < 4; quarter++) {
      const centerX = INSET + slot * (quarter + 0.5);
      const gq = Math.max(gr[quarter], 0);
      if (quarter !== selected) {
        const direction = quarter < selected ? -1 : 1;
        g.layer(
          () => {
            g.c.translate(direction * SLIDE * mix, 0);
            let bottom = maxY;
            for (let month = 0; month < 3; month++) {
              const height = plot.h * (months[quarter][month] / OVERVIEW_TOP) * gq;
              const h = Math.max(height - 1, 0);
              fill(centerX - QUARTER_W / 2, bottom - height + 1, QUARTER_W, h, Math.min(3, h / 2), shades[month]);
              bottom -= height;
            }
            label(`${totalOf(quarter)}`, centerX, bottom - 3, Math.min(gq, 1), true);
            label(`Q${quarter + 1}`, centerX, maxY + 6, 1, false, true);
          },
          { alpha: 1 - mix },
        );
        continue;
      }

      let stacked = 0;
      for (let month = 0; month < 3; month++) {
        const value = sel[month];
        const p = op[month];
        const fromHeight = plot.h * (value / OVERVIEW_TOP) * gq;
        const fromBottom = maxY - plot.h * (stacked / OVERVIEW_TOP) * gq;
        const toHeight = plot.h * (value / detailTop);
        const toCenter = INSET + ((plot.w - INSET) / 3) * (month + 0.5);
        const width = lerp(QUARTER_W, MONTH_W, p);
        const midX = lerp(centerX, toCenter, p);
        const height = Math.max(lerp(fromHeight - 1, toHeight, p), 0);
        const bottom = lerp(fromBottom, maxY, p);
        const radius = Math.min(lerp(3, 6, clamp01(p)), height / 2);
        fill(midX - width / 2, bottom - height, width, height, radius, shades[month]);
        const shownAlpha = smoothstep(0.55, 1, p);
        label(`${value}`, midX, bottom - height - 3, shownAlpha, true);
        const name = ctx.lang === "zh" ? `${selected * 3 + month + 1}月` : monthNamesEN[selected * 3 + month];
        label(name, midX, maxY + 6, shownAlpha, false, true);
        stacked += value;
      }
      const closed = 1 - smoothstep(0, 0.35, Math.max(op[0], op[1], op[2]));
      const topY = maxY - plot.h * (stacked / OVERVIEW_TOP) * gq;
      label(`${stacked}`, centerX, topY - 3, closed * Math.min(gq, 1), true);
      label(`Q${quarter + 1}`, centerX, maxY + 6, closed, false, true);
    }
  };

  const chip = spring(0.4, 0.8);
  const Icon = drilled ? Minimize2 : Maximize2;
  return (
    <ChartStage ctx={ctx} hint={["Tap a bar to drill in, tap again to go back", "点击柱子下钻，再点一次返回"]}>
      <div style={card(10)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={{ ...captionSecondary, display: "flex", alignItems: "center", gap: 4, height: 16 }}>
              <span>{ctx.t("Sales 2025", "2025 销售额")}</span>
              <AnimatePresence initial={false}>
                {drilled && (
                  <motion.span key="chev" initial={{ opacity: 0, x: -6 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -6 }} transition={chip} style={{ display: "grid" }}>
                    <ChevronRight size={9} strokeWidth={3.5} />
                  </motion.span>
                )}
                {drilled && (
                  <motion.span key="q" initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0, x: -8 }} transition={chip} style={{ color: Palette.indigo }}>
                    Q{selected + 1}
                  </motion.span>
                )}
              </AnimatePresence>
            </div>
            <div style={{ ...sys(26, 700, true), ...mono }}>${swiftRound(v.get(1))}k</div>
          </div>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 3,
              padding: "5px 9px",
              borderRadius: 999,
              ...sys(12, 600),
              color: drilled ? Palette.indigo : Palette.secondaryLabel,
              background: drilled ? alpha(Palette.indigo, 0.14) : Palette.labelAlpha(0.06),
              transition: "color 0.3s, background 0.3s",
            }}
          >
            <Crossfade id={drilled ? "in" : "out"} symbol>
              <Icon size={10} strokeWidth={3} />
            </Crossfade>
            <Crossfade id={drilled ? "m" : "q"} align="start">
              {drilled ? ctx.t("Months", "月份") : ctx.t("Quarters", "季度")}
            </Crossfade>
          </div>
        </div>
        <div onClick={tap} style={{ width: PLOT_W, height: 178, cursor: "pointer" }}>
          <Plot ctx={ctx} width={PLOT_W} height={178} draw={draw} />
        </div>
      </div>
    </ChartStage>
  );
}
