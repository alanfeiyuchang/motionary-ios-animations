/** morph.portal-zoom · 传送门穿越 (Morph+PortalZoom.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { memo, useId, useRef, useState, type ReactNode } from "react";
import { DemoHint, anim, black, delayed, fonts, forever, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Column, mixN, morphScreen, smooth, unit, useMV } from "./_shared";

const W = 316;
const H = 306;
const portals = [
  { x: 216, y: 112 },
  { x: 104, y: 122 },
  { x: 178, y: 150 },
];
const titles: [string, string][] = [
  ["Dusk", "黄昏"],
  ["Meadow", "草甸"],
  ["Night", "夜空"],
];
const captions: [string, string][] = [
  ["Ridge trail, 18:42", "山脊步道 18:42"],
  ["Valley floor, 10:15", "谷底草场 10:15"],
  ["Summit camp, 23:30", "山顶营地 23:30"],
];

export default function PortalZoom({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [index, setIndex] = useState(0);
  const progressMV = useMotionValue(0);
  const portalInMV = useMotionValue(1);
  const progress = useMV(progressMV);
  const portalIn = useMV(portalInMV);
  const diving = useRef(false);
  const L = ctx.lang === "zh" ? 1 : 0;

  const dive = (buzz = true) => {
    if (diving.current) return;
    diving.current = true;
    haptics.tap("medium");
    void animate(progressMV, 1, anim.curve(0.65, 0, 0.3, 1, ctx.n("duration"))).then(() => {
      setIndex((i) => (i + 1) % 3);
      progressMV.jump(0);
      portalInMV.jump(0);
      diving.current = false;
      if (buzz) haptics.tap("soft");
      animate(portalInMV, 1, delayed(spring(0.45, 0.6), 0.08));
    });
  };
  useAutoplay(ctx.isPreview, () => dive(false), { every: 1.9 });

  const radius = ctx.n("radius");
  const depth = ctx.n("depth");
  const p = unit(progress);
  const portal = portals[index];
  const next = (index + 1) % 3;
  // Scale that makes the portal's circle reach the farthest corner.
  const reach = Math.max(...[[0, 0], [W, 0], [0, H], [W, H]].map(([x, y]) => Math.hypot(x - portal.x, y - portal.y)));
  const full = (reach + 8) / Math.max(radius, 1);
  const zoom = Math.pow(full, p);
  // The inner scene grows with the opening until it is life-size, drifting to the frame's centre as it does.
  const nominal = Math.min(depth * zoom, 1);
  const travel = unit((nominal - depth) / Math.max(1 - depth, 0.01));
  const ic = { x: mixN(portal.x, W / 2, travel), y: mixN(portal.y, H / 2, travel) };
  // Never smaller than what the opening shows, so the scene's own edges stay out of sight.
  const drift = Math.hypot(ic.x - portal.x, ic.y - portal.y);
  const cover = (radius * zoom + drift + 6) / (Math.min(W, H) / 2);
  const inner = Math.min(Math.max(nominal, cover), 1);
  const hole = Math.max(radius * zoom * portalIn, 0);
  const idle = p === 0;
  const blur = ctx.n("blur") * p;

  return (
    <Column gap={10}>
      <div onClick={() => dive()} style={{ ...morphScreen(), cursor: "pointer" }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${zoom})`, transformOrigin: `${portal.x}px ${portal.y}px`, filter: blur > 0.05 ? `blur(${blur}px)` : undefined }}>
          <Scene index={index} L={L} />
        </div>
        <div style={{ position: "absolute", inset: 0, clipPath: `circle(${hole}px at ${portal.x}px ${portal.y}px)` }}>
          <div style={{ position: "absolute", left: ic.x - W / 2, top: ic.y - H / 2, width: W, height: H, transform: `scale(${inner})` }}>
            <Scene index={next} L={L} />
          </div>
          {/* Depth: the opening is darker toward its edge until you are through it. */}
          <div
            style={{
              position: "absolute",
              left: portal.x - hole,
              top: portal.y - hole,
              width: hole * 2,
              height: hole * 2,
              borderRadius: "50%",
              background: `radial-gradient(circle closest-side, transparent 55%, ${black(0.4)} 100%)`,
              opacity: 1 - smooth(p, 0.1, 0.7),
            }}
          />
        </div>
        <div style={{ position: "absolute", left: portal.x - hole, top: portal.y - hole, width: hole * 2, height: hole * 2, opacity: 1 - smooth(p, 0.35, 0.8), pointerEvents: "none" }}>
          {/* Always in the tree (hidden while diving), so it never animates in from elsewhere. */}
          <motion.div
            animate={{ scale: [1, 1.7, 1], opacity: [0.8, 0, 0.8] }}
            transition={{ duration: 1.6, times: [0, 0.875, 1], ease: [[0, 0, 0.58, 1], "linear"], repeat: Infinity }}
            style={{ position: "absolute", inset: 0 }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1.5px ${white(0.7)}`, opacity: idle ? 1 : 0 }} />
          </motion.div>
          <motion.div animate={{ scale: idle ? [1, 1.05] : 1 }} transition={idle ? forever(anim.easeInOut(1.2)) : anim.easeInOut(1.2)} style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `0 0 8px ${white(0.8)}, inset 0 0 8px ${white(0.8)}` }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 ${3 + 7 * p}px #fff` }} />
          </motion.div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap the portal" zh="点击传送门" />
    </Column>
  );
}

function ridge(base: number, height: number, phase: number, frequency: number) {
  let d = `M0 ${H}`;
  for (let step = 0; step <= 48; step++) {
    const u = step / 48;
    const wave = Math.sin(u * frequency + phase) * 0.6 + Math.sin(u * frequency * 2.3 + phase * 1.7) * 0.4;
    d += ` L${(W * u).toFixed(2)} ${(H * (base - height * wave)).toFixed(2)}`;
  }
  return `${d} L${W} ${H} Z`;
}

const Scene = memo(function Scene({ index, L }: { index: number; L: number }) {
  const id = useId().replace(/:/g, "");
  const sky = (colors: string[]) => (
    <>
      <defs>
        <linearGradient id={`k${id}`} gradientUnits="userSpaceOnUse" x1={W * 0.4} y1={0} x2={W * 0.6} y2={H}>
          {colors.map((c, i) => (
            <stop key={i} offset={i / (colors.length - 1)} stopColor={c} />
          ))}
        </linearGradient>
      </defs>
      <rect width={W} height={H} fill={`url(#k${id})`} />
    </>
  );
  const disc = (cx: number, cy: number, r: number, color: string, glow: number) => (
    <>
      <defs>
        <radialGradient id={`d${id}`}>
          <stop offset="0" stopColor={color} stopOpacity="0.5" />
          <stop offset="1" stopColor={color} stopOpacity="0" />
        </radialGradient>
      </defs>
      <circle cx={cx} cy={cy} r={r * glow} fill={`url(#d${id})`} />
      <circle cx={cx} cy={cy} r={r} fill={color} />
    </>
  );
  let art: ReactNode;
  if (index === 0) {
    art = (
      <>
        {sky(["#2A2F86", "#B04A9A", "#FF8660", "#FFD08A"])}
        {disc(W * 0.3, H * 0.56, 30, "#FFF0C4", 3)}
        <path d={ridge(0.66, 0.07, 0.4, 5)} fill="rgb(138 60 134 / 0.85)" />
        <path d={ridge(0.78, 0.06, 2.1, 6.5)} fill="#532468" />
        <path d={ridge(0.9, 0.05, 4.0, 8)} fill="#24123C" />
      </>
    );
  } else if (index === 1) {
    const clouds = [
      [150, 196, 84, 22],
      [176, 184, 50, 24],
      [30, 56, 70, 18],
      [52, 46, 40, 20],
    ];
    art = (
      <>
        {sky(["#3FA9F5", "#8EDBFF", "#DDF7E6"])}
        {disc(W * 0.76, H * 0.2, 22, "#FFFFFF", 3.2)}
        {clouds.map(([x, y, w, h], i) => (
          <rect key={i} x={x} y={y} width={w} height={h} rx={h / 2} fill={white(0.85)} />
        ))}
        <path d={ridge(0.7, 0.08, 1.2, 4)} fill="#7ED69A" />
        <path d={ridge(0.8, 0.06, 3.0, 5.5)} fill="#43B27A" />
        <path d={ridge(0.9, 0.04, 5.2, 7)} fill="#1F8058" />
      </>
    );
  } else {
    const mx = W * 0.24;
    const my = H * 0.22;
    art = (
      <>
        {sky(["#060920", "#18205A", "#43307E"])}
        {Array.from({ length: 70 }, (_, star) => {
          const r = star % 7 === 0 ? 1.5 : star % 3 === 0 ? 1.0 : 0.7;
          return <circle key={star} cx={((star * 73 + 11) % 316) + r} cy={((star * 137 + 29) % 210) + r} r={r} fill={white(star % 4 === 0 ? 0.95 : 0.6)} />;
        })}
        {disc(mx, my, 20, "#F4F1FF", 2.8)}
        <circle cx={mx + 9} cy={my - 5} r={19} fill="#0D1238" />
        <path d={ridge(0.76, 0.09, 0.9, 6)} fill="#1C2258" />
        <path d={ridge(0.88, 0.06, 2.8, 8)} fill="#0B0E2C" />
      </>
    );
  }
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H }}>
      <svg width={W} height={H} style={{ position: "absolute", inset: 0 }}>
        {art}
      </svg>
      <div style={{ position: "absolute", left: 18, bottom: 18, display: "flex", flexDirection: "column", gap: 2, color: "#fff", textShadow: `0 2px 6px ${black(0.3)}` }}>
        <span style={{ fontSize: 30, lineHeight: "36px", fontWeight: 700, fontFamily: fonts.rounded }}>{titles[index][L]}</span>
        <span style={{ fontSize: 12, lineHeight: "14.5px", fontWeight: 500, opacity: 0.8 }}>{captions[index][L]}</span>
      </div>
    </div>
  );
});
