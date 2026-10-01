/** cards.levitate · 磁悬浮卡片 (Cards+Levitate.swift) */
import { useRef, useState } from "react";
import { DemoHint, clamp, useAutoplay, useClock, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { CreditCard, Stage, persp, themeColors } from "./shared";
import { track } from "./_kit";

const CARD = { w: 230, h: (230 * 158) / 250 };
const now = () => performance.now() / 1000;

export default function Levitate({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const hover = ctx.n("height");
  const body = useRef({ height: hover, velocity: 0, last: null as number | null, touchedGround: false });
  const pressed = useRef(false);
  const scripted = useRef(false);
  /** The scripted press of the preview / arrival play lands silently. */
  const silent = useRef(false);
  const touch = useRef({ x: 0, y: 0 });
  const [ripples, setRipples] = useState(0);
  const script = useTimeouts();
  useClock(true, ctx.isPreview ? 30 : undefined);

  // Semi-implicit Euler toward the target, once per frame.
  const t = now();
  {
    const b = body.current;
    const stiffness = pressed.current ? 520 : 150;
    const ratio = pressed.current ? 0.9 : ctx.n("damping");
    const damping = 2 * ratio * Math.sqrt(stiffness);
    const target = pressed.current ? -8 : hover;
    if (b.last !== null) {
      let remaining = Math.min(t - b.last, 1 / 20);
      let landed = false;
      while (remaining > 0.0001) {
        const dt = Math.min(remaining, 1 / 240);
        remaining -= dt;
        const force = -stiffness * (b.height - target) - damping * b.velocity;
        b.velocity += force * dt;
        b.height += b.velocity * dt;
        if (b.height < 0) {
          b.height = 0;
          b.velocity = Math.max(b.velocity, 0) * 0.2;
          if (!b.touchedGround) landed = true;
          b.touchedGround = true;
        }
      }
      if (b.height > 6) b.touchedGround = false;
      if (landed) {
        const quiet = silent.current;
        queueMicrotask(() => {
          setRipples((r) => r + 1);
          if (!quiet) haptics.tap("soft");
        });
      }
    }
    b.last = t;
  }

  const release = () => {
    if (!pressed.current || scripted.current) return;
    pressed.current = false;
    haptics.tap("light");
  };

  const pan = usePan({
    onChange: ({ location }) => {
      if (!pressed.current || scripted.current) {
        script.clearAll();
        scripted.current = false;
        silent.current = false;
        pressed.current = true;
      }
      touch.current = { x: clamp(location.x - CARD.w / 2, -CARD.w / 2, CARD.w / 2), y: clamp(location.y - CARD.h / 2, -CARD.h / 2, CARD.h / 2) };
    },
    onEnd: release,
  });

  useAutoplay(
    ctx.isPreview,
    () => {
      if (pressed.current) return;
      touch.current = { x: 54, y: 18 };
      pressed.current = true;
      scripted.current = true;
      silent.current = true;
      script.clearAll();
      script.after(0.75, () => {
        scripted.current = false;
        pressed.current = false;
      });
    },
    { every: 3.4, delay: 1.4 },
  );

  const base = body.current.height;
  const wall = Date.now() / 1000;
  // The bob fades out as the card is pushed down, so a grounded card lies still.
  const afloat = clamp(base / Math.max(hover, 1), 0, 1.4);
  const bob = ctx.n("bob") * afloat * Math.sin((wall * 2 * Math.PI) / ctx.n("period"));
  const height = Math.max(base + bob, 0);
  const lift = clamp(height / 60, 0, 1.2);
  const swayX = 3.2 * Math.sin((wall * 2 * Math.PI) / 5.3) * afloat;
  const swayY = 3.6 * Math.sin((wall * 2 * Math.PI) / 7.1 + 1.3) * afloat;
  const lean = 1 - clamp(afloat);
  const tiltX = swayX - (touch.current.y / (CARD.h / 2)) * 7 * lean;
  const tiltY = swayY + (touch.current.x / (CARD.w / 2)) * 7 * lean;
  const scale = 0.93 + 0.07 * clamp(height / Math.max(hover, 1), 0, 1.5);
  const p = persp(CARD.w, CARD.h, 0.5);

  const e = useElapsed(ripples, 0.6, true);
  const grow = e < 0 ? 0 : track(e, 0, [{ move: 0 }, { cubic: 1, d: 0.6 }]);
  const fade = e < 0 ? 0 : 0.55 * (1 - e / 0.6);

  const cx = 150;
  const cy = 143 + 26;
  const glowW = CARD.w * 0.9;
  const glowH = CARD.h * 0.8;
  const darkW = CARD.w * (0.96 - 0.1 * lift);
  const darkH = CARD.h * (0.94 - 0.14 * lift);

  return (
    <Stage>
      <div style={{ position: "relative", width: 300, height: 286, flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            left: cx - glowW / 2,
            top: cy - glowH / 2 + height * 0.5 + 6,
            width: glowW,
            height: glowH,
            borderRadius: 18,
            background: `linear-gradient(to right, ${themeColors(0).join(", ")})`,
            filter: "blur(26px)",
            opacity: 0.16 + 0.26 * lift,
          }}
        />
        <div
          style={{
            position: "absolute",
            left: cx - darkW / 2,
            top: cy - darkH / 2 + 4 + height * 0.62,
            width: darkW,
            height: darkH,
            borderRadius: 18,
            background: "#000",
            filter: `blur(${6 + 20 * lift}px)`,
            opacity: 0.5 - 0.27 * clamp(lift),
          }}
        />
        <div
          style={{
            position: "absolute",
            left: cx - CARD.w / 2 - 1,
            top: cy - CARD.h / 2 - 1 + 4,
            width: CARD.w + 2,
            height: CARD.h + 2,
            borderRadius: 23,
            border: `2px solid ${white(0.9)}`,
            transform: `scale(${1 + 0.24 * grow})`,
            opacity: fade,
            filter: `blur(${1 + 5 * grow}px)`,
            mixBlendMode: "plus-lighter",
            pointerEvents: "none",
          }}
        />
        <div {...pan} style={{ position: "absolute", left: cx - CARD.w / 2, top: cy - CARD.h / 2, width: CARD.w, height: CARD.h, transform: `translateY(${-height * 0.72}px) scale(${scale})`, touchAction: "none", cursor: "pointer" }}>
          <div style={{ transform: `${p} rotateY(${tiltY}deg)` }}>
            <div style={{ transform: `${p} rotateX(${tiltX}deg)` }}>
              <CreditCard theme={0} width={CARD.w} last4="2048" />
            </div>
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Press and hold the card" zh="按住卡片" />
    </Stage>
  );
}
