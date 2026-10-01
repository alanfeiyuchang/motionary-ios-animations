/** cards.swap-places · 上下互换 (Cards+SwapPlaces.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { ArrowUpDown, DollarSign, Euro, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, fonts, rubberBand, spring, useAutoplay, useHaptics, useTimeouts, type DemoContext, type DemoProps } from "../../kit";
import { Stage, diag, tr, useMV, type LText } from "./shared";
import { PRIMARY_STRONG, STAGE, useLatchedPress, usePageSafePan } from "./_kit";

/** Distance between the two slots (92 pt card + 12 pt gap). */
const SLOT = 104;

const CURRENCIES: { code: string; name: LText; Icon: LucideIcon; amount: string; colors: string[] }[] = [
  { code: "USD", name: ["US Dollar", "美元"], Icon: DollarSign, amount: "1,000.00", colors: ["#21D4A8", "#1A9E9A"] },
  { code: "EUR", name: ["Euro", "欧元"], Icon: Euro, amount: "921.40", colors: ["#4F7CFF", "#7A45D6"] },
];

export default function SwapPlaces({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const tMV = useMotionValue(0);
  const [target, setTarget] = useState(0);
  const targetRef = useRef(0);
  const [over, setOver] = useState(0);
  const overRef = useRef(0);
  const dragStart = useRef<number | null>(null);
  const dragDecided = useRef(false);
  const landing = useTimeouts();
  const [pressed, press] = useLatchedPress();

  const pickOver = (v: number) => {
    overRef.current = v;
    setOver(v);
  };

  const settle = (next: number, muted: boolean) => {
    const changed = next !== targetRef.current;
    targetRef.current = next;
    setTarget(next);
    const response = ctx.n("response");
    animate(tMV, next, spring(response, 0.78));
    landing.clearAll();
    if (!changed || muted) return;
    landing.after(response * 0.8, () => haptics.tap("light"));
  };

  const swap = (muted: boolean) => {
    if (dragStart.current !== null) return;
    haptics.tap("medium");
    pickOver(targetRef.current);
    settle(1 - targetRef.current, muted);
  };

  const pan = usePageSafePan(["up", "down"], {
    onChange: (translation) => {
      if (dragStart.current === null) {
        dragStart.current = targetRef.current;
        dragDecided.current = false;
        landing.clearAll();
        tMV.stop();
      }
      const dy = translation.y;
      if (!dragDecided.current) {
        if (Math.abs(dy) <= 0.5) return;
        dragDecided.current = true;
        pickOver(dy > 0 ? targetRef.current : 1 - targetRef.current);
        haptics.tap("soft");
      }
      const grabbedTop = overRef.current === targetRef.current;
      const travel = Math.max(grabbedTop ? dy : -dy, 0) / SLOT;
      const amount = travel > 1 ? 1 + rubberBand(travel - 1, 0.3) : travel;
      tMV.set(targetRef.current === 0 ? amount : 1 - amount);
    },
    onEnd: (end) => {
      if (dragStart.current === null) return;
      dragStart.current = null;
      tMV.jump(tMV.get());
      if (!dragDecided.current || !end) {
        settle(targetRef.current, false);
        return;
      }
      const grabbedTop = overRef.current === targetRef.current;
      const predicted = (grabbedTop ? end.predicted.y : -end.predicted.y) / SLOT;
      settle(predicted > 0.5 ? 1 - targetRef.current : targetRef.current, false);
    },
  });

  useAutoplay(ctx.isPreview, () => swap(true), { every: 1.7 });

  const t = useMV(tMV);

  return (
    <Stage gap={22}>
      <div {...pan} style={{ position: "relative", width: 300, height: 216, flexShrink: 0, touchAction: "none" }}>
        {[0, 1].map((index) => (
          <SwapCard key={index} index={index} progress={index === 0 ? t : 1 - t} sign={over === index ? 1 : -1} arc={ctx.n("arc")} lift={ctx.n("lift")} sends={target === index} ctx={ctx} />
        ))}
        <motion.button
          {...press}
          onPointerDown={(e) => {
            // The stage's pan would capture the pointer and swallow the button's click.
            e.stopPropagation();
            press.onPointerDown();
          }}
          onClick={() => swap(false)}
          animate={{ scale: pressed ? 0.86 : 1 }}
          transition={spring(0.3, 0.6)}
          style={{
            position: "absolute",
            left: 130,
            top: 88,
            width: 40,
            height: 40,
            borderRadius: 20,
            zIndex: 3,
            display: "grid",
            placeItems: "center",
            color: "#fff",
            background: PRIMARY_STRONG,
            boxShadow: `inset 0 0 0 4px ${STAGE}`,
          }}
        >
          <ArrowUpDown size={17} strokeWidth={2.8} style={{ transform: `rotate(${t * 180}deg)` }} />
        </motion.button>
      </div>
      <DemoHint ctx={ctx} en="Tap the button, or drag a card onto the other" zh="点击按钮，或把一张卡片拖向另一张" />
    </Stage>
  );
}

/** One currency card. `progress` is its slot (0 top, 1 bottom); everything else is derived from it. */
function SwapCard({ index, progress, sign, arc, lift, sends, ctx }: { index: number; progress: number; sign: number; arc: number; lift: number; sends: boolean; ctx: DemoContext }) {
  const bow = Math.sin(progress * Math.PI);
  const mid = Math.max(bow, 0);
  const overAmount = sign > 0 ? mid : 0;
  const underAmount = sign > 0 ? 0 : mid;
  const shadowRadius = 10 + 16 * overAmount - 6 * underAmount;
  const shadowY = 6 + 12 * overAmount - 4 * underAmount;
  const c = CURRENCIES[index];
  return (
    <div
      style={{
        position: "absolute",
        left: 28,
        top: 62,
        width: 244,
        height: 92,
        zIndex: sign > 0 ? 2 : 1,
        transform: `translate(${sign * arc * bow}px, ${-SLOT / 2 + SLOT * progress}px) rotate(${sign * bow * 2.5}deg) scale(${1 + sign * lift * bow})`,
        borderRadius: 22,
        boxShadow: `0 ${shadowY}px ${shadowRadius}px ${black(0.13 + 0.1 * overAmount)}`,
      }}
    >
      <div
        style={{
          width: 244,
          height: 92,
          padding: "0 14px",
          display: "flex",
          alignItems: "center",
          gap: 12,
          borderRadius: 22,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
          filter: underAmount > 0 ? `brightness(${1 - 0.07 * underAmount})` : undefined,
        }}
      >
        <div style={{ width: 44, height: 44, borderRadius: 22, flexShrink: 0, display: "grid", placeItems: "center", color: "#fff", background: diag(c.colors) }}>
          <c.Icon size={21} strokeWidth={2.8} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <span style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "20px", fontWeight: 700 }}>{c.code}</span>
          <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{tr(ctx, c.name)}</span>
        </div>
        <span style={{ flex: 1 }} />
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 3 }}>
          <span style={{ fontSize: 10.5, lineHeight: "13px", fontWeight: 600, color: sends ? Palette.secondaryLabel : Palette.green, transition: "color 0.2s" }}>{sends ? ctx.t("You send", "付款") : ctx.t("You get", "收款")}</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 19, lineHeight: "23px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{c.amount}</span>
        </div>
      </div>
    </div>
  );
}
