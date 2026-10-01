/** feedback.swipe-toast · 甩走式吐司 (Feedback+SwipeToast.swift) */
import { BellOff, Download, Images, Link, SquarePen } from "lucide-react";
import { motion, type Transition } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, black, hex, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { FeedbackMockHeader, FeedbackMockRows, FeedbackScene, gradientOf } from "./_scene";

interface Item {
  icon: ReactNode;
  tint: string;
  title: [string, string];
  detail: [string, string];
  action: [string, string];
}

/** SF `archivebox.fill`. */
const ArchiveFill = (
  <svg width={17} height={17} viewBox="0 0 24 24" fill="currentColor">
    <rect x={2} y={3.5} width={20} height={5.5} rx={1.8} />
    <path fillRule="evenodd" d="M3.6 10.6h16.800v6.900a3 3 0 0 1-3 3H6.600a3 3 0 0 1-3-3zM9.300 12.800a1.100 1.100 0 0 0 0 2.200h5.400a1.100 1.100 0 0 0 0-2.200z" />
  </svg>
);

const ITEMS: Item[] = [
  { icon: ArchiveFill, tint: Palette.indigo, title: ["Conversation archived", "会话已归档"], detail: ["Design review · 12 messages", "设计评审 · 12 条消息"], action: ["Undo", "撤销"] },
  { icon: <Link size={15} strokeWidth={2.8} />, tint: Palette.mint, title: ["Link copied", "链接已复制"], detail: ["Anyone with the link can view", "拿到链接的人都能查看"], action: ["Share", "分享"] },
  { icon: <Download size={16} strokeWidth={2.6} />, tint: Palette.coral, title: ["Draft saved", "草稿已保存"], detail: ["Trip notes · just now", "旅行笔记 · 刚刚"], action: ["Open", "打开"] },
  { icon: <Images size={16} strokeWidth={2.4} />, tint: Palette.amber, title: ["2 photos moved", "已移动 2 张照片"], detail: ["To album Kyoto", "移至相簿“京都”"], action: ["View", "查看"] },
  { icon: <BellOff size={16} strokeWidth={2.4} />, tint: Palette.violet, title: ["Muted for 1 hour", "已静音 1 小时"], detail: ["Team channel", "团队频道"], action: ["Undo", "撤销"] },
];

interface Size {
  x: number;
  y: number;
}
const ZERO: Size = { x: 0, y: 0 };
const NONE: Transition = { duration: 0 };

export default function SwipeToast({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";

  /** Toast ids, front first. A thrown toast stays here until its flight ends. */
  const [queue, setQueue] = useState([0, 1, 2]);
  /** Live drag of the front toast, and the animation its last change was made in. */
  const [drag, setDragState] = useState<{ value: Size; t: Transition }>({ value: ZERO, t: NONE });
  /** Fly-out offsets of toasts that were thrown (with the flight's ease-out). */
  const [thrown, setThrown] = useState<Record<number, { to: Size; t: Transition }>>({});
  /** Fade-in of toasts that arrive at the back. */
  const arrivals = useRef<Record<number, Transition>>({});
  const s = useRef({ queue, drag: ZERO, thrown: {} as Record<number, unknown>, nextID: 3, armed: false, autoDirection: 1, token: 0 });
  s.current.queue = queue;

  const setDrag = (value: Size, t: Transition) => {
    s.current.drag = value;
    setDragState({ value, t });
  };
  const waitingOf = (q: number[], th: Record<number, unknown>) => q.filter((id) => th[id] === undefined);
  const front = () => waitingOf(s.current.queue, s.current.thrown)[0] as number | undefined;

  const settle = () => setDrag(ZERO, spring(0.4, ctx.n("damping")));

  /** The toast keeps the finger's direction and speed; the stack steps forward behind it. */
  const throwAway = (id: number, direction: number, velocity: number, buzz: boolean) => {
    const start = s.current.drag;
    const distance = Math.max(360 - Math.abs(start.x), 120);
    const speed = Math.max(Math.abs(velocity), 760);
    const duration = Math.min(Math.max(distance / speed, 0.16), 0.4);
    if (buzz) haptics.tap("light");
    const arriving = s.current.nextID++;
    const flight = anim.easeOut(duration);
    arrivals.current[arriving] = flight;
    const record = { to: { x: direction * 360, y: start.y + 26 }, t: flight };
    s.current.thrown = { ...s.current.thrown, [id]: record };
    setThrown((th) => ({ ...th, [id]: record }));
    setDrag(ZERO, NONE);
    setQueue((q) => [...q, arriving]);
    after(duration + 0.1, () => {
      const rest = { ...s.current.thrown };
      delete rest[id];
      s.current.thrown = rest;
      setQueue((q) => q.filter((x) => x !== id));
      setThrown((th) => {
        const next = { ...th };
        delete next[id];
        return next;
      });
    });
  };

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        if (front() === undefined) return;
        s.current.token++;
        const value = { x: translation.x, y: translation.y * 0.2 };
        setDrag(value, NONE);
        const nowArmed = Math.abs(value.x) > ctx.n("threshold");
        if (nowArmed !== s.current.armed) {
          s.current.armed = nowArmed;
          haptics.selection();
        }
      },
      onEnd: ({ velocity }) => {
        s.current.armed = false;
        const id = front();
        if (id === undefined) return;
        const width = s.current.drag.x;
        const flicked = Math.abs(velocity.x) > 600 && velocity.x * width >= 0;
        if (!(Math.abs(width) > ctx.n("threshold") || flicked)) {
          settle();
          return;
        }
        const direction = (flicked ? velocity.x : width) >= 0 ? 1 : -1;
        throwAway(id, direction, velocity.x, true);
      },
    },
    8,
  );

  /** Preview and intro: a scripted drag, then the same throw a finger would trigger. */
  const simulate = () => {
    const id = front();
    if (id === undefined || Object.keys(s.current.thrown).length > 0) return;
    const current = ++s.current.token;
    const direction = s.current.autoDirection;
    s.current.autoDirection = -direction;
    setDrag({ x: direction * 66, y: -3 }, anim.easeInOut(0.5));
    after(0.56, () => {
      if (s.current.token !== current || front() !== id) return;
      throwAway(id, direction, direction * 900, false);
    });
  };

  useAutoplay(ctx.isPreview, simulate, { every: 2.0, delay: 0.7 });

  const order = waitingOf(queue, thrown);
  const stack = spring(0.42, ctx.n("damping"));
  const tiltPer = ctx.n("tilt");

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene width={300} height={270}>
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column" }}>
          <FeedbackMockHeader title={zh ? "收件箱" : "Inbox"} symbol={<SquarePen size={15} strokeWidth={2.4} />} />
          <FeedbackMockRows count={4} rowHeight={48} />
        </div>
        <div {...(ctx.isPreview ? {} : pan)} style={{ position: "absolute", left: 0, bottom: 14, width: 300, height: 100, touchAction: "pan-y", cursor: ctx.isPreview ? undefined : "grab" }}>
          {[...queue].reverse().map((id) => {
            const flying = thrown[id];
            const depth = Math.max(order.indexOf(id), 0);
            const isFront = !flying && depth === 0;
            const offset = flying ? flying.to : isFront ? drag.value : ZERO;
            const offsetT = flying ? flying.t : isFront ? drag.t : NONE;
            const level = flying ? 0 : Math.min(depth, 3);
            const arrival = arrivals.current[id];
            return (
              <motion.div
                key={id}
                initial={arrival ? { opacity: 0 } : false}
                animate={{ opacity: 1 }}
                transition={arrival ?? NONE}
                style={{ position: "absolute", left: 16, bottom: 0, width: 268, height: 58, zIndex: flying ? 10 : 5 - depth }}
              >
                <motion.div
                  initial={false}
                  animate={{ x: offset.x, y: offset.y, rotate: (offset.x / 100) * tiltPer }}
                  transition={offsetT}
                  style={{ position: "absolute", inset: 0, transformOrigin: "50% 100%" }}
                >
                  <motion.div
                    initial={false}
                    animate={{ y: -11 * level, scale: 1 - 0.06 * level, opacity: level > 2 ? 0 : 1 }}
                    transition={stack}
                    style={{ position: "absolute", inset: 0, transformOrigin: "50% 100%" }}
                  >
                    <Card item={ITEMS[id % ITEMS.length]} zh={zh} shade={level * 0.1} t={stack} />
                  </motion.div>
                </motion.div>
              </motion.div>
            );
          })}
        </div>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Swipe the toast away" zh="把吐司甩出去" />
    </div>
  );
}

function Card({ item, zh, shade, t }: { item: Item; zh: boolean; shade: number; t: Transition }) {
  const i = zh ? 1 : 0;
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: 20,
        background: `linear-gradient(${hex(0x26262d)}, ${hex(0x17171b)})`,
        boxShadow: `0 6px 24px ${black(0.28)}`,
        display: "flex",
        alignItems: "center",
        gap: 11,
        padding: "0 16px 0 12px",
      }}
    >
      <div style={{ width: 34, height: 34, flexShrink: 0, borderRadius: 10, background: gradientOf(item.tint), color: "#fff", display: "grid", placeItems: "center" }}>{item.icon}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0, flex: 1 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.title[i]}</span>
        <span style={{ fontSize: 12, lineHeight: "16px", color: white(0.6), whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.detail[i]}</span>
      </div>
      <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, color: hex(0x9db2ff), whiteSpace: "nowrap", marginLeft: 4, flexShrink: 0 }}>{item.action[i]}</span>
      {/* Darkening of toasts further back in the stack. */}
      <motion.div initial={false} animate={{ opacity: shade }} transition={t} style={{ position: "absolute", inset: 0, borderRadius: 20, background: "#000", pointerEvents: "none" }} />
      <div style={{ position: "absolute", inset: 0, borderRadius: 20, boxShadow: `inset 0 0 0 0.6px ${white(0.16)}`, pointerEvents: "none" }} />
    </div>
  );
}
