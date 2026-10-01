/** inputs.paste-code (Inputs+PasteCode.swift) */
import { AnimatePresence, animate, motion, useMotionValue, type MotionValue } from "motion/react";
import { useState } from "react";
import { RotateCcw } from "lucide-react";
import { DemoHint, Palette, alpha, anim, black, clamp, delayed, fonts, spring, textStyle, useAutoplay, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { CheckCircleFill } from "./_a-common";
import { LockGlyph } from "./_b-common";
import { BOUNCY, SNAPPY, column, spacer, springTrack, useLatchedPress, useLive, useMV, useQuiet, useTask } from "./_c-common";

type Phase = "empty" | "filling" | "verified";
const SIZE = { w: 300, h: 262 };
const DIGITS = ["3", "8", "4", "9", "2", "1"];
const BOX_Y = 72;
const CHIP_Y = 186;
const CHIP_W = 166;
const boxAt = (index: number) => ({ x: 11 + 19 + index * 46 + (index >= 3 ? 10 : 0), y: BOX_Y });
/** Centre of a digit while it sits inside the suggestion chip. */
const chipAt = (index: number) => {
  const digitsWidth = 6 * 11 + 5;
  const start = SIZE.w / 2 + CHIP_W / 2 - 14 - digitsWidth;
  return { x: start + 5.5 + index * 11 + (index >= 3 ? 5 : 0), y: CHIP_Y };
};

export default function PasteCode({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const press = useLatchedPress();
  const { wrap, quiet } = useQuiet();
  const [phase, setPhase, phaseRef] = useLive<Phase>("empty");
  const f0 = useMotionValue(0);
  const f1 = useMotionValue(0);
  const f2 = useMotionValue(0);
  const f3 = useMotionValue(0);
  const f4 = useMotionValue(0);
  const f5 = useMotionValue(0);
  const flight = [f0, f1, f2, f3, f4, f5];
  const [landed, setLanded] = useState(() => Array<boolean>(6).fill(false));
  const [pops, setPops] = useState(() => Array<number>(6).fill(0));
  const [gone, setGone] = useState(false);
  const [clearing, setClearing, clearingRef] = useLive(false);
  const [wave, setWave] = useState(0);
  const task = useTask();
  const verified = phase === "verified";
  void clearing;

  const paste = (silent: boolean) => {
    const stagger = ctx.n("stagger");
    const response = ctx.n("response");
    haptics.tap("light");
    setPhase("filling");
    flight.forEach((f, index) => animate(f, 1, delayed(spring(response, 0.74), index * stagger)));
    task.start(async (sleep) => {
      // A digit reaches its box a little before its spring settles.
      if (!(await sleep(response * 0.62))) return;
      for (let index = 0; index < 6; index++) {
        setLanded((l) => l.map((v, i) => (i === index ? true : v)));
        setPops((p) => p.map((v, i) => (i === index ? v + 1 : v)));
        if (!silent) haptics.tap("light");
        if (!(await sleep(stagger))) return;
      }
      if (!(await sleep(0.28))) return;
      setPhase("verified");
      setWave((w) => w + 1);
      if (!silent) haptics.success();
    });
  };
  const clear = () => {
    haptics.tap("light");
    setClearing(true);
    setGone(true);
    setLanded(Array<boolean>(6).fill(false));
    setPhase("empty");
    task.start(async (sleep) => {
      if (!(await sleep(0.34))) return;
      // The digits are invisible now: send them home without animation.
      flight.forEach((f) => f.jump(0));
      setGone(false);
      setClearing(false);
    });
  };
  const chipTapped = () => {
    if (clearingRef.current) return;
    press.bump();
    if (phaseRef.current === "empty") paste(quiet());
    else if (phaseRef.current === "verified") clear();
  };
  useAutoplay(ctx.isPreview, wrap(chipTapped), { every: 2.1, delay: 0.5 });

  const smooth = anim.smoothD(0.3);
  const statusColor = verified ? Palette.green : Palette.secondaryLabel;

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0 }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: 10, textAlign: "center", ...textStyle.subheadline, fontWeight: 600 }}>{ctx.t("Enter the 6-digit code", "输入 6 位验证码")}</div>
        {DIGITS.map((_, index) => (
          <Hop key={index} index={index} wave={wave} at={boxAt(index)}>
            <Box landed={landed[index]} verified={verified} pop={pops[index]} />
          </Hop>
        ))}
        {/* status */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 122 - 9, height: 18, display: "grid", placeItems: "center" }}>
          <AnimatePresence initial={false}>
            <motion.div
              key={verified ? "ok" : "sent"}
              initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
              exit={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              transition={anim.easeInOut(0.35)}
              style={{ gridArea: "1 / 1", display: "flex", alignItems: "center", gap: 6, ...textStyle.footnote, fontWeight: 600, color: statusColor, whiteSpace: "nowrap" }}
            >
              {verified ? <CheckCircleFill size={15} /> : <LockGlyph open={false} size={13} />}
              {verified ? ctx.t("Verified", "验证成功") : ctx.t("Sent to your phone", "已发送到你的手机")}
            </motion.div>
          </AnimatePresence>
        </div>
        {/* keyboard */}
        <div style={{ position: "absolute", left: 0, top: CHIP_Y + 22 - 50, width: SIZE.w, height: 100, borderRadius: "20px 20px 26px 26px", background: Palette.labelAlpha(0.07) }}>
          <div style={{ position: "absolute", left: 0, right: 0, top: 50 + 24 - 17, display: "flex", justifyContent: "center", gap: 4 }}>
            {"QWERTYUIOP".split("").map((letter) => (
              <div
                key={letter}
                style={{
                  width: 24.6,
                  height: 34,
                  borderRadius: 6,
                  background: Palette.elevated,
                  boxShadow: `0 1px 0 ${black(0.12)}`,
                  display: "grid",
                  placeItems: "center",
                  fontSize: 14,
                  fontWeight: 500,
                  color: Palette.labelAlpha(0.75),
                }}
              >
                {letter}
              </div>
            ))}
          </div>
          <motion.button
            type="button"
            onClick={chipTapped}
            {...press.handlers}
            animate={{ scale: press.pressed ? 0.94 : 1 }}
            transition={spring(0.3, 0.6)}
            style={{
              position: "absolute",
              left: (SIZE.w - CHIP_W) / 2,
              top: 50 - 22 - 17,
              width: CHIP_W,
              height: 34,
              padding: "0 14px",
              borderRadius: 17,
              background: Palette.elevated,
              boxShadow: `0 1px 4px ${black(0.12)}`,
              display: "grid",
              alignItems: "center",
            }}
          >
            <motion.div
              initial={false}
              animate={{ opacity: phase === "verified" ? 0 : phase === "empty" ? 1 : 0.35, filter: `blur(${phase === "verified" ? 5 : 0}px)` }}
              transition={smooth}
              style={{ gridArea: "1 / 1", display: "flex", alignItems: "center" }}
            >
              <span style={{ width: 67, textAlign: "left", fontSize: 12, fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden" }}>{ctx.t("Messages", "来自信息")}</span>
              <motion.span initial={false} animate={{ opacity: phase === "empty" ? 1 : 0 }} transition={phase === "empty" ? smooth : { duration: 0 }} style={{ display: "flex", fontFamily: fonts.rounded, fontSize: 15, fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
                {DIGITS.map((digit, index) => (
                  <span key={index} style={{ width: 11, textAlign: "center", marginLeft: index === 3 ? 5 : 0 }}>
                    {digit}
                  </span>
                ))}
              </motion.span>
            </motion.div>
            <motion.div
              initial={false}
              animate={{ opacity: phase === "verified" ? 1 : 0, filter: `blur(${phase === "verified" ? 0 : 5}px)` }}
              transition={smooth}
              style={{ gridArea: "1 / 1", display: "flex", alignItems: "center", justifyContent: "center", gap: 5, fontSize: 13, fontWeight: 600, color: Palette.secondaryLabel }}
            >
              <RotateCcw size={13} strokeWidth={2.6} />
              {ctx.t("Clear", "清除")}
            </motion.div>
          </motion.button>
        </div>
        {/* flying digits */}
        {DIGITS.map((digit, index) => (
          <FlyingDigit key={index} index={index} digit={digit} progress={flight[index]} lift={ctx.n("lift")} wave={wave} verified={verified} hidden={phase === "empty" || gone} gone={gone} />
        ))}
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the suggestion above the keys" zh="点击键盘上方的验证码建议" style={{ paddingBottom: 12 }} />
    </div>
  );
}

/** The verify wave: each box (and its digit) hops a moment after the one before it. */
function useHop(index: number, wave: number) {
  const t = useElapsed(wave, 0.7 + index * 0.05, true);
  return springTrack(t, 0, [
    { to: 0, duration: 0.01 + index * 0.05 },
    { to: -9, duration: 0.14, spring: SNAPPY },
    { to: 0, duration: 0.45, spring: BOUNCY },
  ]);
}

function Hop({ index, wave, at, children }: { index: number; wave: number; at: { x: number; y: number }; children: React.ReactNode }) {
  const lift = useHop(index, wave);
  return <div style={{ position: "absolute", left: at.x - 19, top: at.y - 24, transform: `translateY(${lift}px)` }}>{children}</div>;
}

function Box({ landed, verified, pop }: { landed: boolean; verified: boolean; pop: number }) {
  const t = useElapsed(pop, 0.45, true);
  const scale = springTrack(t, 1, [
    { to: 1.12, duration: 0.1, spring: SNAPPY },
    { to: 1, duration: 0.35, spring: BOUNCY },
  ]);
  const border = verified ? Palette.green : landed ? Palette.indigo : Palette.labelAlpha(0.14);
  return (
    <div
      style={{
        width: 38,
        height: 48,
        borderRadius: 12,
        background: Palette.elevated,
        boxShadow: `0 2px 6px ${black(0.06)}`,
        transform: `scale(${scale})`,
        position: "relative",
      }}
    >
      <div style={{ position: "absolute", inset: 0, borderRadius: 12, background: alpha(Palette.green, 0.12), opacity: verified ? 1 : 0, transition: "opacity 0.25s ease-out" }} />
      <div style={{ position: "absolute", inset: 0, borderRadius: 12, border: `${landed ? 1.8 : 1.2}px solid ${border}`, transition: "border-color 0.2s ease-out, border-width 0.2s ease-out" }} />
    </div>
  );
}

/** Flies a digit from the chip to its box along an arc, growing on the way. */
function FlyingDigit({
  index,
  digit,
  progress,
  lift,
  wave,
  verified,
  hidden,
  gone,
}: {
  index: number;
  digit: string;
  progress: MotionValue<number>;
  lift: number;
  wave: number;
  verified: boolean;
  hidden: boolean;
  gone: boolean;
}) {
  const p = useMV(progress);
  const hop = useHop(index, wave);
  const from = chipAt(index);
  const to = boxAt(index);
  const arc = Math.sin(Math.PI * clamp(p)) * lift;
  const x = from.x + (to.x - from.x) * p;
  const y = from.y + (to.y - from.y) * p - arc;
  const scale = 15 / 26 + (1 - 15 / 26) * p;
  return (
    <motion.div
      initial={false}
      animate={{ opacity: hidden ? 0 : 1, y: gone ? 16 : 0, filter: `blur(${gone ? 4 : 0}px)` }}
      transition={gone ? anim.easeIn(0.22) : { duration: 0 }}
      style={{ position: "absolute", left: 0, top: 0, pointerEvents: "none" }}
    >
      <div
        style={{
          position: "absolute",
          left: x - 15,
          top: y - 16,
          width: 30,
          height: 32,
          display: "grid",
          placeItems: "center",
          transform: `scale(${scale}) translateY(${hop}px)`,
          fontFamily: fonts.rounded,
          fontSize: 26,
          fontWeight: 600,
          fontVariantNumeric: "tabular-nums",
          lineHeight: "32px",
          color: verified ? Palette.green : Palette.label,
          transition: `color 0.2s ease-out ${index * 0.05}s`,
        }}
      >
        {digit}
      </div>
    </motion.div>
  );
}
