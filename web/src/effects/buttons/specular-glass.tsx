/** buttons.specular-glass · 高光玻璃 (Buttons+SpecularGlass.swift) */
import type { Transition } from "motion/react";
import { ArrowRight } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, clamp, hex, mix, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { cubicKF, moveKF, track, useSince } from "./_a-kit";
import { useAnimatedNumber } from "./_c-kit";

const REST = { x: -0.55, y: -0.7 };
const CARD = { w: 304, h: 220 };
const GLASS = { w: 232, h: 76 };
const PATH = [
  { x: 0.8, y: -0.6 },
  { x: 0.5, y: 0.7 },
  { x: -0.2, y: 0.1 },
  { x: -0.85, y: 0.6 },
  { x: -0.4, y: -0.8 },
];

/** The wallpaper under the glass: soft colour fields plus a crisp dot grid. */
function Backdrop() {
  const blob = (color: string, size: number, x: number, y: number) => (
    <div style={{ position: "absolute", left: CARD.w / 2 + x - size / 2, top: CARD.h / 2 + y - size / 2, width: size, height: size, borderRadius: "50%", background: color }} />
  );
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: CARD.w, height: CARD.h, overflow: "hidden", background: `linear-gradient(${Math.atan2(CARD.w, -CARD.h)}rad, ${hex(0x1b1d3a)}, ${hex(0x3a1d4f)})` }}>
      <div style={{ position: "absolute", inset: 0, filter: "blur(30px)" }}>
        {blob(Palette.pink, 150, -96, -52)}
        {blob(Palette.amber, 120, 104, 46)}
        {blob(Palette.sky, 170, 6, 86)}
        {blob(Palette.mint, 96, 70, -84)}
      </div>
      <div style={{ position: "absolute", inset: 0, backgroundImage: `radial-gradient(circle, ${white(0.42)} 1.1px, transparent 1.4px)`, backgroundSize: "19px 19px" }} />
    </div>
  );
}

export default function SpecularGlass({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const intro = useTimeouts();
  const press = useTimeouts();
  const [light, setLight] = useState(REST);
  const [lightTr, setLightTr] = useState<Transition>(spring(0.22, 0.75));
  const [pressed, setPressedState] = useState(false);
  const [pressTr, setPressTr] = useState<Transition>(spring(0.26, 0.7));
  const pressedRef = useRef(false);
  const lightRef = useRef(REST);
  const [sheens, setSheens] = useState(0);
  const step = useRef(0);
  const lag = ctx.n("lag");

  const moveLight = (l: { x: number; y: number }, t: Transition) => {
    lightRef.current = l;
    setLightTr(t);
    setLight(l);
  };
  const setPressed = (p: boolean, t: Transition) => {
    pressedRef.current = p;
    setPressTr(t);
    setPressedState(p);
  };
  const release = () => {
    if (!pressedRef.current && lightRef.current === REST) return;
    setPressed(false, spring(0.4, 0.55));
    moveLight(REST, spring(0.7, 0.8));
  };
  const stepPreview = () => {
    const next = PATH[step.current % PATH.length];
    step.current += 1;
    moveLight(next, spring(0.7, 0.8));
    if (step.current % 3 !== 0) return;
    setPressed(true, spring(0.26, 0.7));
    press.after(0.45, () => {
      setSheens((s) => s + 1);
      setPressed(false, spring(0.4, 0.55));
    });
  };
  const playIntro = () => {
    intro.clearAll();
    stepPreview();
    intro.after(0.9, stepPreview);
    intro.after(1.8, stepPreview);
    intro.after(2.7, release);
  };
  useAutoplay(ctx.isPreview, () => (ctx.isPreview ? stepPreview() : playIntro()), { every: 0.95, delay: 0.3 });

  const onGlass = (p: { x: number; y: number }) => Math.abs(p.x - CARD.w / 2) < GLASS.w / 2 && Math.abs(p.y - CARD.h / 2) < GLASS.h / 2;
  const pan = usePan({
    onChange: (s) => {
      intro.clearAll();
      const inside = onGlass(s.location);
      if (inside !== pressedRef.current) {
        if (inside) haptics.tap("soft");
        setPressed(inside, spring(0.26, 0.7));
      }
      moveLight({ x: clamp((s.location.x - CARD.w / 2) / (GLASS.w / 2), -1, 1), y: clamp((s.location.y - CARD.h / 2) / (GLASS.h / 2), -1, 1) }, spring(lag, 0.75));
    },
    onEnd: (s) => {
      if (onGlass(s.location)) {
        haptics.tap("medium");
        setSheens((n) => n + 1);
      }
      release();
    },
  });

  const lx = useAnimatedNumber(light.x, lightTr);
  const ly = useAnimatedNumber(light.y, lightTr);
  const pp = useAnimatedNumber(pressed ? 1 : 0, pressTr);
  const p01 = clamp(pp);
  const highlight = ctx.n("size");
  const intensity = ctx.n("intensity");
  const refraction = ctx.n("refraction");

  const spot = { x: lx * (GLASS.w / 2 - 26), y: ly * (GLASS.h / 2 - 14) };
  const width = highlight * mix(1, 0.6, pp);
  const peak = clamp(intensity * mix(0.8, 1, pp));
  const st = useSince(sheens, 0.55);
  const travel = st < 0 ? -1 : track(st, -1, [moveKF(-1), cubicKF(1, 0.5)]);

  // Rim gradient from the point where the light enters to the opposite point.
  const dx = -lx * GLASS.w;
  const dy = -ly * GLASS.h;
  const len = Math.hypot(dx, dy);
  let rim = white(0.95);
  if (len > 0.5) {
    const theta = Math.atan2(dx, -dy);
    const L = Math.abs(GLASS.w * Math.sin(theta)) + Math.abs(GLASS.h * Math.cos(theta));
    const at = (loc: number) => `${(L / 2 - len / 2 + loc * len).toFixed(2)}px`;
    rim = `linear-gradient(${theta}rad, ${white(0.95)} ${at(0)}, ${white(0.12)} ${at(0.55)}, ${white(0.5)} ${at(1)})`;
  }
  const inner = Math.max(mix(7, 12, pp), 0);
  const farMask = `radial-gradient(circle 80px at ${GLASS.w / 2 - (lx * GLASS.w) / 2}px ${GLASS.h / 2 - (ly * GLASS.h) / 2}px, #fff, transparent)`;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div {...pan} role="button" style={{ ...pan.style, position: "relative", width: CARD.w, height: CARD.h, flexShrink: 0, cursor: "pointer" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 30, overflow: "hidden", boxShadow: `0 10px 18px ${black(0.18)}` }}>
          <Backdrop />
        </div>
        <div
          style={{
            position: "absolute",
            left: (CARD.w - GLASS.w) / 2,
            top: (CARD.h - GLASS.h) / 2,
            width: GLASS.w,
            height: GLASS.h,
            borderRadius: GLASS.h / 2,
            transform: `scale(${mix(1, 0.955, pp)})`,
            boxShadow: `0 ${mix(12, 4, pp)}px ${Math.max(mix(18, 7, pp), 0)}px ${black(clamp(mix(0.38, 0.3, pp)))}`,
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: GLASS.h / 2, overflow: "hidden", isolation: "isolate" }}>
            <div
              style={{
                position: "absolute",
                left: (GLASS.w - CARD.w) / 2,
                top: (GLASS.h - CARD.h) / 2,
                width: CARD.w,
                height: CARD.h,
                transform: `translate(${-lx * refraction * 44}px, ${-ly * refraction * 26}px) scale(${1.18 + 0.06 * pp})`,
                filter: `blur(${Math.max(mix(0.5, 1.6, pp), 0) * 0.6}px) saturate(1.25)`,
              }}
            >
              <Backdrop />
            </div>
            <div style={{ position: "absolute", inset: 0, background: white(0.1 * (1 - p01)) }} />
            <div style={{ position: "absolute", inset: 0, background: black(0.16 * p01) }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: GLASS.h / 2,
                boxSizing: "border-box",
                border: `${inner}px solid ${black(clamp(mix(0.28, 0.5, pp)))}`,
                filter: `blur(${Math.max(mix(6, 8, pp), 0) * 0.6}px)`,
                transform: `translateY(${mix(1, 3, pp)}px)`,
              }}
            />
            <div
              style={{
                position: "absolute",
                left: GLASS.w / 2 + spot.x - width / 2,
                top: GLASS.h / 2 + spot.y - width / 2,
                width,
                height: width,
                borderRadius: "50%",
                background: `radial-gradient(circle closest-side, ${white(peak)} 0%, ${white(peak * 0.45)} 30%, transparent 100%)`,
                transform: `scaleY(${mix(0.4, 0.32, pp)})`,
                mixBlendMode: "plus-lighter",
              }}
            />
            <div style={{ position: "absolute", inset: 0, WebkitMaskImage: farMask, maskImage: farMask, mixBlendMode: "plus-lighter" }}>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: GLASS.h / 2,
                  boxSizing: "border-box",
                  border: `3.5px solid ${white(clamp(intensity * 0.75))}`,
                  filter: "blur(1.6px)",
                }}
              />
            </div>
            <div
              style={{
                position: "absolute",
                inset: 0,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 8,
                color: "#fff",
                fontSize: 20,
                fontWeight: 600,
                filter: `drop-shadow(0 1px 1.5px ${black(0.35)})`,
                transform: `translate(${-lx * 3}px, ${-ly * 2}px)`,
              }}
            >
              <span>{ctx.t("Continue", "继续")}</span>
              <ArrowRight size={22} strokeWidth={2.5} />
            </div>
            {st >= 0 && travel < 0.999 && (
              <div
                style={{
                  position: "absolute",
                  left: GLASS.w / 2 - 35,
                  top: GLASS.h / 2 - GLASS.h,
                  width: 70,
                  height: GLASS.h * 2,
                  background: `linear-gradient(90deg, transparent, ${white(0.55)}, transparent)`,
                  transform: `translateX(${travel * (GLASS.w / 2 + 60)}px) rotate(20deg)`,
                  opacity: 1 - Math.abs(travel) * 0.6,
                  mixBlendMode: "plus-lighter",
                }}
              />
            )}
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: GLASS.h / 2,
              padding: 1.4,
              background: rim,
              WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
              WebkitMaskComposite: "xor",
              mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              pointerEvents: "none",
            }}
          />
        </div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Drag across the glass, then tap it" zh="在玻璃上拖动，再点一下" style={{ paddingBottom: 18 }} />
    </div>
  );
}
