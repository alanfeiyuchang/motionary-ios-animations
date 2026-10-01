/** gestures.swipe-reply · 右滑引用回复 (Gestures+SwipeReply.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { ArrowUp, Reply, X } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, clamp, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { TrayStroke, useGhost } from "./_sim-kit";

type L = [string, string];
type Message = { id: number; text: L; mine: boolean; quote?: L; quoteMine?: boolean };

const SIZE = { w: 300, h: 286 };
const SEED: Message[] = [
  { id: 0, text: ["Dinner on Friday?", "周五一起吃饭？"], mine: false },
  { id: 1, text: ["Yes! Where to?", "好呀，去哪儿？"], mine: true },
  { id: 2, text: ["That new ramen place", "新开的那家拉面"], mine: false },
  { id: 3, text: ["Does 7 pm work?", "七点可以吗？"], mine: false },
];
const REPLIES: L[] = [
  ["Perfect, see you then", "可以，到时见"],
  ["Sounds great", "听起来不错"],
  ["Count me in", "算我一个"],
];
const INCOMING: L[] = [
  ["I'll book a table", "那我去订位"],
  ["Bring an umbrella", "记得带伞"],
  ["Should we invite Leo?", "要不要叫上小磊？"],
];
const ME: L = ["You", "你"];
const THEM: L = ["Mina", "小敏"];
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const COMPOSER_H = 52;
const QUOTE_H = 42;
const ROW_H = 33;
const QUOTED_ROW_H = 72;

/** Room for four rows; a quoted reply is taller and counts double. */
function appended(list: Message[], message: Message): Message[] {
  const next = [...list, message];
  while (next.reduce((n, m) => n + (m.quote ? 2 : 1), 0) > 4) next.shift();
  if (next.length > 4) next.shift();
  return next;
}

export default function SwipeReply({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const timers = useTimeouts();
  const [messages, setMessages] = useState<Message[]>(SEED);
  const [quoted, setQuoted] = useState<Message | null>(null);
  const [dragID, setDragID] = useState<number | null>(null);
  const [armed, setArmed] = useState(false);
  const [layoutSpring, setLayoutSpring] = useState(() => spring(0.42, 0.78));
  const dragX = useMotionValue(0);
  const s = useRef({ messages: SEED, quoted: null as Message | null, dragID: null as number | null, dragTarget: 0, armed: false, nextID: 4, sent: 0, followUp: 0 }).current;
  const threshold = ctx.n("threshold");
  const t = (l: L) => ctx.t(l[0], l[1]);

  /** The finger (or the scripted one) is `translation` points right of where it started on row `id`. */
  const dragChanged = (id: number, translation: number, scripted = false) => {
    if (s.dragID !== id) {
      s.dragID = id;
      s.armed = false;
      setDragID(id);
      setArmed(false);
    }
    dragX.stop();
    const x = translation > 0 ? rubberBand(translation, ctx.n("limit"), 1.1) : -rubberBand(-translation, 14);
    dragX.set(x);
    s.dragTarget = x;
    const nowArmed = x >= ctx.n("threshold");
    if (nowArmed !== s.armed) {
      s.armed = nowArmed;
      setArmed(nowArmed);
      if (!scripted) haptics.tap(nowArmed ? "medium" : "light");
    }
  };

  const dragEnded = () => {
    const id = s.dragID;
    if (id === null) return;
    const commit = s.armed;
    const settle = spring(ctx.n("response"), ctx.n("damping"));
    animate(dragX, 0, settle);
    s.dragTarget = 0;
    s.armed = false;
    setArmed(false);
    const message = s.messages.find((m) => m.id === id);
    if (commit && message) {
      setLayoutSpring(settle);
      s.quoted = message;
      setQuoted(message);
    }
    // Keep the row identified until the spring has carried it home.
    timers.after(0.5, () => {
      if (s.dragID === id && s.dragTarget === 0) {
        s.dragID = null;
        setDragID(null);
      }
    });
  };

  const dismissQuote = () => {
    setLayoutSpring(spring(0.3, 0.85));
    s.quoted = null;
    setQuoted(null);
    haptics.tap("light");
  };

  const send = (scripted = false) => {
    const source = s.quoted;
    if (!source) return;
    const reply: Message = { id: s.nextID, text: REPLIES[s.sent % REPLIES.length], mine: true, quote: source.text, quoteMine: source.mine };
    const follow: Message = { id: s.nextID + 1, text: INCOMING[s.sent % INCOMING.length], mine: false };
    s.nextID += 2;
    s.sent += 1;
    setLayoutSpring(spring(0.42, 0.78));
    s.quoted = null;
    setQuoted(null);
    s.messages = appended(s.messages, reply);
    setMessages(s.messages);
    if (!scripted) haptics.tap("soft");
    window.clearTimeout(s.followUp);
    s.followUp = window.setTimeout(() => {
      setLayoutSpring(spring(0.42, 0.78));
      s.messages = appended(s.messages, follow);
      setMessages(s.messages);
    }, 900);
  };

  /** A scripted finger swipes the newest incoming bubble past the threshold, then the reply is sent. */
  useAutoplay(
    ctx.isPreview,
    () => {
      const target = [...s.messages].reverse().find((m) => !m.mine);
      if (s.dragID !== null || s.quoted !== null || !target) return;
      const reach = ctx.n("threshold") * 1.9 + 20;
      ghost.run(async (g) => {
        if (!(await g.drag({ x: 0, y: 0 }, { x: reach, y: 0 }, 0.6, (p) => dragChanged(target.id, p.x, true)))) return;
        if (!(await g.sleep(0.12))) return;
        dragEnded();
        if (!(await g.sleep(1.1))) return;
        send(true);
      });
    },
    { every: 3.6, delay: 0.6 },
  );

  // Rows stack up from the bottom of the thread.
  const lift = quoted ? QUOTE_H : 0;
  const tops = new Map<number, number>();
  {
    let y = SIZE.h - COMPOSER_H - lift - 8;
    for (let i = messages.length - 1; i >= 0; i--) {
      const h = messages[i].quote ? QUOTED_ROW_H : ROW_H;
      y -= h;
      tops.set(messages[i].id, y);
      y -= 7;
    }
  }
  const active = quoted !== null;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div style={{ position: "relative", width: SIZE.w, height: SIZE.h, flex: "none", borderRadius: 26, background: Palette.elevated, boxShadow: `0 8px 16px ${black(0.08)}`, overflow: "hidden" }}>
        <AnimatePresence initial={false}>
          {messages.map((message) => {
            const top = tops.get(message.id) ?? 0;
            const h = message.quote ? QUOTED_ROW_H : ROW_H;
            return (
              <motion.div
                key={message.id}
                initial={{ y: top + h, opacity: 0 }}
                animate={{ y: top, opacity: 1 }}
                exit={{ y: top - h, opacity: 0 }}
                transition={layoutSpring}
                style={{ position: "absolute", left: 12, right: 12, top: 0, height: h }}
              >
                <Row
                  message={message}
                  dragging={dragID === message.id}
                  dragX={dragX}
                  threshold={threshold}
                  armed={dragID === message.id && armed}
                  text={t(message.text)}
                  quote={message.quote ? t(message.quote) : null}
                  quoteName={t(message.quoteMine ? ME : THEM)}
                  onDrag={(x) => {
                    ghost.touch();
                    dragChanged(message.id, x);
                  }}
                  onEnd={dragEnded}
                />
              </motion.div>
            );
          })}
        </AnimatePresence>

        <AnimatePresence initial={false}>
          {quoted && (
            <motion.div
              key="quote"
              initial={{ y: QUOTE_H, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: QUOTE_H, opacity: 0 }}
              transition={layoutSpring}
              style={{ position: "absolute", left: 0, right: 0, bottom: COMPOSER_H, height: QUOTE_H, background: Palette.elevated }}
            >
              <div style={{ position: "absolute", inset: 0, background: Palette.labelAlpha(0.04), padding: "7px 14px", display: "flex", alignItems: "center", gap: 9 }}>
                <Reply size={15} strokeWidth={2.6} color={Palette.indigo} style={{ flex: "none" }} />
                <div style={{ width: 3, height: 28, borderRadius: 1.5, background: Palette.indigo, flex: "none" }} />
                <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 700, color: Palette.indigo }}>{t(quoted.mine ? ME : THEM)}</div>
                  <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{t(quoted.text)}</div>
                </div>
                <div style={{ flex: 1 }} />
                <button
                  onClick={() => {
                    ghost.touch();
                    dismissQuote();
                  }}
                  style={{ width: 24, height: 24, borderRadius: "50%", background: Palette.labelAlpha(0.07), display: "grid", placeItems: "center", color: Palette.secondaryLabel, flex: "none" }}
                >
                  <X size={11} strokeWidth={3.2} />
                </button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>

        <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: COMPOSER_H, padding: "9px 12px", display: "flex", alignItems: "center", gap: 9, background: Palette.elevated, boxShadow: `inset 0 1px 0 ${Palette.stroke}` }}>
          <div style={{ flex: 1, height: 34, borderRadius: 17, background: Palette.labelAlpha(0.06), padding: "0 13px", display: "flex", alignItems: "center", fontSize: 14, color: Palette.tertiaryLabel }}>
            {ctx.t("Message", "发消息")}
          </div>
          <motion.button
            disabled={!active}
            onClick={() => {
              ghost.touch();
              send();
            }}
            initial={false}
            animate={{ scale: active ? 1 : 0.9 }}
            transition={spring(0.3, 0.6)}
            style={{ position: "relative", width: 34, height: 34, borderRadius: "50%", background: Palette.labelAlpha(0.08), display: "grid", placeItems: "center", color: active ? "#fff" : Palette.secondaryLabel, flex: "none", overflow: "hidden" }}
          >
            <motion.span initial={false} animate={{ opacity: active ? 1 : 0 }} transition={spring(0.3, 0.6)} style={{ position: "absolute", inset: 0, background: PRIMARY_STRONG }} />
            <ArrowUp size={16} strokeWidth={3} style={{ position: "relative" }} />
          </motion.button>
        </div>
        <TrayStroke radius={26} />
      </div>
      <DemoHint ctx={ctx} en="Swipe a message to the right" zh="把一条消息向右滑" />
    </div>
  );
}

function Row({
  message,
  dragging,
  dragX,
  threshold,
  armed,
  text,
  quote,
  quoteName,
  onDrag,
  onEnd,
}: {
  message: Message;
  dragging: boolean;
  dragX: MotionValue<number>;
  threshold: number;
  armed: boolean;
  text: string;
  quote: string | null;
  quoteName: string;
  onDrag: (translation: number) => void;
  onEnd: () => void;
}) {
  const horizontal = useRef(false);
  const pan = usePan(
    {
      // `pageSafeHorizontalDrag`: only drags that start sideways are taken.
      onStart: ({ translation }) => {
        horizontal.current = Math.abs(translation.x) >= Math.abs(translation.y);
      },
      onChange: ({ translation }) => {
        if (horizontal.current) onDrag(translation.x);
      },
      onEnd: () => {
        if (horizontal.current) onEnd();
      },
    },
    8,
  );
  const x = useTransform(dragX, (v) => (dragging ? v : 0));
  const arrowX = useTransform(dragX, (v) => (dragging ? Math.max(v, 0) * 0.5 - 22 : -22));
  const p = (v: number) => (dragging ? clamp(v / threshold, 0, 1) : 0);
  const arrowScale = useTransform(dragX, (v) => 0.5 + 0.5 * p(v));
  const arrowOpacity = useTransform(dragX, (v) => Math.min(p(v) * 1.6, 1));
  const ring = useTransform(dragX, (v) => 2 * Math.PI * 14 * (1 - p(v)));
  const armSpring = spring(0.28, 0.5);

  return (
    <div {...pan} style={{ ...pan.style, position: "absolute", inset: 0, display: "flex", justifyContent: message.mine ? "flex-end" : "flex-start", alignItems: "center", cursor: "grab" }}>
      <div style={{ position: "relative", maxWidth: 276 - 40 }}>
        {/* The reply glyph behind the bubble: its ring draws with the pull and it fills once armed. */}
        <motion.div style={{ position: "absolute", left: 0, top: "50%", marginTop: -15, width: 30, height: 30, x: arrowX, scale: arrowScale, opacity: arrowOpacity }}>
          <motion.div initial={false} animate={{ scale: armed ? 1.25 : 1 }} transition={armSpring} style={{ position: "absolute", inset: 0 }}>
            <motion.div
              initial={false}
              animate={{ opacity: armed ? 1 : 0 }}
              transition={armSpring}
              style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.indigo }}
            />
            <motion.div initial={false} animate={{ opacity: armed ? 0 : 1 }} transition={armSpring} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.labelAlpha(0.06) }}>
              <svg width={30} height={30} style={{ position: "absolute", inset: 0, transform: "rotate(-90deg)" }}>
                <motion.circle cx={15} cy={15} r={14} fill="none" stroke={Palette.indigo} strokeWidth={2} strokeLinecap="round" strokeDasharray={2 * Math.PI * 14} style={{ strokeDashoffset: ring }} />
              </svg>
            </motion.div>
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: armed ? "#fff" : Palette.indigo }}>
              <Reply size={14} strokeWidth={2.8} />
            </div>
          </motion.div>
        </motion.div>
        <motion.div
          style={{
            position: "relative",
            x,
            padding: "8px 12px",
            borderRadius: 17,
            background: message.mine ? PRIMARY_STRONG : Palette.labelAlpha(0.08),
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-start",
            gap: 5,
          }}
        >
          {quote !== null && (
            <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "4px 7px", borderRadius: 9, background: white(0.16), color: white(0.92) }}>
              <div style={{ width: 2.5, height: 26, borderRadius: 1.25, background: white(0.9), flex: "none" }} />
              <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
                <div style={{ fontSize: 10, lineHeight: "12px", fontWeight: 700 }}>{quoteName}</div>
                <div style={{ fontSize: 11, lineHeight: "13px", whiteSpace: "nowrap" }}>{quote}</div>
              </div>
            </div>
          )}
          <div style={{ fontSize: 14, lineHeight: "17px", color: message.mine ? "#fff" : Palette.label, whiteSpace: "nowrap" }}>{text}</div>
        </motion.div>
      </div>
    </div>
  );
}
