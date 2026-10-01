/** cards.number-reveal · 卡号显隐 (Cards+NumberReveal.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Nfc, Sparkle } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { Palette, anim, black, clamp, fonts, hex, spring, useAutoplay, useClock, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, persp, useMV } from "./shared";
import { track, useLatchedPress } from "./_kit";

/** 12 masked number characters + 3 CVV characters. */
const MASKED = 15;
const NUMBER = "541275349021";
const CVV = "372";
const now = () => performance.now() / 1000;

export default function NumberReveal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [revealed, setRevealedState] = useState(false);
  const revealedRef = useRef(false);
  const changedAt = useRef(-1e6);
  const [animating, setAnimating] = useState(false);
  const [shows, setShows] = useState(0);
  const ring = useMotionValue(0);
  const script = useTimeouts();
  const [pressed, press] = useLatchedPress();
  useClock(animating, ctx.isPreview ? 30 : undefined);

  const setRevealed = (value: boolean, muted: boolean) => {
    const stagger = ctx.n("stagger");
    const autoHide = ctx.n("autoHide");
    revealedRef.current = value;
    setRevealedState(value);
    changedAt.current = now();
    setAnimating(true);
    script.clearAll();
    ring.stop();
    if (value) {
      setShows((s) => s + 1);
      ring.jump(1);
    } else {
      animate(ring, 0, anim.easeOut(0.2));
    }
    // Until the last cell has settled (plus its pop / roll).
    const total = value ? (MASKED - 1) * stagger + ctx.n("scramble") + 0.2 : (MASKED - 1) * stagger * 0.6 + 0.3;
    script.after(total, () => {
      setAnimating(false);
      if (!value) return;
      if (!muted) haptics.success();
      // The preview loop hides it on its own beat; on the detail page the ring counts down.
      if (!(autoHide > 0) || ctx.isPreview) {
        animate(ring, 0, anim.easeOut(0.3));
        return;
      }
      animate(ring, 0, anim.linear(autoHide));
      script.after(autoHide, () => setRevealed(false, false));
    });
  };
  const toggle = (muted: boolean) => setRevealed(!revealedRef.current, muted);

  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.3 });

  const elapsed = now() - changedAt.current;
  const fx = useElapsed(shows, 1.6, true);
  const tilt = fx < 0 ? 0 : track(fx, 0, [{ cubic: -9, d: 0.3 }, { cubic: 4, d: 0.35 }, { spring: 0, d: 0.45, response: 0.35, damping: 0.7 }]);
  const sweep = fx < 0 ? 1.3 : track(fx, 1.3, [{ move: -1.3 }, { cubic: 1.3, d: 0.9 }]);
  const ringValue = useMV(ring);
  const stagger = ctx.n("stagger");
  const scramble = ctx.n("scramble");

  /** One masked character: a dot, a flickering random digit, or the real digit. */
  const cell = (index: number, character: string, size: number, width: number): ReactNode => {
    let scrambling = false;
    let digitOpacity = 0;
    let digitScale = 1;
    let digitOffset = 0;
    let dotOpacity = 1;
    let dotOffset = 0;
    if (revealed) {
      const start = index * stagger;
      const lock = start + scramble;
      if (elapsed >= start) {
        dotOpacity = 0;
        if (elapsed < lock) {
          scrambling = true;
          digitOpacity = 0.7;
        } else {
          digitOpacity = 1;
          const pop = Math.max(0, 1 - (elapsed - lock) / 0.18);
          digitScale = 1 + 0.3 * pop * pop;
        }
      }
    } else {
      const start = (14 - index) * stagger * 0.6;
      const p = clamp((elapsed - start) / 0.22);
      const eased = p * p * (3 - 2 * p);
      digitOpacity = 1 - eased;
      digitOffset = -12 * eased;
      dotOpacity = eased;
      dotOffset = 12 * (1 - eased);
    }
    let glyph = character;
    if (scrambling) {
      const tick = Math.floor(elapsed / 0.045);
      glyph = String(Math.abs(index * 7919 + tick * 104729 + index * tick * 31) % 10);
    }
    return (
      <div key={index} style={{ position: "relative", width, height: "100%", display: "grid", placeItems: "center", flexShrink: 0 }}>
        <span style={{ gridArea: "1 / 1", fontFamily: fonts.mono, fontSize: size, lineHeight: 1, fontWeight: 600, opacity: digitOpacity, transform: `translateY(${digitOffset}px) scale(${digitScale})` }}>{glyph}</span>
        <div style={{ gridArea: "1 / 1", width: size * 0.3, height: size * 0.3, borderRadius: "50%", background: "currentColor", opacity: dotOpacity, transform: `translateY(${dotOffset}px)` }} />
      </div>
    );
  };

  const caption = (title: string) => <span style={{ fontSize: 7.5, lineHeight: "9px", fontWeight: 600, letterSpacing: 1, opacity: 0.6 }}>{title}</span>;
  const label = (title: string, value: string) => (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3 }}>
      {caption(title)}
      <span style={{ fontFamily: fonts.mono, fontSize: 11.5, lineHeight: "14px", fontWeight: 600 }}>{value}</span>
    </div>
  );

  return (
    <Stage gap={22}>
      <div style={{ width: 286, height: 180, flexShrink: 0, borderRadius: 20, transform: `${persp(286, 180, 0.5)} rotateY(${tilt}deg)`, boxShadow: `0 14px 20px ${black(0.3)}` }}>
        <div style={{ position: "relative", width: 286, height: 180, borderRadius: 20, overflow: "hidden", isolation: "isolate", background: diag(["#262A44", "#10111A"]) }}>
          <div style={{ position: "absolute", left: 143 - 105 + 120, top: 90 - 105 - 90, width: 210, height: 210, borderRadius: "50%", background: hex(0x6e7bff, 0.55), filter: "blur(46px)" }} />
          <div style={{ position: "absolute", left: 143 - 85 - 130, top: 90 - 85 + 100, width: 170, height: 170, borderRadius: "50%", background: hex(0xff5fa2, 0.3), filter: "blur(50px)" }} />
          <div style={{ position: "absolute", inset: 0, padding: 20, display: "flex", flexDirection: "column", alignItems: "flex-start", color: "#fff" }}>
            <div style={{ alignSelf: "stretch", display: "flex", alignItems: "center", gap: 6, height: 20 }}>
              <Sparkle size={14} fill="currentColor" strokeWidth={1.5} />
              <span style={{ fontFamily: fonts.rounded, fontSize: 16, lineHeight: "19px", fontWeight: 700 }}>Aurora</span>
              <span style={{ flex: 1 }} />
              <Nfc size={17} strokeWidth={2.2} style={{ opacity: 0.8 }} />
            </div>
            <span style={{ flex: 1 }} />
            <div style={{ width: 36, height: 26, borderRadius: 5, background: diag(["#F7E3A1", "#C9A24B"]), display: "flex", flexDirection: "column", justifyContent: "center", gap: 5, padding: "0 4px", flexShrink: 0 }}>
              {[0, 1, 2].map((i) => (
                <div key={i} style={{ height: 0.8, background: black(0.18) }} />
              ))}
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: 11, height: 24, marginTop: 14, flexShrink: 0 }}>
              {[0, 1, 2].map((group) => (
                <div key={group} style={{ display: "flex", height: "100%" }}>
                  {[0, 1, 2, 3].map((k) => cell(group * 4 + k, NUMBER[group * 4 + k], 19, 12))}
                </div>
              ))}
              <span style={{ fontFamily: fonts.mono, fontSize: 19, lineHeight: 1, fontWeight: 600, letterSpacing: 0.5, whiteSpace: "nowrap" }}>4821</span>
            </div>
            <div style={{ alignSelf: "stretch", display: "flex", alignItems: "flex-end", marginTop: 12, flexShrink: 0 }}>
              {label("CARD HOLDER", "ALEX MORGAN")}
              <span style={{ flex: 1 }} />
              {label("EXP", "09/29")}
              <span style={{ flex: 1 }} />
              <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3 }}>
                {caption("CVV")}
                <div style={{ display: "flex", height: 14 }}>{[0, 1, 2].map((k) => cell(12 + k, CVV[k], 11.5, 9))}</div>
              </div>
            </div>
          </div>
          <StrokeBorder radius={20} color={`linear-gradient(to bottom right, ${white(0.45)}, ${white(0.05)})`} />
          {ctx.b("sweep") && (
            <div
              style={{
                position: "absolute",
                left: 143 - 48 + sweep * 230,
                top: 90 - 190,
                width: 96,
                height: 380,
                transform: "rotate(22deg)",
                background: `linear-gradient(to right, transparent, ${white(0.34)}, transparent)`,
                mixBlendMode: "plus-lighter",
                pointerEvents: "none",
              }}
            />
          )}
        </div>
      </div>
      <motion.button
        {...press}
        onClick={() => {
          haptics.tap("light");
          toggle(false);
        }}
        animate={{ scale: pressed ? 0.95 : 1 }}
        transition={spring(0.3, 0.6)}
        style={{
          height: 44,
          padding: "0 16px 0 10px",
          display: "flex",
          alignItems: "center",
          gap: 9,
          borderRadius: 22,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 8px ${black(0.08)}`,
          color: Palette.label,
          flexShrink: 0,
        }}
      >
        <div style={{ position: "relative", width: 26, height: 26, display: "grid", placeItems: "center" }}>
          <svg width={26} height={26} style={{ position: "absolute", inset: 0, overflow: "visible", transform: "rotate(-90deg)" }}>
            <circle cx={13} cy={13} r={13} fill="none" stroke={Palette.indigo} strokeWidth={2} strokeLinecap="round" pathLength={1} strokeDasharray={`${ringValue} 2`} opacity={ringValue > 0.001 ? 1 : 0} />
          </svg>
          <EyeGlyph slashed={revealed} />
        </div>
        <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{revealed ? ctx.t("Hide number", "隐藏卡号") : ctx.t("Show number", "显示卡号")}</span>
      </motion.button>
    </Stage>
  );
}

/** `eye.fill` / `eye.slash.fill`. */
function EyeGlyph({ slashed }: { slashed: boolean }) {
  return (
    <svg width={16} height={16} viewBox="0 0 24 24" style={{ position: "relative" }}>
      <path d="M1.5 12C3.6 7.4 7.5 4.8 12 4.8s8.4 2.6 10.5 7.2c-2.1 4.6-6 7.2-10.5 7.2S3.6 16.6 1.5 12Z" fill="currentColor" />
      <circle cx={12} cy={12} r={4.4} fill={Palette.elevated} />
      <circle cx={12} cy={12} r={2.5} fill="currentColor" />
      {slashed && (
        <>
          <line x1={4} y1={3} x2={20} y2={21} stroke={Palette.elevated} strokeWidth={5} strokeLinecap="round" />
          <line x1={4.5} y1={3.5} x2={19.5} y2={20.5} stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" />
        </>
      )}
    </svg>
  );
}
