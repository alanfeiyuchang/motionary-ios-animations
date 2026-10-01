/** buttons.icon-kick · 图标起跳 (Buttons+IconKick.swift) */
import { Zap } from "lucide-react";
import { useState } from "react";
import { DemoHint, Palette, alpha, black, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, linearKF, moveKF, springKF, track, useSince } from "./_a-kit";

export default function IconKick({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [kicks, setKicks] = useState(0);
  const air = Math.max(ctx.n("air"), 0.1);
  const squash = ctx.n("squash");
  const height = ctx.n("height");

  const kick = () => {
    setKicks((k) => k + 1);
    haptics.tap("light");
    clearAll();
    if (ctx.isPreview) return;
    after(0.09 + air, () => haptics.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, kick, { every: 1.7, delay: 0.4 });

  const t = useSince(kicks, 0.09 + air * 1.6 + 1.2);
  const flight = track(t, 0, [linearKF(0, 0.09), linearKF(1, air)]);
  const hop = track(t, 0, [linearKF(0, 0.09 + air + 0.05), linearKF(1, air * 0.4)]);
  const squashY = track(t, 1, [
    cubicKF(0.7, 0.09),
    cubicKF(1.14, 0.07),
    cubicKF(1, air - 0.1),
    cubicKF(1 - squash, 0.06),
    cubicKF(1.04, air * 0.2),
    cubicKF(1, air * 0.2),
    cubicKF(1 - squash * 0.4, 0.05),
    springKF(1, 0.4, BOUNCY),
  ]);
  const squashX = track(t, 1, [
    cubicKF(1.18, 0.09),
    cubicKF(0.9, 0.07),
    cubicKF(1, air - 0.1),
    cubicKF(1 + squash * 0.8, 0.06),
    cubicKF(0.98, air * 0.2),
    cubicKF(1, air * 0.2),
    cubicKF(1 + squash * 0.3, 0.05),
    springKF(1, 0.4, BOUNCY),
  ]);
  const nudge = track(t, 0, [cubicKF(-1.5, 0.09), cubicKF(5, 0.1), springKF(0, 0.5, BOUNCY)]);
  const press = track(t, 1, [cubicKF(0.96, 0.09), springKF(1, 0.4, BOUNCY), linearKF(1, Math.max(air - 0.4, 0.01)), cubicKF(0.985, 0.05), springKF(1, 0.35, BOUNCY)]);
  const impact = t < 0 ? 1 : track(t, 1, [moveKF(1), linearKF(1, 0.09 + air - 0.01), moveKF(0), cubicKF(1, 0.3)]);

  const lift = height * 4 * flight * (1 - flight) + (height / 6) * 4 * hop * (1 - hop);
  const closeness = 1 - Math.min(lift / Math.max(height, 1), 1);
  const turn = 360 * Math.round(ctx.n("spins")) * flight;
  const fade = 1 - impact;
  const streak = { width: 9 * fade + 2, height: 2.4, borderRadius: 1.2, background: white(0.9 * fade), flexShrink: 0 } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <button
        type="button"
        onClick={kick}
        style={{
          position: "relative",
          width: 224,
          height: 60,
          flexShrink: 0,
          borderRadius: 30,
          background: "linear-gradient(135deg, #4B57E0, #7A45D6)",
          boxShadow: `0 8px 14px ${alpha(Palette.indigo, 0.4)}`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 10,
          color: "#fff",
          transform: `scale(${press})`,
        }}
      >
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 30,
            padding: 1,
            background: `linear-gradient(180deg, ${white(0.4)}, transparent)`,
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
            pointerEvents: "none",
          }}
        />
        <div style={{ position: "relative", width: 26, height: 30 }}>
          <div
            style={{
              position: "absolute",
              left: 13 - (12 + 12 * closeness) / 2,
              top: 15 + 13 - 2.5,
              width: 12 + 12 * closeness,
              height: 5,
              borderRadius: "50%",
              background: black(0.1 + 0.25 * closeness),
              filter: "blur(1.5px)",
            }}
          />
          <div style={{ position: "absolute", left: 13, top: 15 + 11, width: 0, height: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 14 + 22 * impact }}>
            <div style={streak} />
            <div style={streak} />
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "grid",
              placeItems: "center",
              transform: `translateY(${-lift}px)`,
            }}
          >
            <div style={{ transform: `scale(${squashX}, ${squashY})`, transformOrigin: "50% 100%", display: "grid" }}>
              <Zap
                size={24}
                fill={Palette.amber}
                color={Palette.amber}
                strokeWidth={1.5}
                style={{ transform: `rotate(${turn}deg)`, filter: `drop-shadow(0 0 2.5px ${alpha(Palette.amber, 0.6)})` }}
              />
            </div>
          </div>
        </div>
        <span style={{ fontSize: 17, fontWeight: 600, transform: `translateX(${nudge}px)`, whiteSpace: "nowrap" }}>{ctx.t("Boost now", "立即加速")}</span>
      </button>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Tap the button" zh="点击按钮" style={{ paddingBottom: 18 }} />
    </div>
  );
}
