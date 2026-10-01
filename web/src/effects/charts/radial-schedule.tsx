/** charts.radial-schedule · 24 小时环形日程 (Charts+RadialSchedule.swift) */
import { Book, Coffee, Dumbbell, Laptop, Moon, Users, Utensils, type LucideIcon } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef } from "react";
import { Palette, anim, demoCard, spring, useAutoplay, useClock, usePan, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, Crossfade, G, Plot, RGB, circle, mono, smoothstep, sys, useChartHaptics, useNums, useTask, type Pt } from "./_round2";

type Block = { en: string; zh: string; Icon: LucideIcon; filled: boolean; start: number; end: number; rgb: RGB };

/** `end` may exceed 24 for a block that wraps past midnight. */
const blocks: Block[] = [
  { en: "Sleep", zh: "睡眠", Icon: Moon, filled: true, start: 23, end: 31, rgb: RGB.violet },
  { en: "Focus", zh: "专注", Icon: Laptop, filled: false, start: 9, end: 12.5, rgb: RGB.indigo },
  { en: "Lunch", zh: "午餐", Icon: Utensils, filled: false, start: 12.5, end: 13.5, rgb: RGB.amber },
  { en: "Meetings", zh: "会议", Icon: Users, filled: true, start: 13.5, end: 17.5, rgb: RGB.sky },
  { en: "Gym", zh: "健身", Icon: Dumbbell, filled: false, start: 18, end: 19.5, rgb: RGB.coral },
  { en: "Reading", zh: "阅读", Icon: Book, filled: false, start: 20, end: 22.5, rgb: RGB.mint },
];

const contains = (b: Block, hour: number) => (hour >= b.start && hour < b.end) || (hour + 24 >= b.start && hour + 24 < b.end);
/** 0…1: how firmly the hand is inside this block (eases in and out over 0.4 h). */
function weightOf(b: Block, hour: number): number {
  const h = hour >= b.start ? hour : hour + 24;
  if (!(h >= b.start && h <= b.end)) return 0;
  return Math.min(smoothstep(b.start, b.start + 0.4, h), 1 - smoothstep(b.end - 0.4, b.end, h));
}

const DIAL = 236;
const pad2 = (n: number) => String(n).padStart(2, "0");
function clockText(hour: number): string {
  const h = hour >= 24 ? hour - 24 : hour;
  return `${pad2(Math.trunc(h))}:${pad2(Math.trunc((h - Math.floor(h)) * 60 + 0.5))}`;
}

export default function RadialSchedule({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const sweep = useNums(6, 0);
  const grab = useNums(1, 0);
  const anchor = useRef({ hour: 10.4, at: performance.now() / 1000 });
  const dragging = useRef(false);
  const lastBlock = useRef(-2);
  useClock(true, ctx.isPreview ? 30 : undefined);

  const enter = () => {
    const gap = ctx.n("stagger");
    task.run(async (sleep) => {
      for (let step = 0; step < 6; step++) {
        sweep.to(step, 1, spring(0.6, 0.8));
        if (gap > 0) await sleep(gap);
      }
    });
  };

  const replay = () => {
    sweep.toAll(0, anim.easeIn(0.25));
    task.run(async (sleep) => {
      await sleep(0.3);
      enter();
    });
  };

  const scrub = (location: Pt) => {
    const dx = location.x - DIAL / 2;
    const dy = location.y - DIAL / 2;
    if (!(dx * dx + dy * dy > 18 * 18)) return;
    let angle = Math.atan2(dx, -dy) / (2 * Math.PI);
    if (angle < 0) angle += 1;
    const hour = angle * 24;
    if (!dragging.current) {
      dragging.current = true;
      haptics.tap("light");
      grab.to(0, 1, spring(0.3, 0.6));
    }
    const block = blocks.findIndex((b) => contains(b, hour));
    if (block !== lastBlock.current) {
      lastBlock.current = block;
      haptics.selection();
    }
    anchor.current = { hour, at: performance.now() / 1000 };
  };

  const pan = usePan({
    onChange: (s) => scrub(s.location),
    onEnd: () => {
      anchor.current.at = performance.now() / 1000;
      dragging.current = false;
      grab.to(0, 0, spring(0.35, 0.6));
    },
  });

  useChartEntrance(enter);
  useAutoplay(ctx.isPreview, replay, { every: 7, delay: 7, intro: false });

  let hour = anchor.current.hour;
  if (!dragging.current) {
    const raw = anchor.current.hour + (performance.now() / 1000 - anchor.current.at) * ctx.n("speed");
    hour = raw - Math.floor(raw / 24) * 24;
  }
  const thickness = ctx.n("thickness");
  const sw = sweep.all();
  const gr = grab.get();

  const draw = (g: G) => {
    const cx = g.width / 2;
    const cy = g.height / 2;
    const radius = Math.min(g.width, g.height) / 2 - 16;
    const angle = (h: number) => ((h / 24) * 360 - 90) * (Math.PI / 180);
    const point = (h: number, r: number): Pt => ({ x: cx + r * Math.cos(angle(h)), y: cy + r * Math.sin(angle(h)) });

    g.stroke(circle(cx, cy, radius), g.primary(0.07), thickness);

    // Hour ticks and the four cardinal labels, inside the ring.
    const inner = radius - thickness / 2 - 5;
    for (let tick = 0; tick < 24; tick++) {
      const major = tick % 6 === 0;
      const a = point(tick, inner);
      const b = point(tick, inner - (major ? 6 : 3));
      g.line(a.x, a.y, b.x, b.y, g.primary(major ? 0.4 : 0.16), major ? 1.5 : 1, { cap: "round" });
      if (major) {
        const p = point(tick, inner - 15);
        g.text(`${tick}`, p.x, p.y, { size: 10, weight: 600, rounded: true, color: g.secondary(), anchor: "center" });
      }
    }

    blocks.forEach((block, index) => {
      const progress = sw[index];
      if (!(progress > 0.005)) return;
      const weight = weightOf(block, hour);
      const width = Math.max(thickness - 5, 4) + 6 * weight;
      // Round caps add half a line width at each end: pull the arc in so neighbours keep a hairline gap.
      const cap = ((Math.max(thickness - 5, 4) / 2 + 1) / radius / (2 * Math.PI)) * 24;
      const from = block.start + cap;
      const end = from + Math.max(block.end - block.start - cap * 2, 0.01) * progress;
      const arc = new Path2D();
      arc.arc(cx, cy, radius, angle(from), angle(end), false);
      if (weight > 0.01) g.blurred(7, block.rgb.color(0.5 * weight), () => g.stroke(arc, "#000", width, { cap: "round" }));
      g.stroke(arc, block.rgb.color(0.6 + 0.4 * weight), width, { cap: "round" });
    });

    // The "now" hand: hairline, hub and a knob riding the ring.
    const h0 = point(hour, inner - 9);
    const h1 = point(hour, radius + thickness / 2 + 5);
    g.line(h0.x, h0.y, h1.x, h1.y, g.primary(0.85), 2, { cap: "round" });
    const knob = point(hour, radius);
    const knobRadius = thickness / 2 + 1 + 2.5 * gr;
    g.shadowed("rgba(0,0,0,0.3)", 4, 2, () => g.fill(circle(knob.x, knob.y, knobRadius), "#fff"));
    const active = blocks.find((b) => contains(b, hour));
    g.fill(circle(knob.x, knob.y, knobRadius * 0.45), active ? active.rgb.color() : "rgb(153,153,153)");
  };

  const index = blocks.findIndex((b) => contains(b, hour));
  const block = index >= 0 ? blocks[index] : null;
  const minutes = Math.trunc(hour * 60) % 1440;
  const Icon = block ? block.Icon : Coffee;
  const swap = spring(0.35, 0.7);

  return (
    <ChartStage ctx={ctx} hint={["Drag around the ring to move the hand", "沿圆环拖动指针"]}>
      <div style={{ ...demoCard(28), padding: 14 }}>
        <div {...pan} style={{ ...pan.style, position: "relative", width: DIAL, height: DIAL, borderRadius: "50%", cursor: "grab" }}>
          <Plot ctx={ctx} width={DIAL} height={DIAL} draw={draw} bleed={12} style={{ position: "absolute", inset: 0 }} />
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 3, pointerEvents: "none" }}>
            <div style={{ position: "relative", width: 22, height: 22 }}>
              <AnimatePresence initial={false}>
                <motion.div
                  key={index}
                  initial={{ scale: 0.5, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0.5, opacity: 0 }}
                  transition={swap}
                  style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: block ? block.rgb.color() : Palette.secondaryLabel }}
                >
                  <Icon size={19} strokeWidth={2.4} fill={block?.filled || !block ? "currentColor" : "none"} />
                </motion.div>
              </AnimatePresence>
            </div>
            <div style={{ ...sys(30, 700, true), ...mono }}>
              {pad2(Math.trunc(minutes / 60))}:{pad2(minutes % 60)}
            </div>
            <Crossfade id={index} transition={swap} style={{ ...sys(13, 600), color: Palette.secondaryLabel }}>
              {block ? ctx.t(block.en, block.zh) : ctx.t("Free time", "空闲")}
            </Crossfade>
            <Crossfade id={index} transition={swap} style={{ ...sys(11, 500, true), ...mono, color: Palette.tertiaryLabel, minHeight: 13 }}>
              {block ? `${clockText(block.start)} – ${clockText(block.end)}` : " "}
            </Crossfade>
          </div>
        </div>
      </div>
    </ChartStage>
  );
}
