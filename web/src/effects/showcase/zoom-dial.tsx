/** showcase.zoom-dial · 变焦拨盘 (Showcase+ZoomDial.swift) */
import { useEffect, useRef } from "react";
import { black, clamp, fonts, hex, localPoint, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { LandscapeArt, Signature, SignatureRim, signatureCard } from "./signature";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const W = 248;
const DH = 86;
const R = 190;
const STOPS = [0.5, 1, 2, 3, 5, 8, 10];
function zoomLabel(zoom: number): string {
  if (zoom < 0.95) return zoom.toFixed(1).replace("0.", ".");
  if (Math.abs(zoom - Math.round(zoom)) < 0.05) return String(Math.round(zoom));
  return zoom.toFixed(1);
}

export default function ZoomDial({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [level, levelApi] = useAnimatedNumber(0);
  const [open, openApi] = useAnimatedNumber(0);
  const st = useRef({ open: false, dragStart: null as number | null, hold: 0, fold: 0, scripting: false, flip: false, startX: 0, down: false });
  const script = useStudioScript();
  const spacing = ctx.n("spacing");
  const maxLevel = Math.log2(Math.max(ctx.n("max"), 2));
  const pointsPerDoubling = (R * spacing * Math.PI) / 180;
  useEffect(
    () => () => {
      window.clearTimeout(st.current.hold);
      window.clearTimeout(st.current.fold);
    },
    [],
  );

  const openDial = (user: boolean) => {
    if (st.current.open) return;
    if (user) haptics.tap("light");
    st.current.open = true;
    openApi.animateTo(1, spring(0.4, 0.72));
  };
  const scheduleFold = () => {
    window.clearTimeout(st.current.fold);
    st.current.fold = window.setTimeout(() => {
      st.current.open = false;
      openApi.animateTo(0, spring(0.45, 0.85));
    }, ctx.n("fold") * 1000);
  };
  const setLevel = (raw: number, user: boolean) => {
    let value = clamp(raw, -1, maxLevel);
    let onStop = false;
    for (const stop of STOPS.map((s) => Math.log2(s))) {
      if (stop <= maxLevel + 0.001 && Math.abs(value - stop) < 0.045) {
        value = stop;
        onStop = true;
      }
    }
    const before = levelApi.get();
    if (value === before) return;
    levelApi.set(value);
    if (!user) return;
    if (onStop) haptics.tap("rigid");
    else if (Math.floor(value * 8) !== Math.floor(before * 8)) haptics.selection();
  };
  const finishDrag = (tapAt: number | null) => {
    const s = st.current;
    window.clearTimeout(s.hold);
    s.dragStart = null;
    if (tapAt !== null) {
      const target = tapAt < W / 2 - 28 ? 0.5 : tapAt > W / 2 + 28 ? 3 : Math.abs(levelApi.get()) < 0.05 ? 2 : 1;
      haptics.tap("light");
      levelApi.animateTo(Math.min(Math.log2(target), maxLevel), spring(0.45, 0.8));
    } else scheduleFold();
  };
  const runScript = () => {
    const s = st.current;
    if (s.dragStart !== null) return;
    window.clearTimeout(s.fold);
    script.run(async (task) => {
      s.scripting = true;
      openDial(false);
      if (!(await task.pause(0.45))) return;
      const from = levelApi.get();
      const target = s.flip ? 0 : Math.min(Math.log2(3), maxLevel);
      s.flip = !s.flip;
      const finished = await task.script(1.3, (t) => setLevel(from + (target - from) * studioEase(t), false));
      if (!task.alive()) return;
      s.scripting = false;
      if (!finished) return;
      scheduleFold();
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 4.0, delay: 0.7 });

  const gesture = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      const s = st.current;
      s.down = true;
      s.startX = localPoint(e, e.currentTarget).x;
      script.cancel();
      s.scripting = false;
      window.clearTimeout(s.fold);
      s.dragStart = levelApi.get();
      if (!s.open) {
        window.clearTimeout(s.hold);
        s.hold = window.setTimeout(() => openDial(true), 160);
      }
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      const s = st.current;
      if (!s.down || s.dragStart === null) return;
      const dx = localPoint(e, e.currentTarget).x - s.startX;
      if (!s.open && Math.abs(dx) > 6) {
        window.clearTimeout(s.hold);
        openDial(true);
      }
      if (s.open) setLevel(s.dragStart - dx / pointsPerDoubling, true);
    },
    onPointerUp: (e: React.PointerEvent<HTMLDivElement>) => {
      const s = st.current;
      if (!s.down) return;
      s.down = false;
      if (s.dragStart === null) return;
      const x = localPoint(e, e.currentTarget).x;
      const moved = Math.abs(x - s.startX) > 6;
      finishDrag(s.open || moved ? null : x);
    },
    onPointerCancel: () => {
      st.current.down = false;
      if (st.current.dragStart !== null) finishDrag(null);
    },
  };

  const zoom = Math.pow(2, level);
  const shown = clamp(open);
  const wheel = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const el = wheel.current;
    if (!el) return;
    const dpr = Math.max(2, window.devicePixelRatio || 1);
    if (el.width !== W * dpr) {
      el.width = W * dpr;
      el.height = DH * dpr;
    }
    const g = el.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, W, DH);
    const cx = W / 2;
    const cy = 16 + R;
    const rad = (deg: number) => (deg * Math.PI) / 180;
    g.lineWidth = 46;
    g.lineCap = "butt";
    for (const color of [black(0.5), white(0.06)]) {
      g.strokeStyle = color;
      g.beginPath();
      g.arc(cx, cy, R - 15, rad(-140), rad(-40));
      g.stroke();
    }
    const point = (degrees: number, r: number) => ({ x: cx + r * Math.sin(rad(degrees)), y: cy - r * Math.cos(rad(degrees)) });
    g.lineCap = "round";
    const count = Math.trunc((maxLevel + 1) * 8 + 0.5);
    for (let index = 0; index <= Math.max(count, 1); index++) {
      const degrees = (-1 + index / 8 - level) * spacing;
      if (Math.abs(degrees) >= 44) continue;
      const fade = 1 - Math.pow(Math.abs(degrees) / 44, 2);
      const a = point(degrees, R);
      const b = point(degrees, R - 6);
      g.strokeStyle = white(0.4 * fade);
      g.lineWidth = 1.2;
      g.beginPath();
      g.moveTo(a.x, a.y);
      g.lineTo(b.x, b.y);
      g.stroke();
    }
    g.textAlign = "center";
    g.textBaseline = "middle";
    for (const stop of STOPS) {
      if (Math.log2(stop) > maxLevel + 0.001) continue;
      const degrees = (Math.log2(stop) - level) * spacing;
      if (Math.abs(degrees) >= 44) continue;
      const fade = 1 - Math.pow(Math.abs(degrees) / 44, 2);
      const near = Math.max(0, 1 - Math.abs(degrees) / 5);
      const a = point(degrees, R + 1);
      const b = point(degrees, R - 11);
      g.strokeStyle = white(fade);
      g.lineWidth = 2;
      g.beginPath();
      g.moveTo(a.x, a.y);
      g.lineTo(b.x, b.y);
      g.stroke();
      g.font = `700 ${11 + 2 * near}px ${fonts.rounded}`;
      g.fillStyle = near > 0.5 ? Signature.accent : white(0.85 * fade);
      const p = point(degrees, R - 24);
      g.fillText(zoomLabel(stop), p.x, p.y + 0.5);
    }
    g.fillStyle = Signature.accent;
    g.beginPath();
    g.moveTo(cx - 5, 2);
    g.lineTo(cx + 5, 2);
    g.lineTo(cx, 11);
    g.closePath();
    g.fill();
  });

  const sideChip = (text: string) => (
    <span style={{ width: 30, height: 30, borderRadius: "50%", background: black(0.45), display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 700, color: white(0.85), opacity: 1 - shown, transform: `scale(${1 - 0.3 * shown})` }}>{text}</span>
  );
  const arm = 62 * 0.24;

  return (
    <StudioScene ctx={ctx} en="Hold the zoom pill, then drag" zh="按住变焦胶囊，再左右拖动">
      <div style={{ ...signatureCard(), padding: 16, display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ position: "relative", width: W, height: 150, borderRadius: 18, overflow: "hidden" }}>
          <div style={{ position: "absolute", inset: 0, transformOrigin: "47% 46%", transform: `scale(${Math.pow(zoom / 0.5, 0.62)})` }}>
            <LandscapeArt seed={1} />
          </div>
          <svg width={62} height={62} style={{ position: "absolute", left: W / 2 - 31, top: 75 - 31, overflow: "visible", transform: `scale(${1 + 0.12 * open})`, filter: `drop-shadow(0 0 1.5px ${black(0.5)})` }}>
            <path
              d={`M${arm} 0H0V${arm} M${62 - arm} 0H62V${arm} M${62 - arm} 62H62V${62 - arm} M${arm} 62H0V${62 - arm}`}
              fill="none"
              stroke={white(0.8)}
              strokeWidth={1.4}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 1px ${white(0.12)}` }} />
        </div>
        <div {...gesture} style={{ position: "relative", width: W, height: DH, touchAction: "none" }}>
          <canvas ref={wheel} style={{ position: "absolute", left: 0, top: 0, width: W, height: DH, transformOrigin: "50% 100%", transform: `translateY(${(1 - open) * 26}px) scale(${0.7 + 0.3 * open})`, opacity: shown }} />
          <div style={{ position: "absolute", left: 0, right: 0, bottom: 2, display: "flex", justifyContent: "center" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, padding: 5, borderRadius: 22, background: white(0.07 * (1 - shown)) }}>
              {sideChip(".5")}
              <span style={{ width: 46, height: 34, borderRadius: 17, background: black(0.55), boxShadow: `inset 0 0 0 1px ${hex(0xff8a1f, 0.35 + 0.4 * shown)}`, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 13, fontWeight: 800, fontVariantNumeric: "tabular-nums", color: Signature.accent }}>{zoomLabel(zoom) + "×"}</span>
              {sideChip("3")}
            </div>
          </div>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
