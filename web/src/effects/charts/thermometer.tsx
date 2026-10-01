/** charts.thermometer · 目标温度计 (Charts+Thermometer.swift) */
import { BadgeCheck, Flame } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, demoCard, spring, useAutoplay, useClock, type DemoProps } from "../../kit";
import { ChartStage, G, Plot, RGB, backOut, captionSecondary, chartHash, circle, mono, rgba, rrect, smoothstep, swiftRound, sys, useChartHaptics } from "./_round2";

/** Warm all the way up (red → coral → amber), turning green only over the last stretch to the goal. */
function toneOf(level: number): RGB {
  const warm = RGB.red.mixed(RGB.coral, smoothstep(0, 0.4, level)).mixed(RGB.amber, smoothstep(0.35, 0.85, level));
  return warm.mixed(RGB.green, smoothstep(0.88, 1, level));
}

const milestones = [0.25, 0.5, 0.75, 1];
const GOAL = 10000;
const chunks = [0.16, 0.12, 0.14, 0.2];
const DISTANT_PAST = -1e9;

class Model {
  level: number;
  velocity = 0;
  target: number;
  shown: number;
  ripple = 0;
  last: number | null = null;
  /** When each milestone (25/50/75/100%) lit up; `null` while the liquid is below it. */
  lit: (number | null)[];
  burst: number | null = null;

  constructor(level: number) {
    this.level = level;
    this.target = level;
    this.shown = level;
    this.lit = milestones.map((m) => (level >= m ? DISTANT_PAST : null));
  }

  step(now: number, damping: number, onMilestone: (index: number) => void) {
    const dt = Math.min(Math.max(now - (this.last ?? now), 0), 1 / 30);
    this.last = now;
    if (!(dt > 0)) return;
    const omega = 9.5;
    // Two half steps keep the under-damped spring stable at 30 fps.
    for (let k = 0; k < 2; k++) {
      const h = dt / 2;
      const acceleration = omega * omega * (this.target - this.level) - 2 * damping * omega * this.velocity;
      this.velocity += acceleration * h;
      this.level += this.velocity * h;
    }
    this.ripple = Math.max(this.ripple * Math.exp(-dt * 2.4), Math.min(Math.abs(this.velocity) * 2.6, 1));
    this.shown += (this.target - this.shown) * (1 - Math.exp(-dt * 6));
    milestones.forEach((mark, index) => {
      if (this.lit[index] === null && this.level >= mark) {
        this.lit[index] = now;
        if (index === 3) this.burst = now;
        onMilestone(index);
      } else if (this.lit[index] !== null && this.level < mark - 0.03) {
        this.lit[index] = null;
      }
    });
  }
}

function grouped(value: number): string {
  const number = swiftRound(value);
  const thousands = Math.trunc(number / 1000);
  return thousands > 0 ? `${thousands},${String(number % 1000).padStart(3, "0")}` : `${number}`;
}

export default function Thermometer({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const modelRef = useRef<Model | null>(null);
  if (!modelRef.current) modelRef.current = new Model(0.62);
  const model = modelRef.current;
  const [gift, setGift] = useState({ gifts: 0, last: 0 });
  const giftRef = useRef(gift);
  const frame = useClock(true, ctx.isPreview ? 30 : undefined);
  const lastFrame = useRef(-1);
  const now = performance.now() / 1000;
  if (frame !== lastFrame.current) {
    lastFrame.current = frame;
    model.step(now, ctx.n("damping"), (index) => {
      if (ctx.isPreview) return;
      if (index === 3) haptics.success();
      else haptics.tap("rigid");
    });
  }

  /** Tap and autoplay: one more donation, or a fresh round once the goal has been reached. */
  const donate = () => {
    haptics.tap("light");
    const g = giftRef.current;
    let last = 0;
    if (model.target >= 0.999) {
      model.target = 0.14;
    } else {
      const next = Math.min(model.target + chunks[g.gifts % chunks.length], 1);
      last = swiftRound((next - model.target) * GOAL);
      model.target = next;
    }
    giftRef.current = { gifts: g.gifts + 1, last };
    setGift(giftRef.current);
  };
  useAutoplay(ctx.isPreview, donate, { every: 1.5, delay: 0.8 });

  const wave = ctx.n("wave");
  const confetti = ctx.i("confetti");

  const draw = (g: G) => {
    const c = g.c;
    const time = (Date.now() / 1000) % 100000;
    const tubeWidth = 30;
    const bulbRadius = 27;
    const midX = 44;
    const bulbY = g.height - bulbRadius - 6;
    const tubeTop = 16;
    const goalY = tubeTop + 16;
    const zeroY = bulbY - bulbRadius + 6;
    const surface = (level: number) => zeroY + (goalY - zeroY) * level;

    const glass = (inset: number) => {
      const path = new Path2D();
      const w = tubeWidth - inset * 2;
      path.roundRect(midX - w / 2, tubeTop + inset, w, bulbY - tubeTop - inset, w / 2);
      const r = bulbRadius - inset;
      path.moveTo(midX + r, bulbY);
      path.arc(midX, bulbY, r, 0, Math.PI * 2);
      return path;
    };

    const level = Math.min(Math.max(model.level, -0.05), 1.12);
    const tone = toneOf(level);
    g.fill(glass(0), g.primary(0.07));

    // Liquid: a rectangle with a wavy top edge, clipped to the inside of the glass.
    const top = surface(level);
    const amplitude = wave * model.ripple;
    const liquid = new Path2D();
    const left = midX - bulbRadius;
    const right = midX + bulbRadius;
    liquid.moveTo(left, g.height);
    for (let x = left; x <= right; x += 2) {
      const offset = amplitude * Math.sin(x * 0.42 + time * 9) + amplitude * 0.4 * Math.sin(x * 0.9 - time * 13);
      liquid.lineTo(x, top + offset);
    }
    liquid.lineTo(right, g.height);
    liquid.closePath();
    g.layer(
      () => {
        g.fill(liquid, g.gradient(0, top, 0, g.height, [tone.mixed(RGB.white, 0.25).color(), tone.color(), tone.mixed(RGB.black, 0.18).color()]));
        for (let bubble = 0; bubble < 5; bubble++) {
          const travel = zeroY + 30 - top;
          if (!(travel > 12)) continue;
          const phase = (time * (0.16 + 0.05 * bubble) + chartHash(bubble, 3)) % 1;
          const bx = midX + (chartHash(bubble, 5) - 0.5) * 12 + Math.sin(time * 2 + bubble) * 1.5;
          const by = zeroY + 30 - travel * phase;
          g.fill(circle(bx, by, 1.2 + chartHash(bubble, 9) * 1.4), `rgba(255,255,255,${0.4 * Math.sin(Math.PI * phase)})`);
        }
      },
      { clip: glass(4) },
    );

    // Glass: rim and a specular strip.
    g.stroke(glass(0.5), g.primary(0.14), 1);
    g.line(midX - 7, tubeTop + 12, midX - 7, bulbY - bulbRadius - 2, "rgba(255,255,255,0.45)", 2.5, { cap: "round" });
    g.fill(circle(midX - 10.5, bulbY - 10.5, 4.5), "rgba(255,255,255,0.45)");

    // Milestones.
    milestones.forEach((mark, index) => {
      const markY = surface(mark);
      const litAt = model.lit[index];
      const on = litAt !== null;
      const pop = litAt !== null ? backOut(Math.min((now - litAt) / 0.35, 1), 3) : 0;
      g.line(midX + tubeWidth / 2 + 4, markY, midX + tubeWidth / 2 + 10 + 4 * Math.min(pop, 1), markY, on ? tone.color() : g.primary(0.25), on ? 2.5 : 1.5, { cap: "round" });
      c.save();
      c.translate(midX + tubeWidth / 2 + 20, markY);
      const scale = on ? 0.7 + 0.3 * pop : 0.9;
      c.scale(scale, scale);
      const color = on ? g.primary() : g.secondary(0.8);
      const font = { size: 11, weight: on ? 700 : 500, rounded: true, color, anchor: "leading" as const };
      if (index === 3) {
        // flag.fill
        const flag = new Path2D();
        flag.moveTo(1.5, -4.6);
        flag.bezierCurveTo(4, -6.2, 6.2, -3.2, 9.4, -4.6);
        flag.lineTo(9.4, 1.4);
        flag.bezierCurveTo(6.2, 2.8, 4, -0.2, 1.5, 1.4);
        flag.closePath();
        g.fill(flag, color);
        g.line(1.5, -4.8, 1.5, 5, color, 1.4, { cap: "round" });
        g.text("100%", 13.5, 0, font);
      } else g.text(`${swiftRound(mark * 100)}%`, 0, 0, font);
      c.restore();
    });

    // Goal burst: a ring flash and confetti under gravity.
    if (model.burst !== null) {
      const t = now - model.burst;
      if (t >= 0 && t < 1.4) {
        const ringRadius = 8 + 46 * (1 - Math.pow(1 - Math.min(t / 0.5, 1), 3));
        const ringAlpha = Math.max(0, 1 - t / 0.5);
        g.stroke(circle(midX, goalY, ringRadius), rgba(Palette.green, 0.7 * ringAlpha), 3 * ringAlpha + 0.5);
        for (let index = 0; index < Math.max(confetti, 0); index++) {
          const angle = -Math.PI / 2 + (chartHash(index, 11) - 0.5) * 2.4;
          const speed = 110 + 150 * chartHash(index, 13);
          const px = midX + Math.cos(angle) * speed * t;
          const py = goalY + Math.sin(angle) * speed * t + 260 * t * t;
          const a = Math.max(0, 1 - t / 1.4);
          c.save();
          c.translate(px, py);
          c.rotate(t * (4 + 8 * chartHash(index, 17)) + index);
          const w = 5 + 3 * chartHash(index, 19);
          g.fill(rrect(-w / 2, -1.5, w, 3, 1), rgba(Palette.spectrum[index % Palette.spectrum.length], a));
          c.restore();
        }
      }
    }
  };

  const zh = ctx.lang === "zh";
  const shown = Math.max(model.shown, 0);
  const reached = model.target >= 0.999;
  const tone = toneOf(model.shown);
  const Badge = reached ? BadgeCheck : Flame;
  const giftSpring = spring(0.4, 0.7);

  return (
    <ChartStage ctx={ctx} hint={["Tap to donate", "点击捐一笔"]}>
      <div onClick={donate} style={{ ...demoCard(), width: 300, padding: "14px 16px", display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
        <Plot ctx={ctx} width={124} height={236} draw={draw} bleed={70} />
        <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 4 }}>
          <div style={captionSecondary}>{ctx.t("Community garden", "社区花园募款")}</div>
          <div style={{ ...sys(28, 700, true), ...mono }}>${grouped(shown * GOAL)}</div>
          <div style={{ ...sys(12, 500), color: Palette.secondaryLabel }}>{zh ? "目标 $10,000" : "of $10,000 goal"}</div>
          <motion.div
            layout="size"
            transition={spring(0.35, 0.6)}
            style={{ marginTop: 6, display: "flex", alignItems: "center", gap: 4, padding: "5px 9px", borderRadius: 999, color: tone.mixed(RGB.black, 0.15).color(), background: tone.color(0.16) }}
          >
            <Badge size={11} strokeWidth={reached ? 2.5 : 0} fill={reached ? "none" : "currentColor"} />
            <span style={{ ...sys(12, 700, true), ...mono }}>{reached ? (zh ? "目标达成" : "Goal reached") : `${swiftRound(shown * 100)}%`}</span>
          </motion.div>
          <div style={{ position: "relative", height: 26, marginTop: 10, alignSelf: "stretch" }}>
            <AnimatePresence initial={false}>
              {gift.gifts > 0 && (
                <motion.div
                  key={gift.gifts}
                  initial={{ y: 14, opacity: 0, scale: 0.7 }}
                  animate={{ y: 0, opacity: 1, scale: 1 }}
                  exit={{ y: -16, opacity: 0 }}
                  transition={giftSpring}
                  style={{ position: "absolute", left: 0, top: 4, transformOrigin: "0% 50%", ...sys(15, 700, true), ...mono, color: gift.last > 0 ? Palette.green : Palette.secondaryLabel }}
                >
                  {gift.last > 0 ? `+$${grouped(gift.last)}` : zh ? "新一轮" : "New round"}
                </motion.div>
              )}
            </AnimatePresence>
          </div>
          <div style={{ display: "flex", alignItems: "center", marginTop: 2 }}>
            {[0, 1, 2, 3].map((index) => {
              const color = Palette.spectrum[(index * 2 + 1) % Palette.spectrum.length];
              return (
                <div
                  key={index}
                  style={{
                    width: 22,
                    height: 22,
                    borderRadius: "50%",
                    marginLeft: index === 0 ? 0 : -7,
                    background: `linear-gradient(to bottom, color-mix(in srgb, ${color} 82%, white), ${color})`,
                    boxShadow: `inset 0 0 0 2px ${Palette.elevated}`,
                  }}
                />
              );
            })}
            <div style={{ display: "flex", marginLeft: -7, paddingLeft: 9, ...sys(11, 500), ...mono, color: Palette.secondaryLabel, whiteSpace: "pre" }}>
              <span>{"  "}</span>
              <NumericText value={128 + gift.gifts} />
              <span>{zh ? " 人已捐" : " donors"}</span>
            </div>
          </div>
        </div>
      </div>
    </ChartStage>
  );
}
