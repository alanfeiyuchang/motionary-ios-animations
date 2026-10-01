/** navigation.floating-sheet · 悬浮到贴边面板 (Navigation+FloatingSheet.swift) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { DemoHint, Palette, clamp, glass, rubberBand, spring, useAutoplay, useHaptics, white, type DemoContext, type DemoProps } from "../../kit";
import { colorGradient, predicted, useMotionNumber } from "./nav-util";
import { PauseFill, useNavPan } from "./_r2";
import { MusicNote, PauseCircleFill, SkipFill } from "./_stubs-kit";

const FRAME = { w: 250, h: 330 };
const DETENTS = [72, 190, FRAME.h - 30];
const LOW = DETENTS[0];
const HIGH = DETENTS[2];

export default function FloatingSheet({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const heightMV = useMotionValue(LOW);
  const height = useMotionNumber(heightMV);
  /** The model height (what the sheet is heading to), as SwiftUI's state holds it. */
  const target = useRef(LOW);
  const dragStart = useRef<number | null>(null);
  const autoStep = useRef(0);

  const snap = (to: number) => {
    if (Math.abs(to - target.current) > 1) haptics.tap("light");
    target.current = to;
    animate(heightMV, to, spring(ctx.n("response"), ctx.n("damping")));
  };
  const cycle = () => {
    const index = DETENTS.findIndex((d) => Math.abs(d - target.current) < 1);
    snap(DETENTS[((index < 0 ? 0 : index) + 1) % DETENTS.length]);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const sequence = [1, 2, 1, 0];
      snap(DETENTS[sequence[autoStep.current % sequence.length]]);
      autoStep.current += 1;
    },
    { every: 1.3 },
  );

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (dragStart.current === null) {
          dragStart.current = target.current;
          heightMV.stop();
        }
        const raw = dragStart.current - s.translation.y;
        const h = raw > HIGH ? HIGH + rubberBand(raw - HIGH, 24) : raw < LOW ? LOW + rubberBand(raw - LOW, 24) : raw;
        target.current = h;
        heightMV.set(h);
      },
      onEnd: (s) => {
        // Normal release (flick-projected height) or cancellation (current height).
        const start = dragStart.current;
        if (start === null) return;
        dragStart.current = null;
        const projected = s ? start - predicted(s).y : target.current;
        const nearest = DETENTS.reduce((best, d) => (Math.abs(d - projected) < Math.abs(best - projected) ? d : best), DETENTS[0]);
        snap(nearest);
      },
    },
    { minimumDistance: 6 },
  );

  const t = clamp((height - LOW) / (HIGH - LOW));
  const margin = 12 * (1 - t);
  const topRadius = 30 - 6 * t;
  const bottomRadius = 30 * (1 - t);
  const radius = `${topRadius}px ${topRadius}px ${bottomRadius}px ${bottomRadius}px`;
  const solid = ctx.b("glass") ? Math.min(t * 1.6, 1) : 1;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 34, overflow: "hidden", boxShadow: "0 10px 18px rgb(0 0 0 / 0.18)" }}>
        <AlbumBackdrop />
        <div
          {...pan}
          onClick={cycle}
          style={{
            position: "absolute",
            left: margin,
            bottom: margin,
            width: FRAME.w - margin * 2,
            height: Math.max(height, 56),
            borderRadius: radius,
            overflow: "hidden",
            boxShadow: "0 4px 16px rgb(0 0 0 / 0.18)",
            cursor: "pointer",
            touchAction: "none",
            userSelect: "none",
            WebkitUserSelect: "none",
          }}
        >
          <div style={{ ...glass("ultraThin"), position: "absolute", inset: 0 }} />
          <div style={{ position: "absolute", inset: 0, background: Palette.elevated, opacity: solid }} />
          <SheetContent expansion={t} ctx={ctx} />
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${white(0.25 * (1 - solid))}`, pointerEvents: "none" }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag the sheet or tap it" zh="拖动或点击面板" />
    </div>
  );
}

function SheetContent({ expansion, ctx }: { expansion: number; ctx: DemoContext }) {
  const reveal = (start: number, span = 0.3) => clamp((expansion - start) / span);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, padding: "0 14px", display: "flex", flexDirection: "column", gap: 12 }}>
      <div style={{ alignSelf: "center", width: 36, height: 5 * (0.4 + expansion), marginTop: 6, borderRadius: 3, background: Palette.secondaryLabel, opacity: 0.45 * (0.3 + 0.7 * expansion), flexShrink: 0 }} />
      {/* mini player row */}
      <div style={{ display: "flex", alignItems: "center", gap: 10, flexShrink: 0 }}>
        <div style={{ width: 40, height: 40, borderRadius: 8, background: `linear-gradient(to bottom right, ${Palette.violet}, ${Palette.pink}, ${Palette.amber})`, color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>
          <MusicNote size={21} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
          <div style={{ fontSize: 15, lineHeight: "18px", fontWeight: 700, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t("Midnight Drive", "午夜兜风")}</div>
          <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t("Neon Coast", "霓虹海岸")}</div>
        </div>
        <div style={{ flex: 1, minWidth: 4 }} />
        <PauseFill size={23} />
        <SkipFill size={25} color={Palette.secondaryLabel} />
      </div>
      {/* scrubber and transport */}
      <div style={{ display: "flex", flexDirection: "column", gap: 6, opacity: reveal(0.1), flexShrink: 0 }}>
        <div style={{ position: "relative", height: 4, borderRadius: 2, background: Palette.labelAlpha(0.12) }}>
          <div style={{ width: 84, height: 4, borderRadius: 2, background: Palette.labelAlpha(0.7) }} />
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>
          <span>1:12</span>
          <span>-2:31</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 34 }}>
          <SkipFill size={30} back />
          <PauseCircleFill size={38} />
          <SkipFill size={30} />
        </div>
      </div>
      {/* up next */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8, opacity: reveal(0.55), flexShrink: 0 }}>
        <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 700, color: Palette.secondaryLabel }}>{ctx.t("Up Next", "待播清单")}</div>
        {[0, 1, 2].map((index) => (
          <div key={index} style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 26, height: 26, borderRadius: 5, background: colorGradient(Palette.spectrum[(index + 2) % Palette.spectrum.length]) }} />
            <div style={{ width: 110 - index * 18, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.12) }} />
          </div>
        ))}
      </div>
    </div>
  );
}

/** Full-bleed album art behind the player, so the glass has something colourful to blur. */
function AlbumBackdrop() {
  return (
    <div style={{ position: "absolute", inset: 0, background: `linear-gradient(to bottom, #2B1A4F, ${Palette.violet}, ${Palette.pink}, ${Palette.amber})`, overflow: "hidden" }}>
      <div style={{ position: "absolute", left: FRAME.w / 2 + 60 - 70, top: FRAME.h / 2 - 80 - 70, width: 140, height: 140, borderRadius: "50%", background: "rgb(255 194 71 / 0.55)", filter: "blur(30px)" }} />
      <div style={{ position: "absolute", left: 0, right: 0, top: FRAME.h / 2 - 60 - 54, display: "flex", justifyContent: "center", color: white(0.28) }}>
        <MusicNote size={118} />
      </div>
    </div>
  );
}
