/**
 * Small helpers shared by the second round of Navigation ports.
 */
import type { MotionValue } from "motion/react";
import { useCallback, useRef, type CSSProperties } from "react";
import { rubberBand, useAutoplay, type PanState } from "../../kit";
import { predicted, useNavPan as useBaseNavPan } from "./nav-util";

/** The usual demo root: a `VStack` centred in the stage. */
export const stageColumn = (gap: number): CSSProperties => ({
  position: "absolute",
  inset: 0,
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  gap,
});

/** `LinearGradient(colors:, startPoint: .topLeading, endPoint: .bottomTrailing)` on any box. */
export const diag = (...colors: string[]) => `linear-gradient(to bottom right, ${colors.join(", ")})`;
export const vert = (...colors: string[]) => `linear-gradient(to bottom, ${colors.join(", ")})`;

/**
 * `useAutoplay` that also tells the action it is a simulated tap, so haptics the action schedules for
 * later (which the kit cannot mute, it only mutes synchronously) can be skipped: read `auto.current`
 * inside the action.
 */
export function useAutoplayFlag(active: boolean, action: () => void, opts?: { every?: number; delay?: number; intro?: boolean }) {
  const auto = useRef(false);
  const latest = useRef(action);
  latest.current = action;
  const run = useCallback(() => {
    auto.current = true;
    try {
      latest.current();
    } finally {
      auto.current = false;
    }
  }, []);
  useAutoplay(active, run, opts);
  return auto;
}

/** `Color.mix(with:by:)` between two CSS colours. */
export const mixColor = (a: string, b: string, t: number) => `color-mix(in oklab, ${a} ${((1 - t) * 100).toFixed(2)}%, ${b})`;

/** Colour at an opacity for any CSS colour (hex, var, color-mix). */
export const fade = (color: string, opacity: number) => `color-mix(in srgb, ${color} ${(opacity * 100).toFixed(2)}%, transparent)`;

/** `Shape.strokeBorder(LinearGradient…, lineWidth:)` on a rounded box: a 1 px gradient ring inside the parent. */
export function GradientStroke({ gradient, width = 1, radius = "inherit" }: { gradient: string; width?: number; radius?: number | string }) {
  const mask = "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)";
  return (
    <div
      aria-hidden
      style={{
        position: "absolute",
        inset: 0,
        borderRadius: radius,
        padding: width,
        background: gradient,
        WebkitMask: mask,
        WebkitMaskComposite: "xor",
        mask,
        maskComposite: "exclude",
        pointerEvents: "none",
      }}
    />
  );
}

type GlyphProps = { size: number; color?: string; style?: CSSProperties };
const glyph = (d: string, evenodd = true) =>
  function GlyphIcon({ size, color = "currentColor", style }: GlyphProps) {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill={color} fillRule={evenodd ? "evenodd" : undefined} style={{ display: "block", flexShrink: 0, ...style }} aria-hidden>
        <path d={d} />
      </svg>
    );
  };

/** `camera.fill` */
export const CameraFill = glyph(
  "M8.6 4.2a1.6 1.6 0 0 0-1.4.8L6.4 6.5H4.6A2.6 2.6 0 0 0 2 9.1v8.3A2.6 2.6 0 0 0 4.6 20h14.8a2.6 2.6 0 0 0 2.6-2.6V9.1a2.6 2.6 0 0 0-2.6-2.6h-1.8L16.8 5a1.6 1.6 0 0 0-1.4-.8ZM12 8.6a4.4 4.4 0 1 1 0 8.8 4.4 4.4 0 0 1 0-8.8Zm0 1.7a2.7 2.7 0 1 0 0 5.4 2.7 2.7 0 0 0 0-5.4Z",
);
/** `photo.fill` */
export const PhotoFill = glyph(
  "M5 4h14a3 3 0 0 1 3 3v10a3 3 0 0 1-3 3H5a3 3 0 0 1-3-3V7a3 3 0 0 1 3-3Zm3.2 3.4a1.9 1.9 0 1 0 0 3.8 1.9 1.9 0 0 0 0-3.8ZM4 16.6V17a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-2.6l-4.300-4.300a1 1 0 0 0-1.400 0L9.500 14.900l-1.800-1.800a1 1 0 0 0-1.400 0Z",
);
/** `doc.text.fill` */
export const DocTextFill = glyph(
  "M7 2h6.200a2 2 0 0 1 1.400.6l4.800 4.800A2 2 0 0 1 20 8.800V19a3 3 0 0 1-3 3H7a3 3 0 0 1-3-3V5a3 3 0 0 1 3-3Zm1.500 9.300a.85.85 0 0 0 0 1.700h7a.85.85 0 0 0 0-1.700Zm0 3.600a.85.85 0 0 0 0 1.700h7a.85.85 0 0 0 0-1.700Zm0-7.200a.85.85 0 0 0 0 1.700h3a.85.85 0 0 0 0-1.700Z",
);
/** `play.fill` */
export const PlayFill = glyph("M7 3.700c0-1 1.100-1.600 2-1.100l12.300 7.800c.800.500.800 1.700 0 2.200L9 20.400c-.900.500-2-.100-2-1.100Z", false);
/** `pause.fill` */
export const PauseFill = glyph("M6.500 3h2.600c.800 0 1.400.600 1.400 1.400v15.200c0 .800-.600 1.400-1.400 1.400H6.500c-.800 0-1.400-.600-1.400-1.400V4.400C5.100 3.600 5.700 3 6.500 3Zm8.400 0h2.600c.800 0 1.400.600 1.400 1.400v15.200c0 .800-.600 1.400-1.400 1.400h-2.600c-.800 0-1.400-.600-1.400-1.400V4.400c0-.800.600-1.400 1.400-1.400Z", false);
/** `paperplane.fill` */
export const PaperplaneFill = glyph("M21.300 2.100c.500-.200 1 .300.800.800l-6.400 18.200c-.200.600-1 .600-1.300.100l-3.300-6.300 4.700-5.300-5.300 4.700-6.300-3.300c-.500-.300-.500-1.100.100-1.300Z", false);
/** `tray.full.fill` */
export const TrayFullFill = glyph(
  "M6.700 4h10.600a2 2 0 0 1 1.900 1.400L21.900 13v5a2.500 2.500 0 0 1-2.500 2.500H4.600A2.500 2.500 0 0 1 2.100 18v-5L4.800 5.400A2 2 0 0 1 6.700 4Zm.200 2-2.300 6.600h3.700c.500 0 .900.300 1 .800a2.800 2.800 0 0 0 5.400 0c.100-.500.500-.800 1-.800h3.700L17.100 6Zm1.200 1.600h7.800l.5 1.500H7.600Zm-.9 2.500h9.600l.5 1.500H6.700Z",
);

/** `sun.horizon.fill` */
export function SunHorizonFill({ size, style }: { size: number | string; style?: CSSProperties }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" strokeWidth={2} strokeLinecap="round" style={{ display: "block", ...style }} aria-hidden>
      <path d="M6.2 15.5a5.8 5.8 0 0 1 11.6 0Z" stroke="none" />
      <path d="M12 4.2v2.2M4.3 7.8l1.5 1.5M19.7 7.8l-1.5 1.5M1.8 15h1.6M20.6 15h1.6M2.5 19h19" fill="none" />
    </svg>
  );
}

const CLOUD = "M6.6 20a4.6 4.6 0 0 1-.6-9.160A6.2 6.2 0 0 1 17.900 9.400 5.300 5.300 0 0 1 17.600 20Z";

/** `cloud.sun.fill`; `sun` colours the sun (multicolour rendering), otherwise it is `currentColor`. */
export function CloudSunFill({ size, sun = "currentColor", style }: { size: number | string; sun?: string; style?: CSSProperties }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block", ...style }} aria-hidden>
      <g fill={sun} stroke={sun} strokeWidth={1.8} strokeLinecap="round">
        <circle cx={16.4} cy={8} r={3.5} stroke="none" />
        <path d="M16.4 1.6v1.300M10.900 2.900l.900.900M21.900 2.900l-.900.900M22.800 8h-1.300M21.600 13l-.800-.800" fill="none" />
      </g>
      <path d={CLOUD} fill="currentColor" transform="translate(-1.500 4.200) scale(0.800)" />
    </svg>
  );
}

/** `cloud.rain.fill` (white cloud, blue drops). */
export function CloudRainFill({ size, rain = "currentColor" }: { size: number | string; rain?: string }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ display: "block" }} aria-hidden>
      <path d={CLOUD} fill="currentColor" transform="translate(0 -4.500) scale(0.950)" />
      <path d="M8 17.500l-1.200 3.200M12.300 17.500l-1.200 3.200M16.600 17.500l-1.200 3.200" stroke={rain} strokeWidth={1.900} strokeLinecap="round" fill="none" />
    </svg>
  );
}

/**
 * The paging drag most of these demos share: the page index follows the finger 1:1 (`unit` points per
 * page), rubber-bands past both ends, and on release projects the flick at most `limit` pages away
 * from where the drag began. A cancelled drag settles from where it is.
 */
export function usePageDrag(
  mv: MotionValue<number>,
  o: {
    unit: number;
    last: number;
    bandLow?: number;
    bandHigh?: number;
    limit?: number;
    minimumDistance?: number;
    enabled?: () => boolean;
    onPage?: (page: number, s: PanState) => void;
    settle: (index: number, start: number) => void;
  },
) {
  const start = useRef<number | null>(null);
  const pan = useNavPan(
    {
      onChange: (s) => {
        if (o.enabled && !o.enabled()) return;
        if (start.current === null) {
          mv.stop();
          start.current = mv.get();
        }
        let page = start.current - s.translation.x / o.unit;
        if (page < 0) page = -rubberBand(-page, o.bandLow ?? 0.5);
        if (page > o.last) page = o.last + rubberBand(page - o.last, o.bandHigh ?? o.bandLow ?? 0.5);
        mv.set(page);
        o.onPage?.(page, s);
      },
      onEnd: (s) => {
        const from = start.current;
        if (from === null) return;
        start.current = null;
        const projected = s ? from - predicted(s).x / o.unit : mv.get();
        const limit = o.limit ?? 1;
        const limited = Math.min(Math.max(projected, Math.round(from) - limit), Math.round(from) + limit);
        o.settle(Math.round(limited), from);
      },
    },
    { axis: "horizontal", minimumDistance: o.minimumDistance ?? 10 },
  );
  return { pan, dragging: () => start.current !== null };
}

/** `checkmark.circle.fill` */
export const CheckCircleFill = glyph(
  "M12 1.5a10.5 10.5 0 1 1 0 21 10.5 10.5 0 0 1 0-21Zm4.9 6.6a1.1 1.1 0 0 0-1.55.2l-4.5 5.9-2.3-2.3a1.1 1.1 0 0 0-1.55 1.55l3.2 3.2a1.1 1.1 0 0 0 1.65-.1l5.25-6.9a1.1 1.1 0 0 0-.2-1.55Z",
);

const SEAL = (() => {
  const pts: string[] = [];
  for (let i = 0; i <= 96; i++) {
    const a = (i / 96) * Math.PI * 2;
    const r = 10.2 + 1.1 * Math.cos(8 * a);
    pts.push(`${i === 0 ? "M" : "L"}${(12 + r * Math.sin(a)).toFixed(2)} ${(12 - r * Math.cos(a)).toFixed(2)}`);
  }
  return `${pts.join("")}Z`;
})();
/** `seal.fill` */
export const SealFill = glyph(SEAL, false);

/** `note.text`: a rounded note with text lines. */
export function NoteText({ size, style }: { size: number | string; style?: CSSProperties }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" style={{ display: "block", ...style }} aria-hidden>
      <rect x={3} y={4} width={18} height={16} rx={3.5} />
      <path d="M7.5 9.5h9M7.5 13h9M7.5 16.2h5" strokeWidth={1.8} />
    </svg>
  );
}

/**
 * `useNavPan` that also swallows the click the browser sends after an engaged drag (a SwiftUI tap
 * never fires at the end of a drag), for elements that carry both a pan and an `onClick`.
 */
export function useNavPan(handlers: Parameters<typeof useBaseNavPan>[0], opts?: Parameters<typeof useBaseNavPan>[1]) {
  const engaged = useRef(false);
  const pan = useBaseNavPan(
    {
      ...handlers,
      onStart: (s) => {
        engaged.current = true;
        handlers.onStart?.(s);
      },
    },
    opts,
  );
  return {
    ...pan,
    onPointerDown: (e: React.PointerEvent<HTMLElement>) => {
      engaged.current = false;
      pan.onPointerDown(e);
    },
    onClickCapture: (e: React.MouseEvent<HTMLElement>) => {
      if (!engaged.current) return;
      engaged.current = false;
      e.stopPropagation();
    },
  };
}
