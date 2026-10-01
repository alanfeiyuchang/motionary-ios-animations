/** cards.bend-flex · 弯折回弹 (Cards+BendFlex.swift) */
import { animate, useMotionValue } from "motion/react";
import { Nfc, TramFront } from "lucide-react";
import { memo, useRef } from "react";
import { DemoHint, anim, black, clamp, fonts, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, useMV } from "./shared";
import { Projected, projection } from "./_kit";

const CARD = { w: 236, h: 148 };
const CANVAS = 290;
const STRIPS = 40;
const DEPTH = 520;
const STRIP_W = CANVAS / STRIPS;
const EYE = { x: CANVAS / 2, y: CANVAS / 2 };

export default function BendFlex({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const bx = useMotionValue(0);
  const by = useMotionValue(0);
  const held = useRef(false);
  const autoStep = useRef(0);
  const script = useTimeouts();

  const twang = () => {
    const t = spring(ctx.n("response"), ctx.n("damping"));
    animate(bx, 0, t);
    animate(by, 0, t);
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (!held.current) {
        held.current = true;
        script.clearAll();
        haptics.tap("soft");
      }
      // Past 120 pt the plastic resists like a rubber band.
      const length = Math.hypot(translation.x, translation.y);
      const scale = length > 120 ? (120 + rubberBand(length - 120, 46)) / length : 1;
      const t = spring(0.16, 0.86);
      animate(bx, translation.x * scale, t);
      animate(by, translation.y * scale, t);
    },
    onEnd: () => {
      if (!held.current) return;
      held.current = false;
      haptics.tap("rigid");
      twang();
    },
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current) return;
      const targets = [
        [118, -20],
        [-70, -92],
        [-112, 36],
        [60, 100],
      ];
      const target = targets[autoStep.current % targets.length];
      autoStep.current += 1;
      animate(bx, target[0], anim.easeInOut(0.75));
      animate(by, target[1], anim.easeInOut(0.75));
      script.clearAll();
      script.after(1.05, twang);
    },
    { every: 2.5 },
  );

  const bw = useMV(bx);
  const bh = useMV(by);
  const maxAngle = ctx.n("angle");
  const gloss = ctx.n("gloss");
  const length = Math.hypot(bw, bh);
  const phi = length < 0.01 ? 0 : Math.atan2(bh, bw);
  const lift = Math.min(length / 120, 1.3);

  // Integrates the curl across the strips: the angle grows with the square of the distance from the pinned edge.
  const reach = Math.max((CARD.w / 2) * Math.abs(Math.cos(phi)) + (CARD.h / 2) * Math.abs(Math.sin(phi)), 1);
  const peak = (Math.min(length / 120, 1.35) * maxAngle * Math.PI) / 180;
  const raw: { start: number; x: number; z: number; angle: number }[] = [];
  let x = -CANVAS / 2;
  let z = 0;
  let centre = 0;
  for (let index = 0; index < STRIPS; index++) {
    const start = -CANVAS / 2 + index * STRIP_W;
    const mid = start + STRIP_W / 2;
    const along = clamp((mid + reach) / (2 * reach));
    const angle = Math.min(peak * along * along, 1.5);
    raw.push({ start, x, z, angle });
    if (start <= 0 && start + STRIP_W > 0) centre = x + (0 - start) * Math.cos(angle);
    x += STRIP_W * Math.cos(angle);
    z += STRIP_W * Math.sin(angle);
  }
  const slide = centre * 0.5;
  const push = lift * 10;
  const flat = length < 0.01;
  const zh = ctx.lang === "zh";

  return (
    <Stage gap={2}>
      <div style={{ position: "relative", width: CANVAS, height: CANVAS, flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            left: CANVAS / 2 - (CARD.w * 0.94) / 2 + Math.cos(phi) * push,
            top: CANVAS / 2 - (CARD.h * 0.9) / 2 + 12 + Math.sin(phi) * push,
            width: CARD.w * 0.94,
            height: CARD.h * 0.9,
            borderRadius: 18,
            background: "#000",
            filter: `blur(${12 + 8 * lift}px)`,
            opacity: 0.3 - 0.06 * lift,
          }}
        />
        {flat ? (
          <div style={{ position: "absolute", left: (CANVAS - CARD.w) / 2, top: (CANVAS - CARD.h) / 2 }}>
            <Face zh={zh} />
          </div>
        ) : (
          <>
            {raw.map((strip, index) => {
              const c = Math.cos(strip.angle);
              const s = Math.sin(strip.angle);
              const lead = -CANVAS / 2 - strip.start;
              const plane = { origin: [strip.x - slide + lead * c + CANVAS / 2, 0, strip.z + lead * s] as [number, number, number], u: [c, 0, s] as [number, number, number], v: [0, 1, 0] as [number, number, number] };
              const band = (strip.angle - 0.33) / 0.15;
              const glint = gloss * 0.62 * Math.exp(-band * band);
              const shade = 0.42 * clamp((strip.angle - 0.45) / 0.95);
              const left = strip.start + CANVAS / 2 - 0.35;
              return (
                <Projected
                  key={index}
                  w={STRIP_W + 0.7}
                  h={CANVAS}
                  transform={`translate(${CANVAS / 2}px, ${CANVAS / 2}px) rotate(${phi}rad) translate(${-CANVAS / 2}px, ${-CANVAS / 2}px) ${projection(plane, EYE, DEPTH)} translate(${left}px, 0px)`}
                  style={{ pointerEvents: "none" }}
                  inner={{ overflow: "hidden" }}
                >
                  <div style={{ position: "absolute", left: (CANVAS - CARD.w) / 2 - left, top: (CANVAS - CARD.h) / 2, width: CARD.w, height: CARD.h, transform: `rotate(${-phi}rad)`, borderRadius: 18 }}>
                    <Face zh={zh} />
                    {glint > 0.004 && <div style={{ position: "absolute", inset: 0, borderRadius: 18, background: white(glint) }} />}
                    {shade > 0.004 && <div style={{ position: "absolute", inset: 0, borderRadius: 18, background: black(shade) }} />}
                  </div>
                </Projected>
              );
            })}
          </>
        )}
        <div {...pan} style={{ position: "absolute", left: (CANVAS - CARD.w) / 2, top: (CANVAS - CARD.h) / 2, width: CARD.w, height: CARD.h, touchAction: "none", cursor: "grab" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the card in any direction" zh="朝任意方向拖动卡片" />
    </Stage>
  );
}

/** A plastic transit pass: flat fills only, because it is drawn once per strip. */
const Face = memo(function Face({ zh }: { zh: boolean }) {
  return (
    <div style={{ position: "relative", width: CARD.w, height: CARD.h }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 18, overflow: "hidden", background: diag(["#1FD1C1", "#2C7BF2", "#5B3BFF"]) }}>
        <div style={{ position: "absolute", left: CARD.w / 2 - 44 + 66, top: CARD.h / 2 - 130 + 10, width: 88, height: 260, display: "flex", gap: 14, transform: "rotate(32deg)" }}>
          {[0, 1, 2].map((i) => (
            <div key={i} style={{ width: 20, height: 260, borderRadius: 10, background: white(0.1 + 0.05 * i), flexShrink: 0 }} />
          ))}
        </div>
        <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", alignItems: "flex-start", color: "#fff" }}>
          <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 6, height: 18 }}>
            <TramFront size={14} strokeWidth={2.6} />
            <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>{zh ? "地铁通行卡" : "Metro Pass"}</span>
            <span style={{ flex: 1 }} />
            <Nfc size={16} strokeWidth={2.2} style={{ opacity: 0.85 }} />
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 32, lineHeight: "38px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>24.60</span>
          <div style={{ alignSelf: "stretch", display: "flex", fontSize: 9, lineHeight: "11px", fontWeight: 600, letterSpacing: 1.2, opacity: 0.8, marginTop: 2 }}>
            <span>{zh ? "余额" : "BALANCE"}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontVariantNumeric: "tabular-nums" }}>0421 7730</span>
          </div>
        </div>
      </div>
      <StrokeBorder radius={18} color={`linear-gradient(to bottom right, ${white(0.55)}, ${white(0.08)})`} />
    </div>
  );
});
