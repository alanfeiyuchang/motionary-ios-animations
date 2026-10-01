/** loading.voice-orb · 语音光球 (Loading+VoiceOrb.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { TimeCanvas, css } from "./round2";

const DIAMETER = 150;
const COLORS = [Palette.sky, Palette.violet, Palette.pink, Palette.mint, Palette.amber, Palette.indigo];
const RATES = [0.55, -0.42, 0.78, -0.66, 0.36, -0.9];
const MARGIN = 40;

/** A speech-like loudness in 0…1: syllables riding on slower phrases. */
function loudness(t: number) {
  const syllable = Math.abs(Math.sin(t * 7.1) * Math.sin(t * 2.9 + 0.7));
  const phrase = 0.6 + 0.4 * Math.sin(t * 1.3 + 2);
  return Math.min(0.25 + 0.9 * Math.pow(syllable, 0.7) * phrase, 1);
}

/** A level that eases exponentially toward a target, with its running integral in closed form. */
class Envelope {
  start = performance.now() / 1000;
  from = 0;
  target = 0;
  tau = 0.45;
  area = 0;
  value(now: number) {
    const dt = Math.max(now - this.start, 0);
    return this.target + (this.from - this.target) * Math.exp(-dt / this.tau);
  }
  integral(now: number) {
    const dt = Math.max(now - this.start, 0);
    return this.area + this.target * dt + (this.from - this.target) * this.tau * (1 - Math.exp(-dt / this.tau));
  }
  retarget(target: number, tau: number, now: number) {
    const level = this.value(now);
    this.area = this.integral(now);
    this.from = level;
    this.target = target;
    this.tau = tau;
    this.start = now;
  }
}

const nowS = () => performance.now() / 1000;
const clockT = () => (Date.now() / 1000) % 3600;

export default function VoiceOrb({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const envelope = useRef<Envelope>(null as unknown as Envelope);
  if (!envelope.current) envelope.current = new Envelope();
  const [listening, setListening] = useState(false);
  const listeningRef = useRef(false);
  const pressedAt = useRef(-Infinity);
  const releaseTimer = useRef(0);
  const blobs = Math.max(ctx.i("blobs"), 1);
  const soft = ctx.n("soft");
  const gain = ctx.n("gain");

  const halo = useRef<HTMLDivElement>(null);
  const orb = useRef<HTMLDivElement>(null);
  const rings = useRef<(HTMLDivElement | null)[]>([]);
  const bars = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => () => window.clearTimeout(releaseTimer.current), []);

  const begin = () => {
    window.clearTimeout(releaseTimer.current);
    releaseTimer.current = 0;
    if (listeningRef.current) return;
    listeningRef.current = true;
    setListening(true);
    pressedAt.current = nowS();
    envelope.current.retarget(1, 0.18, nowS());
    haptics.tap("soft");
  };
  const release = (quiet = false) => {
    releaseTimer.current = 0;
    if (!listeningRef.current) return;
    listeningRef.current = false;
    setListening(false);
    envelope.current.retarget(0, 0.45, nowS());
    if (!quiet) haptics.tap("light");
  };
  /** A quick tap still listens for a moment, so the reaction is always visible. */
  const end = () => {
    const remaining = 1.1 - (nowS() - pressedAt.current);
    window.clearTimeout(releaseTimer.current);
    if (remaining <= 0) return release();
    releaseTimer.current = window.setTimeout(() => release(), remaining * 1000);
  };
  const simulate = () => {
    begin();
    window.clearTimeout(releaseTimer.current);
    releaseTimer.current = window.setTimeout(() => release(true), 2200);
  };
  useAutoplay(ctx.isPreview, simulate, { every: 4.4, delay: 0.8 });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ position: "relative", width: 250, height: 216, flex: "none" }}>
        {[0, 1, 2].map((i) => (
          <div
            key={i}
            ref={(el) => {
              rings.current[i] = el;
            }}
            style={{ position: "absolute", left: 125, top: 108, borderRadius: "50%", border: `1.5px solid ${Palette.violet}`, opacity: 0, pointerEvents: "none" }}
          />
        ))}
        <div
          ref={halo}
          style={{
            position: "absolute",
            left: 125 - DIAMETER / 2,
            top: 108 - DIAMETER / 2,
            width: DIAMETER,
            height: DIAMETER,
            borderRadius: "50%",
            filter: "blur(18px)",
            pointerEvents: "none",
          }}
        />
        <div
          ref={orb}
          style={{
            position: "absolute",
            left: 125 - DIAMETER / 2,
            top: 108 - DIAMETER / 2,
            width: DIAMETER,
            height: DIAMETER,
            borderRadius: "50%",
            boxShadow: `0 10px 36px ${css(Palette.violet, 0.35)}`,
            pointerEvents: "none",
          }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              overflow: "hidden",
              background: "radial-gradient(circle closest-side, #1C2150, #0A0B22)",
              isolation: "isolate",
            }}
          >
            <TimeCanvas
              width={DIAMETER + MARGIN * 2}
              height={DIAMETER + MARGIN * 2}
              fps={previewFps(ctx.isPreview)}
              style={{ position: "absolute", left: -MARGIN, top: -MARGIN, filter: `blur(${soft}px)`, mixBlendMode: "plus-lighter" }}
              draw={(g) => {
                const now = nowS();
                const t = clockT();
                const level = envelope.current.value(now);
                const spin = envelope.current.integral(now);
                const voice = level * loudness(t) * gain;
                const breath = 0.02 * Math.sin(t * 1.5);
                const scale = 1 + breath + 0.12 * Math.min(voice, 1.4);
                if (orb.current) orb.current.style.transform = `scale(${scale})`;
                if (halo.current) {
                  halo.current.style.transform = `scale(${1 + 0.1 * Math.min(voice, 1.4)})`;
                  halo.current.style.opacity = String(0.28 + 0.45 * Math.min(voice, 1));
                  halo.current.style.background = `conic-gradient(from ${90 + t * 40}deg, ${Palette.sky}, ${Palette.violet}, ${Palette.pink}, ${Palette.mint}, ${Palette.sky})`;
                }
                rings.current.forEach((el, index) => {
                  if (!el) return;
                  const p = (t * 0.7 + index / 3) % 1;
                  const r = DIAMETER / 2 + 4 + 46 * p;
                  el.style.width = el.style.height = `${r * 2}px`;
                  el.style.marginLeft = el.style.marginTop = `${-r}px`;
                  el.style.opacity = level > 0.02 ? String(0.5 * level * (1 - p) * Math.min(p * 6, 1)) : "0";
                });
                bars.current.forEach((el, index) => {
                  if (!el) return;
                  const v = loudness(t - index * 0.07) * (index === 2 ? 1 : index % 4 === 0 ? 0.55 : 0.8);
                  el.style.height = `${4 + 16 * Math.min(level * v * gain, 1)}px`;
                  el.style.opacity = String(0.35 + 0.65 * Math.min(level, 1));
                });

                const radius = DIAMETER / 2;
                const c = MARGIN + radius;
                const reach = 0.34 + 0.24 * Math.min(voice, 1.3);
                g.globalCompositeOperation = "screen";
                for (let index = 0; index < blobs; index++) {
                  const rate = RATES[index % RATES.length];
                  const angle = (t + 1.4 * spin) * rate * 2.2 + index * 2.1;
                  const wobble = 0.5 + 0.5 * Math.sin(t * (0.9 + 0.23 * index) + index);
                  const distance = radius * reach * (0.7 + 0.3 * wobble);
                  const w = radius * (0.66 + 0.18 * wobble + 0.22 * Math.min(voice, 1));
                  const h = w * 0.62;
                  g.beginPath();
                  g.ellipse(c + distance * Math.cos(angle), c + distance * Math.sin(angle), w / 2, h / 2, angle * 0.8, 0, Math.PI * 2);
                  g.fillStyle = css(COLORS[index % COLORS.length], 0.78);
                  g.fill();
                }
                g.globalCompositeOperation = "source-over";
              }}
            />
          </div>
          {/* Glass: a soft top-left specular and a rim that is brighter on the lit side. */}
          <div
            style={{
              position: "absolute",
              left: DIAMETER / 2 - 42 - 14,
              top: DIAMETER / 2 - 22 - 42,
              width: 84,
              height: 44,
              borderRadius: "50%",
              background: `linear-gradient(${white(0.42)}, ${white(0)})`,
              filter: "blur(6px)",
            }}
          />
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              padding: 1.2,
              background: `linear-gradient(135deg, ${white(0.55)}, ${white(0.06)})`,
              WebkitMask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
            }}
          />
        </div>
        {/* `.contentShape(Circle().inset(by: 20))`: the touch target. */}
        <div
          onPointerDown={(e) => {
            e.currentTarget.setPointerCapture(e.pointerId);
            begin();
          }}
          onPointerUp={end}
          onPointerCancel={end}
          style={{ position: "absolute", left: 125 - 88, top: 108 - 88, width: 176, height: 176, borderRadius: "50%", touchAction: "none", cursor: "pointer" }}
        />
      </div>
      <div style={{ height: 22, display: "flex", alignItems: "center", gap: 4, flex: "none" }}>
        {[0, 1, 2, 3, 4].map((i) => (
          <div
            key={i}
            ref={(el) => {
              bars.current[i] = el;
            }}
            style={{ width: 4, height: 4, borderRadius: 2, background: `linear-gradient(to top, ${Palette.sky}, ${Palette.violet})`, opacity: 0.35 }}
          />
        ))}
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6 }}>
        <div style={{ position: "relative", height: 20, display: "grid", placeItems: "center", fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>
          <AnimatePresence initial={false}>
            <motion.span
              key={listening ? "on" : "off"}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={anim.smoothD(0.3)}
              style={{ gridArea: "1 / 1" }}
            >
              {listening ? ctx.t("Listening…", "正在聆听…") : ctx.t("Ask me anything", "有什么可以帮你")}
            </motion.span>
          </AnimatePresence>
        </div>
        <DemoHint ctx={ctx} en="Press and hold the orb" zh="按住光球" />
      </div>
    </div>
  );
}
