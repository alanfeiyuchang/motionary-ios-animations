/** loading.skeleton-resolve · 骨架逐块显现 (Loading+SkeletonResolve.swift) */
import { motion, type Transition } from "motion/react";
import { Clock, Heart, MessageCircle } from "lucide-react";
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { DemoHint, Palette, anim, black, demoCard, fonts, spring, useAutoplay, useHaptics, white, type DemoContext, type DemoProps } from "../../kit";
import { makeRun, primary, type Run } from "./shared";

const ORDERS = [
  [0, 1, 2, 3, 4, 5],
  [3, 2, 4, 1, 5, 0],
  [4, 0, 5, 2, 1, 3],
];

/** A placeholder shape with a highlight sweeping across it every 1.3 s. */
function Bone({ radius = 999, style, dark }: { radius?: number | string; style?: CSSProperties; dark: boolean }) {
  const highlight = dark ? white(0.1) : white(0.65);
  return (
    <div style={{ position: "relative", borderRadius: radius, background: primary(0.1), overflow: "hidden", flex: "none", ...style }}>
      <motion.div
        animate={{ x: ["-125%", "150%"] }}
        transition={{ duration: 1.3, ease: "linear", repeat: Infinity }}
        style={{ position: "absolute", top: 0, bottom: 0, left: 0, width: "80%", background: `linear-gradient(97deg, transparent, ${highlight}, transparent)` }}
      />
    </div>
  );
}

function Hero({ caption }: { caption: string }) {
  const ridge = (peaks: number[]) => `0,100 ${peaks.map((p, i) => `${(100 * i) / (peaks.length - 1)},${100 - 100 * p}`).join(" ")} 100,100`;
  return (
    <div style={{ position: "relative", height: 86, borderRadius: 16, overflow: "hidden", background: "linear-gradient(#5B4BD6, #FF6B8B, #FFC36B)" }}>
      <div
        style={{
          position: "absolute",
          left: "50%",
          top: "50%",
          width: 34,
          height: 34,
          marginLeft: -17 + 46,
          marginTop: -17 + 6,
          borderRadius: "50%",
          background: "#FFF1C2",
          boxShadow: "0 0 24px #FFE39A",
        }}
      />
      <svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: "absolute", inset: 0 }}>
        <polygon points={ridge([0.0, 0.55, 0.28, 0.7, 0.4, 0.62, 0.2])} fill="rgb(59 42 122 / 0.55)" />
        <polygon points={ridge([0.25, 0.1, 0.42, 0.18, 0.5, 0.3, 0.46])} fill="rgb(36 26 82 / 0.85)" />
      </svg>
      <div
        style={{
          position: "absolute",
          right: 8,
          bottom: 8,
          height: 22,
          padding: "0 8px",
          borderRadius: 11,
          background: black(0.35),
          color: "#fff",
          display: "flex",
          alignItems: "center",
          gap: 4,
          fontSize: 11,
          fontWeight: 600,
        }}
      >
        <Clock size={11} strokeWidth={2.6} />
        {caption}
      </div>
    </div>
  );
}

function Block({
  visible,
  ctx,
  transition,
  content,
  bones,
  style,
}: {
  visible: boolean;
  ctx: DemoContext;
  transition: Transition;
  content: ReactNode;
  bones: ReactNode;
  style?: CSSProperties;
}) {
  return (
    <div style={{ display: "grid", justifyItems: "start", alignItems: "start", ...style }}>
      <motion.div initial={false} animate={{ opacity: visible ? 0 : 1, scale: visible ? 0.97 : 1 }} transition={transition} style={{ gridArea: "1 / 1", width: "100%" }}>
        {bones}
      </motion.div>
      <motion.div
        initial={false}
        animate={{ opacity: visible ? 1 : 0, y: visible ? 0 : ctx.n("rise"), filter: `blur(${visible ? 0 : ctx.n("blur")}px)` }}
        transition={{ ...transition, filter: visible ? anim.easeOut(0.4) : transition }}
        style={{ gridArea: "1 / 1", width: "100%" }}
      >
        {content}
      </motion.div>
    </div>
  );
}

export default function SkeletonResolve({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [shown, setShown] = useState<number[]>([]);
  const [transition, setTransition] = useState<Transition>(spring(0.5, 0.8));
  const shownRef = useRef<number[]>([]);
  shownRef.current = shown;
  const task = useRef<Run | null>(null);
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  const play = () => {
    task.current?.cancel();
    const c = latest.current;
    const order = ORDERS[Math.min(Math.max(c.i("order"), 0), 2)];
    const stagger = Math.max(c.n("stagger"), 0.01);
    const wasLoaded = shownRef.current.length > 0;
    const run = makeRun();
    task.current = run;
    (async () => {
      if (wasLoaded) {
        setTransition(anim.easeInOut(0.3));
        setShown([]);
        await run.sleep(0.3);
      }
      await run.sleep(0.9);
      for (const index of order) {
        setTransition(spring(0.5, 0.8));
        setShown((s) => (s.includes(index) ? s : [...s, index]));
        await run.sleep(stagger);
      }
    })().catch(() => {});
  };
  useAutoplay(ctx.isPreview, play, { every: 4.6, delay: 0.3 });

  const dark = ctx.scheme === "dark";
  const block = (index: number, content: ReactNode, bones: ReactNode, style?: CSSProperties) => (
    <Block visible={shown.includes(index)} ctx={ctx} transition={transition} content={content} bones={bones} style={style} />
  );
  const label: CSSProperties = { display: "flex", alignItems: "center", gap: 5 };

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={() => {
          haptics.tap();
          play();
        }}
        style={{ ...demoCard(24), width: 296, padding: 14, display: "flex", flexDirection: "column", alignItems: "stretch", gap: 10, flex: "none", cursor: "pointer" }}
      >
        {block(0, <Hero caption={zh ? "4 分钟" : "4 min"} />, <Bone radius={16} dark={dark} style={{ height: 86 }} />)}
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          {block(
            1,
            <div
              style={{ width: 36, height: 36, borderRadius: "50%", background: Palette.aurora, display: "grid", placeItems: "center", color: "#fff", fontFamily: fonts.rounded, fontSize: 13, fontWeight: 700 }}
            >
              LM
            </div>,
            <Bone radius="50%" dark={dark} style={{ width: 36, height: 36 }} />,
            { width: 36, flex: "none" },
          )}
          {block(
            2,
            <div style={{ height: 36, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "flex-start", gap: 2, whiteSpace: "nowrap" }}>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "林夏" : "Lena Morales"}</span>
              <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{zh ? "2 小时前 · 里斯本" : "2 h ago · Lisbon"}</span>
            </div>,
            <div style={{ height: 36, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "flex-start", gap: 7 }}>
              <Bone dark={dark} style={{ width: 104, height: 11 }} />
              <Bone dark={dark} style={{ width: 76, height: 9 }} />
            </div>,
          )}
        </div>
        {block(
          3,
          <div style={{ minHeight: 22, fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", letterSpacing: zh ? undefined : "-0.03em" }}>
            {zh ? "云海之上的日出山脊徒步" : "Sunrise ridge walk above the clouds"}
          </div>,
          <div style={{ height: 22, display: "flex", alignItems: "center" }}>
            <Bone dark={dark} style={{ width: 236, height: 14 }} />
          </div>,
        )}
        {block(
          4,
          <div style={{ minHeight: 36, fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
            {zh ? "六公里山路，一壶热咖啡，还有一年里最好的那束光。" : "Six kilometres, one thermos of coffee and the best light of the whole year."}
          </div>,
          <div style={{ height: 36, marginTop: 4, display: "flex", flexDirection: "column", alignItems: "stretch", gap: 9 }}>
            <Bone dark={dark} style={{ height: 9 }} />
            <Bone dark={dark} style={{ width: 168, height: 9 }} />
          </div>,
        )}
        {block(
          5,
          <div style={{ height: 32, display: "flex", alignItems: "center", gap: 14, fontSize: 13, fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
            <span style={{ ...label, color: Palette.pink }}>
              <Heart size={14} fill="currentColor" strokeWidth={0} />
              248
            </span>
            <span style={{ ...label, color: Palette.secondaryLabel }}>
              <MessageCircle size={14} fill="currentColor" strokeWidth={0} />
              32
            </span>
            <span style={{ flex: 1 }} />
            <span style={{ height: 32, padding: "0 18px", borderRadius: 16, background: "linear-gradient(135deg, #4B57E0, #7A45D6)", color: "#fff", fontSize: 15, display: "flex", alignItems: "center" }}>
              {zh ? "阅读" : "Read"}
            </span>
          </div>,
          <div style={{ height: 32, display: "flex", alignItems: "center", gap: 12 }}>
            <Bone dark={dark} style={{ width: 48, height: 14 }} />
            <Bone dark={dark} style={{ width: 40, height: 14 }} />
            <span style={{ flex: 1 }} />
            <Bone dark={dark} style={{ width: 72, height: 32 }} />
          </div>,
        )}
      </div>
      <DemoHint ctx={ctx} en="Tap the card to reload" zh="点击卡片重新加载" />
    </div>
  );
}
