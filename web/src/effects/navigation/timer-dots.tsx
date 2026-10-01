/** navigation.timer-dots · 计时自动翻页圆点 (Navigation+TimerDots.swift) */
import { motion } from "motion/react";
import { CalendarDays } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, clamp, demoCard, elementScale, localPoint, spring, useHaptics, type DemoProps } from "../../kit";
import { BellFill, BlurReplace, colorGradient } from "./groupA-kit";
import { CheckSealFill, SparklesFill, useFrame } from "./_stubs-kit";

type L = [string, string];
const PAGES: { icon: ReactNode; title: L; body: L; color: string }[] = [
  { icon: <SparklesFill size={44} />, title: ["Welcome", "欢迎"], body: ["A calmer way to plan your week.", "用更从容的方式规划一周。"], color: Palette.violet },
  { icon: <CalendarDays size={38} strokeWidth={2.3} />, title: ["Plan", "规划"], body: ["Drag tasks straight onto your day.", "把任务直接拖进日程。"], color: Palette.sky },
  {
    icon: (
      <div style={{ position: "relative" }}>
        <BellFill size={38} />
        <div style={{ position: "absolute", right: 1, top: 0, width: 13, height: 13, borderRadius: "50%", background: "#fff", boxShadow: `0 0 0 2px ${Palette.coral}` }} />
      </div>
    ),
    title: ["Focus", "专注"],
    body: ["Only the reminders that matter.", "只保留真正重要的提醒。"],
    color: Palette.coral,
  },
  { icon: <CheckSealFill size={42} />, title: ["Done", "完成"], body: ["Celebrate every small win.", "为每个小成就喝彩。"], color: Palette.green },
];
const now = () => performance.now() / 1000;

export default function TimerDots({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [page, setPage] = useState(0);
  const [paused, setPaused] = useState(false);
  const pausedRef = useRef(false);
  const runStart = useRef(now());
  const banked = useRef(0);
  const press = useRef<{ id: number; x: number; y: number; at: number; failed: boolean } | null>(null);
  const dwell = Math.max(ctx.n("dwell"), 0.1);
  useFrame(true, ctx.isPreview ? 30 : undefined);

  const show = (index: number, byUser = true) => {
    if (index === page) return;
    if (byUser) haptics.selection();
    runStart.current = now();
    banked.current = 0;
    pausedRef.current = false;
    setPaused(false);
    setPage(index);
  };
  const pause = () => {
    if (pausedRef.current) return;
    banked.current += now() - runStart.current;
    runStart.current = now();
    pausedRef.current = true;
    setPaused(true);
  };
  const resume = () => {
    if (!pausedRef.current) return;
    runStart.current = now();
    pausedRef.current = false;
    setPaused(false);
  };

  // Sleeps for what is left of the page's dwell, then hands off to the next page.
  const latestShow = useRef(show);
  latestShow.current = show;
  useEffect(() => {
    if (paused) return;
    const elapsed = banked.current + now() - runStart.current;
    const timer = window.setTimeout(() => latestShow.current((page + 1) % PAGES.length, false), Math.max(dwell - elapsed, 0.05) * 1000);
    return () => window.clearTimeout(timer);
  }, [page, paused, dwell]);

  // Holding pauses until release; a quick tap skips by side; a swipe past 12 pt lets the page scroll.
  const down = (e: React.PointerEvent<HTMLDivElement>) => {
    if (press.current || (e.pointerType === "mouse" && e.button !== 0)) return;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch {
      /* pointer already gone */
    }
    press.current = { id: e.pointerId, x: e.clientX, y: e.clientY, at: now(), failed: false };
    pause();
  };
  const moved = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId || p.failed) return;
    if (Math.hypot(e.clientX - p.x, e.clientY - p.y) / (elementScale(e.currentTarget) || 1) > 12) {
      p.failed = true;
      resume();
    }
  };
  const up = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId) return;
    press.current = null;
    resume();
    if (p.failed || e.type === "pointercancel") return;
    if (now() - p.at >= 0.25) return;
    const forward = localPoint(e, e.currentTarget).x > 135;
    show((page + (forward ? 1 : PAGES.length - 1)) % PAGES.length);
  };

  const item = PAGES[page];
  const dot = ctx.n("dot");
  const active = Math.max(ctx.n("width"), dot);
  const t = now();
  const running = paused ? 0 : t - runStart.current;
  const linear = clamp((banked.current + running) / dwell);
  const eased = linear * linear * (3 - 2 * linear);
  const breath = paused ? 0.8 + 0.2 * Math.cos(((t - runStart.current) * 2 * Math.PI) / 1.6) : 1;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 24 }}>
      <motion.div
        onPointerDown={down}
        onPointerMove={moved}
        onPointerUp={up}
        onPointerCancel={up}
        initial={false}
        animate={{ scale: paused ? 0.98 : 1 }}
        transition={spring(0.3, 0.8)}
        style={{ width: 270, height: 210, flexShrink: 0, cursor: "pointer", touchAction: "pan-y", userSelect: "none", WebkitUserSelect: "none" }}
      >
        <BlurReplace id={page} transition={anim.easeInOut(0.35)} style={{ width: 270, height: 210 }}>
          <div style={{ ...demoCard(26), width: 270, height: 210, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
            <div
              style={{
                width: 80,
                height: 80,
                borderRadius: 24,
                background: colorGradient(item.color),
                boxShadow: `0 8px 14px ${alpha(item.color, 0.35)}`,
                color: "#fff",
                display: "grid",
                placeItems: "center",
              }}
            >
              {item.icon}
            </div>
            <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }}>{ctx.t(...item.title)}</div>
            <div style={{ fontSize: 15, lineHeight: "20px", color: Palette.secondaryLabel, textAlign: "center", padding: "0 12px" }}>{ctx.t(...item.body)}</div>
          </div>
        </BlurReplace>
      </motion.div>
      <div style={{ display: "flex", gap: 8, flexShrink: 0 }}>
        {PAGES.map((_, index) => {
          const isActive = index === page;
          return (
            <motion.div
              key={index}
              onClick={() => show(index)}
              initial={false}
              animate={{ width: isActive ? active : dot }}
              transition={spring(0.4, 0.75)}
              style={{ position: "relative", height: dot, cursor: "pointer" }}
            >
              <div style={{ position: "absolute", inset: -8 }} />
              <div style={{ position: "absolute", inset: 0, borderRadius: dot / 2, background: Palette.labelAlpha(0.16), overflow: "hidden" }}>
                {isActive && <div style={{ width: Math.max(active * eased, dot), height: dot, borderRadius: dot / 2, background: item.color, opacity: breath }} />}
              </div>
            </motion.div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Hold the card to pause · tap its edges or a dot" zh="按住卡片暂停 · 点击两侧或圆点跳页" />
    </div>
  );
}
