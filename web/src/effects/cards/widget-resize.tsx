/** cards.widget-resize · 小组件缩放 (Cards+WidgetResize.swift) */
import { animate, useMotionValue } from "motion/react";
import { Navigation } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, rubberBand, spring, useAutoplay, useHaptics, usePan, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, tr, useMV, type LText } from "./shared";

const SMALL = 142;
const LARGE = 300;
const SIZES = [
  { w: 142, h: 142 },
  { w: 300, h: 142 },
  { w: 300, h: 300 },
];
const RADIUS = 28;

export default function WidgetResize({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const wMV = useMotionValue(SIZES[0].w);
  const hMV = useMotionValue(SIZES[0].h);
  const kind = useRef(0);
  const dragStart = useRef<{ w: number; h: number } | null>(null);
  const [grabbed, setGrabbed] = useState(false);

  const snap = (index: number) => {
    kind.current = index;
    const t = spring(ctx.n("response"), ctx.n("damping"));
    animate(wMV, SIZES[index].w, t);
    animate(hMV, SIZES[index].h, t);
  };
  const cycle = () => {
    if (dragStart.current) return;
    snap((kind.current + 1) % SIZES.length);
  };
  const resisted = (raw: number) => {
    if (!ctx.b("rubber")) return clamp(raw, SMALL, LARGE);
    if (raw < SMALL) return SMALL + rubberBand(raw - SMALL, 40);
    if (raw > LARGE) return LARGE + rubberBand(raw - LARGE, 40);
    return raw;
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (!dragStart.current) {
        wMV.stop();
        hMV.stop();
        dragStart.current = { w: wMV.get(), h: hMV.get() };
        setGrabbed(true);
        haptics.tap("soft");
      }
      wMV.set(resisted(dragStart.current.w + translation.x));
      hMV.set(resisted(dragStart.current.h + translation.y));
    },
    onEnd: ({ velocity }) => {
      if (!dragStart.current) return;
      dragStart.current = null;
      setGrabbed(false);
      wMV.jump(wMV.get());
      hMV.jump(hMV.get());
      const aim = { w: wMV.get() + velocity.x * 0.25 * 0.5, h: hMV.get() + velocity.y * 0.25 * 0.5 };
      let best = 0;
      let bestDistance = Infinity;
      SIZES.forEach((c, index) => {
        const distance = Math.hypot(c.w - aim.w, c.h - aim.h);
        if (distance < bestDistance) {
          best = index;
          bestDistance = distance;
        }
      });
      if (best !== kind.current) haptics.tap("rigid");
      snap(best);
    },
  });

  useAutoplay(ctx.isPreview, cycle, { every: 1.5 });

  const w = useMV(wMV);
  const h = useMV(hMV);
  const pitch = (LARGE - 62) / 3;
  const R = RADIUS + 7;
  const cx = w - RADIUS;
  const cy = h - RADIUS;
  const pt = (deg: number) => `${cx + R * Math.cos((deg * Math.PI) / 180)} ${cy + R * Math.sin((deg * Math.PI) / 180)}`;

  return (
    <Stage gap={14}>
      <div style={{ position: "relative", width: LARGE, height: LARGE, flexShrink: 0 }}>
        {Array.from({ length: 16 }, (_, slot) => {
          const column = slot % 4;
          const row = Math.floor(slot / 4);
          const clearance = Math.max(column * pitch + 31 - w, row * pitch + 31 - h);
          const amount = clamp((clearance + 22) / 34);
          return (
            <div
              key={slot}
              style={{
                position: "absolute",
                left: column * pitch,
                top: row * pitch,
                width: 62,
                height: 62,
                borderRadius: 15,
                background: alpha(Palette.spectrum[(slot * 3) % Palette.spectrum.length], 0.3),
                boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}`,
                transform: `scale(${0.7 + 0.3 * amount})`,
                opacity: amount,
              }}
            />
          );
        })}
        <div style={{ position: "absolute", left: 0, top: 0, width: w, height: h, borderRadius: RADIUS, boxShadow: `0 8px 14px ${black(0.2)}` }}>
          <WeatherWidget w={w} h={h} ctx={ctx} />
        </div>
        <svg width={LARGE} height={LARGE} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" }}>
          <path
            d={`M ${pt(14)} A ${R} ${R} 0 0 1 ${pt(76)}`}
            fill="none"
            stroke={Palette.labelAlpha(grabbed ? 0.7 : 0.4)}
            strokeWidth={grabbed ? 5 : 4}
            strokeLinecap="round"
            style={{ transition: "stroke 0.25s, stroke-width 0.25s" }}
          />
        </svg>
        <div
          onClick={() => {
            haptics.tap("soft");
            cycle();
          }}
          style={{ position: "absolute", left: 0, top: 0, width: Math.max(w - 24, 40), height: Math.max(h - 24, 40), cursor: "pointer" }}
        />
        <div {...pan} style={{ position: "absolute", left: w - 38, top: h - 38, width: 60, height: 60, touchAction: "none", cursor: "nwse-resize" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the corner handle, or tap the widget" zh="拖动角上的把手，或点击小组件" />
    </Stage>
  );
}

// MARK: - Weather glyphs (SF multicolor symbols)

const CLOUD = "M17.5 19H9a7 7 0 1 1 6.71-9h1.79a4.5 4.5 0 1 1 0 9Z";
const SUN_YELLOW = "#FFD60A";
type Glyph = "cloud.sun" | "sun" | "cloud" | "cloud.rain" | "cloud.bolt";

function Weather({ kind, size }: { kind: Glyph; size: number }) {
  const rays = Array.from({ length: 8 }, (_, k) => {
    const a = (k * Math.PI) / 4;
    return <line key={k} x1={12 + Math.cos(a) * 8} y1={12 + Math.sin(a) * 8} x2={12 + Math.cos(a) * 10.5} y2={12 + Math.sin(a) * 10.5} stroke={SUN_YELLOW} strokeWidth={2} strokeLinecap="round" />;
  });
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flexShrink: 0 }}>
      {kind === "sun" && (
        <>
          <circle cx={12} cy={12} r={5.2} fill={SUN_YELLOW} />
          {rays}
        </>
      )}
      {kind === "cloud.sun" && (
        <>
          <g transform="translate(-1.5 -2.5) scale(0.72)">
            <circle cx={12} cy={12} r={5.2} fill={SUN_YELLOW} />
            {rays}
          </g>
          <path d={CLOUD} fill="#fff" transform="translate(4 6.5) scale(0.8)" />
        </>
      )}
      {kind === "cloud" && <path d={CLOUD} fill="#fff" transform="translate(0 -0.5)" />}
      {kind === "cloud.rain" && (
        <>
          <path d={CLOUD} fill="#fff" transform="translate(1.2 -3.5) scale(0.9)" />
          {[7, 12, 17].map((x) => (
            <line key={x} x1={x + 1} y1={17.5} x2={x - 0.5} y2={21.5} stroke="#6BD3FF" strokeWidth={1.9} strokeLinecap="round" />
          ))}
        </>
      )}
      {kind === "cloud.bolt" && (
        <>
          <path d={CLOUD} fill="#fff" transform="translate(1.2 -3.5) scale(0.9)" />
          <path d="M13 14.5 9.5 19h2.6l-1 4 4-5h-2.7l1.2-3.5Z" fill={SUN_YELLOW} />
        </>
      )}
    </svg>
  );
}

const HOURS: { label: LText; glyph: Glyph; temp: string }[] = [
  { label: ["Now", "现在"], glyph: "cloud.sun", temp: "22°" },
  { label: ["10", "10时"], glyph: "sun", temp: "23°" },
  { label: ["11", "11时"], glyph: "sun", temp: "24°" },
  { label: ["12", "12时"], glyph: "cloud.sun", temp: "25°" },
  { label: ["13", "13时"], glyph: "cloud", temp: "24°" },
];
const DAYS: { day: LText; glyph: Glyph; low: number; high: number }[] = [
  { day: ["Tue", "周二"], glyph: "cloud.rain", low: 13, high: 21 },
  { day: ["Wed", "周三"], glyph: "sun", low: 14, high: 26 },
  { day: ["Thu", "周四"], glyph: "cloud.sun", low: 15, high: 24 },
  { day: ["Fri", "周五"], glyph: "cloud.bolt", low: 12, high: 20 },
];

function WeatherWidget({ w, h, ctx }: { w: number; h: number; ctx: DemoContext }) {
  const fw = clamp((w - SMALL) / (LARGE - SMALL));
  const cx = 16 + (w - 32 - 110) * fw;
  const cyy = 84 - 66 * fw;
  const trailing = clamp((fw - 0.45) / 0.25);
  const leading = clamp(1 - fw / 0.4);
  const block = (align: "flex-start" | "flex-end", opacity: number) => (
    <div style={{ position: "absolute", left: 0, top: 0, width: 110, display: "flex", flexDirection: "column", alignItems: align, gap: 2, opacity, whiteSpace: "nowrap" }}>
      <Weather kind="cloud.sun" size={20} />
      <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 600 }}>{ctx.t("Partly Cloudy", "局部多云")}</span>
      <span style={{ fontSize: 11.5, lineHeight: "14px", fontWeight: 500, opacity: 0.85 }}>{ctx.t("H:25° L:14°", "最高 25° 最低 14°")}</span>
    </div>
  );
  return (
    <div style={{ position: "relative", width: w, height: h, borderRadius: RADIUS, overflow: "hidden", background: "linear-gradient(#2F7BEA, #5AB4F6)", color: "#fff" }}>
      <div style={{ position: "absolute", left: w - 120, top: -90, width: 190, height: 190, borderRadius: "50%", background: white(0.22), filter: "blur(34px)" }} />
      <div style={{ position: "absolute", left: 16, top: 14, display: "flex", flexDirection: "column", alignItems: "flex-start", whiteSpace: "nowrap" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
          <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600 }}>{ctx.t("Cupertino", "库比蒂诺")}</span>
          <Navigation size={9} fill="currentColor" strokeWidth={0} />
        </div>
        <span style={{ fontSize: 44, lineHeight: "52px", fontWeight: 300, marginTop: -2 }}>22°</span>
      </div>
      <div style={{ position: "absolute", left: cx, top: cyy, width: 110, height: 50 }}>
        {block("flex-start", leading)}
        {block("flex-end", trailing)}
      </div>
      <div style={{ position: "absolute", left: 16, top: 78, width: Math.max(w - 32, 1), height: 54, display: "flex", alignItems: "center" }}>
        {HOURS.map((hour, k) => {
          const reveal = clamp((fw - 0.3 - 0.1 * k) / 0.28);
          return (
            <div key={k} style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 5, opacity: reveal, transform: `translateY(${(1 - reveal) * 8}px)`, whiteSpace: "nowrap" }}>
              <span style={{ fontSize: 10.5, lineHeight: "13px", fontWeight: 600, opacity: 0.85 }}>{tr(ctx, hour.label)}</span>
              <div style={{ height: 16, display: "grid", placeItems: "center" }}>
                <Weather kind={hour.glyph} size={18} />
              </div>
              <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 600 }}>{hour.temp}</span>
            </div>
          );
        })}
      </div>
      <div style={{ position: "absolute", left: 16, top: 146, width: Math.max(w - 32, 1) }}>
        {DAYS.map((day, k) => {
          const rowBottom = 150 + (k + 1) * 36;
          const reveal = clamp((h - rowBottom) / 24 + 1);
          const start = (day.low - 10) / 18;
          const end = (day.high - 10) / 18;
          return (
            <div key={k} style={{ position: "relative", height: 36, display: "flex", alignItems: "center", gap: 8, opacity: reveal, transform: `translateY(${(1 - reveal) * -10}px)`, whiteSpace: "nowrap" }}>
              <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 0.6, background: white(0.22) }} />
              <span style={{ width: 40, fontSize: 13, fontWeight: 600 }}>{tr(ctx, day.day)}</span>
              <div style={{ width: 24, display: "grid", placeItems: "center" }}>
                <Weather kind={day.glyph} size={18} />
              </div>
              <span style={{ width: 28, textAlign: "right", fontSize: 13, fontWeight: 500, opacity: 0.7 }}>{`${day.low}°`}</span>
              <div style={{ position: "relative", flex: 1, minWidth: 0, height: 4, borderRadius: 2, background: black(0.16) }}>
                <div style={{ position: "absolute", top: 0, bottom: 0, left: `${start * 100}%`, width: `${Math.max(end - start, 0) * 100}%`, borderRadius: 2, background: "linear-gradient(to right, #9BE7C4, #FFD45E)" }} />
              </div>
              <span style={{ width: 28, textAlign: "right", fontSize: 13, fontWeight: 600 }}>{`${day.high}°`}</span>
            </div>
          );
        })}
      </div>
      <StrokeBorder radius={RADIUS} color={white(0.18)} />
    </div>
  );
}
