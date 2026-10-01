/** morph.drip-reveal · 液体滴落揭示 (Morph+DripReveal.swift) */
import { animate, useMotionValue } from "motion/react";
import { Heart, Leaf, Sun, type LucideIcon } from "lucide-react";
import { useId, useRef, useState } from "react";
import { DemoHint, anim, fonts, spring, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { Column, morphScreen, predicted, smooth, unit, useMV } from "./_shared";

const W = 316;
const H = 306;
interface DripPage {
  title: [string, string];
  caption: [string, string];
  Icon: LucideIcon;
  colors: [string, string];
  ink: string;
}
const pages: DripPage[] = [
  { title: ["Mango", "芒果"], caption: ["Sunny, loud, a little sticky", "明亮、张扬，还有点黏"], Icon: Sun, colors: ["#FFC53D", "#FF9A2E"], ink: "#4A2500" },
  { title: ["Berry", "莓果"], caption: ["Deep, sweet, stains everything", "浓郁、甜，沾上就洗不掉"], Icon: Heart, colors: ["#F0437A", "#B32BD1"], ink: "#FFFFFF" },
  { title: ["Mint", "薄荷"], caption: ["Cool, clean, slow to pour", "清凉、干净，倒得很慢"], Icon: Leaf, colors: ["#2FE0B0", "#13A892"], ink: "#00352C" },
];
function hash(a: number, b: number) {
  const value = Math.sin(a * 127.1 + b * 311.7) * 43758.5453;
  return value - Math.floor(value);
}

export default function DripReveal({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [index, setIndex] = useState(0);
  const progressMV = useMotionValue(0);
  const progress = useMV(progressMV);
  const pouring = useRef(false);
  const dragged = useRef(false);
  const id = useId().replace(/:/g, "");
  const L = ctx.lang === "zh" ? 1 : 0;

  const pour = (buzz = true) => {
    if (pouring.current) return;
    pouring.current = true;
    haptics.tap("soft");
    const remaining = Math.max(1 - progressMV.get(), 0.25);
    void animate(progressMV, 1, anim.curve(0.3, 0, 0.6, 1, ctx.n("duration") * remaining)).then(() => {
      setIndex((i) => (i + 1) % pages.length);
      progressMV.jump(0);
      pouring.current = false;
      if (buzz) haptics.tap("light");
    });
  };
  useAutoplay(ctx.isPreview, () => pour(false), { every: ctx.n("duration") + 0.7 });

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ translation: t }) => {
        if (!pouring.current) progressMV.set(unit(t.y / 250));
      },
      onEnd: ({ translation: t, velocity: v }) => {
        if (pouring.current) return;
        if (predicted(t.y, v.y) / 250 > 0.4 || progressMV.get() > 0.4) pour();
        else animate(progressMV, 0, spring(0.45, 0.9));
      },
    },
    10,
  );

  // The liquid's silhouette: curtain, columns and bulbs fused by blur + alpha threshold.
  const columns = Math.max(ctx.i("columns"), 2);
  const spread = ctx.n("spread");
  const goo = ctx.n("goo");
  const shapes: React.ReactNode[] = [];
  if (progress > 0.001) {
    const p = Math.min(progress, 1);
    const slot = W / columns;
    // Curtain following the drips down.
    const curtain = (H + 60) * smooth(p, 0.25, 1) - 30;
    shapes.push(<rect key="curtain" x={-40} y={-80} width={W + 80} height={Math.max(curtain + 80, 0)} />);
    for (let column = 0; column < columns; column++) {
      const delay = hash(column, index * 7 + 1);
      const local = unit(p * (1 + spread) - delay * spread);
      if (!(local > 0)) continue;
      const width = slot * (0.6 + 0.5 * hash(column, index * 7 + 2));
      const x = slot * (column + 0.5) + slot * 0.24 * (hash(column, index * 7 + 3) - 0.5);
      const bulb = width * 0.62;
      const tip = -bulb + (H + bulb * 2 + 40) * Math.pow(local, 1.5);
      shapes.push(<rect key={`c${column}`} x={x - width / 2} y={-80} width={width} height={Math.max(tip + 80, 0)} rx={width / 2} />);
      shapes.push(<ellipse key={`b${column}`} cx={x} cy={tip + bulb * 0.075} rx={bulb} ry={bulb * 1.075} />);
    }
  }
  const next = (index + 1) % pages.length;
  const region = { x: -60, y: -120, width: W + 120, height: H + 240, filterUnits: "userSpaceOnUse" } as const;

  return (
    <Column gap={10}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          if (dragged.current) dragged.current = false;
          else pour();
        }}
        style={{ ...pan.style, ...morphScreen(), cursor: "pointer" }}
      >
        <svg width={W} height={H} viewBox={`0 0 ${W} ${H}`} style={{ position: "absolute", inset: 0 }}>
          <defs>
            <filter id={`goo${id}`} {...region} colorInterpolationFilters="sRGB">
              <feGaussianBlur stdDeviation={goo} />
              <feColorMatrix type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 60 -30" />
            </filter>
            <filter id={`shade${id}`} {...region} colorInterpolationFilters="sRGB">
              <feGaussianBlur stdDeviation={goo} />
              <feColorMatrix type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 60 -30" />
              <feGaussianBlur stdDeviation={5} />
            </filter>
            <mask id={`lip${id}`} maskUnits="userSpaceOnUse" x={0} y={0} width={W} height={H}>
              <g filter={`url(#goo${id})`} fill="#fff">
                {shapes}
              </g>
            </mask>
            <mask id={`body${id}`} maskUnits="userSpaceOnUse" x={0} y={0} width={W} height={H}>
              <g transform="translate(0 -6)">
                <g filter={`url(#goo${id})`} fill="#fff">
                  {shapes}
                </g>
              </g>
            </mask>
          </defs>
          <PageArt page={pages[index]} L={L} uid={`a${id}`} />
          {/* Shadow the liquid casts on the page beneath it. */}
          <g transform="translate(0 7)" opacity={0.3}>
            <g filter={`url(#shade${id})`}>{shapes}</g>
          </g>
          {/* The lip: the same page a shade darker, showing 6 pt below the bright body. */}
          <g mask={`url(#lip${id})`}>
            <PageArt page={pages[next]} L={L} uid={`b${id}`} />
            <rect width={W} height={H} fill="#000" opacity={0.24} />
          </g>
          <g mask={`url(#body${id})`}>
            <PageArt page={pages[next]} L={L} uid={`c${id}`} />
          </g>
        </svg>
      </div>
      <DemoHint ctx={ctx} en="Tap, or drag down to pour" zh="点击，或向下拖动倾倒" />
    </Column>
  );
}

function PageArt({ page, L, uid }: { page: DripPage; L: number; uid: string }) {
  return (
    <g>
      <defs>
        <linearGradient id={uid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={page.colors[0]} />
          <stop offset="1" stopColor={page.colors[1]} />
        </linearGradient>
      </defs>
      <rect width={W} height={H} fill={`url(#${uid})`} />
      <circle cx={W / 2} cy={100} r={56} fill="#fff" opacity={0.22} />
      <page.Icon x={W / 2 - 30} y={70} size={60} color={page.ink} fill={page.ink} strokeWidth={2} opacity={0.9} />
      <text x={20} y={258} fill={page.ink} style={{ fontSize: 40, fontWeight: 800, fontFamily: fonts.rounded }}>
        {page.title[L]}
      </text>
      <text x={20} y={282} fill={page.ink} opacity={0.75} style={{ fontSize: 13, fontWeight: 600, fontFamily: fonts.text }}>
        {page.caption[L]}
      </text>
    </g>
  );
}
