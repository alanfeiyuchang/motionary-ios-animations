/** scroll.fold-edge · 边缘风琴折叠 (Scroll+FoldEdge.swift) */
import { ChevronRight } from "lucide-react";
import { useRef } from "react";
import { Palette, anim, clamp, useAutoplay, type DemoProps } from "../../kit";
import { ScrollKit, ScrollKitIcon, brightness, perspectivePx, useScroller } from "./_kit";
import { Ico } from "./_motion";

const ROW = 50;
const COUNT = 26;

/** The accordion's geometry: where a point of the flat strip lands once the edge zones are pleated. */
function foldCurve(viewport: number, zone: number, maxAngle: number) {
  /** Compressed position of a point `y` measured from an edge (the integral of cos θ over the zone). */
  const fromEdge = (y: number) => {
    if (y >= zone) return y;
    const u = (zone - y) / zone;
    const k = zone / maxAngle;
    if (u <= 1) return zone - k * Math.sin(maxAngle * u);
    // Beyond the edge the strip stays folded at the maximum angle.
    return zone - k * Math.sin(maxAngle) - (u - 1) * zone * Math.cos(maxAngle);
  };
  return (y: number) => (y < viewport / 2 ? fromEdge(y) : viewport - fromEdge(viewport - y));
}

export default function FoldEdge({ ctx }: DemoProps) {
  const down = useRef(false);
  const sc = useScroller({ axis: "y" });
  const viewport = Math.max(sc.size.height || (ctx.isPreview ? 340 : 400), 1);
  const map = foldCurve(viewport, Math.min(ctx.n("zone"), viewport / 2), Math.max((ctx.n("angle") * Math.PI) / 180, 0.01));
  const shade = ctx.n("shade");

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 620 : 0, anim.smoothD(2.3));
    },
    { every: 2.8 },
  );

  const persp = perspectivePx(340 - 44, ROW, 0.3);

  return (
    <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
      <div ref={sc.contentRef} style={{ padding: "10px 22px" }}>
        {Array.from({ length: COUNT }, (_, i) => {
          const hingesOnTop = i % 2 === 0;
          const minY = 10 + i * ROW - sc.offset;
          const top = map(minY);
          const bottom = map(minY + ROW);
          const ratio = clamp((bottom - top) / ROW, 0, 1);
          const angle = Math.acos(ratio);
          const tilt = Math.sin(angle);
          // Top-hinged rows tip their lower edge back and face the floor: darker.
          const light = hingesOnTop ? -0.2 * tilt * shade : 0.05 * tilt * shade;
          const dy = hingesOnTop ? top - minY : bottom - (minY + ROW);
          return (
            <div
              key={i}
              style={{
                position: "relative",
                height: ROW,
                padding: "0 14px",
                display: "flex",
                alignItems: "center",
                gap: 12,
                background: Palette.elevated,
                boxShadow: `inset 0 0 0 0.5px ${Palette.labelAlpha(0.05)}`,
                transformOrigin: hingesOnTop ? "50% 0" : "50% 100%",
                transform: `translateY(${dy}px) perspective(${persp}px) rotateX(${hingesOnTop ? -angle : angle}rad)`,
                filter: Math.abs(light) > 0.001 ? swiftBrightness(light) : undefined,
              }}
            >
              <ScrollKitIcon index={i} size={32} />
              <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ScrollKit.title(i, ctx.lang)}</div>
              <div style={{ flex: 1 }} />
              <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>{ScrollKit.time(i)}</div>
              <Ico icon={ChevronRight} size={11} weight={700} color={Palette.tertiaryLabel} />
              {/* The crease between two panels of the strip. */}
              <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 0.5, background: Palette.labelAlpha(i === COUNT - 1 ? 0 : 0.1) }} />
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** Additive `.brightness(x)`: lighten or darken toward white / black. */
function swiftBrightness(x: number) {
  return brightness(x);
}
