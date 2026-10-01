/** inputs.seat-picker (Inputs+SeatPicker.swift) */
import { motion } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, fonts, spring, textStyle, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { FadeText } from "./_a-common";
import { PRIMARY_STRONG } from "./_b-common";
import { BOUNCY, SNAPPY, column, spacer, springTrack, useLive } from "./_c-common";

const ROWS = 5;
const COLUMNS = 8;
const SEAT = { w: 22, h: 20 };
const PITCH = { w: 30, h: 28 };
const AISLE = 14;
const SIZE = { w: 8 * 30 - 8 + 14, h: 5 * 28 + 10 };
const TAKEN = new Set([2, 3, 13, 22, 26, 27, 33, 38]);
const PRICE = 14;
const SCRIPT = [19, 20, 21, 12, 20, 19, 21, 12];

function center(index: number) {
  const row = Math.floor(index / COLUMNS);
  const columnIndex = index % COLUMNS;
  const x = columnIndex * PITCH.w + SEAT.w / 2 + (columnIndex >= COLUMNS / 2 ? AISLE : 0);
  const dx = x - SIZE.w / 2;
  return { x, y: row * PITCH.h + SEAT.h / 2 + dx * dx * 0.0009 };
}
const label = (index: number) => ["A", "B", "C", "D", "E"][Math.floor(index / COLUMNS)] + String((index % COLUMNS) + 1);

interface Pulse {
  origin: number;
  id: number;
  selecting: boolean;
}

export default function SeatPicker({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected, selectedRef] = useLive<number[]>([]);
  const [pulse, setPulse] = useState<Pulse>({ origin: 0, id: 0, selecting: true });
  const step = useRef(0);
  const zh = ctx.lang === "zh";

  /** Finger and autoplay both land here. */
  const toggle = (index: number) => {
    if (TAKEN.has(index)) return;
    const selecting = !selectedRef.current.includes(index);
    haptics.tap(selecting ? "light" : "soft");
    setPulse((p) => ({ origin: index, id: p.id + 1, selecting }));
    setSelected(selecting ? [...selectedRef.current, index] : selectedRef.current.filter((s) => s !== index));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      toggle(SCRIPT[step.current % SCRIPT.length]);
      step.current += 1;
    },
    { every: 0.75, delay: 0.4 },
  );

  const empty = selected.length === 0;
  const labels = [...selected].sort((a, b) => a - b).map(label);
  const listed = labels.slice(0, 3).join(", ") + (labels.length > 3 ? ` +${labels.length - 3}` : "");
  const count = Math.max(selected.length, 1);
  const total = count * PRICE;
  const ringT = useElapsed(pulse.id, 0.5, true);
  const ringP = ringT < 0 ? 1 : 1 - (1 - ringT / 0.5) * (1 - ringT / 0.5);
  const origin = center(pulse.origin);

  return (
    <div style={column}>
      <div style={spacer} />
      {/* screen */}
      <div style={{ position: "relative", width: 236, height: 34, flexShrink: 0 }}>
        <svg width={236} height={34} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
          <defs>
            <linearGradient id="c-seat-glow" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor={Palette.sky} stopOpacity={0.35} />
              <stop offset="1" stopColor={Palette.sky} stopOpacity={0} />
            </linearGradient>
            <linearGradient id="c-seat-edge" gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={236} y2={0}>
              <stop offset="0" stopColor={Palette.sky} />
              <stop offset="1" stopColor={Palette.indigo} />
            </linearGradient>
          </defs>
          <path d="M0 12 Q118 -10 236 12 L214 34 L22 34 Z" fill="url(#c-seat-glow)" />
          <path d="M0 12 Q118 -10 236 12" fill="none" stroke="url(#c-seat-edge)" strokeWidth={3.5} strokeLinecap="round" style={{ filter: `drop-shadow(0 0 6px ${alpha(Palette.sky, 0.7)})` }} />
        </svg>
        <div style={{ position: "absolute", left: 0, right: 0, top: 15, textAlign: "center", fontSize: 9, fontWeight: 700, letterSpacing: 2, lineHeight: "11px", color: Palette.secondaryLabel }}>{ctx.t("SCREEN", "银幕")}</div>
      </div>
      {/* map */}
      <div style={{ position: "relative", width: SIZE.w, height: SIZE.h, marginTop: 14, flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            left: origin.x - 60,
            top: origin.y - 60,
            width: 120,
            height: 120,
            borderRadius: "50%",
            border: `1.5px solid ${Palette.violet}`,
            transform: `scale(${0.12 + 0.88 * ringP})`,
            opacity: pulse.selecting ? (1 - ringP) * 0.7 : 0,
            pointerEvents: "none",
          }}
        />
        {Array.from({ length: ROWS * COLUMNS }, (_, index) => (
          <Seat
            key={index}
            index={index}
            state={TAKEN.has(index) ? "taken" : selected.includes(index) ? "selected" : "free"}
            pulse={pulse}
            radius={ctx.n("radius")}
            delay={ctx.n("delay")}
            push={ctx.n("push")}
            onTap={() => toggle(index)}
          />
        ))}
      </div>
      {/* summary */}
      <motion.div
        initial={false}
        animate={{ y: empty ? 30 : 0, opacity: empty ? 0 : 1, scale: empty ? 0.94 : 1 }}
        transition={spring(0.45, 0.78)}
        style={{
          marginTop: 10,
          width: 290,
          height: 50,
          padding: "0 10px 0 18px",
          borderRadius: 18,
          background: PRIMARY_STRONG,
          boxShadow: `0 5px 15px ${alpha(Palette.indigo, 0.3)}`,
          display: "flex",
          alignItems: "center",
          gap: 10,
          color: "#fff",
          flexShrink: 0,
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1 }}>
          <span style={{ ...textStyle.subheadline, fontWeight: 700 }}>
            <NumericText value={count} text={zh ? `${count} 个座位` : count === 1 ? "1 seat" : `${count} seats`} />
          </span>
          <FadeText text={listed} style={{ ...textStyle.caption, fontWeight: 500, opacity: 0.8 }} />
        </div>
        <div style={{ flex: 1 }} />
        <div style={{ height: 32, padding: "0 14px", borderRadius: 16, background: white(0.2), display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700 }}>
          <NumericText value={total} text={(zh ? "¥" : "$") + String(total * (zh ? 5 : 1))} />
        </div>
      </motion.div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap free seats" zh="点选空座位" style={{ paddingBottom: 12 }} />
    </div>
  );
}

function Seat({ index, state, pulse, radius, delay, push, onTap }: { index: number; state: "free" | "taken" | "selected"; pulse: Pulse; radius: number; delay: number; push: number; onTap: () => void }) {
  // Distance to the ripple origin, in seats, and the unit direction away from it.
  const here = center(index);
  const origin = center(pulse.origin);
  const dx = here.x - origin.x;
  const dy = here.y - origin.y;
  const length = Math.hypot(dx, dy);
  const distance = length > 0.5 ? length / PITCH.w : 0;
  const dir = length > 0.5 ? { x: dx / length, y: dy / length } : { x: 0, y: 0 };
  const hold = 0.005 + distance * delay;
  const isOrigin = distance === 0;
  const strength = isOrigin ? 1 : Math.max(1 - distance / Math.max(radius, 0.1), 0);
  const t = useElapsed(pulse.id, strength > 0 ? hold + 0.62 : 0, true);
  const wave =
    strength > 0
      ? springTrack(t, 0, [
          { to: 0, duration: hold },
          { to: 1, duration: 0.12, spring: SNAPPY },
          { to: 0, duration: 0.5, spring: BOUNCY },
        ])
      : 0;
  const scale = isOrigin ? 1 + (pulse.selecting ? 0.28 : -0.18) * wave : 1 - 0.14 * wave * strength;
  const isSelected = state === "selected";
  const taken = state === "taken";
  const corner = "8px 8px 4px 4px";
  return (
    <div
      onClick={onTap}
      style={{
        position: "absolute",
        left: here.x - SEAT.w / 2 - 3,
        top: here.y - SEAT.h / 2 - 3,
        padding: 3,
        transform: `translate(${dir.x * push * wave * strength}px, ${dir.y * push * wave * strength}px) scale(${scale})`,
        cursor: taken ? "default" : "pointer",
      }}
    >
      <div style={{ position: "relative", width: SEAT.w, height: SEAT.h, borderRadius: corner, background: Palette.labelAlpha(taken ? 0.1 : 0.05), boxShadow: taken ? undefined : `inset 0 0 0 1.4px ${Palette.labelAlpha(0.3)}` }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: corner,
            background: `linear-gradient(180deg, ${Palette.indigo}, ${Palette.violet})`,
            boxShadow: `0 2px 7px ${alpha(Palette.indigo, 0.6)}`,
            opacity: isSelected ? 1 : 0,
            transition: "opacity 0.2s ease-out",
          }}
        />
      </div>
    </div>
  );
}
