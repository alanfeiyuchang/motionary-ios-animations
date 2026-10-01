/** showcase.vinyl-scrub · 黑胶搓碟唱机 (Showcase+VinylScrub.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Play, Square } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { clamp, fonts, hex, localPoint, spring, useAutoplay, useClock, useHaptics, white, black, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow } from "./signature";
import { SportPress, sportHash } from "./_a-sport";
import { StudioScene, studioClock, studioEase, useStudioScript } from "./_studio";

const LENGTH = 204;
const DISC = 164;

class VinylModel {
  angle = 0.5;
  omega = 0;
  seconds = 42;
  grabbed = false;
  playing = false;
  target = 3.49;
  tau = 0.6;
  private last: number | null = null;

  step(now: number) {
    const last = this.last;
    this.last = now;
    if (last === null) return;
    const dt = Math.min(Math.max(now - last, 0), 0.05);
    if (this.grabbed || dt <= 0) return;
    const goal = this.playing ? this.target : 0;
    this.omega += (goal - this.omega) * (1 - Math.exp(-dt / Math.max(this.tau, 0.05)));
    this.angle += this.omega * dt;
    this.advance(this.omega * dt);
  }

  advance(delta: number) {
    this.seconds = (this.seconds + delta / this.target) % LENGTH;
    if (this.seconds < 0) this.seconds += LENGTH;
  }
}

export default function VinylScrub({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const model = useRef<VinylModel>(null as unknown as VinylModel);
  if (!model.current) model.current = new VinylModel();
  const m = model.current;
  const [playing, setPlaying] = useState(false);
  const [grabbed, setGrabbed] = useState(false);
  const st = useRef({ playing: false, scripting: false, lastTouch: 0, lastMove: 0, lastTick: 0 });
  const script = useStudioScript();
  const lift = useMotionValue(0);
  const discRef = useRef<HTMLDivElement>(null);

  const targetOmega = ((ctx.i("rpm") === 1 ? 45 : 100 / 3) * 2 * Math.PI) / 60;
  useClock(true, ctx.isPreview ? 30 : undefined);
  m.target = targetOmega;
  m.tau = ctx.n("inertia");
  m.step(performance.now() / 1000);

  const togglePlay = () => {
    st.current.playing = !st.current.playing;
    m.playing = st.current.playing;
    setPlaying(st.current.playing);
    animate(lift, st.current.playing ? 1 : 0, spring(0.55, 0.6));
  };
  const buzz = (style: "medium" | "light") => {
    if (!st.current.scripting) haptics.tap(style);
  };
  const grab = (a: number) => {
    st.current.lastTouch = a;
    st.current.lastMove = performance.now();
    m.grabbed = true;
    m.omega = 0;
    setGrabbed(true);
    buzz("medium");
  };
  const scratch = (a: number) => {
    let delta = a - st.current.lastTouch;
    if (delta > Math.PI) delta -= 2 * Math.PI;
    if (delta < -Math.PI) delta += 2 * Math.PI;
    st.current.lastTouch = a;
    const now = performance.now();
    const dt = Math.max((now - st.current.lastMove) / 1000, 1 / 240);
    st.current.lastMove = now;
    m.angle += delta;
    m.advance(delta);
    m.omega = m.omega * 0.6 + (delta / dt) * 0.4;
    const tick = Math.floor(m.angle / (Math.PI / 6));
    if (tick !== st.current.lastTick) {
      st.current.lastTick = tick;
      buzz("light");
    }
  };
  const release = () => {
    if (!m.grabbed) return;
    if (performance.now() - st.current.lastMove > 90) m.omega = 0;
    m.omega = clamp(m.omega, -40, 40);
    m.grabbed = false;
    setGrabbed(false);
  };
  const userTogglePlay = () => {
    script.cancel();
    st.current.scripting = false;
    togglePlay();
    haptics.tap("medium");
  };

  useEffect(() => {
    const id = window.setTimeout(() => {
      if (!st.current.playing) togglePlay();
    }, 300);
    return () => window.clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const runScript = () => {
    script.run(async (s) => {
      st.current.scripting = true;
      if (!st.current.playing) togglePlay();
      const start = -0.7;
      grab(start);
      const moves: [number, number][] = [[-2.3, 0.42], [1.5, 0.22], [-1.2, 0.26], [2.4, 0.2]];
      let origin = start;
      for (const [delta, duration] of moves) {
        const from = origin;
        if (!(await s.script(duration, (t) => scratch(from + delta * studioEase(t))))) {
          if (s.alive()) st.current.scripting = false;
          release();
          return;
        }
        origin += delta;
      }
      release();
      st.current.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 4.6, delay: 1.6 });

  const polar = (e: React.PointerEvent) => {
    const p = localPoint(e, discRef.current!);
    return Math.atan2(p.y - DISC / 2, p.x - DISC / 2);
  };
  const down = useRef(false);
  const discPointer = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      script.cancel();
      st.current.scripting = false;
      if (m.grabbed) release();
      grab(polar(e));
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current) scratch(polar(e));
    },
    onPointerUp: () => {
      if (down.current) {
        down.current = false;
        release();
      }
    },
    onPointerCancel: () => {
      if (down.current) {
        down.current = false;
        release();
      }
    },
  };

  const rate = m.omega / targetOmega;
  const speed = Math.min(Math.abs(m.omega) / targetOmega, 2.2);
  const k = lift.get();
  const armAngle = -3 + (30 + (17 * m.seconds) / LENGTH + 3) * k;
  const off = Math.abs(rate - 1) > 0.08 && (playing || grabbed || Math.abs(rate) > 0.05);
  const rpmText = ctx.i("rpm") === 1 ? "45 RPM" : "33⅓ RPM";
  const press = spring(0.3, 0.7);
  const sway = Math.sin(m.angle * 2) * 5;

  return (
    <StudioScene ctx={ctx} en="Drag the record to scratch · tap the arm" zh="拖动唱片搓碟 · 点击唱臂">
      <div style={{ ...signatureCard(), width: 284, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ position: "relative", width: 252, height: 180 }}>
          <motion.div
            initial={false}
            animate={{
              boxShadow: grabbed ? `inset 0 0 0 1.5px ${hex(0xff8a1f, 0.9)}, 0 0 12px ${hex(0xff8a1f, 0.55)}` : `inset 0 0 0 1px ${white(0.07)}, 0 0 12px ${hex(0xff8a1f, 0)}`,
            }}
            transition={press}
            style={{ position: "absolute", left: 104 - 88, top: 90 - 88, width: 176, height: 176, borderRadius: "50%", background: black(0.55) }}
          />
          <motion.div
            ref={discRef}
            {...discPointer}
            initial={false}
            animate={{ scale: grabbed ? 0.975 : 1, boxShadow: grabbed ? `0 3px 6px ${black(0.6)}` : `0 8px 12px ${black(0.6)}` }}
            transition={press}
            style={{ position: "absolute", left: 104 - DISC / 2, top: 90 - DISC / 2, width: DISC, height: DISC, borderRadius: "50%", touchAction: "none", cursor: "grab" }}
          >
            <div style={{ position: "absolute", inset: 0, transform: `rotate(${m.angle}rad)` }}>
              <Disc />
            </div>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                pointerEvents: "none",
                opacity: clamp(ctx.n("shimmer") * (0.45 + 0.4 * speed)),
                mixBlendMode: "plus-lighter",
                background: `conic-gradient(from ${20 + sway}deg, transparent 0%, transparent 5%, ${white(0.34)} 11.5%, ${hex(0xffb45c, 0.12)} 16%, transparent 24%, transparent 53%, ${white(0.2)} 61.5%, transparent 71%, transparent 100%)`,
                WebkitMaskImage: "radial-gradient(circle, transparent 32.5px, #000 33.5px, #000 79.5px, transparent 80.5px)",
                maskImage: "radial-gradient(circle, transparent 32.5px, #000 33.5px, #000 79.5px, transparent 80.5px)",
              }}
            />
          </motion.div>
          <div
            onClick={userTogglePlay}
            style={{
              position: "absolute",
              left: 222 - 12,
              top: 87 - 83,
              width: 24,
              height: 166,
              transformOrigin: "12px 26px",
              transform: `rotate(${armAngle}deg) scale(${1 + 0.03 * (1 - k)})`,
              filter: `drop-shadow(${2 + 5 * (1 - k)}px ${2 + 7 * (1 - k)}px ${3 + 6 * (1 - k)}px ${black(0.6 - 0.25 * (1 - k))})`,
              cursor: "pointer",
            }}
          >
            <Arm />
          </div>
          <div
            style={{
              position: "absolute",
              left: 222 - 11,
              top: 30 - 11,
              width: 22,
              height: 22,
              borderRadius: "50%",
              background: "linear-gradient(#D9DADF, #6D6E75)",
              boxShadow: `0 3px 4px ${black(0.5)}`,
              display: "grid",
              placeItems: "center",
              pointerEvents: "none",
            }}
          >
            <span style={{ width: 7, height: 7, borderRadius: "50%", background: black(0.55) }} />
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}>
            <span style={{ ...signatureEyebrow(), whiteSpace: "nowrap" }}>{(zh ? "A 面 · " : "Side A · ") + rpmText}</span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, lineHeight: "20px", whiteSpace: "nowrap" }}>{zh ? "海岸公路" : "Coastal Drive"}</span>
            <span style={{ display: "flex", gap: 4, fontFamily: fonts.rounded, fontSize: 12, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "14px", whiteSpace: "nowrap" }}>
              <span style={{ color: Signature.accentSoft }}>{studioClock(m.seconds)}</span>
              <span style={{ color: Signature.textSecondary }}>{"/ " + studioClock(LENGTH)}</span>
            </span>
          </div>
          <div style={{ flex: 1 }} />
          <span
            style={{
              width: 46,
              height: 24,
              borderRadius: 12,
              display: "grid",
              placeItems: "center",
              fontFamily: fonts.rounded,
              fontSize: 12,
              fontWeight: 700,
              fontVariantNumeric: "tabular-nums",
              color: off ? Signature.ink : Signature.textSecondary,
              background: off ? Signature.accentGradient : white(0.08),
              flexShrink: 0,
            }}
          >
            {rate.toFixed(1).replace("-", "−") + "×"}
          </span>
          <SportPress scale={0.9} dim={0.05} onClick={userTogglePlay} radius={22} style={{ flexShrink: 0 }}>
            <span style={{ width: 44, height: 44, borderRadius: "50%", background: Signature.accentGradient, boxShadow: `0 3px 8px ${hex(0xff8a1f, 0.5)}`, display: "grid", placeItems: "center", color: Signature.ink }}>
              <AnimatePresence initial={false} mode="popLayout">
                <motion.span key={playing ? "stop" : "play"} initial={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }} exit={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} transition={{ duration: 0.22 }} style={{ display: "grid" }}>
                  {playing ? <Square size={14} fill="currentColor" strokeWidth={0} /> : <Play size={16} fill="currentColor" strokeWidth={0} />}
                </motion.span>
              </AnimatePresence>
            </span>
          </SportPress>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}

function Disc() {
  const rings = useMemo(() => {
    const out: { r: number; a: number }[] = [];
    let radius = 36;
    let index = 0;
    while (radius < DISC / 2 - 3) {
      const gap = Math.abs(radius - 50) < 1.2 || Math.abs(radius - 64) < 1.2;
      out.push({ r: radius, a: gap ? 0 : 0.035 + 0.075 * sportHash(index) });
      radius += 1.9;
      index += 1;
    }
    return out;
  }, []);
  const c = DISC / 2;
  const pt = (deg: number, r: number) => `${c + Math.cos((deg * Math.PI) / 180) * r} ${c + Math.sin((deg * Math.PI) / 180) * r}`;
  const labelText = { fontFamily: fonts.rounded, fontSize: 6.5, fontWeight: 800, lineHeight: "8px", whiteSpace: "nowrap" as const };
  return (
    <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `radial-gradient(circle, #1D1D21 20px, #050506 ${DISC / 2}px)` }}>
      <svg width={DISC} height={DISC} style={{ position: "absolute", inset: 0 }}>
        {rings.map((ring, i) => (
          <circle key={i} cx={c} cy={c} r={ring.r} fill="none" stroke="#fff" strokeOpacity={ring.a} strokeWidth={0.7} />
        ))}
        <path d={`M${pt(200, 69)}A69 69 0 0 1 ${pt(236, 69)}`} fill="none" stroke="#fff" strokeOpacity={0.16} strokeWidth={1.1} strokeLinecap="round" />
        {[[0.6, 57], [2.9, 74], [4.4, 44]].map(([a, r], i) => (
          <circle key={i} cx={c + Math.cos(a) * r} cy={c + Math.sin(a) * r} r={0.9} fill="#fff" fillOpacity={0.35} />
        ))}
      </svg>
      <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1px ${white(0.12)}` }} />
      <div style={{ position: "absolute", left: c - 30, top: c - 30, width: 60, height: 60, borderRadius: "50%", background: Signature.accentGradient, overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 13 }}>
        <div style={{ position: "absolute", left: 0, top: 30, width: 60, height: 30, background: black(0.22) }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1px ${black(0.25)}` }} />
        <span style={{ ...labelText, letterSpacing: 1.1, color: hex(0x0b0b0d, 0.8), position: "relative" }}>MOTIONARY</span>
        <span style={{ ...labelText, letterSpacing: 0.8, color: white(0.85), position: "relative" }}>A · 33</span>
        <span style={{ position: "absolute", left: 26.5, top: 26.5, width: 7, height: 7, borderRadius: "50%", background: "#C9CACF", boxShadow: `inset 0 0 0 1px ${black(0.4)}` }} />
      </div>
    </div>
  );
}

function Arm() {
  return (
    <>
      <div style={{ position: "absolute", left: 4, top: 0, width: 16, height: 20, borderRadius: 5, background: "linear-gradient(90deg, #8B8C93, #3A3B40)" }} />
      <div style={{ position: "absolute", left: 9.5, top: 18, width: 5, height: 126, borderRadius: 2.5, background: "linear-gradient(90deg, #F1F1F4, #9A9BA2, #5A5B61)" }} />
      <div style={{ position: "absolute", left: 4.5, top: 138, width: 15, height: 26, borderRadius: 4, background: "linear-gradient(#3A3B40, #1B1B1F)", boxShadow: `inset 0 0 0 0.5px ${white(0.18)}`, transform: "rotate(14deg)" }}>
        <div style={{ position: "absolute", left: 3, bottom: 3, width: 9, height: 5, borderRadius: 2, background: Signature.accent }} />
      </div>
    </>
  );
}
