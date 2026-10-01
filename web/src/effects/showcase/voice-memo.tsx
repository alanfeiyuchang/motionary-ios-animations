/** showcase.voice-memo · 语音备忘录音 (Showcase+VoiceMemo.swift) */
import { AnimatePresence, motion } from "motion/react";
import { AudioLines, Mic, Pause, Play } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, anim, clamp, delayed, hex, localPoint, spring, useAutoplay, useClock, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportLiveDot, SportPress, sportHash } from "./_a-sport";
import { StudioScene, studioClock } from "./_studio";

const RED = "#FF453A";
const W = 252;
const H = 60;
const LIVE_PITCH = 6.5;
const HEAD_INSET = 18;
const PILL_LEAD = 54;
const PILL_TRAIL = 16;
const PILL_W = W - PILL_LEAD - PILL_TRAIL;

function amplitude(index: number, take: number, gain: number): number {
  const seed = take * 17.3;
  const peak = Math.pow(sportHash(index * 1.37 + seed), 1.5);
  const phrase = 0.3 + 0.7 * Math.abs(Math.sin(index * 0.17 + seed));
  return clamp((0.1 + 0.9 * peak * phrase) * gain, 0.07, 1);
}

function slotLevels(samples: number[], slots: number): number[] {
  const count = samples.length;
  if (count === 0) return Array(slots).fill(0.1);
  const sums = Array(slots).fill(0);
  const peaks = Array(slots).fill(0);
  const counts = Array(slots).fill(0);
  for (let index = 0; index < count; index++) {
    const slot = Math.min(slots - 1, Math.trunc((index * slots) / count));
    sums[slot] += samples[index];
    peaks[slot] = Math.max(peaks[slot], samples[index]);
    counts[slot] += 1;
  }
  const result = Array(slots).fill(0.1);
  let lastFilled = 0.1;
  for (let slot = 0; slot < slots; slot++) {
    if (counts[slot] > 0) lastFilled = 0.5 * peaks[slot] + (0.5 * sums[slot]) / counts[slot];
    result[slot] = lastFilled;
  }
  return result;
}

export default function VoiceMemo({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [recording, setRecording] = useState(false);
  const [samples, setSamples] = useState<number[]>(() => Array.from({ length: 84 }, (_, i) => amplitude(i, 3, 1)));
  const [duration, setDuration] = useState(7);
  const [playhead, setPlayhead] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [scrubbing, setScrubbing] = useState(false);
  const [take, setTake] = useState(3);
  const [recordStart, setRecordStart] = useState(0);
  const st = useRef({ recording, samples, playing, playhead, scrubbing, take, cap: 12, userDriven: false, resume: false, lastSlot: -1, duration });
  Object.assign(st.current, { recording, samples, playing, playhead, scrubbing, take, duration });

  const rate = Math.max(ctx.n("rate"), 4);
  const slots = Math.max(ctx.i("bars"), 8);
  const gain = ctx.n("gain");
  const gainRef = useRef(gain);
  gainRef.current = gain;
  const rateRef = useRef(rate);
  rateRef.current = rate;

  const now = useClock(recording, ctx.isPreview ? 30 : undefined);
  void now;

  const stop = () => {
    const s = st.current;
    if (!s.recording) return;
    s.recording = false;
    setDuration(Math.max(s.samples.length / rateRef.current, 0.5));
    setRecording(false);
    setPlayhead(0);
    const finished = s.take;
    window.setTimeout(() => {
      const c = st.current;
      if (!alive.current || c.recording || c.take !== finished || c.playing) return;
      setPlaying(true);
    }, 700);
  };
  const start = (cap: number, user: boolean) => {
    const s = st.current;
    s.cap = cap;
    s.userDriven = user;
    s.recording = true;
    s.samples = [];
    setRecordStart(performance.now());
    setPlaying(false);
    setPlayhead(0);
    setSamples([]);
    setTake((t) => t + 1);
    setRecording(true);
  };
  const alive = useRef(true);
  useEffect(() => {
    alive.current = true;
    return () => void (alive.current = false);
  }, []);

  // record()
  useEffect(() => {
    if (!recording) return;
    const interval = 1 / rate;
    const id = window.setInterval(() => {
      const s = st.current;
      if (!s.recording) return;
      const index = s.samples.length;
      const value = amplitude(index, s.take, gainRef.current);
      s.samples = [...s.samples, value];
      setSamples(s.samples);
      if ((index + 1) * interval >= s.cap) {
        if (s.userDriven) haptics.tap("medium");
        stop();
      }
    }, interval * 1000);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recording, take, rate]);

  // play()
  useEffect(() => {
    if (!playing || scrubbing || recording) return;
    let raf = 0;
    let last = performance.now();
    const frame = (t: number) => {
      const dt = Math.min((t - last) / 1000, 0.1);
      last = t;
      const next = st.current.playhead + dt / st.current.duration;
      if (next >= 1) {
        st.current.playhead = 1;
        setPlayhead(1);
        setPlaying(false);
        return;
      }
      st.current.playhead = next;
      setPlayhead(next);
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [playing, scrubbing, recording]);

  useAutoplay(
    ctx.isPreview,
    () => {
      if (st.current.recording) return;
      start(3.8, false);
    },
    { every: 8.4, delay: 0.8 },
  );

  const userPrimary = () => {
    if (st.current.recording) {
      haptics.tap("medium");
      stop();
    } else {
      haptics.tap("light");
      start(12, true);
    }
  };
  const userTogglePlay = () => {
    haptics.tap("light");
    if (!st.current.playing && st.current.playhead >= 0.999) setPlayhead(0);
    setPlaying((p) => !p);
  };
  const scrub = (fraction: number) => {
    const s = st.current;
    if (!s.scrubbing) {
      s.resume = s.playing;
      s.scrubbing = true;
      setScrubbing(true);
    }
    const c = clamp(fraction);
    s.playhead = c;
    setPlayhead(c);
    const slot = Math.trunc(c * slots);
    if (slot !== s.lastSlot) {
      s.lastSlot = slot;
      haptics.selection();
    }
  };
  const endScrub = () => {
    const s = st.current;
    if (!s.scrubbing) return;
    s.scrubbing = false;
    setScrubbing(false);
    if (s.resume && s.playhead < 0.999) setPlaying(true);
  };

  const t = recording ? Math.max(0, (performance.now() - recordStart) / 1000) : playhead * duration;
  const whole = Math.trunc(t);
  const modeSpring = recording ? spring(0.45, 0.8) : spring(0.6, 0.78);
  const fade = { duration: 0.25 };

  // Waveform
  const levels = recording ? [] : slotLevels(samples, slots);
  const slotPitch = PILL_W / slots;
  const slotBar = Math.max(2, slotPitch * 0.56);
  const count = samples.length;
  const interval = 1 / rate;
  const dragging = useRef(false);
  const wavePointer = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      if ((e.target as HTMLElement).closest("button")) return;
      e.currentTarget.setPointerCapture(e.pointerId);
      dragging.current = true;
      if (!st.current.recording) scrub((localPoint(e, e.currentTarget).x - PILL_LEAD) / PILL_W);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (dragging.current && !st.current.recording) scrub((localPoint(e, e.currentTarget).x - PILL_LEAD) / PILL_W);
    },
    onPointerUp: () => {
      dragging.current = false;
      endScrub();
    },
    onPointerCancel: () => {
      dragging.current = false;
      endScrub();
    },
  };
  const mask = recording ? "linear-gradient(90deg, transparent 0px, #000 80px)" : undefined;

  return (
    <StudioScene ctx={ctx} en="Tap to record, tap to stop · drag the pill" zh="点击录音，再点停止 · 拖动胶囊定位">
      <div style={{ ...signatureCard(), width: 288, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 14, color: "#fff" }}>
        <div style={{ ...signatureEyebrow(), display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ position: "relative", width: 24, height: 24, display: "grid", placeItems: "center" }}>
            <AnimatePresence initial={false}>
              <motion.span key={recording ? "dot" : "wave"} initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0, opacity: 0 }} transition={modeSpring} style={{ position: "absolute", display: "grid", placeItems: "center", color: Signature.accent }}>
                {recording ? <SportLiveDot color={RED} preview={ctx.isPreview} /> : <AudioLines size={13} strokeWidth={2.8} />}
              </motion.span>
            </AnimatePresence>
          </span>
          <span style={{ whiteSpace: "nowrap" }}>{(zh ? "新录音 " : "New memo ") + take}</span>
          <span style={{ flex: 1 }} />
          <span style={{ position: "relative", height: 12 }}>
            <AnimatePresence initial={false} mode="popLayout">
              <motion.span key={String(recording)} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fade} style={{ display: "block", whiteSpace: "nowrap", color: recording ? RED : Signature.lime }}>
                {recording ? (zh ? "录音中" : "Recording") : zh ? "已保存" : "Saved"}
              </motion.span>
            </AnimatePresence>
          </span>
        </div>

        <div style={{ display: "flex", alignItems: "baseline" }}>
          <span style={{ ...signatureNumber(44), lineHeight: "52px" }}>
            <NumericText value={whole} text={studioClock(t)} />
          </span>
          <span style={{ ...signatureNumber(24), color: Signature.textSecondary }}>{"." + (Math.trunc(t * 10) % 10)}</span>
          <span style={{ flex: 1 }} />
          <motion.span initial={false} animate={{ opacity: recording ? 0 : 1 }} transition={modeSpring} style={{ ...signatureNumber(14), color: Signature.textSecondary }}>
            {"/ " + studioClock(duration)}
          </motion.span>
        </div>

        <div {...wavePointer} style={{ position: "relative", width: W, height: H, touchAction: "none" }}>
          <motion.div
            initial={false}
            animate={{ opacity: recording ? 0 : 1, scaleX: recording ? 1.06 : 1, scaleY: recording ? 0.8 : 1 }}
            transition={modeSpring}
            style={{ position: "absolute", inset: 0, borderRadius: H / 2, background: white(0.07), boxShadow: `inset 0 0 0 1px ${Signature.hairline}` }}
          />
          <div style={{ position: "absolute", inset: 0, overflow: "hidden", WebkitMaskImage: mask, maskImage: mask }}>
            <AnimatePresence initial={false}>
              {samples.map((sample, index) => {
                const slot = Math.min(slots - 1, Math.trunc((index * slots) / Math.max(count, 1)));
                const age = count - 1 - index;
                const played = slot + 0.5 < playhead * slots;
                const width = recording ? 3.5 : slotBar;
                const height = recording ? Math.max(4, sample * H) : Math.max(4, (slot < levels.length ? levels[slot] : 0.1) * (H - 22));
                const x = recording ? W - HEAD_INSET - age * LIVE_PITCH : PILL_LEAD + slot * slotPitch + (slotPitch - slotBar) / 2;
                return (
                  <motion.div
                    key={`${take}-${index}`}
                    initial={{ x, width, height, scale: 0.05, opacity: 0, backgroundColor: "rgb(240 240 240)" }}
                    animate={{ x, width, height, scale: 1, opacity: 1, backgroundColor: recording ? "rgb(240 240 240)" : played ? "rgb(255 138 31)" : "rgb(102 102 102)" }}
                    exit={{ scale: 0.05, opacity: 0, transition: spring(0.45, 0.8) }}
                    transition={{
                      default: recording ? anim.linear(interval) : delayed(spring(0.6, 0.78), Math.min(age * 0.004, 0.3)),
                      backgroundColor: recording ? { duration: 0 } : { duration: 0.03 },
                    }}
                    style={{ position: "absolute", left: 0, top: "50%", y: "-50%", borderRadius: 4 }}
                  />
                );
              })}
            </AnimatePresence>
          </div>
          <motion.div
            initial={false}
            animate={{ opacity: recording ? 1 : 0 }}
            transition={modeSpring}
            style={{ position: "absolute", left: W - HEAD_INSET + LIVE_PITCH - 1, top: 0, width: 2, height: H, borderRadius: 1, background: RED, boxShadow: `0 0 5px ${hex(0xff453a, 0.9)}` }}
          />
          <motion.div
            initial={false}
            animate={{ opacity: recording ? 0 : 1 }}
            transition={modeSpring}
            style={{ position: "absolute", left: PILL_LEAD + PILL_W * playhead - 1, top: 8, width: 2, height: H - 16, borderRadius: 1, background: "#fff", boxShadow: `0 0 4px ${white(0.7)}` }}
          />
          <motion.div
            initial={false}
            animate={{ scale: recording ? 0.2 : 1, opacity: recording ? 0 : 1 }}
            transition={modeSpring}
            style={{ position: "absolute", left: 9, top: 11, pointerEvents: recording ? "none" : "auto" }}
          >
            <SportPress scale={0.88} dim={0.05} onClick={userTogglePlay} radius={19}>
              <span style={{ width: 38, height: 38, borderRadius: "50%", background: Signature.accentGradient, boxShadow: `0 2px 6px ${hex(0xff8a1f, 0.5)}`, display: "grid", placeItems: "center", color: Signature.ink }}>
                <AnimatePresence initial={false} mode="popLayout">
                  <motion.span key={String(playing)} initial={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }} exit={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} transition={{ duration: 0.22 }} style={{ display: "grid" }}>
                    {playing ? <Pause size={15} fill="currentColor" strokeWidth={0} /> : <Play size={15} fill="currentColor" strokeWidth={0} style={{ marginLeft: 2 }} />}
                  </motion.span>
                </AnimatePresence>
              </span>
            </SportPress>
          </motion.div>
        </div>

        <div style={{ display: "flex", alignItems: "center" }}>
          <span style={{ position: "relative", width: 84, height: 12 }}>
            <AnimatePresence initial={false}>
              <motion.span key={String(recording)} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={fade} style={{ ...signatureEyebrow(), position: "absolute", left: 0, top: 0, whiteSpace: "nowrap" }}>
                {recording ? (zh ? "轻点停止" : "Tap to stop") : zh ? "轻点重录" : "Tap to record"}
              </motion.span>
            </AnimatePresence>
          </span>
          <span style={{ flex: 1 }} />
          <SportPress scale={0.92} dim={0.05} onClick={userPrimary} radius={30}>
            <span style={{ width: 60, height: 60, borderRadius: "50%", boxShadow: `inset 0 0 0 3px ${white(0.9)}`, display: "grid", placeItems: "center" }}>
              <motion.span
                initial={false}
                animate={{ width: recording ? 24 : 48, height: recording ? 24 : 48, borderRadius: recording ? 7 : 24, boxShadow: recording ? `0 0 12px ${hex(0xff453a, 0.7)}` : `0 0 5px ${hex(0xff453a, 0.3)}` }}
                transition={modeSpring}
                style={{ background: RED, display: "block" }}
              />
            </span>
          </SportPress>
          <span style={{ flex: 1 }} />
          <span style={{ ...signatureEyebrow(), width: 84, display: "flex", alignItems: "center", justifyContent: "flex-end", gap: 4 }}>
            <Mic size={11} strokeWidth={2.8} />
            AAC
          </span>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
