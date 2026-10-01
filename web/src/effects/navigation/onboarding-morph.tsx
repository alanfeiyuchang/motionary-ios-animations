/** navigation.onboarding-morph · 引导页圆点变按钮 (Navigation+OnboardingMorph.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { ArrowRight, Check, Layers, Sparkles, Users } from "lucide-react";
import { useId, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, spring, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { useMotionNumber } from "./nav-util";
import { PaperplaneFill, diag, stageColumn, useAutoplayFlag, usePageDrag } from "./_r2";

const PAGES: { icon: ReactNode; title: [string, string]; subtitle: [string, string]; colors: [string, string] }[] = [
  { icon: <Sparkles size={44} fill="currentColor" strokeWidth={1.2} />, title: ["Collect ideas", "收集灵感"], subtitle: ["Save anything in one tap", "一键保存任何内容"], colors: [Palette.amber, Palette.coral] },
  { icon: <Layers size={44} fill="currentColor" strokeWidth={1.6} />, title: ["Stay organised", "井井有条"], subtitle: ["Boards sort themselves", "看板会自动归类"], colors: [Palette.mint, Palette.sky] },
  { icon: <Users size={44} fill="currentColor" strokeWidth={2.4} />, title: ["Share with friends", "和朋友分享"], subtitle: ["Edit together, live", "实时一起编辑"], colors: [Palette.pink, Palette.violet] },
  { icon: <PaperplaneFill size={42} />, title: ["Ready to go", "准备好了"], subtitle: ["It takes ten seconds", "只需要十秒钟"], colors: [Palette.indigo, Palette.violet] },
];
const FRAME = { w: 290, h: 284 };
const DOT = 8;
const ACTIVE = 22;
const GAP = 8;
const BUTTON_H = 52;
const IND = { w: 262, h: 60 };
const LAST = PAGES.length - 1;

const smooth = (value: number, from: number, to: number) => {
  const t = Math.min(Math.max((value - from) / (to - from), 0), 1);
  return t * t * (3 - 2 * t);
};

interface Box {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** Everything the indicator needs for one fractional page (`OnboardGeometry`). */
function geometry(progress: number, buttonWidth: number) {
  const m = Math.min(Math.max(progress - (LAST - 1), 0), 1);
  const merge = smooth(m, 0, 0.55);
  const grow = smooth(m, 0.35, 1);
  const overshoot = Math.max(progress - LAST, 0);
  const cx0 = IND.w / 2;
  const cy = IND.h / 2;
  const nears = PAGES.map((_, index) => Math.max(0, 1 - Math.abs(index - Math.min(Math.max(progress, 0), LAST))));
  const widths = nears.map((near) => DOT + (ACTIVE - DOT) * near);
  const total = widths.reduce((a, b) => a + b, 0) + GAP * LAST;
  const dots: Box[] = [];
  const accent: Box[] = [];
  let x = cx0 - total / 2;
  widths.forEach((width, index) => {
    const rest = x + width / 2;
    x += width + GAP;
    const cx = rest + (cx0 - rest) * merge;
    dots.push({ x: cx - width / 2, y: cy - DOT / 2, w: width, h: DOT });
    const share = Math.max(nears[index], merge);
    if (share > 0.02) {
      const w = width * Math.min(share * 1.4, 1);
      const h = DOT * Math.min(share * 1.4, 1);
      accent.push({ x: cx - w / 2, y: cy - h / 2, w, h });
    }
  });
  if (grow > 0) {
    const scale = 1 + overshoot * 0.5;
    const w = (ACTIVE + (buttonWidth - ACTIVE) * grow) * scale;
    const h = (DOT + (BUTTON_H - DOT) * grow) * scale;
    accent.push({ x: cx0 - w / 2, y: cy - h / 2, w, h });
  }
  return { dots, accent, merge, grow, overshoot };
}

export default function OnboardingMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const progressMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const goal = useRef(0);
  const [done, setDoneState] = useState(false);
  const doneRef = useRef(false);
  const cancelRestart = useRef<(() => void) | null>(null);
  const uid = useId().replace(/:/g, "");
  const buttonWidth = ctx.n("width");
  const goo = ctx.n("goo");

  const setDone = (v: boolean) => {
    doneRef.current = v;
    setDoneState(v);
  };

  const settle = (index: number) => {
    const clamped = Math.min(Math.max(index, 0), LAST);
    haptics.tap(clamped === LAST ? "soft" : "light");
    goal.current = clamped;
    animate(progressMV, clamped, spring(ctx.n("response"), ctx.n("damping")));
  };

  const start = () => {
    if (doneRef.current) return;
    haptics.success();
    setDone(true);
    cancelRestart.current?.();
    cancelRestart.current = after(1.0, () => {
      goal.current = 0;
      animate(progressMV, 0, spring(0.6, 0.86));
      setDone(false);
    });
  };

  const advance = () => {
    const page = Math.round(goal.current);
    if (page >= LAST) start();
    else settle(page + 1);
  };

  useAutoplayFlag(ctx.isPreview, () => !doneRef.current && advance(), { every: 1.4 });

  const { pan } = usePageDrag(progressMV, {
    unit: FRAME.w,
    last: LAST,
    bandLow: 0.4,
    bandHigh: 0.25,
    enabled: () => !doneRef.current,
    onPage: (page) => (goal.current = page),
    settle: (index) => settle(index),
  });

  const g = geometry(progress, buttonWidth);
  // Goo only while shapes are actually merging; at rest the edges stay crisp.
  const mixing = Math.sin(Math.PI * Math.min(Math.max(g.merge * 0.5 + g.grow * 0.5, 0), 1));
  const blur = goo * mixing;
  const reveal = smooth(g.grow, 0.7, 1);
  const labelSwap = done ? spring(0.35, 0.7) : spring(0.6, 0.86);

  return (
    <div style={stageColumn(14)}>
      <div
        {...pan}
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          borderRadius: 32,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)`,
          overflow: "hidden",
          touchAction: "pan-y",
        }}
      >
        {/* pages */}
        <div style={{ position: "absolute", left: 0, top: 0, width: FRAME.w, height: FRAME.h - IND.h - 14, overflow: "hidden" }}>
          {PAGES.map((item, index) => {
            const distance = index - progress;
            if (Math.abs(distance) >= 1.4) return null;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  inset: 0,
                  paddingTop: 10,
                  boxSizing: "border-box",
                  display: "flex",
                  flexDirection: "column",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 14,
                  transform: `translateX(${distance * FRAME.w}px)`,
                  opacity: 1 - Math.min(Math.abs(distance), 1) * 0.6,
                }}
              >
                <div
                  style={{
                    width: 96,
                    height: 96,
                    borderRadius: "50%",
                    background: diag(...item.colors),
                    boxShadow: `0 8px 16px ${alpha(item.colors[0], 0.4)}`,
                    color: "#fff",
                    display: "grid",
                    placeItems: "center",
                    transform: `translateX(${distance * 40}px)`,
                    flexShrink: 0,
                  }}
                >
                  <div style={{ transform: `translateX(${distance * 30}px)`, display: "grid" }}>{item.icon}</div>
                </div>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
                  <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700, whiteSpace: "nowrap" }}>{ctx.t(...item.title)}</div>
                  <div style={{ fontSize: 15, lineHeight: "20px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...item.subtitle)}</div>
                </div>
              </div>
            );
          })}
        </div>
        {/* indicator */}
        <div style={{ position: "absolute", left: (FRAME.w - IND.w) / 2, bottom: 14, width: IND.w, height: IND.h }}>
          <svg width={IND.w} height={IND.h} style={{ position: "absolute", inset: 0, overflow: "visible", opacity: 1 - g.merge }}>
            {g.dots.map((r, i) => (
              <rect key={i} x={r.x} y={r.y} width={r.w} height={r.h} rx={r.h / 2} fill={Palette.labelAlpha(0.22)} />
            ))}
          </svg>
          <svg width={IND.w} height={IND.h} style={{ position: "absolute", inset: 0, overflow: "visible", filter: `drop-shadow(0 6px 12px ${alpha(Palette.indigo, 0.4 * g.grow)})` }}>
            <defs>
              <linearGradient id={`${uid}-g`} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={IND.w} y2={0}>
                <stop offset="0" stopColor={Palette.indigo} />
                <stop offset="1" stopColor={Palette.violet} />
              </linearGradient>
              <filter id={`${uid}-goo`} filterUnits="userSpaceOnUse" x={-30} y={-30} width={IND.w + 60} height={IND.h + 60} colorInterpolationFilters="sRGB">
                <feGaussianBlur in="SourceGraphic" stdDeviation={Math.max(blur, 0.01)} result="b" />
                <feColorMatrix in="b" mode="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 24 -12" />
              </filter>
              <mask id={`${uid}-m`} maskUnits="userSpaceOnUse" x={-30} y={-30} width={IND.w + 60} height={IND.h + 60}>
                <g filter={blur > 0.3 ? `url(#${uid}-goo)` : undefined}>
                  {g.accent.map((r, i) => (
                    <rect key={i} x={r.x} y={r.y} width={Math.max(r.w, 0)} height={Math.max(r.h, 0)} rx={r.h / 2} fill="#fff" />
                  ))}
                </g>
              </mask>
            </defs>
            <rect x={-30} y={-30} width={IND.w + 60} height={IND.h + 60} fill={`url(#${uid}-g)`} mask={`url(#${uid}-m)`} />
          </svg>
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff", opacity: reveal, transform: `scale(${(0.9 + 0.1 * reveal) * (1 + g.overshoot * 0.5)})`, pointerEvents: "none" }}>
            <AnimatePresence initial={false}>
              {done ? (
                <motion.div key="done" initial={{ opacity: 0, scale: 0.4 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.4 }} transition={labelSwap} style={{ gridArea: "1 / 1", display: "grid" }}>
                  <Check size={24} strokeWidth={3.6} />
                </motion.div>
              ) : (
                <motion.div
                  key="label"
                  initial={{ opacity: 0, scale: 0.8 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.8 }}
                  transition={labelSwap}
                  style={{ gridArea: "1 / 1", display: "flex", alignItems: "center", gap: 6 }}
                >
                  <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("Get started", "开始使用")}</span>
                  <ArrowRight size={17} strokeWidth={3.2} />
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
        {/* tap target over the indicator: the button on the last page, "next" before that */}
        <div onClick={advance} style={{ position: "absolute", left: (FRAME.w - buttonWidth) / 2, bottom: 14, width: buttonWidth, height: IND.h, cursor: "pointer" }} />
      </div>
      <DemoHint ctx={ctx} en="Swipe to the last page and back" zh="滑到最后一页，再滑回来" />
    </div>
  );
}
