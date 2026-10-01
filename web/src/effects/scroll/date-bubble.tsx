/** scroll.date-bubble · 拖动滚动条的日期气泡 (Scroll+DateBubble.swift) */
import { motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, clamp, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKit, ScrollVelocityTracker, Sym, useScroller } from "./_kit";
import { useSpringValue } from "./_motion";

// MARK: - Library model

const MONTHS = 24;
const COLUMNS = 4;
const GAP = 3;
const HEADER = 30;
const INSET = 12;
const NAMES_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
/** Photos in month `m` (0 is the newest: September 2026). */
const count = (m: number) => [7, 12, 5, 9, 4, 8, 11, 6][m % 8];
const rowsOf = (m: number) => Math.floor((count(m) + COLUMNS - 1) / COLUMNS);
const tileOf = (width: number) => Math.max((width - INSET * 2 - GAP * (COLUMNS - 1)) / COLUMNS, 20);
const heightOf = (m: number, width: number) => HEADER + rowsOf(m) * (tileOf(width) + GAP);
/** Content y where each month begins. */
function startsOf(width: number) {
  let y = 0;
  return Array.from({ length: MONTHS }, (_, m) => {
    const start = y;
    y += heightOf(m, width);
    return start;
  });
}
const yearOf = (m: number) => 2026 - Math.floor((m + 3) / 12);
/** 1…12, counting back from September. */
const monthOf = (m: number) => ((((8 - m) % 12) + 12) % 12) + 1;
const labelOf = (m: number, lang: Lang) => (lang === "zh" ? `${yearOf(m)}年${monthOf(m)}月` : `${NAMES_EN[monthOf(m) - 1]} ${yearOf(m)}`);

const THUMB = 46;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

// MARK: - Demo

export default function DateBubble({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [scrubbing, setScrubbingState] = useState(false);
  const scrubbingRef = useRef(false);
  /** Signed speed, −1…1 (positive while moving down the library). */
  const stretch = useSpringValue(0);
  const tracker = useRef(new ScrollVelocityTracker());
  const calmToken = useRef(0);
  const grabFraction = useRef(0);
  const [month, setMonth] = useState(0);
  const monthRef = useRef(0);
  const down = useRef(false);
  /** True while the autoplay scrubs: its month changes stay silent. */
  const scripted = useRef(false);
  const widthRef = useRef(340);

  const sc = useScroller({
    axis: "y",
    onScroll: (o) => {
      const starts = startsOf(widthRef.current);
      let current = 0;
      starts.forEach((start, m) => {
        if (start <= o + 24) current = m;
      });
      if (current !== monthRef.current) {
        monthRef.current = current;
        setMonth(current);
        if (scrubbingRef.current && !ctx.isPreview && !scripted.current) haptics.selection();
      }
      if (!scrubbingRef.current) return;
      stretch.to(clamp(tracker.current.sample(o, 6000) / 4000, -1, 1), null);
      // No new offsets for a moment means the thumb is being held still: relax.
      const token = ++calmToken.current;
      after(0.09, () => {
        if (token !== calmToken.current) return;
        tracker.current.reset();
        stretch.to(0, spring(0.25, 0.55));
      });
    },
  });
  const width = sc.size.width || 340;
  const height = sc.size.height || (ctx.isPreview ? 340 : 400);
  widthRef.current = width;
  const maxOffset = Math.max(sc.max(), 1);

  // The detail stage keeps its Reset button in the top-trailing corner.
  const trackTop = ctx.isPreview ? 10 : 50;
  const travel = Math.max(height - trackTop - 10 - THUMB, 1);
  const fraction = clamp(sc.offset / maxOffset, 0, 1);
  const thumbY = trackTop + fraction * travel;

  // Scrubbing (finger and autoplay share these)
  const setScrubbing = (on: boolean) => {
    scrubbingRef.current = on;
    setScrubbingState(on);
  };
  const beginScrub = (y: number | null) => {
    if (y !== null) {
      // A touch on the track outside the thumb brings the thumb under the finger first.
      const onThumb = y >= thumbY - 8 && y <= thumbY + THUMB + 8;
      grabFraction.current = onThumb ? fraction : clamp((y - trackTop - THUMB / 2) / travel, 0, 1);
      haptics.tap("light");
    }
    tracker.current.reset();
    setScrubbing(true);
  };
  const scrub = (target: number) => sc.scrollTo(clamp(target, 0, 1) * Math.max(sc.max(), 1), null);
  const endScrub = () => {
    calmToken.current += 1;
    setScrubbing(false);
    stretch.to(0, spring(0.25, 0.55));
  };

  /** Claims the touch at once (no minimum distance), so the grid does not scroll instead. */
  const grab = usePan({
    onStart: (s) => {
      scripted.current = false;
      beginScrub(s.start.y);
    },
    onChange: (s) => scrub(grabFraction.current + s.translation.y / travel),
    onEnd: endScrub,
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      scripted.current = true;
      beginScrub(null);
      sc.scrollTo((down.current ? 0.72 : 0.06) * Math.max(sc.max(), 1), anim.easeInOut(1.5));
      after(1.75, endScrub);
    },
    { every: 2.5 },
  );
  useEffect(() => () => void (calmToken.current += 1), []);

  const squash = ctx.n("squash");
  const speed = Math.abs(stretch.value) * squash;
  const starts = startsOf(width);
  const thumbSpring = spring(0.25, 0.7);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ padding: `0 ${INSET}px` }}>
          {Array.from({ length: MONTHS }, (_, m) => (
            <Month key={m} month={m} width={width} lang={ctx.lang} />
          ))}
        </div>
      </div>
      {/* Year labels beside the track, at the height where the thumb sits when that year starts. */}
      {ctx.b("ticks") && (
        <motion.div initial={false} animate={{ opacity: scrubbing ? 1 : 0 }} transition={thumbSpring} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          {Array.from({ length: MONTHS }, (_, m) =>
            m === 0 || yearOf(m) !== yearOf(m - 1) ? (
              <div
                key={m}
                style={{
                  position: "absolute",
                  right: 16,
                  top: trackTop + THUMB / 2 + clamp(starts[m] / maxOffset, 0, 1) * travel - 9,
                  padding: "2px 5px",
                  borderRadius: 999,
                  background: "color-mix(in srgb, var(--ml-stage) 85%, transparent)",
                  display: "flex",
                  alignItems: "center",
                  gap: 4,
                }}
              >
                <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel }}>{yearOf(m)}</span>
                <span style={{ width: 8, height: 1.5, borderRadius: 1, background: Palette.labelAlpha(0.3) }} />
              </div>
            ) : null,
          )}
        </motion.div>
      )}
      {/* Thumb */}
      <div style={{ position: "absolute", right: 5, top: thumbY, height: THUMB, display: "flex", justifyContent: "flex-end", pointerEvents: "none" }}>
        <motion.div initial={false} animate={{ width: scrubbing ? 8 : 5 }} transition={thumbSpring} style={{ position: "relative", height: THUMB, borderRadius: 4, background: Palette.labelAlpha(0.32), overflow: "hidden" }}>
          <motion.div initial={false} animate={{ opacity: scrubbing ? 1 : 0 }} transition={thumbSpring} style={{ position: "absolute", inset: 0, background: Palette.primary }} />
        </motion.div>
      </div>
      {/* Bubble: it trails the motion (up while moving down, down while moving up). */}
      <div style={{ position: "absolute", right: 22, top: thumbY + (THUMB - 34) / 2 - 10 * stretch.value * squash, pointerEvents: "none" }}>
        <motion.div
          initial={false}
          animate={{ scale: scrubbing ? 1 : 0.4, opacity: scrubbing ? 1 : 0 }}
          transition={scrubbing ? spring(ctx.n("response"), 0.6) : anim.easeIn(0.2)}
          style={{ transformOrigin: "100% 50%" }}
        >
          <div
            style={{
              position: "relative",
              height: 34,
              transform: `scale(${1 + 0.18 * speed}, ${1 - 0.22 * speed})`,
              transformOrigin: "100% 50%",
              filter: `drop-shadow(0 5px 10px ${alpha(Palette.indigo, 0.4)})`,
            }}
          >
            {/* The pointer: a rounded square turned 45°, half hidden behind the capsule. */}
            <div style={{ position: "absolute", right: -5, top: (34 - 17) / 2, width: 17, height: 17, borderRadius: 4, background: "#7A45D6", transform: "rotate(45deg)" }} />
            <div
              style={{
                position: "relative",
                height: 34,
                padding: "0 13px",
                borderRadius: 17,
                background: PRIMARY_STRONG,
                display: "flex",
                alignItems: "center",
                color: "#fff",
                fontSize: 15,
                fontWeight: 700,
                whiteSpace: "nowrap",
              }}
            >
              <NumericText value={-month} text={labelOf(month, ctx.lang)} />
            </div>
          </div>
        </motion.div>
      </div>
      {/* The strip that claims vertical drags from the grid. */}
      <div {...grab} style={{ ...grab.style, position: "absolute", right: 0, top: 0, bottom: 0, width: 34, cursor: "grab" }} />
    </div>
  );
}

// MARK: - Pieces

function Month({ month, width, lang }: { month: number; width: number; lang: Lang }) {
  const tile = tileOf(width);
  const n = count(month);
  return (
    <div style={{ height: heightOf(month, width) }}>
      <div style={{ height: HEADER, display: "flex", alignItems: "flex-end", gap: 6, whiteSpace: "nowrap" }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 700 }}>{labelOf(month, lang)}</span>
        <span style={{ fontSize: 12, lineHeight: "19px", color: Palette.secondaryLabel }}>{lang === "zh" ? `${n} 张` : `${n} photos`}</span>
      </div>
      <div style={{ paddingTop: GAP, display: "flex", flexWrap: "wrap", gap: GAP }}>
        {Array.from({ length: n }, (_, index) => (
          <Tile key={index} seed={month * 17 + index * 5} size={tile} />
        ))}
      </div>
    </div>
  );
}

function Tile({ seed, size }: { seed: number; size: number }) {
  const colors = ScrollKit.colors(seed);
  return (
    <div
      style={{
        position: "relative",
        width: size,
        height: size,
        borderRadius: 7,
        overflow: "hidden",
        background: `linear-gradient(${seed % 2 === 0 ? 135 : 153}deg, ${colors[0]}, ${colors[1]})`,
        display: "grid",
        placeItems: "center",
        color: white(0.85),
      }}
    >
      {seed % 3 === 0 ? (
        <Sym name={ScrollKit.symbol(seed)} size={20} weight={600} />
      ) : (
        <div
          style={{
            position: "absolute",
            left: size / 2 - 32 + ((seed % 5) * 6 - 12),
            top: size / 2 - 32 + ((seed % 4) * 6 - 10),
            width: 64,
            height: 64,
            background: `radial-gradient(circle, ${white(0.17)} 25%, transparent 70%)`,
          }}
        />
      )}
    </div>
  );
}
