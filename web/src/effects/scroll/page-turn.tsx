/** scroll.page-turn · 杂志翻页 (Scroll+PageTurn.swift) */
import { useRef, useState, type CSSProperties, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, black, clamp, fonts, hex, localPoint, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKit, Sym, perspectivePx } from "./_kit";
import { useDrag, useSpringValue } from "./_motion";

const LEAVES = 5;
const W = 148;
const H = 226;
const PAPER = "#FAF7F0";
const INK = 0x1f1c18;
const HEADLINES: [string, string][] = [
  ["Springs with a memory", "有记忆的弹簧"], ["The weight of a swipe", "一次滑动的分量"],
  ["Light that follows", "跟着走的光"], ["Slow in, never out", "只缓入，不缓出"],
  ["Paper, glass, ink", "纸、玻璃与墨"],
];
const radii = (isLeft: boolean) => (isLeft ? "9px 1.5px 1.5px 9px" : "1.5px 9px 9px 1.5px");

export default function PageTurn({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  /** Number of leaves turned to the left (fractional while one is in flight). */
  const turn = useSpringValue(1);
  const [spread, setSpreadState] = useState(1);
  const spreadRef = useRef(1);
  const dragStart = useRef<number | null>(null);
  const direction = useRef(1);

  /** Lands on a whole spread; the same path for drags, taps and autoplay. */
  const flip = (target: number, haptic: boolean) => {
    const clamped = clamp(target, 0, LEAVES);
    const changed = clamped !== spreadRef.current;
    spreadRef.current = clamped;
    setSpreadState(clamped);
    const response = ctx.n("response");
    turn.to(turn.get(), null);
    turn.to(clamped, spring(response, 0.9));
    if (!changed || !haptic || ctx.isPreview) return;
    // The page lands roughly when the spring has covered most of its travel.
    after(response * 0.75, () => haptics.tap("soft"));
  };

  const drag = useDrag(
    {
      onChange: (s) => {
        const start = dragStart.current ?? turn.get();
        dragStart.current = start;
        // The finger carries the page edge across both pages for one full turn.
        const raw = start - s.translation.x / (W * 1.7);
        turn.to(clamp(raw, Math.max(start - 1, 0), Math.min(start + 1, LEAVES)), null);
      },
      onEnd: (s) => {
        const start = dragStart.current ?? turn.get();
        dragStart.current = null;
        const projected = start - s.predicted.x / (W * 1.7);
        flip(Math.trunc(clamp(Math.round(projected), Math.round(start) - 1, Math.round(start) + 1)), true);
      },
    },
    { minimumDistance: 10, direction: "x", touchAction: "pan-y" },
  );

  useAutoplay(
    ctx.isPreview,
    () => {
      if (spreadRef.current + direction.current > LEAVES - 1 || spreadRef.current + direction.current < 1) direction.current = -direction.current;
      flip(spreadRef.current + direction.current, false);
    },
    { every: 1.8 },
  );

  const total = LEAVES * 2;
  const zh = ctx.lang === "zh";
  const label =
    spread === 0
      ? zh ? "封面内页" : "Inside cover"
      : spread === LEAVES
        ? zh ? `第 ${total} 页 · 共 ${total} 页` : `Page ${total} of ${total}`
        : zh ? `第 ${spread * 2}–${spread * 2 + 1} 页 · 共 ${total} 页` : `Pages ${spread * 2}–${spread * 2 + 1} of ${total}`;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}>
      <div
        {...drag}
        onClick={(e) => flip(spreadRef.current + (localPoint(e, e.currentTarget).x > W ? 1 : -1), true)}
        style={{ ...drag.style, position: "relative", width: W * 2, height: H, flexShrink: 0, cursor: "pointer" }}
      >
        <Book turn={turn.value} perspective={ctx.n("perspective")} shade={ctx.n("shade")} lang={ctx.lang} />
      </div>
      <div style={{ padding: "6px 12px", borderRadius: 999, background: Palette.labelAlpha(0.07), fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel, flexShrink: 0 }}>
        <NumericText value={spread} text={label} />
      </div>
      <DemoHint ctx={ctx} en="Drag a page across · tap to turn" zh="拖动书页翻过去 · 点击翻页" />
    </div>
  );
}

function Book({ turn, perspective, shade, lang }: { turn: number; perspective: number; shade: number; lang: Lang }) {
  const bounded = clamp(turn, 0, LEAVES);
  const flying = Math.floor(bounded);
  const t = bounded - flying;
  const inFlight = t > 0.0005 && flying < LEAVES;
  // Leaves lying flat: `flying − 1` shows its back on the left, the next unturned one its front on the right.
  const rightLeaf = inFlight ? flying + 1 : flying;
  const angle = t * 180;
  const lift = Math.sin((angle * Math.PI) / 180);
  const projected = W * Math.abs(Math.cos((angle * Math.PI) / 180));
  const onRight = t < 0.5;
  const castOpacity = (0.12 + shade * 0.7) * lift;
  const castW = Math.min(projected + 26, W);
  const showsBack = angle > 90;
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <Edges left={bounded} right={LEAVES - bounded} />
      <div style={{ position: "absolute", left: 0, top: 0 }}>
        <Paper page={flying === 0 ? 0 : (flying - 1) * 2 + 2} isLeft lang={lang} />
      </div>
      <div style={{ position: "absolute", left: W, top: 0 }}>
        <Paper page={rightLeaf >= LEAVES ? LEAVES * 2 + 1 : rightLeaf * 2 + 1} isLeft={false} lang={lang} />
      </div>
      {inFlight && (
        <>
          {/* The shadow the lifted leaf throws on the page under it: as wide as the leaf's projection. */}
          <div
            style={{
              position: "absolute",
              top: 0,
              left: onRight ? W : W - castW,
              width: castW,
              height: H,
              background: `linear-gradient(${onRight ? 90 : 270}deg, ${black(castOpacity)}, ${black(castOpacity * 0.5)}, transparent)`,
              pointerEvents: "none",
            }}
          />
          <div style={{ position: "absolute", left: W, top: 0, width: W, height: H, filter: `drop-shadow(0 6px 10px ${black(0.16 * lift)})`, pointerEvents: "none" }}>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: radii(false),
                overflow: "hidden",
                transformOrigin: "0 50%",
                transform: `perspective(${perspectivePx(W, H, perspective)}px) rotateY(${-angle}deg)`,
              }}
            >
              {showsBack ? (
                <div style={{ position: "absolute", inset: 0, transform: "scaleX(-1)" }}>
                  <Paper page={flying * 2 + 2} isLeft lang={lang} />
                  {/* The back catches less light until it lies flat again. */}
                  <div style={{ position: "absolute", inset: 0, background: `linear-gradient(90deg, ${black(shade * lift)}, ${black(shade * lift * 0.25)})` }} />
                </div>
              ) : (
                <div style={{ position: "absolute", inset: 0 }}>
                  <Paper page={flying * 2 + 1} isLeft={false} lang={lang} />
                  <div style={{ position: "absolute", inset: 0, background: `linear-gradient(90deg, ${black(shade * lift * 0.2)}, ${black(shade * lift)})` }} />
                </div>
              )}
              {/* A sheen that crosses the page while it stands up. */}
              <div
                style={{
                  position: "absolute",
                  top: 0,
                  bottom: 0,
                  left: W / 2 - 23 + W * (0.5 - angle / 180),
                  width: 46,
                  background: `linear-gradient(90deg, transparent, ${white(0.5 * lift)}, transparent)`,
                  mixBlendMode: "plus-lighter",
                }}
              />
            </div>
          </div>
        </>
      )}
    </div>
  );
}

/** The stacked page edges peeking out under each side: thicker where more pages lie. */
function Edges({ left, right }: { left: number; right: number }) {
  const sheet = (isLeft: boolean, shift: number): CSSProperties => ({
    position: "absolute",
    left: isLeft ? 0 : W,
    top: 0,
    width: W,
    height: H,
    borderRadius: radii(isLeft),
    background: "#E4DFD3",
    boxShadow: `inset 0 0 0 0.5px ${black(0.1)}`,
    transform: `translate(${isLeft ? -shift : shift}px, ${shift * 0.7}px)`,
  });
  return (
    <div style={{ position: "absolute", inset: 0, filter: `drop-shadow(0 12px 16px ${black(0.22)})` }}>
      {[0, 1, 2].map((k) => {
        const step = 3 - k;
        return (
          <div key={k}>
            <div style={sheet(true, Math.min(left, step) * 1.6)} />
            <div style={sheet(false, Math.min(right, step) * 1.6)} />
          </div>
        );
      })}
    </div>
  );
}

/** One printed page. Page 0 is the inside front cover and the last one the inside back cover. */
function Paper({ page, isLeft, lang }: { page: number; isLeft: boolean; lang: Lang }) {
  const zh = lang === "zh";
  const ink = hex(INK);
  const headline = HEADLINES[page % HEADLINES.length][zh ? 1 : 0];
  const art = (height: number) => (
    <div style={{ height, flexShrink: 0, borderRadius: 5, background: ScrollKit.gradient(page + 1), display: "grid", placeItems: "center", color: white(0.92) }}>
      <Sym name={ScrollKit.symbol(page + 1)} size={height * 0.42} weight={600} />
    </div>
  );
  const lines = (count: number) => (
    <div style={{ display: "flex", flexDirection: "column", gap: 5, flexShrink: 0 }}>
      {Array.from({ length: count }, (_, i) => (
        <div key={i} style={{ height: 3.5, borderRadius: 2, background: hex(INK, 0.16), maxWidth: i === count - 1 ? 60 : undefined }} />
      ))}
    </div>
  );
  const head = (size: number): CSSProperties => ({ fontFamily: fonts.serif, fontSize: size, lineHeight: 1.2, fontWeight: 700, color: ink });
  const cover = (title: string, line: string) => (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8, color: ink, fontFamily: fonts.serif }}>
      <div style={{ fontSize: 30, lineHeight: "36px", fontWeight: 900, letterSpacing: 2, marginRight: -2 }}>{title}</div>
      <div style={{ width: 36, height: 2, background: ink }} />
      <div style={{ fontSize: 10, lineHeight: "12px", fontWeight: 500, opacity: 0.65, whiteSpace: "nowrap" }}>{line}</div>
    </div>
  );
  let content: ReactNode;
  if (page === 0) content = cover(zh ? "动效" : "MOTION", zh ? "季刊 · 第 12 期" : "Quarterly · Issue 12");
  else if (page > LEAVES * 2) content = cover(zh ? "完" : "FIN", zh ? "下一期春季见" : "Next issue in spring");
  else if (page % 3 === 0)
    content = (
      <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
        {art(84)}
        <div style={head(15)}>{headline}</div>
        {lines(6)}
      </div>
    );
  else if (page % 3 === 1)
    content = (
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <div style={head(15)}>{headline}</div>
        {lines(3)}
        {art(62)}
        {lines(4)}
      </div>
    );
  else
    content = (
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        <div style={{ fontFamily: fonts.serif, fontSize: 44, lineHeight: "52px", height: 30, fontWeight: 900, color: ScrollKit.colors(page + 1)[0] }}>“</div>
        <div style={head(19)}>{headline}</div>
        <div style={{ width: 26, height: 1.5, background: hex(INK, 0.8) }} />
        {lines(7)}
      </div>
    );
  return (
    <div style={{ position: "relative", width: W, height: H, borderRadius: radii(isLeft), overflow: "hidden", background: PAPER }}>
      <div style={{ position: "absolute", inset: 0, padding: "14px 13px 22px" }}>{content}</div>
      {/* Gutter shadow along the spine. */}
      <div
        style={{
          position: "absolute",
          top: 0,
          bottom: 0,
          width: 30,
          ...(isLeft ? { right: 0 } : { left: 0 }),
          background: `linear-gradient(${isLeft ? 270 : 90}deg, ${black(0.2)}, ${black(0.05)}, transparent)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          bottom: 10,
          ...(isLeft ? { left: 10 } : { right: 10 }),
          fontFamily: fonts.serif,
          fontSize: 9,
          lineHeight: "11px",
          fontWeight: 600,
          fontVariantNumeric: "tabular-nums",
          color: hex(INK, 0.5),
        }}
      >
        {page === 0 || page > LEAVES * 2 ? "" : page}
      </div>
    </div>
  );
}
