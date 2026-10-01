/** morph.thumb-to-player · 缩略图展开播放器 (Morph+ThumbToPlayer.swift) */
import { animate, useMotionValue } from "motion/react";
import { AudioLines, ChevronDown, Play, X } from "lucide-react";
import { useLayoutEffect, useRef } from "react";
import { DemoHint, Palette, black, hex, localPoint, rubberBand, spring, useAutoplay, useClock, useHaptics, usePan, white, type DemoProps } from "../../kit";
import { Column, diag, lerpRect, mixN, morphScreen, predicted, smooth, unit, useMV, type Rect } from "./_shared";

const W = 316;
const H = 306;
const THUMB: Rect = { x: 12, y: 52, w: 292, h: 164 };
const PLAYER: Rect = { x: 0, y: 0, w: 316, h: 178 };
const TRAVEL = 170;
const pipRect = (width: number): Rect => ({ x: W - 10 - width, y: H - 10 - (width * 9) / 16, w: width, h: (width * 9) / 16 });

export default function ThumbToPlayer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const openMV = useMotionValue(0);
  const dockMV = useMotionValue(0);
  const open = useMV(openMV);
  const dock = useMV(dockMV);
  const dragBase = useRef<number | null>(null);
  const dragged = useRef(false);
  const autoStep = useRef(0);
  const zh = ctx.lang === "zh";
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  // The model values (where the springs are heading), like reading the @State.
  const target = useRef({ open: 0, dock: 0 });
  const go = (o: number | null, d: number | null) => {
    if (o !== null) {
      target.current.open = o;
      animate(openMV, o, spr);
    }
    if (d !== null) {
      target.current.dock = d;
      animate(dockMV, d, spr);
    }
  };

  const setDock = (value: number) => {
    if (target.current.open <= 0.5) return;
    haptics.tap("medium");
    go(null, value);
  };
  const tapSurface = () => {
    if (target.current.open < 0.5) {
      haptics.tap("light");
      go(1, 0);
    } else if (target.current.dock > 0.5) setDock(0);
  };
  const close = () => {
    haptics.tap("light");
    go(0, 0);
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const step = autoStep.current % 5;
      if (step === 0) tapSurface();
      else if (step === 1 || step === 3) setDock(1);
      else if (step === 2) setDock(0);
      else close();
      autoStep.current += 1;
    },
    { every: 1.3 },
  );

  const pan = usePan(
    {
      onStart: () => {
        dragged.current = true;
        if (target.current.open > 0.5) {
          dockMV.stop();
          dragBase.current = target.current.dock > 0.5 ? 1 : 0;
        }
      },
      onChange: ({ translation: t }) => {
        if (dragBase.current === null) return;
        const raw = dragBase.current + t.y / TRAVEL;
        // Soft limits past either end.
        const value = raw < 0 ? -rubberBand(-raw, 0.25) : raw > 1 ? 1 + rubberBand(raw - 1, 0.12) : raw;
        dockMV.set(value);
        target.current.dock = value;
      },
      onEnd: ({ translation: t, velocity: v }) => {
        const base = dragBase.current;
        if (base === null) return;
        dragBase.current = null;
        const projected = base + predicted(t.y, v.y) / TRAVEL;
        const threshold = ctx.n("threshold");
        const to = base < 0.5 ? (projected > threshold ? 1 : 0) : projected < 1 - threshold ? 0 : 1;
        if (to !== base) haptics.tap("medium");
        go(null, to);
      },
    },
    10,
  );

  const opened = unit(open);
  const docked = unit(dock);
  const rect = lerpRect(lerpRect(THUMB, PLAYER, open), pipRect(ctx.n("pip")), dock);
  const radius = mixN(mixN(16, 0, opened), 12, docked);
  // How much of the "full player" state is showing.
  const sheet = opened * (1 - smooth(dock, 0, 0.7));
  const controls = opened * (1 - smooth(dock, 0, 0.35));
  const mini = smooth(dock, 0.7, 1);
  const thumbAlpha = 1 - smooth(open, 0, 0.4);
  const hint: [string, string] = target.current.open < 0.5 ? ["Tap the thumbnail", "点击缩略图"] : target.current.dock > 0.5 ? ["Tap the window to expand", "点击小窗重新展开"] : ["Drag the player down", "向下拖动播放器"];

  const onClick = (e: React.MouseEvent<HTMLDivElement>) => {
    if (dragged.current) {
      dragged.current = false;
      return;
    }
    const p = localPoint(e, e.currentTarget);
    if (controls > 0.6 && p.x <= 46 && p.y <= 46) setDock(1);
    else if (mini > 0.6 && p.x >= rect.w - 36 && p.y <= 36) close();
    else tapSurface();
  };

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        <Feed zh={zh} playing={opened} />
        <div style={{ position: "absolute", left: 0, top: PLAYER.h + (1 - opened) * 30 + docked * 46, width: W, height: H - PLAYER.h, opacity: sheet, pointerEvents: "none" }}>
          <Details zh={zh} />
        </div>
        <div
          {...pan}
          onPointerDown={(e) => {
            dragged.current = false;
            pan.onPointerDown(e);
          }}
          onClick={onClick}
          style={{
            ...pan.style,
            position: "absolute",
            left: rect.x,
            top: rect.y,
            width: rect.w,
            height: rect.h,
            borderRadius: radius,
            overflow: "hidden",
            boxShadow: `0 ${4 + 6 * docked}px ${8 + 10 * docked}px ${black(0.14 + 0.2 * docked)}`,
            cursor: "pointer",
          }}
        >
          <Video height={rect.h} preview={ctx.isPreview} />
          {/* Thumbnail state: play glyph and duration. */}
          <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", opacity: thumbAlpha, pointerEvents: "none" }}>
            <div style={{ width: 50, height: 50, borderRadius: 25, background: black(0.4), color: "#fff", display: "grid", placeItems: "center", transform: `scale(${1 + 0.5 * opened})` }}>
              <Play size={21} fill="currentColor" strokeWidth={2} style={{ marginLeft: 2 }} />
            </div>
          </div>
          <div style={{ position: "absolute", right: 8, bottom: 8, height: 20, padding: "0 6px", borderRadius: 6, background: black(0.55), color: "#fff", fontSize: 11, fontWeight: 600, display: "grid", placeItems: "center", fontVariantNumeric: "tabular-nums", opacity: thumbAlpha, pointerEvents: "none" }}>
            4:12
          </div>
          {/* Full player: minimise button. */}
          <div style={{ position: "absolute", left: 10, top: 10, width: 32, height: 32, borderRadius: 16, background: black(0.35), color: "#fff", display: "grid", placeItems: "center", opacity: controls, pointerEvents: "none" }}>
            <ChevronDown size={16} strokeWidth={3.2} />
          </div>
          {/* PiP: close button. */}
          <div style={{ position: "absolute", right: 6, top: 6, width: 24, height: 24, borderRadius: 12, background: black(0.45), color: "#fff", display: "grid", placeItems: "center", opacity: mini, pointerEvents: "none" }}>
            <X size={11} strokeWidth={3.6} />
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${white(0.14 * docked)}`, pointerEvents: "none" }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en={hint[0]} zh={hint[1]} />
    </Column>
  );
}

/** The "video": a dusk landscape whose ridges scroll at different speeds, with a scrubber along the bottom. */
function Video({ height, preview }: { height: number; preview: boolean }) {
  const ref = useRef<HTMLCanvasElement>(null);
  const clock = useClock(true, preview ? 30 : undefined);
  const time = (clock + 7.5) % 600;
  const dpr = Math.max(typeof window === "undefined" ? 2 : window.devicePixelRatio, 2);
  const w = 316;
  const h = 178;
  useLayoutEffect(() => {
    const g = ref.current?.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    const sky = g.createLinearGradient(w * 0.4, 0, w * 0.55, h);
    ["#1B1F5E", "#8A3F8F", "#FF8A5C", "#FFD08A"].forEach((c, i) => sky.addColorStop(i / 3, c));
    g.fillStyle = sky;
    g.fillRect(0, 0, w, h);
    const sunRadius = h * 0.16;
    const sx = w * 0.68;
    const sy = h * (0.5 + 0.02 * Math.sin(time * 0.4));
    const glow = g.createRadialGradient(sx, sy, 0, sx, sy, sunRadius * 3);
    glow.addColorStop(0, "rgba(255,255,255,0.45)");
    glow.addColorStop(1, "rgba(255,255,255,0)");
    g.fillStyle = glow;
    g.beginPath();
    g.arc(sx, sy, sunRadius * 3, 0, Math.PI * 2);
    g.fill();
    g.fillStyle = "#FFF1C9";
    g.beginPath();
    g.arc(sx, sy, sunRadius, 0, Math.PI * 2);
    g.fill();
    const layers: [number, number, number, string][] = [
      [0.58, 0.16, 0.05, "rgba(122,60,134,0.85)"],
      [0.72, 0.14, 0.11, "#4A2468"],
      [0.86, 0.1, 0.2, "#1F1238"],
    ];
    layers.forEach((layer, index) => {
      g.beginPath();
      g.moveTo(0, h);
      for (let step = 0; step <= 40; step++) {
        const u = step / 40;
        const phase = u * 5 + time * layer[2] * 3 + index * 1.7;
        const ridge = Math.sin(phase) * 0.6 + Math.sin(phase * 2.3 + 1.1) * 0.4;
        g.lineTo(w * u, h * (layer[0] - layer[1] * ridge * 0.5));
      }
      g.lineTo(w, h);
      g.closePath();
      g.fillStyle = layer[3];
      g.fill();
    });
    // Scrubber (at least 2 pt tall at whatever size the video is shown).
    const played = (time % 24) / 24;
    const bar = (Math.max(height * 0.016, 2) * h) / Math.max(height, 1);
    g.fillStyle = "rgba(255,255,255,0.28)";
    g.fillRect(0, h - bar, w, bar);
    g.fillStyle = Palette.coral;
    g.fillRect(0, h - bar, w * played, bar);
  });
  return <canvas ref={ref} width={w * dpr} height={h * dpr} style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }} />;
}

function Feed({ zh, playing }: { zh: boolean; playing: number }) {
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ height: 44, marginBottom: 8, padding: "0 16px", display: "flex", alignItems: "flex-end", fontSize: 22, lineHeight: "27px", fontWeight: 700 }}>{zh ? "为你推荐" : "For you"}</div>
      <div style={{ margin: "0 12px", width: THUMB.w, height: THUMB.h, borderRadius: 16, background: Palette.labelAlpha(0.07), display: "flex", alignItems: "center", justifyContent: "center", gap: 6, fontSize: 12, fontWeight: 600, color: Palette.secondaryLabel }}>
        <AudioLines size={14} strokeWidth={2.4} style={{ opacity: playing }} />
        <span style={{ opacity: playing }}>{zh ? "正在播放" : "Now playing"}</span>
      </div>
      <div style={{ height: 46, padding: "0 14px", display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 30, height: 30, flexShrink: 0, borderRadius: 15, background: Palette.sunset }} />
        <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
          <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600, whiteSpace: "nowrap" }}>{zh ? "山脊线上的黄昏延时" : "Dusk timelapse from the ridge"}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel }}>{zh ? "远山影像 · 12 万次观看" : "Farhill Films · 120K views"}</span>
        </div>
      </div>
      <div style={{ margin: "4px 12px 0", width: THUMB.w, height: 120, borderRadius: 16, background: diag(hex(Palette.sky, 0.8), Palette.indigo) }} />
    </div>
  );
}

function Details({ zh }: { zh: boolean }) {
  return (
    <div style={{ position: "absolute", inset: 0, background: Palette.surface, padding: "12px 16px 0", display: "flex", flexDirection: "column", gap: 10 }}>
      <span style={{ fontSize: 16, lineHeight: "19px", fontWeight: 700 }}>{zh ? "山脊线上的黄昏延时" : "Dusk timelapse from the ridge"}</span>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 30, height: 30, borderRadius: 15, background: Palette.sunset }} />
        <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
          <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 600 }}>{zh ? "远山影像" : "Farhill Films"}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel }}>{zh ? "48 万订阅" : "480K subscribers"}</span>
        </div>
        <span style={{ flex: 1 }} />
        <div style={{ height: 28, padding: "0 12px", borderRadius: 14, background: Palette.label, color: Palette.background, fontSize: 12, fontWeight: 600, display: "grid", placeItems: "center" }}>{zh ? "订阅" : "Subscribe"}</div>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 64, height: 36, borderRadius: 8, background: diag(hex(Palette.sky, 0.8), Palette.indigo) }} />
        <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
          <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, color: Palette.secondaryLabel }}>{zh ? "接下来播放" : "Up next"}</span>
          <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 500, whiteSpace: "nowrap" }}>{zh ? "云海之上的清晨" : "Morning above the clouds"}</span>
        </div>
      </div>
    </div>
  );
}
