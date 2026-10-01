/** morph.page-curl · 翻页卷角 (Morph+PageCurl.swift) */
import { animate, useMotionValue } from "motion/react";
import { AudioLines, ChartNoAxesColumn, Spline, Sun, type LucideIcon } from "lucide-react";
import { memo, useId, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, fonts, hex, spring, useAutoplay, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { Column, diag, useMV } from "./_shared";

type Pt = { x: number; y: number };
const PW = 228;
const PH = 284;
const MARGIN = 70;
const HOME: Pt = { x: PW, y: PH };
/** Where the corner is at time `t` of an automatic turn: it sweeps left while lifting off the bottom edge. */
const autoPoint = (t: number): Pt => ({ x: PW - 2 * PW * t, y: PH - 92 * Math.sin(Math.PI * t) });

/** The corner stays on the paper side of its home and within reach of both ends of the spine. */
function clampCorner(point: Pt): Pt {
  let p = { x: Math.min(point.x, PW), y: Math.min(point.y, PH) };
  const d1 = Math.hypot(p.x, p.y - PH);
  if (d1 > PW) p = { x: (p.x * PW) / d1, y: PH + ((p.y - PH) * PW) / d1 };
  const reach = Math.hypot(PW, PH);
  const d2 = Math.hypot(p.x, p.y);
  if (d2 > reach) p = { x: (p.x * reach) / d2, y: (p.y * reach) / d2 };
  return p;
}
/** Sutherland–Hodgman against the fold line. */
function clip(polygon: Pt[], mid: Pt, normal: Pt, keepLifted: boolean): Pt[] {
  const side = (p: Pt) => {
    const s = (p.x - mid.x) * normal.x + (p.y - mid.y) * normal.y;
    return keepLifted ? s : -s;
  };
  const result: Pt[] = [];
  polygon.forEach((a, i) => {
    const b = polygon[(i + 1) % polygon.length];
    const sa = side(a);
    const sb = side(b);
    if (sa >= 0) result.push(a);
    if (sa >= 0 !== sb >= 0) {
      const t = sa / (sa - sb);
      result.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t });
    }
  });
  return result;
}
/** Fold line and polygons for a page whose bottom-right corner has been dragged to `point`. */
function curlGeometry(point: Pt) {
  const corner = clampCorner(point);
  const dx = HOME.x - corner.x;
  const dy = HOME.y - corner.y;
  const length = Math.hypot(dx, dy);
  const rect: Pt[] = [{ x: 0, y: 0 }, { x: PW, y: 0 }, HOME, { x: 0, y: PH }];
  if (length <= 1) return { active: false, mid: HOME, normal: { x: 1, y: 0 }, depth: 0, front: rect, lifted: [] as Pt[], flap: [] as Pt[] };
  const normal = { x: dx / length, y: dy / length };
  const mid = { x: (HOME.x + corner.x) / 2, y: (HOME.y + corner.y) / 2 };
  const lifted = clip(rect, mid, normal, true);
  const flap = lifted.map((p) => {
    const s = (p.x - mid.x) * normal.x + (p.y - mid.y) * normal.y;
    return { x: p.x - 2 * s * normal.x, y: p.y - 2 * s * normal.y };
  });
  return { active: true, mid, normal, depth: length / 2, front: clip(rect, mid, normal, false), lifted, flap };
}
const pointsAttr = (pts: Pt[]) => pts.map((p) => `${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(" ");
const clipPoly = (pts: Pt[]) => (pts.length > 2 ? `polygon(${pts.map((p) => `${p.x.toFixed(2)}px ${p.y.toFixed(2)}px`).join(", ")})` : "polygon(0 0, 0 0, 0 0)");

interface PageContent {
  chapter: string;
  title: [string, string];
  Icon: LucideIcon;
  colors: [string, string];
}
const pages: PageContent[] = [
  { chapter: "01", title: ["Easing", "缓动"], Icon: Spline, colors: [Palette.coral, Palette.pink] },
  { chapter: "02", title: ["Springs", "弹簧"], Icon: AudioLines, colors: [Palette.indigo, Palette.violet] },
  { chapter: "03", title: ["Stagger", "错峰"], Icon: ChartNoAxesColumn, colors: [Palette.mint, Palette.sky] },
  { chapter: "04", title: ["Light", "光影"], Icon: Sun, colors: [Palette.amber, Palette.coral] },
];
const INK = 0x2b2622;

export default function PageCurl({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [index, setIndex] = useState(0);
  const cxMV = useMotionValue(HOME.x);
  const cyMV = useMotionValue(HOME.y);
  const autoMV = useMotionValue(0);
  const cx = useMV(cxMV);
  const cy = useMV(cyMV);
  const autoT = useMV(autoMV);
  const turning = useRef(false);
  const token = useRef(0);
  const dragged = useRef(false);
  const id = useId().replace(/:/g, "");
  const zh = ctx.lang === "zh";

  /** The page has fully turned: the next one becomes the front page, with nothing visibly changing. */
  const commit = (current: number, buzz: boolean) => {
    if (current !== token.current) return;
    if (buzz) haptics.tap("soft");
    setIndex((i) => (i + 1) % pages.length);
    cxMV.jump(HOME.x);
    cyMV.jump(HOME.y);
    autoMV.jump(0);
    turning.current = false;
  };
  /** Tap and autoplay: the corner travels the whole arc by itself. */
  const turn = (buzz = true) => {
    if (turning.current) return;
    turning.current = true;
    token.current += 1;
    const current = token.current;
    cxMV.jump(HOME.x);
    cyMV.jump(HOME.y);
    void animate(autoMV, 1, anim.curve(0.5, 0, 0.3, 1, ctx.n("duration"))).then(() => commit(current, buzz));
  };
  useAutoplay(ctx.isPreview, () => turn(false), { every: 2.0 });

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
      },
      onChange: ({ translation: t }) => {
        if (turning.current) return;
        const c = clampCorner({ x: HOME.x + t.x * 1.25, y: HOME.y + t.y * 1.25 });
        cxMV.set(c.x);
        cyMV.set(c.y);
      },
      onEnd: ({ velocity }) => {
        if (turning.current) return;
        if (cxMV.get() < PW * 0.4 || velocity.x < -600) {
          turning.current = true;
          token.current += 1;
          const current = token.current;
          const t = anim.easeOut(ctx.n("duration") * 0.55);
          animate(cyMV, PH, t);
          void animate(cxMV, -PW, t).then(() => commit(current, true));
        } else {
          animate(cxMV, HOME.x, spring(0.42, 1));
          animate(cyMV, HOME.y, spring(0.42, 1));
        }
      },
    },
    10,
  );

  const point = autoT > 0.0001 ? autoPoint(autoT) : { x: cx, y: cy };
  const g = curlGeometry(point);
  const strength = ctx.n("shadow");
  const ghost = ctx.n("ghost");
  const { mid, normal: n, depth } = g;
  const reach = Math.min(Math.max(depth * 0.7, 14), 60);
  const k = 0.35 + 0.65 * strength;
  const kk = n.x * mid.x + n.y * mid.y;
  const reflection = `matrix(${1 - 2 * n.x * n.x}, ${-2 * n.x * n.y}, ${-2 * n.x * n.y}, ${1 - 2 * n.y * n.y}, ${2 * kk * n.x}, ${2 * kk * n.y})`;
  const fill = { position: "absolute", left: 0, top: 0, width: PW, height: PH } as const;
  const svg = { position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" } as const;
  const front = pages[index % pages.length];

  return (
    <Column gap={16}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          if (dragged.current) dragged.current = false;
          else turn();
        }}
        style={{ ...pan.style, position: "relative", width: PW, height: PH, flexShrink: 0, cursor: "pointer" }}
      >
        {/* The pages underneath: two paper edges and a soft shadow. */}
        <div style={{ ...fill, filter: `drop-shadow(0 10px 16px ${black(0.22)})` }}>
          <div style={{ ...fill, background: "#D9D3C6", transform: "translate(5px, 5px)" }} />
          <div style={{ ...fill, background: "#E6E1D5", transform: "translate(2.5px, 2.5px)" }} />
        </div>
        {/* Everything right of the spine is visible (the flap may hang over the other three edges). */}
        <div style={{ ...fill, clipPath: `inset(${-MARGIN}px ${-MARGIN}px ${-MARGIN}px 0px)` }}>
          <div style={fill}>
            <Page page={pages[(index + 1) % pages.length]} zh={zh} />
          </div>
          {g.active ? (
            <svg width={PW} height={PH} style={{ ...svg, overflow: "hidden" }}>
              <defs>
                <linearGradient id={`f${id}`} gradientUnits="userSpaceOnUse" x1={mid.x} y1={mid.y} x2={mid.x + n.x * reach} y2={mid.y + n.y * reach}>
                  <stop offset="0" stopColor="#000" stopOpacity={0.42 * strength} />
                  <stop offset="1" stopColor="#000" stopOpacity="0" />
                </linearGradient>
              </defs>
              <polygon points={pointsAttr(g.lifted)} fill={`url(#f${id})`} />
            </svg>
          ) : null}
          <div style={{ ...fill, clipPath: clipPoly(g.front) }}>
            <Page page={front} zh={zh} />
          </div>
          {g.active && g.flap.length > 2 ? (
            <>
              <svg
                width={PW}
                height={PH}
                style={{
                  ...svg,
                  filter: `drop-shadow(${-n.x * (4 + depth * 0.06)}px ${-n.y * (4 + depth * 0.06) + 3}px ${6 + depth * 0.12}px ${black(0.45 * strength)})`,
                }}
              >
                <polygon points={pointsAttr(g.flap)} fill="#EFEAE0" stroke={black(0.08)} strokeWidth={0.6} />
              </svg>
              <div style={{ ...fill, clipPath: clipPoly(g.flap), opacity: ghost, pointerEvents: "none" }}>
                <div style={{ ...fill, transform: reflection, transformOrigin: "0 0" }}>
                  <Page page={front} zh={zh} />
                </div>
              </div>
              <svg width={PW} height={PH} style={svg}>
                <defs>
                  <linearGradient id={`s${id}`} gradientUnits="userSpaceOnUse" x1={mid.x} y1={mid.y} x2={mid.x - n.x * depth} y2={mid.y - n.y * depth}>
                    <stop offset="0" stopColor="#000" stopOpacity={0.26 * k} />
                    <stop offset="0.1" stopColor="#000" stopOpacity={0.04 * k} />
                    <stop offset="0.1" stopColor="#fff" stopOpacity={0.1 * k} />
                    <stop offset="0.28" stopColor="#fff" stopOpacity={0.7 * k} />
                    <stop offset="0.6" stopColor="#fff" stopOpacity="0" />
                    <stop offset="0.6" stopColor="#000" stopOpacity="0" />
                    <stop offset="1" stopColor="#000" stopOpacity={0.12 * k} />
                  </linearGradient>
                </defs>
                <polygon points={pointsAttr(g.flap)} fill={`url(#s${id})`} />
              </svg>
            </>
          ) : null}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Drag the page, or tap to turn" zh="拖动页面，或点击翻页" />
    </Column>
  );
}

/** Printed paper: the same in light and dark mode, like a real book. */
const Page = memo(function Page({ page, zh }: { page: PageContent; zh: boolean }) {
  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        padding: "20px 20px 14px",
        display: "flex",
        flexDirection: "column",
        background: `linear-gradient(to right, ${black(0.1)}, transparent 14px), linear-gradient(to right, #FCFAF4, #F6F2E8)`,
      }}
    >
      <div style={{ display: "flex", alignItems: "baseline" }}>
        <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, letterSpacing: 1.5, color: page.colors[0] }}>{zh ? `第 ${page.chapter} 章` : `CHAPTER ${page.chapter}`}</span>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 9, fontWeight: 500, letterSpacing: 1, color: hex(INK, 0.4) }}>{zh ? "动效手册" : "HANDBOOK"}</span>
      </div>
      <span style={{ fontSize: 34, lineHeight: "41px", fontWeight: 700, fontFamily: zh ? fonts.text : fonts.serif, color: hex(INK), paddingTop: 6 }}>{page.title[zh ? 1 : 0]}</span>
      <div style={{ marginTop: 12, height: 86, flexShrink: 0, borderRadius: 12, background: diag(...page.colors), color: white(0.95), display: "grid", placeItems: "center" }}>
        <page.Icon size={42} strokeWidth={2.4} />
      </div>
      <div style={{ paddingTop: 16, display: "flex", flexDirection: "column", gap: 8 }}>
        {[0, 1, 2, 3].map((line) => (
          <div key={line} style={{ height: 6, borderRadius: 3, background: hex(INK, 0.16), maxWidth: line === 3 ? 110 : undefined }} />
        ))}
      </div>
      <span style={{ flex: 1 }} />
      <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, fontFamily: fonts.serif, color: hex(INK, 0.5), textAlign: "center" }}>{page.chapter}</span>
    </div>
  );
});
