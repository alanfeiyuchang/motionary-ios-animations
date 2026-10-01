/** charts.lollipop · 棒棒糖落点与排序 (Charts+Lollipop.swift) */
import { ArrowUpDown } from "lucide-react";
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, alpha, anim, delayed, fonts, spring, springAt, useAutoplay, useElapsed, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, bounceHeight, bounceSquash, card, firstImpact, smoothstep, sys, useChartHaptics, useNums, useTask } from "./_round2";

const items = [
  { code: "US", value: 62, color: Palette.indigo },
  { code: "JP", value: 88, color: Palette.violet },
  { code: "DE", value: 45, color: Palette.pink },
  { code: "FR", value: 73, color: Palette.coral },
  { code: "UK", value: 34, color: Palette.amber },
  { code: "BR", value: 95, color: Palette.mint },
  { code: "IN", value: 56, color: Palette.sky },
  { code: "KR", value: 68, color: Palette.blue },
];

/** Slot of each item when sorted by value, largest first. */
const ranks = (() => {
  const order = items.map((_, i) => i).sort((a, b) => items[b].value - items[a].value);
  const out = items.map(() => 0);
  order.forEach((index, rank) => (out[index] = rank));
  return out;
})();

const PLOT_W = 268;
const PLOT_H = 150;
const DOT = 18;
const SLOT = PLOT_W / items.length;

export default function Lollipop({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const grow = useNums(items.length, 0);
  const drop = useNums(items.length, 0);
  const [order, setOrder] = useState({ sorted: false, animated: true });
  const sortedRef = useRef(false);
  const [sortCount, setSortCount] = useState(0);
  const autoStep = useRef(0);

  const play = () => {
    const stagger = ctx.n("stagger");
    items.forEach((_, index) => {
      const delay = index * stagger;
      grow.to(index, 1, delayed(spring(0.5, 0.8), delay));
      drop.to(index, 1, delayed(anim.linear(0.8), 0.22 + delay));
    });
    if (ctx.isPreview) return;
    // One soft tick per landing.
    const impact = 0.8 * firstImpact(ctx.n("bounce"));
    task.run(async (sleep) => {
      await sleep(0.22 + impact);
      for (let i = 0; i < items.length; i++) {
        haptics.tap("soft");
        await sleep(Math.max(stagger, 0.02));
      }
    });
  };

  const replay = () => {
    task.cancel();
    grow.jumpAll(0);
    drop.jumpAll(0);
    sortedRef.current = false;
    setOrder({ sorted: false, animated: false });
    task.run(async (sleep) => {
      await sleep(0.05);
      play();
    });
  };

  /** The Sort chip and autoplay share this. */
  const toggleSort = () => {
    haptics.selection();
    sortedRef.current = !sortedRef.current;
    setOrder({ sorted: sortedRef.current, animated: true });
    setSortCount((n) => n + 1);
  };

  const autoAdvance = () => {
    autoStep.current += 1;
    if (autoStep.current % 3 === 0) replay();
    else toggleSort();
  };

  useChartEntrance(play);
  useAutoplay(ctx.isPreview, autoAdvance, { every: 2.1, delay: 2.4, intro: false });

  const { sorted } = order;
  const chipSpring = spring(0.4, 0.7);
  return (
    <ChartStage ctx={ctx} hint={["Tap Sort, or the chart to drop again", "点「排序」，或点图表让圆点重新落下"]}>
      <div style={card(8)}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Downloads by region", "各地区下载量")}</div>
            <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t("Thousands · this week", "千次 · 本周")}</div>
          </div>
          <button type="button" onClick={toggleSort} style={{ position: "relative", padding: "7px 11px", borderRadius: 999, overflow: "hidden", background: Palette.labelAlpha(0.08) }}>
            <motion.span
              initial={false}
              animate={{ opacity: sorted ? 1 : 0 }}
              transition={chipSpring}
              style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg, #4B57E0, #7A45D6)" }}
            />
            <motion.span
              initial={false}
              animate={{ color: sorted ? "rgb(255,255,255)" : ctx.scheme === "dark" ? "rgb(255,255,255)" : "rgb(0,0,0)" }}
              transition={chipSpring}
              style={{ position: "relative", display: "flex", alignItems: "center", gap: 4 }}
            >
              <motion.span initial={false} animate={{ rotate: sorted ? 180 : 0 }} transition={chipSpring} style={{ display: "grid" }}>
                <ArrowUpDown size={11} strokeWidth={3} />
              </motion.span>
              <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Sort", "排序")}</span>
            </motion.span>
          </button>
        </div>
        <div
          onClick={() => {
            haptics.tap("light");
            replay();
          }}
          style={{ position: "relative", width: PLOT_W, height: PLOT_H + 18, cursor: "pointer" }}
        >
          <div style={{ position: "absolute", left: 0, bottom: 18, width: PLOT_W, height: 1, background: Palette.labelAlpha(0.14) }} />
          {items.map((item, index) => {
            const position = sorted ? ranks[index] : index;
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{ x: position * SLOT }}
                transition={order.animated ? delayed(spring(ctx.n("response"), 0.74), position * 0.035) : { duration: 0 }}
                style={{ position: "absolute", left: 0, top: 0, width: SLOT, height: PLOT_H + 18 }}
              >
                <Mark item={item} grow={grow.get(index)} drop={drop.get(index)} restitution={ctx.n("bounce")} hop={sortCount} hopDelay={position * 0.035} />
              </motion.div>
            );
          })}
        </div>
      </div>
    </ChartStage>
  );
}

function Mark({ item, grow, drop, restitution, hop, hopDelay }: { item: (typeof items)[number]; grow: number; drop: number; restitution: number; hop: number; hopDelay: number }) {
  const full = (PLOT_H - 30) * (item.value / 100);
  const stem = Math.max(full * grow, 0);
  const height = bounceHeight(drop, restitution);
  const squash = bounceSquash(drop, restitution);
  const fall = height * (PLOT_H - full + 8);
  const labelAlpha = smoothstep(0.7, 1, drop);

  // keyframeAnimator: hold for the rank delay, spring up 12 pt (.snappy, 0.2 s), settle (.bouncy, 0.5 s).
  const e = useElapsed(hop, hopDelay + 0.75, true);
  let lift = 0;
  if (e >= 0) {
    const t = e - hopDelay;
    const peak = -12 * springAt(0.2, 0.5, 0.85);
    if (t > 0 && t <= 0.2) lift = -12 * springAt(t, 0.5, 0.85);
    else if (t > 0.2) lift = peak * (1 - springAt(t - 0.2, 0.5, 0.7));
  }

  return (
    <>
      <div
        style={{
          position: "absolute",
          left: SLOT / 2 - 1.5,
          bottom: 18,
          width: 3,
          height: stem,
          borderRadius: 1.5,
          background: `linear-gradient(to bottom, ${alpha(item.color, 0.75)}, ${alpha(item.color, 0.2)})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 0,
          width: SLOT,
          bottom: 18 + (full - DOT / 2) + fall - lift,
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 2,
          opacity: drop > 0.002 ? 1 : 0,
        }}
      >
        <div style={{ ...sys(10, 700, true), fontVariantNumeric: "tabular-nums", opacity: labelAlpha }}>{item.value}</div>
        <div
          style={{
            width: DOT,
            height: DOT,
            borderRadius: "50%",
            background: `linear-gradient(to bottom, color-mix(in srgb, ${item.color} 82%, white), ${item.color})`,
            boxShadow: `inset 0 0 0 1.5px rgb(255 255 255 / 0.55), 0 3px 10px ${alpha(item.color, 0.45)}`,
            transform: `scale(${1 + squash}, ${1 - squash})`,
            transformOrigin: "50% 100%",
          }}
        />
      </div>
      <div style={{ position: "absolute", left: 0, width: SLOT, bottom: 0, height: 14, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: fonts.text, fontSize: 10, fontWeight: 500, color: Palette.secondaryLabel }}>
        {item.code}
      </div>
    </>
  );
}
