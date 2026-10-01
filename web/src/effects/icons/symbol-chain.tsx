/** icons.symbol-chain · 符号接龙 (Icons+SymbolChain.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, clamp, ease, hex, spring, springAt, textStyle, useAutoplay, useHaptics, useLatest, useTimeouts, type DemoProps } from "../../kit";
import { BOUNCE_DURATION, C, Glyph, S, SLASH, SYM, arc, bounceAt, rrect, track, useSince, type GlyphDef } from "./_icons-kit";

// MARK: - Symbols (24 × 24 grid; hierarchical: secondary layers at a lower opacity)

/** A clockwise circle, so overlapping lobes union under the non-zero fill rule. */
const disc = (cx: number, cy: number, r: number) => `M${cx - r} ${cy}a${r} ${r} 0 1 1 ${2 * r} 0a${r} ${r} 0 1 1 ${-2 * r} 0Z`;
/** `cloud.fill` centred on (cx, cy), `k` = scale (1 → 21 units wide). */
const cloud = (cx: number, cy: number, k = 1) =>
  disc(cx - 6.45 * k, cy + 2.8 * k, 4.05 * k) +
  disc(cx + 6.3 * k, cy + 2.65 * k, 4.17 * k) +
  rrect(cx - 6.45 * k, cy + 2.8 * k - 0.1, 12.75 * k, 4.13 * k, 0) +
  disc(cx - 0.76 * k, cy - 1 * k, 5.8 * k) +
  disc(cx + 4.8 * k, cy + 0.25 * k, 3.8 * k);
const spark = (x: number, y: number, r: number) => `M${x} ${y - r}Q${x} ${y} ${x + r} ${y}Q${x} ${y} ${x} ${y + r}Q${x} ${y} ${x - r} ${y}Q${x} ${y} ${x} ${y - r}Z`;
const speaker = (dx: number) => `M${1.2 + dx} 9.3a1 1 0 0 1 1-1h2.7l3.9-3.4a.9.9 0 0 1 1.5.7v12.8a.9.9 0 0 1-1.5.7l-3.9-3.4H${2.2 + dx}a1 1 0 0 1-1-1Z`;
const waves = (dx: number, n: number): GlyphDef =>
  [3.6, 7.1, 10.6].slice(0, n).map((r, i) => ({ d: arc(10.6 + dx, 12, r, -48 - 3 * i, 48 + 3 * i), mode: "stroke" as const, sw: 1.9, alpha: 0.55 }));
const RAYS = "M12 1.6v2.4M12 20v2.4M1.6 12H4M20 12h2.4M4.65 4.65l1.7 1.7M17.65 17.65l1.7 1.7M4.65 19.35l1.7-1.7M17.65 6.35l1.7-1.7";
const CHECK = "M7.4 12.4l3.1 3.1 6.1-6.6";

export const CHAIN_GLYPHS = {
  sunrise: [
    { d: "M7 17.2a5 5 0 0 1 10 0Z", mode: "solid" },
    { d: "M2.4 17.2h2M19.6 17.2h2M5.1 10.6l1.5 1.5M18.9 10.6l-1.5 1.5", mode: "stroke", sw: 1.8, alpha: 0.55 },
    { d: "M12 9.2V3.4M9.4 5.8 12 3.2l2.6 2.6M2.6 20.6h18.8", mode: "stroke", sw: 1.8, alpha: 0.55 },
  ],
  sunMax: [
    { d: disc(12, 12, 4.9), mode: "solid" },
    { d: RAYS, mode: "stroke", sw: 2 },
  ],
  cloudSun: [
    { d: disc(16.2, 8.2, 3.7) + "M16.2 1.6v1.5M22.8 8.2h-1.5M20.9 3.5l-1.1 1.1M11.5 3.5l1.1 1.1M20.9 12.9l-1.1-1.1", mode: "fill", sw: 1.6, alpha: 0.55, cut: { d: cloud(10.4, 14.6, 0.86), fill: true, sw: 2.6 } },
    { d: cloud(10.4, 14.6, 0.86), mode: "solid" },
  ],
  cloudRain: [
    { d: cloud(12, 8.6, 0.94), mode: "solid" },
    { d: "M8.4 17.2l-1.2 2.5M11.9 17.2l-2.6 5.3M14.6 17.2l-1.2 2.5M18.1 17.2l-2.6 5.3", mode: "stroke", sw: 1.7, alpha: 0.5 },
  ],
  cloudBoltRain: [
    { d: cloud(12, 8.6, 0.94), mode: "solid" },
    { d: "M12.9 16 9.9 20.2h2.5l-1.3 3.2 4-4.9h-2.6l1.4-2.5Z", sw: 0.6, alpha: 0.55 },
    { d: "M7.6 17.2l-2.4 4.9M18.4 17.2l-2.4 4.9", mode: "stroke", sw: 1.7, alpha: 0.5 },
  ],
  moonStars: [
    { d: "M19.6 14.2a8.6 8.6 0 1 1-9.8-10.6.6.6 0 0 1 .64.86 6.9 6.9 0 0 0 8.3 9.1.6.6 0 0 1 .76.74Z" },
    { d: spark(16.6, 5.6, 3.3) + spark(20.6, 10.6, 1.9), mode: "solid", alpha: 0.55 },
  ],
  speaker: [{ d: speaker(6.3) }],
  speaker1: [{ d: speaker(3.8) }, ...waves(3.8, 1)],
  speaker2: [{ d: speaker(2) }, ...waves(2, 2)],
  speaker3: [{ d: speaker(0) }, ...waves(0, 3)],
  speakerSlash: [
    { d: speaker(6.3), alpha: 0.55, cut: { d: SLASH, sw: 4.6 } },
    { d: SLASH, mode: "stroke", sw: 2.1 },
  ],
  envelope: [{ d: rrect(1.8, 4.8, 20.4, 14.4, 3), cut: { d: "M2.4 7.4 12 13.6l9.6-6.2", sw: 1.5 } }],
  envelopeOpen: [
    {
      d: "M21.2 8.4c.5.38.8.97.8 1.6v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V10a2 2 0 0 1 .8-1.6l8-6a2 2 0 0 1 2.4 0l8 6Z",
      cut: { d: "m22 10-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 10", sw: 1.5 },
    },
  ],
  reply: [{ d: "M10 4.2a.9.9 0 0 0-1.5-.66L1.9 9.7a.9.9 0 0 0 0 1.3l6.6 6.16A.9.9 0 0 0 10 16.5v-3.1c4.6 0 8 1.5 10.4 5.6.5.85 1.6.5 1.6-.5C22 11.8 17.6 7.6 10 7.3Z" }],
  checkCircle: [{ d: disc(12, 12, 10.4), mode: "solid", cut: { d: CHECK, sw: 2.4 } }],
} satisfies Record<string, GlyphDef>;

interface Link {
  key: string;
  def: GlyphDef;
  colors: [number, number];
  en: string;
  zh: string;
}
const CHAINS: Link[][] = [
  [
    { key: "sunrise", def: CHAIN_GLYPHS.sunrise, colors: [0xffb45c, 0xff6f61], en: "Sunrise", zh: "日出" },
    { key: "sun", def: CHAIN_GLYPHS.sunMax, colors: [0xffc83d, 0xff8a2a], en: "Sunny", zh: "晴" },
    { key: "cloudsun", def: CHAIN_GLYPHS.cloudSun, colors: [0x5ab8ff, 0x3c7bff], en: "Partly cloudy", zh: "多云" },
    { key: "rain", def: CHAIN_GLYPHS.cloudRain, colors: [0x5c8cc8, 0x3f5c96], en: "Rain", zh: "雨" },
    { key: "bolt", def: CHAIN_GLYPHS.cloudBoltRain, colors: [0x6a63c8, 0x3a3478], en: "Thunderstorm", zh: "雷暴" },
    { key: "moon", def: CHAIN_GLYPHS.moonStars, colors: [0x4b50b8, 0x1f2460], en: "Clear night", zh: "晴夜" },
  ],
  [
    { key: "spk0", def: CHAIN_GLYPHS.speaker, colors: [0x8e93a6, 0x62677a], en: "Silent", zh: "无声" },
    { key: "spk1", def: CHAIN_GLYPHS.speaker1, colors: [0x5ac8c0, 0x2e9ca8], en: "Low", zh: "低" },
    { key: "spk2", def: CHAIN_GLYPHS.speaker2, colors: [0x4fa3ff, 0x3a6bff], en: "Medium", zh: "中" },
    { key: "spk3", def: CHAIN_GLYPHS.speaker3, colors: [0x7c6bff, 0xa352f0], en: "Loud", zh: "高" },
    { key: "mute", def: CHAIN_GLYPHS.speakerSlash, colors: [0xff7a6b, 0xe8425a], en: "Muted", zh: "静音" },
  ],
  [
    { key: "mail", def: CHAIN_GLYPHS.envelope, colors: [0x4fa3ff, 0x3a6bff], en: "New mail", zh: "新邮件" },
    { key: "open", def: CHAIN_GLYPHS.envelopeOpen, colors: [0x5ac8c0, 0x2e9ca8], en: "Opened", zh: "已打开" },
    { key: "reply", def: CHAIN_GLYPHS.reply, colors: [0x7c6bff, 0xa352f0], en: "Replying", zh: "回复中" },
    { key: "sent", def: SYM.paperplaneFill, colors: [0xffb45c, 0xff6f61], en: "Sent", zh: "已发送" },
    { key: "done", def: CHAIN_GLYPHS.checkCircle, colors: [0x4cd98a, 0x1fa866], en: "Delivered", zh: "已送达" },
  ],
];

const GLYPH = 82;

/**
 * The tile's symbol: `.contentTransition(.symbolEffect(.replace.downUp))` (by layer or whole symbol)
 * between links, plus `.symbolEffect(.bounce.up.byLayer)` on the accent.
 */
function ChainSymbol({ link, byLayer, bounces }: { link: Link; byLayer: boolean; bounces: number }) {
  const [pair, setPair] = useState<{ cur: Link; prev: Link | null; n: number }>({ cur: link, prev: null, n: 0 });
  if (pair.cur.key !== link.key) setPair({ cur: link, prev: pair.cur, n: pair.n + 1 });
  const t = useSince(pair.n, 1.1);
  const bt = useSince(bounces, BOUNCE_DURATION + 0.4);
  const lag = byLayer ? 0.06 : 0;

  const outStyle = (i: number) => {
    const p = clamp((t - i * lag) / 0.2);
    const e = ease.in(p);
    return { transform: `scale(${1 - 0.65 * e})`, opacity: 1 - e, filter: p > 0 && p < 1 ? `blur(${3 * e}px)` : undefined };
  };
  const inStyle = (i: number) => {
    const local = t < 0 ? 10 : t - 0.08 - i * lag;
    const s = local <= 0 ? 0 : springAt(local, 0.38, 0.62);
    const o = clamp(local / 0.16);
    const b = bounceAt(bt < 0 ? -1 : bt - i * 0.07);
    return {
      transform: `translateY(${b.y * 30}px) scale(${(0.35 + 0.65 * s) * b.scale})`,
      opacity: o,
      filter: o < 1 ? `blur(${3 * (1 - o)}px)` : undefined,
    };
  };
  return (
    <div style={{ position: "relative", width: GLYPH, height: GLYPH, color: "#fff", filter: "drop-shadow(0 4px 6px rgb(0 0 0 / 0.18))" }}>
      {pair.prev && t >= 0 && t < 0.2 + pair.prev.def.length * lag && (
        <Glyph def={pair.prev.def} size={GLYPH} weight={1.1} style={{ position: "absolute", inset: 0 }} layerStyle={outStyle} />
      )}
      <Glyph def={pair.cur.def} size={GLYPH} weight={1.1} style={{ position: "absolute", inset: 0 }} layerStyle={inStyle} />
    </div>
  );
}

export default function SymbolChain({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [index, setIndex] = useState(0);
  const [bounces, setBounces] = useState(0);
  /** Bumped by a tap so the beat restarts from that tap. */
  const [nonce, setNonce] = useState(0);

  const chainId = Math.min(Math.max(ctx.i("chain"), 0), CHAINS.length - 1);
  const chain = CHAINS[chainId];
  const position = index % chain.length;
  const current = chain[position];
  const beat = ctx.n("beat");
  const accent = ctx.b("accent");

  const lastChain = useRef(chainId);
  useEffect(() => {
    if (lastChain.current !== chainId) {
      lastChain.current = chainId;
      setIndex(0);
    }
  }, [chainId]);

  const step = (target: number, byTouch: boolean) => {
    const count = chain.length;
    const next = ((target % count) + count) % count;
    if (next === position && byTouch) return;
    setIndex(next);
    if (byTouch) {
      haptics.selection();
      setNonce((n) => n + 1);
    }
    if (!accent) return;
    after(0.22, () => setBounces((b) => b + 1));
  };
  const advance = useLatest(() => step(position + 1, false));
  useAutoplay(ctx.isPreview, () => advance.current(), { every: beat, intro: false });
  // The stage keeps its own beat; previews are driven by autoplay.
  useEffect(() => {
    if (ctx.isPreview) return;
    const id = window.setInterval(() => advance.current(), Math.max(beat, 0.1) * 1000);
    return () => window.clearInterval(id);
  }, [ctx.isPreview, beat, nonce, advance]);

  const t = useSince(index, 0.7);
  const rippleScale = t < 0 ? 1 : track(t, 1, [C(1, 0.01), C(1.3, 0.55)]);
  const rippleOpacity = t < 0 ? 0 : track(t, 0, [C(0.7, 0.01), C(0, 0.55)]);
  const tileScale = t < 0 ? 1 : track(t, 1, [C(0.93, 0.1), S(1, 0.55, [0.3, 0.4])]);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div onClick={() => step(position + 1, true)} style={{ position: "relative", width: 136, height: 136, cursor: "pointer", flexShrink: 0 }}>
        <div
          style={{
            position: "absolute",
            inset: -1.5,
            borderRadius: 39.5,
            border: `3px solid ${hex(current.colors[0])}`,
            transform: `scale(${rippleScale})`,
            opacity: rippleOpacity,
          }}
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 38,
            transform: `scale(${tileScale})`,
            boxShadow: `0 9px 16px ${hex(current.colors[1], 0.4)}`,
            transition: "box-shadow 0.4s",
            display: "grid",
            placeItems: "center",
            overflow: "hidden",
          }}
        >
          {chain.map((link, offset) => (
            <div
              key={link.key}
              style={{
                position: "absolute",
                inset: 0,
                background: `linear-gradient(135deg, ${hex(link.colors[0])}, ${hex(link.colors[1])})`,
                opacity: offset === position ? 1 : 0,
                transition: "opacity 0.4s",
              }}
            />
          ))}
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 38,
              background: "linear-gradient(rgb(255 255 255 / 0.28), rgb(255 255 255 / 0) 50%)",
              boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.22)",
            }}
          />
          <ChainSymbol key={chainId} link={current} byLayer={ctx.b("byLayer")} bounces={bounces} />
        </div>
      </div>
      <div style={{ display: "grid", ...textStyle.headline, color: Palette.label }}>
        <AnimatePresence initial={false}>
          <motion.span
            key={current.key}
            initial={{ opacity: 0, y: 8, filter: "blur(2px)" }}
            animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
            exit={{ opacity: 0, y: -8, filter: "blur(2px)" }}
            transition={anim.snappyD(0.4)}
            style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap" }}
          >
            {ctx.t(current.en, current.zh)}
          </motion.span>
        </AnimatePresence>
      </div>
      <div style={{ display: "flex", alignItems: "center" }}>
        {chain.map((link, offset) => {
          const active = offset === position;
          const passed = offset < position;
          return (
            <div key={link.key} style={{ display: "flex", alignItems: "center" }}>
              {offset > 0 && (
                <div
                  style={{
                    width: 12,
                    height: 3,
                    borderRadius: 1.5,
                    background: offset <= position ? hex(chain[position].colors[0]) : Palette.labelAlpha(0.14),
                    transition: "background 0.3s",
                  }}
                />
              )}
              <motion.div
                initial={false}
                animate={{ scale: active ? 1.18 : 1 }}
                transition={spring(0.35, 0.6)}
                onClick={() => step(offset, true)}
                style={{
                  position: "relative",
                  width: 30,
                  height: 30,
                  borderRadius: "50%",
                  display: "grid",
                  placeItems: "center",
                  cursor: "pointer",
                  background: Palette.labelAlpha(0.07),
                  color: active ? "#fff" : Palette.labelAlpha(passed ? 0.6 : 0.3),
                }}
              >
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    borderRadius: "50%",
                    background: `linear-gradient(${hex(link.colors[0])}, ${hex(link.colors[1])})`,
                    opacity: active ? 1 : 0,
                    transition: "opacity 0.3s",
                  }}
                />
                <Glyph def={link.def.map((l) => ({ ...l, alpha: undefined }))} size={17} weight={1.15} style={{ position: "relative" }} />
              </motion.div>
            </div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap the tile or a node to jump" zh="点击方块或节点可跳转" />
    </div>
  );
}
