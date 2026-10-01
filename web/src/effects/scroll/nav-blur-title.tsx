/** scroll.nav-blur-title · 大标题交接导航栏 (Scroll+NavBlurTitle.swift) */
import { ChevronLeft, CircleEllipsis } from "lucide-react";
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { Palette, anim, glass, useAutoplay, type DemoProps } from "../../kit";
import { ScrollKitRow, useScroller } from "./_kit";
import { Ico, ScrollMath, useTopPull } from "./_motion";

const BAR = 46;
/** Scroll offset at which the large title's baseline meets the bar's bottom edge. */
const BASELINE = 31;

export default function NavBlurTitle({ ctx }: DemoProps) {
  const [inline, setInline] = useState(false);
  const inlineRef = useRef(false);
  const down = useRef(false);
  const handoff = ctx.n("handoff");
  const sc = useScroller({
    axis: "y",
    bounce: false,
    onScroll: (o) => {
      // Triggered by position, played in time.
      const show = o >= BASELINE * handoff;
      if (show !== inlineRef.current) {
        inlineRef.current = show;
        setInline(show);
      }
    },
  });
  const top = useTopPull({ enabled: () => !ctx.isPreview && sc.get() <= 0.5 });
  const offset = sc.offset;
  const pull = Math.max(-offset, 0) + top.pull;

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 150 : 0, anim.easeInOut(1.5));
    },
    { every: 2.2 },
  );

  const frost = ScrollMath.unit(offset, 6, 30);
  const soft = ctx.i("edge") === 1;
  // The detail stage keeps its Reset button in the top-trailing corner.
  const trailingInset = ctx.isPreview ? 14 : 52;
  const violetText = ctx.scheme === "dark" ? "#C4A0FF" : "#7A45D6";
  const softMask = `linear-gradient(#000 ${BAR - 6}px, transparent)`;

  return (
    <div {...top.props} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ padding: "0 16px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ height: BAR + top.pull - 10, flexShrink: 0 }} />
          {/* The large title is real content and scrolls away with the list. */}
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 2, paddingBottom: 4, flexShrink: 0 }}>
            <div style={{ fontSize: 32, lineHeight: "38px", fontWeight: 700, transform: `scale(${1 + Math.min(pull / 500, 0.12)})`, transformOrigin: "0 100%", whiteSpace: "nowrap" }}>
              {ctx.t("Library", "资料库")}
            </div>
            <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>{ctx.t("248 songs · 19 albums", "248 首歌曲 · 19 张专辑")}</div>
          </div>
          {Array.from({ length: 14 }, (_, i) => (
            <ScrollKitRow key={i} index={i + 4} lang={ctx.lang} style={{ flexShrink: 0 }} />
          ))}
        </div>
      </div>
      {/* Bar */}
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: BAR, pointerEvents: "none" }}>
        {/* The frosted backdrop: a hard edge with a hairline, or a soft edge that melts into the content. */}
        {soft ? (
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: BAR + 22, ...glass("regular"), WebkitMaskImage: softMask, maskImage: softMask, opacity: frost }} />
        ) : (
          <div style={{ position: "absolute", inset: 0, ...glass("regular"), boxShadow: `inset 0 -0.5px 0 ${Palette.labelAlpha(0.14)}`, opacity: frost }} />
        )}
        <div style={{ position: "absolute", inset: 0, padding: "0 14px", display: "flex", alignItems: "center", gap: 3, color: violetText }}>
          <Ico icon={ChevronLeft} size={17} weight={600} />
          <span style={{ fontSize: 17 }}>{ctx.t("Music", "音乐")}</span>
          <div style={{ flex: 1 }} />
          <Ico icon={CircleEllipsis} size={19} weight={400} style={{ marginRight: trailingInset - 14 }} />
        </div>
        <motion.div
          initial={false}
          animate={{ opacity: inline ? 1 : 0, y: inline ? 0 : 7, filter: inline ? "blur(0px)" : "blur(2.2px)" }}
          transition={anim.easeOut(ctx.n("fade"))}
          style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontSize: 17, fontWeight: 600 }}
        >
          {ctx.t("Library", "资料库")}
        </motion.div>
      </div>
    </div>
  );
}
