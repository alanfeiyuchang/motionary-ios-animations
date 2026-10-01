/** buttons.hold-fuse · 引线长按 (Buttons+HoldFuse.swift) */
import { motion } from "motion/react";
import { Flame, Zap } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, clamp, hash, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, SymbolReplace, cubicKF, moveKF, springKF, track, useLongPress, useSince } from "./_a-kit";
import { clockValue, mixRGB, nowSeconds, rgba, roundedLoop, useCanvas2D, useFrame, type RateClock } from "./_c-kit";

const STAGE = { w: 320, h: 170 };
const FACE = { w: 236, h: 64 };
const RECT = { x: (STAGE.w - FACE.w) / 2 - 5, y: (STAGE.h - FACE.h) / 2 - 5, w: FACE.w + 10, h: FACE.h + 10 };
const RED = 0xff4d5e;
const AMBER = 0xffc247;
const CORAL = 0xff7a5c;
const WHITE = [255, 255, 255];
type Phase = "idle" | "burning" | "reeling" | "armed";

export default function HoldFuse({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const finish = useTimeouts();
  const script = useTimeouts();
  const clock = useRef<RateClock>({ base: 0, rate: 0, since: -1e9 });
  const phaseRef = useRef<Phase>("idle");
  const [phase, setPhaseState] = useState<Phase>("idle");
  const boomAt = useRef(-1e9);
  const [booms, setBooms] = useState(0);
  const [progress, setProgress] = useState(0);
  const crackle = useRef(0);
  const duration = Math.max(ctx.n("duration"), 0.2);
  const params = useRef({ duration, trail: 0.14, sparks: 34, reel: 2.5, dark: true });
  params.current = { duration, trail: ctx.n("trail"), sparks: ctx.n("sparks"), reel: ctx.n("reel"), dark: ctx.scheme === "dark" };
  const loop = useMemo(() => roundedLoop(RECT.x, RECT.y, RECT.w, RECT.h, 24), []);

  const setPhase = (p: Phase) => {
    phaseRef.current = p;
    setPhaseState(p);
  };

  const detonate = (buzz: boolean) => {
    window.clearInterval(crackle.current);
    const t = nowSeconds();
    clock.current = { base: 1, rate: 0, since: t };
    boomAt.current = t;
    setBooms((b) => b + 1);
    setPhase("armed");
    if (buzz) haptics.tap("heavy");
    finish.clearAll();
    finish.after(0.16, () => buzz && haptics.success());
    finish.after(1.7, () => {
      clock.current = { base: 0, rate: 0, since: -1e9 };
      setPhase("idle");
    });
  };
  const begin = (buzz: boolean) => {
    if (phaseRef.current === "armed") return;
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    clock.current = { base: current, rate: 1 / d, since: t };
    setPhase("burning");
    if (buzz) haptics.tap("soft");
    finish.clearAll();
    finish.after((1 - current) * d, () => detonate(buzz));
    window.clearInterval(crackle.current);
    if (!buzz) return;
    crackle.current = window.setInterval(() => haptics.tap("soft"), 140);
  };
  const cancel = () => {
    if (phaseRef.current !== "burning") return;
    finish.clearAll();
    window.clearInterval(crackle.current);
    const t = nowSeconds();
    const current = clockValue(clock.current, t);
    const d = params.current.duration;
    const speed = Math.max(params.current.reel, 0.5);
    clock.current = { base: current, rate: -speed / d, since: t };
    setPhase("reeling");
    finish.after((current * d) / speed + 0.05, () => {
      if (phaseRef.current === "reeling") setPhase("idle");
    });
  };
  const playScript = () => {
    if (phaseRef.current !== "idle") return;
    script.clearAll();
    const burn = params.current.duration;
    begin(false);
    if (!ctx.isPreview) return;
    script.after(burn + 2.1, () => begin(false));
    script.after(burn + 2.1 + burn * 0.45, cancel);
  };
  useAutoplay(ctx.isPreview, playScript, { every: duration * 1.7 + 2.7, delay: 0.4 });

  const longPress = useLongPress({
    duration: 600,
    maximumDistance: 60,
    onComplete: () => {},
    onPressingChanged: (pressing) => {
      script.clearAll();
      if (pressing) begin(true);
      else cancel();
    },
  });

  const glow = useCanvas2D(STAGE.w, STAGE.h);
  const main = useCanvas2D(STAGE.w, STAGE.h);

  useFrame(
    () => {
      const g = main.get();
      const gg = glow.get();
      if (!g || !gg) return;
      g.clearRect(0, 0, STAGE.w, STAGE.h);
      gg.clearRect(0, 0, STAGE.w, STAGE.h);
      const p = params.current;
      const time = nowSeconds();
      const prog = clockValue(clock.current, time);
      setProgress(prog);
      const ink = p.dark ? "255 255 255" : "0 0 0";

      if (phaseRef.current === "armed") {
        const age = time - boomAt.current;
        [0, 0.09].forEach((delay, index) => {
          const t = clamp((age - delay) / 0.6);
          if (t <= 0 || t >= 1) return;
          const eased = 1 - Math.pow(1 - t, 3);
          const grow = eased * (index === 0 ? 30 : 20);
          g.beginPath();
          g.roundRect(RECT.x - grow, RECT.y - grow, RECT.w + grow * 2, RECT.h + grow * 2, 24 + grow);
          g.strokeStyle = rgba(mixRGB(index === 0 ? AMBER : CORAL, 0, 0), 1 - eased);
          g.lineWidth = 3.5 * (1 - eased) + 0.6;
          g.setLineDash([]);
          g.stroke();
        });
        const t = clamp(age / 0.75);
        if (t >= 1) return;
        const eased = 1 - Math.pow(1 - t, 3);
        const cx = RECT.x + RECT.w / 2;
        const cy = RECT.y + RECT.h / 2;
        for (let index = 0; index < 22; index++) {
          const angle = (index / 22) * 2 * Math.PI + hash(index, 4) * 0.2;
          const reach = (26 + 30 * hash(index, 5)) * eased;
          const x = cx + (Math.cos(angle) * RECT.w) / 2 + Math.cos(angle) * reach;
          const y = cy + (Math.sin(angle) * RECT.h) / 2 + Math.sin(angle) * reach + 70 * t * t;
          const radius = (1.2 + 1.6 * hash(index, 6)) * (1 - t * 0.6);
          g.beginPath();
          g.arc(x, y, radius, 0, Math.PI * 2);
          g.fillStyle = rgba(index % 3 === 0 ? WHITE : mixRGB(AMBER, 0, 0), 1 - t * t);
          g.fill();
        }
        return;
      }

      // Fuse: ash behind, unburnt dots ahead.
      g.lineCap = "round";
      if (prog > 0.001) {
        loop.trace(g, 0, prog);
        g.setLineDash([]);
        g.strokeStyle = `rgb(${ink} / 0.1)`;
        g.lineWidth = 1.2;
        g.stroke();
      }
      if (prog < 0.999) {
        loop.trace(g, prog, 1);
        g.setLineDash([0.5, 5]);
        g.strokeStyle = `rgb(${ink} / 0.34)`;
        g.lineWidth = 2.4;
        g.stroke();
        g.setLineDash([]);
      }
      if (prog <= 0.0005) return;

      // Ember trail.
      const start = Math.max(prog - p.trail, 0);
      if (prog - start > 0.0005) {
        const segments = 14;
        const strokeSegments = (target: CanvasRenderingContext2D, width: number) => {
          target.lineCap = "round";
          for (let index = 0; index < segments; index++) {
            const a = start + ((prog - start) * index) / segments;
            const b = start + ((prog - start) * (index + 1)) / segments;
            const heat = (index + 1) / segments;
            const color = mixRGB(mixRGB(RED, AMBER, Math.min(heat * 1.4, 1)), WHITE, Math.max(heat - 0.75, 0) * 3);
            loop.trace(target, a, b);
            target.strokeStyle = rgba(color, heat * heat);
            target.lineWidth = width * (0.5 + 0.5 * heat);
            target.stroke();
          }
        };
        strokeSegments(gg, 7);
        strokeSegments(g, 3);
      }

      // Sparks (stateless slots).
      if (phaseRef.current === "burning" && p.sparks > 0.5) {
        const life = 0.5;
        const c = clock.current;
        const newest = Math.floor(time * p.sparks);
        const oldest = newest - Math.floor(life * p.sparks);
        for (let slot = newest; slot >= oldest; slot--) {
          const birth = slot / p.sparks;
          if (birth < c.since) continue;
          const age = time - birth;
          if (age < 0 || age >= life) continue;
          const home = loop.at(Math.max(Math.min(c.base + c.rate * (birth - c.since), 1), 0.0001));
          const angle = hash(slot, 1) * 2 * Math.PI;
          const speed = 30 + 70 * hash(slot, 2);
          const x = home.x + Math.cos(angle) * speed * age;
          const y = home.y + Math.sin(angle) * speed * age + 0.5 * 220 * age * age;
          const fade = 1 - age / life;
          const radius = (0.8 + 0.9 * hash(slot, 3)) * (0.5 + 0.5 * fade);
          g.beginPath();
          g.arc(x, y, radius, 0, Math.PI * 2);
          g.fillStyle = rgba(mixRGB(AMBER, WHITE, fade * 0.7), fade);
          g.fill();
        }
      }

      // Head.
      const head = loop.at(Math.max(prog, 0.0001));
      const flicker = 0.82 + 0.18 * Math.sin(time * 47) * Math.sin(time * 31);
      const halo = 16 * flicker;
      const grad = g.createRadialGradient(head.x, head.y, 0, head.x, head.y, halo);
      grad.addColorStop(0, alpha(Palette.amber, 0.85));
      grad.addColorStop(0.5, alpha(Palette.coral, 0.35));
      grad.addColorStop(1, alpha(Palette.coral, 0));
      g.fillStyle = grad;
      g.beginPath();
      g.arc(head.x, head.y, halo, 0, Math.PI * 2);
      g.fill();
      const long = 11 * flicker;
      g.beginPath();
      for (let index = 0; index < 4; index++) {
        const angle = time * 2.2 + (index * Math.PI) / 2;
        g.moveTo(head.x, head.y);
        g.lineTo(head.x + Math.cos(angle) * long, head.y + Math.sin(angle) * long);
      }
      g.strokeStyle = white(0.9);
      g.lineWidth = 1.4;
      g.stroke();
      g.beginPath();
      g.arc(head.x, head.y, 3.2, 0, Math.PI * 2);
      g.fillStyle = "#fff";
      g.fill();
    },
    ctx.isPreview ? 30 : undefined,
  );

  const armed = phase === "armed";
  const holding = phase === "burning";
  const bt = useSince(booms, 0.7);
  const boomScale = track(bt, 1, [cubicKF(1.08, 0.09), springKF(1, 0.55, BOUNCY)]);
  const flash = bt < 0 ? 0 : track(bt, 0, [moveKF(0.85), cubicKF(0, 0.4)]);
  const fade = armed ? anim.smoothD(0.2) : anim.smoothD(0.35);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div role="button" style={{ position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0 }}>
        <div style={{ position: "absolute", left: (STAGE.w - FACE.w) / 2, top: (STAGE.h - FACE.h) / 2, width: FACE.w, height: FACE.h, transform: `scale(${boomScale})` }}>
          <motion.div
            initial={false}
            animate={{ scale: holding ? 0.97 : 1, boxShadow: armed ? `0px 8px 22px ${alpha(Palette.coral, 0.45)}` : `0px 8px 14px ${black(0.12)}` }}
            transition={{ scale: spring(0.3, 0.7), boxShadow: fade }}
            style={{ position: "absolute", inset: 0, borderRadius: 20, background: Palette.elevated, overflow: "hidden" }}
          >
            <div style={{ position: "absolute", inset: 0, background: alpha(Palette.coral, armed ? 0 : progress * 0.22) }} />
            <motion.div
              initial={false}
              animate={{ opacity: armed ? 1 : 0 }}
              transition={fade}
              style={{ position: "absolute", inset: 0, background: `linear-gradient(${Math.atan2(FACE.w, -FACE.h)}rad, ${Palette.amber}, ${Palette.coral}, ${Palette.red})` }}
            />
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 8, fontSize: 17, fontWeight: 600 }}>
              <SymbolReplace id={armed ? "bolt" : "flame"}>
                {armed ? <Zap size={19} fill="#fff" color="#fff" strokeWidth={1.5} /> : <Flame size={19} fill={Palette.coral} color={Palette.coral} strokeWidth={1.5} />}
              </SymbolReplace>
              <motion.span key={armed ? "armed" : "hold"} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={fade} style={{ color: armed ? "#fff" : Palette.label }}>
                {armed ? ctx.t("Armed", "已启动") : ctx.t("Hold to arm", "按住启动")}
              </motion.span>
            </div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 20, boxShadow: `inset 0 0 0 1px ${Palette.stroke}` }} />
            <div style={{ position: "absolute", inset: 0, background: white(flash) }} />
          </motion.div>
        </div>
        <canvas ref={glow.ref} style={{ ...glow.style, position: "absolute", inset: 0, filter: "blur(4px)" }} />
        <canvas ref={main.ref} style={{ ...main.style, position: "absolute", inset: 0 }} />
        <div
          {...longPress}
          style={{ ...longPress.style, position: "absolute", left: (STAGE.w - FACE.w) / 2 - 8, top: (STAGE.h - FACE.h) / 2 - 8, width: FACE.w + 16, height: FACE.h + 16 }}
        />
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Hold until the fuse burns all the way round" zh="一直按住，直到引线烧完一圈" style={{ paddingBottom: 18 }} />
    </div>
  );
}
