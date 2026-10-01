/** navigation.icon-pop-bar · 图标表演标签栏 (Navigation+IconPopBar.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Bell, Compass, Heart, House, Send } from "lucide-react";
import { useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { BellFill, BlurReplace, HeartFill, HouseFill, SafariFill } from "./groupA-kit";
import { BOUNCY, cubicKF, linearKF, springKF, track, useSince, type Keyframe } from "./groupB-kit";
import { PaperplaneFill, stageColumn } from "./_r2";

const outline = { size: 23, strokeWidth: 2.4 } as const;
const TABS: { line: ReactNode; fill: ReactNode; label: [string, string]; color: string }[] = [
  { line: <House {...outline} />, fill: <HouseFill size={24} />, label: ["Home", "首页"], color: Palette.indigo },
  { line: <Compass {...outline} />, fill: <SafariFill size={24} />, label: ["Explore", "探索"], color: Palette.mint },
  { line: <Heart {...outline} />, fill: <HeartFill size={24} />, label: ["Likes", "喜欢"], color: Palette.pink },
  { line: <Bell {...outline} />, fill: <BellFill size={24} />, label: ["Alerts", "通知"], color: Palette.amber },
  { line: <Send {...outline} />, fill: <PaperplaneFill size={24} />, label: ["Inbox", "私信"], color: Palette.sky },
];

const move = (v: number): Keyframe => linearKF(v, 0);
const SMOOTH: [number, number] = [0.5, 1];

interface Pose {
  sx: number;
  sy: number;
  x: number;
  y: number;
  angle: number;
  opacity: number;
  origin: string;
}

/** Each icon's own keyframe routine, `t` seconds after its trigger. */
function pose(index: number, t: number, a: number, u: number): Pose {
  const p: Pose = { sx: 1, sy: 1, x: 0, y: 0, angle: 0, opacity: 1, origin: "50% 50%" };
  if (t < 0) return p;
  if (index === 0) {
    // Squash, jump with a stretch, land with a second squash.
    p.origin = "50% 100%";
    p.sy = track(t, 1, [cubicKF(1 - 0.28 * a, 0.1 * u), cubicKF(1 + 0.18 * a, 0.14 * u), cubicKF(1, 0.14 * u), cubicKF(1 - 0.16 * a, 0.08 * u), springKF(1, 0.3 * u, BOUNCY)]);
    p.sx = track(t, 1, [cubicKF(1 + 0.2 * a, 0.1 * u), cubicKF(1 - 0.1 * a, 0.14 * u), cubicKF(1, 0.14 * u), cubicKF(1 + 0.12 * a, 0.08 * u), springKF(1, 0.3 * u, BOUNCY)]);
    p.y = track(t, 0, [cubicKF(0, 0.1 * u), cubicKF(-14 * a, 0.16 * u), cubicKF(0, 0.14 * u)]);
  } else if (index === 1) {
    // One full turn on an underdamped spring, with a small swell.
    p.angle = track(t, 0, [springKF(360, 0.75 * u, [0.45 * u, 0.55]), move(0)]);
    p.sx = p.sy = track(t, 1, [cubicKF(1 + 0.16 * a, 0.18 * u), springKF(1, 0.4 * u, BOUNCY)]);
  } else if (index === 2) {
    // Two beats: a big one and a smaller echo.
    p.sx = p.sy = track(t, 1, [cubicKF(1 - 0.25 * a, 0.08 * u), cubicKF(1 + 0.3 * a, 0.14 * u), cubicKF(1 - 0.04 * a, 0.12 * u), cubicKF(1 + 0.18 * a, 0.12 * u), springKF(1, 0.25 * u, BOUNCY)]);
  } else if (index === 3) {
    // A decaying swing from the top, like a real bell.
    p.origin = "50% 0%";
    p.angle = track(t, 0, [cubicKF(24 * a, 0.1 * u), cubicKF(-20 * a, 0.13 * u), cubicKF(14 * a, 0.12 * u), cubicKF(-8 * a, 0.11 * u), springKF(0, 0.25 * u, SMOOTH)]);
  } else {
    // Flies off up and to the right, then re-enters from the opposite corner.
    p.x = track(t, 0, [cubicKF(-3 * a, 0.08 * u), cubicKF(18 * a, 0.18 * u), move(-16 * a), springKF(0, 0.4 * u, BOUNCY)]);
    p.y = track(t, 0, [cubicKF(3 * a, 0.08 * u), cubicKF(-18 * a, 0.18 * u), move(16 * a), springKF(0, 0.4 * u, BOUNCY)]);
    p.opacity = track(t, 1, [linearKF(1, 0.12 * u), linearKF(0, 0.14 * u), linearKF(1, 0.16 * u)]);
  }
  return p;
}

function TabButton({ index, active, trigger, ctx, onSelect }: { index: number; active: boolean; trigger: number; ctx: DemoProps["ctx"]; onSelect: () => void }) {
  const tab = TABS[index];
  const u = 1 / Math.max(ctx.n("speed"), 0.1);
  const t = useSince(trigger, 1.0 * u + 0.1);
  const p = pose(index, t, ctx.n("amount"), u);
  const count = Math.max(ctx.i("particles"), 0);
  const burst = t < 0 ? 0 : Math.min(t / (0.55 * u), 1);
  const eased = 1 - Math.pow(1 - burst, 3);
  const visible = burst > 0.001 && burst < 0.999;
  const tint = active ? tab.color : Palette.secondaryLabel;
  return (
    <div onClick={onSelect} style={{ flex: 1, height: "100%", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4, cursor: "pointer", color: tint, transition: "color 0.25s" }}>
      <div style={{ position: "relative", height: 30, width: 30, display: "grid", placeItems: "center" }}>
        {/* a ring of dots thrown outward from behind the icon */}
        <div style={{ position: "absolute", left: "50%", top: "50%", opacity: visible ? 1 - burst * burst : 0, pointerEvents: "none" }}>
          {Array.from({ length: count }, (_, k) => {
            const angle = (k / Math.max(count, 1)) * 2 * Math.PI - Math.PI / 2;
            const radius = 8 + 18 * eased;
            const d = k % 2 === 0 ? 4.5 : 3;
            return (
              <div
                key={k}
                style={{
                  position: "absolute",
                  left: -d / 2,
                  top: -d / 2,
                  width: d,
                  height: d,
                  borderRadius: "50%",
                  background: k % 2 === 0 ? tab.color : alpha(tab.color, 0.55),
                  transform: `translate(${Math.cos(angle) * radius}px, ${Math.sin(angle) * radius}px) scale(${1 - 0.85 * burst})`,
                }}
              />
            );
          })}
        </div>
        <div
          style={{
            width: 30,
            height: 28,
            display: "grid",
            placeItems: "center",
            transformOrigin: p.origin,
            transform: `translate(${p.x}px, ${p.y}px) rotate(${p.angle}deg) scale(${p.sx}, ${p.sy})`,
            opacity: p.opacity,
          }}
        >
          <AnimatePresence initial={false} mode="popLayout">
            <motion.div
              key={active ? "fill" : "line"}
              initial={{ opacity: 0, scale: 0.6 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.6 }}
              transition={spring(0.3, 0.8)}
              style={{ display: "grid" }}
            >
              {active ? tab.fill : tab.line}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
      <div style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...tab.label)}</div>
    </div>
  );
}

export default function IconPopBar({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selection, setSelection] = useState(0);
  const [pops, setPops] = useState(() => TABS.map(() => 0));

  const select = (index: number) => {
    haptics.tap("light");
    setPops((p) => p.map((v, i) => (i === index ? v + 1 : v)));
    setSelection(index);
  };

  useAutoplay(ctx.isPreview, () => select((selection + 1) % TABS.length), { every: 1.2 });

  const tab = TABS[selection];
  return (
    <div style={stageColumn(14)}>
      <div
        style={{
          width: 300,
          height: 284,
          flexShrink: 0,
          boxSizing: "border-box",
          padding: 12,
          display: "flex",
          flexDirection: "column",
          borderRadius: 32,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)`,
          overflow: "hidden",
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
          <BlurReplace id={selection} transition={spring(0.3, 0.8)} style={{ justifyItems: "start", padding: "8px 0 0 6px" }}>
            <div style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700, whiteSpace: "nowrap" }}>{ctx.t(...tab.label)}</div>
          </BlurReplace>
          {[0, 1].map((row) => (
            <div key={row} style={{ height: 54, padding: "0 10px", display: "flex", alignItems: "center", gap: 12, borderRadius: 16, background: Palette.labelAlpha(0.035) }}>
              <div style={{ width: 36, height: 36, borderRadius: 10, background: alpha(tab.color, row === 0 ? 0.32 : 0.18), transition: "background 0.25s", flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <PlaceholderLines count={2} color={Palette.labelAlpha(0.09)} />
              </div>
            </div>
          ))}
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ height: 64, display: "flex", borderRadius: 22, background: Palette.labelAlpha(0.05), boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, flexShrink: 0 }}>
          {TABS.map((_, index) => (
            <TabButton key={index} index={index} active={selection === index} trigger={pops[index]} ctx={ctx} onSelect={() => select(index)} />
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap each tab" zh="逐个点击标签" />
    </div>
  );
}
