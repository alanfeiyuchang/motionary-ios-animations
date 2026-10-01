/** navigation.bubble-tab-bar · 气泡标签栏 (Navigation+BubbleTabBar.swift) */
import { AnimatePresence, animate, motion, useMotionValue, type MotionValue } from "motion/react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { Bounce, HouseFill, PersonFill, SafariFill, colorGradient, useTextWidths } from "./groupA-kit";
import { cubicKF, linearKF, springKF, track, useSince } from "./groupB-kit";
import { useMotionNumber } from "./nav-util";
import { TrayFullFill, fade, mixColor } from "./_r2";

const TABS: { icon: (size: number) => ReactNode; title: [string, string]; color: string; headline: [string, string] }[] = [
  { icon: (s) => <HouseFill size={s} />, title: ["Home", "首页"], color: Palette.indigo, headline: ["Good morning", "早上好"] },
  { icon: (s) => <SafariFill size={s} />, title: ["Explore", "发现"], color: Palette.pink, headline: ["Trending now", "正在流行"] },
  { icon: (s) => <TrayFullFill size={s} />, title: ["Inbox", "收件箱"], color: Palette.coral, headline: ["3 unread", "3 条未读"] },
  { icon: (s) => <PersonFill size={s} />, title: ["Profile", "我的"], color: Palette.green, headline: ["Your space", "个人空间"] },
];
const TITLE = { fontSize: 15, lineHeight: "20px", fontWeight: 600 } as const;
const BAR_W = 304;

function useSelections(): MotionValue<number>[] {
  const a = useMotionValue(1);
  const b = useMotionValue(0);
  const c = useMotionValue(0);
  const d = useMotionValue(0);
  return [a, b, c, d];
}

export default function BubbleTabBar({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected] = useState(0);
  const [previous, setPrevious] = useState(0);
  const [moves, setMoves] = useState(0);
  const [bounces, setBounces] = useState([0, 0, 0, 0]);
  const distances = useRef([0, 1, 2, 3]);
  const filled = ctx.i("style") === 1;
  const squeeze = ctx.n("squeeze");
  const [textWidths, probe] = useTextWidths(TABS.map((t) => ctx.t(...t.title)), TITLE);

  // How selected each tab is (0…1): one spring per tab drives its width, label and the pill.
  const mvs = useSelections();
  const s0 = useMotionNumber(mvs[0]);
  const s1 = useMotionNumber(mvs[1]);
  const s2 = useMotionNumber(mvs[2]);
  const s3 = useMotionNumber(mvs[3]);
  const sel = [s0, s1, s2, s3];

  const select = (index: number) => {
    if (index === selected) return;
    haptics.selection();
    distances.current = TABS.map((_, i) => Math.abs(i - index));
    setMoves((m) => m + 1);
    setBounces((b) => b.map((v, i) => (i === index ? v + 1 : v)));
    setPrevious(selected);
    setSelected(index);
    const t = spring(ctx.n("response"), ctx.n("damping"));
    mvs.forEach((mv, i) => animate(mv, i === index ? 1 : 0, t));
  };

  useAutoplay(ctx.isPreview, () => select((selected + 1) % TABS.length), { every: 1.3 });

  // Layout, the way the HStack with Spacers resolves it.
  const widths = sel.map((s, i) => 2 * (13 + 3 * s) + 24 + Math.max(s, 0) * (7 + textWidths[i]));
  const gap = (BAR_W - 20 - widths.reduce((a, b) => a + b, 0)) / (TABS.length - 1);
  const lefts: number[] = [];
  widths.reduce((x, w) => (lefts.push(x), x + w + gap), 10);
  // The matched-geometry pill: one frame blended between the tabs by how selected each is.
  const weights = sel.map((s) => Math.max(s, 0));
  const total = weights.reduce((a, b) => a + b, 0) || 1;
  const pillLeft = lefts.reduce((a, x, i) => a + x * weights[i], 0) / total;
  const pillWidth = widths.reduce((a, w, i) => a + w * weights[i], 0) / total;
  const squeezeT = useSince(moves, 0.8);
  const direction = selected >= previous ? 1 : -1;
  const page = TABS[selected];
  const move = spring(ctx.n("response"), ctx.n("damping"));

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      {probe}
      <div style={{ flex: 1 }} />
      {/* page */}
      <div style={{ position: "relative", width: 304, height: 176, flexShrink: 0 }}>
        <AnimatePresence initial={false} custom={direction}>
          <motion.div
            key={selected}
            custom={direction}
            variants={{
              enter: (d: number) => ({ x: 36 * d, opacity: 0, scale: 1 }),
              shown: { x: 0, opacity: 1, scale: 1 },
              exit: { scale: 0.96, opacity: 0 },
            }}
            initial="enter"
            animate="shown"
            exit="exit"
            transition={move}
            style={{
              position: "absolute",
              inset: 0,
              padding: 18,
              boxSizing: "border-box",
              display: "flex",
              flexDirection: "column",
              gap: 14,
              borderRadius: 26,
              background: alpha(page.color, 0.1),
              boxShadow: `inset 0 0 0 1px ${alpha(page.color, 0.22)}`,
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <div style={{ width: 48, height: 48, borderRadius: 15, background: colorGradient(page.color), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{page.icon(25)}</div>
              <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
                <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }}>{ctx.t(...page.headline)}</div>
                <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{ctx.t(...page.title)}</div>
              </div>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
              <div style={{ height: 10, borderRadius: 5, background: alpha(page.color, 0.28) }} />
              <div style={{ width: 210, height: 10, borderRadius: 5, background: alpha(page.color, 0.2) }} />
              <div style={{ width: 130, height: 10, borderRadius: 5, background: alpha(page.color, 0.14) }} />
            </div>
          </motion.div>
        </AnimatePresence>
      </div>
      <div style={{ flex: 1, minHeight: 18 }} />
      {/* bar */}
      <div
        style={{
          position: "relative",
          width: BAR_W,
          height: 64,
          flexShrink: 0,
          borderRadius: 32,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px ${alpha(page.color, 0.28)}, 0 2px 6px rgb(0 0 0 / 0.08)`,
          transition: "box-shadow 0.35s",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: pillLeft,
            top: 10,
            width: pillWidth,
            height: 44,
            borderRadius: 22,
            background: TABS.map((t, i) => `linear-gradient(${fade(filled ? t.color : alpha(t.color, 0.16), weights[i] / total)} 0 0)`).join(", "),
          }}
        />
        {TABS.map((t, index) => {
          const s = Math.min(Math.max(sel[index], 0), 1);
          const d = distances.current[index];
          const dip = track(squeezeT, 1, [linearKF(1, 0.01 + Math.max(d - 1, 0) * 0.04), cubicKF(squeeze, 0.12), springKF(1, 0.45, [0.3, 0.5])]);
          const ink = mixColor(Palette.secondaryLabel, filled ? "#fff" : t.color, s);
          return (
            <div
              key={index}
              onClick={() => select(index)}
              style={{
                position: "absolute",
                left: lefts[index],
                top: 10,
                width: widths[index],
                height: 44,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: ink,
                cursor: "pointer",
                transform: `scale(${index === selected ? 1 : dip})`,
              }}
            >
              <Bounce trigger={bounces[index]} style={{ width: 24, height: 24, alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                {t.icon(21)}
              </Bounce>
              <div style={{ width: Math.max(sel[index], 0) * (7 + textWidths[index]), overflow: "hidden", opacity: s, filter: `blur(${4 * (1 - s)}px)`, flexShrink: 0 }}>
                <div style={{ ...TITLE, paddingLeft: 7, whiteSpace: "nowrap" }}>{ctx.t(...t.title)}</div>
              </div>
            </div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap a tab" zh="点击任一标签" style={{ paddingTop: 14 }} />
      <div style={{ flex: 1 }} />
    </div>
  );
}
