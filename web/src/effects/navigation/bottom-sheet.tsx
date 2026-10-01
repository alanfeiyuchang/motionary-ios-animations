/** navigation.bottom-sheet · 底部面板 (Navigation+BottomSheet.swift) */
import { animate, useMotionValue } from "motion/react";
import { BookOpen, Coffee, Leaf, TramFront, Utensils, type LucideIcon } from "lucide-react";
import { useRef } from "react";
import { Palette, clamp, glass, hex, rubberBand, spring, useAutoplay, useHaptics, type DemoContext, type DemoProps } from "../../kit";
import { colorGradient, predicted, useMotionNumber, useNavPan } from "./nav-util";

const sheetDetents = [0.3, 0.55, 0.92];

export default function BottomSheet({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const stageHeight = ctx.isPreview ? 340 : 400;
  const W = 340;
  const detentRef = useRef(0);
  const height = (index: number) => sheetDetents[index] * stageHeight;
  /** `height(for: detent)` and the drag, animated together like SwiftUI's `withAnimation { detent = …; drag = 0 }`. */
  const baseMV = useMotionValue(height(0));
  const dragMV = useMotionValue(0);
  const base = useMotionNumber(baseMV);
  const drag = useMotionNumber(dragMV);
  const autoStep = useRef(0);

  const minHeight = height(0);
  const maxHeight = height(sheetDetents.length - 1);
  const limit = ctx.n("resistance");

  const heightFor = (b: number, dragValue: number) => {
    const raw = b - dragValue;
    if (raw > maxHeight) return maxHeight + rubberBand(raw - maxHeight, limit);
    if (raw < minHeight) return minHeight - rubberBand(minHeight - raw, limit);
    return raw;
  };
  const currentHeight = heightFor(base, drag);
  const half = height(1);
  const lift = clamp((currentHeight - half) / Math.max(maxHeight - half, 1));

  const snap = (index: number) => {
    // Only a new detent clicks; springing back to where it was stays silent.
    if (index !== detentRef.current) haptics.tap("light");
    detentRef.current = index;
    const t = spring(ctx.n("response"), ctx.n("damping"));
    animate(baseMV, height(index), t);
    animate(dragMV, 0, t);
  };

  const pan = useNavPan(
    {
      onStart: () => dragMV.stop(),
      onChange: (s) => dragMV.set(s.translation.y),
      onEnd: (s) => {
        const target = s ? height(detentRef.current) - predicted(s).y : heightFor(baseMV.get(), dragMV.get());
        let best = 0;
        sheetDetents.forEach((_, index) => {
          if (Math.abs(height(index) - target) < Math.abs(height(best) - target)) best = index;
        });
        snap(best);
      },
    },
    { minimumDistance: 10 },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      const order = [1, 2, 1, 0];
      snap(order[autoStep.current % order.length]);
      autoStep.current += 1;
    },
    { every: 1.5 },
  );

  const corner = 28 - 10 * lift;
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div style={{ position: "absolute", inset: 0, transform: `scale(${1 - 0.06 * lift})` }}>
        <MapCanvas ctx={ctx} width={W} height={stageHeight} />
      </div>
      <div style={{ position: "absolute", inset: 0, background: "#000", opacity: 0.3 * lift, pointerEvents: "none" }} />
      {/* Sheet */}
      <div
        {...pan}
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: W,
          height: maxHeight + 80,
          transform: `translateY(${stageHeight - currentHeight}px)`,
          padding: "0 18px",
          display: "flex",
          flexDirection: "column",
          gap: 14,
          background: Palette.elevated,
          borderRadius: `${corner}px ${corner}px 0 0`,
          boxShadow: "0 -4px 20px rgb(0 0 0 / 0.18)",
          cursor: "grab",
        }}
      >
        <div style={{ alignSelf: "center", width: 38, height: 5, borderRadius: 2.5, background: Palette.labelAlpha(0.2), marginTop: 8, flexShrink: 0 }} />
        <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }}>{ctx.t("Nearby", "附近")}</div>
        {[0, 1, 2, 3, 4].map((index) => (
          <NearbyRow key={index} index={index} ctx={ctx} />
        ))}
      </div>
      {!ctx.isPreview && (
        <div style={{ position: "absolute", top: 14, left: 0, right: 0, display: "flex", justifyContent: "center", pointerEvents: "none", opacity: 1 - lift }}>
          <div
            style={{
              padding: "6px 12px",
              borderRadius: 999,
              ...glass("thin"),
              fontSize: 13,
              lineHeight: "18px",
              fontWeight: 500,
              color: Palette.secondaryLabel,
            }}
          >
            {ctx.t("Drag or flick the sheet", "拖动或轻甩面板")}
          </div>
        </div>
      )}
    </div>
  );
}

const rowIcons: LucideIcon[] = [Coffee, Utensils, BookOpen, TramFront, Leaf];
const rowNames: [string, string][] = [
  ["Corner Café", "街角咖啡"],
  ["Noodle House", "面馆"],
  ["City Library", "城市图书馆"],
  ["Central Station", "中央车站"],
  ["Riverside Park", "滨江公园"],
];

function NearbyRow({ index, ctx }: { index: number; ctx: DemoContext }) {
  const Icon = rowIcons[index % rowIcons.length];
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, flexShrink: 0 }}>
      <div
        style={{
          width: 36,
          height: 36,
          borderRadius: "50%",
          background: colorGradient(Palette.spectrum[index % Palette.spectrum.length]),
          color: "#fff",
          display: "grid",
          placeItems: "center",
          flexShrink: 0,
        }}
      >
        <Icon size={16} strokeWidth={2.5} fill={Icon === Leaf ? "currentColor" : "none"} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{ctx.t(...rowNames[index % rowNames.length])}</span>
        <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{`${index + 2}00 m`}</span>
      </div>
    </div>
  );
}

function MapCanvas({ ctx, width, height }: { ctx: DemoContext; width: number; height: number }) {
  const lines: string[] = [];
  for (let x = 0; x < width; x += 28) lines.push(`M${x} 0V${height}`);
  for (let y = 0; y < height; y += 28) lines.push(`M0 ${y}H${width}`);
  const road = `M-10 ${height * 0.7} C${width * 0.35} ${height * 0.75} ${width * 0.55} ${height * 0.1} ${width + 10} ${height * 0.2}`;
  return (
    <div style={{ position: "absolute", inset: 0, background: ctx.scheme === "dark" ? "#1C2330" : "#E8F0E6" }}>
      <svg width={width} height={height} style={{ position: "absolute", inset: 0 }}>
        <path d={lines.join("")} stroke={Palette.labelAlpha(0.06)} strokeWidth={1} fill="none" />
        <path d={road} stroke={hex(Palette.amber, 0.55)} strokeWidth={10} fill="none" />
      </svg>
      <div
        style={{
          position: "absolute",
          left: width / 2 + 30 - 16,
          top: height / 2 - 60 - 16,
          width: 32,
          height: 32,
          borderRadius: "50%",
          background: Palette.red,
          color: "#fff",
          display: "grid",
          placeItems: "center",
          boxShadow: "0 3px 6px rgb(0 0 0 / 0.2)",
        }}
      >
        {/* mappin.circle.fill: a pin head on a short needle */}
        <svg width={32} height={32} viewBox="-16 -16 32 32">
          <line x1={0} y1={-2} x2={0} y2={9} stroke="#fff" strokeWidth={2.4} strokeLinecap="round" />
          <circle cx={0} cy={-5} r={4.6} fill="#fff" />
        </svg>
      </div>
    </div>
  );
}
