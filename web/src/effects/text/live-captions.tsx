/** text.live-captions · 实时字幕滚动 (Text+LiveCaptions.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useLayoutEffect, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, demoCard, fonts, spring, useHaptics, useLatest, type DemoProps } from "../../kit";
import { randIn, useTask } from "./_text-kit";
import { squeezed } from "./_fx";

interface CaptionLine {
  speaker: number;
  tokens: string[];
  /** The token that is first misheard, and what was heard instead. */
  slip: number;
  misheard: string;
}
const SCRIPT: Record<"zh" | "en", CaptionLine[]> = {
  zh: [
    { speaker: 0, tokens: ["所以", "思路", "很", "简单：", "字幕", "应该", "是", "活的。", "听到", "一个词", "就", "落下", "一个词，", "一行", "满了", "就", "整体", "往上", "滚。"], slip: 4, misheard: "字母" },
    { speaker: 1, tokens: ["对，", "识别", "结果", "改", "主意", "的", "时候，", "那个", "词", "就", "在", "原地", "换掉，", "谁", "也", "不会", "看丢", "位置。"], slip: 11, misheard: "园地" },
  ],
  en: [
    { speaker: 0, tokens: ["So", "the", "idea", "is", "simple:", "captions", "should", "feel", "alive.", "Words", "land", "as", "they", "are", "heard,", "and", "a", "full", "line", "rolls", "away."], slip: 14, misheard: "hurt," },
    { speaker: 1, tokens: ["Right,", "and", "when", "the", "recogniser", "changes", "its", "mind,", "the", "word", "swaps", "in", "place.", "Nobody", "loses", "their", "spot."], slip: 7, misheard: "mined," },
  ],
};
const TINTS = [Palette.coral, Palette.sky];
const LINE_HEIGHT = 27;
const LINE_SPACING = 5;
const ROLL = spring(0.4, 0.85);

export default function LiveCaptions({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [sentence, setSentence] = useState(0);
  const sentenceRef = useRef(0);
  const [revealed, setRevealed] = useState(0);
  const revealedRef = useRef(0);
  const [clearing, setClearing] = useState(false);
  const [talking, setTalking] = useState(false);
  const [levels, setLevels] = useState([0.3, 0.6, 0.9, 0.5, 0.35]);
  const [runs, setRuns] = useState(0);
  const [blockHeight, setBlockHeight] = useState(0);
  const rate = useLatest(ctx.n("rate"));
  const all = SCRIPT[ctx.lang];
  const line = all[sentence % all.length];
  const names = ctx.lang === "zh" ? ["小满", "阿健"] : ["Maya", "Kenji"];
  const isCJK = ctx.lang === "zh";
  const tentative = ctx.b("tentative");

  useTask(`${runs}|${ctx.lang}`, async (sleep) => {
    for (;;) {
      if (revealedRef.current > 0) {
        setTalking(false);
        setClearing(true);
        if (!(await sleep(0.26))) return;
        sentenceRef.current += 1;
        revealedRef.current = 0;
        setSentence(sentenceRef.current);
        setRevealed(0);
        setClearing(false);
      }
      if (!(await sleep(0.45))) return;
      setTalking(true);
      const list = SCRIPT[ctx.lang];
      const tokens = list[sentenceRef.current % list.length].tokens;
      for (let index = 0; index < tokens.length; index++) {
        revealedRef.current = index + 1;
        setRevealed(index + 1);
        setLevels(Array.from({ length: 5 }, () => randIn(0.2, 1)));
        const base = 1 / Math.max(rate.current, 1);
        const last = tokens[index].slice(-1) || " ";
        const pause = "。.：:".includes(last) ? 2.6 : ",，".includes(last) ? 1.7 : 1;
        if (!(await sleep(base * randIn(0.7, 1.3) * pause))) return;
      }
      // The last word is confirmed and the speaker goes quiet.
      setTalking(false);
      if (!(await sleep(1.7))) return;
    }
  });

  const block = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const measure = () => {
      if (block.current) setBlockHeight(block.current.offsetHeight);
    };
    measure();
    void document.fonts?.ready.then(measure);
  }, [revealed, sentence, ctx.lang]);

  const rows = ctx.i("lines") === 1 ? 3 : 2;
  const windowHeight = LINE_HEIGHT * rows + LINE_SPACING * (rows - 1);
  const count = Math.min(revealed, line.tokens.length);

  const tile = (index: number) => {
    const active = line.speaker === index && talking;
    const tint = TINTS[index];
    const tileSpring = spring(0.35, 0.7);
    return (
      <div style={{ position: "relative", width: 144, height: 88, borderRadius: 18, background: Palette.labelAlpha(0.05), display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 7 }}>
        <motion.div initial={false} animate={{ opacity: active ? 0.9 : 0 }} transition={tileSpring} style={{ position: "absolute", inset: 0, borderRadius: 18, border: `2px solid ${tint}`, pointerEvents: "none" }} />
        <motion.div
          initial={false}
          animate={{ scale: active ? 1.06 : 1 }}
          transition={tileSpring}
          style={{ width: 38, height: 38, borderRadius: "50%", background: `linear-gradient(${tint}, ${alpha(tint, 0.6)})`, display: "flex", alignItems: "center", justifyContent: "center", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 800, color: "#fff" }}
        >
          {Array.from(names[index])[0]}
        </motion.div>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 13, lineHeight: "16px", fontWeight: 600, color: active ? Palette.label : Palette.secondaryLabel, transition: "color 0.3s" }}>{names[index]}</span>
          <motion.div initial={false} animate={{ opacity: active ? 1 : 0.35 }} transition={tileSpring} style={{ height: 14, display: "flex", alignItems: "center", gap: 2 }}>
            {levels.map((level, bar) => (
              <motion.span key={bar} initial={false} animate={{ height: active ? 4 + 10 * level : 3 }} transition={active ? spring(0.22, 0.55) : tileSpring} style={{ width: 2.5, borderRadius: 1.25, background: tint }} />
            ))}
          </motion.div>
        </div>
      </div>
    );
  };

  return (
    <div
      onClick={() => {
        haptics.tap("light");
        setRuns((r) => r + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, cursor: "pointer" }}
    >
      <div style={{ display: "flex", gap: 12 }}>
        {tile(0)}
        {tile(1)}
      </div>
      <div style={{ ...demoCard(22), padding: "14px 16px", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6, color: TINTS[line.speaker], transition: "color 0.25s ease-in-out" }}>
          <svg width={14} height={12} viewBox="0 0 14 12">
            <mask id="text-captions-bubble">
              <rect width={14} height={12} fill="#fff" />
              <path d="M3.4 4.3 H10.6 M3.4 6.6 H8.2" stroke="#000" strokeWidth={1.1} strokeLinecap="round" />
            </mask>
            <path d="M2.4 0.6 H11.6 A1.9 1.9 0 0 1 13.5 2.5 V7.6 A1.9 1.9 0 0 1 11.6 9.5 H6.6 L3.9 11.6 V9.5 H2.4 A1.9 1.9 0 0 1 0.5 7.6 V2.5 A1.9 1.9 0 0 1 2.4 0.6 Z" fill="currentColor" mask="url(#text-captions-bubble)" />
          </svg>
          <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 700 }}>{names[line.speaker]}</span>
        </div>
        {/* The block is pinned by an explicit offset, so a new row moves every line up as one piece. */}
        <motion.div
          initial={false}
          animate={{ height: windowHeight, opacity: clearing ? 0 : 1, y: clearing ? -10 : 0 }}
          transition={{ height: ROLL, default: clearing ? anim.easeIn(0.22) : { duration: 0 } }}
          style={{
            position: "relative",
            width: 268,
            overflow: "hidden",
            maskImage: `linear-gradient(transparent -6px, #000 calc(22% - 4.7px), #000)`,
            WebkitMaskImage: `linear-gradient(transparent -6px, #000 calc(22% - 4.7px), #000)`,
          }}
        >
          <motion.div
            key={sentence}
            ref={block}
            initial={{ y: windowHeight }}
            animate={{ y: windowHeight - blockHeight }}
            transition={ROLL}
            style={{ position: "absolute", left: 0, top: 0, width: 268, display: "flex", flexWrap: "wrap", alignItems: "center", columnGap: isCJK ? 0 : 5, rowGap: LINE_SPACING }}
          >
            {line.tokens.slice(0, count).map((token, index) => {
              const newest = tentative && index === revealed - 1 && talking;
              const isSlip = index === line.slip;
              const fixed = revealed >= index + 3;
              const text = isSlip && !fixed ? line.misheard : token;
              return (
                <motion.span
                  key={index}
                  initial={{ y: 6, filter: "blur(5px)", opacity: 0 }}
                  animate={{ y: 0, filter: "blur(0px)", opacity: 1 }}
                  transition={anim.easeOut(0.22)}
                  style={{ position: "relative", display: "inline-flex", alignItems: "center", height: LINE_HEIGHT, fontSize: 21, fontWeight: 600, whiteSpace: "pre", color: newest ? Palette.secondaryLabel : Palette.label, transition: "color 0.3s" }}
                >
                  {isSlip ? (
                    <AnimatePresence initial={false} mode="popLayout">
                      <motion.span key={text} initial={{ opacity: 0, filter: "blur(3px)" }} animate={{ opacity: 1, filter: "blur(0px)" }} exit={{ opacity: 0, filter: "blur(3px)" }} transition={ROLL}>
                        {squeezed(text)}
                      </motion.span>
                    </AnimatePresence>
                  ) : (
                    <span>{squeezed(text)}</span>
                  )}
                  {isSlip && (
                    <motion.span
                      initial={false}
                      animate={{ opacity: fixed && revealed <= index + 6 ? 1 : 0 }}
                      transition={ROLL}
                      style={{ position: "absolute", left: 0, right: 0, bottom: 0, height: 2.5, borderRadius: 1.25, background: Palette.amber }}
                    />
                  )}
                </motion.span>
              );
            })}
          </motion.div>
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap to pass the mic" zh="点击换人发言" />
    </div>
  );
}
