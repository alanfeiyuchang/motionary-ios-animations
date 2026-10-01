/** scroll.pull-search · 下拉展开搜索 (Scroll+PullSearch.swift) */
import { Mic, Search } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, glass, rubberBand, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { ScrollKitRow, useScroller } from "./_kit";
import { Ico, ScrollMath, useSpringValue, useTopPull } from "./_motion";

const BAR = 48;
/** Room the open field takes below the bar. */
const SLOT = 52;
const WIDTH = 340;
const { lerp, unit, smooth } = ScrollMath;

export default function PullSearch({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const threshold = Math.max(ctx.n("threshold"), 1);
  const openSpring = spring(ctx.n("response"), ctx.n("damping"));
  /** 1 while the field is latched open (animated by the spring). */
  const openAmount = useSpringValue(0);
  const [isOpen, setIsOpen] = useState(false);
  const openRef = useRef(false);
  /** Simulated overscroll, used by the autoplay only. */
  const simulated = useSpringValue(0);
  const step = useRef(0);
  const cancelPull = useRef<(() => void) | null>(null);

  const setOpen = (open: boolean, haptic: boolean) => {
    openRef.current = open;
    setIsOpen(open);
    if (haptic) haptics.tap(open ? "medium" : "light");
    openAmount.to(open ? 1 : 0, openSpring);
  };
  const sc = useScroller({
    axis: "y",
    bounce: false,
    // Scrolling up into the content tucks the field away.
    onScroll: (o) => {
      if (openRef.current && o > 24) setOpen(false, false);
    },
  });
  const top = useTopPull({
    enabled: () => !ctx.isPreview && !openRef.current && sc.get() <= 0.5,
    onRelease: (pull) => release(pull, true),
  });
  const offset = sc.offset;
  const pull = Math.max(-offset, 0) + simulated.value + top.pull;

  /** The finger let go (or the autoplay's simulated pull ended): latch open past the threshold. */
  const release = (current: number, haptic: boolean) => {
    if (openRef.current || current < threshold) return;
    setOpen(true, haptic);
  };

  // One tick as the pull crosses the threshold (never for the scripted pull).
  const past = pull >= threshold;
  useEffect(() => {
    if (past && !openRef.current && !ctx.isPreview && simulated.get() === 0) haptics.tap("light");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [past]);

  useAutoplay(
    ctx.isPreview,
    () => {
      switch (step.current % 3) {
        case 0:
          // Pull, hold a beat, let go: one whole gesture per action.
          simulated.to(threshold + 18, spring(0.5, 0.9));
          cancelPull.current?.();
          cancelPull.current = after(0.65, () => {
            release(simulated.get(), false);
            simulated.to(0, openSpring);
          });
          break;
        case 1:
          sc.scrollTo(190, anim.smoothD(0.9));
          break;
        default:
          sc.scrollTo(0, anim.smoothD(0.9));
      }
      step.current += 1;
    },
    { every: 1.5 },
  );

  const live = Math.min(pull / threshold, 1);
  const p = Math.max(openAmount.value, live);
  // Past the threshold the field rubber-bands a little taller.
  const over = isOpen ? 0 : rubberBand(Math.max(pull - threshold, 0), 60);
  const scrolled = offset > 4;
  // The detail stage keeps its Reset button in the top-trailing corner.
  const trailingInset = ctx.isPreview ? 16 : 58;

  const button = { x: WIDTH - trailingInset - 34, y: 7, width: 34, height: 34 };
  const field = { x: 16, y: BAR + 4, width: Math.max(WIDTH - 32, 34), height: 40 + over * 0.3 };
  // The capsule first drops and widens together; the drop finishes a little earlier.
  const drop = smooth(unit(p, 0, 0.8));
  const rect = {
    x: lerp(button.x, field.x, p),
    y: lerp(button.y, field.y, drop),
    width: lerp(button.width, field.width, p),
    height: lerp(button.height, field.height, p),
  };
  const reveal = unit(p, 0.55, 1);
  // The glyph starts centred in the round button and slides to the field's leading inset.
  const glyphX = lerp((34 - 16) / 2, 13, p);

  return (
    <div {...top.props} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div
          ref={sc.contentRef}
          style={{
            padding: `${BAR + 8 + SLOT * openAmount.value + simulated.value + top.pull}px 16px 16px`,
            display: "flex",
            flexDirection: "column",
            gap: 10,
          }}
        >
          {Array.from({ length: 14 }, (_, i) => (
            <ScrollKitRow key={i} index={i + 5} lang={ctx.lang} style={{ flexShrink: 0 }} />
          ))}
        </div>
      </div>
      {/* Bar */}
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: BAR, pointerEvents: "none" }}>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 0,
            height: BAR + SLOT * p,
            ...glass("regular"),
            opacity: scrolled ? 1 : 0,
            transition: "opacity 0.2s ease-out",
          }}
        />
        <div style={{ position: "relative", height: BAR, padding: "0 18px", display: "flex", alignItems: "center", fontSize: 20, fontWeight: 700 }}>
          {ctx.t("Notes", "备忘录")}
        </div>
      </div>
      {/* The button that becomes the field */}
      <div
        onClick={() => setOpen(!openRef.current, true)}
        style={{
          position: "absolute",
          left: rect.x,
          top: rect.y,
          width: rect.width,
          height: rect.height,
          borderRadius: rect.height / 2,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.1)}, 0 4px 14px ${black(0.1 * p)}`,
          overflow: "hidden",
          cursor: "pointer",
        }}
      >
        <div style={{ position: "absolute", left: glyphX, top: 0, bottom: 0, width: 16, display: "grid", placeItems: "center", color: "#8370FF" }}>
          <Ico icon={Search} size={14} weight={700} />
        </div>
        <div
          style={{
            position: "absolute",
            left: 38 + (1 - reveal) * 10,
            top: 0,
            bottom: 0,
            display: "flex",
            alignItems: "center",
            fontSize: 15,
            color: Palette.secondaryLabel,
            whiteSpace: "nowrap",
            opacity: reveal,
          }}
        >
          {ctx.t("Search notes", "搜索备忘录")}
        </div>
        <div
          style={{
            position: "absolute",
            right: 13,
            top: 0,
            bottom: 0,
            display: "grid",
            placeItems: "center",
            color: Palette.secondaryLabel,
            opacity: reveal,
            transform: `scale(${0.6 + 0.4 * reveal})`,
          }}
        >
          <Ico icon={Mic} size={13} weight={600} fill />
        </div>
      </div>
      {!ctx.isPreview && (
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 10, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
          <div
            style={{
              padding: "6px 12px",
              borderRadius: 999,
              ...glass("regular"),
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 14px ${black(0.18)}`,
            }}
          >
            <DemoHint ctx={ctx} en={isOpen ? "Scroll up to tuck it away" : "Pull the list down"} zh={isOpen ? "向上滚动即可收起" : "向下拉动列表"} />
          </div>
        </div>
      )}
    </div>
  );
}
