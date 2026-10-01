/** icons.airdrop-rings · 隔空投送圆环 (Icons+AirdropRings.swift) */
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Stage, arcPath, checkPath, useIconNow, useLater, usePhase, usePlayhead } from "./_time-kit";

const REACH = 88;
const INNER = 16;
const FIRST_LOCKED = 36;

/** Blue while searching, green once locked. */
const blend = (tint: number, alpha = 1) => {
  const k = IC.unit(tint);
  const c = (a: number, b: number) => Math.round(IC.mix(a, b, k) * 255);
  return `rgb(${c(0.227, 0.173)} ${c(0.545, 0.784)} ${c(1.0, 0.451)} / ${alpha})`;
};

export default function AirdropRings({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  /** On = locked on. */
  const play = usePlayhead(false);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const locked = play.isOn;
  /** Search cycles elapsed (one unit = one ring period). */
  const phase = usePhase(now, 1 / Math.max(ctx.n("period"), 0.1));

  const count = Math.max(ctx.i("rings"), 1);
  const damping = ctx.n("damping");

  const toggle = (scripted = false) => {
    if (play.toggle(1.0, 0.4)) {
      haptics.tap("light");
      later(0.3, scripted, (h) => h.success());
    } else {
      haptics.tap("soft");
    }
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.4 });

  const lock = (index: number) => (locked ? IC.spring(t - 0.05 - 0.07 * index, 0.42, damping) : 1 - IC.easeOut(IC.seg(t, 0, 0.35)));
  const tint = IC.unit(lock(0));

  const swell = locked ? IC.spring(t - 0.22, 0.34, 0.5) : 1 - IC.easeIn(IC.seg(t, 0, 0.18));
  const breathe = 1 + 0.12 * Math.sin(phase * 2 * Math.PI);
  const size = Math.max(IC.mix(18 * breathe, 44, swell), 1);
  const stroke = locked ? IC.easeOut(IC.seg(t, 0.34, 0.56)) : 1 - IC.seg(t, 0, 0.1);
  const cp = IC.seg(t - 0.3, 0, 0.6);
  const confirmLive = locked && cp > 0 && cp < 1;

  return (
    <Stage gap={10}>
      <svg width={250} height={204} viewBox="-125 -102 250 204" onClick={() => toggle()} style={{ display: "block", overflow: "visible", cursor: "pointer", flexShrink: 0 }}>
        {confirmLive && <circle r={44 * (0.5 + 2.1 * IC.easeOut(cp))} fill="none" stroke={hex(0x2cc873, 0.6 * (1 - cp))} strokeWidth={(5 * (1 - cp) + 0.5) * (0.5 + 2.1 * IC.easeOut(cp))} />}
        {Array.from({ length: count }, (_, index) => {
          const amount = lock(index);
          const held = IC.unit(amount);
          // Search pose: born at the centre, grows and fades.
          const cycle = phase + index / count;
          const p = cycle - Math.floor(cycle);
          const searchRadius = IC.mix(INNER, REACH, IC.easeOut(p));
          const searchOpacity = Math.pow(IC.bump(p), 0.7);
          const searchWidth = 8 - 4.5 * p;
          let spin = (phase * 70 + index * 47) % 360;
          if (spin > 180) spin -= 360;
          // Locked pose: evenly spaced, fully closed, fading slightly outward.
          const step = count > 1 ? (REACH - FIRST_LOCKED) / (count - 1) : 0;
          const radius = Math.max(IC.mix(searchRadius, FIRST_LOCKED + step * index, amount), 2);
          const gap = 80 * (1 - held);
          const common = { fill: "none", stroke: blend(tint), strokeWidth: IC.mix(searchWidth, 7, held), strokeLinecap: "round" as const, opacity: IC.mix(searchOpacity, 1 - 0.22 * index, held) };
          return gap < 0.5 ? (
            <circle key={index} r={radius} {...common} />
          ) : (
            <path key={index} d={arcPath(0, 0, radius, 90 + gap / 2, 450 - gap / 2)} transform={`rotate(${spin * (1 - held)})`} {...common} />
          );
        })}
        <circle r={size / 2} fill={blend(tint)} style={{ filter: `drop-shadow(0 3px 8px ${blend(tint, 0.5)})` }} />
        {stroke > 0 && (
          <path
            d={checkPath(20, 17)}
            transform="translate(-10 -8.5)"
            fill="none"
            stroke="#fff"
            strokeWidth={5}
            strokeLinecap="round"
            strokeLinejoin="round"
            pathLength={1}
            strokeDasharray={`${stroke} 2`}
          />
        )}
      </svg>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {[false, true].map((state) => (
          <span key={String(state)} style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap", opacity: locked === state ? 1 : 0, transition: "opacity 0.25s ease-in-out" }}>
            {state ? ctx.t("Connected to Mia's phone", "已连接 Mia 的手机") : ctx.t("Looking for nearby devices…", "正在寻找附近的设备…")}
          </span>
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap to lock on or search again" zh="点击锁定或重新搜索" />
    </Stage>
  );
}
