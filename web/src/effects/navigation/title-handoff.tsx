/** navigation.title-handoff · 标题接力转场 (Navigation+TitleHandoff.swift) */
import { animate, useMotionValue } from "motion/react";
import { ChevronLeft, ChevronRight, ListMusic, MicVocal } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Glyph } from "./groupB-kit";
import { predicted, useMotionNumber } from "./nav-util";
import { diag, mixColor, stageColumn, useNavPan } from "./_r2";

const ROWS: { icon: ReactNode; title: [string, string]; colors: [string, string] }[] = [
  { icon: <ListMusic size={16} strokeWidth={3} />, title: ["Playlists", "播放列表"], colors: [Palette.pink, Palette.coral] },
  { icon: <MicVocal size={15} strokeWidth={2.8} />, title: ["Artists", "艺人"], colors: [Palette.indigo, Palette.violet] },
  { icon: <Glyph name="square.stack.fill" size={15} />, title: ["Albums", "专辑"], colors: [Palette.mint, Palette.sky] },
  {
    // arrow.down.circle.fill
    icon: (
      <svg width={16} height={16} viewBox="0 0 24 24">
        <path fill="currentColor" fillRule="evenodd" d="M12 1.5a10.5 10.5 0 1 1 0 21 10.5 10.5 0 0 1 0-21Zm0 4.700a1.200 1.200 0 0 0-1.200 1.200v6.300l-2.300-2.300a1.200 1.200 0 0 0-1.700 1.700l4.350 4.350a1.200 1.200 0 0 0 1.700 0l4.350-4.350a1.200 1.200 0 0 0-1.700-1.700l-2.300 2.300V7.400A1.200 1.200 0 0 0 12 6.200Z" />
      </svg>
    ),
    title: ["Downloads", "已下载"],
    colors: [Palette.amber, Palette.coral],
  },
];
const FRAME = { w: 290, h: 284 };
const LARGE = 30;
const SMALL = 17 / 30;
const LINE = 36;
const LARGE_ORIGIN = { x: 18, y: 46 };
const BACK_ORIGIN = { x: 32, y: 27 - (LINE * SMALL) / 2 };
const ROW_TOP = 96;
const ROW_PITCH = 45;
const ROW_H = 43;
const ROW_LABEL_X = 58;
const rowLabelOrigin = (index: number) => ({ x: ROW_LABEL_X, y: ROW_TOP + index * ROW_PITCH + ROW_H / 2 - (LINE * SMALL) / 2 });
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const TITLE = { position: "absolute", left: 0, top: 0, fontSize: LARGE, lineHeight: `${LINE}px`, fontWeight: 700, whiteSpace: "nowrap", transformOrigin: "0 0" } as const;

export default function TitleHandoff({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const goal = useRef(0);
  const [source, setSource] = useState(0);
  const dragging = useRef(false);
  const autoStep = useRef(0);
  const [, rerender] = useState(0);

  const move = () => spring(ctx.n("response"), ctx.n("damping"));
  const go = (to: number) => {
    goal.current = to;
    rerender((n) => n + 1);
    animate(progressMV, to, move());
  };
  const push = (index: number) => {
    if (goal.current >= 0.01) return;
    haptics.tap("light");
    setSource(index);
    go(1);
  };
  const pop = () => {
    if (goal.current <= 0.5) return;
    haptics.tap("light");
    go(0);
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (!dragging.current) {
          if (!(goal.current > 0.99 && s.translation.x > 0)) return;
          dragging.current = true;
          progressMV.stop();
        }
        goal.current = Math.min(Math.max(1 - s.translation.x / FRAME.w, 0), 1);
        progressMV.set(goal.current);
      },
      onEnd: (s) => {
        if (!dragging.current) return;
        dragging.current = false;
        const projected = s ? 1 - predicted(s).x / FRAME.w : goal.current;
        haptics.tap("light");
        go(projected > 0.5 ? 1 : 0);
      },
    },
    { axis: "horizontal" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      if (goal.current > 0.5) pop();
      else {
        push(autoStep.current % ROWS.length);
        autoStep.current += 1;
      }
    },
    { every: 1.5 },
  );

  const p = Math.min(Math.max(progress, 0), 1);
  const row = ROWS[source];
  const rowOrigin = rowLabelOrigin(source);
  const parallax = ctx.n("parallax");
  const edge = Math.min(p * 4, 1) * Math.min((1 - p) * 4, 1);

  return (
    <div style={stageColumn(14)}>
      <div {...pan} style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 32, overflow: "hidden", background: Palette.elevated, boxShadow: "0 10px 18px rgb(0 0 0 / 0.16)", touchAction: "pan-y" }}>
        {/* list page */}
        <div style={{ position: "absolute", inset: 0, background: Palette.elevated, transform: `translateX(${-p * parallax * FRAME.w}px)` }}>
          {ROWS.map((r, index) => (
            <div
              key={index}
              style={{
                position: "absolute",
                left: 0,
                top: ROW_TOP + index * ROW_PITCH,
                width: FRAME.w,
                height: ROW_H,
                boxSizing: "border-box",
                padding: "0 18px",
                display: "flex",
                alignItems: "center",
                gap: 12,
                background: Palette.labelAlpha(index === source ? 0.06 * Math.min(p * 4, 1) : 0),
              }}
            >
              <div style={{ width: 28, height: 28, borderRadius: 8, background: diag(...r.colors), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{r.icon}</div>
              {/* the tapped row's label is drawn by the travelling copy while the push is under way */}
              <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap", opacity: index === source && p > 0.001 ? 0 : 1 }}>{ctx.t(...r.title)}</span>
              <div style={{ flex: 1 }} />
              <ChevronRight size={15} strokeWidth={3.2} color={Palette.secondaryLabel} style={{ opacity: 0.5 }} />
            </div>
          ))}
          <div style={{ position: "absolute", inset: 0, background: "#000", opacity: 0.12 * p, pointerEvents: "none" }} />
        </div>
        {/* detail page */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            background: Palette.elevated,
            boxShadow: `-6px 0 14px rgb(0 0 0 / ${0.22 * edge})`,
            transform: `translateX(${(1 - p) * FRAME.w}px)`,
          }}
        >
          <div style={{ padding: `${ROW_TOP}px 18px 0`, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
            {[0, 1, 2, 3].map((index) => (
              <div key={index} style={{ position: "relative", height: 78, borderRadius: 16, transform: `translateX(${(1 - p) * 18 * (index + 1)}px)` }}>
                <div style={{ position: "absolute", inset: 0, borderRadius: 16, background: diag(...row.colors), opacity: 1 - index * 0.17 }} />
                <div style={{ position: "absolute", left: 10, bottom: 10, width: 46, height: 7, borderRadius: 3.5, background: white(0.55) }} />
              </div>
            ))}
          </div>
        </div>
        {/* travelling text */}
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {/* old large title → back button label */}
          <div
            style={{
              ...TITLE,
              color: mixColor(Palette.label, Palette.blue, p),
              transform: `translate(${lerp(LARGE_ORIGIN.x, BACK_ORIGIN.x, p)}px, ${lerp(LARGE_ORIGIN.y, BACK_ORIGIN.y, p)}px) scale(${lerp(1, SMALL, p)})`,
            }}
          >
            {ctx.t("Library", "资料库")}
          </div>
          <ChevronLeft size={21} strokeWidth={2.8} color={Palette.blue} style={{ position: "absolute", left: 14 + (1 - p) * 10 - 5, top: 16.5, opacity: Math.max(p * 2 - 1, 0) }} />
          {/* row label → new large title */}
          <div
            style={{
              ...TITLE,
              color: Palette.label,
              transform: `translate(${lerp(rowOrigin.x, LARGE_ORIGIN.x, p)}px, ${lerp(rowOrigin.y, LARGE_ORIGIN.y, p)}px) scale(${lerp(SMALL, 1, p)})`,
              opacity: p > 0.001 ? 1 : 0,
            }}
          >
            {ctx.t(...row.title)}
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 32, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
        {/* row targets on the list, the back button on the detail page */}
        {goal.current < 0.5 ? (
          ROWS.map((_, index) => <div key={index} onClick={() => push(index)} style={{ position: "absolute", left: 0, top: ROW_TOP + index * ROW_PITCH, width: FRAME.w, height: ROW_H, cursor: "pointer" }} />)
        ) : (
          <div onClick={pop} style={{ position: "absolute", left: 0, top: 0, width: 130, height: 48, cursor: "pointer" }} />
        )}
      </div>
      <DemoHint ctx={ctx} en="Tap a row, then swipe right to go back" zh="点击一行，再向右滑动返回" />
    </div>
  );
}
