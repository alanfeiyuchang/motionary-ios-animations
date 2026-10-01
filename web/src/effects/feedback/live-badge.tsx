/** feedback.live-badge · 直播中角标 (Feedback+LiveBadge.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { Eye, MicVocal } from "lucide-react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, hex, mix, spring, useClock, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { track } from "./shared";

const AUDIENCE = 1284;

export default function LiveBadge({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [live, setLive] = useState(true);
  const liveRef = useRef(true);
  const [viewers, setViewers] = useState(AUDIENCE);
  const [delta, setDelta] = useState(12);
  const [changes, setChanges] = useState(0);
  const [wentLive, setWentLive] = useState(0);
  /** 1 = live, 0 = offline; springs between them (the look of everything keyed on `live`). */
  const lv = useMotionValue(1);
  /** The ring that sweeps the picture when going live: 1 is its spread, invisible end state. */
  const sweep = useMotionValue(1);
  const running = useRef<ReturnType<typeof animate>[]>([]);
  useEffect(() => () => running.current.forEach((a) => a.stop()), []);

  const tick = ctx.n("tick");
  useEffect(() => {
    if (!live) return;
    const id = window.setInterval(() => {
      const change = Math.floor(Math.random() * 34) - 9;
      if (change === 0) return;
      setDelta(change);
      setChanges((n) => n + 1);
      setViewers((v) => Math.max(v + change, 1));
    }, Math.max(tick, 0.1) * 1000);
    return () => window.clearInterval(id);
  }, [live, tick]);

  const toggle = () => {
    haptics.tap("medium");
    running.current.forEach((a) => a.stop());
    running.current = [];
    clearAll();
    if (liveRef.current) {
      liveRef.current = false;
      setLive(false);
      running.current.push(animate(lv, 0, spring(0.4, 0.8)));
      return;
    }
    setWentLive(performance.now() / 1000);
    sweep.set(0);
    setViewers(0);
    liveRef.current = true;
    setLive(true);
    running.current.push(animate(lv, 1, spring(0.4, 0.55)));
    after(0.03, () => {
      running.current.push(animate(sweep, 1, anim.easeOut(0.8)));
      // The audience pours in: the count climbs in eased steps so the digits keep rolling.
      const steps = 9;
      for (let step = 1; step <= steps; step++) {
        after(0.25 + (step - 1) * 0.09, () => {
          if (!liveRef.current) return;
          setViewers(Math.round(AUDIENCE * (1 - (1 - step / steps) ** 2.4)));
        });
      }
    });
  };

  const saturation = useTransform(lv, (v) => `saturate(${Math.max(mix(0.15, 1, v), 0)})`);
  const dim = useTransform(lv, (v) => Math.min(Math.max(0.4 * (1 - v), 0), 1));
  const chipX = useTransform(lv, (v) => -46 * (1 - v));
  const chipScale = useTransform(lv, (v) => mix(0.7, 1, v));
  const redOpacity = useTransform(lv, (v) => Math.min(Math.max(v, 0), 1));
  const glow = useTransform(lv, (v) => `0 2px 10px ${hex(0xff2d4b, Math.min(Math.max(0.55 * v, 0), 1))}`);
  const sweepOpacity = useTransform(sweep, (v) => 0.7 * (1 - v));
  const sweepScale = useTransform(sweep, (v) => 1 + 21 * v);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div onClick={toggle} style={{ position: "relative", width: 300, height: 270, flexShrink: 0, borderRadius: 26, boxShadow: `0 10px 18px ${black(0.2)}`, cursor: "pointer" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden", isolation: "isolate" }}>
          <motion.div style={{ position: "absolute", inset: 0, filter: saturation }}>
            <Video preview={ctx.isPreview} />
          </motion.div>
          <motion.div style={{ position: "absolute", inset: 0, background: "#000", opacity: dim }} />
          <motion.div style={{ position: "absolute", left: 14, top: 14, width: 30, height: 30, borderRadius: "50%", border: `2px solid ${white(1)}`, opacity: sweepOpacity, scale: sweepScale, pointerEvents: "none" }} />
          <div style={{ position: "absolute", left: 14, top: 14, display: "flex", alignItems: "center", gap: 8 }}>
            <motion.div style={{ position: "relative", height: 28, borderRadius: 14, padding: "0 10px", display: "flex", alignItems: "center", gap: 6, color: "#fff", background: "rgb(82 82 82)", boxShadow: glow, zIndex: 1 }}>
              <motion.div style={{ position: "absolute", inset: 0, borderRadius: 14, background: "linear-gradient(#FF5A6E, #E5213F)", opacity: redOpacity }} />
              <div style={{ position: "relative", width: 10, height: 10, flexShrink: 0 }}>
                <Dot lv={lv} live={live} wentLive={wentLive} period={ctx.n("period")} reach={ctx.n("reach")} preview={ctx.isPreview} />
              </div>
              <BadgeLabel text={live ? (zh ? "直播中" : "LIVE") : zh ? "未开播" : "OFFLINE"} kerning={zh ? 0 : 0.6} transition={live ? spring(0.4, 0.55) : spring(0.4, 0.8)} />
            </motion.div>
            <motion.div style={{ position: "relative", height: 28, borderRadius: 14, padding: "0 10px", display: "flex", alignItems: "center", gap: 5, color: "#fff", background: black(0.42), boxShadow: `inset 0 0 0 0.5px ${white(0.16)}`, x: chipX, opacity: redOpacity, scale: chipScale, transformOrigin: "0% 50%" }}>
              <Eye size={13} fill="#fff" stroke="rgb(40 30 45)" strokeWidth={2} />
              <NumericText value={viewers} text={viewers.toLocaleString("en-US")} style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600 }} />
              <Delta delta={delta} changes={changes} />
            </motion.div>
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: 14, display: "flex", alignItems: "center", gap: 10, background: `linear-gradient(${black(0)}, ${black(0.55)})`, color: "#fff" }}>
            <div style={{ width: 36, height: 36, borderRadius: "50%", background: Palette.sunset, boxShadow: `inset 0 0 0 1.5px ${white(0.8)}`, display: "grid", placeItems: "center", flexShrink: 0 }}>
              <MicVocal size={17} strokeWidth={2.4} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{zh ? "屋顶不插电现场" : "Rooftop acoustic set"}</span>
              <span style={{ fontSize: 12, lineHeight: "16px", opacity: 0.75, whiteSpace: "nowrap" }}>{zh ? "夏树 · 第 3 首" : "Natsuki · song 3"}</span>
            </div>
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to end or start the stream" zh="点击结束或开始直播" />
    </div>
  );
}

/** The badge text: cross-fades (`contentTransition(.opacity)`) while the capsule's width follows. */
function BadgeLabel({ text, kerning, transition }: { text: string; kerning: number; transition: ReturnType<typeof spring> }) {
  const measure = useRef<HTMLSpanElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  useLayoutEffect(() => {
    if (measure.current) setWidth(measure.current.offsetWidth);
  }, [text, kerning]);
  const font = { fontSize: 12, lineHeight: "16px", fontWeight: 800, letterSpacing: kerning, whiteSpace: "nowrap" as const };
  return (
    <motion.div initial={false} animate={width === null ? undefined : { width }} transition={transition} style={{ position: "relative", height: 16, width: width ?? undefined }}>
      <span ref={measure} style={{ ...font, position: "absolute", left: 0, top: 0, visibility: "hidden" }}>{text}</span>
      <AnimatePresence initial={false}>
        <motion.span key={text} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={transition} style={{ ...font, position: "absolute", left: 0, top: 0 }}>
          {text}
        </motion.span>
      </AnimatePresence>
    </motion.div>
  );
}

/** The green '+12' / coral '−5' that floats up beside the count on every change. */
function Delta({ delta, changes }: { delta: number; changes: number }) {
  const e = useElapsed(changes, 0.7, true);
  const playing = e >= 0 && e < 0.7;
  const lift = playing ? track(e, 4, [{ cubic: -8, d: 0.7 }]) : 4;
  const opacity = playing
    ? track(e, 0, [
        { linear: 1, d: 0.12 },
        { linear: 1, d: 0.28 },
        { linear: 0, d: 0.3 },
      ])
    : 0;
  return (
    <span style={{ position: "absolute", right: 0, top: 0, transform: `translate(26px, ${6 + lift}px)`, opacity, fontSize: 11, lineHeight: "13px", fontWeight: 700, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap", color: delta >= 0 ? "#6DF0A6" : Palette.coral, pointerEvents: "none" }}>
      {delta >= 0 ? `+${delta}` : `−${-delta}`}
    </span>
  );
}

/** The dot: a two-beat heartbeat and the rings each beat releases. */
function Dot({ lv, live, wentLive, period, reach, preview }: { lv: MotionValue<number>; live: boolean; wentLive: number; period: number; reach: number; preview: boolean }) {
  useClock(live, preview ? 30 : undefined);
  const on = Math.min(Math.max(lv.get(), 0), 1);
  const elapsed = performance.now() / 1000 - wentLive;
  const cycle = Math.max(period, 0.2);
  const p = (elapsed / cycle) % 1;
  const phase = p < 0 ? p + 1 : p;
  const echo = phase - 0.28;
  const beat = 0.22 * Math.exp(-phase * 9) + (echo >= 0 ? 0.12 * Math.exp(-echo * 12) : 0);
  const ring = (progress: number, dim: number) => {
    const eased = 1 - (1 - Math.min(Math.max(progress, 0), 1)) ** 2.2;
    const scale = 1 + (reach - 1) * eased;
    return <circle cx={5} cy={5} r={4 * scale} fill="none" stroke="#fff" strokeWidth={1.4} opacity={(live ? 0.75 * (1 - eased) : 0) * dim} />;
  };
  return (
    <svg width={10} height={10} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
      {ring(phase, 1)}
      {ring(echo >= 0 ? echo / 0.72 : 1, 0.6)}
      <circle cx={5} cy={5} r={4 * mix(0.8, 1 + beat, on)} fill="#fff" opacity={mix(0.6, 1, on)} />
    </svg>
  );
}

/** A warm stage: slow spotlights over a dark gradient, so the thumbnail feels like video. */
function Video({ preview }: { preview: boolean }) {
  const t = useClock(true, preview ? 20 : 30) + 2;
  const spot = (colour: number, x: number, y: number, size: number) => (
    <div
      style={{
        position: "absolute",
        left: 150 + x - size / 2,
        top: 135 + y - size / 2,
        width: size,
        height: size,
        borderRadius: "50%",
        background: `radial-gradient(circle closest-side, ${hex(colour, 0.75)}, ${hex(colour, 0)})`,
        mixBlendMode: "screen",
      }}
    />
  );
  const sway = 3 * Math.sin(t * 1.3);
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", isolation: "isolate", background: "linear-gradient(#1A1033, #3A1650, #7A2A4A)" }}>
      {spot(0xff8a3d, 70 * Math.sin(t * 0.5), -30 + 16 * Math.cos(t * 0.4), 190)}
      {spot(0xb04bff, -80 * Math.cos(t * 0.37), 40 + 20 * Math.sin(t * 0.6), 210)}
      {spot(0xffd27a, 20 + 30 * Math.sin(t * 0.8), 70, 120)}
      {/* The performer, as a simple silhouette. */}
      <div style={{ position: "absolute", left: 128 + sway, top: 134, width: 44, height: 44, borderRadius: "50%", background: black(0.55) }} />
      <div style={{ position: "absolute", left: 108 + sway, top: 172, width: 84, height: 120, borderRadius: 42, background: black(0.55) }} />
    </div>
  );
}
