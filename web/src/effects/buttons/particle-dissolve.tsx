/** buttons.particle-dissolve · 粒子消散换字 (Buttons+ParticleDissolve.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, clamp, delayed, fonts, springDB, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { useLatchedPress } from "./_a-kit";
import { nowSeconds, useCanvas2D, useFrame } from "./_c-kit";

const SIZE = { w: 232, h: 60 };
const AREA = { w: 320, h: 200 };
const TOTAL = 2.15;
const ICON = 19;
const TEXT_H = 22;

interface Label {
  points: { x: number; y: number }[];
  width: number;
  height: number;
  text: string;
  icon: "plane" | "check";
}
interface Particle {
  fx: number;
  fy: number;
  tx: number;
  ty: number;
  fromSweep: number;
  toSweep: number;
  r1: number;
  r2: number;
  r3: number;
  r4: number;
}

const FONT = `600 18px ${fonts.text}`;

/** Draws the icon + text label (white) with its top-left at the origin. */
function drawLabel(g: CanvasRenderingContext2D, label: Pick<Label, "text" | "icon" | "width" | "height">, color: string) {
  g.fillStyle = color;
  g.strokeStyle = color;
  const iy = (label.height - ICON) / 2;
  g.save();
  g.translate(2, iy);
  g.scale(ICON / 24, ICON / 24);
  if (label.icon === "plane") {
    g.beginPath();
    g.moveTo(22.3, 1.7);
    g.lineTo(15.2, 22.3);
    g.lineTo(11, 13);
    g.lineTo(1.7, 8.8);
    g.closePath();
    g.lineJoin = "round";
    g.lineWidth = 1.6;
    g.fill();
    g.stroke();
    // The fold line, cut out.
    g.globalCompositeOperation = "destination-out";
    g.beginPath();
    g.moveTo(11, 13);
    g.lineTo(21.5, 2.5);
    g.lineWidth = 1.7;
    g.stroke();
    g.globalCompositeOperation = "source-over";
  } else {
    g.beginPath();
    g.arc(12, 12, 11, 0, Math.PI * 2);
    g.fill();
    g.globalCompositeOperation = "destination-out";
    g.beginPath();
    g.moveTo(7.2, 12.4);
    g.lineTo(10.6, 15.8);
    g.lineTo(17, 8.8);
    g.lineWidth = 2.4;
    g.lineCap = "round";
    g.lineJoin = "round";
    g.stroke();
    g.globalCompositeOperation = "source-over";
  }
  g.restore();
  g.font = FONT;
  g.textBaseline = "middle";
  g.textAlign = "left";
  g.fillText(label.text, 2 + ICON + 8, label.height / 2 + 1);
}

function makeLabel(text: string, icon: Label["icon"], step: number): Label {
  const canvas = document.createElement("canvas");
  const g = canvas.getContext("2d", { willReadFrequently: true })!;
  g.font = FONT;
  const width = Math.ceil(ICON + 8 + g.measureText(text).width) + 4;
  const height = Math.ceil(Math.max(ICON, TEXT_H)) + 4;
  const scale = 2;
  canvas.width = width * scale;
  canvas.height = height * scale;
  g.setTransform(scale, 0, 0, scale, 0, 0);
  drawLabel(g, { text, icon, width, height }, "#fff");
  const data = g.getImageData(0, 0, canvas.width, canvas.height).data;
  const points: { x: number; y: number }[] = [];
  for (let y = step / 2; y < height; y += step) {
    for (let x = step / 2; x < width; x += step) {
      const px = Math.min(Math.floor(x * scale), canvas.width - 1);
      const py = Math.min(Math.floor(y * scale), canvas.height - 1);
      if (data[(py * canvas.width + px) * 4 + 3] > 96) points.push({ x: x - width / 2, y: y - height / 2 });
    }
  }
  return { points, width, height, text, icon };
}

function pair(source: Label, target: Label): Particle[] {
  const order = (a: { x: number; y: number }, b: { x: number; y: number }) => (a.x === b.x ? a.y - b.y : a.x - b.x);
  const from = [...source.points].sort(order);
  const to = [...target.points].sort(order);
  const count = Math.max(from.length, to.length);
  return Array.from({ length: count }, (_, index) => {
    const a = from[Math.floor((index * from.length) / count)];
    const b = to[Math.floor((index * to.length) / count)];
    return { fx: a.x, fy: a.y, tx: b.x, ty: b.y, fromSweep: a.x / source.width + 0.5, toSweep: b.x / target.width + 0.5, r1: Math.random(), r2: Math.random(), r3: Math.random(), r4: Math.random() };
  });
}

/** The crisp label, drawn the same way it was sampled so the grains land exactly on it. */
function Crisp({ label, color, visible }: { label: Label; color: string; visible: boolean }) {
  const canvas = useCanvas2D(label.width, label.height);
  useEffect(() => {
    const g = canvas.get();
    if (!g) return;
    g.clearRect(0, 0, label.width, label.height);
    drawLabel(g, label, color);
  });
  return (
    <canvas
      ref={canvas.ref}
      style={{ ...canvas.style, position: "absolute", left: (SIZE.w - label.width) / 2, top: (SIZE.h - label.height) / 2, opacity: visible ? 1 : 0 }}
    />
  );
}

export default function ParticleDissolve({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const finish = useTimeouts();
  const [sent, setSent] = useState(false);
  const sentRef = useRef(false);
  const [labels, setLabels] = useState<Label[]>([]);
  const labelsRef = useRef<Label[]>([]);
  const run = useRef<{ start: number; particles: Particle[]; forward: boolean } | null>(null);
  const [running, setRunning] = useState(false);
  const [labelVisible, setLabelVisible] = useState(true);
  const dark = ctx.scheme === "dark";
  const greenInk = dark ? [0x5b, 0xe4, 0x9b] : [0x17, 0x80, 0x3f];
  const grain = ctx.n("grain");
  const speed = Math.max(ctx.n("speed"), 0.2);
  const params = useRef({ grain, drift: 28, turbulence: 0.5, speed, greenInk });
  params.current = { grain, drift: ctx.n("drift"), turbulence: ctx.n("turbulence"), speed, greenInk };
  const zh = ctx.lang === "zh";

  useEffect(() => {
    let cancelled = false;
    const build = () => {
      if (cancelled) return;
      finish.clearAll();
      run.current = null;
      setRunning(false);
      setLabelVisible(true);
      const next = [makeLabel(zh ? "发送邀请" : "Send invite", "plane", grain), makeLabel(zh ? "邀请已发送" : "Invite sent", "check", grain)];
      labelsRef.current = next;
      setLabels(next);
    };
    build();
    // Fonts that arrive late change the glyph shapes: sample again.
    void document.fonts?.ready.then(build);
    return () => {
      cancelled = true;
    };
  }, [zh, grain, finish.clearAll]);

  const dust = useCanvas2D(AREA.w, AREA.h);
  const dissolve = (buzz: boolean) => {
    const list = labelsRef.current;
    if (run.current || list.length !== 2) return;
    const forward = !sentRef.current;
    const source = list[forward ? 0 : 1];
    const target = list[forward ? 1 : 0];
    if (!source.points.length || !target.points.length) return;
    run.current = { start: nowSeconds(), particles: pair(source, target), forward };
    setRunning(true);
    setLabelVisible(false);
    sentRef.current = forward;
    setSent(forward);
    finish.clearAll();
    finish.after(TOTAL / params.current.speed, () => {
      setLabelVisible(true);
      run.current = null;
      setRunning(false);
      dust.get()?.clearRect(0, 0, AREA.w, AREA.h);
      if (buzz) haptics.tap("soft");
    });
  };
  useAutoplay(ctx.isPreview, () => dissolve(false), { every: TOTAL / speed + 1.1, delay: 0.5 });

  useFrame(
    () => {
      const g = dust.get();
      if (!g) return;
      g.clearRect(0, 0, AREA.w, AREA.h);
      const r = run.current;
      if (!r) return;
      const p = params.current;
      const t = (nowSeconds() - r.start) * p.speed;
      const white = [255, 255, 255];
      const source = r.forward ? white : p.greenInk;
      const target = r.forward ? p.greenInk : white;
      const cx = AREA.w / 2;
      const cy = AREA.h / 2;
      for (const q of r.particles) {
        const leave = clamp((t - (q.fromSweep * 0.38 + q.r1 * 0.14)) / 0.75);
        const out = 1 - Math.pow(1 - leave, 3);
        const angle = -0.62 + (q.r2 - 0.5) * 2.4 * p.turbulence;
        const distance = p.drift * (0.55 + 0.9 * q.r3);
        const bob = 3 * p.turbulence * out;
        const dustX = q.fx + Math.cos(angle) * distance * out + Math.sin(t * 2.1 + q.r1 * 6.28) * bob;
        const dustY = q.fy + Math.sin(angle) * distance * out + Math.cos(t * 1.7 + q.r2 * 6.28) * bob;
        const arrive = clamp((t - (0.92 + q.toSweep * 0.34 + q.r4 * 0.12)) / 0.7);
        const back = arrive - 1;
        const settle = 1 + 2.4 * back * back * back + 1.4 * back * back;
        const x = dustX + (q.tx - dustX) * settle;
        const y = dustY + (q.ty - dustY) * settle;
        const loose = out * (1 - arrive);
        const side = p.grain * (1 - 0.3 * loose);
        const c = source.map((v, i) => Math.round(v + (target[i] - v) * arrive));
        g.fillStyle = `rgb(${c[0]} ${c[1]} ${c[2]} / ${1 - 0.5 * loose})`;
        g.fillRect(cx + x - side / 2, cy + y - side / 2, side, side);
      }
    },
    ctx.isPreview ? 30 : undefined,
    running,
  );

  const { held, handlers } = useLatchedPress();
  const swap = delayed(springDB(0.55 / speed, 0), 0.45 / speed);
  const ink = `rgb(${greenInk.join(" ")})`;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ position: "relative", width: AREA.w, height: AREA.h, flexShrink: 0 }}>
        <motion.button
          type="button"
          {...handlers}
          onClick={() => {
            haptics.tap("medium");
            dissolve(true);
          }}
          initial={false}
          animate={{ scale: held ? 0.96 : 1 }}
          transition={spring(0.3, 0.6)}
          style={{ position: "absolute", left: (AREA.w - SIZE.w) / 2, top: (AREA.h - SIZE.h) / 2, width: SIZE.w, height: SIZE.h, borderRadius: SIZE.h / 2 }}
        >
          <motion.div
            initial={false}
            animate={{ boxShadow: sent ? `0px 9px 16px ${alpha(Palette.green, 0.2)}` : `0px 9px 16px ${alpha(Palette.indigo, 0.36)}` }}
            transition={swap}
            style={{ position: "absolute", inset: 0, borderRadius: SIZE.h / 2, background: Palette.primary, overflow: "hidden" }}
          >
            <motion.div initial={false} animate={{ opacity: sent ? 1 : 0 }} transition={swap} style={{ position: "absolute", inset: 0, background: Palette.elevated }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: SIZE.h / 2, background: alpha(Palette.green, 0.18), boxShadow: `inset 0 0 0 1.2px ${alpha(Palette.green, 0.55)}` }} />
            </motion.div>
          </motion.div>
          {labels.length === 2 ? (
            <Crisp label={labels[sent ? 1 : 0]} color={sent ? ink : "#fff"} visible={labelVisible} />
          ) : (
            <span style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff", fontSize: 18, fontWeight: 600 }}>{ctx.t("Send invite", "发送邀请")}</span>
          )}
        </motion.button>
        <canvas ref={dust.ref} style={{ ...dust.style, position: "absolute", inset: 0 }} />
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap the button" zh="点击按钮" style={{ paddingBottom: 18 }} />
    </div>
  );
}
