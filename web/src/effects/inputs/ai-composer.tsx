/** inputs.ai-composer (Inputs+AIComposer.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useLayoutEffect, useRef, useState } from "react";
import { ArrowUp, Mic, Plus, Sparkles, Square } from "lucide-react";
import { DemoHint, Palette, alpha, anim, forever, mix, spring, springAt, textStyle, useAutoplay, useClock, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { TextInputStyles } from "./_b-common";
import { GradientBorder, useLive, useTask } from "./_c-common";
import { SymbolBounce } from "../../kit";

type Phase = "idle" | "generating" | "done";
type Action = "mic" | "send" | "stop";
const WIDTH = 300;
const BORDER_COLORS = [Palette.indigo, Palette.pink, Palette.amber, Palette.mint, Palette.sky, Palette.indigo];

export default function AIComposer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [text, setText, textRef] = useLive("");
  const [sent, setSent] = useState<string | null>(null);
  const [phase, setPhase, phaseRef] = useLive<Phase>("idle");
  const [stopped, setStopped] = useState(false);
  const [micBounce, setMicBounce] = useState(0);
  const [focused, setFocused] = useState(false);
  const scriptTask = useTask();
  const scriptRunning = useRef(false);
  const replyTask = useTask();
  const fieldHeight = useMotionValue(52);
  const inner = useRef<HTMLDivElement>(null);
  const area = useRef<HTMLTextAreaElement>(null);
  const isStatic = ctx.isPreview;
  const sample = ctx.t(
    "Write a SwiftUI spring where a button sinks to 94% on press and overshoots a little on release",
    "帮我写一个 SwiftUI 弹簧动画：按钮按下时缩小到 94%，松手后带一点过冲回弹",
  );
  const action: Action = phase === "generating" ? "stop" : text === "" ? "mic" : "send";

  // Text lays out instantly; the field copies that natural height into a spring-animated frame.
  useLayoutEffect(() => {
    const el = area.current;
    if (el) {
      el.style.height = "0px";
      el.style.height = `${Math.min(el.scrollHeight, 21 * 4)}px`;
    }
    const height = inner.current?.offsetHeight ?? 52;
    if (Math.abs(height - fieldHeight.get()) > 0.5 || fieldHeight.isAnimating()) animate(fieldHeight, height, spring(ctx.n("grow"), 0.72));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [text]);

  const send = () => {
    const message = textRef.current.trim();
    if (!message || phaseRef.current === "generating") return;
    haptics.tap("medium");
    setStopped(false);
    setSent(message);
    setPhase("generating");
    setText("");
    const quiet = ctx.isPreview || scriptRunning.current;
    replyTask.start(async (sleep) => {
      if (!(await sleep(ctx.n("think")))) return;
      setPhase("done");
      if (!quiet) haptics.success();
    });
  };
  const stop = () => {
    if (phaseRef.current !== "generating") return;
    replyTask.cancel();
    haptics.tap("rigid");
    setStopped(true);
    setPhase("done");
  };
  const typeSample = async (sleep: (s: number) => Promise<boolean>) => {
    const chars = Array.from(sample);
    setText("");
    for (let index = 0; index < chars.length; index++) {
      if (!(await sleep(ctx.lang === "zh" ? 0.042 : 0.02))) return false;
      setText(chars.slice(0, index + 1).join(""));
    }
    return true;
  };
  /** The mic "dictates" the sample prompt, so the field can be tried without the keyboard. */
  const dictate = () => {
    if (scriptRunning.current) return;
    haptics.tap("light");
    setMicBounce((b) => b + 1);
    scriptRunning.current = true;
    scriptTask.start(async (sleep) => {
      if (!(await typeSample(sleep))) return;
      scriptRunning.current = false;
    });
  };
  /** Preview loop and detail intro: type, send, wait for the answer. */
  const runScript = () => {
    replyTask.cancel();
    scriptRunning.current = true;
    scriptTask.start(async (sleep) => {
      setSent(null);
      setPhase("idle");
      if (!(await sleep(0.5))) return;
      if (!(await typeSample(sleep))) return;
      if (!(await sleep(0.55))) return;
      send();
      scriptRunning.current = false;
    });
  };
  const stopScript = () => {
    scriptTask.cancel();
    scriptRunning.current = false;
    setText("");
  };
  useAutoplay(ctx.isPreview, runScript, { every: 7.4, delay: 0.4 });

  const kickT = useElapsed(action, 0.5, true);
  const kick = kickT < 0 ? 1 : kickT < 0.1 ? 1 + 0.18 * ((kickT / 0.1) ** 2 * (3 - (2 * kickT) / 0.1)) : mix(1.18, 1, springAt(kickT - 0.1, 0.4, 0.7));
  const energy = phase === "generating" ? 1 : text === "" && !focused ? 0.45 : 0.75;
  const answer = stopped
    ? ctx.t("Stopped.", "已停止生成。")
    : ctx.t(
        "Drive scaleEffect with .spring(response: 0.35, dampingFraction: 0.6): 0.94 while pressed, back to 1 on release.",
        "用 .spring(response: 0.35, dampingFraction: 0.6) 驱动 scaleEffect：按下时 0.94，松手回到 1。",
      );
  const placeholder = ctx.t("Ask anything", "问点什么");
  const layerT = spring(0.3, 0.7);
  const clamp3 = { display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical", overflow: "hidden" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }} onClick={() => area.current?.blur()}>
      <TextInputStyles />
      {/* Conversation */}
      <div style={{ position: "relative", flex: 1, minHeight: 0, width: WIDTH, marginTop: 18, marginBottom: 14 }}>
        <AnimatePresence initial={false}>
          {sent === null && (
            <motion.div
              key="greeting"
              initial={{ opacity: 0, scale: 0.92 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.92 }}
              transition={sent === null ? anim.smoothD(0.3) : spring(0.45, 0.74)}
              style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8 }}
            >
              <svg width={0} height={0} style={{ position: "absolute" }}>
                <defs>
                  <linearGradient id="c-ai-sparkle" x1="0" y1="0" x2="1" y2="1">
                    <stop offset="0" stopColor={Palette.indigo} />
                    <stop offset="0.5" stopColor={Palette.pink} />
                    <stop offset="1" stopColor={Palette.amber} />
                  </linearGradient>
                </defs>
              </svg>
              <Sparkles size={34} strokeWidth={1.6} stroke="url(#c-ai-sparkle)" fill="url(#c-ai-sparkle)" />
              <span style={{ ...textStyle.headline }}>{ctx.t("What shall we make today?", "今天想做点什么？")}</span>
            </motion.div>
          )}
        </AnimatePresence>
        <AnimatePresence initial={false}>
          {sent !== null && (
            <motion.div key="thread" exit={{ opacity: 0 }} transition={anim.smoothD(0.3)} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", justifyContent: "flex-end", gap: 12 }}>
              <motion.div
                initial={{ y: 70, scale: 0.7, opacity: 0 }}
                animate={{ y: 0, scale: 1, opacity: 1 }}
                transition={spring(0.45, 0.74)}
                style={{
                  alignSelf: "flex-end",
                  maxWidth: 236,
                  padding: "10px 14px",
                  borderRadius: 18,
                  background: `linear-gradient(135deg, ${Palette.indigo}, ${Palette.violet})`,
                  color: "#fff",
                  fontSize: 14,
                  fontWeight: 500,
                  lineHeight: "18px",
                  transformOrigin: "100% 100%",
                }}
              >
                <div style={clamp3}>{sent}</div>
              </motion.div>
              <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={spring(0.45, 0.74)} style={{ display: "flex", alignItems: "flex-start", gap: 10 }}>
                <div style={{ width: 28, height: 28, borderRadius: "50%", background: `linear-gradient(135deg, ${Palette.pink}, ${Palette.amber})`, color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>
                  <Sparkles size={15} strokeWidth={1.8} fill="currentColor" />
                </div>
                <div style={{ position: "relative", flex: 1, minHeight: 52, display: "grid" }}>
                  <AnimatePresence initial={false}>
                    {phase === "generating" ? (
                      <motion.div key="shimmer" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={anim.smoothD(0.45)} style={{ gridArea: "1 / 1" }}>
                        <Shimmer />
                      </motion.div>
                    ) : (
                      <motion.div
                        key={stopped ? "stopped" : "answer"}
                        initial={{ opacity: 0, filter: "blur(6px)", scale: 0.96 }}
                        animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                        exit={{ opacity: 0, filter: "blur(6px)", scale: 0.96 }}
                        transition={anim.easeInOut(stopped ? 0.35 : 0.45)}
                        style={{ gridArea: "1 / 1", fontSize: 14, lineHeight: "18px", color: stopped ? Palette.secondaryLabel : Palette.label, transformOrigin: "0 0" }}
                      >
                        <div style={clamp3}>{answer}</div>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </motion.div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
      {/* Composer */}
      <motion.div
        style={{ position: "relative", width: WIDTH, height: fieldHeight, flexShrink: 0, marginBottom: ctx.isPreview ? 22 : 10 }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, background: Palette.elevated }} />
        <Border turns={ctx.n("speed")} glow={ctx.n("glow") * energy} fast={phase === "generating"} preview={ctx.isPreview} />
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden" }}>
          <div ref={inner} style={{ position: "absolute", left: 0, right: 0, bottom: 0, padding: 8, display: "flex", alignItems: "flex-end", gap: 8 }}>
            <div style={{ width: 36, height: 36, borderRadius: "50%", background: Palette.labelAlpha(0.07), color: Palette.secondaryLabel, display: "grid", placeItems: "center", flexShrink: 0 }}>
              <Plus size={19} strokeWidth={2.4} />
            </div>
            <div style={{ flex: 1, minWidth: 0, padding: "8px 0", fontSize: 16, lineHeight: "21px", display: "flex" }} onClick={() => area.current?.focus()}>
              {isStatic ? (
                <div style={{ color: text === "" ? "rgb(var(--ml-label-rgb) / 0.42)" : Palette.label, display: "-webkit-box", WebkitLineClamp: 4, WebkitBoxOrient: "vertical", overflow: "hidden", wordBreak: "break-word" }}>
                  {text === "" ? placeholder : text}
                </div>
              ) : (
                <textarea
                  ref={area}
                  className="ml-b-input"
                  rows={1}
                  value={text}
                  placeholder={placeholder}
                  onChange={(e) => setText(e.target.value)}
                  onFocus={() => {
                    setFocused(true);
                    if (scriptRunning.current) stopScript();
                  }}
                  onBlur={() => setFocused(false)}
                  style={{ flex: 1, width: "100%", resize: "none", fontSize: 16, lineHeight: "21px", display: "block", color: "inherit", fontFamily: "inherit", scrollbarWidth: "none" }}
                />
              )}
            </div>
            <button
              type="button"
              onClick={() => (action === "mic" ? dictate() : action === "send" ? send() : stop())}
              style={{ position: "relative", width: 36, height: 36, flexShrink: 0, transform: `scale(${kick})`, borderRadius: "50%" }}
            >
              <AnimatePresence>
                {action === "stop" && (
                  <motion.div key="pulse" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={layerT} style={{ position: "absolute", inset: 0 }}>
                    <motion.div
                      initial={{ scale: 1, opacity: 0.8 }}
                      animate={{ scale: 1.4, opacity: 0 }}
                      transition={forever(anim.easeOut(1.1), false)}
                      style={{ position: "absolute", inset: 0 }}
                    >
                      <GradientBorder background={`linear-gradient(180deg, ${Palette.indigo}, ${Palette.pink})`} width={2} radius="50%" style={{ inset: -1 }} />
                    </motion.div>
                  </motion.div>
                )}
              </AnimatePresence>
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.labelAlpha(0.08) }} />
              <motion.div initial={false} animate={{ opacity: action === "send" ? 1 : 0 }} transition={layerT} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `linear-gradient(180deg, ${Palette.indigo}, ${Palette.violet})` }} />
              <motion.div initial={false} animate={{ opacity: action === "stop" ? 1 : 0 }} transition={layerT} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.label }} />
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: action === "mic" ? Palette.secondaryLabel : action === "stop" ? Palette.background : "#fff" }}>
                <SymbolBounce trigger={micBounce}>
                  <SymbolSwap k={action}>
                    {action === "mic" ? <Mic size={18} strokeWidth={2.4} /> : action === "send" ? <ArrowUp size={19} strokeWidth={3} /> : <Square size={11} strokeWidth={0} fill="currentColor" />}
                  </SymbolSwap>
                </SymbolBounce>
              </div>
            </button>
          </div>
        </div>
      </motion.div>
      <DemoHint ctx={ctx} en="Type, or tap the mic to dictate a sample, then send" zh="输入文字，或点麦克风口述一段示例，再发送" style={{ paddingBottom: 12 }} />
    </div>
  );
}

/** Rotating gradient stroke with a breathing glow underneath. */
function Border({ turns, glow, fast, preview }: { turns: number; glow: number; fast: boolean; preview: boolean }) {
  const t = useClock(true, preview ? 30 : undefined);
  // Phase bookkeeping, so changing the speed never makes the gradient jump.
  const book = useRef({ base: 0, since: 0, rate: turns * 360 * (fast ? 3 : 1) });
  const rate = turns * 360 * (fast ? 3 : 1);
  if (book.current.rate !== rate) {
    book.current.base += (t - book.current.since) * book.current.rate;
    book.current.since = t;
    book.current.rate = rate;
  }
  const angle = book.current.base + (t - book.current.since) * rate;
  const breath = 0.75 + 0.25 * Math.sin((t * 2 * Math.PI) / 3.5);
  const gradient = `conic-gradient(from ${90 + angle}deg, ${BORDER_COLORS.join(", ")})`;
  return (
    <>
      <GradientBorder background={gradient} width={6} radius={29} style={{ inset: -3, filter: "blur(9px)", opacity: glow * breath, transition: "opacity 0.3s" }} />
      <GradientBorder background={gradient} width={1.5} radius={26} style={{ opacity: 0.55 + 0.45 * Math.min(glow * 1.6, 1), zIndex: 1 }} />
    </>
  );
}

/** Three placeholder lines with a highlight sweeping across them. */
function Shimmer() {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8, paddingTop: 4 }}>
      {[220, 190, 110].map((width, index) => (
        <div key={index} style={{ position: "relative", width, height: 10, borderRadius: 5, background: Palette.labelAlpha(0.1), overflow: "hidden" }}>
          <motion.div
            initial={{ x: -190 }}
            animate={{ x: 190 }}
            transition={forever(anim.linear(1.1), false)}
            style={{
              position: "absolute",
              left: 110 - 60,
              top: 0,
              width: 120,
              height: 10,
              background: `linear-gradient(90deg, transparent, ${alpha(Palette.pink, 0.09)}, ${alpha(Palette.amber, 0.09)}, transparent)`,
            }}
          />
        </div>
      ))}
    </div>
  );
}
