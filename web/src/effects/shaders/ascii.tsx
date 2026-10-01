/** shader.ascii · ASCII 字符画 (Shaders+Ascii.swift, mlAscii) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { ChevronsLeftRight } from "lucide-react";
import { fonts, hex, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { nowSec, rgba, useLayer, useSpeedClock } from "./_shared";
import { CenterStack } from "./_stage";
import { Shader } from "./_gl";
import { FRAG } from "./_metal";
import { CARD_H, CARD_W, ShaderCard, clampTo, color4, useShaderTouch } from "./_card";
import { linear } from "./_scenes";

/** `AsciiLiveScene`: a sun whose highlight orbits, a moon crossing it and rolling dunes of light. */
function drawLive(g: CanvasRenderingContext2D, time: number) {
  const W = CARD_W;
  const H = CARD_H;
  g.fillStyle = linear(g, [0x0b1030, 0x3a1c71, 0xd76d77, 0xffaf7b], 0, 0, 0, H);
  g.fillRect(0, 0, W, H);
  const sx = W / 2;
  const sy = H / 2 - 34;
  const lx = sx - 75 + 150 * (0.5 + 0.32 * Math.cos(time * 0.9));
  const ly = sy - 75 + 150 * (0.5 + 0.32 * Math.sin(time * 0.9));
  const sun = g.createRadialGradient(lx, ly, 2, lx, ly, 96);
  ["#ffffff", rgba(0xffd27a), rgba(0xff6f61), rgba(0x5b2a86)].forEach((c, i) => sun.addColorStop(i / 3, c));
  g.fillStyle = sun;
  g.beginPath();
  g.arc(sx, sy, 75, 0, Math.PI * 2);
  g.fill();
  g.fillStyle = "#fff";
  g.beginPath();
  g.arc(sx + 104 * Math.cos(time * 0.7), sy + 46 * Math.sin(time * 0.7), 13, 0, Math.PI * 2);
  g.fill();
  for (let band = 0; band < 4; band++) {
    const base = H * (0.66 + 0.09 * band);
    const y = (x: number) => base + Math.sin(x / 34 + time * (0.9 + 0.35 * band) + band * 1.7) * 9;
    g.beginPath();
    g.moveTo(0, H);
    for (let x = 0; x <= W + 6; x += 6) g.lineTo(x, y(x));
    g.lineTo(W, H);
    g.closePath();
    g.fillStyle = rgba([0x2a1b5e, 0x5b2a86, 0x1b1444, 0x0b0a24][band]);
    g.fill();
    // A bright crest so the dunes read in luminance, not only in hue.
    g.beginPath();
    for (let x = 0; x <= W + 6; x += 6) (x === 0 ? g.moveTo(x, y(x)) : g.lineTo(x, y(x)));
    g.strokeStyle = rgba(0xffc9a0, 0.75 - 0.15 * band);
    g.lineWidth = 2.5;
    g.lineJoin = "miter";
    g.stroke();
  }
}

const tag: React.CSSProperties = {
  fontFamily: fonts.mono,
  fontSize: 10,
  lineHeight: "12px",
  fontWeight: 800,
  letterSpacing: 1.5,
  color: "#fff",
  padding: "4px 8px",
  borderRadius: 999,
  background: "rgb(0 0 0 / 0.45)",
};

export default function Ascii({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const layer = useLayer(CARD_W, CARD_H);
  const clock = useSpeedClock();
  const divider = useMotionValue(96);
  const toRight = useRef(true);
  const handle = useRef<HTMLDivElement>(null);
  const raw = useRef<HTMLSpanElement>(null);
  const txt = useRef<HTMLSpanElement>(null);

  const limit = (x: number) => clampTo(x, 8, CARD_W - 8);
  const slide = (x: number) => animate(divider, limit(x), spring(0.55, 0.8));
  useAutoplay(
    ctx.isPreview,
    () => {
      slide(toRight.current ? 222 : 44);
      toRight.current = !toRight.current;
    },
    { every: 2.2, delay: 0.4 },
  );
  const touch = useShaderTouch({
    onBegan: () => haptics.selection(),
    onMoved: (p) => animate(divider, limit(p.x), spring(0.18, 0.86)),
    onTap: (p) => {
      haptics.selection();
      slide(p.x);
    },
  });

  return (
    <CenterStack ctx={ctx} en="Drag the divider, or tap to send it" zh="拖动分割线，或点击让它滑过去">
      <ShaderCard glow={hex(0x5b2a86, 0.4)} {...touch}>
        <Shader
          width={CARD_W}
          height={CARD_H}
          fragment={FRAG.Ascii}
          source={layer.canvas}
          fps={ctx.isPreview ? 30 : undefined}
          uniforms={() => {
            const time = clock.advance(nowSec(), 1);
            layer.paint((g) => drawLive(g, time));
            const d = divider.get();
            // The grab handle rides the animated divider, so it never lags behind the shader.
            if (handle.current) handle.current.style.transform = `translate(${d - 13}px, ${CARD_H / 2 - 22}px)`;
            if (raw.current) raw.current.style.opacity = d > 62 ? "1" : "0";
            if (txt.current) txt.current.style.opacity = d < CARD_W - 62 ? "1" : "0";
            return {
              p_cell: ctx.n("cell"),
              p_divider: d,
              p_band: ctx.n("band"),
              p_time: time,
              p_mode: ctx.i("mode"),
              p_tint: color4(0x4dff88),
              p_contrast: ctx.n("contrast"),
            };
          }}
        />
        <div
          ref={handle}
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            width: 26,
            height: 44,
            borderRadius: 13,
            background: "#fff",
            color: "#14162B",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            boxShadow: "0 3px 8px rgb(0 0 0 / 0.35)",
            pointerEvents: "none",
          }}
        >
          <ChevronsLeftRight size={15} strokeWidth={3.2} />
        </div>
        <div style={{ position: "absolute", left: 14, right: 14, top: 14, display: "flex", justifyContent: "space-between", pointerEvents: "none" }}>
          <span ref={raw} style={tag}>RAW</span>
          <span ref={txt} style={tag}>TXT</span>
        </div>
      </ShaderCard>
    </CenterStack>
  );
}
