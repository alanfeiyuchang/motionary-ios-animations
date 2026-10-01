/** navigation.title-scale-tabs · 大标题标签 (Navigation+TitleScaleTabs.swift) */
import { animate, useMotionValue } from "motion/react";
import { Sparkles, Sun } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, rubberBand, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { useTextWidths } from "./groupA-kit";
import { Glyph } from "./groupB-kit";
import { predicted, useMotionNumber } from "./nav-util";
import { diag, stageColumn, useNavPan } from "./_r2";

const PAGES: { title: [string, string]; icon: ReactNode; colors: [string, string]; caption: [string, string] }[] = [
  { title: ["Today", "今日"], icon: <Sun size={62} fill="currentColor" strokeWidth={2.6} />, colors: [Palette.amber, Palette.coral], caption: ["Morning mix", "晨间精选"] },
  { title: ["Discover", "发现"], icon: <Sparkles size={62} fill="currentColor" strokeWidth={1.2} />, colors: [Palette.indigo, Palette.violet], caption: ["New for you", "为你上新"] },
  { title: ["Library", "资料库"], icon: <Glyph name="square.stack.fill" size={62} />, colors: [Palette.mint, Palette.sky], caption: ["Recently added", "最近添加"] },
  { title: ["Profile", "我的"], icon: <Glyph name="person.fill" size={58} />, colors: [Palette.pink, Palette.violet], caption: ["Your year so far", "你的这一年"] },
];

const FRAME = { w: 290, h: 284 };
const FONT = { fontSize: 32, lineHeight: "38px", fontWeight: 700 } as const;
const DESCENT = 32 * 0.241;
const INSET = 22;
const GAP = 16;
const ROW_H = 44;
const PARALLAX = 26;
const LAST = PAGES.length - 1;

const nearness = (index: number, progress: number) => Math.max(0, 1 - Math.abs(index - progress));

function positions(progress: number, widths: number[], small: number): number[] {
  const xs: number[] = [];
  let x = 0;
  widths.forEach((w, index) => {
    xs.push(x);
    x += w * (small + (1 - small) * nearness(index, progress)) + GAP;
  });
  const clamped = Math.min(Math.max(progress, 0), widths.length - 1);
  const lower = Math.floor(clamped);
  const upper = Math.min(lower + 1, widths.length - 1);
  const fraction = clamped - lower;
  const anchor = xs[lower] * (1 - fraction) + xs[upper] * fraction;
  const overshoot = (progress - clamped) * 60;
  return xs.map((v) => v - anchor + INSET - overshoot);
}

export default function TitleScaleTabs({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const dragStart = useRef<number | null>(null);
  const autoForward = useRef(true);
  const small = ctx.n("small");
  const dim = ctx.n("dim");
  const [widths, probe] = useTextWidths(PAGES.map((p) => ctx.t(...p.title)), FONT);

  const settle = (index: number) => {
    const clamped = Math.min(Math.max(index, 0), LAST);
    haptics.selection();
    animate(progressMV, clamped, spring(ctx.n("response"), ctx.n("damping")));
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (dragStart.current === null) {
          progressMV.stop();
          dragStart.current = progressMV.get();
        }
        let page = dragStart.current - s.translation.x / FRAME.w;
        if (page < 0) page = -rubberBand(-page, 0.5);
        if (page > LAST) page = LAST + rubberBand(page - LAST, 0.5);
        progressMV.set(page);
      },
      onEnd: (s) => {
        const start = dragStart.current;
        if (start === null) return;
        dragStart.current = null;
        const projected = s ? start - predicted(s).x / FRAME.w : progressMV.get();
        const limited = Math.min(Math.max(projected, Math.round(start) - 1), Math.round(start) + 1);
        settle(Math.round(limited));
      },
    },
    { axis: "horizontal" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      const current = Math.round(progressMV.get());
      let next = current + (autoForward.current ? 1 : -1);
      if (next >= PAGES.length) {
        autoForward.current = false;
        next = current - 1;
      } else if (next < 0) {
        autoForward.current = true;
        next = current + 1;
      }
      settle(next);
    },
    { every: 1.5 },
  );

  const xs = positions(progress, widths, small);
  const page = Math.round(progress);
  const targetXs = positions(page, widths, small);

  return (
    <div style={stageColumn(14)}>
      {probe}
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
        {/* titles: drawn once at full size, scaled from the baseline */}
        <div style={{ position: "absolute", left: 0, top: 18, width: FRAME.w, height: ROW_H }}>
          {PAGES.map((p, index) => {
            const near = nearness(index, progress);
            const scale = small + (1 - small) * near;
            const rest = index < progress ? 0 : dim;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: 0,
                  bottom: 0,
                  ...FONT,
                  color: Palette.label,
                  whiteSpace: "nowrap",
                  transformOrigin: "0 100%",
                  transform: `translate(${xs[index]}px, ${-DESCENT * (1 - scale)}px) scale(${scale})`,
                  opacity: rest + (1 - rest) * near,
                  pointerEvents: "none",
                }}
              >
                {ctx.t(...p.title)}
              </div>
            );
          })}
        </div>
        {/* pages */}
        <div style={{ position: "absolute", left: 0, top: 18 + ROW_H + 10, width: FRAME.w }}>
          {PAGES.map((p, index) => {
            const distance = index - progress;
            if (Math.abs(distance) >= 1.5) return null;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: 0,
                  top: 0,
                  width: FRAME.w,
                  padding: `0 ${INSET}px`,
                  boxSizing: "border-box",
                  display: "flex",
                  flexDirection: "column",
                  gap: 12,
                  transform: `translateX(${distance * FRAME.w}px)`,
                  opacity: 1 - Math.min(Math.abs(distance), 1) * 0.5,
                }}
              >
                <div style={{ position: "relative", height: 112, borderRadius: 20, background: diag(...p.colors), overflow: "hidden", flexShrink: 0 }}>
                  <div style={{ position: "absolute", right: 20, top: 0, bottom: 0, display: "flex", alignItems: "center", color: white(0.3), transform: `translateX(${distance * PARALLAX}px)` }}>
                    {p.icon}
                  </div>
                  <div style={{ position: "absolute", left: 14, bottom: 14, fontSize: 17, lineHeight: "22px", fontWeight: 600, color: "#fff" }}>{ctx.t(...p.caption)}</div>
                </div>
                {[0, 1].map((row) => (
                  <div key={row} style={{ display: "flex", alignItems: "center", gap: 12 }}>
                    <div style={{ width: 34, height: 34, borderRadius: 10, background: alpha(p.colors[row % p.colors.length], 0.3), flexShrink: 0 }} />
                    <div style={{ flex: 1 }}>
                      <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
                    </div>
                  </div>
                ))}
              </div>
            );
          })}
        </div>
        {/* invisible tap targets over the titles at their settled positions */}
        <div style={{ position: "absolute", left: 0, top: 0, width: FRAME.w, height: 70, overflow: "hidden" }}>
          {PAGES.map((_, index) => {
            const scale = index === page ? 1 : small;
            return (
              <div
                key={index}
                onClick={() => index !== Math.round(progressMV.get()) && settle(index)}
                style={{ position: "absolute", left: targetXs[index] - 4, top: 14, width: widths[index] * scale + 8, height: ROW_H + 8, cursor: "pointer" }}
              />
            );
          })}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Swipe the page, or tap a title" zh="左右滑动页面，或点击标题" />
    </div>
  );
}
