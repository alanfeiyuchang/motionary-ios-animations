/** text.strike-rewrite · 划掉重写 (Text+StrikeRewrite.swift) */
import { useState } from "react";
import { DemoHint, Palette, fonts, useAutoplay, useClock, useHaptics, type DemoProps } from "../../kit";
import { useSize } from "./_text-kit";
import { curve, now, squeezed } from "./_fx";

const COPIES = {
  zh: [
    { first: "这个版本", prefix: "", wrong: "下个月", suffix: "上线。", right: "本周五" },
    { first: "动效应该是", prefix: "一种", wrong: "装饰", suffix: "。", right: "反馈" },
    { first: "把这个标志", prefix: "再", wrong: "放大一点", suffix: "。", right: "留点呼吸" },
  ],
  en: [
    { first: "This version", prefix: "ships ", wrong: "next month", suffix: ".", right: "on Friday" },
    { first: "Motion should", prefix: "be ", wrong: "decoration", suffix: ".", right: "feedback" },
    { first: "Make the logo", prefix: "", wrong: "bigger", suffix: ".", right: "breathe" },
  ],
};

const easeOutBack = (x: number) => {
  const u = Math.min(Math.max(x, 0), 1) - 1;
  const c = 2.2;
  return 1 + (c + 1) * u * u * u + c * u * u;
};

/** A quick hand-drawn line: slightly wavy, slightly rising, overshooting the bounds on both sides. */
function strikePath(w: number, h: number, wobble: number) {
  const points: string[] = [];
  for (let index = 0; index <= 28; index++) {
    const u = index / 28;
    const x = -5 + (w + 10) * u;
    const y = h / 2 + 2 + Math.sin(u * Math.PI * 3.3 + 0.6) * wobble - (u - 0.5) * 4;
    points.push(`${x.toFixed(2)} ${y.toFixed(2)}`);
  }
  return "M" + points.join("L");
}

export default function StrikeRewrite({ ctx }: DemoProps) {
  const haptics = useHaptics();
  useClock(true, ctx.isPreview ? 30 : undefined);
  const [start, setStart] = useState<number | null>(null);
  const [copy, setCopy] = useState(0);
  const [played, setPlayed] = useState(false);
  const zh = ctx.lang === "zh";
  const copies = COPIES[ctx.lang];
  const text = copies[copy % copies.length];
  const ink = [Palette.red, Palette.blue, ctx.scheme === "dark" ? "#34C77B" : "#1E9E5A"][ctx.i("ink")] ?? Palette.red;

  const play = () => {
    if (played) setCopy((c) => c + 1);
    setPlayed(true);
    setStart(now());
  };
  useAutoplay(ctx.isPreview, play, { every: 3.6, delay: 0.7 });

  const time = start === null ? -1 : now() - start;
  const swapped = copy > 0;
  const strikeStart = swapped ? 0.55 : 0.1;
  const strikeDuration = Math.max(ctx.n("strike"), 0.05);
  const writeStart = strikeStart + strikeDuration + 0.14;
  const writeDuration = Math.max(ctx.n("write"), 0.05);

  const arrive = swapped ? curve.easeOutCubic(time / 0.3) : 1;
  const strike = curve.easeOutCubic((time - strikeStart) / strikeDuration);
  const dim = curve.clamp01((time - strikeStart - strikeDuration * 0.7) / 0.2);
  const gap = easeOutBack((time - strikeStart - strikeDuration * 0.6) / 0.4);
  const write = curve.easeInOut((time - writeStart) / writeDuration);
  const lift = curve.clamp01((time - writeStart - writeDuration) / 0.15);
  const underline = curve.easeOutCubic((time - writeStart - writeDuration - 0.05) / 0.2);

  const size = zh ? 42 : 36;
  const [wrongRef, wrong] = useSize<HTMLSpanElement>([text.wrong, size]);
  const [rightRef, right] = useSize<HTMLSpanElement>([text.right, ctx.lang]);
  const line = { fontSize: size, lineHeight: `${Math.round(size * 1.193)}px`, fontWeight: 700, whiteSpace: "pre", color: Palette.label } as const;
  const edge = write * 1.12;
  const maskStops = `#000 0%, #000 ${(Math.min(Math.max(edge - 0.12, 0), 1) * 100).toFixed(2)}%, transparent ${(Math.min(Math.max(edge, 0.0001), 1) * 100).toFixed(2)}%`;

  return (
    <div
      onClick={() => {
        haptics.tap("light");
        play();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
    >
      <div key={copy} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2 + 32 * gap, paddingBottom: 10, opacity: arrive, transform: `translateY(${10 * (1 - arrive)}px)` }}>
        <span style={line}>{squeezed(text.first)}</span>
        <div style={{ display: "flex", alignItems: "baseline" }}>
          <span style={line}>{text.prefix}</span>
          <span ref={wrongRef} style={{ ...line, position: "relative", display: "inline-block" }}>
            <span style={{ opacity: 1 - 0.6 * dim }}>{text.wrong}</span>
            {wrong.w > 0 && (
              <svg width={wrong.w} height={wrong.h} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", pointerEvents: "none" }}>
                <path
                  d={strikePath(wrong.w, wrong.h, ctx.n("wobble"))}
                  fill="none"
                  stroke={ink}
                  strokeWidth={3.5}
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  pathLength={1}
                  strokeDasharray={`${strike} 2`}
                  opacity={strike > 0.0005 ? 1 : 0}
                />
              </svg>
            )}
            {/* The correction sits above the struck word, overlapping its top by 5 pt. */}
            <span style={{ position: "absolute", left: "50%", bottom: "100%", width: 0, display: "flex", justifyContent: "center", marginBottom: -5, pointerEvents: "none" }}>
              <span
                ref={rightRef}
                style={{
                  position: "relative",
                  flex: "none",
                  padding: "0 6px",
                  transform: "rotate(-3deg)",
                  fontFamily: zh ? fonts.rounded : `"Noteworthy", "Bradley Hand", "Segoe Print", "Comic Sans MS", cursive`,
                  fontSize: 31,
                  lineHeight: zh ? "37px" : "50px",
                  fontWeight: zh ? 800 : 700,
                  color: ink,
                  whiteSpace: "pre",
                }}
              >
                <span style={{ display: "block", maskImage: `linear-gradient(90deg, ${maskStops})`, WebkitMaskImage: `linear-gradient(90deg, ${maskStops})`, margin: "0 -6px", padding: "0 6px" }}>{text.right}</span>
                {right.w > 0 && (
                  <>
                    <span
                      style={{
                        position: "absolute",
                        left: right.w * write - 4,
                        top: right.h * 0.55 + 6 * Math.sin(write * 26) - 4,
                        width: 8,
                        height: 8,
                        borderRadius: "50%",
                        background: ink,
                        transform: `scale(${write > 0.001 ? 1 - lift : 0})`,
                      }}
                    />
                    <svg width={right.w - 16} height={6} style={{ position: "absolute", left: 8, bottom: -3, overflow: "visible" }}>
                      <path d={strikePath(right.w - 16, 6, 1.2)} fill="none" stroke={ink} strokeWidth={2.5} strokeLinecap="round" pathLength={1} strokeDasharray={`${underline} 2`} opacity={underline > 0.0005 ? 1 : 0} />
                    </svg>
                  </>
                )}
              </span>
            </span>
          </span>
          <span style={line}>{squeezed(text.suffix)}</span>
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 14 }}>
        <DemoHint ctx={ctx} en="Tap to correct the next sentence" zh="点击修改下一句" />
      </div>
    </div>
  );
}
