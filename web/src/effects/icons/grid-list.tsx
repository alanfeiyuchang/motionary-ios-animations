/** icons.grid-list · 宫格列表切换 (Icons+GridList.swift) */
import { useState } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { C, Glyph, S, SYM, circ, rrect, sym, track, useSince, type GlyphDef } from "./_icons-kit";
import { IC, RollText, Stage, useIconNow, usePlayhead } from "./_time-kit";

const SIDE = 196;
const SYMBOLS: GlyphDef[] = [
  [{ d: rrect(2, 4.5, 20, 15, 3.4), cut: { d: circ(8, 9.6, 1.1) + "M3.4 18l5-5.2 3.4 3.4 3.4-4.4 5.6 6.6", sw: 1.7 } }],
  SYM.musicNote,
  [
    {
      d: "M6 2h7.6L20 8.4V20a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2Z",
      cut: { d: "M13.6 1.6v5.3a1.5 1.5 0 0 0 1.5 1.5h5.3M8 12.6h8M8 16.6h8M8 8.6h2.6", sw: 1.6 },
    },
  ],
  [{ d: "M2.4 6.4 8.6 3.6l6.8 2.6 6.2-2.6v14L15.4 20.4l-6.8-2.6-6.2 2.6Z", cut: { d: "M8.6 3.6v14.2M15.4 6.2v14.2", sw: 1.4 } }],
];
const COLORS: [number, number][] = [
  [0x7c83ff, 0x5a54e0],
  [0xff8cbe, 0xf04e93],
  [0xffc45c, 0xff8a2a],
  [0x5be3c0, 0x14b893],
];

/** The rect of cell `index` inside a square of `side`, for `p` between 0 (2 × 2 grid) and 1 (four rows). */
function cellRect(index: number, p: number, side: number, gap: number, rowGap: number) {
  const cell = (side - gap) / 2;
  const gx = (index % 2) * (cell + gap);
  const gy = Math.floor(index / 2) * (cell + gap);
  const row = (side - rowGap * 3) / 4;
  const ly = index * (row + rowGap);
  return {
    x: gx + (0 - gx) * p,
    y: gy + (ly - gy) * p,
    w: Math.max(cell + (side - cell) * p, 1),
    h: Math.max(cell + (row - cell) * p, 1),
  };
}

export default function GridList({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** On = list. */
  const play = usePlayhead(false);
  const [presses, setPresses] = useState(0);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const isList = play.isOn;

  const response = ctx.n("response");
  const damping = ctx.n("damping");
  const stagger = ctx.n("stagger");
  const duration = 3 * stagger + response * 1.6;

  const toggle = () => {
    play.toggle(duration, duration);
    setPresses((p) => p + 1);
    haptics.tap("light");
  };
  useAutoplay(ctx.isPreview, toggle, { every: 1.9 });

  const progress = [0, 1, 2, 3].map((index) =>
    isList ? IC.spring(t - index * stagger, response, damping) : 1 - IC.spring(t - (3 - index) * stagger, response, damping),
  );
  const pt = useSince(presses, 0.6);
  const pressScale = pt < 0 ? 1 : track(pt, 1, [C(0.9, 0.09), S(1, 0.45, [0.28, 0.5])]);

  return (
    <Stage gap={12} onClick={toggle}>
      <div style={{ width: SIDE, display: "flex", alignItems: "center", justifyContent: "space-between", flexShrink: 0 }}>
        <RollText k={isList ? "list" : "grid"} style={{ ...textStyle.headline, color: Palette.label }}>
          {isList ? ctx.t("List", "列表") : ctx.t("Grid", "宫格")}
        </RollText>
        <div
          style={{
            width: 58,
            height: 58,
            borderRadius: 18,
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 5px 10px rgb(0 0 0 / 0.12)`,
            display: "grid",
            placeItems: "center",
            transform: `scale(${pressScale})`,
          }}
        >
          <div style={{ position: "relative", width: 28, height: 28 }}>
            {progress.map((p, index) => {
              const r = cellRect(index, p, 28, 6, 3.5);
              return (
                <div key={index} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, borderRadius: Math.min(r.w, r.h) * 0.3, background: Palette.primary }} />
              );
            })}
          </div>
        </div>
      </div>
      <div style={{ position: "relative", width: SIDE, height: SIDE, flexShrink: 0 }}>
        {progress.map((p, index) => {
          const shown = IC.unit(p);
          const r = cellRect(index, p, SIDE, 12, 10);
          const radius = IC.mix(24, 14, shown);
          // The icon slides from the middle of the tile to its leading edge.
          const iconX = IC.mix(r.w / 2, 24, shown);
          const glyph = sym(30);
          return (
            <div
              key={index}
              style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, borderRadius: radius, boxShadow: `0 5px 8px ${hex(COLORS[index][1], 0.3)}` }}
            >
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  borderRadius: radius,
                  overflow: "hidden",
                  background: `linear-gradient(rgb(255 255 255 / 0.22), rgb(255 255 255 / 0) 50%), linear-gradient(to bottom right, ${hex(COLORS[index][0])}, ${hex(COLORS[index][1])})`,
                }}
              >
                <div
                  style={{
                    position: "absolute",
                    left: 50 + 18 * (1 - shown),
                    top: r.h / 2 - 9.5,
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "flex-start",
                    gap: 6,
                    opacity: IC.unit((p - 0.45) * 2.2),
                  }}
                >
                  <div style={{ width: 78, height: 7, borderRadius: 3.5, background: "rgb(255 255 255 / 0.95)" }} />
                  <div style={{ width: 48, height: 6, borderRadius: 3, background: "rgb(255 255 255 / 0.55)" }} />
                </div>
                <div style={{ position: "absolute", left: iconX - glyph / 2, top: r.h / 2 - glyph / 2, color: "#fff", transform: `scale(${IC.mix(1, 0.7, shown)})` }}>
                  <Glyph def={SYMBOLS[index]} size={glyph} weight={1.1} />
                </div>
              </div>
            </div>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap to switch the layout" zh="点击切换布局" />
    </Stage>
  );
}
