/** gestures.zoom-timeline · 时间轴缩放 (Gestures+ZoomTimeline.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useMotionValueEvent } from "motion/react";
import { Calendar, Clock } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, clamp, demoCard, fonts, rubberBand, spring, useAutoplay, useDoubleTap, useHaptics, usePan, type DemoProps } from "../../kit";
import { GMath, labelColor, roundRect, useCanvas2D, usePinch } from "./_sim-kit";

const SIZE = { w: 300, h: 150 };
const MIN_SCALE = 2.4;
const MAX_SCALE = 64;
const HOURS_SCALE = 32;
const DAYS_SCALE = 2.6;
const NOW = 58.4;
const WEEK = { lo: 0, hi: 168 };
const BASELINE = 112;

type Evt = { start: number; end: number; lane: number; color: string; en: string; zh: string };
const EVENTS: Evt[] = [
  { start: 9, end: 10, lane: 0, color: Palette.indigo, en: "Standup", zh: "站会" },
  { start: 13, end: 15.5, lane: 1, color: Palette.pink, en: "Roadmap", zh: "路线图" },
  { start: 34, end: 36.5, lane: 0, color: Palette.mint, en: "Workshop", zh: "工作坊" },
  { start: 42, end: 43.5, lane: 1, color: Palette.amber, en: "Gym", zh: "健身" },
  { start: 57, end: 57.5, lane: 0, color: Palette.indigo, en: "Standup", zh: "站会" },
  { start: 58, end: 60, lane: 1, color: Palette.pink, en: "Design review", zh: "设计评审" },
  { start: 60.5, end: 61.5, lane: 0, color: Palette.amber, en: "Lunch", zh: "午餐" },
  { start: 62, end: 65, lane: 1, color: Palette.violet, en: "Deep work", zh: "专注时间" },
  { start: 63, end: 63.75, lane: 0, color: Palette.sky, en: "Call", zh: "通话" },
  { start: 81, end: 84, lane: 0, color: Palette.coral, en: "Offsite", zh: "团建" },
  { start: 86, end: 88, lane: 1, color: Palette.mint, en: "Run", zh: "跑步" },
  { start: 106, end: 107.5, lane: 0, color: Palette.green, en: "Demo", zh: "演示" },
  { start: 111, end: 114.5, lane: 1, color: Palette.sky, en: "Flight", zh: "航班" },
  { start: 130, end: 134, lane: 0, color: Palette.mint, en: "Hike", zh: "徒步" },
  { start: 155, end: 157, lane: 1, color: Palette.coral, en: "Brunch", zh: "早午餐" },
];
const DAYS: [string, string][] = [
  ["Mon 12", "周一 12"],
  ["Tue 13", "周二 13"],
  ["Wed 14", "周三 14"],
  ["Thu 15", "周四 15"],
  ["Fri 16", "周五 16"],
  ["Sat 17", "周六 17"],
  ["Sun 18", "周日 18"],
];

export default function ZoomTimeline({ ctx }: DemoProps) {
  const haptics = useHaptics();
  // Model values (what SwiftUI state holds) and their animated presentation.
  const m = useRef({ logScale: Math.log(HOURS_SCALE), anchorTime: NOW, anchorX: 150 }).current;
  const logScale = useMotionValue(m.logScale);
  const anchorTime = useMotionValue(m.anchorTime);
  const anchorX = useMotionValue(m.anchorX);
  const pinchStart = useRef<number | null>(null);
  const panStart = useRef<number | null>(null);
  const hoursRef = useRef(true);
  const [hoursMode, setHoursMode] = useState(true);
  const [spanScale, setSpanScale] = useState(HOURS_SCALE);
  const canvas = useCanvas2D(SIZE.w, SIZE.h);
  const density = ctx.n("density");
  const scheme = ctx.scheme;
  const lang = ctx.lang;

  const scale = () => Math.exp(m.logScale);
  const centre = () => m.anchorTime - (m.anchorX - SIZE.w / 2) / scale();
  const settleSpring = () => spring(ctx.n("response"), ctx.n("damping"));

  const draw = () => {
    const g = canvas.begin();
    if (!g) return;
    const sc = Math.exp(logScale.get());
    const aT = anchorTime.get();
    const aX = anchorX.get();
    const x = (time: number) => aX + (time - aT) * sc;
    const first = aT - aX / sc;
    const last = first + SIZE.w / sc;

    // Days
    g.textBaseline = "middle";
    const firstDay = Math.floor(first / 24);
    const lastDay = Math.floor(last / 24);
    for (let day = firstDay; day <= lastDay; day++) {
      const x0 = x(day * 24);
      const x1 = x((day + 1) * 24);
      const inWeek = day >= 0 && day < 7;
      if (!inWeek || ((day % 2) + 2) % 2 === 1) {
        g.fillStyle = labelColor(scheme, inWeek ? 0.035 : 0.07);
        g.fillRect(x0, 0, x1 - x0, BASELINE);
      }
      if (!inWeek) continue;
      // Sticky day name: pinned to the left edge until the next day pushes it out.
      g.font = `700 12px ${fonts.rounded}`;
      g.textAlign = "left";
      const text = DAYS[day][lang === "zh" ? 1 : 0];
      const width = g.measureText(text).width;
      const pinned = Math.min(Math.max(x0 + 7, 24), x1 - width - 7);
      g.fillStyle = labelColor(scheme, 0.75);
      g.fillText(text, pinned, 14.5);
    }

    // Events
    for (const event of EVENTS) {
      if (!(event.end > first - 2 && event.start < last + 2)) continue;
      const x0 = x(event.start);
      const natural = x(event.end) - x0;
      const width = Math.max(natural - 2, 6);
      const y = 32 + event.lane * 30;
      const rx = x0 + (natural - width) / 2;
      roundRect(g, rx, y, width, 24, Math.min(8, width / 2));
      g.fillStyle = alpha(event.color, 0.9);
      g.fill();
      const titleAlpha = GMath.smoothstep3(40, 62, width);
      if (titleAlpha <= 0.01) continue;
      g.save();
      g.clip();
      g.globalAlpha = titleAlpha;
      g.font = `600 11px ${fonts.text}`;
      g.textAlign = "left";
      g.fillStyle = "#fff";
      g.fillText(lang === "zh" ? event.zh : event.en, Math.max(rx, 16) + 7, y + 12.5);
      g.restore();
    }

    // Ticks
    g.beginPath();
    g.moveTo(0, BASELINE);
    g.lineTo(SIZE.w, BASELINE);
    g.strokeStyle = labelColor(scheme, 0.18);
    g.lineWidth = 1;
    g.stroke();
    // (step in hours, the coarser step whose ticks replace this one, full height)
    const levels: [number, number, number][] = [
      [24, 0, 20],
      [6, 24, 13],
      [1, 6, 9],
      [0.25, 1, 5],
    ];
    g.lineCap = "round";
    for (const [step, parent, height] of levels) {
      const spacing = step * sc;
      const a = GMath.smoothstep3(density, density + 9, spacing);
      if (a <= 0.01) continue;
      const grow = 0.45 + 0.55 * GMath.smoothstep3(density, density + 40, spacing);
      g.beginPath();
      const end = Math.ceil(last / step);
      for (let index = Math.floor(first / step); index <= end; index++) {
        const time = index * step;
        if (parent > 0 && Math.abs(time - Math.round(time / parent) * parent) < 0.001) continue;
        const px = x(time);
        g.moveTo(px, BASELINE);
        g.lineTo(px, BASELINE - height * grow);
      }
      const strength = step >= 24 ? 0.55 : step >= 6 ? 0.4 : 0.28;
      g.strokeStyle = labelColor(scheme, strength * a);
      g.lineWidth = step >= 24 ? 1.5 : 1;
      g.stroke();
    }
    g.lineCap = "butt";

    // Hour labels
    const steps = [1, 3, 6, 12];
    const alphas = steps.map((s) => GMath.smoothstep3(38, 56, s * sc));
    const fi = alphas.findIndex((v) => v > 0.01);
    if (fi >= 0) {
      const finest = steps[fi];
      const end = Math.ceil(last);
      g.font = `500 10px ${fonts.text}`;
      g.textAlign = "center";
      for (let hour = Math.floor(first / finest) * finest; hour <= end; hour += finest) {
        const ofDay = ((hour % 24) + 24) % 24;
        let a = 0;
        steps.forEach((s, i) => {
          if (ofDay % s === 0) a = Math.max(a, alphas[i]);
        });
        if (a <= 0.01) continue;
        g.fillStyle = labelColor(scheme, 0.55 * a);
        g.fillText(`${String(ofDay).padStart(2, "0")}:00`, x(hour), BASELINE + 14.5);
      }
    }

    // Now
    const px = x(NOW);
    if (px > -10 && px < SIZE.w + 10) {
      g.beginPath();
      g.moveTo(px, 26);
      g.lineTo(px, BASELINE);
      g.strokeStyle = Palette.red;
      g.lineWidth = 1.5;
      g.stroke();
      g.beginPath();
      g.arc(px, 26, 4, 0, Math.PI * 2);
      g.fillStyle = Palette.red;
      g.fill();
    }
  };

  const pending = useRef(0);
  const schedule = () => {
    if (pending.current) return;
    pending.current = requestAnimationFrame(() => {
      pending.current = 0;
      draw();
    });
  };
  useMotionValueEvent(logScale, "change", (v) => {
    schedule();
    // The header reads the model's scale, which animates with the ruler.
    setSpanScale(Math.round(Math.exp(v) * 200) / 200);
  });
  useMotionValueEvent(anchorTime, "change", schedule);
  useMotionValueEvent(anchorX, "change", schedule);
  useEffect(() => {
    draw();
    return () => cancelAnimationFrame(pending.current);
  });

  const updateMode = (haptic: boolean) => {
    const hours = scale() > 8.5;
    if (hours === hoursRef.current) return;
    hoursRef.current = hours;
    setHoursMode(hours);
    if (haptic) haptics.tap("light");
  };

  /** Re-expresses the current view around a new anchor x without moving anything. */
  const reanchor = (x: number) => {
    const time = centre() + (x - SIZE.w / 2) / scale();
    m.anchorX = x;
    m.anchorTime = time;
    anchorX.jump(x);
    anchorTime.stop();
    anchorTime.jump(time);
  };

  /** Springs the zoom back inside its limits and the visible centre back inside the week. */
  const settle = () => {
    const clampedScale = Math.min(Math.max(m.logScale, Math.log(MIN_SCALE)), Math.log(MAX_SCALE));
    const offset = (m.anchorX - SIZE.w / 2) / Math.exp(clampedScale);
    const centreNow = m.anchorTime - offset;
    const clampedCentre = Math.min(Math.max(centreNow, WEEK.lo + 4), WEEK.hi - 4);
    if (clampedScale === m.logScale && clampedCentre === centreNow) return;
    m.logScale = clampedScale;
    m.anchorTime = clampedCentre + offset;
    animate(logScale, m.logScale, settleSpring());
    animate(anchorTime, m.anchorTime, settleSpring());
    updateMode(false);
  };

  /** Double tap, and the autoplay: jump between the days view and the hours view around `x`. */
  const toggle = (x: number, haptic = true) => {
    if (pinchStart.current !== null) return;
    reanchor(clamp(x, 20, SIZE.w - 20));
    const target = hoursRef.current ? DAYS_SCALE : HOURS_SCALE;
    m.logScale = Math.log(target);
    animate(logScale, m.logScale, settleSpring());
    updateMode(haptic);
    settle();
  };

  const endPinch = () => {
    if (pinchStart.current === null) return;
    pinchStart.current = null;
    settle();
  };

  const pinch = usePinch<HTMLDivElement>({
    onChange: (magnification, _rotation, anchor) => {
      if (pinchStart.current === null) {
        logScale.stop();
        anchorTime.stop();
        m.logScale = logScale.get();
        m.anchorTime = anchorTime.get();
        reanchor(anchor.x);
        pinchStart.current = m.logScale;
        panStart.current = null;
      }
      const raw = pinchStart.current + Math.log(Math.max(magnification, 0.01));
      const low = Math.log(MIN_SCALE);
      const high = Math.log(MAX_SCALE);
      if (raw > high) m.logScale = high + rubberBand(raw - high, 0.6);
      else if (raw < low) m.logScale = low + rubberBand(raw - low, 0.6);
      else m.logScale = raw;
      logScale.jump(m.logScale);
      updateMode(true);
    },
    onEnd: endPinch,
  });

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        if (pinchStart.current !== null || pinch.active()) return;
        if (panStart.current === null) {
          anchorTime.stop();
          logScale.stop();
          m.anchorTime = anchorTime.get();
          m.logScale = logScale.get();
          panStart.current = m.anchorTime;
        }
        m.anchorTime = panStart.current - translation.x / scale();
        anchorTime.jump(m.anchorTime);
      },
      onEnd: ({ translation, velocity }) => {
        const start = panStart.current;
        if (start === null) return;
        panStart.current = null;
        if (pinchStart.current !== null) return;
        // Coast along the throw, then come to rest inside the week.
        m.anchorTime = start - (translation.x + velocity.x * 0.25) / scale();
        animate(anchorTime, m.anchorTime, spring(0.55, 1));
        settle();
      },
    },
    8,
  );

  const doubleTap = useDoubleTap((p) => toggle(p.x));

  const nowX = () => SIZE.w / 2 + (NOW - centre()) * scale();
  useAutoplay(ctx.isPreview, () => toggle(nowX(), false), { every: 2.4, delay: 0.7 });

  const visible = SIZE.w / Math.min(Math.max(spanScale, MIN_SCALE), MAX_SCALE);
  const span = hoursMode ? visible : visible / 24;
  const spanText = span < 10 ? span.toFixed(1) : span.toFixed(0);
  const Icon = hoursMode ? Clock : Calendar;
  const fade = "linear-gradient(90deg, transparent 0%, #000 6%, #000 94%, transparent 100%)";

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div style={{ ...demoCard(28), width: SIZE.w + 16, padding: "14px 0", display: "flex", flexDirection: "column", alignItems: "center", gap: 10, flex: "none" }}>
        <div style={{ alignSelf: "stretch", padding: "0 18px", display: "flex", alignItems: "center", gap: 8 }}>
          <motion.div
            initial={false}
            animate={{ backgroundColor: hoursMode ? Palette.indigo : Palette.mint }}
            transition={spring(0.35, 0.8)}
            style={{ display: "flex", alignItems: "center", gap: 6, padding: "6px 12px", borderRadius: 999, color: "#fff", fontSize: 15, lineHeight: "20px", fontWeight: 600 }}
          >
            <span style={{ position: "relative", width: 16, height: 16, display: "inline-block" }}>
              <AnimatePresence initial={false} mode="popLayout">
                <motion.span
                  key={hoursMode ? "h" : "d"}
                  initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
                  exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  transition={spring(0.35, 0.8)}
                  style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}
                >
                  <Icon size={15} strokeWidth={2.4} />
                </motion.span>
              </AnimatePresence>
            </span>
            <span>{hoursMode ? ctx.t("Hours", "小时") : ctx.t("Days", "天")}</span>
          </motion.div>
          <div style={{ flex: 1 }} />
          <div style={{ display: "flex", gap: 3, fontSize: 13, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel }}>
            <NumericText value={span} text={spanText} />
            <span>{hoursMode ? ctx.t("h in view", "小时可见") : ctx.t("days in view", "天可见")}</span>
          </div>
        </div>
        <div
          ref={pinch.ref}
          onPointerDown={(e) => {
            pinch.handlers.down(e);
            pan.onPointerDown(e);
          }}
          onPointerMove={(e) => {
            pinch.handlers.move(e);
            pan.onPointerMove(e);
          }}
          onPointerUp={(e) => {
            const wasPinch = pinch.handlers.up(e);
            pan.onPointerUp(e);
            if (!wasPinch && !pinch.active()) doubleTap(e);
          }}
          onPointerCancel={(e) => {
            pinch.handlers.up(e);
            pan.onPointerCancel(e);
          }}
          style={{ position: "relative", width: SIZE.w, height: SIZE.h, touchAction: "none", WebkitMaskImage: fade, maskImage: fade, cursor: "grab" }}
        >
          <canvas ref={canvas.ref} style={canvas.style} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Pinch to zoom, drag to pan, double-tap to switch" zh="捏合缩放、拖动平移，双击切换" />
    </div>
  );
}
