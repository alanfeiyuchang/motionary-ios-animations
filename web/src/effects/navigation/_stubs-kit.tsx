/**
 * Glyphs and small hooks shared by the older Navigation ports (context menu, dock, sheet, stepper…).
 */
import { useEffect, useId, useLayoutEffect, useRef, useState, type CSSProperties, type RefObject } from "react";
import { glass } from "../../kit";

/**
 * `.regularMaterial` behind menus and chips: the kit's glass with a denser tint, so content under it
 * stays hidden even while a transition (opacity / blur on an ancestor) switches the backdrop blur off.
 */
export const menuGlass = (): CSSProperties => ({ ...glass("regular"), background: "color-mix(in srgb, var(--ml-elevated) 86%, transparent)" });

type GlyphProps = { size: number; color?: string; style?: CSSProperties };
const box = (size: number, style?: CSSProperties) =>
  ({ width: size, height: size, viewBox: "0 0 24 24", style: { display: "block", flexShrink: 0, ...style }, "aria-hidden": true }) as const;

const SEAL = (() => {
  const pts: string[] = [];
  for (let i = 0; i <= 96; i++) {
    const a = (i / 96) * Math.PI * 2;
    const r = 10.2 + 1.1 * Math.cos(8 * a);
    pts.push(`${i === 0 ? "M" : "L"}${(12 + r * Math.sin(a)).toFixed(2)} ${(12 - r * Math.cos(a)).toFixed(2)}`);
  }
  return `${pts.join("")}Z`;
})();

/** `checkmark.seal.fill`: a scalloped seal with the checkmark cut out. */
export function CheckSealFill({ size, color = "currentColor", style }: GlyphProps) {
  const id = useId();
  return (
    <svg {...box(size, style)}>
      <defs>
        <mask id={id}>
          <rect width={24} height={24} fill="#fff" />
          <path d="M7.6 12.4l3 3 5.8-6.6" fill="none" stroke="#000" strokeWidth={2.3} strokeLinecap="round" strokeLinejoin="round" />
        </mask>
      </defs>
      <path d={SEAL} fill={color} mask={`url(#${id})`} />
    </svg>
  );
}

/** `music.note` (bold): one head, a stem and a block flag. */
export function MusicNote({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <ellipse cx={8.3} cy={18.4} rx={4.3} ry={3.3} transform="rotate(-18 8.3 18.4)" fill={color} />
      <path fill={color} d="M10.300 4.300c0-.800.600-1.500 1.400-1.650l6.100-1.250c.900-.200 1.700.500 1.700 1.400v3.300c0 .700-.500 1.300-1.200 1.450l-5.300 1.100V18.400h-2.700Z" />
    </svg>
  );
}

/** `mountain.2.fill` */
export function Mountain2Fill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path fill={color} d="M8.300 6.300c.500-.800 1.600-.800 2.100 0l3 4.800 1.500-2.200c.500-.700 1.500-.700 2 0l6.300 9.600c.500.800 0 1.900-1 1.900H1.900c-1 0-1.600-1.100-1-1.900Z" />
    </svg>
  );
}

/** `sparkles` */
export function SparklesFill({ size, color = "currentColor", style }: GlyphProps) {
  const star = (cx: number, cy: number, r: number) => {
    const k = r * 0.22;
    return `M${cx} ${cy - r}C${cx + k} ${cy - k * 1.6} ${cx + k * 1.6} ${cy - k} ${cx + r} ${cy}C${cx + k * 1.6} ${cy + k} ${cx + k} ${cy + k * 1.6} ${cx} ${cy + r}C${cx - k} ${cy + k * 1.6} ${cx - k * 1.6} ${cy + k} ${cx - r} ${cy}C${cx - k * 1.6} ${cy - k} ${cx - k} ${cy - k * 1.6} ${cx} ${cy - r}Z`;
  };
  return (
    <svg {...box(size, style)}>
      <path fill={color} d={`${star(14.2, 14.2, 7.8)}${star(5.6, 9, 3.8)}${star(10.4, 3.4, 2.5)}`} />
    </svg>
  );
}

/** `creditcard.fill` */
export function CreditCardFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path
        fill={color}
        fillRule="evenodd"
        d="M4.8 4.6h14.4a3 3 0 0 1 3 3v8.8a3 3 0 0 1-3 3H4.8a3 3 0 0 1-3-3V7.6a3 3 0 0 1 3-3ZM1.8 8.5v2.6h20.400V8.500ZM5.200 14a.9.9 0 0 0-.9.9v1.100a.9.9 0 0 0 .9.9h3a.9.9 0 0 0 .9-.9v-1.100a.9.9 0 0 0-.9-.9Z"
      />
    </svg>
  );
}

/** `cart.fill` */
export function CartFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path fill="none" stroke={color} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" d="M1.6 3.4h2.300l.9 3.200" />
      <path fill={color} d="M4.500 6h16.300a1.200 1.200 0 0 1 1.150 1.500l-1.700 6.400a2.200 2.200 0 0 1-2.100 1.600H8.200a2.200 2.200 0 0 1-2.100-1.600Z" />
      <path fill="none" stroke={color} strokeWidth={1.800} strokeLinecap="round" d="M6.800 15.200l-.500 2.300h12.400" />
      <circle cx={8.400} cy={20} r={1.700} fill={color} />
      <circle cx={17.600} cy={20} r={1.700} fill={color} />
    </svg>
  );
}

/** `doc.fill` */
export function DocFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path fill={color} d="M7 2h5.400v5.200a2 2 0 0 0 2 2H19.600V19.200a2.800 2.800 0 0 1-2.800 2.800H7.200a2.800 2.800 0 0 1-2.800-2.800V4.800A2.800 2.800 0 0 1 7 2Z" />
      <path fill={color} d="M14.100 2.300 19.300 7.500H15a.9.900 0 0 1-.9-.9Z" />
    </svg>
  );
}

/** `location.fill` */
export function LocationFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path fill={color} d="M20.300 2.600c.800-.300 1.500.400 1.100 1.200l-7.600 16.900c-.400.900-1.700.700-1.800-.300l-.800-7.400-7.400-.800c-1-.100-1.200-1.400-.300-1.800Z" />
    </svg>
  );
}

/** `mic.fill` */
export function MicFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <rect x={8.400} y={1.800} width={7.200} height={12.600} rx={3.600} fill={color} />
      <path fill="none" stroke={color} strokeWidth={1.900} strokeLinecap="round" d="M5.200 10.800v.600a6.800 6.800 0 0 0 13.600 0v-.600M12 18.300v3.300M8.600 21.600h6.800" />
    </svg>
  );
}

/** `message.fill` */
export function MessageFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path fill={color} d="M12 2.800c5.600 0 10.100 3.800 10.100 8.500s-4.500 8.500-10.100 8.500c-1 0-2-.100-2.900-.400-1.200 1-2.800 1.700-4.500 1.900-.500.100-.800-.500-.500-.900.700-.900 1.200-1.900 1.300-2.900C3.200 16 1.900 13.800 1.900 11.300c0-4.700 4.500-8.500 10.100-8.500Z" />
    </svg>
  );
}

/** `gearshape.fill` */
export function GearFill({ size, color = "currentColor", style }: GlyphProps) {
  const teeth: string[] = [];
  const n = 8;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const w = 0.21;
    const p = (r: number, t: number) => `${(12 + r * Math.sin(t)).toFixed(2)} ${(12 - r * Math.cos(t)).toFixed(2)}`;
    teeth.push(`${i === 0 ? "M" : "L"}${p(8.1, a - w - 0.12)}L${p(10.6, a - w)}L${p(10.6, a + w)}L${p(8.1, a + w + 0.12)}`);
  }
  return (
    <svg {...box(size, style)}>
      <path fill={color} fillRule="evenodd" stroke={color} strokeWidth={1.2} strokeLinejoin="round" d={`${teeth.join("")}ZM12 8.5a3.500 3.500 0 1 0 0 7 3.500 3.500 0 0 0 0-7Z`} />
    </svg>
  );
}

/** `pause.circle.fill` */
export function PauseCircleFill({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <path
        fill={color}
        fillRule="evenodd"
        d="M12 1.500a10.500 10.500 0 1 1 0 21 10.500 10.500 0 0 1 0-21ZM9.700 7.500a1.150 1.150 0 0 0-1.150 1.150v6.700a1.150 1.150 0 0 0 2.300 0v-6.700A1.150 1.150 0 0 0 9.700 7.500Zm4.600 0a1.150 1.150 0 0 0-1.150 1.150v6.700a1.150 1.150 0 0 0 2.300 0v-6.700a1.150 1.150 0 0 0-1.150-1.150Z"
      />
    </svg>
  );
}

/** `backward.fill` / `forward.fill` */
export function SkipFill({ size, color = "currentColor", style, back = false }: GlyphProps & { back?: boolean }) {
  return (
    <svg {...box(size, { transform: back ? "scaleX(-1)" : undefined, ...style })}>
      <path fill={color} d="M2 7.300c0-.9 1-1.400 1.700-.9l7.300 4.700V7.300c0-.9 1-1.400 1.700-.9l8.300 5.300c.700.400.700 1.400 0 1.800l-8.300 5.300c-.700.500-1.700 0-1.700-.9v-3.800l-7.300 4.700c-.700.500-1.700 0-1.700-.9Z" />
    </svg>
  );
}

/** `ellipsis` */
export function EllipsisGlyph({ size, color = "currentColor", style }: GlyphProps) {
  return (
    <svg {...box(size, style)}>
      <circle cx={5} cy={12} r={2.100} fill={color} />
      <circle cx={12} cy={12} r={2.100} fill={color} />
      <circle cx={19} cy={12} r={2.100} fill={color} />
    </svg>
  );
}

/** Layout height (canvas points) of an element, re-measured when it resizes. */
export function useLayoutHeight(ref: RefObject<HTMLElement | null>, fallback: number): number {
  const [h, setH] = useState(fallback);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => el.offsetHeight > 0 && setH(el.offsetHeight);
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [ref]);
  return h;
}

/** Re-renders every animation frame while `running` (for bodies that read refs / `performance.now()`). */
export function useFrame(running: boolean, fps?: number) {
  const [, setTick] = useState(0);
  const last = useRef(0);
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    const step = (now: number) => {
      if (!fps || now - last.current >= 1000 / fps - 1) {
        last.current = now;
        setTick((n) => (n + 1) % 1_000_000);
      }
      raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [running, fps]);
}
