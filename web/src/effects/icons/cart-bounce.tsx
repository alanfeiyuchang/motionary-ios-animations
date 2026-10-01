/** icons.cart-bounce · 购物车入篮 (Icons+CartBounce.swift) */
import { useId, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, fonts, hex, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Item, Stage, Svg, Z, nowSeconds, roundedPolygon, scaleAt, since, useIconNow, useLater } from "./_time-kit";

const GROUND = 80;
const SLOTS: [number, number][] = [
  [-24, -22],
  [32, -20],
  [6, -42],
];
const COLORS: [number, number][] = [
  [0xff9a7a, 0xff6048],
  [0xffd466, 0xffaa2b],
  [0x5be3c0, 0x14b893],
  [0x6cd2ff, 0x2e9cf0],
  [0xff8cbe, 0xf04e93],
];
const BASKET = roundedPolygon(
  [
    [-72, -20],
    [90, -20],
    [72, 34],
    [-58, 34],
  ],
  (i) => (i < 2 ? 7 : 13),
);
const wire = (x0: number, y0: number, x1: number, y1: number) => `M${-125 + 250 * x0} ${-118 + 236 * y0}L${-125 + 250 * x1} ${-118 + 236 * y1}`;
const WIRES = wire(0.33, 0.45, 0.36, 0.61) + wire(0.53, 0.45, 0.53, 0.61) + wire(0.74, 0.45, 0.71, 0.61);

/** When the falling parcel reaches its slot: a short hover, then a fall whose time grows with the height. */
const landing = (height: number) => 0.14 + 0.33 * Math.sqrt(Math.max(height, 1) / 100);
const tilt = (item: number) => (IC.hash(item + 7) - 0.5) * 22;
/** The newest landed parcel resting in `slot`, if any. */
function latest(slot: number, landed: number): number | null {
  for (let item = landed - 1; item >= 0; item--) if (item % 3 === slot) return item;
  return null;
}

function Parcel({ item }: { item: number }) {
  const c = COLORS[((item % COLORS.length) + COLORS.length) % COLORS.length];
  return (
    <div
      style={{
        width: 38,
        height: 38,
        borderRadius: 10,
        background: `linear-gradient(${hex(c[0])}, ${hex(c[1])})`,
        boxShadow: `inset 0 0 0 1.5px rgb(255 255 255 / 0.35), 0 3px 5px ${hex(c[1], 0.35)}`,
        display: "flex",
        justifyContent: "center",
        overflow: "hidden",
      }}
    >
      <div style={{ width: 8, background: "rgb(255 255 255 / 0.5)" }} />
    </div>
  );
}

export default function CartBounce({ ctx }: DemoProps) {
  const { haptics, after, later } = useLater();
  const uid = useId().replace(/:/g, "");
  const start = useRef(DISTANT_PAST);
  /** Parcels dropped so far (the last one may still be falling). */
  const [count, setCount] = useState(2);
  const [badge, setBadge] = useState(2);
  const badgeRef = useRef(badge);
  badgeRef.current = badge;
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const height = ctx.n("height");
  const squash = ctx.n("squash");
  const pop = ctx.n("pop");
  const land = landing(height);

  const add = (scripted = false) => {
    // One parcel at a time: taps are ignored while it is in the air.
    if (since(nowSeconds(), start.current) <= land + 0.25) return;
    start.current = nowSeconds();
    setCount((c) => c + 1);
    haptics.tap("light");
    const next = badgeRef.current >= 99 ? 1 : badgeRef.current + 1;
    after(land + 0.04, () => setBadge(next));
    later(land, scripted, (h) => h.tap("medium"));
  };
  useAutoplay(ctx.isPreview, () => add(true), { every: 1.9 });

  const s = t - land;
  const press = squash * IC.ring(s, 11, 30) * (s >= 0 ? 1 : 0);
  const roll = 8 * IC.shake(s, 5, 13);
  const landed = t >= land ? count : count - 1;

  const item = count - 1;
  const slot = SLOTS[((item % 3) + 3) % 3];
  const arrive = IC.spring(t, 0.22, 0.6);
  const fall = IC.seg(t, 0.14, land);
  const drop = fall * fall;
  const kick = pop * 1.3 * IC.shake(s - 0.04, 9, 20);

  const wheel = (x: number) => (
    <Svg w={22} h={22} tf={`translate(${x}px, 68px) rotate(${(roll / 11) * 57.3}deg)`}>
      <circle r={11} style={{ fill: Palette.labelAlpha(0.85) }} />
      <circle r={4.5} style={{ fill: Palette.background }} />
      <rect x={-1.5} y={-9} width={3} height={8} rx={1.5} style={{ fill: Palette.background }} />
    </Svg>
  );

  return (
    <Stage gap={8}>
      <Z w={250} h={236} onClick={() => add()}>
        <Item
          w={150 * (1 + press * 0.8)}
          h={14}
          tf={`translate(${roll}px, ${GROUND + 2}px)`}
          style={{ borderRadius: "50%", background: "rgb(0 0 0 / 0.18)", filter: "blur(7px)" }}
        />
        <Z w={250} h={236} style={{ gridArea: "1 / 1", transform: `translateX(${roll}px) ${scaleAt(1 + press * 0.5, 1 - press, 0, 0.34 * 236)}` }}>
          <Svg w={250} h={236}>
            <path d="M-98 -42L-78 -42L-54 50L64 50" fill="none" strokeWidth={9} strokeLinecap="round" strokeLinejoin="round" style={{ stroke: Palette.labelAlpha(0.82) }} />
          </Svg>
          {[0, 1, 2].map((k) => {
            const resting = latest(k, landed);
            if (resting === null) return null;
            // Parcels already in the basket hop when the new one lands (the new one does not).
            const hop = resting === count - 1 ? 0 : 7 * IC.bump(IC.seg(s, 0.02 + 0.05 * k, 0.3 + 0.05 * k));
            return (
              <Item key={k} tf={`translate(${SLOTS[k][0]}px, ${SLOTS[k][1] - hop}px) rotate(${tilt(resting)}deg)`}>
                <Parcel item={resting} />
              </Item>
            );
          })}
          <Item
            tf={`translate(${slot[0]}px, ${slot[1] - height * (1 - drop)}px) rotate(${IC.mix(24, tilt(item), drop)}deg) scale(${Math.max(arrive, 0) * (1 + 0.1 * fall)})`}
            o={t < land ? 1 : 0}
          >
            <Parcel item={item} />
          </Item>
          <Svg w={250} h={236} style={{ filter: `drop-shadow(0 7px 12px ${hex(0x6e7bff, 0.4)})` }}>
            <defs>
              <linearGradient id={`${uid}-basket`} x1={-125} y1={-118} x2={125} y2={118} gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor={Palette.indigo} />
                <stop offset="1" stopColor={Palette.violet} />
              </linearGradient>
              <linearGradient id={`${uid}-sheen`} x1="0" y1={-118} x2="0" y2="0" gradientUnits="userSpaceOnUse">
                <stop offset="0" stopColor="#fff" stopOpacity={0.3} />
                <stop offset="1" stopColor="#fff" stopOpacity={0} />
              </linearGradient>
            </defs>
            <path d={BASKET} fill={`url(#${uid}-basket)`} />
            <path d={WIRES} fill="none" stroke="rgb(255 255 255 / 0.38)" strokeWidth={3} strokeLinecap="round" />
            <path d={BASKET} fill={`url(#${uid}-sheen)`} />
          </Svg>
          {wheel(-40)}
          {wheel(52)}
          <Item
            tf={`translate(92px, ${-40 - 10 * Math.max(kick, 0)}px) scale(${1 + kick})`}
            style={{
              minWidth: 34,
              height: 34,
              boxSizing: "border-box",
              padding: badge > 9 ? "0 5px" : 0,
              borderRadius: 17,
              display: "grid",
              placeItems: "center",
              background: `linear-gradient(${hex(0xff6b7a)}, ${hex(0xf0304a)})`,
              boxShadow: `inset 0 0 0 2.5px rgb(255 255 255 / 0.9), 0 4px 7px ${hex(0xff4d5e, 0.45)}`,
              color: "#fff",
              fontFamily: fonts.rounded,
              fontSize: 18,
              lineHeight: "22px",
              fontWeight: 700,
            }}
          >
            <NumericText value={badge} />
          </Item>
        </Z>
      </Z>
      <DemoHint ctx={ctx} en="Tap to add an item" zh="点击加入一件商品" />
    </Stage>
  );
}
