/** backgrounds.silk-folds · 丝绸褶皱 (Backgrounds+SilkFolds.swift) */
import { useRef } from "react";
import { useHaptics, type DemoProps } from "../../kit";
import { BackgroundClock, Layer, Stage, clampv, prep, sizeOf, useBackgroundsTouch, useFrameLoop, useModel, useRatio } from "./_support";
import { BackgroundPointer, ChipHint, css, rgbHex, rgbScaled, smoothstep, type RGB } from "./_extra";

interface SilkTone {
  shadow: RGB;
  mid: RGB;
  light: RGB;
  highlight: RGB;
}
const TONES: SilkTone[] = [
  { shadow: rgbHex(0x7a5a3c), mid: rgbHex(0xd9be98), light: rgbHex(0xf4e4c8), highlight: rgbHex(0xfffbf0) },
  { shadow: rgbHex(0x6e1f3c), mid: rgbHex(0xd4577e), light: rgbHex(0xf5a3b8), highlight: rgbHex(0xffedf2) },
  { shadow: rgbHex(0x05382c), mid: rgbHex(0x14846a), light: rgbHex(0x4fc9a4), highlight: rgbHex(0xe4fff4) },
  { shadow: rgbHex(0x070b2a), mid: rgbHex(0x1e2e7a), light: rgbHex(0x4c68d0), highlight: rgbHex(0xdce6ff) },
];
const ANGLE = (-24 * Math.PI) / 180;
const SAMPLES = 96;
const STEP = 2.5;

export default function SilkFolds({ ctx }: DemoProps) {
  const root = useRef<HTMLDivElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const model = useModel(() => ({ clock: new BackgroundClock(), pointer: new BackgroundPointer(), tex: null as HTMLCanvasElement | null }));
  const ratio = useRatio(root);
  const haptics = useHaptics();
  const tone = TONES[clampv(ctx.i("tone"), 0, TONES.length - 1)];

  useFrameLoop(root, ctx.isPreview, (now) => {
    const { w, h } = sizeOf(root.current);
    const t = model.clock.advance(now, ctx.n("speed"));
    const idle = { x: w * (0.5 + 0.3 * Math.sin(t * 0.21)), y: h * (0.5 + 0.26 * Math.sin(t * 0.33 + 1.2)) };
    const finger = model.pointer.step(now, idle, 40, 0.75);
    const pull = 2.6 * model.pointer.strength(0.45);
    const folds = Math.max(ctx.n("folds"), 0.1);
    const sheen = ctx.n("sheen");
    const g = prep(canvas.current, w, h, ratio());
    if (!g) return;

    const cx = w / 2;
    const cy = h / 2;
    const reach = Math.hypot(w, h) / 2 + 6;
    const dx = finger.x - cx;
    const dy = finger.y - cy;
    const fu = dx * Math.cos(-ANGLE) - dy * Math.sin(-ANGLE);
    const fv = dx * Math.sin(-ANGLE) + dy * Math.cos(-ANGLE);

    // One texel per gradient stop and per 2.5 pt row; the GPU's bilinear filter does the gradients.
    const rows = Math.ceil((reach * 2) / STEP);
    const cols = SAMPLES + 1;
    if (!model.tex) model.tex = document.createElement("canvas");
    const tex = model.tex;
    if (tex.width !== cols || tex.height !== rows) {
      tex.width = cols;
      tex.height = rows;
    }
    const tg = tex.getContext("2d");
    if (!tg) return;
    const image = tg.createImageData(cols, rows);
    const data = image.data;
    const unit = 340;
    const { shadow, mid, light, highlight } = tone;
    let o = 0;
    for (let row = 0; row < rows; row++) {
      const v = -reach + row * STEP;
      const vn = v / unit;
      const w1 = 1.1 * Math.sin(vn * 1.9 + t * 0.21) + 0.6 * Math.sin(vn * 4.3 - t * 0.16 + 1.3) + t * 0.1;
      const w2 = 0.9 * Math.sin(vn * 2.6 + t * 0.2);
      const w3 = 3.0 * vn - 1.4 * Math.sin(vn * 2.7 + t * 0.13 + 2.0) - t * 0.06;
      const dv = (v - fv) / 100;
      for (let s = 0; s <= SAMPLES; s++) {
        const f = s / SAMPLES;
        const u = (f * 2 - 1) * reach;
        const un = (u / unit) * folds;
        const du = (u - fu) / 100;
        const gather = pull * Math.exp(-(du * du + dv * dv));
        const main = 17.0 * un + w1 + gather;
        const slope = Math.cos(main) + 0.35 * Math.cos(2 * main + w2) + 0.4 * Math.cos(31.0 * un + w3 - gather * 0.6);
        const depth = 0.66 + 0.34 * Math.sin(un * 2.3 + vn * 1.7 + t * 0.1);
        const n = Math.min(Math.max((slope / 1.3) * depth, -1), 1);
        const diffuse = Math.pow(0.5 + 0.5 * n, 1.2);
        let a: RGB;
        let b: RGB;
        let m: number;
        if (diffuse < 0.5) {
          a = shadow;
          b = mid;
          m = smoothstep(0, 0.5, diffuse);
        } else {
          a = mid;
          b = light;
          m = smoothstep(0.5, 1, diffuse);
        }
        const spec = Math.pow(Math.max(0, 1 - Math.abs(n - 0.62) / 0.24), 2);
        const back = Math.pow(Math.max(0, 1 - Math.abs(n + 0.8) / 0.2), 2) * 0.22;
        const hl = Math.min((spec + back) * sheen, 1) * 0.95;
        for (let c = 0; c < 3; c++) {
          const base = a[c] + (b[c] - a[c]) * m;
          data[o++] = (base + (highlight[c] - base) * hl) * 255;
        }
        data[o++] = 255;
      }
    }
    tg.putImageData(image, 0, 0);

    g.save();
    g.translate(cx, cy);
    g.rotate(ANGLE);
    g.imageSmoothingEnabled = true;
    g.imageSmoothingQuality = "high";
    const texel = (reach * 2) / SAMPLES;
    g.drawImage(tex, -reach - texel / 2, -reach, texel * cols, rows * STEP);
    g.restore();

    const edge = g.createRadialGradient(cx, cy, 0, cx, cy, reach * 1.08);
    edge.addColorStop(0.5, css(rgbScaled(shadow, 0.5), 0));
    edge.addColorStop(1, css(rgbScaled(shadow, 0.5), 0.42));
    g.fillStyle = edge;
    g.fillRect(0, 0, w, h);
  });

  const touch = useBackgroundsTouch(
    (p) => {
      if (!model.pointer.userTouched) haptics.tap("soft");
      model.pointer.userTouched = true;
      model.pointer.touch = p;
    },
    () => (model.pointer.touch = null),
  );

  return (
    <Stage rootRef={root} background={css(tone.mid)} handlers={touch}>
      <Layer canvasRef={canvas} />
      <ChipHint ctx={ctx} en="Swipe sideways to gather the silk" zh="横向滑动把丝绸聚拢" />
    </Stage>
  );
}
