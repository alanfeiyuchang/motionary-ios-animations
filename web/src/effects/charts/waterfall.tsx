/** charts.waterfall · 瀑布图搭建 (Charts+Waterfall.swift) */
import { ArrowDownRight, ArrowUpRight } from "lucide-react";
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, anim, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, bounceHeight, bounceSquash, card, captionSecondary, firstImpact, mono, rrect, signed, smoothstep, swiftRound, sys, useChartHaptics, useNums, useTask, type Sleep } from "./_round2";

type Step = { en: string; zh: string; amount: number; isTotal: boolean };
type WaterfallSet = { en: string; zh: string; steps: Step[] };

const sets: WaterfallSet[] = [
  {
    en: "Net cash · Q3",
    zh: "净现金流 · Q3",
    steps: [
      { en: "Open", zh: "期初", amount: 420, isTotal: true },
      { en: "Sales", zh: "销售", amount: 180, isTotal: false },
      { en: "Service", zh: "服务", amount: 90, isTotal: false },
      { en: "Costs", zh: "成本", amount: -150, isTotal: false },
      { en: "Tax", zh: "税费", amount: -60, isTotal: false },
      { en: "Other", zh: "其他", amount: 40, isTotal: false },
      { en: "Close", zh: "期末", amount: 0, isTotal: true },
    ],
  },
  {
    en: "Net cash · Q4",
    zh: "净现金流 · Q4",
    steps: [
      { en: "Open", zh: "期初", amount: 520, isTotal: true },
      { en: "Sales", zh: "销售", amount: 130, isTotal: false },
      { en: "Refund", zh: "退款", amount: -80, isTotal: false },
      { en: "Costs", zh: "成本", amount: -190, isTotal: false },
      { en: "Grants", zh: "补贴", amount: 110, isTotal: false },
      { en: "Tax", zh: "税费", amount: -50, isTotal: false },
      { en: "Close", zh: "期末", amount: 0, isTotal: true },
    ],
  },
];

/** Level before and after each step. */
function levelsOf(set: WaterfallSet) {
  let running = 0;
  return set.steps.map((step) => {
    if (step.isTotal) {
      if (running === 0) running = step.amount;
      return { before: 0, after: running };
    }
    const before = running;
    running += step.amount;
    return { before, after: running };
  });
}

const BAR = 22;
const DROP = 54;

export default function Waterfall({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const grow = useNums(7, 0);
  const link = useNums(6, 0);
  const shown = useNums(1, 0);
  const [setIndex, setSetIndex] = useState(0);
  const setRef = useRef(0);
  const [finished, setFinished] = useState(false);

  const data = sets[setIndex];
  const levels = levelsOf(data);

  const steps = async (sleep: Sleep) => {
    const stagger = ctx.n("stagger");
    const response = ctx.n("response");
    const lv = levelsOf(sets[setRef.current]);
    const last = lv.length - 1;
    for (let index = 0; index < lv.length; index++) {
      if (index === last) {
        // The closing total falls and bounces: linear time, the plot maps it through the bounce curve.
        grow.to(index, 1, anim.linear(0.75));
        await sleep(0.75 * firstImpact(ctx.n("bounce")));
        haptics.success();
        setFinished(true);
      } else {
        grow.to(index, 1, spring(response, 0.78));
        shown.to(0, lv[index].after, anim.easeOut(Math.max(response, 0.2)));
        haptics.tap("soft");
        await sleep(stagger * 0.56);
        link.to(index, 1, anim.easeOut(0.14));
        await sleep(stagger * 0.44);
      }
    }
  };

  /** Tap and autoplay: fold the chart away, switch dataset, build again. */
  const rebuild = () => {
    haptics.tap("light");
    grow.toAll(0, anim.easeIn(0.2));
    link.toAll(0, anim.easeIn(0.2));
    setFinished(false);
    task.run(async (sleep) => {
      await sleep(0.26);
      setRef.current = (setRef.current + 1) % sets.length;
      setSetIndex(setRef.current);
      shown.jump(0, 0);
      await sleep(0.05);
      await steps(sleep);
    });
  };

  useChartEntrance(() => task.run(steps));
  useAutoplay(ctx.isPreview, rebuild, { every: 4.4, delay: 3.6, intro: false });

  const net = levels[levels.length - 1].after - levels[0].after;
  const tint = net >= 0 ? Palette.green : Palette.red;
  const restitution = ctx.n("bounce");
  const showLinks = ctx.b("links");
  const g = grow.all();
  const l = link.all();

  const draw = (cv: G) => {
    const top = Math.max(...levels.map((x) => Math.max(x.before, x.after))) * 1.16;
    const plot = { x: 0, y: 16, w: cv.width, h: cv.height - 16 - 20 };
    const maxY = plot.y + plot.h;
    const slot = plot.w / data.steps.length;
    const y = (value: number) => maxY - plot.h * (value / top);

    for (let line = 0; line <= 2; line++) {
      const lineY = maxY - (plot.h * line) / 2.4;
      cv.line(0, lineY, plot.w, lineY, cv.primary(line === 0 ? 0.16 : 0.06), 1);
    }

    data.steps.forEach((step, index) => {
      const level = levels[index];
      const gi = g[index];
      const centerX = slot * (index + 0.5);
      const left = centerX - BAR / 2;
      let rect: { x: number; y: number; w: number; h: number };
      let a = 1;
      const isLast = index === data.steps.length - 1;

      if (step.isTotal && isLast) {
        const fall = bounceHeight(gi, restitution) * DROP;
        const squash = bounceSquash(gi, restitution);
        const height = (maxY - y(level.after)) * (1 - squash);
        rect = { x: left - (BAR * squash) / 2, y: maxY - height - fall, w: BAR * (1 + squash), h: height };
        a = Math.min(Math.max(gi * 8, 0), 1);
      } else if (step.isTotal) {
        const height = (maxY - y(level.after)) * Math.max(gi, 0);
        rect = { x: left, y: maxY - height, w: BAR, h: height };
      } else {
        const from = y(level.before);
        const to = from + (y(level.after) - from) * gi;
        rect = { x: left, y: Math.min(from, to), w: BAR, h: Math.abs(to - from) };
      }

      if (rect.h > 0.5 && a > 0.01) {
        const colors = step.isTotal ? [Palette.violet, Palette.indigo] : step.amount >= 0 ? [Palette.mint, Palette.green] : [Palette.coral, Palette.red];
        cv.fill(rrect(rect.x, rect.y, rect.w, rect.h, Math.min(5, rect.h / 2)), cv.gradient(0, rect.y, 0, rect.y + rect.h, colors), a);
      }

      // Value: totals above the bar, deltas on the far side of their travel.
      const labelAlpha = smoothstep(0.45, 0.95, gi) * a;
      if (labelAlpha > 0.01) {
        const font = { size: 10, weight: 700, rounded: true, alpha: labelAlpha };
        if (step.isTotal) cv.text(`${swiftRound(level.after)}`, centerX, rect.y - 3, { ...font, color: cv.primary(), anchor: "bottom" });
        else if (step.amount >= 0) cv.text(signed(step.amount), centerX, rect.y - 3, { ...font, color: Palette.green, anchor: "bottom" });
        else cv.text(signed(step.amount).replace("-", "−"), centerX, rect.y + rect.h + 3, { ...font, color: Palette.red, anchor: "top" });
      }

      cv.text(ctx.t(step.en, step.zh), centerX, maxY + 6, { size: 10, weight: 500, color: cv.secondary(), anchor: "top" });

      if (showLinks && index < data.steps.length - 1) {
        const progress = Math.min(Math.max(l[index], 0), 1);
        if (progress > 0.01) {
          const lineY = y(level.after);
          const startX = centerX + BAR / 2 + 1;
          const endX = centerX + slot - BAR / 2 - 1;
          cv.line(startX, lineY, startX + (endX - startX) * progress, lineY, cv.primary(0.42), 1, { cap: "round", dash: [2.5, 2.5] });
        }
      }
    });
  };

  const Arrow = net >= 0 ? ArrowUpRight : ArrowDownRight;
  return (
    <ChartStage ctx={ctx} hint={["Tap to rebuild with new figures", "点击用新数据重新搭建"]}>
      <div onClick={rebuild} style={{ ...card(10), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t(data.en, data.zh)}</div>
            <div style={{ ...sys(26, 700, true), ...mono }}>${swiftRound(shown.get())}k</div>
          </div>
          <motion.div
            initial={false}
            animate={{ scale: finished ? 1 : 0.4, opacity: finished ? 1 : 0 }}
            transition={finished ? spring(0.4, 0.6) : anim.easeIn(0.2)}
            style={{ display: "flex", alignItems: "center", gap: 3, padding: "5px 9px", borderRadius: 999, background: alpha(tint, 0.14), color: tint, ...sys(13, 600, true), ...mono }}
          >
            <Arrow size={11} strokeWidth={3} />
            <span>{signed(net)}</span>
          </motion.div>
        </div>
        <Plot ctx={ctx} width={268} height={178} draw={draw} />
      </div>
    </ChartStage>
  );
}
