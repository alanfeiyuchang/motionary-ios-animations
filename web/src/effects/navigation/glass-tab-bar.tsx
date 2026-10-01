/** navigation.glass-tab-bar · 液态玻璃标签栏 (Navigation+GlassTabBar.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Droplet, Flame, Leaf, Mountain, Search, Sparkles } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, glass, localPoint, spring, springDB, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { HeartFill, HouseFill, PersonFill, SquareGrid2x2Fill } from "./groupA-kit";
import { useMotionNumber } from "./nav-util";
import { GradientStroke, diag, useNavPan } from "./_r2";

const TABS: { icon: (size: number) => ReactNode; title: [string, string] }[] = [
  { icon: (s) => <HouseFill size={s} />, title: ["Home", "首页"] },
  { icon: (s) => <SquareGrid2x2Fill size={s} />, title: ["Browse", "浏览"] },
  { icon: (s) => <HeartFill size={s} />, title: ["Saved", "收藏"] },
  { icon: (s) => <PersonFill size={s} />, title: ["Me", "我的"] },
];
const SLOT = 58;
const PAD = 4;
const HEIGHT = 60;
const WIDTH = SLOT * TABS.length + PAD * 2;

const FEED_ICONS = [
  // sun.horizon.fill
  <svg key={0} width={36} height={36} viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth={2} strokeLinecap="round">
    <path d="M6.200 15.500a5.800 5.800 0 0 1 11.600 0Z" stroke="none" />
    <path d="M12 4.200v2.200M4.300 7.800l1.500 1.500M19.700 7.800l-1.500 1.500M1.800 15h1.600M20.600 15h1.600M2.500 19h19" fill="none" />
  </svg>,
  <Leaf key={1} size={34} fill="currentColor" strokeWidth={1.5} />,
  <Sparkles key={2} size={34} fill="currentColor" strokeWidth={1.2} />,
  <Mountain key={3} size={34} fill="currentColor" strokeWidth={2} />,
  <Droplet key={4} size={34} fill="currentColor" strokeWidth={1.5} />,
  <Flame key={5} size={34} fill="currentColor" strokeWidth={1.5} />,
];

function FeedCard({ index }: { index: number }) {
  const s = Palette.spectrum;
  return (
    <div style={{ position: "relative", height: 104, borderRadius: 22, background: diag(s[index % s.length], s[(index + 2) % s.length]), flexShrink: 0 }}>
      <div style={{ position: "absolute", left: 16, bottom: 16, display: "flex", flexDirection: "column", gap: 6 }}>
        <div style={{ width: 110, height: 9, borderRadius: 4.5, background: white(0.85) }} />
        <div style={{ width: 70, height: 7, borderRadius: 3.5, background: white(0.5) }} />
      </div>
      <div style={{ position: "absolute", right: 16, top: 16, color: white(0.9) }}>{FEED_ICONS[index % FEED_ICONS.length]}</div>
    </div>
  );
}

function IconRow({ ctx, color }: { ctx: DemoProps["ctx"]; color: string }) {
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: WIDTH, height: HEIGHT, display: "flex", alignItems: "center", color }}>
      {TABS.map((t, index) => (
        <div key={index} style={{ width: SLOT, display: "flex", flexDirection: "column", alignItems: "center", gap: 3, marginLeft: index === 0 ? PAD : 0 }}>
          <div style={{ height: 20, display: "grid", placeItems: "center" }}>{t.icon(21)}</div>
          <div style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...t.title)}</div>
        </div>
      ))}
    </div>
  );
}

const RIM = `linear-gradient(to bottom, ${white(0.7)}, ${white(0.08)}, ${white(0.3)})`;

function BarSurface() {
  return (
    <div style={{ position: "absolute", inset: 0, borderRadius: HEIGHT / 2, ...glass("ultraThin"), boxShadow: "0 8px 18px rgb(0 0 0 / 0.16)" }}>
      <GradientStroke gradient={RIM} />
    </div>
  );
}

export default function GlassTabBar({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [selected, setSelected] = useState(0);
  const selectedRef = useRef(0);
  const hovered = useRef(0);
  const leadMV = useMotionValue(PAD);
  const trailMV = useMotionValue(PAD + SLOT);
  const liftMV = useMotionValue(0);
  const lead = useMotionNumber(leadMV);
  const trail = useMotionNumber(trailMV);
  const lift = useMotionNumber(liftMV);
  /** Where the two edges are heading (SwiftUI state values, as opposed to the presented ones). */
  const goal = useRef({ lead: PAD, trail: PAD + SLOT });
  const dragging = useRef(false);
  const [minimized, setMinimizedState] = useState(false);
  const minimizedRef = useRef(false);
  const moveToken = useRef(0);
  const travel = useRef(0);
  const lastScroll = useRef(0);
  const autoStep = useRef(0);
  const scroller = useRef<HTMLDivElement>(null);

  const dark = ctx.scheme === "dark";
  const tint = dark ? "#8FC0FF" : "#1F62F2";
  const magnify = ctx.n("magnify");

  const pick = (index: number) => {
    selectedRef.current = index;
    setSelected(index);
  };
  const indexAt = (x: number) => Math.min(Math.max(Math.floor((x - PAD) / SLOT), 0), TABS.length - 1);

  const setMinimized = (target: boolean) => {
    if (target === minimizedRef.current) return;
    minimizedRef.current = target;
    setMinimizedState(target);
  };

  /** Sends the lens to a slot: the edge facing the target leads, the other one lags, and the lift pulses. */
  const move = (index: number, response: number) => {
    const targetLead = PAD + index * SLOT;
    const targetTrail = targetLead + SLOT;
    const goingRight = targetLead + targetTrail > goal.current.lead + goal.current.trail;
    const fast = spring(response, 0.72);
    const slow = spring(response * ctx.n("lag"), 0.82);
    pick(index);
    hovered.current = index;
    goal.current = { lead: targetLead, trail: targetTrail };
    animate(trailMV, targetTrail, goingRight ? fast : slow);
    animate(leadMV, targetLead, goingRight ? slow : fast);
    moveToken.current += 1;
    const token = moveToken.current;
    animate(liftMV, 1, spring(0.24, 0.7));
    after(response * 0.85, () => {
      if (token !== moveToken.current || dragging.current) return;
      animate(liftMV, 0, spring(0.42, 0.6));
    });
  };

  const select = (index: number) => {
    if (index === selectedRef.current) return;
    haptics.selection();
    move(index, ctx.n("response"));
  };

  const tapped = (x: number) => {
    if (minimizedRef.current) {
      haptics.tap("light");
      travel.current = 0;
      setMinimized(false);
      return;
    }
    select(indexAt(x));
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (minimizedRef.current) return;
        if (!dragging.current) {
          dragging.current = true;
          moveToken.current += 1;
          animate(liftMV, 1, spring(0.24, 0.7));
        }
        const half = SLOT / 2;
        const centre = Math.min(Math.max(s.location.x, PAD + half), WIDTH - PAD - half);
        const goingRight = centre > (goal.current.lead + goal.current.trail) / 2;
        const fast = spring(0.16, 0.86);
        const slow = spring(0.2 * ctx.n("lag"), 0.86);
        goal.current = { lead: centre - half, trail: centre + half };
        animate(trailMV, centre + half, goingRight ? fast : slow);
        animate(leadMV, centre - half, goingRight ? slow : fast);
        const now = indexAt(centre);
        if (now !== hovered.current) {
          hovered.current = now;
          pick(now);
          haptics.selection();
        }
      },
      onEnd: () => {
        if (!dragging.current) return;
        dragging.current = false;
        haptics.tap("light");
        move(hovered.current, ctx.n("response") * 0.8);
      },
    },
    { axis: "horizontal", minimumDistance: 6 },
  );

  const handleScroll = (newValue: number) => {
    const oldValue = lastScroll.current;
    lastScroll.current = newValue;
    if (!ctx.b("minimize")) return setMinimized(false);
    const delta = newValue - oldValue;
    if (newValue < 20) {
      travel.current = 0;
      return setMinimized(false);
    }
    if (delta === 0) return;
    if (travel.current !== 0 && delta > 0 !== travel.current > 0) travel.current = 0;
    travel.current += delta;
    if (travel.current > 30) setMinimized(true);
    else if (travel.current < -15) setMinimized(false);
  };

  const scrollTo = (y: number) => {
    const el = scroller.current;
    if (!el) return;
    animate(el.scrollTop, y, { ...springDB(0.9, 0), onUpdate: (v) => (el.scrollTop = v) });
  };

  // Preview loop: three tab changes, a scroll that minimises the bar, a scroll back, then the first tab again.
  useAutoplay(
    ctx.isPreview,
    () => {
      const canMinimize = ctx.b("minimize") && ctx.isPreview;
      const step = autoStep.current % (canMinimize ? 6 : 4);
      autoStep.current += 1;
      if (step <= 2) select(step + 1);
      else if (step === 3) {
        if (canMinimize) scrollTo(260);
        else select(0);
      } else if (step === 4) scrollTo(0);
      else select(0);
    },
    { every: 1.25 },
  );

  // GlassLensLiftLayer
  const lensW = Math.max(trail - lead, 24) * (1 + 0.08 * lift);
  const lensH = (HEIGHT - PAD * 2) * (1 + 0.18 * lift);
  const cx = (lead + trail) / 2;
  const cy = HEIGHT / 2;
  const x0 = cx - lensW / 2;
  const y0 = cy - lensH / 2;
  const r = Math.min(lensW, lensH) / 2;
  const capsule = `M${x0 + r} ${y0}H${x0 + lensW - r}A${r} ${r} 0 0 1 ${x0 + lensW - r} ${y0 + lensH}H${x0 + r}A${r} ${r} 0 0 1 ${x0 + r} ${y0}Z`;
  const outer = `M-12 -12H${WIDTH + 12}V${HEIGHT + 12}H-12Z`;
  const glassAlpha = dark ? 0.12 + 0.06 * lift : 0.42 + 0.14 * lift;
  const minimize = spring(0.45, 0.8);

  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div
        ref={scroller}
        onScroll={(e) => handleScroll(e.currentTarget.scrollTop)}
        style={{ position: "absolute", inset: 0, overflowY: ctx.isPreview ? "hidden" : "auto", touchAction: "pan-y", scrollbarWidth: "none" }}
      >
        <div style={{ padding: "16px 16px 96px", display: "flex", flexDirection: "column", gap: 12 }}>
          <div style={{ padding: "0 4px", display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700 }}>{ctx.t(...TABS[selected].title)}</div>
            <DemoHint ctx={ctx} en="Tap a tab or drag the lens · scroll to minimise" zh="点击标签或拖动透镜 · 滚动可收起" style={{ textAlign: "left" }} />
          </div>
          {Array.from({ length: 9 }, (_, index) => (
            <FeedCard key={index} index={index} />
          ))}
        </div>
      </div>
      {/* bar */}
      <div style={{ position: "absolute", left: 15, bottom: 16, width: 310, display: "flex", alignItems: "center", pointerEvents: "none" }}>
        <motion.div
          {...pan}
          onClick={(e) => tapped(localPoint(e, e.currentTarget).x)}
          initial={false}
          animate={{ width: minimized ? HEIGHT : WIDTH }}
          transition={minimize}
          style={{ position: "relative", height: HEIGHT, flexShrink: 0, cursor: "pointer", pointerEvents: "auto", touchAction: "pan-y" }}
        >
          <BarSurface />
          {/* clipped at the sides only: the lifted lens may rise a little above and below the bar */}
          <div style={{ position: "absolute", inset: 0, clipPath: `inset(-10px 0px -10px 0px round ${HEIGHT / 2 + 10}px)` }}>
            <motion.div
              initial={false}
              animate={{ opacity: minimized ? 0 : 1, filter: `blur(${minimized ? 6 : 0}px)` }}
              transition={minimize}
              style={{ position: "absolute", left: 0, top: 0, width: WIDTH, height: HEIGHT }}
            >
              <div style={{ position: "absolute", inset: -12, clipPath: `path(evenodd, "${shift(outer + capsule, 12)}")` }}>
                <div style={{ position: "absolute", left: 12, top: 12 }}>
                  <IconRow ctx={ctx} color={Palette.labelAlpha(0.7)} />
                </div>
              </div>
              {/* the lens */}
              <div
                style={{
                  position: "absolute",
                  left: x0,
                  top: y0,
                  width: lensW,
                  height: lensH,
                  borderRadius: r,
                  background: `linear-gradient(to bottom, ${white(0.12 + 0.3 * lift)}, ${white(0)} 50%), ${white(glassAlpha)}`,
                  boxShadow: `0 ${2 + 6 * lift}px ${5 + 10 * lift}px rgb(0 0 0 / ${0.1 + 0.16 * lift})`,
                }}
              >
                <GradientStroke gradient={`linear-gradient(to bottom, ${white(0.95)}, ${white(dark ? 0.12 : 0.4)}, ${white(0.6)})`} />
              </div>
              {/* tinted, magnified icons seen through the lens */}
              <div style={{ position: "absolute", left: x0, top: y0, width: lensW, height: lensH, borderRadius: r, overflow: "hidden" }}>
                <div
                  style={{
                    position: "absolute",
                    left: -x0,
                    top: -y0,
                    width: WIDTH,
                    height: HEIGHT,
                    transformOrigin: `${cx}px 50%`,
                    transform: `scale(${1 + (magnify - 1) * lift})`,
                  }}
                >
                  <IconRow ctx={ctx} color={tint} />
                </div>
              </div>
            </motion.div>
            <motion.div
              initial={false}
              animate={{ opacity: minimized ? 1 : 0, scale: minimized ? 1 : 0.5 }}
              transition={minimize}
              style={{ position: "absolute", left: 0, top: 0, width: HEIGHT, height: HEIGHT, display: "grid", placeItems: "center", color: tint }}
            >
              {TABS[selected].icon(23)}
            </motion.div>
          </div>
        </motion.div>
        <div style={{ flex: 1 }} />
        <div style={{ position: "relative", width: HEIGHT, height: HEIGHT, display: "grid", placeItems: "center", color: Palette.labelAlpha(0.8), flexShrink: 0 }}>
          <BarSurface />
          <Search size={22} strokeWidth={2.6} style={{ position: "relative" }} />
        </div>
      </div>
    </div>
  );
}

/** Translates an absolute-coordinate path made of M/H/V/A commands by (d, d). */
function shift(path: string, d: number): string {
  return path.replace(/([MHVA])([^MHVAZ]*)/g, (_, cmd: string, args: string) => {
    const n = args.trim().split(/[\s,]+/).map(Number);
    if (cmd === "M") return `M${n[0] + d} ${n[1] + d}`;
    if (cmd === "H") return `H${n[0] + d}`;
    if (cmd === "V") return `V${n[0] + d}`;
    return `A${n[0]} ${n[1]} ${n[2]} ${n[3]} ${n[4]} ${n[5] + d} ${n[6] + d}`;
  });
}
