/** text.rank-change · 排名升降 (Text+RankChange.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, fonts, spring, useAutoplay, useHaptics, useLatest, type DemoProps } from "../../kit";
import { RollingText } from "./_text-kit";
import { RollGlyph, curve, usePulse } from "./_fx";

const YOU = 6;
const ROW_HEIGHT = 34;
const ROW_SPACING = 4;
/** Places moved per change (negative = climbing). They sum to zero, so the loop is seamless. */
const MOVES = [-2, -1, 2, -2, 1, 2];
const NAMES = {
  zh: ["林夏", "周屿", "沈星", "陈默", "许诺", "江南", "你", "乔一", "唐棠", "顾北", "苏禾", "叶子"],
  en: ["Ava", "Noah", "Mia", "Leo", "Zoe", "Eli", "You", "Ivy", "Max", "Uma", "Kai", "Ada"],
};
const EASE = "cubic-bezier(0, 0, 0.58, 1)";

export default function RankChange({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [order, setOrder] = useState(() => Array.from({ length: 12 }, (_, i) => i));
  const orderRef = useRef(order);
  const [center, setCenter] = useState(YOU);
  const [direction, setDirection] = useState(1);
  const [delta, setDelta] = useState(2);
  const [pulses, setPulses] = useState(0);
  const [hot, setHot] = useState(false);
  const step = useRef(0);
  const timers = useRef<number[]>([]);
  useEffect(() => () => timers.current.forEach((t) => window.clearTimeout(t)), []);
  const response = ctx.n("response");
  const stagger = ctx.n("stagger");
  const flashHold = useLatest(ctx.n("flash"));

  const youIndex = order.indexOf(YOU);
  const tint = direction > 0 ? Palette.green : Palette.red;
  const names = NAMES[ctx.lang];

  const move = () => {
    const amount = MOVES[step.current % MOVES.length];
    step.current += 1;
    const current = orderRef.current;
    const from = current.indexOf(YOU);
    const to = Math.min(Math.max(from + amount, 0), current.length - 1);
    if (to === from) return;
    setDirection(to < from ? 1 : -1);
    setDelta(Math.abs(to - from));
    setPulses((p) => p + 1);
    const next = current.slice();
    next.splice(from, 1);
    next.splice(to, 0, YOU);
    orderRef.current = next;
    setOrder(next);
    setHot(true);
    timers.current.forEach((t) => window.clearTimeout(t));
    timers.current = [
      window.setTimeout(() => setCenter(Math.min(Math.max(to, 2), next.length - 3)), 350),
      window.setTimeout(() => setHot(false), (0.35 + flashHold.current) * 1000),
    ];
  };
  useAutoplay(ctx.isPreview, move, { every: 2.0 });

  const glyphs = Array.from(String(youIndex + 1));
  const pitch = ROW_HEIGHT + ROW_SPACING;
  const windowHeight = pitch * 5 - ROW_SPACING;
  const rowSpring = spring(response, 0.75);
  const highlight = hot ? tint : Palette.indigo;
  const hotTransition = hot ? spring(0.3, 0.6) : anim.easeOut(0.45);
  const hotCSS = hot ? "0.3s" : "0.45s";

  return (
    <div
      onClick={() => {
        haptics.tap("light");
        move();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, cursor: "pointer" }}
    >
      <div style={{ height: 84, display: "flex", alignItems: "center", gap: 16 }}>
        <div style={{ position: "relative", display: "flex", alignItems: "flex-end", gap: 2 }}>
          <div
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              width: 120,
              height: 84,
              marginLeft: -60,
              marginTop: -42,
              maskImage: "linear-gradient(transparent, #000 30%, #000 70%, transparent)",
              WebkitMaskImage: "linear-gradient(transparent, #000 30%, #000 70%, transparent)",
              pointerEvents: "none",
            }}
          >
            <Streaks trigger={pulses} direction={direction} tint={tint} />
          </div>
          <span style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 30, lineHeight: "30px", fontWeight: 700, color: Palette.secondaryLabel, marginBottom: 12 }}>#</span>
          {glyphs.map((g, index) => (
            <RollGlyph
              key={glyphs.length - 1 - index}
              glyph={g}
              direction={direction}
              font={{ fontFamily: fonts.rounded, fontSize: 68, fontWeight: 800, fontVariantNumeric: "tabular-nums", lineHeight: "80px" }}
              slot={{ w: 44, h: 80 }}
              flash={tint}
              flashHold={ctx.n("flash")}
              response={response}
              damping={0.78}
              blur={5}
            />
          ))}
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 6 }}>
          <Chip trigger={pulses} direction={direction} delta={delta} tint={tint} />
          <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t("vs. last week", "较上周")}</span>
        </div>
      </div>

      <div
        style={{
          position: "relative",
          width: 292,
          height: windowHeight,
          maskImage: "linear-gradient(transparent, #000 16%, #000 84%, transparent)",
          WebkitMaskImage: "linear-gradient(transparent, #000 16%, #000 84%, transparent)",
        }}
      >
        <motion.div initial={false} animate={{ y: -(center - 2) * pitch }} transition={spring(response * 1.4, 0.86)} style={{ position: "absolute", left: 0, top: 0, width: 292 }}>
          {order.map((player, index) => {
            const isYou = player === YOU;
            const distance = Math.abs(index - youIndex);
            const accent = Palette.spectrum[player % Palette.spectrum.length];
            const numbers = delayed(rowSpring, isYou ? 0 : distance * stagger);
            return (
              <motion.div
                key={player}
                initial={false}
                animate={{ y: index * pitch }}
                transition={delayed(rowSpring, isYou ? 0 : distance * stagger)}
                style={{ position: "absolute", left: 0, top: 0, width: 292, height: ROW_HEIGHT, zIndex: isYou ? 1 : 0 }}
              >
                <motion.div
                  initial={false}
                  animate={{ scale: isYou && hot ? 1.04 : 1, boxShadow: `0 5px 20px ${black(isYou && hot ? 0.22 : 0)}` }}
                  transition={hotTransition}
                  style={{
                    position: "relative",
                    height: ROW_HEIGHT,
                    borderRadius: 11,
                    padding: "0 10px",
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                    background: isYou ? Palette.elevated : Palette.labelAlpha(0.05),
                    color: Palette.label,
                  }}
                >
                  {isYou && (
                    <div
                      style={{
                        position: "absolute",
                        inset: 0,
                        borderRadius: 11,
                        background: alpha(highlight, 0.18),
                        boxShadow: `inset 0 0 0 1px ${alpha(highlight, 0.55)}`,
                        transition: `background-color ${hotCSS} ${EASE}, box-shadow ${hotCSS} ${EASE}`,
                      }}
                    />
                  )}
                  <span style={{ position: "relative", width: 22, display: "flex", justifyContent: "center", color: isYou ? highlight : Palette.secondaryLabel, transition: `color ${hotCSS} ${EASE}` }}>
                    <RollingText value={-index} text={String(index + 1)} transition={numbers} style={{ fontFamily: fonts.rounded, fontSize: 14, lineHeight: "17px", fontWeight: 800 }} />
                  </span>
                  <span style={{ position: "relative", width: 20, height: 20, borderRadius: "50%", background: alpha(accent, isYou ? 1 : 0.75), flex: "none" }} />
                  <span style={{ position: "relative", fontSize: 15, lineHeight: "18px", fontWeight: isYou ? 700 : 500 }}>{names[player]}</span>
                  <span style={{ flex: 1 }} />
                  <RollingText
                    value={3120 - index * 135}
                    transition={numbers}
                    style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 13, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel }}
                  />
                </motion.div>
              </motion.div>
            );
          })}
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap for the next change" zh="点击触发下一次变化" />
    </div>
  );
}

function Chip({ trigger, direction, delta, tint }: { trigger: number; direction: number; delta: number; tint: string }) {
  const p = usePulse(trigger, 0.5);
  const eased = curve.easeOutCubic(p);
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 5,
        padding: "6px 12px",
        borderRadius: 999,
        color: tint,
        background: alpha(tint, 0.16),
        boxShadow: `inset 0 0 0 1px ${alpha(tint, 0.3)}`,
        transition: `color 0.25s ${EASE}, background-color 0.25s ${EASE}, box-shadow 0.25s ${EASE}`,
        transform: `translateY(${direction * 14 * (1 - eased)}px)`,
        opacity: 0.3 + 0.7 * eased,
      }}
    >
      <motion.svg width={13} height={14} viewBox="0 0 13 14" initial={false} animate={{ rotate: direction > 0 ? 0 : 180 }} transition={spring(0.4, 0.55)}>
        <path d="M6.5 12.6 V1.8 M1.8 6.4 L6.5 1.6 L11.2 6.4" fill="none" stroke="currentColor" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" />
      </motion.svg>
      <RollingText value={delta} transition={anim.easeOut(0.25)} style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "20px", fontWeight: 800 }} />
    </div>
  );
}

/** Three chevrons that streak past the number in the direction of the change. */
function Streaks({ trigger, direction, tint }: { trigger: number; direction: number; tint: string }) {
  const p = usePulse(trigger, 0.75);
  if (p >= 1) return null;
  return (
    <div style={{ position: "absolute", inset: 0, transform: "translateX(12px)" }}>
      {[0, 1, 2].map((index) => {
        const local = curve.clamp01((p - index * 0.093) / 0.7);
        const travel = curve.easeOutCubic(local);
        const alphaValue = Math.sin(Math.PI * local);
        return (
          <svg
            key={index}
            width={56}
            height={34}
            viewBox="0 0 56 34"
            style={{ position: "absolute", left: "50%", top: "50%", marginLeft: -28, marginTop: -17, opacity: 0.26 * alphaValue, transform: `translateY(${direction * (46 - 92 * travel)}px) rotate(${direction > 0 ? 0 : 180}deg)` }}
          >
            <path d="M6 27 L28 7 L50 27" fill="none" stroke={tint} strokeWidth={10} strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        );
      })}
    </div>
  );
}
