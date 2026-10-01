/** feedback.typing-bubble · 输入气泡变形 (Feedback+TypingBubble.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { ArrowUp } from "lucide-react";
import { useLayoutEffect, useRef, useState } from "react";
import { DemoHint, Palette, black, delayed, fonts, hex, spring, useAutoplay, useClock, useElapsed, useHaptics, useTimeouts, type DemoProps, type Lang } from "../../kit";
import { SPRINGS, separator, track } from "./shared";

interface Message {
  id: number;
  outgoing: boolean;
  text: string;
  isTyping: boolean;
  /** Bubble size once it shows its text. */
  width: number;
  height: number;
  /** Part of the thread from the start: no insertion transition. */
  seeded?: boolean;
}

const SCRIPT: [en: string, zh: string, replyEn: string, replyZh: string][] = [
  ["Lunch today?", "中午一起吃饭？", "Yes! Ramen at 12:30?", "好呀！12:30 吃拉面？"],
  ["Perfect, I'll book", "好，我来订位", "You're the best. See you there", "你最好了，一会儿见"],
  ["Running 5 min late", "我晚到 5 分钟", "No rush, I just got us a table", "不急，我刚占到位置"],
];

const LAYOUT = spring(0.42, 0.8);
const TEXT = { fontSize: 15, lineHeight: "20px" } as const;
const TYPING_W = 62;
const TYPING_H = 38;
/** Thread width 300 − 2 × 12 padding, minus the row's `Spacer(minLength:)`, minus the bubble's padding. */
const OUT_TEXT_MAX = 300 - 24 - 70 - 26;
const IN_TEXT_MAX = 300 - 24 - 60 - 26;

export default function TypingBubble({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [messages, setMessages] = useState<Message[]>([]);
  const [layoutT, setLayoutT] = useState<Transition>(LAYOUT);
  const [morphT, setMorphT] = useState<Transition>(spring(0.42, 0.74));
  const [busy, setBusy] = useState(false);
  const [sends, setSends] = useState(0);
  const live = useRef({ busy: false, round: 0, nextID: 10 });
  const ruler = useRef<HTMLSpanElement>(null);

  /** The bubble a text needs: its (wrapped) text box plus 13 / 9 pt padding. */
  const measure = (text: string, outgoing: boolean) => {
    const node = ruler.current;
    if (!node) return { width: TYPING_W, height: TYPING_H };
    node.style.maxWidth = `${outgoing ? OUT_TEXT_MAX : IN_TEXT_MAX}px`;
    node.textContent = text;
    // A wrapped SwiftUI Text is as wide as its longest line, not the width it was offered.
    const range = document.createRange();
    range.selectNodeContents(node);
    const scale = node.offsetWidth > 0 ? node.getBoundingClientRect().width / node.offsetWidth : 1;
    const tight = scale > 0 ? range.getBoundingClientRect().width / scale : node.offsetWidth;
    return { width: Math.ceil(Math.min(tight, node.offsetWidth)) + 1 + 26, height: node.offsetHeight + 18 };
  };

  // Seed the thread once the ruler exists (the language at arrival, like the Swift `init`).
  const seedLang = useRef<Lang>(ctx.lang);
  useLayoutEffect(() => {
    const cn = seedLang.current === "zh";
    const first = cn ? "这周有空吗？" : "Free this week?";
    const second = cn ? "周四可以" : "Thursday works";
    setMessages([
      { id: 0, outgoing: false, text: first, isTyping: false, seeded: true, ...measure(first, false) },
      { id: 1, outgoing: true, text: second, isTyping: false, seeded: true, ...measure(second, true) },
    ]);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /** Keeps the last five bubbles; older ones fade out above the thread's top edge. */
  const trim = (list: Message[]) => (list.length > 5 ? list.slice(list.length - 5) : list);

  const send = (buzz = true) => {
    if (live.current.busy) return;
    live.current.busy = true;
    setBusy(true);
    clearAll();
    const pair = SCRIPT[live.current.round % SCRIPT.length];
    live.current.round += 1;
    const typing = ctx.n("typing");
    const morph = ctx.n("morph");
    const mine = zh ? pair[1] : pair[0];
    const reply = zh ? pair[3] : pair[2];
    if (buzz) haptics.tap();
    setSends((s) => s + 1);
    const id = live.current.nextID;
    const replyID = id + 1;
    live.current.nextID += 2;
    const mineSize = measure(mine, true);
    const replySize = measure(reply, false);
    setLayoutT(LAYOUT);
    setMessages((list) => trim([...list, { id, outgoing: true, text: mine, isTyping: false, ...mineSize }]));
    after(0.55, () => {
      // The row's height animates the thread up; the bubble's pieces spring in on their own.
      setLayoutT(LAYOUT);
      setMessages((list) => trim([...list, { id: replyID, outgoing: false, text: reply, isTyping: true, ...replySize }]));
      after(typing, () => {
        const t = spring(morph, 0.74);
        setLayoutT(t);
        setMorphT(t);
        setMessages((list) => list.map((m) => (m.id === replyID ? { ...m, isTyping: false } : m)));
        if (buzz) haptics.tap("soft");
        after(0.5, () => {
          live.current.busy = false;
          setBusy(false);
        });
      });
    });
  };

  useAutoplay(ctx.isPreview, () => send(false), { every: ctx.n("typing") + 2.8, delay: 0.4 });

  const e = useElapsed(sends, 1.2, true);
  const sendScale = e < 0 ? 1 : track(e, 1, [{ cubic: 0.8, d: 0.08 }, { spring: 1, d: 0.4, ...SPRINGS.bouncy }]);

  // Bottom-aligned stack: each row sits above the rows after it.
  const offsets: number[] = [];
  let below = 0;
  for (let index = messages.length - 1; index >= 0; index--) {
    offsets[index] = -below;
    below += (messages[index].isTyping ? TYPING_H : messages[index].height) + 7;
  }
  const grey = ctx.scheme === "dark" ? hex(0x2e2e33) : hex(0xe9e9eb);
  const rise = ctx.n("wave");
  const period = Math.max(ctx.n("period"), 0.2);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={() => send()}
        style={{
          position: "relative",
          width: 300,
          height: 300,
          flexShrink: 0,
          borderRadius: 26,
          overflow: "hidden",
          background: ctx.scheme === "dark" ? hex(0x0c0c0e) : "#fff",
          boxShadow: `0 10px 18px ${black(0.12)}`,
          display: "flex",
          flexDirection: "column",
          cursor: "pointer",
        }}
      >
        {/* Header */}
        <div style={{ height: 48, flexShrink: 0, padding: "0 14px", display: "flex", alignItems: "center", gap: 9, borderBottom: `0.5px solid ${separator(ctx.scheme)}` }}>
          <div style={{ width: 28, height: 28, borderRadius: 14, background: Palette.sunset, color: "#fff", display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 13, fontWeight: 700 }}>M</div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>Mia</span>
            <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel }}>{zh ? "在线" : "online"}</span>
          </div>
        </div>
        {/* Thread */}
        <div
          style={{
            position: "relative",
            width: 300,
            height: 204,
            flexShrink: 0,
            overflow: "hidden",
            WebkitMaskImage: "linear-gradient(transparent 0%, #000 12%)",
            maskImage: "linear-gradient(transparent 0%, #000 12%)",
          }}
        >
          <AnimatePresence initial={false}>
            {messages.map((message, index) => (
              <motion.div
                key={message.id}
                initial={message.seeded ? false : message.outgoing ? { y: offsets[index] + 26, scale: 0.6, opacity: 0 } : { y: offsets[index], scale: 1, opacity: 1 }}
                animate={{ y: offsets[index], scale: 1, opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={layoutT}
                style={{ position: "absolute", left: 12, right: 12, bottom: 14, display: "flex", justifyContent: message.outgoing ? "flex-end" : "flex-start", transformOrigin: "100% 100%" }}
              >
                {message.outgoing ? (
                  <div style={{ ...TEXT, width: message.width, height: message.height, padding: "9px 13px", borderRadius: 19, color: "#fff", background: `linear-gradient(${hex(0x3d95ff)}, ${hex(0x0a7aff)})` }}>{message.text}</div>
                ) : (
                  <IncomingBubble message={message} grey={grey} rise={rise} period={period} preview={ctx.isPreview} morphT={morphT} />
                )}
              </motion.div>
            ))}
          </AnimatePresence>
          <span ref={ruler} aria-hidden style={{ ...TEXT, position: "absolute", left: 0, top: 0, visibility: "hidden", pointerEvents: "none", display: "inline-block" }} />
        </div>
        {/* Composer */}
        <div style={{ height: 48, flexShrink: 0, padding: "0 12px", display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ flex: 1, height: 32, borderRadius: 16, padding: "0 14px", display: "flex", alignItems: "center", boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.14)}`, color: Palette.tertiaryLabel, ...TEXT }}>{zh ? "信息" : "Message"}</div>
          <div style={{ width: 30, height: 30, flexShrink: 0, display: "grid", placeItems: "center", opacity: busy ? 0.4 : 1, transform: `scale(${sendScale})` }}>
            <div style={{ width: 29, height: 29, borderRadius: "50%", background: hex(0x0a7aff), color: "#fff", display: "grid", placeItems: "center" }}>
              <ArrowUp size={18} strokeWidth={3} />
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Tap to send a message" zh="点击发送一条消息" />
    </div>
  );
}

/** The typing indicator and the reply are the same bubble: its frame springs from 62 × 38 to the text's size. */
function IncomingBubble({ message, grey, rise, period, preview, morphT }: { message: Message; grey: string; rise: number; period: number; preview: boolean; morphT: Transition }) {
  const typing = message.isTyping;
  // Bubbles that are already messages are complete from the start.
  const [complete] = useState(!typing);
  const piece = spring(0.38, 0.6);
  const width = typing ? TYPING_W : message.width;
  const height = typing ? TYPING_H : message.height;
  return (
    <div style={{ position: "relative" }}>
      {/* The thought-bubble tail: two circles that retract into the corner once the message arrives. */}
      <motion.div
        initial={{ scale: 0.01 }}
        animate={{ scale: typing ? 1 : 0.01 }}
        transition={typing ? delayed(piece, 0.07) : morphT}
        style={{ position: "absolute", left: -1, bottom: -2, width: 11, height: 11, borderRadius: "50%", background: grey }}
      />
      <motion.div
        initial={{ scale: 0.01 }}
        animate={{ scale: typing ? 1 : 0.01 }}
        transition={typing ? piece : morphT}
        style={{ position: "absolute", left: -6, bottom: -7, width: 6, height: 6, borderRadius: "50%", background: grey }}
      />
      <motion.div initial={complete ? false : { scale: 0.01 }} animate={{ scale: 1 }} transition={delayed(piece, 0.14)} style={{ transformOrigin: "0% 100%" }}>
        <motion.div initial={false} animate={{ width, height }} transition={morphT} style={{ position: "relative", width, height, borderRadius: 19, background: grey }}>
          <AnimatePresence initial={false}>
            {typing ? (
              <motion.div key="dots" exit={{ scale: 0.4, opacity: 0 }} transition={morphT} style={{ position: "absolute", left: 14, top: 10, width: 34, height: 18 }}>
                <TypingDots rise={rise} period={period} preview={preview} />
              </motion.div>
            ) : (
              <motion.div
                key="text"
                initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
                animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                transition={morphT}
                style={{ ...TEXT, position: "absolute", left: 13, top: 9, width: message.width - 26, color: Palette.label, transformOrigin: "0% 50%" }}
              >
                {message.text}
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </motion.div>
    </div>
  );
}

function TypingDots({ rise, period, preview }: { rise: number; period: number; preview: boolean }) {
  const t = useClock(true, preview ? 30 : undefined);
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 5, height: 18 }}>
      {[0, 1, 2].map((index) => {
        // A travelling wave: each dot is 0.15 of a cycle behind the previous one.
        const cycle = t / period - index * 0.15;
        const lift = Math.max(Math.sin(cycle * 2 * Math.PI), 0);
        return <div key={index} style={{ width: 8, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.32 + 0.4 * lift), transform: `translateY(${-rise * lift + rise * 0.3}px)` }} />;
      })}
    </div>
  );
}
