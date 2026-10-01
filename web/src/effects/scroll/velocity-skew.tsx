/** scroll.velocity-skew · 速度倾斜卡片带 (Scroll+VelocitySkew.swift) */
import { Wind } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, spring, useAutoplay, white, type DemoProps } from "../../kit";
import { ScrollKit, ScrollVelocityTracker, Sym, useScroller } from "./_kit";
import { Ico, useSpringValue } from "./_motion";

const TOP_SPEED = 1800;
const CARD = { width: 150, height: 200 };
const TARGETS = [620, 240, 1180, 760, 1400, 0];
/** Extra room above and below the strip so sheared cards and shadows are not clipped (`scrollClipDisabled`). */
const BLEED = 30;

export default function VelocitySkew({ ctx }: DemoProps) {
  /** Scroll velocity in pt/s (positive while the content moves left). */
  const [velocity, setVelocity] = useState(0);
  const tracker = useRef(new ScrollVelocityTracker());
  const settleTimer = useRef(0);
  const step = useRef(0);
  // `.animation(spring, value: velocity)`: what the cards show follows the speed through a spring.
  const speedS = useSpringValue(0);
  const absS = useSpringValue(0);
  const gauge = useSpringValue(0);
  const damping = ctx.n("damping");

  const apply = (v: number) => {
    setVelocity(v);
    const speed = clamp(v / TOP_SPEED, -1, 1);
    const t = spring(0.32, damping);
    speedS.to(speed, t);
    absS.to(Math.abs(speed), t);
    gauge.to(speed, spring(0.3, 0.8));
  };
  const settle = () => {
    window.clearTimeout(settleTimer.current);
    tracker.current.reset();
    apply(0);
  };
  const sc = useScroller({
    axis: "x",
    onScroll: (o) => {
      apply(tracker.current.sample(o, 3000));
      // Geometry only changes while the content moves, so 70 ms of silence means "stopped".
      window.clearTimeout(settleTimer.current);
      settleTimer.current = window.setTimeout(settle, 70);
    },
    onPhase: (p) => {
      if (p === "idle") settle();
    },
  });
  useEffect(() => () => window.clearTimeout(settleTimer.current), []);

  useAutoplay(
    ctx.isPreview,
    () => {
      const target = TARGETS[step.current % TARGETS.length];
      step.current += 1;
      sc.scrollTo(target, spring(0.75, 0.92));
    },
    { every: 1.5 },
  );

  const speed = speedS.value;
  const shear = Math.tan((ctx.n("angle") * Math.PI) / 180) * speed;
  const stretch = ctx.n("stretch") * absS.value;
  const g = gauge.value;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div {...sc.props} style={{ ...sc.props.style, width: 340, height: CARD.height + 36 + BLEED * 2, margin: `${-BLEED}px 0`, flexShrink: 0 }}>
        <div ref={sc.contentRef} style={{ display: "flex", gap: 14, padding: `${18 + BLEED}px 28px`, width: "max-content" }}>
          {Array.from({ length: 12 }, (_, i) => (
            <div
              key={i}
              style={{
                position: "relative",
                width: CARD.width,
                height: CARD.height,
                flexShrink: 0,
                borderRadius: 22,
                transform: `scale(${1 + stretch}, ${1 - stretch * 0.35}) matrix(1, 0, ${-shear}, 1, 0, 0)`,
                boxShadow: `${-speed * 10}px 10px 21px ${alpha(ScrollKit.colors(i)[0], 0.3)}`,
              }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: 22, overflow: "hidden", background: ScrollKit.gradient(i) }}>
                {/* The glyph and its glow drift against the motion. */}
                <div style={{ position: "absolute", inset: 0, transform: `translateX(${-speed * 10}px)` }}>
                  <div
                    style={{
                      position: "absolute",
                      left: CARD.width / 2 - 65 + 34,
                      top: CARD.height / 2 - 65 - 50,
                      width: 130,
                      height: 130,
                      borderRadius: "50%",
                      background: white(0.22),
                      filter: "blur(22px)",
                    }}
                  />
                  <div
                    style={{
                      position: "absolute",
                      left: "50%",
                      top: "50%",
                      transform: "translate(-50%, -50%) translateY(-22px)",
                      color: "#fff",
                      filter: `drop-shadow(0 4px 8px ${black(0.18)})`,
                    }}
                  >
                    <Sym name={ScrollKit.symbol(i)} size={46} weight={600} />
                  </div>
                </div>
                {/* The caption lags behind the card. */}
                <div
                  style={{
                    position: "absolute",
                    left: 0,
                    bottom: 0,
                    padding: 14,
                    display: "flex",
                    flexDirection: "column",
                    gap: 2,
                    color: "#fff",
                    transform: `translateX(${speed * 8}px)`,
                  }}
                >
                  <div style={{ fontSize: 17, lineHeight: "22px", fontWeight: 700, whiteSpace: "nowrap" }}>{ScrollKit.title(i, ctx.lang)}</div>
                  <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, opacity: 0.85, whiteSpace: "nowrap" }}>{ScrollKit.subtitle(i, ctx.lang)}</div>
                </div>
              </div>
              <div style={{ position: "absolute", inset: 0, borderRadius: 22, boxShadow: `inset 0 0 0 1px ${white(0.22)}` }} />
            </div>
          ))}
        </div>
      </div>
      {/* Live speed readout: a centre-zero bar and the velocity in pt/s. */}
      <div style={{ display: "flex", alignItems: "center", gap: 10, flexShrink: 0 }}>
        <Ico icon={Wind} size={12} weight={700} color={Palette.secondaryLabel} />
        <div style={{ position: "relative", width: 120, height: 5, borderRadius: 2.5, background: Palette.labelAlpha(0.08) }}>
          <div
            style={{
              position: "absolute",
              top: 0,
              height: 5,
              borderRadius: 2.5,
              width: Math.max(Math.abs(g) * 60, 4),
              left: 60 - Math.max(Math.abs(g) * 60, 4) / 2 + g * 30,
              background: `linear-gradient(90deg, ${Palette.mint}, ${Palette.sky}, ${Palette.violet})`,
            }}
          />
        </div>
        <div style={{ width: 76, fontSize: 12, lineHeight: "16px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel }}>
          {Math.round(Math.abs(velocity) / 10) * 10} pt/s
        </div>
      </div>
      <DemoHint ctx={ctx} en="Flick the strip" zh="用力甩动卡片带" />
    </div>
  );
}
