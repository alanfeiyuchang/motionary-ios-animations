/** gestures.answer-call · 滑动接听 (Gestures+AnswerCall.swift) */
import { animate, motion, useAnimationControls, useMotionValue, useMotionValueEvent } from "motion/react";
import { ChevronLeft, ChevronRight, Phone, User } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, alpha, black, fonts, hex, rubberBand, spring, useAutoplay, useClock, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { useGhost } from "./_sim-kit";

const CARD = { w: 270, h: 288 };
const TRACK = { w: 238, h: 62 };
const HANDLE = 54;
const TRAVEL = 88;
const GREEN = "#30D158";
const RED = "#FF453A";

type CallState = "ringing" | "answered" | "declined";

export default function AnswerCall({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  /** −1 = fully at decline, +1 = fully at answer. */
  const progress = useMotionValue(0);
  const [p, setP] = useState(0);
  const [state, setState] = useState<CallState>("ringing");
  const [armed, setArmed] = useState(0);
  const [held, setHeld] = useState(false);
  const [answeredAt, setAnsweredAt] = useState(0);
  const [stateSpring, setStateSpring] = useState(() => spring(0.4, 0.7));
  const s = useRef({ state: "ringing" as CallState, armed: 0, held: false, autoStep: 0, reset: 0, tapMoved: false, target: 0 }).current;
  const shake = useAnimationControls();
  const time = useClock(true, 30);

  useMotionValueEvent(progress, "change", setP);

  const setCall = (next: CallState, t: ReturnType<typeof spring>) => {
    s.state = next;
    setStateSpring(t);
    setState(next);
  };
  const setArm = (v: number) => {
    s.armed = v;
    setArmed(v);
  };
  const setHold = (v: boolean) => {
    s.held = v;
    setHeld(v);
  };

  /** The finger (or the scripted one) is `translation` points from where it took the handle. */
  const dragChanged = (translation: number, scripted = false) => {
    const raw = translation / TRAVEL;
    const sign = raw < 0 ? -1 : 1;
    progress.stop();
    const value = Math.abs(raw) <= 1 ? raw : sign * (1 + rubberBand(Math.abs(raw) - 1, 0.12));
    progress.set(value);
    s.target = value;
    const threshold = ctx.n("threshold");
    const nowArmed = value >= threshold ? 1 : value <= -threshold ? -1 : 0;
    if (nowArmed !== s.armed) {
      setArm(nowArmed);
      if (!scripted) haptics.tap("light");
    }
  };

  /** A new call comes in: the handle returns to the centre. */
  const ringAgain = (delay: number) => {
    window.clearTimeout(s.reset);
    s.reset = window.setTimeout(() => {
      const t = spring(0.5, 0.8);
      animate(progress, 0, t);
      s.target = 0;
      setCall("ringing", t);
    }, delay * 1000);
  };

  const release = (velocity: number, scripted = false) => {
    setHold(false);
    if (s.state !== "ringing") return;
    const value = s.target;
    const flick = velocity > 650 && value > 0.2 ? 1 : velocity < -650 && value < -0.2 ? -1 : 0;
    const outcome = s.armed !== 0 ? s.armed : flick;
    const t = spring(ctx.n("response"), ctx.n("damping"));
    if (outcome > 0) {
      setAnsweredAt(performance.now() / 1000);
      animate(progress, 1, t);
      s.target = 1;
      setCall("answered", t);
      setArm(0);
      if (!scripted) haptics.success();
    } else if (outcome < 0) {
      animate(progress, -1, t);
      s.target = -1;
      setCall("declined", t);
      setArm(0);
      void shake.start({ x: [0, -9, 8, -5, 3, 0], transition: { duration: 0.39, times: [0, 0.07 / 0.39, 0.16 / 0.39, 0.24 / 0.39, 0.31 / 0.39, 1], ease: "easeInOut" } });
      if (!scripted) haptics.error();
      ringAgain(1.5);
    } else {
      animate(progress, 0, t);
      s.target = 0;
      setArm(0);
    }
  };

  const hangUp = (scripted = false) => {
    if (s.state !== "answered") return;
    setCall("declined", spring(ctx.n("response"), 0.85));
    if (!scripted) haptics.tap("rigid");
    ringAgain(0.9);
  };

  const pan = usePan(
    {
      onStart: () => {
        s.tapMoved = true;
      },
      onChange: ({ translation }) => {
        if (s.state !== "ringing") return;
        if (!s.held) {
          setHold(true);
          ghost.touch();
        }
        dragChanged(translation.x);
      },
      onEnd: ({ velocity }) => {
        if (s.held) release(velocity.x);
      },
    },
    2,
  );

  /** A scripted finger slides the handle: to answer one time, to decline the next. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.held) return;
      if (s.state === "answered") {
        hangUp(true);
        return;
      }
      if (s.state !== "ringing") return;
      s.autoStep += 1;
      const direction = s.autoStep % 2 === 1 ? 1 : -1;
      ghost.run(async (g) => {
        if (!(await g.drag({ x: 0, y: 0 }, { x: direction * TRAVEL * 0.94, y: 0 }, 0.7, (pt) => dragChanged(pt.x, true)))) return;
        if (!(await g.sleep(0.1))) return;
        release(0, true);
      });
    },
    { every: 3.4, delay: 0.7 },
  );

  const ringing = state === "ringing";
  const amount = Math.min(Math.abs(p), 1);
  const positive = p >= 0;
  // After the call is answered the handle becomes the hang-up button.
  const hang = !ringing;
  const tint = hang ? RED : positive ? GREEN : RED;
  const fillAmount = hang ? 0 : amount;
  const handleAmount = hang ? 1 : amount;
  const turn = hang || !positive ? 135 * handleAmount : 0;

  // Header rings.
  const period = Math.max(ctx.n("pulse"), 0.2);
  // Ringer: shivers in short bursts, like a ringing phone.
  const ringerOn = ringing && !held && handleAmount < 0.05;
  const cycle = time / 1.4 - Math.floor(time / 1.4);
  const envelope = ringerOn && cycle < 0.45 ? Math.sin((cycle / 0.45) * Math.PI) : 0;
  const shiver = Math.sin(time * 46) * 13 * envelope;
  const chevronsOn = ringing && !held;
  const chevronCycle = time / 1.3 - Math.floor(time / 1.3);
  const seconds = state === "answered" ? Math.max(Math.floor(performance.now() / 1000 - answeredAt), 0) : 0;
  const glow = state === "declined" ? RED : GREEN;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <motion.div animate={shake} style={{ flex: "none" }}>
        <motion.div
          initial={false}
          animate={{ filter: `brightness(${state === "declined" ? 0.94 : 1})` }}
          transition={stateSpring}
          style={{ position: "relative", width: CARD.w, height: CARD.h, borderRadius: 34, overflow: "hidden", boxShadow: `0 10px 18px ${black(0.25)}`, background: "linear-gradient(180deg, #1D2B3A, #0E1220)" }}
        >
          <motion.div
            initial={false}
            animate={{ backgroundColor: glow, opacity: ringing ? 0.14 : 0.24 }}
            transition={stateSpring}
            style={{ position: "absolute", left: CARD.w / 2 - 120, top: CARD.h / 2 - 70 - 120, width: 240, height: 240, borderRadius: "50%", filter: "blur(60px)" }}
          />
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
            {/* Header */}
            <div style={{ position: "relative", height: 112, marginTop: 14, alignSelf: "stretch" }}>
              {[0, 1, 2].map((index) => {
                const raw = time / period + index / 3;
                const phase = ringing ? raw - Math.floor(raw) : 0;
                return (
                  <div
                    key={index}
                    style={{
                      position: "absolute",
                      left: CARD.w / 2 - 37,
                      top: 56 - 37,
                      width: 74,
                      height: 74,
                      borderRadius: "50%",
                      boxShadow: `0 0 0 ${0.75 / (1 + 0.95 * phase)}px ${white(ringing ? 0.34 * (1 - phase) : 0)}, inset 0 0 0 ${0.75 / (1 + 0.95 * phase)}px ${white(ringing ? 0.34 * (1 - phase) : 0)}`,
                      transform: `scale(${1 + 0.95 * phase})`,
                    }}
                  />
                );
              })}
              <motion.div
                initial={false}
                animate={{ opacity: state === "answered" ? 1 : 0 }}
                transition={stateSpring}
                style={{ position: "absolute", left: CARD.w / 2 - 43.5, top: 56 - 43.5, width: 87, height: 87, borderRadius: "50%", border: `3px solid ${alpha(GREEN, 0.9)}`, boxShadow: `0 0 8px ${alpha(GREEN, 0.8)}, inset 0 0 8px ${alpha(GREEN, 0.4)}` }}
              />
              <motion.div
                initial={false}
                animate={{ filter: `saturate(${state === "declined" ? 0.2 : 1})` }}
                transition={stateSpring}
                style={{ position: "absolute", left: CARD.w / 2 - 36, top: 56 - 36, width: 72, height: 72, borderRadius: "50%", background: "linear-gradient(135deg, #FFB36B, #FF6B8B)", display: "grid", placeItems: "center", color: white(0.92) }}
              >
                <User size={38} fill="currentColor" strokeWidth={0} />
              </motion.div>
            </div>
            <div style={{ marginTop: 2, fontFamily: fonts.rounded, fontSize: 22, lineHeight: "26px", fontWeight: 600, color: "#fff" }}>{ctx.t("Mina Park", "林小敏")}</div>
            <div style={{ position: "relative", marginTop: 3, height: 20, alignSelf: "stretch", fontSize: 13, fontWeight: 500 }}>
              {(["ringing", "declined", "answered"] as CallState[]).map((kind) => (
                <motion.div
                  key={kind}
                  initial={false}
                  animate={{ opacity: state === kind ? 1 : 0 }}
                  transition={stateSpring}
                  style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: kind === "ringing" ? white(0.62) : kind === "declined" ? RED : GREEN }}
                >
                  {kind === "ringing" ? ctx.t("Incoming call", "来电") : kind === "declined" ? ctx.t("Call ended", "通话已结束") : <NumericText value={seconds} text={`${String(Math.floor(seconds / 60)).padStart(2, "0")}:${String(seconds % 60).padStart(2, "0")}`} />}
                </motion.div>
              ))}
            </div>
            <div style={{ flex: 1 }} />

            {/* Slider */}
            <div style={{ position: "relative", width: TRACK.w, height: TRACK.h, marginBottom: 18, borderRadius: TRACK.h / 2, background: white(0.1), boxShadow: `inset 0 0 0 1px ${white(0.12)}` }}>
              {/* Colour floods from the centre to the handle. */}
              <div
                style={{
                  position: "absolute",
                  top: (TRACK.h - HANDLE - 8) / 2,
                  height: HANDLE + 8,
                  width: HANDLE + 8 + fillAmount * TRAVEL,
                  left: TRACK.w / 2 - (HANDLE + 8 + fillAmount * TRAVEL) / 2 + ((positive ? 1 : -1) * fillAmount * TRAVEL) / 2,
                  borderRadius: (HANDLE + 8) / 2,
                  background: hex(tint, 0.28 + 0.5 * fillAmount),
                  opacity: Math.min(fillAmount * 4, 1),
                }}
              />
              {/* Chevrons streaming away from the centre on both sides. */}
              <motion.div
                initial={false}
                animate={{ opacity: ringing ? 1 : 0 }}
                transition={stateSpring}
                style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: HANDLE + 22 }}
              >
                {[true, false].map((reversed) => (
                  <div key={String(reversed)} style={{ display: "flex", gap: 3, opacity: 1 - amount }}>
                    {[0, 1, 2].map((index) => {
                      // The wave leaves the handle: the chevron nearest to it lights first.
                      const order = reversed ? 2 - index : index;
                      const phase = chevronCycle - order * 0.16;
                      const wave = chevronsOn ? Math.max(0, 1 - Math.abs(phase - 0.3) / 0.3) : 0.4;
                      const Icon = reversed ? ChevronLeft : ChevronRight;
                      return <Icon key={index} size={12} strokeWidth={3.6} color={white(0.18 + 0.6 * wave)} style={{ margin: "0 -2px" }} />;
                    })}
                  </div>
                ))}
              </motion.div>
              {/* The voice level shown in the track while the call is connected. */}
              <motion.div
                initial={false}
                animate={{ opacity: state === "answered" ? 1 : 0 }}
                transition={stateSpring}
                style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 4, transform: "translateX(-26px)" }}
              >
                {Array.from({ length: 18 }, (_, index) => {
                  // Two beating sines per bar give an uneven, speech-like level.
                  const level = state === "answered" ? 0.5 + 0.5 * Math.sin(time * 6.3 + index * 0.9) * Math.sin(time * 2.1 + index * 0.37) : 0.35;
                  return <div key={index} style={{ width: 3, height: 5 + 22 * Math.max(level, 0.05), borderRadius: 1.5, background: alpha(GREEN, 0.85) }} />;
                })}
              </motion.div>
              <motion.div
                initial={false}
                animate={{ opacity: ringing ? 1 : 0 }}
                transition={stateSpring}
                style={{ position: "absolute", inset: 0, padding: "0 20px", display: "flex", alignItems: "center", justifyContent: "space-between" }}
              >
                <motion.div initial={false} animate={{ scale: armed < 0 ? 1.25 : 1 }} transition={spring(0.28, 0.55)} style={{ color: RED, display: "grid" }}>
                  <Phone size={21} fill="currentColor" strokeWidth={0} style={{ transform: "rotate(135deg)" }} />
                </motion.div>
                <motion.div initial={false} animate={{ scale: armed > 0 ? 1.25 : 1 }} transition={spring(0.28, 0.55)} style={{ color: GREEN, display: "grid" }}>
                  <Phone size={21} fill="currentColor" strokeWidth={0} />
                </motion.div>
              </motion.div>

              {/* Handle; the touch target rides with it. */}
              <div
                {...pan}
                onClick={() => {
                  const moved = s.tapMoved;
                  s.tapMoved = false;
                  if (!moved && s.state === "answered") {
                    ghost.touch();
                    hangUp();
                  }
                }}
                style={{
                  ...pan.style,
                  position: "absolute",
                  left: TRACK.w / 2 - (HANDLE + 16) / 2,
                  top: TRACK.h / 2 - (HANDLE + 16) / 2,
                  width: HANDLE + 16,
                  height: HANDLE + 16,
                  borderRadius: "50%",
                  transform: `translateX(${p * TRAVEL}px)`,
                  display: "grid",
                  placeItems: "center",
                  cursor: "grab",
                }}
              >
                <motion.div
                  initial={false}
                  animate={{ scale: held ? 1.06 : 1 }}
                  transition={spring(0.25, 0.6)}
                  style={{ position: "relative", width: HANDLE, height: HANDLE, borderRadius: "50%", background: "#fff", boxShadow: `0 0 10px ${hex(tint, 0.55 * handleAmount)}, 0 3px 6px ${black(0.3)}` }}
                >
                  <motion.div initial={false} animate={{ backgroundColor: tint }} transition={stateSpring} style={{ position: "absolute", inset: 0, borderRadius: "50%", opacity: handleAmount }} />
                  <div style={{ position: "absolute", inset: 0, transform: `rotate(${shiver}deg)` }}>
                    <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", transform: `rotate(${turn}deg)` }}>
                      <Phone size={24} fill="#1D2B3A" strokeWidth={0} style={{ gridArea: "1 / 1", opacity: 1 - handleAmount }} />
                      <Phone size={24} fill="#fff" strokeWidth={0} style={{ gridArea: "1 / 1", opacity: handleAmount }} />
                    </div>
                  </div>
                </motion.div>
              </div>
            </div>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: 34, boxShadow: `inset 0 0 0 1px ${white(0.1)}`, pointerEvents: "none" }} />
        </motion.div>
      </motion.div>
      <DemoHint ctx={ctx} en={state === "answered" ? "Tap the red handle to hang up" : "Slide right to answer, left to decline"} zh={state === "answered" ? "点击红色滑块挂断" : "右滑接听，左滑拒接"} />
    </div>
  );
}
