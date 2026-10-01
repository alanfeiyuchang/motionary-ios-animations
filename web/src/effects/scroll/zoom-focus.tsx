/** scroll.zoom-focus · 对焦放大选择行 (Scroll+ZoomFocus.swift) */
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, ease, mix, spring, springAt, useAutoplay, useElapsed, white, type DemoProps } from "../../kit";
import { FadeText, ScrollKit, SnapMarkers, Sym, strideSnap, swiftBlur, useScroller, useSelectionTick } from "./_kit";
import { ScrollMath } from "./_motion";

const INITIAL = 4;
const COUNT = 12;
const SIDE = 72;
const PITCH = 90;
const WIDTH = 340;
const HEIGHT = 186;

export default function ZoomFocus({ ctx }: DemoProps) {
  const [current, setCurrent] = useState(INITIAL);
  const direction = useRef(1);
  /** True while autoplay scrolls the row, so scripted ticks stay silent. */
  const scripted = useRef(false);
  const sc = useScroller({
    axis: "x",
    initial: INITIAL * PITCH,
    snap: strideSnap(PITCH),
    onScroll: (o) => setCurrent(clamp(Math.round(o / PITCH), 0, COUNT - 1)),
    onPhase: (p) => {
      if (p === "interacting") scripted.current = false;
    },
  });
  useSelectionTick(current, ctx.isPreview, scripted);

  const select = (i: number) => {
    scripted.current = false;
    sc.scrollTo(i * PITCH, spring(0.5, 0.84));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const jump = 2;
      scripted.current = true;
      if (current + direction.current * jump >= COUNT || current + direction.current * jump < 0) direction.current = -direction.current;
      sc.scrollTo((current + direction.current * jump) * PITCH, spring(0.6, 0.86));
    },
    { every: 1.3 },
  );

  const peak = ctx.n("scale");
  const blur = ctx.n("blur");
  const dim = ctx.n("dim");
  const sigma = PITCH * 0.76;
  const pad = (WIDTH - SIDE) / 2;

  // The brackets pinch when a new tile lands: 1 → 1.12 in 0.09 s, then a bouncy spring back.
  const e = useElapsed(current, 0.54, true);
  const pinch = e < 0 ? 1 : e < 0.09 ? mix(1, 1.12, ease.inOut(e / 0.09)) : 1.12 - 0.12 * springAt(e - 0.09, 0.5, 0.7);
  const bracket = SIDE * peak + 16;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 4 }}>
      <div style={{ position: "relative", width: WIDTH, height: HEIGHT, flexShrink: 0 }}>
        <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
          <div ref={sc.contentRef} style={{ position: "relative", width: pad * 2 + (COUNT - 1) * PITCH + SIDE, height: HEIGHT }}>
            <SnapMarkers count={COUNT} pitch={PITCH} />
            {Array.from({ length: COUNT }, (_, i) => {
              const d = i * PITCH - sc.offset;
              const lens = ScrollMath.fisheye(d, sigma, peak, 0.86);
              const away = 1 - lens.weight;
              const colors = ScrollKit.colors(i);
              const radius = SIDE * 0.28;
              return (
                <div
                  key={i}
                  onClick={() => select(i)}
                  style={{
                    position: "absolute",
                    left: pad + i * PITCH,
                    top: (HEIGHT - SIDE) / 2,
                    width: SIDE,
                    height: SIDE,
                    borderRadius: radius,
                    background: `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`,
                    boxShadow: `0 5px 13px ${alpha(colors[0], 0.35)}`,
                    display: "grid",
                    placeItems: "center",
                    color: "#fff",
                    cursor: "pointer",
                    transform: `translateX(${lens.position - d}px) scale(${lens.scale})`,
                    filter: [swiftBlur(blur * away), `saturate(${1 - 0.55 * away})`].filter(Boolean).join(" "),
                    opacity: 1 - dim * away,
                  }}
                >
                  <Sym name={ScrollKit.symbol(i)} size={SIDE * 0.4} weight={600} style={{ filter: `drop-shadow(0 2px 4px ${black(0.18)})` }} />
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      borderRadius: radius,
                      background: `linear-gradient(${white(0.32)}, transparent 50%)`,
                      mixBlendMode: "plus-lighter",
                      pointerEvents: "none",
                    }}
                  />
                  <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 0.75px ${white(0.25)}`, pointerEvents: "none" }} />
                </div>
              );
            })}
          </div>
        </div>
        <Brackets side={bracket} scale={pinch} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
        <FadeText text={ScrollKit.title(current, ctx.lang)} duration={0.28} style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }} />
        <FadeText
          text={ScrollKit.subtitle(current, ctx.lang)}
          duration={0.28}
          style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}
        />
      </div>
      <DemoHint ctx={ctx} en="Swipe the row · tap a tile" zh="滑动这一排 · 点击图块" style={{ marginTop: 10 }} />
    </div>
  );
}

/** Four camera-style corner brackets around the focused tile. */
function Brackets({ side, scale }: { side: number; scale: number }) {
  const arm = 13;
  const r = Math.min(side * 0.26, side / 2);
  const corners: [number, number, number, number][] = [
    [0, 0, 1, 1],
    [side, 0, -1, 1],
    [side, side, -1, -1],
    [0, side, 1, -1],
  ];
  const d = corners
    .map(([x, y, sx, sy]) => `M${x} ${y + sy * (r + arm)} L${x} ${y + sy * r} Q${x} ${y} ${x + sx * r} ${y} L${x + sx * (r + arm)} ${y}`)
    .join(" ");
  return (
    <svg
      width={side}
      height={side}
      style={{ position: "absolute", left: (WIDTH - side) / 2, top: (HEIGHT - side) / 2, overflow: "visible", pointerEvents: "none", transform: `scale(${scale})` }}
    >
      <path d={d} fill="none" stroke={Palette.labelAlpha(0.55)} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
