/** cards.glass-stack · 玻璃叠层 (Cards+GlassStack.swift) */
import { animate, useMotionValue } from "motion/react";
import { Lock, Music, Sun, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, fonts, rubberBand, spring, useClock, useHaptics, usePan, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, linearPoints, persp, tr, useMV, type LText } from "./shared";
import { STAGE } from "./_kit";

const PANES: { Icon: LucideIcon; filled: boolean; title: LText; detail: LText; tint: string }[] = [
  { Icon: Sun, filled: true, title: ["Daylight", "日光"], detail: ["Living room · 72%", "客厅 · 72%"], tint: Palette.amber },
  { Icon: Music, filled: false, title: ["Now Playing", "正在播放"], detail: ["Lo-fi mix", "Lo-fi 合集"], tint: Palette.pink },
  { Icon: Lock, filled: false, title: ["Front Door", "入户门"], detail: ["Locked", "已上锁"], tint: Palette.mint },
];
const W = 232;
const H = 148;
const now = () => Date.now() / 1000;
const idleTilt = (t: number) => ({ x: Math.cos(t * 0.9) * 0.55, y: Math.sin(t * 1.3) * 0.45 });

export default function GlassStack({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const tx = useMotionValue(0);
  const ty = useMotionValue(0);
  const [touched, setTouched] = useState(false);
  const touchedRef = useRef(false);
  const held = useRef(false);
  useClock(true, ctx.isPreview ? 30 : undefined);

  const pan = usePan({
    onChange: ({ translation }) => {
      if (!touchedRef.current) {
        const idle = idleTilt(now());
        tx.jump(idle.x);
        ty.jump(idle.y);
        touchedRef.current = true;
        setTouched(true);
      }
      if (!held.current) {
        held.current = true;
        haptics.tap("soft");
      }
      const t = spring(0.22, 0.8);
      animate(tx, rubberBand(translation.x / 90, 1.4), t);
      animate(ty, rubberBand(translation.y / 90, 1.4), t);
    },
    onEnd: () => {
      if (!held.current) return;
      held.current = false;
      const t = spring(0.5, ctx.n("damping"));
      animate(tx, 0, t);
      animate(ty, 0, t);
    },
  });

  const time = now();
  const mx = useMV(tx);
  const my = useMV(ty);
  const tilt = touched ? { x: mx, y: my } : idleTilt(time);
  const depth = ctx.n("depth");
  const maxAngle = ctx.n("angle");
  const slide = { x: -tilt.x * 34 * depth, y: -tilt.y * 26 * depth };
  const tiltX = clamp(tilt.x, -1.2, 1.2);
  const tiltY = clamp(tilt.y, -1.2, 1.2);
  const p = persp(W, H, 0.5);

  return (
    <Stage gap={10}>
      <div style={{ position: "relative", width: 310, height: 290, flexShrink: 0 }}>
        <div style={{ position: "absolute", inset: 0, transform: `translate(${slide.x}px, ${slide.y}px)`, filter: "blur(5px)" }}>
          <Blobs time={time} />
        </div>
        {[2, 1, 0].map((layer) => {
          const travel = (22 - 10 * layer) * depth;
          const x = tilt.x * travel;
          const y = 30 - 22 * layer + tilt.y * travel;
          const scale = 1 - 0.08 * layer;
          return (
            <div key={layer} style={{ position: "absolute", left: 155 - W / 2, top: 145 - H / 2, width: W, height: H, transform: `translate(${x}px, ${y}px)` }}>
              <div style={{ width: W, height: H, transform: `${p} rotateY(${tiltX * maxAngle}deg)` }}>
                <div style={{ width: W, height: H, transform: `${p} rotateX(${-tiltY * maxAngle}deg) scale(${scale})`, borderRadius: 26, boxShadow: `${(-tiltX * 10) / scale}px ${(10 - tiltY * 8) / scale}px ${14 / scale}px ${black(0.16)}` }}>
                  <Pane layer={layer} sheen={tilt} time={time} backdrop={{ x: slide.x - x, y: slide.y - y }} backdropScale={1 / scale} ctx={ctx} />
                </div>
              </div>
            </div>
          );
        })}
        <div {...pan} style={{ position: "absolute", left: 155 - W / 2, top: 145 - H / 2 + 30, width: W, height: H, touchAction: "none", cursor: "grab" }} />
      </div>
      <DemoHint ctx={ctx} en="Drag the front pane" zh="拖动最前面的玻璃" />
    </Stage>
  );
}

/** The drifting colour field, centred in the 310×290 scene. */
function Blobs({ time }: { time: number }) {
  const blob = (color: string, size: number, x: number, y: number, phase: number) => (
    <div
      key={color}
      style={{
        position: "absolute",
        left: 155 - size / 2 + x + Math.cos(time * 0.5 + phase) * 16,
        top: 145 - size / 2 + y + Math.sin(time * 0.4 + phase * 1.3) * 14,
        width: size,
        height: size,
        borderRadius: "50%",
        background: alpha(color, 0.9),
      }}
    />
  );
  return (
    <div style={{ position: "relative", width: 310, height: 290 }}>
      {blob(Palette.indigo, 118, -84, -8, 0)}
      {blob(Palette.pink, 104, 76, -52, 1.7)}
      {blob(Palette.amber, 92, 70, 84, 3.1)}
      {blob(Palette.mint, 84, -56, 100, 4.4)}
    </div>
  );
}

function Pane({ layer, sheen, time, backdrop, backdropScale, ctx }: { layer: number; sheen: { x: number; y: number }; time: number; backdrop: { x: number; y: number }; backdropScale: number; ctx: DemoContext }) {
  const pane = PANES[layer];
  const isFront = layer === 0;
  const dark = ctx.scheme === "dark";
  const header = (icon: number, glyph: number, text: number) => (
    <div style={{ display: "flex", alignItems: "center", gap: icon > 20 ? 10 : 6, alignSelf: "stretch", color: Palette.label }}>
      <div style={{ width: icon, height: icon, borderRadius: "50%", flexShrink: 0, display: "grid", placeItems: "center", color: "#fff", background: `linear-gradient(color-mix(in srgb, ${pane.tint}, #fff 22%), ${pane.tint})` }}>
        <pane.Icon size={glyph * 1.1} fill={pane.filled ? "currentColor" : "none"} strokeWidth={2.6} />
      </div>
      <span style={{ fontSize: text, lineHeight: 1.2, fontWeight: 600, whiteSpace: "nowrap" }}>{tr(ctx, pane.title)}</span>
      <span style={{ flex: 1 }} />
      {!isFront && <span style={{ fontSize: 10.5, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{tr(ctx, pane.detail)}</span>}
    </div>
  );
  return (
    <div style={{ position: "relative", width: W, height: H, borderRadius: 26, overflow: "hidden", isolation: "isolate", background: STAGE }}>
      <div style={{ position: "absolute", left: (W - 310) / 2, top: (H - 290) / 2, transform: `scale(${backdropScale}) translate(${backdrop.x}px, ${backdrop.y}px)`, filter: "blur(24px) saturate(1.25)" }}>
        <Blobs time={time} />
      </div>
      <div style={{ position: "absolute", inset: 0, background: white(dark ? 0.1 : 0.42) }} />
      {isFront ? (
        <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
          {header(34, 15, 15)}
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 34, lineHeight: "41px", fontWeight: 600 }}>72%</span>
          <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 500, color: Palette.secondaryLabel }}>{tr(ctx, pane.detail)}</span>
        </div>
      ) : (
        <div style={{ position: "absolute", left: 0, right: 0, top: 0, padding: "5px 14px 0", display: "flex" }}>{header(17, 8.5, 11.5)}</div>
      )}
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `radial-gradient(circle 190px at ${(0.3 - sheen.x * 0.3) * W}px ${-sheen.y * 0.2 * H}px, ${white(0.28)}, ${white(0)})`,
          mixBlendMode: "plus-lighter",
          pointerEvents: "none",
        }}
      />
      <StrokeBorder radius={26} width={1.2} color={linearPoints(W, H, [0.2 - sheen.x * 0.3, 0], [1, 1], [[white(0.75), 0], [white(0.08), 0.5], [white(0.3), 1]])} />
    </div>
  );
}
