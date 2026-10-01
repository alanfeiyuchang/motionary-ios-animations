/** text.block-reveal · 色块擦拭揭示 (Text+BlockReveal.swift) */
import { animate, useMotionValue } from "motion/react";
import { useEffect, useRef, useState, type CSSProperties } from "react";
import { DemoHint, Palette, anim, delayed, fonts, useAutoplay, useHaptics, useLatest, type DemoProps } from "../../kit";
import { useMV } from "./_fx";

const ACCENTS = [Palette.coral, Palette.indigo, Palette.pink, Palette.mint];
const SETS = {
  zh: [
    ["第 05 期 · 动效", "让每一行", "都有自己的", "出场方式。"],
    ["第 06 期 · 节奏", "先遮住，", "再揭开，", "才有期待。"],
  ],
  en: [
    ["ISSUE 05 · MOTION", "Every line", "earns its", "entrance."],
    ["ISSUE 06 · RHYTHM", "Cover it,", "then let", "it show."],
  ],
};

const easeQuart = (x: number) => {
  const u = Math.min(Math.max(x, 0), 1);
  return u < 0.5 ? 8 * u * u * u * u : 1 - Math.pow(-2 * u + 2, 4) / 2;
};
/** Block width (0…1) and whether it is still growing at wipe position `a` (0…1). */
const cover = (a: number) => (a < 0.5 ? { scale: easeQuart(a * 2), growing: true } : { scale: 1 - easeQuart((a - 0.5) * 2), growing: false });

export default function BlockReveal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** Odd = revealed, even = hidden. Only ever increases, so replays never run backwards. */
  const [phase, setPhase] = useState(0);
  const phaseRef = useRef(0);
  const [copy, setCopy] = useState(0);
  const busy = useRef(false);
  const timers = useRef<number[]>([]);
  const duration = ctx.n("duration");
  const stagger = ctx.n("stagger");
  const live = useLatest({ duration, stagger });
  const texts = SETS[ctx.lang][copy % 2];

  const bump = () => {
    phaseRef.current += 1;
    setPhase(phaseRef.current);
  };
  useEffect(() => {
    if (phaseRef.current === 0) bump();
    return () => timers.current.forEach((t) => window.clearTimeout(t));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /** Wipes the current headline away, swaps the copy while everything is hidden, then reveals it. */
  const advance = () => {
    if (busy.current) return;
    if (phaseRef.current % 2 !== 1) return bump();
    busy.current = true;
    bump();
    const wait = live.current.duration + live.current.stagger * (texts.length - 1) + 0.06;
    timers.current.forEach((t) => window.clearTimeout(t));
    timers.current = [
      // Swap the copy in its own update, so the phase animation never cross-fades text or colours.
      window.setTimeout(() => setCopy((c) => c + 1), wait * 1000),
      window.setTimeout(() => {
        bump();
        busy.current = false;
      }, (wait + 0.04) * 1000),
    ];
  };
  useAutoplay(ctx.isPreview, advance, { every: duration * 2 + 2.6, delay: 2.4, intro: false });

  const direction = ctx.i("direction");
  const zh = ctx.lang === "zh";
  return (
    <div
      onClick={() => {
        haptics.tap("light");
        advance();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
    >
      <div style={{ width: 300, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 4 }}>
        {texts.map((text, index) => (
          <Line
            key={index}
            phase={phase}
            duration={duration}
            delay={index * stagger}
            text={text}
            style={
              index === 0
                ? { fontFamily: fonts.rounded, fontSize: 13, lineHeight: "16px", fontWeight: 800, letterSpacing: 1.6, marginBottom: 8 }
                : { fontSize: zh ? 42 : 44, lineHeight: `${zh ? 50 : 53}px`, fontWeight: 900, letterSpacing: -0.5 }
            }
            block={ACCENTS[(index + copy) % ACCENTS.length]}
            echo={ctx.b("echo")}
            reversed={direction === 1 ? true : direction === 2 ? index % 2 === 1 : false}
          />
        ))}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Tap to wipe to the next headline" zh="点击切换到下一组标题" />
      </div>
    </div>
  );
}

function Line({ phase, duration, delay, text, style, block, echo, reversed }: { phase: number; duration: number; delay: number; text: string; style: CSSProperties; block: string; echo: boolean; reversed: boolean }) {
  const progressMV = useMotionValue(0);
  const timing = useLatest({ duration, delay });
  useEffect(() => {
    const controls = animate(progressMV, phase, delayed(anim.linear(timing.current.duration), timing.current.delay));
    return () => controls.stop();
  }, [phase, progressMV, timing]);
  const progress = useMV(progressMV);

  // Position inside the current two-step cycle: 0…1 reveals, 1…2 wipes the text away again.
  const cycle = progress % 2;
  const exiting = cycle > 1;
  const a = exiting ? cycle - 1 : cycle;
  const main = cover(a);
  const lag = cover(a - 0.035 * Math.sin(Math.PI * a));
  const textVisible = exiting ? a < 0.5 : a >= 0.5;
  const settle = exiting ? 0 : 1 - easeQuart((a - 0.5) * 2);
  // The text settles from the side the block retracts to, so it never shows outside the block.
  const side = reversed ? -1 : 1;
  const origin = (growing: boolean) => (growing !== reversed ? "left" : "right");
  return (
    <div style={{ position: "relative", whiteSpace: "pre", color: Palette.label, ...style }}>
      <span style={{ display: "inline-block", opacity: textVisible ? 1 : 0, transform: `translateX(${side * 6 * settle}px)` }}>{text}</span>
      {echo && <div style={{ position: "absolute", left: -6, right: -6, top: 0, bottom: 0, background: Palette.label, transform: `scaleX(${lag.scale})`, transformOrigin: origin(lag.growing) }} />}
      <div style={{ position: "absolute", left: -6, right: -6, top: 0, bottom: 0, background: block, transform: `scaleX(${main.scale})`, transformOrigin: origin(main.growing) }} />
    </div>
  );
}
