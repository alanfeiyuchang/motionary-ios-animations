/** charts.pan-zoom · 时间轴平移与捏合缩放 (Charts+PanZoom.swift) */
import { ZoomIn, ZoomOut } from "lucide-react";
import { useEffect, useRef } from "react";
import { Palette, anim, elementScale, localPoint, rubberBand, spring, useAutoplay, type DemoProps } from "../../kit";
import { useChartEntrance } from "./_shared";
import { ChartStage, G, Plot, RGB, captionSecondary, card, chartHash, circle, clamp01, mono, polyline, rgba, rrect, sampleAt, smoothstep, swiftRound, sys, useChartHaptics, useNums, type Pt } from "./_round2";

const DAYS = 180;
const seriesData = Array.from({ length: DAYS + 1 }, (_, day) => {
  const d = day;
  const trend = 96 + d * 0.22;
  const waves = Math.sin(d / 9.5) * 9 + Math.sin(d / 3.7 + 1.2) * 3.2 + Math.sin(d / 27 + 0.6) * 14;
  const noise = (chartHash(day, 7) - 0.5) * 3.4;
  return trend + waves + noise;
});
const seriesLow = Math.min(...seriesData);
const seriesHigh = Math.max(...seriesData);
const valueAt = (day: number) => sampleAt(seriesData, day / DAYS);
const monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"];

function dateText(day: number, zh: boolean): string {
  const d = Math.min(Math.max(swiftRound(day), 0), DAYS);
  const month = Math.min(Math.trunc(d / 30), 6);
  const dayOfMonth = Math.max(d - month * 30, 1);
  return zh ? `${month + 1}月${dayOfMonth}日` : `${monthNames[month]} ${dayOfMonth}`;
}

const PLOT_W = 268;
const PLOT_H = 132;
const TOTAL = DAYS;
const clampTo = (v: number, lo: number, hi: number) => Math.min(Math.max(v, lo), hi);
const limit = (value: number, span: number) => clampTo(value, 0, Math.max(TOTAL - span, 0));

type Touch = { start: Pt; client: Pt; now: Pt; moved: boolean; velocity: number; lastX: number; lastT: number };

export default function PanZoom({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  /** 0 start, 1 span, 2 draw: what the card draws; `model` holds the targets. */
  const v = useNums(3, [112, 60, 0]);
  const model = useRef({ start: 112, span: 60 });
  const dragStart = useRef<number | null>(null);
  const pinch = useRef<{ span: number; anchorDay: number; anchorUnit: number; distance: number } | null>(null);
  const touches = useRef(new Map<number, Touch>());
  const lastTap = useRef<{ t: number; x: number; y: number } | null>(null);
  const wheel = useRef<{ timer: number; active: boolean }>({ timer: 0, active: false });
  const surface = useRef<HTMLDivElement>(null);
  const autoStep = useRef(0);

  const setNow = (start: number, span: number) => {
    model.current = { start, span };
    v.jump(0, start);
    v.jump(1, span);
    v.jump(2, 1);
  };
  const animateTo = (start: number, span: number, t: ReturnType<typeof spring>) => {
    model.current = { start, span };
    v.to(0, start, t);
    v.to(1, span, t);
  };
  /** The interpolated values on screen: an interrupted glide continues from where it is. */
  const current = () => ({ start: v.get(0), span: v.get(1) });

  const settle = () => {
    pinch.current = null;
    dragStart.current = null;
    const now = current();
    const target = clampTo(now.span, 10, TOTAL);
    haptics.tap("light");
    animateTo(limit(now.start, target), target, spring(0.5, 0.82));
  };

  const toggleZoom = (x: number) => {
    const now = current();
    const unit = clamp01(x / PLOT_W);
    const anchor = now.start + now.span * unit;
    const zoomed = ctx.n("zoom");
    const target = now.span > zoomed * 1.5 ? zoomed : 60;
    haptics.tap("light");
    animateTo(limit(anchor - target * unit, target), target, spring(0.5, 0.82));
    v.to(2, 1, spring(0.5, 0.82));
  };

  const onPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    const el = e.currentTarget;
    el.setPointerCapture(e.pointerId);
    const p = localPoint(e, el);
    touches.current.set(e.pointerId, { start: p, client: { x: e.clientX, y: e.clientY }, now: p, moved: false, velocity: 0, lastX: p.x, lastT: performance.now() });
    if (touches.current.size === 2) {
      // MagnifyGesture begins: the midpoint is the anchor that stays under the fingers.
      const [a, b] = [...touches.current.values()];
      const now = current();
      const unit = clamp01((a.now.x + b.now.x) / 2 / PLOT_W);
      pinch.current = { span: now.span, anchorDay: now.start + now.span * unit, anchorUnit: unit, distance: Math.max(Math.hypot(a.now.x - b.now.x, a.now.y - b.now.y), 1) };
      a.moved = b.moved = true;
      haptics.tap("soft");
    }
  };

  const onPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const t = touches.current.get(e.pointerId);
    if (!t) return;
    const scale = elementScale(e.currentTarget) || 1;
    const p = { x: t.start.x + (e.clientX - t.client.x) / scale, y: t.start.y + (e.clientY - t.client.y) / scale };
    const now = performance.now();
    const dt = Math.max((now - t.lastT) / 1000, 1 / 240);
    t.velocity = t.velocity * 0.6 + ((p.x - t.lastX) / dt) * 0.4;
    t.lastX = p.x;
    t.lastT = now;
    t.now = p;

    if (pinch.current && touches.current.size >= 2) {
      const [a, b] = [...touches.current.values()];
      const magnification = Math.hypot(a.now.x - b.now.x, a.now.y - b.now.y) / pinch.current.distance;
      const newSpan = clampTo(pinch.current.span / Math.max(magnification, 0.05), 8, TOTAL * 1.15);
      setNow(pinch.current.anchorDay - newSpan * pinch.current.anchorUnit, newSpan);
      return;
    }
    if (pinch.current) return;
    if (!t.moved) {
      if (Math.hypot(p.x - t.start.x, p.y - t.start.y) < 2) return;
      t.moved = true;
    }
    if (dragStart.current === null) {
      dragStart.current = current().start;
      // Measure the pan from here, so a glide caught mid-flight does not jump.
      t.start = p;
      t.client = { x: e.clientX, y: e.clientY };
      model.current = current();
      haptics.tap("soft");
    }
    const span = model.current.span;
    const raw = dragStart.current - ((p.x - t.start.x) / PLOT_W) * span;
    const maxStart = Math.max(TOTAL - span, 0);
    // Rubber band past either end of the data.
    let target = raw;
    if (raw < 0) target = -rubberBand(-raw, span * 0.3);
    else if (raw > maxStart) target = maxStart + rubberBand(raw - maxStart, span * 0.3);
    setNow(target, span);
  };

  const onPointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    const t = touches.current.get(e.pointerId);
    if (!t) return;
    touches.current.delete(e.pointerId);
    if (pinch.current) {
      settle();
      // A finger that stays down starts a fresh pan from where the chart is now.
      for (const rest of touches.current.values()) {
        rest.start = rest.now;
        rest.moved = true;
      }
      touches.current.forEach((rest, id) => {
        const el = e.currentTarget;
        const rect = el.getBoundingClientRect();
        const scale = elementScale(el) || 1;
        rest.client = { x: rect.left + rest.now.x * scale, y: rect.top + rest.now.y * scale };
        void id;
      });
      return;
    }
    if (dragStart.current !== null) {
      dragStart.current = null;
      if (e.type === "pointercancel") return;
      const { start, span } = model.current;
      const velocity = performance.now() - t.lastT > 80 ? 0 : t.velocity;
      // `predictedEndTranslation - translation`: the distance the finger's velocity would still carry.
      const extra = ((velocity * 0.25) / PLOT_W) * span * ctx.n("glide");
      const target = limit(start - extra, span);
      const hitEnd = target !== start - extra;
      animateTo(target, span, hitEnd ? spring(0.55, 0.78) : spring(0.9, 1));
      return;
    }
    if (!t.moved && e.type !== "pointercancel") {
      const now = performance.now();
      const prev = lastTap.current;
      if (prev && now - prev.t < 350 && Math.hypot(prev.x - t.start.x, prev.y - t.start.y) < 30) {
        lastTap.current = null;
        toggleZoom(t.start.x);
      } else lastTap.current = { t: now, x: t.start.x, y: t.start.y };
    }
  };

  // Desktop fallback for the pinch: a trackpad pinch (or ctrl + wheel) zooms around the cursor.
  useEffect(() => {
    const el = surface.current;
    if (!el || ctx.isPreview) return;
    const onWheel = (e: WheelEvent) => {
      if (!e.ctrlKey && !e.metaKey) return;
      e.preventDefault();
      const now = current();
      const unit = clamp01(localPoint(e, el).x / PLOT_W);
      const anchor = now.start + now.span * unit;
      if (!wheel.current.active) {
        wheel.current.active = true;
        haptics.tap("soft");
      }
      const newSpan = clampTo(now.span * Math.exp(e.deltaY * 0.01), 8, TOTAL * 1.15);
      setNow(anchor - newSpan * unit, newSpan);
      window.clearTimeout(wheel.current.timer);
      wheel.current.timer = window.setTimeout(() => {
        wheel.current.active = false;
        settle();
      }, 180);
    };
    el.addEventListener("wheel", onWheel, { passive: false });
    return () => {
      el.removeEventListener("wheel", onWheel);
      window.clearTimeout(wheel.current.timer);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ctx.isPreview]);

  /** Autoplay and the arrival play: pan with a glide, zoom in, pan, zoom out, come back. */
  const auto = () => {
    if (dragStart.current !== null || pinch.current) return;
    const step = autoStep.current % 5;
    autoStep.current += 1;
    const zoomed = ctx.n("zoom");
    const m = model.current;
    if (step === 0) animateTo(58, m.span, spring(0.9, 1));
    else if (step === 1) animateTo(limit(88 - zoomed / 2, zoomed), zoomed, spring(0.5, 0.82));
    else if (step === 2) animateTo(limit(m.start + zoomed * 1.6, m.span), m.span, spring(0.9, 1));
    else if (step === 3) animateTo(20, 150, spring(0.6, 0.82));
    else animateTo(112, 60, spring(0.6, 0.82));
  };

  useChartEntrance(() => v.to(2, 1, anim.easeInOut(0.8)));
  useAutoplay(ctx.isPreview, auto, { every: 1.5, delay: 1.2 });

  const start = v.get(0);
  const spanNow = v.get(1);
  const span = Math.max(spanNow, 1);
  const drawP = clamp01(v.get(2));
  const zh = ctx.lang === "zh";
  const from = Math.max(start, 0);
  const to = Math.min(start + span, TOTAL);

  const draw = (g: G) => {
    const height = PLOT_H;
    const x = (day: number) => g.width * ((day - start) / span);

    // Fit the value range to what is visible (edges interpolated, so it never jumps).
    let low = Math.min(valueAt(from), valueAt(to));
    let high = Math.max(valueAt(from), valueAt(to));
    const firstDay = Math.ceil(from);
    const lastDay = Math.floor(to);
    for (let day = firstDay; day <= lastDay; day++) {
      low = Math.min(low, seriesData[day]);
      high = Math.max(high, seriesData[day]);
    }
    const pad = Math.max((high - low) * 0.16, 2);
    low -= pad;
    high += pad;
    const y = (value: number) => height - height * ((value - low) / (high - low));

    // Ticks: each day belongs to the coarsest level that divides it and fades with that level's spacing.
    const levels = ([[1, 16], [5, 22], [30, 22]] as const).map(([every, threshold]) => smoothstep(threshold, threshold + 10, (g.width * every) / span));
    const tickFrom = Math.max(Math.floor(start - span * 0.05), 0);
    const tickTo = Math.min(Math.ceil(start + span * 1.05), DAYS);
    for (let day = tickFrom; day <= tickTo; day++) {
      const level = day % 30 === 0 ? 2 : day % 5 === 0 ? 1 : 0;
      const a = levels[level];
      if (!(a > 0.01)) continue;
      const tickX = x(day);
      g.line(tickX, 0, tickX, height, g.primary((level === 2 ? 0.14 : 0.06) * a), 1);
      const text = level === 2 ? (zh ? `${Math.trunc(day / 30) + 1}月` : monthNames[Math.min(Math.trunc(day / 30), 6)]) : `${day % 30}`;
      // Labels dissolve at the plot's edges instead of being cut off.
      const edge = smoothstep(2, 16, tickX) * smoothstep(2, 16, g.width - tickX);
      g.text(text, tickX, height + 4, { size: 10, weight: level === 2 ? 600 : 500, color: level === 2 ? g.primary(0.7) : g.secondary(), anchor: "top", alpha: a * edge });
    }

    // Series, one sample per day plus the two interpolated edges.
    const points: Pt[] = [{ x: x(from), y: y(valueAt(from)) }];
    for (let day = firstDay; day <= lastDay; day++) points.push({ x: x(day), y: y(seriesData[day]) });
    points.push({ x: x(to), y: y(valueAt(to)) });
    const line = polyline(points);
    const area = polyline(points);
    area.lineTo(x(to), height);
    area.lineTo(x(from), height);
    area.closePath();

    const clip = new Path2D();
    clip.rect(0, -6, g.width * drawP, height + 6);
    g.layer(
      () => {
        g.fill(area, g.gradient(0, 0, 0, height, [rgba(Palette.indigo, 0.28), rgba(Palette.indigo, 0.02)]));
        g.stroke(line, Palette.indigo, 2, { cap: "round", join: "round" });
        // Daily dots appear once days are far enough apart.
        const dotAlpha = levels[0];
        if (dotAlpha > 0.01) {
          for (let day = firstDay; day <= lastDay; day++) {
            const cx = x(day);
            const cy = y(seriesData[day]);
            g.fill(circle(cx, cy, 3.5), `rgba(255,255,255,${dotAlpha})`);
            g.fill(circle(cx, cy, 1.9), rgba(Palette.indigo, dotAlpha));
          }
        }
      },
      { clip },
    );
    g.line(0, height, g.width, height, g.primary(0.16), 1);
  };

  const drawMap = (g: G) => {
    const pts: Pt[] = [];
    for (let day = 0; day <= DAYS; day += 2) pts.push({ x: (g.width * day) / DAYS, y: g.height - 3 - (g.height - 6) * ((seriesData[day] - seriesLow) / (seriesHigh - seriesLow)) });
    g.fill(rrect(0, 0, g.width, g.height, 6), g.primary(0.05));
    g.stroke(polyline(pts), g.secondary(0.7), 1, { join: "round" });
    const a = clamp01(start / TOTAL);
    const b = clamp01((start + spanNow) / TOTAL);
    const shape = rrect(g.width * a, 0, Math.max(g.width * (b - a), 6), g.height, 6);
    g.fill(shape, rgba(Palette.indigo, 0.2));
    g.stroke(shape, Palette.indigo, 1.5);
  };

  const first = valueAt(from);
  const last = valueAt(to);
  const change = ((last - first) / Math.max(first, 1)) * 100;
  const tone = RGB.trend(change / 6);
  const Zoom = spanNow > 40 ? ZoomIn : ZoomOut;

  return (
    <ChartStage ctx={ctx} hint={["Drag to pan · pinch or double-tap to zoom", "拖动平移 · 捏合或双击缩放"]}>
      <div style={card(8)}>
        <div style={{ display: "flex", alignItems: "baseline", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={{ ...captionSecondary, ...mono }}>
              {dateText(from, zh)} – {dateText(to, zh)}
            </div>
            <div style={{ ...sys(26, 700, true), ...mono }}>{last.toFixed(1)}</div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 5, alignItems: "flex-end" }}>
            <div style={{ ...sys(13, 600, true), ...mono, color: tone.mixed(RGB.black, 0.12).color(), padding: "5px 9px", borderRadius: 999, background: tone.color(0.16) }}>
              {`${change >= 0 ? "+" : "−"}${Math.abs(change).toFixed(1)}%`}
            </div>
            <button
              type="button"
              onClick={() => toggleZoom(PLOT_W / 2)}
              style={{ height: 22, padding: "0 8px", borderRadius: 11, display: "flex", alignItems: "center", gap: 3, color: Palette.secondaryLabel, background: Palette.labelAlpha(0.06) }}
            >
              <Zoom size={11} strokeWidth={3} />
              <span style={{ ...sys(11, 600, true), ...mono }}>{zh ? `${swiftRound(spanNow)} 天` : `${swiftRound(spanNow)} days`}</span>
            </button>
          </div>
        </div>
        <div
          ref={surface}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={onPointerUp}
          onPointerCancel={onPointerUp}
          style={{ width: PLOT_W, height: PLOT_H + 16, touchAction: "none", cursor: "grab" }}
        >
          <Plot ctx={ctx} width={PLOT_W} height={PLOT_H + 16} draw={draw} />
        </div>
        {ctx.b("minimap") && <Plot ctx={ctx} width={PLOT_W} height={20} draw={drawMap} />}
      </div>
    </ChartStage>
  );
}
