/** feedback.counter-badge · 弹性计数角标 (Feedback+CounterBadge.swift) */
import { motion, type Transition } from "motion/react";
import { useId, useLayoutEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track } from "./shared";

/** The preview's script: 1, 2, 9, 10 (stretch), 99, 99+ (stretch), poof. */
const SCRIPT = [1, 1, 7, 1, 89, 1, 0];
const POOF = 0.45;

export default function CounterBadge({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  // Previews start empty and build up; the detail page starts with a count.
  const [count, setCount] = useState(ctx.isPreview ? 0 : 3);
  const [poofing, setPoofing] = useState(false);
  const [pops, setPops] = useState(0);
  const [poofs, setPoofs] = useState(0);
  const [motionT, setMotionT] = useState<Transition>({ duration: 0 });
  const live = useRef({ count: ctx.isPreview ? 0 : 3, poofing: false, step: 0 });

  const cap = [9, 99, 999][ctx.i("cap")] ?? 99;
  const label = count > cap ? `${cap}+` : `${count}`;
  const pop = ctx.n("pop");
  const puffs = Math.max(ctx.i("puffs"), 1);

  const add = (amount: number) => {
    clearAll();
    const appearing = live.current.count === 0 || live.current.poofing;
    live.current.poofing = false;
    live.current.count = Math.min(live.current.count + amount, 9999);
    setMotionT(spring(0.35, appearing ? 0.5 : ctx.n("damping")));
    setPoofing(false);
    setCount(live.current.count);
    // A badge that springs in from zero already bounces; the pop is for increments.
    if (!appearing) setPops((p) => p + 1);
    haptics.tap("light");
  };

  const clear = () => {
    if (live.current.count <= 0 || live.current.poofing) return;
    clearAll();
    live.current.poofing = true;
    setMotionT(anim.easeOut(0.14));
    setPoofing(true);
    setPoofs((p) => p + 1);
    haptics.tap("soft");
    after(0.2, () => {
      // The badge is invisible now: drop the count without animating it.
      live.current.count = 0;
      live.current.poofing = false;
      setMotionT({ duration: 0 });
      setCount(0);
      setPoofing(false);
    });
  };

  const autoStep = () => {
    if (!ctx.isPreview) {
      // The detail page's arrival play: a single increment.
      add(1);
      return;
    }
    const step = SCRIPT[live.current.step % SCRIPT.length];
    live.current.step += 1;
    if (step === 0) clear();
    else add(step);
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 0.95, delay: 0.5 });

  // The capsule is sized by its text: measure the label and stretch to it.
  const measure = useRef<HTMLSpanElement>(null);
  const [width, setWidth] = useState(34);
  useLayoutEffect(() => {
    if (measure.current) setWidth(Math.max(34, measure.current.offsetWidth + 18));
  }, [label]);

  // keyframeAnimators keyed on the pop counter.
  const e = useElapsed(pops, 1.3, true);
  const scale = e < 0 ? 1 : track(e, 1, [{ cubic: pop, d: 0.1 }, { cubic: 0.94, d: 0.12 }, { spring: 1, d: 0.4, ...SPRINGS.bouncy }]);
  const squash = e < 0 ? 0 : track(e, 0, [{ cubic: 0.12, d: 0.06 }, { cubic: -0.08, d: 0.1 }, { spring: 0, d: 0.4, ...SPRINGS.bouncy }]);
  const hop = e < 0 ? 0 : track(e, 0, [{ cubic: -6, d: 0.1 }, { spring: 0, d: 0.45, ...SPRINGS.bouncy }]);
  const rock = e < 0 ? 0 : track(e, 0, [{ cubic: 5, d: 0.09 }, { cubic: -2.5, d: 0.12 }, { spring: 0, d: 0.35, ...SPRINGS.bouncy }]);

  // The poof's 0 → 1 clock.
  const p = useElapsed(poofs, POOF, true);
  const clock = p < 0 ? 1 : Math.min(p / POOF, 1);
  const poofLive = clock > 0.001 && clock < 0.999;
  const eased = 1 - (1 - clock) ** 3;

  const visible = count > 0 && !poofing;
  const badgeFont = { fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 700, fontVariantNumeric: "tabular-nums" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 30 }}>
      <div onClick={() => add(1)} style={{ position: "relative", width: 124, height: 124, marginTop: 18, flexShrink: 0, cursor: "pointer" }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 30,
            background: `linear-gradient(${white(0.3)}, ${white(0)} 50%), linear-gradient(${hex(0x5ac8fa)}, ${hex(0x0a7aff)})`,
            boxShadow: `0 9px 16px ${hex(0x0a7aff, 0.35)}`,
            display: "grid",
            placeItems: "center",
            transform: `rotate(${rock}deg)`,
            transformOrigin: "50% 100%",
          }}
        >
          <Envelope />
        </div>
        {/* Trailing edge anchored outside the icon's corner, so the badge grows leftward. */}
        <div style={{ position: "absolute", right: -16, top: -14, height: 34 }}>
          <motion.div initial={false} animate={{ width }} transition={motionT} style={{ position: "relative", height: 34, width }}>
            {/* Poof: an expanding ring and puffs, centred on the badge. */}
            <div style={{ position: "absolute", left: "50%", top: 17, width: 0, height: 0, opacity: poofLive ? 1 : 0, pointerEvents: "none" }}>
              <div
                style={{
                  position: "absolute",
                  width: 34 + 38 * eased,
                  height: 34 + 38 * eased,
                  left: -(34 + 38 * eased) / 2,
                  top: -(34 + 38 * eased) / 2,
                  borderRadius: "50%",
                  border: `${3 * (1 - clock) + 0.5}px solid ${hex(0xff2d55, 0.7 * (1 - clock))}`,
                }}
              />
              {Array.from({ length: puffs }, (_, index) => {
                const noise = Math.abs(Math.sin(index * 12.9898 + 1.1));
                const angle = (index / puffs) * 2 * Math.PI + noise * 0.6;
                const reach = 26 + 16 * noise;
                const size = (10 + 8 * noise) * (1 - clock * 0.8);
                return (
                  <div
                    key={index}
                    style={{
                      position: "absolute",
                      width: size,
                      height: size,
                      left: -size / 2 + Math.cos(angle) * reach * eased,
                      top: -size / 2 + Math.sin(angle) * reach * eased,
                      borderRadius: "50%",
                      background: index % 2 === 0 ? hex(0xff2d55) : hex(0xff6b6b),
                      opacity: 1 - clock * clock,
                    }}
                  />
                );
              })}
            </div>
            <motion.div
              initial={false}
              animate={{ scale: poofing ? 1.35 : count > 0 ? 1 : 0.01, opacity: visible ? 1 : 0, filter: poofing ? "blur(4px)" : "blur(0px)" }}
              transition={motionT}
              style={{ position: "absolute", inset: 0 }}
            >
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: 17,
                  background: `linear-gradient(${hex(0xff6259)}, ${hex(0xff2d55)})`,
                  boxShadow: `0 3px 6px ${hex(0xff2d55, 0.45)}`,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "#fff",
                  whiteSpace: "nowrap",
                  transform: `translateY(${hop}px) scale(${scale * (1 + squash)}, ${scale * (1 - squash)})`,
                  ...badgeFont,
                }}
              >
                <NumericText value={count} text={label} />
              </div>
            </motion.div>
          </motion.div>
          <span ref={measure} aria-hidden style={{ position: "absolute", visibility: "hidden", pointerEvents: "none", whiteSpace: "nowrap", ...badgeFont }}>
            {label}
          </span>
        </div>
      </div>
      <div style={{ display: "flex", gap: 10, flexShrink: 0 }}>
        <Chip title="+1" onClick={() => add(1)} />
        <Chip title="+10" onClick={() => add(10)} />
        <Chip title={zh ? "全部已读" : "Mark read"} onClick={clear} />
      </div>
      <DemoHint ctx={ctx} en="Tap the icon or the buttons" zh="点击图标或下方按钮" />
    </div>
  );
}

function Chip({ title, onClick }: { title: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        height: 38,
        padding: "0 16px",
        borderRadius: 19,
        background: Palette.elevated,
        boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
        fontSize: 15,
        lineHeight: "20px",
        fontWeight: 600,
        fontVariantNumeric: "tabular-nums",
        whiteSpace: "nowrap",
      }}
    >
      {title}
    </button>
  );
}

/** `envelope.fill` at 54 pt: a solid envelope with the flap and fold lines knocked out. */
function Envelope() {
  const id = useId();
  return (
    <svg width={66} height={49} viewBox="0 0 66 49">
      <defs>
        <mask id={id}>
          <rect width={66} height={49} rx={8} fill="#fff" />
          <g fill="none" stroke="#000" strokeWidth={3.6} strokeLinecap="round" strokeLinejoin="round">
            <path d="M1.5 4 L28.5 28 Q33 31.6 37.5 28 L64.5 4" />
            <path d="M1.5 46 L24 25.5" />
            <path d="M64.5 46 L42 25.5" />
          </g>
        </mask>
      </defs>
      <rect width={66} height={49} fill="#fff" mask={`url(#${id})`} />
    </svg>
  );
}
