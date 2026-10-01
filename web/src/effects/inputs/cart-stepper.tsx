/** inputs.cart-stepper (Inputs+CartStepper.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { CakeSlice, Minus, Plus, Trash2 } from "lucide-react";
import { DemoHint, NumericText, Palette, alpha, clamp, demoCard, fonts, spring, textStyle, useAutoplay, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { PRIMARY_STRONG } from "./_b-common";
import { BOUNCY, SNAPPY, column, spacer, springTrack, useLive } from "./_c-common";

const UNIT_PRICE = 4.5;
const SCRIPT = [1, 1, 1, -1, -1, -1];

export default function CartStepper({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [count, setCount, countRef] = useLive(0);
  /** Its change triggers the nudge, its last direction picks the side. */
  const [nudges, setNudges] = useState(0);
  const direction = useRef(1);
  const [bumps, setBumps] = useState(0);
  const step = useRef(0);
  const open = count > 0;
  const t = spring(ctx.n("response"), ctx.n("damping"));
  const zh = ctx.lang === "zh";
  const money = (amount: number) => (zh ? "¥" : "$") + (amount * (zh ? 6 : 1)).toFixed(2);

  /** Finger and autoplay both land here. */
  const change = (delta: number) => {
    const current = countRef.current;
    const next = clamp(current + delta, 0, 9);
    if (next === current) return;
    const opening = current === 0;
    const closing = next === 0;
    haptics.tap(opening || closing ? "medium" : "light");
    if (!opening && !closing) {
      direction.current = delta > 0 ? 1 : -1;
      setNudges((n) => n + 1);
    }
    setBumps((b) => b + 1);
    setCount(next);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      change(SCRIPT[step.current % SCRIPT.length]);
      step.current += 1;
    },
    { every: 0.85, delay: 0.5 },
  );

  const nudgeT = useElapsed(nudges, 0.44, true);
  const nudge = springTrack(nudgeT, 0, [
    { to: 4 * direction.current, duration: 0.09, spring: SNAPPY },
    { to: 0, duration: 0.35, spring: BOUNCY },
  ]);
  const bumpT = useElapsed(bumps, 0.45, true);
  const bump = springTrack(bumpT, 1, [
    { to: 1.25, duration: 0.1, spring: SNAPPY },
    { to: 1, duration: 0.35, spring: BOUNCY },
  ]);

  const width = open ? ctx.n("width") : 84;
  const shown = Math.max(count, 1);
  const itemsLabel = zh ? `购物车 · ${shown} 件` : shown === 1 ? "Cart · 1 item" : `Cart · ${shown} items`;
  const glyph = (name: "trash" | "minus" | "plus", side: number) => (
    <motion.div
      initial={false}
      animate={{ x: open ? side * (width / 2 - 21) : 0, opacity: open ? 1 : 0, scale: open ? 1 : 0.4 }}
      transition={t}
      style={{ position: "absolute", left: "50%", top: 5, width: 30, height: 30, marginLeft: -15, display: "grid", placeItems: "center", color: name === "trash" ? Palette.red : Palette.indigo }}
    >
      <SymbolSwap k={name}>{name === "trash" ? <Trash2 size={16} strokeWidth={2.6} /> : name === "minus" ? <Minus size={17} strokeWidth={3.2} /> : <Plus size={17} strokeWidth={3.2} />}</SymbolSwap>
    </motion.div>
  );

  return (
    <div style={column}>
      <div style={spacer} />
      {/* Product row */}
      <div style={{ ...demoCard(24), width: 304, padding: 12, display: "flex", alignItems: "center", gap: 12, flexShrink: 0, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 27px rgb(0 0 0 / 0.12)` }}>
        <div style={{ width: 52, height: 52, borderRadius: 16, background: "linear-gradient(135deg, #B7E3A0, #5FA86B)", display: "grid", placeItems: "center", color: "#fff", flexShrink: 0 }}>
          <CakeSlice size={28} strokeWidth={2} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3, minWidth: 0 }}>
          <span style={{ ...textStyle.subheadline, fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Matcha Roll", "抹茶蛋糕卷")}</span>
          <span style={{ ...textStyle.footnote, fontWeight: 500, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{money(UNIT_PRICE)}</span>
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ width: Math.max(ctx.n("width"), 84), display: "flex", justifyContent: "flex-end", flexShrink: 0, transform: `translateX(${nudge}px)` }}>
          <motion.div initial={false} animate={{ width }} transition={t} style={{ position: "relative", height: 40, borderRadius: 20, overflow: "hidden", cursor: "pointer" }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 20, background: alpha(Palette.indigo, 0.14) }} />
            <motion.div initial={false} animate={{ opacity: open ? 0 : 1 }} transition={t} style={{ position: "absolute", inset: 0, borderRadius: 20, background: Palette.primary }} />
            <motion.div
              initial={false}
              animate={{ scale: open ? 0.6 : 1, opacity: open ? 0 : 1, filter: `blur(${open ? 5 : 0}px)` }}
              transition={{ ...t, filter: { duration: 0.25 } }}
              style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 4, color: "#fff", whiteSpace: "nowrap" }}
            >
              <Plus size={14} strokeWidth={3.4} />
              <span style={{ ...textStyle.subheadline, fontWeight: 600 }}>{ctx.t("Add", "加入")}</span>
            </motion.div>
            <motion.div
              initial={false}
              animate={{ scale: open ? 1 : 0.3, opacity: open ? 1 : 0 }}
              transition={t}
              style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, color: Palette.indigo }}
            >
              <NumericText value={shown} />
            </motion.div>
            {glyph(count <= 1 ? "trash" : "minus", -1)}
            {glyph("plus", 1)}
            <div style={{ position: "absolute", inset: 0, display: "flex" }}>
              <div style={{ flex: 1 }} onClick={() => change(countRef.current > 0 ? -1 : 1)} />
              <div style={{ flex: 1 }} onClick={() => change(1)} />
            </div>
          </motion.div>
        </div>
      </div>
      {/* Cart bar */}
      <motion.div
        initial={false}
        animate={{ y: open ? 0 : 34, opacity: open ? 1 : 0, scale: open ? 1 : 0.94 }}
        transition={t}
        style={{
          marginTop: 16,
          width: 304,
          height: 52,
          padding: "0 18px",
          borderRadius: 20,
          background: PRIMARY_STRONG,
          boxShadow: `0 6px 18px ${alpha(Palette.indigo, 0.35)}`,
          display: "flex",
          alignItems: "center",
          gap: 10,
          color: "#fff",
          flexShrink: 0,
          pointerEvents: "none",
        }}
      >
        <span style={{ display: "block", transform: `scale(${bump})` }}>
          <svg width={17} height={19} viewBox="0 0 17 19" fill="currentColor" style={{ display: "block" }}>
            <path fillRule="evenodd" d="M8.5 0a4 4 0 0 0-4 4v1H2.6A2.100 2.100 0 0 0 .5 7.100v8.400A3.500 3.500 0 0 0 4 19h9a3.500 3.500 0 0 0 3.500-3.500V7.100A2.100 2.100 0 0 0 14.400 5H12.500V4a4 4 0 0 0-4-4Zm2.200 5V4a2.200 2.200 0 0 0-4.400 0v1Z" />
          </svg>
        </span>
        <span style={{ ...textStyle.subheadline, fontWeight: 600 }}>
          <NumericText value={count} text={itemsLabel} />
        </span>
        <div style={{ flex: 1 }} />
        <span style={{ ...textStyle.subheadline, fontWeight: 700 }}>
          <NumericText value={count} text={money(UNIT_PRICE * shown)} />
        </span>
      </motion.div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap Add, then + and −" zh="点「加入」，再点 + 和 −" style={{ paddingBottom: 14 }} />
    </div>
  );
}
