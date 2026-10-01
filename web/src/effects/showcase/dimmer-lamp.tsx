/** showcase.dimmer-lamp · 调光吊灯 (Showcase+DimmerLamp.swift) */
import { Lightbulb } from "lucide-react";
import { useRef, useState } from "react";
import { NumericText, black, clamp, fonts, rubberBand, spring, useAutoplay, useElapsed, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { Signature, signatureEyebrow, signatureNumber } from "./signature";
import { StudioScene, studioEase, studioMix, useAnimatedNumber, useStudioScript } from "./_studio";

const W = 224;
const H = 280;
const BULB = { x: 112, y: 96 };

/** Piecewise smooth keyframes: `[value, duration]` segments starting from `from`. */
function keyframes(e: number, from: number, frames: [number, number][]): number {
  if (e < 0) return frames[frames.length - 1][0];
  let t = e;
  let v = from;
  for (const [to, d] of frames) {
    if (t < d) return v + (to - v) * studioEase(t / d);
    t -= d;
    v = to;
  }
  return v;
}

export default function DimmerLamp({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [litRaw, litApi] = useAnimatedNumber(0.68);
  const [stretch, stretchApi] = useAnimatedNumber(0);
  const [drag, dragApi] = useAnimatedNumber(0);
  const [isOn, setIsOn] = useState(true);
  const [blooms, setBlooms] = useState(0);
  const [swings, setSwings] = useState(0);
  const st = useRef({ level: 0.68, isOn: true, dragging: false, startLevel: 0, touchStart: 0, lastTap: -1e9, atLimit: false, scripting: false, moved: false });
  const script = useStudioScript();
  const travel = ctx.n("travel");
  const warm = ctx.b("warm");

  const lit = clamp(litRaw);
  const tone = (a = 1) => (warm ? studioMix(0xff8f33, 0xfff0da, lit, a) : studioMix(0xffd9a3, 0xffd9a3, 0, a));
  const kelvin = warm ? Math.trunc((2200 + 1800 * lit) / 50) * 50 : 3000;

  const beginDrag = () => {
    const s = st.current;
    s.startLevel = s.isOn ? s.level : 0;
    s.touchStart = performance.now();
    s.dragging = true;
    s.moved = false;
    dragApi.animateTo(1, spring(0.3, 0.75));
  };
  const setLevel = (raw: number) => {
    const s = st.current;
    const c = clamp(raw);
    s.level = c;
    s.isOn = c > 0.004;
    setIsOn(s.isOn);
    litApi.set(s.isOn ? c : 0);
    const over = raw > 1 ? raw - 1 : raw < 0 ? raw : 0;
    stretchApi.set(rubberBand(over * travel, 15));
    const limit = over !== 0;
    if (limit !== s.atLimit) {
      s.atLimit = limit;
      if (limit && !s.scripting) haptics.tap("rigid");
    }
  };
  const endDrag = () => {
    const s = st.current;
    if (!s.dragging) return;
    s.atLimit = false;
    s.dragging = false;
    stretchApi.animateTo(0, spring(0.35, 0.55));
    dragApi.animateTo(0, spring(0.35, 0.55));
  };
  const toggle = () => {
    const s = st.current;
    const turningOn = !(s.isOn && s.level > 0.004);
    if (turningOn && s.level < 0.08) s.level = 0.6;
    s.isOn = turningOn;
    setIsOn(turningOn);
    litApi.animateTo(turningOn ? s.level : 0, spring(0.5, 0.62));
    if (turningOn) setBlooms((n) => n + 1);
    setSwings((n) => n + 1);
  };
  const registerTap = () => {
    const now = performance.now();
    if (now - st.current.lastTap < 450) {
      st.current.lastTap = -1e9;
      haptics.tap("medium");
      toggle();
    } else st.current.lastTap = now;
  };
  const runScript = () => {
    script.run(async (task) => {
      const s = st.current;
      s.scripting = true;
      if (!s.isOn) toggle();
      const legs: [number, number][] = [[1.08, 1.0], [0.2, 1.2]];
      let from = s.isOn ? s.level : 0;
      for (const [target, duration] of legs) {
        const origin = from;
        s.dragging = true;
        dragApi.animateTo(1, spring(0.3, 0.75));
        const ok = await task.script(duration, (t) => setLevel(origin + (target - origin) * studioEase(t)));
        if (!task.alive()) return;
        endDrag();
        if (!ok) return;
        from = clamp(target);
        if (!(await task.pause(0.3))) return;
      }
      toggle();
      if (!(await task.pause(0.9))) return;
      s.level = 0.68;
      toggle();
      s.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 7.2, delay: 0.7 });

  const pan = usePan({
    onStart: () => {
      script.cancel();
      st.current.scripting = false;
      if (st.current.dragging) endDrag();
      beginDrag();
    },
    onChange: (p) => {
      const s = st.current;
      if (!(Math.abs(p.translation.y) > 3 || s.moved)) return;
      s.moved = true;
      setLevel(s.startLevel - p.translation.y / travel);
    },
    onEnd: (p) => {
      const moved = Math.abs(p.translation.y) + Math.abs(p.translation.x);
      const wasTap = moved < 8 && performance.now() - st.current.touchStart < 300;
      endDrag();
      if (wasTap) registerTap();
    },
  });

  const be = useElapsed(blooms, 0.72, true);
  const bp = be < 0 ? 0 : keyframes(be, 0, [[0.6, 0.22], [1, 0.5]]);
  const se = useElapsed(swings, 1.51, true);
  const swing = se < 0 ? 0 : keyframes(se, 0, [[3.6, 0.22], [-2.2, 0.42], [1.1, 0.42], [0, 0.45]]);
  const percent = Math.round(lit * 100);
  const showOn = isOn && percent > 0;
  const sy = 1 + Math.abs(stretch) / 300;
  const sx = 1 - Math.abs(stretch) / 900;
  const k = 1 - 0.015 * drag;
  const plus = { mixBlendMode: "plus-lighter" as const };

  return (
    <StudioScene ctx={ctx} en="Drag up or down · double-tap to toggle" zh="上下拖动调光 · 双击开关">
      <div
        {...pan}
        style={{
          position: "relative",
          width: W,
          height: H,
          borderRadius: 30,
          boxShadow: `0 0 68px ${tone(0.32 * lit)}, 0 14px 22px ${black(0.45)}`,
          transformOrigin: stretch > 0 ? "50% 100%" : "50% 0%",
          transform: `scale(${sx * k}, ${sy * k})`,
          touchAction: "none",
          color: "#fff",
        }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: 30, overflow: "hidden", background: "linear-gradient(#1C1C21, #0D0D10)", isolation: "isolate" }}>
          <div style={{ position: "absolute", inset: 0, background: `radial-gradient(215px circle at 50% 36%, ${tone(0.5)}, ${tone(0.12)} 50%, transparent)`, opacity: lit, ...plus }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 58, height: 1, background: white(0.07 + 0.1 * lit) }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 58, background: `linear-gradient(${black(0.22)}, ${black(0.5)})` }} />
          <div style={{ position: "absolute", left: BULB.x - 102, top: BULB.y, width: 204, height: 154, filter: "blur(7px)", opacity: lit, ...plus }}>
            <div style={{ position: "absolute", inset: 0, clipPath: "polygon(64px 0, 140px 0, 204px 154px, 0 154px)", background: `linear-gradient(${tone(0.42)}, ${tone(0.03)})` }} />
          </div>
          <div style={{ position: "absolute", left: BULB.x - 83, top: H - 30 - 14, width: 166, height: 28, borderRadius: "50%", background: tone(), filter: "blur(10px)", opacity: 0.55 * lit, ...plus }} />
          <div
            style={{
              position: "absolute",
              left: BULB.x - 60,
              top: BULB.y - 60,
              width: 120,
              height: 120,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${tone()}, ${tone(0)} 60px)`,
              transform: `scale(${0.3 + 3.2 * bp})`,
              opacity: bp > 0 && bp < 1 ? (1 - bp) * 0.6 * ctx.n("bloom") : 0,
              pointerEvents: "none",
              ...plus,
            }}
          />
          <div style={{ position: "absolute", inset: 0, transformOrigin: "50% 0%", transform: `rotate(${swing}deg)`, pointerEvents: "none" }}>
            <div style={{ position: "absolute", left: W / 2 - 0.75, top: 0, width: 1.5, height: 54, background: white(0.28) }} />
            <div
              style={{
                position: "absolute",
                left: W / 2 - 10,
                top: 86,
                width: 20,
                height: 20,
                borderRadius: "50%",
                background: `radial-gradient(circle, #fff, ${tone()} 11px)`,
                opacity: 0.25 + 0.75 * lit,
                boxShadow: `0 0 ${12 + 36 * lit}px ${tone(lit)}, 0 0 ${60 * lit}px ${tone(0.7 * lit)}`,
              }}
            />
            <svg width={86} height={42} style={{ position: "absolute", left: W / 2 - 43, top: 52, overflow: "visible" }}>
              <defs>
                <linearGradient id="lamp-shade" x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0" stopColor="#4A4A52" />
                  <stop offset="1" stopColor="#202024" />
                </linearGradient>
              </defs>
              <path d="M0 42 C1.72 14.7 20.64 0 34 0 L52 0 C65.36 0 84.28 14.7 86 42 Z" fill="url(#lamp-shade)" stroke={white(0.14)} strokeWidth={1} />
            </svg>
            <div style={{ position: "absolute", left: W / 2 - 40, top: 92, width: 80, height: 4, borderRadius: 2, background: tone(), opacity: 0.15 + 0.85 * lit, boxShadow: `0 0 12px ${tone(lit)}` }} />
          </div>
          <div style={{ position: "absolute", left: 16, right: 16, bottom: 16, display: "flex", alignItems: "flex-end", pointerEvents: "none" }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 1, alignItems: "flex-start" }}>
              <span style={{ ...signatureEyebrow(), display: "flex", alignItems: "center", gap: 5 }}>
                <span style={{ display: "grid", color: showOn ? tone() : Signature.textSecondary }}>
                  <Lightbulb size={12} strokeWidth={2.6} fill={showOn ? "currentColor" : "none"} />
                </span>
                {zh ? "客厅吊灯" : "Living room"}
              </span>
              <span style={{ display: "flex", alignItems: "baseline", gap: 1 }}>
                <span style={{ ...signatureNumber(40), lineHeight: "48px" }}>
                  <NumericText value={percent} />
                </span>
                <span style={{ ...signatureNumber(18), color: Signature.textSecondary }}>%</span>
              </span>
              <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "14px", color: Signature.textSecondary }}>{showOn ? `${kelvin} K` : zh ? "已关闭" : "Off"}</span>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ position: "relative", width: 8, height: 88, borderRadius: 4, background: white(0.1), transformOrigin: "100% 50%", transform: `scaleX(${1 + 0.5 * drag})` }}>
              <div style={{ position: "absolute", left: 0, bottom: 0, width: 8, height: Math.max(8, 88 * lit), borderRadius: 4, background: tone(), boxShadow: `0 0 12px ${tone(0.7 * lit)}` }} />
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 30, padding: 1, background: `linear-gradient(${white(0.18 + 0.2 * lit)}, ${white(0.03)})`, WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)", WebkitMaskComposite: "xor", maskComposite: "exclude", pointerEvents: "none" }} />
      </div>
    </StudioScene>
  );
}
