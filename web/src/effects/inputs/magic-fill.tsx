/** inputs.magic-fill (Inputs+MagicFill.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Home, Mail, Phone, User, WandSparkles, X } from "lucide-react";
import { DemoHint, Palette, alpha, anim, black, clamp, delayed, spring, textStyle, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { CheckCircleFill, SymbolSwap } from "./_a-common";
import { column, spacer, useLatchedPress, useLive, useQuiet, useTask } from "./_c-common";

const ICON = { size: 15, strokeWidth: 2.2, fill: "currentColor" } as const;
const FIELDS: { icon: React.ReactNode; label: [string, string]; value: [string, string] }[] = [
  { icon: <User {...ICON} />, label: ["Full name", "姓名"], value: ["Avery Lin", "林安然"] },
  { icon: <Mail size={15} strokeWidth={2.2} />, label: ["Email", "邮箱"], value: ["avery@example.com", "anran@example.com"] },
  { icon: <Phone {...ICON} />, label: ["Phone", "电话"], value: ["(555) 010-4821", "555 0104 821"] },
  { icon: <Home size={15} strokeWidth={2.2} />, label: ["Address", "地址"], value: ["28 Juniper Lane, Apt 5", "梧桐路 28 号 5 楼"] },
];
const ROW_H = 48;
const WIDTH = 288;

export default function MagicFill({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const press = useLatchedPress();
  const { wrap, quiet } = useQuiet();
  const [filled, setFilled] = useState(() => FIELDS.map(() => false));
  const [isFilled, setIsFilled, isFilledRef] = useLive(false);
  const busy = useRef(false);
  const task = useTask();

  const fill = (silent: boolean) => {
    busy.current = true;
    setIsFilled(true);
    const stagger = ctx.n("stagger");
    task.start(async (sleep) => {
      for (let index = 0; index < FIELDS.length; index++) {
        setFilled((f) => f.map((v, i) => (i === index ? true : v)));
        if (!silent) haptics.tap("light");
        if (!(await sleep(stagger))) return;
      }
      await sleep(ctx.n("sweep") * 0.7);
      busy.current = false;
      if (!silent) haptics.success();
    });
  };
  const clear = () => {
    busy.current = true;
    setIsFilled(false);
    haptics.tap("light");
    task.start(async (sleep) => {
      for (let index = FIELDS.length - 1; index >= 0; index--) {
        setFilled((f) => f.map((v, i) => (i === index ? false : v)));
        if (!(await sleep(0.05))) return;
      }
      busy.current = false;
    });
  };
  const toggle = () => {
    if (busy.current) return;
    press.bump();
    if (isFilledRef.current) clear();
    else fill(quiet());
  };
  useAutoplay(ctx.isPreview, wrap(toggle), { every: 3.2, delay: 0.5 });

  const t = spring(0.4, 0.8);

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ width: WIDTH, borderRadius: 20, background: Palette.elevated, boxShadow: `0 8px 21px ${black(0.1)}`, position: "relative", flexShrink: 0 }}>
        <div style={{ borderRadius: 20, overflow: "hidden" }}>
          {FIELDS.map((field, index) => (
            <div key={index}>
              <Row icon={field.icon} label={ctx.t(...field.label)} value={ctx.t(...field.value)} filled={filled[index]} sweepDuration={ctx.n("sweep")} hold={ctx.n("hold")} />
              {index < FIELDS.length - 1 && <div style={{ height: 1, marginLeft: 46, background: Palette.labelAlpha(0.08) }} />}
            </div>
          ))}
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 20, border: `1px solid ${Palette.labelAlpha(0.08)}`, pointerEvents: "none" }} />
      </div>
      <motion.button
        type="button"
        onClick={toggle}
        {...press.handlers}
        animate={{ scale: press.pressed ? 0.95 : 1 }}
        transition={spring(0.3, 0.6)}
        style={{ position: "relative", marginTop: 14, height: 40, padding: "0 18px", borderRadius: 20, flexShrink: 0, display: "flex", alignItems: "center", gap: 7, ...textStyle.subheadline, fontWeight: 600 }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: 20, background: Palette.labelAlpha(0.09) }} />
        <motion.div initial={false} animate={{ opacity: isFilled ? 0 : 1 }} transition={t} style={{ position: "absolute", inset: 0, borderRadius: 20, background: Palette.primary }} />
        <motion.span initial={false} animate={{ color: isFilled ? (ctx.scheme === "dark" ? "#ffffff" : "#000000") : "#ffffff" }} transition={t} style={{ position: "relative", display: "flex", alignItems: "center", gap: 7 }}>
          <SymbolSwap k={isFilled ? "x" : "wand"}>{isFilled ? <X size={16} strokeWidth={2.8} /> : <WandSparkles size={16} strokeWidth={2.2} />}</SymbolSwap>
          <span style={{ display: "inline-grid" }}>
            <AnimatePresence initial={false} mode="popLayout">
              <motion.span
                key={isFilled ? "clear" : "fill"}
                initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
                animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                exit={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
                transition={anim.easeInOut(0.3)}
                style={{ gridArea: "1 / 1", whiteSpace: "nowrap" }}
              >
                {isFilled ? ctx.t("Clear", "清除") : ctx.t("Autofill", "自动填充")}
              </motion.span>
            </AnimatePresence>
          </span>
        </motion.span>
      </motion.button>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap Autofill, then Clear" zh="点击「自动填充」，再点「清除」" style={{ paddingBottom: 12 }} />
    </div>
  );
}

function Row({ icon, label, value, filled, sweepDuration, hold }: { icon: React.ReactNode; label: string; value: string; filled: boolean; sweepDuration: number; hold: number }) {
  const { after } = useTimeouts();
  /** Position of the light band across the row, -0.3 (off the left) ... 1.3 (off the right). */
  const sweep = useMotionValue(-0.3);
  const reveal = useMotionValue(0);
  const highlight = useMotionValue(0);
  const [checked, setChecked] = useState(false);
  const fadeTask = useRef<(() => void) | null>(null);
  const first = useRef(true);

  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    fadeTask.current?.();
    if (filled) {
      animate(sweep, 1.3, anim.easeInOut(sweepDuration));
      animate(reveal, 1, anim.easeInOut(sweepDuration));
      animate(highlight, 1, anim.easeOut(0.2));
      setChecked(true);
      fadeTask.current = after(sweepDuration + hold, () => animate(highlight, 0, anim.easeOut(0.9)));
    } else {
      animate(reveal, 0, anim.easeIn(0.2));
      animate(highlight, 0, anim.easeIn(0.2));
      setChecked(false);
      // The band is off-stage on the right: move it back to the left unseen.
      sweep.jump(-0.3);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [filled]);

  const bandX = useTransform(sweep, (s) => (s - 0.5) * WIDTH);
  const background = useTransform(highlight, (h) => alpha(Palette.amber, 0.2 * clamp(h)));
  const clip = useTransform(reveal, (r) => `inset(-6px ${(1 - clamp(r)) * 100}% -6px 0)`);
  const blur = useTransform(reveal, (r) => `blur(${(1 - clamp(r)) * 4}px)`);
  const t = spring(0.4, 0.8);

  return (
    <motion.div style={{ position: "relative", width: WIDTH, height: ROW_H, padding: "0 14px", display: "flex", alignItems: "center", gap: 12, overflow: "hidden", backgroundColor: background }}>
      <span style={{ width: 20, display: "grid", placeItems: "center", color: filled ? Palette.indigo : Palette.secondaryLabel, transition: "color 0.3s", flexShrink: 0 }}>{icon}</span>
      <div style={{ position: "relative", display: "grid", alignItems: "center", fontSize: 16, lineHeight: "21px" }}>
        <motion.span initial={false} animate={{ scale: filled ? 0.78 : 1, y: filled ? -11 : 0 }} transition={t} style={{ gridArea: "1 / 1", color: Palette.secondaryLabel, transformOrigin: "0 50%", whiteSpace: "nowrap", justifySelf: "start" }}>
          {label}
        </motion.span>
        <motion.span style={{ gridArea: "1 / 1", fontWeight: 500, whiteSpace: "nowrap", y: 8, clipPath: clip, filter: blur }}>{value}</motion.span>
      </div>
      <div style={{ flex: 1 }} />
      <motion.span
        initial={false}
        animate={{ scale: checked ? 1 : 0.2, opacity: checked ? 1 : 0 }}
        transition={checked ? delayed(spring(0.35, 0.55), sweepDuration * 0.75) : anim.easeIn(0.2)}
        style={{ color: Palette.green, display: "block" }}
      >
        <CheckCircleFill size={19} />
      </motion.span>
      {/* band */}
      <motion.div
        style={{
          position: "absolute",
          left: WIDTH / 2 - 28,
          top: ROW_H / 2 - (ROW_H * 2.2) / 2,
          width: 56,
          height: ROW_H * 2.2,
          x: bandX,
          rotate: 18,
          background: `linear-gradient(90deg, ${alpha(Palette.amber, 0)}, ${alpha(Palette.amber, 0.45)}, ${white(0.6)}, ${alpha(Palette.amber, 0.45)}, ${alpha(Palette.amber, 0)})`,
          pointerEvents: "none",
        }}
      />
    </motion.div>
  );
}
