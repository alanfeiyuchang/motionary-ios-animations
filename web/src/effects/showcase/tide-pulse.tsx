/** showcase.tide-pulse · 实时行情脉冲 (Showcase+TidePulse.swift) */
import { motion } from "motion/react";
import { Pause } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, anim, clamp, delayed, fonts, localPoint, springAt, springDB, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportLiveDot, sportHash } from "./_a-sport";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const OPEN = 184.2;
const COUNT = 41;
const PW = 250;
const PH = 96;
const STEP = PW / (COUNT - 2);

function nextPrice(previous: number, tick: number, vol: number): number {
  const target = OPEN + (0.6 + 2.2 * Math.sin(tick * 0.13) + 1.1 * Math.sin(tick * 0.047 + 1)) * vol;
  const noise = (sportHash(tick * 1.91 + 3) - 0.5) * 1.5 * vol;
  return Math.round((previous + (target - previous) * 0.14 + noise) * 100) / 100;
}
function seed(vol: number): number[] {
  const values: number[] = [];
  let last = OPEN;
  for (let tick = 0; tick < COUNT; tick++) {
    last = nextPrice(last, tick, vol);
    values.push(last);
  }
  return values;
}
function range(values: number[], vol: number) {
  const pad = 0.3 + 0.35 * vol;
  return { lo: Math.min(...values, OPEN) - pad, hi: Math.max(...values, OPEN) + pad };
}
function valueAt(points: number[], x: number): number {
  const position = x / STEP + 1;
  const lower = clamp(Math.floor(position), 0, points.length - 1);
  const upper = Math.min(lower + 1, points.length - 1);
  return points[lower] + (points[upper] - points[lower]) * (position - lower);
}

export default function TidePulse({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const vol = ctx.n("vol");
  const beat = ctx.n("beat");
  const [points, setPoints] = useState(() => seed(vol));
  const init = useRef(range(points, vol));
  const [shift, shiftApi] = useAnimatedNumber(0);
  const [lo, loApi] = useAnimatedNumber(init.current.lo);
  const [hi, hiApi] = useAnimatedNumber(init.current.hi);
  const [flash, setFlash] = useState<{ n: number; up: boolean }>({ n: 0, up: true });
  const [chipUp, setChipUp] = useState(points[points.length - 1] >= OPEN);
  const [flips, setFlips] = useState(0);
  const [scrubX, setScrubX] = useState<number | null>(null);
  const st = useRef({ points, tick: COUNT, chipUp, scrubbing: false, scripting: false, lastIndex: -1, vol, beat, hold: 0 });
  st.current.vol = vol;
  st.current.beat = beat;
  const script = useStudioScript();
  const scrubbing = scrubX !== null;

  const upColor = ctx.i("palette") === 1 ? "#FF5A5F" : Signature.lime;
  const downColor = ctx.i("palette") === 1 ? "#3DDC97" : "#FF6B5E";

  const advance = () => {
    const s = st.current;
    const previous = s.points[s.points.length - 1] ?? OPEN;
    const next = nextPrice(previous, s.tick, s.vol);
    s.points = [...s.points, next];
    if (s.points.length > COUNT) s.points.shift();
    setPoints(s.points);
    shiftApi.set(1);
    setFlash((f) => ({ n: f.n + 1, up: next >= previous }));
    s.tick += 1;
    const r = range(s.points, s.vol);
    const out = anim.easeOut(Math.min(0.55, s.beat * 0.8));
    shiftApi.animateTo(0, out);
    loApi.animateTo(r.lo, out);
    hiApi.animateTo(r.hi, out);
    const nowUp = next >= OPEN;
    if (nowUp !== s.chipUp) {
      s.chipUp = nowUp;
      setFlips((n) => n + 1);
      window.setTimeout(() => setChipUp(nowUp), 140);
    }
  };
  useEffect(() => {
    if (scrubbing) return;
    const id = window.setInterval(advance, beat * 1000);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scrubbing, beat]);

  const buzz = (f: () => void) => {
    if (!st.current.scripting) f();
  };
  const beginScrub = (x: number) => {
    buzz(() => haptics.tap("medium"));
    st.current.scrubbing = true;
    setScrubX(clamp(x, 0, PW));
  };
  const scrub = (x: number) => {
    const c = clamp(x, 0, PW);
    st.current.scrubbing = true;
    setScrubX(c);
    const index = Math.round(c / STEP);
    if (index !== st.current.lastIndex) {
      st.current.lastIndex = index;
      buzz(() => haptics.selection());
    }
  };
  const endScrub = () => {
    if (!st.current.scrubbing) return;
    st.current.scrubbing = false;
    setScrubX(null);
  };
  const runScript = () => {
    if (st.current.scrubbing) return;
    script.run(async (s) => {
      st.current.scripting = true;
      beginScrub(PW * 0.84);
      const legs: [number, number, number][] = [[0.84, 0.3, 1.1], [0.3, 0.62, 0.8]];
      for (const [from, to, duration] of legs) {
        if (!(await s.script(duration, (t) => scrub(PW * (from + (to - from) * studioEase(t)))))) {
          if (s.alive()) endScrub();
          return;
        }
      }
      await s.pause(0.3);
      if (!s.alive()) return;
      endScrub();
      st.current.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 7.5, delay: 3.2 });

  const down = useRef(false);
  const hold = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      if (st.current.scripting) {
        script.cancel();
        st.current.scripting = false;
        endScrub();
      }
      const x = localPoint(e, e.currentTarget).x;
      window.clearTimeout(st.current.hold);
      st.current.hold = window.setTimeout(() => {
        if (down.current && !st.current.scrubbing) beginScrub(x);
      }, 220);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current && st.current.scrubbing && !st.current.scripting) scrub(localPoint(e, e.currentTarget).x);
    },
    onPointerUp: () => {
      down.current = false;
      window.clearTimeout(st.current.hold);
      if (!st.current.scripting) endScrub();
    },
    onPointerCancel: () => {
      down.current = false;
      window.clearTimeout(st.current.hold);
      if (!st.current.scripting) endScrub();
    },
  };

  const value = scrubX === null ? points[points.length - 1] ?? OPEN : Math.round(valueAt(points, scrubX) * 100) / 100;
  const up = value >= OPEN;
  const color = up ? upColor : downColor;
  const delta = value - OPEN;
  const percent = (Math.abs(delta) / OPEN) * 100;
  const chipIsUp = scrubbing ? delta >= 0 : chipUp;

  const y = (v: number) => PH - 6 - ((v - lo) / Math.max(hi - lo, 0.01)) * (PH - 12);
  const x = (index: number) => (index - 1 + shift) * STEP;
  const headY = y(points[points.length - 2]) + (y(points[points.length - 1]) - y(points[points.length - 2])) * (1 - shift);

  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    if (el.width !== PW * dpr) {
      el.width = PW * dpr;
      el.height = PH * dpr;
    }
    const g = el.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, PW, PH);
    const line = new Path2D();
    points.forEach((p, i) => (i === 0 ? line.moveTo(x(i), y(p)) : line.lineTo(x(i), y(p))));
    const area = new Path2D(line);
    area.lineTo(x(points.length - 1), PH);
    area.lineTo(x(0), PH);
    area.closePath();
    g.strokeStyle = white(0.22);
    g.lineWidth = 1;
    g.setLineDash([3, 4]);
    g.beginPath();
    g.moveTo(0, y(OPEN));
    g.lineTo(PW, y(OPEN));
    g.stroke();
    g.setLineDash([]);
    const fill = g.createLinearGradient(0, 0, 0, PH);
    fill.addColorStop(0, color + "52");
    fill.addColorStop(1, color + "00");
    const paint = (clipW: number, alpha: number) => {
      g.save();
      g.beginPath();
      g.rect(0, 0, clipW, PH);
      g.clip();
      g.globalAlpha = alpha;
      g.fillStyle = fill;
      g.fill(area);
      g.strokeStyle = color;
      g.lineWidth = 2.2;
      g.lineCap = "round";
      g.lineJoin = "round";
      g.stroke(line);
      g.restore();
    };
    paint(PW, scrubX === null ? 1 : 0.25);
    if (scrubX !== null) {
      paint(scrubX, 1);
      g.strokeStyle = white(0.7);
      g.lineWidth = 1;
      g.beginPath();
      g.moveTo(scrubX, 0);
      g.lineTo(scrubX, PH);
      g.stroke();
      const dy = y(valueAt(points, scrubX));
      g.fillStyle = color + "59";
      g.beginPath();
      g.arc(scrubX, dy, 6.5, 0, Math.PI * 2);
      g.fill();
      g.fillStyle = "#fff";
      g.beginPath();
      g.arc(scrubX, dy, 4, 0, Math.PI * 2);
      g.fill();
    }
  });

  const flipE = useElapsed(flips, 0.7, true);
  const angle = flipE < 0 ? 0 : flipE < 0.14 ? 90 * studioEase(flipE / 0.14) : -90 * (1 - springAt(flipE - 0.14, 0.32, 0.55));
  const agoText = scrubX === null ? "" : (() => {
    const seconds = Math.round(((PW - scrubX) / STEP) * beat);
    return zh ? `${seconds} 秒前` : `${seconds} s ago`;
  })();
  const stat = (label: string, v: number) => (
    <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
      <span style={signatureEyebrow()}>{label}</span>
      <span style={{ ...signatureNumber(15), lineHeight: "18px", color: white(0.9) }}>
        <NumericText value={v} text={v.toFixed(2)} />
      </span>
    </div>
  );
  const flashColor = flash.up ? upColor : downColor;

  return (
    <StudioScene ctx={ctx} en="Press and hold the chart to scrub" zh="长按走势图回看">
      <div style={{ ...signatureCard(), width: 300, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ ...signatureEyebrow(), display: "flex", alignItems: "center", gap: 6, whiteSpace: "nowrap" }}>
          <span style={{ width: 24, height: 24, display: "grid", placeItems: "center" }}>
            {scrubbing ? <Pause size={11} fill="currentColor" strokeWidth={0} /> : <SportLiveDot color={Signature.accent} preview={ctx.isPreview} />}
          </span>
          <span style={{ color: "#fff" }}>SOLR</span>
          <span>{scrubbing ? agoText : zh ? "实时" : "Live"}</span>
          <span style={{ flex: 1 }} />
          <span>Solaris Energy</span>
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
          {scrubbing ? (
            <span style={{ ...signatureNumber(40), lineHeight: "48px" }}>{value.toFixed(2)}</span>
          ) : (
            <motion.span
              key={flash.n}
              initial={{ color: flash.n === 0 ? "#FFFFFF" : flashColor }}
              animate={{ color: "#FFFFFF" }}
              transition={delayed(anim.easeOut(0.7), 0.12)}
              style={{ ...signatureNumber(40), lineHeight: "48px" }}
            >
              <NumericText value={value} text={value.toFixed(2)} />
            </motion.span>
          )}
          <span style={{ perspective: 60, display: "inline-flex", alignSelf: "center" }}>
            <span
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 3,
                padding: "4px 8px",
                borderRadius: 12,
                background: chipIsUp ? upColor : downColor,
                color: Signature.ink,
                fontFamily: fonts.rounded,
                fontSize: 12,
                fontWeight: 700,
                fontVariantNumeric: "tabular-nums",
                lineHeight: "14px",
                transform: `rotateX(${angle}deg)`,
              }}
            >
              <svg width={8} height={7} viewBox="0 0 8 7" style={{ transform: chipIsUp ? undefined : "rotate(180deg)" }}>
                <path d="M4 0.3 L7.8 6.7 H0.2 Z" fill="currentColor" />
              </svg>
              {scrubbing ? percent.toFixed(2) + "%" : <NumericText value={percent} text={percent.toFixed(2) + "%"} />}
            </span>
          </span>
        </div>
        <div {...hold} style={{ position: "relative", width: 264, height: PH, touchAction: "none" }}>
          <canvas ref={canvas} style={{ position: "absolute", left: 0, top: 0, width: PW, height: PH }} />
          <div style={{ position: "absolute", left: PW - 12, top: headY - 12, opacity: scrubbing ? 0.3 : 1, pointerEvents: "none" }}>
            <SportLiveDot color={color} size={8} period={1.2} preview={ctx.isPreview} />
          </div>
        </div>
        <motion.div initial={false} animate={{ opacity: scrubbing ? 0.25 : 1 }} transition={springDB(0.25, 0)} style={{ display: "flex", justifyContent: "space-between" }}>
          {stat(zh ? "开盘" : "Open", OPEN)}
          {stat(zh ? "最高" : "High", Math.max(...points))}
          {stat(zh ? "最低" : "Low", Math.min(...points))}
        </motion.div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
