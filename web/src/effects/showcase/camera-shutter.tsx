/** showcase.camera-shutter · 相机快门 (Showcase+CameraShutter.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Image as ImageIcon, RefreshCcw, ZapOff } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { NumericText, black, clamp, fonts, hex, localPoint, rubberBand, spring, springAt, springDB, useAutoplay, useClock, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { LandscapeArt, Signature, SignatureRim, signatureCard } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioScene, studioClock, studioEase } from "./_studio";

const W = 244;
const FH = 132;
const THUMB = 44;
const CELL = 62;
const MODES: [string, string][] = [["Video", "视频"], ["Photo", "照片"], ["Portrait", "人像"], ["Pano", "全景"]];
const SEEDS = [4, 0, 1, 2];
const TARGET = { x: 22, y: 206 };

function Chip({ children }: { children: ReactNode }) {
  return (
    <span style={{ height: 18, padding: "0 7px", borderRadius: 9, background: black(0.45), display: "flex", alignItems: "center", gap: 4, fontFamily: fonts.rounded, fontSize: 9, fontWeight: 800, fontVariantNumeric: "tabular-nums", color: "#fff", whiteSpace: "nowrap" }}>{children}</span>
  );
}

function RecordChip({ start }: { start: number }) {
  useClock(true, 10);
  const seconds = (performance.now() - start) / 1000;
  return (
    <Chip>
      <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#FF3B30", opacity: Math.trunc(seconds * 2) % 2 === 0 ? 1 : 0.25 }} />
      {studioClock(seconds)}
    </Chip>
  );
}

export default function CameraShutter({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [mode, setModeState] = useState(1);
  const [shots, setShots] = useState(0);
  const [shotSeed, setShotSeed] = useState(0);
  const [thumbSeed, setThumbSeed] = useState<number | null>(null);
  const [count, setCount] = useState(0);
  const [thumbPops, setThumbPops] = useState(0);
  const [modeChanges, setModeChanges] = useState(0);
  const [recording, setRecording] = useState(false);
  const [recordStart, setRecordStart] = useState(0);
  const [autoPressed, setAutoPressed] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [flips, setFlips] = useState(0);
  const [stripDrag, setStripDrag] = useState(0);
  const [stripLive, setStripLive] = useState(false);
  const st = useRef({ mode: 1, step: 0, pending: 0, press: 0, latch: 0 });
  const fly = Math.max(ctx.n("fly"), 0.1);
  const video = mode === 0;
  useEffect(
    () => () => {
      window.clearTimeout(st.current.pending);
      window.clearTimeout(st.current.press);
      window.clearTimeout(st.current.latch);
    },
    [],
  );

  const shoot = (user: boolean) => {
    const s = st.current;
    if (s.mode === 0) {
      if (user) haptics.tap("medium");
      setRecordStart(performance.now());
      setRecording((r) => !r);
      return;
    }
    if (user) haptics.tap("rigid");
    window.clearTimeout(s.pending);
    const seed = SEEDS[s.mode];
    setShotSeed(seed);
    setShots((n) => n + 1);
    s.pending = window.setTimeout(() => {
      setThumbSeed(seed);
      setThumbPops((n) => n + 1);
      setCount((n) => n + 1);
      if (user) haptics.tap("soft");
    }, (0.12 + fly) * 1000);
  };
  const setMode = (index: number, user: boolean) => {
    if (index === st.current.mode) return;
    if (user) haptics.selection();
    setModeChanges((n) => n + 1);
    st.current.mode = index;
    setModeState(index);
    setStripLive(false);
    setStripDrag(0);
    setRecording(false);
  };
  const autoStep = () => {
    const s = st.current;
    if (s.step % 2 === 0) {
      window.clearTimeout(s.press);
      setAutoPressed(true);
      shoot(false);
      s.press = window.setTimeout(() => setAutoPressed(false), 160);
    } else setMode((s.mode + 1) % MODES.length, false);
    s.step += 1;
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 1.45, delay: 0.7 });

  // Keyframes
  const me = useElapsed(modeChanges, 0.44, true);
  const blur = me < 0 ? 0 : me < 0.14 ? 7 * studioEase(me / 0.14) : 7 * (1 - studioEase((me - 0.14) / 0.3));
  const total = 0.12 + fly + 0.06;
  const se = useElapsed(shots, Math.max(total, 0.42), true);
  const flash = se < 0 ? 0 : se < 0.05 ? se / 0.05 : 1 - studioEase((se - 0.05) / 0.3);
  const blink = se < 0 ? 1 : se < 0.06 ? 1 - 0.015 * studioEase(se / 0.06) : 0.985 + 0.015 * springAt(se - 0.06, 0.25, 0.6);
  const flight = (() => {
    if (se < 0 || se >= 0.1 + fly + 0.05) return null;
    const a = studioEase(Math.min(se / 0.12, 1));
    const b = studioEase(clamp((se - 0.12) / fly));
    const sx = se < 0.12 ? 1 - 0.1 * a : 0.9 + (THUMB / W - 0.9) * b;
    const sy = se < 0.12 ? 1 - 0.1 * a : 0.9 + (THUMB / FH - 0.9) * b;
    const x = W / 2 + (TARGET.x - W / 2) * b;
    const t2 = se - 0.12;
    const y = t2 < 0 ? FH / 2 : t2 < fly * 0.3 ? FH / 2 - 12 * studioEase(t2 / (fly * 0.3)) : FH / 2 - 12 + (TARGET.y - (FH / 2 - 12)) * studioEase(clamp((t2 - fly * 0.3) / (fly * 0.7)));
    const opacity = se < 0.1 + fly ? 1 : 1 - (se - 0.1 - fly) / 0.05;
    return { sx, sy, x, y, opacity };
  })();
  const te = useElapsed(thumbPops, 0.6, true);
  const thumbScale = te < 0 ? 1 : te < 0.1 ? 1 + 0.18 * studioEase(te / 0.1) : 1.18 - 0.18 * springAt(te - 0.1, 0.3, 0.5);

  // Mode strip gesture
  const strip = useRef({ down: false, startX: 0, active: false, lastX: 0, lastT: 0, v: 0 });
  const stripGesture = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      const x = localPoint(e, e.currentTarget).x;
      strip.current = { down: true, startX: x, active: false, lastX: x, lastT: performance.now(), v: 0 };
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      const g = strip.current;
      if (!g.down) return;
      const x = localPoint(e, e.currentTarget).x;
      const now = performance.now();
      g.v = g.v * 0.6 + ((x - g.lastX) / Math.max((now - g.lastT) / 1000, 1 / 240)) * 0.4;
      g.lastX = x;
      g.lastT = now;
      if (!g.active && Math.abs(x - g.startX) < 8) return;
      g.active = true;
      setStripLive(true);
      setStripDrag(rubberBand(x - g.startX, CELL * 1.5));
    },
    onPointerUp: (e: React.PointerEvent<HTMLDivElement>) => {
      const g = strip.current;
      if (!g.down) return;
      g.down = false;
      const x = localPoint(e, e.currentTarget).x;
      if (!g.active) {
        const index = st.current.mode + Math.round((x - W / 2) / CELL);
        if (index >= 0 && index < MODES.length) setMode(index, true);
        return;
      }
      const v = performance.now() - g.lastT > 80 ? 0 : g.v;
      const predicted = x - g.startX + v * 0.25;
      const steps = clamp(Math.round(-predicted / CELL), -1, 1);
      const target = clamp(st.current.mode + steps, 0, MODES.length - 1);
      setStripLive(false);
      if (target === st.current.mode) setStripDrag(0);
      else setMode(target, true);
    },
  };

  const modeSpring = spring(0.4, 0.78);
  const down = pressed || autoPressed;
  const recSpring = spring(0.35, 0.7);

  return (
    <StudioScene ctx={ctx} en="Press the shutter · swipe the modes" zh="按下快门 · 横扫切换模式">
      <div style={{ ...signatureCard(), padding: 16, color: "#fff" }}>
        <div style={{ position: "relative", width: W, display: "flex", flexDirection: "column", gap: 8 }}>
          <div style={{ position: "relative", width: W, height: FH, transform: `scale(${blink})` }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 18, overflow: "hidden" }}>
              <div style={{ position: "absolute", inset: blur > 0.05 ? -14 : 0, filter: blur > 0.05 ? `blur(${blur}px)` : undefined }}>
                <div style={{ position: "absolute", inset: blur > 0.05 ? 14 : 0 }}>
                  <AnimatePresence initial={false}>
                    <motion.div key={mode} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={modeSpring} style={{ position: "absolute", inset: 0 }}>
                      <LandscapeArt seed={SEEDS[mode]} />
                    </motion.div>
                  </AnimatePresence>
                  <svg width={W} height={FH} style={{ position: "absolute", inset: 0 }}>
                    {[1, 2].map((i) => (
                      <g key={i} stroke={white(0.22)} strokeWidth={0.6}>
                        <line x1={(W * i) / 3} y1={0} x2={(W * i) / 3} y2={FH} />
                        <line x1={0} y1={(FH * i) / 3} x2={W} y2={(FH * i) / 3} />
                      </g>
                    ))}
                  </svg>
                  <div style={{ position: "absolute", left: 8, right: 8, top: 8, display: "flex", justifyContent: "space-between" }}>
                    <Chip>
                      <ZapOff size={10} strokeWidth={3} />
                    </Chip>
                    <AnimatePresence initial={false} mode="popLayout">
                      {recording ? (
                        <motion.span key="rec" initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.6, opacity: 0 }} transition={recSpring}>
                          <RecordChip start={recordStart} />
                        </motion.span>
                      ) : (
                        <motion.span key="info" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={recSpring}>
                          <Chip>{video ? "4K · 60" : mode === 2 ? "ƒ 2.8" : "HDR"}</Chip>
                        </motion.span>
                      )}
                    </AnimatePresence>
                  </div>
                </div>
              </div>
              <div style={{ position: "absolute", inset: 0, background: white(clamp(flash * ctx.n("flash"))), pointerEvents: "none" }} />
            </div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 1px ${white(0.12)}`, pointerEvents: "none" }} />
          </div>

          <div {...stripGesture} style={{ position: "relative", width: W, height: 26, touchAction: "none", WebkitMaskImage: "linear-gradient(90deg, transparent, #000 22%, #000 78%, transparent)", maskImage: "linear-gradient(90deg, transparent, #000 22%, #000 78%, transparent)" }}>
            <div style={{ position: "absolute", left: W / 2 - (CELL - 4) / 2, top: 2, width: CELL - 4, height: 22, borderRadius: 11, background: hex(0xff8a1f, 0.16), boxShadow: `inset 0 0 0 1px ${hex(0xff8a1f, 0.4)}` }} />
            <motion.div initial={false} animate={{ x: -(mode - 1.5) * CELL + stripDrag }} transition={stripLive ? { duration: 0 } : modeSpring} style={{ position: "absolute", left: (W - CELL * 4) / 2, top: 0, display: "flex" }}>
              {MODES.map((m, index) => (
                <motion.span key={index} initial={false} animate={{ color: index === mode ? Signature.accent : white(0.5) }} transition={modeSpring} style={{ width: CELL, height: 26, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 800, letterSpacing: zh ? 2 : 0.5, textTransform: "uppercase", whiteSpace: "nowrap" }}>
                  {m[zh ? 1 : 0]}
                </motion.span>
              ))}
            </motion.div>
          </div>

          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", height: 64 }}>
            <div style={{ position: "relative", width: THUMB, height: THUMB, transform: `scale(${thumbScale})` }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 11, overflow: "hidden", background: white(0.08), display: "grid", placeItems: "center", color: white(0.3) }}>
                {thumbSeed === null ? <ImageIcon size={16} strokeWidth={2.2} /> : <LandscapeArt seed={thumbSeed} />}
              </div>
              <div style={{ position: "absolute", inset: 0, borderRadius: 11, boxShadow: `inset 0 0 0 1.5px ${white(0.5)}` }} />
              <AnimatePresence>
                {count > 0 && (
                  <motion.span key="badge" initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0, opacity: 0 }} transition={springDB(0.25, 0.15)} style={{ position: "absolute", right: -6, top: -6, minWidth: 17, height: 17, borderRadius: 8.5, background: Signature.accent, color: Signature.ink, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 10, fontWeight: 800 }}>
                    <NumericText value={count} />
                  </motion.span>
                )}
              </AnimatePresence>
            </div>
            <button
              type="button"
              onPointerDown={() => {
                window.clearTimeout(st.current.latch);
                setPressed(true);
              }}
              onPointerUp={() => (st.current.latch = window.setTimeout(() => setPressed(false), 120))}
              onPointerLeave={() => setPressed(false)}
              onPointerCancel={() => setPressed(false)}
              onClick={() => shoot(true)}
              style={{ position: "relative", width: 64, height: 64, padding: 0, border: 0, background: "none", borderRadius: "50%", cursor: "pointer", display: "grid", placeItems: "center" }}
            >
              <span style={{ position: "absolute", left: 1, top: 1, width: 62, height: 62, borderRadius: "50%", boxShadow: "inset 0 0 0 3.5px #fff" }} />
              <motion.span initial={false} animate={{ scale: down ? ctx.n("press") : 1 }} transition={spring(0.22, 0.6)} style={{ display: "grid", placeItems: "center" }}>
                <motion.span
                  initial={false}
                  animate={{ width: recording ? 26 : 52, height: recording ? 26 : 52, borderRadius: recording ? 7 : 26, backgroundColor: video ? "#FF3B30" : "#FFFFFF" }}
                  transition={{ default: recSpring, backgroundColor: springDB(0.25, 0) }}
                  style={{ display: "block" }}
                />
              </motion.span>
            </button>
            <SportPress
              scale={0.9}
              dim={0.06}
              radius={22}
              onClick={() => {
                haptics.tap("light");
                setFlips((n) => n + 1);
              }}
            >
              <span style={{ width: THUMB, height: THUMB, borderRadius: "50%", background: white(0.1), display: "grid", placeItems: "center", color: "#fff" }}>
                <motion.span initial={false} animate={{ rotate: flips * 180 }} transition={spring(0.5, 0.7)} style={{ display: "grid" }}>
                  <RefreshCcw size={17} strokeWidth={2.6} />
                </motion.span>
              </span>
            </SportPress>
          </div>

          {flight && (
            <div style={{ position: "absolute", left: flight.x - W / 2, top: flight.y - FH / 2, width: W, height: FH, transform: `scale(${flight.sx}, ${flight.sy})`, opacity: flight.opacity, pointerEvents: "none" }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 18, overflow: "hidden" }}>
                <LandscapeArt seed={shotSeed} />
              </div>
              <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: "inset 0 0 0 3px #fff" }} />
            </div>
          )}
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
