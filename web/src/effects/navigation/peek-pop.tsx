/** navigation.peek-pop · 预览与弹入 (Navigation+PeekPop.swift) */
import { animate, motion, useMotionValue, type Transition } from "motion/react";
import { ChevronLeft, Leaf, Mountain, Plane, Reply, SquarePen, WandSparkles } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, anim, elementScale, forever, rubberBand, spring, useHaptics, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { colorGradient, useMotionNumber } from "./nav-util";
import { diag, stageColumn, useAutoplayFlag, useNavPan } from "./_r2";

type L = [string, string];
const MAILS: { initial: string; color: string; sender: L; subject: L; time: L; message: L; icon: ReactNode; art: [string, string] }[] = [
  {
    initial: "M",
    color: Palette.pink,
    sender: ["Mia Chen", "陈米娅"],
    subject: ["Photos from the ridge", "山脊上的照片"],
    time: ["9:41", "9:41"],
    message: ["We made it up before sunrise. The light on the lake was unreal, have a look.", "我们赶在日出前登顶了。湖面上的光美得不真实，你看看。"],
    icon: <Mountain size={30} fill="currentColor" strokeWidth={2} />,
    art: [Palette.sky, Palette.indigo],
  },
  {
    initial: "K",
    color: Palette.indigo,
    sender: ["Kai Tanaka", "田中凯"],
    subject: ["Motion review at 3", "三点动效评审"],
    time: ["8:15", "8:15"],
    message: ["I pushed the new tab bar springs. Bring your phone, it only makes sense in the hand.", "新的标签栏弹簧我已经提交了。记得带手机，这东西得拿在手里才有感觉。"],
    icon: <WandSparkles size={30} strokeWidth={2.4} />,
    art: [Palette.violet, Palette.pink],
  },
  {
    initial: "L",
    color: Palette.mint,
    sender: ["Lena Park", "朴莉娜"],
    subject: ["Weekend market", "周末集市"],
    time: ["Tue", "周二"],
    message: ["The flower stall is back. Saturday at ten, coffee is on me this time.", "花摊回来了。周六十点见，这次咖啡我请。"],
    icon: <Leaf size={30} fill="currentColor" strokeWidth={1.6} />,
    art: [Palette.mint, Palette.green],
  },
  {
    initial: "S",
    color: Palette.amber,
    sender: ["Sam Rivera", "里维拉"],
    subject: ["Your ticket to Lisbon", "你的里斯本机票"],
    time: ["Mon", "周一"],
    message: ["Boarding pass attached. Window seat, as promised. See you at the gate.", "登机牌在附件里。按约定给你留了靠窗的位子，登机口见。"],
    icon: <Plane size={30} fill="currentColor" strokeWidth={1.6} />,
    art: [Palette.amber, Palette.coral],
  },
];

const FRAME = { w: 260, h: 290 };
const ROW_H = 52;
const ROW_STEP = 57;
const LIST_TOP = 54;
const PEEK = { x: 14, y: 48, w: 232, h: 190 };
const POP_TRAVEL = 110;
const rowRect = (index: number) => ({ x: 10, y: LIST_TOP + index * ROW_STEP, w: FRAME.w - 20, h: ROW_H });
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1);

function RowContent({ mail, ctx }: { mail: (typeof MAILS)[number]; ctx: DemoContext }) {
  return (
    <div style={{ height: ROW_H, padding: "0 10px", boxSizing: "border-box", display: "flex", alignItems: "center", gap: 10 }}>
      <div style={{ width: 36, height: 36, borderRadius: "50%", background: colorGradient(mail.color), color: "#fff", display: "grid", placeItems: "center", fontSize: 15, fontWeight: 700, flexShrink: 0 }}>{mail.initial}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...mail.sender)}</span>
        <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t(...mail.subject)}</span>
      </div>
      <div style={{ flex: 1, minWidth: 6 }} />
      <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>{ctx.t(...mail.time)}</span>
    </div>
  );
}

export default function PeekPop({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  /** The message that is lifted (peeked or popped). */
  const [active, setActiveState] = useState<number | null>(null);
  const activeRef = useRef<number | null>(null);
  const liftMV = useMotionValue(0); // 0 = in its row, 1 = preview card
  const popMV = useMotionValue(0); // 0 = preview card, 1 = full screen
  const lift = useMotionNumber(liftMV);
  const pop = useMotionNumber(popMV);
  /** The model values (what SwiftUI's state holds while the presentation animates). */
  const model = useRef({ lift: 0, pop: 0 });
  const [sunk, setSunk] = useState<number | null>(null);
  const closeToken = useRef(0);
  const autoStep = useRef(0);
  const autoIndex = useRef(0);
  const cancelAuto = useRef<(() => void) | null>(null);
  const press = useRef<{ id: number; index: number; x: number; y: number; scale: number; held: boolean; base: number; lastY: number; lastT: number; v: number; cancel: () => void } | null>(null);

  const response = ctx.n("response");
  const move = spring(response, 0.78);
  const isFull = () => activeRef.current !== null && model.current.pop >= 1;
  const setActive = (v: number | null) => {
    activeRef.current = v;
    setActiveState(v);
  };
  const drive = (liftTo: number, popTo: number, t: Transition) => {
    model.current = { lift: liftTo, pop: popTo };
    animate(popMV, popTo, t);
    return animate(liftMV, liftTo, t);
  };

  const peek = (index: number, silent = false) => {
    if (activeRef.current !== null) return;
    if (!silent) haptics.tap("medium");
    setActive(index);
    popMV.jump(0);
    drive(1, 0, move);
  };
  const popFull = () => {
    if (activeRef.current === null) return;
    haptics.tap("heavy");
    drive(1, 1, spring(response * 0.9, 0.84));
  };
  const close = () => {
    if (activeRef.current === null) return;
    haptics.tap("light");
    drive(0, 0, spring(response, 0.86));
    // The spring's logical completion (well before the last sub-pixel settles).
    const token = ++closeToken.current;
    after(response * 1.4, () => {
      if (token === closeToken.current && model.current.lift === 0) setActive(null);
    });
  };
  /** The finger lifted while peeking without a drag: stay, or drop back, depending on the parameter. */
  const released = () => {
    if (activeRef.current === null || isFull()) return;
    if (!ctx.b("sticky")) close();
  };

  const cardDragChanged = (dy: number) => {
    if (activeRef.current === null || isFull()) return;
    liftMV.stop();
    popMV.stop();
    if (dy <= 0) {
      const raw = -dy / POP_TRAVEL;
      model.current = { pop: raw <= 1 ? raw : 1 + rubberBand(raw - 1, 0.12), lift: 1 };
    } else {
      model.current = { pop: 0, lift: 1 - Math.min(dy / 260, 0.35) };
    }
    popMV.set(model.current.pop);
    liftMV.set(model.current.lift);
  };
  const cardDragEnded = (translation: number, velocity: number) => {
    if (activeRef.current === null || isFull()) return;
    if (model.current.pop > 0.45 || velocity < -600) popFull();
    else if (translation > 50 || velocity > 600) close();
    else {
      drive(1, 0, move);
      released();
    }
  };

  // Hold, then drag (one touch).
  const rowDown = (index: number, e: React.PointerEvent<HTMLDivElement>) => {
    if (press.current || activeRef.current !== null) return;
    if (e.pointerType === "mouse" && e.button !== 0) return;
    const el = e.currentTarget;
    try {
      el.setPointerCapture(e.pointerId);
    } catch {
      /* pointer already gone */
    }
    setSunk(index);
    const cancel = after(ctx.n("hold"), () => {
      const p = press.current;
      if (!p || p.held) return;
      p.held = true;
      p.base = p.lastY;
      setSunk(null);
      peek(index);
    });
    press.current = { id: e.pointerId, index, x: e.clientX, y: e.clientY, scale: elementScale(el) || 1, held: false, base: e.clientY, lastY: e.clientY, lastT: performance.now(), v: 0, cancel };
  };
  const rowMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId) return;
    const now = performance.now();
    const dt = Math.max((now - p.lastT) / 1000, 1 / 240);
    p.v = p.v * 0.6 + ((e.clientY - p.lastY) / p.scale / dt) * 0.4;
    p.lastY = e.clientY;
    p.lastT = now;
    if (!p.held) {
      if (Math.hypot(e.clientX - p.x, e.clientY - p.y) / p.scale > 12) {
        p.cancel();
        press.current = null;
        setSunk(null);
      }
      return;
    }
    cardDragChanged((e.clientY - p.base) / p.scale);
  };
  const rowUp = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId) return;
    press.current = null;
    p.cancel();
    setSunk(null);
    if (!p.held) return;
    const dy = (e.clientY - p.base) / p.scale;
    const velocity = performance.now() - p.lastT > 80 ? 0 : p.v;
    if (e.type !== "pointercancel" && (model.current.pop > 0.02 || dy > 30)) cardDragEnded(dy, velocity);
    else if (model.current.pop < 0.02 && model.current.lift > 0.98) released();
  };

  const cardPan = useNavPan(
    {
      onChange: (s) => cardDragChanged(s.translation.y),
      onEnd: (s) => cardDragEnded(s?.translation.y ?? 0, s?.velocity.y ?? 0),
    },
    { directions: ["up", "down"], enabled: !(active !== null && model.current.pop >= 1) },
  );

  // Preview loop: a simulated hold lifts the next message, a simulated drag pops it, then it closes.
  useAutoplayFlag(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 3;
      autoStep.current += 1;
      if (phase === 0) {
        if (activeRef.current !== null) {
          close();
          autoStep.current = 0;
          return;
        }
        if (sunk !== null) return;
        const index = autoIndex.current % MAILS.length;
        autoIndex.current += 1;
        setSunk(index);
        cancelAuto.current?.();
        cancelAuto.current = after(ctx.n("hold"), () => {
          setSunk(null);
          peek(index, true);
        });
      } else if (phase === 1) {
        if (activeRef.current === null) return;
        model.current.pop = 0.5;
        void animate(popMV, 0.5, anim.easeInOut(0.3)).then(() => {
          if (activeRef.current !== null && model.current.pop === 0.5) popFull();
        });
      } else close();
    },
    { every: 1.4 },
  );
  useEffect(() => () => cancelAuto.current?.(), []);

  const l01 = clamp01(lift);
  const p = Math.max(pop, 0);
  const p01 = Math.min(p, 1);

  let card: ReactNode = null;
  if (active !== null) {
    const mail = MAILS[active];
    const row = rowRect(active);
    const x = lerp(lerp(row.x, PEEK.x, lift), 0, p);
    const y = lerp(lerp(row.y, PEEK.y, lift), 0, p);
    const width = lerp(lerp(row.w, PEEK.w, lift), FRAME.w, p);
    const height = lerp(lerp(row.h, PEEK.h, lift), FRAME.h, p);
    const radius = lerp(lerp(16, 24, lift), 34, p01);
    const hint = l01 * Math.max(1 - p * 4, 0);
    card = (
      <div
        {...cardPan}
        onClick={() => !isFull() && popFull()}
        style={{
          position: "absolute",
          left: x,
          top: y,
          width: Math.max(width, 40),
          height: Math.max(height, 40),
          borderRadius: radius,
          background: Palette.elevated,
          boxShadow: `0 12px 24px rgb(0 0 0 / ${0.3 * l01})`,
          overflow: "hidden",
          cursor: "pointer",
        }}
      >
        {/* navigation bar */}
        <div style={{ height: 44 * p01, opacity: p01, overflow: "hidden", display: "flex", alignItems: "flex-end" }}>
          <div style={{ flex: 1, height: 36, padding: "0 14px", display: "flex", alignItems: "center", justifyContent: "space-between", color: Palette.blue }}>
            <div
              onClick={(e) => {
                e.stopPropagation();
                close();
              }}
              style={{ height: 36, display: "flex", alignItems: "center", gap: 3, cursor: "pointer" }}
            >
              <ChevronLeft size={19} strokeWidth={2.8} style={{ marginLeft: -5 }} />
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap" }}>{ctx.t("Inbox", "收件箱")}</span>
            </div>
            <Reply size={18} strokeWidth={2.6} />
          </div>
        </div>
        <RowContent mail={mail} ctx={ctx} />
        <div style={{ padding: "2px 14px 0", display: "flex", flexDirection: "column", gap: 10, opacity: l01 }}>
          <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.labelAlpha(0.85), display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical", overflow: "hidden" }}>{ctx.t(...mail.message)}</div>
          <div style={{ height: 64 + 36 * p01, borderRadius: 14, background: diag(...mail.art), color: white(0.92), display: "grid", placeItems: "center", flexShrink: 0 }}>{mail.icon}</div>
          <div style={{ opacity: p01 }}>
            <PlaceholderLines count={4} color={Palette.labelAlpha(0.1)} />
          </div>
        </div>
        {/* "drag up" affordance at the foot of the peek; gone as soon as the pop begins */}
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            bottom: 0,
            height: 30,
            display: "grid",
            placeItems: "center",
            background: `linear-gradient(to bottom, transparent, ${Palette.elevated} 50%)`,
            opacity: hint,
            pointerEvents: "none",
          }}
        >
          <motion.svg width={30} height={12} viewBox="0 0 30 12" initial={{ y: 1 }} animate={{ y: -3 }} transition={forever(anim.easeInOut(0.9))}>
            <path d="M3 10L15 3L27 10" fill="none" stroke={Palette.labelAlpha(0.45)} strokeWidth={3.4} strokeLinecap="round" strokeLinejoin="round" />
          </motion.svg>
        </div>
      </div>
    );
  }

  return (
    <div style={stageColumn(14)}>
      <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 34, overflow: "hidden", background: Palette.elevated, boxShadow: "0 10px 18px rgb(0 0 0 / 0.18)" }}>
        {/* inbox */}
        <div style={{ position: "absolute", inset: 0, transform: `scale(${1 - 0.04 * Math.min(lift, 1)})`, filter: l01 > 0.001 ? `blur(${ctx.n("blur") * l01}px)` : undefined }}>
          <div style={{ position: "absolute", left: 0, right: 0, top: 14, height: 34, padding: "0 18px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <span style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700 }}>{ctx.t("Inbox", "收件箱")}</span>
            <SquarePen size={19} strokeWidth={2.5} color={Palette.blue} />
          </div>
          {MAILS.map((mail, index) => {
            const rect = rowRect(index);
            const isSunk = sunk === index;
            return (
              <motion.div
                key={index}
                onPointerDown={(e) => rowDown(index, e)}
                onPointerMove={rowMove}
                onPointerUp={rowUp}
                onPointerCancel={rowUp}
                initial={false}
                animate={{ scale: isSunk ? 0.96 : 1 }}
                transition={isSunk ? anim.easeOut(ctx.n("hold")) : spring(0.3, 0.7)}
                style={{
                  position: "absolute",
                  left: rect.x,
                  top: rect.y,
                  width: rect.w,
                  height: rect.h,
                  borderRadius: 16,
                  background: Palette.labelAlpha(0.045),
                  opacity: active === index ? 0 : 1,
                  cursor: "pointer",
                  touchAction: "pan-y",
                  userSelect: "none",
                  WebkitUserSelect: "none",
                }}
              >
                <RowContent mail={mail} ctx={ctx} />
              </motion.div>
            );
          })}
        </div>
        <div onClick={close} style={{ position: "absolute", inset: 0, background: "#000", opacity: 0.25 * l01, pointerEvents: active !== null ? "auto" : "none" }} />
        {card}
      </div>
      <DemoHint ctx={ctx} en="Hold a message, then drag up" zh="按住一封邮件，再向上拖" />
    </div>
  );
}
