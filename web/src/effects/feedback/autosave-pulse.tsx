/** feedback.autosave-pulse · 自动保存脉冲 (Feedback+AutosavePulse.swift) */
import { AnimatePresence, motion, useTransform } from "motion/react";
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, anim, delayed, demoCard, spring, useAutoplay, useClock, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { separator, useAnimated } from "./shared";

type Status = "edited" | "saving" | "saved";

const START_TOKENS = 15;
const ENGLISH = [
  "Ship ", "the ", "new ", "onboarding ", "on ", "Friday. ", "Keep ", "the ", "copy ", "short, ", "lead ", "with ",
  "the ", "demo, ", "and ", "let ", "the ", "motion ", "explain ", "what ", "words ", "would ", "only ", "slow ",
  "down. ", "Every ", "screen ", "earns ", "its ", "place.",
];
const CHINESE = [
  "周五", "上线", "新的", "引导", "流程。", "文案", "要短，", "先放", "演示，", "让", "动效", "去", "解释",
  "文字", "说不清", "的", "部分。", "每一屏", "都要", "有", "存在", "的", "理由，", "多余", "的", "就", "删掉。",
];
const RESIZE = spring(0.4, 0.8);
/** `.serif` design: New York for Latin text; Chinese falls back to the system sans, as on iOS. */
const SERIF = `ui-serif, "New York", Georgia, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", serif`;
const FOOTNOTE = { fontSize: 13, lineHeight: "18px", fontWeight: 600, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" } as const;

export default function AutosavePulse({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const words = zh ? CHINESE : ENGLISH;
  const [status, setStatus] = useState<Status>("saved");
  const [shownTokens, setShownTokens] = useState(START_TOKENS);
  const [version, setVersion] = useState(12);
  const wordCount = useRef(words.length);
  wordCount.current = words.length;

  const edit = (buzz = true) => {
    clearAll();
    const save = ctx.n("save");
    if (buzz) haptics.selection();
    setStatus("edited");
    // Three words per burst; wrap around when the paragraph is complete.
    const type = () => setShownTokens((n) => (n >= wordCount.current ? START_TOKENS : n + 1));
    type();
    after(0.13, type);
    after(0.26, type);
    after(0.39 + 0.5, () => {
      setStatus("saving");
      after(save, () => {
        setStatus("saved");
        setVersion((v) => v + 1);
        if (buzz) haptics.tap("light");
      });
    });
  };

  useAutoplay(ctx.isPreview, () => edit(false), { every: ctx.n("save") + 3.4, delay: 0.5 });

  // The caret stays lit while typing and blinks at rest.
  const [blink, setBlink] = useState(true);
  useEffect(() => {
    const id = window.setInterval(() => setBlink((b) => !b), 530);
    return () => window.clearInterval(id);
  }, []);
  const lit = status === "edited" || blink;

  const text = words.slice(0, Math.min(shownTokens, words.length)).join("");
  const count = 128 + shownTokens;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div onClick={() => edit()} style={{ ...demoCard(26), width: 300, height: 300, flexShrink: 0, display: "flex", flexDirection: "column", cursor: "pointer" }}>
        {/* Toolbar */}
        <div style={{ height: 58, flexShrink: 0, paddingLeft: 16, paddingRight: 12, display: "flex", alignItems: "center", gap: 8 }}>
          <DocIcon />
          <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{zh ? "发布笔记" : "Launch notes"}</span>
          <div style={{ flex: 1 }} />
          <Pill status={status} version={version} zh={zh} period={Math.max(ctx.n("period"), 0.2)} draw={ctx.n("draw")} preview={ctx.isPreview} />
        </div>
        <div style={{ height: 0.5, flexShrink: 0, background: separator(ctx.scheme) }} />
        {/* Editor */}
        <div style={{ flex: 1, minHeight: 0, padding: "16px 18px 0", fontFamily: SERIF, fontSize: 17, lineHeight: "25.5px", textAlign: "left", overflow: "hidden" }}>
          {text}
          <span style={{ color: lit ? Palette.indigo : "transparent", fontWeight: 300 }}>|</span>
        </div>
        {/* Footer */}
        <div style={{ height: 36, flexShrink: 0, padding: "0 18px", display: "flex", alignItems: "center", fontSize: 11, lineHeight: "13px", fontWeight: 500, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
          {zh ? (
            <span style={{ display: "inline-flex" }}>
              <NumericText value={count} />
              &nbsp;词
            </span>
          ) : (
            <span style={{ display: "inline-flex" }}>
              <NumericText value={count} />
              &nbsp;words
            </span>
          )}
          <div style={{ flex: 1 }} />
          <span>{zh ? "自动保存已开启" : "Autosave on"}</span>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap the page to type" zh="点击页面继续输入" />
    </div>
  );
}

// MARK: - Status pill

function Pill({ status, version, zh, period, draw, preview }: { status: Status; version: number; zh: boolean; period: number; draw: number; preview: boolean }) {
  // One clock for the pulse and the stepping dots; it only runs while saving.
  const t = useClock(status === "saving", preview ? 30 : undefined);
  const cycle = t / period;
  const phase = status === "saving" ? cycle - Math.floor(cycle) : 0;

  const content = (live: boolean): ReactNode =>
    status === "edited" ? (
      <span style={{ color: Palette.secondaryLabel }}>{zh ? "已编辑" : "Edited"}</span>
    ) : status === "saving" ? (
      <span style={{ display: "inline-flex", alignItems: "center", gap: 1, color: Palette.secondaryLabel }}>
        {zh ? "保存中" : "Saving"}
        <span style={{ display: "inline-flex", gap: 1.5, transform: "translateY(2.5px)" }}>
          {[0, 1, 2].map((index) => (
            <span key={index} style={{ width: 2.5, height: 2.5, borderRadius: "50%", background: "currentColor", opacity: index <= Math.floor(phase * 3) ? 1 : 0.25 }} />
          ))}
        </span>
      </span>
    ) : (
      <span style={{ display: "inline-flex", gap: 5 }}>
        <span style={{ color: Palette.label }}>{zh ? "已保存" : "Saved"}</span>
        <span style={{ display: "inline-flex", color: Palette.secondaryLabel }}>v{live ? <NumericText value={version} /> : version}</span>
      </span>
    );

  // The pill is sized by its content: measure the label and spring to it.
  const ruler = useRef<HTMLSpanElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  useLayoutEffect(() => {
    if (ruler.current) setWidth(ruler.current.offsetWidth + 1);
  }, [status, version, zh]);

  return (
    <div style={{ ...FOOTNOTE, height: 36, flexShrink: 0, paddingLeft: 9, paddingRight: 13, borderRadius: 18, background: Palette.labelAlpha(0.06), display: "flex", alignItems: "center", gap: 6 }}>
      <Glyph status={status} phase={phase} draw={draw} />
      <motion.div initial={false} animate={width === null ? undefined : { width }} transition={RESIZE} style={{ position: "relative", height: 18, width: width ?? undefined }}>
        <AnimatePresence initial={false}>
          <motion.div
            key={status}
            initial={{ opacity: 0, filter: "blur(5px)", scale: 0.9 }}
            animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
            exit={{ opacity: 0, filter: "blur(5px)", scale: 0.9 }}
            transition={RESIZE}
            style={{ position: "absolute", left: 0, top: 0, height: 18, display: "flex", alignItems: "center", transformOrigin: "0% 50%" }}
          >
            {content(true)}
          </motion.div>
        </AnimatePresence>
        <span ref={ruler} aria-hidden style={{ position: "absolute", left: 0, top: 0, visibility: "hidden", pointerEvents: "none", display: "inline-flex" }}>
          {content(false)}
        </span>
      </motion.div>
    </div>
  );
}

/** Dot → pulsing dot → a cloud outline that draws itself, then a check inside it. 27.5 × 20. */
function Glyph({ status, phase, draw }: { status: Status; phase: number; draw: number }) {
  const saved = status === "saved";
  const pulsing = status === "saving";
  // A glyph created in the saved state (arrival) is already drawn.
  const [cloud, cloudTo] = useAnimated(saved ? 1 : 0);
  const [check, checkTo] = useAnimated(saved ? 1 : 0);
  const previous = useRef(status);
  useEffect(() => {
    if (previous.current === status) return;
    previous.current = status;
    if (status === "saved") {
      cloudTo(1, anim.easeInOut(draw));
      checkTo(1, delayed(anim.easeOut(draw * 0.6), draw * 0.85));
    } else {
      cloudTo(0, anim.easeOut(0.12));
      checkTo(0, anim.easeOut(0.12));
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [status]);
  const cloudOffset = useTransform(cloud, (p) => 1 - Math.min(Math.max(p, 0), 1));
  const checkOffset = useTransform(check, (p) => 1 - Math.min(Math.max(p, 0), 1));
  // Round caps leave a dot at trim 0 in SVG; SwiftUI draws nothing there.
  const cloudOpacity = useTransform(cloud, (p) => (p > 0.001 ? 1 : 0));
  const checkOpacity = useTransform(check, (p) => (p > 0.001 ? 1 : 0));

  const colour = pulsing ? Palette.indigo : Palette.amber;
  const eased = 1 - (1 - phase) ** 2;
  return (
    <div style={{ position: "relative", width: 27.5, height: 20, flexShrink: 0 }}>
      <motion.div initial={false} animate={{ scale: saved ? 0.2 : 1, opacity: saved ? 0 : 1 }} transition={RESIZE} style={{ position: "absolute", left: 8.75, top: 5, width: 10, height: 10 }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", border: `1.5px solid ${colour}`, transform: `scale(${1 + 1.6 * eased})`, opacity: pulsing ? 0.7 * (1 - phase) : 0 }} />
        {/* Dips to 80% at the start of each pulse and recovers. */}
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: colour, transition: "background-color 0.25s ease-out", transform: `scale(${pulsing ? 0.8 + 0.2 * Math.min(phase * 2.5, 1) : 1})` }} />
      </motion.div>
      <motion.svg width={27.5} height={20} viewBox="0 0 22 16" fill="none" strokeLinecap="round" strokeLinejoin="round" initial={false} animate={{ opacity: saved ? 1 : 0 }} transition={RESIZE} style={{ position: "absolute", left: 0, top: 0, overflow: "visible" }}>
        {/* Left lobe, crown, right lobe, base: one continuous path so it can be drawn. */}
        <motion.path
          d="M5 14.2 A4 4 0 0 1 4.58 6.22 A5.5 5.5 0 0 1 15.19 5.39 A4.5 4.5 0 1 1 16.5 14.2 Z"
          pathLength={1}
          stroke={Palette.labelAlpha(0.75)}
          strokeWidth={1.9 / 1.25}
          strokeDasharray="1 1"
          style={{ strokeDashoffset: cloudOffset, opacity: cloudOpacity }}
        />
        <motion.path d="M7.6 9.9 L10 12.1 L14.2 7.3" pathLength={1} stroke={Palette.green} strokeWidth={2.2 / 1.25} strokeDasharray="1 1" style={{ strokeDashoffset: checkOffset, opacity: checkOpacity }} />
      </motion.svg>
    </div>
  );
}

/** `doc.text.fill` at 13 pt: a filled page with a folded corner and two text lines knocked out. */
function DocIcon() {
  return (
    <svg width={11.5} height={14.5} viewBox="0 0 23 29" style={{ flexShrink: 0 }}>
      <path
        fillRule="evenodd"
        fill={Palette.indigo}
        d="M5 0 H12.5 V7.5 A3 3 0 0 0 15.5 10.5 H23 V24 A5 5 0 0 1 18 29 H5 A5 5 0 0 1 0 24 V5 A5 5 0 0 1 5 0 Z M15 0.6 L22.4 8 H16.5 A1.5 1.5 0 0 1 15 6.5 Z M5.5 15 H17.5 A1.1 1.1 0 0 1 17.5 17.2 H5.5 A1.1 1.1 0 0 1 5.5 15 Z M5.5 20.5 H17.5 A1.1 1.1 0 0 1 17.5 22.7 H5.5 A1.1 1.1 0 0 1 5.5 20.5 Z"
      />
    </svg>
  );
}
