/** inputs.glass-toggle (Inputs+GlassToggle.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useRef } from "react";
import { MoonStar } from "lucide-react";
import { DemoHint, Palette, anim, black, clamp, delayed, mix, rubberBand, spring, textStyle, useAutoplay, useHaptics, useLatest, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { SymbolSwap } from "./_a-common";
import { GradientBorder, adaptive, column, spacer, useLive, useQuiet } from "./_c-common";

const TRACK = { w: 168, h: 72 };
const THUMB = { w: 92, h: 58 };
const INSET = 7;
const CANVAS = { w: 260, h: 108 };
const TRAVEL = TRACK.w - THUMB.w - INSET * 2;

export default function GlassToggle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const { wrap, quiet } = useQuiet();
  const params = useLatest({ lift: ctx.n("lift"), zoom: ctx.n("zoom") });
  const [isOn, setIsOn, isOnRef] = useLive(false);
  /** Thumb position, 0 (off) … 1 (on); runs past the ends while rubber-banding. */
  const position = useMotionValue(0);
  /** 0 = solid pill, 1 = lifted lens. */
  const lifted = useMotionValue(0);
  const stretch = useMotionValue(0);
  const dragStart = useRef<number | null>(null);
  const crossedHalf = useRef(false);
  const landTask = useRef<(() => void) | null>(null);

  const thumbX = useTransform(position, (p) => (p - 0.5) * TRAVEL);
  const onAmount = useTransform(position, (p) => clamp(p));
  const scaleX = useTransform(() => (1 + (params.current.lift - 1) * lifted.get()) * (1 + stretch.get()));
  const scaleY = useTransform(() => (1 + (params.current.lift - 1) * lifted.get()) * (1 - stretch.get() * 0.4));
  // Inverse of the lens transform, then the zoom around the lens centre.
  const artScaleX = useTransform(() => params.current.zoom / scaleX.get());
  const artScaleY = useTransform(() => params.current.zoom / scaleY.get());
  const artX = useTransform(() => -thumbX.get() * artScaleX.get());
  const liftOpacity = useTransform(lifted, (l) => clamp(l));
  const fillOpacity = useTransform(lifted, (l) => mix(1, 0.12, clamp(l)));
  const shadowOpacity = useTransform(lifted, (l) => mix(0.22, 0.3, clamp(l)));
  const shadowBlur = useTransform(lifted, (l) => `blur(${Math.max(mix(3, 12, l), 0)}px)`);
  const shadowY = useTransform(lifted, (l) => mix(2, 10, l));
  const restRim = useTransform(lifted, (l) => 1 - clamp(l));
  const glowOpacity = useTransform(onAmount, (a) => a * 0.45);

  const cancelLand = () => {
    landTask.current?.();
    landTask.current = null;
  };

  /** The single landing path for a released drag, a tap and autoplay. */
  const settle = (target: boolean, silent: boolean) => {
    if (target !== isOnRef.current && !silent) haptics.tap("medium");
    setIsOn(target);
    animate(position, target ? 1 : 0, spring(0.42, ctx.n("damping")));
    animate(stretch, 0, delayed(spring(0.3, 0.5), 0.1));
    cancelLand();
    landTask.current = after(0.14, () => animate(lifted, 0, spring(0.34, 0.72)));
  };

  /** Autoplay: lift, travel, land. */
  const flip = () => {
    cancelLand();
    animate(lifted, 1, spring(0.28, 0.7));
    const target = !isOnRef.current;
    const silent = quiet();
    landTask.current = after(0.16, () => settle(target, silent));
  };

  const endDrag = (predicted: number | null, moved: number) => {
    if (dragStart.current === null) return;
    dragStart.current = null;
    if (moved < 6) settle(!isOnRef.current, false);
    else settle((predicted ?? position.get()) > 0.5, false);
  };

  const pan = usePan({
    onStart: () => {
      cancelLand();
      dragStart.current = position.get();
      crossedHalf.current = position.get() > 0.5;
      animate(lifted, 1, spring(0.28, 0.7));
      haptics.tap("soft");
    },
    onChange: ({ translation, velocity }) => {
      const raw = (dragStart.current ?? 0) + translation.x / TRAVEL;
      let banded = raw;
      if (raw > 1) banded = 1 + rubberBand((raw - 1) * TRAVEL, 26) / TRAVEL;
      else if (raw < 0) banded = rubberBand(raw * TRAVEL, 26) / TRAVEL;
      const pull = Math.min(Math.abs(velocity.x) / 2400, 1) * ctx.n("stretch");
      const t = spring(0.18, 0.8);
      animate(position, banded, t);
      animate(stretch, pull, t);
      const half = banded > 0.5;
      if (half !== crossedHalf.current) {
        crossedHalf.current = half;
        haptics.selection();
      }
    },
    onEnd: ({ translation, velocity }) => {
      const predicted = (dragStart.current ?? 0) + (translation.x + velocity.x * 0.2) / TRAVEL;
      endDrag(predicted, Math.abs(translation.x));
    },
  });

  useAutoplay(ctx.isPreview, wrap(flip), { every: 1.7, delay: 0.5 });

  const lensLayer = { position: "absolute", inset: 0, borderRadius: THUMB.h / 2 } as const;

  return (
    <div style={column}>
      <div style={spacer} />
      {/* caption */}
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <SymbolSwap k={isOn ? "on" : "off"} style={{ color: isOn ? Palette.green : Palette.secondaryLabel, transition: "color 0.3s" }}>
          <MoonStar size={22} strokeWidth={2.2} fill={isOn ? "currentColor" : "none"} />
        </SymbolSwap>
        <span style={{ ...textStyle.title3, fontWeight: 600 }}>{ctx.t("Focus", "专注模式")}</span>
        <span style={{ display: "inline-grid", ...textStyle.subheadline, fontWeight: 500, color: Palette.secondaryLabel }}>
          <AnimatePresence initial={false}>
            <motion.span
              key={isOn ? "on" : "off"}
              initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
              exit={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
              transition={anim.easeInOut(0.3)}
              style={{ gridArea: "1 / 1", whiteSpace: "nowrap" }}
            >
              {isOn ? ctx.t("On", "已开启") : ctx.t("Off", "已关闭")}
            </motion.span>
          </AnimatePresence>
        </span>
      </div>
      {/* toggle */}
      <div
        {...pan}
        style={{
          ...pan.style,
          position: "relative",
          width: CANVAS.w,
          height: CANVAS.h,
          marginTop: 10,
          flexShrink: 0,
          display: "grid",
          placeItems: "center",
          transform: ctx.isPreview ? "scale(1.12)" : undefined,
          cursor: "pointer",
        }}
      >
        <motion.div
          style={{
            gridArea: "1 / 1",
            width: TRACK.w * 0.8,
            height: TRACK.h * 0.7,
            borderRadius: 999,
            background: Palette.green,
            filter: "blur(34px)",
            opacity: glowOpacity,
            y: 14,
          }}
        />
        <div style={{ gridArea: "1 / 1" }}>
          <TrackArt onAmount={onAmount} scheme={ctx.scheme} />
        </div>
        {/* lens: lifted scale, velocity stretch, position */}
        <motion.div style={{ gridArea: "1 / 1", position: "relative", width: THUMB.w, height: THUMB.h, x: thumbX, scaleX, scaleY, pointerEvents: "none" }}>
          <motion.div style={{ ...lensLayer, background: "#000", opacity: shadowOpacity, filter: shadowBlur, y: shadowY }} />
          {/* The refraction: the same art, magnified around the thumb centre, seen only through the lens. */}
          <motion.div style={{ ...lensLayer, overflow: "hidden", opacity: liftOpacity }}>
            <motion.div
              style={{
                position: "absolute",
                left: (THUMB.w - TRACK.w) / 2,
                top: (THUMB.h - TRACK.h) / 2,
                x: artX,
                scaleX: artScaleX,
                scaleY: artScaleY,
                filter: "brightness(1.06) saturate(1.25)",
              }}
            >
              <TrackArt onAmount={onAmount} scheme={ctx.scheme} />
            </motion.div>
          </motion.div>
          <motion.div style={{ ...lensLayer, background: "#fff", opacity: fillOpacity }} />
          {/* specular */}
          <motion.div style={{ ...lensLayer, opacity: liftOpacity, overflow: "hidden" }}>
            <div style={{ position: "absolute", inset: 3, borderRadius: 999, background: `linear-gradient(180deg, ${white(0.55)}, ${white(0)} 50%)` }} />
            <div style={{ position: "absolute", inset: 3, borderRadius: 999, background: `linear-gradient(180deg, ${white(0)} 50%, ${white(0.22)})` }} />
            <div style={{ position: "absolute", inset: 1, borderRadius: 999, border: `4px solid ${black(0.22)}`, filter: "blur(3px)" }} />
          </motion.div>
          {/* rim */}
          <motion.div style={{ ...lensLayer, opacity: restRim }}>
            <GradientBorder background={`linear-gradient(135deg, ${white(0.95)}, ${white(0.6)}, ${white(0.6)})`} width={0.5} radius={999} />
          </motion.div>
          <motion.div style={{ ...lensLayer, opacity: liftOpacity }}>
            <GradientBorder background={`linear-gradient(148deg, ${white(0.95)}, ${white(0.2)}, ${white(0.7)})`} width={1.5} radius={999} />
          </motion.div>
        </motion.div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Press and drag the thumb, or tap" zh="按住拖动滑块，或直接点击" style={{ paddingBottom: 14 }} />
    </div>
  );
}

/** Track with its off/on marks; drawn once as the track and once more, magnified, inside the lens. */
function TrackArt({ onAmount, scheme }: { onAmount: MotionValue<number>; scheme: "dark" | "light" }) {
  const off = useTransform(onAmount, (a) => 1 - a);
  return (
    <div style={{ position: "relative", width: TRACK.w, height: TRACK.h, borderRadius: 999, background: adaptive(scheme, 0xd4d4dc, 0x3a3a40) }}>
      <motion.div style={{ position: "absolute", inset: 0, borderRadius: 999, background: "linear-gradient(180deg, #3DDC84, #1FB866)", opacity: onAmount }} />
      <GradientBorder background={`linear-gradient(180deg, ${black(0.18)}, transparent)`} width={1.5} radius={999} />
      <motion.div style={{ position: "absolute", left: 34 - 1.5, top: (TRACK.h - 18) / 2, width: 3, height: 18, borderRadius: 1.5, background: white(0.9), opacity: onAmount }} />
      <motion.div
        style={{
          position: "absolute",
          left: TRACK.w - 34 - 8,
          top: (TRACK.h - 16) / 2,
          width: 16,
          height: 16,
          borderRadius: "50%",
          border: `3px solid ${Palette.labelAlpha(0.35)}`,
          opacity: off,
        }}
      />
    </div>
  );
}
