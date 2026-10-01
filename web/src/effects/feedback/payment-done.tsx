/** feedback.payment-done · 支付完成 (Feedback+PaymentDone.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, delayed, demoCard, ease, fonts, hex, useAutoplay, useClock, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track } from "./shared";

type Phase = "idle" | "processing" | "closing" | "done";

const BLUE = hex(0x0a84ff);
const CLOSE_DURATION = 0.35;
const TURNS_PER_SECOND = 1.4;
const R = 36;
const LENGTH = 2 * Math.PI * R;
const now = () => performance.now() / 1000;

export default function PaymentDone({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [phase, setPhase] = useState<Phase>("idle");
  const [phaseT, setPhaseT] = useState<Transition>(anim.easeOut(0.2));
  const [completions, setCompletions] = useState(0);
  const phaseRef = useRef<Phase>("idle");
  const spinStart = useRef(0);
  const closeStart = useRef(0);
  /** The arc's clock when the timeline paused (ring whole). */
  const frozen = useRef(0);
  const go = (next: Phase, t: Transition) => {
    phaseRef.current = next;
    setPhaseT(t);
    setPhase(next);
  };

  const pay = (buzz = true) => {
    const current = phaseRef.current;
    if (current === "processing" || current === "closing") return;
    clearAll();
    if (current === "done") {
      go("idle", anim.smoothD(0.3));
      return;
    }
    const live = !ctx.isPreview;
    const processing = ctx.n("processing");
    const draw = ctx.n("draw");
    if (buzz) haptics.tap();
    spinStart.current = now();
    go("processing", anim.easeOut(0.2));
    after(processing, () => {
      closeStart.current = now();
      go("closing", anim.easeOut(0.2));
      if (buzz) haptics.tap("light");
      after(CLOSE_DURATION, () => {
        frozen.current = now();
        setCompletions((n) => n + 1);
        go("done", delayed(anim.easeOut(0.3), 0.12));
        after(draw + 0.04, () => {
          if (buzz) haptics.success();
          if (live) return;
          after(2.0, () => go("idle", anim.smoothD(0.3)));
        });
      });
    });
  };

  useAutoplay(ctx.isPreview, () => pay(false), { every: ctx.n("processing") + 3.6, delay: 0.5 });

  const idle = phase === "idle";
  const done = phase === "done";
  const running = phase === "processing" || phase === "closing";
  useClock(running, ctx.isPreview ? 30 : undefined);

  // The spinner arc: spins on the time since the tap; once closing, its tail runs ahead until the ring is whole.
  const t = running ? now() : frozen.current;
  const elapsed = Math.max(t - spinStart.current, 0);
  const breathing = 0.26 + 0.08 * Math.sin(elapsed * 4.2);
  const grow = Math.min(elapsed / 0.25, 1);
  let sweep = breathing * grow;
  if (phase === "closing") {
    const u = Math.min(Math.max((t - closeStart.current) / CLOSE_DURATION, 0), 1);
    sweep += (1 - sweep) * (1 - (1 - u) ** 3);
  }
  if (done) sweep = 1;
  const arcAngle = elapsed * TURNS_PER_SECOND * 360 - 90;

  const c = useElapsed(completions, 1.4, true);
  const nod = c < 0 ? 0 : track(c, 0, [{ cubic: -14, d: 0.16 }, { spring: 0, d: 0.6, ...SPRINGS.bouncy }]);
  const pulse = c < 0 ? 1 : track(c, 1, [{ cubic: 1.1, d: 0.12 }, { spring: 1, d: 0.5, response: 0.35, damping: 0.5 }]);
  const bloomScale = c < 0 ? 1.9 : track(Math.min(c, 0.6), 1.9, [{ move: 0.7 }, { cubic: 1.9, d: 0.6 }]);
  const bloomOpacity = c < 0 ? 0 : 0.9 * (1 - ease.out(Math.min(c / 0.6, 1)));
  const idleT = idle ? phaseT : anim.easeOut(0.2);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div onClick={() => pay()} style={{ ...demoCard(30), width: 280, height: 300, flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "center", cursor: "pointer" }}>
        {/* Mini card */}
        <div style={{ marginTop: 26, perspective: 104 / 0.7, flexShrink: 0 }}>
          <div
            style={{
              position: "relative",
              width: 104,
              height: 66,
              borderRadius: 10,
              transform: `rotateX(${nod}deg)`,
              background: `linear-gradient(${90 + (Math.atan2(66, 104) * 180) / Math.PI}deg, ${hex(0x2e3a59)}, ${hex(0x0e1220)})`,
              boxShadow: `inset 0 0 0 0.5px ${white(0.14)}, 0 5px 8px ${black(0.22)}`,
            }}
          >
            <div style={{ position: "absolute", left: 10, top: 12, width: 17, height: 13, borderRadius: 3, background: `linear-gradient(${hex(0xffe39a)}, ${hex(0xd9a441)})` }} />
            <span style={{ position: "absolute", left: 10, bottom: 8, fontFamily: fonts.mono, fontSize: 9, lineHeight: "11px", fontWeight: 600, color: white(0.85), whiteSpace: "pre" }}>•••• 4821</span>
          </div>
        </div>
        <span style={{ marginTop: 14, fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>{zh ? "街角咖啡" : "Corner Café"}</span>
        <span style={{ marginTop: 1, fontFamily: fonts.rounded, fontSize: 32, lineHeight: "38px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{zh ? "¥58.00" : "$8.50"}</span>

        {/* Indicator */}
        <div style={{ position: "relative", width: 72, height: 72, marginTop: 18, flexShrink: 0, transform: `scale(${pulse})` }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: BLUE, filter: "blur(16px)", transform: `scale(${bloomScale})`, opacity: bloomOpacity * ctx.n("bloom") }} />
          <svg width={72} height={72} viewBox="0 0 72 72" style={{ position: "absolute", inset: 0, overflow: "visible" }}>
            <motion.circle cx={36} cy={36} r={R} fill="none" stroke={Palette.labelAlpha(0.09)} strokeWidth={5} initial={false} animate={{ opacity: done ? 0 : 1 }} transition={phaseT} />
            <motion.g initial={false} animate={{ opacity: idle ? 0 : 1 }} transition={idleT}>
              <circle
                cx={36}
                cy={36}
                r={R}
                fill="none"
                stroke={BLUE}
                strokeWidth={5}
                strokeLinecap="round"
                strokeDasharray={sweep >= 1 ? undefined : `${LENGTH * sweep} ${LENGTH}`}
                transform={`rotate(${arcAngle} 36 36)`}
              />
            </motion.g>
          </svg>
          {/* wave.3.right */}
          <motion.div initial={false} animate={{ scale: idle ? 1 : 0.4, opacity: idle ? 1 : 0 }} transition={idleT} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
            <motion.svg width={34} height={34} viewBox="0 0 30 30" animate={{ opacity: [1, 0.45] }} transition={{ duration: 0.9, ease: [0.42, 0, 0.58, 1], repeat: Infinity, repeatType: "reverse" }}>
              <g fill="none" stroke={BLUE} strokeWidth={2.9} strokeLinecap="round">
                <path d="M7 10.8 a6.2 6.2 0 0 1 0 8.4" />
                <path d="M12.6 6.6 a12.2 12.2 0 0 1 0 16.8" />
                <path d="M18.2 2.6 a18.4 18.4 0 0 1 0 24.8" />
              </g>
            </motion.svg>
          </motion.div>
          <svg width={30} height={23} viewBox="0 0 30 23" style={{ position: "absolute", left: 21, top: 24.5, overflow: "visible" }}>
            <motion.path
              d="M0 12.65 L10.8 23 L30 0"
              fill="none"
              stroke={BLUE}
              strokeWidth={5.5}
              strokeLinecap="round"
              strokeLinejoin="round"
              initial={false}
              animate={{ pathLength: done ? 1 : 0, opacity: done ? 1 : 0 }}
              transition={
                done
                  ? { pathLength: delayed(anim.easeOut(ctx.n("draw")), 0.04), opacity: { duration: 0.01, delay: 0.04 } }
                  : { pathLength: anim.linear(0.08), opacity: { duration: 0.01, delay: 0.08 } }
              }
            />
          </svg>
        </div>

        {/* Caption */}
        <div style={{ position: "relative", width: 200, height: 22, marginTop: 12, flexShrink: 0, fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>
          <AnimatePresence initial={false}>
            {idle && (
              <motion.span key="idle" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseT} style={{ position: "absolute", inset: 0, textAlign: "center", color: Palette.secondaryLabel }}>
                {zh ? "轻点付款" : "Tap to Pay"}
              </motion.span>
            )}
            {running && (
              <motion.span key="busy" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={phaseT} style={{ position: "absolute", inset: 0, textAlign: "center", color: Palette.secondaryLabel }}>
                {zh ? "处理中" : "Processing"}
              </motion.span>
            )}
            {done && (
              <motion.span
                key="done"
                initial={{ opacity: 0, y: 10, filter: "blur(5px)" }}
                animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                exit={{ opacity: 0, y: 10, filter: "blur(5px)" }}
                transition={phaseT}
                style={{ position: "absolute", inset: 0, textAlign: "center", color: BLUE }}
              >
                {zh ? "完成" : "Done"}
              </motion.span>
            )}
          </AnimatePresence>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to pay" zh="点击付款" />
    </div>
  );
}
