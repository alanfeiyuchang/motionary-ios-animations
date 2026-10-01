/** text.score-flip · 比分翻牌 (Text+ScoreFlip.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, forever, hex, spring, springDB, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { RollingText } from "./_text-kit";
import { curve, usePulse } from "./_fx";

const START = [87, 85];
const SCRIPT = [
  { side: 0, points: 3 },
  { side: 1, points: 2 },
  { side: 1, points: 3 },
  { side: 0, points: 2 },
  { side: 1, points: 3 },
  { side: 0, points: 2 },
];
const TINTS = [Palette.amber, Palette.sky];
const CARD = { w: 54, h: 78 };

export default function ScoreFlip({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [scores, setScores] = useState(START);
  const [dimmed, setDimmed] = useState<number | null>(null);
  const [pulses, setPulses] = useState([0, 0]);
  const [points, setPoints] = useState([3, 2]);
  const [seconds, setSeconds] = useState(151);
  const step = useRef(0);
  const live = useRef({ scores: START });
  const dimTimer = useRef(0);
  useEffect(() => () => window.clearTimeout(dimTimer.current), []);
  const names = [ctx.t("HOME", "主队"), ctx.t("AWAY", "客队")];
  const flip = ctx.n("flip");
  const stagger = ctx.n("stagger");
  const dim = ctx.n("dim");

  const score = (index: number, amount: number) => {
    step.current += 1;
    const current = live.current.scores;
    if (!(current[index] + amount <= 99) || (ctx.isPreview && step.current % (SCRIPT.length + 1) === 0)) {
      // New game: every card flips back, nobody is highlighted.
      live.current.scores = START;
      setScores(START);
      setSeconds(151);
      return;
    }
    const next = current.map((s, i) => (i === index ? s + amount : s));
    live.current.scores = next;
    setScores(next);
    setPoints((p) => p.map((v, i) => (i === index ? amount : v)));
    setPulses((p) => p.map((v, i) => (i === index ? v + 1 : v)));
    setSeconds((s) => Math.max(s - 14, 9));
    setDimmed(1 - index);
    window.clearTimeout(dimTimer.current);
    dimTimer.current = window.setTimeout(() => setDimmed(null), 1000);
  };
  const auto = () => {
    const entry = SCRIPT[step.current % SCRIPT.length];
    score(entry.side, entry.points);
  };
  useAutoplay(ctx.isPreview, auto, { every: 1.9 });

  const side = (index: number) => {
    const tint = TINTS[index];
    const value = scores[index];
    const ahead = scores[index] > scores[1 - index];
    const isDim = dimmed === index;
    return (
      <motion.div
        onClick={() => {
          haptics.tap("rigid");
          score(index, step.current % 2 === 0 ? 3 : 2);
        }}
        initial={false}
        animate={{ opacity: isDim ? 1 - dim : 1, filter: `saturate(${isDim ? 0.4 : 1})` }}
        transition={isDim ? anim.easeOut(0.18) : anim.easeInOut(0.45)}
        style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 9, cursor: "pointer" }}
      >
        <div style={{ position: "relative", display: "flex", gap: 5 }}>
          <FlipDigit glyph={String(Math.floor(value / 10))} duration={flip} delay={stagger} />
          <FlipDigit glyph={String(value % 10)} duration={flip} delay={0} />
          <Flash trigger={pulses[index]} duration={flip + 0.7} landing={(flip * 0.72) / (flip + 0.7)} tint={tint} />
          <Pop trigger={pulses[index]} points={points[index]} tint={tint} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ width: 10, height: 10, borderRadius: 3, background: tint }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 13, lineHeight: "16px", fontWeight: 800, letterSpacing: 1.4, marginRight: -1.4, color: white(0.9) }}>{names[index]}</span>
        </div>
        <motion.div initial={false} animate={{ width: ahead ? 46 : 10, opacity: ahead ? 1 : 0.28 }} transition={spring(0.45, 0.6)} style={{ height: 4, borderRadius: 2, background: tint }} />
      </motion.div>
    );
  };

  const mm = String(Math.floor(seconds / 60)).padStart(2, "0");
  const ss = String(seconds % 60).padStart(2, "0");
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: 38,
          padding: "14px 20px 18px",
          borderRadius: 28,
          background: `linear-gradient(${hex(0x1d1d24)}, ${hex(0x0e0e12)})`,
          boxShadow: `inset 0 0 0 1px ${white(0.09)}, 0 12px 40px ${black(0.28)}`,
        }}
      >
        <div style={{ width: 252, display: "flex", alignItems: "center", gap: 8 }}>
          <motion.span initial={{ opacity: 1 }} animate={{ opacity: 0.35 }} transition={forever(anim.easeInOut(0.9))} style={{ width: 6, height: 6, borderRadius: "50%", background: Palette.red }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 11, lineHeight: "13px", fontWeight: 800, letterSpacing: 1.2, color: white(0.7) }}>{ctx.t("LIVE", "直播")}</span>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 11, lineHeight: "13px", fontWeight: 700, color: white(0.5) }}>{ctx.t("Q4", "第四节")}</span>
          <RollingText value={seconds} text={`${mm}:${ss}`} transition={springDB(0.3, 0.15)} style={{ fontFamily: fonts.mono, fontSize: 13, lineHeight: "16px", fontWeight: 700, color: white(0.85) }} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          {side(0)}
          <div style={{ display: "flex", flexDirection: "column", gap: 9, paddingBottom: 38 }}>
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: white(0.35) }} />
            <span style={{ width: 6, height: 6, borderRadius: "50%", background: white(0.35) }} />
          </div>
          {side(1)}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap a side to score" zh="点击任意一方得分" />
    </div>
  );
}

/** 0…180°: the flap falls with growing speed, hits the lower half at 72% and rebounds about 14°. */
function flapAngle(p: number) {
  const fall = 0.72;
  if (p < fall) {
    const u = p / fall;
    return 180 * (0.3 * u + 0.7 * u * u);
  }
  const v = (p - fall) / (1 - fall);
  return 180 - 14 * Math.sin(Math.PI * v) * (1 - v);
}

function FlipDigit({ glyph, duration, delay }: { glyph: string; duration: number; delay: number }) {
  const last = useRef(glyph);
  const leaving = useRef(glyph);
  if (last.current !== glyph) {
    leaving.current = last.current;
    last.current = glyph;
  }
  const e = useElapsed(glyph, duration + delay, true);
  const p = e < 0 ? 1 : clamp((e - delay) / Math.max(duration, 0.001));
  const angle = flapAngle(p);
  const lean = Math.sin((angle * Math.PI) / 180);
  // SwiftUI's perspective 0.45 on a 78 pt view.
  const perspective = CARD.h / 0.45;
  return (
    <div style={{ position: "relative", width: CARD.w, height: CARD.h }}>
      {/* Revealed behind the falling flap: the new upper half, in the flap's shadow at first. */}
      <Half glyph={glyph} top shade={0.45 * Math.max(1 - angle / 90, 0)} />
      {/* The old lower half, shadowed as the flap comes down over it. */}
      <Half glyph={leaving.current} top={false} shade={angle > 90 ? 0.5 * lean : 0} />
      {angle < 90 ? (
        <Half glyph={leaving.current} top shade={0.4 * lean} transform={`perspective(${perspective}px) rotateX(${-angle}deg)`} />
      ) : (
        <Half glyph={glyph} top={false} shade={0.35 * lean} transform={`perspective(${perspective}px) rotateX(${180 - angle}deg)`} />
      )}
      <div style={{ position: "absolute", left: 0, right: 0, top: CARD.h / 2 - 0.75, height: 1.5, background: black(0.75) }} />
    </div>
  );
}

function Half({ glyph, top, shade, transform }: { glyph: string; top: boolean; shade: number; transform?: string }) {
  const card: CSSProperties = {
    position: "absolute",
    inset: 0,
    borderRadius: 10,
    background: `linear-gradient(${hex(0x34343e)}, ${hex(0x1f1f27)})`,
    boxShadow: `inset 0 0 0 1px ${white(0.1)}`,
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontFamily: fonts.rounded,
    fontSize: 58,
    fontWeight: 800,
    fontVariantNumeric: "tabular-nums",
    color: "#fff",
    overflow: "hidden",
  };
  return (
    <div style={{ position: "absolute", inset: 0, transform, clipPath: top ? "inset(0 0 50% 0)" : "inset(50% 0 0 0)" }}>
      <div style={card}>
        {glyph}
        <div style={{ position: "absolute", inset: 0, background: black(shade) }} />
      </div>
    </div>
  );
}

function Flash({ trigger, duration, landing, tint }: { trigger: number; duration: number; landing: number; tint: string }) {
  const p = usePulse(trigger, duration);
  const rise = clamp((p - landing * 0.7) / Math.max(landing * 0.3, 0.001));
  const fall = clamp((p - landing) / Math.max(1 - landing, 0.001));
  const amount = p >= 1 ? 0 : rise * (1 - fall) * (1 - fall);
  if (amount <= 0) return null;
  return (
    <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
      <div style={{ position: "absolute", inset: -6, borderRadius: 12, background: tint, filter: "blur(18px)", opacity: 0.55 * amount }} />
      <div style={{ position: "absolute", inset: 0, borderRadius: 12, background: tint, opacity: 0.5 * amount, mixBlendMode: "plus-lighter" }} />
    </div>
  );
}

function Pop({ trigger, points, tint }: { trigger: number; points: number; tint: string }) {
  const p = usePulse(trigger, 1.1);
  const rise = curve.easeOutCubic(p);
  const alpha = p >= 1 ? 0 : Math.min(p / 0.12, 1) * (1 - curve.smoothstep((p - 0.55) / 0.45));
  const pop = 0.6 + 0.4 * curve.easeOutCubic(Math.min(p / 0.2, 1));
  if (alpha <= 0) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
      <span
        style={{
          fontFamily: fonts.rounded,
          fontSize: 17,
          lineHeight: "20px",
          fontWeight: 800,
          color: hex(0x15151a),
          padding: "3px 9px",
          borderRadius: 999,
          background: tint,
          transform: `translateY(${-10 - 20 * rise}px) scale(${pop})`,
          opacity: alpha,
        }}
      >
        +{points}
      </span>
    </div>
  );
}
