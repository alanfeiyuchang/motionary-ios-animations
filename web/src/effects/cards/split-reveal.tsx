/** cards.split-reveal · 撕开夹层 (Cards+SplitReveal.swift) */
import { animate, useMotionValue } from "motion/react";
import { Armchair, ChevronsUpDown, Clock, DoorOpen, Plane, type LucideIcon } from "lucide-react";
import { memo, useRef, useState } from "react";
import { DemoHint, Palette, black, clamp, fonts, rubberBand, spring, useAutoplay, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, diag, tr, useMV, type LText } from "./shared";
import { Projected, hingeX, projection, track } from "./_kit";

const SIZE = { w: 252, h: 124 };
const HALF = 62;
const NOTCH = 9;
/** A rounded ticket with a half-round notch on each side of the perforation. */
const TICKET = `path("M20 0H232A20 20 0 0 1 252 20V${HALF - NOTCH}A${NOTCH} ${NOTCH} 0 0 0 252 ${HALF + NOTCH}V104A20 20 0 0 1 232 124H20A20 20 0 0 1 0 104V${HALF + NOTCH}A${NOTCH} ${NOTCH} 0 0 0 0 ${HALF - NOTCH}V20A20 20 0 0 1 20 0Z")`;
const ROWS: { Icon: LucideIcon; label: LText; value: string }[] = [
  { Icon: DoorOpen, label: ["Gate", "登机口"], value: "B12" },
  { Icon: Clock, label: ["Boarding", "登机时间"], value: "18:40" },
  { Icon: Armchair, label: ["Seat", "座位"], value: "14A" },
];

export default function SplitReveal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** 0 closed, 1 fully open. */
  const amountMV = useMotionValue(0);
  const isOpen = useRef(false);
  const [claps, setClaps] = useState(0);
  const dragStart = useRef<number | null>(null);
  const dragSign = useRef(1);
  const clap = useTimeouts();

  const set = (open: boolean, buzz: boolean) => {
    const response = ctx.n("response");
    const wasApart = amountMV.get() > 0.2;
    isOpen.current = open;
    animate(amountMV, open ? 1 : 0, spring(response, ctx.n("damping")));
    clap.clearAll();
    if (open) {
      if (buzz) haptics.tap("light");
      return;
    }
    if (!wasApart) return;
    // The halves meet a little after half the spring's response.
    clap.after(response * 0.6, () => {
      setClaps((c) => c + 1);
      if (buzz) haptics.tap("rigid");
    });
  };

  const pan = usePan({
    onChange: ({ start, translation }) => {
      if (dragStart.current === null) {
        amountMV.stop();
        dragStart.current = amountMV.get();
        clap.clearAll();
        // Pull the top half up or the bottom half down.
        dragSign.current = start.y < 131 ? -1 : 1;
      }
      if (Math.abs(translation.y) <= 4) return;
      const travel = ctx.n("gap") / 2;
      const raw = dragStart.current + (dragSign.current * translation.y) / travel;
      amountMV.set(raw < 0 ? rubberBand(raw * travel, 24) / travel : raw > 1 ? 1 + rubberBand((raw - 1) * travel, 24) / travel : raw);
    },
    onEnd: ({ translation, velocity }) => {
      const start = dragStart.current;
      if (start === null) return;
      dragStart.current = null;
      amountMV.jump(amountMV.get());
      if (Math.hypot(translation.x, translation.y) < 8) {
        set(!isOpen.current, true);
        return;
      }
      set(start + (dragSign.current * (translation.y + velocity.y * 0.25)) / (ctx.n("gap") / 2) > 0.5, true);
    },
  });

  useAutoplay(ctx.isPreview, () => set(!isOpen.current, false), { every: 1.9 });

  const amount = useMV(amountMV);
  const gap = ctx.n("gap");
  const tilt = ctx.n("tilt");
  const e = useElapsed(claps, 0.6, true);
  const squash = e < 0 ? 1 : track(e, 1, [{ cubic: 0.97, d: 0.06 }, { spring: 1, d: 0.4, response: 0.24, damping: 0.5 }]);

  const open = gap * amount;
  const lift = clamp(amount, 0, 1.2);
  const lit = clamp(lift);
  const angle = ((tilt * Math.PI) / 180) * lift;
  const eye = { x: SIZE.w / 2, y: SIZE.h / 2 };
  const panelH = Math.max(open + 8, 0);
  const zh = ctx.lang === "zh";
  const top0 = (262 - SIZE.h) / 2;

  const half = (top: boolean) => (
    <div
      style={{
        position: "absolute",
        left: 0,
        top: top0 + ((top ? -1 : 1) * open) / 2,
        width: SIZE.w,
        height: SIZE.h,
        filter: `drop-shadow(0 ${4 + 6 * lift}px ${6 + 10 * lift}px ${black(0.14 + 0.14 * lit)})`,
        pointerEvents: "none",
      }}
    >
      {/* Each half hinges on its outer edge, so the cut edge comes toward the viewer. */}
      <Projected w={SIZE.w} h={SIZE.h} transform={projection(top ? hingeX(0, angle) : hingeX(SIZE.h, -angle), eye, 600)} inner={{ clipPath: top ? `inset(0 0 ${HALF}px 0)` : `inset(${HALF}px 0 0 0)` }}>
        <Face zh={zh} />
        {/* The freshly cut edge catches a line of light. */}
        <div style={{ position: "absolute", left: 0, right: 0, top: top ? HALF - 1 : HALF, height: 1, background: white(0.5 * lit) }} />
      </Projected>
    </div>
  );

  return (
    <Stage gap={12}>
      <div {...pan} style={{ position: "relative", width: SIZE.w, height: 262, flexShrink: 0, touchAction: "none", cursor: "pointer", transform: `scale(${2 - squash}, ${squash})` }}>
        {/* The recessed panel between the halves. */}
        <div
          style={{
            position: "absolute",
            left: 9,
            top: 131 - panelH / 2,
            width: SIZE.w - 18,
            height: panelH,
            borderRadius: 6,
            overflow: "hidden",
            background: Palette.surface,
            opacity: clamp(amount * 6),
          }}
        >
          <div style={{ position: "absolute", left: 0, right: 0, top: panelH / 2 - 50, height: 100, padding: "0 16px", display: "flex", flexDirection: "column", justifyContent: "center" }}>
            {ROWS.map((row, index) => {
              // Each row owns a slice of the opening: 30% → 60%, 45% → 75%, 60% → 90%.
              const shown = clamp((amount - 0.3 - 0.15 * index) / 0.3);
              return (
                <div key={index} style={{ height: 30, flexShrink: 0, display: "flex", alignItems: "center", gap: 10, opacity: shown, transform: `translateY(${8 * (1 - shown)}px)` }}>
                  <div style={{ width: 20, display: "grid", placeItems: "center", color: Palette.blue }}>
                    <row.Icon size={14} strokeWidth={2.4} />
                  </div>
                  <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{tr(ctx, row.label)}</span>
                  <span style={{ flex: 1 }} />
                  <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{row.value}</span>
                </div>
              );
            })}
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 14, background: `linear-gradient(${black(0.3)}, ${black(0)})` }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 12, background: `linear-gradient(${black(0)}, ${black(0.22)})` }} />
          <div style={{ position: "absolute", inset: 0, borderRadius: 6, boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}` }} />
        </div>
        {half(true)}
        {half(false)}
      </div>
      <DemoHint ctx={ctx} en="Tap the pass, or pull the halves apart" zh="点击登机牌，或把两半拉开" />
    </Stage>
  );
}

/** The whole pass, drawn at full size; each half shows it through a mask. */
const Face = memo(function Face({ zh }: { zh: boolean }) {
  const t = (en: string, cn: string) => (zh ? cn : en);
  const airport = (code: string, city: string, trailing = false) => (
    <div style={{ display: "flex", flexDirection: "column", alignItems: trailing ? "flex-end" : "flex-start" }}>
      <span style={{ fontFamily: fonts.rounded, fontSize: 26, lineHeight: "31px", fontWeight: 800 }}>{code}</span>
      <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 500, opacity: 0.8 }}>{city}</span>
    </div>
  );
  return (
    <div style={{ position: "absolute", inset: 0, clipPath: TICKET, background: diag(["#2BB8F5", "#3A7BFF", "#5B48F0"]), color: "#fff" }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: HALF, padding: "6px 18px 0", display: "flex", alignItems: "center", gap: 10 }}>
        {airport("SFO", t("San Francisco", "旧金山"))}
        <span style={{ flex: 1 }} />
        <Plane size={16} fill="currentColor" strokeWidth={1} style={{ opacity: 0.9, transform: "rotate(45deg)" }} />
        <span style={{ flex: 1 }} />
        {airport("HND", t("Tokyo", "东京"), true)}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: HALF, height: HALF, padding: "0 18px 4px", display: "flex", alignItems: "center", gap: 8 }}>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 2 }}>
          <span style={{ fontSize: 8, lineHeight: "10px", fontWeight: 600, letterSpacing: 1.2, opacity: 0.7 }}>{t("FLIGHT", "航班")}</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>ML 204</span>
        </div>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 700, padding: "4px 9px", borderRadius: 99, background: white(0.22) }}>{t("On time", "准点")}</span>
        <ChevronsUpDown size={13} strokeWidth={3} style={{ opacity: 0.8 }} />
      </div>
      <div style={{ position: "absolute", left: NOTCH + 4, right: NOTCH + 4, top: HALF - 0.5, height: 1, background: `repeating-linear-gradient(to right, ${white(0.45)} 0 4px, transparent 4px 8px)` }} />
    </div>
  );
});
