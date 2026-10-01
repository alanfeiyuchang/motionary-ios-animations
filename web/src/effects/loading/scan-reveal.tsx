/** loading.scan-reveal · 扫描显影 (Loading+ScanReveal.swift) */
import { AnimatePresence, motion } from "motion/react";
import { CircleCheck, WandSparkles } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, demoCard, spring, usePan, useHaptics, white, type DemoProps } from "../../kit";
import { popScale } from "./bar-shared";
import { makeRun, useAnimatedNumber, useTriggerElapsed, type Run } from "./shared";

const W = 264;
const H = 176;

/** The photograph: dusk sky, a sun, three ridges and a tree line. */
function drawScene(g: CanvasRenderingContext2D) {
  const w = W;
  const h = H;
  const sky = g.createLinearGradient(0, 0, 0, h);
  sky.addColorStop(0, "#161A4A");
  sky.addColorStop(0.38, "#5B3A9E");
  sky.addColorStop(0.62, "#FF6F91");
  sky.addColorStop(0.8, "#FFC27A");
  g.fillStyle = sky;
  g.fillRect(0, 0, w, h);
  g.fillStyle = white(0.85);
  for (let index = 0; index < 22; index++) {
    const hx = Math.abs(Math.sin(index * 12.9898) * 43758.5453);
    const hy = Math.abs(Math.sin(index * 78.233) * 43758.5453);
    const x = w * (hx - Math.floor(hx));
    const y = h * 0.42 * (hy - Math.floor(hy));
    const r = index % 5 === 0 ? 1.3 : 0.8;
    g.beginPath();
    g.arc(x + r, y + 4 + r, r, 0, Math.PI * 2);
    g.fill();
  }
  const sx = w * 0.68;
  const sy = h * 0.56;
  const halo = g.createRadialGradient(sx, sy, 10, sx, sy, 60);
  halo.addColorStop(0, "rgb(255 233 168 / 0.7)");
  halo.addColorStop(1, "rgb(255 233 168 / 0)");
  g.fillStyle = halo;
  g.beginPath();
  g.arc(sx, sy, 60, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = "#FFF1C4";
  g.beginPath();
  g.arc(sx, sy, 20, 0, Math.PI * 2);
  g.fill();
  for (const [bx, by] of [
    [0.3, 0.3],
    [0.37, 0.25],
  ]) {
    const ox = w * bx;
    const oy = h * by;
    g.beginPath();
    g.moveTo(ox - 6, oy - 2);
    g.quadraticCurveTo(ox - 3, oy - 5, ox, oy);
    g.quadraticCurveTo(ox + 3, oy - 5, ox + 6, oy - 2);
    g.strokeStyle = "rgb(22 26 74 / 0.8)";
    g.lineWidth = 1.2;
    g.lineCap = "round";
    g.stroke();
  }
  const ridges: [number, number, number, number, string][] = [
    [0.66, 0.1, 2.1, 0.4, "#8A56B8"],
    [0.76, 0.12, 3.2, 1.9, "#4B2F86"],
    [0.88, 0.07, 4.6, 3.1, "#1D1542"],
  ];
  ridges.forEach(([base, amp, freq, shift, color], index) => {
    const crest: [number, number][] = [];
    for (let step = 0; step <= 66; step++) {
      const u = step / 66;
      const wave = Math.sin(u * freq * Math.PI + shift) * 0.6 + Math.sin(u * freq * 2.7 * Math.PI + shift * 2) * 0.4;
      crest.push([w * u, h * (base - amp * wave)]);
    }
    // Swift's `addLines` starts a new subpath, so the ridge closes from the bottom-right corner straight
    // back to the crest's first point (the bottom-left corner is not part of it).
    g.beginPath();
    crest.forEach(([x, y], i) => (i === 0 ? g.moveTo(x, y) : g.lineTo(x, y)));
    g.lineTo(w, h);
    g.closePath();
    g.fillStyle = color;
    g.fill();
    if (index === 2) {
      for (let step = 1; step < 66; step += 2) {
        const [x, y] = crest[step];
        const tall = 7 + 5 * ((step * 0.618) % 1);
        g.beginPath();
        g.moveTo(x - 3, y + 1);
        g.lineTo(x, y - tall);
        g.lineTo(x + 3, y + 1);
        g.closePath();
        g.fill();
      }
    }
  });
}

function Scene({ style }: { style?: React.CSSProperties }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    const g = canvas?.getContext("2d");
    if (!canvas || !g) return;
    const k = Math.max(2, Math.min(window.devicePixelRatio || 1, 3));
    canvas.width = W * k;
    canvas.height = H * k;
    g.setTransform(k, 0, 0, k, 0, 0);
    drawScene(g);
  }, []);
  return <canvas ref={ref} style={{ position: "absolute", left: 0, top: 0, width: W, height: H, ...style }} />;
}

/** A flickering grid of translucent blocks: the "not yet resolved" texture. */
function Blocks({ paused }: { paused: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    const g = canvas?.getContext("2d");
    if (!canvas || !g) return;
    canvas.width = W;
    canvas.height = H;
    const paint = () => {
      const tick = paused ? 0 : Math.floor(Date.now() / 140) % 100000;
      const cell = 12;
      g.clearRect(0, 0, W, H);
      for (let row = 0; row < Math.ceil(H / cell); row++) {
        for (let column = 0; column < Math.ceil(W / cell); column++) {
          let hash = Math.imul(row, 73856093) ^ Math.imul(column, 19349663);
          if ((row + column + tick) % 3 === 0) hash ^= Math.imul(tick, 83492791);
          const value = (Math.abs(hash) % 1000) / 1000;
          g.fillStyle = value > 0.5 ? white((value - 0.5) * 0.36) : black((0.5 - value) * 0.3);
          g.fillRect(column * cell, row * cell, cell, cell);
        }
      }
    };
    paint();
    if (paused) return;
    const id = window.setInterval(paint, 140);
    return () => clearInterval(id);
  }, [paused]);
  return <canvas ref={ref} style={{ position: "absolute", left: 0, top: 0, width: W, height: H, pointerEvents: "none" }} />;
}

export default function ScanReveal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const progress = useAnimatedNumber(0);
  const [done, setDone] = useState(false);
  const [pops, setPops] = useState(0);
  const task = useRef<Run | null>(null);
  const latest = useRef(ctx);
  latest.current = ctx;
  const doneRef = useRef(false);
  doneRef.current = done;
  const panned = useRef(false);
  const vertical = ctx.i("axis") === 1;

  const start = (rewind: boolean, buzz: boolean) => {
    task.current?.cancel();
    const run = makeRun();
    task.current = run;
    const c = latest.current;
    const duration = Math.max(c.n("duration"), 0.3);
    const loops = c.isPreview;
    (async () => {
      do {
        if ((rewind || loops) && progress.mv.get() > 0.01) {
          progress.to(0, anim.easeInOut(0.4));
          setDone(false);
          await run.sleep(0.55);
        } else {
          await run.sleep(0.35);
        }
        const remaining = duration * Math.max(1 - progress.mv.get(), 0.15);
        progress.to(1, anim.curve(0.5, 0, 0.2, 1, remaining));
        await run.sleep(remaining);
        setDone(true);
        setPops((v) => v + 1);
        if (buzz) haptics.success();
        if (!loops) return;
        await run.sleep(1.7);
      } while (!run.cancelled);
    })().catch(() => {});
  };

  useEffect(() => {
    start(false, false);
    return () => task.current?.cancel();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const pan = usePan(
    {
      onStart: () => {
        panned.current = true;
      },
      onChange: (s) => {
        task.current?.cancel();
        const share = vertical ? s.location.y / H : s.location.x / W;
        progress.mv.stop();
        progress.mv.set(Math.min(Math.max(share, 0), 1));
        progress.target.current = progress.mv.get();
        if (doneRef.current) setDone(false);
      },
      onEnd: () => start(false, !ctx.isPreview),
    },
    6,
  );

  const p = progress.value;
  const barOpacity = done ? 0 : Math.min(p * 12, 1);
  const percent = Math.round(p * 100);
  const pop = popScale(useTriggerElapsed(pops, 0.8), 1.03, 0.14);
  const fade = "opacity 0.3s cubic-bezier(0, 0, 0.58, 1)";

  return (
    <div
      onClick={() => {
        if (panned.current) {
          panned.current = false;
          return;
        }
        haptics.tap();
        start(true, !ctx.isPreview);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}
    >
      <div style={{ ...demoCard(28), width: W + 24, padding: 12, display: "flex", flexDirection: "column", gap: 12, transform: `scale(${pop})`, flex: "none" }}>
        <div {...pan} style={{ position: "relative", width: W, height: H, borderRadius: 18, overflow: "hidden", touchAction: "none" }}>
          <Scene style={{ filter: `blur(${ctx.n("blur")}px) saturate(0.45)`, transform: "scale(1.1)" }} />
          {ctx.b("blocks") && <Blocks paused={done} />}
          <Scene style={{ clipPath: vertical ? `inset(0 0 ${H - H * p}px 0)` : `inset(0 ${W - W * p}px 0 0)` }} />
          <div
            style={{
              position: "absolute",
              left: vertical ? 0 : W * p - 48,
              top: vertical ? H * p - 48 : 0,
              width: vertical ? W : 48,
              height: vertical ? 48 : H,
              background: `linear-gradient(${vertical ? "180deg" : "90deg"}, ${white(0)}, ${white(0.42)})`,
              mixBlendMode: "plus-lighter",
              opacity: barOpacity,
              transition: done ? fade : undefined,
            }}
          />
          <div
            style={{
              position: "absolute",
              left: vertical ? 0 : W * p - 1.5,
              top: vertical ? H * p - 1.5 : 0,
              width: vertical ? W : 3,
              height: vertical ? 3 : H,
              borderRadius: 1.5,
              background: "#fff",
              boxShadow: `0 0 12px ${Palette.mint}, 0 0 28px ${alpha(Palette.mint, 0.8)}`,
              opacity: barOpacity,
              transition: done ? fade : undefined,
            }}
          />
        </div>
        <div style={{ width: W, height: 36, padding: "0 4px", display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ width: 34, height: 34, borderRadius: 11, background: alpha(Palette.mint, 0.14), color: Palette.mint, display: "grid", placeItems: "center", flex: "none" }}>
            <WandSparkles size={16} strokeWidth={2.3} />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{done ? (zh ? "照片已增强" : "Photo enhanced") : zh ? "正在增强照片" : "Enhancing photo"}</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
              {done ? "4032 × 3024" : zh ? `超分辨率 · ${percent}%` : `Upscaling · ${percent}%`}
            </span>
          </div>
          <span style={{ flex: 1 }} />
          <AnimatePresence>
            {done && (
              <motion.span
                initial={{ scale: 0.3, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.3, opacity: 0 }}
                transition={spring(0.4, 0.65)}
                style={{ display: "grid", color: Palette.green }}
              >
                <CircleCheck size={26} fill="currentColor" stroke="var(--ml-elevated)" strokeWidth={2} />
              </motion.span>
            )}
          </AnimatePresence>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to rescan · drag to scrub" zh="点击重新扫描 · 拖动手动扫描" />
    </div>
  );
}
