/** navigation.card-stack-drawer · 卡片堆抽屉 (Navigation+CardStackDrawer.swift) */
import { motion } from "motion/react";
import { Menu } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, anim, delayed, spring, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Glyph, type GlyphName } from "./groupB-kit";
import { diag, stageColumn, useAutoplayFlag } from "./_r2";

const SCREENS: { symbol: GlyphName; title: [string, string]; colors: [string, string] }[] = [
  { symbol: "house.fill", title: ["Home", "首页"], colors: [Palette.indigo, Palette.violet] },
  { symbol: "chart.bar.fill", title: ["Stats", "统计"], colors: [Palette.mint, Palette.sky] },
  { symbol: "person.fill", title: ["Profile", "我的"], colors: [Palette.pink, Palette.coral] },
];
const FRAME = { w: 290, h: 284 };

export default function CardStackDrawer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [open, setOpen] = useState(false);
  /** Screen indices from front to back. */
  const [order, setOrder] = useState([0, 1, 2]);
  const [lifted, setLifted] = useState<number | null>(null);
  /** Which state change the current render animates (the innermost `.animation(_:value:)` that fired). */
  const [cause, setCause] = useState<"open" | "order" | "lifted">("open");
  const live = useRef({ open, order, lifted });
  live.current = { open, order, lifted };
  const autoStep = useRef(0);

  const move = spring(ctx.n("response"), ctx.n("damping"));

  const toggle = () => {
    if (live.current.lifted !== null) return;
    haptics.tap("medium");
    setCause("open");
    setOpen(!live.current.open);
  };

  /** Pulls the card out of the stack, then brings it to the front and closes the drawer. */
  const pick = (index: number) => {
    const now = live.current;
    if (!now.open || now.lifted !== null) return;
    haptics.tap("light");
    if (now.order[0] === index) {
      setCause("open");
      setOpen(false);
      return;
    }
    setCause("lifted");
    setLifted(index);
    after(0.16, () => {
      setCause("open");
      setLifted(null);
      setOrder((o) => [index, ...o.filter((v) => v !== index)]);
      setOpen(false);
    });
  };

  useAutoplayFlag(
    ctx.isPreview,
    () => {
      if (live.current.open) pick(live.current.order[1 + (Math.floor(autoStep.current / 2) % 2)]);
      else toggle();
      autoStep.current += 1;
    },
    { every: 1.5 },
  );

  const dark = ctx.scheme === "dark";
  const tilt = ctx.n("tilt");
  const fan = ctx.n("fan");

  return (
    <div style={stageColumn(14)}>
      <div
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          borderRadius: 32,
          overflow: "hidden",
          background: dark ? "linear-gradient(to bottom, #14151D, #0B0C11)" : "linear-gradient(to bottom, #DCDFEE, #C9CDE2)",
          boxShadow: "0 10px 18px rgb(0 0 0 / 0.16)",
        }}
      >
        {/* menu */}
        <div style={{ position: "absolute", left: 14, top: 0, bottom: 0, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "flex-start", gap: 6, pointerEvents: open ? "auto" : "none" }}>
          {SCREENS.map((screen, index) => {
            const active = order[0] === index;
            return (
              <motion.div
                key={index}
                onClick={() => pick(index)}
                initial={false}
                animate={{ opacity: open ? 1 : 0, x: open ? 0 : -14 }}
                transition={delayed(move, open ? 0.06 + index * 0.05 : 0)}
                style={{ height: 38, padding: "0 10px", display: "flex", alignItems: "center", gap: 8, borderRadius: 19, background: Palette.labelAlpha(active ? 0.08 : 0), cursor: "pointer" }}
              >
                <div style={{ width: 20, display: "grid", placeItems: "center", color: active ? screen.colors[0] : Palette.secondaryLabel }}>
                  <Glyph name={screen.symbol} size={15} />
                </div>
                <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: active ? 700 : 500, color: active ? Palette.label : Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...screen.title)}</span>
              </motion.div>
            );
          })}
        </div>
        {/* cards */}
        {SCREENS.map((screen, index) => {
          const depth = Math.max(order.indexOf(index), 0);
          const pulled = lifted === index;
          const scale = open ? 0.62 - 0.07 * depth + (pulled ? 0.03 : 0) : depth === 0 ? 1 : 0.92;
          // The front card sits furthest right; deeper cards peek out from behind its left edge.
          const x = open ? 96 - depth * fan - (pulled ? 46 : 0) : 0;
          const radius = open ? 40 : 32;
          const t = cause === "open" ? delayed(move, open ? depth * 0.05 : 0) : cause === "order" ? move : anim.easeOut(0.16);
          return (
            <motion.div
              key={index}
              initial={false}
              animate={{ x, opacity: open || depth === 0 ? 1 : 0 }}
              transition={t}
              style={{ position: "absolute", inset: 0, zIndex: SCREENS.length - depth, pointerEvents: "none" }}
            >
              <motion.div
                initial={false}
                animate={{ scale, rotateY: open ? -tilt : 0, borderRadius: radius, boxShadow: `-8px 10px 18px rgb(0 0 0 / ${open ? 0.28 : 0})` }}
                transition={t}
                style={{ position: "absolute", inset: 0, transformPerspective: Math.max(FRAME.w, FRAME.h) / 0.6, background: Palette.elevated, overflow: "hidden", pointerEvents: open || depth === 0 ? "auto" : "none" }}
              >
                <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", gap: 12 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                    <div onClick={toggle} style={{ width: 38, height: 38, borderRadius: "50%", background: Palette.labelAlpha(0.07), display: "grid", placeItems: "center", cursor: "pointer", flexShrink: 0 }}>
                      <Menu size={18} strokeWidth={3} />
                    </div>
                    <span style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700, whiteSpace: "nowrap" }}>{ctx.t(...screen.title)}</span>
                  </div>
                  <div style={{ position: "relative", height: 104, borderRadius: 20, background: diag(...screen.colors), flexShrink: 0 }}>
                    <div style={{ position: "absolute", right: 14, bottom: 14, color: white(0.35) }}>
                      <Glyph name={screen.symbol} size={52} />
                    </div>
                  </div>
                  {[0, 1].map((row) => (
                    <div key={row} style={{ display: "flex", alignItems: "center", gap: 12 }}>
                      <div style={{ width: 34, height: 34, borderRadius: 10, background: alpha(screen.colors[row % screen.colors.length], 0.28), flexShrink: 0 }} />
                      <div style={{ flex: 1 }}>
                        <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
                      </div>
                    </div>
                  ))}
                </div>
                {/* cards deeper in the stack sit in shade */}
                <motion.div initial={false} animate={{ opacity: open ? 0.14 * depth : 0 }} transition={t} style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: "none" }} />
                {open && <div onClick={() => pick(index)} style={{ position: "absolute", inset: 0, cursor: "pointer" }} />}
              </motion.div>
            </motion.div>
          );
        })}
        <div style={{ position: "absolute", inset: 0, borderRadius: 32, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none", zIndex: 10 }} />
      </div>
      <DemoHint ctx={ctx} en="Tap the menu button, then pick a card" zh="点击菜单按钮，再挑一张卡片" />
    </div>
  );
}
