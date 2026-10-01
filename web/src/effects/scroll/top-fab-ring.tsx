/** scroll.top-fab-ring · 回到顶部进度环按钮 (Scroll+TopFabRing.swift) */
import { ArrowUp } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, black, clamp, ease, glass, mix, spring, springAt, useAutoplay, useElapsed, useHaptics, type DemoProps } from "../../kit";
import { ScrollKitArt, ScrollKitRow, useScroller } from "./_kit";
import { Ico } from "./_motion";

export default function TopFabRing({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [launches, setLaunches] = useState(0);
  const step = useRef(0);
  const sc = useScroller({ axis: "y" });
  const offset = sc.offset;
  const range = sc.max();
  const progress = range > 0 ? clamp(offset / range, 0, 1) : 0;
  const moving = sc.phase !== "idle";
  const visible = offset > ctx.n("threshold");

  /** Tap (and the autoplay's simulated tap): fire the arrow and glide the feed back to the top. */
  const launch = () => {
    haptics.tap("medium");
    setLaunches((n) => n + 1);
    // A timed curve (not a spring) so the glide ends exactly on schedule and the ring unwinds evenly.
    sc.scrollTo(0, anim.easeInOut(ctx.n("duration")));
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      switch (step.current % 4) {
        case 0:
          sc.scrollTo(420, anim.easeInOut(1.0));
          break;
        case 1:
          sc.scrollTo(980, anim.easeInOut(1.0));
          break;
        case 2:
          launch();
          break;
        default:
          break;
      }
      step.current += 1;
    },
    { every: 1.5 },
  );

  const percent = Math.round(progress * 100);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ padding: 16, display: "flex", flexDirection: "column", gap: 14 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 4 }}>
            <div style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700 }}>{ctx.t("Field Journal", "野外手记")}</div>
            <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>{ctx.t("12 entries this month", "本月 12 篇")}</div>
          </div>
          {Array.from({ length: 12 }, (_, i) =>
            i % 3 === 0 ? (
              <div key={i} style={{ position: "relative", height: 150, flexShrink: 0, borderRadius: 20, overflow: "hidden" }}>
                <ScrollKitArt index={i + 2} lang={ctx.lang} />
              </div>
            ) : (
              <ScrollKitRow key={i} index={i + 2} lang={ctx.lang} style={{ flexShrink: 0 }} />
            ),
          )}
        </div>
      </div>
      <div style={{ position: "absolute", right: 16, bottom: 16, display: "flex", alignItems: "center", gap: 8, pointerEvents: "none" }}>
        <AnimatePresence initial={false}>
          {visible && moving && (
            <motion.div
              key="chip"
              layout="position"
              initial={{ opacity: 0, x: 40, scale: 0.8 }}
              animate={{ opacity: 1, x: 0, scale: 1 }}
              exit={{ opacity: 0, x: 40, scale: 0.8 }}
              transition={spring(0.35, 0.8)}
              style={{
                height: 28,
                padding: "0 10px",
                borderRadius: 14,
                display: "flex",
                alignItems: "center",
                fontSize: 12,
                fontWeight: 700,
                transformOrigin: "100% 50%",
                ...glass("regular"),
                boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 11px ${black(0.1)}`,
              }}
            >
              <NumericText value={percent} text={`${percent}%`} />
            </motion.div>
          )}
          {visible && (
            <motion.div
              key="fab"
              initial={{ opacity: 0, scale: 0.4, y: 18 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.3 }}
              transition={spring(0.4, 0.6)}
              style={{ pointerEvents: "auto" }}
            >
              <Fab progress={progress} thickness={ctx.n("thickness")} launches={launches} action={launch} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

function Fab({ progress, thickness, launches, action }: { progress: number; thickness: number; launches: number; action: () => void }) {
  // Press dip: 1 → 0.86 in 0.1 s, then a bouncy spring back.
  const e = useElapsed(launches, 0.72, true);
  const press = e < 0 ? 1 : e < 0.1 ? mix(1, 0.86, ease.inOut(e / 0.1)) : 0.86 + 0.14 * springAt(e - 0.1, 0.5, 0.7);
  // Arrow hand-off: the old one shoots up, a fresh one rises from below.
  const arrowY = e < 0 ? 0 : e < 0.18 ? mix(0, -26, ease.inOut(e / 0.18)) : 26 - 26 * springAt(e - 0.18, 0.5, 0.7);
  const arrowOpacity = e < 0 ? 1 : e < 0.18 ? 1 - e / 0.18 : e < 0.22 ? 0 : Math.min((e - 0.22) / 0.2, 1);
  const p = Math.max(progress, 0.001);
  const ring = `radial-gradient(circle closest-side, transparent ${22 - thickness / 2 - 0.4}px, #000 ${22 - thickness / 2}px, #000 ${22 + thickness / 2}px, transparent ${22 + thickness / 2 + 0.4}px)`;
  const box = 44 + thickness + 2;
  const inset = (52 - box) / 2;
  return (
    <div
      onClick={action}
      style={{
        position: "relative",
        width: 52,
        height: 52,
        borderRadius: "50%",
        cursor: "pointer",
        transform: `scale(${press})`,
        ...glass("regular"),
        boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 6px 18px ${black(0.16)}`,
      }}
    >
      <div style={{ position: "absolute", left: inset, top: inset, width: box, height: box, borderRadius: "50%", background: Palette.labelAlpha(0.1), WebkitMaskImage: ring, maskImage: ring }} />
      <div
        style={{
          position: "absolute",
          left: inset,
          top: inset,
          width: box,
          height: box,
          borderRadius: "50%",
          background: `conic-gradient(${Palette.mint}, ${Palette.sky}, ${Palette.violet}, ${Palette.pink})`,
          WebkitMaskImage: `${ring}, conic-gradient(#000 ${p * 360}deg, transparent ${p * 360}deg)`,
          maskImage: `${ring}, conic-gradient(#000 ${p * 360}deg, transparent ${p * 360}deg)`,
          WebkitMaskComposite: "source-in",
          maskComposite: "intersect",
        }}
      />
      {/* Round cap at the start of the ring. */}
      <div style={{ position: "absolute", left: 26 - thickness / 2, top: 4 - thickness / 2, width: thickness, height: thickness, borderRadius: "50%", background: Palette.mint, opacity: progress > 0.004 ? 1 : 0 }} />
      {/* The glowing tip of the ring. */}
      <div style={{ position: "absolute", inset: 0, transform: `rotate(${360 * progress}deg)`, opacity: progress > 0.01 ? 1 : 0 }}>
        <div
          style={{
            position: "absolute",
            left: 26 - (thickness + 1.5) / 2,
            top: 4 - (thickness + 1.5) / 2,
            width: thickness + 1.5,
            height: thickness + 1.5,
            borderRadius: "50%",
            background: "#fff",
            boxShadow: `0 0 7px ${alpha(Palette.pink, 0.9)}`,
          }}
        />
      </div>
      <div style={{ position: "absolute", left: 11, top: 11, width: 30, height: 30, borderRadius: "50%", overflow: "hidden", display: "grid", placeItems: "center", color: "#8370FF" }}>
        <div style={{ transform: `translateY(${arrowY}px)`, opacity: arrowOpacity }}>
          <Ico icon={ArrowUp} size={17} weight={700} />
        </div>
      </div>
    </div>
  );
}
