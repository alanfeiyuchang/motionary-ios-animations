/** showcase.focus-timer · 专注计时表盘 (Showcase+FocusTimer.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Pause, Play } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, black, clamp, fonts, hex, localPoint, spring, springAt, useAutoplay, useClock, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const SIDE = 202;
const RADIUS = 72;

export default function FocusTimer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const session = Math.max(ctx.n("session"), 1);
  const [minutes, minutesApi] = useAnimatedNumber(25);
  const [restQ, restQApi] = useAnimatedNumber(0);
  const [running, setRunning] = useState(false);
  const [paused, setPaused] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [completions, setCompletions] = useState(0);
  const st = useRef({ minutes: 25, raw: 25, running: false, elapsed: 0, start: 0, dragging: false, lastAngle: 0, userStarted: false, scripting: false, flip: false, session });
  st.current.session = session;
  const script = useStudioScript();
  const clock = useClock(running, ctx.isPreview ? 30 : undefined);
  const detent = ctx.i("detent") === 1 ? 5 : 1;

  const finish = () => {
    const s = st.current;
    setCompletions((n) => n + 1);
    if (s.userStarted) haptics.success();
    s.running = false;
    s.elapsed = 0;
    setRunning(false);
    setPaused(false);
    restQApi.set(1);
    restQApi.animateTo(0, spring(0.7, 0.7));
  };
  useEffect(() => {
    if (!running) return;
    const s = st.current;
    const left = session - s.elapsed - (performance.now() - s.start) / 1000;
    const id = window.setTimeout(() => {
      if (st.current.running) finish();
    }, Math.max(left, 0) * 1000);
    return () => window.clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [running, session]);

  const toggle = () => {
    const s = st.current;
    if (s.running) {
      s.elapsed += (performance.now() - s.start) / 1000;
      s.running = false;
      restQApi.set(Math.min(1, s.elapsed / s.session));
      setRunning(false);
      setPaused(s.elapsed > 0);
    } else {
      s.start = performance.now();
      s.running = true;
      setRunning(true);
      setPaused(false);
    }
  };
  const userToggle = () => {
    script.cancel();
    st.current.scripting = false;
    haptics.tap("medium");
    st.current.userStarted = true;
    toggle();
  };
  const dial = (delta: number) => {
    const s = st.current;
    s.raw = clamp(s.raw + (delta / (2 * Math.PI)) * 60, detent, 60);
    const snapped = clamp(Math.round(s.raw / detent) * detent, detent, 60);
    if (snapped === s.minutes) return;
    s.minutes = snapped;
    minutesApi.animateTo(snapped, spring(0.2, 0.8));
    if (s.scripting) return;
    if (snapped % 5 === 0) haptics.tap("rigid");
    else haptics.selection();
  };
  const beginDial = (angle: number) => {
    const s = st.current;
    s.lastAngle = angle;
    s.raw = s.minutes;
    s.dragging = true;
    setDragging(true);
    const knob = (s.minutes / 60) * 2 * Math.PI;
    let gap = angle - knob;
    if (gap > Math.PI) gap -= 2 * Math.PI;
    if (gap < -Math.PI) gap += 2 * Math.PI;
    if (Math.abs(gap) > 0.3) dial(gap);
  };
  const turnDial = (angle: number) => {
    let delta = angle - st.current.lastAngle;
    if (delta > Math.PI) delta -= 2 * Math.PI;
    if (delta < -Math.PI) delta += 2 * Math.PI;
    st.current.lastAngle = angle;
    dial(delta);
  };
  const endDial = () => {
    if (!st.current.dragging) return;
    st.current.dragging = false;
    setDragging(false);
  };
  const runScript = () => {
    const s = st.current;
    if (s.running || s.elapsed > 0 || s.dragging) return;
    script.run(async (task) => {
      s.scripting = true;
      s.userStarted = false;
      s.raw = s.minutes;
      const target = s.flip ? 25 : 40;
      s.flip = !s.flip;
      const total = ((target - s.minutes) / 60) * 2 * Math.PI;
      let done = 0;
      s.dragging = true;
      setDragging(true);
      const finished = await task.script(0.9, (t) => {
        const goal = total * studioEase(t);
        dial(goal - done);
        done = goal;
      });
      if (!task.alive()) return;
      endDial();
      if (!finished || !(await task.pause(0.35)) || s.running) {
        if (task.alive()) s.scripting = false;
        return;
      }
      toggle();
      s.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: session + 3.6, delay: 0.7 });

  const down = useRef(false);
  const polar = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = localPoint(e, e.currentTarget);
    const dx = p.x - SIDE / 2;
    const dy = p.y - SIDE / 2;
    let angle = Math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * Math.PI;
    return { angle, distance: Math.hypot(dx, dy) };
  };
  const onDial = (e: React.PointerEvent<HTMLDivElement>) => {
    const s = st.current;
    if (s.running || s.elapsed > 0) return;
    const { angle, distance } = polar(e);
    if (!s.dragging) {
      if (distance <= 40) return;
      script.cancel();
      s.scripting = false;
      beginDial(angle);
    } else turnDial(angle);
  };
  const gesture = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      if (st.current.scripting) {
        script.cancel();
        st.current.scripting = false;
        endDial();
      }
      onDial(e);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current) onDial(e);
    },
    onPointerUp: () => {
      down.current = false;
      endDial();
    },
    onPointerCancel: () => {
      down.current = false;
      endDial();
    },
  };

  const s = st.current;
  const q = running ? Math.min(1, (s.elapsed + Math.max(0, (performance.now() - s.start) / 1000)) / session) : restQ;
  const left = minutes * (1 - q);
  const fraction = left / 60;
  const t = 1000 + clock;
  const sweep = running ? (t / 1.5) % 1 : null;

  const ticks = useRef<HTMLCanvasElement>(null);
  const arc = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    for (const el of [ticks.current, arc.current]) {
      if (el && el.width !== SIDE * dpr) {
        el.width = SIDE * dpr;
        el.height = SIDE * dpr;
      }
    }
    const g = ticks.current?.getContext("2d");
    const c = SIDE / 2;
    if (g) {
      g.setTransform(dpr, 0, 0, dpr, 0, 0);
      g.clearRect(0, 0, SIDE, SIDE);
      const outer = SIDE / 2 - 3;
      g.lineCap = "round";
      for (let index = 0; index < 60; index++) {
        const position = index / 60;
        const major = index % 5 === 0;
        const lit = position < fraction - 0.0001;
        const angle = position * 2 * Math.PI - Math.PI / 2;
        const inner = outer - (major ? 9 : 5);
        let color = lit ? hex(0xff8a1f, major ? 1 : 0.75) : white(major ? 0.26 : 0.13);
        if (sweep !== null && lit) {
          let behind = sweep - position;
          if (behind < 0) behind += 1;
          if (behind < 0.12) color = white(1 - (behind / 0.12) * 0.75);
        }
        g.strokeStyle = color;
        g.lineWidth = major ? 2 : 1.4;
        g.beginPath();
        g.moveTo(c + Math.cos(angle) * inner, c + Math.sin(angle) * inner);
        g.lineTo(c + Math.cos(angle) * outer, c + Math.sin(angle) * outer);
        g.stroke();
      }
      g.strokeStyle = white(0.07);
      g.lineWidth = 13;
      g.beginPath();
      g.arc(c, c, RADIUS, 0, Math.PI * 2);
      g.stroke();
    }
    const a = arc.current?.getContext("2d");
    if (a) {
      a.setTransform(dpr, 0, 0, dpr, 0, 0);
      a.clearRect(0, 0, SIDE, SIDE);
      const f = Math.max(fraction, 0.0001);
      const span = Math.max(fraction, 0.05);
      const grad = a.createConicGradient(-Math.PI / 2, c, c);
      grad.addColorStop(0, Signature.accentHot);
      grad.addColorStop(Math.min(span * 0.5, 1), Signature.accent);
      grad.addColorStop(Math.min(span, 1), Signature.accentSoft);
      if (span < 0.999) grad.addColorStop(Math.min((span + 1) / 2, 1), Signature.accentSoft);
      a.strokeStyle = grad;
      a.lineWidth = 13;
      a.lineCap = "butt";
      a.beginPath();
      a.arc(c, c, RADIUS, -Math.PI / 2, -Math.PI / 2 + f * 2 * Math.PI);
      a.stroke();
      const end = -Math.PI / 2 + f * 2 * Math.PI;
      const mixTo = (k: number) => {
        const lerp = (x: number, y: number) => Math.round(x + (y - x) * k);
        return `rgb(${lerp(255, 255)} ${lerp(138, 180)} ${lerp(31, 92)})`;
      };
      a.fillStyle = fraction >= 0.05 ? Signature.accentSoft : mixTo(clamp(fraction / 0.05));
      a.beginPath();
      a.arc(c + Math.cos(end) * RADIUS, c + Math.sin(end) * RADIUS, 6.5, 0, Math.PI * 2);
      a.fill();
      a.fillStyle = Signature.accentHot;
      a.beginPath();
      a.arc(c, c - RADIUS, 6.5, 0, Math.PI * 2);
      a.fill();
    }
  });

  const pop = useElapsed(completions, 0.7, true);
  const popScale = pop < 0 ? 1 : pop < 0.14 ? 1 + 0.06 * studioEase(pop / 0.14) : 1.06 - 0.06 * springAt(pop - 0.14, 0.35, 0.5);
  const flash = pop < 0 ? 0 : pop < 0.1 ? (0.35 * pop) / 0.1 : 0.35 * (1 - studioEase((pop - 0.1) / 0.5));
  const seconds = Math.ceil(left * 60 - 1e-9);
  const clockText = `${String(Math.trunc(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`;
  const stateLabel = running ? (zh ? "深度专注中" : "Deep focus") : paused ? (zh ? "已暂停" : "Paused") : zh ? "分钟 · 拖动设定" : "Minutes · drag to set";
  const buttonLabel = running ? (zh ? "暂停" : "Pause") : paused ? (zh ? "继续" : "Resume") : zh ? "开始专注" : "Start focus";
  const mode = spring(0.35, 0.8);
  const glowWave = Math.sin((t * Math.PI) / 2);

  return (
    <StudioScene ctx={ctx} en="Drag around the ring, then start" zh="绕圆环拖动设定时间，再点开始">
      <div style={{ ...signatureCard(), width: 280, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", alignItems: "center", gap: 8, color: "#fff" }}>
        <div {...gesture} style={{ position: "relative", width: SIDE, height: SIDE, borderRadius: "50%", touchAction: "none", transform: `scale(${popScale})`, filter: flash > 0.001 ? `brightness(${1 + flash * 1.6})` : undefined }}>
          {ctx.b("glow") && (
            <motion.div
              initial={false}
              animate={{ scale: running ? 0.96 + 0.07 * glowWave : 0.9, opacity: running ? 0.24 + 0.12 * glowWave : 0.1 }}
              transition={running ? { duration: 0 } : mode}
              style={{ position: "absolute", left: 26, top: 26, width: 150, height: 150, borderRadius: "50%", background: Signature.accent, filter: "blur(30px)" }}
            />
          )}
          <canvas ref={ticks} style={{ position: "absolute", inset: 0, width: SIDE, height: SIDE }} />
          <canvas ref={arc} style={{ position: "absolute", inset: 0, width: SIDE, height: SIDE, filter: `drop-shadow(0 0 8px ${hex(0xff8a1f, 0.5)})` }} />
          <div style={{ position: "absolute", left: SIDE / 2, top: SIDE / 2, width: 0, height: 0, transform: `rotate(${fraction * 360}deg)` }}>
            <motion.div
              initial={false}
              animate={{ scale: running || paused ? 0.01 : dragging ? 1.25 : 1 }}
              transition={running || paused ? mode : spring(0.3, 0.7)}
              style={{ position: "absolute", left: -11, top: -RADIUS - 11, width: 22, height: 22, borderRadius: "50%", background: "#fff", boxShadow: `0 2px 4px ${black(0.45)}`, display: "grid", placeItems: "center" }}
            >
              <span style={{ width: 7, height: 7, borderRadius: "50%", background: Signature.accent }} />
            </motion.div>
          </div>
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 2, pointerEvents: "none" }}>
            <span style={{ ...signatureNumber(36), lineHeight: "43px" }}>{running ? clockText : <NumericText value={seconds} text={clockText} />}</span>
            <span style={{ position: "relative", height: 12, width: 160 }}>
              <AnimatePresence initial={false}>
                <motion.span key={stateLabel} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.25 }} style={{ ...signatureEyebrow(), position: "absolute", left: 0, right: 0, top: 0, textAlign: "center", whiteSpace: "nowrap" }}>
                  {stateLabel}
                </motion.span>
              </AnimatePresence>
            </span>
          </div>
        </div>
        <SportPress scale={0.95} dim={0.05} radius={22} onClick={userToggle}>
          <span style={{ position: "relative", width: 168, height: 44, borderRadius: 22, display: "flex", alignItems: "center", justifyContent: "center", gap: 7, fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700 }}>
            <motion.span initial={false} animate={{ opacity: running ? 0 : 1 }} transition={mode} style={{ position: "absolute", inset: 0, borderRadius: 22, background: Signature.accentGradient, boxShadow: `0 4px 10px ${hex(0xff8a1f, 0.45)}` }} />
            <motion.span initial={false} animate={{ opacity: running ? 1 : 0 }} transition={mode} style={{ position: "absolute", inset: 0, borderRadius: 22, background: white(0.1), boxShadow: `inset 0 0 0 1px ${white(0.16)}` }} />
            <motion.span initial={false} animate={{ color: running ? "#FFFFFF" : Signature.ink }} transition={mode} style={{ position: "relative", display: "flex", alignItems: "center", gap: 7, whiteSpace: "nowrap" }}>
              {running ? <Pause size={15} fill="currentColor" strokeWidth={0} /> : <Play size={14} fill="currentColor" strokeWidth={0} />}
              {buttonLabel}
            </motion.span>
          </span>
        </SportPress>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
