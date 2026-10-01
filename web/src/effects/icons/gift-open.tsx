/** icons.gift-open · 礼盒开启 (Icons+GiftOpen.swift) */
import { DemoHint, hex, useAutoplay, type DemoProps } from "../../kit";
import { IC, Item, Stage, Svg, Z, rotateAt, scaleAt, sparklePath, useIconNow, useLater, usePlayhead } from "./_time-kit";

const BOX_W = 124;
const BOX_H = 86;
const LID_W = 142;
const LID_H = 32;
/** Top edge of the box, relative to the scene's centre. */
const BOX_TOP = 12;
const SPARK_COLORS = [0xffd466, 0xfff1b8, 0xff8cbe, 0x7cd8ff, 0x8cf0c8];
const RIBBON = `linear-gradient(to right, ${hex(0xffe08a)}, ${hex(0xf5a623)})`;

export default function GiftOpen({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  /** On = open. */
  const play = usePlayhead(false);
  const clock = useIconNow(ctx.isPreview);
  const t = play.elapsed(clock);
  const open = play.isOn;

  const lift = ctx.n("lift");
  const sparkles = Math.max(ctx.i("sparkles"), 0);
  const wiggle = ctx.n("wiggle");

  const toggle = (scripted = false) => {
    const on = play.toggle(1.1, 0.6);
    haptics.tap("light");
    if (on) later(0.18, scripted, (h) => h.success());
    else later(0.14, scripted, (h) => h.tap("rigid"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.0 });

  // Closing is rectified, so the lid bounces on the rim instead of passing through it.
  const up = open ? IC.spring(t - 0.1, 0.42, 0.55) : Math.abs(1 - IC.spring(t, 0.32, 0.42));
  const press = open ? 0.06 * IC.bump(IC.seg(t, 0, 0.2)) : 0.07 * IC.ring(t - 0.11, 12, 30) * IC.seg(t, 0.11, 0.13);
  const shownGlow = IC.unit(up) * (0.85 + 0.15 * Math.sin(clock * 2.6)) * (open ? 1 : 0.6);
  const bob = open ? 3 * Math.sin(clock * 2.4) * IC.seg(t, 0.8, 1.4) : 0;
  const shake = open ? IC.shake(t - 0.1, 5, 20) : 0.4 * IC.shake(t - 0.11, 8, 24);
  const swing = wiggle * shake;
  const twinkle = open ? IC.seg(t, 0.7, 1.2) : 0;
  const lidStack = LID_H + 23;

  const loop = (side: number) => (
    <Svg w={32} h={20} tf={`translate(${side * 19}px, -3px) ${rotateAt(side * (24 + swing), -side * 16, 10)}`}>
      <defs>
        <linearGradient id="gift-ribbon" x1={-20} y1="0" x2={20} y2="0" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor={hex(0xffe08a)} />
          <stop offset="1" stopColor={hex(0xf5a623)} />
        </linearGradient>
      </defs>
      <ellipse rx={16} ry={10} fill="none" stroke="url(#gift-ribbon)" strokeWidth={8} />
    </Svg>
  );

  return (
    <Stage gap={8}>
      <Z w={250} h={236} onClick={() => toggle()}>
        <Item
          w={130 * (1 + press)}
          h={14}
          tf={`translateY(${BOX_TOP + BOX_H + 3}px)`}
          style={{ borderRadius: "50%", background: "rgb(0 0 0 / 0.18)", filter: "blur(8px)" }}
        />
        <Item
          w={160}
          h={120}
          tf={`translateY(${BOX_TOP - 22}px)`}
          o={shownGlow}
          style={{
            borderRadius: "50%",
            filter: "blur(6px)",
            background: `radial-gradient(circle 80px at center, ${hex(0xffe9a0, 0.95)} 2px, ${hex(0xffc247, 0.5)} 41px, ${hex(0xffc247, 0)} 80px)`,
          }}
        />
        <Item
          w={BOX_W}
          h={BOX_H}
          tf={`translateY(${BOX_TOP + BOX_H / 2}px) ${scaleAt(1 + press * 0.6, 1 - press, 0, BOX_H / 2)}`}
          style={{ filter: `drop-shadow(0 8px 14px ${hex(0xee4a85, 0.35)})` }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: "4px 4px 16px 16px", overflow: "hidden", background: `linear-gradient(${hex(0xff86b0)}, ${hex(0xee4a85)})` }}>
            <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 12, background: hex(0x9c1f52) }} />
            <div style={{ position: "absolute", left: BOX_W / 2 - 12, top: 0, bottom: 0, width: 24, background: RIBBON }} />
            <div style={{ position: "absolute", left: 0, right: 0, top: 12, height: 5, background: "rgb(0 0 0 / 0.14)" }} />
          </div>
        </Item>
        <Z style={{ gridArea: "1 / 1" }}>
          {[0, 1, 2].map((index) => {
            const beat = 0.5 + 0.5 * Math.sin(clock * (2.2 + 0.5 * index) + index * 2.1);
            return (
              <Svg key={index} w={17} h={17} tf={`translate(${-46 + 44 * index}px, ${BOX_TOP - 30 - (index === 1 ? 20 : 0)}px) scale(${0.5 + 0.6 * beat})`} o={twinkle * (0.3 + 0.7 * beat)}>
                <path d={sparklePath(8.5)} fill={hex(0xffe08a)} />
              </Svg>
            );
          })}
        </Z>
        <Z style={{ gridArea: "1 / 1", transform: `translateY(${BOX_TOP}px)`, opacity: open ? 1 : 0 }}>
          {Array.from({ length: sparkles }, (_, index) => {
            const delay = 0.16 + 0.14 * IC.hash(index * 3 + 1);
            const life = 0.75 + 0.3 * IC.hash(index * 3 + 2);
            const p = IC.seg(t, delay, delay + life);
            if (!(p > 0 && p < 1)) return null;
            const eased = IC.easeOut(p);
            // An upward fan from 150° to 30°, evenly spread with a little jitter.
            const spread = (index + 0.5) / Math.max(sparkles, 1);
            const heading = ((-150 + 120 * spread + 14 * (IC.hash(index * 3 + 5) - 0.5)) * Math.PI) / 180;
            const reach = 80 + 80 * IC.hash(index * 3 + 7);
            const size = 16 + 13 * IC.hash(index * 3 + 9);
            return (
              <Svg
                key={index}
                w={size}
                h={size}
                tf={`translate(${Math.cos(heading) * reach * eased}px, ${Math.sin(heading) * reach * eased + 46 * p * p}px) rotate(${200 * p * (index % 2 === 0 ? 1 : -1)}deg) scale(${0.3 + 1.1 * IC.bump(IC.unit(p * 1.15))})`}
                o={1 - IC.easeIn(p)}
              >
                <path d={sparklePath(size / 2)} fill={hex(SPARK_COLORS[index % SPARK_COLORS.length])} />
              </Svg>
            );
          })}
        </Z>
        <Z
          w={LID_W}
          h={lidStack}
          style={{
            gridArea: "1 / 1",
            transform: `translateY(${press * BOX_H}px) translate(${10 * up}px, ${BOX_TOP - 4 - lidStack / 2 + LID_H / 2 - lift * up + bob}px) ${rotateAt(13 * up, 0, lidStack / 2)}`,
          }}
        >
          <Z w={96} h={28} style={{ gridArea: "1 / 1", transform: `translateY(${-lidStack / 2 + 14}px)`, filter: `drop-shadow(0 2px 3px ${hex(0xc2861a, 0.4)})` }}>
            {loop(-1)}
            {loop(1)}
            <Item w={17} h={17} tf="translateY(5px)" style={{ borderRadius: "50%", background: `linear-gradient(${hex(0xffe9a0)}, ${hex(0xf5a623)})` }} />
          </Z>
          <Item w={LID_W} h={LID_H} tf={`translateY(${lidStack / 2 - LID_H / 2}px)`} style={{ filter: `drop-shadow(0 4px 6px ${hex(0xc2306b, 0.35)})` }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 9, overflow: "hidden", background: `linear-gradient(${hex(0xff9cc0)}, ${hex(0xf25c93)})` }}>
              <div style={{ position: "absolute", left: LID_W / 2 - 12, top: 0, bottom: 0, width: 24, background: RIBBON }} />
              <div style={{ position: "absolute", left: 12, right: 12, top: 4, height: 3, borderRadius: 1.5, background: "rgb(255 255 255 / 0.35)" }} />
            </div>
          </Item>
        </Z>
      </Z>
      <DemoHint ctx={ctx} en="Tap to open or close the gift" zh="点击打开或合上礼盒" />
    </Stage>
  );
}
