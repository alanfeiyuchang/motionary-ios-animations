/** loading.buffer-scrub · 缓冲进度条 (Loading+BufferScrub.swift) */
import { AnimatePresence, motion } from "motion/react";
import { ArrowDown, Pause, Play } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, demoCard, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { primary, useAnimatedNumber } from "./shared";
import { css, mixColor } from "./round2";

const BAR = 272;
const VIDEO_H = 150;
/** Playback resumes once this much is buffered ahead. */
const RESUME_GAP = 0.07;
/** Uneven burst sizes, as multiples of the `burst` parameter. */
const FACTORS = [1.5, 0.45, 1.3, 0.4, 1.7, 0.6, 1.1, 0.35];
const VIDEO_SECONDS = 200;

function timeString(fraction: number) {
  const seconds = Math.floor(Math.min(Math.max(fraction, 0), 1) * VIDEO_SECONDS);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
}

/** The "video": a day passing over two ridges. It only moves when the play head does. */
function drawScene(g: CanvasRenderingContext2D, progress: number) {
  const w = BAR;
  const h = VIDEO_H;
  const p = Math.min(Math.max(progress, 0), 1);
  const dusk = Math.pow(p, 1.6);
  const sky = g.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, css(mixColor("#3C5BD8", "#2B1E66", dusk)));
  sky.addColorStop(1, css(mixColor("#9AD8FF", "#FF8A5C", dusk)));
  g.fillStyle = sky;
  g.fillRect(0, 0, w, h);

  const sx = 28 + (w - 56) * p;
  const sy = h * 0.78 - h * 0.56 * Math.sin(Math.PI * (0.12 + 0.76 * p));
  const halo = g.createRadialGradient(sx, sy, 8, sx, sy, 46);
  halo.addColorStop(0, "rgb(255 243 196 / 0.7)");
  halo.addColorStop(1, "rgb(255 243 196 / 0)");
  g.beginPath();
  g.arc(sx, sy, 46, 0, Math.PI * 2);
  g.fillStyle = halo;
  g.fill();
  g.beginPath();
  g.arc(sx, sy, 13, 0, Math.PI * 2);
  g.fillStyle = "#FFF6D6";
  g.fill();

  g.fillStyle = white(0.42);
  for (let index = 0; index < 3; index++) {
    const x = w * (0.2 + 0.36 * index) - 60 * p;
    const y = 26 + 16 * (index % 2);
    g.beginPath();
    g.roundRect(x, y, 54, 13, 6.5);
    g.fill();
    g.beginPath();
    g.roundRect(x + 14 + 10, y - 7, 34, 13, 6.5);
    g.fill();
  }

  const ridge = (base: number, amplitude: number, wavelength: number, shift: number, color: string) => {
    g.beginPath();
    g.moveTo(0, h);
    for (let x = 0; x <= w + 6; x += 6) {
      const a = ((x + shift) / wavelength) * 2 * Math.PI;
      g.lineTo(x, h * base - amplitude * (Math.sin(a) * 0.65 + Math.sin(a * 2.3 + 1) * 0.35));
    }
    g.lineTo(w, h);
    g.closePath();
    g.fillStyle = color;
    g.fill();
  };
  ridge(0.58, 22, 150, 40 * p, "rgb(46 60 140 / 0.75)");
  ridge(0.74, 16, 96, 110 * p, "#161A45");
}

/** An arc that spins for as long as it is on screen. */
function Spinner({ color, lineWidth, size }: { color: string; lineWidth: number; size: number }) {
  const r = size / 2;
  const c = 2 * Math.PI * r;
  return (
    <motion.svg
      width={size}
      height={size}
      viewBox={`0 0 ${size} ${size}`}
      animate={{ rotate: 360 }}
      transition={{ duration: 0.7, ease: "linear", repeat: Infinity }}
      style={{ overflow: "visible", display: "block" }}
    >
      <circle cx={r} cy={r} r={r} fill="none" stroke={color} strokeWidth={lineWidth} strokeLinecap="round" strokeDasharray={`${0.7 * c} ${c}`} strokeDashoffset={-0.08 * c} />
    </motion.svg>
  );
}

export default function BufferScrub({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const latest = useRef(ctx);
  latest.current = ctx;
  const sim = useRef({ played: 0, bufferStart: 0, buffered: 0.1, stalled: false, scrubbing: false, paused: false, sinceBurst: 0, burstIndex: 0, endedFor: 0 });
  const played = useAnimatedNumber(0);
  const buffered = useAnimatedNumber(0.1);
  const [bufferStart, setBufferStart] = useState(0);
  const [stalled, setStalledState] = useState(false);
  const [scrubbing, setScrubbingState] = useState(false);
  const [paused, setPausedState] = useState(false);
  const [speed, setSpeed] = useState(2.4);
  const [full, setFull] = useState(false);
  const canvas = useRef<HTMLCanvasElement>(null);
  const scrubTimer = useRef(0);

  const setPlayed = (v: number) => {
    sim.current.played = v;
    played.mv.stop();
    played.mv.set(v);
  };
  const setStalled = (v: boolean) => {
    sim.current.stalled = v;
    setStalledState(v);
  };

  const step = (dt: number) => {
    const s = sim.current;
    const c = latest.current;
    if (s.scrubbing) return;
    if (s.buffered < 1) {
      s.sinceBurst += dt;
      if (s.sinceBurst >= Math.max(c.n("interval"), 0.1)) {
        s.sinceBurst = 0;
        const factor = FACTORS[s.burstIndex % FACTORS.length];
        s.burstIndex += 1;
        s.buffered = Math.min(s.buffered + c.n("burst") * factor, 1);
        buffered.to(s.buffered, spring(0.45, 0.85));
        setSpeed(Math.round(c.n("burst") * factor * 15 * 10) / 10);
        setFull(s.buffered >= 1);
      }
    }
    if (s.paused) return;
    if (s.played >= 1) {
      s.endedFor += dt;
      if (s.endedFor > 1.3) {
        // Restart.
        setPlayed(0);
        s.bufferStart = 0;
        setBufferStart(0);
        s.buffered = 0.1;
        buffered.mv.stop();
        buffered.mv.set(0.1);
        setFull(false);
        setStalled(false);
        s.sinceBurst = 0;
        s.burstIndex = 0;
        s.endedFor = 0;
      }
      return;
    }
    if (s.stalled) {
      if (s.buffered - s.played >= RESUME_GAP || s.buffered >= 1) setStalled(false);
      return;
    }
    const next = s.played + dt / Math.max(c.n("length"), 1);
    if (next >= s.buffered && s.buffered < 1) {
      setPlayed(s.buffered);
      setStalled(true);
    } else {
      setPlayed(Math.min(next, 1));
    }
  };
  const stepRef = useRef(step);
  stepRef.current = step;

  useEffect(() => {
    const el = canvas.current;
    const g = el?.getContext("2d");
    if (!el || !g) return;
    const k = Math.max(2, Math.min(window.devicePixelRatio || 1, 3));
    el.width = BAR * k;
    el.height = VIDEO_H * k;
    let raf = 0;
    let last = 0;
    let drawn = -1;
    const tick = latest.current.isPreview ? 1000 / 30 : 0;
    const loop = (now: number) => {
      raf = requestAnimationFrame(loop);
      if (last && now - last < tick - 1) return;
      if (last) stepRef.current(Math.min((now - last) / 1000, 0.1));
      last = now;
      if (sim.current.played !== drawn) {
        drawn = sim.current.played;
        g.setTransform(k, 0, 0, k, 0, 0);
        drawScene(g, drawn);
      }
    };
    raf = requestAnimationFrame(loop);
    return () => {
      cancelAnimationFrame(raf);
      window.clearTimeout(scrubTimer.current);
    };
  }, []);

  const beginScrub = () => {
    haptics.tap();
    sim.current.scrubbing = true;
    setScrubbingState(true);
    setStalled(false);
  };
  const endScrub = () => {
    const s = sim.current;
    s.endedFor = 0;
    const outside = s.played < s.bufferStart || s.played > s.buffered;
    if (outside) {
      // A new range request: the buffer starts over from the play head.
      s.bufferStart = s.played;
      s.buffered = s.played;
      setBufferStart(s.played);
      buffered.mv.stop();
      buffered.mv.set(s.played);
      buffered.target.current = s.played;
      setFull(false);
      s.sinceBurst = Math.max(latest.current.n("interval"), 0.1) * 0.55;
    }
    const starving = outside || (s.buffered - s.played < RESUME_GAP && s.buffered < 1);
    s.scrubbing = false;
    setScrubbingState(false);
    setStalled(starving && s.played < 1);
  };
  const simulateScrub = () => {
    const s = sim.current;
    if (s.scrubbing || s.played >= 0.62) return;
    beginScrub();
    const target = Math.min(s.played + 0.3, 0.9);
    s.played = target;
    played.to(target, anim.easeInOut(0.55));
    window.clearTimeout(scrubTimer.current);
    scrubTimer.current = window.setTimeout(endScrub, 800);
  };
  // Previews also show a seek past the loaded range.
  useAutoplay(ctx.isPreview, simulateScrub, { every: 8, delay: 3.4, intro: false });

  const pan = usePan({
    onChange: (p) => {
      if (!sim.current.scrubbing) beginScrub();
      setPlayed(Math.min(Math.max(p.location.x / BAR, 0), 1));
    },
    onEnd: endScrub,
  });

  const x = BAR * played.value;
  const knob = stalled ? 22 : scrubbing ? 20 : 14;
  const stallSpring = spring(0.35, 0.7);
  const shownTime = timeString(sim.current.played);
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ ...demoCard(24), width: BAR + 24, padding: 12, display: "flex", flexDirection: "column", gap: 10, flex: "none" }}>
        <div
          onClick={() => {
            haptics.tap();
            sim.current.paused = !sim.current.paused;
            setPausedState(sim.current.paused);
          }}
          style={{ position: "relative", width: BAR, height: VIDEO_H, borderRadius: 16, overflow: "hidden" }}
        >
          <canvas ref={canvas} style={{ width: BAR, height: VIDEO_H, display: "block" }} />
          <motion.div initial={false} animate={{ opacity: stalled ? 0.3 : paused ? 0.18 : 0 }} transition={stallSpring} style={{ position: "absolute", inset: 0, background: "#000" }} />
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
            <AnimatePresence>
              {stalled ? (
                <motion.div
                  key="stall"
                  initial={{ scale: 0.8, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0.8, opacity: 0 }}
                  transition={stallSpring}
                  style={{ gridArea: "1 / 1", height: 28, padding: "0 11px", borderRadius: 14, background: black(0.5), color: "#fff", display: "flex", alignItems: "center", gap: 7, fontSize: 12, fontWeight: 600 }}
                >
                  <Spinner color="#fff" lineWidth={2} size={13} />
                  {zh ? "缓冲中" : "Buffering"}
                </motion.div>
              ) : paused ? (
                <motion.div
                  key="paused"
                  initial={{ scale: 0.6, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0.6, opacity: 0 }}
                  transition={spring(0.3, 0.7)}
                  style={{ gridArea: "1 / 1", color: "#fff", display: "grid" }}
                >
                  <Play size={30} fill="currentColor" strokeWidth={2} />
                </motion.div>
              ) : null}
            </AnimatePresence>
          </div>
        </div>

        <div style={{ position: "relative", width: BAR, height: 26 }}>
          <div {...pan} style={{ position: "absolute", inset: -8, touchAction: "none", zIndex: 2 }} />
          <div style={{ position: "absolute", left: 0, top: 10.5, width: BAR, height: 5, borderRadius: 2.5, background: primary(0.12) }} />
          <div
            style={{ position: "absolute", left: BAR * bufferStart, top: 10.5, width: Math.max(BAR * (buffered.value - bufferStart), 0), height: 5, borderRadius: 2.5, background: primary(0.42) }}
          />
          <div style={{ position: "absolute", left: 0, top: 10.5, width: Math.max(x, 0), height: 5, borderRadius: 2.5, background: `linear-gradient(90deg, ${Palette.coral}, ${Palette.red})` }} />
          <motion.div
            initial={false}
            animate={{ width: knob, height: knob, x: -knob / 2, y: -knob / 2 }}
            transition={scrubbing ? spring(0.3, 0.65) : stallSpring}
            style={{ position: "absolute", left: x, top: 13, borderRadius: "50%", background: "#fff", boxShadow: `0 2px 8px ${black(0.28)}`, display: "grid", placeItems: "center" }}
          >
            <AnimatePresence initial={false}>
              {stalled ? (
                <motion.div key="spin" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={stallSpring} style={{ gridArea: "1 / 1" }}>
                  <Spinner color={Palette.red} lineWidth={2.4} size={13} />
                </motion.div>
              ) : (
                <motion.div
                  key="dot"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1, inset: scrubbing ? 5.5 : 4 }}
                  exit={{ opacity: 0 }}
                  transition={stallSpring}
                  style={{ position: "absolute", inset: 4, borderRadius: "50%", background: Palette.red }}
                />
              )}
            </AnimatePresence>
          </motion.div>
          <div style={{ position: "absolute", left: Math.min(Math.max(x - 30, -8), BAR - 52), top: -27, width: 60, height: 24, display: "grid", placeItems: "center", pointerEvents: "none" }}>
            <motion.div
              initial={false}
              animate={{ scale: scrubbing ? 1 : 0.5, opacity: scrubbing ? 1 : 0 }}
              transition={scrubbing ? spring(0.3, 0.65) : stallSpring}
              style={{
                height: 24,
                padding: "0 8px",
                borderRadius: 12,
                background: black(0.78),
                color: "#fff",
                fontSize: 12,
                fontWeight: 600,
                fontVariantNumeric: "tabular-nums",
                display: "flex",
                alignItems: "center",
                whiteSpace: "nowrap",
                transformOrigin: "50% 100%",
              }}
            >
              {shownTime}
            </motion.div>
          </div>
        </div>

        <div style={{ width: BAR, display: "flex", alignItems: "center", gap: 8 }}>
          <span style={{ width: 20, height: 18, display: "grid", placeItems: "center" }}>
            <AnimatePresence mode="popLayout" initial={false}>
              <motion.span
                key={paused ? "play" : "pause"}
                initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
                exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                transition={anim.snappyD(0.3)}
                style={{ display: "grid" }}
              >
                {paused ? <Play size={15} fill="currentColor" strokeWidth={2} /> : <Pause size={15} fill="currentColor" strokeWidth={1} />}
              </motion.span>
            </AnimatePresence>
          </span>
          <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
            {shownTime} / {timeString(1)}
          </span>
          <span style={{ flex: 1 }} />
          <span style={{ display: "flex", alignItems: "center", gap: 3, fontSize: 12, lineHeight: "16px", fontWeight: 600, color: full ? Palette.secondaryLabel : Palette.green }}>
            <ArrowDown size={10} strokeWidth={3.6} />
            <NumericText value={speed} text={`${(full ? 0 : speed).toFixed(1)} MB/s`} />
          </span>
          <span style={{ height: 17, padding: "0 5px", borderRadius: 4, boxShadow: `inset 0 0 0 1px ${primary(0.45)}`, fontSize: 10, fontWeight: 800, display: "flex", alignItems: "center" }}>HD</span>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag the bar · tap the video to pause" zh="拖动进度条 · 点击画面暂停" />
    </div>
  );
}
