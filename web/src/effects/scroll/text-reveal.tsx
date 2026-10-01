/** scroll.text-reveal · 滚动点亮文字 (Scroll+TextReveal.swift) */
import { useLayoutEffect, useMemo, useRef, useState } from "react";
import { Palette, anim, clamp, useAutoplay, type DemoProps } from "../../kit";
import { useScroller } from "./_kit";

const PARAGRAPHS: [string, string][] = [
  [
    "Motion is not decoration. It is how an interface explains itself: where things came from, where they went, and what just changed.",
    "动效不是装饰。它是界面解释自己的方式：东西从哪里来，到哪里去，刚才又发生了什么变化。",
  ],
  [
    "When the finger drives the timeline, nothing has to be waited for. You read at your own pace and the page keeps up.",
    "当手指掌控时间轴，就没有什么需要等待。你按自己的节奏阅读，页面始终跟得上。",
  ],
  [
    "A spring remembers speed. An easing curve only remembers time. That is why one feels alive and the other merely correct.",
    "弹簧记得速度，缓动曲线只记得时间。所以前者显得鲜活，后者只是正确。",
  ],
  ["Give every pixel a reason to move, and a place to rest.", "让每个像素的移动都有理由，停下时都有归处。"],
  ["The best animation is the one you only notice when it is gone.", "最好的动画，是它消失之后你才察觉到的那一个。"],
];
const LINE = 34;
const CLOSERS = new Set(["，", "。", "：", "；", "、", "！", "？", "”", "）"]);

/** English splits on spaces; Chinese per character, with punctuation kept on the previous character. */
function tokens(text: string, zh: boolean): string[] {
  if (!zh) return text.split(" ");
  const result: string[] = [];
  for (const ch of text) {
    if (CLOSERS.has(ch) && result.length) result[result.length - 1] += ch;
    else result.push(ch);
  }
  return result;
}

export default function TextReveal({ ctx }: DemoProps) {
  const zh = ctx.lang === "zh";
  const down = useRef(false);
  const sc = useScroller({ axis: "y" });
  const width = sc.size.width || 340;
  const height = sc.size.height || (ctx.isPreview ? 340 : 400);
  const focusY = height * ctx.n("focus");
  const band = Math.max(ctx.n("band"), 1);
  const dim = ctx.n("dim");
  const tint = ctx.b("tint");
  const violetText = ctx.scheme === "dark" ? "#C4A0FF" : "#7A45D6";

  const paragraphs = useMemo(() => PARAGRAPHS.map((p) => tokens(zh ? p[1] : p[0], zh)), [zh]);

  // Each word's centre in the content (the web twin of `proxy.frame(in: .scrollView)` minus the offset).
  const words = useRef<(HTMLSpanElement | null)[]>([]);
  const [frames, setFrames] = useState<{ x: number; y: number }[]>([]);
  useLayoutEffect(() => {
    const content = sc.contentRef.current;
    if (!content) return;
    const measure = () => setFrames(words.current.map((w) => (w ? { x: w.offsetLeft + w.offsetWidth / 2, y: w.offsetTop + w.offsetHeight / 2 } : { x: 0, y: 0 })));
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(content);
    void document.fonts?.ready.then(measure);
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [zh]);

  useAutoplay(
    ctx.isPreview,
    () => {
      if (!ctx.isPreview) {
        // Detail intro: read the first few lines, then hand over to the finger.
        sc.scrollTo(170, anim.easeInOut(2.2));
        return;
      }
      down.current = !down.current;
      sc.scrollTo(down.current ? "end" : 0, anim.easeInOut(4.6));
    },
    { every: 5.2 },
  );

  /** 0 (unlit) … 1 (lit), in reading order: words further along a line trigger later. */
  const lit = (k: number) => {
    const f = frames[k];
    if (!f) return 0;
    const along = clamp(f.x / width, 0, 1) - 0.5;
    const y = f.y - sc.offset + along * LINE;
    return clamp((focusY + band / 2 - y) / band, 0, 1);
  };

  // Trailing CJK punctuation is set half-width, like CoreText trims it at the end of a Text.
  const glyphs = (word: string) => {
    if (!zh || word.length < 2) return word;
    return (
      <>
        {word.slice(0, -1)}
        <span style={{ display: "inline-block", width: "0.34em" }}>{word.slice(-1)}</span>
      </>
    );
  };

  let k = 0;
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div
          ref={sc.contentRef}
          style={{
            position: "relative",
            padding: `30px 24px ${Math.max(height - focusY, 0) + 12}px`,
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-start",
            gap: 26,
          }}
        >
          <div style={{ fontSize: 12, lineHeight: "16px", fontWeight: 800, letterSpacing: 1.6, color: violetText }}>{zh ? "关于动效" : "ON MOTION"}</div>
          {paragraphs.map((list, p) => (
            <div key={p} style={{ display: "flex", flexWrap: "wrap", columnGap: zh ? 0 : 6, width: "100%" }}>
              {list.map((word, i) => {
                const index = k++;
                const t = lit(index);
                return (
                  <span
                    key={i}
                    ref={(el) => {
                      words.current[index] = el;
                    }}
                    style={{ position: "relative", height: LINE, lineHeight: `${LINE}px`, fontSize: 23, fontWeight: 700, whiteSpace: "nowrap" }}
                  >
                    <span style={{ opacity: dim + (1 - dim) * t }}>{glyphs(word)}</span>
                    {tint && (
                      // Triangular weight: strongest at the wavefront, gone once fully lit.
                      <span
                        style={{
                          position: "absolute",
                          left: 0,
                          top: 0,
                          opacity: 1 - Math.abs(2 * t - 1),
                          background: Palette.primary,
                          WebkitBackgroundClip: "text",
                          backgroundClip: "text",
                          color: "transparent",
                        }}
                      >
                        {glyphs(word)}
                      </span>
                    )}
                  </span>
                );
              })}
            </div>
          ))}
        </div>
      </div>
      {/* Two small ticks at the edges of the stage marking the focus line. */}
      {!ctx.isPreview && (
        <div style={{ position: "absolute", left: 5, right: 5, top: focusY, height: 2, display: "flex", justifyContent: "space-between", pointerEvents: "none", opacity: 0.7 }}>
          <div style={{ width: 10, height: 2, borderRadius: 1, background: violetText }} />
          <div style={{ width: 10, height: 2, borderRadius: 1, background: violetText }} />
        </div>
      )}
    </div>
  );
}
