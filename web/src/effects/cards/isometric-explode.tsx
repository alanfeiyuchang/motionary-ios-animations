/** cards.isometric-explode · 等距分层拆解 (Cards+IsometricExplode.swift) */
import { animate, useMotionValue, type MotionValue } from "motion/react";
import { memo, useRef, useState, type CSSProperties, type ReactNode } from "react";
import { DemoHint, Palette, clamp, delayed, hex, spring, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, linearPoints, tr, useMV, type LText } from "./shared";

const SIDE = 128;
const SQUASH = 0.56;
const THICKNESS = 7;
const REST = 11;
const COUNT = 4;
/** Half the width of a slab on screen. */
const REACH = SIDE * 0.7071;
const ISO = `scaleY(${SQUASH}) rotate(45deg)`;
const LABELS: [LText, LText][] = [
  [["Base", "底图"], ["Grid & land", "网格与陆地"]],
  [["Terrain", "地形"], ["Parks & water", "绿地与水域"]],
  [["Roads", "道路"], ["Streets & route", "街道与路线"]],
  [["Pins", "图钉"], ["Places & names", "地点与名称"]],
];

export default function IsometricExplode({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** 0 stacked, 1 fully apart: one value for the stack and one per slab (they are staggered). */
  const stackMV = useMotionValue(0);
  const l0 = useMotionValue(0);
  const l1 = useMotionValue(0);
  const l2 = useMotionValue(0);
  const l3 = useMotionValue(0);
  const layers = [l0, l1, l2, l3];
  const amount = useRef(0);
  const [exploded, setExploded] = useState(false);
  const explodedRef = useRef(false);
  const dragStart = useRef<number | null>(null);
  const ticks = useTimeouts();

  const set = (value: boolean, haptic: boolean) => {
    explodedRef.current = value;
    setExploded(value);
    amount.current = value ? 1 : 0;
    const t = spring(ctx.n("response"), ctx.n("damping"));
    const stagger = ctx.n("stagger");
    animate(stackMV, amount.current, t);
    layers.forEach((mv, layer) => {
      // Exploding starts at the top; stacking starts at the bottom.
      const order = value ? COUNT - 1 - layer : layer;
      animate(mv, amount.current, delayed(t, order * stagger));
    });
    ticks.clearAll();
    if (!haptic) return;
    if (value) {
      haptics.tap("medium");
      return;
    }
    // One tick as each of the three upper slabs lands.
    const landing = ctx.n("response") * 0.55;
    for (let i = 0; i < COUNT - 1; i++) ticks.after(landing + i * Math.max(stagger, 0.03), () => haptics.tap("light"));
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (dragStart.current === null) {
        dragStart.current = amount.current;
        ticks.clearAll();
      }
      if (Math.abs(translation.y) <= 4) return;
      amount.current = clamp(dragStart.current - translation.y / 130, -0.08, 1.12);
      [stackMV, ...layers].forEach((mv) => {
        mv.stop();
        mv.set(amount.current);
      });
    },
    onEnd: ({ translation, velocity }) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      [stackMV, ...layers].forEach((mv) => mv.jump(mv.get()));
      if (Math.hypot(translation.x, translation.y) < 8) {
        set(!explodedRef.current, true);
        return;
      }
      set(start - (translation.y + velocity.y * 0.25) / 130 > 0.5, true);
    },
  });

  useAutoplay(ctx.isPreview, () => set(!explodedRef.current, false), { every: 2.1 });

  const stack = useMV(stackMV);
  const gapParam = ctx.n("gap");
  const gap = REST + (gapParam - REST) * stack;
  useClock(exploded || stack > 0.02, ctx.isPreview ? 30 : undefined);
  const t = Date.now() / 1000;

  return (
    <Stage>
      <div {...pan} style={{ position: "relative", width: 330, height: 288, flexShrink: 0, touchAction: "none", cursor: "pointer" }}>
        <div style={{ position: "absolute", left: 165, top: 144, transform: `translate(${-52 * stack}px, ${1.5 * gap + 10}px)` }}>
          {layers.map((mv, layer) => (
            <Layer key={layer} layer={layer} amountMV={mv} gapParam={gapParam} time={t} ctx={ctx} />
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to explode, drag to scrub" zh="点击拆开，上下拖动调节" />
    </Stage>
  );
}

/** A square centred on the parent's origin. */
function Centred({ size = SIDE, x = 0, y = 0, style, children }: { size?: number; x?: number; y?: number; style?: CSSProperties; children?: ReactNode }) {
  return <div style={{ position: "absolute", left: -size / 2 + x, top: -size / 2 + y, width: size, height: size, ...style }}>{children}</div>;
}

/** One slab with the shadow it casts on the slab below and its label. */
function Layer({ layer, amountMV, gapParam, time, ctx }: { layer: number; amountMV: MotionValue<number>; gapParam: number; time: number; ctx: DemoContext }) {
  const amount = useMV(amountMV);
  const gap = REST + (gapParam - REST) * amount;
  const shown = clamp(amount);
  const drift = layer === 0 ? 0 : 2.5 * amount * Math.sin(time * 1.5 + layer * 1.4);
  const text = LABELS[layer % LABELS.length];
  return (
    <div style={{ position: "absolute", left: 0, top: 0, transform: `translateY(${-layer * gap}px)`, zIndex: layer }}>
      {layer > 0 ? (
        <Centred y={gap - THICKNESS + 2} style={{ filter: `blur(${3 + 9 * shown}px)`, opacity: 0.4 - 0.18 * shown }}>
          <div style={{ width: SIDE, height: SIDE, borderRadius: 22, background: "#000", transform: ISO }} />
        </Centred>
      ) : (
        <Centred y={18} style={{ filter: "blur(12px)", opacity: 0.3 }}>
          <div style={{ width: SIDE, height: SIDE, borderRadius: 22, background: "#000", transform: ISO }} />
        </Centred>
      )}
      <div style={{ position: "absolute", left: 0, top: 0, transform: `translateY(${drift}px)` }}>
        <Slab kind={layer} />
        <div style={{ position: "absolute", left: REACH + 6 + 8 * (1 - shown), top: -16, height: 32, width: 130, display: "flex", alignItems: "center", gap: 6, opacity: shown, whiteSpace: "nowrap", pointerEvents: "none" }}>
          <div style={{ width: 4, height: 4, borderRadius: 2, background: Palette.labelAlpha(0.55), flexShrink: 0 }} />
          <div style={{ width: 14, height: 1, background: Palette.labelAlpha(0.3), flexShrink: 0 }} />
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1 }}>
            <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 600, color: Palette.label }}>{tr(ctx, text[0])}</span>
            <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 500, color: Palette.secondaryLabel }}>{tr(ctx, text[1])}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

const glass = `${linearPoints(SIDE, SIDE, [0, 0], [0.5, 0.5], [[white(0.16), 0], [white(0), 1]])}, ${hex(0x2a3350, 0.5)}`;

/** A slab seen isometrically: its top face over offset copies that read as thickness. */
const Slab = memo(function Slab({ kind }: { kind: number }) {
  const solid = kind === 0;
  const el = (w: number, h: number, x: number, y: number, style: CSSProperties) => <div style={{ position: "absolute", left: SIDE / 2 - w / 2 + x, top: SIDE / 2 - h / 2 + y, width: w, height: h, ...style }} />;
  const pin = (color: number, x: number, y: number) =>
    el(20, 20, x, y, {
      borderRadius: 10,
      background: `radial-gradient(circle, #fff 3.5px, ${hex(color)} 3.6px)`,
      boxShadow: `inset 0 0 0 1.5px ${white(0.9)}, 0 0 6px ${hex(color, 0.8)}`,
    });
  let face: ReactNode;
  if (kind === 0) {
    const lines: ReactNode[] = [];
    for (let o = 16; o < SIDE; o += 16) lines.push(<path key={o} d={`M${o} 0V${SIDE}M0 ${o}H${SIDE}`} />);
    face = (
      <div style={{ position: "absolute", inset: 0, background: diag(["#34416A", "#222B48"]) }}>
        <svg width={SIDE} height={SIDE} stroke={white(0.16)} strokeWidth={0.8} fill="none">
          {lines}
        </svg>
      </div>
    );
  } else if (kind === 1) {
    face = (
      <div style={{ position: "absolute", inset: 0, background: glass }}>
        {el(50, 44, -26, -28, { borderRadius: 16, background: hex(0x3ddc97, 0.9) })}
        {el(34, 26, 34, 36, { borderRadius: 12, background: hex(0x3ddc97, 0.7) })}
        {el(190, 20, 4, 14, { borderRadius: 10, background: hex(0x3ac4ff, 0.9), transform: "rotate(-24deg)" })}
      </div>
    );
  } else if (kind === 2) {
    const s = SIDE;
    face = (
      <div style={{ position: "absolute", inset: 0, background: glass }}>
        <svg width={s} height={s} fill="none" strokeLinecap="round" strokeLinejoin="round">
          <path d={`M0 ${s * 0.3}H${s}M${s * 0.62} 0V${s}M0 ${s * 0.78}H${s * 0.62}`} stroke={white(0.92)} strokeWidth={6} />
          <path d={`M${s * 0.26} 0V${s * 0.78}`} stroke={white(0.6)} strokeWidth={3} />
          <path d={`M${s * 0.26} ${s * 0.78}H${s * 0.62}V${s * 0.3}H${s * 0.88}`} stroke="#FF8A3C" strokeWidth={4} />
        </svg>
      </div>
    );
  } else {
    face = (
      <div style={{ position: "absolute", inset: 0, background: glass }}>
        {pin(0xff5f6d, -30, 36)}
        {pin(0x6e7bff, 48, -26)}
        {el(40, 9, -26, -32, { borderRadius: 5, background: white(0.92) })}
        {el(28, 7, 30, 38, { borderRadius: 4, background: white(0.6) })}
      </div>
    );
  }
  return (
    <>
      {Array.from({ length: THICKNESS }, (_, step) => (
        <Centred key={step} y={THICKNESS - step}>
          <div style={{ width: SIDE, height: SIDE, borderRadius: 22, background: solid ? "#141A2E" : hex(0x566080, 0.55), transform: ISO }} />
        </Centred>
      ))}
      <Centred>
        <div style={{ position: "relative", width: SIDE, height: SIDE, transform: ISO }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: 22, overflow: "hidden" }}>{face}</div>
          <StrokeBorder radius={22} color={white(solid ? 0.3 : 0.42)} />
        </div>
      </Centred>
    </>
  );
});
