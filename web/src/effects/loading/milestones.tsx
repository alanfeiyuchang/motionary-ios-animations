/** loading.milestones · 里程碑进度 (Loading+Milestones.swift) */
import { motion } from "motion/react";
import { Bike, House, Package, Plane, ShoppingCart, type LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, delayed, demoCard, fonts, spring, useClock, useHaptics, usePan, type DemoProps } from "../../kit";
import { previewFps, primary } from "./shared";
import { LoadingCurve } from "./round2";

interface Info {
  en: string;
  zh: string;
  icon: LucideIcon;
  filled?: boolean;
  time: string;
}
const ALL: Info[] = [
  { en: "Ordered", zh: "已下单", icon: ShoppingCart, time: "09:12" },
  { en: "Packed", zh: "已打包", icon: Package, time: "11:40" },
  { en: "Shipped", zh: "运输中", icon: Plane, filled: true, time: "14:05" },
  { en: "Nearby", zh: "派送中", icon: Bike, time: "17:30" },
  { en: "Delivered", zh: "已送达", icon: House, filled: true, time: "18:02" },
];
const slotsFor = (count: number) => (count <= 3 ? [0, 2, 4] : count === 4 ? [0, 1, 2, 4] : [0, 1, 2, 3, 4]);

const WIDTH = 260;
const HOLD = 1.7;
/** Where marker `index` sits on the line, as a fraction of its width. */
const position = (index: number, count: number) => (14 + ((WIDTH - 28) * (index + 1)) / count) / WIDTH;

/** Progress of the timed run: one marker per `segment` seconds, eased a little at each one. */
function timed(elapsed: number, segment: number, count: number) {
  const run = Math.min(Math.max(elapsed / segment, 0), count);
  const whole = Math.min(Math.floor(run), count - 1);
  const u = run - whole;
  const eased = 0.55 * u + 0.45 * LoadingCurve.smoothstep(u);
  const from = whole === 0 ? 0 : position(whole - 1, count);
  const to = whole === count - 1 ? 1 : position(whole, count);
  return Math.min(from + (to - from) * eased, 1);
}

export default function Milestones({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const slots = slotsFor(ctx.i("count"));
  const count = slots.length;
  const segment = Math.max(ctx.n("segment"), 0.1);
  const run = segment * count + HOLD;
  const now = useClock(true, previewFps(ctx.isPreview));
  const started = useRef(0);
  const nowRef = useRef(now);
  nowRef.current = now;
  const [manual, setManual] = useState<number | null>(null);
  const [dragging, setDragging] = useState(false);
  const draggingRef = useRef(false);

  const since = Math.max(now - started.current - 0.5, 0);
  // Previews loop; the detail page plays once and then waits for the finger.
  const elapsed = ctx.isPreview ? since % (run + 0.5) : since;
  const progress = manual ?? timed(elapsed, segment, count);
  const done = progress >= 0.999;
  const percent = Math.round(progress * 100);

  const pan = usePan({
    onChange: (s) => {
      if (!(Math.abs(s.translation.x) > 4 || draggingRef.current)) return;
      draggingRef.current = true;
      setDragging(true);
      setManual(Math.min(Math.max(s.location.x / WIDTH, 0), 1));
    },
    onEnd: () => {
      if (draggingRef.current) {
        draggingRef.current = false;
        setDragging(false);
      } else {
        haptics.tap();
        setManual(null);
        started.current = nowRef.current;
      }
    },
  });

  const smooth = "0.4s cubic-bezier(0.22, 0.61, 0.36, 1)";
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div style={{ ...demoCard(24), padding: "16px 18px 4px", display: "flex", flexDirection: "column", alignItems: "flex-start", flex: "none" }}>
        <div style={{ width: WIDTH, display: "flex", alignItems: "baseline" }}>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 2 }}>
            <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>{zh ? "订单 #2048" : "Order #2048"}</span>
            <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>
              {done ? (zh ? "包裹已送达" : "Your parcel has arrived") : zh ? "正在路上" : "On its way"}
            </span>
          </div>
          <span style={{ flex: 1 }} />
          <span
            style={{
              fontFamily: fonts.rounded,
              fontSize: 26,
              fontWeight: 700,
              fontVariantNumeric: "tabular-nums",
              color: done ? Palette.green : Palette.label,
              transition: `color ${smooth}`,
              alignSelf: "flex-start",
              lineHeight: "31px",
            }}
          >
            {percent}%
          </span>
        </div>
        <div {...pan} style={{ position: "relative", width: WIDTH, height: 112, touchAction: "none" }}>
          <div style={{ position: "absolute", left: 0, top: 53, width: WIDTH, height: 6, borderRadius: 3, background: primary(0.1) }} />
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 53,
              width: Math.max(WIDTH * progress, 6),
              height: 6,
              borderRadius: 3,
              overflow: "hidden",
              background: `linear-gradient(90deg, ${Palette.mint}, ${Palette.sky})`,
            }}
          >
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(90deg, ${Palette.green}, ${Palette.mint})`, opacity: done ? 1 : 0, transition: `opacity ${smooth}` }} />
          </div>
          <motion.div
            animate={{ scale: dragging ? 1.6 : 1 }}
            transition={spring(0.3, 0.6)}
            style={{
              position: "absolute",
              left: WIDTH * progress - 5,
              top: 51,
              width: 10,
              height: 10,
              borderRadius: "50%",
              background: "#fff",
              boxShadow: `0 0 12px ${alpha(Palette.sky, 0.9)}`,
              opacity: done ? 0 : 1,
            }}
          />
          {slots.map((slot, index) => {
            const at = position(index, count);
            return (
              <div key={`${count}-${index}`} style={{ position: "absolute", left: WIDTH * at - 14, top: 42 }}>
                <Marker info={ALL[slot]} reached={progress >= at - 0.0005} done={done} damping={ctx.n("damping")} zh={zh} onChange={() => dragging && haptics.selection()} />
              </div>
            );
          })}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag along the line · tap to replay" zh="沿线拖动 · 点击重播" />
    </div>
  );
}

function Marker({ info, reached, done, damping, zh, onChange }: { info: Info; reached: boolean; done: boolean; damping: number; zh: boolean; onChange: () => void }) {
  const [bursts, setBursts] = useState(0);
  const was = useRef(reached);
  const notify = useRef(onChange);
  notify.current = onChange;
  useEffect(() => {
    if (was.current === reached) return;
    was.current = reached;
    if (reached) setBursts((v) => v + 1);
    notify.current();
  }, [reached]);
  const s = spring(0.38, damping);
  const smooth = "0.4s cubic-bezier(0.22, 0.61, 0.36, 1)";
  const Icon = info.icon;
  const glow = done ? Palette.green : Palette.sky;
  return (
    <motion.div initial={false} animate={{ scale: reached ? 1 : 0.86 }} transition={s} style={{ position: "relative", width: 28, height: 28 }}>
      {bursts > 0 && (
        <motion.div
          key={bursts}
          initial={{ scale: 1, opacity: 0.7 }}
          animate={{ scale: 2.1, opacity: 0 }}
          transition={anim.easeInOut(0.54)}
          style={{ position: "absolute", inset: -1, borderRadius: "50%", border: `2px solid ${glow}` }}
        />
      )}
      <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.elevated, boxShadow: `inset 0 0 0 1.5px ${primary(0.16)}` }} />
      <motion.div
        initial={false}
        animate={{ scale: reached ? 1 : 0.2, opacity: reached ? 1 : 0 }}
        transition={s}
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: "50%",
          overflow: "hidden",
          background: `linear-gradient(135deg, ${Palette.mint}, ${Palette.sky})`,
          boxShadow: `0 3px 14px ${alpha(glow, reached ? 0.45 : 0)}`,
          transition: `box-shadow ${smooth}`,
        }}
      >
        <div style={{ position: "absolute", inset: 0, background: `linear-gradient(135deg, ${Palette.green}, ${Palette.mint})`, opacity: done ? 1 : 0, transition: `opacity ${smooth}` }} />
      </motion.div>
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "grid",
          placeItems: "center",
          color: reached ? "#fff" : Palette.secondaryLabel,
          opacity: reached ? 1 : 0.7,
          transition: "color 0.25s, opacity 0.25s",
        }}
      >
        <Icon size={13} strokeWidth={2.6} fill={info.filled ? "currentColor" : "none"} />
      </div>
      <motion.span
        initial={false}
        animate={{ y: reached ? 36 : 44, opacity: reached ? 1 : 0 }}
        transition={s}
        style={{ position: "absolute", left: "50%", top: 0, translateX: "-50%", fontSize: 12, lineHeight: "16px", fontWeight: 600, whiteSpace: "nowrap" }}
      >
        {zh ? info.zh : info.en}
      </motion.span>
      <motion.span
        initial={false}
        animate={{ y: reached ? -34 : -44, opacity: reached ? 1 : 0 }}
        transition={delayed(s, reached ? 0.08 : 0)}
        style={{
          position: "absolute",
          left: "50%",
          bottom: 0,
          translateX: "-50%",
          fontSize: 11,
          lineHeight: "13px",
          fontWeight: 500,
          fontVariantNumeric: "tabular-nums",
          color: Palette.secondaryLabel,
          whiteSpace: "nowrap",
        }}
      >
        {info.time}
      </motion.span>
    </motion.div>
  );
}
