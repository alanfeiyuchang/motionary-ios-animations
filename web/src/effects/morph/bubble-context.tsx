/** morph.bubble-context · 气泡长按菜单 (Morph+BubbleContext.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Copy, Heart, Mic, Plus, Reply, Smile, ThumbsDown, ThumbsUp, Trash2 } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, black, delayed, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { Column, diag, morphScreen } from "./_shared";

interface Message {
  text: [string, string];
  mine: boolean;
  w: number;
  h: number;
  top: number;
}
const W = 316;
const H = 306;
const BAR = { w: 236, h: 44 };
const MENU = { w: 172, h: 114 };
const GAP = 8;
const messages: Message[] = [
  { text: ["Did you see the venue photos?", "场地的照片你看了吗？"], mine: false, w: 214, h: 36, top: 14 },
  { text: ["Yes! The rooftop is perfect", "看了！那个露台太合适了"], mine: true, w: 200, h: 36, top: 58 },
  { text: ["Let's book it for the 14th before someone else does", "那就订 14 号吧，别被别人抢先了"], mine: false, w: 218, h: 54, top: 102 },
  { text: ["Booking now", "我这就订"], mine: true, w: 112, h: 36, top: 164 },
  { text: ["You're the best", "你最靠谱了"], mine: false, w: 128, h: 36, top: 208 },
];
const leftOf = (m: Message) => (m.mine ? W - 12 - m.w : 12);
const mark = (s: string) => (p: { size: number }) => <span style={{ fontSize: p.size * 1.05, fontWeight: 800, lineHeight: 1, letterSpacing: -1 }}>{s}</span>;
const glyphs: { render: (p: { size: number }) => ReactNode; color: string }[] = [
  { render: (p) => <Heart size={p.size} fill="currentColor" strokeWidth={0} />, color: Palette.pink },
  { render: (p) => <ThumbsUp size={p.size} fill="currentColor" strokeWidth={1.5} />, color: Palette.blue },
  { render: (p) => <ThumbsDown size={p.size} fill="currentColor" strokeWidth={1.5} />, color: Palette.indigo },
  { render: (p) => <Smile size={p.size} strokeWidth={2.4} />, color: Palette.amber },
  { render: mark("!!"), color: Palette.coral },
  { render: mark("?"), color: Palette.violet },
];
const primaryStrong = diag("#4B57E0", "#7A45D6");

export default function BubbleContext({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [selected, setSelected] = useState(2);
  const [lifted, setLifted] = useState(false);
  const [pressed, setPressed] = useState<number | null>(null);
  const [chosen, setChosen] = useState<number | null>(null);
  const [reactions, setReactions] = useState<Record<number, number>>({});
  const autoStep = useRef(0);
  const hold = useRef<(() => void) | null>(null);
  const zh = ctx.lang === "zh";
  const L = zh ? 1 : 0;
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");
  const pressSpring = spring(0.28, 0.7);

  const lift = (index: number) => {
    if (lifted) return;
    clearAll();
    haptics.tap("medium");
    setSelected(index);
    setChosen(null);
    setLifted(true);
    setPressed(null);
  };
  const liftRef = useRef(lift);
  liftRef.current = lift;
  const dismiss = () => {
    if (!lifted) return;
    clearAll();
    setLifted(false);
  };
  const react = (glyph: number) => {
    if (!lifted || chosen !== null) return;
    haptics.tap("rigid");
    const index = selected;
    setChosen(glyph);
    after(0.26, () => {
      setLifted(false);
      after(0.14, () =>
        setReactions((r) => {
          const next = { ...r };
          if (next[index] === glyph) delete next[index];
          else next[index] = glyph;
          return next;
        }),
      );
    });
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const step = autoStep.current;
      const even = Math.floor(step / 4) % 2 === 0;
      if (step % 4 === 0) lift(2);
      else if (step % 4 === 1) react(even ? 0 : 3);
      else if (step % 4 === 2) lift(1);
      else react(even ? 1 : 4);
      autoStep.current += 1;
    },
    { every: 1.35 },
  );

  // `onLongPressGesture(minimumDuration: 0.3, maximumDistance: 24)`. The overlay copy slides under the finger as
  // soon as the press begins, so the rest of the gesture is tracked on the window rather than on the bubble.
  const cancelHold = () => {
    hold.current?.();
    hold.current = null;
  };
  useEffect(() => cancelHold, []);
  const holdProps = (index: number) => ({
    onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
      if (lifted) return;
      cancelHold();
      const el = e.currentTarget;
      const scale = el.getBoundingClientRect().width / el.offsetWidth || 1;
      const x = e.clientX;
      const y = e.clientY;
      // The overlay copy takes over the pressed bubble before it moves, with no animation.
      setSelected(index);
      setPressed(index);
      const timer = window.setTimeout(() => {
        cancelHold();
        liftRef.current(index);
      }, 300);
      const move = (ev: PointerEvent) => {
        if (Math.hypot(ev.clientX - x, ev.clientY - y) > 24 * scale) end();
      };
      const end = () => {
        cancelHold();
        setPressed(null);
      };
      window.addEventListener("pointermove", move);
      window.addEventListener("pointerup", end);
      window.addEventListener("pointercancel", end);
      hold.current = () => {
        window.clearTimeout(timer);
        window.removeEventListener("pointermove", move);
        window.removeEventListener("pointerup", end);
        window.removeEventListener("pointercancel", end);
      };
    },
  });

  const message = messages[selected];
  const lowest = H - 10 - MENU.h - GAP - message.h;
  const highest = BAR.h + GAP + 8;
  const top = Math.min(Math.max(message.top, highest), lowest);
  const shift = lifted ? top - message.top : 0;
  const barLeft = message.mine ? W - 30 - BAR.w : 12;
  const menuLeft = message.mine ? W - 12 - MENU.w : 12;
  const menuRows: [string, string, ReactNode][] = [
    ["Reply", "回复", <Reply key="r" size={16} strokeWidth={2} />],
    ["Copy", "拷贝", <Copy key="c" size={15} strokeWidth={2} />],
    ["Delete", "删除", <Trash2 key="d" size={15} strokeWidth={2} />],
  ];

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        {/* Everything that can blur: the bubbles (minus the selected one) and the composer. */}
        <motion.div initial={false} animate={{ scale: lifted ? 0.97 : 1, filter: `blur(${lifted ? ctx.n("blur") : 0}px)` }} transition={spr} style={{ position: "absolute", inset: 0 }}>
          {messages.map((m, index) => (
            <motion.div
              key={index}
              initial={false}
              animate={{ scale: pressed === index && index !== selected ? 0.96 : 1 }}
              transition={pressSpring}
              {...holdProps(index)}
              style={{ position: "absolute", left: leftOf(m), top: m.top, opacity: index === selected ? 0.001 : 1, cursor: "pointer" }}
            >
              <Bubble message={m} reaction={reactions[index]} L={L} />
            </motion.div>
          ))}
          <div style={{ position: "absolute", left: 12, right: 12, top: H - 28 - 17, display: "flex", gap: 8, pointerEvents: "none" }}>
            <div style={{ width: 34, height: 34, borderRadius: 17, background: Palette.elevated, color: Palette.secondaryLabel, display: "grid", placeItems: "center" }}>
              <Plus size={16} strokeWidth={2.6} />
            </div>
            <div style={{ flex: 1, height: 34, borderRadius: 17, background: Palette.elevated, padding: "0 14px", display: "flex", alignItems: "center" }}>
              <span style={{ fontSize: 14, color: Palette.tertiaryLabel }}>{zh ? "发消息" : "Message"}</span>
              <span style={{ flex: 1 }} />
              <Mic size={14} fill="currentColor" strokeWidth={2} style={{ color: Palette.secondaryLabel }} />
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={false}
          animate={{ opacity: lifted ? 0.22 : 0 }}
          transition={spr}
          onClick={dismiss}
          style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: lifted ? "auto" : "none" }}
        />
        {/* The selected bubble with its reaction bar and menu, above the blur. */}
        <div key={selected} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          <motion.div
            initial={{ y: 0, scale: 0.3, opacity: 0 }}
            animate={{ y: shift, scale: lifted ? 1 : 0.3, opacity: lifted ? 1 : 0 }}
            transition={spr}
            style={{
              position: "absolute",
              left: barLeft,
              top: message.top - GAP - BAR.h,
              width: BAR.w,
              height: BAR.h,
              transformOrigin: message.mine ? "100% 100%" : "0% 100%",
              borderRadius: BAR.h / 2,
              background: Palette.elevated,
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 16px ${black(0.22)}`,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 2,
              pointerEvents: lifted ? "auto" : "none",
            }}
          >
            {glyphs.map((glyph, index) => {
              const isChosen = chosen === index;
              return (
                <motion.div
                  key={index}
                  initial={{ scale: 0.2, opacity: 0 }}
                  animate={{ scale: lifted ? 1 : 0.2, opacity: lifted ? 1 : 0 }}
                  transition={delayed(spring(0.34, 0.55), lifted ? 0.06 + index * stagger : 0)}
                  style={{ position: "relative", zIndex: isChosen ? 1 : 0 }}
                >
                  <motion.button
                    type="button"
                    onClick={() => react(index)}
                    initial={false}
                    animate={{ scale: isChosen ? 1.45 : 1, y: isChosen ? -8 : 0, backgroundColor: isChosen ? glyph.color : `${glyph.color}00`, color: isChosen ? "#ffffff" : glyph.color }}
                    transition={spring(0.26, 0.5)}
                    style={{ width: 36, height: 36, borderRadius: 18, display: "grid", placeItems: "center" }}
                  >
                    {glyph.render({ size: 19 })}
                  </motion.button>
                </motion.div>
              );
            })}
          </motion.div>
          <motion.div
            initial={{ y: 0, scale: 0.3, opacity: 0 }}
            animate={{ y: shift, scale: lifted ? 1 : 0.3, opacity: lifted ? 1 : 0 }}
            transition={delayed(spr, lifted ? 0.07 : 0)}
            style={{
              position: "absolute",
              left: menuLeft,
              top: message.top + message.h + GAP,
              width: MENU.w,
              height: MENU.h,
              transformOrigin: message.mine ? "100% 0%" : "0% 0%",
              borderRadius: 16,
              background: Palette.elevated,
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px ${black(0.22)}`,
              pointerEvents: lifted ? "auto" : "none",
            }}
          >
            {menuRows.map((row, index) => (
              <motion.button
                key={index}
                type="button"
                onClick={dismiss}
                initial={{ opacity: 0 }}
                animate={{ opacity: lifted ? 1 : 0 }}
                transition={delayed(anim.easeOut(0.2), lifted ? 0.14 + index * 0.05 : 0)}
                style={{
                  width: "100%",
                  height: 38,
                  padding: "0 14px",
                  display: "flex",
                  alignItems: "center",
                  color: index === 2 ? Palette.red : Palette.label,
                  borderTop: index > 0 ? `1px solid ${Palette.stroke}` : undefined,
                }}
              >
                <span style={{ fontSize: 14 }}>{row[L]}</span>
                <span style={{ flex: 1 }} />
                {row[2]}
              </motion.button>
            ))}
          </motion.div>
          <motion.div
            initial={{ y: 0, scale: 1, boxShadow: `0 0px 0px ${black(0)}` }}
            animate={{
              y: shift,
              scale: pressed === selected && !lifted ? 0.96 : lifted ? 1.04 : 1,
              boxShadow: lifted ? `0 10px 18px ${black(0.3)}` : `0 0px 0px ${black(0)}`,
            }}
            transition={{ default: spr, scale: lifted || pressed === null ? spr : pressSpring }}
            {...holdProps(selected)}
            style={{ position: "absolute", left: leftOf(message), top: message.top, borderRadius: 18, pointerEvents: "auto", cursor: "pointer" }}
          >
            <Bubble message={message} reaction={reactions[selected]} L={L} />
          </motion.div>
        </div>
      </div>
      <DemoHint ctx={ctx} en={lifted ? "Pick a reaction" : "Touch and hold a bubble"} zh={lifted ? "选一个表情" : "按住一条气泡"} />
    </Column>
  );
}

function Bubble({ message, reaction, L }: { message: Message; reaction: number | undefined; L: number }) {
  const mine = message.mine;
  const glyph = reaction === undefined ? null : glyphs[reaction];
  return (
    <div
      style={{
        position: "relative",
        width: message.w,
        height: message.h,
        padding: "0 13px",
        display: "flex",
        alignItems: "center",
        fontSize: 14,
        lineHeight: "18px",
        color: mine ? "#fff" : Palette.label,
        background: mine ? primaryStrong : Palette.elevated,
        borderRadius: mine ? "18px 18px 6px 18px" : "18px 18px 18px 6px",
      }}
    >
      {message.text[L]}
      <AnimatePresence>
        {glyph ? (
          <motion.div
            key={reaction}
            initial={{ scale: 0.2, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.2, opacity: 0 }}
            transition={spring(0.32, 0.5)}
            style={{
              position: "absolute",
              top: -11,
              ...(mine ? { left: -9 } : { right: -9 }),
              width: 24,
              height: 24,
              borderRadius: 12,
              background: glyph.color,
              boxShadow: `0 0 0 2px ${Palette.surface}`,
              color: "#fff",
              display: "grid",
              placeItems: "center",
            }}
          >
            {glyph.render({ size: 12 })}
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}
