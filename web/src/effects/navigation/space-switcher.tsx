/** navigation.space-switcher · 空间切换侧栏 (Navigation+SpaceSwitcher.swift) */
import { animate, useMotionValue } from "motion/react";
import { BedDouble, Briefcase, ClipboardList, CodeXml, ListTodo, Lock, Mail, Map as MapIcon, PencilRuler, Plane, Ticket, Utensils } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { HeartFill } from "./groupA-kit";
import { Glyph } from "./groupB-kit";
import { colorGradient, useMotionNumber } from "./nav-util";
import { DocTextFill, PhotoFill, fade, mixColor, stageColumn, usePageDrag } from "./_r2";

type IconFn = (size: number) => ReactNode;
const line = (Icon: typeof Lock): IconFn => (s) => <Icon size={s} strokeWidth={2.8} />;
const solid = (Icon: typeof Lock): IconFn => (s) => <Icon size={s} fill="currentColor" strokeWidth={1.6} />;

const SPACES: { icon: IconFn; name: [string, string]; color: string; tabs: { icon: IconFn; title: [string, string] }[] }[] = [
  {
    icon: solid(Briefcase),
    name: ["Work", "工作"],
    color: Palette.indigo,
    tabs: [
      { icon: line(ListTodo), title: ["Sprint board", "迭代看板"] },
      { icon: line(PencilRuler), title: ["Design file", "设计稿"] },
      { icon: line(CodeXml), title: ["Pull requests", "合并请求"] },
      { icon: (s) => <DocTextFill size={s} />, title: ["Launch notes", "发布说明"] },
    ],
  },
  {
    icon: (s) => <HeartFill size={s} />,
    name: ["Personal", "个人"],
    color: Palette.pink,
    tabs: [
      { icon: line(Mail), title: ["Mail", "邮件"] },
      { icon: (s) => <PhotoFill size={s} />, title: ["Photos", "照片"] },
      { icon: line(Utensils), title: ["Recipes", "食谱"] },
      { icon: (s) => <Glyph name="music.note" size={s} />, title: ["Playlist", "歌单"] },
    ],
  },
  {
    icon: solid(Plane),
    name: ["Travel", "旅行"],
    color: Palette.mint,
    tabs: [
      { icon: line(Ticket), title: ["Flights", "机票"] },
      { icon: line(MapIcon), title: ["Route map", "路线地图"] },
      { icon: line(BedDouble), title: ["Hotels", "酒店"] },
      { icon: line(ClipboardList), title: ["Itinerary", "行程单"] },
    ],
  },
];
const FRAME = { w: 260, h: 290 };
const SIDEBAR_W = 176;
const ICON_STEP = 34;
const LAST = SPACES.length - 1;
const LIST_W = SIDEBAR_W - 20;

export default function SpaceSwitcher({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const goal = useRef(0);
  const autoForward = useRef(true);
  const fan = ctx.n("fan");
  const tint = ctx.n("tint");

  const settle = (index: number) => {
    const clamped = Math.min(Math.max(index, 0), LAST);
    haptics.tap("light");
    goal.current = clamped;
    animate(progressMV, clamped, spring(ctx.n("response"), ctx.n("damping")));
  };
  const { pan } = usePageDrag(progressMV, { unit: SIDEBAR_W, last: LAST, bandLow: 0.5, onPage: (p) => (goal.current = p), settle });

  useAutoplay(
    ctx.isPreview,
    () => {
      const current = Math.round(goal.current);
      let next = current + (autoForward.current ? 1 : -1);
      if (next > LAST) {
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

  // The two neighbouring spaces' colours mixed by the fractional part.
  const clamped = Math.min(Math.max(progress, 0), LAST);
  const lower = Math.floor(clamped);
  const upper = Math.min(lower + 1, LAST);
  const wash = mixColor(SPACES[lower].color, SPACES[upper].color, clamped - lower);

  return (
    <div style={stageColumn(14)}>
      <div
        {...pan}
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          borderRadius: 34,
          overflow: "hidden",
          background: `linear-gradient(to bottom right, ${fade(wash, 0.15 + 0.5 * tint)}, ${fade(wash, 0.05 + 0.2 * tint)}), ${Palette.elevated}`,
          boxShadow: "0 10px 18px rgb(0 0 0 / 0.18)",
          touchAction: "pan-y",
        }}
      >
        {/* page */}
        <div
          style={{
            position: "absolute",
            left: SIDEBAR_W + 16,
            top: 8,
            width: 150,
            height: FRAME.h - 16,
            boxSizing: "border-box",
            padding: 12,
            display: "flex",
            flexDirection: "column",
            gap: 10,
            borderRadius: 22,
            background: Palette.elevated,
            boxShadow: "0 4px 8px rgb(0 0 0 / 0.08)",
          }}
        >
          <div style={{ height: 64, borderRadius: 10, background: colorGradient(wash), flexShrink: 0 }} />
          <PlaceholderLines count={3} color={Palette.labelAlpha(0.1)} />
          <div style={{ height: 70, borderRadius: 10, background: fade(wash, 0.2), flexShrink: 0 }} />
        </div>
        {/* sidebar */}
        <div
          style={{
            position: "absolute",
            left: 8,
            top: 8,
            width: SIDEBAR_W,
            height: FRAME.h - 16,
            boxSizing: "border-box",
            padding: 10,
            display: "flex",
            flexDirection: "column",
            gap: 8,
            borderRadius: 26,
            background: `linear-gradient(${fade(wash, 0.04 + 0.12 * tint)} 0 0), ${Palette.elevated}`,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 4px 6px 14px rgb(0 0 0 / 0.14)`,
          }}
        >
          <div style={{ height: 28, padding: "0 10px", display: "flex", alignItems: "center", gap: 6, borderRadius: 10, background: Palette.labelAlpha(0.06), color: Palette.secondaryLabel, flexShrink: 0 }}>
            <Lock size={10} fill="currentColor" strokeWidth={2.6} />
            <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600 }}>motionary.app</span>
          </div>
          {/* lists */}
          <div style={{ position: "relative", width: LIST_W, height: 178, overflow: "hidden", flexShrink: 0 }}>
            {SPACES.map((space, index) => {
              const distance = index - progress;
              if (Math.abs(distance) >= 1.6) return null;
              return (
                <div
                  key={index}
                  style={{
                    position: "absolute",
                    left: 0,
                    top: 0,
                    width: LIST_W,
                    display: "flex",
                    flexDirection: "column",
                    gap: 4,
                    opacity: 1 - Math.min(Math.abs(distance), 1) * 0.7,
                    transform: `translateX(${distance * (LIST_W + 14)}px)`,
                  }}
                >
                  <div style={{ height: 30, padding: "0 6px", display: "flex", alignItems: "center", gap: 7 }}>
                    <span style={{ color: space.color, display: "grid" }}>{space.icon(14)}</span>
                    <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 700, whiteSpace: "nowrap" }}>{ctx.t(...space.name)}</span>
                  </div>
                  {space.tabs.map((tab, row) => (
                    <div
                      key={row}
                      style={{
                        height: 32,
                        padding: "0 6px",
                        display: "flex",
                        alignItems: "center",
                        gap: 9,
                        borderRadius: 10,
                        background: row === 0 ? alpha(space.color, 0.16) : undefined,
                        transform: `translateX(${distance * (row + 1) * fan}px)`,
                      }}
                    >
                      <div
                        style={{
                          width: 22,
                          height: 22,
                          borderRadius: 7,
                          background: colorGradient(Palette.spectrum[(row * 2 + 1) % Palette.spectrum.length]),
                          color: "#fff",
                          display: "grid",
                          placeItems: "center",
                          flexShrink: 0,
                        }}
                      >
                        {tab.icon(12)}
                      </div>
                      <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t(...tab.title)}</span>
                    </div>
                  ))}
                </div>
              );
            })}
          </div>
          <div style={{ flex: 1 }} />
          {/* space icons */}
          <div style={{ position: "relative", height: 30, flexShrink: 0 }}>
            <div style={{ position: "absolute", left: 2 + clamped * ICON_STEP, top: 0, width: 30, height: 30, borderRadius: 10, background: fade(wash, 0.22) }} />
            <div style={{ position: "absolute", left: 0, top: 0, display: "flex" }}>
              {SPACES.map((space, index) => {
                const near = Math.max(0, 1 - Math.abs(index - clamped));
                return (
                  <div key={index} style={{ width: ICON_STEP, height: 30, display: "grid", placeItems: "center", color: mixColor(Palette.secondaryLabel, space.color, near), transform: `scale(${1 + 0.12 * near})` }}>
                    {space.icon(15)}
                  </div>
                );
              })}
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
        {/* invisible tap targets over the three space icons */}
        <div style={{ position: "absolute", left: 18, bottom: 14, display: "flex" }}>
          {SPACES.map((_, index) => (
            <div key={index} onClick={() => index !== Math.round(goal.current) && settle(index)} style={{ width: ICON_STEP, height: 40, cursor: "pointer" }} />
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Swipe the sidebar, or tap a space icon" zh="横向滑动侧栏，或点击空间图标" />
    </div>
  );
}
