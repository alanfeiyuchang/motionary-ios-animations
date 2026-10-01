/** scroll.profile-header · 个人主页头部归位 (Scroll+ProfileHeader.swift) */
import { ChevronLeft, UserRound } from "lucide-react";
import { useRef } from "react";
import { Palette, alpha, anim, black, clamp, useAutoplay, white, type DemoProps, type Lang } from "../../kit";
import { ScrollKitRow, Sym, swiftBlur, useScroller } from "./_kit";
import { Ico, ScrollMath, useTopPull } from "./_motion";

/** Height of the expanded header (cover, avatar, name, stats). */
const EXPANDED = 262;
const BAR = 52;
const COVER = 120;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const { lerp, unit, smooth } = ScrollMath;

export default function ProfileHeader({ ctx }: DemoProps) {
  const range = Math.max(ctx.n("range"), 1);
  const down = useRef(false);
  const snap = ctx.b("snap");
  const sc = useScroller({
    axis: "y",
    bounce: false,
    onPhase: (p) => {
      if (p !== "idle") return;
      const offset = sc.get();
      if (!snap || offset <= 0.5 || offset >= range - 0.5) return;
      sc.scrollTo(offset < range / 2 ? 0 : range, anim.smoothD(0.35));
    },
  });
  const top = useTopPull({ enabled: () => !ctx.isPreview && sc.get() <= 0.5 });
  const offset = sc.offset;

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 300 : 0, anim.smoothD(1.5));
    },
    { every: 2.3 },
  );

  return (
    <div {...top.props} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ padding: "0 16px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
          <div style={{ height: EXPANDED + top.pull, flexShrink: 0 }} />
          {Array.from({ length: 14 }, (_, i) => (
            <ScrollKitRow key={i} index={i + 1} lang={ctx.lang} style={{ flexShrink: 0 }} />
          ))}
        </div>
      </div>
      <Header
        progress={clamp(offset / range, 0, 1)}
        scrolled={clamp(offset, 0, range)}
        pull={Math.max(-offset, 0) + top.pull}
        blur={ctx.n("blur")}
        // The detail stage keeps its Reset button in the top-trailing corner.
        dockInset={ctx.isPreview ? 14 : 56}
        lang={ctx.lang}
      />
    </div>
  );
}

function Header({ progress: p, scrolled, pull, blur, dockInset, lang }: { progress: number; scrolled: number; pull: number; blur: number; dockInset: number; lang: Lang }) {
  const zh = lang === "zh";
  // The lower block (handle, stats) leaves early; the button and name dock late.
  const early = unit(p, 0, 0.4);
  const late = smooth(unit(p, 0.35, 1));

  const coverH = lerp(COVER, BAR, p) + pull;
  const coverBlur = blur * Math.max(p, Math.min(pull / 90, 1) * 0.7);

  const size = lerp(68, 28, p);
  // Arc: the vertical travel leads, the horizontal one eases in late.
  const ax = lerp(16, 44, p * p);
  const ay = lerp(COVER - 34, 12, smooth(p)) + pull;
  const ring = lerp(3.5, 0, p);

  // The name steps aside early, before it rises into the avatar's row.
  const nx = lerp(16, 80, smooth(unit(p, 0.1, 0.55)));
  const ny = lerp(COVER + 42, 9, smooth(p)) + pull * (1 - p);
  const posts = unit(p, 0.8, 1);
  const name = zh ? "林见夏" : "Mira Okafor";
  const stat = (value: string, label: string) => (
    <div style={{ display: "flex", gap: 4, fontSize: 13, lineHeight: "18px", whiteSpace: "nowrap" }}>
      <span style={{ fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{value}</span>
      <span style={{ color: Palette.secondaryLabel }}>{label}</span>
    </div>
  );

  return (
    <div style={{ position: "absolute", left: 0, top: 0, right: 0, height: lerp(EXPANDED, BAR, p) + pull, pointerEvents: "none" }}>
      {/* Cover: blurred first, clipped after, so the edges stay solid. */}
      <div style={{ position: "absolute", left: 0, top: 0, right: 0, height: coverH, overflow: "hidden" }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${1.12 + pull / 300})`, filter: swiftBlur(coverBlur) }}>
          <CoverArt />
        </div>
        <div style={{ position: "absolute", inset: 0, background: black(0.3 * p) }} />
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 0.5, background: white(0.14 * p) }} />
      </div>
      {/* Handle, bio line and stats: they ride up with the content and fade out early. */}
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          padding: "0 16px",
          display: "flex",
          flexDirection: "column",
          gap: 10,
          opacity: 1 - early,
          transform: `translateY(${COVER + 74 - scrolled + pull}px)`,
        }}
      >
        <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
          {zh ? "@mira · 常驻里斯本的动效设计师" : "@mira · Motion designer in Lisbon"}
        </div>
        <div style={{ display: "flex", gap: 18 }}>
          {stat("128", zh ? "动态" : "Posts")}
          {stat("24.6K", zh ? "粉丝" : "Followers")}
          {stat("312", zh ? "关注" : "Following")}
        </div>
      </div>
      {/* Name */}
      <div style={{ position: "absolute", left: 0, top: 0, transform: `translate(${nx}px, ${ny}px)`, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
        <div style={{ position: "relative", fontSize: 22, lineHeight: "26px", fontWeight: 700, whiteSpace: "nowrap", transform: `scale(${lerp(1, 0.73, late)})`, transformOrigin: "0 0" }}>
          <span style={{ opacity: 1 - late }}>{name}</span>
          <span style={{ position: "absolute", left: 0, top: 0, color: "#fff", opacity: late }}>{name}</span>
        </div>
        <div
          style={{
            fontSize: 11,
            lineHeight: "13px",
            fontWeight: 500,
            color: white(0.8),
            whiteSpace: "nowrap",
            opacity: posts,
            transform: `translateY(${-8 + 6 * (1 - posts)}px)`,
          }}
        >
          {zh ? "128 条动态" : "128 posts"}
        </div>
      </div>
      {/* Avatar */}
      <div
        style={{
          position: "absolute",
          left: 0,
          top: 0,
          width: size,
          height: size,
          borderRadius: "50%",
          transform: `translate(${ax}px, ${ay}px)`,
          background: `linear-gradient(135deg, ${Palette.amber}, ${Palette.coral}, ${Palette.pink})`,
          boxShadow: `0 0 0 ${ring}px var(--ml-stage), 0 4px 12px ${ring}px ${black(0.18 * (1 - p))}`,
          display: "grid",
          placeItems: "center",
          color: "#fff",
        }}
      >
        <Ico icon={UserRound} size={size * 0.46} fill />
      </div>
      {/* Follow */}
      <div
        style={{
          position: "absolute",
          right: lerp(14, dockInset, late),
          top: lerp(COVER + 10, 9, late) + pull * (1 - late),
          height: 34,
          padding: "0 16px",
          borderRadius: 17,
          background: PRIMARY_STRONG,
          boxShadow: `inset 0 0 0 1px ${white(0.25 * late)}`,
          color: "#fff",
          fontSize: 15,
          fontWeight: 600,
          display: "flex",
          alignItems: "center",
          whiteSpace: "nowrap",
          transform: `scale(${lerp(1, 0.82, late)})`,
          transformOrigin: "100% 50%",
        }}
      >
        {zh ? "关注" : "Follow"}
      </div>
      {/* Back chevron */}
      <div style={{ position: "absolute", left: 10, top: 12, width: 28, height: 28, display: "grid", placeItems: "center", color: "#fff", filter: `drop-shadow(0 1px 3px ${black(0.25)})` }}>
        <Ico icon={ChevronLeft} size={16} weight={700} />
      </div>
    </div>
  );
}

/** The cover photo: a warm dusk gradient with soft light blobs (shapes only, no image assets). */
function CoverArt() {
  const blob = (w: number, x: number, y: number): React.CSSProperties => ({
    position: "absolute",
    left: "50%",
    top: "50%",
    width: w,
    height: w,
    marginLeft: -w / 2 + x,
    marginTop: -w / 2 + y,
    borderRadius: "50%",
  });
  return (
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(135deg, #3B2A8C, #B0489A, #FF8A5B)" }}>
      <div style={{ ...blob(120, 90, 30), background: alpha(Palette.amber, 0.75), filter: "blur(30px)" }} />
      <div style={{ ...blob(150, -110, -40), background: alpha(Palette.sky, 0.5), filter: "blur(36px)" }} />
      <div style={{ ...blob(90, 120, -30), boxShadow: `inset 0 0 0 10px ${white(0.2)}` }} />
      <div style={{ position: "absolute", left: "50%", top: "50%", transform: "translate(-50%, -50%) translate(40px, -18px)", color: white(0.55) }}>
        <Sym name="sparkles" size={34} weight={600} />
      </div>
    </div>
  );
}
