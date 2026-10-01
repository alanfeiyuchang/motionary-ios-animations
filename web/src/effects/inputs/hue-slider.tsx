/** inputs.hue-slider (Inputs+HueSlider.swift) */
import { animate, motion, useMotionValue, useTransform } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, mix, spring, springAt, textStyle, useAutoplay, useElapsed, useHaptics, useLatest, usePan, type DemoProps } from "../../kit";
import { column, hsb, hsbCss, rgbCss, spacer, useMV, useQuiet, useTask } from "./_c-common";

const WIDTH = 280;
const TRACK_H = 26;
const PREVIEW_HUES = [0.92, 0.08, 0.36, 0.58];

export default function HueSlider({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  const settleTask = useTask();
  const hueMV = useMotionValue(0.58);
  /** 0 = loupe inside the thumb, 1 = out. */
  const press = useMotionValue(0);
  const lean = useMotionValue(0);
  const pressing = useRef(false);
  const touching = useRef(false);
  const [drops, setDrops] = useState(0);
  const step = useRef(0);
  const loupe = ctx.n("size");
  const tail = loupe * 0.3;
  const size = useLatest({ loupe, tail });

  const doPress = (silent: boolean) => {
    pressing.current = true;
    animate(press, 1, spring(0.32, ctx.n("pop")));
    if (!silent) haptics.tap("soft");
  };
  const upright = () => animate(lean, 0, spring(0.3, 0.45));
  /** Finger lifted, gesture cancelled or autoplay: the loupe falls back into the thumb. */
  const drop = (silent: boolean) => {
    if (!pressing.current) return;
    settleTask.cancel();
    upright();
    pressing.current = false;
    animate(press, 0, spring(0.3, 0.8));
    setDrops((d) => d + 1);
    if (!silent) haptics.tap("light");
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ location, velocity }) => {
      if (!pressing.current) doPress(false);
      const hue = hueMV.get();
      const newHue = clamp((location.x - 16) / WIDTH);
      if (Math.floor(newHue * 12) !== Math.floor(hue * 12)) haptics.selection();
      hueMV.stop();
      hueMV.set(newHue);
      const target = clamp(-velocity.x / 45, -22, 22) * ctx.n("sway");
      animate(lean, target, spring(0.25, 0.7));
      settleTask.start(async (sleep) => {
        if (!(await sleep(0.09))) return;
        upright();
      });
    },
    onEnd: () => {
      touching.current = false;
      drop(false);
    },
  });

  const previewTick = () => {
    const silent = quiet();
    const phase = step.current % 3;
    step.current += 1;
    if (phase === 2) {
      drop(silent);
      return;
    }
    if (!pressing.current) doPress(silent);
    const target = PREVIEW_HUES[(Math.floor(step.current / 3) * 2 + phase) % PREVIEW_HUES.length];
    const direction = target > hueMV.get() ? -1 : 1;
    animate(hueMV, target, anim.smoothD(0.75));
    animate(lean, 18 * direction * ctx.n("sway"), spring(0.25, 0.7));
    settleTask.start(async (sleep) => {
      if (!(await sleep(0.55))) return;
      upright();
      // The detail intro plays one glide; it must not leave the loupe out.
      if (ctx.isPreview) return;
      if (!(await sleep(0.7)) || touching.current) return;
      drop(silent);
    });
  };
  useAutoplay(ctx.isPreview, wrap(previewTick), { every: 1.0, delay: 0.4 });

  // Everything below re-derives from the animated hue, so glides interpolate in hue space.
  const hue = clamp(useMV(hueMV));
  const sat = ctx.n("sat");
  const rgb = hsb(hue * 0.999, sat, 0.96);
  const color = rgbCss(rgb);
  const ink = 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2] > 0.66 ? "#16161A" : "#fff";
  const hexCode = "#" + rgb.map((c) => Math.round(c * 255).toString(16).padStart(2, "0").toUpperCase()).join("");
  const x = WIDTH * hue;
  const stops = Array.from({ length: 13 }, (_, i) => hsbCss((i / 12) * 0.999, sat, 0.96)).join(", ");

  // Thumb: shrinks while pressed, pulses when it absorbs the loupe.
  const pulseT = useElapsed(drops, 0.7, true);
  let pulse = 1;
  if (pulseT >= 0.14 && pulseT < 0.24) {
    const p = (pulseT - 0.14) / 0.1;
    pulse = 1 + 0.28 * (p * p * (3 - 2 * p));
  } else if (pulseT >= 0.24) pulse = mix(1.28, 1, springAt(pulseT - 0.24, 0.45, 0.7));
  const thumbScale = useTransform(press, (p) => mix(1, 0.86, p));

  const loupeScale = useTransform(press, (p) => mix(0.2, 1, p));
  const loupeOpacity = useTransform(press, (p) => clamp(p));
  const loupeY = useTransform(press, (p) => -(size.current.loupe + size.current.tail) / 2 - mix(-14, 10, p));
  const r = Math.min(loupe, loupe) / 2;
  const a125 = (125 * Math.PI) / 180;
  const a55 = (55 * Math.PI) / 180;
  const cx = loupe / 2;
  const teardrop = [
    `M${cx + r * Math.cos(a125)} ${r + r * Math.sin(a125)}`,
    `A${r} ${r} 0 1 1 ${cx + r * Math.cos(a55)} ${r + r * Math.sin(a55)}`,
    `Q${cx + r * 0.2} ${r + r * 1.05} ${cx} ${loupe + tail}`,
    `Q${cx - r * 0.2} ${r + r * 1.05} ${cx + r * Math.cos(a125)} ${r + r * Math.sin(a125)}`,
    "Z",
  ].join(" ");

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "center", flexShrink: 0 }}>
        {/* Tinted card */}
        <div
          style={{
            width: WIDTH,
            padding: 16,
            display: "flex",
            flexDirection: "column",
            gap: 14,
            background: Palette.elevated,
            borderRadius: 24,
            boxShadow: `inset 0 0 0 1px ${rgbCss(rgb, 0.35)}, 0 12px 33px ${rgbCss(rgb, 0.35)}`,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
            <div
              style={{
                width: 50,
                height: 50,
                borderRadius: 15,
                flexShrink: 0,
                background: `linear-gradient(135deg, ${color}, ${hsbCss((hue + 0.09) % 1, sat, 0.9)})`,
                display: "grid",
                placeItems: "center",
                color: ink,
              }}
            >
              <PaintPalette />
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}>
              <span style={{ ...textStyle.subheadline, fontWeight: 600 }}>{ctx.t("Accent", "强调色")}</span>
              <span style={{ ...textStyle.caption, fontFamily: fonts.mono, fontWeight: 500, color: Palette.secondaryLabel }}>{hexCode}</span>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ ...textStyle.subheadline, fontWeight: 700, color: ink, padding: "0 16px", height: 34, lineHeight: "34px", borderRadius: 17, background: color, whiteSpace: "nowrap" }}>
              {ctx.t("Apply", "应用")}
            </div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div style={{ flex: 1, height: 8, borderRadius: 4, background: Palette.labelAlpha(0.08), position: "relative" }}>
              <div style={{ position: "absolute", left: 0, top: 0, width: 110, height: 8, borderRadius: 4, background: color }} />
            </div>
            {[0, 1, 2].map((i) => (
              <div key={i} style={{ width: 16, height: 16, borderRadius: "50%", background: hsbCss((hue + (i + 1) * 0.07) % 1, sat * 0.9, 0.96) }} />
            ))}
          </div>
        </div>
        <div style={{ height: 94 }} />
        {/* Track, thumb, loupe */}
        <div style={{ position: "relative", width: WIDTH, height: TRACK_H }}>
          <div
            style={{
              position: "absolute",
              left: -TRACK_H / 2,
              top: 0,
              width: WIDTH + TRACK_H,
              height: TRACK_H,
              borderRadius: TRACK_H / 2,
              background: `linear-gradient(90deg, ${stops})`,
              boxShadow: `inset 0 0 0 1px ${black(0.08)}`,
            }}
          />
          <motion.div
            style={{
              position: "absolute",
              left: x - 16,
              top: TRACK_H / 2 - 16,
              width: 32,
              height: 32,
              borderRadius: "50%",
              background: "#fff",
              boxShadow: `0 3px 7px ${black(0.28)}`,
              scale: thumbScale,
            }}
          >
            <div style={{ position: "absolute", inset: 0, transform: `scale(${pulse})`, borderRadius: "50%", background: "#fff" }}>
              <div style={{ position: "absolute", inset: 5, borderRadius: "50%", background: color }} />
            </div>
          </motion.div>
          {/* Zero-size anchor at the loupe's tip; the teardrop grows upward from it. */}
          <motion.div
            style={{
              position: "absolute",
              left: x - loupe / 2,
              top: -(loupe + tail) / 2,
              width: loupe,
              height: loupe + tail,
              y: loupeY,
              rotate: lean,
              scale: loupeScale,
              opacity: loupeOpacity,
              originX: 0.5,
              originY: 1,
              pointerEvents: "none",
              filter: `drop-shadow(0 6px 10px ${black(0.25)})`,
            }}
          >
            <svg width={loupe} height={loupe + tail} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
              <path d={teardrop} fill={color} stroke="#fff" strokeWidth={3} strokeLinejoin="round" />
            </svg>
            <div
              style={{
                position: "absolute",
                inset: 0,
                display: "grid",
                placeItems: "center",
                transform: `translateY(${-tail / 2}px)`,
                fontFamily: fonts.rounded,
                fontSize: loupe * 0.27,
                fontWeight: 700,
                fontVariantNumeric: "tabular-nums",
                color: ink,
              }}
            >
              {Math.round(hue * 360)}°
            </div>
          </motion.div>
          {/* gesture strip */}
          <div {...pan} style={{ ...pan.style, position: "absolute", left: -16, top: TRACK_H / 2 - 32, width: WIDTH + 32, height: 64, cursor: "pointer" }} />
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Press and drag along the track" zh="按住并沿轨道拖动" style={{ paddingBottom: 14 }} />
    </div>
  );
}

/** SF `paintpalette.fill`. */
function PaintPalette() {
  return (
    <svg width={24} height={22} viewBox="0 0 24 22" fill="currentColor" fillRule="evenodd">
      <path d="M12 1C5.9 1 1 5.3 1 10.8c0 5 4.300 9.200 9.600 9.200 1.500 0 2.300-1 2.300-2.100 0-.6-.2-1-.5-1.500-.3-.4-.5-.9-.5-1.400 0-1.200 1-2.100 2.200-2.100h2.600c3.500 0 6.300-2.500 6.300-5.600C23 3.900 18.100 1 12 1ZM6 12.300a1.700 1.700 0 1 1 0-3.400 1.700 1.700 0 0 1 0 3.400Zm2.700-4.700a1.700 1.700 0 1 1 0-3.400 1.700 1.700 0 0 1 0 3.400Zm5.300-1.300a1.700 1.700 0 1 1 0-3.400 1.700 1.700 0 0 1 0 3.400Zm4.600 2.700a1.700 1.700 0 1 1 0-3.400 1.700 1.700 0 0 1 0 3.400Z" />
    </svg>
  );
}
