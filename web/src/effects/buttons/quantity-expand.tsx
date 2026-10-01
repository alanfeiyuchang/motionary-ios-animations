/** buttons.quantity-expand · 加购展开步进器 (Buttons+QuantityExpand.swift) */
import { motion } from "motion/react";
import { Minus, Plus, Trash2 } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, black, delayed, demoCard, fonts, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, SymbolReplace, cubicKF, linearKF, springKF, track, useSince } from "./_a-kit";

const UNIT_PRICE = 28;
const ACCENT = Palette.coral;
const INK = hex(0x2b2b33);

export default function QuantityExpand({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const collapseT = useTimeouts();
  const script = useTimeouts();
  const [count, setCountState] = useState(0);
  const [expanded, setExpandedState] = useState(false);
  const state = useRef({ count: 0, expanded: false });
  const [plusBumps, setPlusBumps] = useState(0);
  const [minusBumps, setMinusBumps] = useState(0);
  const [badgePops, setBadgePops] = useState(0);
  const springTr = spring(ctx.n("response"), ctx.n("damping"));
  const stepperWidth = ctx.n("width");
  const idle = useRef(2.2);
  idle.current = Math.max(ctx.n("idle"), 0.3);

  const setCount = (c: number) => {
    state.current.count = c;
    setCountState(c);
  };
  const setExpanded = (e: boolean) => {
    state.current.expanded = e;
    setExpandedState(e);
  };
  const collapse = () => {
    const s = state.current;
    if (!s.expanded || s.count <= 0) return;
    setExpanded(false);
    setBadgePops((n) => n + 1);
  };
  const scheduleCollapse = () => {
    collapseT.clearAll();
    collapseT.after(idle.current, collapse);
  };
  const increment = (buzz: boolean) => {
    if (buzz) haptics.tap("light");
    const s = state.current;
    const wasOpen = s.expanded && s.count > 0;
    setCount(Math.min(s.count + 1, 99));
    setExpanded(true);
    if (wasOpen) setPlusBumps((n) => n + 1);
    scheduleCollapse();
  };
  const decrement = (buzz: boolean) => {
    const s = state.current;
    if (s.count <= 0) return;
    if (s.count === 1) {
      if (buzz) haptics.tap("rigid");
      collapseT.clearAll();
      setCount(0);
      setExpanded(false);
      return;
    }
    if (buzz) haptics.tap("light");
    setCount(s.count - 1);
    setMinusBumps((n) => n + 1);
    scheduleCollapse();
  };
  const tapFace = (buzz: boolean) => {
    const s = state.current;
    if (s.expanded && s.count !== 0) return;
    if (s.count === 0) increment(buzz);
    else {
      if (buzz) haptics.tap("light");
      setExpanded(true);
      scheduleCollapse();
    }
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (state.current.count !== 0) return;
      script.clearAll();
      tapFace(false);
      script.after(0.55, () => increment(false));
      script.after(0.97, () => increment(false));
      script.after(1.72, () => {
        collapseT.clearAll();
        collapse();
      });
      script.after(2.67, () => tapFace(false));
      script.after(3.17, () => decrement(false));
      script.after(3.57, () => decrement(false));
      script.after(4.02, () => decrement(false));
    },
    { every: 5.6, delay: 0.5 },
  );

  const open = expanded && count > 0;
  const badge = !expanded && count > 0;
  const width = open ? stepperWidth : 42;
  const shown = Math.max(count, 1);
  const pt = useSince(plusBumps, 0.5);
  const mt = useSince(minusBumps, 0.5);
  const bt = useSince(badgePops, 0.7);
  const plusScale = track(pt, 1, [cubicKF(1.07, 0.08), springKF(1, 0.4, BOUNCY)]);
  const minusScale = track(mt, 1, [cubicKF(1.07, 0.08), springKF(1, 0.4, BOUNCY)]);
  const badgeScale = track(bt, 1, [linearKF(1, 0.16), cubicKF(1.14, 0.1), springKF(1, 0.4, BOUNCY)]);
  const digits = { fontFamily: fonts.rounded, fontSize: 17, lineHeight: "22px", fontWeight: 700 } as const;
  const amount = UNIT_PRICE * shown;

  const stepButton = (onTap: () => void, children: React.ReactNode, color: string) => (
    <button
      type="button"
      onClick={(e) => {
        e.stopPropagation();
        script.clearAll();
        onTap();
      }}
      style={{ width: 42, height: 42, borderRadius: 21, display: "grid", placeItems: "center", color, flexShrink: 0 }}
    >
      {children}
    </button>
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ ...demoCard(26), width: 246, boxSizing: "border-box", padding: 10, flexShrink: 0, display: "flex", flexDirection: "column", alignItems: "stretch" }}>
        <div style={{ position: "relative", width: 226, height: 138, borderRadius: 18, overflow: "hidden", background: `linear-gradient(${Math.atan2(226, -138)}rad, ${hex(0xffd9a8)}, ${hex(0xff9d7a)})` }}>
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: white(0.92), filter: `drop-shadow(0 5px 4px ${hex(0xc8552b, 0.35)})` }}>
            <svg width={76} height={64} viewBox="0 0 66 56" fill="currentColor">
              <path d="M9 6h38v17c0 12-8 19-19 19S9 35 9 23Z" />
              <path d="M47 11h4a8 8 0 0 1 0 16h-5" fill="none" stroke="currentColor" strokeWidth={5} strokeLinecap="round" />
              <path d="M4 45h48c1.300 0 2.100 1.100 1.600 2.300C52 51.500 47 54 40 54H16C9 54 4 51.500 2.400 47.300 1.900 46.100 2.700 45 4 45Z" />
            </svg>
          </div>
          <div style={{ position: "absolute", right: 10, bottom: 10, transform: `scaleX(${plusScale})`, transformOrigin: "0% 50%" }}>
            <div style={{ transform: `scaleX(${minusScale})`, transformOrigin: "100% 50%" }}>
              <div style={{ transform: `scale(${badgeScale})`, transformOrigin: "100% 50%" }}>
                <motion.div
                  role="button"
                  onClick={() => {
                    script.clearAll();
                    tapFace(true);
                  }}
                  initial={false}
                  animate={{ width, backgroundColor: badge ? ACCENT : "#FFFFFF" }}
                  transition={springTr}
                  style={{ position: "relative", height: 42, borderRadius: 21, overflow: "hidden", boxShadow: `0 4px 8px ${black(0.18)}`, cursor: "pointer" }}
                >
                  <div style={{ position: "absolute", right: 0, top: 0, width: stepperWidth, height: 42, display: "flex", alignItems: "center" }}>
                    <motion.div
                      initial={false}
                      animate={{ opacity: open ? 1 : 0, x: open ? 0 : 30 }}
                      transition={delayed(springTr, open ? 0.04 : 0)}
                      style={{ pointerEvents: open ? "auto" : "none", display: "grid" }}
                    >
                      {stepButton(
                        () => decrement(true),
                        <SymbolReplace id={count <= 1 ? "trash" : "minus"}>
                          {count <= 1 ? <Trash2 size={16} strokeWidth={2.6} /> : <Minus size={17} strokeWidth={3.4} />}
                        </SymbolReplace>,
                        count <= 1 ? Palette.red : INK,
                      )}
                    </motion.div>
                    <div style={{ flex: 1 }} />
                    <motion.div initial={false} animate={{ opacity: open ? 1 : 0, x: open ? 0 : 16 }} transition={springTr} style={{ color: INK }}>
                      <NumericText value={count} text={String(shown)} style={digits} />
                    </motion.div>
                    <div style={{ flex: 1 }} />
                    <motion.div
                      initial={false}
                      animate={{ opacity: open || count === 0 ? 1 : 0 }}
                      transition={springTr}
                      style={{ pointerEvents: open ? "auto" : "none", display: "grid" }}
                    >
                      {stepButton(() => increment(true), <Plus size={17} strokeWidth={3.4} />, ACCENT)}
                    </motion.div>
                  </div>
                  <motion.div
                    initial={false}
                    animate={{ opacity: badge ? 1 : 0, scale: badge ? 1 : 0.5 }}
                    transition={springTr}
                    style={{ position: "absolute", right: 0, top: 0, width: 42, height: 42, display: "grid", placeItems: "center", color: "#fff", pointerEvents: "none" }}
                  >
                    <NumericText value={count} text={String(shown)} style={digits} />
                  </motion.div>
                </motion.div>
              </div>
            </div>
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "baseline", padding: "12px 6px 4px" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: Palette.label }}>{ctx.t("Flat White", "澳白咖啡")}</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{ctx.t("Medium · Hot", "中杯 · 热")}</span>
          </div>
          <div style={{ flex: 1 }} />
          <NumericText
            value={count}
            text={`${ctx.t("$", "¥")}${amount}`}
            style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "20px", fontWeight: 700, color: count > 0 ? ACCENT : Palette.label }}
          />
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap +, then wait for it to fold" zh="点 +，再等它自动收拢" style={{ paddingBottom: 18 }} />
    </div>
  );
}
