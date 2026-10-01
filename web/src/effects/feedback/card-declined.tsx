/** feedback.card-declined · 刷卡被拒 (Feedback+CardDeclined.swift) */
import { AnimatePresence, motion, useTransform } from "motion/react";
import { ArrowUp } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, ease, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track, useAnimated, type Keyframe } from "./shared";

type Phase = "idle" | "reading" | "declined";

const RED = hex(0xff453a);
const SCREEN_BLUE = hex(0x7fd4ff);
const CIRCLE = 2 * Math.PI * 9;
const CROSS = 7 * Math.SQRT2;

export default function CardDeclined({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [phase, setPhaseState] = useState<Phase>("idle");
  const phaseRef = useRef<Phase>("idle");
  const setPhase = (p: Phase) => {
    phaseRef.current = p;
    setPhaseState(p);
  };
  /** The animation the last phase change ran in (glow, red screen). */
  const [phaseAnim, setPhaseAnim] = useState(anim.easeOut(0.2));
  const [leds, setLeds] = useState(0);
  const [rejections, setRejections] = useState(0);
  const [seats, setSeats] = useState(0);
  const [cardY, cardYTo] = useAnimated(0);
  const [rejected, rejectedTo] = useAnimated(0);
  const [label, labelTo] = useAnimated(0);

  const amplitude = ctx.n("shake");
  const tilt = ctx.n("tilt");

  const reset = (t: ReturnType<typeof spring>) => {
    setPhaseAnim(t);
    setPhase("idle");
    setLeds(0);
    cardYTo(0, t);
    rejectedTo(0, t);
    labelTo(0, t);
  };

  const play = (buzz = true) => {
    if (phaseRef.current === "reading") return;
    clearAll();
    const reading = ctx.n("reading");
    const eject = ctx.n("eject");
    const preview = ctx.isPreview;
    if (buzz) haptics.tap();
    const insert = () => {
      setPhaseAnim(anim.easeOut(0.2));
      setPhase("reading");
      cardYTo(-58, spring(0.45, 0.86));
      after(0.26, () => {
        setSeats((s) => s + 1);
        if (buzz) haptics.tap("rigid");
        for (let index = 1; index <= 4; index++) after((reading / 4) * index, () => setLeds(index));
        after(reading + 0.12, () => {
          setPhaseAnim(anim.easeOut(0.12));
          setPhase("declined");
          const out = spring(0.38, eject);
          cardYTo(8, out);
          rejectedTo(1, out);
          setRejections((r) => r + 1);
          if (buzz) haptics.error();
          after(0.3, () => {
            labelTo(1, anim.easeOut(0.35));
            if (!preview) return;
            after(2.2, () => reset(spring(0.4, 0.8)));
          });
        });
      });
    };
    if (phaseRef.current === "declined") {
      // Try again: straighten the card and clear the error first.
      reset(spring(0.35, 0.8));
      after(0.35, insert);
    } else insert();
  };

  useAutoplay(ctx.isPreview, () => play(false), { every: ctx.n("reading") + 4.2, delay: 0.5 });

  // keyframeAnimators keyed on the rejection / seat counters.
  const r = useElapsed(rejections, 1.3, true);
  const s = useElapsed(seats, 1.2, true);
  const cardShake: Keyframe[] = [
    { cubic: -amplitude, d: 0.06 },
    { cubic: amplitude * 0.8, d: 0.09 },
    { cubic: -amplitude * 0.55, d: 0.09 },
    { cubic: amplitude * 0.3, d: 0.08 },
    { cubic: -amplitude * 0.12, d: 0.08 },
    { spring: 0, d: 0.25, ...SPRINGS.snappy },
  ];
  const readerShake: Keyframe[] = [
    { linear: 0, d: 0.03 },
    { cubic: amplitude * 0.3, d: 0.07 },
    { cubic: -amplitude * 0.22, d: 0.09 },
    { cubic: amplitude * 0.12, d: 0.09 },
    { spring: 0, d: 0.3, ...SPRINGS.snappy },
  ];
  const cardX = r < 0 ? 0 : track(r, 0, cardShake);
  const readerX = r < 0 ? 0 : track(r, 0, readerShake);
  const readerY = s < 0 ? 0 : track(s, 0, [{ cubic: -3, d: 0.08 }, { spring: 0, d: 0.35, ...SPRINGS.bouncy }]);
  const flash = r < 0 ? 0 : 0.75 * (1 - ease.out(Math.min(r / 0.6, 1)));
  const wash = r < 0 ? 0 : 0.6 * (1 - ease.out(Math.min(r / 0.5, 1)));

  const declined = phase === "declined";
  const ringOffset = useTransform(label, (p) => CIRCLE * (1 - Math.min(Math.max(p, 0), 1)));
  // One trimmed path with two strokes: the second starts when the first is done.
  const crossA = useTransform(label, (p) => CROSS * (1 - Math.min(Math.max(p * 2, 0), 1)));
  const crossB = useTransform(label, (p) => CROSS * (1 - Math.min(Math.max(p * 2 - 1, 0), 1)));
  const crossBOpacity = useTransform(label, (p) => (p > 0.5 ? 1 : 0));
  const labelOpacity = useTransform(label, (p) => Math.min(Math.max(p, 0), 1));
  const labelClip = useTransform(label, (p) => `inset(0 ${100 * (1 - Math.min(Math.max(p, 0), 1))}% 0 0)`);
  const ledColour = declined ? RED : Palette.green;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div onClick={() => play()} style={{ width: 300, height: 302, flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", cursor: "pointer" }}>
        <div style={{ position: "relative", width: 300, height: 268, flexShrink: 0 }}>
          {/* Card: behind the reader, so sliding up hides it in the slot. */}
          <div style={{ position: "absolute", left: 102, top: 124, width: 96, height: 132, transform: `translateX(${cardX}px)` }}>
            <motion.div style={{ position: "absolute", inset: 0, ["--y" as string]: cardY, ["--r" as string]: rejected, transform: `translateY(calc(var(--y) * 1px)) rotate(calc(var(--r) * ${-tilt}deg))`, transformOrigin: "50% 0%", borderRadius: 12, boxShadow: `0 6px 10px ${black(0.22)}` }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: 12, overflow: "hidden", background: `linear-gradient(to bottom right, ${white(0.28)}, ${white(0)} 50%), linear-gradient(to bottom right, ${hex(0x5b6cff)}, ${hex(0x9a4dff)})` }}>
                <div style={{ position: "absolute", left: 35, top: 20, width: 26, height: 20, borderRadius: 4, background: `linear-gradient(${hex(0xffe39a)}, ${hex(0xd9a441)})` }} />
                <div style={{ position: "absolute", left: 0, right: 0, bottom: 14, display: "flex", flexDirection: "column", alignItems: "center", gap: 3, color: "#fff", fontFamily: fonts.mono, fontWeight: 600, whiteSpace: "nowrap" }}>
                  <span style={{ fontSize: 11, lineHeight: "13px" }}>•••• 4821</span>
                  <span style={{ fontSize: 7, lineHeight: "8.5px", opacity: 0.7 }}>VALID 09/29</span>
                </div>
                <div style={{ position: "absolute", inset: 0, background: RED, opacity: wash }} />
              </div>
            </motion.div>
          </div>
          {/* Reader */}
          <div style={{ position: "absolute", left: 70, top: 0, width: 160, height: 116, transform: `translate(${readerX}px, ${readerY}px)` }}>
            <motion.div
              initial={false}
              animate={{ opacity: declined ? 0.3 : 0, scale: declined ? 1.08 : 0.9 }}
              transition={phaseAnim}
              style={{ position: "absolute", inset: 0, borderRadius: 26, background: RED, filter: "blur(30px)" }}
            />
            <div style={{ position: "absolute", inset: 0, borderRadius: 26, background: RED, filter: "blur(26px)", opacity: flash }} />
            <div style={{ position: "absolute", inset: 0, borderRadius: 26, background: `linear-gradient(${hex(0x3a3a42)}, ${hex(0x1a1a1f)})`, boxShadow: `0 8px 14px ${black(0.28)}` }} />
            {/* strokeBorder with a top → bottom gradient */}
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: 26,
                padding: 1,
                background: `linear-gradient(${white(0.22)}, ${white(0.04)})`,
                WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                WebkitMaskComposite: "xor",
                maskComposite: "exclude",
              }}
            />
            <div style={{ position: "absolute", inset: 0, paddingTop: 2, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
              {/* Screen */}
              <div style={{ position: "relative", width: 128, height: 50, flexShrink: 0, borderRadius: 11, background: hex(0x0a0f1a), overflow: "hidden", fontFamily: fonts.mono, fontSize: 13, lineHeight: "16px", fontWeight: 700 }}>
                <motion.div initial={false} animate={{ opacity: declined ? 0.9 : 0 }} transition={phaseAnim} style={{ position: "absolute", inset: 0, background: RED }} />
                <AnimatePresence initial={false}>
                  {phase === "idle" && (
                    <motion.div key="idle" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseAnim} style={{ ...screenLine, color: SCREEN_BLUE }}>
                      <ArrowUp size={14} strokeWidth={3} />
                      {zh ? "请插卡" : "Insert card"}
                    </motion.div>
                  )}
                  {phase === "reading" && (
                    <motion.div key="reading" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseAnim} style={{ ...screenLine, color: SCREEN_BLUE }}>
                      {zh ? "读取中" : "Reading"}
                    </motion.div>
                  )}
                  {phase === "declined" && (
                    <motion.div key="declined" initial={{ opacity: 0, scale: 1.25 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 1.25 }} transition={phaseAnim} style={{ ...screenLine, color: "#fff" }}>
                      {zh ? "交易被拒" : "DECLINED"}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
              {/* LEDs */}
              <div style={{ display: "flex", gap: 9, flexShrink: 0 }}>
                {[0, 1, 2, 3].map((index) => {
                  const on = index < leds;
                  return (
                    <div
                      key={index}
                      style={{
                        width: 6,
                        height: 6,
                        borderRadius: 3,
                        background: on ? ledColour : white(0.12),
                        boxShadow: on ? `0 0 4px ${declined ? hex(0xff453a, 0.9) : hex(0x34c77b, 0.9)}` : "0 0 4px transparent",
                        transition: "background 0.12s ease-out, box-shadow 0.12s ease-out",
                      }}
                    />
                  );
                })}
              </div>
              {/* The slot the card dips into. */}
              <div style={{ width: 108, height: 7, flexShrink: 0, borderRadius: 3.5, background: black(0.75), boxShadow: `inset 0 0 0 0.5px ${white(0.08)}` }} />
            </div>
          </div>
        </div>
        {/* Error label */}
        <div style={{ height: 26, marginTop: 6, flexShrink: 0, display: "flex", alignItems: "center", gap: 7 }}>
          <motion.svg width={20} height={20} viewBox="0 0 20 20" style={{ opacity: labelOpacity, overflow: "visible", flexShrink: 0 }} fill="none" stroke={RED} strokeLinecap="round">
            <motion.circle cx={10} cy={10} r={9} strokeWidth={2} strokeDasharray={CIRCLE} style={{ strokeDashoffset: ringOffset }} transform="rotate(-90 10 10)" />
            <motion.path d="M6.5 6.5 L13.5 13.5" strokeWidth={2.2} strokeDasharray={CROSS} style={{ strokeDashoffset: crossA }} />
            <motion.path d="M13.5 6.5 L6.5 13.5" strokeWidth={2.2} strokeDasharray={CROSS} style={{ strokeDashoffset: crossB, opacity: crossBOpacity }} />
          </motion.svg>
          <motion.span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, color: RED, whiteSpace: "nowrap", opacity: labelOpacity, clipPath: labelClip }}>
            {zh ? "刷卡被拒 · 余额不足" : "Card declined · Insufficient funds"}
          </motion.span>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to pay again" zh="点击再次刷卡" />
    </div>
  );
}

const screenLine = {
  position: "absolute",
  inset: 0,
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  gap: 6,
  whiteSpace: "nowrap",
} as const;
