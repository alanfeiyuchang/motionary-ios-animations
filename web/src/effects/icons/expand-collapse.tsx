/** icons.expand-collapse · 展开收起 (Icons+ExpandCollapse.swift) */
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { IC, Item, RollText, Stage, Svg, Z, useIconNow, useLater, usePlayhead } from "./_time-kit";

const FULL_W = 250;
const FULL_H = 168;
const SMALL = 0.58;

export default function ExpandCollapse({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  /** On = expanded (the glyph shows collapse). */
  const play = usePlayhead(false);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const expanded = play.isOn;

  const response = ctx.n("response");
  const damping = ctx.n("damping");
  const travel = ctx.n("travel");
  const flat = ctx.i("style") === 1;

  const toggle = (scripted = false) => {
    play.toggle(response * 1.8, response * 1.8);
    haptics.tap("light");
    later(0.1 + response * 0.6, scripted, (h) => h.tap("soft"));
  };
  useAutoplay(ctx.isPreview, () => toggle(true), { every: 1.8 });

  const turn = IC.spring(t - 0.08, response, damping);
  // 0 = windowed, 1 = full screen; may overshoot either way.
  const p = expanded ? turn : 1 - turn;
  const u = IC.unit(p);
  const tuck = 4 * IC.bump(IC.seg(t, 0, 0.16));
  const flight = travel * IC.bump(IC.seg(t, 0.08, 0.08 + response * 1.15));
  const scale = IC.mix(SMALL, 1, p);
  const w = FULL_W * scale;
  const h = FULL_H * scale;
  const radius = IC.mix(20, 26, u);
  const offset = (21 + 3 * u - tuck + flight) * 0.7071;

  const arrow = (heading: number, x: number, y: number) => (
    <Svg w={30} h={26} tf={`translate(${x}px, ${y}px) rotate(${heading}deg) ${flat ? `rotate(${180 * p}deg)` : `perspective(60px) rotateY(${180 * p}deg)`}`}>
      <path d="M-15 0L15 0M2 -13L15 0L2 13" fill="none" stroke="#fff" strokeWidth={8} strokeLinecap="round" strokeLinejoin="round" />
    </Svg>
  );

  return (
    <Stage gap={10}>
      <Z w={262} h={196} onClick={() => toggle()}>
        <Svg w={FULL_W} h={FULL_H} o={1 - 0.8 * u}>
          <rect
            x={-FULL_W / 2 + 0.75}
            y={-FULL_H / 2 + 0.75}
            width={FULL_W - 1.5}
            height={FULL_H - 1.5}
            rx={25.25}
            fill="none"
            strokeWidth={1.5}
            strokeDasharray="5 5"
            style={{ stroke: Palette.labelAlpha(0.16) }}
          />
        </Svg>
        <Item w={w} h={h} style={{ borderRadius: radius, boxShadow: `0 ${6 + 6 * u}px ${10 + 10 * u}px ${hex(0x5a3fd0, 0.25 + 0.2 * u)}` }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: radius,
              overflow: "hidden",
              background: `linear-gradient(to bottom right, ${hex(0x6f78ff)}, ${hex(0x8a4fe8)}, ${hex(0xe0559a)})`,
            }}
          >
            {/* A soft sun and hills, so the window reads as a picture. */}
            <div
              style={{ position: "absolute", left: w / 2 + w * 0.26 - h * 0.17, top: h / 2 - h * 0.2 - h * 0.17, width: h * 0.34, height: h * 0.34, borderRadius: "50%", background: hex(0xffd98a, 0.85) }}
            />
            <div
              style={{ position: "absolute", left: w / 2 - w * 0.22 - w * 0.45, top: h / 2 + h * 0.5 - h * 0.3, width: w * 0.9, height: h * 0.6, borderRadius: "50%", background: hex(0x2b1e6b, 0.45) }}
            />
            <div
              style={{ position: "absolute", left: w / 2 + w * 0.3 - w * 0.45, top: h / 2 + h * 0.52 - h * 0.25, width: w * 0.9, height: h * 0.5, borderRadius: "50%", background: hex(0x1f154f, 0.5) }}
            />
            <div style={{ position: "absolute", left: 14, right: 14, bottom: 12, height: 4, borderRadius: 2, background: "rgb(255 255 255 / 0.35)" }}>
              <div style={{ width: w * 0.3, height: 4, borderRadius: 2, background: "#fff" }} />
            </div>
            <div style={{ position: "absolute", inset: 0, background: "rgb(0 0 0 / 0.12)" }} />
            <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.22)" }} />
          </div>
        </Item>
        <Z style={{ gridArea: "1 / 1", filter: "drop-shadow(0 2px 4px rgb(0 0 0 / 0.3))" }}>
          {/* Up-right arrow, then its mirror, down-left. */}
          {arrow(-45, offset, -offset)}
          {arrow(135, -offset, offset)}
        </Z>
      </Z>
      <RollText k={expanded ? "full" : "window"} style={{ ...textStyle.subheadline, fontWeight: 600, color: Palette.secondaryLabel }}>
        {expanded ? ctx.t("Full screen", "全屏") : ctx.t("Windowed", "窗口")}
      </RollText>
      <DemoHint ctx={ctx} en="Tap to expand or collapse" zh="点击展开或收起" />
    </Stage>
  );
}
