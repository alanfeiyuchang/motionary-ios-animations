/** scroll.expanding-strips · 展开式竖条画廊 (Scroll+ExpandingStrips.swift) */
import { ArrowUpRight } from "lucide-react";
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, rubberBand, spring, useAutoplay, useHaptics, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKit, Sym } from "./_kit";
import { Ico, ScrollMath, useDrag, useSpringValue } from "./_motion";

const COUNT = 9;
/** Finger travel that moves the gallery by one strip. */
const DRAG_PITCH = 110;
const EXPANDED = 190;
const SPACING = 8;
const WIDTH = 340;
const { lerp, unit, smooth } = ScrollMath;

export default function ExpandingStrips({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const position = useSpringValue(2);
  const [selected, setSelectedState] = useState(2);
  const selectedRef = useRef(2);
  const dragStart = useRef<number | null>(null);
  const direction = useRef(1);
  const setSelected = (i: number) => {
    selectedRef.current = i;
    setSelectedState(i);
  };

  /** The single settle path: drags, taps and autoplay all land here. */
  const settle = (index: number, haptic: boolean) => {
    const target = clamp(index, 0, COUNT - 1);
    if (target !== selectedRef.current) {
      if (haptic) haptics.selection();
      setSelected(target);
    }
    position.to(position.get(), null);
    position.to(target, spring(ctx.n("response"), ctx.n("damping")));
  };

  const drag = useDrag(
    {
      onChange: (s) => {
        const start = dragStart.current ?? position.get();
        dragStart.current = start;
        let raw = start - s.translation.x / DRAG_PITCH;
        const last = COUNT - 1;
        if (raw < 0) raw = -rubberBand(-raw * DRAG_PITCH, 80) / DRAG_PITCH;
        if (raw > last) raw = last + rubberBand((raw - last) * DRAG_PITCH, 80) / DRAG_PITCH;
        position.to(raw, null);
        const nearest = clamp(Math.round(raw), 0, COUNT - 1);
        if (nearest !== selectedRef.current) {
          setSelected(nearest);
          haptics.selection();
        }
      },
      onEnd: (s) => {
        const start = dragStart.current ?? position.get();
        dragStart.current = null;
        // A flick may carry up to two strips.
        const now = position.get();
        const projected = start - s.predicted.x / DRAG_PITCH;
        settle(Math.round(clamp(Math.round(projected), now - 2, now + 2)), false);
      },
    },
    { minimumDistance: 10, direction: "x", touchAction: "pan-y" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      if (selectedRef.current + direction.current >= COUNT - 1 || selectedRef.current + direction.current < 1) direction.current = -direction.current;
      settle(selectedRef.current + direction.current, false);
    },
    { every: 1.5 },
  );

  const collapsed = ctx.n("collapsed");
  const pos = position.value;
  const weight = (i: number) => smooth(1 - Math.abs(i - pos));
  const stripWidth = (i: number) => lerp(collapsed, EXPANDED, weight(i));

  // x of the weighted centre of the open strip(s) inside the row.
  let x = 0;
  let centre = 0;
  let total = 0;
  const lefts: number[] = [];
  for (let i = 0; i < COUNT; i++) {
    const w = stripWidth(i);
    const k = weight(i);
    lefts.push(x);
    centre += (x + w / 2) * k;
    total += k;
    x += w + SPACING;
  }
  let focusCentre: number;
  if (total <= 0.001) {
    // Past either end (rubber band) no strip is open: follow the nearest one.
    focusCentre = pos < 0 ? collapsed / 2 + pos * 60 : x - SPACING - collapsed / 2 + (pos - (COUNT - 1)) * 60;
  } else {
    const edge = pos < 0 ? pos * 60 : Math.max(pos - (COUNT - 1), 0) * 60;
    focusCentre = centre / total + edge;
  }

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div {...drag} style={{ ...drag.style, position: "relative", width: WIDTH, height: 240, flexShrink: 0 }}>
        <div style={{ position: "absolute", left: 0, top: 0, height: 240, transform: `translateX(${WIDTH / 2 - focusCentre}px)` }}>
          {Array.from({ length: COUNT }, (_, i) => (
            <Strip key={i} index={i} weight={weight(i)} width={stripWidth(i)} left={lefts[i]} lang={ctx.lang} onTap={() => settle(i, true)} />
          ))}
        </div>
      </div>
      <div style={{ display: "flex", gap: 5, flexShrink: 0 }}>
        {Array.from({ length: COUNT }, (_, i) => (
          <motion.div
            key={i}
            initial={false}
            animate={{ width: i === selected ? 18 : 6 }}
            transition={spring(0.4, 0.72)}
            style={{ height: 6, borderRadius: 3, background: i === selected ? Palette.primary : Palette.labelAlpha(0.18) }}
          />
        ))}
      </div>
      <DemoHint ctx={ctx} en="Drag sideways · tap a strip" zh="左右拖动 · 点击任意一条" />
    </div>
  );
}

function Strip({ index, weight, width, left, lang, onTap }: { index: number; weight: number; width: number; left: number; lang: Lang; onTap: () => void }) {
  const height = lerp(200, 236, weight);
  const radius = lerp(Math.min(width / 2, 22), 28, weight);
  const label = 1 - unit(weight, 0, 0.5);
  const caption = unit(weight, 0.5, 1);
  const colors = ScrollKit.colors(index);
  const title = ScrollKit.title(index, lang);
  const blob = (w: number, x: number, y: number): React.CSSProperties => ({
    position: "absolute",
    left: EXPANDED / 2 - w / 2 + x,
    top: 118 - w / 2 + y,
    width: w,
    height: w,
    borderRadius: "50%",
  });
  return (
    <div
      onClick={onTap}
      style={{
        position: "absolute",
        left,
        top: (240 - height) / 2,
        width,
        height,
        borderRadius: radius,
        boxShadow: `0 10px 24px ${alpha(colors[0], 0.35 * weight)}`,
        cursor: "pointer",
      }}
    >
      <div style={{ position: "absolute", inset: 0, borderRadius: radius, overflow: "hidden" }}>
        {/* A picture of fixed width: the strip is a window that opens onto it. */}
        <div style={{ position: "absolute", left: (width - EXPANDED) / 2, top: (height - 236) / 2, width: EXPANDED, height: 236, background: ScrollKit.gradient(index) }}>
          <div style={{ ...blob(150, 40, -70), background: white(0.22), filter: "blur(26px)" }} />
          <div style={{ ...blob(130, -50, 40), boxShadow: `inset 0 0 0 14px ${white(0.15)}` }} />
          <div
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              transform: `translate(-50%, -50%) translateY(${lerp(-72, -34, weight)}px)`,
              color: "#fff",
              filter: `drop-shadow(0 4px 8px ${black(0.18)})`,
            }}
          >
            <Sym name={ScrollKit.symbol(index)} size={lerp(20, 58, weight)} weight={600} />
          </div>
          <div style={{ position: "absolute", inset: 0, background: `linear-gradient(transparent 50%, ${black(0.3)})` }} />
          {/* Latin titles are rotated a quarter turn; Chinese ones are set upright, one character per line. */}
          <div
            style={{
              position: "absolute",
              left: "50%",
              top: "50%",
              transform: lang === "zh" ? "translate(-50%, -50%) translateY(24px)" : "translate(-50%, -50%) translateY(24px) rotate(-90deg)",
              color: "#fff",
              fontSize: 14,
              fontWeight: 700,
              opacity: label,
              ...(lang === "zh" ? { width: 16, lineHeight: "20px", textAlign: "center", wordBreak: "break-all" } : { whiteSpace: "nowrap", letterSpacing: 0.6 }),
            }}
          >
            {title}
          </div>
          <div
            style={{
              position: "absolute",
              left: 0,
              right: 0,
              bottom: 0,
              padding: 14,
              display: "flex",
              alignItems: "flex-end",
              gap: 8,
              color: "#fff",
              opacity: caption,
              transform: `translateY(${10 * (1 - caption)}px)`,
            }}
          >
            <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
              <div style={{ fontSize: 20, lineHeight: "24px", fontWeight: 700, whiteSpace: "nowrap" }}>{title}</div>
              <div style={{ fontSize: lang === "zh" ? 12 : 10.5, lineHeight: "16px", fontWeight: 500, opacity: 0.85, whiteSpace: "nowrap" }}>{ScrollKit.subtitle(index, lang)}</div>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ width: 30, height: 30, borderRadius: 15, background: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>
              <Ico icon={ArrowUpRight} size={13} weight={700} color={colors[0]} />
            </div>
          </div>
        </div>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${white(0.18)}`, pointerEvents: "none" }} />
    </div>
  );
}
