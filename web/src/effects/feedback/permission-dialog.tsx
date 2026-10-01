/** feedback.permission-dialog · 权限请求弹窗 (Feedback+PermissionDialog.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { Bell, BellOff, Navigation, NavigationOff } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, pressHandlers, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { FeedbackMockHeader, FeedbackMockRows, FeedbackScene } from "./_scene";
import { track } from "./shared";

/** `Palette.primaryStrong` */
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

/** What the surface currently shows; it keeps showing it while it leaves. */
type Face = "question" | "allowed" | "declined";

export default function PermissionDialog({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";
  const location = ctx.i("kind") === 1;
  const [visible, setVisible] = useState(false);
  const [face, setFace] = useState<Face>("question");
  /** Rows of the dialog have risen in. */
  const [settled, setSettled] = useState(false);
  const [rings, setRings] = useState(0);
  /** The button a scripted choice is pressing (0 = allow, 1 = not now). */
  const [forced, setForced] = useState<number | null>(null);
  /** Bumped per presentation: the surface restarts from its small, blurred entrance pose. */
  const [session, setSession] = useState(0);
  const state = useRef({ visible: false, face: "question" as Face, token: 0, autoAllow: true });
  const asking = visible && face === "question";
  const surfaceSpring = spring(0.45, ctx.n("damping"));

  // The icon repeats its little act while the question is open.
  useEffect(() => {
    if (!asking) return;
    let interval = 0;
    const first = window.setTimeout(() => {
      setRings((n) => n + 1);
      interval = window.setInterval(() => setRings((n) => n + 1), 2400);
    }, 450);
    return () => {
      window.clearTimeout(first);
      window.clearInterval(interval);
    };
  }, [asking]);

  const present = () => {
    const s = state.current;
    if (s.visible) return;
    const current = ++s.token;
    haptics.tap();
    // Start from the small, blurred entrance pose (not from where the result pill left).
    s.face = "question";
    setFace("question");
    setSettled(false);
    setSession((n) => n + 1);
    after(0.03, () => {
      if (s.token !== current) return;
      s.visible = true;
      setVisible(true);
      setSettled(true);
    });
  };

  const choose = (allowed: boolean) => {
    const s = state.current;
    if (!(s.visible && s.face === "question")) return;
    const current = ++s.token;
    if (allowed) haptics.success();
    else haptics.tap();
    s.face = allowed ? "allowed" : "declined";
    setFace(s.face);
    after(1.3, () => {
      if (s.token !== current) return;
      s.visible = false;
      setVisible(false);
    });
  };

  /** Preview loop and intro: ask, then answer (allow and decline alternate). */
  const step = () => {
    const s = state.current;
    if (!s.visible) return present();
    if (s.face !== "question") return;
    const allow = s.autoAllow;
    s.autoAllow = !allow;
    const current = ++s.token;
    setForced(allow ? 0 : 1);
    after(0.2, () => {
      setForced(null);
      if (s.token !== current) return;
      choose(allow);
    });
  };
  useAutoplay(ctx.isPreview, step, { every: 2.5, delay: 0.5 });

  const question = face === "question";
  const pageTransition: Transition = visible ? surfaceSpring : anim.easeIn(0.26);
  const hiddenPose = question ? { scale: 0.86, opacity: 0, filter: "blur(8px)", y: 0 } : { scale: 0.94, opacity: 0, filter: "blur(8px)", y: 26 };
  const size = question ? { width: 248, height: 214, borderRadius: 28 } : { width: 196, height: 48, borderRadius: 24 };
  const rise = (index: number) => ({
    initial: { opacity: 0, y: 14 },
    animate: { opacity: settled ? 1 : 0, y: settled ? 0 : 14 },
    transition: settled ? delayed(spring(0.42, 0.78), 0.16 + index * ctx.n("stagger")) : anim.linear(0.01),
  });
  const title = face === "allowed" ? (location ? (zh ? "位置已开启" : "Location on") : zh ? "通知已开启" : "Notifications on") : zh ? "以后再说" : "Maybe later";

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene height={276}>
        <motion.div initial={false} animate={{ filter: visible ? "blur(3px)" : "blur(0px)" }} transition={pageTransition} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
          <FeedbackMockHeader title={zh ? "订单" : "Orders"} symbol={location ? <Navigation size={14} fill="currentColor" strokeWidth={1.5} /> : <Bell size={15} fill="currentColor" strokeWidth={1.5} />} />
          <FeedbackMockRows count={3} rowHeight={48} />
          <div style={{ flex: 1 }} />
          <button type="button" onClick={present} style={{ width: 268, height: 42, borderRadius: 21, background: PRIMARY_STRONG, color: "#fff", fontSize: 15, lineHeight: "20px", fontWeight: 600, marginBottom: 14, flexShrink: 0 }}>
            {location ? (zh ? "查找附近门店" : "Find stores nearby") : zh ? "开启发货提醒" : "Turn on shipping alerts"}
          </button>
        </motion.div>
        <motion.div initial={false} animate={{ opacity: visible ? 0.32 : 0 }} transition={pageTransition} style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: "none" }} />
        <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
          <motion.div
            key={session}
            initial={{ width: 248, height: 214, borderRadius: 28, scale: 0.86, opacity: 0, filter: "blur(8px)", y: 0 }}
            animate={{ ...size, ...(visible ? { scale: 1, opacity: 1, filter: "blur(0px)", y: 0 } : hiddenPose) }}
            transition={visible ? surfaceSpring : anim.easeIn(0.26)}
            style={{ position: "relative", flexShrink: 0, background: Palette.elevated, boxShadow: `0 12px 24px ${black(0.3)}`, pointerEvents: asking ? "auto" : "none" }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: "inherit", overflow: "hidden" }}>
              <AnimatePresence initial={false}>
                {question ? (
                  <motion.div key="q" {...blurReplace} transition={surfaceSpring} style={{ position: "absolute", left: "50%", top: "50%", marginLeft: -124, marginTop: -107, width: 248, height: 214, display: "flex", flexDirection: "column", alignItems: "center" }}>
                    <div style={{ width: 56, height: 56, marginTop: 20, flexShrink: 0 }}>
                      <PermissionIcon location={location} rings={rings} />
                    </div>
                    <motion.div {...rise(0)} style={{ marginTop: 12, fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>
                      {location ? (zh ? "允许使用你的位置？" : "Use your location?") : zh ? "允许发送通知？" : "Allow notifications?"}
                    </motion.div>
                    <motion.div {...rise(1)} style={{ marginTop: 2, width: 204, height: 36, display: "grid", placeItems: "center", textAlign: "center", fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>
                      {location ? (zh ? "用于查找附近门店和预计送达时间。" : "To find nearby stores and delivery times.") : zh ? "订单发货时提醒你，绝不打扰。" : "We'll ping you when an order ships. No spam."}
                    </motion.div>
                    <div style={{ display: "flex", gap: 8, padding: "0 14px", marginTop: 12, alignSelf: "stretch", fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>
                      <motion.div {...rise(2)} style={{ flex: 1 }}>
                        <PressButton forced={forced === 1} onClick={() => choose(false)} style={{ background: Palette.labelAlpha(0.08), color: Palette.label }}>
                          {zh ? "以后再说" : "Not now"}
                        </PressButton>
                      </motion.div>
                      <motion.div {...rise(3)} style={{ flex: 1 }}>
                        <PressButton forced={forced === 0} onClick={() => choose(true)} style={{ background: PRIMARY_STRONG, color: "#fff" }}>
                          {zh ? "允许" : "Allow"}
                        </PressButton>
                      </motion.div>
                    </div>
                  </motion.div>
                ) : (
                  <motion.div key={face} {...blurReplace} transition={surfaceSpring} style={{ position: "absolute", left: "50%", top: "50%", marginLeft: -98, marginTop: -24, width: 196, height: 48, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
                    {face === "allowed" ? (
                      <svg width={22} height={22} viewBox="0 0 22 22">
                        <circle cx={11} cy={11} r={10.5} fill={Palette.green} />
                        <path d="M6.3 11.4l3.2 3.1 6.2-6.7" fill="none" stroke={Palette.elevated} strokeWidth={2.3} strokeLinecap="round" strokeLinejoin="round" />
                      </svg>
                    ) : location ? (
                      <NavigationOff size={20} fill="currentColor" strokeWidth={2} style={{ color: Palette.secondaryLabel }} />
                    ) : (
                      <BellOff size={20} fill="currentColor" strokeWidth={2} style={{ color: Palette.secondaryLabel }} />
                    )}
                    <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{title}</span>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
            <div style={{ position: "absolute", inset: 0, borderRadius: "inherit", boxShadow: `inset 0 0 0 0.5px ${Palette.labelAlpha(0.08)}`, pointerEvents: "none" }} />
          </motion.div>
        </div>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Choose an answer" zh="选一个回答" />
    </div>
  );
}

/** `.transition(.blurReplace)` */
const blurReplace = {
  initial: { opacity: 0, filter: "blur(8px)", scale: 0.9 },
  animate: { opacity: 1, filter: "blur(0px)", scale: 1 },
  exit: { opacity: 0, filter: "blur(8px)", scale: 0.9 },
};

/** PermissionPressStyle: 96% and a touch darker while pressed. */
function PressButton({ forced, onClick, style, children }: { forced: boolean; onClick: () => void; style: React.CSSProperties; children: ReactNode }) {
  const [down, setDown] = useState(false);
  const pressed = down || forced;
  return (
    <motion.button
      type="button"
      onClick={onClick}
      {...pressHandlers(setDown)}
      initial={false}
      animate={{ scale: pressed ? 0.96 : 1, filter: pressed ? "brightness(0.88)" : "brightness(1)" }}
      transition={spring(0.25, 0.7)}
      style={{ width: "100%", height: 40, borderRadius: 20, display: "grid", placeItems: "center", whiteSpace: "nowrap", ...style }}
    >
      {children}
    </motion.button>
  );
}

// MARK: - Icon

/** The tile that acts out the request: a ringing bell or a hopping pin with radar rings. */
function PermissionIcon({ location, rings }: { location: boolean; rings: number }) {
  const e = useElapsed(rings, 1.3, true);
  const idle = e < 0;
  return (
    <div style={{ position: "relative", width: 56, height: 56, borderRadius: 16, background: location ? Palette.ocean : Palette.sunset, boxShadow: `0 5px 10px ${alpha(location ? Palette.blue : Palette.coral, 0.4)}` }}>
      {location ? <Pin e={idle ? 10 : e} /> : <RingingBell e={idle ? 10 : e} />}
      <div style={{ position: "absolute", inset: 0, borderRadius: 16, boxShadow: `inset 0 0 0 1px ${white(0.25)}`, pointerEvents: "none" }} />
    </div>
  );
}

function RingingBell({ e }: { e: number }) {
  const angle = track(e, 0, [
    { cubic: 20, d: 0.09 },
    { cubic: -18, d: 0.13 },
    { cubic: 14, d: 0.13 },
    { cubic: -10, d: 0.13 },
    { cubic: 6, d: 0.13 },
    { cubic: -3, d: 0.13 },
    { cubic: 0, d: 0.14 },
  ]);
  const badge = track(e, 1, [
    { cubic: 0.2, d: 0.05 },
    { spring: 1, d: 0.5, response: 0.3, damping: 0.45 },
  ]);
  const waves = track(e, 0, [
    { linear: 1, d: 0.12 },
    { linear: 1, d: 0.4 },
    { linear: 0, d: 0.36 },
  ]);
  return (
    <>
      {/* PermissionWaves: two short arcs either side of the bell. */}
      <svg width={50} height={22} style={{ position: "absolute", left: 3, top: 13, overflow: "visible", opacity: waves }}>
        <path d="M1.51 19.55 A25 25 0 0 1 1.51 2.45 M48.49 2.45 A25 25 0 0 1 48.49 19.55" fill="none" stroke={white(0.85)} strokeWidth={2} strokeLinecap="round" />
      </svg>
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff", transform: `rotate(${angle}deg)`, transformOrigin: "50% 22%" }}>
        <Bell size={29} fill="currentColor" strokeWidth={1.6} />
      </div>
      <div style={{ position: "absolute", left: 28 + 10 - 5.5, top: 28 - 11 - 5.5, width: 11, height: 11, borderRadius: "50%", background: Palette.red, boxShadow: "inset 0 0 0 1.5px #fff", transform: `scale(${badge})` }} />
    </>
  );
}

function Pin({ e }: { e: number }) {
  const lift = track(e, 0, [
    { cubic: -9, d: 0.16 },
    { spring: 0, d: 0.5, response: 0.3, damping: 0.45 },
  ]);
  // Rests at 0 again once the rings have spread (`MoveKeyframe(0)`).
  const ring = e >= 1.16 ? 0 : track(e, 0, [{ linear: 0, d: 0.26 }, { cubic: 1.3, d: 0.9 }]);
  return (
    <>
      <svg width={56} height={56} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
        {[0, 1].map((index) => {
          const p = Math.min(Math.max(ring - index * 0.3, 0), 1);
          return <ellipse key={index} cx={28} cy={43} rx={(10 + 34 * p) / 2} ry={(4 + 12 * p) / 2} fill="none" stroke="#fff" strokeOpacity={(1 - p) * 0.9} strokeWidth={1.6} />;
        })}
      </svg>
      {/* `mappin`: a ball on a needle. */}
      <svg width={56} height={56} style={{ position: "absolute", inset: 0, transform: `translateY(${lift}px)` }}>
        <path d="M28 24 L28 42" stroke="#fff" strokeWidth={3} strokeLinecap="round" />
        <circle cx={28} cy={20.5} r={7.5} fill="#fff" />
      </svg>
    </>
  );
}
