/** scroll.windowed-dots · 滑动窗口页码点 (Scroll+WindowedDots.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { NumericText, Palette, anim, black, clamp, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { ScrollKit, ScrollKitArt, SnapMarkers, strideSnap, useScroller } from "./_kit";

const COUNT = 12;
const PAGE = 340;
const DOT = 7;
const GAP = 6;
const PILL = 16;
const PITCH = DOT + GAP;

export default function WindowedDots({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [page, setPage] = useState(0);
  const pageRef = useRef(0);
  const direction = useRef(1);
  /** Set while autoplay turns the pages, so scripted page changes stay silent. */
  const scripted = useRef(false);
  const sc = useScroller({
    axis: "x",
    snap: strideSnap(PAGE),
    onScroll: (o) => {
      const now = clamp(Math.round(o / PAGE), 0, COUNT - 1);
      if (now !== pageRef.current) {
        pageRef.current = now;
        setPage(now);
      }
    },
    onPhase: (p) => {
      if (p === "interacting") scripted.current = false;
    },
  });
  /** The pager's position in pages, fractional while a page is in transit. */
  const fraction = sc.offset / PAGE;

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
      const now = pageRef.current;
      scripted.current = true;
      if (now + direction.current >= COUNT || now + direction.current < 0) direction.current = -direction.current;
      sc.scrollTo((now + direction.current) * PAGE, anim.smoothD(0.7));
    },
    { every: 1.15 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ position: "relative", width: PAGE, height: 236, flexShrink: 0 }}>
        <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
          <div ref={sc.contentRef} style={{ position: "relative", width: COUNT * PAGE, height: 236, display: "flex" }}>
            <SnapMarkers count={COUNT} pitch={PAGE} />
            {Array.from({ length: COUNT }, (_, i) => {
              const t = clamp((i * PAGE + PAGE / 2 - sc.offset) / PAGE - 0.5, -1, 1);
              return (
                <div key={i} style={{ width: PAGE, height: 236, padding: "4px 22px", flexShrink: 0 }}>
                  <div style={{ position: "relative", height: "100%", borderRadius: 26, boxShadow: `0 8px 21px ${black(0.16)}` }}>
                    <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden" }}>
                      {/* The picture is wider than its frame and drifts against the paging for depth. */}
                      <ScrollKitArt index={i + 5} lang={ctx.lang} showsTitle={false} style={{ left: -30, right: -30, transform: `translateX(${-t * 30}px)` }} />
                      {/* The caption belongs to the frame, not to the drifting picture. */}
                      <div
                        style={{
                          position: "absolute",
                          left: 0,
                          right: 0,
                          bottom: 0,
                          padding: 16,
                          display: "flex",
                          flexDirection: "column",
                          gap: 2,
                          color: "#fff",
                          background: `linear-gradient(transparent, ${black(0.3)})`,
                        }}
                      >
                        <div style={{ fontSize: 17, lineHeight: "22px", fontWeight: 700 }}>{ScrollKit.title(i + 5, ctx.lang)}</div>
                        <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, opacity: 0.85 }}>{ScrollKit.subtitle(i + 5, ctx.lang)}</div>
                      </div>
                    </div>
                    <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${white(0.16)}`, pointerEvents: "none" }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        <div
          style={{
            position: "absolute",
            left: 34,
            top: 12,
            padding: "4px 9px",
            borderRadius: 999,
            background: black(0.32),
            color: "#fff",
            fontSize: 12,
            lineHeight: "16px",
            fontWeight: 700,
            display: "flex",
            gap: 3,
            pointerEvents: "none",
          }}
        >
          <NumericText value={page} text={String(page + 1)} />
          <span style={{ opacity: 0.7, fontVariantNumeric: "tabular-nums" }}>/ {COUNT}</span>
        </div>
      </div>
      <Dots page={page} fraction={ctx.b("scrub") ? fraction : page} scrub={ctx.b("scrub")} window={ctx.i("window")} response={ctx.n("response")} />
    </div>
  );
}

function Dots({ page, fraction, scrub, window, response }: { page: number; fraction: number; scrub: boolean; window: number; response: number }) {
  const size = clamp(window, 1, COUNT);
  const [start, setStart] = useState(0);
  // Moves the window just far enough to contain the page.
  let next = start;
  if (page < next) next = page;
  if (page > next + size - 1) next = page - size + 1;
  next = clamp(next, 0, Math.max(COUNT - size, 0));
  if (next !== start) setStart(next);

  /** 1 inside the window, tapering over the two dots outside each end, 0 beyond. */
  const scale = (i: number) => {
    const outside = i < start ? start - i : Math.max(i - (start + size - 1), 0);
    return outside === 0 ? 1 : outside === 1 ? 0.66 : outside === 2 ? 0.36 : 0.001;
  };
  // The window plus two tapering dots on each side, plus the pill's extra width.
  const width = (size + 4) * PITCH - GAP + (PILL - DOT);
  const t = spring(response, 0.8);
  const instant = { duration: 0 };
  return (
    <div style={{ position: "relative", width, height: 16, overflow: "hidden", flexShrink: 0 }}>
      <motion.div initial={false} animate={{ x: -(start - 2) * PITCH }} transition={t} style={{ position: "absolute", left: 0, top: 0, height: 16, display: "flex", alignItems: "center", gap: GAP }}>
        {Array.from({ length: COUNT }, (_, i) => {
          const weight = Math.max(0, 1 - Math.abs(i - fraction));
          return (
            <motion.div
              key={i}
              initial={false}
              animate={{ scale: scale(i), width: DOT + (PILL - DOT) * weight }}
              transition={{ scale: t, width: scrub ? instant : t }}
              style={{ position: "relative", height: DOT, borderRadius: DOT / 2, background: Palette.labelAlpha(0.22), overflow: "hidden", flexShrink: 0 }}
            >
              <motion.div initial={false} animate={{ opacity: weight }} transition={scrub ? instant : t} style={{ position: "absolute", inset: 0, background: Palette.primary }} />
            </motion.div>
          );
        })}
      </motion.div>
    </div>
  );
}
