/** text.letter-morph · 逐字母变形换词 (Text+LetterMorph.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, delayed, fonts, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { measureText } from "./_text-kit";

const WORDS = {
  zh: ["动效", "动效设计", "交互设计", "交互动效", "微交互", "微动效"],
  en: ["creative", "reactive", "interactive", "active", "attractive"],
};

interface Letter {
  id: number;
  character: string;
  /** Order among the letters that were added in the same change (for the stagger). */
  arrival: number;
  isNew: boolean;
}

/** Longest common subsequence: index pairs (old, new) of the characters both words share, in order. */
function commonSubsequence(a: string[], b: string[]): { old: number; new: number }[] {
  if (!a.length || !b.length) return [];
  const table = Array.from({ length: a.length + 1 }, () => new Array<number>(b.length + 1).fill(0));
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      table[i][j] = a[i] === b[j] ? table[i + 1][j + 1] + 1 : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  const pairs: { old: number; new: number }[] = [];
  let i = 0, j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      pairs.push({ old: i, new: j });
      i += 1;
      j += 1;
    } else if (table[i + 1][j] >= table[i][j + 1]) i += 1;
    else j += 1;
  }
  return pairs;
}

const FONT = `800 54px ${fonts.rounded}`;

export default function LetterMorph({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const words = WORDS[ctx.lang];
  const initial = () => Array.from(words[0]).map((character, id) => ({ id, character, arrival: 0, isNew: false }));
  const [letters, setLetters] = useState<Letter[]>(initial);
  const index = useRef(0);
  const nextID = useRef(Array.from(words[0]).length);
  const lang = useRef(ctx.lang);
  if (lang.current !== ctx.lang) {
    lang.current = ctx.lang;
    index.current = 0;
    nextID.current += 100;
    const base = nextID.current;
    setLetters(Array.from(words[0]).map((character, i) => ({ id: base + i, character, arrival: 0, isNew: false })));
    nextID.current += 20;
  }
  // Glyph widths come from the font, so measure again once it has loaded.
  const [, setFontsReady] = useState(0);
  useEffect(() => {
    void document.fonts?.ready.then(() => setFontsReady(1));
  }, []);

  const transition = spring(ctx.n("response"), ctx.n("damping"));
  const blur = ctx.n("blur");
  const interval = Math.max(ctx.n("interval"), 0.6);
  const label = ctx.scheme === "dark" ? "#FFFFFF" : "#000000";

  const advance = () => {
    index.current += 1;
    const target = Array.from(words[index.current % words.length]);
    setLetters((current) => {
      const kept = commonSubsequence(current.map((l) => l.character), target);
      const next: Letter[] = [];
      let arrivals = 0;
      let cursor = 0;
      target.forEach((character, position) => {
        if (cursor < kept.length && kept[cursor].new === position) {
          next.push({ ...current[kept[cursor].old], isNew: false });
          cursor += 1;
        } else {
          next.push({ id: nextID.current++, character, arrival: arrivals++, isNew: true });
        }
      });
      return next;
    });
  };
  useAutoplay(true, advance, { every: interval, delay: interval });

  const widths = letters.map((l) => measureText(l.character, FONT));
  const total = widths.reduce((a, b) => a + b, 0);
  let x = -total / 2;
  const lefts = widths.map((w) => {
    const left = x;
    x += w;
    return left;
  });

  return (
    <div
      onClick={() => {
        haptics.selection();
        advance();
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10, cursor: "pointer" }}
    >
      <span style={{ fontFamily: fonts.rounded, fontSize: 26, lineHeight: "31px", fontWeight: 600, color: Palette.secondaryLabel }}>{ctx.t("Make it", "认真做好")}</span>
      <div style={{ position: "relative", width: 0, height: 72 }}>
        <AnimatePresence initial={false}>
          {letters.map((letter, i) => (
            <motion.span
              key={letter.id}
              initial={{ x: lefts[i], scale: 0.6, filter: `blur(${blur}px)`, opacity: 0, color: Palette.violet }}
              animate={{ x: lefts[i], scale: 1, filter: "blur(0px)", opacity: 1, color: label }}
              exit={{ scale: 0.6, filter: `blur(${blur}px)`, opacity: 0, transition: delayed(transition, letter.arrival * 0.03) }}
              transition={{
                x: transition,
                scale: delayed(transition, letter.arrival * 0.03),
                filter: delayed(transition, letter.arrival * 0.03),
                opacity: delayed(transition, letter.arrival * 0.03),
                color: { type: "tween", duration: letter.isNew ? 0.9 : 0, delay: letter.isNew ? 0.3 : 0, ease: [0, 0, 0.58, 1] },
              }}
              style={{ position: "absolute", left: 0, top: 0, width: widths[i], height: 72, lineHeight: "72px", textAlign: "center", fontFamily: fonts.rounded, fontSize: 54, fontWeight: 800, whiteSpace: "pre" }}
            >
              {letter.character}
            </motion.span>
          ))}
        </AnimatePresence>
        <motion.div
          initial={false}
          animate={{ width: Math.max(total - 6, 0), x: -Math.max(total - 6, 0) / 2 }}
          transition={transition}
          style={{ position: "absolute", left: 0, bottom: -10, height: 5, borderRadius: 2.5, background: `linear-gradient(90deg, ${Palette.indigo}, ${Palette.violet}, ${Palette.pink})` }}
        />
      </div>
      <DemoHint ctx={ctx} en="Tap for the next word" zh="点击切换下一个词" style={{ paddingTop: 34 }} />
    </div>
  );
}
