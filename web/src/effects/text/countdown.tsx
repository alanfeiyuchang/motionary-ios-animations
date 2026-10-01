/** text.countdown · 发售倒计时 (Text+Countdown.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Radio } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, fonts, spring, useHaptics, useLatest, type DemoProps } from "../../kit";
import { useTask } from "./_text-kit";
import { RollGlyph } from "./_fx";

/** 3 days and 3 seconds: the fourth tick wraps every unit at once. */
const START = 3 * 86_400 + 3;
const FINAL_WINDOW = 5;
const EASE = "0.3s cubic-bezier(0, 0, 0.58, 1)";

export default function Countdown({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [remaining, setRemainingState] = useState(START);
  const remainingRef = useRef(START);
  const [celebrate, setCelebrate] = useState(0);
  /** Celebrate changes made by `setRemaining` ease out; the hops are springs. */
  const [celebrateEase, setCelebrateEase] = useState(false);
  const [jumps, setJumps] = useState(0);
  const armed = useRef(false);
  const colon = useMotionValue(1);
  const pulse = useMotionValue(1);
  const ringScale = useMotionValue(1.34);
  const ringOpacity = useMotionValue(0);
  const params = useLatest({ tick: ctx.n("tick"), pulse: ctx.n("pulse") });

  const isFinal = remaining <= FINAL_WINDOW && remaining > 0;
  const isLive = remaining === 0;

  const setRemaining = (value: number) => {
    remainingRef.current = value;
    setRemainingState(value);
    setCelebrateEase(true);
    setCelebrate(0);
  };

  const tick = () => {
    const value = remainingRef.current - 1;
    remainingRef.current = value;
    setRemainingState(value);
    const final = value <= FINAL_WINDOW && value > 0;
    // Colons: dim at once, come back before the next tick.
    colon.jump(0.25);
    ringScale.jump(1);
    ringOpacity.jump(final ? 0.7 : 0);
    animate(colon, 1, delayed(anim.easeInOut(Math.min(params.current.tick * 0.6, 0.6)), 0.08));
    if (!final) return;
    if (armed.current) haptics.tap("rigid");
    animate(pulse, [pulse.get(), params.current.pulse], anim.easeOut(0.1)).then(() => {
      animate(pulse, 1, spring(0.4, 0.45));
    });
    animate(ringScale, 1.34, delayed(anim.easeOut(0.55), 0.02));
    animate(ringOpacity, 0, delayed(anim.easeOut(0.55), 0.02));
  };

  useTask(jumps, async (sleep) => {
    setRemaining(jumps > 0 ? FINAL_WINDOW : START);
    for (;;) {
      if (!(await sleep(params.current.tick))) return;
      if (remainingRef.current === 0) {
        setRemaining(START);
        continue;
      }
      // After the big wrap has played, skip ahead to the last seconds.
      if (remainingRef.current === START - 6) {
        setRemaining(FINAL_WINDOW);
        continue;
      }
      tick();
      if (remainingRef.current === 0) {
        // Zero: the tiles hop one after another and settle in mint.
        if (armed.current) haptics.success();
        for (let unit = 0; unit < 5; unit++) {
          setCelebrateEase(false);
          setCelebrate(unit + 1);
          if (!(await sleep(0.07))) return;
        }
        if (!(await sleep(1.6))) return;
      }
    }
  });

  const units = [Math.floor(remaining / 86_400), Math.floor(remaining / 3_600) % 24, Math.floor(remaining / 60) % 60, remaining % 60];
  const labels = [ctx.t("DAYS", "天"), ctx.t("HRS", "时"), ctx.t("MIN", "分"), ctx.t("SEC", "秒")];
  const accent = isLive ? Palette.mint : isFinal ? Palette.red : null;
  const digitColor = accent ?? Palette.label;
  const softColor = accent ?? Palette.secondaryLabel;
  const tileEdge = isLive ? alpha(Palette.mint, 0.55) : isFinal ? alpha(Palette.red, 0.4) : Palette.stroke;
  const captionText = isLive ? ctx.t("Live now", "已开始") : ctx.t("Drop starts in", "距离发售还有");
  const captionSpring = spring(0.45, 0.8);

  return (
    <div
      onClick={() => {
        if (ctx.isPreview) return;
        armed.current = true;
        haptics.tap("medium");
        setJumps((j) => j + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 22, cursor: "pointer" }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 8, color: softColor, transition: `color ${EASE}` }}>
        <span style={{ position: "relative", width: 16, height: 16, display: "inline-flex", alignItems: "center", justifyContent: "center" }}>
          <AnimatePresence initial={false} mode="popLayout">
            <motion.span
              key={isLive ? "live" : "clock"}
              initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
              animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
              exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
              transition={captionSpring}
              style={{ display: "inline-flex" }}
            >
              {isLive ? <Radio size={16} strokeWidth={2.6} /> : <ClockFill />}
            </motion.span>
          </AnimatePresence>
        </span>
        <span style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700, whiteSpace: "pre" }}>
          <AnimatePresence initial={false} mode="popLayout">
            <motion.span
              key={captionText}
              initial={{ y: 10, opacity: 0, filter: "blur(3px)" }}
              animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
              exit={{ y: -10, opacity: 0, filter: "blur(3px)" }}
              transition={captionSpring}
              style={{ display: "inline-block" }}
            >
              {captionText}
            </motion.span>
          </AnimatePresence>
        </span>
      </div>

      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        {units.map((value, unit) => {
          const digits = [String(Math.floor(value / 10)), String(value % 10)];
          const isSeconds = unit === 3;
          return [
            <motion.div
              key={`t${unit}`}
              animate={{ y: celebrate === unit + 1 ? -10 : 0 }}
              transition={celebrateEase ? anim.easeOut(0.3) : spring(0.32, 0.5)}
              style={{ position: "relative", width: 64, height: 78, scale: isSeconds ? pulse : 1 }}
            >
              {isSeconds && (
                <motion.div
                  style={{ position: "absolute", inset: -1, borderRadius: 19, border: `2px solid ${Palette.red}`, scale: ringScale, opacity: ringOpacity, pointerEvents: "none" }}
                />
              )}
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: 18,
                  background: Palette.elevated,
                  boxShadow: `inset 0 0 0 1px ${tileEdge}, 0 6px 20px ${black(0.1)}`,
                  transition: `box-shadow ${EASE}`,
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 2,
                }}
              >
                <div style={{ display: "flex" }}>
                  {digits.map((d, place) => {
                    // Places counted from the right across the whole clock: seconds' ones roll first.
                    const order = (3 - unit) * 2 + (1 - place);
                    return (
                      <RollGlyph
                        key={place}
                        glyph={d}
                        direction={-1}
                        font={{ fontFamily: fonts.rounded, fontSize: 34, fontWeight: 800, fontVariantNumeric: "tabular-nums", lineHeight: "44px" }}
                        slot={{ w: 23, h: 44 }}
                        color={digitColor}
                        colorTransition={`color ${EASE}`}
                        response={ctx.n("response")}
                        damping={0.8}
                        delay={order * 0.05}
                        blur={3}
                      />
                    );
                  })}
                </div>
                <span style={{ fontFamily: fonts.rounded, fontSize: 10, lineHeight: "12px", fontWeight: 800, letterSpacing: 1, marginRight: -1, color: Palette.secondaryLabel }}>{labels[unit]}</span>
              </div>
            </motion.div>,
            unit < 3 && (
              <motion.div key={`c${unit}`} style={{ display: "flex", flexDirection: "column", gap: 8, paddingBottom: 14, opacity: colon }}>
                <span style={{ width: 5, height: 5, borderRadius: "50%", background: softColor, transition: `background-color ${EASE}` }} />
                <span style={{ width: 5, height: 5, borderRadius: "50%", background: softColor, transition: `background-color ${EASE}` }} />
              </motion.div>
            ),
          ];
        })}
      </div>

      <DemoHint ctx={ctx} en="Tap to jump to the last seconds" zh="点击跳到最后几秒" style={{ paddingTop: 10 }} />
    </div>
  );
}

/** `clock.fill`: a solid disc with the hands knocked out. */
function ClockFill() {
  return (
    <svg width={16} height={16} viewBox="0 0 16 16">
      <mask id="text-countdown-clock">
        <rect width={16} height={16} fill="#fff" />
        <path d="M8 4.2 V8.2 H5" fill="none" stroke="#000" strokeWidth={1.5} strokeLinecap="round" strokeLinejoin="round" />
      </mask>
      <circle cx={8} cy={8} r={7.2} fill="currentColor" mask="url(#text-countdown-clock)" />
    </svg>
  );
}
