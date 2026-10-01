/** cards.crumple-dismiss · 揉成纸团 (Cards+CrumpleDismiss.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Circle } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, spring, useAutoplay, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, tr, useMV, type LText } from "./shared";
import { track } from "./_kit";

const NOTE = { w: 200, h: 150 };
const HOME = { x: -10, y: -52 };
const BIN = { x: 112, y: 96 };
/** Where the ball goes in: the mouth of the bin. */
const MOUTH = { x: 112, y: 70 };
const BALL = 26;

const MODELS: { title: LText; detail: LText; paper: string }[] = [
  { title: ["Call the dentist", "给牙医打电话"], detail: ["Before Friday", "周五之前"], paper: "#FFE27A" },
  { title: ["Old login flow", "旧版登录流程"], detail: ["Not needed any more", "已经用不上了"], paper: "#FFB8CC" },
  { title: ["Buy oat milk", "买燕麦奶"], detail: ["And coffee beans", "还有咖啡豆"], paper: "#A9DBFF" },
  { title: ["Idea: a paper bin", "点子：一个纸篓"], detail: ["Too silly?", "会不会太傻？"], paper: "#B9F2D2" },
];

const M64 = (1n << 64n) - 1n;
const noiseCache = new Map<number, number>();
/** Deterministic 0…1 noise per (note, point). */
function noise(seed: number, index: number): number {
  const key = seed * 1000 + index;
  const hit = noiseCache.get(key);
  if (hit !== undefined) return hit;
  let x = BigInt(seed * 7919 + index * 104729 + 12345) & M64;
  x ^= x >> 33n;
  x = (x * 0xff51afd7ed558ccdn) & M64;
  x ^= x >> 33n;
  x = (x * 0xc4ceb9fe1a85ec53n) & M64;
  x ^= x >> 33n;
  const v = Number(x % 10000n) / 10000;
  noiseCache.set(key, v);
  return v;
}

type P = { x: number; y: number };

/** The scrunched outline and its facets for one crumple amount, in the note's own space. */
function mesh(crumple: number, seed: number) {
  const a = NOTE.w / 2;
  const b = NOTE.h / 2;
  const c = clamp(crumple, 0, 1.15);
  const ease = c * c * (3 - 2 * Math.min(c, 1));
  const rest: P[] = [
    { x: -a, y: -b }, { x: -a / 2, y: -b }, { x: 0, y: -b }, { x: a / 2, y: -b },
    { x: a, y: -b }, { x: a, y: -b / 3 }, { x: a, y: b / 3 },
    { x: a, y: b }, { x: a / 2, y: b }, { x: 0, y: b }, { x: -a / 2, y: b },
    { x: -a, y: b }, { x: -a, y: b / 3 }, { x: -a, y: -b / 3 },
  ];
  const count = rest.length;
  const first = Math.atan2(-b, -a);
  const pinch = Math.sin(Math.PI * Math.min(c, 1));
  const outer: P[] = rest.map((r, index) => {
    const angle = first + (2 * Math.PI * index) / count;
    const ball = BALL * (0.84 + 0.36 * noise(seed, index));
    // Mid-squeeze the points cave in by different amounts, so the outline is jagged.
    const cave = 1 - 0.3 * pinch * noise(seed, index + 40);
    return { x: (r.x * (1 - ease) + Math.cos(angle) * ball * ease) * cave + a, y: (r.y * (1 - ease) + Math.sin(angle) * ball * ease) * cave + b };
  });
  const inner: P[] = [];
  for (let index = 0; index < count / 2; index++) {
    const p = rest[index * 2];
    const q = rest[index * 2 + 1];
    const angle = first + (2 * Math.PI * (index * 2 + 0.5)) / count;
    const jitter = 0.38 + 0.24 * noise(seed, index + 80);
    inner.push({
      x: ((p.x + q.x) / 2) * jitter * (1 - ease) + Math.cos(angle) * BALL * 0.5 * ease + a,
      y: ((p.y + q.y) / 2) * jitter * (1 - ease) + Math.sin(angle) * BALL * 0.5 * ease + b,
    });
  }
  const centre = { x: a + 8 * (1 - ease) + 2, y: b - 5 * (1 - ease) - 1 };
  const facets: P[][] = [];
  const n = outer.length;
  const m = inner.length;
  for (let j = 0; j < m; j++) {
    const p0 = outer[(2 * j) % n];
    const p1 = outer[(2 * j + 1) % n];
    const p2 = outer[(2 * j + 2) % n];
    const q0 = inner[j];
    const q1 = inner[(j + 1) % m];
    facets.push([p0, p1, q0], [p1, p2, q0], [p2, q1, q0], [q0, q1, centre]);
  }
  return { outer, facets };
}

export default function CrumpleDismiss({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [index, setIndex] = useState(0);
  const crumpleMV = useMotionValue(0);
  const dragX = useMotionValue(0);
  const dragY = useMotionValue(0);
  const tossMV = useMotionValue(0);
  const riseMV = useMotionValue(1);
  const busy = useRef(false);
  const [lidOpen, setLidOpen] = useState(false);
  const [hits, setHits] = useState(0);
  const held = useRef(false);
  const script = useTimeouts();

  const relax = () => {
    if (busy.current) return;
    const t = spring(0.4, 0.7);
    animate(dragX, 0, t);
    animate(dragY, 0, t);
    animate(crumpleMV, 0, t);
  };

  const dismiss = (buzz: boolean) => {
    if (busy.current) return;
    busy.current = true;
    const total = ctx.n("crumple");
    if (buzz) haptics.tap("soft");
    animate(crumpleMV, 0.55, anim.easeIn(total * 0.4));
    script.clearAll();
    script.after(total * 0.4 + 0.05, () => {
      if (buzz) haptics.tap("medium");
      animate(crumpleMV, 1, spring(total * 0.5, 0.72));
      setLidOpen(true);
      script.after(total * 0.6, () => {
        animate(tossMV, 1, anim.linear(0.5));
        script.after(0.5, () => {
          setHits((h) => h + 1);
          if (buzz) haptics.tap("rigid");
          setLidOpen(false);
          // Swap in the next note underneath, then let it rise.
          setIndex((i) => i + 1);
          [crumpleMV, tossMV, dragX, dragY, riseMV].forEach((mv) => {
            mv.stop();
            mv.jump(0);
          });
          animate(riseMV, 1, spring(0.45, 0.68));
          script.after(0.3, () => (busy.current = false));
        });
      });
    });
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (busy.current) return;
      held.current = true;
      dragX.set(translation.x);
      dragY.set(translation.y);
      // The note starts to wrinkle under the finger.
      crumpleMV.set(Math.min(Math.hypot(translation.x, translation.y) / 260, 0.28));
    },
    onEnd: ({ translation, velocity }) => {
      if (!held.current) return;
      held.current = false;
      [dragX, dragY, crumpleMV].forEach((mv) => mv.jump(mv.get()));
      const distance = Math.hypot(translation.x, translation.y);
      const predicted = Math.hypot(translation.x + velocity.x * 0.25, translation.y + velocity.y * 0.25);
      if (distance < 8 || distance > 70 || predicted > 150) dismiss(true);
      else relax();
    },
  });

  useAutoplay(ctx.isPreview, () => dismiss(false), { every: 2.5 });

  const crumple = useMV(crumpleMV);
  const drag = { x: useMV(dragX), y: useMV(dragY) };
  const t = useMV(tossMV);
  const rise = useMV(riseMV);
  const arc = ctx.n("arc");
  const spin = ctx.n("spin");
  const cx = 160;
  const cy = 145;

  const level = 1 - rise;
  const from = { x: HOME.x + drag.x, y: HOME.y + drag.y };
  const fx = from.x + (MOUTH.x - from.x) * t;
  const fy = from.y + (MOUTH.y - from.y) * t - arc * 4 * t * (1 - t);

  const e = useElapsed(hits, 0.7, true);
  const squash = e < 0 ? 1 : track(e, 1, [{ cubic: 0.9, d: 0.08 }, { spring: 1, d: 0.5, response: 0.28, damping: 0.42 }]);

  return (
    <Stage gap={2}>
      <div style={{ position: "relative", width: 320, height: 290, flexShrink: 0 }}>
        {/* bin */}
        <div onClick={() => dismiss(true)} style={{ position: "absolute", left: cx + BIN.x - 30, top: cy + BIN.y - 38, width: 60, height: 76, cursor: "pointer" }}>
          <div style={{ position: "absolute", left: 4, top: 5, width: 52, height: 66, transformOrigin: "50% 100%", transform: `scale(${2 - squash}, ${squash})` }}>
            <motion.div
              initial={false}
              animate={{ rotate: lidOpen ? 62 : 0 }}
              transition={lidOpen ? spring(0.3, 0.62) : spring(0.22, 0.6)}
              style={{ position: "absolute", left: 0, top: 0, width: 52, height: 12, transformOrigin: "100% 100%" }}
            >
              <div style={{ position: "absolute", left: 19, top: 0, width: 14, height: 4, borderRadius: 2, background: Palette.labelAlpha(0.45) }} />
              <div style={{ position: "absolute", left: 0, top: 4, width: 52, height: 8, borderRadius: 4, background: "linear-gradient(#9AA3B5, #6C7488)" }} />
            </motion.div>
            <svg width={46} height={52} style={{ position: "absolute", left: 3, top: 14, overflow: "visible", filter: `drop-shadow(0 4px 6px ${black(0.2)})` }}>
              <defs>
                <linearGradient id="crumple-can" x1="0" x2="1" y1="0" y2="0">
                  <stop offset="0" stopColor="#8C95A8" />
                  <stop offset="1" stopColor="#5D6578" />
                </linearGradient>
              </defs>
              <path d="M0 0H46L41 45Q40 52 34 52H12Q6 52 5 45Z" fill="url(#crumple-can)" />
              {[0, 1, 2].map((i) => (
                <rect key={i} x={23 - 1.25 + (i - 1) * 10.5} y={11} width={2.5} height={30} rx={1.25} fill={black(0.2)} />
              ))}
            </svg>
          </div>
        </div>
        {/* notes waiting underneath */}
        {[2, 1].map((depth) => {
          const l = depth + (1 - rise);
          return (
            <div
              key={index + depth}
              style={{
                position: "absolute",
                left: cx + HOME.x - NOTE.w / 2,
                top: cy + HOME.y - NOTE.h / 2,
                transform: `translateY(${10 * l}px) scale(${1 - 0.06 * l})`,
                opacity: clamp(3 - l),
                filter: `brightness(${1 - 0.05 * l})`,
                pointerEvents: "none",
              }}
            >
              <Note crumple={0} index={index + depth} contrast={0} ctx={ctx} />
            </div>
          );
        })}
        {/* top note */}
        <div
          key={index}
          {...pan}
          style={{
            position: "absolute",
            left: cx - NOTE.w / 2,
            top: cy - NOTE.h / 2,
            width: NOTE.w,
            height: NOTE.h,
            transform: `translate(${fx}px, ${fy + 10 * level}px) rotate(${360 * spin * t}deg) scale(${1 - 0.2 * t}) rotate(${drag.x / 16}deg) scale(${1 - 0.06 * level})`,
            opacity: t >= 0.999 ? 0 : 1,
            touchAction: "none",
            cursor: "grab",
          }}
        >
          <Note crumple={crumple} index={index} contrast={ctx.n("facets")} ctx={ctx} />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Swipe the note away, or tap it" zh="把便签划走，或点击它" />
    </Stage>
  );
}

function Note({ crumple, index, contrast, ctx }: { crumple: number; index: number; contrast: number; ctx: DemoContext }) {
  const model = MODELS[((index % MODELS.length) + MODELS.length) % MODELS.length];
  const c = clamp(crumple);
  const strength = Math.min(c * 2.2, 1) * contrast;
  const flat = crumple <= 0.0005;
  const m = flat ? null : mesh(crumple, index);
  const pts = (ps: P[]) => ps.map((p) => `${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(" ");
  return (
    <div style={{ width: NOTE.w, height: NOTE.h, transform: `rotate(${4 * Math.sin(c * Math.PI * 3) * (1 - c)}deg)`, filter: `drop-shadow(0 5px 7px ${black(0.18)})` }}>
      <div style={{ position: "absolute", inset: 0, clipPath: m ? `polygon(${m.outer.map((p) => `${p.x.toFixed(2)}px ${p.y.toFixed(2)}px`).join(", ")})` : undefined }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 10, overflow: "hidden", background: `linear-gradient(${white(0.25)}, ${black(0.06)}), ${model.paper}` }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              padding: 18,
              display: "flex",
              flexDirection: "column",
              alignItems: "flex-start",
              gap: 8,
              color: "#3A3320",
              fontFamily: fonts.rounded,
              transform: `scale(${1 - 0.7 * c})`,
              opacity: clamp(1 - c / 0.6),
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <Circle size={20} strokeWidth={2.4} />
              <span style={{ fontSize: 18, lineHeight: "22px", fontWeight: 700, whiteSpace: "nowrap" }}>{tr(ctx, model.title)}</span>
            </div>
            <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 500, opacity: 0.6 }}>{tr(ctx, model.detail)}</span>
            <span style={{ flex: 1 }} />
            <div style={{ width: 120, height: 7, borderRadius: 4, background: black(0.12), flexShrink: 0 }} />
            <div style={{ width: 84, height: 7, borderRadius: 4, background: black(0.12), flexShrink: 0 }} />
          </div>
          {m && strength > 0.01 && (
            <svg width={NOTE.w} height={NOTE.h} style={{ position: "absolute", inset: 0 }}>
              {m.facets.map((triangle, number) => {
                const tone = noise(index, number + 200) * 2 - 1;
                return <polygon key={number} points={pts(triangle)} fill={tone > 0 ? black(0.3 * tone * strength) : white(-0.5 * tone * strength)} stroke={black(0.14 * strength)} strokeWidth={0.6} />;
              })}
            </svg>
          )}
        </div>
      </div>
    </div>
  );
}
