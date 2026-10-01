/** feedback.new-messages-pill · 新消息胶囊 (Feedback+NewMessagesPill.swift) */
import { ArrowDown } from "lucide-react";
import { motion, type Transition } from "motion/react";
import { useRef, useState, type MouseEvent } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, delayed, forever, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { FeedbackScene } from "./_scene";
import { SPRINGS, track, type Keyframe } from "./shared";

type PillState = "hidden" | "shown" | "dived";

const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const ROW = 44;
const INSTANT: Transition = { duration: 0 };
const THREAD = spring(0.5, 0.86);

const OLDER = [
  { en: "Did the build go out?", zh: "新版本发出去了吗？", mine: false },
  { en: "Yes, 2.4 is live", zh: "发了，2.4 已上线", mine: true },
  { en: "Nice. Any crashes?", zh: "不错，有崩溃吗？", mine: false },
  { en: "None so far", zh: "目前没有", mine: true },
  { en: "I'll watch the charts", zh: "我盯着数据", mine: true },
  { en: "Thanks!", zh: "辛苦啦！", mine: false },
];
const INCOMING = [
  { en: "Reviews are coming in", zh: "评价开始进来了" },
  { en: "4.9 stars so far", zh: "目前 4.9 星" },
  { en: "Someone loved the haptics", zh: "有人夸触感做得好" },
  { en: "Featured in Today?!", zh: "上 Today 推荐了？！" },
  { en: "Screenshot coming", zh: "截图马上发你" },
];
const GLOW: Keyframe[] = [{ cubic: 1, d: 0.14 }, { cubic: 0, d: 0.5 }];
const DIVE: Keyframe[] = [{ cubic: -7, d: 0.11 }, { cubic: 0, d: 0.12 }];
const POSE: Record<PillState, { y: number; scale: number; opacity: number }> = {
  hidden: { y: 30, scale: 0.6, opacity: 0 },
  shown: { y: 0, scale: 1, opacity: 1 },
  dived: { y: 80, scale: 0.82, opacity: 0 },
};

export default function NewMessagesPill({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  /** Messages that arrived below the fold since the last reset. */
  const [arrived, setArrived] = useState(0);
  /** The number shown in the pill. */
  const [unread, setUnread] = useState(0);
  const [pill, setPillRaw] = useState<PillState>("hidden");
  const [pillT, setPillT] = useState<Transition>(INSTANT);
  /** Whether the thread has jumped to the newest message. */
  const [atBottom, setAtBottomRaw] = useState(false);
  const [threadT, setThreadT] = useState<Transition>(THREAD);
  const [bumps, setBumps] = useState(0);
  const [dives, setDives] = useState(0);
  const [glow, setGlow] = useState(0);
  const s = useRef({ unread: 0, pill: "hidden" as PillState, atBottom: false });
  const zh = ctx.lang === "zh";

  const setPill = (p: PillState, t: Transition) => {
    s.current.pill = p;
    setPillT(t);
    setPillRaw(p);
  };
  const setAtBottom = (v: boolean, t: Transition) => {
    s.current.atBottom = v;
    setThreadT(t);
    setAtBottomRaw(v);
  };

  const arrive = () => {
    if (s.current.atBottom) return;
    haptics.tap("soft");
    setArrived((n) => n + 1);
    setGlow((n) => n + 1);
    if (s.current.pill === "shown") {
      s.current.unread += 1;
      setUnread(s.current.unread);
      setBumps((n) => n + 1);
    } else {
      s.current.unread = 1;
      setUnread(1);
      setPill("shown", spring(ctx.n("response"), ctx.n("damping")));
    }
  };

  const dive = () => {
    if (s.current.pill !== "shown") return;
    haptics.tap("medium");
    setDives((n) => n + 1);
    setPill("dived", delayed(anim.easeIn(0.22), 0.11));
    setAtBottom(true, delayed(THREAD, 0.12));
  };

  const reset = () => {
    clearAll();
    setPill("hidden", INSTANT);
    setAtBottom(false, THREAD);
    s.current.unread = 0;
    setUnread(0);
    // Forget the read messages once the thread is back at the older ones.
    after(0.4, () => {
      if (!s.current.atBottom) setArrived(0);
    });
  };

  /** A tap on the chat: a message comes in (after scrolling back up if the thread is at the bottom). */
  const receive = () => {
    if (!s.current.atBottom) {
      arrive();
      return;
    }
    reset();
    after(0.5, arrive);
  };

  /** Preview loop and intro: three arrivals, the dive, then back up to the older messages. */
  const tick = () => {
    if (s.current.atBottom) reset();
    else if (s.current.unread < 3) arrive();
    else dive();
  };
  useAutoplay(ctx.isPreview, tick, { every: 1.0, delay: 0.6 });

  const bump = ctx.n("bump");
  const bumpE = useElapsed(bumps, 1.2, true);
  const bumpScale = bumpE < 0 ? 1 : track(bumpE, 1, [{ cubic: bump, d: 0.11 }, { spring: 1, d: 0.45, ...SPRINGS.bouncy }]);
  const bumpLift = bumpE < 0 ? 0 : track(bumpE, 0, [{ cubic: -5, d: 0.11 }, { spring: 0, d: 0.45, ...SPRINGS.bouncy }]);
  const diveE = useElapsed(dives, 0.23, true);
  const diveLift = diveE < 0 ? 0 : track(diveE, 0, DIVE);
  const glowE = useElapsed(glow, 0.64, true);
  const glowOpacity = glowE < 0 ? 0 : track(glowE, 0, GLOW);

  const bubble = (text: string, mine: boolean, fresh: boolean) => (
    <div style={{ height: ROW, flexShrink: 0, padding: "0 14px", display: "flex", alignItems: "center", justifyContent: mine ? "flex-end" : "flex-start" }}>
      <span
        style={{
          display: "inline-flex",
          alignItems: "center",
          height: 34,
          padding: "0 12px",
          borderRadius: 17,
          fontSize: 13,
          lineHeight: "18px",
          whiteSpace: "nowrap",
          color: mine ? "#fff" : Palette.label,
          background: mine ? PRIMARY_STRONG : fresh ? alpha(Palette.indigo, 0.16) : Palette.labelAlpha(0.08),
        }}
      >
        {text}
      </span>
    </div>
  );

  const shown = Math.max(unread, 1);
  const label = zh ? `${shown} 条新消息` : unread > 1 ? `${unread} new messages` : "1 new message";
  const pose = POSE[pill];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene height={270} style={{ cursor: "pointer" }}>
        <div onClick={receive} style={{ position: "absolute", inset: 0 }}>
          {/* thread */}
          <motion.div
            initial={false}
            animate={{ y: atBottom ? -arrived * ROW : 0 }}
            transition={threadT}
            style={{ position: "absolute", left: 0, top: 0, width: 300, paddingTop: 8, display: "flex", flexDirection: "column" }}
          >
            {OLDER.map((b, index) => (
              <div key={index}>{bubble(zh ? b.zh : b.en, b.mine, false)}</div>
            ))}
            {Array.from({ length: arrived }, (_, index) => {
              const text = INCOMING[index % INCOMING.length];
              return (
                <motion.div
                  key={`new-${index}`}
                  initial={{ scale: 0.7, opacity: 0 }}
                  animate={{ scale: atBottom ? 1 : 0.7, opacity: atBottom ? 1 : 0 }}
                  transition={delayed(spring(0.4, 0.68), atBottom ? 0.16 + index * 0.06 : 0)}
                  style={{ transformOrigin: "0% 100%" }}
                >
                  {bubble(zh ? text.zh : text.en, false, true)}
                </motion.div>
              );
            })}
          </motion.div>

          {/* A glow along the bottom edge each time something lands below the fold. */}
          <div style={{ position: "absolute", left: 0, bottom: 0, width: 300, height: 46, pointerEvents: "none", opacity: glowOpacity, background: `linear-gradient(${alpha(Palette.indigo, 0)}, ${alpha(Palette.indigo, 0.45)})` }} />

          {/* pill */}
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 14, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
            <motion.div initial={false} animate={pose} transition={pillT}>
              <button
                type="button"
                onClick={(e: MouseEvent) => {
                  e.stopPropagation();
                  dive();
                }}
                style={{
                  position: "relative",
                  display: "flex",
                  alignItems: "center",
                  gap: 7,
                  height: 36,
                  padding: "0 14px 0 8px",
                  borderRadius: 18,
                  background: PRIMARY_STRONG,
                  color: "#fff",
                  boxShadow: `inset 0 0 0 0.5px ${white(0.2)}, 0 6px 12px ${alpha(Palette.indigo, 0.45)}`,
                  pointerEvents: pill === "shown" ? "auto" : "none",
                  transform: `translateY(${bumpLift + diveLift}px) scale(${bumpScale})`,
                }}
              >
                <span style={{ width: 20, height: 20, borderRadius: 10, background: white(0.22), display: "grid", placeItems: "center", flexShrink: 0 }}>
                  <motion.span initial={{ y: -1.5 }} animate={{ y: 1.5 }} transition={forever(anim.easeInOut(0.6))} style={{ display: "grid" }}>
                    <ArrowDown size={13} strokeWidth={3.4} />
                  </motion.span>
                </span>
                <NumericText value={unread} text={label} style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "pre" }} />
              </button>
            </motion.div>
          </div>
        </div>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Tap the chat to receive, tap the pill to jump" zh="点会话收一条消息，点胶囊跳到底部" />
    </div>
  );
}
