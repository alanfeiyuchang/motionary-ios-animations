/** morph.app-launch · 应用启动 (Morph+AppLaunch.swift) */
import { animate, useMotionValue } from "motion/react";
import {
  AudioLines,
  Book,
  Calendar,
  Camera,
  CircleUserRound,
  CloudSun,
  Compass,
  CreditCard,
  Gamepad2,
  Heart,
  Images,
  Map as MapIcon,
  MessageCircle,
  Music,
  NotebookText,
  Phone,
  Settings,
  type LucideIcon,
} from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, PlaceholderLines, anim, black, glass, hex, localPoint, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { Column, diag, lerpRect, mixN, predicted, smooth, unit, useMV, vert } from "./_shared";

interface App {
  Icon: LucideIcon;
  filled?: boolean;
  colors: [string, string];
  name: [string, string];
}
const apps: App[] = [
  { Icon: CloudSun, colors: ["#4FB4FF", "#2B6BE8"], name: ["Weather", "天气"] },
  { Icon: Calendar, colors: ["#FF7A6B", "#F0453A"], name: ["Calendar", "日历"] },
  { Icon: Images, colors: [Palette.amber, Palette.coral], name: ["Photos", "照片"] },
  { Icon: Camera, colors: ["#9A9AA2", "#55555C"], name: ["Camera", "相机"] },
  { Icon: MapIcon, colors: [Palette.mint, Palette.green], name: ["Maps", "地图"] },
  { Icon: NotebookText, colors: ["#FFD66B", Palette.amber], name: ["Notes", "备忘录"] },
  { Icon: Heart, filled: true, colors: [Palette.pink, Palette.red], name: ["Health", "健康"] },
  { Icon: Book, colors: ["#FFA24F", "#F06A1F"], name: ["Books", "图书"] },
  { Icon: AudioLines, colors: [Palette.violet, Palette.indigo], name: ["Podcasts", "播客"] },
  { Icon: Gamepad2, colors: [Palette.indigo, Palette.sky], name: ["Arcade", "游戏"] },
  { Icon: CreditCard, colors: ["#3A3A44", "#17171C"], name: ["Wallet", "钱包"] },
  { Icon: Settings, colors: ["#8E8E93", "#5A5A60"], name: ["Settings", "设置"] },
  { Icon: Phone, filled: true, colors: ["#5BE584", "#1FB855"], name: ["Phone", "电话"] },
  { Icon: Compass, colors: [Palette.sky, Palette.blue], name: ["Safari", "Safari"] },
  { Icon: MessageCircle, filled: true, colors: ["#5BE584", "#1FB855"], name: ["Messages", "信息"] },
  { Icon: Music, colors: [Palette.pink, Palette.red], name: ["Music", "音乐"] },
];

const SIDE = 316;
const ICON = 54;
const DOCK = { x: 10, y: 232, w: 296, h: 72 };
const FIT = 0.95;
const autoOrder = [5, 2, 14, 8, 0, 11];
/** Twelve icons in a 4 × 3 grid, then four in the dock. */
function center(index: number) {
  const pitch = (SIDE - 44 - ICON) / 3;
  const x = 22 + ICON / 2 + (index % 4) * pitch;
  if (index >= 12) return { x, y: DOCK.y + DOCK.h / 2 };
  return { x, y: 48 + Math.floor(index / 4) * 68 };
}

function Glyph({ app, size }: { app: App; size: number }) {
  return <app.Icon size={size} strokeWidth={app.filled ? 0 : 2.3} fill={app.filled ? "currentColor" : "none"} />;
}

export default function AppLaunch({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [selected, setSelected] = useState(5);
  const [isOpen, setIsOpen] = useState(false);
  const progressMV = useMotionValue(0);
  const dragXMV = useMotionValue(0);
  const dragYMV = useMotionValue(0);
  const progress = useMV(progressMV);
  const dragX = useMV(dragXMV);
  const dragY = useMV(dragYMV);
  const autoIndex = useRef(0);
  const dragged = useRef(false);
  const L = ctx.lang === "zh" ? 1 : 0;
  const zoom = ctx.n("zoom");

  const open = (index: number) => {
    if (isOpen) return;
    haptics.tap("light");
    setSelected(index);
    progressMV.jump(0);
    dragXMV.jump(0);
    dragYMV.jump(0);
    setIsOpen(true);
    animate(progressMV, 1, spring(ctx.n("response"), 0.86));
  };
  const close = () => {
    if (!isOpen) return;
    clearAll();
    haptics.tap("soft");
    const spr = spring(ctx.n("response"), ctx.n("damping"));
    setIsOpen(false);
    animate(progressMV, 0, spr);
    animate(dragXMV, 0, spr);
    animate(dragYMV, 0, spr);
  };
  // Autoplay stand-in for a finger: launch an app, then swipe it home.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (isOpen) {
        animate(dragXMV, 12, anim.easeOut(0.3));
        animate(dragYMV, -130, anim.easeOut(0.3));
        clearAll();
        after(0.32, closeRef.current);
      } else {
        open(autoOrder[autoIndex.current % autoOrder.length]);
        autoIndex.current += 1;
      }
    },
    { every: 1.7 },
  );
  const closeRef = useRef(close);
  closeRef.current = close;

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
        clearAll();
      },
      onChange: ({ translation: t }) => {
        if (!isOpen) return;
        dragXMV.set(t.x);
        dragYMV.set(t.y < 0 ? t.y : rubberBand(t.y, 24));
      },
      onEnd: ({ translation: t, velocity: v }) => {
        if (!isOpen) return;
        if (-t.y > 70 || -predicted(t.y, v.y) > 220) close();
        else {
          animate(dragXMV, 0, spring(0.35, 0.82));
          animate(dragYMV, 0, spring(0.35, 0.82));
        }
      },
    },
    10,
  );

  // One frame of the launch: everything is derived from the in-flight progress and drag.
  const pull = unit(-dragY / 240);
  const depth = progress * (1 - pull);
  const focus = center(selected);
  const cardSide = SIDE * (1 - 0.5 * pull);
  const cardCenter = { x: SIDE / 2 + dragX * 0.6, y: SIDE / 2 + dragY * 0.36 };
  const rect = lerpRect(
    { x: focus.x - ICON / 2, y: focus.y - ICON / 2, w: ICON, h: ICON },
    { x: cardCenter.x - cardSide / 2, y: cardCenter.y - cardSide / 2, w: cardSide, h: cardSide },
    progress,
  );
  const up = unit(progress);
  const radius = mixN(13, 38, up) * (rect.w < ICON ? rect.w / ICON : 1);
  const appAlpha = smooth(progress, 0.05, 0.45);
  const app = apps[selected];

  const onClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dragged.current) {
      dragged.current = false;
      return;
    }
    const pt = localPoint(e, e.currentTarget);
    const inCard = pt.x >= rect.x && pt.x <= rect.x + rect.w && pt.y >= rect.y && pt.y <= rect.y + rect.h;
    if (inCard) {
      if (progress < 0.5) open(selected);
      else if (pt.y - rect.y > rect.h - 60) close();
      return;
    }
    if (isOpen) return;
    const hit = apps.findIndex((_, i) => {
      const c = center(i);
      return Math.abs(pt.x - c.x) <= ICON / 2 && Math.abs(pt.y - c.y) <= ICON / 2;
    });
    if (hit >= 0) open(hit);
  };

  return (
    <Column gap={10}>
      <div style={{ width: SIDE * FIT, height: SIDE * FIT, flexShrink: 0, borderRadius: 38 * FIT, boxShadow: `0 12px 22px ${hex(0x1b2a6b, 0.3)}` }}>
        <div
          {...pan}
          onPointerDown={(e) => {
            dragged.current = false;
            pan.onPointerDown(e);
          }}
          onClick={onClick}
          style={{
            ...pan.style,
            position: "relative",
            width: SIDE,
            height: SIDE,
            transform: `scale(${FIT})`,
            transformOrigin: "0 0",
            borderRadius: 38,
            overflow: "hidden",
            cursor: "pointer",
          }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              transform: `scale(${1 + 0.12 * depth})`,
              background: `radial-gradient(220px circle at 10% 95%, ${hex(0x6bffe1, 0.3)}, transparent), radial-gradient(210px circle at 90% 15%, ${hex(0xff9ed8, 0.5)}, transparent), ${diag("#10194F", "#3D4FD0", "#8EC5F5")}`,
            }}
          />
          <div style={{ position: "absolute", inset: 0, background: black(0.3 * unit(depth)) }} />
          <div
            style={{
              position: "absolute",
              inset: 0,
              transform: `scale(${Math.max(1 + zoom * depth, 0.2)})`,
              transformOrigin: `${focus.x}px ${focus.y}px`,
              opacity: 1 - unit(depth * 1.4),
            }}
          >
            <div style={{ position: "absolute", left: DOCK.x, top: DOCK.y, width: DOCK.w, height: DOCK.h, borderRadius: 26, ...glass("ultraThin", "dark"), background: white(0.22) }} />
            {apps.map((a, index) => {
              if (index === selected) return null;
              const c = center(index);
              return (
                <div
                  key={index}
                  style={{
                    position: "absolute",
                    left: c.x - ICON / 2,
                    top: c.y - ICON / 2,
                    width: ICON,
                    height: ICON,
                    borderRadius: 13,
                    background: vert(...a.colors),
                    boxShadow: `0 3px 5px ${black(0.2)}`,
                    color: "#fff",
                    display: "grid",
                    placeItems: "center",
                  }}
                >
                  <Glyph app={a} size={ICON * 0.5} />
                </div>
              );
            })}
          </div>
          <div
            style={{
              position: "absolute",
              left: rect.x,
              top: rect.y,
              width: rect.w,
              height: rect.h,
              borderRadius: radius,
              overflow: "hidden",
              background: vert(...app.colors),
              boxShadow: `0 ${3 + 9 * up}px ${5 + 16 * up}px ${black(0.2 + 0.2 * up)}`,
              color: "#fff",
              display: "grid",
              placeItems: "center",
            }}
          >
            <Glyph app={app} size={rect.w * 0.5} />
            <div style={{ position: "absolute", left: 0, top: 0, width: SIDE, height: SIDE, transform: `scale(${rect.w / SIDE})`, transformOrigin: "0 0", opacity: appAlpha }}>
              <AppScreen app={app} L={L} />
            </div>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: 38, boxShadow: `inset 0 0 0 1px ${white(0.12)}`, pointerEvents: "none" }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en={isOpen ? "Swipe up to go home" : "Tap an app"} zh={isOpen ? "向上滑动返回主屏" : "点击一个应用"} />
    </Column>
  );
}

/** The launched app's first screen, always laid out at full size and scaled into the flying rect. */
function AppScreen({ app, L }: { app: App; L: number }) {
  return (
    <div style={{ position: "absolute", inset: 0, background: Palette.background, color: Palette.label, padding: "26px 20px 0", display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={{ display: "flex", alignItems: "center" }}>
        <span style={{ fontSize: 28, lineHeight: "34px", fontWeight: 700 }}>{app.name[L]}</span>
        <span style={{ flex: 1 }} />
        <CircleUserRound size={30} strokeWidth={2} style={{ color: app.colors[0] }} />
      </div>
      <div style={{ position: "relative", height: 112, flexShrink: 0, borderRadius: 22, background: diag(...app.colors), color: "#fff" }}>
        <div style={{ position: "absolute", left: 16, bottom: 16, display: "flex", flexDirection: "column", gap: 6 }}>
          <Glyph app={app} size={34} />
          <div style={{ width: 120, height: 9, borderRadius: 5, background: white(0.85) }} />
          <div style={{ width: 76, height: 9, borderRadius: 5, background: white(0.5) }} />
        </div>
      </div>
      {[0, 1].map((row) => (
        <div key={row} style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ width: 38, height: 38, flexShrink: 0, borderRadius: 11, background: hex(app.colors[row % 2], 0.22) }} />
          <div style={{ flex: 1 }}>
            <PlaceholderLines count={2} />
          </div>
        </div>
      ))}
      <div style={{ position: "absolute", left: "50%", bottom: 8, marginLeft: -54, width: 108, height: 5, borderRadius: 3, background: Palette.labelAlpha(0.85) }} />
    </div>
  );
}
