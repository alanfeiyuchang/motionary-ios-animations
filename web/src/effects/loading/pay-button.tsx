/** loading.pay-button · 支付按钮 (Loading+PayButton.swift) */
import { AnimatePresence, motion } from "motion/react";
import { CircleCheck, CreditCard, Fingerprint, ScanFace } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, ease, pressHandlers, spring, springAt, useAutoplay, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { TrimPath, makeRun, useAnimatedNumber, type Run } from "./shared";

type Stage = "idle" | "processing" | "scanning" | "success" | "receipt";
const SIZES: Record<Stage, [number, number]> = { idle: [236, 58], receipt: [236, 58], processing: [58, 58], scanning: [84, 84], success: [64, 64] };
const cornerOf = (s: Stage) => (s === "scanning" ? 26 : SIZES[s][1] / 2);
const isGreen = (s: Stage) => s === "success" || s === "receipt";
const MORPH = spring(0.45, 0.78);
const SIDE = 46;

export default function PayButton({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [stage, setStageState] = useState<Stage>("idle");
  const stageRef = useRef<Stage>("idle");
  const scan = useAnimatedNumber(0);
  const check = useAnimatedNumber(0);
  const [recognized, setRecognized] = useState(false);
  const [bloom, setBloom] = useState(0);
  const [pressed, setPressed] = useState(false);
  const task = useRef<Run | null>(null);
  const muted = useRef(false);
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  const setStage = (s: Stage) => {
    stageRef.current = s;
    setStageState(s);
  };

  const pay = () => {
    if (stageRef.current === "receipt") {
      task.current?.cancel();
      setStage("idle");
      return;
    }
    if (stageRef.current !== "idle") return;
    const c = latest.current;
    haptics.tap("medium");
    const processing = Math.max(c.n("processing"), 0.1);
    const scanTime = Math.max(c.n("scan"), 0.2);
    const buzz = !c.isPreview && !muted.current;
    const loops = c.isPreview;
    scan.mv.stop();
    scan.mv.set(0);
    check.mv.stop();
    check.mv.set(0);
    setRecognized(false);
    setBloom(0);
    setStage("processing");
    task.current?.cancel();
    const run = makeRun();
    task.current = run;
    (async () => {
      await run.sleep(processing);
      setStage("scanning");
      await run.sleep(0.25);
      scan.to(1, anim.easeInOut(scanTime));
      await run.sleep(scanTime);
      setRecognized(true);
      if (buzz) haptics.tap("light");
      await run.sleep(0.4);
      setStage("success");
      setBloom((v) => v + 1);
      check.to(1, delayed(anim.easeOut(0.3), 0.12));
      if (buzz) haptics.success();
      await run.sleep(1.15);
      setStage("receipt");
      await run.sleep(loops ? 1.4 : 2.4);
      setStage("idle");
    })().catch(() => {});
  };

  // Only an idle button is tapped, so a payment is never cut short; it resets itself.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (stageRef.current !== "idle") return;
      muted.current = true;
      pay();
      muted.current = false;
    },
    { every: 1.0, delay: 0.6 },
  );

  const touchID = ctx.i("biometric") === 1;
  const Glyph = touchID ? Fingerprint : ScanFace;
  const dark = ctx.scheme === "dark";
  const ink = dark ? "#F5F5F7" : "#111114";
  const onInk = dark ? "#111114" : "#FFFFFF";
  const paid = isGreen(stage);
  const [w, h] = SIZES[stage];
  const reveal = SIDE * Math.min(Math.max(scan.value, 0), 1);
  const lineY = touchID ? SIDE / 2 - reveal : reveal - SIDE / 2;
  const lineColor = touchID ? Palette.pink : Palette.mint;
  const layer = { position: "absolute", inset: 0, display: "grid", placeItems: "center" } as const;
  const label = { display: "flex", alignItems: "center", gap: 8, fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18 }}>
      <div
        style={{
          width: 252,
          height: 54,
          padding: "0 13px",
          borderRadius: 18,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
          display: "flex",
          alignItems: "center",
          gap: 11,
          flex: "none",
        }}
      >
        <div style={{ width: 38, height: 28, borderRadius: 8, background: "linear-gradient(135deg, #4B57E0, #7A45D6)", display: "grid", placeItems: "center", color: "#fff", flex: "none" }}>
          <CreditCard size={15} strokeWidth={2.4} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1, whiteSpace: "nowrap" }}>
          <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600 }}>Nova •••• 4242</span>
          <span style={{ fontSize: 12, lineHeight: "16px", color: paid ? Palette.green : Palette.secondaryLabel, transition: "color 0.3s" }}>
            {paid ? (zh ? "刚刚已支付" : "Paid just now") : zh ? "馥芮白 × 2" : "Flat White × 2"}
          </span>
        </div>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>$24.00</span>
      </div>

      <div style={{ position: "relative", height: 92, width: 252, display: "grid", placeItems: "center", flex: "none" }}>
        {bloom > 0 && <Bloom key={bloom} scale={ctx.n("bloom")} />}
        <motion.button
          type="button"
          onClick={pay}
          {...pressHandlers(setPressed)}
          initial={false}
          animate={{ width: w, height: h, borderRadius: cornerOf(stage), scale: pressed ? 0.96 : 1 }}
          transition={{ default: MORPH, scale: spring(0.28, 0.6) }}
          style={{
            gridArea: "1 / 1",
            position: "relative",
            overflow: "hidden",
            background: ink,
            boxShadow: `0 8px 28px ${paid ? alpha(Palette.green, 0.4) : black(0.22)}`,
            transition: "box-shadow 0.4s",
          }}
        >
          <motion.div initial={false} animate={{ opacity: paid ? 1 : 0 }} transition={MORPH} style={{ position: "absolute", inset: 0, background: `linear-gradient(#2FBF71, ${Palette.successStrong})` }} />

          <motion.div initial={false} animate={{ opacity: stage === "idle" ? 1 : 0, scale: stage === "idle" ? 1 : 0.8 }} transition={MORPH} style={{ ...layer, color: onInk }}>
            <span style={label}>
              <Glyph size={21} strokeWidth={2} />
              {zh ? "支付 $24.00" : "Pay $24.00"}
            </span>
          </motion.div>

          <AnimatePresence>
            {stage === "processing" && (
              <motion.div key="spin" initial={{ scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.4, opacity: 0 }} transition={MORPH} style={layer}>
                <motion.svg width={24} height={24} viewBox="0 0 24 24" animate={{ rotate: 360 }} transition={{ duration: 0.75, ease: "linear", repeat: Infinity }} style={{ overflow: "visible" }}>
                  <circle cx={12} cy={12} r={12} fill="none" stroke={onInk} strokeWidth={2.6} strokeLinecap="round" strokeDasharray={`${0.7 * 2 * Math.PI * 12} 200`} strokeDashoffset={-0.05 * 2 * Math.PI * 12} />
                </motion.svg>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Biometric scan: a dim base, a bright copy revealed by the scan, and the scan line on its edge. */}
          <motion.div initial={false} animate={{ opacity: stage === "scanning" ? 1 : 0, scale: stage === "scanning" ? 1 : 0.5 }} transition={MORPH} style={layer}>
            <motion.div initial={false} animate={{ scale: recognized ? 1 : 0.88 }} transition={spring(0.3, 0.45)} style={{ position: "relative", width: SIDE, height: SIDE }}>
              <svg width={0} height={0} style={{ position: "absolute" }}>
                <defs>
                  <linearGradient id="pay-scan-face" gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={24}>
                    <stop offset={0} stopColor={Palette.sky} />
                    <stop offset={1} stopColor={Palette.mint} />
                  </linearGradient>
                  <linearGradient id="pay-scan-touch" gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={0} y2={24}>
                    <stop offset={0} stopColor={Palette.coral} />
                    <stop offset={1} stopColor={Palette.pink} />
                  </linearGradient>
                </defs>
              </svg>
              <Glyph size={SIDE} strokeWidth={1.5} color={alpha(onInk, 0.28)} style={{ position: "absolute", inset: 0 }} />
              <div style={{ position: "absolute", left: 0, right: 0, height: reveal, overflow: "hidden", ...(touchID ? { bottom: 0 } : { top: 0 }) }}>
                <Glyph size={SIDE} strokeWidth={1.5} stroke={`url(#${touchID ? "pay-scan-touch" : "pay-scan-face"})`} style={{ position: "absolute", left: 0, ...(touchID ? { bottom: 0 } : { top: 0 }) }} />
              </div>
              <div
                style={{
                  position: "absolute",
                  left: SIDE / 2 - 29,
                  top: SIDE / 2 - 1.25 + lineY,
                  width: 58,
                  height: 2.5,
                  borderRadius: 2,
                  background: lineColor,
                  boxShadow: `0 0 10px ${lineColor}`,
                  opacity: scan.value > 0.01 && scan.value < 0.99 ? 1 : 0,
                }}
              />
            </motion.div>
          </motion.div>

          <motion.div initial={false} animate={{ opacity: stage === "success" ? 1 : 0 }} transition={MORPH} style={layer}>
            <TrimPath d={`M 0 ${9 + 18 * 0.06} L ${24 * 0.37} 18 L 24 0`} width={24} height={18} trim={check.value} color="#fff" lineWidth={4} />
          </motion.div>

          <motion.div initial={false} animate={{ opacity: stage === "receipt" ? 1 : 0, scale: stage === "receipt" ? 1 : 0.8 }} transition={MORPH} style={{ ...layer, color: "#fff" }}>
            <span style={label}>
              <CircleCheck size={22} fill="currentColor" stroke="#24A862" strokeWidth={2.2} />
              {zh ? "支付成功" : "Payment complete"}
            </span>
          </motion.div>
        </motion.button>
      </div>
      <DemoHint ctx={ctx} en="Tap to pay" zh="点击支付" />
    </div>
  );
}

/**
 * The success bloom. Swift springs both layers toward visible (with the morph) and, in the same breath,
 * eases them out to their grown, hidden end state over 0.85 s; the animations add up to a flash.
 */
function Bloom({ scale }: { scale: number }) {
  const e = useElapsed(0, 0.9);
  const out = ease.out(e / 0.85);
  const visible = Math.max(0, springAt(e, 0.45, 0.78) - out);
  const base = { gridArea: "1 / 1", width: 64, height: 64, borderRadius: "50%", pointerEvents: "none" } as const;
  return (
    <>
      <div style={{ ...base, background: Palette.green, filter: "blur(10px)", transform: `scale(${0.9 + (scale - 0.9) * out})`, opacity: 0.6 * visible }} />
      <div style={{ ...base, boxShadow: `0 0 0 1px ${Palette.green}, inset 0 0 0 1px ${Palette.green}`, transform: `scale(${1 + (scale * 0.8 - 1) * out})`, opacity: 0.8 * visible }} />
    </>
  );
}
