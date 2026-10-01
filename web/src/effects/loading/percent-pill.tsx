/** loading.percent-pill · 百分比胶囊 (Loading+PercentPill.swift) */
import { motion, type Transition } from "motion/react";
import { useEffect, useId, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, ease, fonts, spring, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { TrimPath, previewFps, primary, useAnimatedNumber, useTask } from "./shared";

const HEIGHT = 56;
const MIN = 72;
const MAX = 250;

export default function PercentPill({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [progress, setProgress] = useState(0);
  const [done, setDone] = useState(false);
  const [checked, setChecked] = useState(false);
  const [ripple, setRipple] = useState(0);
  const [run, setRun] = useState(0);
  const [t, setT] = useState<Transition>(spring(0.45, 0.8));
  const width = useAnimatedNumber(MIN);
  const trim = useAnimatedNumber(0);
  const latest = useRef(ctx);
  latest.current = ctx;
  const collapse = ctx.b("collapse");
  const collapsed = done && collapse;

  // The pill's width follows whatever animation changed its inputs (progress, done, the toggle).
  const target = collapsed ? HEIGHT : MIN + (MAX - MIN) * progress;
  const tRef = useRef(t);
  tRef.current = t;
  useEffect(() => {
    width.to(target, tRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target]);
  const wantCheck = checked && collapsed;
  useEffect(() => {
    if (wantCheck) trim.to(1, anim.easeOut(0.3));
    else {
      trim.mv.stop();
      trim.mv.set(0);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [wantCheck]);

  useTask(run, async (task) => {
    const live = !ctx.isPreview && run > 0;
    let p = 0;
    setRipple(0);
    setChecked(false);
    setT(spring(0.45, 0.8));
    setDone(false);
    setProgress(0);
    await task.sleep(0.7);
    while (p < 1) {
      const c = latest.current;
      const step = (0.06 + Math.random() * 0.11) * c.n("speed");
      p = Math.min(1, p + step);
      setT(spring(0.5, c.n("damping")));
      setProgress(p);
      await task.sleep(0.32 + Math.random() * 0.23);
    }
    await task.sleep(0.35);
    setT(spring(0.5, 0.68));
    setDone(true);
    await task.sleep(0.18);
    setChecked(true);
    if (latest.current.b("collapse")) setRipple((v) => v + 1);
    if (live) haptics.success();
    if (!ctx.isPreview) return;
    await task.sleep(1.8);
    setRun((v) => v + 1);
  });

  const percent = Math.round(progress * 100);
  const written = (progress * 38.4).toFixed(1);
  return (
    <div
      onClick={() => {
        haptics.tap();
        setRun((v) => v + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 20 }}
    >
      <div style={{ position: "relative", width: MAX + 20, height: 120, display: "grid", placeItems: "center", flex: "none" }}>
        <svg
          width={MAX}
          height={HEIGHT}
          style={{ gridArea: "1 / 1", opacity: collapsed ? 0 : 1, transition: "opacity 0.3s cubic-bezier(0, 0, 0.58, 1)", overflow: "visible" }}
        >
          <rect x={0} y={0} width={MAX} height={HEIGHT} rx={HEIGHT / 2} fill={primary(0.05)} />
          <rect x={0.5} y={0.5} width={MAX - 1} height={HEIGHT - 1} rx={HEIGHT / 2 - 0.5} fill="none" stroke={primary(0.1)} strokeWidth={1} strokeDasharray="3 4" />
        </svg>
        {ripple > 0 && collapse && <Ripple key={ripple} />}
        <div
          style={{
            gridArea: "1 / 1",
            position: "relative",
            width: Math.max(width.value, HEIGHT),
            height: HEIGHT,
            borderRadius: HEIGHT / 2,
            boxShadow: `0 8px 28px ${alpha(done ? Palette.green : Palette.indigo, 0.4)}`,
            transition: "box-shadow 0.4s",
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: HEIGHT / 2, overflow: "hidden", background: "linear-gradient(135deg, #4B57E0, #7A45D6)" }}>
            <motion.div initial={false} animate={{ opacity: done ? 1 : 0 }} transition={t} style={{ position: "absolute", inset: 0, background: Palette.green }} />
            <motion.div initial={false} animate={{ opacity: done ? 0 : 1 }} transition={t} style={{ position: "absolute", inset: 0 }}>
              <Sheen preview={ctx.isPreview} paused={done} />
            </motion.div>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: HEIGHT / 2,
                padding: 1,
                background: `linear-gradient(${white(0.45)}, ${white(0)})`,
                WebkitMask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              }}
            />
            <motion.div
              initial={false}
              animate={{ opacity: collapsed ? 0 : 1, filter: `blur(${collapsed ? 6 : 0}px)`, scale: collapsed ? 0.5 : 1 }}
              transition={{ ...t, filter: anim.easeOut(0.3) }}
              style={{
                position: "absolute",
                inset: 0,
                display: "grid",
                placeItems: "center",
                color: "#fff",
                fontFamily: fonts.rounded,
                fontSize: 20,
                fontWeight: 700,
                whiteSpace: "nowrap",
              }}
            >
              {done && !collapsed ? <span>{zh ? "完成" : "Done"}</span> : <NumericText value={percent} text={`${percent}%`} />}
            </motion.div>
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
              <TrimPath d={`M ${22 * 0.06} ${17 * 0.55} L ${22 * 0.38} ${17 - 17 * 0.06} L ${22 - 22 * 0.04} ${17 * 0.08}`} width={22} height={17} trim={trim.value} color="#fff" lineWidth={3.5} />
            </div>
          </div>
        </div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{done ? (zh ? "已存入相册" : "Saved to Photos") : zh ? "正在导出视频" : "Exporting video"}</span>
        <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>
          <NumericText value={progress} text={done ? "1080p · 38.4 MB" : zh ? `1080p · 已写入 ${written} / 38.4 MB` : `1080p · ${written} of 38.4 MB`} />
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap to restart" zh="点击重新开始" />
    </div>
  );
}

/**
 * The ripple ring. Swift fades it in (ease-out 0.3 s → 70 %) and, in the same breath, sets it to its
 * hidden, doubled end state (ease-out 0.7 s); the two animations add up to a brief flash that grows.
 */
function Ripple() {
  const e = useElapsed(0, 0.7);
  const opacity = Math.max(0, 0.7 * (ease.out(e / 0.3) - ease.out(e / 0.7)));
  return (
    <div
      style={{
        gridArea: "1 / 1",
        width: HEIGHT,
        height: HEIGHT,
        borderRadius: "50%",
        boxShadow: `0 0 0 1px ${Palette.green}, inset 0 0 0 1px ${Palette.green}`,
        transform: `scale(${1 + ease.out(e / 0.7)})`,
        opacity,
        pointerEvents: "none",
      }}
    />
  );
}

/** A soft highlight that crosses the pill every 1.6 s (unit-point gradient, like SwiftUI's). */
function Sheen({ preview, paused }: { preview: boolean; paused: boolean }) {
  const id = useId();
  const ref = useRef<SVGLinearGradientElement>(null);
  useEffect(() => {
    let raf = 0;
    let last = 0;
    const fps = previewFps(preview);
    const step = (now: number) => {
      if (!paused) raf = requestAnimationFrame(step);
      if (fps && now - last < 1000 / fps - 1) return;
      last = now;
      const x = ((Date.now() / 1600) % 1) * 2.2 - 0.6;
      ref.current?.setAttribute("x1", String(x - 0.25));
      ref.current?.setAttribute("x2", String(x + 0.25));
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [preview, paused]);
  return (
    <svg width="100%" height="100%" preserveAspectRatio="none" style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
      <defs>
        <linearGradient ref={ref} id={id} x1={-0.85} y1={0.2} x2={-0.35} y2={0.8}>
          <stop offset={0} stopColor="#fff" stopOpacity={0} />
          <stop offset={0.5} stopColor="#fff" stopOpacity={0.28} />
          <stop offset={1} stopColor="#fff" stopOpacity={0} />
        </linearGradient>
      </defs>
      <rect width="100%" height="100%" fill={`url(#${id})`} />
    </svg>
  );
}
