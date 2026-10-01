/** buttons.lit-toggle · 自锁发光键 (Buttons+LitToggle.swift) */
import { Power } from "lucide-react";
import { useRef, useState } from "react";
import type { Transition } from "motion/react";
import { DemoHint, Palette, alpha, anim, black, clamp, delayed, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { useAnimatedNumber } from "./_c-kit";

const LAMPS = [Palette.amber, Palette.mint, Palette.pink, Palette.sky];

export default function LitToggle({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [isOn, setIsOn] = useState(false);
  const [pressed, setPressed] = useState(false);
  const [glowTarget, setGlowTarget] = useState(0);
  const [depthTr, setDepthTr] = useState<Transition>(spring(0.18, 0.8));
  const [glowTr, setGlowTr] = useState<Transition>(anim.easeOut(0.45));
  const onRef = useRef(false);
  const downRef = useRef(false);
  const dark = ctx.scheme === "dark";
  const lamp = LAMPS[clamp(ctx.i("color"), 0, LAMPS.length - 1)];
  const travel = ctx.n("travel");
  const warm = ctx.n("warm");

  const depth = useAnimatedNumber(pressed ? 1 : isOn ? 0.6 : 0, depthTr);
  const glow = useAnimatedNumber(glowTarget, glowTr);
  const intensity = ctx.n("glow") * glow;

  const pressDown = () => {
    setDepthTr(spring(0.18, 0.8));
    setPressed(true);
  };
  const letGo = () => {
    const turningOn = !onRef.current;
    onRef.current = turningOn;
    setDepthTr(spring(0.32, 0.5));
    setPressed(false);
    setIsOn(turningOn);
    if (turningOn) {
      setGlowTr(delayed(spring(warm, 0.5), 0.06));
      setGlowTarget(1);
    } else {
      setGlowTr(anim.easeOut(0.45));
      setGlowTarget(0);
    }
  };
  const simulatePress = () => {
    pressDown();
    clearAll();
    after(0.22, letGo);
  };
  const playIntro = () => {
    clearAll();
    pressDown();
    after(0.22, letGo);
    after(1.52, pressDown);
    after(1.74, letGo);
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? simulatePress() : playIntro()), { every: 1.5, delay: 0.5 });

  const down = (e: React.PointerEvent<HTMLElement>) => {
    if (downRef.current) return;
    downRef.current = true;
    e.currentTarget.setPointerCapture(e.pointerId);
    clearAll();
    pressDown();
    haptics.tap("rigid");
  };
  const up = () => {
    if (!downRef.current) return;
    downRef.current = false;
    letGo();
    haptics.tap("light");
  };

  const circle = (size: number) => ({ position: "absolute" as const, left: 100 - size / 2, top: 100 - size / 2, width: size, height: size, borderRadius: "50%" });
  const d = clamp(depth, -0.3, 1.2);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 18, flexShrink: 0 }}>
        <div role="button" onPointerDown={down} onPointerUp={up} onPointerCancel={up} style={{ position: "relative", width: 200, height: 200, borderRadius: "50%", touchAction: "none", cursor: "pointer" }}>
          <div style={{ ...circle(190), background: lamp, filter: "blur(34px)", opacity: clamp(0.5 * intensity) }} />
          <div
            style={{
              ...circle(158),
              background: dark ? `linear-gradient(180deg, ${hex(0x4a4a52)}, ${hex(0x1e1e22)})` : `linear-gradient(180deg, #fff, ${hex(0xc9c9d2)})`,
              boxShadow: `0 10px 14px ${black(dark ? 0.5 : 0.18)}`,
            }}
          />
          <div style={{ ...circle(138), background: dark ? hex(0x0b0b0d) : hex(0x8e8e99) }} />
          <div style={{ ...circle(138), boxSizing: "border-box", border: `6px solid ${black(0.45)}`, filter: "blur(4px)" }} />
          <div style={{ ...circle(134), boxSizing: "border-box", border: `5px solid ${lamp}`, filter: "blur(3px)", opacity: clamp(intensity * 1.1) }} />
          <div
            style={{
              ...circle(124),
              transform: `scale(${1 - travel * 1.7 * depth})`,
              boxShadow: `0 ${7 - 6 * d}px ${Math.max(9 - 7 * d, 0)}px ${black(clamp(0.35 - 0.2 * d))}`,
            }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", overflow: "hidden" }}>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  background: dark ? `linear-gradient(180deg, ${hex(0x45454c)}, ${hex(0x28282d)})` : `linear-gradient(180deg, ${hex(0xfafafc)}, ${hex(0xd9d9e0)})`,
                }}
              />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  background: `radial-gradient(circle 64px at center, color-mix(in srgb, ${lamp} 35%, white) 0%, ${lamp} 55%, color-mix(in srgb, ${lamp} 72%, black) 100%)`,
                  opacity: clamp(intensity * 1.15),
                }}
              />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: "50%",
                  boxSizing: "border-box",
                  border: `${Math.max(4 + 6 * d, 0)}px solid ${black(clamp(0.1 + 0.3 * d))}`,
                  filter: "blur(4px)",
                }}
              />
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: "50%",
                  padding: 1.2,
                  background: `linear-gradient(180deg, ${white(dark ? 0.35 : 0.9)}, transparent 50%)`,
                  WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                  WebkitMaskComposite: "xor",
                  mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                }}
              />
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: Palette.labelAlpha(0.45) }}>
                <Power size={46} strokeWidth={3} />
              </div>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  display: "grid",
                  placeItems: "center",
                  color: "#fff",
                  opacity: clamp(intensity * 1.3),
                  filter: `drop-shadow(0 0 4px ${white(0.9)})`,
                }}
              >
                <Power size={46} strokeWidth={3} />
              </div>
            </div>
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
          <div
            style={{
              width: 7,
              height: 7,
              borderRadius: "50%",
              background: isOn ? lamp : Palette.labelAlpha(0.2),
              boxShadow: `0 0 4px ${alpha(lamp, isOn ? 0.9 : 0)}`,
              transition: "background 0.3s, box-shadow 0.3s",
            }}
          />
          <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, color: Palette.secondaryLabel }}>
            {isOn ? ctx.t("Latched on", "已锁定 · 开") : ctx.t("Released", "已弹起 · 关")}
          </span>
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Press to latch, press again to release" zh="按一下锁定，再按一下弹起" style={{ paddingBottom: 18 }} />
    </div>
  );
}
