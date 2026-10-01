/** icons.cloud-sync · 云同步 (Icons+CloudSync.swift) */
import { useId, useRef, useState } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, arcPath, checkPath, nowSeconds, polar, rr, since, useIconNow, useLater } from "./_time-kit";

const ARROWS_IN = 0.12;
const HALF_TURN = 0.55;
const GLYPH_Y = 12;
const CW = 166;
const CH = 108;

/** The cloud silhouette (`cloud.fill` at 132 pt) as a union of lobes, centred on the origin. */
const CloudLobes = () => (
  <>
    <circle cx={-51} cy={22} r={32} />
    <circle cx={50} cy={21} r={33} />
    <rect x={-51} y={22} width={101} height={32} />
    <circle cx={-6} cy={-8} r={46} />
    <circle cx={38} cy={2} r={30} />
  </>
);

function heads(radius: number, size: number) {
  let d = "";
  for (const base of [0, 180]) {
    const deg = base + 156;
    const a = (deg * Math.PI) / 180;
    const rad = [Math.cos(a), Math.sin(a)];
    const tan = [-Math.sin(a), Math.cos(a)];
    const [ax, ay] = polar(0, 0, radius, deg);
    d += `M${ax + tan[0] * size} ${ay + tan[1] * size}L${ax - tan[0] * size * 0.3 + rad[0] * size} ${ay - tan[1] * size * 0.3 + rad[1] * size}L${ax - tan[0] * size * 0.3 - rad[0] * size} ${ay - tan[1] * size * 0.3 - rad[1] * size}Z`;
  }
  return d;
}
const ARCS = arcPath(0, 0, 19, 28, 150) + arcPath(0, 0, 19, 208, 330);
const HEADS = heads(19, 7);

export default function CloudSync({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  const start = useRef(DISTANT_PAST);
  const runs = useRef(0);
  /** [failing, failedBefore]: how the current (or last) run ends, and how the one before it ended. */
  const [result, setResult] = useState<[boolean, boolean]>([false, false]);
  const [failing, failedBefore] = result;
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const end = ARROWS_IN + ctx.n("duration");
  const shake = ctx.n("shake");
  const mode = ctx.i("result");

  const sync = (scripted = false) => {
    // A sync already under way finishes first.
    if (since(nowSeconds(), start.current) <= end + 0.6) return;
    const fails = mode === 1 || (mode === 2 && runs.current % 2 === 1);
    setResult(([f]) => [fails, f]);
    runs.current += 1;
    start.current = nowSeconds();
    haptics.tap("light");
    later(end + 0.12, scripted, (h) => (fails ? h.error() : h.success()));
  };
  useAutoplay(ctx.isPreview, () => sync(true), { every: end + 1.9 });

  const after = t - end;
  const syncing = t < end;
  const breathe = syncing ? 0.02 * Math.sin(t * 6) * IC.seg(t, 0.1, 0.4) : 0;
  const bump = failing ? 0 : 0.2 * IC.shake(after, 7, 15);
  const sway = failing ? shake * IC.shake(after - 0.06, 5.5, 38) : 0;
  const sag = failing ? 4 * IC.easeOut(IC.seg(after, 0, 0.2)) : 0;
  const press = 0.05 * IC.bump(IC.seg(t, 0, 0.26));

  const tint = syncing ? 1 - IC.seg(t, 0, 0.25) : IC.seg(after, 0, 0.3);
  const red = syncing ? failedBefore : failing;

  // Arrows
  const arrive = IC.spring(t - ARROWS_IN, 0.36, 0.6);
  const leave = IC.easeIn(IC.seg(after, 0, 0.2));
  const steps = Math.max(t - ARROWS_IN, 0) / HALF_TURN;
  const whole = Math.floor(steps);
  const rotation = 180 * (whole + IC.easeInOut(steps - whole));
  const exit = failing ? -40 * leave : 180 * leave;
  const arrowScale = Math.max(arrive * (failing ? 1 : 1 - leave), 0);
  const arrowOpacity = t < ARROWS_IN || t > 9000 ? 0 : 1 - leave;

  // Check
  const erased = IC.easeIn(IC.seg(t, 0, 0.16));
  const drawn = IC.easeOut(IC.seg(after, 0.12, 0.42));
  const checkAmount = syncing ? (failedBefore ? 0 : 1 - erased) : failing ? 0 : drawn;
  const checkPop = syncing ? 1 : 0.6 + 0.4 * IC.spring(after - 0.12, 0.34, 0.5);

  // Exclamation
  const bar = failing ? IC.spring(after - 0.08, 0.3, 0.55) : 0;
  const dot = failing ? IC.spring(after - 0.2, 0.3, 0.5) : 0;
  const leftover = failedBefore ? 1 - IC.easeIn(IC.seg(t, 0, 0.16)) : 0;
  const exOpacity = syncing ? (leftover > 0.01 ? 1 : 0) : failing ? 1 : 0;
  const barScale = syncing ? leftover : Math.max(bar, 0);
  const dotScale = syncing ? leftover : Math.max(dot, 0);

  const gate = IC.seg(t, 0.2, 0.45) * (1 - IC.seg(t, end - 0.2, end));
  const ringP = failing ? 0 : IC.seg(after, 0.1, 0.75);

  const busy = IC.seg(t, 0.05, 0.25) * (1 - IC.seg(t, end, end + 0.2));
  const done = t < end ? 1 - IC.seg(t, 0, 0.15) : IC.easeOut(IC.seg(t, end + 0.1, end + 0.36));
  const failed = t < end ? failedBefore : failing;

  const grad = (id: string, top: string, bottom: string) => (
    <linearGradient id={`${uid}-${id}`} x1="0" y1={-CH / 2} x2="0" y2={CH / 2} gradientUnits="userSpaceOnUse">
      <stop offset="0" stopColor={top} />
      <stop offset="1" stopColor={bottom} />
    </linearGradient>
  );
  const fillRect = (id: string, opacity?: number) => <rect x={-CW / 2} y={-CH / 2} width={CW} height={CH} fill={`url(#${uid}-${id})`} opacity={opacity} />;

  return (
    <Stage gap={8}>
      <div onClick={() => sync()} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 6, cursor: "pointer" }}>
        <Z w={250} h={196}>
          <Svg w={150} h={96} tf={`translateY(6px) scale(${1 + 0.5 * IC.easeOut(ringP)})`} o={ringP > 0 && ringP < 1 ? 1 : 0}>
            <path d={rr(-75, -48, 150, 96, 48)} fill="none" stroke={`rgb(33 212 168 / ${0.7 * (1 - ringP)})`} strokeWidth={5 * (1 - ringP) + 0.5} />
          </Svg>
          <Z style={{ gridArea: "1 / 1", opacity: syncing ? gate : 0 }}>
            {[0, 1, 2, 3, 4].map((index) => {
              const phase = (t * 1.3 + index * 0.2) % 1;
              const x = (index - 2) * 17 + Math.sin(t * 3 + index) * 3;
              const y = 96 - 56 * IC.easeOut(phase);
              return (
                <Item
                  key={index}
                  w={7.5}
                  h={7.5}
                  tf={`translate(${x}px, ${y}px) scale(${1 - 0.45 * phase})`}
                  o={IC.bump(phase)}
                  style={{ borderRadius: "50%", background: Palette.sky }}
                />
              );
            })}
          </Z>
          <Svg
            w={CW}
            h={CH}
            tf={`translate(${sway}px, ${sag}px) scale(${1 + breathe + bump - press})`}
            style={{
              filter: `drop-shadow(0 10px 16px ${hex(0x4f7cff, 0.3 * (1 - tint))}) drop-shadow(0 10px 16px ${red ? hex(0xff4d5e, 0.32 * tint) : hex(0x34c77b, 0.32 * tint)})`,
            }}
          >
            <defs>
              {grad("blue", hex(0x6ccbff), Palette.blue)}
              {grad("green", hex(0x5fe0a4), hex(0x1fa866))}
              {grad("red", hex(0xff8a8f), hex(0xe5374d))}
              <linearGradient id={`${uid}-sheen`} x1="0" y1={-CH / 2} x2="0" y2="0" gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor="#fff" stopOpacity={0.38} />
                <stop offset="1" stopColor="#fff" stopOpacity={0} />
              </linearGradient>
              <clipPath id={`${uid}-cloud`} transform="scale(0.93)">
                <CloudLobes />
              </clipPath>
            </defs>
            <g clipPath={`url(#${uid}-cloud)`}>
              {fillRect("blue")}
              {fillRect("green", red ? 0 : tint)}
              {fillRect("red", red ? tint : 0)}
              {fillRect("sheen")}
            </g>
            <g transform={`translate(0 ${GLYPH_Y})`} fill="#fff" stroke="#fff">
              <g transform={`translate(0 ${failing ? 10 * leave : 0}) scale(${arrowScale}) rotate(${syncing ? rotation : rotation + exit})`} opacity={arrowOpacity}>
                <path d={ARCS} fill="none" strokeWidth={5.5} strokeLinecap="round" />
                <path d={HEADS} strokeWidth={2.5} strokeLinejoin="round" />
              </g>
              {checkAmount > 0.001 && (
                <g transform={`scale(${checkPop}) translate(-22 -18)`}>
                  <path d={checkPath(44, 36)} fill="none" strokeWidth={8} strokeLinecap="round" strokeLinejoin="round" pathLength={1} strokeDasharray={`${checkAmount} 2`} />
                </g>
              )}
              <g opacity={exOpacity} stroke="none">
                <g transform={`translate(0 -21.5) scale(1 ${barScale})`}>
                  <path d={rr(-4, 0, 8, 28, 4)} />
                </g>
                <circle cy={17} r={4.5 * dotScale} />
              </g>
            </g>
          </Svg>
        </Z>
        <Z h={20} style={{ ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
          <Item o={busy}>{ctx.t("Syncing…", "正在同步…")}</Item>
          <Item o={done} tf={`translateY(${t < end ? 0 : 8 * (1 - done)}px)`} style={{ color: failed ? Palette.red : undefined }}>
            {failed ? ctx.t("Sync failed · Tap to retry", "同步失败 · 点击重试") : ctx.t("All changes saved", "所有更改已保存")}
          </Item>
        </Z>
      </div>
      <DemoHint ctx={ctx} en="Tap the cloud to sync" zh="点击云朵开始同步" />
    </Stage>
  );
}
