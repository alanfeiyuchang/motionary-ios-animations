/** cards.gift-unwrap · 拆礼物 (Cards+GiftUnwrap.swift) */
import { animate, useMotionValue, type MotionValue } from "motion/react";
import { Gift, Sparkle } from "lucide-react";
import { memo, useRef, useState, type CSSProperties } from "react";
import { DemoHint, anim, black, clamp, delayed, fonts, hex, spring, useAutoplay, useClock, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, useMV } from "./shared";
import { Projected, hingeX, hingeY, projection, track, type Plane3D } from "./_kit";

const BOX = { w: 168, h: 124 };
const CARD = { w: 142, h: 90 };
const BOX_Y = 28;
const DEPTH = 520;
const GOLD = diag(["#FFE9A8", "#E9B24A", "#C48A22"]);
const EYE = { x: BOX.w / 2, y: BOX.h / 2 };

/** Twelve soft rays. */
const RAYS = (() => {
  const stops: string[] = [];
  for (let ray = 0; ray < 12; ray++) {
    const start = ray / 12;
    const width = 1 / 12;
    stops.push(`${hex(0xffe2a0, 0)} ${(start * 360).toFixed(2)}deg`, `${hex(0xffe2a0, 0.5)} ${((start + width * 0.25) * 360).toFixed(2)}deg`, `${hex(0xffe2a0, 0)} ${((start + width * 0.5) * 360).toFixed(2)}deg`);
  }
  stops.push(`${hex(0xffe2a0, 0)} 360deg`);
  return stops.join(", ");
})();

const DOTS: [number, number][] = (() => {
  const dots: [number, number][] = [];
  let row = 0;
  for (let y = 8; y < BOX.h; y += 16, row++) for (let x = row % 2 === 0 ? 8 : 18; x < BOX.w; x += 20) dots.push([x, y]);
  return dots;
})();

export default function GiftUnwrap({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const opened = useRef(false);
  /** 0 tied, 1 ribbon gone. */
  const untieMV = useMotionValue(0);
  /** 0 closed, 1 open, one per flap (top, right, bottom, left). */
  const f0 = useMotionValue(0);
  const f1 = useMotionValue(0);
  const f2 = useMotionValue(0);
  const f3 = useMotionValue(0);
  const flaps = [f0, f1, f2, f3];
  /** 0 inside the box, 1 risen. */
  const liftMV = useMotionValue(0);
  const [bursts, setBursts] = useState(0);
  const busy = useRef(false);
  const script = useTimeouts();

  const toggle = (buzz: boolean) => {
    if (busy.current) return;
    busy.current = true;
    const response = ctx.n("response");
    script.clearAll();
    if (!opened.current) {
      opened.current = true;
      if (buzz) haptics.tap("light");
      animate(untieMV, 1, anim.easeIn(0.28));
      script.after(0.24, () => {
        flaps.forEach((mv, index) => animate(mv, 1, delayed(spring(response, 0.62), 0.05 * index)));
        script.after(0.2, () => {
          animate(liftMV, 1, spring(response * 1.15, 0.6));
          setBursts((b) => b + 1);
          if (buzz) haptics.success();
          script.after(response * 0.8, () => (busy.current = false));
        });
      });
    } else {
      opened.current = false;
      if (buzz) haptics.tap("light");
      animate(liftMV, 0, spring(0.36, 0.9));
      script.after(0.18, () => {
        flaps.forEach((mv, index) => animate(mv, 0, delayed(spring(response * 0.8, 0.86), 0.04 * (3 - index))));
        script.after(response * 0.55, () => {
          animate(untieMV, 0, spring(0.4, 0.58));
          if (buzz) haptics.tap("soft");
          script.after(0.3, () => (busy.current = false));
        });
      });
    }
  };

  useAutoplay(ctx.isPreview, () => toggle(false), { every: 2.7 });

  const up = useMV(liftMV);
  const untie = useMV(untieMV);
  const glow = ctx.n("glow");
  const strength = glow * clamp(up);
  useClock(strength >= 0.02, ctx.isPreview ? 30 : undefined);
  const turn = ((Date.now() / 1000) % 36) * 10;
  const cx = 160;
  const cy = 145;
  const risenY = BOX_Y - ctx.n("rise") * up;
  const zh = ctx.lang === "zh";

  const b = useElapsed(bursts, 1.1, true);

  return (
    <Stage>
      <div onClick={() => toggle(true)} style={{ position: "relative", width: 320, height: 290, flexShrink: 0, cursor: "pointer" }}>
        {/* gift */}
        <div style={{ position: "absolute", left: cx - BOX.w / 2, top: cy - BOX.h / 2 + BOX_Y, width: BOX.w, height: BOX.h }}>
          <div style={{ position: "absolute", left: BOX.w * 0.03, top: BOX.h * 0.05 + 14, width: BOX.w * 0.94, height: BOX.h * 0.9, borderRadius: 14, background: "#000", filter: "blur(14px)", opacity: 0.3 }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: 14, overflow: "hidden", background: "linear-gradient(#2B1524, #1A0D18)", boxShadow: `inset 0 6px 10px ${black(0.8)}` }}>
            <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle 100px at 50% 50%, ${hex(0xffc56b, 0.85 * strength)} 4px, ${hex(0xff8a3c, 0)} 100px)` }} />
          </div>
          {flaps.map((mv, index) => (
            <Flap key={index} side={index} openMV={mv} maxAngle={ctx.n("angle")} />
          ))}
          <Ribbon untie={untie} />
        </div>
        {/* The glow, rays, sparkles and the card: above the box once it is out. */}
        <div style={{ position: "absolute", left: cx, top: cy + risenY, pointerEvents: "none" }}>
          <div style={{ position: "absolute", left: -108, top: -108, width: 216, height: 216, transform: `scale(${0.5 + 0.5 * strength})`, opacity: strength, isolation: "isolate" }}>
            <div style={{ position: "absolute", inset: 8, borderRadius: "50%", background: `radial-gradient(circle, ${hex(0xffd27a, 0.75)} 6px, ${hex(0xff9a4a, 0)} 100px)` }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                background: `conic-gradient(from ${turn + 90}deg, ${RAYS})`,
                WebkitMaskImage: "radial-gradient(circle, #000 30px, transparent 106px)",
                maskImage: "radial-gradient(circle, #000 30px, transparent 106px)",
                mixBlendMode: "plus-lighter",
              }}
            />
          </div>
          {Array.from({ length: 7 }, (_, index) => {
            const angle = (index * 2 * Math.PI) / 7 - 1.2;
            const size = index % 2 === 0 ? 16 : 11;
            const reach = b < 0 ? 0 : track(b, 0, [{ move: 0 }, { linear: 0, d: 0.03 * index + 0.01 }, { spring: 1, d: 0.7, response: 0.45, damping: 0.72 }]);
            const fade = b < 0 ? 0 : track(b, 0, [{ move: 0 }, { linear: 1, d: 0.03 * index + 0.08 }, { linear: 1, d: 0.3 }, { linear: 0, d: 0.4 }]);
            return (
              <Sparkle
                key={index}
                size={size}
                fill="currentColor"
                strokeWidth={1.5}
                style={{
                  position: "absolute",
                  left: -size / 2,
                  top: -size / 2,
                  color: "#FFE9A8",
                  opacity: fade,
                  transform: `translate(${Math.cos(angle) * (40 + 78 * reach)}px, ${Math.sin(angle) * (28 + 54 * reach)}px) scale(${0.3 + 0.9 * reach})`,
                }}
              />
            );
          })}
          <div
            style={{
              position: "absolute",
              left: -CARD.w / 2,
              top: -CARD.h / 2,
              width: CARD.w,
              height: CARD.h,
              borderRadius: 14,
              transform: `rotate(${-4 * up}deg) scale(${0.78 + 0.22 * up})`,
              boxShadow: `0 10px 14px ${black(0.3 * clamp(up))}`,
              opacity: clamp(up * 5),
            }}
          >
            <GiftCard zh={zh} />
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap the gift" zh="点击礼物" />
    </Stage>
  );
}

const TRIANGLES = [
  `polygon(0 0, ${BOX.w}px 0, ${BOX.w / 2}px ${BOX.h / 2}px)`,
  `polygon(${BOX.w}px 0, ${BOX.w}px ${BOX.h}px, ${BOX.w / 2}px ${BOX.h / 2}px)`,
  `polygon(${BOX.w}px ${BOX.h}px, 0 ${BOX.h}px, ${BOX.w / 2}px ${BOX.h / 2}px)`,
  `polygon(0 ${BOX.h}px, 0 0, ${BOX.w / 2}px ${BOX.h / 2}px)`,
];

const Paper = memo(function Paper() {
  return (
    <div style={{ position: "absolute", inset: 0, background: diag(["#FF6F91", "#E8437A", "#B9306E"]) }}>
      <svg width={BOX.w} height={BOX.h} style={{ position: "absolute", inset: 0 }}>
        {DOTS.map(([x, y]) => (
          <circle key={`${x}-${y}`} cx={x} cy={y} r={2.2} fill={white(0.32)} />
        ))}
      </svg>
    </div>
  );
});

/** One triangular flap of wrapping paper, hinged on an edge of the box. `side`: 0 top, 1 right, 2 bottom, 3 left. */
function Flap({ side, openMV, maxAngle }: { side: number; openMV: MotionValue<number>; maxAngle: number }) {
  const open = useMV(openMV);
  const angle = (Math.max(open, -0.05) * maxAngle * Math.PI) / 180;
  const inside = angle > Math.PI / 2;
  const turned = Math.abs(Math.sin(angle));
  const plane: Plane3D = side === 0 ? hingeX(0, angle) : side === 1 ? hingeY(BOX.w, -angle) : side === 2 ? hingeX(BOX.h, -angle) : hingeY(0, angle);
  return (
    <Projected w={BOX.w} h={BOX.h} transform={projection(plane, EYE, DEPTH)} inner={{ clipPath: TRIANGLES[side] }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 14, overflow: "hidden" }}>
        {inside ? (
          <>
            {/* The paper's plain inner side. */}
            <div style={{ position: "absolute", inset: 0, background: "linear-gradient(#FFF3E4, #F2D9C0)" }} />
            <div style={{ position: "absolute", inset: 0, background: black(0.16 * (1 - turned)) }} />
          </>
        ) : (
          <>
            <Paper />
            <div style={{ position: "absolute", inset: 0, background: black(0.34 * turned) }} />
          </>
        )}
      </div>
    </Projected>
  );
}

/** Ribbon cross and bow. As `untie` runs 0 → 1 the loops fold into the knot and the bands slip off. */
function Ribbon({ untie }: { untie: number }) {
  const u = clamp(untie, 0, 1.2);
  const slip = clamp((u - 0.25) / 0.75);
  const fold = clamp(u / 0.55);
  const scale = 1 - fold;
  const band = (vertical: boolean, sign: number) => {
    const length = (vertical ? BOX.h : BOX.w) / 2;
    const shown = Math.max(length * (1 - slip), 0);
    const w = vertical ? 20 : shown;
    const h = vertical ? shown : 20;
    const x = vertical ? 0 : sign * (length - shown / 2);
    const y = vertical ? sign * (length - shown / 2) : 0;
    return (
      <div
        key={`${vertical}-${sign}`}
        style={{ position: "absolute", left: BOX.w / 2 - w / 2 + x, top: BOX.h / 2 - h / 2 + y, width: w, height: h, background: GOLD, boxShadow: `0 1px 2px ${black(0.2)}`, opacity: slip >= 1 ? 0 : 1, display: "grid", placeItems: "center" }}
      >
        <div style={{ width: vertical ? 3 : "100%", height: vertical ? "100%" : 3, background: white(0.35) }} />
      </div>
    );
  };
  const loop = (left: boolean) => {
    const style: CSSProperties = {
      position: "absolute",
      left: BOX.w / 2 - 19 + (left ? -19 : 19),
      top: BOX.h / 2 - 13,
      width: 38,
      height: 26,
      borderRadius: "50%",
      background: GOLD,
      boxShadow: `inset 0 0 0 0.8px ${white(0.4)}`,
      transformOrigin: left ? "100% 50%" : "0% 50%",
      transform: `rotate(${left ? 18 + 30 * fold : -18 - 30 * fold}deg) scale(${scale}, ${0.6 + 0.4 * scale})`,
      display: "grid",
      placeItems: "center",
    };
    return (
      <div style={style}>
        <div style={{ width: 20, height: 10, borderRadius: "50%", background: black(0.22) }} />
      </div>
    );
  };
  return (
    <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
      {/* Each band is two halves that slide off toward their own edge. */}
      {band(true, -1)}
      {band(true, 1)}
      {band(false, -1)}
      {band(false, 1)}
      <div style={{ position: "absolute", inset: 0, transform: untie < 0 ? `scale(${1 - untie * 0.6})` : undefined, filter: `drop-shadow(0 3px 4px ${black(0.25 * scale)})`, opacity: fold >= 1 ? 0 : 1 }}>
        {loop(true)}
        {loop(false)}
        <div style={{ position: "absolute", left: BOX.w / 2 - 9, top: BOX.h / 2 - 9, width: 18, height: 18, borderRadius: 9, background: GOLD, boxShadow: `inset 0 0 0 0.8px ${black(0.14)}`, transform: `scale(${1 - 0.9 * fold})` }} />
      </div>
    </div>
  );
}

const GiftCard = memo(function GiftCard({ zh }: { zh: boolean }) {
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 14, overflow: "hidden", background: diag(["#6E5BFF", "#A95CFF", "#FF7AB8"]) }}>
        <div style={{ position: "absolute", right: -36, top: -60, width: 110, height: 110, borderRadius: 55, background: white(0.18) }} />
        <div style={{ position: "absolute", inset: 0, padding: 12, display: "flex", flexDirection: "column", alignItems: "flex-start", color: "#fff" }}>
          <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 6, opacity: 0.9 }}>
            <Gift size={12} strokeWidth={2.8} />
            <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 700, letterSpacing: 1.4 }}>{zh ? "礼品卡" : "GIFT CARD"}</span>
            <span style={{ flex: 1 }} />
            <Sparkle size={12} fill="currentColor" strokeWidth={1.5} />
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 36, lineHeight: "43px", fontWeight: 800, fontVariantNumeric: "tabular-nums" }}>50</span>
          <span style={{ fontSize: 9, lineHeight: "11px", fontWeight: 600, opacity: 0.8 }}>{zh ? "送给你，谢谢你" : "For you, with thanks"}</span>
        </div>
      </div>
      <StrokeBorder radius={14} color={`linear-gradient(to bottom right, ${white(0.7)}, ${white(0.1)})`} />
    </div>
  );
});
