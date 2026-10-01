/** inputs.voice-field (Inputs+VoiceField.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useId, useLayoutEffect, useRef, useState } from "react";
import { Mic, Square } from "lucide-react";
import { DemoHint, Palette, alpha, anim, black, clamp, spring, useAutoplay, useClock, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { column, spacer, useLive, useQuiet, useTask } from "./_c-common";

type Phase = "idle" | "listening" | "result";
const PHRASES: { en: string[]; zh: string[] }[] = [
  { en: ["Remind", "me", "to", "water", "the", "plants", "at", "seven", "tomorrow", "morning"], zh: ["明天", "早上", "七点", "提醒我", "给", "阳台", "的", "植物", "浇水"] },
  { en: ["Play", "something", "calm", "for", "a", "rainy", "evening", "at", "home"], zh: ["放", "一点", "适合", "下雨", "的", "夜晚", "听的", "安静", "音乐"] },
  { en: ["Add", "oat", "milk", "and", "coffee", "beans", "to", "my", "shopping", "list"], zh: ["把", "燕麦奶", "和", "咖啡豆", "加到", "我的", "购物", "清单", "里"] },
];
const WAVE_W = 292 - 18 - 8 - 10 - 40;

export default function VoiceField({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  const [phase, setPhase, phaseRef] = useLive<Phase>("idle");
  const [phraseIndex, setPhraseIndex, phraseRef] = useLive(0);
  const [shown, setShown] = useState(0);
  const [startedAt, setStartedAt] = useState(-1e9);
  const [stoppedAt, setStoppedAt, stoppedRef] = useLive(-1e9);
  const task = useTask();
  const height = useMotionValue(56);
  const inner = useRef<HTMLDivElement>(null);
  const target = useRef(56);

  const wordsFor = (index: number) => PHRASES[index % PHRASES.length][ctx.lang];
  const words = wordsFor(phraseIndex);

  const finish = (silent: boolean) => {
    if (phaseRef.current !== "listening" || stoppedRef.current !== Infinity) return;
    setStoppedAt(performance.now() / 1000);
    setShown(0);
    task.start(async (sleep) => {
      // Let the bars collapse first.
      if (!(await sleep(0.25))) return;
      setPhase("result");
      const total = wordsFor(phraseRef.current).length;
      for (let index = 0; index < total; index++) {
        if (!(await sleep(ctx.n("stagger")))) return;
        setShown(index + 1);
      }
      if (!silent) haptics.success();
    });
  };
  const listen = (silent: boolean) => {
    haptics.tap("light");
    setStartedAt(performance.now() / 1000);
    setStoppedAt(Infinity);
    setPhase("listening");
    task.start(async (sleep) => {
      if (!(await sleep(ctx.n("listen")))) return;
      finish(silent);
    });
  };
  const micTapped = () => {
    const silent = quiet();
    if (phaseRef.current === "idle") listen(silent);
    else if (phaseRef.current === "listening") finish(silent);
    else {
      // Clear the last transcript, then listen for the next phrase.
      setShown(0);
      setPhraseIndex(phraseRef.current + 1);
      listen(silent);
    }
  };
  useAutoplay(ctx.isPreview, wrap(micTapped), { every: ctx.n("listen") + 2.6, delay: 0.5 });

  // The field's height follows its content on the phase spring.
  useLayoutEffect(() => {
    const el = inner.current;
    if (!el) return;
    const sync = () => {
      const h = el.offsetHeight;
      if (Math.abs(h - target.current) < 0.5) return;
      target.current = h;
      animate(height, h, spring(0.45, 0.8));
    };
    sync();
    const observer = new ResizeObserver(sync);
    observer.observe(el);
    return () => observer.disconnect();
  }, [height]);

  const listening = phase === "listening";
  const phaseT = spring(0.45, 0.8);

  return (
    <div style={column}>
      <div style={spacer} />
      <motion.div
        style={{
          position: "relative",
          width: 292,
          height,
          flexShrink: 0,
          borderRadius: 26,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${listening ? alpha(Palette.red, 0.45) : Palette.labelAlpha(0.1)}, 0 8px 21px ${black(0.1)}`,
          transition: "box-shadow 0.3s",
        }}
      >
        <div ref={inner} style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: "8px 8px 8px 18px", display: "flex", alignItems: "flex-end", gap: 10 }}>
          <div style={{ position: "relative", flex: 1, minWidth: 0, minHeight: 28, margin: "6px 0", display: "grid", alignItems: "center" }}>
            <motion.div
              initial={false}
              animate={{ opacity: phase === "idle" ? 1 : 0, filter: `blur(${phase === "idle" ? 0 : 6}px)` }}
              transition={phase === "idle" ? anim.easeOut(0.2) : phaseT}
              style={{ gridArea: "1 / 1", fontSize: 17, lineHeight: "22px", color: Palette.tertiaryLabel, whiteSpace: "nowrap" }}
            >
              {ctx.t("Ask anything", "有什么想问的")}
            </motion.div>
            <motion.div initial={false} animate={{ opacity: listening ? 1 : 0 }} transition={phaseT} style={{ gridArea: "1 / 1", height: 28 }}>
              <Wave bars={ctx.i("bars")} startedAt={startedAt} stoppedAt={stoppedAt} live={listening} ctx={ctx} />
            </motion.div>
            <AnimatePresence initial={false} mode="popLayout">
              {phase === "result" && (
                <motion.div
                  key={phraseIndex}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0, transition: anim.easeOut(0.2) }}
                  transition={phaseT}
                  style={{ gridArea: "1 / 1", display: "flex", flexWrap: "wrap", columnGap: ctx.lang === "zh" ? 0 : 5, rowGap: 5 }}
                >
                  {words.map((word, index) => {
                    const visible = index < shown;
                    return (
                      <motion.span
                        key={index}
                        initial={false}
                        animate={{ opacity: visible ? 1 : 0, y: visible ? 0 : 6, filter: `blur(${visible ? 0 : ctx.n("blur")}px)` }}
                        transition={{ ...spring(0.4, 0.75), filter: anim.easeOut(0.3) }}
                        style={{ fontSize: 17, lineHeight: "20px", whiteSpace: "nowrap" }}
                      >
                        {word}
                      </motion.span>
                    );
                  })}
                </motion.div>
              )}
            </AnimatePresence>
          </div>
          {/* mic */}
          <button type="button" onClick={micTapped} style={{ position: "relative", width: 40, height: 40, flexShrink: 0, borderRadius: "50%" }}>
            {listening && (
              <motion.div
                initial={{ scale: 1, opacity: 0.7 }}
                animate={{ scale: 1.55, opacity: 0 }}
                transition={{ ...anim.easeOut(0.9), repeat: Infinity, repeatType: "loop", repeatDelay: 0.01 }}
                style={{ position: "absolute", inset: -1, borderRadius: "50%", border: `2px solid ${Palette.red}` }}
              />
            )}
            <motion.div
              initial={false}
              animate={{ backgroundColor: listening ? Palette.red : "rgb(128 128 128 / 0.16)" }}
              transition={spring(0.35, 0.7)}
              style={{ position: "absolute", inset: 0, borderRadius: "50%" }}
            />
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: listening ? "#fff" : Palette.indigo }}>
              <SymbolSwap k={listening ? "stop" : "mic"}>{listening ? <Square size={13} strokeWidth={0} fill="currentColor" /> : <Mic size={19} strokeWidth={2.3} />}</SymbolSwap>
            </div>
          </button>
        </div>
      </motion.div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the mic and watch it listen" zh="点击麦克风，看它聆听" style={{ paddingBottom: 14 }} />
    </div>
  );
}

/** Scrolling bar waveform. Its envelope comes from the start/stop times, so it needs no state of its own. */
function Wave({ bars, startedAt, stoppedAt, live, ctx }: { bars: number; startedAt: number; stoppedAt: number; live: boolean; ctx: DemoContext }) {
  useClock(live, ctx.isPreview ? 30 : undefined);
  const id = `c-wave-${useId().replace(/:/g, "")}`;
  const now = performance.now() / 1000;
  const frozen = useRef(now);
  if (live) frozen.current = now;
  const time = frozen.current;
  const rise = clamp((time - startedAt) / 0.35);
  const fall = 1 - clamp((time - stoppedAt) / 0.25);
  const envelope = rise * rise * (3 - 2 * rise) * fall;
  const count = Math.max(bars, 2);
  const pitch = WAVE_W / count;
  const barWidth = Math.min(pitch * 0.5, 4);
  const H = 28;
  return (
    <svg width={WAVE_W} height={H} style={{ display: "block" }}>
      <defs>
        <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={WAVE_W} y2={0}>
          <stop offset="0" stopColor={Palette.indigo} />
          <stop offset="0.5" stopColor={Palette.violet} />
          <stop offset="1" stopColor={Palette.pink} />
        </linearGradient>
      </defs>
      {Array.from({ length: count }, (_, index) => {
        const phase = index * 0.55 + time * 7;
        const noise = Math.sin(phase) * 0.45 + Math.sin(phase * 0.43 + 1.7) * 0.35 + Math.sin(phase * 2.3 + 0.4) * 0.2;
        const swell = 0.55 + 0.45 * Math.sin(time * 2.1 + index * 0.12);
        const level = envelope * Math.min(0.14 + 1.25 * Math.abs(noise) * swell, 1);
        const h = 3 + level * (H - 3);
        return <rect key={index} x={index * pitch + (pitch - barWidth) / 2} y={(H - h) / 2} width={barWidth} height={h} rx={barWidth / 2} fill={`url(#${id})`} />;
      })}
    </svg>
  );
}
