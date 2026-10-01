/** inputs.crown-scroll (Inputs+CrownScroll.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, clamp, fonts, rubberBand, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { column, spacer, useMV, useTask } from "./_c-common";

const MAX = 12;
const BODY = { w: 166, h: 202 };
const ROW = 62;

/** Position after the detent curve (inside the range) or the rubber band (outside it), in steps. */
function display(pos: number, unit: number, detent: number, limit: number) {
  if (pos < 0) return rubberBand(pos * unit, limit) / ROW;
  if (pos > MAX) return MAX + rubberBand((pos - MAX) * unit, limit) / ROW;
  const base = Math.round(pos);
  const offset = pos - base;
  const shaped = Math.pow(Math.abs(offset) * 2, 1 + detent) / 2;
  return base + (offset < 0 ? -shaped : shaped);
}
/** How far the crown surface has travelled, in points. It resists past the ends too. */
function travelOf(pos: number, unit: number, limit: number) {
  if (pos < 0) return rubberBand(pos * unit, limit * 1.5);
  if (pos > MAX) return MAX * unit + rubberBand((pos - MAX) * unit, limit * 1.5);
  return pos * unit;
}

export default function CrownScroll({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const posMV = useMotionValue(5);
  const posTarget = useRef(5);
  const startPos = useRef(0);
  const dragging = useRef(false);
  const touching = useRef(false);
  const [active, setActive] = useState(false);
  const lastIndex = useRef(5);
  const atEnd = useRef(false);
  /** Fling still to come, in steps. */
  const fling = useRef(0);
  const step = useRef(0);
  const playTask = useTask();
  const idleTask = useTask();
  const unit = ctx.n("unit");

  /** Finger and autoplay both land here. */
  const roll = (target: number) => {
    posMV.stop();
    posMV.set(target);
    posTarget.current = target;
    const index = clamp(Math.round(target), 0, MAX);
    if (index !== lastIndex.current) {
      lastIndex.current = index;
      haptics.selection();
    }
    const beyond = target < -0.05 || target > MAX + 0.05;
    if (beyond && !atEnd.current) haptics.tap("rigid");
    atEnd.current = beyond;
  };
  const sleepSoon = () =>
    idleTask.start(async (sleep) => {
      if (!(await sleep(1.1))) return;
      setActive(false);
    });
  const settle = (projected: number) => {
    if (!dragging.current) return;
    dragging.current = false;
    atEnd.current = false;
    const rest = clamp(Math.round(projected), 0, MAX);
    lastIndex.current = rest;
    posTarget.current = rest;
    animate(posMV, rest, spring(0.5, 0.78));
    sleepSoon();
  };
  const wake = () => {
    idleTask.cancel();
    setActive(true);
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ translation, velocity }) => {
      if (!dragging.current) {
        playTask.cancel();
        dragging.current = true;
        startPos.current = posMV.get();
        wake();
      }
      fling.current = (velocity.y * 0.2) / unit;
      roll(startPos.current - translation.y / unit);
    },
    onEnd: () => {
      touching.current = false;
      settle(posTarget.current - fling.current * 0.4);
    },
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      if (touching.current) return;
      const target = [8, 13.4, 9, 3, -1.4, 5][step.current % 6];
      step.current += 1;
      playTask.start(async (sleep) => {
        wake();
        dragging.current = true;
        const beyond = target < 0 || target > MAX;
        posTarget.current = target;
        animate(posMV, target, beyond ? anim.easeOut(0.5) : spring(0.6, 0.82));
        if (!(await sleep(beyond ? 0.55 : 0.7))) return;
        settle(target);
      });
    },
    { every: 1.4, delay: 0.5 },
  );

  const pos = useMV(posMV);
  const shown = display(pos, unit, ctx.n("detent"), ctx.n("limit"));
  const travel = travelOf(pos, unit, ctx.n("limit"));
  const nearest = clamp(Math.round(shown), 0, MAX);
  const numbers: number[] = [];
  for (let n = Math.max(nearest - 2, 0); n <= Math.min(nearest + 2, MAX); n++) numbers.push(n);
  const fraction = clamp(shown / MAX, -0.08, 1.08);
  const cx = 115;
  const cy = 131;
  const box = (x: number, y: number, w: number, h: number) => ({ position: "absolute", left: cx + x - w / 2, top: cy + y - h / 2, width: w, height: h }) as const;

  // Crown ridges: lines on a turning cylinder.
  const radius = 26;
  const spacing = 0.34;
  const turn = travel / radius;
  const first = Math.ceil((-Math.PI / 2 + turn) / spacing);
  const last = Math.floor((Math.PI / 2 + turn) / spacing);
  const ridges = [];
  for (let index = first; index <= last; index++) {
    const phi = index * spacing - turn;
    const y = radius + Math.sin(phi) * radius;
    const facing = Math.cos(phi);
    ridges.push(
      <g key={index}>
        <line x1={1} y1={y} x2={17} y2={y} stroke={black(0.55 * facing)} strokeWidth={Math.max(2.4 * facing, 0.4)} />
        <line x1={1} y1={y + 1.6 * facing} x2={17} y2={y + 1.6 * facing} stroke={white(0.3 * facing)} strokeWidth={0.8} />
      </g>,
    );
  }
  const strap = (y: number) => <div style={{ ...box(0, y, 116, 44), borderRadius: 14, background: "linear-gradient(90deg, #3B3B42, #26262B)" }} />;

  return (
    <div style={column}>
      <div style={spacer} />
      <div {...pan} style={{ ...pan.style, position: "relative", width: 230, height: 262, flexShrink: 0, cursor: "grab" }}>
        <div style={{ position: "absolute", inset: 0, transform: "translateX(-8px)" }}>
          {strap(-112)}
          {strap(112)}
          {/* crown */}
          <motion.div
            initial={false}
            animate={{ boxShadow: `0 0 9px ${alpha(Palette.amber, active ? 0.5 : 0)}` }}
            transition={anim.easeOut(active ? 0.2 : 0.4)}
            style={{
              ...box(BODY.w / 2 + 7, -34, 18, 52),
              borderRadius: 6,
              overflow: "hidden",
              background: "linear-gradient(180deg, #1F1F23, #8A8A93, #B8B8C0, #77777F, #1F1F23)",
            }}
          >
            <svg width={18} height={52} style={{ position: "absolute", inset: 0 }}>
              {ridges}
            </svg>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: 6,
                border: `1px solid ${active ? alpha(Palette.amber, 0.9) : white(0.2)}`,
                transition: `border-color ${active ? 0.2 : 0.4}s ease-out`,
              }}
            />
          </motion.div>
          <div style={{ ...box(BODY.w / 2 + 2, 34, 7, 36), borderRadius: 3.5, background: "linear-gradient(180deg, #55555C, #2A2A2F)" }} />
          {/* casing */}
          <div style={{ ...box(0, 0, BODY.w, BODY.h), borderRadius: 46, background: "linear-gradient(140deg, #4A4A52, #1E1E22)", boxShadow: `inset 0 0 0 1px ${white(0.18)}, 0 10px 24px ${black(0.3)}` }} />
          {/* screen */}
          <div style={{ ...box(0, 0, BODY.w - 16, BODY.h - 16), borderRadius: 38, overflow: "hidden", background: "#000" }}>
            {numbers.map((number) => {
              const distance = number - shown;
              const far = Math.min(Math.abs(distance), 2);
              return (
                <div
                  key={number}
                  style={{
                    position: "absolute",
                    inset: 0,
                    display: "grid",
                    placeItems: "center",
                    fontFamily: fonts.rounded,
                    fontSize: 68,
                    fontWeight: 700,
                    fontVariantNumeric: "tabular-nums",
                    lineHeight: "81px",
                    color: "#fff",
                    opacity: 1 - far * 0.42,
                    transform: `translateY(${distance * ROW * (1 - far * 0.08)}px) perspective(164px) rotateX(${distance * -28}deg) scale(${1 - far * 0.28})`,
                  }}
                >
                  {number}
                </div>
              );
            })}
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(180deg, #000 0%, ${black(0)} 30%, ${black(0)} 72%, #000 100%)` }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                padding: "15px 20px",
                display: "flex",
                flexDirection: "column",
                justifyContent: "space-between",
                alignItems: "flex-start",
                fontFamily: fonts.rounded,
                fontSize: 12,
                fontWeight: 700,
                lineHeight: "15px",
              }}
            >
              <span style={{ color: Palette.amber }}>{ctx.t("TIMER", "计时")}</span>
              <span style={{ color: white(0.55) }}>{ctx.t("MIN", "分钟")}</span>
            </div>
            {/* The small pill that appears next to the crown while scrolling. */}
            <div
              style={{
                position: "absolute",
                right: 9,
                top: 47,
                width: 5,
                height: 40,
                borderRadius: 2.5,
                background: white(0.18),
                overflow: "hidden",
                opacity: active ? 1 : 0,
                transition: `opacity ${active ? 0.2 : 0.4}s ease-out`,
              }}
            >
              <div style={{ position: "absolute", left: 0, top: fraction * 26, width: 5, height: 14, borderRadius: 2.5, background: Palette.amber }} />
            </div>
          </div>
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Roll the crown up or down" zh="上下拨动表冠" style={{ paddingBottom: 14 }} />
    </div>
  );
}
