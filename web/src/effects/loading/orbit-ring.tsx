/** loading.orbit-ring · 轨道进度环 (Loading+OrbitRing.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, anim, fonts, spring, useHaptics, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { LoadingCurve, TimeCanvas, blurFill, css, labelRGB } from "./round2";

const SIZE = 250;
const R = 86;
const TARGETS = [0.16, 0.39, 0.58, 0.86, 1];
const PAUSE = 0.45;
const LAP = 0.8;
const HOLD = 0.7;
const REEL = 0.45;

/** The scripted run: five eased steps, a victory lap, a hold and the tail reeling in. */
function script(step: number) {
  const slot = step + PAUSE;
  const loadEnd = TARGETS.length * slot;
  return {
    loadEnd,
    total: loadEnd + LAP + HOLD + REEL + 0.25,
    progress(time: number) {
      const index = Math.floor(Math.max(time, 0) / slot);
      if (index >= TARGETS.length) return 1;
      const from = index === 0 ? 0 : TARGETS[index - 1];
      const u = (Math.max(time, 0) - index * slot) / step;
      return from + (TARGETS[index] - from) * LoadingCurve.easeInOutCubic(u);
    },
    moving(time: number) {
      if (!(time >= 0 && time < loadEnd)) return false;
      const local = time - Math.floor(time / slot) * slot;
      return local > step * 0.08 && local < step * 0.92;
    },
  };
}

const pointAt = (turn: number, radius: number): [number, number] => {
  const angle = turn * 2 * Math.PI - Math.PI / 2;
  return [SIZE / 2 + radius * Math.cos(angle), SIZE / 2 + radius * Math.sin(angle)];
};

export default function OrbitRing({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const run = script(Math.max(ctx.n("step"), 0.1));
  const thickness = ctx.n("thickness");
  const sparks = ctx.b("sparks");
  const started = useRef<number | null>(null);
  const [percent, setPercent] = useState(0);
  const [complete, setComplete] = useState(false);
  const shown = useRef({ percent: 0, complete: false });

  return (
    <div
      onClick={() => {
        haptics.tap();
        started.current = null;
      }}
      style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}
    >
      <TimeCanvas
        width={SIZE}
        height={SIZE}
        fps={previewFps(ctx.isPreview)}
        style={{ gridArea: "1 / 1" }}
        draw={(g, seconds, _dt, canvas) => {
          if (started.current === null) started.current = seconds;
          const time = Math.max(seconds - started.current, 0) % run.total;
          const k = canvas.width / SIZE;
          const c = SIZE / 2;
          const p = Math.round(run.progress(time) * 100);
          const done = time >= run.loadEnd && time < run.loadEnd + LAP + HOLD;
          if (p !== shown.current.percent || done !== shown.current.complete) {
            shown.current = { percent: p, complete: done };
            setPercent(p);
            setComplete(done);
          }

          const afterLoad = time - run.loadEnd;
          const lapU = afterLoad / LAP;
          const reelU = (afterLoad - LAP - HOLD) / REEL;
          // Where the arc starts and where its head is, in turns from twelve o'clock.
          let tail = 0;
          let head = run.progress(time);
          if (afterLoad >= 0) {
            head = 1 + LoadingCurve.easeOutCubic(lapU);
            tail = head - 1;
            if (reelU > 0) tail = head - 1 + LoadingCurve.easeInOutCubic(reelU) * 0.999;
          }
          const span = Math.max(head - tail, 0);
          const fadeOut = reelU > 0 ? 1 - LoadingCurve.smoothstep((reelU - 0.75) / 0.25) : 1;
          const flash = afterLoad >= 0 ? Math.exp(-Math.max(afterLoad, 0) * 3.2) : 0;
          const arc = (from: number, to: number) => g.arc(c, c, R, from * 2 * Math.PI - Math.PI / 2, to * 2 * Math.PI - Math.PI / 2, false);

          g.beginPath();
          g.arc(c, c, R, 0, Math.PI * 2);
          g.strokeStyle = css(labelRGB(canvas), 0.09);
          g.lineWidth = thickness;
          g.stroke();

          if (span > 0.002) {
            // The bright stop sits exactly at the head; past it the colour falls back to the tail colour
            // so the round cap at the start is not painted pink.
            const headStop = Math.min(span, 0.998);
            const tailColor = css(Palette.indigo, 0.28 + 0.5 * flash);
            const gradient = g.createConicGradient(tail * 2 * Math.PI - Math.PI / 2, c, c);
            gradient.addColorStop(0, tailColor);
            gradient.addColorStop(headStop * 0.6, css(Palette.violet, 0.8));
            gradient.addColorStop(headStop, Palette.pink);
            gradient.addColorStop(Math.min(headStop + 0.002, 1), tailColor);
            gradient.addColorStop(1, tailColor);
            g.save();
            g.globalAlpha = fadeOut;
            g.beginPath();
            arc(tail, head);
            g.strokeStyle = gradient;
            g.lineWidth = thickness;
            g.lineCap = "round";
            g.stroke();
            // Glow on the part nearest the head.
            const glowFrom = Math.max(head - Math.min(span, 0.16), tail);
            blurFill(g, k, css(Palette.pink, (0.75 + 0.25 * flash) * fadeOut), 7, () => arc(glowFrom, head), thickness * (1 + 0.5 * flash));
            g.restore();
          }

          if (sparks) {
            // Sparks are born on a fixed clock, at wherever the head was then, while it was moving.
            const rate = 0.055;
            const life = 0.7;
            const newest = Math.floor(time / rate);
            const oldest = Math.floor((time - life) / rate);
            for (let index = Math.max(oldest, 0); index <= Math.max(newest, 0); index++) {
              const born = index * rate;
              const age = time - born;
              if (!(age >= 0 && age < life && run.moving(born))) continue;
              const u = age / life;
              const side = LoadingCurve.hash(index) > 0.5 ? 1 : -1;
              const drift = side * (thickness / 2 + 3 + 18 * LoadingCurve.hash(index * 3 + 1) * LoadingCurve.easeOutCubic(u));
              const [x, y] = pointAt(run.progress(born) - 0.012 * u, R + drift);
              const dot = (1.9 + 1.2 * LoadingCurve.hash(index * 5 + 2)) * (1 - u);
              g.beginPath();
              g.arc(x, y, dot, 0, Math.PI * 2);
              g.fillStyle = css(LoadingCurve.hash(index * 7) > 0.5 ? Palette.pink : Palette.amber, 0.9 * (1 - u));
              g.fill();
            }
          }

          // The head.
          const waiting = !run.moving(time) && afterLoad < 0;
          const breathe = waiting ? 1 + 0.12 * Math.sin(time * 5) : 1;
          const [hx, hy] = pointAt(head, R);
          const dot = 9;
          g.save();
          // The head fades back in at the top when a new run begins.
          g.globalAlpha = fadeOut * LoadingCurve.smoothstep(time / 0.25);
          const halo = dot * 2.6 * breathe;
          const glow = g.createRadialGradient(hx, hy, dot * 0.5, hx, hy, halo);
          glow.addColorStop(0, css(Palette.pink, 0.55));
          glow.addColorStop(1, css(Palette.pink, 0));
          g.beginPath();
          g.arc(hx, hy, halo, 0, Math.PI * 2);
          g.fillStyle = glow;
          g.fill();
          g.beginPath();
          g.arc(hx, hy, dot, 0, Math.PI * 2);
          g.fillStyle = Palette.pink;
          g.fill();
          g.beginPath();
          g.arc(hx, hy, dot * 0.48, 0, Math.PI * 2);
          g.fillStyle = "#fff";
          g.fill();
          g.restore();
        }}
      />
      <div style={{ gridArea: "1 / 1", display: "flex", flexDirection: "column", alignItems: "center", gap: 2, pointerEvents: "none" }}>
        <motion.div animate={{ scale: complete ? 1.08 : 1 }} transition={spring(0.35, 0.5)} style={{ display: "flex", alignItems: "baseline", gap: 1, fontFamily: fonts.rounded, fontWeight: 700 }}>
          <span style={{ fontSize: 46, lineHeight: "55px" }}>
            <NumericText value={percent} />
          </span>
          <span style={{ fontSize: 20, color: Palette.secondaryLabel }}>%</span>
        </motion.div>
        <motion.span
          key={complete ? "done" : "busy"}
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={anim.smoothD(0.3)}
          style={{ fontSize: 13, lineHeight: "18px", fontWeight: 500, color: complete ? Palette.pink : Palette.secondaryLabel }}
        >
          {complete ? (zh ? "同步完成" : "Synced") : zh ? "正在同步资料库" : "Syncing library"}
        </motion.span>
      </div>
    </div>
  );
}
