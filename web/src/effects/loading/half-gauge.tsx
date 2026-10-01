/** loading.half-gauge · 半圆仪表盘 (Loading+HalfGauge.swift) */
import { CircleArrowDown } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, fonts, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { makeRun, previewFps, useAnimatedNumber, type Run } from "./shared";
import { TimeCanvas, blurFill, css, labelRGB } from "./round2";

const READINGS = [0.72, 0.38, 0.86, 0.55, 0.24];
const MAXIMUM = 300;
const W = 250;
const H = 150;
const TICKS = 31;

export default function HalfGauge({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const value = useAnimatedNumber(0);
  const reading = useRef(0);
  const [booting, setBooting] = useState(false);
  const task = useRef<Run | null>(null);
  const muted = useRef(false);
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  /** The boot sequence: a full sweep to the end stop, then a springy drop onto the next reading. */
  const boot = () => {
    const c = latest.current;
    haptics.tap();
    const sweep = Math.max(c.n("sweep"), 0.1);
    const response = c.n("response");
    const damping = c.n("damping");
    const target = READINGS[reading.current % READINGS.length];
    reading.current += 1;
    const buzz = !c.isPreview && !muted.current;
    task.current?.cancel();
    setBooting(true);
    // From wherever the needle is, back to zero first if it is not already there.
    const rewind = value.target.current > 0.02 ? 0.3 : 0;
    if (rewind > 0) value.to(0, anim.easeIn(rewind));
    const run = makeRun();
    task.current = run;
    (async () => {
      if (rewind > 0) await run.sleep(rewind);
      value.to(1, anim.easeInOut(sweep));
      await run.sleep(sweep);
      if (buzz) haptics.tap("medium");
      await run.sleep(0.06);
      value.to(target, spring(response, damping));
      await run.sleep(response * 1.6);
      setBooting(false);
      if (buzz) haptics.tap("light");
    })().catch(() => {});
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      muted.current = true;
      boot();
      muted.current = false;
    },
    { every: 3.6, delay: 0.4 },
  );

  const ticks = ctx.b("ticks");
  const needle = ctx.scheme === "dark" ? "#F2F2F7" : "#2A2A33";
  const number = Math.round(Math.min(Math.max(value.value, 0), 1.05) * MAXIMUM);

  return (
    <div onClick={boot} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div style={{ position: "relative", width: W, height: H, marginBottom: 58, flex: "none" }}>
        <TimeCanvas
          width={W + 20}
          height={H + 20}
          fps={previewFps(ctx.isPreview)}
          style={{ position: "absolute", left: -10, top: -10 }}
          draw={(g, _s, _dt, canvas) => {
            const k = canvas.width / (W + 20);
            g.translate(10, 10);
            const label = labelRGB(canvas);
            // The needle may swing a little past either end stop.
            const v = Math.min(Math.max(value.mv.get(), -0.03), 1.05);
            const cx = W / 2;
            const cy = H - 26;
            const radius = 110;
            const width = 14;
            const trackRadius = radius - width / 2;
            // Angles run from 180° (zero, left) over the top to 360° (maximum, right).
            const angle = (fraction: number) => Math.PI + Math.PI * fraction;
            const point = (fraction: number, r: number): [number, number] => [cx + r * Math.cos(angle(fraction)), cy + r * Math.sin(angle(fraction))];

            g.lineCap = "round";
            g.beginPath();
            g.arc(cx, cy, trackRadius, angle(0), angle(1), false);
            g.strokeStyle = css(label, 0.1);
            g.lineWidth = width;
            g.stroke();

            const filled = Math.min(Math.max(v, 0), 1);
            if (filled > 0.004) {
              const gradient = g.createConicGradient(Math.PI, cx, cy);
              gradient.addColorStop(0, Palette.mint);
              gradient.addColorStop(0.3, Palette.amber);
              gradient.addColorStop(0.5, Palette.coral);
              gradient.addColorStop(0.97, Palette.mint);
              gradient.addColorStop(1, Palette.mint);
              g.beginPath();
              g.arc(cx, cy, trackRadius, angle(0), angle(filled), false);
              g.strokeStyle = gradient;
              g.lineWidth = width;
              g.stroke();
            }

            if (ticks) {
              const last = TICKS - 1;
              for (let index = 0; index <= last; index++) {
                const fraction = index / last;
                const major = index % 5 === 0;
                const lit = fraction <= filled + 0.001;
                const a = point(fraction, radius - width - 7);
                const b = point(fraction, radius - width - (major ? 18 : 13));
                g.beginPath();
                g.moveTo(a[0], a[1]);
                g.lineTo(b[0], b[1]);
                g.strokeStyle = css(label, lit ? (major ? 0.8 : 0.5) : major ? 0.22 : 0.12);
                g.lineWidth = major ? 2 : 1.3;
                g.stroke();
              }
            }

            // A glowing bead where the needle meets the arc.
            const tip = point(v, trackRadius);
            blurFill(g, k, white(0.75), 5, () => g.arc(tip[0], tip[1], 9, 0, Math.PI * 2));
            g.beginPath();
            g.arc(tip[0], tip[1], 4.5, 0, Math.PI * 2);
            g.fillStyle = "#fff";
            g.fill();

            // The needle: a taper from the hub to just short of the ticks, with a short counterweight.
            const dx = Math.cos(angle(v));
            const dy = Math.sin(angle(v));
            const nx = -dy;
            const ny = dx;
            const reach = radius - width - 24;
            g.save();
            g.shadowColor = black(0.25);
            g.shadowBlur = 8 * k;
            g.shadowOffsetY = 3 * k;
            g.beginPath();
            g.moveTo(cx + dx * reach, cy + dy * reach);
            g.lineTo(cx + nx * 4.5, cy + ny * 4.5);
            g.lineTo(cx - dx * 16 + nx * 2.5, cy - dy * 16 + ny * 2.5);
            g.lineTo(cx - dx * 16 - nx * 2.5, cy - dy * 16 - ny * 2.5);
            g.lineTo(cx - nx * 4.5, cy - ny * 4.5);
            g.closePath();
            g.fillStyle = needle;
            g.fill();
            g.restore();
            g.beginPath();
            g.arc(cx, cy, 9, 0, Math.PI * 2);
            g.fillStyle = needle;
            g.fill();
            g.beginPath();
            g.arc(cx, cy, 3.5, 0, Math.PI * 2);
            g.fillStyle = Palette.coral;
            g.fill();
          }}
        />
        <div style={{ position: "absolute", left: 0, right: 0, bottom: -62, display: "flex", flexDirection: "column", alignItems: "center" }}>
          <span style={{ fontFamily: fonts.rounded, fontSize: 44, lineHeight: "52px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{number}</span>
          <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel }}>Mbps</span>
        </div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 13, lineHeight: "18px", fontWeight: 600, color: Palette.secondaryLabel }}>
        <CircleArrowDown size={16} fill={Palette.mint} stroke="var(--ml-stage)" strokeWidth={2.2} />
        <span>{booting ? (zh ? "正在测速…" : "Testing…") : zh ? "下载速度" : "Download"}</span>
      </div>
      <DemoHint ctx={ctx} en="Tap to run the test again" zh="点击重新测速" />
    </div>
  );
}
