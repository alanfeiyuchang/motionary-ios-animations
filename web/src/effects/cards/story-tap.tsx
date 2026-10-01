/** cards.story-tap · 故事点按翻页 (Cards+StoryTap.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Ellipsis, Pause, Plane } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, black, clamp, spring, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { DeckFace, Stage, StrokeBorder, useMV } from "./shared";
import { Projected, hingeY, projection } from "./_kit";

const SIZE = { w: 196, h: 284 };
const COUNT = 5;
const now = () => performance.now() / 1000;

interface Story {
  index: number;
  previous: number | null;
  direction: number;
  started: number;
  pausedAt: number | null;
}

export default function StoryTap({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [story, setStoryState] = useState<Story>(() => ({ index: 0, previous: null, direction: 1, started: now(), pausedAt: null }));
  const ref = useRef(story);
  const setStory = (patch: Partial<Story>) => {
    ref.current = { ...ref.current, ...patch };
    setStoryState(ref.current);
  };
  /** 0 → 1 while the new page pushes in. */
  const slideMV = useMotionValue(1);
  /** −1 left side pressed, +1 right side, 0 flat. */
  const tiltMV = useMotionValue(0);
  const [holding, setHolding] = useState(false);
  const holdingRef = useRef(false);
  const touching = useRef(false);
  const touchSide = useRef(1);
  const holdTask = useTimeouts();
  const autoTask = useTimeouts();
  const autoStep = useRef(0);
  const duration = ctx.n("duration");
  const running = story.pausedAt === null;
  useClock(running, ctx.isPreview ? 30 : undefined);

  const advance = (step: number) => {
    const s = ref.current;
    const target = s.index + step;
    const started = now();
    setStory({ started, pausedAt: s.pausedAt !== null ? started : null });
    // Going back from the first story just restarts it.
    if (target < 0) return;
    setStory({ previous: s.index, direction: step >= 0 ? 1 : -1, index: target % COUNT });
    slideMV.stop();
    slideMV.jump(0);
    animate(slideMV, 1, spring(ctx.n("response"), 0.86));
  };
  const advanceRef = useRef(advance);
  advanceRef.current = advance;

  useEffect(() => {
    if (!running) return;
    const remaining = duration - (now() - story.started);
    const id = window.setTimeout(() => advanceRef.current(1), Math.max(remaining, 0) * 1000);
    return () => window.clearTimeout(id);
  }, [story.index, story.started, running, duration]);

  const setHold = (value: boolean) => {
    holdingRef.current = value;
    setHolding(value);
  };

  /** Single end of a touch: a short one is a tap that advances, a long one only resumes. */
  const lift = (wantsAdvance: boolean) => {
    if (!touching.current) return;
    touching.current = false;
    holdTask.clearAll();
    const wasHolding = holdingRef.current;
    setHold(false);
    animate(tiltMV, 0, spring(0.45, 0.5));
    const s = ref.current;
    if (s.pausedAt !== null) setStory({ started: s.started + (now() - s.pausedAt), pausedAt: null });
    if (wantsAdvance && !wasHolding) {
      haptics.tap("light");
      advance(touchSide.current);
    }
  };

  const pan = usePan({
    onChange: ({ start }) => {
      if (touching.current) return;
      touching.current = true;
      autoTask.clearAll();
      touchSide.current = start.x < SIZE.w / 2 ? -1 : 1;
      if (ref.current.pausedAt === null) setStory({ pausedAt: now() });
      animate(tiltMV, touchSide.current, spring(0.25, 0.7));
      holdTask.clearAll();
      holdTask.after(0.25, () => {
        setHold(true);
        haptics.tap("soft");
      });
    },
    onEnd: () => lift(true),
  });

  // Preview: the same press-then-release a finger makes, mostly on the right side.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      const side = autoStep.current % 4 === 3 ? -1 : 1;
      autoStep.current += 1;
      animate(tiltMV, side, spring(0.25, 0.7));
      autoTask.clearAll();
      autoTask.after(0.16, () => {
        animate(tiltMV, 0, spring(0.45, 0.5));
        advance(side);
      });
    },
    { every: 1.5, intro: false },
  );

  const slide = useMV(slideMV);
  const tilt = useMV(tiltMV);
  const angle = (-tilt * ctx.n("tilt") * Math.PI) / 180;
  const fill = clamp(((story.pausedAt ?? now()) - story.started) / duration);
  const K = 2;

  return (
    <Stage gap={10}>
      <motion.div {...pan} initial={false} animate={{ scale: holding ? 0.97 : 1 }} transition={spring(0.3, 0.8)} style={{ position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0, touchAction: "none", cursor: "pointer" }}>
        <Projected
          w={SIZE.w}
          h={SIZE.h}
          k={K}
          transform={projection(hingeY(SIZE.w / 2, angle), { x: SIZE.w / 2, y: SIZE.h / 2 }, 620)}
          style={{ borderRadius: 26 * K, boxShadow: `${-tilt * 9 * K}px ${12 * K}px ${16 * K}px ${black(0.24)}` }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden" }}>
            {story.previous !== null && (
              <div style={{ position: "absolute", inset: 0, transform: `translateX(${-story.direction * SIZE.w * 0.3 * slide}px)`, filter: `brightness(${1 - 0.3 * slide})` }}>
                <DeckFace index={story.previous} ctx={ctx} width={SIZE.w} height={SIZE.h} />
              </div>
            )}
            <div style={{ position: "absolute", inset: 0, borderRadius: 24, transform: `translateX(${story.direction * SIZE.w * (1 - slide)}px)`, boxShadow: `0 0 12px ${black(0.35)}` }}>
              <DeckFace index={story.index} ctx={ctx} width={SIZE.w} height={SIZE.h} />
            </div>
            {/* The pressed side sinks away from the light. */}
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(to ${tilt >= 0 ? "left" : "right"}, ${black(0.3)}, ${black(0)} 50%)`, opacity: Math.min(Math.abs(tilt), 1), pointerEvents: "none" }} />
            <motion.div initial={false} animate={{ opacity: holding ? 0 : 1 }} transition={spring(0.3, 0.8)} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
              <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 76, background: `linear-gradient(${black(0.35)}, ${black(0)})` }} />
              <div style={{ position: "absolute", left: 11, right: 11, top: 12, display: "flex", flexDirection: "column", gap: 9 }}>
                <div style={{ display: "flex", gap: 4 }}>
                  {Array.from({ length: COUNT }, (_, segment) => {
                    const amount = segment < story.index ? 1 : segment === story.index ? fill : 0;
                    return (
                      <div key={segment} style={{ position: "relative", flex: 1, height: 3, borderRadius: 1.5, background: white(0.35), overflow: "hidden" }}>
                        <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: `${amount * 100}%`, borderRadius: 1.5, background: "#fff" }} />
                      </div>
                    );
                  })}
                </div>
                <div style={{ display: "flex", alignItems: "center", gap: 7, color: "#fff" }}>
                  <div style={{ width: 24, height: 24, borderRadius: 12, background: white(0.25), boxShadow: `inset 0 0 0 1.2px ${white(0.8)}`, display: "grid", placeItems: "center" }}>
                    <Plane size={11} fill="currentColor" strokeWidth={1} style={{ transform: "rotate(45deg)" }} />
                  </div>
                  <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 700 }}>{ctx.t("Wander", "漫游志")}</span>
                  <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, opacity: 0.7 }}>2h</span>
                  <span style={{ flex: 1 }} />
                  <Ellipsis size={15} strokeWidth={3.2} />
                </div>
              </div>
            </motion.div>
            <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", pointerEvents: "none" }}>
              <motion.div
                initial={false}
                animate={{ scale: holding ? 1 : 0.6, opacity: holding ? 1 : 0 }}
                transition={spring(0.3, 0.8)}
                style={{ width: 52, height: 52, borderRadius: 26, background: black(0.4), display: "grid", placeItems: "center", color: "#fff" }}
              >
                <Pause size={22} fill="currentColor" strokeWidth={0} />
              </motion.div>
            </div>
          </div>
          <StrokeBorder radius={26} color={white(0.18)} />
        </Projected>
      </motion.div>
      <DemoHint ctx={ctx} en="Tap left or right, hold to pause" zh="点按左右两侧，按住暂停" />
    </Stage>
  );
}
