/** showcase.lap-timer · 秒表计圈 (Showcase+LapTimer.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Play, Square, Timer } from "lucide-react";
import { useMemo, useRef, useState } from "react";
import { NumericText, fonts, hex, spring, springDB, useAutoplay, useClock, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioScene, useAnimatedNumber, useStudioScript } from "./_studio";

interface Lap {
  id: number;
  time: number;
}
function lapClock(time: number) {
  const total = Math.max(0, time);
  const whole = Math.trunc(total);
  const cents = Math.trunc((total - whole) * 100);
  return { main: `${Math.trunc(whole / 60)}:${String(whole % 60).padStart(2, "0")}`, cents: "." + String(cents).padStart(2, "0") };
}
const homeward = (degrees: number) => {
  const wrapped = degrees % 360;
  return wrapped > 180 ? wrapped - 360 : wrapped;
};

export default function LapTimer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [running, setRunning] = useState(false);
  const [laps, setLaps] = useState<Lap[]>([]);
  const [lapOffset, lapOffsetApi] = useAnimatedNumber(0);
  const [totalOffset, totalOffsetApi] = useAnimatedNumber(0);
  const st = useRef({ running: false, start: 0, banked: 0, lapMark: 0, laps: [] as Lap[] });
  const script = useStudioScript();
  useClock(running, ctx.isPreview ? 30 : undefined);
  const rowSpring = spring(ctx.n("response"), ctx.n("damping"));

  const elapsed = () => st.current.banked + (st.current.running ? Math.max(0, (performance.now() - st.current.start) / 1000) : 0);
  const toggleRun = () => {
    const s = st.current;
    if (s.running) {
      s.banked += (performance.now() - s.start) / 1000;
      s.running = false;
    } else {
      s.start = performance.now();
      s.running = true;
    }
    setRunning(s.running);
  };
  const lap = () => {
    const s = st.current;
    if (!s.running) return;
    const total = elapsed();
    const time = total - s.lapMark;
    if (time <= 0.05) return;
    const swing = homeward((time / 10) * 360);
    s.lapMark = total;
    lapOffsetApi.set(lapOffsetApi.get() + swing);
    lapOffsetApi.animateTo(0, spring(0.5, 0.62));
    s.laps = [{ id: (s.laps[0]?.id ?? 0) + 1, time }, ...s.laps];
    setLaps(s.laps);
  };
  const reset = () => {
    const s = st.current;
    if (s.running) return;
    const lapSwing = homeward(((s.banked - s.lapMark) / 10) * 360);
    const totalSwing = homeward((s.banked / 60) * 360);
    s.banked = 0;
    s.lapMark = 0;
    lapOffsetApi.set(lapOffsetApi.get() + lapSwing);
    totalOffsetApi.set(totalOffsetApi.get() + totalSwing);
    lapOffsetApi.animateTo(0, spring(0.55, 0.66));
    totalOffsetApi.animateTo(0, spring(0.55, 0.66));
    s.laps = [];
    setLaps([]);
  };
  const userPrimary = () => {
    script.cancel();
    haptics.tap("medium");
    toggleRun();
  };
  const userSecondary = () => {
    script.cancel();
    const s = st.current;
    if (s.running) {
      haptics.tap("rigid");
      lap();
    } else if (s.banked > 0 || s.laps.length > 0) {
      haptics.tap("light");
      reset();
    }
  };
  const runScript = () => {
    script.run(async (task) => {
      if (st.current.running) toggleRun();
      reset();
      if (!(await task.pause(0.5))) return;
      toggleRun();
      for (const gap of [1.25, 1.9, 0.95, 1.5]) {
        if (!(await task.pause(gap))) return;
        lap();
      }
      if (!(await task.pause(0.9)) || !st.current.running) return;
      toggleRun();
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 9.2, delay: 0.6 });

  const total = elapsed();
  const lapTime = total - st.current.lapMark;
  const clock = lapClock(total);
  const lapText = lapClock(lapTime);
  const rows = Math.max(ctx.i("rows"), 2);
  const shown = laps.slice(0, rows);
  const times = laps.map((l) => l.time);
  const tint = ctx.b("tint");
  const best = tint && laps.length >= 2 ? Math.min(...times) : null;
  const worst = tint && laps.length >= 3 ? Math.max(...times) : null;
  const longest = Math.max(times.length ? Math.max(...times) : 1, 0.1);
  const canReset = !running && (st.current.banked > 0 || laps.length > 0);
  const snappy = springDB(0.25, 0.15);
  const red = "#FF4D3D";

  const ticks = useMemo(() => {
    const out = [];
    for (let index = 0; index < 50; index++) {
      const major = index % 5 === 0;
      const a = (index / 50) * 2 * Math.PI - Math.PI / 2;
      const outer = 35;
      const inner = outer - (major ? 7 : 3.5);
      out.push(<line key={index} x1={36 + Math.cos(a) * inner} y1={36 + Math.sin(a) * inner} x2={36 + Math.cos(a) * outer} y2={36 + Math.sin(a) * outer} stroke="#fff" strokeOpacity={major ? 0.7 : 0.25} strokeWidth={major ? 1.6 : 1} strokeLinecap="round" />);
    }
    return out;
  }, []);
  const hand = (length: number, width: number, color: string, degrees: number, glow?: string) => (
    <div style={{ position: "absolute", left: 36, top: 36, width: 0, height: 0, transform: `rotate(${degrees}deg)` }}>
      <div style={{ position: "absolute", left: -width / 2, top: -length, width, height: length + 7, borderRadius: width / 2, background: color, boxShadow: glow }} />
    </div>
  );
  const buttonText = { fontFamily: fonts.rounded, fontSize: 14, fontWeight: 700, whiteSpace: "nowrap" as const };

  return (
    <StudioScene ctx={ctx} en="Start, then tap Lap" zh="点开始，再点计圈">
      <div style={{ ...signatureCard(), width: 290, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "秒表 · 400 米间歇" : "Stopwatch · 400 m repeats"} icon={<Timer size={13} strokeWidth={2.8} />} trailing={laps.length === 0 ? undefined : zh ? `第 ${laps.length + 1} 圈` : `Lap ${laps.length + 1}`} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{ position: "relative", width: 72, height: 72, flexShrink: 0 }}>
            <svg width={72} height={72} style={{ position: "absolute", inset: 0 }}>
              <circle cx={36} cy={36} r={36} fill="#fff" fillOpacity={0.05} />
              {ticks}
            </svg>
            {hand(22, 1.6, white(0.45), (total / 60) * 360 + totalOffset)}
            {hand(29, 2.4, Signature.accent, (lapTime / 10) * 360 + lapOffset, `0 0 4px ${hex(0xff8a1f, 0.7)}`)}
            <div style={{ position: "absolute", left: 32.5, top: 32.5, width: 7, height: 7, borderRadius: "50%", background: "#fff", display: "grid", placeItems: "center" }}>
              <span style={{ width: 2.5, height: 2.5, borderRadius: "50%", background: Signature.ink }} />
            </div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 1, alignItems: "flex-start" }}>
            <span style={{ display: "flex", alignItems: "baseline" }}>
              <span style={{ ...signatureNumber(40), lineHeight: "48px" }}>
                <NumericText value={Math.trunc(total)} text={clock.main} />
              </span>
              <span style={{ ...signatureNumber(24), color: Signature.accentSoft }}>{clock.cents}</span>
            </span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "14px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>{(zh ? "本圈 " : "This lap ") + lapText.main + lapText.cents}</span>
          </div>
        </div>
        <div style={{ position: "relative", height: rows * 31 - 5, overflow: "hidden" }}>
          <AnimatePresence initial={false}>
            {Array.from({ length: Math.max(rows - shown.length, 0) }, (_, k) => {
              const index = shown.length + k;
              return (
                <motion.div key={`empty-${index}`} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={rowSpring} style={{ position: "absolute", left: 0, right: 0, top: index * 31, height: 26 }}>
                  <svg width="100%" height={26} style={{ display: "block" }}>
                    <rect x={0.5} y={0.5} width={257} height={25} rx={8.5} fill="none" stroke={white(0.07)} strokeDasharray="3 4" />
                  </svg>
                </motion.div>
              );
            })}
            {shown.map((l, index) => {
              const mark = l.time === best ? "best" : l.time === worst ? "worst" : "none";
              const color = mark === "best" ? Signature.lime : mark === "worst" ? "#FF6B5E" : "#FFFFFF";
              const c = lapClock(l.time);
              return (
                <motion.div
                  key={l.id}
                  initial={{ y: index * 31 - 31, opacity: 0, scale: 0.86 }}
                  animate={{ y: index * 31, opacity: 1, scale: 1 }}
                  exit={{ opacity: 0 }}
                  transition={rowSpring}
                  style={{ position: "absolute", left: 0, right: 0, top: 0, height: 26, borderRadius: 9, background: white(0.06), display: "flex", alignItems: "center", gap: 8, padding: "0 10px", boxSizing: "border-box", transformOrigin: "50% 0%" }}
                >
                  <span style={{ width: 50, fontFamily: fonts.rounded, fontSize: 12, fontWeight: 700, color: white(0.7), whiteSpace: "nowrap", flexShrink: 0 }}>{zh ? `第 ${l.id} 圈` : `Lap ${l.id}`}</span>
                  <span style={{ position: "relative", flex: 1, height: 4, borderRadius: 2, background: white(0.08) }}>
                    <motion.span initial={false} animate={{ width: `${Math.max(3, (l.time / longest) * 100)}%`, backgroundColor: mark === "none" ? "rgba(255,255,255,0.35)" : color }} transition={spring(0.4, 0.75)} style={{ position: "absolute", left: 0, top: 0, height: 4, borderRadius: 2 }} />
                  </span>
                  <AnimatePresence initial={false}>
                    {mark !== "none" && (
                      <motion.span key="mark" initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0, opacity: 0 }} transition={spring(0.4, 0.75)} style={{ fontFamily: fonts.rounded, fontSize: 9, fontWeight: 800, lineHeight: "11px", color: Signature.ink, padding: "2px 5px", borderRadius: 8, background: color, whiteSpace: "nowrap", flexShrink: 0 }}>
                        {mark === "best" ? (zh ? "最快" : "Best") : zh ? "最慢" : "Slow"}
                      </motion.span>
                    )}
                  </AnimatePresence>
                  <motion.span initial={false} animate={{ color }} transition={spring(0.4, 0.75)} style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: 600, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap", flexShrink: 0 }}>
                    {c.main + c.cents}
                  </motion.span>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
        <div style={{ display: "flex", gap: 10 }}>
          <SportPress scale={0.95} dim={0.05} radius={20} onClick={userSecondary} style={{ flex: 1 }}>
            <motion.span initial={false} animate={{ color: white(running || canReset ? 1 : 0.35) }} transition={snappy} style={{ ...buttonText, height: 40, borderRadius: 20, background: white(0.1), boxShadow: `inset 0 0 0 1px ${white(0.14)}`, display: "grid", placeItems: "center" }}>
              {canReset ? (zh ? "复位" : "Reset") : zh ? "计圈" : "Lap"}
            </motion.span>
          </SportPress>
          <SportPress scale={0.95} dim={0.05} radius={20} onClick={userPrimary} style={{ flex: 1 }}>
            <span style={{ position: "relative", height: 40, borderRadius: 20, display: "flex", alignItems: "center", justifyContent: "center" }}>
              <motion.span initial={false} animate={{ opacity: running ? 0 : 1 }} transition={snappy} style={{ position: "absolute", inset: 0, borderRadius: 20, background: Signature.accentGradient, boxShadow: `0 4px 9px ${hex(0xff8a1f, 0.4)}` }} />
              <motion.span initial={false} animate={{ opacity: running ? 1 : 0 }} transition={snappy} style={{ position: "absolute", inset: 0, borderRadius: 20, background: hex(0xff4d3d, 0.85), boxShadow: `0 4px 9px ${hex(red, 0.4)}` }} />
              <motion.span initial={false} animate={{ color: running ? "#FFFFFF" : Signature.ink }} transition={snappy} style={{ ...buttonText, position: "relative", display: "flex", alignItems: "center", gap: 6 }}>
                {running ? <Square size={12} fill="currentColor" strokeWidth={0} /> : <Play size={13} fill="currentColor" strokeWidth={0} />}
                {running ? (zh ? "停止" : "Stop") : zh ? "开始" : "Start"}
              </motion.span>
            </span>
          </SportPress>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
