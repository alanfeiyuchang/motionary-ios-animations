/** scroll.pinned-zoom · 固定头图放大 (Scroll+PinnedZoom.swift) */
import { useRef } from "react";
import { Palette, anim, black, clamp, hex, useAutoplay, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKitRow, Sym, useScroller } from "./_kit";
import { ScrollMath, useTopPull } from "./_motion";

const INSET = 16;
const TOP = 14;
const HEIGHT = 224;
const { lerp, unit, smooth } = ScrollMath;

export default function PinnedZoom({ ctx }: DemoProps) {
  const range = Math.max(ctx.n("range"), 1);
  const down = useRef(false);
  const sc = useScroller({ axis: "y", bounce: false });
  const top = useTopPull({ enabled: () => !ctx.isPreview && sc.get() <= 0.5 });
  const offset = sc.offset;

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? range + 8 : 0, anim.smoothD(1.9));
    },
    { every: 2.6 },
  );

  return (
    <div {...top.props} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <Hero
        progress={clamp(offset / range, 0, 1)}
        beyond={Math.max(offset - range, 0)}
        pull={Math.max(-offset, 0) + top.pull}
        zoom={ctx.n("zoom")}
        radius={ctx.n("radius")}
        lang={ctx.lang}
      />
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef}>
          <div style={{ height: TOP + HEIGHT + 14 + top.pull * 0.5 }} />
          <div
            style={{
              padding: "10px 16px 24px",
              display: "flex",
              flexDirection: "column",
              gap: 10,
              background: Palette.surface,
              borderRadius: "24px 24px 0 0",
              boxShadow: `0 -6px 27px ${black(0.22)}`,
            }}
          >
            <div style={{ alignSelf: "center", width: 36, height: 5, borderRadius: 2.5, background: Palette.labelAlpha(0.15), flexShrink: 0 }} />
            <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700, paddingTop: 2 }}>{ctx.t("Itinerary", "行程")}</div>
            {Array.from({ length: 10 }, (_, i) => (
              <ScrollKitRow key={i} index={i + 6} lang={ctx.lang} style={{ flexShrink: 0 }} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Hero({ progress, beyond, pull, zoom, radius, lang }: { progress: number; beyond: number; pull: number; zoom: number; radius: number; lang: Lang }) {
  const zh = lang === "zh";
  /** 0 = inset rounded card, 1 = full bleed. */
  const p = smooth(progress);
  const inset = lerp(INSET, 0, p);
  const top = lerp(TOP, 0, p);
  const height = HEIGHT + (TOP - top) + 14 * p;
  const r = lerp(radius, 0, p);
  const first = 1 - unit(p, 0, 0.5);
  const second = unit(p, 0.5, 1);
  const width = 340 - inset * 2;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, right: 0, height: top + height, transform: `scale(${1 + Math.min(pull / 100, 1) * 0.08})`, transformOrigin: "50% 0" }}>
      <div
        style={{
          position: "absolute",
          left: inset,
          top,
          width,
          height,
          borderRadius: r,
          overflow: "hidden",
          boxShadow: `0 10px 24px ${black(0.2 * (1 - p))}`,
        }}
      >
        <div style={{ position: "absolute", inset: 0, transform: `translateY(${-Math.min(beyond * 0.25, 40)}px)` }}>
          <Scene progress={p} zoom={zoom} width={width} height={height} />
        </div>
        <div style={{ position: "absolute", inset: 0, background: black(0.3 * unit(beyond, 0, 120)) }} />
        <div style={{ position: "absolute", left: 18, top: 18, color: "#fff", filter: `drop-shadow(0 3px 8px ${black(0.28)})` }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 3, opacity: first, transform: `translateY(${-10 * (1 - first)}px)` }}>
            <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 800, letterSpacing: 1.2, opacity: 0.85, whiteSpace: "nowrap" }}>{zh ? "第一章" : "CHAPTER 01"}</div>
            <div style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700, whiteSpace: "nowrap" }}>{zh ? "山脊上的黄昏" : "Dusk over the ridge"}</div>
          </div>
          <div
            style={{ position: "absolute", left: 0, top: 0, display: "flex", flexDirection: "column", gap: 3, opacity: second, transform: `translateY(${10 * (1 - second)}px)` }}
          >
            <div style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700, whiteSpace: "nowrap" }}>{zh ? "休西高原" : "Alpe di Siusi"}</div>
            <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, lineHeight: "16px", fontWeight: 600, opacity: 0.9, whiteSpace: "nowrap" }}>
              <Sym name="mountain.2.fill" size={12} weight={600} />
              {zh ? "海拔 2100 米 · 19:42" : "2,100 m · 19:42"}
            </div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: r, boxShadow: `inset 0 0 0 1px ${white(0.14 * (1 - p))}` }} />
      </div>
    </div>
  );
}

/** A rolling ridge line: the area below a sum of two sines (in a 100 × 100 box). */
function ridge(base: number, amplitude: number, frequency: number, phase: number) {
  const steps = 48;
  let d = "M0 100";
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const wave = Math.sin(t * frequency * 2 * Math.PI + phase) + 0.45 * Math.sin(t * frequency * 5.3 * Math.PI + phase * 2.1);
    d += ` L${(100 * t).toFixed(3)} ${(100 * (base - amplitude * wave)).toFixed(3)}`;
  }
  return d + " L100 100 Z";
}
const FAR = ridge(0.56, 0.11, 2.1, 0.6);
const NEAR = ridge(0.72, 0.13, 1.4, 2.4);

/** A dusk landscape in four layers that zoom at different rates (sky, sun, far ridge, near ridge). */
function Scene({ progress, zoom, width, height }: { progress: number; zoom: number; width: number; height: number }) {
  const depth = Math.max(zoom - 1, 0) * progress;
  const layer = (scale: number): React.CSSProperties => ({ position: "absolute", inset: 0, transform: `scale(${scale})`, transformOrigin: "50% 100%" });
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", inset: 0, background: "linear-gradient(#2B2A7A, #8B4BB0, #FF7A6B, #FFC56B)", transform: `scale(${1 + depth * 0.2})` }} />
      <div
        style={{
          position: "absolute",
          left: width / 2 - 28,
          top: height / 2 - 28,
          width: 56,
          height: 56,
          transform: `scale(${1 + depth * 0.625}) translate(54px, 4px)`,
          transformOrigin: "50% 100%",
          borderRadius: "50%",
          background: "radial-gradient(circle, #FFF3C4 2px, #FFB45E 30px)",
          boxShadow: `0 0 39px ${hex(0xffc56b, 0.9)}`,
        }}
      />
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" width={width} height={height} style={layer(1 + depth * 0.375)}>
        <defs>
          <linearGradient id="pz-far" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="100">
            <stop offset="0" stopColor="#6C3F9E" />
            <stop offset="1" stopColor="#3B2A6E" />
          </linearGradient>
          <linearGradient id="pz-near" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="100">
            <stop offset="0" stopColor="#2A1E52" />
            <stop offset="1" stopColor="#15102B" />
          </linearGradient>
        </defs>
        <path d={FAR} fill="url(#pz-far)" />
      </svg>
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" width={width} height={height} style={layer(1 + depth)}>
        <path d={NEAR} fill="url(#pz-near)" />
      </svg>
    </div>
  );
}
