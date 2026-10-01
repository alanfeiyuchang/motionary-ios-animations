/** buttons.squircle-morph · 方圆形变 (Buttons+SquircleMorph.swift) */
import { ArrowRight } from "lucide-react";
import { useState } from "react";
import { DemoHint, Palette, alpha, clamp, delayed, fonts, mix, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { useLatchedPress } from "./_a-kit";
import { cssWeight, useAnimatedNumber } from "./_c-kit";

export default function SquircleMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [autoPressed, setAutoPressed] = useState(false);
  const corner = ctx.n("corner");
  const squeeze = ctx.n("squeeze");
  const weight = ctx.n("weight");
  const damping = ctx.n("damping");

  const { held, handlers } = useLatchedPress({ minimumHold: 0.2, onPress: () => haptics.tap("soft") });
  const pressed = held || autoPressed;

  useAutoplay(
    ctx.isPreview,
    () => {
      if (ctx.isPreview) setAutoPressed((v) => !v);
      else {
        setAutoPressed(true);
        after(0.5, () => setAutoPressed(false));
      }
    },
    { every: 1.0 },
  );

  const p = useAnimatedNumber(pressed ? 1 : 0, pressed ? spring(0.24, 0.8) : spring(0.5, damping));
  const q = useAnimatedNumber(pressed ? 1 : 0, pressed ? spring(0.2, 0.9) : delayed(spring(0.62, Math.max(damping - 0.08, 0.25)), 0.06));

  const width = mix(220, 220 * squeeze, p);
  const height = mix(58, 66, p);
  const radius = Math.max(0, mix(29, corner, p));
  const ringW = mix(234, 220 * squeeze, q);
  const ringH = mix(72, 66, q);
  const ringR = Math.max(0, mix(36, corner, q));
  const w = cssWeight(clamp(mix(0.23, weight, p), -0.2, 0.62));

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <button
        type="button"
        {...handlers}
        onClick={() => haptics.tap()}
        style={{ position: "relative", width: 248, height: 96, flexShrink: 0, display: "grid", placeItems: "center", touchAction: "none" }}
      >
        <div
          style={{
            position: "absolute",
            left: 124 - ringW / 2,
            top: 48 - ringH / 2,
            width: ringW,
            height: ringH,
            borderRadius: ringR,
            boxShadow: `inset 0 0 0 1.5px ${alpha(Palette.indigo, clamp(mix(0.26, 0, q)))}`,
          }}
        />
        <div
          style={{
            position: "absolute",
            left: 124 - width / 2,
            top: 48 - height / 2,
            width,
            height,
            borderRadius: radius,
            boxShadow: `0 ${mix(10, 3, p)}px ${Math.max(0, mix(16, 6, p))}px ${alpha(Palette.indigo, clamp(mix(0.4, 0.22, p)))}`,
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, background: Palette.primary, filter: `brightness(${1 - 0.12 * clamp(p)})` }} />
          <div
            style={{
              position: "absolute",
              inset: 1.5,
              borderRadius: Math.max(0, radius - 1.5),
              background: `linear-gradient(180deg, ${white(0.26)}, transparent 50%)`,
            }}
          />
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${white(0.22)}` }} />
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: mix(9, 5, p),
              color: "#fff",
              fontFamily: fonts.text,
              fontSize: 19,
              fontWeight: w,
              fontVariationSettings: `"wght" ${w}`,
              whiteSpace: "nowrap",
            }}
          >
            <span>{ctx.t("Continue", "继续")}</span>
            <ArrowRight size={20} strokeWidth={mix(2, 3.2, clamp(p))} style={{ transform: `scale(${mix(1, 0.9, p)})` }} />
          </div>
        </div>
      </button>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Press and hold, then let go" zh="按住按钮，再松开" style={{ paddingBottom: 18 }} />
    </div>
  );
}
