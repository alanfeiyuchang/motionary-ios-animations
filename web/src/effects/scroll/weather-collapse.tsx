/** scroll.weather-collapse · 天气头部折叠 (Scroll+WeatherCollapse.swift) */
import { Calendar, Clock, Cloud, CloudLightning, CloudRain, Droplets, MoonStar, Sun, Wind, type LucideIcon } from "lucide-react";
import { useRef, type ReactNode } from "react";
import { Palette, anim, black, clamp, hex, useAutoplay, white, type DemoProps, type Lang } from "../../kit";
import { useScroller } from "./_kit";
import { Ico, ScrollMath, useTopPull } from "./_motion";

const EXPANDED = 196;
const BAR = 68;
const { lerp, unit, smooth } = ScrollMath;

export default function WeatherCollapse({ ctx }: DemoProps) {
  const range = Math.max(ctx.n("range"), 1);
  const snap = ctx.b("snap");
  const sky = ctx.i("sky");
  const down = useRef(false);
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
  const progress = clamp(offset / range, 0, 1);
  const pull = Math.max(-offset, 0) + top.pull;
  const headerHeight = lerp(EXPANDED, BAR, progress) + pull;

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 250 : 0, anim.smoothD(1.6));
    },
    { every: 2.4 },
  );

  // Cards never show through the header: they fade out 14 pt under its current bottom edge.
  const from = Math.max(headerHeight - 4, 0);
  const mask = `linear-gradient(transparent ${from}px, #000 ${from + 14}px)`;

  return (
    <div {...top.props} style={{ position: "absolute", inset: 0, overflow: "hidden", color: "#fff" }}>
      <Sky sky={sky} drift={Math.min(offset, range) * 0.5 - pull * 0.3} dim={progress} />
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0, WebkitMaskImage: mask, maskImage: mask }}>
        <div ref={sc.contentRef} style={{ padding: "0 14px 16px", display: "flex", flexDirection: "column", gap: 10 }}>
          {/* At the default distance the header gives back exactly the space the scroll consumes. */}
          <div style={{ height: EXPANDED + top.pull, flexShrink: 0 }} />
          <Hourly lang={ctx.lang} />
          <Daily lang={ctx.lang} />
          <div style={{ display: "flex", gap: 10 }}>
            <Card icon={Wind} title={ctx.t("Wind", "风")}>
              <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{ctx.t("14 km/h", "14 公里/时")}</div>
            </Card>
            <Card icon={Droplets} title={ctx.t("Humidity", "湿度")} fill>
              <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>62%</div>
            </Card>
          </div>
        </div>
      </div>
      <Header progress={progress} pull={pull} height={headerHeight} lang={ctx.lang} />
    </div>
  );
}

// MARK: - Header

function Header({ progress: p, pull, height, lang }: { progress: number; pull: number; height: number; lang: Lang }) {
  const zh = lang === "zh";
  const stretch = Math.min(pull / 160, 1);
  // Sequenced exits and the late arrival of the compact line.
  const highLow = 1 - unit(p, 0, 0.3);
  const condition = 1 - unit(p, 0.15, 0.5);
  const compact = smooth(unit(p, 0.65, 1));
  const travel = smooth(p);
  /** How far left the shrunken number sits, so that "21° | Mostly Clear" reads as one centred line. */
  const compactShift = zh ? -44 : -58;
  const row = (y: number, x = 0): React.CSSProperties => ({
    position: "absolute",
    left: 0,
    right: 0,
    top: 0,
    display: "flex",
    justifyContent: "center",
    transform: `translate(${x}px, ${y}px)`,
    whiteSpace: "nowrap",
  });
  const city = lerp(24, 20, p);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, height, pointerEvents: "none", filter: `drop-shadow(0 2px 6px ${black(0.18)})` }}>
      <div style={{ ...row(lerp(18, 12, p) + pull * 0.35), fontSize: city, lineHeight: `${city * 1.2}px`, fontWeight: 600 }}>{zh ? "里斯本" : "Lisbon"}</div>
      {/* One number: it shrinks about its top and slides left into the compact line. */}
      <div style={row(lerp(44, 39, travel) + pull * 0.55, lerp(8, compactShift, travel))}>
        <div
          style={{
            position: "relative",
            fontSize: 76,
            lineHeight: "91px",
            fontVariantNumeric: "tabular-nums",
            transform: `scale(${lerp(1 + 0.12 * stretch, 0.26, travel)})`,
            transformOrigin: "50% 0",
          }}
        >
          {/* Thin at display size; it gains weight as it shrinks so it stays legible in the bar. */}
          <span style={{ fontWeight: 200, opacity: 1 - compact }}>21°</span>
          <span style={{ position: "absolute", left: 0, top: 0, fontWeight: 400, opacity: compact }}>21°</span>
        </div>
      </div>
      <div style={{ ...row(136 - 30 * (1 - condition) + pull * 0.7), fontSize: 17, lineHeight: "20px", fontWeight: 500, opacity: condition * 0.9 }}>
        {zh ? "晴间多云" : "Mostly Clear"}
      </div>
      <div style={{ ...row(160 - 26 * (1 - highLow) + pull * 0.8), fontSize: 17, lineHeight: "20px", fontWeight: 500, fontVariantNumeric: "tabular-nums", opacity: highLow, whiteSpace: "pre" }}>
        {zh ? "最高 24°  最低 15°" : "H:24°  L:15°"}
      </div>
      <div style={{ ...row(41, 12 + 8 * (1 - compact)), opacity: compact }}>
        <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
          <div style={{ width: 1, height: 13, background: white(0.5) }} />
          <div style={{ fontSize: 15, lineHeight: "18px", fontWeight: 500, opacity: 0.9 }}>{zh ? "晴间多云" : "Mostly Clear"}</div>
        </div>
      </div>
    </div>
  );
}

// MARK: - Sky

const SKIES = [
  { colors: ["#2F7FD8", "#5FA9EE", "#9CCBF5"], glow: 0xfff3c4 },
  { colors: ["#3B2F7A", "#C2557E", "#F7A45C"], glow: 0xffd08a },
  { colors: ["#070B24", "#1A2460", "#3A3F8F"], glow: 0xdce4ff },
];

function Sky({ sky, drift, dim }: { sky: number; drift: number; dim: number }) {
  const s = SKIES[clamp(sky, 0, 2)];
  const night = sky === 2;
  const disc = night ? 30 : 46;
  return (
    <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${s.colors.join(", ")})`, overflow: "hidden" }}>
      <div style={{ position: "absolute", right: 0, top: 0, width: 190, height: 190, transform: `translate(40px, ${10 - drift}px)`, opacity: 1 - 0.55 * dim }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: hex(s.glow, 0.55), filter: "blur(40px)" }} />
        <div
          style={{
            position: "absolute",
            left: 95 - disc / 2,
            top: 95 - disc / 2,
            width: disc,
            height: disc,
            borderRadius: "50%",
            background: hex(s.glow, night ? 0.95 : 0.9),
            filter: `blur(${night ? 0.4 : 4}px)`,
          }}
        />
      </div>
      {night && (
        <div style={{ position: "absolute", inset: 0, opacity: 1 - 0.4 * dim, transform: `translateY(${-drift * 0.4}px)` }}>
          {Array.from({ length: 34 }, (_, i) => {
            const r = (i % 3) * 0.35 + 0.6;
            return (
              <div
                key={i}
                style={{
                  position: "absolute",
                  left: `${(((i * 73 + 19) % 101) / 101) * 100}%`,
                  top: `${(((i * 47 + 7) % 89) / 89) * 75}%`,
                  width: r * 2,
                  height: r * 2,
                  borderRadius: "50%",
                  background: white(0.35 + (i % 4) * 0.15),
                }}
              />
            );
          })}
        </div>
      )}
      {/* The collapsed bar reads better on a slightly deeper sky. */}
      <div style={{ position: "absolute", inset: 0, background: black(0.14 * dim) }} />
    </div>
  );
}

// MARK: - Cards

function Card({ icon, title, fill, children }: { icon: LucideIcon; title: string; fill?: boolean; children: ReactNode }) {
  return (
    <div
      style={{
        flex: 1,
        flexShrink: 0,
        padding: 12,
        display: "flex",
        flexDirection: "column",
        gap: 10,
        borderRadius: 18,
        background: white(0.14),
        boxShadow: `inset 0 0 0 0.5px ${white(0.16)}`,
      }}
    >
      <div style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, lineHeight: "16px", fontWeight: 600, textTransform: "uppercase", color: white(0.62) }}>
        <Ico icon={icon} size={11} weight={600} fill={fill} />
        {title}
      </div>
      {children}
    </div>
  );
}

const YELLOW = "#FFD60A";
/** `symbolRenderingMode(.multicolor)` weather glyphs. */
function Glyph({ name, size }: { name: string; size: number }) {
  const px = size * 1.2;
  switch (name) {
    case "sun.max.fill":
      return <Sun size={px} color={YELLOW} fill={YELLOW} strokeWidth={2} />;
    case "cloud.sun.fill":
      return (
        <div style={{ position: "relative", width: px, height: px }}>
          <Sun size={px * 0.62} color={YELLOW} fill={YELLOW} strokeWidth={2} style={{ position: "absolute", right: 0, top: 0 }} />
          <Cloud size={px * 0.9} color="#fff" fill="#fff" strokeWidth={2} style={{ position: "absolute", left: 0, bottom: -px * 0.08 }} />
        </div>
      );
    case "cloud.rain.fill":
      return <CloudRain size={px} color="#fff" fill="#fff" strokeWidth={2} />;
    case "cloud.bolt.rain.fill":
      return <CloudLightning size={px} color="#fff" fill="#fff" strokeWidth={2} />;
    case "moon.stars.fill":
      return <MoonStar size={px} color="#fff" fill="#fff" strokeWidth={2} />;
    default:
      return <Cloud size={px} color="#fff" fill="#fff" strokeWidth={2} />;
  }
}

function Hourly({ lang }: { lang: Lang }) {
  const icons = ["sun.max.fill", "sun.max.fill", "cloud.sun.fill", "cloud.sun.fill", "cloud.fill", "moon.stars.fill"];
  const temps = [21, 22, 24, 23, 20, 17];
  return (
    <Card icon={Clock} title={lang === "zh" ? "每小时预报" : "Hourly forecast"}>
      <div style={{ display: "flex" }}>
        {temps.map((t, i) => (
          <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 7 }}>
            <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
              {i === 0 ? (lang === "zh" ? "现在" : "Now") : String((13 + i * 2) % 24).padStart(2, "0")}
            </div>
            <div style={{ height: 20, display: "grid", placeItems: "center" }}>
              <Glyph name={icons[i]} size={17} />
            </div>
            <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{t}°</div>
          </div>
        ))}
      </div>
    </Card>
  );
}

const DAYS: [string, string, string, number, number][] = [
  ["Today", "今天", "sun.max.fill", 15, 24], ["Thu", "周四", "cloud.sun.fill", 14, 22],
  ["Fri", "周五", "cloud.rain.fill", 12, 18], ["Sat", "周六", "cloud.bolt.rain.fill", 11, 17],
  ["Sun", "周日", "cloud.sun.fill", 13, 21], ["Mon", "周一", "sun.max.fill", 16, 26],
  ["Tue", "周二", "sun.max.fill", 17, 27],
];

function Daily({ lang }: { lang: Lang }) {
  return (
    <Card icon={Calendar} title={lang === "zh" ? "7 日预报" : "7-day forecast"}>
      <div>
        {DAYS.map(([en, zh, icon, low, high], i) => {
          const a = (low - 10) / 18;
          const b = (high - 10) / 18;
          return (
            <div key={i} style={{ height: 34, display: "flex", alignItems: "center", gap: 8, fontSize: 15, lineHeight: "20px", boxShadow: i > 0 ? `inset 0 0.5px 0 ${white(0.14)}` : undefined }}>
              <div style={{ width: 46, fontWeight: 600, whiteSpace: "nowrap" }}>{lang === "zh" ? zh : en}</div>
              <div style={{ width: 26, display: "grid", placeItems: "center" }}>
                <Glyph name={icon} size={15} />
              </div>
              <div style={{ width: 30, textAlign: "right", fontWeight: 500, fontVariantNumeric: "tabular-nums", color: white(0.6) }}>{low}°</div>
              {/* The week's temperature span as a track, with this day's low…high as a gradient segment. */}
              <div style={{ flex: 1, height: 4, borderRadius: 2, background: black(0.18), position: "relative" }}>
                <div
                  style={{
                    position: "absolute",
                    inset: 0,
                    borderRadius: 2,
                    background: `linear-gradient(90deg, ${Palette.mint}, ${Palette.amber}, ${Palette.coral})`,
                    clipPath: `inset(0 ${(1 - b) * 100}% 0 ${a * 100}% round 2px)`,
                  }}
                />
              </div>
              <div style={{ width: 30, textAlign: "right", fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>{high}°</div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}
