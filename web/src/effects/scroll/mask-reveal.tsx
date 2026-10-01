/** scroll.mask-reveal · 遮罩揭示图片流 (Scroll+MaskReveal.swift) */
import { Heart } from "lucide-react";
import { useRef } from "react";
import { Palette, alpha, anim, black, clamp, useAutoplay, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKit, Sym, useScroller } from "./_kit";
import { Ico, ScrollMath } from "./_motion";

const CARD = 190;
const CAPTION = 38;
const PITCH = 240;
const TOP = 12;
const COUNT = 7;
const WIDTH = 340 - 28;
const { lerp, unit, smooth } = ScrollMath;

export default function MaskReveal({ ctx }: DemoProps) {
  const down = useRef(false);
  const sc = useScroller({ axis: "y" });
  const viewport = sc.size.height || (ctx.isPreview ? 340 : 400);
  const offset = sc.offset;

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? PITCH * 2.6 : 0, anim.easeInOut(2.5));
    },
    { every: 3.0 },
  );

  return (
    <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
      <div ref={sc.contentRef} style={{ padding: `${TOP}px 14px 0` }}>
        {Array.from({ length: COUNT }, (_, i) => {
          const top = TOP + i * PITCH - offset;
          // 0 closed … 1 fully open, from where the card sits in the viewport.
          const progress = smooth(unit(viewport - top, 20, CARD + 20));
          // −1 at the bottom of the viewport … +1 at the top: drives the inner drift.
          const drift = clamp(1 - (2 * (top + CARD / 2)) / Math.max(viewport, 1), -1.4, 1.4);
          return (
            <div key={i} style={{ height: PITCH }}>
              <Card index={i} progress={progress} drift={drift} style={ctx.i("shape")} parallax={ctx.n("parallax")} zoom={ctx.n("zoom")} lang={ctx.lang} />
            </div>
          );
        })}
      </div>
    </div>
  );
}

/** The opening mask as CSS: an outer rounded clip (the full 24 pt card) and an inner `clip-path`. */
function maskClip(p: number, style: number): { radius: number; clip?: string } {
  if (p >= 0.999) return { radius: 24 };
  if (style === 0) {
    // Iris: a circle growing from the centre until it covers the corners.
    return { radius: 24, clip: `circle(${(Math.hypot(WIDTH, CARD) / 2) * p}px at 50% 50%)` };
  }
  if (style === 2) {
    // Curtain: rises from the bottom with a bowed leading edge that flattens as it arrives.
    const top = CARD - (CARD + 30) * p;
    const bow = 46 * (1 - p);
    return { radius: 24, clip: `path("M0 ${CARD} L0 ${top + bow} Q${WIDTH / 2} ${top - bow} ${WIDTH} ${top + bow} L${WIDTH} ${CARD} Z")` };
  }
  // Inset: a rounded rectangle opening from 34% inset and 60 pt corners.
  const inset = 0.34 * (1 - p);
  const w = WIDTH * (1 - 2 * inset);
  const h = CARD * (1 - 2 * inset);
  const radius = Math.min(lerp(60, 24, p), Math.min(w, h) / 2);
  return { radius: 0, clip: `inset(${CARD * inset}px ${WIDTH * inset}px round ${radius}px)` };
}

function Card({ index, progress, drift, style, parallax, zoom, lang }: { index: number; progress: number; drift: number; style: number; parallax: number; zoom: number; lang: Lang }) {
  const caption = unit(progress, 0.6, 1);
  const colors = ScrollKit.colors(index + 1);
  const mask = maskClip(clamp(progress, 0, 1), style);
  const artH = CARD + parallax * 2;
  const centred = (w: number, x: number, y: number): React.CSSProperties => ({
    position: "absolute",
    left: WIDTH / 2 - w / 2 + x,
    top: artH / 2 - w / 2 + y,
    width: w,
    height: w,
    borderRadius: "50%",
  });
  return (
    <div>
      <div style={{ position: "relative", height: CARD }}>
        {/* The empty slot the picture opens into. */}
        <div style={{ position: "absolute", inset: 0, borderRadius: 24, background: Palette.labelAlpha(0.05), border: `1px dashed ${Palette.labelAlpha(0.08)}`, opacity: 1 - progress }} />
        <div style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 8px 14px ${alpha(colors[0], 0.28 * progress)})` }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: mask.radius, overflow: "hidden", clipPath: mask.clip }}>
            {/* The picture: larger than its window so it can drift. */}
            <div
              style={{
                position: "absolute",
                left: 0,
                top: -parallax,
                width: WIDTH,
                height: artH,
                background: `linear-gradient(135deg, ${colors[0]}, ${colors[1]})`,
                transform: `translateY(${-drift * parallax}px) scale(${lerp(zoom, 1, progress)})`,
                overflow: "hidden",
              }}
            >
              <div style={{ ...centred(200, 80, -70), background: white(0.26), filter: "blur(34px)" }} />
              <div style={{ ...centred(180, -90, 60), boxShadow: `inset 0 0 0 18px ${white(0.18)}` }} />
              <div style={{ ...centred(260, 120, 150), background: black(0.1) }} />
              <div
                style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%, -50%)", color: white(0.95), filter: `drop-shadow(0 8px 12px ${black(0.18)})` }}
              >
                <Sym name={ScrollKit.symbol(index + 1)} size={76} weight={600} />
              </div>
            </div>
          </div>
        </div>
      </div>
      <div style={{ height: CAPTION, padding: "0 6px", display: "flex", alignItems: "baseline", gap: 8, opacity: caption, transform: `translateY(${12 * (1 - caption)}px)`, whiteSpace: "nowrap" }}>
        <div style={{ alignSelf: "center", fontSize: 15, lineHeight: "20px", fontWeight: 700 }}>{ScrollKit.title(index + 1, lang)}</div>
        <div style={{ alignSelf: "center", fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{ScrollKit.subtitle(index + 1, lang)}</div>
        <div style={{ flex: 1 }} />
        <Ico icon={Heart} size={13} weight={600} color={Palette.secondaryLabel} style={{ alignSelf: "center" }} />
      </div>
    </div>
  );
}
