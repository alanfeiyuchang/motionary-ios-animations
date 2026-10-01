/** cards.rolodex · 名片转轮 (Cards+Rolodex.swift) */
import { animate, useMotionValue, useMotionValueEvent } from "motion/react";
import { Phone } from "lucide-react";
import { useRef } from "react";
import { DemoHint, Palette, black, clamp, fonts, spring, useAutoplay, useHaptics, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, persp, tr, useMV, type LText } from "./shared";
import { usePageSafePan } from "./_kit";

/** Finger travel that turns the wheel by one card. */
const PITCH = 120;
const CARD = { w: 200, h: 118 };
const TAB_H = 14;
const AXLE_Y = 8;
const STANDING = 5;
const FALLEN = 3;

const CONTACTS: { name: LText; role: LText; tab: string; phone: string; tint: string }[] = [
  { name: ["Ava Chen", "安然"], role: ["Motion designer", "动效设计师"], tab: "A", phone: "415 · 0142", tint: Palette.indigo },
  { name: ["Ben Ortiz", "柏宇"], role: ["iOS engineer", "iOS 工程师"], tab: "B", phone: "206 · 0178", tint: Palette.mint },
  { name: ["Cleo Park", "陈曦"], role: ["Illustrator", "插画师"], tab: "C", phone: "312 · 0119", tint: Palette.coral },
  { name: ["Dev Rao", "丁一"], role: ["Producer", "制作人"], tab: "D", phone: "646 · 0155", tint: Palette.amber },
  { name: ["Elle Wu", "方圆"], role: ["Type designer", "字体设计师"], tab: "E", phone: "503 · 0191", tint: Palette.pink },
  { name: ["Finn Hale", "高远"], role: ["Sound designer", "声音设计师"], tab: "F", phone: "718 · 0133", tint: Palette.sky },
  { name: ["Gia Rossi", "韩雪"], role: ["Art director", "艺术指导"], tab: "G", phone: "917 · 0167", tint: Palette.violet },
  { name: ["Hugo Lin", "江南"], role: ["Prototyper", "原型工程师"], tab: "H", phone: "425 · 0120", tint: Palette.green },
];
const METAL = "linear-gradient(#F2F3F5, #9A9DA6, #D9DBE0, #6E717A)";

export default function Rolodex({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const positionMV = useMotionValue(0);
  const dragStart = useRef<number | null>(null);
  const dragged = useRef(false);
  /** Autoplay turns are silent (the app mutes simulated taps and the arrival play). */
  const silent = useRef(false);
  const lastDetent = useRef(0);

  useMotionValueEvent(positionMV, "change", (v) => {
    const d = Math.round(v);
    if (d !== lastDetent.current) {
      lastDetent.current = d;
      if (!silent.current) haptics.selection();
    }
  });

  const snap = (target: number) => animate(positionMV, target, spring(ctx.n("response"), ctx.n("damping")));
  const step = (amount: number) => {
    if (dragStart.current !== null) return;
    snap(Math.round(positionMV.get()) + amount);
  };

  const pan = usePageSafePan(["up", "down"], {
    onChange: (translation) => {
      if (dragStart.current === null) {
        dragStart.current = positionMV.get();
        dragged.current = true;
        silent.current = false;
        positionMV.stop();
      }
      positionMV.set(dragStart.current + translation.y / PITCH);
    },
    onEnd: (end) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      const position = positionMV.get();
      positionMV.jump(position);
      if (!end) {
        snap(Math.round(position));
        return;
      }
      snap(Math.round(clamp(start + end.predicted.y / PITCH, position - 2, position + 2)));
    },
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      silent.current = true;
      step(1);
    },
    { every: 1.25 },
  );

  const position = useMV(positionMV);
  const peek = ctx.n("peek");
  const perspective = ctx.n("perspective");
  const n = CONTACTS.length;
  const height = CARD.h + TAB_H;

  return (
    <Stage gap={8}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          if (dragged.current) return;
          silent.current = false;
          step(1);
        }}
        style={{ position: "relative", width: 300, height: 300, flexShrink: 0, touchAction: "none", cursor: "pointer" }}
      >
        {/* stand */}
        <div style={{ position: "absolute", left: 19, top: 150 + AXLE_Y + 30 - 33, width: 12, height: 66, borderRadius: 6, background: Palette.labelAlpha(0.13) }} />
        <div style={{ position: "absolute", left: 269, top: 150 + AXLE_Y + 30 - 33, width: 12, height: 66, borderRadius: 6, background: Palette.labelAlpha(0.13) }} />
        <div style={{ position: "absolute", left: 12, top: 150 + AXLE_Y + 30 + 60 - 4, width: 276, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.1) }} />
        {CONTACTS.map((_, index) => {
          let r = (index - position) % n;
          if (r < -FALLEN) r += n;
          if (r >= STANDING) r -= n;
          const lean = 16;
          let angle: number, lift: number, shade: number, z: number;
          if (r >= 0) {
            angle = lean + r * 2;
            lift = -r * peek;
            shade = 0.07 * r;
            z = 20 - r;
          } else if (r > -1) {
            const f = -r;
            angle = lean + (-125 - lean) * f;
            lift = 0;
            shade = 0.3 * Math.sin(f * Math.PI);
            z = 100;
          } else {
            const k = -1 - r;
            angle = -125 - k * 5;
            lift = k * 7;
            shade = 0.08 * k;
            z = 60 + r;
          }
          const fade = clamp(Math.min((r + FALLEN) / 0.6, (STANDING - r) / 0.6, 1));
          return (
            <div
              key={index}
              style={{
                position: "absolute",
                left: 50,
                top: 150 - height / 2 + AXLE_Y - height / 2 + lift,
                width: CARD.w,
                height,
                opacity: fade,
                zIndex: Math.round(z * 100),
                transformOrigin: "50% 100%",
                transform: `${persp(CARD.w, height, perspective)} rotateX(${angle}deg)`,
              }}
            >
              <RolodexCard index={index} flipped={angle < -90} shade={shade} ctx={ctx} />
            </div>
          );
        })}
        {/* spindle */}
        <div style={{ position: "absolute", left: 32, top: 150 + AXLE_Y - 4.5, width: 236, height: 9, borderRadius: 4.5, background: METAL, boxShadow: `0 2px 3px ${black(0.3)}`, zIndex: 20000 }} />
        {[16, 254].map((left) => (
          <div
            key={left}
            style={{
              position: "absolute",
              left,
              top: 150 + AXLE_Y - 15,
              width: 30,
              height: 30,
              borderRadius: 15,
              zIndex: 20000,
              background: "linear-gradient(#4A4C55, #1D1E23)",
              boxShadow: `0 3px 4px ${black(0.3)}`,
            }}
          >
            <div style={{ position: "absolute", inset: 0, transform: `rotate(${position * 45}deg)` }}>
              {Array.from({ length: 6 }, (_, k) => (
                <div key={k} style={{ position: "absolute", left: 14, top: 2.5, width: 2, height: 7, borderRadius: 1, background: white(0.22), transformOrigin: "1px 12.5px", transform: `rotate(${k * 60}deg)` }} />
              ))}
              <div style={{ position: "absolute", left: 11, top: 11, width: 8, height: 8, borderRadius: 4, background: white(0.12) }} />
            </div>
          </div>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Drag down to flip, up to flip back" zh="向下拖动翻过一张，向上翻回" />
    </Stage>
  );
}

function RolodexCard({ index, flipped, shade, ctx }: { index: number; flipped: boolean; shade: number; ctx: DemoContext }) {
  const c = CONTACTS[index];
  const slot = index % 4;
  const paper = ctx.scheme === "dark" ? "#2B2B31" : "#FFFFFF";
  const name = tr(ctx, c.name);
  return (
    <div style={{ position: "relative", width: CARD.w, height: CARD.h + TAB_H, filter: `drop-shadow(0 2px 5px ${black(0.12)})` }}>
      <div
        style={{
          position: "absolute",
          left: 18 + slot * 42,
          top: 0,
          width: 38,
          height: TAB_H + 6,
          paddingTop: 2,
          borderRadius: "7px 7px 0 0",
          background: `color-mix(in srgb, ${c.tint}, #000 ${Math.min((shade + (flipped ? 0.25 : 0)) * 100, 100)}%)`,
          textAlign: "center",
          fontFamily: fonts.rounded,
          fontSize: 10,
          lineHeight: "12px",
          fontWeight: 700,
          color: flipped ? "transparent" : "#fff",
        }}
      >
        {c.tab}
      </div>
      <div style={{ position: "absolute", left: 0, top: TAB_H, width: CARD.w, height: CARD.h, borderRadius: 12, background: paper, overflow: "hidden" }}>
        {flipped ? (
          <div style={{ position: "absolute", inset: 0, padding: "0 18px", display: "flex", flexDirection: "column", justifyContent: "center", gap: 15, transform: "scaleY(-1)" }}>
            {Array.from({ length: 5 }, (_, i) => (
              <div key={i} style={{ height: 1, background: Palette.labelAlpha(0.09) }} />
            ))}
          </div>
        ) : (
          <div style={{ position: "absolute", inset: 0, padding: "0 18px", display: "flex", alignItems: "center", gap: 14 }}>
            <div
              style={{
                width: 54,
                height: 54,
                borderRadius: 27,
                flexShrink: 0,
                display: "grid",
                placeItems: "center",
                background: `linear-gradient(color-mix(in srgb, ${c.tint}, #fff 22%), ${c.tint})`,
                color: "#fff",
                fontFamily: fonts.rounded,
                fontSize: 22,
                fontWeight: 700,
              }}
            >
              {Array.from(name)[0]}
            </div>
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3 }}>
              <span style={{ fontSize: 17, lineHeight: "21px", fontWeight: 600, whiteSpace: "nowrap" }}>{name}</span>
              <span style={{ fontSize: 12, lineHeight: "15px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{tr(ctx, c.role)}</span>
              <div style={{ display: "flex", alignItems: "center", gap: 5, color: c.tint, marginTop: 5 }}>
                <Phone size={9} fill="currentColor" strokeWidth={0} />
                <span style={{ fontFamily: fonts.mono, fontSize: 11.5, lineHeight: "14px", fontWeight: 500, whiteSpace: "nowrap" }}>{c.phone}</span>
              </div>
            </div>
          </div>
        )}
        <div style={{ position: "absolute", inset: 0, background: black(shade) }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: 12, boxShadow: `inset 0 0 0 0.8px ${Palette.labelAlpha(0.1)}` }} />
      </div>
    </div>
  );
}
