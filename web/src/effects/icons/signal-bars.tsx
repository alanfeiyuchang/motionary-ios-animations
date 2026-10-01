/** icons.signal-bars · 信号格 (Icons+SignalBars.swift) */
import { useId, useRef } from "react";
import { DemoHint, Palette, fonts, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Item, RollText, Stage, Svg, Z, rr, useIconNow, useLater, usePlayhead } from "./_time-kit";

const SEARCH_START = 0.42;
const BAR_W = 28;
const SPACING = 13;
const TALLEST = 124;
const SHORTEST = 34;
const STUB = 16;
const BASELINE = 66;
const SLASH = `M-40 0L40 ${(0.908 - 0.5) * 196}`;

export default function SignalBars({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  /** On = connected. */
  const play = usePlayhead(false);
  const playRef = useRef(play);
  playRef.current = play;
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const on = play.isOn;

  const count = Math.max(ctx.i("bars"), 1);
  const stagger = ctx.n("stagger");
  const search = ctx.n("search");
  const damping = ctx.n("damping");
  /** When the bars start to fill, measured from the tap that connects. */
  const fillStart = SEARCH_START + search;
  const connectDuration = fillStart + count * stagger + 0.5;
  const dropDuration = count * stagger + 0.5;
  const stage = on ? (t < fillStart ? 1 : 2) : 0;

  const toggle = (scripted = false) => {
    const isOn = play.toggle(connectDuration, dropDuration);
    haptics.tap("light");
    if (isOn) later(fillStart + (count - 1) * stagger + 0.1, scripted, (h) => playRef.current.isOn && h.success());
    else later(count * stagger + 0.3, scripted, (h) => !playRef.current.isOn && h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: Math.max(connectDuration, dropDuration) + 0.9 });

  const slashStart = (count - 1) * stagger + 0.14;
  /** 0 = stub, 1 = full-height track. */
  const growth = (index: number) => {
    if (on) return IC.easeOut(IC.seg(t, 0.1 + 0.04 * index, 0.32 + 0.04 * index));
    const order = count - 1 - index;
    return 1 - IC.easeIn(IC.seg(t, order * stagger, order * stagger + 0.2));
  };
  /** 0 = empty, 1 = full; springs past 1 while filling. */
  const fill = (index: number) => (on ? IC.spring(t - fillStart - index * stagger, 0.36, damping) : growth(index));
  /** 0…1: how strongly the searching glint lights bar `index`. */
  const glint = (index: number) => {
    if (!(on && t > SEARCH_START && t < fillStart)) return 0;
    const cycle = ((t - SEARCH_START) / 0.6) % 1;
    const head = -1 + cycle * (count + 1);
    return Math.max(0, 1 - Math.abs(head - index));
  };
  const cut = on ? 1 - IC.easeIn(IC.seg(t, 0, 0.16)) : IC.easeOut(IC.seg(t, slashStart, slashStart + 0.26));
  const rock = on ? 0 : -4 * IC.shake(t - slashStart - 0.2, 9, 24);
  const arrive = on ? IC.spring(t - fillStart - count * stagger - 0.04, 0.32, 0.5) : 1 - IC.easeIn(IC.seg(t, 0, 0.14));
  const total = count * BAR_W + (count - 1) * SPACING;
  const dash = { pathLength: 1, strokeDasharray: `${cut} 2`, strokeLinecap: "round" as const, fill: "none" };
  const captions = [ctx.t("No service", "无服务"), ctx.t("Searching…", "搜索中…"), ctx.t("Connected · full signal", "已连接 · 信号满格")];

  return (
    <Stage gap={10}>
      <Z w={250} h={196} onClick={() => toggle()} style={{ transform: `rotate(${rock}deg)` }}>
        <Svg w={250} h={196}>
          <defs>
            <linearGradient id={`${uid}-green`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0" stopColor={hex(0x5be89a)} />
              <stop offset="1" stopColor={hex(0x1fb86a)} />
            </linearGradient>
            <mask id={`${uid}-cut`} maskUnits="userSpaceOnUse" x={-200} y={-150} width={400} height={300}>
              <rect x={-200} y={-150} width={400} height={300} fill="#fff" />
              {cut > 0.001 && <path d={SLASH} stroke="#000" strokeWidth={24} {...dash} />}
            </mask>
            {Array.from({ length: count }, (_, index) => (
              <clipPath key={index} id={`${uid}-bar${index}`}>
                <path d={barShape(index, count, growth(index), total).d} />
              </clipPath>
            ))}
          </defs>
          <g mask={`url(#${uid}-cut)`}>
            {Array.from({ length: count }, (_, index) => {
              const shape = barShape(index, count, growth(index), total);
              const level = fill(index);
              const lit = glint(index);
              const stretch = on ? 1 + 0.9 * Math.max(level - 1, 0) : 1;
              const filled = shape.height * IC.unit(level);
              return (
                <g
                  key={index}
                  transform={`translate(0 ${-4 * lit}) translate(0 ${BASELINE}) scale(1 ${stretch}) translate(0 ${-BASELINE})`}
                  style={{ filter: `drop-shadow(0 4px 8px ${hex(0x1fb86a, 0.35 * IC.unit(level))})` }}
                >
                  <g clipPath={`url(#${uid}-bar${index})`}>
                    <rect x={shape.x} y={BASELINE - shape.height} width={BAR_W} height={shape.height} fill={hex(0x8e8e99, 0.32)} />
                    <rect x={shape.x} y={BASELINE - shape.height} width={BAR_W} height={shape.height} fill={hex(0x3ac4ff, 0.75 * lit)} />
                    <rect x={shape.x} y={BASELINE - filled} width={BAR_W} height={filled} fill={`url(#${uid}-green)`} />
                  </g>
                </g>
              );
            })}
          </g>
          {cut > 0.001 && <path d={SLASH} stroke={Palette.red} strokeWidth={10} {...dash} style={{ filter: `drop-shadow(0 3px 6px ${hex(0xff4d5e, 0.4)})` }} />}
        </Svg>
        <Item
          tf={`translate(-74px, -62px) scale(${Math.max(arrive, 0)})`}
          style={{
            padding: "5px 10px",
            borderRadius: 16,
            background: `linear-gradient(${hex(0x5be89a)}, ${hex(0x1fb86a)})`,
            boxShadow: `0 3px 6px ${hex(0x1fb86a, 0.4)}`,
            color: "#fff",
            fontFamily: fonts.rounded,
            fontSize: 17,
            lineHeight: "21px",
            fontWeight: 800,
          }}
        >
          5G
        </Item>
      </Z>
      <RollText k={stage} style={{ ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {captions[stage]}
      </RollText>
      <DemoHint ctx={ctx} en="Tap to connect or drop the signal" zh="点击连接或断开信号" />
    </Stage>
  );
}

/** Bar `index` standing on the baseline: its left edge, current height and rounded outline. */
function barShape(index: number, count: number, grown: number, total: number) {
  const step = count > 1 ? index / (count - 1) : 1;
  const full = SHORTEST + (TALLEST - SHORTEST) * step;
  const stub = Math.max(STUB, full * 0.42);
  const height = stub + (full - stub) * grown;
  const x = -total / 2 + index * (BAR_W + SPACING);
  return { x, height, d: rr(x, BASELINE - height, BAR_W, height, 9) };
}
