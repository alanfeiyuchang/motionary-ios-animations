/** showcase.sun-arc · 日出日落弧线 (Showcase+SunArc.swift) */
import { Moon, Sun } from "lucide-react";
import { useEffect, useMemo, useRef } from "react";
import { black, clamp, fonts, hex, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { signatureEyebrow, signatureNumber } from "./signature";
import { CanvasLayer, sportHash } from "./_a-sport";
import { StudioScene, studioEase, studioMix, useAnimatedNumber, useStudioScript } from "./_studio";

const W = 300;
const H = 270;
const HORIZON = 186;
const AMP = 72;
const NOON = 12.4;

const KEYS: [number, number, number, number][] = [
  [-0.32, 0x040716, 0x0b1230, 0x18204c],
  [0.0, 0x232759, 0x8e4e7e, 0xf39b5b],
  [0.24, 0x2c5fae, 0x86a6d4, 0xf6c98e],
  [0.6, 0x1867cc, 0x4a98e6, 0x9ccff5],
];
function skyColors(e: number): string[] {
  const first = KEYS[0];
  const last = KEYS[KEYS.length - 1];
  if (e <= first[0]) return [hex(first[1]), hex(first[2]), hex(first[3])];
  if (e >= last[0]) return [hex(last[1]), hex(last[2]), hex(last[3])];
  for (let i = 1; i < KEYS.length; i++) {
    if (e <= KEYS[i][0]) {
      const a = KEYS[i - 1];
      const b = KEYS[i];
      const t = (e - a[0]) / (b[0] - a[0]);
      return [studioMix(a[1], b[1], t), studioMix(a[2], b[2], t), studioMix(a[3], b[3], t)];
    }
  }
  return [hex(last[1]), hex(last[2]), hex(last[3])];
}
const smooth = (from: number, to: number, v: number) => studioEase((v - from) / (to - from));
const clock = (hour: number) => {
  const minutes = clamp(Math.round(hour * 60), 0, 24 * 60 - 1);
  return `${String(Math.trunc(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
};
const span = (hours: number, zh: boolean) => {
  const minutes = Math.max(0, Math.round(hours * 60));
  const h = Math.trunc(minutes / 60);
  const m = String(minutes % 60).padStart(2, "0");
  return zh ? `${h} 小时 ${m} 分` : `${h} h ${m} m`;
};

export default function SunArc({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const now = ctx.n("now");
  const dayLength = ctx.n("day");
  const [hour, hourApi] = useAnimatedNumber(now);
  const [grab, grabApi] = useAnimatedNumber(0);
  const st = useRef({ grabbed: false, grabHour: 12, scripting: false });
  const script = useStudioScript();

  const c = Math.cos((Math.PI * dayLength) / 24);
  const sunrise = NOON - dayLength / 2;
  const sunset = NOON + dayLength / 2;
  const elevation = (h: number) => (Math.cos((2 * Math.PI * (h - NOON)) / 24) - c) / (1 - c);
  const point = (h: number) => ({ x: (W * h) / 24, y: HORIZON - AMP * elevation(h) });

  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (!st.current.grabbed) hourApi.animateTo(now, spring(0.5, 0.8));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [now]);

  const buzz = (style: "light" | "medium") => {
    if (!st.current.scripting) haptics.tap(style);
  };
  const drag = (target: number) => {
    const next = clamp(target, 0.2, 23.8);
    if (!st.current.grabbed) {
      st.current.grabbed = true;
      grabApi.animateTo(1, spring(0.3, 0.7));
      buzz("light");
    }
    if (elevation(hourApi.get()) >= 0 !== elevation(next) >= 0) buzz("medium");
    hourApi.set(next);
  };
  const release = () => {
    if (!st.current.grabbed) return;
    st.current.grabbed = false;
    const snap = spring(ctx.n("snap"), 0.72);
    hourApi.animateTo(now, snap);
    grabApi.animateTo(0, snap);
  };
  const runScript = () => {
    script.run(async (s) => {
      st.current.scripting = true;
      const legs: [number, number][] = [[22.6, 1.5], [4.6, 1.9], [9.5, 0.9]];
      let from = now;
      for (const [target, duration] of legs) {
        const origin = from;
        if (!(await s.script(duration, (t) => drag(origin + (target - origin) * studioEase(t))))) return;
        from = target;
      }
      if (!(await s.pause(0.25))) return;
      release();
      st.current.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 6.2, delay: 0.7 });

  const pan = usePan({
    onStart: () => {
      script.cancel();
      st.current.scripting = false;
      if (!st.current.grabbed) st.current.grabHour = hourApi.get();
    },
    onChange: (p) => drag(st.current.grabHour + (p.translation.x / W) * 24),
    onEnd: release,
  });

  const e = elevation(hour);
  const sun = point(hour);
  const sky = skyColors(e);
  const curve = useMemo(() => {
    let d = "";
    for (let i = 0; i <= 96; i++) {
      const p = point((i / 96) * 24);
      d += `${i === 0 ? "M" : "L"}${p.x.toFixed(2)} ${p.y.toFixed(2)}`;
    }
    return d;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dayLength]);
  const nowPoint = point(now);
  const lit = smooth(-0.08, 0.06, e);
  const core = (a = 1) => studioMix(0xff8a3d, 0xfff8e0, e / 0.45, a);
  const starAmount = smooth(0.02, -0.32, e);
  const starAmountRef = useRef(starAmount);
  starAmountRef.current = starAmount;
  const caption =
    hour < sunrise
      ? zh ? "距日出 " + span(sunrise - hour, true) : "Sunrise in " + span(sunrise - hour, false)
      : hour < sunset
        ? zh ? "距日落 " + span(sunset - hour, true) : "Sunset in " + span(sunset - hour, false)
        : zh ? "日落后 " + span(hour - sunset, true) : span(hour - sunset, false) + " after sunset";
  const marker = { position: "absolute" as const, top: HORIZON - 11, transform: "translate(-50%, -50%)", fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: white(0.7), whiteSpace: "nowrap" as const };

  return (
    <StudioScene ctx={ctx} en="Drag the sun through the day" zh="拖动太阳，走过一整天">
      <div {...pan} style={{ position: "relative", width: W, height: H, borderRadius: 26, boxShadow: `0 14px 22px ${black(0.45)}`, touchAction: "none" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden", background: `linear-gradient(${sky.join(", ")})`, isolation: "isolate" }}>
          {ctx.b("stars") && starAmount > 0.01 && (
            <CanvasLayer
              width={W}
              height={H}
              fps={ctx.isPreview ? 15 : 30}
              draw={(g, t) => {
                for (let index = 0; index < 36; index++) {
                  const x = sportHash(index * 1.7 + 0.3) * W;
                  const y = sportHash(index * 3.1 + 5.2) * 168;
                  const radius = 0.5 + sportHash(index * 7.7) * 1.0;
                  const twinkle = 0.55 + 0.45 * Math.sin(t * (0.9 + sportHash(index * 2.3) * 2.2) + index);
                  g.fillStyle = white(clamp(starAmountRef.current * twinkle));
                  g.beginPath();
                  g.arc(x, y, radius, 0, Math.PI * 2);
                  g.fill();
                }
              }}
            />
          )}
          <div
            style={{
              position: "absolute",
              left: sun.x - 110,
              top: HORIZON - 45,
              width: 220,
              height: 90,
              borderRadius: "50%",
              background: `radial-gradient(90px circle, ${hex(0xffb45c, 0.85)}, transparent)`,
              opacity: Math.max(0, 1 - Math.abs(e) / 0.3),
              mixBlendMode: "plus-lighter",
            }}
          />
          <div style={{ position: "absolute", left: 0, right: 0, top: HORIZON - 1, height: 1, background: white(0.4) }} />
          <div style={{ position: "absolute", left: 0, right: 0, top: HORIZON, bottom: 0, background: `linear-gradient(${black(0.34)}, ${black(0.5)})` }} />
          <svg width={W} height={H} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <clipPath id="sun-arc-below"><rect x={-10} y={HORIZON} width={W + 20} height={H - HORIZON} /></clipPath>
            <clipPath id="sun-arc-above"><rect x={-10} y={0} width={W + 20} height={HORIZON} /></clipPath>
            <path d={curve} fill="none" stroke={white(0.32)} strokeWidth={1.5} strokeLinecap="round" strokeDasharray="2 5" clipPath="url(#sun-arc-below)" />
            <path d={curve} fill="none" stroke={white(0.85)} strokeWidth={2} strokeLinecap="round" clipPath="url(#sun-arc-above)" />
          </svg>
          <span style={{ ...marker, left: (W * sunrise) / 24 - 30 }}>{"↑ " + clock(sunrise)}</span>
          <span style={{ ...marker, left: (W * sunset) / 24 + 30 }}>{clock(sunset) + " ↓"}</span>
          <div style={{ position: "absolute", left: nowPoint.x - 5.5, top: nowPoint.y - 5.5, width: 11, height: 11, borderRadius: "50%", background: black(0.25), boxShadow: `inset 0 0 0 1.5px ${white(0.9)}`, opacity: Math.min(1, Math.abs(hour - now) / 0.6) }} />
          <div style={{ position: "absolute", left: sun.x, top: sun.y, width: 0, height: 0, transform: `scale(${1 + 0.18 * grab})` }}>
            <div style={{ position: "absolute", left: -62, top: -62, width: 124, height: 124, borderRadius: "50%", background: `radial-gradient(circle, ${core(0.6)} 4px, ${core(0)} 56px)`, opacity: lit, mixBlendMode: "plus-lighter" }} />
            <div style={{ position: "absolute", left: -9, top: -9, width: 18, height: 18, borderRadius: "50%", background: "#1B2148", boxShadow: `inset 0 0 0 1.5px ${white(0.55)}`, opacity: 1 - lit }} />
            <div style={{ position: "absolute", left: -11, top: -11, width: 22, height: 22, borderRadius: "50%", background: `radial-gradient(circle, #fff, ${core()} 12px)`, boxShadow: `0 0 20px ${core(0.9)}`, opacity: lit }} />
            <div style={{ position: "absolute", left: -20, top: -20, width: 40, height: 40, borderRadius: "50%", boxShadow: `inset 0 0 0 1.5px ${white(0.75)}`, transform: `scale(${0.5 + 0.5 * grab})`, opacity: clamp(grab) }} />
          </div>
          <div style={{ position: "absolute", left: 18, top: 18, display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start", filter: `drop-shadow(0 1px 5px ${black(0.4)})` }}>
            <span style={{ ...signatureEyebrow(), color: white(0.75), display: "flex", alignItems: "center", gap: 6 }}>
              {e >= 0 ? <Sun size={12} fill="currentColor" strokeWidth={2.6} /> : <Moon size={12} fill="currentColor" strokeWidth={0} />}
              {zh ? "日出日落 · 上海" : "Sun · Shanghai"}
            </span>
            <span style={{ ...signatureNumber(46), lineHeight: "55px", color: "#fff" }}>{clock(hour)}</span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "16px", color: white(0.78) }}>{caption}</span>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, padding: 1, background: `linear-gradient(${white(0.28)}, ${white(0.04)})`, WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)", WebkitMaskComposite: "xor", maskComposite: "exclude", pointerEvents: "none" }} />
      </div>
    </StudioScene>
  );
}
