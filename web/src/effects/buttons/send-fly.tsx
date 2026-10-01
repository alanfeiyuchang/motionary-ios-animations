/** buttons.send-fly · 纸飞机发送 (Buttons+SendFly.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { Send } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, delayed, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, cubicKF, linearKF, springKF, track, useSince } from "./_a-kit";
import { mixRGB, rgba } from "./_c-kit";

type Phase = "idle" | "sending" | "sent";
const STAGE = { w: 320, h: 250 };
const CENTER = { x: 160, y: 168 };

function flightPath(curve: number) {
  const start = { x: 135, y: 168 };
  const end = { x: 338, y: 14 };
  const c1 = { x: start.x + 8, y: start.y - curve };
  const c2 = { x: end.x - 150, y: end.y + 12 };
  return {
    point(t: number) {
      const u = 1 - t;
      const a = u * u * u;
      const b = 3 * u * u * t;
      const c = 3 * u * t * t;
      const d = t * t * t;
      return { x: a * start.x + b * c1.x + c * c2.x + d * end.x, y: a * start.y + b * c1.y + c * c2.y + d * end.y };
    },
    heading(t: number) {
      const u = 1 - t;
      const dx = 3 * u * u * (c1.x - start.x) + 6 * u * t * (c2.x - c1.x) + 3 * t * t * (end.x - c2.x);
      const dy = 3 * u * u * (c1.y - start.y) + 6 * u * t * (c2.y - c1.y) + 3 * t * t * (end.y - c2.y);
      return Math.atan2(dy, dx);
    },
  };
}

export default function SendFly({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [phase, setPhaseState] = useState<Phase>("idle");
  const phaseRef = useRef<Phase>("idle");
  const [tr, setTr] = useState<Transition>(spring(0.4, 0.62));
  const [flights, setFlights] = useState(0);
  const flight = Math.max(ctx.n("flight"), 0.1);
  const hold = ctx.n("hold");
  const curve = ctx.n("curve");
  const trail = ctx.n("trail");

  const setPhase = (p: Phase, t: Transition) => {
    phaseRef.current = p;
    setTr(t);
    setPhaseState(p);
  };
  const send = (buzz: boolean) => {
    if (phaseRef.current !== "idle") return;
    clearAll();
    setPhase("sending", { duration: 0 });
    setFlights((n) => n + 1);
    after(0.1 + flight * 0.55, () => {
      setPhase("sent", spring(0.4, 0.62));
      if (buzz) haptics.success();
    });
    after(0.1 + flight * 0.55 + hold, () => setPhase("idle", spring(0.45, 0.7)));
  };
  useAutoplay(ctx.isPreview, () => send(false), { every: flight + hold + 1.3, delay: 0.5 });

  const t = useSince(flights, 0.1 + flight + 0.7);
  const clock = track(t, 0, [linearKF(0, 0.1), linearKF(1, flight)]);
  const wind = track(t, 0, [cubicKF(1, 0.1), cubicKF(0, 0.1)]);
  const press = track(t, 1, [cubicKF(0.95, 0.1), springKF(1, 0.5, BOUNCY)]);
  const recoil = track(t, 0, [linearKF(0, 0.1), cubicKF(-4, 0.07), springKF(0, 0.5, BOUNCY)]);

  const path = flightPath(curve);
  const progress = Math.pow(clock, 1.6);
  const airborne = phase === "sending" || clock > 0.001;
  const sent = phase === "sent";

  // Trail segments.
  const segments: { a: { x: number; y: number }; b: { x: number; y: number }; color: string; heat: number }[] = [];
  if (airborne && progress > 0.001) {
    const start = Math.max(progress - trail, 0);
    if (progress - start > 0.002) {
      const presence = progress > 0.8 ? (1 - progress) / 0.2 : 1;
      for (let index = 0; index < 16; index++) {
        const heat = (index + 1) / 16;
        segments.push({
          a: path.point(start + ((progress - start) * index) / 16),
          b: path.point(start + ((progress - start) * (index + 1)) / 16),
          color: rgba(mixRGB(0x6e7bff, 0x3ac4ff, heat), heat * heat * presence),
          heat,
        });
      }
    }
  }
  const lines = (width: number) =>
    segments.map((s, i) => <line key={i} x1={s.a.x} y1={s.a.y} x2={s.b.x} y2={s.b.y} stroke={s.color} strokeWidth={width * (0.25 + 0.75 * s.heat)} strokeLinecap="round" />);

  // Plane.
  const point = path.point(progress);
  const heading = (path.heading(progress) * 180) / Math.PI + 45;
  const blend = Math.min(progress / 0.12, 1);
  const eased = blend * blend * (3 - 2 * blend);
  const angle = -16 * wind * (1 - eased) + heading * eased;
  const lifted = Math.min(progress / 0.18, 1);
  const planeColor = rgba(mixRGB([255, 255, 255], 0x3ac4ff, lifted));
  const title = phase === "idle" ? ctx.t("Send", "发送") : phase === "sending" ? ctx.t("Sending", "发送中") : ctx.t("Sent", "已发送");

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1, minHeight: 0 }} />
      <div style={{ position: "relative", width: STAGE.w, height: STAGE.h, flexShrink: 0 }}>
        {segments.length > 0 && (
          <svg width={STAGE.w} height={STAGE.h} viewBox={`0 0 ${STAGE.w} ${STAGE.h}`} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" }}>
            <g style={{ filter: "blur(3.5px)" }}>{lines(8)}</g>
            {lines(3.2)}
          </svg>
        )}
        <div
          style={{
            position: "absolute",
            left: CENTER.x,
            top: CENTER.y,
            width: 0,
            height: 0,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transform: `translate(${recoil}px, ${-recoil * 0.4}px) scale(${press})`,
          }}
        >
          <motion.button
            type="button"
            onClick={() => {
              haptics.tap("light");
              send(true);
            }}
            initial={false}
            animate={{ width: sent ? 172 : 200, boxShadow: `0px 8px 14px ${sent ? alpha(Palette.green, 0.4) : alpha(Palette.indigo, 0.4)}` }}
            transition={tr}
            style={{ position: "relative", height: 58, borderRadius: 29, flexShrink: 0, background: "linear-gradient(135deg, #4B57E0, #7A45D6)", color: "#fff" }}
          >
            <motion.div initial={false} animate={{ opacity: sent ? 1 : 0 }} transition={tr} style={{ position: "absolute", inset: 0, borderRadius: 29, background: Palette.successStrong }} />
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: 29,
                padding: 1,
                background: `linear-gradient(180deg, ${white(0.4)}, transparent)`,
                WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                WebkitMaskComposite: "xor",
                mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
              }}
            />
            <div style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", gap: 9 }}>
              <div style={{ position: "relative", width: 24, height: 24 }}>
                <AnimatePresence initial={false}>
                  {phase === "idle" && (
                    <motion.div
                      key="plane"
                      initial={{ x: -30, opacity: 0 }}
                      animate={{ x: 0, opacity: 1 }}
                      exit={{ opacity: 0, transition: { duration: 0 } }}
                      transition={tr}
                      style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}
                    >
                      <Send size={20} fill="#fff" strokeWidth={1.5} />
                    </motion.div>
                  )}
                </AnimatePresence>
                <svg width={18} height={14} viewBox="0 0 18 14" style={{ position: "absolute", left: 3, top: 5, overflow: "visible" }}>
                  <motion.path
                    d="M0 7.7L6.48 14L18 0"
                    fill="none"
                    stroke="#fff"
                    strokeWidth={2.6}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    initial={false}
                    animate={{ pathLength: sent ? 1 : 0, opacity: sent ? 1 : 0 }}
                    transition={sent ? { pathLength: delayed(anim.easeOut(0.3), 0.12), opacity: { duration: 0, delay: 0.12 } } : { duration: 0 }}
                  />
                </svg>
              </div>
              <motion.span key={phase} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={phase === "sending" ? { duration: 0 } : tr} style={{ fontSize: 17, fontWeight: 600, whiteSpace: "nowrap" }}>
                {title}
              </motion.span>
            </div>
          </motion.button>
        </div>
        {airborne && t >= 0 && clock < 0.999 && (
          <div
            style={{
              position: "absolute",
              left: point.x - 7 * wind,
              top: point.y + 2 * wind,
              width: 0,
              height: 0,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              pointerEvents: "none",
              opacity: progress > 0.85 ? (1 - progress) / 0.15 : 1,
              transform: `scale(${1 - 0.4 * progress}) rotate(${angle}deg)`,
            }}
          >
            <Send size={20} fill={planeColor} color={planeColor} strokeWidth={1.5} style={{ flexShrink: 0, filter: `drop-shadow(0 0 3px ${alpha(Palette.sky, 0.7 * lifted)})` }} />
          </div>
        )}
      </div>
      <div style={{ flex: 1, minHeight: 0 }} />
      <DemoHint ctx={ctx} en="Tap Send" zh="点击发送" style={{ paddingBottom: 18 }} />
    </div>
  );
}
