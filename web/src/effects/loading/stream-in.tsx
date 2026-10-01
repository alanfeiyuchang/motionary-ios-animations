/** loading.stream-in · 流式回答 (Loading+StreamIn.swift) */
import { animate, motion, useMotionValue, useTransform, type Transition } from "motion/react";
import { Copy, RotateCw, Sparkles, ThumbsUp } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, delayed, fonts, spring, useHaptics, type DemoProps } from "../../kit";
import { primary, useTask } from "./shared";

const FONT_SIZE = 15;
const LINE = 23;
const WIDTH = 260;

interface Token {
  id: number;
  text: string;
  x: number;
  line: number;
  width: number;
  pausesAfter: boolean;
}
interface Piece {
  text: string;
  latin: boolean;
}
interface Layout {
  tokens: Token[];
  lineWidths: number[];
  height: number;
}

const ENGLISH =
  "Springs feel natural because they carry velocity. Start with a response near 0.4 s and a damping of 0.8, then lower the damping until the motion gains a little life.";
const CHINESE = "弹簧动画显得自然，是因为它会延续速度。先把响应设在 0.4 秒左右、阻尼设为 0.8，再一点点调低阻尼，直到动作带上一丝生命力。";

/** One token per Han character; Latin and digit runs stay whole and punctuation hangs on the token before it. */
function splitChinese(text: string): Piece[] {
  const pieces: Piece[] = [];
  let run = "";
  const closing = new Set(["，", "。", "、", "！", "？"]);
  const flush = () => {
    if (run) pieces.push({ text: run, latin: true });
    run = "";
  };
  for (const character of text) {
    if (character === " ") {
      flush();
      continue;
    }
    if (character.charCodeAt(0) < 128) {
      run += character;
      continue;
    }
    flush();
    if (closing.has(character) && pieces.length) pieces[pieces.length - 1].text += character;
    else pieces.push({ text: character, latin: false });
  }
  flush();
  return pieces;
}

let measurer: CanvasRenderingContext2D | null = null;
function measure(text: string): number {
  if (!measurer) measurer = document.createElement("canvas").getContext("2d");
  if (!measurer) return text.length * 8;
  measurer.font = `${FONT_SIZE}px ${fonts.text}`;
  return measurer.measureText(text).width;
}

function makeLayout(pieces: Piece[], spaced: boolean): Layout {
  const space = spaced ? measure(" ") : 0;
  const air = 3;
  const tokens: Token[] = [];
  const widths: number[] = [];
  let x = 0;
  let line = 0;
  let trailing = 0;
  pieces.forEach((piece, index) => {
    const width = Math.ceil(measure(piece.text) * 10) / 10;
    const lead = piece.latin && x > 0 ? air : 0;
    if (x > 0 && x + lead + width > WIDTH) {
      widths.push(x - trailing);
      x = 0;
      line += 1;
    } else {
      x += lead;
    }
    const last = piece.text[piece.text.length - 1] ?? " ";
    const pauses = [",", ".", "，", "。", "、"].includes(last);
    tokens.push({ id: index, text: piece.text, x, line, width, pausesAfter: pauses });
    trailing = space + (piece.latin && !pauses ? air : 0);
    x += width + trailing;
  });
  widths.push(Math.max(x - trailing, 0));
  return { tokens, lineWidths: widths, height: widths.length * LINE };
}

type Phase = "thinking" | "writing" | "done";
const EASE_OUT = "cubic-bezier(0, 0, 0.58, 1)";

export default function StreamIn({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const layout = useMemo(() => (zh ? makeLayout(splitChinese(CHINESE), false) : makeLayout(ENGLISH.split(" ").map((text) => ({ text, latin: false })), true)), [zh]);
  const [count, setCount] = useState(0);
  const [phase, setPhase] = useState<Phase>("thinking");
  const [run, setRun] = useState(0);
  const [motionT, setMotionT] = useState<Transition>(anim.easeOut(0.25));
  const latest = useRef({ ctx, layout });
  latest.current = { ctx, layout };

  useTask(`${run}-${ctx.lang}`, async (task) => {
    const live = !ctx.isPreview && run > 0;
    const total = latest.current.layout.tokens.length;
    let shown = 0;
    setMotionT(anim.easeOut(0.25));
    setCount(0);
    setPhase("thinking");
    await task.sleep(0.7);
    setMotionT(spring(0.3, 0.7));
    setPhase("writing");
    while (shown < total) {
      const burst = Math.min(1 + Math.floor(Math.random() * 3), total - shown);
      shown += burst;
      setMotionT(spring(0.22, 0.85));
      setCount(shown);
      const c = latest.current.ctx;
      const rate = Math.max(c.n("rate"), 1) * (c.lang === "zh" ? 2 : 1);
      let wait = (burst / rate) * (0.7 + Math.random() * 0.6);
      if (latest.current.layout.tokens[shown - 1].pausesAfter) wait += 0.16;
      await task.sleep(wait);
    }
    await task.sleep(0.25);
    setMotionT(spring(0.4, 0.7));
    setPhase("done");
    if (live) haptics.success();
    if (!ctx.isPreview) return;
    await task.sleep(2.0);
    setRun((v) => v + 1);
  });

  const shownCount = Math.min(count, layout.tokens.length);
  const caret = (() => {
    if (shownCount <= 0) return { x: 0, y: 0 };
    const token = layout.tokens[shownCount - 1];
    return { x: token.x + token.width + 3, y: token.line * LINE };
  })();
  const currentLine = shownCount > 0 ? layout.tokens[shownCount - 1].line : 0;
  const thinking = phase === "thinking";
  const done = phase === "done";
  const status = thinking ? ctx.t("Thinking…", "思考中…") : phase === "writing" ? ctx.t("Writing…", "撰写中…") : ctx.t("Done", "已完成");
  const violetText = ctx.scheme === "dark" ? "#C4A0FF" : "#7A45D6";
  const blur = ctx.n("blur");

  return (
    <div
      onClick={() => {
        haptics.tap();
        setRun((v) => v + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 16 }}
    >
      <div
        style={{
          width: 296,
          padding: 18,
          display: "flex",
          flexDirection: "column",
          gap: 14,
          borderRadius: 24,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 36px ${black(0.1)}`,
          flex: "none",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 9 }}>
          <div style={{ width: 28, height: 28, borderRadius: "50%", background: `linear-gradient(135deg, ${Palette.violet}, ${Palette.pink})`, display: "grid", placeItems: "center", color: "#fff" }}>
            <Sparkles size={14} fill="currentColor" strokeWidth={1.5} />
          </div>
          <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "助手" : "Assistant"}</span>
          <span style={{ flex: 1 }} />
          <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel }}>{status}</span>
        </div>

        <div style={{ position: "relative", width: WIDTH, height: layout.height }}>
          {ctx.b("skeleton") &&
            layout.lineWidths.map((full, line) => (
              <SkeletonBar
                key={`${ctx.lang}-${line}`}
                y={line * LINE + (LINE - 9) / 2}
                full={full}
                start={line < currentLine ? full : line === currentLine ? Math.min(caret.x + 12, full) : 0}
                transition={motionT}
                paused={done}
              />
            ))}
          {layout.tokens.map((token) => {
            const shown = token.id < shownCount;
            const fresh = !done && token.id >= shownCount - 3;
            return (
              <span
                key={`${ctx.lang}-${token.id}`}
                style={{
                  position: "absolute",
                  left: token.x,
                  top: token.line * LINE,
                  height: LINE,
                  lineHeight: `${LINE}px`,
                  fontSize: FONT_SIZE,
                  fontFamily: fonts.text,
                  whiteSpace: "nowrap",
                  color: fresh ? violetText : Palette.label,
                  opacity: shown ? 1 : 0,
                  filter: `blur(${shown ? 0 : blur}px)`,
                  transform: `translateY(${shown ? 0 : 5}px)`,
                  transition: `opacity 0.38s ${EASE_OUT}, filter 0.38s ${EASE_OUT}, transform 0.38s ${EASE_OUT}, color 0.6s ${EASE_OUT}`,
                }}
              >
                {token.text}
              </span>
            );
          })}
          <motion.div
            initial={false}
            animate={{ x: caret.x, y: caret.y, opacity: done ? 0 : 1, scale: done ? 0.4 : 1 }}
            transition={motionT}
            style={{ position: "absolute", left: 0, top: 0, width: 9, height: LINE, display: "flex", alignItems: "center", pointerEvents: "none" }}
          >
            <motion.div
              initial={false}
              animate={{ width: thinking ? 9 : 3, height: thinking ? 9 : 17 }}
              transition={motionT}
              style={{ borderRadius: 999, background: `linear-gradient(${Palette.violet}, ${Palette.pink})`, boxShadow: `0 0 10px ${alpha(Palette.violet, 0.7)}` }}
            >
              <CaretPulse thinking={thinking} />
            </motion.div>
          </motion.div>
        </div>

        <div style={{ display: "flex", gap: 8, height: 26 }}>
          {[Copy, ThumbsUp, RotateCw].map((Icon, index) => (
            <motion.div
              key={index}
              initial={false}
              animate={{ scale: done ? 1 : 0.4, opacity: done ? 1 : 0 }}
              transition={done ? delayed(spring(0.36, 0.6), index * 0.06) : anim.easeOut(0.15)}
              style={{ width: 30, height: 26, borderRadius: 9, background: primary(0.06), display: "grid", placeItems: "center", color: Palette.secondaryLabel }}
            >
              <Icon size={13} strokeWidth={2.4} />
            </motion.div>
          ))}
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to regenerate" zh="点击重新生成" />
    </div>
  );
}

/** `phaseAnimator([false, true])`: the thinking dot dims to 35 % and back, 0.45 s each way. */
function CaretPulse({ thinking }: { thinking: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const el = ref.current?.parentElement;
    if (!el) return;
    if (!thinking) {
      const c = animate(el, { filter: "opacity(1)" }, anim.easeInOut(0.45));
      return () => c.stop();
    }
    const c = animate(el, { filter: ["opacity(1)", "opacity(0.35)"] }, { duration: 0.45, ease: [0.42, 0, 0.58, 1], repeat: Infinity, repeatType: "reverse" });
    return () => c.stop();
  }, [thinking]);
  return <div ref={ref} style={{ display: "none" }} />;
}

/** One skeleton bar from `start` to `full`; hidden when shorter than 8 pt (`StreamBar`). */
function SkeletonBar({ y, full, start, transition, paused }: { y: number; full: number; start: number; transition: Transition; paused: boolean }) {
  const from = useMotionValue(start);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    const c = animate(from, start, transition);
    return () => c.stop();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [start]);
  const clipPath = useTransform(from, (v) => {
    const a = Math.min(Math.max(v, 0), WIDTH);
    const b = Math.min(Math.max(full, 0), WIDTH);
    return b - a >= 8 ? `inset(0px ${WIDTH - b}px 0px ${a}px round 4.5px)` : "inset(0px 100% 0px 0px)";
  });
  const tile = 0.8 * WIDTH;
  return (
    <motion.div style={{ position: "absolute", left: 0, top: y, width: WIDTH, height: 9, clipPath, background: primary(0.08), pointerEvents: "none" }}>
      <motion.div
        animate={paused ? undefined : { backgroundPositionX: [`${-1.1 * WIDTH}px`, `${1.3 * WIDTH}px`] }}
        transition={{ duration: 1.5, ease: "linear", repeat: Infinity }}
        style={{
          position: "absolute",
          inset: 0,
          backgroundImage: `linear-gradient(90deg, ${alpha(Palette.violet, 0)} 0%, ${alpha(Palette.violet, 0.5)} 45%, ${alpha(Palette.pink, 0.45)} 60%, ${alpha(Palette.pink, 0)} 100%)`,
          backgroundSize: `${tile}px 100%`,
          backgroundRepeat: "no-repeat",
          backgroundPositionX: `${-1.1 * WIDTH}px`,
        }}
      />
    </motion.div>
  );
}
