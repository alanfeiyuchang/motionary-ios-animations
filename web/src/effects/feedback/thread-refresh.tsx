/** feedback.thread-refresh · 拨弦下拉刷新 (Feedback+ThreadRefresh.swift) */
import { AudioLines, Guitar, Metronome, Music, Users } from "lucide-react";
import { AnimatePresence, animate, motion, useMotionValue, useMotionValueEvent, type Transition } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, demoCard, ease, mix, progress, rubberBand, spring, useAutoplay, useClock, useElapsed, useHaptics, usePan, useTimeouts, type DemoProps } from "../../kit";
import { gradientOf } from "./_scene";
import { SPRINGS, separator, track } from "./shared";

const THRESHOLD = 80;
const HOLD_HEIGHT = 70;
/** Height of the pins the thread is strung between. */
const ANCHOR_Y = 12;
/** How far above the list's top edge the bead rides. */
const BEAD_GAP = 12;
const ROW_HEIGHT = 62;

/** `tuningfork`: lucide has none, so a small hand-drawn one. */
const TuningFork = (
  <svg width={17} height={17} viewBox="0 0 17 17" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
    <path d="M9.2 2.2 L5.4 6 a2.6 2.6 0 0 0 3.7 3.7 L12.9 5.9" transform="translate(1.6 -0.6)" />
    <path d="M8 9.6 L3.2 14.4" />
  </svg>
);

const ITEMS: { icon: ReactNode; tint: string; title: [string, string]; detail: [string, string] }[] = [
  { icon: <Music size={16} strokeWidth={2.6} />, tint: Palette.pink, title: ["New release from Khruangbin", "Khruangbin 发布新专辑"], detail: ["12 tracks · out now", "12 首 · 现已上线"] },
  { icon: <Guitar size={17} strokeWidth={2.4} />, tint: Palette.indigo, title: ["Lesson 8: fingerpicking", "第 8 课：指弹"], detail: ["14 min · intermediate", "14 分钟 · 中级"] },
  { icon: TuningFork, tint: Palette.mint, title: ["Tuner calibrated", "调音器已校准"], detail: ["A4 = 440 Hz", "A4 = 440 Hz"] },
  { icon: <AudioLines size={17} strokeWidth={2.4} />, tint: Palette.coral, title: ["Take 3 saved", "第 3 次录音已保存"], detail: ["0:48 · just now", "0:48 · 刚刚"] },
  { icon: <Users size={16} strokeWidth={2.6} fill="currentColor" />, tint: Palette.sky, title: ["Jam session on Friday", "周五合奏"], detail: ["Studio B · 7:30 pm", "B 号排练室 · 晚 7:30"] },
  { icon: <Metronome size={17} strokeWidth={2.4} />, tint: Palette.amber, title: ["Practice streak: 9 days", "已连续练习 9 天"], detail: ["Keep it going", "继续保持"] },
];

export default function ThreadRefresh({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const live = !ctx.isPreview;

  /** The finger's rubber-banded pull, and the extra shift of the rows (scripted pull, hold height). */
  const finger = useMotionValue(0);
  const shift = useMotionValue(0);
  const listSlide = useMotionValue(0);
  const [pull, setPull] = useState(0);
  const [refreshing, setRefreshing] = useState(false);
  const [items, setItems] = useState([3, 2, 1, 0]);
  const [userDriven, setUserDriven] = useState(false);
  const nextItem = useRef(4);
  const refreshingRef = useRef(false);
  const userDrivenRef = useRef(false);
  const fingerAnim = useRef<ReturnType<typeof animate> | null>(null);
  const shiftAnim = useRef<ReturnType<typeof animate> | null>(null);
  const slideAnim = useRef<ReturnType<typeof animate> | null>(null);

  const update = () => setPull(finger.get() + shift.get());
  useMotionValueEvent(finger, "change", update);
  useMotionValueEvent(shift, "change", update);
  useEffect(
    () => () => {
      fingerAnim.current?.stop();
      shiftAnim.current?.stop();
      slideAnim.current?.stop();
    },
    [],
  );

  const shiftTo = (v: number, t: Transition) => {
    shiftAnim.current?.stop();
    shiftAnim.current = animate(shift, v, t);
  };

  /** Finger lifted, or the scripted pull ended: refresh if past the threshold. */
  const release = () => {
    if (refreshingRef.current) return;
    if (finger.get() + shift.get() < THRESHOLD) {
      shiftTo(0, spring(0.4, 0.75));
      return;
    }
    refreshingRef.current = true;
    setRefreshing(true);
    shiftTo(HOLD_HEIGHT, spring(0.4, 0.9));
    const buzz = live && userDrivenRef.current;
    clearAll();
    after(ctx.n("duration"), () => {
      const done = spring(0.5, 0.84);
      const id = nextItem.current++;
      setItems((list) => [id, ...list].slice(0, 4));
      // The new row moves in from the top edge while the others make room: the whole column slides one row.
      slideAnim.current?.stop();
      listSlide.set(-ROW_HEIGHT);
      slideAnim.current = animate(listSlide, 0, done);
      shiftTo(0, done);
      refreshingRef.current = false;
      setRefreshing(false);
      if (buzz) haptics.success();
    });
  };

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        fingerAnim.current?.stop();
        finger.set(rubberBand(Math.max(translation.y, 0), 240, 0.8));
        if (!userDrivenRef.current) {
          userDrivenRef.current = true;
          setUserDriven(true);
        }
      },
      onEnd: () => {
        release();
        fingerAnim.current = animate(finger, 0, spring(0.4, 0.9));
      },
    },
    4,
  );

  const simulate = () => {
    if (refreshingRef.current) return;
    userDrivenRef.current = false;
    setUserDriven(false);
    clearAll();
    shiftTo(THRESHOLD * 0.62, anim.easeOut(0.6));
    after(0.6, () => {
      if (refreshingRef.current) return;
      // Linger just under the threshold so the taut V reads, then pull through.
      shiftTo(THRESHOLD - 5, anim.easeOut(0.5));
      after(0.75, () => {
        if (refreshingRef.current) return;
        shiftTo(THRESHOLD + 14, anim.easeOut(0.25));
        after(0.5, release);
      });
    });
  };

  useAutoplay(ctx.isPreview, simulate, { every: ctx.n("duration") + 3.6, delay: 0.6 });

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ ...demoCard(22), position: "relative", width: 300, height: 260, flexShrink: 0 }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 22, overflow: "hidden", background: Palette.surface }}>
          <div style={{ position: "absolute", left: 0, top: 0, width: 300, height: Math.max(pull, 1), overflow: "hidden" }}>
            <ThreadIndicator pull={pull} refreshing={refreshing} pitch={ctx.n("pitch")} decay={ctx.n("decay")} preview={ctx.isPreview} buzz={userDriven && live} />
          </div>
          <div
            {...(live ? pan : {})}
            style={{ position: "absolute", left: 0, top: 0, width: 300, height: 260, transform: `translateY(${pull}px)`, background: Palette.elevated, borderRadius: "22px 22px 0 0", overflow: "hidden", touchAction: "pan-x", cursor: live ? "grab" : undefined }}
          >
            <motion.div style={{ y: listSlide }}>
              <AnimatePresence initial={false}>
                {items.map((item) => (
                  <motion.div key={item} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={spring(0.5, 0.84)}>
                    <Row item={ITEMS[item % ITEMS.length]} zh={zh} scheme={ctx.scheme} />
                  </motion.div>
                ))}
              </AnimatePresence>
            </motion.div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 22, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Pull the list down" zh="向下拖动列表" />
    </div>
  );
}

function Row({ item, zh, scheme }: { item: (typeof ITEMS)[number]; zh: boolean; scheme: "dark" | "light" }) {
  return (
    <div style={{ position: "relative", height: ROW_HEIGHT, padding: "0 14px", display: "flex", alignItems: "center", gap: 12 }}>
      <div style={{ width: 36, height: 36, flexShrink: 0, borderRadius: 10, background: gradientOf(item.tint), color: "#fff", display: "grid", placeItems: "center" }}>{item.icon}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.title[zh ? 1 : 0]}</span>
        <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{item.detail[zh ? 1 : 0]}</span>
      </div>
      <div style={{ position: "absolute", left: 62, right: 0, bottom: 0, height: 0.5, background: separator(scheme) }} />
    </div>
  );
}

// MARK: - Indicator

/** Indigo (0x6E7BFF) to pink (0xFF5FA2). */
const threadRGB = (t: number): [number, number, number] => [110 + (255 - 110) * t, 123 + (95 - 123) * t, 255 + (162 - 255) * t];
const rgb = (c: [number, number, number]) => `rgb(${c[0].toFixed(1)} ${c[1].toFixed(1)} ${c[2].toFixed(1)})`;
const INDIGO: [number, number, number] = [110, 123, 255];

/**
 * `ThreadShape`: a string between two pins, deflected by the first three odd harmonics of a triangle
 * wave. With equal amplitudes they sum to a V with its apex at `ANCHOR_Y + amplitude`.
 */
function threadPath(first: number, third: number, fifth: number): string {
  const inset = 28;
  const span = 300 - inset * 2;
  const norm = 1 + 1 / 9 + 1 / 25;
  const steps = 56;
  let d = "";
  for (let step = 0; step <= steps; step++) {
    const u = step / steps;
    const a = Math.sin(Math.PI * u);
    const b = -Math.sin(3 * Math.PI * u) / 9;
    const c = Math.sin(5 * Math.PI * u) / 25;
    let deflection = (first * a + third * b + fifth * c) / norm;
    // The pins sit near the top edge, so the upward swing is kept short to stay inside the pull area.
    if (deflection < 0) deflection *= 0.3;
    d += `${step === 0 ? "M" : "L"}${(inset + span * u).toFixed(2)} ${(ANCHOR_Y + deflection).toFixed(2)}`;
  }
  return d;
}

function ThreadIndicator({ pull, refreshing, pitch, decay, preview, buzz }: { pull: number; refreshing: boolean; pitch: number; decay: number; preview: boolean; buzz: boolean }) {
  const haptics = useHaptics();
  const fps = preview ? 30 : undefined;
  /** When the bead slipped off, and how far the thread was deflected at that instant. */
  const snapTime = useRef(-1e9);
  const snapSag = useRef(0);
  const [ringing, setRinging] = useState(false);
  /** The bead has slipped off and stays free until the list is back home. */
  const [slipped, setSlipped] = useState(false);
  const [snaps, setSnaps] = useState(0);
  const ringTimer = useRef(0);
  const heldColour = useRef<[number, number, number]>(INDIGO);

  const snapped = refreshing || pull >= THRESHOLD;
  const beadY = Math.max(pull - BEAD_GAP, ANCHOR_Y);
  const sag = beadY - ANCHOR_Y;
  const tension = Math.min(Math.max(sag / (THRESHOLD - BEAD_GAP - ANCHOR_Y), 0), 1);
  const held = !snapped && !slipped;
  if (held) heldColour.current = threadRGB(tension);

  const latest = useRef({ sag, buzz });
  latest.current = { sag, buzz };
  useEffect(() => {
    if (!snapped || slipped) return;
    snapSag.current = Math.max(latest.current.sag, 40);
    snapTime.current = performance.now() / 1000;
    setRinging(true);
    setSlipped(true);
    setSnaps((n) => n + 1);
    if (latest.current.buzz) haptics.tap("rigid");
    window.clearTimeout(ringTimer.current);
    // Stop redrawing once the string has died away.
    ringTimer.current = window.setTimeout(() => setRinging(false), 1600);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [snapped]);
  const home = pull < 8;
  useEffect(() => {
    if (home) setSlipped(false);
  }, [home]);
  useEffect(() => () => window.clearTimeout(ringTimer.current), []);

  // Redraw every frame while the string rings or the arc spins.
  useClock(!held && (ringing || pull > 6), fps);
  const now = performance.now() / 1000;

  /** Deflection carried by harmonic `n` at `t` seconds after the snap: a damped cosine at n × the pitch. */
  const mode = (n: number, t: number) => (ringing ? snapSag.current * Math.exp(-decay * Math.pow(n, 1.3) * t) * Math.cos(2 * Math.PI * pitch * n * t) : 0);
  const t = Math.max(now - snapTime.current, 0);

  // Bead: the pop when it slips off, and the ring opening into an arc (easeOut 0.2 s).
  const popE = useElapsed(snaps, 1.2, true);
  const pop = popE < 0 ? 1 : track(popE, 1, [{ cubic: 1.35, d: 0.09 }, { spring: 1, d: 0.45, ...SPRINGS.bouncy }]);
  const spinning = !held;
  const openE = useElapsed(spinning, 0.2, true);
  const open = openE < 0 ? 1 : ease.out(progress(openE, 0, 0.2));
  const trim = spinning ? mix(1, 0.72, open) : mix(0.72, 1, open);
  const beadColour = spinning ? (heldColour.current.map((v, i) => mix(v, INDIGO[i], open)) as [number, number, number]) : heldColour.current;
  const absolute = now + performance.timeOrigin / 1000;
  const turn = spinning ? ((absolute / 0.75) % 1) * 360 : 0;
  const circumference = 2 * Math.PI * 9;

  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: 300, height: 90, opacity: pull > 6 ? 1 : 0 }}>
      <svg width={300} height={90} viewBox="0 0 300 90" style={{ position: "absolute", inset: 0, overflow: "visible" }}>
        {held ? (
          <path d={threadPath(sag, sag, sag)} fill="none" stroke={rgb(threadRGB(tension))} strokeWidth={3.2 - 1.4 * tension} strokeLinecap="round" strokeLinejoin="round" />
        ) : (
          <path d={threadPath(mode(1, t), mode(3, t), mode(5, t))} fill="none" stroke={Palette.indigo} strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" />
        )}
        {/* Pins */}
        <circle cx={28} cy={ANCHOR_Y} r={2.5} fill={Palette.labelAlpha(0.35)} />
        <circle cx={272} cy={ANCHOR_Y} r={2.5} fill={Palette.labelAlpha(0.35)} />
      </svg>
      {/* Bead: a closed ring on the thread, an open spinning arc once it has slipped off. */}
      <div style={{ position: "absolute", left: 141, top: beadY - 9, width: 18, height: 18, transform: `scale(${pop})` }}>
        <svg width={18} height={18} viewBox="0 0 18 18" style={{ overflow: "visible" }}>
          <circle cx={9} cy={9} r={9} fill={Palette.surface} />
          <circle
            cx={9}
            cy={9}
            r={9}
            fill="none"
            stroke={rgb(beadColour)}
            strokeWidth={3}
            strokeLinecap={trim < 0.999 ? "round" : "butt"}
            strokeDasharray={trim < 0.999 ? `${circumference * trim} ${circumference}` : undefined}
            transform={`rotate(${turn - 90} 9 9)`}
          />
        </svg>
      </div>
    </div>
  );
}
