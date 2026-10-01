/** gestures.swipe-up-unlock · 上滑解锁 (Gestures+SwipeUpUnlock.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { BookOpen, Calendar, Camera, CloudSun, Compass, Flashlight, Gamepad2, Heart, Image, Lock, LockOpen, Mail, Map, MessageCircle, Music, Phone, Settings, ShoppingCart, Zap, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, clamp, fonts, hex, rubberBand, spring, useAutoplay, useClock, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { useGhost } from "./_sim-kit";

const SIZE = { w: 210, h: 300 };
const TRAVEL = 270;
const CORNER = 36;

export default function SwipeUpUnlock({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  /** 0 = locked, 1 = unlocked. */
  const progress = useMotionValue(0);
  const [unlocked, setUnlocked] = useState(false);
  const [armed, setArmed] = useState(false);
  const s = useRef({ unlocked: false, armed: false, held: false, dragged: false }).current;
  const blur = ctx.n("blur");

  const setArm = (v: boolean) => {
    s.armed = v;
    setArmed(v);
  };
  const setUnlock = (v: boolean) => {
    s.unlocked = v;
    setUnlocked(v);
  };

  /** Finger (or ghost finger) is `lift` points above where it started. */
  const dragChanged = (lift: number) => {
    const raw = lift / TRAVEL;
    progress.stop();
    progress.set(raw >= 0 ? Math.min(raw, 1) : -rubberBand(-raw, 0.08));
    const nowArmed = progress.get() >= ctx.n("threshold");
    if (nowArmed !== s.armed) {
      setArm(nowArmed);
      if (s.held) haptics.tap("light");
    }
  };

  const release = (velocity: number, scripted = false) => {
    s.held = false;
    if (s.unlocked) return;
    if (s.armed || velocity < -700) {
      animate(progress, 1, spring(ctx.n("response"), 0.82));
      setUnlock(true);
      setArm(false);
      if (!scripted) haptics.success();
    } else {
      animate(progress, 0, spring(ctx.n("response") * 0.8, 0.68));
      setArm(false);
    }
  };

  const lock = (scripted = false) => {
    animate(progress, 0, spring(ctx.n("response"), 0.86));
    setUnlock(false);
    setArm(false);
    if (!scripted) haptics.tap("rigid");
  };

  const pan = usePan(
    {
      onStart: () => {
        s.dragged = true;
      },
      onChange: ({ translation }) => {
        if (s.unlocked) return;
        if (!s.held) {
          s.held = true;
          ghost.touch();
        }
        dragChanged(-translation.y);
      },
      onEnd: ({ velocity }) => {
        if (s.held) release(velocity.y);
      },
    },
    4,
  );

  /** A scripted finger swipes up past the threshold and lets go, then the screen locks again. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.held) return;
      if (s.unlocked) {
        ghost.cancel();
        lock(true);
        return;
      }
      const reach = TRAVEL * Math.min(ctx.n("threshold") + 0.14, 0.9);
      ghost.run(async (g) => {
        if (!(await g.drag({ x: 0, y: 0 }, { x: 0, y: reach }, 0.7, (p) => dragChanged(p.y)))) return;
        release(-500, true);
        if (!(await g.sleep(1.5))) return;
        if (!s.unlocked || s.held) return;
        lock(true);
      });
    },
    { every: 3.4, delay: 0.6 },
  );

  const dim = useTransform(progress, (p) => 0.3 * (1 - Math.min(p, 1)));
  const contentTransform = useTransform(progress, (p) => `translateY(${-p * TRAVEL}px) scale(${1 - 0.12 * Math.min(p, 1)})`);
  const contentFilter = useTransform(progress, (p) => (blur * Math.min(p, 1) > 0.05 ? `blur(${blur * Math.min(Math.max(p, 0), 1)}px)` : "none"));
  const contentOpacity = useTransform(progress, (p) => 1 - Math.min(p, 1) * 0.95);
  const open = armed || unlocked;
  const LockIcon = open ? LockOpen : Lock;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div
        {...pan}
        onClick={() => {
          const dragged = s.dragged;
          s.dragged = false;
          if (!dragged && s.unlocked) {
            ghost.touch();
            lock();
          }
        }}
        style={{
          ...pan.style,
          position: "relative",
          width: SIZE.w,
          height: SIZE.h,
          flex: "none",
          borderRadius: CORNER,
          boxShadow: `0 0 0 3px ${black(0.5)}, 0 10px 18px ${black(0.25)}`,
          cursor: "grab",
        }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: CORNER, overflow: "hidden" }}>
          {/* Wallpaper */}
          <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg, #2B1B6B, #6A3CC8, #E8608F, #FFB36B)" }} />
          <div style={{ position: "absolute", left: SIZE.w / 2 - 70 - 95, top: SIZE.h / 2 - 40 - 95, width: 190, height: 190, borderRadius: "50%", background: hex(0x4fa3ff, 0.55), filter: "blur(46px)" }} />
          <div style={{ position: "absolute", left: SIZE.w / 2 + 80 - 85, top: SIZE.h / 2 + 70 - 85, width: 170, height: 170, borderRadius: "50%", background: hex(0xff5fa2, 0.5), filter: "blur(44px)" }} />
          <HomeIcons progress={progress} />
          <motion.div style={{ position: "absolute", inset: 0, background: "#000", opacity: dim }} />
          <motion.div
            style={{
              position: "absolute",
              inset: 0,
              transformOrigin: "50% 0%",
              transform: contentTransform,
              filter: contentFilter,
              opacity: contentOpacity,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              color: "#fff",
            }}
          >
            <motion.div initial={false} animate={{ scale: open ? 1.2 : 1 }} transition={spring(0.3, 0.6)} style={{ position: "relative", height: 22, width: 22, marginTop: 16 }}>
              <AnimatePresence initial={false} mode="popLayout">
                <motion.span
                  key={open ? "open" : "closed"}
                  initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
                  exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                  transition={spring(0.3, 0.6)}
                  style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}
                >
                  <LockIcon size={15} strokeWidth={2.6} fill={white(0.9)} />
                </motion.span>
              </AnimatePresence>
            </motion.div>
            <div style={{ marginTop: 6, fontSize: 12, lineHeight: "14px", fontWeight: 600, color: white(0.85) }}>{ctx.t("Tuesday, January 14", "1月14日 星期二")}</div>
            <div style={{ marginTop: -4, fontFamily: fonts.rounded, fontSize: 58, lineHeight: "69px", fontWeight: 600 }}>9:41</div>
            <div
              style={{
                marginTop: 14,
                alignSelf: "stretch",
                marginLeft: 12,
                marginRight: 12,
                padding: 9,
                borderRadius: 16,
                background: white(0.2),
                boxShadow: `inset 0 0 0 0.5px ${white(0.22)}`,
                display: "flex",
                alignItems: "center",
                gap: 9,
              }}
            >
              <div style={{ width: 30, height: 30, borderRadius: 8, background: `linear-gradient(135deg, ${Palette.mint}, ${Palette.sky})`, display: "grid", placeItems: "center", flex: "none" }}>
                <MessageCircle size={14} fill="#fff" strokeWidth={0} />
              </div>
              <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
                <div style={{ fontSize: 12, lineHeight: "14px", fontWeight: 700 }}>{ctx.t("Mina", "小敏")}</div>
                <div style={{ fontSize: 11, lineHeight: "13px", opacity: 0.85, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t("Are we still on for tonight?", "今晚还照常见面吗？")}</div>
              </div>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ alignSelf: "stretch", padding: "0 18px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
              <RoundButton icon={Flashlight} />
              <Chevrons />
              <RoundButton icon={Camera} />
            </div>
            <div style={{ width: 74, height: 4, borderRadius: 2, background: white(0.9), marginTop: 10, marginBottom: 8 }} />
          </motion.div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: CORNER, boxShadow: `inset 0 0 0 1px ${white(0.16)}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en={unlocked ? "Tap the screen to lock it again" : "Swipe up to unlock"} zh={unlocked ? "点击屏幕重新锁定" : "向上轻扫解锁"} />
    </div>
  );
}

function RoundButton({ icon: Icon }: { icon: LucideIcon }) {
  return (
    <div style={{ width: 34, height: 34, borderRadius: "50%", background: black(0.28), display: "grid", placeItems: "center" }}>
      <Icon size={14} fill="#fff" strokeWidth={1.6} color="#fff" />
    </div>
  );
}

/** Three chevrons lighting up from bottom to top in a wave. */
function Chevrons() {
  const clock = useClock(true, 30);
  const t = clock / 1.4;
  const cycle = t - Math.floor(t);
  return (
    <div style={{ height: 40, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}>
      {[0, 1, 2].map((index) => {
        // Index 2 is the bottom chevron; the wave climbs.
        const phase = cycle - (2 - index) * 0.16;
        const wave = Math.max(0, 1 - Math.abs(phase - 0.3) / 0.3);
        return (
          <svg key={index} width={24} height={10} viewBox="0 0 24 10" style={{ marginTop: index === 0 ? 0 : -1, transform: `translateY(${-3 * wave}px)`, opacity: 0.3 + 0.7 * wave }}>
            <path d="M3 8 L12 2.5 L21 8" fill="none" stroke="#fff" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        );
      })}
    </div>
  );
}

const SYMBOLS: LucideIcon[] = [MessageCircle, Phone, Camera, Map, Music, Mail, Calendar, CloudSun, Image, Gamepad2, Heart, BookOpen, ShoppingCart, Zap, Settings, Compass];
const FILLED = new Set<LucideIcon>([MessageCircle, Phone, Heart, Zap]);
const TINTS = [Palette.green, Palette.mint, "#4A4A55", Palette.sky, Palette.pink, Palette.blue, Palette.red, Palette.sky, Palette.amber, Palette.violet, Palette.pink, Palette.coral, Palette.indigo, Palette.amber, "#6B6B78", Palette.blue];

/** The home screen behind the lock: every icon zooms into place, outer ones arriving later. */
function HomeIcons({ progress }: { progress: MotionValue<number> }) {
  return (
    <>
      {SYMBOLS.map((Icon, index) => (
        <HomeIcon key={index} index={index} Icon={Icon} progress={progress} />
      ))}
    </>
  );
}

function HomeIcon({ index, Icon, progress }: { index: number; Icon: LucideIcon; progress: MotionValue<number> }) {
  const icon = 36;
  const pitch = icon + 13;
  const column = (index % 4) - 1.5;
  const row = Math.floor(index / 4) - 1.5;
  const distance = Math.hypot(column, row) / 2.13;
  // Outer icons start later, so the grid assembles from the centre outward.
  const delay = distance * 0.3;
  const local = (p: number) => clamp((p - delay) / (1 - delay), 0, 1.2);
  const transform = useTransform(progress, (p) => {
    const l = local(p);
    const eased = 1 - (1 - Math.min(l, 1)) * (1 - Math.min(l, 1));
    const spread = 1.8 - 0.8 * eased + (l > 1 ? -(l - 1) * 0.25 : 0);
    return `translate(${column * pitch * spread}px, ${(row * pitch - 6) * spread}px) scale(${spread})`;
  });
  const opacity = useTransform(progress, (p) => Math.min(local(p) * 1.6, 1));
  const tint = TINTS[index];
  return (
    <motion.div
      style={{
        position: "absolute",
        left: SIZE.w / 2 - icon / 2,
        top: SIZE.h / 2 - icon / 2,
        width: icon,
        height: icon,
        borderRadius: 10,
        background: `linear-gradient(180deg, ${alpha(tint, 0.95)}, ${alpha(tint, 0.7)})`,
        boxShadow: `inset 0 0 0 0.5px ${white(0.25)}`,
        display: "grid",
        placeItems: "center",
        transform,
        opacity,
      }}
    >
      <Icon size={17} color="#fff" strokeWidth={2.2} fill={FILLED.has(Icon) ? "#fff" : "none"} />
    </motion.div>
  );
}
