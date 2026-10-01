/** cards.spotlight-border · 聚光描边卡片组 (Cards+SpotlightBorder.swift) */
import { animate, useMotionValue } from "motion/react";
import { ShieldCheck, TrendingUp, Zap, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, Palette, black, clamp, hex, spring, useClock, useHaptics, usePan, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, tr, useMV, type LText } from "./shared";

const AREA = { w: 308, h: 268 };
const CARDS = [
  { x: 0, y: 0, w: 308, h: 120 },
  { x: 0, y: 132, w: 148, h: 136 },
  { x: 160, y: 132, w: 148, h: 136 },
];
const ICONS: LucideIcon[] = [Zap, ShieldCheck, TrendingUp];
const TITLES: LText[] = [["Realtime sync", "实时同步"], ["Private", "私密"], ["Insights", "洞察"]];
const DETAILS: LText[] = [
  ["Every change lands on all devices in 40 ms.", "每次改动 40 毫秒内到达所有设备。"],
  ["End-to-end encrypted.", "端到端加密。"],
  ["Trends, at a glance.", "趋势一目了然。"],
];
const TINTS = [0xffffff, 0x8e9bff, 0xff7a1a];

const idleLight = (t: number) => ({
  x: AREA.w / 2 + Math.cos(t * 0.7) * AREA.w * 0.42,
  y: AREA.h / 2 + Math.sin(t * 1.1) * AREA.h * 0.4,
});
const now = () => Date.now() / 1000;

export default function SpotlightBorder({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const lx = useMotionValue(205);
  const ly = useMotionValue(104);
  const strengthMV = useMotionValue(1);
  const [touched, setTouched] = useState(false);
  const touchedRef = useRef(false);
  const held = useRef(false);
  useClock(!touched, ctx.isPreview ? 30 : undefined);

  const release = () => {
    if (!held.current) return;
    held.current = false;
    const t = spring(0.9, 0.85);
    animate(lx, (lx.get() + AREA.w / 2) / 2, t);
    animate(ly, (ly.get() + AREA.h / 2) / 2, t);
    animate(strengthMV, 0.55, t);
  };

  const pan = usePan({
    onChange: ({ location }) => {
      if (!touchedRef.current) {
        const p = idleLight(now());
        lx.jump(p.x);
        ly.jump(p.y);
        touchedRef.current = true;
        setTouched(true);
      }
      if (!held.current) {
        held.current = true;
        haptics.tap("soft");
      }
      const t = spring(ctx.n("lag"), 0.8);
      animate(lx, clamp(location.x, -30, AREA.w + 30), t);
      animate(ly, clamp(location.y, -30, AREA.h + 30), t);
      animate(strengthMV, 1, t);
    },
    onEnd: release,
  });

  const mx = useMV(lx);
  const my = useMV(ly);
  const light = touched ? { x: mx, y: my } : idleLight(now());
  const strength = useMV(strengthMV) * ctx.n("intensity");
  const tint = TINTS[ctx.i("tint")] ?? TINTS[1];

  return (
    <Stage gap={20}>
      <div {...pan} style={{ position: "relative", width: AREA.w, height: AREA.h, flexShrink: 0, touchAction: "none" }}>
        {CARDS.map((r, i) => (
          <div key={i} style={{ position: "absolute", left: r.x, top: r.y }}>
            <Card index={i} w={r.w} h={r.h} light={{ x: light.x - r.x, y: light.y - r.y }} strength={strength} radius={ctx.n("radius")} tint={tint} ctx={ctx} />
          </div>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Drag across the cards" zh="在卡片上拖动" />
    </Stage>
  );
}

function Card({ index, w, h, light, strength, radius, tint, ctx }: { index: number; w: number; h: number; light: { x: number; y: number }; strength: number; radius: number; tint: number; ctx: DemoContext }) {
  const iconLit = Math.max(0, 1 - Math.hypot(light.x - 34, light.y - 34) / radius) * strength;
  const at = `at ${light.x.toFixed(1)}px ${light.y.toFixed(1)}px`;
  const rim = `radial-gradient(circle ${radius * 0.9}px ${at}, ${white(0.95 * strength)} 0%, ${hex(tint, 0.75 * strength)} 35%, ${hex(tint, 0)} 100%)`;
  const Icon = ICONS[index];
  return (
    <div style={{ position: "relative", width: w, height: h, borderRadius: 22, boxShadow: `0 8px 14px ${black(0.28)}` }}>
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 22,
          background: `radial-gradient(circle ${radius}px ${at}, ${hex(tint, 0.3 * strength)}, ${hex(tint, 0)}), #0E0F13`,
        }}
      />
      <div style={{ position: "absolute", inset: 0, padding: 16, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <div style={{ display: "flex", alignItems: "flex-start", alignSelf: "stretch" }}>
          <div
            style={{
              width: 36,
              height: 36,
              borderRadius: 11,
              display: "grid",
              placeItems: "center",
              color: white(0.42 + 0.58 * iconLit),
              background: white(0.05 + 0.09 * iconLit),
              filter: `drop-shadow(0 0 9px ${hex(tint, 0.85 * iconLit)})`,
            }}
          >
            {index === 0 ? <Zap size={16} fill="currentColor" strokeWidth={1} style={{ transform: "rotate(90deg) scaleX(-1)" }} /> : <Icon size={17} strokeWidth={2.3} />}
          </div>
          <span style={{ flex: 1 }} />
          {index === 0 && (
            <div style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 9px", borderRadius: 99, background: white(0.06) }}>
              <div style={{ width: 6, height: 6, borderRadius: 3, background: Palette.green }} />
              <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: white(0.7) }}>{ctx.t("Live", "在线")}</span>
            </div>
          )}
        </div>
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600, color: white(0.94) }}>{tr(ctx, TITLES[index])}</span>
        <span
          style={{
            fontSize: 11.5,
            lineHeight: "14px",
            color: white(0.46),
            marginTop: 3,
            display: "-webkit-box",
            WebkitLineClamp: 2,
            WebkitBoxOrient: "vertical",
            overflow: "hidden",
          }}
        >
          {tr(ctx, DETAILS[index])}
        </span>
      </div>
      <StrokeBorder radius={22} width={1} color={white(0.07)} />
      <StrokeBorder radius={22} width={3} color={rim} style={{ filter: "blur(5px)", mixBlendMode: "plus-lighter" }} />
      <StrokeBorder radius={22} width={1.5} color={rim} />
    </div>
  );
}
