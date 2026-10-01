/** feedback.silent-hud · 静音提示 HUD (Feedback+SilentHUD.swift) */
import { motion, useTransform, type Transition } from "motion/react";
import { Bell } from "lucide-react";
import { useLayoutEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track, useAnimated } from "./shared";

const RED = hex(0xff453a);
const SLASH = 22 * Math.SQRT2;
const WAVE = 0.7;
const LEVEL_SPRING = spring(0.5, 0.8);

export default function SilentHUD({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [silent, setSilent] = useState(false);
  const [shown, setShown] = useState(false);
  const [shownT, setShownT] = useState<Transition>(spring(0.45, 0.7));
  const [swings, setSwings] = useState(0);
  const [waves, setWaves] = useState(0);
  const [flips, setFlips] = useState(0);
  const live = useRef({ silent: false, shown: false });
  const [slash, slashTo] = useAnimated(0);

  const flip = () => {
    clearAll();
    const dismiss = ctx.n("dismiss");
    const wasShown = live.current.shown;
    const goingSilent = !live.current.silent;
    haptics.tap("rigid");
    live.current.shown = true;
    setShownT(spring(0.45, ctx.n("damping")));
    setShown(true);
    const react = () => {
      setSwings((s) => s + 1);
      live.current.silent = goingSilent;
      setSilent(goingSilent);
      setFlips((f) => f + 1);
      slashTo(goingSilent ? 1 : 0, anim.easeOut(0.28));
      if (!goingSilent) setWaves((w) => w + 1);
      after(dismiss, () => {
        live.current.shown = false;
        setShownT(anim.easeIn(0.25));
        setShown(false);
      });
    };
    // A fresh pill lands first; one that is already down reacts at once.
    if (wasShown) react();
    else after(0.12, react);
  };

  useAutoplay(ctx.isPreview, flip, { every: ctx.n("dismiss") + 0.8, delay: 0.5 });

  // The bell swings around its top through decaying angles.
  const angle = ctx.n("swing");
  const e = useElapsed(swings, 1.6, true);
  const swing =
    e < 0
      ? 0
      : track(e, 0, [
          { cubic: angle, d: 0.14 },
          { cubic: -angle * 0.71, d: 0.2 },
          { cubic: angle * 0.43, d: 0.2 },
          { cubic: -angle * 0.21, d: 0.2 },
          { spring: 0, d: 0.3, ...SPRINGS.smooth },
        ]);
  const w = useElapsed(waves, WAVE, true);
  const clock = w < 0 ? 1 : Math.min(w / WAVE, 1);

  const slashOffset = useTransform(slash, (p) => SLASH * (1 - Math.min(Math.max(p, 0), 1)));
  // Round caps leave a dot at trim 0 in SVG; SwiftUI draws nothing there.
  const slashOpacity = useTransform(slash, (p) => (p > 0.001 ? 1 : 0));

  const tint = silent ? RED : "#fff";
  const label = silent ? (zh ? "静音" : "Silent") : zh ? "响铃" : "Ring";
  const level = silent ? 0 : ctx.n("level");

  // The pill is sized by its content: the label's width springs along with the switch.
  const ruler = useRef<HTMLSpanElement>(null);
  const [labelWidth, setLabelWidth] = useState<number | null>(null);
  useLayoutEffect(() => {
    if (ruler.current) setLabelWidth(ruler.current.offsetWidth + 1);
  }, [label]);
  const labelFont = { fontSize: 16, lineHeight: "21px", fontWeight: 600, whiteSpace: "nowrap" } as const;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div onClick={flip} style={{ position: "relative", width: 280, height: 300, flexShrink: 0, borderRadius: 34, boxShadow: `0 10px 18px ${black(0.18)}`, cursor: "pointer" }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, overflow: "hidden" }}>
          {/* Wallpaper */}
          <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${hex(0x1b1f4b)}, ${hex(0x5b3a8c)}, ${hex(0xe0708a)}, ${hex(0xffb36b)})` }} />
          <div style={{ position: "absolute", left: 65, top: 185, width: 150, height: 150, borderRadius: "50%", background: hex(0xffd9a0, 0.5), filter: "blur(40px)" }} />
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", transform: "translateY(-20px)" }}>
            <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, color: white(0.85), whiteSpace: "nowrap" }}>{zh ? "9月30日 星期三" : "Wednesday, September 30"}</span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 72, lineHeight: "86px", fontWeight: 600, color: "#fff" }}>9:41</span>
          </div>
          {/* HUD */}
          <div style={{ position: "absolute", left: 0, right: 0, top: 14, display: "flex", justifyContent: "center" }}>
            <motion.div
              initial={false}
              animate={{ scale: shown ? 1 : 0.6, opacity: shown ? 1 : 0, y: shown ? 0 : -70, filter: shown ? "blur(0px)" : "blur(6px)" }}
              transition={shownT}
              style={{
                height: 50,
                paddingLeft: 14,
                paddingRight: 20,
                borderRadius: 25,
                background: "#000",
                boxShadow: `inset 0 0 0 0.5px ${white(0.12)}, 0 8px 14px ${black(0.35)}`,
                display: "flex",
                alignItems: "center",
                gap: 8,
              }}
            >
              {/* Bell */}
              <div style={{ position: "relative", width: 36, height: 28, flexShrink: 0, transform: `rotate(${swing}deg)`, transformOrigin: "50% 0%" }}>
                <Waves clock={clock} />
                <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: tint, transition: "color 0.3s ease-out" }}>
                  <Bell size={22} fill="currentColor" strokeWidth={2} />
                </div>
                {/* Knock-out under the slash, then the slash itself. */}
                <motion.svg width={28} height={28} viewBox="0 0 28 28" fill="none" strokeLinecap="round" style={{ position: "absolute", left: 4, top: 0, overflow: "visible", opacity: slashOpacity }}>
                  <motion.path d="M3 3 L25 25" stroke="#000" strokeWidth={5.5} strokeDasharray={SLASH} style={{ strokeDashoffset: slashOffset }} />
                  <motion.path d="M3 3 L25 25" stroke={tint} strokeWidth={2} strokeDasharray={SLASH} style={{ strokeDashoffset: slashOffset, transition: "stroke 0.3s ease-out" }} />
                </motion.svg>
              </div>
              <motion.div
                initial={false}
                animate={labelWidth === null ? undefined : { width: labelWidth }}
                transition={LEVEL_SPRING}
                style={{ ...labelFont, position: "relative", height: 21, flexShrink: 0, color: tint, transition: "color 0.3s ease-out", width: labelWidth ?? undefined }}
              >
                <NumericText value={flips} text={label} />
                <span ref={ruler} aria-hidden style={{ ...labelFont, position: "absolute", left: 0, top: 0, visibility: "hidden", pointerEvents: "none" }}>
                  {label}
                </span>
              </motion.div>
              {/* Level bar */}
              <div style={{ position: "relative", width: 72, height: 6, flexShrink: 0, borderRadius: 3, overflow: "hidden", background: white(0.22) }}>
                <motion.div initial={false} animate={{ width: Math.max(72 * level, 0) }} transition={LEVEL_SPRING} style={{ position: "absolute", left: 0, top: 0, height: 6, borderRadius: 3, background: "#fff" }} />
              </div>
            </motion.div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 34, boxShadow: `inset 0 0 0 3px ${Palette.labelAlpha(0.22)}`, pointerEvents: "none" }} />
        {/* The side switch: up for ring, down (showing orange) for silent. */}
        <div style={{ position: "absolute", left: -5, top: 62, width: 5, height: 26 }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: 2.5, background: hex(0xff9500) }} />
          <motion.div
            initial={false}
            animate={{ y: silent ? 9 : 0 }}
            transition={spring(0.22, 0.6)}
            style={{ position: "absolute", left: 0, top: 0, width: 5, height: 17, borderRadius: 2.5, background: ctx.scheme === "dark" ? hex(0xaeaeb2) : hex(0x8e8e93) }}
          />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to flip the ringer switch" zh="点击拨动静音键" />
    </div>
  );
}

/** Two arcs on each side of the bell that pulse outward when the ringer comes back on. */
function Waves({ clock }: { clock: number }) {
  const arc = (radius: number, from: number, to: number) => {
    const a = from * 2 * Math.PI;
    const b = to * 2 * Math.PI;
    return `M${Math.cos(a) * radius} ${Math.sin(a) * radius} A${radius} ${radius} 0 0 1 ${Math.cos(b) * radius} ${Math.sin(b) * radius}`;
  };
  return (
    <svg width={36} height={28} viewBox="-18 -14 36 28" fill="none" stroke="#fff" strokeWidth={1.6} strokeLinecap="round" style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" }}>
      {[0, 1].map((index) => {
        const u = Math.min(Math.max(clock * 1.4 - index * 0.4, 0), 1);
        const radius = 12 + index * 2.5 + 3 * u;
        return (
          <g key={index} opacity={u > 0 && u < 1 ? Math.sin(u * Math.PI) : 0}>
            <path d={arc(radius, -0.08, 0.08)} />
            <path d={arc(radius, 0.42, 0.58)} />
          </g>
        );
      })}
    </svg>
  );
}
