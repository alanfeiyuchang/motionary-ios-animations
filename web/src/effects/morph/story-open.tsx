/** morph.story-open · 故事圆环展开 (Morph+StoryOpen.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Bookmark, BookOpen, Coffee, Ellipsis, Guitar, Heart, Image as ImageIcon, Leaf, MessageSquare, MicVocal, MoonStar, Music, Sailboat, Send, Sparkles, Sun, Tent, Umbrella } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, hex, localPoint, rubberBand, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { Column, diag, lerpRect, predicted, smooth, unit, useMV } from "./_shared";
import { Mountain2, SunHorizon, type SymbolComponent } from "./_symbols";

interface Person {
  name: [string, string];
  colors: [string, string];
  face: SymbolComponent;
  scenes: SymbolComponent[];
  captions: [string, string][];
}
const S = (I: unknown) => I as SymbolComponent;
const people: Person[] = [
  {
    name: ["maya", "知夏"],
    colors: ["#FF8A5B", "#E5407A"],
    face: S(Sun),
    scenes: [SunHorizon, S(Umbrella), S(Sailboat)],
    captions: [
      ["Golden hour", "黄金时刻"],
      ["Beach day", "海边的一天"],
      ["Out on the water", "出海"],
    ],
  },
  {
    name: ["leo", "一舟"],
    colors: ["#4FB4FF", "#5B4FE8"],
    face: Mountain2,
    scenes: [Mountain2, S(Tent), S(MoonStar)],
    captions: [
      ["Summit at last", "终于登顶"],
      ["Camp for the night", "今晚扎营"],
      ["So many stars", "漫天繁星"],
    ],
  },
  {
    name: ["ava", "晚晴"],
    colors: ["#34D9A8", "#1F8FB8"],
    face: S(Leaf),
    scenes: [S(Leaf), S(Coffee), S(BookOpen)],
    captions: [
      ["Morning walk", "清晨散步"],
      ["Slow coffee", "慢慢喝一杯"],
      ["New chapter", "新的一章"],
    ],
  },
  {
    name: ["noah", "牧野"],
    colors: ["#B86BFF", "#FF5FA2"],
    face: S(Music),
    scenes: [S(Guitar), S(MicVocal), S(Sparkles)],
    captions: [
      ["Soundcheck", "试音"],
      ["On stage", "登台"],
      ["What a night", "难忘的夜晚"],
    ],
  },
];
const W = 316;
const H = 308;
const AVATAR = 52;
const ring = (i: number) => ({ x: 47 + i * 74, y: 46 });

export default function StoryOpen({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected] = useState(1);
  const [isOpen, setIsOpen] = useState(false);
  const [segment, setSegment] = useState(0);
  const [seen, setSeen] = useState<Set<number>>(() => new Set());
  const progressMV = useMotionValue(0);
  const dragXMV = useMotionValue(0);
  const dragYMV = useMotionValue(0);
  const playedMV = useMotionValue(0);
  const progress = useMV(progressMV);
  const dragX = useMV(dragXMV);
  const dragY = useMV(dragYMV);
  const played = useMV(playedMV);
  const autoIndex = useRef(0);
  const dragged = useRef(false);
  const timers = useRef<number[]>([]);
  const live = useRef({ isOpen, selected, segment, seen });
  live.current = { isOpen, selected, segment, seen };
  const L = ctx.lang === "zh" ? 1 : 0;
  const preview = ctx.isPreview;

  const cancelTimers = () => {
    timers.current.forEach((t) => window.clearTimeout(t));
    timers.current = [];
  };
  useEffect(() => cancelTimers, []);
  const later = (seconds: number, fn: () => void) => timers.current.push(window.setTimeout(fn, seconds * 1000));

  const close = (buzz = true) => {
    if (!live.current.isOpen) return;
    cancelTimers();
    if (buzz) haptics.tap("soft");
    const who = live.current.selected;
    setSeen((s) => new Set(s).add(who));
    setIsOpen(false);
    const spr = spring(ctx.n("response"), ctx.n("damping"));
    animate(progressMV, 0, spr);
    animate(dragXMV, 0, spr);
    animate(dragYMV, 0, spr);
  };
  /** Plays the remaining segments one after another, then closes the story. */
  const run = (who: number, first: number, buzz: boolean) => {
    cancelTimers();
    const duration = ctx.n("segment");
    const count = people[who].scenes.length;
    for (let index = first; index < count; index++) {
      later(0.05 + (index - first) * duration, () => {
        if (index !== first) {
          if (buzz && !preview) haptics.selection();
          setSegment(index);
        }
        animate(playedMV, index + 1, anim.linear(duration));
      });
    }
    later(0.05 + (count - first) * duration, () => close(buzz));
  };
  const open = (index: number, buzz = true) => {
    if (live.current.isOpen) return;
    haptics.tap("light");
    setSelected(index);
    setSegment(0);
    playedMV.stop();
    playedMV.jump(0);
    progressMV.jump(0);
    dragXMV.jump(0);
    dragYMV.jump(0);
    setIsOpen(true);
    live.current.isOpen = true;
    animate(progressMV, 1, spring(ctx.n("response"), 0.86));
    run(index, 0, buzz);
  };
  /** A tap on the story: finish the current segment at once and move on (or close after the last one). */
  const skip = () => {
    if (!isOpen) return;
    const next = segment + 1;
    haptics.selection();
    if (next >= people[selected].scenes.length) {
      close();
      return;
    }
    animate(playedMV, next, anim.easeOut(0.12));
    setSegment(next);
    cancelTimers();
    // `run` restarts the bar after its own beat, once the quick fill has landed.
    run(selected, next, true);
  };
  // Autoplay stand-in for a finger: open the next story, then drag it down and let go.
  useAutoplay(
    preview,
    () => {
      if (live.current.isOpen) {
        animate(dragXMV, 26, anim.easeOut(0.32));
        animate(dragYMV, 150, anim.easeOut(0.32));
        cancelTimers();
        later(0.34, () => close(false));
      } else {
        if (live.current.seen.size === people.length) setSeen(new Set());
        open(autoIndex.current % people.length, false);
        autoIndex.current += 1;
      }
    },
    { every: 2.0 },
  );

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ translation: t }) => {
        if (!isOpen) return;
        dragXMV.set(t.x);
        dragYMV.set(t.y > 0 ? t.y : rubberBand(t.y, 20));
      },
      onEnd: ({ translation: t, velocity: v }) => {
        if (!isOpen) return;
        const threshold = ctx.n("threshold");
        if (t.y > threshold || predicted(t.y, v.y) > threshold * 2.5) close();
        else {
          animate(dragXMV, 0, spring(0.35, 0.82));
          animate(dragYMV, 0, spring(0.35, 0.82));
        }
      },
    },
    10,
  );

  const pull = unit(dragY / 260);
  const up = unit(progress);
  const depth = up * (1 - pull);
  const scale = 1 - 0.45 * pull;
  const cc = { x: W / 2 + dragX * 0.7, y: H / 2 + dragY * 0.8 };
  const rc = ring(selected);
  const rect = lerpRect(
    { x: rc.x - AVATAR / 2, y: rc.y - AVATAR / 2, w: AVATAR, h: AVATAR },
    { x: cc.x - (W * scale) / 2, y: cc.y - (H * scale) / 2, w: W * scale, h: H * scale },
    progress,
  );
  const radius = Math.min(26 + 4 * up, Math.min(rect.w, rect.h) / 2);
  const fill = Math.max(rect.w / W, rect.h / H);
  const person = people[selected];

  const onClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dragged.current) {
      dragged.current = false;
      return;
    }
    const pt = localPoint(e, e.currentTarget);
    const inCard = pt.x >= rect.x && pt.x <= rect.x + rect.w && pt.y >= rect.y && pt.y <= rect.y + rect.h;
    if (inCard) {
      if (progress > 0.5) skip();
      else open(selected);
      return;
    }
    const hit = people.findIndex((_, i) => Math.abs(pt.x - ring(i).x) <= 31 && Math.abs(pt.y - (ring(i).y + 9)) <= 40);
    if (hit >= 0) open(hit);
  };

  return (
    <Column gap={10}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={onClick}
        style={{ ...pan.style, position: "relative", width: W, height: H, flexShrink: 0, borderRadius: 30, overflow: "hidden", cursor: "pointer" }}
      >
        <div style={{ position: "absolute", inset: 0, transform: `scale(${1 - 0.06 * depth})`, filter: depth > 0.01 ? `blur(${5 * depth}px)` : undefined }}>
          <Feed selected={selected} hideSelected={progress > 0.002} seen={seen} L={L} />
        </div>
        <div style={{ position: "absolute", inset: 0, background: black(0.6 * depth), pointerEvents: "none" }} />
        <div
          style={{
            position: "absolute",
            left: rect.x,
            top: rect.y,
            width: rect.w,
            height: rect.h,
            borderRadius: radius,
            overflow: "hidden",
            boxShadow: `0 10px 20px ${black(0.35 * up)}`,
          }}
        >
          <AvatarArt person={person} size={Math.min(rect.w, rect.h)} />
          <div
            style={{
              position: "absolute",
              left: (rect.w - W) / 2,
              top: (rect.h - H) / 2,
              width: W,
              height: H,
              transform: `scale(${fill})`,
              opacity: smooth(progress, 0.08, 0.5),
            }}
          >
            <Content person={person} segment={segment} played={played} L={L} />
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en={isOpen ? "Tap to skip, drag down to close" : "Tap a story ring"} zh={isOpen ? "点击跳到下一段，下拉关闭" : "点击一个圆环"} />
    </Column>
  );
}

function AvatarArt({ person, size }: { person: Person; size: number }) {
  const Face = person.face;
  return (
    <div style={{ position: "absolute", inset: 0, background: diag(...person.colors), display: "grid", placeItems: "center", color: white(0.95) }}>
      <Face size={size * 0.5} strokeWidth={2.4} />
    </div>
  );
}

function Content({ person, segment, played, L }: { person: Person; segment: number; played: number; L: number }) {
  const index = Math.min(Math.max(segment, 0), person.scenes.length - 1);
  const Scene = person.scenes[index];
  return (
    <div style={{ position: "absolute", inset: 0, color: "#fff", background: `radial-gradient(180px circle at 50% 40%, ${white(0.35)}, transparent), linear-gradient(to bottom, ${person.colors[0]}, ${person.colors[1]}, ${black(0.9)})` }}>
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
        <AnimatePresence initial={false}>
          <motion.div
            key={index}
            initial={{ scale: 0.7, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.7, opacity: 0 }}
            transition={spring(0.4, 0.7)}
            style={{ gridArea: "1 / 1", marginTop: -12, color: white(0.95), filter: `drop-shadow(0 8px 14px ${black(0.25)})` }}
          >
            <Scene size={96} strokeWidth={2.2} />
          </motion.div>
        </AnimatePresence>
      </div>
      <div style={{ position: "absolute", inset: 0, padding: "14px 14px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
        <div style={{ display: "flex", gap: 4 }}>
          {person.scenes.map((_, i) => (
            <div key={i} style={{ flex: 1, height: 3, borderRadius: 1.5, background: white(0.35), overflow: "hidden" }}>
              <div style={{ width: "100%", height: "100%", background: "#fff", transform: `scaleX(${unit(played - i)})`, transformOrigin: "0 50%" }} />
            </div>
          ))}
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ position: "relative", width: 28, height: 28, borderRadius: 14, overflow: "hidden", boxShadow: `inset 0 0 0 1px ${white(0.7)}` }}>
            <AvatarArt person={person} size={28} />
            <div style={{ position: "absolute", inset: 0, borderRadius: 14, boxShadow: `inset 0 0 0 1px ${white(0.7)}` }} />
          </div>
          <span style={{ fontSize: 14, fontWeight: 600 }}>{person.name[L]}</span>
          <span style={{ fontSize: 13, opacity: 0.7 }}>{L ? "2 小时前" : "2h"}</span>
        </div>
        <span style={{ flex: 1 }} />
        <div style={{ position: "relative", height: 27 }}>
          <AnimatePresence initial={false}>
            <motion.div
              key={index}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 8 }}
              transition={spring(0.4, 0.7)}
              style={{ position: "absolute", left: 0, top: 0, fontSize: 22, lineHeight: "27px", fontWeight: 700, whiteSpace: "nowrap" }}
            >
              {person.captions[index][L]}
            </motion.div>
          </AnimatePresence>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <div style={{ flex: 1, height: 40, borderRadius: 20, padding: "0 16px", display: "flex", alignItems: "center", boxShadow: `inset 0 0 0 1px ${white(0.6)}` }}>
            <span style={{ fontSize: 14, opacity: 0.8 }}>{L ? "发送消息" : "Send message"}</span>
          </div>
          <Heart size={24} strokeWidth={1.8} />
          <Send size={22} strokeWidth={1.8} />
        </div>
      </div>
    </div>
  );
}

/** The feed behind: story rings on top, one post below. */
function Feed({ selected, hideSelected, seen, L }: { selected: number; hideSelected: boolean; seen: Set<number>; L: number }) {
  return (
    <>
      {people.map((person, index) => {
        const c = ring(index);
        const isSeen = seen.has(index);
        return (
          <div key={index} style={{ position: "absolute", left: c.x - 31, top: c.y - 31, width: 62, display: "flex", flexDirection: "column", alignItems: "center", gap: 5 }}>
            <div style={{ position: "relative", width: 62, height: 62 }}>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: "50%",
                  padding: 2.5,
                  background: `conic-gradient(from 90deg, ${Palette.amber}, ${Palette.pink}, ${Palette.violet}, ${Palette.amber})`,
                  WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                  WebkitMaskComposite: "xor",
                  maskComposite: "exclude",
                  opacity: isSeen ? 0 : 1,
                  transition: "opacity 0.3s ease-out",
                }}
              />
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1.5px ${Palette.labelAlpha(0.18)}`, opacity: isSeen ? 1 : 0, transition: "opacity 0.3s ease-out" }} />
              <div style={{ position: "absolute", left: 5, top: 5, width: AVATAR, height: AVATAR, borderRadius: "50%", overflow: "hidden", opacity: hideSelected && index === selected ? 0 : 1 }}>
                <AvatarArt person={person} size={AVATAR} />
              </div>
            </div>
            <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: isSeen ? Palette.secondaryLabel : Palette.label }}>{person.name[L]}</span>
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          left: 8,
          top: 104,
          width: 300,
          height: 198,
          padding: 12,
          borderRadius: 22,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
          display: "flex",
          flexDirection: "column",
          gap: 10,
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <div style={{ width: 28, height: 28, borderRadius: 14, background: Palette.primary }} />
          <div style={{ display: "flex", flexDirection: "column", gap: 5 }}>
            <div style={{ width: 84, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.22) }} />
            <div style={{ width: 52, height: 7, borderRadius: 4, background: Palette.labelAlpha(0.1) }} />
          </div>
          <span style={{ flex: 1 }} />
          <Ellipsis size={20} style={{ color: Palette.secondaryLabel }} />
        </div>
        <div style={{ flex: 1, borderRadius: 14, background: diag(hex(Palette.indigo, 0.85), hex(Palette.sky, 0.85)), display: "grid", placeItems: "center", color: white(0.7) }}>
          <ImageIcon size={34} strokeWidth={2} />
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 16, color: Palette.labelAlpha(0.75) }}>
          <Heart size={19} strokeWidth={2.1} />
          <MessageSquare size={19} strokeWidth={2.1} />
          <Send size={19} strokeWidth={2.1} />
          <span style={{ flex: 1 }} />
          <Bookmark size={19} strokeWidth={2.1} />
        </div>
      </div>
    </>
  );
}
