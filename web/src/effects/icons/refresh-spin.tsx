/** icons.refresh-spin · 刷新旋转 (Icons+RefreshSpin.swift) */
import { useRef } from "react";
import { DemoHint, Palette, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { CheckCircleFill, DISTANT_PAST, IC, Item, Stage, Svg, Z, arcPath, nowSeconds, since, useIconNow, useLater } from "./_time-kit";

const HEAD = -52;
const WIND_UP = 24;
const WIND_TIME = 0.14;
const GHOST_GAP = 0.008;
const DISC = 152;
const R = 33;

/** When the spring first reaches its target (for damping below 1), capped for the critically damped case. */
function settleTime(response: number, damping: number) {
  const zeta = Math.min(Math.max(damping, 0.05), 0.999);
  const root = Math.sqrt(1 - zeta * zeta);
  const omega = (2 * Math.PI) / Math.max(response, 0.05);
  const crossing = (Math.PI - Math.acos(zeta)) / (omega * root);
  return WIND_TIME + Math.min(crossing, response * 1.1);
}

function Arrow({ span, lineWidth, angle, opacity }: { span: number; lineWidth: number; angle: number; opacity?: number }) {
  const a = (HEAD * Math.PI) / 180;
  const rad = [Math.cos(a), Math.sin(a)];
  const tan = [-Math.sin(a), Math.cos(a)];
  const size = lineWidth * 1.45;
  const back = size * 0.55;
  const ax = rad[0] * R;
  const ay = rad[1] * R;
  const head = `M${ax + tan[0] * size * 0.75} ${ay + tan[1] * size * 0.75}L${ax - tan[0] * back + rad[0] * size} ${ay - tan[1] * back + rad[1] * size}L${ax - tan[0] * back - rad[0] * size} ${ay - tan[1] * back - rad[1] * size}Z`;
  return (
    <g transform={`rotate(${angle})`} opacity={opacity}>
      <path d={arcPath(0, 0, R, HEAD - span, HEAD - 8)} fill="none" stroke="url(#refresh-ocean)" strokeWidth={lineWidth} strokeLinecap="round" />
      <path d={head} fill="url(#refresh-ocean)" stroke="url(#refresh-ocean)" strokeWidth={lineWidth * 0.45} strokeLinejoin="round" />
    </g>
  );
}

export default function RefreshSpin({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const start = useRef(DISTANT_PAST);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const turns = ctx.i("turns");
  const response = ctx.n("response");
  const damping = ctx.n("damping");
  const trail = Math.max(ctx.i("trail"), 0);
  const settle = settleTime(response, damping);

  const refresh = (scripted = false) => {
    // A refresh already under way finishes first.
    if (since(nowSeconds(), start.current) <= settle + 0.1) return;
    start.current = nowSeconds();
    haptics.tap("light");
    later(settle, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => refresh(true), { every: 2.4 });

  /** Rotation in degrees at `time` seconds after the tap: a whole number of turns. */
  const angle = (time: number) => {
    if (!(time > 0)) return 0;
    if (time < WIND_TIME) return -WIND_UP * IC.easeOut(time / WIND_TIME);
    return -WIND_UP + (360 * turns + WIND_UP) * IC.spring(time - WIND_TIME, response, damping);
  };
  const tickFlare = (index: number) => {
    if (!(t < 20)) return 0;
    const tick = index * 30 - 90;
    const step = 0.025;
    for (let sample = 0; sample < 14; sample++) {
      const end = t - sample * step;
      if (!(end > 0)) break;
      const a = (HEAD + angle(end - step) - tick) / 360;
      const b = (HEAD + angle(end) - tick) / 360;
      if (Math.floor(a) !== Math.floor(b)) return 1 - sample / 14;
    }
    return 0;
  };

  const cur = angle(t);
  const speed = Math.abs(cur - angle(t - 0.016)) / 0.016;
  const blur = IC.unit(speed / 1700);
  const flash = IC.seg(t, settle, settle + 0.03) * (1 - IC.seg(t, settle + 0.03, settle + 0.5));
  const press = 0.06 * IC.bump(IC.seg(t, 0, 0.26)) - 0.035 * IC.shake(t - settle, 9, 26);
  const ringP = IC.seg(t - settle, 0, 0.6);
  const span = 290 + 44 * blur;
  const width = 8.5 - 2 * blur;

  const leaving = IC.seg(t, 0, 0.1);
  const busyIn = IC.easeOut(IC.seg(t, 0.1, 0.26));
  const busyOut = IC.seg(t, settle, settle + 0.1);
  const arriving = IC.easeOut(IC.seg(t, settle + 0.1, settle + 0.34));
  const busy = busyIn * (1 - busyOut);
  const done = t < settle ? 1 - leaving : arriving;
  const doneShift = t < settle ? -8 * leaving : 8 * (1 - arriving);

  return (
    <Stage gap={10}>
      <div onClick={() => refresh()} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 14, cursor: "pointer" }}>
        <Z w={210} h={196}>
          <Z style={{ gridArea: "1 / 1", transform: `scale(${1 - press})` }}>
            <Svg w={DISC} h={DISC} tf={`scale(${1 + 0.26 * IC.easeOut(ringP)})`} o={ringP > 0 && ringP < 1 ? 1 : 0}>
              <circle r={DISC / 2} fill="none" stroke={`rgb(33 212 168 / ${0.7 * (1 - ringP)})`} strokeWidth={4 * (1 - ringP) + 0.5} />
            </Svg>
            <Item
              w={DISC}
              h={DISC}
              style={{ borderRadius: "50%", background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 9px 16px rgb(0 0 0 / 0.14)` }}
            />
            {Array.from({ length: 12 }, (_, index) => {
              const m = Math.max(tickFlare(index), flash);
              return (
                <Item
                  key={index}
                  w={3}
                  h={8 + 3 * m}
                  tf={`rotate(${index * 30}deg) translateY(-62px)`}
                  o={0.16 + 0.84 * m}
                  style={{ borderRadius: 1.5, background: Palette.sky, overflow: "hidden" }}
                >
                  <div style={{ position: "absolute", inset: 0, background: Palette.mint, opacity: flash }} />
                </Item>
              );
            })}
            <Svg w={96} h={96}>
              <defs>
                <linearGradient id="refresh-ocean" x1={-48} y1={-48} x2={48} y2={48} gradientUnits="userSpaceOnUse">
                  <stop offset="0" stopColor={Palette.sky} />
                  <stop offset="1" stopColor={Palette.blue} />
                </linearGradient>
              </defs>
              {Array.from({ length: trail }, (_, k) => trail - 1 - k).map((index) => {
                const lagged = angle(t - (index + 1) * GHOST_GAP);
                return <Arrow key={index} span={span} lineWidth={width} angle={lagged} opacity={Math.abs(lagged - cur) > 1 ? 0.3 * (1 - index / (trail + 1)) : 0} />;
              })}
              <Arrow span={span} lineWidth={width} angle={cur} />
            </Svg>
          </Z>
        </Z>
        <Z h={20} style={{ ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
          <Item tf={`translateY(${t < settle ? 8 * (1 - busyIn) : -8 * busyOut}px)`} o={busy}>
            {ctx.t("Refreshing…", "正在刷新…")}
          </Item>
          <Item tf={`translateY(${doneShift}px)`} o={done} style={{ display: "flex", alignItems: "center", gap: 5 }}>
            <CheckCircleFill size={17} color={Palette.mint} />
            <span>{ctx.t("Updated just now", "刚刚更新")}</span>
          </Item>
        </Z>
      </div>
      <DemoHint ctx={ctx} en="Tap to refresh" zh="点击刷新" />
    </Stage>
  );
}
