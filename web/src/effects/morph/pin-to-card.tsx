/** morph.pin-to-card · 图钉展开卡片 (Morph+PinToCard.swift) */
import { animate, useMotionValue } from "motion/react";
import { Bookmark, Coffee, CornerUpRight, LibraryBig, Star, TreePine, X, type LucideIcon } from "lucide-react";
import { memo, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, hex, spring, useAutoplay, useClock, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Column, diag, lerpRect, mixN, smooth, unit, useMV, vert } from "./_shared";

interface Place {
  name: [string, string];
  kind: [string, string];
  distance: [string, string];
  Icon: LucideIcon;
  color: string;
  rating: string;
  reviews: string;
  /** Where the pin's tip touches the map. */
  spot: { x: number; y: number };
}
const places: Place[] = [
  { name: ["Fern & Flour", "蕨与麦"], kind: ["Bakery · Café", "烘焙 · 咖啡"], distance: ["350 m", "350 米"], Icon: Coffee, color: Palette.coral, rating: "4.8", reviews: "1,204", spot: { x: 92, y: 106 } },
  { name: ["Harbor Books", "海港书店"], kind: ["Bookshop", "独立书店"], distance: ["600 m", "600 米"], Icon: LibraryBig, color: Palette.indigo, rating: "4.6", reviews: "382", spot: { x: 232, y: 142 } },
  { name: ["Kite Hill Park", "风筝山公园"], kind: ["Park · Viewpoint", "公园 · 观景点"], distance: ["1.2 km", "1.2 公里"], Icon: TreePine, color: Palette.green, rating: "4.9", reviews: "2,671", spot: { x: 150, y: 222 } },
];
const W = 316;
const H = 308;
const CARD = { x: 12, y: 170, w: 292, h: 128 };
const HEAD = 34;
const STEM = 30;
const FOCUS = { x: 158, y: 120 };
const MARKER_H = STEM + HEAD / 2;
const TAIL = "M0 0 L20 0 Q15 10 11.5 18 Q10 21 8.5 18 Q5 10 0 0 Z";

export default function PinToCard({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [selected, setSelected] = useState(0);
  const [isOpen, setIsOpen] = useState(false);
  const progressMV = useMotionValue(0);
  const liftMV = useMotionValue(0);
  const rippleMV = useMotionValue(1);
  const progress = useMV(progressMV);
  const lift = useMV(liftMV);
  const ripple = useMV(rippleMV);
  const autoIndex = useRef(0);
  const L = ctx.lang === "zh" ? 1 : 0;
  const dark = ctx.scheme === "dark";

  /** Lift first, then unroll into the card. */
  const open = (index: number, buzz = true) => {
    if (isOpen) return;
    clearAll();
    haptics.tap("light");
    setSelected(index);
    rippleMV.stop();
    rippleMV.jump(1);
    setIsOpen(true);
    animate(liftMV, 1, spring(0.26, 0.6));
    const morph = spring(ctx.n("response"), ctx.n("damping"));
    after(0.16, () => {
      if (buzz) haptics.tap("medium");
      animate(progressMV, 1, morph);
      animate(liftMV, 0, morph);
    });
  };
  /** Fold back into a pin held in the air, then let it drop. */
  const close = (buzz = true) => {
    if (!isOpen) return;
    clearAll();
    const response = ctx.n("response");
    setIsOpen(false);
    animate(progressMV, 0, spring(response, 0.9));
    animate(liftMV, 1, spring(response, 0.9));
    after(response * 0.6, () => {
      animate(liftMV, 0, spring(0.32, 0.42));
      after(0.11, () => {
        if (buzz) haptics.tap("rigid");
        rippleMV.jump(0);
        animate(rippleMV, 1, anim.easeOut(0.7));
      });
    });
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (isOpen) close(false);
      else {
        open(autoIndex.current % places.length, false);
        autoIndex.current += 1;
      }
    },
    { every: 2.1 },
  );

  const openP = unit(progress);
  const place = places[selected];
  const shift = { x: (FOCUS.x - place.spot.x) * progress, y: (FOCUS.y - place.spot.y) * progress };
  const tip = { x: place.spot.x + shift.x, y: place.spot.y + shift.y };
  const airborne = unit(lift);

  const raise = ctx.n("lift") * lift;
  const hc = { x: tip.x, y: tip.y - STEM - raise };
  const rect = lerpRect({ x: hc.x - HEAD / 2, y: hc.y - HEAD / 2, w: HEAD, h: HEAD }, CARD, progress);
  const radius = Math.min(mixN(HEAD / 2, 26, openP), Math.min(rect.w, rect.h) / 2);
  const tint = 1 - smooth(progress, 0.12, 0.6);
  const tail = 1 - smooth(progress, 0, 0.32);
  const blur = ctx.n("blur") * openP;

  return (
    <Column gap={10}>
      <div style={{ position: "relative", width: W, height: H, flexShrink: 0, borderRadius: 30, overflow: "hidden" }}>
        <div onClick={() => close()} style={{ position: "absolute", inset: 0 }}>
          <div style={{ position: "absolute", left: (W - 620) / 2, top: (H - 640) / 2, transform: `translate(${shift.x}px, ${shift.y}px)`, filter: blur > 0.05 ? `blur(${blur}px)` : undefined }}>
            <PinMap dark={dark} />
          </div>
          <div style={{ position: "absolute", inset: 0, background: black(0.14 * openP) }} />
        </div>
        <div style={{ position: "absolute", left: 204 + shift.x, top: 76 + shift.y, opacity: 1 - 0.5 * openP, pointerEvents: "none" }}>
          <UserDot preview={ctx.isPreview} />
        </div>
        {places.map((p, index) =>
          index === selected ? null : (
            <div
              key={index}
              onClick={() => (progress > 0.5 ? close() : open(index))}
              style={{
                position: "absolute",
                left: p.spot.x + shift.x - HEAD / 2,
                top: p.spot.y + shift.y - MARKER_H,
                width: HEAD,
                height: MARKER_H,
                transform: `scale(${1 - 0.22 * openP})`,
                transformOrigin: "50% 100%",
                opacity: 1 - 0.45 * openP,
                cursor: "pointer",
              }}
            >
              <Marker place={p} />
            </div>
          ),
        )}
        {/* Contact shadow and landing ripple at the pin's tip. */}
        <div style={{ position: "absolute", left: tip.x, top: tip.y, pointerEvents: "none" }}>
          <div
            style={{
              position: "absolute",
              width: 16 + 12 * airborne,
              height: 6 + 3 * airborne,
              transform: "translate(-50%, -50%)",
              borderRadius: "50%",
              background: black((0.32 - 0.16 * airborne) * (1 - openP)),
              filter: `blur(${1.5 + 2 * airborne}px)`,
            }}
          />
          <div
            style={{
              position: "absolute",
              width: 18 + 62 * ripple,
              height: (18 + 62 * ripple) * 0.46,
              transform: "translate(-50%, -50%)",
              borderRadius: "50%",
              border: `2px solid ${place.color}`,
              opacity: 0.7 * (1 - ripple),
            }}
          />
        </div>
        <svg width={20} height={20} style={{ position: "absolute", left: rect.x + rect.w / 2 - 10, top: rect.y + rect.h - 5, transform: `scale(${tail})`, transformOrigin: "50% 0%", opacity: tail, pointerEvents: "none" }}>
          <path d={TAIL} fill={place.color} />
        </svg>
        <div
          onClick={() => progress < 0.5 && open(selected)}
          style={{
            position: "absolute",
            left: rect.x,
            top: rect.y,
            width: rect.w,
            height: rect.h,
            borderRadius: radius,
            overflow: "hidden",
            background: Palette.elevated,
            boxShadow: `0 ${2 + 10 * openP + 4 * lift}px ${Math.max(4 + 18 * openP + 4 * lift, 0)}px ${black(0.22)}`,
            cursor: progress < 0.5 ? "pointer" : undefined,
          }}
        >
          <div style={{ position: "absolute", inset: 0, background: vert(hex(place.color, 0.85), place.color), opacity: tint }} />
          <div style={{ position: "absolute", left: (rect.w - CARD.w) / 2, top: (rect.h - CARD.h) / 2, width: CARD.w, height: CARD.h, transform: `scale(${0.86 + 0.14 * openP})` }}>
            <CardContent place={place} progress={progress} L={L} onClose={() => close()} />
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "grid",
              placeItems: "center",
              color: "#fff",
              transform: `scale(${1 + 0.8 * unit(progress * 2)})`,
              opacity: 1 - smooth(progress, 0.05, 0.3),
              pointerEvents: "none",
            }}
          >
            <place.Icon size={17} strokeWidth={2.4} />
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1.5px ${white(0.5 * tint)}`, pointerEvents: "none" }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, opacity: openP, pointerEvents: "none" }} />
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 30, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en={isOpen ? "Tap the map to close" : "Tap a pin"} zh={isOpen ? "点击地图关闭" : "点击图钉"} />
    </Column>
  );
}

/** A resting pin: head, tail and glyph, with its tip at the bottom centre of the frame. */
function Marker({ place }: { place: Place }) {
  return (
    <>
      <div style={{ position: "absolute", left: 9, bottom: -3, width: 16, height: 6, borderRadius: "50%", background: black(0.32), filter: "blur(1.5px)" }} />
      <div style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 2px 4px ${black(0.22)})` }}>
        <svg width={20} height={20} style={{ position: "absolute", left: 7, top: HEAD - 8 }}>
          <path d={TAIL} fill={place.color} />
        </svg>
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            width: HEAD,
            height: HEAD,
            borderRadius: "50%",
            background: vert(hex(place.color, 0.85), place.color),
            boxShadow: `inset 0 0 0 1.5px ${white(0.5)}`,
            color: "#fff",
            display: "grid",
            placeItems: "center",
          }}
        >
          <place.Icon size={17} strokeWidth={2.4} />
        </div>
      </div>
    </>
  );
}

function CardContent({ place, progress, L, onClose }: { place: Place; progress: number; L: number; onClose: () => void }) {
  const alpha = (step: number) => smooth(progress, 0.4 + 0.1 * step, 0.68 + 0.1 * step);
  const rise = (step: number) => (1 - alpha(step)) * 12;
  const line = (step: number) => ({ opacity: alpha(step), transform: `translateY(${rise(step)}px)` });
  return (
    <div style={{ position: "absolute", inset: 0, padding: 14, display: "flex", alignItems: "center", gap: 14, color: Palette.label }}>
      <div
        style={{
          width: 88,
          height: 100,
          flexShrink: 0,
          borderRadius: 20,
          background: diag(hex(place.color, 0.75), place.color),
          color: "#fff",
          display: "grid",
          placeItems: "center",
          opacity: alpha(0),
          transform: `scale(${0.9 + 0.1 * alpha(0)})`,
        }}
      >
        <place.Icon size={38} strokeWidth={2.2} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 5, minWidth: 0 }}>
        <span style={{ fontSize: 18, lineHeight: "21.5px", fontWeight: 700, whiteSpace: "nowrap", ...line(1) }}>{place.name[L]}</span>
        <div style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 12, lineHeight: "14.5px", ...line(2) }}>
          <Star size={12} fill={Palette.amber} strokeWidth={0} />
          <span style={{ fontWeight: 600 }}>{place.rating}</span>
          <span style={{ color: Palette.secondaryLabel }}>({place.reviews})</span>
        </div>
        <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel, whiteSpace: "nowrap", ...line(2) }}>{`${place.kind[L]} · ${place.distance[L]}`}</span>
        <div style={{ display: "flex", alignItems: "center", gap: 8, paddingTop: 3, ...line(3) }}>
          <div style={{ height: 32, padding: "0 12px", borderRadius: 16, background: Palette.blue, color: "#fff", display: "flex", alignItems: "center", gap: 5, fontSize: 13, fontWeight: 600, whiteSpace: "nowrap" }}>
            <span style={{ width: 11, height: 11, margin: "0 2px", borderRadius: 2.5, background: "#fff", transform: "rotate(45deg)", display: "grid", placeItems: "center" }}>
              <CornerUpRight size={8} strokeWidth={4} style={{ color: Palette.blue, transform: "rotate(-45deg)" }} />
            </span>
            {L ? "路线" : "Directions"}
          </div>
          <div style={{ width: 32, height: 32, borderRadius: 16, background: hex(Palette.blue, 0.14), color: Palette.blue, display: "grid", placeItems: "center" }}>
            <Bookmark size={14} fill="currentColor" strokeWidth={2} />
          </div>
        </div>
      </div>
      <div
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
        style={{ position: "absolute", right: 10, top: 10, width: 26, height: 26, borderRadius: 13, background: Palette.labelAlpha(0.08), color: Palette.secondaryLabel, display: "grid", placeItems: "center", opacity: alpha(3), cursor: "pointer" }}
      >
        <X size={11} strokeWidth={3.4} />
      </div>
    </div>
  );
}

/** "You are here": a blue dot with a slow pulsing halo. */
function UserDot({ preview }: { preview: boolean }) {
  const t = useClock(true, 30);
  void preview;
  const wave = (Math.sin(t * 2.2) + 1) / 2;
  const dot = (size: number, style: React.CSSProperties) => (
    <div style={{ position: "absolute", left: -size / 2, top: -size / 2, width: size, height: size, borderRadius: "50%", ...style }} />
  );
  return (
    <>
      {dot(34, { background: hex(Palette.blue, 0.25), transform: `scale(${0.5 + 0.5 * wave})`, opacity: 1 - 0.65 * wave })}
      {dot(16, { background: "#fff", boxShadow: `0 1px 3px ${black(0.2)}` })}
      {dot(11, { background: Palette.blue })}
    </>
  );
}

/** A drawn city map: tilted street grid, an avenue, a river and two parks. Larger than the stage so it can pan. */
const PinMap = memo(function PinMap({ dark }: { dark: boolean }) {
  const land = dark ? "#22262C" : "#ECE8DF";
  const block = dark ? "#282D34" : "#E3DED3";
  const road = dark ? "#3A4048" : "#FFFFFF";
  const avenue = dark ? "#5C4D26" : "#FFE49B";
  const water = dark ? "#17364E" : "#A8D3F2";
  const park = dark ? "#224430" : "#BFE3B2";
  const blocks: React.ReactNode[] = [];
  for (let column = -3; column < 8; column++)
    for (let row = -3; row < 7; row++)
      if ((column + row * 3) % 4 === 0) blocks.push(<rect key={`${column}.${row}`} x={column * 78 + 12} y={row * 64 + 10} width={54} height={44} rx={6} fill={block} />);
  let streets = "";
  for (let row = -3; row < 8; row++) streets += `M-300 ${row * 64} L700 ${row * 64} `;
  for (let column = -3; column < 9; column++) streets += `M${column * 78} -300 L${column * 78} 240 `;
  return (
    <svg width={620} height={640} style={{ background: land }}>
      <g transform={`translate(${(620 - W) / 2} ${(640 - H) / 2})`}>
        <path d="M-160 250 C-60 230 40 330 120 330 C240 330 360 250 480 300 L480 520 L-160 520 Z" fill={water} />
        <g transform="rotate(-11)">
          {blocks}
          <rect x={60} y={200} width={136} height={58} rx={16} fill={park} />
          <rect x={250} y={20} width={60} height={108} rx={16} fill={park} />
          <path d={streets} stroke={road} strokeWidth={7} strokeLinecap="round" fill="none" />
          <path d="M-300 180 C60 200 300 40 700 60" stroke={avenue} strokeWidth={12} strokeLinecap="round" fill="none" />
        </g>
      </g>
    </svg>
  );
});
