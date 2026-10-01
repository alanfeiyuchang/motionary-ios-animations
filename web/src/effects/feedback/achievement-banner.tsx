/** feedback.achievement-banner · 成就横幅 (Feedback+AchievementBanner.swift) */
import { Check } from "lucide-react";
import { motion, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, delayed, demoCard, ease, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { SPRINGS, track, type Keyframe } from "./shared";

const GOLD = 0xffd66b;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const INSTANT: Transition = { duration: 0 };

/** `AchievementSparkShape`: a four-point star in a `size` box. */
function sparkPath(size: number) {
  const r = size / 2;
  const inner = r * 0.26;
  let d = "";
  for (let step = 0; step < 8; step++) {
    const angle = (step * Math.PI) / 4 - Math.PI / 2;
    const radius = step % 2 === 0 ? r : inner;
    d += `${step === 0 ? "M" : "L"}${(r + Math.cos(angle) * radius).toFixed(2)} ${(r + Math.sin(angle) * radius).toFixed(2)} `;
  }
  return `${d}Z`;
}

export default function AchievementBanner({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const [shown, setShown] = useState(false);
  const [shownT, setShownT] = useState<Transition>(spring(0.5, 0.78));
  const [medalShown, setMedalShown] = useState(false);
  const [lettersIn, setLettersIn] = useState(false);
  const [checkedIn, setCheckedIn] = useState(false);
  const [checkT, setCheckT] = useState<Transition>(spring(0.35, 0.5));
  const [drops, setDrops] = useState(0);
  const [impacts, setImpacts] = useState(0);
  const live = useRef({ shown: false, checkedIn: false });

  const play = (buzz = true) => {
    clearAll();
    const hold = ctx.n("hold");
    const preview = ctx.isPreview;
    if (buzz) haptics.tap();
    const run = () => {
      live.current = { shown: false, checkedIn: true };
      setCheckT(spring(0.35, 0.5));
      setCheckedIn(true);
      after(0.35, () => {
        live.current.shown = true;
        setShownT(spring(0.5, 0.78));
        setShown(true);
        after(0.15, () => {
          setMedalShown(true);
          setDrops((n) => n + 1);
          setLettersIn(true);
          // The medal touches down 0.28 s into its fall.
          after(0.28, () => {
            setImpacts((n) => n + 1);
            if (buzz) haptics.tap("medium");
            after(hold, () => {
              live.current.shown = false;
              setShownT(anim.easeIn(0.3));
              setShown(false);
              after(0.35, () => {
                setMedalShown(false);
                setLettersIn(false);
                if (!preview) return;
                live.current.checkedIn = false;
                setCheckT(anim.smoothD(0.3));
                setCheckedIn(false);
              });
            });
          });
        });
      });
    };
    if (live.current.shown || live.current.checkedIn) {
      // Replay: clear the previous run first.
      live.current = { shown: false, checkedIn: false };
      setShownT(anim.easeIn(0.2));
      setCheckT(anim.easeIn(0.2));
      setShown(false);
      setCheckedIn(false);
      after(0.3, () => {
        setMedalShown(false);
        setLettersIn(false);
        // Let the cleared state commit before the next run starts from it.
        after(0.02, run);
      });
    } else run();
  };

  useAutoplay(ctx.isPreview, () => play(false), { every: ctx.n("hold") + 3.2, delay: 0.4 });

  // Medal: a real floor bounce (linear keyframes on ease-in/ease-out curves) plus a squash track.
  const bounce = ctx.n("bounce");
  const d = useElapsed(drops, 1.6, true);
  const yTrack: Keyframe[] = [
    { move: -150 },
    { linear: 0, d: 0.28, curve: ease.in },
    { linear: -bounce, d: 0.14, curve: ease.out },
    { linear: 0, d: 0.14, curve: ease.in },
    { linear: -bounce * 0.32, d: 0.09, curve: ease.out },
    { linear: 0, d: 0.09, curve: ease.in },
  ];
  const medalY = d < 0 ? 0 : track(d, 0, yTrack);
  const medalTurn = d < 0 ? 0 : track(d, 0, [{ move: -70 }, { linear: 0, d: 0.28, curve: ease.out }]);
  const squash =
    d < 0
      ? 1
      : track(d, 1, [
          { move: 1.08 },
          { linear: 1.08, d: 0.25 },
          { cubic: 0.8, d: 0.05 },
          { cubic: 1.05, d: 0.12 },
          { cubic: 1.0, d: 0.11 },
          { cubic: 0.92, d: 0.05 },
          { spring: 1, d: 0.3, ...SPRINGS.bouncy },
        ]);

  const m = useElapsed(impacts, 1.3, true);
  const dip = m < 0 ? 0 : track(m, 0, [{ cubic: 5, d: 0.07 }, { spring: 0, d: 0.45, ...SPRINGS.bouncy }]);
  const sweep = m < 0 ? -1 : track(Math.min(m, 0.7), -1, [{ move: -1 }, { cubic: 1, d: 0.7 }]);
  // 0 → 1 over the 0.9 s burst, 1 (finished) the rest of the time.
  const clock = m < 0 ? 1 : Math.min(m / 0.9, 1);

  const count = Math.max(ctx.i("sparkles"), 1);
  const stagger = ctx.n("stagger");
  const title = zh ? "连续打卡 7 天" : "7-Day Streak";
  const days = zh ? ["一", "二", "三", "四", "五", "六", "日"] : ["M", "T", "W", "T", "F", "S", "S"];

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ position: "relative", width: 320, height: 300, flexShrink: 0 }}>
        {/* Streak card */}
        <div style={{ ...demoCard(26), position: "absolute", left: 20, top: 116, width: 280, padding: "18px 0", display: "flex", flexDirection: "column", alignItems: "center", gap: 14 }}>
          <div style={{ width: 236, display: "flex", alignItems: "baseline", fontSize: 15, lineHeight: "20px" }}>
            <span style={{ fontWeight: 600 }}>{zh ? "本周打卡" : "This week"}</span>
            <div style={{ flex: 1 }} />
            <span style={{ display: "flex", fontWeight: 700, color: Palette.coral, fontVariantNumeric: "tabular-nums" }}>
              <NumericText value={checkedIn ? 7 : 6} />
              /7
            </span>
          </div>
          <div style={{ display: "flex", gap: 9 }}>
            {days.map((day, index) => {
              const filled = index < 6 || checkedIn;
              return (
                <div key={index} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 5 }}>
                  <div style={{ position: "relative", width: 26, height: 26, borderRadius: 13, background: Palette.labelAlpha(0.08) }}>
                    <motion.div initial={false} animate={{ scale: filled ? 1 : 0.01, opacity: filled ? 1 : 0 }} transition={checkT} style={{ position: "absolute", inset: 0, borderRadius: 13, background: Palette.sunset }} />
                    <motion.div initial={false} animate={{ scale: filled ? 1 : 0.2, opacity: filled ? 1 : 0 }} transition={checkT} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff" }}>
                      <Check size={13} strokeWidth={4} />
                    </motion.div>
                  </div>
                  <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel }}>{day}</span>
                </div>
              );
            })}
          </div>
          <button type="button" onClick={() => play()} style={{ width: 236, height: 40, borderRadius: 20, background: PRIMARY_STRONG, color: "#fff", fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>
            {zh ? "签到" : "Check in"}
          </button>
        </div>

        {/* Banner */}
        <motion.div
          initial={false}
          animate={{ scale: shown ? 1 : 0.86, opacity: shown ? 1 : 0, y: shown ? 0 : -130 }}
          transition={shownT}
          style={{ position: "absolute", left: 12, top: 14, width: 296, height: 84, pointerEvents: "none" }}
        >
          <div
            style={{
              position: "absolute",
              inset: 0,
              transform: `translateY(${dip}px)`,
              borderRadius: 26,
              background: `linear-gradient(${90 + (Math.atan2(84, 296) * 180) / Math.PI}deg, ${hex(0x2a2b45)}, ${hex(0x12121c)})`,
              boxShadow: `0 10px 18px ${black(0.3)}`,
              display: "flex",
              alignItems: "center",
              gap: 14,
              padding: "0 12px 0 16px",
            }}
          >
            {/* Medal slot */}
            <div style={{ position: "relative", width: 58, height: 58, flexShrink: 0 }}>
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: black(0.28) }} />
              {Array.from({ length: count }, (_, index) => {
                const noise = Math.abs(Math.sin(index * 12.9898 + 4.1));
                // Each sparkle lives 0.5 s inside the 0.9 s clock.
                const u = Math.min(Math.max((clock * 0.9 - noise * 0.36) / 0.5, 0), 1);
                if (u <= 0 || u >= 1) return null;
                const angle = (index / count) * 2 * Math.PI + noise * 0.5;
                const radius = 30 + 14 * Math.abs(Math.sin(index * 7.31)) + 10 * u;
                const size = index % 3 === 0 ? 20 : 13;
                return (
                  <svg
                    key={index}
                    width={size}
                    height={size}
                    viewBox={`0 0 ${size} ${size}`}
                    style={{
                      position: "absolute",
                      left: 29 - size / 2,
                      top: 29 - size / 2,
                      zIndex: 2,
                      transform: `translate(${Math.cos(angle) * radius}px, ${Math.sin(angle) * radius}px) rotate(${u * 90}deg) scale(${Math.sin(u * Math.PI)})`,
                    }}
                  >
                    <path d={sparkPath(size)} fill={index % 2 === 0 ? "#fff" : hex(GOLD)} />
                  </svg>
                );
              })}
              <div style={{ position: "absolute", left: 2, top: 2, width: 54, height: 54, zIndex: 3, opacity: medalShown ? 1 : 0, transform: `translateY(${medalY}px) rotate(${medalTurn}deg)` }}>
                <div style={{ width: 54, height: 54, transformOrigin: "50% 100%", transform: `scale(${2 - squash}, ${squash})` }}>
                  <Medal />
                </div>
              </div>
            </div>

            {/* Text */}
            <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3, whiteSpace: "nowrap" }}>
              <motion.span
                initial={false}
                animate={{ opacity: lettersIn ? 1 : 0 }}
                transition={anim.easeOut(0.3)}
                style={{ fontSize: 10, lineHeight: "12px", fontWeight: 800, letterSpacing: zh ? 2 : 1.1, color: hex(GOLD) }}
              >
                {zh ? "成就已解锁" : "ACHIEVEMENT UNLOCKED"}
              </motion.span>
              <span style={{ display: "flex", fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 700, color: "#fff" }}>
                {Array.from(title).map((letter, index) => (
                  <motion.span
                    key={index}
                    initial={false}
                    animate={{ y: lettersIn ? 0 : 12, opacity: lettersIn ? 1 : 0, filter: `blur(${lettersIn ? 0 : 5}px)` }}
                    transition={lettersIn ? delayed(spring(0.4, 0.7), index * stagger) : INSTANT}
                    style={{ display: "inline-block", whiteSpace: "pre" }}
                  >
                    {letter}
                  </motion.span>
                ))}
              </span>
              <motion.span
                initial={false}
                animate={{ opacity: lettersIn ? 1 : 0 }}
                transition={lettersIn ? delayed(anim.easeOut(0.3), 0.35) : INSTANT}
                style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: white(0.6) }}
              >
                {zh ? "+250 经验" : "+250 XP"}
              </motion.span>
            </div>

            {/* Shine */}
            <div style={{ position: "absolute", inset: 0, borderRadius: 26, overflow: "hidden", zIndex: 4 }}>
              <div
                style={{
                  position: "absolute",
                  left: 148 - 45,
                  top: 42 - 80,
                  width: 90,
                  height: 160,
                  transform: `translateX(${sweep * 220}px) rotate(20deg)`,
                  background: `linear-gradient(90deg, ${white(0)}, ${white(0.32)}, ${white(0)})`,
                  mixBlendMode: "plus-lighter",
                }}
              />
            </div>
            {/* Gold hairline */}
            <div
              style={{
                position: "absolute",
                inset: 0,
                zIndex: 5,
                borderRadius: 26,
                padding: 1,
                background: `linear-gradient(${90 + (Math.atan2(84, 296) * 180) / Math.PI}deg, ${hex(GOLD, 0.7)}, ${hex(GOLD, 0.12)}, ${hex(GOLD, 0.4)})`,
                WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                WebkitMaskComposite: "xor",
                mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              }}
            />
          </div>
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap Check in" zh="点击“签到”" />
    </div>
  );
}

function Medal() {
  return (
    <div style={{ position: "relative", width: 54, height: 54, filter: `drop-shadow(0 3px 10px ${hex(0xf2a93b, 0.5)})` }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: "conic-gradient(from 90deg, #FFE9A6, #F2A93B, #FFF3C4, #D98B1F, #FFE9A6)" }} />
      <div style={{ position: "absolute", inset: 5, borderRadius: "50%", background: "linear-gradient(#FFD66B, #F0A030)", boxShadow: `inset 0 0 0 1px ${hex(0xb86e0e, 0.55)}` }} />
      <svg width={26} height={26} viewBox="0 0 24 24" style={{ position: "absolute", left: 14, top: 13.5, filter: `drop-shadow(0 1px 0.5px ${hex(0x9a5a00, 0.6)})` }}>
        <defs>
          <linearGradient id="achievement-flame" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#FFF6D8" />
            <stop offset="1" stopColor="#FFE08A" />
          </linearGradient>
        </defs>
        {/* flame.fill: an outer flame with the inner tongue knocked out */}
        <path
          fillRule="evenodd"
          fill="url(#achievement-flame)"
          d="M12.6 1.6c.5 3.2 2.3 5 4 6.900 1.800 2 3.400 4.100 3.400 7.200a8 8 0 0 1-16 0c0-2.300.9-4.200 2.200-5.700.4-.5 1.200-.2 1.200.5 0 1 .5 1.900 1.300 2.400C8.400 9 9.300 4.300 12.600 1.600Zm-.5 11c-1.600 1.500-3 3-3 5a3 3 0 0 0 6 0c0-1-.4-1.800-1-2.500-.3.700-.7 1.100-1.300 1.300.2-1.300 0-2.500-.7-3.800Z"
        />
      </svg>
      {/* Fixed specular highlight. */}
      <div style={{ position: "absolute", left: 27 - 11 - 8, top: 27 - 4.5 - 15, width: 22, height: 9, borderRadius: "50%", background: white(0.5), filter: "blur(4px)" }} />
    </div>
  );
}
