/** shader.zoom-blur · 变焦模糊转场 (Shaders+ZoomBlur.swift, mlZoomBlur) */
import { useRef } from "react";
import { anim, clamp, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { randIn } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, tapPoint, useRun, useScene } from "./_card";
import { drawPoster } from "./_scenes";

export default function ZoomBlur({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const incoming = useScene();
  const outgoing = useScene();
  /** Starts two posters in, so this stage never opens on the same poster as Wax Melt. */
  const current = useRef(2);
  const center = useRef<Point>({ x: 130, y: 150 });
  const fading = useRef<HTMLDivElement>(null);
  const { progress, busy, run } = useRun();

  const cut = (p: Point) => {
    if (busy.current) return;
    center.current = p;
    haptics.tap("rigid");
    // Linear: each scene applies its own easing to this progress.
    run(anim.linear(ctx.n("duration")), () => {
      current.current += 1;
      haptics.tap("soft");
    });
  };
  useAutoplay(ctx.isPreview, () => cut({ x: randIn(70, 190), y: randIn(90, 210) }), { every: ctx.n("duration") + 1.0, delay: 0.4 });

  /** The per-scene curves, evaluated every frame from one progress value. */
  const curves = () => {
    const p = clamp(progress.get(), 0, 1);
    // Outgoing: accelerates over 0…60%. Incoming: decelerates over 40…100%.
    const outT = Math.min(p / 0.6, 1);
    const rush = outT * outT;
    const inT = Math.max((p - 0.4) / 0.6, 0);
    const land = 1 - (1 - inT) * (1 - inT) * (1 - inT);
    const m = clamp((p - 0.4) / 0.2, 0, 1);
    const fade = m * m * (3 - 2 * m);
    const flash = Math.pow(Math.sin(Math.PI * p), 2) * 0.45;
    return { p, rush, land, fade, flash };
  };
  const common = (c: ReturnType<typeof curves>) => ({
    p_bypass: c.p > 0.0001 ? 0 : 1,
    p_center: [center.current.x, center.current.y] as [number, number],
    p_chroma: ctx.n("chroma"),
    p_exposure: c.flash,
  });

  return (
    <CenterStack ctx={ctx} en="Tap where the camera should fly" zh="点击镜头要冲向的位置">
      <ShaderCard onClick={tapPoint(cut)}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.ZoomBlur}
          source={incoming.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const i = current.current + 1;
            incoming.ensure(i, (g, k) => drawPoster(g, k, i));
            const c = curves();
            const strength = ctx.n("strength");
            return { ...common(c), p_amount: strength * (1 - c.land), p_zoom: 1 - 0.35 * strength * (1 - c.land) };
          }}
        />
        <div ref={fading} style={{ position: "absolute", inset: 0 }}>
          <Shader
            width={CARD_W}
            height={CARD_H}
            fragment={FRAG.ZoomBlur}
            source={outgoing.canvas}
            fps={ctx.isPreview ? 30 : undefined}
            uniforms={() => {
              const i = current.current;
              outgoing.ensure(i, (g, k) => drawPoster(g, k, i));
              const c = curves();
              if (fading.current) fading.current.style.opacity = String(1 - c.fade);
              const strength = ctx.n("strength");
              return { ...common(c), p_amount: strength * c.rush, p_zoom: 1 + 0.9 * strength * c.rush };
            }}
          />
        </div>
      </ShaderCard>
    </CenterStack>
  );
}
