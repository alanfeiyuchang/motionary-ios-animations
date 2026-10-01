/** buttons.hold-record · 长按录制 (Buttons+HoldRecord.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, fonts, hex, spring, useAutoplay, useClock, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useLongPress, useSince } from "./_a-kit";
import { nowSeconds } from "./_c-kit";

type Phase = "idle" | "recording" | "saved";

function clockText(seconds: number) {
  const tenths = Math.floor(seconds * 10);
  return `0:${String(Math.floor(tenths / 10)).padStart(2, "0")}.${tenths % 10}`;
}

export default function HoldRecord({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const limitT = useTimeouts();
  const resetT = useTimeouts();
  const script = useTimeouts();
  const tick = useRef(0);
  const phaseRef = useRef<Phase>("idle");
  const [phase, setPhaseState] = useState<Phase>("idle");
  const [tr, setTr] = useState<Transition>(spring(0.32, 0.7));
  const startedAt = useRef(0);
  const [savedLength, setSavedLength] = useState(0);
  const [pops, setPops] = useState(0);
  const limit = Math.max(ctx.n("limit"), 0.5);
  const params = useRef({ limit, response: 0.32 });
  params.current = { limit, response: ctx.n("response") };

  const setPhase = (p: Phase, t: Transition) => {
    phaseRef.current = p;
    setTr(t);
    setPhaseState(p);
  };

  const finish = (buzz: boolean) => {
    if (phaseRef.current !== "recording") return;
    limitT.clearAll();
    window.clearInterval(tick.current);
    const length = Math.min(nowSeconds() - startedAt.current, params.current.limit);
    if (length < 0.35) {
      setPhase("idle", spring(0.3, 0.55));
      return;
    }
    setSavedLength(length);
    setPops((p) => p + 1);
    setPhase("saved", spring(0.34, 0.55));
    if (buzz) haptics.success();
    resetT.clearAll();
    resetT.after(1.5, () => setPhase("idle", anim.smoothD(0.3)));
  };
  const begin = (buzz: boolean) => {
    if (phaseRef.current === "recording") return;
    resetT.clearAll();
    startedAt.current = nowSeconds();
    setPhase("recording", spring(params.current.response, 0.7));
    if (buzz) haptics.tap("medium");
    limitT.clearAll();
    limitT.after(params.current.limit, () => finish(buzz));
    window.clearInterval(tick.current);
    if (!buzz) return;
    tick.current = window.setInterval(() => haptics.tap("soft"), 1000);
  };
  const playScript = () => {
    if (phaseRef.current !== "idle") return;
    script.clearAll();
    begin(false);
    script.after(2.2, () => finish(false));
  };
  useAutoplay(ctx.isPreview, playScript, { every: 4.6, delay: 0.4 });

  const longPress = useLongPress({
    duration: 600,
    maximumDistance: 80,
    onComplete: () => {},
    onPressingChanged: (pressing) => {
      script.clearAll();
      if (pressing) begin(true);
      else finish(true);
    },
  });

  const recording = phase === "recording";
  useClock(recording, ctx.isPreview ? 30 : undefined);
  const elapsed = recording ? Math.min(nowSeconds() - startedAt.current, limit) : 0;
  const pulse = recording ? 0.5 + 0.5 * Math.sin(elapsed * 2 * Math.PI - Math.PI / 2) : 0;
  const grow = recording ? ctx.n("ring") : 1;
  const pt = useSince(pops, 0.65);
  const pop = track(pt, 1, [cubicKF(1.14, 0.1), springKF(1, 0.5, BOUNCY)]);
  const C = 2 * Math.PI * 38;
  const frac = recording ? elapsed / limit : 0;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 26, flexShrink: 0 }}>
        <div style={{ position: "relative", height: 34, width: 240 }}>
          <AnimatePresence initial={false}>
            {phase === "saved" ? (
              <motion.div
                key="saved"
                initial={{ scale: 0.7, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                exit={{ scale: 0.7, opacity: 0 }}
                transition={tr}
                style={{ position: "absolute", inset: 0, display: "flex", justifyContent: "center" }}
              >
                <div
                  style={{
                    height: 34,
                    padding: "0 14px",
                    borderRadius: 17,
                    background: Palette.successStrong,
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                    color: "#fff",
                    fontSize: 15,
                    fontWeight: 600,
                    whiteSpace: "nowrap",
                  }}
                >
                  <svg viewBox="0 0 24 24" width={17} height={17}>
                    <circle cx="12" cy="12" r="10.5" fill="#fff" />
                    <path d="M7.4 12.3l3.1 3.1 6.1-6.5" fill="none" stroke={Palette.successStrong} strokeWidth={2.3} strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                  <span>{ctx.t("Saved", "已保存")}</span>
                  <span style={{ opacity: 0.8, fontVariantNumeric: "tabular-nums" }}>{clockText(savedLength)}</span>
                </div>
              </motion.div>
            ) : (
              <motion.div
                key="timer"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={tr}
                style={{ position: "absolute", inset: 0, display: "flex", justifyContent: "center" }}
              >
                <motion.div
                  initial={false}
                  animate={{ opacity: recording ? 1 : 0, scale: recording ? 1 : 0.85 }}
                  transition={tr}
                  style={{ height: 34, padding: "0 14px", borderRadius: 17, background: alpha(Palette.red, 0.14), display: "flex", alignItems: "center", gap: 8 }}
                >
                  <div style={{ width: 8, height: 8, borderRadius: 4, background: Palette.red, opacity: elapsed % 1 < 0.6 ? 1 : 0.25 }} />
                  <NumericText
                    value={Math.floor(elapsed * 10)}
                    text={clockText(elapsed)}
                    style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "22px", fontWeight: 600, color: Palette.label }}
                  />
                  <div style={{ display: "flex", alignItems: "center", gap: 2.5, height: 18 }}>
                    {[0, 1, 2, 3, 4].map((index) => {
                      const ph = index * 1.9;
                      const level = 0.5 + 0.3 * Math.sin(elapsed * 9 + ph) + 0.2 * Math.sin(elapsed * 15.3 + ph * 2.1);
                      return <div key={index} style={{ width: 2.5, height: 4 + 12 * Math.max(level, 0.05), borderRadius: 1.25, background: Palette.red }} />;
                    })}
                  </div>
                </motion.div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
        <div {...longPress} role="button" style={{ ...longPress.style, position: "relative", width: 130, height: 130, borderRadius: "50%", transform: `scale(${pop})` }}>
          <motion.div
            initial={false}
            animate={{ scale: grow, opacity: recording ? 1 : 0 }}
            transition={tr}
            style={{ position: "absolute", left: 23, top: 23, width: 84, height: 84 }}
          >
            <div style={{ width: 84, height: 84, borderRadius: "50%", background: alpha(Palette.red, 0.16), transform: `scale(${1.12 + 0.14 * pulse})` }} />
          </motion.div>
          <motion.div
            initial={false}
            animate={{ scale: grow, opacity: recording ? 0.14 : 0.85 }}
            transition={tr}
            style={{ position: "absolute", left: 23, top: 23, width: 84, height: 84, borderRadius: "50%", boxShadow: `inset 0 0 0 4px ${Palette.label}` }}
          />
          <motion.svg
            initial={false}
            animate={{ scale: grow, opacity: recording ? 1 : 0 }}
            transition={tr}
            width={84}
            height={84}
            viewBox="0 0 84 84"
            style={{ position: "absolute", left: 23, top: 23, overflow: "visible" }}
          >
            {frac > 0.0005 && (
              <circle cx={42} cy={42} r={38} fill="none" stroke={Palette.red} strokeWidth={4} strokeLinecap="round" strokeDasharray={`${C * frac} ${C}`} transform="rotate(-90 42 42)" />
            )}
          </motion.svg>
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
            <motion.div
              initial={false}
              animate={{ width: recording ? 30 : 60, height: recording ? 30 : 60, borderRadius: recording ? 9 : 30 }}
              transition={tr}
              style={{ background: `linear-gradient(180deg, ${hex(0xff6a6f)}, ${Palette.red})`, boxShadow: `0 4px 8px ${alpha(Palette.red, 0.4)}` }}
            />
          </div>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Hold to record, release to save" zh="按住录制，松手保存" style={{ paddingBottom: 18 }} />
    </div>
  );
}
