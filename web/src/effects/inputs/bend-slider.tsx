/** inputs.bend-slider (Inputs+BendSlider.swift) */
import { animate, useMotionValue } from "motion/react";
import { useRef } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, black, clamp, fonts, mix, rubberBand, spring, textStyle, useAutoplay, useHaptics, usePan, type DemoProps } from "../../kit";
import { column, spacer, useMV, useQuiet, useTask } from "./_c-common";

const WIDTH = 264;
const HEIGHT = 150;
const SCRIPT: [number, number][] = [[0.86, 1], [0.28, -0.8], [0.62, 0.9]];

export default function BendSlider({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { wrap, quiet } = useQuiet();
  const valueMV = useMotionValue(0.62);
  const bendMV = useMotionValue(0);
  const pressMV = useMotionValue(0);
  const pressing = useRef(false);
  const touching = useRef(false);
  const startValue = useRef(0);
  const step = useRef(0);
  const playTask = useTask();

  const pressDown = () => {
    pressing.current = true;
    const t = spring(0.25, 0.6);
    animate(pressMV, 1, t);
    animate(bendMV, ctx.n("sag"), t);
  };
  /** Finger lift, cancelled touch and autoplay all end here. */
  const release = (silent: boolean) => {
    if (!pressing.current) return;
    if (!silent) haptics.tap("soft");
    pressing.current = false;
    animate(bendMV, 0, spring(ctx.n("response"), ctx.n("damping")));
    animate(pressMV, 0, spring(0.3, 0.7));
  };

  const pan = usePan({
    onStart: () => {
      touching.current = true;
    },
    onChange: ({ translation }) => {
      if (!pressing.current) {
        playTask.cancel();
        startValue.current = valueMV.get();
        haptics.tap("light");
        pressDown();
        return;
      }
      const pull = rubberBand(translation.y, ctx.n("limit"));
      const t = spring(0.12, 0.86);
      animate(valueMV, clamp(startValue.current + translation.x / WIDTH), t);
      animate(bendMV, ctx.n("sag") + pull, t);
    },
    onEnd: () => {
      touching.current = false;
      release(false);
    },
  });

  useAutoplay(
    ctx.isPreview,
    wrap(() => {
      if (touching.current) return;
      const silent = quiet();
      const target = SCRIPT[step.current % SCRIPT.length];
      step.current += 1;
      playTask.start(async (sleep) => {
        pressDown();
        if (!(await sleep(0.16))) return;
        animate(valueMV, target[0], anim.smoothD(0.5));
        animate(bendMV, ctx.n("sag") + rubberBand(target[1] * 150, ctx.n("limit")), anim.smoothD(0.5));
        if (!(await sleep(0.56))) return;
        release(silent);
      });
    }),
    { every: 1.7, delay: 0.5 },
  );

  const value = useMV(valueMV);
  const bend = useMV(bendMV);
  const press = useMV(pressMV);
  const p = clamp(press);
  const inset = 8;
  const mid = HEIGHT / 2;
  const left = { x: inset, y: mid };
  const right = { x: WIDTH - inset, y: mid };
  const thumb = { x: left.x + (right.x - left.x) * clamp(value), y: mid + bend };
  /** One half of the band: straight out of the peg, rounding into the thumb. */
  const segment = (peg: { x: number; y: number }) => {
    const dx = thumb.x - peg.x;
    const ease = Math.min(Math.abs(dx) * 0.5, 22) * (dx < 0 ? -1 : 1);
    return `M${peg.x} ${peg.y} C${peg.x + dx * 0.6} ${peg.y + (thumb.y - peg.y) * 0.6} ${thumb.x - ease} ${thumb.y} ${thumb.x} ${thumb.y}`;
  };
  const peg = (at: { x: number; y: number }) => (
    <div style={{ position: "absolute", left: at.x - 7, top: at.y - 7, width: 14, height: 14, borderRadius: "50%", background: Palette.elevated, boxShadow: `inset 0 0 0 1.5px ${Palette.labelAlpha(0.25)}` }} />
  );
  const shownValue = Math.round(value * 100);

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2, paddingBottom: 4 }}>
        <span style={{ fontFamily: fonts.rounded, fontSize: 46, fontWeight: 700, lineHeight: "55px", color: "#8A73FF" }}>
          <NumericText value={shownValue} />
        </span>
        <span style={{ ...textStyle.footnote, fontWeight: 600, color: Palette.secondaryLabel }}>{ctx.t("Tension", "张力")}</span>
      </div>
      <div {...pan} style={{ ...pan.style, position: "relative", width: WIDTH, height: HEIGHT, flexShrink: 0, cursor: "grab" }}>
        <svg width={WIDTH} height={HEIGHT} style={{ position: "absolute", inset: 0, overflow: "visible" }} fill="none">
          <defs>
            <linearGradient id="c-bend-fill" gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={WIDTH} y2={0}>
              <stop offset="0" stopColor={Palette.indigo} />
              <stop offset="1" stopColor={Palette.violet} />
            </linearGradient>
          </defs>
          <line x1={left.x} y1={mid} x2={right.x} y2={mid} stroke={Palette.labelAlpha(0.07)} strokeWidth={1.5} strokeLinecap="round" strokeDasharray="2 5" opacity={Math.min(Math.abs(bend) / 10, 1)} />
          <path d={segment(right)} stroke={Palette.labelAlpha(0.16)} strokeWidth={8} strokeLinecap="round" strokeLinejoin="round" />
          <path d={segment(left)} stroke="url(#c-bend-fill)" strokeWidth={8} strokeLinecap="round" strokeLinejoin="round" style={{ filter: `drop-shadow(0 3px 6px ${alpha(Palette.indigo, 0.35)})` }} />
        </svg>
        {peg(left)}
        {peg(right)}
        <div
          style={{
            position: "absolute",
            left: thumb.x - 15,
            top: thumb.y - 15,
            width: 30,
            height: 30,
            borderRadius: "50%",
            background: "#fff",
            display: "grid",
            placeItems: "center",
            boxShadow: `0 ${mix(3, 6, p)}px ${mix(7, 14, p)}px ${black(mix(0.2, 0.3, p))}`,
            transform: `scale(${mix(1, 1.14, press)})`,
          }}
        >
          <div style={{ width: 9, height: 9, borderRadius: "50%", background: Palette.violet }} />
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Drag the thumb, pull it up or down, let go" zh="拖动滑块，上下拉扯，再松手" style={{ paddingBottom: 14 }} />
    </div>
  );
}
