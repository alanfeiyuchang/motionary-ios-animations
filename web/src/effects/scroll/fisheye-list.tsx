/** scroll.fisheye-list · 鱼眼放大列表 (Scroll+FisheyeList.swift) */
import { Play } from "lucide-react";
import { useRef, useState } from "react";
import { Palette, black, clamp, fonts, spring, useAutoplay, type DemoProps } from "../../kit";
import { SnapMarkers, strideSnap, useScroller, useSelectionTick } from "./_kit";
import { Ico, ScrollMath } from "./_motion";

const TRACKS: [string, string][] = [
  ["First Light", "第一缕光"], ["Paper Boats", "纸船"], ["Low Tide", "退潮"], ["Glasshouse", "玻璃花房"],
  ["Slow Orbit", "慢轨道"], ["Night Ferry", "夜航渡轮"], ["Amber Road", "琥珀之路"], ["Kite Weather", "放风筝的天气"],
  ["Salt & Cedar", "盐与雪松"], ["Second Wind", "再次起风"], ["Blue Hour", "蓝调时刻"], ["Open Window", "开着的窗"],
  ["Long Shadows", "长影"], ["Tin Roof Rain", "铁皮屋顶的雨"], ["Field Notes", "田野笔记"], ["Harbor Lights", "港口灯火"],
  ["Soft Machine", "柔软机器"], ["Winter Sun", "冬日暖阳"], ["Half Awake", "半梦半醒"], ["Riverbend", "河湾"],
  ["Quiet Engine", "安静的引擎"], ["Lanterns", "灯笼"], ["Snowline", "雪线"], ["Afterglow", "余晖"],
  ["North Window", "北窗"], ["Driftwood", "浮木"], ["Small Hours", "凌晨"], ["Last Train", "末班车"],
];
const INITIAL = 7;
const ROW = 30;
const COUNT = TRACKS.length;

export default function FisheyeList({ ctx }: DemoProps) {
  const [current, setCurrent] = useState(INITIAL);
  const direction = useRef(1);
  const scripted = useRef(false);
  const snap = ctx.b("snap");
  const sc = useScroller({
    axis: "y",
    initial: INITIAL * ROW,
    snap: snap ? strideSnap(ROW) : undefined,
    onScroll: (o) => setCurrent(clamp(Math.round(o / ROW), 0, COUNT - 1)),
    onPhase: (p) => {
      if (p === "interacting") scripted.current = false;
    },
  });
  useSelectionTick(current, ctx.isPreview, scripted);

  const select = (i: number) => {
    scripted.current = false;
    sc.scrollTo(i * ROW, spring(0.5, 0.84));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const jump = 6;
      scripted.current = true;
      if (current + direction.current * jump >= COUNT || current + direction.current * jump < 0) direction.current = -direction.current;
      sc.scrollTo((current + direction.current * jump) * ROW, spring(0.9, 0.88));
    },
    { every: 1.5 },
  );

  const peak = ctx.n("scale");
  const sigma = ctx.n("radius");
  const viewport = sc.size.height || (ctx.isPreview ? 340 : 400);
  const pad = Math.max((viewport - ROW) / 2, 0);
  // Indigo → violet, tuned per appearance so the focused row stays readable on both stages.
  const tint = ctx.scheme === "dark" ? "linear-gradient(90deg, #97A1FF, #C9A4FF)" : "linear-gradient(90deg, #4B57E0, #7A45D6)";
  const tintText = { background: tint, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" } as const;
  const tintSolid = ctx.scheme === "dark" ? "#B0A2FF" : "#624EDB";
  const mask = `linear-gradient(transparent, ${black(1)} 14%, ${black(1)} 86%, transparent)`;
  const lensH = ROW * peak + 6;

  return (
    <div style={{ position: "absolute", inset: 0, WebkitMaskImage: mask, maskImage: mask }}>
      {/* The fixed lens band behind the centred row. */}
      <div
        style={{
          position: "absolute",
          left: 12,
          right: 12,
          top: (viewport - lensH) / 2,
          height: lensH,
          borderRadius: 16,
          background: Palette.labelAlpha(0.055),
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
        }}
      >
        <div style={{ position: "absolute", left: 7, top: (lensH - lensH * 0.46) / 2, width: 3, height: lensH * 0.46, borderRadius: 1.5, background: tint }} />
      </div>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ position: "relative", padding: `${pad}px 22px ${pad}px 26px` }}>
          {snap && <SnapMarkers count={COUNT} pitch={ROW} axis="y" />}
          {TRACKS.map((track, i) => {
            const d = i * ROW - sc.offset;
            const lens = ScrollMath.fisheye(d, sigma, peak);
            const label = (
              <>
                <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, fontVariantNumeric: "tabular-nums", opacity: 0.7 }}>{String(i + 1).padStart(2, "0")}</span>
                <span style={{ fontSize: 13, fontWeight: 600 }}>{ctx.lang === "zh" ? track[1] : track[0]}</span>
              </>
            );
            const labelStyle = { display: "flex", alignItems: "center", gap: 10, whiteSpace: "nowrap", lineHeight: "18px" } as const;
            const playWeight = ScrollMath.fisheye(d, sigma * 0.45, peak).weight;
            return (
              <div
                key={i}
                onClick={() => select(i)}
                style={{ height: ROW, display: "flex", alignItems: "center", transform: `translateY(${lens.position - d}px)`, cursor: "pointer" }}
              >
                <div style={{ position: "relative", transform: `scale(${lens.scale})`, transformOrigin: "0 50%" }}>
                  <div style={{ ...labelStyle, color: Palette.secondaryLabel }}>{label}</div>
                  {/* The tinted copy takes over inside the lens. */}
                  <div style={{ ...labelStyle, position: "absolute", left: 0, top: 0, opacity: ScrollMath.fisheye(d, sigma * 0.55, peak).weight }}>
                    <span style={{ ...labelStyle, ...tintText }}>{label}</span>
                  </div>
                </div>
                <div style={{ flex: 1 }} />
                <div style={{ marginRight: 8, opacity: playWeight, transform: `scale(${0.5 + 0.5 * playWeight})` }}>
                  <Ico icon={Play} size={12.5} weight={700} fill color={tintSolid} />
                </div>
                <div style={{ fontSize: 12, fontWeight: 500, fontVariantNumeric: "tabular-nums", color: Palette.tertiaryLabel }}>
                  {2 + ((i * 7) % 4)}:{String((i * 37 + 12) % 60).padStart(2, "0")}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
