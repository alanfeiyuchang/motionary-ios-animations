/** inputs.reaction-slider (Inputs+ReactionSlider.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, clamp, spring, textStyle, useAutoplay, useElapsed, useHaptics, usePan, type DemoProps } from "../../kit";
import { BOUNCY, SNAPPY, column, spacer, springTrack, useMV, useQuiet, useTask } from "./_c-common";

const REACTIONS: { emoji: string; name: [string, string] }[] = [
  { emoji: "❤️", name: ["Love", "喜欢"] },
  { emoji: "👍", name: ["Nice", "赞"] },
  { emoji: "😂", name: ["Haha", "哈哈"] },
  { emoji: "😮", name: ["Wow", "哇"] },
  { emoji: "🎉", name: ["Yay", "庆祝"] },
  { emoji: "🔥", name: ["Fire", "太燃了"] },
];
const CELL = 40;
const REST = CELL * REACTIONS.length;
const SCRIPT = [1, 5, 2, 4, 0, 3];

export default function ReactionSlider({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  /** Finger position along the resting row, 0...REST. */
  const fingerMV = useMotionValue(CELL * 3.5);
  const activeMV = useMotionValue(0);
  const isActive = useRef(false);
  const [selected, setSelected] = useState<number | null>(4);
  const hovered = useRef(-1);
  const touching = useRef(false);
  const [bounces, setBounces] = useState(() => REACTIONS.map(() => 0));
  const step = useRef(0);
  const playTask = useTask();

  const activate = () => {
    isActive.current = true;
    animate(activeMV, 1, spring(0.3, 0.65));
  };
  const hover = (x: number) => {
    const c = clamp(x, 0, REST);
    animate(fingerMV, c, spring(0.14, 0.85));
    const index = clamp(Math.floor(c / CELL), 0, REACTIONS.length - 1);
    if (index !== hovered.current) {
      hovered.current = index;
      haptics.selection();
    }
  };
  /** Finger lift, cancelled touch and autoplay all end here. */
  const release = (silent: boolean) => {
    if (hovered.current < 0) return;
    const choice = hovered.current;
    hovered.current = -1;
    if (!silent) haptics.tap("medium");
    setBounces((b) => b.map((v, i) => (i === choice ? v + 1 : v)));
    isActive.current = false;
    animate(activeMV, 0, spring(0.4, 0.7));
    setSelected(choice);
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ location }) => {
      playTask.cancel();
      if (!isActive.current) activate();
      hover(location.x - 12);
    },
    onEnd: () => {
      touching.current = false;
      release(false);
    },
  });

  useAutoplay(
    ctx.isPreview,
    wrap(() => {
      if (touching.current) return;
      const silent = quiet();
      const target = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      playTask.start(async (sleep) => {
        const from = target >= 3 ? 14 : REST - 14;
        fingerMV.stop();
        fingerMV.set(from);
        hovered.current = Math.floor(from / CELL);
        activate();
        if (!(await sleep(0.2))) return;
        animate(fingerMV, (target + 0.5) * CELL, anim.easeInOut(0.75));
        if (!(await sleep(0.9))) return;
        hovered.current = target;
        release(silent);
      });
    }),
    { every: 2.0, delay: 0.5 },
  );

  // The dock: re-derived from the finger position and the activity amount every frame.
  const fingerX = useMV(fingerMV);
  const active = useMV(activeMV);
  const maxScale = ctx.n("scale");
  const spread = ctx.n("spread");
  const scales = REACTIONS.map((_, index) => {
    const distance = fingerX - (index + 0.5) * CELL;
    return 1 + (maxScale - 1) * Math.exp(-(distance * distance) / (2 * spread * spread)) * active;
  });
  const widths = scales.map((s) => CELL * (1 + (s - 1) * 0.8));
  const total = widths.reduce((a, b) => a + b, 0);
  const centers: number[] = [];
  let cursor = -total / 2;
  for (const w of widths) {
    centers.push(cursor + w / 2);
    cursor += w;
  }
  const nearest = clamp(Math.floor(fingerX / CELL), 0, REACTIONS.length - 1);
  const presence = clamp(active);
  const W = 310;
  const H = 250;
  const barY = H / 2 - 38;

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", width: W, height: H, flexShrink: 0 }}>
        {/* message bubble */}
        <div style={{ position: "absolute", left: 0, right: 0, top: H / 2 + 62, display: "flex", justifyContent: "center" }}>
          <div
            style={{
              position: "relative",
              width: 244,
              padding: "12px 16px",
              transform: "translateY(-50%)",
              borderRadius: "22px 22px 22px 6px",
              background: Palette.elevated,
              boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}`,
              display: "flex",
              flexDirection: "column",
              alignItems: "flex-start",
              gap: 4,
              ...textStyle.callout,
            }}
          >
            <span>{ctx.t("We just shipped the update!", "新版本刚刚上线啦！")}</span>
            <span>{ctx.t("Go try the new animations.", "快去试试新的动效。")}</span>
            <AnimatePresence initial={false}>
              {selected !== null && (
                <motion.div
                  key={selected}
                  initial={{ scale: 0.3, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0.3, opacity: 0 }}
                  transition={spring(0.38, ctx.n("damping"))}
                  style={{
                    position: "absolute",
                    right: 10,
                    bottom: -14,
                    height: 28,
                    padding: "0 8px",
                    borderRadius: 14,
                    background: Palette.elevated,
                    boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.12)}, 0 2px 7px ${black(0.14)}`,
                    display: "grid",
                    placeItems: "center",
                    fontSize: 16,
                    lineHeight: "20px",
                  }}
                >
                  {REACTIONS[selected].emoji}
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
        {/* dock */}
        <div
          style={{
            position: "absolute",
            left: W / 2 - (total + 20) / 2,
            top: barY - 26,
            width: total + 20,
            height: 52,
            borderRadius: 26,
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}, 0 8px 21px ${black(0.16)}`,
          }}
        />
        {REACTIONS.map((reaction, index) => (
          <Emoji key={index} emoji={reaction.emoji} bounce={bounces[index]} scale={scales[index]} x={W / 2 + centers[index]} y={barY - (scales[index] - 1) * 5} />
        ))}
        <div
          style={{
            position: "absolute",
            left: W / 2 + centers[nearest],
            top: barY - 12 - 31 * scales[nearest] + 14 * (1 - presence),
            transform: `translate(-50%, -50%) scale(${0.6 + 0.4 * presence})`,
            opacity: presence,
            height: 20,
            padding: "0 8px",
            borderRadius: 10,
            background: black(0.72),
            color: "#fff",
            fontSize: 11,
            fontWeight: 700,
            lineHeight: "20px",
            whiteSpace: "nowrap",
            pointerEvents: "none",
          }}
        >
          {ctx.t(...REACTIONS[nearest].name)}
        </div>
        <div {...pan} style={{ ...pan.style, position: "absolute", left: W / 2 - (REST + 24) / 2, top: H / 2 - 44 - 38, width: REST + 24, height: 76, cursor: "pointer" }} />
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Slide across the reactions, then let go" zh="在表情上滑动，再松手" style={{ paddingBottom: 14 }} />
    </div>
  );
}

function Emoji({ emoji, bounce, scale, x, y }: { emoji: string; bounce: number; scale: number; x: number; y: number }) {
  const t = useElapsed(bounce, 0.66, true);
  const pop = springTrack(t, 1, [
    { to: 1.35, duration: 0.16, spring: SNAPPY },
    { to: 1, duration: 0.5, spring: BOUNCY },
  ]);
  const lift = springTrack(t, 0, [
    { to: -14, duration: 0.16, spring: SNAPPY },
    { to: 0, duration: 0.5, spring: BOUNCY },
  ]);
  return (
    <div
      style={{
        position: "absolute",
        left: x - 20,
        top: y - 17,
        width: 40,
        height: 34,
        display: "grid",
        placeItems: "center",
        fontSize: 27,
        lineHeight: "34px",
        transformOrigin: "50% 100%",
        transform: `scale(${scale}) translateY(${lift}px) scale(${pop})`,
        pointerEvents: "none",
      }}
    >
      {emoji}
    </div>
  );
}
