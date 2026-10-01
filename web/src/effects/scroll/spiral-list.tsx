/** scroll.spiral-list · 螺旋列表 (Scroll+SpiralList.swift) */
import { useEffect, useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, black, clamp, fonts, localPoint, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { FadeText, ScrollKit, SnapMarkers, Sym, strideSnap, useScroller } from "./_kit";
import { ScrollMath } from "./_motion";

const COUNT = 24;
/** Scroll distance per item. */
const PITCH = 64;
const RADIUS = 116;
const ITEM = 62;

/** Where an item sits for `u` = its index minus the scroll position (0 = in the focus ring). */
function placement(u: number, twist: number, shrink: number) {
  // Ahead of the focus the curve shrinks exponentially; behind it the item keeps going outward.
  const s = u >= 0 ? Math.exp(-shrink * u) : 1 + -u * 0.25;
  const angle = ((90 + u * twist) * Math.PI) / 180;
  const leaving = ScrollMath.unit(-u, 0.15, 1.2);
  const vanishing = ScrollMath.unit(s, 0.05, 0.16);
  return { x: RADIUS * s * Math.cos(angle), y: RADIUS * s * Math.sin(angle), scale: s, opacity: (1 - leaving) * vanishing };
}

export default function SpiralList({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected] = useState(0);
  const selectedRef = useRef(0);
  const userDriven = useRef(false);
  const direction = useRef(1);
  const twist = ctx.n("twist");
  const shrink = ctx.n("shrink");
  // An empty scroll view: it only supplies native scrolling, snapping and inertia.
  const sc = useScroller({
    axis: "y",
    snap: strideSnap(PITCH),
    onScroll: (o) => {
      const nearest = clamp(Math.round(o / PITCH), 0, COUNT - 1);
      if (nearest !== selectedRef.current) {
        selectedRef.current = nearest;
        setSelected(nearest);
      }
    },
    onPhase: (p) => {
      userDriven.current = p === "interacting" || p === "decelerating";
    },
  });
  const width = sc.size.width || 340;
  const height = sc.size.height || (ctx.isPreview ? 340 : 400);
  /** Centre of the spiral in the stage. */
  const centre = { x: width / 2, y: height / 2 - 6 };
  const p = sc.offset / PITCH;

  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    if (!ctx.isPreview && userDriven.current) haptics.selection();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selected]);

  const focus = (index: number, duration: number) => sc.scrollTo(clamp(index, 0, COUNT - 1) * PITCH, anim.easeInOut(duration));
  /** The front-most item under a tap, using the same placement as the drawing. */
  const itemAt = (point: { x: number; y: number }) => {
    const pos = sc.get() / PITCH;
    for (let i = Math.max(Math.floor(pos) - 1, 0); i < COUNT; i++) {
      const place = placement(i - pos, twist, shrink);
      if (place.opacity <= 0.3) continue;
      // A little slack so the small ones near the eye can still be hit.
      if (Math.hypot(point.x - (centre.x + place.x), point.y - (centre.y + place.y)) <= Math.max((ITEM * place.scale) / 2, 14)) return i;
    }
    return null;
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const stride = 3;
      const now = selectedRef.current;
      if (now + direction.current * stride > COUNT - 6 || now + direction.current * stride < 0) direction.current = -direction.current;
      focus(now + direction.current * stride, 1.1);
    },
    { every: 1.6 },
  );

  // Only the items that can be seen: one behind the focus and the tail until it is a speck.
  const firstVisible = Math.max(Math.floor(p) - 1, 0);
  const lastVisible = Math.min(firstVisible + Math.ceil(3 / Math.max(shrink, 0.01)) + 2, COUNT - 1);
  const visible: number[] = [];
  for (let i = firstVisible; i <= lastVisible; i++) visible.push(i);

  let curve = "";
  for (let u = -0.9; u <= 26; u += 0.08) {
    const place = placement(u, twist, shrink);
    curve += `${curve ? "L" : "M"}${place.x.toFixed(2)} ${place.y.toFixed(2)} `;
  }
  const ring = ITEM + 12;

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
        {ctx.b("guide") && (
          <svg width={1} height={1} style={{ position: "absolute", left: centre.x, top: centre.y, overflow: "visible", zIndex: 0 }}>
            <path d={curve} fill="none" stroke={Palette.labelAlpha(0.2)} strokeWidth={1.2} strokeLinecap="round" strokeDasharray="3 5" />
          </svg>
        )}
        {/* The focus slot. */}
        <div
          style={{
            position: "absolute",
            left: centre.x - ring / 2,
            top: centre.y + RADIUS - ring / 2,
            width: ring,
            height: ring,
            borderRadius: "50%",
            zIndex: 0,
            boxShadow: `0 0 12px ${alpha(Palette.indigo, 0.35)}, inset 0 0 10px ${alpha(Palette.indigo, 0.12)}`,
          }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: "50%",
              padding: 2,
              background: Palette.primary,
              WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
              WebkitMaskComposite: "xor",
              maskComposite: "exclude",
            }}
          />
        </div>
        {visible.map((i) => {
          const place = placement(i - p, twist, shrink);
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: centre.x - ITEM / 2,
                top: centre.y - ITEM / 2,
                width: ITEM,
                height: ITEM,
                borderRadius: "50%",
                background: ScrollKit.gradient(i),
                boxShadow: `inset 0 0 0 1.5px ${white(0.35)}, 0 4px 11px ${black(0.2)}`,
                display: "grid",
                placeItems: "center",
                color: "#fff",
                transform: `translate(${place.x}px, ${place.y}px) scale(${place.scale})`,
                opacity: place.opacity,
                zIndex: Math.round((p - i) * 10),
              }}
            >
              <Sym name={ScrollKit.symbol(i)} size={24} weight={600} />
            </div>
          );
        })}
        <div style={{ position: "absolute", left: 14, top: 14, display: "flex", flexDirection: "column", alignItems: "flex-start", zIndex: 400 }}>
          <NumericText
            value={selected}
            text={String(selected + 1).padStart(2, "0")}
            style={{ fontFamily: fonts.rounded, fontSize: 34, lineHeight: "40px", fontWeight: 800, color: "#8873FF" }}
          />
          <FadeText text={ScrollKit.title(selected, ctx.lang)} duration={0.25} style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, placeItems: "start" }} />
        </div>
      </div>
      <div
        {...sc.props}
        onClick={(e) => {
          const index = itemAt(localPoint(e, e.currentTarget));
          if (index !== null) focus(index, 0.6);
        }}
        style={{ ...sc.props.style, position: "absolute", inset: 0 }}
      >
        <div ref={sc.contentRef} style={{ position: "relative", height: (COUNT - 1) * PITCH + height }}>
          <SnapMarkers count={COUNT} pitch={PITCH} axis="y" />
        </div>
      </div>
    </div>
  );
}
