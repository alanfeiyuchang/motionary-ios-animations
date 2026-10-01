/** morph.shutter-iris · 快门光圈 (Morph+ShutterIris.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Leaf, MoonStar } from "lucide-react";
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, anim, black, delayed, fonts, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Column, blurReplace, diag, useMV, vert } from "./_shared";
import { Mountain2, SunHorizon, type SymbolComponent } from "./_symbols";

const scenes: { Icon: SymbolComponent; colors: string[]; name: [string, string] }[] = [
  { Icon: SunHorizon, colors: ["#FFB45A", "#E5407A", "#4B2A78"], name: ["Dusk", "黄昏"] },
  { Icon: Mountain2, colors: ["#8FE3FF", "#3A8BE8", "#1B2F6B"], name: ["Summit", "山巅"] },
  { Icon: (p) => <Leaf {...p} fill="currentColor" strokeWidth={1.2} />, colors: ["#C8F27A", "#2FB37A", "#0E4A46"], name: ["Canopy", "林间"] },
  { Icon: (p) => <MoonStar {...p} fill="currentColor" strokeWidth={1.6} />, colors: ["#9A8BFF", "#4A3AA8", "#130F3A"], name: ["Night", "夜空"] },
];
const LENS = 228;

/** f-number for an aperture value: wide open reads ƒ/1.4, nearly closed ƒ/22. */
function stop(aperture: number) {
  const number = Math.min(1.4 / Math.max(aperture, 0.064), 22);
  return number >= 10 ? number.toFixed(0) : number.toFixed(1);
}

export default function ShutterIris({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const rest = ctx.n("rest");
  const apertureMV = useMotionValue(rest);
  const zoomMV = useMotionValue(1);
  const aperture = useMV(apertureMV);
  const zoom = useMV(zoomMV);
  const [scene, setScene] = useState(0);
  const [shots, setShots] = useState(41);
  const busy = useRef(false);
  const token = useRef(0);

  /** Close, swap the picture in the dark, spring open. */
  const fire = (buzz = true) => {
    if (busy.current) return;
    busy.current = true;
    token.current += 1;
    const current = token.current;
    haptics.tap("light");
    const close = anim.easeIn(ctx.n("close"));
    animate(zoomMV, 1.12, close);
    void animate(apertureMV, 0, close).then(() => {
      if (current !== token.current) return;
      if (buzz) haptics.tap("rigid");
      setScene((s) => s + 1);
      setShots((s) => s + 1);
      animate(apertureMV, ctx.n("rest"), delayed(spring(0.5, 0.7), 0.09));
      animate(zoomMV, 1, delayed(anim.easeOut(0.9), 0.09));
      busy.current = false;
    });
  };
  useAutoplay(ctx.isPreview, () => fire(false), { every: 1.9 });
  useEffect(() => {
    if (!busy.current && Math.abs(apertureMV.get() - rest) > 1e-4) animate(apertureMV, rest, spring(0.4, 0.8));
  }, [rest, apertureMV]);

  const item = scenes[scene % scenes.length];
  const lens = { position: "absolute", left: 18, top: 18, width: LENS, height: LENS, borderRadius: "50%", overflow: "hidden" } as const;

  return (
    <Column gap={14}>
      <div onClick={() => fire()} style={{ position: "relative", width: 264, height: 264, flexShrink: 0, borderRadius: "50%", cursor: "pointer" }}>
        {/* Barrel */}
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: diag("#3A3D45", "#121317"), boxShadow: `0 10px 18px ${black(0.35)}` }} />
        <div
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: "50%",
            padding: 1.5,
            background: diag(white(0.45), white(0.03)),
            WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
            WebkitMaskComposite: "xor",
            maskComposite: "exclude",
          }}
        />
        <div style={{ position: "absolute", inset: 15, borderRadius: "50%", boxShadow: `inset 0 0 0 2px ${black(0.6)}` }} />
        {Array.from({ length: 48 }, (_, tick) => {
          const major = tick % 4 === 0;
          const h = major ? 6 : 3.5;
          return (
            <div
              key={tick}
              style={{
                position: "absolute",
                left: 132 - 0.6,
                top: 132 - h / 2,
                width: 1.2,
                height: h,
                borderRadius: 0.6,
                background: white(major ? 0.5 : 0.18),
                transform: `rotate(${tick * 7.5}deg) translateY(-123px)`,
              }}
            />
          );
        })}
        {/* Picture */}
        <div style={lens}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              transform: `scale(${zoom})`,
              background: `radial-gradient(120px circle at 50% 42%, ${white(0.4)}, transparent), ${vert(...item.colors)}`,
              display: "grid",
              placeItems: "center",
              color: white(0.95),
            }}
          >
            <item.Icon size={104} style={{ filter: `drop-shadow(0 6px 12px ${black(0.25)})` }} />
          </div>
        </div>
        <div style={lens}>
          <Blades aperture={aperture} blades={ctx.i("blades")} twist={ctx.n("twist")} rest={rest} />
        </div>
        {/* Front element: a reflection arc and an inner vignette, above the blades. */}
        <div style={{ ...lens, pointerEvents: "none" }}>
          <div style={{ position: "absolute", inset: 0, background: `radial-gradient(circle closest-side, transparent, transparent 50%, ${black(0.35)})` }} />
          <div
            style={{
              position: "absolute",
              left: LENS / 2 - 75 - 34,
              top: LENS / 2 - 37 - 58,
              width: 150,
              height: 74,
              borderRadius: "50%",
              background: vert(white(0.28), white(0)),
              transform: "rotate(-28deg)",
              filter: "blur(4px)",
            }}
          />
          <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 3px ${black(0.7)}` }} />
        </div>
      </div>
      <div style={{ width: 264, display: "flex", alignItems: "center", gap: 14 }}>
        <span style={{ width: 58, fontSize: 15, fontWeight: 600, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums" }}>{`ƒ/${stop(aperture)}`}</span>
        <div style={{ flex: 1, display: "grid", placeItems: "center" }}>
          <AnimatePresence initial={false}>
            <motion.span key={scene} {...blurReplace()} transition={spring(0.4, 0.8)} style={{ gridArea: "1 / 1", fontSize: 15, fontWeight: 600, whiteSpace: "nowrap" }}>
              {item.name[ctx.lang === "zh" ? 1 : 0]}
            </motion.span>
          </AnimatePresence>
        </div>
        <span style={{ fontSize: 13, fontWeight: 500, fontFamily: fonts.mono, color: Palette.secondaryLabel, display: "inline-flex" }}>
          IMG_00
          <NumericText value={shots} />
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap the lens" zh="点击镜头" />
    </Column>
  );
}

/**
 * The iris at one aperture value. `aperture` is the distance from the centre to each blade's edge as a fraction
 * of the lens radius, so 1 clears the lens entirely for any blade count.
 */
function Blades({ aperture, blades, twist, rest }: { aperture: number; blades: number; twist: number; rest: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  const dpr = Math.max(typeof window === "undefined" ? 2 : window.devicePixelRatio, 2);
  useLayoutEffect(() => {
    const g = ref.current?.getContext("2d");
    if (!g) return;
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.clearRect(0, 0, LENS, LENS);
    const count = Math.min(Math.max(blades, 3), 12);
    const radius = LENS / 2;
    const c = radius;
    // Distance from the centre to each blade's edge. At aperture 1 the edges sit just outside the lens.
    const inset = Math.max(aperture, 0) * radius * 1.03;
    const closing = rest > 0 ? 1 - Math.min(Math.max(aperture / rest, 0), 1.3) : 0;
    const rotation = (closing * twist * Math.PI) / 180;
    const step = (2 * Math.PI) / count;
    const far = radius * 2.4;
    const rectIn = (angle: number, x: number, w: number) => {
      g.save();
      g.translate(c, c);
      g.rotate(angle);
      g.beginPath();
      g.rect(x, -far, w, far * 2);
      g.restore();
    };
    for (let index = 0; index < count; index++) {
      const angle = rotation + index * step;
      const next = angle + step;
      g.save();
      g.beginPath();
      g.arc(c, c, radius, 0, Math.PI * 2);
      g.clip();
      // Beyond this blade's edge…
      rectIn(angle, inset, far);
      g.clip();
      // …but only where the next blade is not lying on top of it.
      rectIn(next, inset - far, far);
      g.clip();
      const tx = -Math.sin(angle);
      const ty = Math.cos(angle);
      const ex = c + Math.cos(angle) * inset;
      const ey = c + Math.sin(angle) * inset;
      const metal = g.createLinearGradient(ex - tx * radius, ey - ty * radius, ex + tx * radius, ey + ty * radius);
      metal.addColorStop(0, "#17181C");
      metal.addColorStop(0.5, "#34373F");
      metal.addColorStop(1, "#1E2025");
      g.fillStyle = metal;
      g.fillRect(0, 0, LENS, LENS);
      // Shadow cast by the next blade, falling inward from its edge.
      const shade = g.createLinearGradient(c + Math.cos(next) * inset, c + Math.sin(next) * inset, c + Math.cos(next) * (inset - 18), c + Math.sin(next) * (inset - 18));
      shade.addColorStop(0, "rgba(0,0,0,0.55)");
      shade.addColorStop(1, "rgba(0,0,0,0)");
      rectIn(next, inset - 18, 18);
      g.fillStyle = shade;
      g.fill();
      // Bright leading edge.
      g.save();
      g.translate(c, c);
      g.rotate(angle);
      g.beginPath();
      g.moveTo(inset + 0.6, -far);
      g.lineTo(inset + 0.6, far);
      g.restore();
      g.strokeStyle = "rgba(255,255,255,0.3)";
      g.lineWidth = 1.2;
      g.stroke();
      g.restore();
    }
  });
  return <canvas ref={ref} width={LENS * dpr} height={LENS * dpr} style={{ position: "absolute", inset: 0, width: LENS, height: LENS }} />;
}
