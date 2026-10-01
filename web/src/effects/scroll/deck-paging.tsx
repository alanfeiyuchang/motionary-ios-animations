/** scroll.deck-paging · 纵深卡片翻页 (Scroll+DeckPaging.swift) */
import { ChevronUp, Clock } from "lucide-react";
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Palette, anim, black, clamp, fonts, spring, useAutoplay, useHaptics, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKit, SnapMarkers, Sym, brightness, strideSnap, swiftBlur, useScroller } from "./_kit";
import { Ico } from "./_motion";

const COUNT = 6;
const STORIES: { kicker: [string, string]; title: [string, string]; minutes: number }[] = [
  { kicker: ["Field notes", "现场笔记"], title: ["The quiet craft of a good spring", "一条好弹簧里的安静功夫"], minutes: 4 },
  { kicker: ["Interview", "访谈"], title: ["Why the best motion is felt, not seen", "最好的动效是被感觉到的"], minutes: 7 },
  { kicker: ["Teardown", "拆解"], title: ["Sixty frames inside one swipe", "一次滑动里的六十帧"], minutes: 5 },
  { kicker: ["Opinion", "观点"], title: ["Stop easing everything in and out", "别再什么都用缓入缓出"], minutes: 3 },
  { kicker: ["Studio visit", "工作室探访"], title: ["A week with people who draw curves", "和画曲线的人待一周"], minutes: 9 },
  { kicker: ["Archive", "档案"], title: ["How the rubber band was invented", "橡皮筋回弹是怎么来的"], minutes: 6 },
];

export default function DeckPaging({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [page, setPage] = useState(0);
  const direction = useRef(1);
  const heightRef = useRef(ctx.isPreview ? 340 : 400);
  /** Set while autoplay turns the page, so the scripted page change stays silent. */
  const scripted = useRef(false);
  const sc = useScroller({
    axis: "y",
    snap: (v) => strideSnap(heightRef.current)(v),
    onScroll: (o) => setPage(clamp(Math.round(o / heightRef.current), 0, COUNT - 1)),
    onPhase: (p) => {
      if (p === "interacting") scripted.current = false;
    },
  });
  const height = Math.max(sc.size.height || heightRef.current, 1);
  heightRef.current = height;

  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (!ctx.isPreview && !scripted.current) haptics.selection();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page]);

  useAutoplay(
    ctx.isPreview,
    () => {
      scripted.current = true;
      if (page + direction.current >= COUNT || page + direction.current < 0) direction.current = -direction.current;
      sc.scrollTo((page + direction.current) * height, anim.smoothD(0.9));
    },
    { every: 1.7 },
  );

  const depth = ctx.n("depth");
  const dim = ctx.n("dim");
  const peek = ctx.n("peek");

  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ position: "relative" }}>
          <SnapMarkers count={COUNT} pitch={height} axis="y" />
          {Array.from({ length: COUNT }, (_, i) => {
            const y = i * height - sc.offset;
            // 0 while the page is in place, 1 once the next page fully covers it.
            const gone = clamp(-y / height, 0, 1);
            const scale = 1 - (1 - depth) * gone;
            // Scaling about the centre pulls the top edge down; the lift puts it back and adds the sliver.
            const shrink = ((height - 38) * (1 - scale)) / 2;
            const lift = (shrink + peek) * gone;
            // Two pages back the card is hidden anyway: let it go.
            const buried = clamp(-y / height - 1, 0, 1);
            return (
              <div
                key={i}
                style={{
                  position: "relative",
                  height,
                  padding: "26px 18px 12px",
                  transform: `translateY(${Math.max(-y, 0) - lift}px) scale(${scale})`,
                  filter: gone > 0.001 ? [brightness(-dim * gone), swiftBlur(3 * gone)].filter(Boolean).join(" ") : undefined,
                  opacity: 1 - buried,
                }}
              >
                <Card index={i} lang={ctx.lang} />
              </div>
            );
          })}
        </div>
      </div>
      {/* Side rail: one dot per page, the current one stretched into a short bar. */}
      <div style={{ position: "absolute", right: 5, top: 0, bottom: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 5, pointerEvents: "none" }}>
        {Array.from({ length: COUNT }, (_, i) => (
          <motion.div
            key={i}
            initial={false}
            animate={{ height: i === page ? 20 : 5 }}
            transition={spring(0.35, 0.7)}
            style={{ width: 5, borderRadius: 2.5, background: i === page ? Palette.primary : Palette.labelAlpha(0.2) }}
          />
        ))}
      </div>
    </div>
  );
}

function Card({ index, lang }: { index: number; lang: Lang }) {
  const zh = lang === "zh";
  const story = STORIES[index % STORIES.length];
  const centred = (w: number, x: number, y: number): React.CSSProperties => ({
    position: "absolute",
    left: "50%",
    top: "50%",
    width: w,
    height: w,
    marginLeft: -w / 2 + x,
    marginTop: -w / 2 + y,
    borderRadius: "50%",
  });
  return (
    // Shadow cast upward, onto the card this one slides over.
    <div style={{ position: "relative", height: "100%", borderRadius: 30, boxShadow: `0 -5px 24px ${black(0.3)}` }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 30, overflow: "hidden", background: ScrollKit.gradient(index + 2) }}>
        <div style={{ ...centred(190, 90, -70), background: white(0.24), filter: "blur(30px)" }} />
        <div style={{ ...centred(170, 110, 20), boxShadow: `inset 0 0 0 18px ${white(0.16)}` }} />
        <div
          style={{
            position: "absolute",
            left: "50%",
            top: "50%",
            transform: "translate(-50%, -50%) translate(72px, -38px)",
            color: white(0.92),
            filter: `drop-shadow(0 6px 10px ${black(0.18)})`,
          }}
        >
          <Sym name={ScrollKit.symbol(index + 2)} size={64} weight={600} />
        </div>
        <div style={{ position: "absolute", inset: 0, background: `linear-gradient(transparent 50%, ${black(0.34)})` }} />
        <div style={{ position: "absolute", inset: 0, padding: 20, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 6, color: "#fff" }}>
          <div style={{ display: "flex", alignItems: "flex-start", gap: 8 }}>
            <div style={{ fontFamily: fonts.rounded, fontSize: 44, lineHeight: "52px", fontWeight: 800, fontVariantNumeric: "tabular-nums" }}>{String(index + 1).padStart(2, "0")}</div>
            <div style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, fontVariantNumeric: "tabular-nums", opacity: 0.7, paddingTop: 10 }}>/ {String(COUNT).padStart(2, "0")}</div>
          </div>
          <div style={{ flex: 1 }} />
          <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 700, textTransform: "uppercase", letterSpacing: zh ? 2 : 0.8, opacity: 0.85 }}>{zh ? story.kicker[1] : story.kicker[0]}</div>
          <div style={{ fontSize: 24, lineHeight: "29px", fontWeight: 700 }}>{zh ? story.title[1] : story.title[0]}</div>
          <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 6, fontSize: 12, lineHeight: "16px", fontWeight: 600, opacity: 0.9, paddingTop: 2 }}>
            <Ico icon={Clock} size={11} weight={600} />
            <span>{zh ? `${story.minutes} 分钟` : `${story.minutes} min read`}</span>
            <div style={{ flex: 1 }} />
            <Ico icon={ChevronUp} size={20} weight={600} style={{ opacity: index === COUNT - 1 ? 0 : 0.8, transform: "scaleX(1.4)" }} />
          </div>
        </div>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 30, boxShadow: `inset 0 0 0 1px ${white(0.2)}`, pointerEvents: "none" }} />
    </div>
  );
}
