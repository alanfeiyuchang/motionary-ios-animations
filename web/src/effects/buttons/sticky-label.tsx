/** buttons.sticky-label · 黏性标签 (Buttons+StickyLabel.swift) */
import { motion, type Transition } from "motion/react";
import { Hand } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, black, hex, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { useSvgID } from "./_a-kit";
import { useAnimatedNumber } from "./_c-kit";

const SIZE = { w: 244, h: 68 };
const SCRIPT = [
  { x: 150, y: -30 },
  { x: -150, y: 40 },
  { x: 90, y: 60 },
];

function tether(px: number, py: number, amount: number): string {
  const distance = Math.hypot(px, py);
  if (distance <= 1) return "";
  const home = { x: SIZE.w / 2 - (px / distance) * 42, y: SIZE.h / 2 - (py / distance) * 5 };
  const tip = { x: home.x + px, y: home.y + py };
  const n = { x: -py / distance, y: px / distance };
  const waist = Math.max(8 * (1 - 0.8 * Math.min(amount, 1)), 1);
  const mid = { x: (home.x + tip.x) / 2, y: (home.y + tip.y) / 2 };
  const s = (p: { x: number; y: number }, by: number) => `${(p.x + n.x * by).toFixed(2)} ${(p.y + n.y * by).toFixed(2)}`;
  return `M${s(home, 15)}Q${s(mid, waist)} ${s(tip, 17)}L${s(tip, -17)}Q${s(mid, -waist)} ${s(home, -15)}Z`;
}

export default function StickyLabel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const script = useTimeouts();
  const snap = useTimeouts();
  const [pull, setPull] = useState({ x: 0, y: 0 });
  const [tr, setTr] = useState<Transition>(spring(0.16, 0.72));
  const [touching, setTouching] = useState(false);
  const touchRef = useRef(false);
  const step = useRef(0);
  const id = useSvgID("sticky");
  const reach = Math.max(ctx.n("reach"), 1);
  const stretch = ctx.n("stretch");
  const params = useRef({ reach, lag: 0.16, bounce: 0.42 });
  params.current = { reach, lag: ctx.n("lag"), bounce: ctx.n("bounce") };

  const go = (target: { x: number; y: number }, t: Transition) => {
    setTr(t);
    setPull(target);
  };
  const band = (raw: { x: number; y: number }, k = 1) => ({
    x: rubberBand(raw.x * k, params.current.reach, 0.9),
    y: rubberBand(raw.y * k, params.current.reach * 0.4, 0.9),
  });
  const follow = (raw: { x: number; y: number }) => go(band(raw), spring(params.current.lag, 0.72));
  const snapHome = (buzz: boolean) => {
    go({ x: 0, y: 0 }, spring(0.36, params.current.bounce));
    snap.clearAll();
    if (!buzz || ctx.isPreview) return;
    snap.after(0.11, () => haptics.tap("rigid"));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (touchRef.current) return;
      const raw = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      script.clearAll();
      go(band(raw, 0.6), spring(0.5, 0.85));
      script.after(0.45, () => follow(raw));
      script.after(0.85, () => snapHome(false));
    },
    { every: 1.6, delay: 0.4 },
  );

  const pan = usePan({
    onChange: (s) => {
      if (!touchRef.current) {
        script.clearAll();
        snap.clearAll();
        touchRef.current = true;
        setTouching(true);
        haptics.tap("soft");
      }
      follow({ x: s.location.x - 30 - SIZE.w / 2, y: s.location.y - 30 - SIZE.h / 2 });
    },
    onEnd: () => {
      touchRef.current = false;
      setTouching(false);
      snapHome(true);
    },
  });

  const px = useAnimatedNumber(pull.x, tr);
  const py = useAnimatedNumber(pull.y, tr);
  const distance = Math.hypot(px, py);
  const amount = Math.min(distance / reach, 1.4);
  const direction = px >= 0 ? 1 : -1;
  const across = px / reach;
  const along = py / (reach * 0.4);
  const tilt = across * along * 5;
  const d = tether(px, py, amount);
  const gx = (0.5 - 0.17 * direction) * SIZE.w;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
      <div style={{ flex: 1 }} />
      <div {...pan} role="button" style={{ ...pan.style, width: SIZE.w + 60, height: SIZE.h, margin: "0", padding: "0 30px", boxSizing: "border-box", position: "relative", flexShrink: 0, cursor: "grab" }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: -30, bottom: -30 }} />
        <motion.div initial={false} animate={{ scale: touching ? 0.98 : 1 }} transition={spring(0.3, 0.7)} style={{ position: "relative", width: SIZE.w, height: SIZE.h }}>
          <div style={{ position: "absolute", inset: 0, transform: `translate(${px * 0.08}px, ${py * 0.08}px)` }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: SIZE.h / 2, background: "linear-gradient(135deg, #4B57E0, #7A45D6)", boxShadow: `0 8px 14px ${alpha(Palette.indigo, 0.4)}` }}>
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: SIZE.h / 2,
                  padding: 1,
                  background: `linear-gradient(180deg, ${white(0.45)}, transparent)`,
                  WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                  WebkitMaskComposite: "xor",
                  mask: "linear-gradient(#000 0 0) content-box exclude, linear-gradient(#000 0 0)",
                }}
              />
            </div>
            <div style={{ position: "absolute", left: 61, top: 13, width: 122, height: 42, borderRadius: 21, background: black(0.22), boxShadow: `inset 0 0 0 1px ${black(0.18)}` }} />
            {d && (
              <svg width={SIZE.w} height={SIZE.h} viewBox={`0 0 ${SIZE.w} ${SIZE.h}`} style={{ position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" }}>
                <defs>
                  <linearGradient id={id} gradientUnits="userSpaceOnUse" x1={gx} y1={0} x2={gx + px} y2={0}>
                    <stop offset="0" stopColor="#fff" stopOpacity={0.08} />
                    <stop offset="1" stopColor="#fff" stopOpacity={0.7} />
                  </linearGradient>
                </defs>
                <path d={d} fill={`url(#${id})`} />
              </svg>
            )}
            <div
              style={{
                position: "absolute",
                left: 61,
                top: 13,
                width: 122,
                height: 42,
                borderRadius: 21,
                background: `linear-gradient(180deg, #fff, ${hex(0xe9e8ff)})`,
                boxShadow: `0 4px 7px ${black(0.28)}`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 6,
                color: hex(0x4b3fd0),
                fontSize: 15,
                fontWeight: 600,
                whiteSpace: "nowrap",
                transform: `translate(${px}px, ${py}px) rotate(${tilt}deg) scale(${1 + stretch * Math.abs(across)}, ${1 - stretch * 0.4 * Math.abs(across) + stretch * 0.25 * Math.abs(along)})`,
              }}
            >
              <Hand size={16} strokeWidth={2.4} />
              <span>{ctx.t("Pull me", "拉我试试")}</span>
            </div>
          </div>
        </motion.div>
      </div>
      <div style={{ flex: 1 }} />
      <DemoHint ctx={ctx} en="Drag from the label and let go" zh="按住标签拖动，然后松手" style={{ paddingBottom: 18 }} />
    </div>
  );
}
