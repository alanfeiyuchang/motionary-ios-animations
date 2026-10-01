/** cards.sticker-peel · 贴纸揭角 (Cards+StickerPeel.swift) */
import { animate, useMotionValue } from "motion/react";
import { Zap } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, ease, fonts, rubberBand, spring, springAt, useAutoplay, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, diag, linearPoints, themeColors, useMV } from "./shared";

const SIDE = 180;
const CANVAS = 300;
const INSET = 60;

/** Corners: 0 top-left, 1 top-right, 2 bottom-right, 3 bottom-left. Signs pointing into the sticker. */
const INWARD: [number, number][] = [[1, 1], [-1, 1], [-1, -1], [1, -1]];
const cornerPoint = (c: number) => ({ x: INWARD[c][0] > 0 ? INSET : INSET + SIDE, y: INWARD[c][1] > 0 ? INSET : INSET + SIDE });

/** The fold line of a peel: the perpendicular bisector between the corner's home and where it is now. */
function peelFold(corner: number, pw: number, ph: number) {
  const home = cornerPoint(corner);
  const [ix, iy] = INWARD[corner];
  const u = Math.max(pw * ix, 0);
  const v = Math.max(ph * iy, 0);
  const length = Math.hypot(u, v);
  if (length < 0.5) {
    const d = 0.7071;
    const n = { x: -ix * d, y: -iy * d };
    return { mid: { x: home.x + n.x * 6, y: home.y + n.y * 6 }, n, reach: 0 };
  }
  const px = u * ix;
  const py = v * iy;
  return { mid: { x: home.x + px / 2, y: home.y + py / 2 }, n: { x: -px / length, y: -py / length }, reach: length / 2 };
}
type Fold = ReturnType<typeof peelFold>;

/** The half-plane on the stuck side of the fold, as a clip-path. */
function halfPlane(f: Fold): string {
  const far = 900;
  const t = { x: -f.n.y, y: f.n.x };
  const a = { x: f.mid.x + t.x * far, y: f.mid.y + t.y * far };
  const b = { x: f.mid.x - t.x * far, y: f.mid.y - t.y * far };
  const pts = [a, b, { x: b.x - f.n.x * far, y: b.y - f.n.y * far }, { x: a.x - f.n.x * far, y: a.y - f.n.y * far }];
  return `polygon(${pts.map((p) => `${p.x.toFixed(2)}px ${p.y.toFixed(2)}px`).join(", ")})`;
}

/** Mirror across the fold line. */
function reflection(f: Fold): string {
  const { x: nx, y: ny } = f.n;
  const k = f.mid.x * nx + f.mid.y * ny;
  return `matrix(${1 - 2 * nx * nx}, ${-2 * nx * ny}, ${-2 * nx * ny}, ${1 - 2 * ny * ny}, ${2 * k * nx}, ${2 * k * ny})`;
}

export default function StickerPeel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [corner, setCorner] = useState(2);
  const cornerRef = useRef(2);
  const pw = useMotionValue(0);
  const ph = useMotionValue(0);
  const held = useRef(false);
  const [slaps, setSlaps] = useState(0);
  const autoStep = useRef(0);
  const script = useTimeouts();
  const slapTask = useTimeouts();

  const pickCorner = (c: number) => {
    cornerRef.current = c;
    setCorner(c);
  };

  const constrained = (tx: number, ty: number) => {
    const [ix, iy] = INWARD[cornerRef.current];
    const u = Math.max(tx * ix, 0) + 22;
    const v = Math.max(ty * iy, 0) + 22;
    const length = Math.hypot(u, v);
    const limit = 200;
    const scale = length > limit ? (limit + rubberBand(length - limit, 40)) / length : 1;
    return [u * scale * ix, v * scale * iy];
  };

  const slapBack = (haptic: boolean) => {
    const response = ctx.n("response");
    const t = spring(response, ctx.n("damping"));
    animate(pw, 0, t);
    animate(ph, 0, t);
    slapTask.clearAll();
    slapTask.after(response * 0.55, () => {
      setSlaps((s) => s + 1);
      if (haptic) haptics.tap("rigid");
    });
  };

  const release = () => {
    if (!held.current) return;
    held.current = false;
    slapBack(true);
  };

  const pan = usePan({
    onChange: ({ start, translation }) => {
      if (!held.current) {
        held.current = true;
        script.clearAll();
        slapTask.clearAll();
        const left = start.x < SIDE / 2;
        const top = start.y < SIDE / 2;
        pickCorner(top ? (left ? 0 : 1) : left ? 3 : 2);
        haptics.tap("soft");
      }
      const [x, y] = constrained(translation.x, translation.y);
      const t = spring(0.18, 0.85);
      animate(pw, x, t);
      animate(ph, y, t);
    },
    onEnd: release,
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current) return;
      const corners = [2, 0, 1, 3];
      const next = corners[autoStep.current % corners.length];
      autoStep.current += 1;
      pickCorner(next);
      const [ix, iy] = INWARD[next];
      animate(pw, ix * 128, anim.easeInOut(0.8));
      animate(ph, iy * 104, anim.easeInOut(0.8));
      script.clearAll();
      script.after(1.15, () => slapBack(false));
    },
    { every: 2.4 },
  );

  const e = useElapsed(slaps, 0.45, true);
  const scale = e < 0 ? 1 : e < 0.07 ? 1 - 0.035 * ease.inOut(e / 0.07) : 0.965 + 0.035 * springAt(e - 0.07, 0.26, 0.45);

  const shade = ctx.n("shade");
  const f = peelFold(corner, useMV(pw), useMV(ph));
  const lifted = Math.min(f.reach / 30, 1);
  const clip = halfPlane(f);
  const mirror = reflection(f);
  const reach = Math.max(f.reach, 1);
  const curl = linearPoints(
    CANVAS,
    CANVAS,
    [f.mid.x / CANVAS, f.mid.y / CANVAS],
    [(f.mid.x + f.n.x * reach) / CANVAS, (f.mid.y + f.n.y * reach) / CANVAS],
    [
      [black(0.34 * shade), 0],
      [white(0.75 * shade), 0.3],
      [white(0), 0.68],
      [black(0.1 * shade), 1],
    ],
  );
  const shapeClip = `inset(${INSET}px round 28px)`;

  return (
    <Stage gap={6}>
      <div style={{ position: "relative", width: CANVAS, height: CANVAS, flexShrink: 0, transform: `scale(${scale})` }}>
        {/* footprint */}
        <div style={{ position: "absolute", left: INSET, top: INSET, width: SIDE, height: SIDE, borderRadius: 28, background: Palette.labelAlpha(0.05) }}>
          <svg width={SIDE} height={SIDE} style={{ position: "absolute", inset: 0 }}>
            <rect x={0.6} y={0.6} width={SIDE - 1.2} height={SIDE - 1.2} rx={27.4} fill="none" stroke={Palette.labelAlpha(0.16)} strokeWidth={1.2} strokeDasharray="5 5" />
          </svg>
        </div>
        {/* face */}
        <div style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 2px 3px ${black(0.2)})` }}>
          <div style={{ position: "absolute", inset: 0, clipPath: clip }}>
            <div style={{ position: "absolute", left: INSET, top: INSET }}>
              <StickerFace zh={ctx.lang === "zh"} />
            </div>
          </div>
        </div>
        {/* flap shadow */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            opacity: 0.4 * shade * lifted,
            filter: "blur(7px)",
            transform: `translate(${-f.n.x * 6}px, ${-f.n.y * 6 + 3}px)`,
            pointerEvents: "none",
          }}
        >
          <div style={{ position: "absolute", inset: 0, clipPath: clip }}>
            <div style={{ position: "absolute", inset: 0, transform: mirror, transformOrigin: "0 0" }}>
              <div style={{ position: "absolute", left: INSET, top: INSET, width: SIDE, height: SIDE, borderRadius: 28, background: "#000" }} />
            </div>
          </div>
        </div>
        {/* flap */}
        <div style={{ position: "absolute", inset: 0, clipPath: clip, pointerEvents: "none" }}>
          <div style={{ position: "absolute", inset: 0, transform: mirror, transformOrigin: "0 0" }}>
            <div style={{ position: "absolute", inset: 0, clipPath: shapeClip, background: `${curl}, #DEDBD3` }} />
          </div>
        </div>
        {/* hit area */}
        <div {...pan} style={{ position: "absolute", left: INSET, top: INSET, width: SIDE, height: SIDE, touchAction: "none", cursor: "grab" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag a corner of the sticker" zh="拖动贴纸的一角" />
    </Stage>
  );
}

/** Die-cut sticker artwork: white border, glossy gradient, a glyph and a word. */
function StickerFace({ zh }: { zh: boolean }) {
  return (
    <div style={{ position: "relative", width: SIDE, height: SIDE, borderRadius: 28, background: "#fff" }}>
      <div style={{ position: "absolute", inset: 9, borderRadius: 20, overflow: "hidden", background: diag(themeColors(2)) }}>
        <div style={{ position: "absolute", left: 81 - 85 + 62, top: 81 - 85 - 70, width: 170, height: 170, borderRadius: "50%", background: white(0.28), filter: "blur(26px)" }} />
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6, color: "#fff" }}>
          <Zap size={70} fill="currentColor" strokeWidth={1.5} style={{ filter: `drop-shadow(0 4px 5px ${black(0.18)})` }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 21, lineHeight: "25px", fontWeight: 800, letterSpacing: zh ? 8 : 3 }}>{zh ? "动效" : "MOTION"}</span>
        </div>
      </div>
    </div>
  );
}
