/** cards.fold-half · 对折翻面 (Cards+FoldHalf.swift) */
import { animate, useMotionValue } from "motion/react";
import { MicVocal } from "lucide-react";
import { memo, useRef, useState, type ReactNode } from "react";
import { DemoHint, anim, black, clamp, fonts, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, diag, useMV } from "./shared";
import { Projected, hingeX, projection, track } from "./_kit";

const SIZE = { w: 236, h: 216 };
const HALF = 108;
const DEPTH = 720;
const EYE = { x: SIZE.w / 2, y: HALF };
const INK = "#2A2630";

const MASK64 = (1n << 64n) - 1n;
const lcg = (seed: bigint) => (seed * 6364136223846793005n + 1442695040888963407n) & MASK64;

/** A QR-like block of modules (fixed pattern, not a real code). */
const CODE: [number, number][] = (() => {
  const cells = 11;
  const on: [number, number][] = [];
  let seed = 0x9e3779b97f4a7c15n;
  for (let row = 0; row < cells; row++) {
    for (let column = 0; column < cells; column++) {
      seed = lcg(seed);
      const corner = (row < 3 || row > cells - 4) && (column < 3 || column > cells - 4) && !(row > cells - 4 && column > cells - 4);
      const lit = corner
        ? row % (cells - 1) === 0 || column % (cells - 1) === 0 || row === 2 || column === 2 || row === cells - 3 || column === cells - 3 || (row === 1 && column === 1) || (row === 1 && column === cells - 2) || (row === cells - 2 && column === 1)
        : (seed >> 33n) % 5n < 2n;
      if (lit) on.push([row, column]);
    }
  }
  return on;
})();

const BARS: [number, number][] = (() => {
  const bars: [number, number][] = [];
  let x = 0;
  let seed = 0x51f15eedn;
  while (x < SIZE.w - 36) {
    seed = lcg(seed);
    const width = 1 + Number((seed >> 40n) % 3n);
    seed = lcg(seed);
    const gap = 1 + Number((seed >> 40n) % 3n);
    bars.push([x, width]);
    x += width + gap;
  }
  return bars;
})();

export default function FoldHalf({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progressMV = useMotionValue(0);
  const steps = useRef(0);
  const [thuds, setThuds] = useState(0);
  const busy = useRef(false);
  const script = useTimeouts();

  const fold = (muted: boolean) => {
    if (busy.current) return;
    busy.current = true;
    if (!muted) haptics.tap("light");
    const fall = ctx.n("fall");
    const response = ctx.n("response");
    const base = steps.current * 2;
    steps.current += 1;
    animate(progressMV, base + 1, anim.curve(0.55, 0, 0.9, 0.55, fall));
    script.clearAll();
    script.after(fall, () => {
      setThuds((n) => n + 1);
      if (!muted) haptics.tap("medium");
      script.after(0.1, () => {
        animate(progressMV, base + 2, spring(response, ctx.n("damping")));
        script.after(response * 0.9, () => (busy.current = false));
      });
    });
  };

  useAutoplay(ctx.isPreview, () => fold(true), { every: 2.4 });

  const progress = useMV(progressMV);
  const shade = ctx.n("shade");
  const zh = ctx.lang === "zh";
  const e = useElapsed(thuds, 0.6, true);
  const squash = e < 0 ? 1 : track(e, 1, [{ cubic: 0.96, d: 0.07 }, { spring: 1, d: 0.4, response: 0.26, damping: 0.5 }]);

  const cycle = Math.floor(progress / 2);
  const local = progress - cycle * 2;
  // Every completed flip swaps which side is "inside".
  const showing = ((cycle % 2) + 2) % 2 === 0 ? 0 : 1;
  const hidden = 1 - showing;
  // The top half falls 0 → 180°; the lower half then rises from edge-on (90°) to flat (180°).
  const fall = Math.min(local, 1) * Math.PI;
  const rise = local <= 1 ? 0 : Math.PI / 2 + ((local - 1) * Math.PI) / 2;

  // Upper half.
  const upBack = fall > Math.PI / 2;
  const tip = Math.sin(fall);
  const upDark = upBack ? 0 : 0.5 * shade * tip;
  const upLit = upBack ? 0.3 * shade * tip : 0;
  // Lower half.
  const lowBack = rise > Math.PI / 2;
  const cast = rise > 0 ? 0 : 0.5 * shade * (fall / Math.PI);
  const turned = clamp((rise - Math.PI / 2) / (Math.PI / 2));
  const lowDark = lowBack ? 0.55 * shade * (1 - turned) : 0;
  // Ground shadow.
  const top = rise > 0 ? Math.max(-Math.cos(rise), 0) : Math.max(Math.cos(fall), 0);
  const shadowH = HALF * (1 + top);

  const panel = (kind: number, mirrored: boolean, clip: string, transform: string, overlays: ReactNode, opacity = 1) => (
    <Projected w={SIZE.w} h={SIZE.h} transform={transform} style={{ opacity }} inner={{ clipPath: clip }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden", transform: mirrored ? "scaleY(-1)" : undefined }}>
        <Side kind={kind} zh={zh} />
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden" }}>{overlays}</div>
    </Projected>
  );

  return (
    <Stage gap={14}>
      <div onClick={() => fold(false)} style={{ position: "relative", width: SIZE.w, height: SIZE.h, flexShrink: 0, cursor: "pointer", transformOrigin: "50% 100%", transform: `scale(${2 - squash}, ${squash})` }}>
        <div style={{ position: "absolute", left: SIZE.w * 0.04, bottom: -12, width: SIZE.w * 0.92, height: shadowH, borderRadius: 20, background: "#000", filter: "blur(14px)", opacity: 0.26 }} />
        {panel(
          lowBack ? hidden : showing,
          lowBack,
          `inset(${HALF}px 0 0 0)`,
          projection(hingeX(HALF, -rise), EYE, DEPTH),
          <>
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${black(cast)} 50%, ${black(cast * 0.25)})` }} />
            <div style={{ position: "absolute", inset: 0, background: black(lowDark) }} />
          </>,
          rise > 0 && !lowBack ? 0 : 1,
        )}
        {panel(
          upBack ? hidden : showing,
          upBack,
          `inset(0 0 ${HALF}px 0)`,
          projection(hingeX(HALF, -fall), EYE, DEPTH),
          <>
            <div style={{ position: "absolute", inset: 0, background: black(upDark) }} />
            <div style={{ position: "absolute", inset: 0, background: white(upLit) }} />
          </>,
        )}
      </div>
      <DemoHint ctx={ctx} en="Tap the ticket" zh="点击票券" />
    </Stage>
  );
}

/** One side of the ticket with its crease. */
const Side = memo(function Side({ kind, zh }: { kind: number; zh: boolean }) {
  const t = (en: string, cn: string) => (zh ? cn : en);
  const field = (label: string, value: string) => (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1 }}>
      <span style={{ fontSize: 9, lineHeight: "11px", fontWeight: 600, letterSpacing: 1.2, opacity: 0.75 }}>{label}</span>
      <span style={{ fontFamily: fonts.rounded, fontSize: 22, lineHeight: "26px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{value}</span>
    </div>
  );
  const crease = (
    <div style={{ position: "absolute", left: 0, right: 0, top: HALF - 0.8 }}>
      <div style={{ height: 0.8, background: black(0.16) }} />
      <div style={{ height: 0.8, background: white(0.22) }} />
    </div>
  );
  if (kind === 0) {
    return (
      <div style={{ position: "absolute", inset: 0, background: diag(["#FF8A4C", "#FF4F8B", "#7A3FE0"]), color: "#fff", overflow: "hidden" }}>
        <div style={{ position: "absolute", right: -56 - 9, top: -70 - 9, width: 188, height: 188, borderRadius: "50%", border: `18px solid ${white(0.14)}` }} />
        <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: HALF, padding: "16px 18px 10px", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 4 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6, opacity: 0.85 }}>
            <MicVocal size={13} strokeWidth={2.6} />
            <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 700, letterSpacing: 1.4 }}>{t("LIVE · ONE NIGHT", "现场 · 仅此一夜")}</span>
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 30, lineHeight: "36px", fontWeight: 800, whiteSpace: "nowrap" }}>{t("Neon Nights", "霓虹之夜")}</span>
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: HALF, height: HALF, padding: "0 18px 16px", display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
          <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 600, opacity: 0.9, marginTop: 10, whiteSpace: "nowrap" }}>{t("Harbour Hall · Doors 19:30", "海港音乐厅 · 19:30 入场")}</span>
          <span style={{ flex: 1 }} />
          <div style={{ alignSelf: "stretch", display: "flex", alignItems: "flex-end", justifyContent: "space-between" }}>
            {field(t("DATE", "日期"), "10.24")}
            {field(t("ROW", "排"), "F")}
            {field(t("SEAT", "座"), "18")}
          </div>
        </div>
        {crease}
      </div>
    );
  }
  const cell = 70 / 11;
  return (
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(#FBF7EF, #EDE6D8)", color: INK }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: HALF, padding: "8px 18px 0", display: "flex", alignItems: "center", gap: 14 }}>
        <svg width={70} height={70} style={{ flexShrink: 0 }}>
          {CODE.map(([row, column]) => (
            <rect key={`${row}-${column}`} x={column * cell} y={row * cell} width={cell + 0.3} height={cell + 0.3} fill={INK} />
          ))}
        </svg>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3, whiteSpace: "nowrap" }}>
          <span style={{ fontFamily: fonts.rounded, fontSize: 17, lineHeight: "20px", fontWeight: 800 }}>{t("ADMIT ONE", "凭票入场")}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, opacity: 0.6 }}>{t("Scan at gate B", "请在 B 口扫码")}</span>
          <span style={{ fontFamily: fonts.mono, fontSize: 10, lineHeight: "12px", fontWeight: 600, opacity: 0.6 }}>NN-1024-F18</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: HALF, height: HALF, padding: "0 18px 6px", display: "flex", flexDirection: "column", justifyContent: "center", gap: 9 }}>
        <svg width={SIZE.w - 36} height={38} style={{ flexShrink: 0 }}>
          {BARS.map(([x, w]) => (
            <rect key={x} x={x} y={0} width={w} height={38} fill={INK} />
          ))}
        </svg>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: 10, lineHeight: "12px", fontWeight: 600, opacity: 0.55, whiteSpace: "nowrap" }}>
          <span>{t("Non-transferable", "不可转让")}</span>
          <span>{t("No re-entry", "离场后不可再入")}</span>
        </div>
      </div>
      {crease}
    </div>
  );
});
