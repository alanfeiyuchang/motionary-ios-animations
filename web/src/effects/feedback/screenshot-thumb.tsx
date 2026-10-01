/** feedback.screenshot-thumb · 截屏缩略图 (Feedback+ScreenshotThumb.swift) */
import { useMotionValueEvent } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, anim, black, fonts, rubberBand, spring, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { useAnimated } from "./shared";

const W = 250;
const H = 280;

export default function ScreenshotThumb({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  /** Whether a frozen copy exists at all. */
  const [captured, setCaptured] = useState(false);
  const capturedRef = useRef(false);
  /** 0 = full screen, 1 = thumbnail in the corner. */
  const [shrink, shrinkTo, shrinkSet] = useAnimated(0);
  const [flash, flashTo, flashSet] = useAnimated(0);
  /** Horizontal offset of the thumbnail: the live drag, or the slide off the edge. */
  const [slide, slideTo, slideSet] = useAnimated(0);
  const [frozenAt, setFrozenAt] = useState(100);
  const token = useRef(0);
  const dragged = useRef(false);
  const [, force] = useState(0);
  const rerender = () => force((n) => n + 1);
  useMotionValueEvent(shrink, "change", rerender);
  useMotionValueEvent(flash, "change", rerender);
  useMotionValueEvent(slide, "change", rerender);

  const setCopy = (v: boolean) => {
    capturedRef.current = v;
    setCaptured(v);
  };

  const leave = (duration: number) => {
    const current = ++token.current;
    slideTo(-160, anim.easeIn(duration));
    after(duration + 0.05, () => {
      if (token.current !== current) return;
      setCopy(false);
      slideSet(0);
      shrinkSet(0);
    });
  };

  const holdThenLeave = (current: number) => {
    after(0.5 + ctx.n("hold"), () => {
      if (token.current !== current) return;
      leave(0.3);
    });
  };

  const capture = () => {
    const current = ++token.current;
    haptics.tap("medium");
    setFrozenAt(performance.now() / 1000);
    setCopy(true);
    shrinkSet(0);
    slideSet(0);
    flashSet(ctx.n("flash"));
    after(0.03, () => {
      if (token.current !== current) return;
      flashTo(0, anim.easeOut(0.35));
      after(0.08, () => {
        if (token.current !== current) return;
        shrinkTo(1, spring(0.5, 0.82));
        holdThenLeave(current);
      });
    });
  };

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ translation }) => {
        if (!capturedRef.current || shrink.get() <= 0.9) return;
        // Holding the thumbnail keeps it on screen.
        token.current += 1;
        const x = translation.x;
        slideSet(x < 0 ? x : rubberBand(x, 40));
      },
      onEnd: ({ velocity }) => {
        if (!capturedRef.current || shrink.get() <= 0.9) return;
        const s = slide.get();
        if (s < -40 || velocity.x < -400) {
          haptics.tap("light");
          const remaining = 160 + s;
          leave(Math.min(Math.max(remaining / Math.max(-velocity.x, 500), 0.12), 0.3));
          return;
        }
        slideTo(0, spring(0.35, 0.75));
        holdThenLeave(++token.current);
      },
    },
    8,
  );

  useAutoplay(ctx.isPreview, capture, { every: ctx.n("hold") + 2.4, delay: 0.6 });

  // ScreenshotShrink: radius, border and shadow are divided by the scale so they read constant on screen.
  const p = shrink.get();
  const thumb = ctx.n("scale");
  const scale = Math.max(1 - (1 - thumb) * p, 0.05);
  const framed = Math.min(Math.max(p * 3, 0), 1);
  const radius = (34 + (10 - 34) * Math.min(Math.max(p, 0), 1)) / scale;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div
        onPointerDown={() => {
          dragged.current = false;
        }}
        onClick={() => {
          if (!dragged.current) capture();
        }}
        style={{ position: "relative", width: W, height: H, flexShrink: 0, borderRadius: 34, boxShadow: `0 10px 18px ${black(0.22)}`, cursor: "pointer" }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, overflow: "hidden", isolation: "isolate" }}>
          <Scene preview={ctx.isPreview} zh={ctx.lang === "zh"} />
          {captured && (
            <div
              {...(ctx.isPreview ? {} : pan)}
              style={{
                position: "absolute",
                inset: 0,
                transformOrigin: "0% 100%",
                transform: `translate(${12 * p + slide.get()}px, ${-12 * p}px) scale(${scale})`,
                borderRadius: radius,
                boxShadow: `0 ${5 / scale}px ${10 / scale}px ${black(0.35 * framed)}`,
                touchAction: "pan-y",
              }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: radius, overflow: "hidden" }}>
                <Scene frozen={frozenAt} preview={ctx.isPreview} zh={ctx.lang === "zh"} />
              </div>
              <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 ${(3 / scale) * framed}px #fff`, pointerEvents: "none" }} />
            </div>
          )}
          <div style={{ position: "absolute", inset: 0, background: "#fff", opacity: flash.get(), pointerEvents: "none" }} />
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, boxShadow: `inset 0 0 0 0.6px ${white(0.18)}, inset 0 0 0 5px #0E0E10`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap to capture, swipe the thumbnail away" zh="点击截屏，把缩略图划走" />
    </div>
  );
}

// MARK: - Screen

/** A weather screen. With `frozen` set its clock stops at that time: that is the screenshot. */
function Scene({ frozen, preview, zh }: { frozen?: number; preview: boolean; zh: boolean }) {
  useClock(frozen === undefined, preview ? 20 : 30);
  const t = frozen ?? performance.now() / 1000;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, overflow: "hidden", background: "linear-gradient(#3C7BEA, #7DB7FF, #FFD9A8)", color: "#fff" }}>
      <div
        style={{
          position: "absolute",
          left: 187 - 29,
          top: 74 - 29,
          width: 58,
          height: 58,
          borderRadius: "50%",
          background: "radial-gradient(circle, #FFF3B0 2px, #FFC247 30px)",
          boxShadow: "0 0 18px rgb(255 213 107 / 0.8)",
          transform: `scale(${1 + 0.04 * Math.sin(t * 1.6)})`,
        }}
      />
      <Cloud width={88} x={125 + 26 + 16 * Math.sin(t * 0.45)} y={140 - 112} />
      <Cloud width={60} x={125 + 74 + 12 * Math.sin(t * 0.3 + 2)} y={140 - 22} opacity={0.8} />
      <svg width={W} height={90} style={{ position: "absolute", left: 0, top: 190 }}>
        <defs>
          <linearGradient id="st-hills" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#4FA36B" />
            <stop offset="1" stopColor="#2C7A55" />
          </linearGradient>
        </defs>
        <path d="M0 90 L0 49.5 Q62.5 -9 125 40.5 Q187.5 76.5 250 27 L250 90 Z" fill="url(#st-hills)" />
      </svg>
      <div style={{ position: "absolute", left: 18, top: 58, width: 214, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, opacity: 0.9 }}>{zh ? "京都 · 周六" : "Kyoto · Saturday"}</span>
        <span style={{ fontSize: 62, lineHeight: "74px", fontWeight: 600, fontFamily: fonts.rounded }}>24°</span>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, opacity: 0.9 }}>{zh ? "晴，微风" : "Sunny, light breeze"}</span>
      </div>
      <div style={{ position: "absolute", left: 17, top: 203, display: "flex", gap: 8 }}>
        <Forecast symbol="sun" temperature="26°" day={zh ? "日" : "Sun"} />
        <Forecast symbol="cloudSun" temperature="23°" day={zh ? "一" : "Mon"} />
        <Forecast symbol="rain" temperature="19°" day={zh ? "二" : "Tue"} />
        <Forecast symbol="sun" temperature="25°" day={zh ? "三" : "Wed"} />
      </div>
    </div>
  );
}

/** A capsule and two circles, centred on (`x`, `y`). */
function Cloud({ width, x, y, opacity = 1 }: { width: number; x: number; y: number; opacity?: number }) {
  const fill = white(0.9);
  const part = (w: number, h: number, dx: number, dy: number) => (
    <div style={{ position: "absolute", left: -w / 2 + dx, top: -h / 2 + dy, width: w, height: h, borderRadius: h / 2, background: fill }} />
  );
  return (
    <div style={{ position: "absolute", left: x, top: y, opacity }}>
      {part(width, width * 0.3, 0, width * 0.1)}
      {part(width * 0.42, width * 0.42, -width * 0.14, 0)}
      {part(width * 0.32, width * 0.32, width * 0.16, width * 0.03)}
    </div>
  );
}

const SUN = "#FFD60A";

/** The multicolour weather symbols (sun.max.fill, cloud.sun.fill, cloud.rain.fill). */
function WeatherSymbol({ kind }: { kind: "sun" | "cloudSun" | "rain" }) {
  const rays = (cx: number, cy: number, r1: number, r2: number, width: number) =>
    Array.from({ length: 8 }, (_, i) => {
      const a = (i * Math.PI) / 4;
      return <line key={i} x1={cx + r1 * Math.cos(a)} y1={cy + r1 * Math.sin(a)} x2={cx + r2 * Math.cos(a)} y2={cy + r2 * Math.sin(a)} stroke={SUN} strokeWidth={width} strokeLinecap="round" />;
    });
  const cloud = (x: number, y: number, s: number) => (
    <path transform={`translate(${x} ${y}) scale(${s})`} d="M4.2 10 A3.2 3.2 0 0 1 4.6 3.7 A4.4 4.4 0 0 1 13 4.6 A2.8 2.8 0 0 1 13 10 Z" fill="#fff" />
  );
  return (
    <svg width={20} height={18} viewBox="0 0 20 18" style={{ overflow: "visible" }}>
      {kind === "sun" && (
        <>
          <circle cx={10} cy={9} r={4.1} fill={SUN} />
          {rays(10, 9, 6.2, 8.2, 1.7)}
        </>
      )}
      {kind === "cloudSun" && (
        <>
          <circle cx={13.2} cy={6} r={3.1} fill={SUN} />
          {rays(13.2, 6, 4.7, 6.2, 1.4)}
          {cloud(0.5, 5.5, 1)}
        </>
      )}
      {kind === "rain" && (
        <>
          {cloud(1.5, 0.5, 1.05)}
          {[5.5, 9.5, 13.5].map((x) => (
            <line key={x} x1={x + 1} y1={13} x2={x} y2={16.6} stroke="#3AC4FF" strokeWidth={1.7} strokeLinecap="round" />
          ))}
        </>
      )}
    </svg>
  );
}

function Forecast({ symbol, temperature, day }: { symbol: "sun" | "cloudSun" | "rain"; temperature: string; day: string }) {
  return (
    <div style={{ width: 48, height: 66, borderRadius: 14, background: black(0.22), display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4 }}>
      <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, opacity: 0.8 }}>{day}</span>
      <div style={{ height: 18, display: "grid", placeItems: "center" }}>
        <WeatherSymbol kind={symbol} />
      </div>
      <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{temperature}</span>
    </div>
  );
}
