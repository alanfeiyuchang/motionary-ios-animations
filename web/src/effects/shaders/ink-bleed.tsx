/** shader.ink-bleed · 墨迹晕染 (Shaders+InkBleed.swift, mlInkBleed) */
import { useRef } from "react";
import { anim, fonts, useAutoplay, useHaptics, type DemoProps, type Point } from "../../kit";
import { LayerView, randIn, rgba } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, color4, rand, tapPoint, useRun, useScene } from "./_card";
import { blurred, box, softDisc, text } from "./_scenes";

interface Sheet {
  paper: number;
  ink: number;
  pigment: number;
  glyph: string;
  caption: string;
  offset: Point;
}

const SHEETS: Sheet[] = [
  { paper: 0xf2eadb, ink: 0x1a1a20, pigment: 0x6b5a3e, glyph: "墨", caption: "INK · 01", offset: { x: -8, y: -12 } },
  { paper: 0x1d3461, ink: 0xf2eadb, pigment: 0x0a1530, glyph: "水", caption: "WATER · 02", offset: { x: 10, y: 6 } },
  { paper: 0xb5362a, ink: 0xfbefd9, pigment: 0x5a100b, glyph: "山", caption: "MOUNTAIN · 03", offset: { x: -4, y: 10 } },
  { paper: 0x15151a, ink: 0xe5b769, pigment: 0x000000, glyph: "風", caption: "WIND · 04", offset: { x: 8, y: -8 } },
];
const sheetAt = (index: number) => SHEETS[((index % 4) + 4) % 4];

/** `InkPaperScene`: a sheet of dyed paper with one brushed character (the serif design has no CJK glyphs, so the system sans draws it), a wash behind it, fibres and a seal. */
function drawSheet(g: CanvasRenderingContext2D, k: number, sheet: Sheet) {
  const W = CARD_W;
  const H = CARD_H;
  box(g, 0, 0, W, H, rgba(sheet.paper));
  blurred(g, k, 18, () => {
    softDisc(g, W * 0.5 + sheet.offset.x, H * 0.46 + sheet.offset.y, 86, rgba(sheet.ink, 0.14));
  });
  g.strokeStyle = rgba(sheet.ink, 0.07);
  g.lineWidth = 0.7;
  g.beginPath();
  for (let i = 0; i < 120; i++) {
    const x = rand(i, 51) * W;
    const y = rand(i, 52) * H;
    const angle = rand(i, 53) * Math.PI;
    const length = 5 + rand(i, 54) * 13;
    g.moveTo(x, y);
    g.lineTo(x + Math.cos(angle) * length, y + Math.sin(angle) * length);
  }
  g.stroke();
  text(g, sheet.glyph, W / 2 + sheet.offset.x, H / 2 + sheet.offset.y + 52, `900 158px ${fonts.text}`, rgba(sheet.ink), "center", "alphabetic");
  text(g, sheet.caption, 20, H - 20 - 6, `700 10px ${fonts.mono}`, rgba(sheet.ink, 0.75), "left", "middle", 2);
  box(g, W - 50, H - 50, 30, 30, rgba(0xc8372d), 6);
  g.strokeStyle = rgba(0xfbefd9, 0.5);
  g.lineWidth = 1;
  g.beginPath();
  g.roundRect(W - 49.5, H - 49.5, 29, 29, 5.5);
  g.stroke();
  text(g, "印", W - 35, H - 35 + 6, `700 17px ${fonts.text}`, rgba(0xfbefd9), "center", "alphabetic");
}

export default function InkBleed({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const top = useScene();
  const bottom = useScene();
  const current = useRef(0);
  const origin = useRef<Point>({ x: 150, y: 130 });
  const seed = useRef(2.3);
  const { progress, busy, run } = useRun();

  const bleed = (p: Point) => {
    if (busy.current) return;
    origin.current = p;
    seed.current = randIn(0, 30);
    haptics.tap("soft");
    // Fast at first, then slowing, like diffusion.
    run(anim.curve(0.25, 0.5, 0.45, 1, ctx.n("duration")), () => (current.current += 1));
  };
  useAutoplay(ctx.isPreview, () => bleed({ x: randIn(60, 200), y: randIn(70, 230) }), { every: ctx.n("duration") + 0.9, delay: 0.4 });

  return (
    <CenterStack ctx={ctx} en="Tap to drop ink" zh="点击落墨">
      <ShaderCard onClick={tapPoint(bleed)}>
        <LayerView layer={bottom.layer} width={CARD_W} height={CARD_H} style={{ position: "absolute", inset: 0 }} />
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.InkBleed}
          source={top.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          style={{ position: "absolute", inset: 0 }}
          uniforms={() => {
            const c = current.current;
            bottom.ensure(c, (g, k) => drawSheet(g, k, sheetAt(c)));
            top.ensure(c + 1, (g, k) => drawSheet(g, k, sheetAt(c + 1)));
            const p = progress.get();
            return {
              // The shader hides the incoming scene; at rest it is simply not drawn.
              p_hidden: p > 0.0001 ? 0 : 1,
              p_origin: [origin.current.x, origin.current.y],
              p_progress: p,
              p_rough: ctx.n("rough"),
              p_fibre: ctx.n("fibre"),
              p_edge: ctx.n("edge"),
              p_ink: color4(sheetAt(c + 1).pigment),
              p_seed: seed.current,
            };
          }}
        />
      </ShaderCard>
    </CenterStack>
  );
}
