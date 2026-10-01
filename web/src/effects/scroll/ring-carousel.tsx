/** scroll.ring-carousel · 3D 环形轮播 (Scroll+RingCarousel.swift) */
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, black, clamp, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { FadeText, ScrollKit, ScrollKitArt, brightness, perspectivePx, swiftBlur, wrap } from "./_kit";
import { useDrag, useSpringValue } from "./_motion";

const CARD = { width: 96, height: 130 };
const FOCAL = 520;
const MOVES = [1, 1, 3, -2, 1, -4];

/** Perspective scale of a point at `depth` (R at the front, −R at the back) on a ring of `radius`. */
const ringScale = (depth: number, radius: number) => FOCAL / (FOCAL + radius - depth);

export default function RingCarousel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const count = Math.max(ctx.i("count"), 3);
  const radius = ctx.n("radius");
  const tilt = (ctx.n("tilt") * Math.PI) / 180;
  const arc = Math.max((radius * 2 * Math.PI) / count, 1);
  /** Ring rotation in card units: card `i` faces the viewer when `rotation == i`. */
  const rotation = useSpringValue(0);
  const dragStart = useRef<number | null>(null);
  const [front, setFront] = useState(0);
  const frontRef = useRef(0);
  const step = useRef(0);

  const spin = (target: number) => {
    const landing = Math.trunc(target);
    if (landing !== frontRef.current) haptics.tap("soft");
    frontRef.current = landing;
    setFront(landing);
    // `withAnimation` from a finger-held (non-animated) value starts at rest.
    rotation.to(rotation.get(), null);
    rotation.to(target, spring(0.7, 0.78));
  };
  const bring = (i: number) => {
    const current = Math.round(rotation.get());
    let delta = i - (current % count);
    const half = count / 2;
    while (delta > half) delta -= count;
    while (delta < -half) delta += count;
    spin(current + delta);
  };
  const drag = useDrag(
    {
      onChange: (s) => {
        const start = dragStart.current ?? rotation.get();
        dragStart.current = start;
        const r = start - s.translation.x / arc;
        rotation.to(r, null);
        const nearest = Math.round(r);
        if (nearest !== frontRef.current) {
          frontRef.current = nearest;
          setFront(nearest);
          haptics.selection();
        }
      },
      onEnd: (s) => {
        const start = dragStart.current ?? rotation.get();
        dragStart.current = null;
        const projected = start - s.predicted.x / arc;
        const now = rotation.get();
        spin(Math.round(clamp(projected, now - count, now + count)));
      },
    },
    { minimumDistance: 8, touchAction: "pan-y" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      spin(Math.round(rotation.target()) + MOVES[step.current % MOVES.length]);
      step.current += 1;
    },
    { every: 1.7 },
  );

  const index = wrap(front, count);
  const r = rotation.value;

  // The elliptical track, traced through the bottom edges of the front and back cards.
  const half = CARD.height / 2;
  const lift = radius * Math.sin(tilt);
  const frontBottom = (lift + half) * ringScale(radius, radius);
  const backBottom = (-lift + half) * ringScale(-radius, radius);
  const floorW = 2 * radius * ringScale(0, radius);
  const floorH = Math.max(frontBottom - backBottom, 2);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6 }}>
      <div {...drag} style={{ ...drag.style, position: "relative", width: 340, height: 236, flexShrink: 0 }}>
        <svg
          width={floorW}
          height={floorH}
          style={{ position: "absolute", left: 170 - floorW / 2, top: 118 + (frontBottom + backBottom) / 2 - floorH / 2, overflow: "visible", zIndex: 0 }}
        >
          <defs>
            <linearGradient id="ring-floor" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor={Palette.labelAlpha(0.05)} />
              <stop offset="1" stopColor={Palette.labelAlpha(0.22)} />
            </linearGradient>
          </defs>
          <ellipse cx={floorW / 2} cy={floorH / 2} rx={floorW / 2 - 0.75} ry={Math.max(floorH / 2 - 0.75, 0.1)} fill="none" stroke="url(#ring-floor)" strokeWidth={1.5} />
        </svg>
        {Array.from({ length: count }, (_, i) => {
          const theta = ((i - r) / count) * 2 * Math.PI;
          const depth = radius * Math.cos(theta);
          const scale = ringScale(depth, radius);
          const x = radius * Math.sin(theta) * scale;
          // Seen from above, the far side of the ring sits higher on screen.
          const y = depth * Math.sin(tilt) * scale;
          const far = (1 - Math.cos(theta)) / 2;
          return (
            <div
              key={i}
              onClick={() => bring(i)}
              style={{
                position: "absolute",
                left: 170 - CARD.width / 2,
                top: 118 - CARD.height / 2,
                width: CARD.width,
                height: CARD.height,
                zIndex: Math.round(depth * 10) + 3000,
                transform: `translate(${x}px, ${y}px) scale(${scale}) perspective(${perspectivePx(CARD.width, CARD.height, 0.45)}px) rotateY(${theta}rad)`,
                filter: [brightness(-0.3 * far), swiftBlur(2.5 * far)].filter(Boolean).join(" "),
                cursor: "pointer",
              }}
            >
              {/* Contact shadow on the floor; it turns with the card. */}
              <div
                style={{
                  position: "absolute",
                  left: CARD.width * 0.07,
                  bottom: -9,
                  width: CARD.width * 0.86,
                  height: 12,
                  borderRadius: "50%",
                  background: black(0.28),
                  filter: "blur(5px)",
                }}
              />
              <div style={{ position: "absolute", inset: 0, borderRadius: 16, overflow: "hidden" }}>
                <ScrollKitArt index={i} lang={ctx.lang} showsTitle={false} />
                <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${white(0.28)}, transparent 50%)`, mixBlendMode: "plus-lighter" }} />
                <div style={{ position: "absolute", inset: 0, borderRadius: 16, boxShadow: `inset 0 0 0 1px ${white(0.24)}` }} />
              </div>
            </div>
          );
        })}
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
        <FadeText text={ScrollKit.title(index, ctx.lang)} style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }} />
        <NumericText
          value={index}
          text={`${index + 1} / ${count}`}
          style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel }}
        />
      </div>
      <DemoHint ctx={ctx} en="Drag to spin · tap a card" zh="拖动旋转 · 点击卡片" style={{ marginTop: 6 }} />
    </div>
  );
}
