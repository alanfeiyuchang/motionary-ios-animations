/** text.ai-stream · AI 逐词流式输出 (Text+AIStream.swift) */
import { motion } from "motion/react";
import { Copy, RotateCw, Sparkles, ThumbsUp } from "lucide-react";
import { useLayoutEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, delayed, fonts, forever, spring, useAutoplay, useHaptics, useLatest, type DemoProps } from "../../kit";
import { randIn, useTask } from "./_text-kit";

const ANSWERS = {
  zh: [
    ["好的", "动效", "只做", "三件", "事：", "立刻", "回应", "手指，", "把", "前后", "两个", "状态", "连", "起来，", "然后", "安静", "地", "退场。", "先", "保证", "100", "毫秒", "内", "有", "反馈，", "再用", "弹簧", "衔接，", "最后", "删掉", "多余", "的", "装饰。"],
    ["可以", "这样", "调：", "响应", "0.35", "秒、", "阻尼", "0.8，", "按下", "即时，", "松手", "回弹。", "幅度", "越小，", "越", "显得", "高级；", "拿", "不准", "时，", "就", "再", "慢", "一点", "点。"],
  ],
  en: [
    ["Great", "motion", "does", "three", "things:", "it", "answers", "the", "finger", "at", "once,", "links", "one", "state", "to", "the", "next,", "then", "gets", "out", "of", "the", "way.", "Cut", "what", "only", "decorates."],
    ["Try", "this:", "response", "0.35 s,", "damping", "0.8.", "Press", "is", "instant,", "release", "is", "elastic.", "Smaller", "moves", "read", "as", "more", "premium;", "when", "unsure,", "slow", "it", "down", "a", "touch."],
  ],
};

export default function AIStream({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [answer, setAnswer] = useState(0);
  const [revealed, setRevealed] = useState(0);
  const [done, setDone] = useState(false);
  const [clearing, setClearing] = useState(false);
  const [runs, setRuns] = useState(0);
  const answerRef = useRef(0);
  const lastRun = useRef(0);
  const rate = useLatest(ctx.n("rate"));
  const fade = ctx.n("fade");
  const blur = ctx.n("blur");
  const all = ANSWERS[ctx.lang];
  const tokens = all[answer % all.length];
  const isCJK = ctx.lang === "zh";

  const regenerate = () => setRuns((r) => r + 1);
  useAutoplay(ctx.isPreview, regenerate, { every: 6.5, delay: 5.2, intro: false });

  useTask(`${runs}|${ctx.lang}`, async (sleep) => {
    if (runs !== lastRun.current) {
      setClearing(true);
      if (!(await sleep(0.28))) return;
      answerRef.current += 1;
      setAnswer(answerRef.current);
      setRevealed(0);
      setDone(false);
      setClearing(false);
    } else {
      setRevealed(0);
      setDone(false);
    }
    lastRun.current = runs;
    if (!(await sleep(0.5))) return;
    const list = ANSWERS[ctx.lang];
    const words = list[answerRef.current % list.length];
    for (let index = 0; index < words.length; index++) {
      setRevealed(index + 1);
      const base = 1 / Math.max(rate.current, 1);
      const jitter = randIn(0.55, 1.5);
      const last = words[index].slice(-1) || " ";
      const pause = "。.：:；;".includes(last) ? 3.2 : ",，、".includes(last) ? 1.9 : 1;
      if (!(await sleep(base * jitter * pause))) return;
    }
    if (!(await sleep(0.25))) return;
    setDone(true);
  });

  // The caret is placed right after the newest token (the flow's `markerAfter`).
  const flow = useRef<HTMLDivElement>(null);
  const [marker, setMarker] = useState({ x: 0, y: 11.5 });
  const markerIndex = Math.min(revealed, tokens.length) - 1;
  useLayoutEffect(() => {
    const measure = () => {
      const el = flow.current;
      if (!el) return;
      const nodes = el.querySelectorAll<HTMLElement>("[data-token]");
      const node = markerIndex >= 0 ? nodes[markerIndex] : null;
      const next = node ? { x: node.offsetLeft + node.offsetWidth, y: node.offsetTop + node.offsetHeight / 2 } : { x: 0, y: (nodes[0]?.offsetHeight ?? 23) / 2 };
      setMarker((m) => (m.x === next.x && m.y === next.y ? m : next));
    };
    measure();
    void document.fonts?.ready.then(measure);
  }, [markerIndex, answer, ctx.lang]);

  const icons = [Copy, ThumbsUp, RotateCw];
  return (
    <div
      onClick={() => {
        haptics.tap("light");
        regenerate();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer" }}
    >
      <div style={{ width: 290, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 14 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 9 }}>
          <motion.span
            animate={{ boxShadow: `0 0 ${done ? 0 : 16}px ${alpha(Palette.violet, done ? 0 : 0.55)}` }}
            transition={anim.easeInOut(0.4)}
            style={{ width: 28, height: 28, borderRadius: "50%", background: Palette.primary, display: "inline-flex", alignItems: "center", justifyContent: "center", color: "#fff" }}
          >
            <motion.span
              animate={done ? { opacity: 1 } : { opacity: [1, 0.45, 1] }}
              transition={done ? anim.easeInOut(0.3) : { duration: 1.6, repeat: Infinity, ease: "easeInOut" }}
              style={{ display: "inline-flex" }}
            >
              <Sparkles size={15} strokeWidth={2.4} fill="currentColor" />
            </motion.span>
          </motion.span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700, color: Palette.label }}>Motionary AI</span>
          <span style={{ position: "relative", fontSize: 13, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "pre" }}>
            <motion.span animate={{ opacity: done ? 0 : 1 }} transition={anim.easeInOut(0.3)} initial={false} style={{ display: "inline-block" }}>
              {ctx.t("Writing…", "正在输出…")}
            </motion.span>
            <motion.span animate={{ opacity: done ? 1 : 0 }} transition={anim.easeInOut(0.3)} initial={false} style={{ position: "absolute", left: 0, top: 0 }}>
              {ctx.t("Answered", "已回答")}
            </motion.span>
          </span>
        </div>

        <div style={{ width: 290, minHeight: 160 }}>
          <motion.div
            key={answer}
            ref={flow}
            initial={false}
            animate={{ opacity: clearing ? 0 : 1, filter: clearing ? "blur(8px)" : "blur(0px)" }}
            transition={clearing ? anim.easeIn(0.25) : { duration: 0 }}
            style={{ position: "relative", display: "flex", flexWrap: "wrap", alignItems: "center", columnGap: isCJK ? 0 : 5, rowGap: 7, width: 290 }}
          >
            {tokens.map((text, index) => {
              const shown = index < revealed;
              const fresh = index >= revealed - 2 && !done;
              const tail = "，。：；、".includes(text.slice(-1)) ? text.slice(-1) : "";
              return (
                <motion.span
                  key={index}
                  data-token=""
                  initial={false}
                  animate={{ opacity: shown ? 1 : 0, filter: shown ? "blur(0px)" : `blur(${blur}px)`, y: shown ? 0 : 6, color: fresh ? Palette.violet : ctx.scheme === "dark" ? "#FFFFFF" : "#000000" }}
                  transition={{ ...anim.easeOut(fade), color: anim.easeOut(0.6) }}
                  style={{ display: "inline-block", fontSize: 19, lineHeight: "23px", fontWeight: 500, whiteSpace: "pre" }}
                >
                  {tail ? text.slice(0, -1) : text}
                  {/* A Text that ends in full-width punctuation is trimmed to its ink by Core Text. */}
                  {tail && <span style={{ fontFeatureSettings: '"halt"' }}>{tail}</span>}
                </motion.span>
              );
            })}
            <motion.div
              initial={false}
              animate={{ x: marker.x, y: marker.y }}
              transition={spring(0.22, 0.85)}
              style={{ position: "absolute", left: 0, top: -10.5, paddingLeft: 3, pointerEvents: "none" }}
            >
              <motion.div initial={false} animate={{ scaleY: done ? 0.01 : 1, opacity: done ? 0 : 1 }} transition={anim.easeOut(0.25)}>
                <motion.div
                  initial={{ opacity: 1 }}
                  animate={{ opacity: 0.45 }}
                  transition={forever(anim.easeInOut(0.55))}
                  style={{ width: 3, height: 21, borderRadius: 1.5, background: `linear-gradient(${Palette.indigo}, ${Palette.violet})`, boxShadow: `0 0 10px ${alpha(Palette.violet, 0.8)}` }}
                />
              </motion.div>
            </motion.div>
          </motion.div>
        </div>

        <div style={{ display: "flex", gap: 18, color: Palette.secondaryLabel }}>
          {icons.map((Icon, index) => (
            <motion.span
              key={index}
              initial={false}
              animate={{ opacity: done ? 1 : 0, y: done ? 0 : 6 }}
              transition={delayed(anim.easeOut(0.3), done ? 0.15 + index * 0.06 : 0)}
              style={{ display: "inline-flex" }}
            >
              <Icon size={17} strokeWidth={2.2} />
            </motion.span>
          ))}
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 12 }}>
        <DemoHint ctx={ctx} en="Tap to regenerate" zh="点击重新生成" />
      </div>
    </div>
  );
}
