/** navigation.filmstrip-scrubber · 胶片缩略图翻页 (Navigation+FilmstripScrubber.swift) */
import { animate, useMotionValue } from "motion/react";
import { Flame, Flower2, Leaf, MoonStar, Mountain, Sailboat, Snowflake, TreePine } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { DemoHint, Palette, localPoint, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { useMotionNumber } from "./nav-util";
import { CloudSunFill, SunHorizonFill, diag, stageColumn, usePageDrag } from "./_r2";

type IconFn = (size: number) => ReactNode;
const filled = (Icon: typeof Flame, stroke = 1.6): IconFn => (s) => <Icon size={s} fill="currentColor" strokeWidth={stroke} />;
const PHOTOS: { icon: IconFn; colors: [string, string] }[] = [
  { icon: filled(Mountain, 2), colors: [Palette.sky, Palette.indigo] },
  { icon: (s) => <SunHorizonFill size={s} />, colors: [Palette.amber, Palette.coral] },
  { icon: filled(Leaf), colors: [Palette.mint, Palette.green] },
  { icon: filled(Sailboat, 2), colors: [Palette.sky, Palette.mint] },
  { icon: (s) => <Flower2 size={s} strokeWidth={2.2} />, colors: [Palette.pink, Palette.violet] },
  { icon: filled(MoonStar), colors: [Palette.indigo, "#241B5C"] },
  { icon: filled(Flame), colors: [Palette.coral, Palette.red] },
  { icon: (s) => <Snowflake size={s} strokeWidth={2.2} />, colors: ["#9AD8FF", Palette.blue] },
  { icon: filled(TreePine, 2), colors: [Palette.green, "#1F7A5A"] },
  { icon: (s) => <CloudSunFill size={s} />, colors: [Palette.amber, Palette.sky] },
];
const FRAME = { w: 290, h: 284 };
const PHOTO = { w: 262, h: 186 };
const THUMB = { w: 16, h: 34 };
const SPACING = 2;
const STRIP_H = 48;
const PITCH = THUMB.w + SPACING;
const LAST = PHOTOS.length - 1;
const nearness = (index: number, progress: number) => Math.max(0, 1 - Math.abs(index - progress));

/** Thumbnail rects for a fractional page, centred on the strip's middle. */
function rects(progress: number, expanded: number, gap: number) {
  const clamped = Math.min(Math.max(progress, 0), LAST);
  const result: { x: number; y: number; w: number; h: number }[] = [];
  let x = 0;
  PHOTOS.forEach((_, index) => {
    const near = nearness(index, clamped);
    const width = THUMB.w + (expanded - THUMB.w) * near;
    const margin = gap * near;
    x += margin;
    result.push({ x, y: (STRIP_H - THUMB.h) / 2, w: width, h: THUMB.h });
    x += width + margin + SPACING;
  });
  const lower = Math.floor(clamped);
  const upper = Math.min(lower + 1, LAST);
  const fraction = clamped - lower;
  const mid = (r: { x: number; w: number }) => r.x + r.w / 2;
  const centre = mid(result[lower]) * (1 - fraction) + mid(result[upper]) * fraction;
  const shift = FRAME.w / 2 - centre - (progress - clamped) * PITCH;
  return result.map((r) => ({ ...r, x: r.x + shift }));
}

export default function FilmstripScrubber({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const goal = useRef(0);
  const lastTick = useRef(0);
  const autoStep = useRef(0);
  const expanded = ctx.n("width");
  const gap = ctx.n("gap");

  const settle = (index: number) => {
    const clamped = Math.min(Math.max(index, 0), LAST);
    haptics.tap("light");
    goal.current = clamped;
    lastTick.current = clamped;
    animate(progressMV, clamped, spring(ctx.n("response"), ctx.n("damping")));
  };
  const onPage = (page: number) => {
    goal.current = page;
    const tick = Math.min(Math.max(Math.round(page), 0), LAST);
    if (tick !== lastTick.current) {
      lastTick.current = tick;
      haptics.selection();
    }
  };
  const photoDrag = usePageDrag(progressMV, { unit: PHOTO.w, last: LAST, bandLow: 0.6, limit: 1, onPage, settle });
  const stripDrag = usePageDrag(progressMV, { unit: PITCH, last: LAST, bandLow: 0.6, limit: LAST, minimumDistance: 6, onPage, settle });

  const stripTapped = (x: number) => {
    if (stripDrag.dragging()) return;
    const at = rects(Math.round(goal.current), expanded, gap);
    const index = at.findIndex((r) => x >= r.x - 1 && x <= r.x + r.w + 1);
    if (index >= 0) settle(index);
  };

  // Preview loop: single steps, then a long fling each way.
  useAutoplay(
    ctx.isPreview,
    () => {
      const tour = [1, 2, 3, 8, 9, 5, 0];
      settle(tour[autoStep.current % tour.length]);
      autoStep.current += 1;
    },
    { every: 1.3 },
  );

  const page = Math.min(Math.max(Math.round(progress), 0), LAST);
  const thumbs = rects(progress, expanded, gap);
  const maskImage = "linear-gradient(to right, transparent 0%, #000 14%, #000 86%, transparent 100%)";

  return (
    <div style={stageColumn(14)}>
      <div
        style={{
          position: "relative",
          width: FRAME.w,
          height: FRAME.h,
          flexShrink: 0,
          borderRadius: 32,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)`,
          overflow: "hidden",
        }}
      >
        {/* pager */}
        <div style={{ position: "absolute", left: 0, top: 14, width: FRAME.w, height: PHOTO.h }}>
          {PHOTOS.map((item, index) => {
            const distance = index - progress;
            if (Math.abs(distance) >= 1.4) return null;
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: (FRAME.w - PHOTO.w) / 2,
                  top: 0,
                  width: PHOTO.w,
                  height: PHOTO.h,
                  borderRadius: 22,
                  overflow: "hidden",
                  background: diag(...item.colors),
                  display: "grid",
                  placeItems: "center",
                  transform: `translateX(${distance * (PHOTO.w + 10)}px) scale(${1 - Math.min(Math.abs(distance), 1) * 0.06})`,
                }}
              >
                <div style={{ color: white(0.9), filter: "drop-shadow(0 4px 8px rgb(0 0 0 / 0.15))", transform: `translateX(${distance * 36}px)` }}>{item.icon(66)}</div>
              </div>
            );
          })}
          <div
            style={{
              position: "absolute",
              right: 24,
              top: 10,
              height: 22,
              padding: "0 9px",
              borderRadius: 11,
              background: "rgb(0 0 0 / 0.35)",
              color: "#fff",
              fontSize: 11,
              lineHeight: "22px",
              fontWeight: 700,
              fontVariantNumeric: "tabular-nums",
            }}
          >
            {page + 1} / {PHOTOS.length}
          </div>
        </div>
        {/* strip */}
        <div style={{ position: "absolute", left: 0, top: 14 + PHOTO.h + 10, width: FRAME.w, height: STRIP_H, maskImage, WebkitMaskImage: maskImage }}>
          {PHOTOS.map((item, index) => {
            const r = thumbs[index];
            const near = nearness(index, progress);
            return (
              <div
                key={index}
                style={{
                  position: "absolute",
                  left: r.x,
                  top: r.y - 3 * near,
                  width: r.w,
                  height: r.h + 6 * near,
                  borderRadius: 4 + 4 * near,
                  background: diag(...item.colors),
                  boxShadow: `0 3px 6px rgb(0 0 0 / ${0.18 * near})`,
                  display: "grid",
                  placeItems: "center",
                  overflow: "hidden",
                }}
              >
                <div style={{ color: white(0.9), opacity: near }}>{item.icon(18)}</div>
              </div>
            );
          })}
        </div>
        {/* gesture targets */}
        <div {...photoDrag.pan} style={{ position: "absolute", left: 0, top: 0, width: FRAME.w, height: PHOTO.h + 20, touchAction: "pan-y" }} />
        <div
          {...stripDrag.pan}
          onClick={(e) => stripTapped(localPoint(e, e.currentTarget).x)}
          style={{ position: "absolute", left: 0, bottom: 0, width: FRAME.w, height: STRIP_H + 20, cursor: "pointer", touchAction: "pan-y" }}
        />
      </div>
      <DemoHint ctx={ctx} en="Drag the filmstrip, or swipe the photo" zh="拖动胶片条，或滑动照片" />
    </div>
  );
}
