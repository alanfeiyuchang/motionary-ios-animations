/** showcase.podcast-chapters · 播客章节进度条 (Showcase+PodcastChapters.swift) */
import { AnimatePresence, motion } from "motion/react";
import { AudioWaveform, MessagesSquare, Mic, Pause, Play, Pointer, RotateCcw, RotateCw, Sparkles } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { anim, black, clamp, fonts, hex, localPoint, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioEqualizer, StudioScene, studioClock, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

const DURATION = 2530;
const TW = 256;
const CHAPTERS: { title: [string, string]; start: number; color: number; icon: ReactNode }[] = [
  { title: ["Cold open", "开场白"], start: 0, color: 0xff8a1f, icon: <Mic size={24} strokeWidth={2.4} /> },
  { title: ["Why motion matters", "动效为什么重要"], start: 0.15, color: 0xe0559a, icon: <Sparkles size={24} strokeWidth={2.4} fill="currentColor" /> },
  { title: ["Springs vs. curves", "弹簧与曲线之争"], start: 0.38, color: 0x7c6cff, icon: <AudioWaveform size={24} strokeWidth={2.6} /> },
  { title: ["Designing haptics", "如何设计触感"], start: 0.61, color: 0x2bb8c9, icon: <Pointer size={24} strokeWidth={2.2} fill="currentColor" /> },
  { title: ["Listener questions", "听众提问"], start: 0.83, color: 0x7bcb4e, icon: <MessagesSquare size={24} strokeWidth={2.4} fill="currentColor" /> },
];
const chapterAt = (fraction: number) => {
  let result = 0;
  CHAPTERS.forEach((c, i) => {
    if (fraction >= c.start - 0.0001) result = i;
  });
  return result;
};
const chapterEnd = (index: number) => (index + 1 < CHAPTERS.length ? CHAPTERS[index + 1].start : 1);

export default function PodcastChapters({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [progress, progressApi] = useAnimatedNumber(0.06);
  const [d, dApi] = useAnimatedNumber(0);
  const [chapter, setChapter] = useState(chapterAt(0.06));
  const [forward, setForward] = useState(true);
  const [playing, setPlaying] = useState(true);
  const [crossings, setCrossings] = useState(0);
  const st = useRef({ chapter: chapterAt(0.06), dragging: false, scripting: false, progress: 0.06 });
  const script = useStudioScript();
  const speed = ctx.n("speed");
  const magnet = ctx.n("magnet");

  const apply = (fraction: number, user: boolean, animated?: "linear" | "spring") => {
    const s = st.current;
    const index = chapterAt(fraction);
    if (index !== s.chapter) {
      setForward(index > s.chapter);
      s.chapter = index;
      setCrossings((n) => n + 1);
      if (user) haptics.tap("rigid");
      setChapter(index);
    }
    s.progress = fraction;
    if (animated === "linear") progressApi.animateTo(fraction, anim.linear(0.25));
    else if (animated === "spring") progressApi.animateTo(fraction, spring(0.4, 0.8));
    else progressApi.set(fraction);
  };
  useEffect(() => {
    if (!playing || speed <= 0) return;
    const id = window.setInterval(() => {
      const s = st.current;
      if (s.dragging) return;
      const next = s.progress + (speed * 0.25) / DURATION;
      apply(next > 1 ? 0 : next, false, "linear");
    }, 250);
    return () => window.clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [playing, speed]);

  const beginDrag = () => {
    st.current.dragging = true;
    dApi.animateTo(1, spring(0.3, 0.7));
  };
  const endDrag = () => {
    if (!st.current.dragging) return;
    st.current.dragging = false;
    dApi.animateTo(0, spring(0.3, 0.7));
  };
  const scrub = (raw: number, user: boolean) => {
    let fraction = clamp(raw);
    const radius = magnet / TW;
    for (const c of CHAPTERS.slice(1)) if (Math.abs(fraction - c.start) < radius) fraction = c.start;
    apply(fraction, user);
  };
  const skip = (seconds: number) => {
    script.cancel();
    st.current.scripting = false;
    endDrag();
    haptics.tap("light");
    apply(clamp(st.current.progress + (seconds * 12) / DURATION), true, "spring");
  };
  const runScript = () => {
    if (st.current.dragging) return;
    script.run(async (task) => {
      st.current.scripting = true;
      const from = st.current.progress;
      const target = from > 0.62 ? 0.04 : from + 0.36;
      beginDrag();
      const finished = await task.script(1.5, (t) => scrub(from + (target - from) * studioEase(t), false));
      if (!finished || !(await task.pause(0.35))) return;
      endDrag();
      st.current.scripting = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 3.3, delay: 0.7 });

  const down = useRef(false);
  const gesture = {
    onPointerDown: (e: React.PointerEvent<HTMLDivElement>) => {
      e.currentTarget.setPointerCapture(e.pointerId);
      down.current = true;
      script.cancel();
      st.current.scripting = false;
      if (!st.current.dragging) beginDrag();
      scrub((localPoint(e, e.currentTarget).x - 8) / TW, true);
    },
    onPointerMove: (e: React.PointerEvent<HTMLDivElement>) => {
      if (down.current) scrub((localPoint(e, e.currentTarget).x - 8) / TW, true);
    },
    onPointerUp: () => {
      down.current = false;
      endDrag();
    },
    onPointerCancel: () => {
      down.current = false;
      endDrag();
    },
  };

  const info = CHAPTERS[chapter];
  const tint = hex(info.color);
  const thickness = 4 + (ctx.n("thick") - 4) * d;
  const knob = 14 + 8 * d;
  const x = TW * progress;
  const ce = useElapsed(crossings, 0.5, true);
  const knobScale = ce < 0 ? 1 : ce < 0.08 ? 1 + 0.3 * studioEase(ce / 0.08) : 1.3 - 0.3 * springAt(ce - 0.08, 0.28, 0.5);
  const fade = anim.easeInOut(0.45);
  const chapterSpring = spring(0.4, 0.8);
  const bubbleX = clamp(x - 30, -8, TW - 52);

  return (
    <StudioScene ctx={ctx} en="Drag the scrubber across the chapters" zh="拖动进度条，越过章节分界">
      <motion.div
        initial={false}
        animate={{ "--tint": tint } as never}
        transition={fade}
        style={{ ...signatureCard(), "--tint": tint, width: 292, padding: 18, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 14, color: "#fff" } as never}
      >
        <div style={{ position: "absolute", left: 0, top: 0, right: 0, height: 170, borderRadius: 26, background: "radial-gradient(210px circle at 0% 0%, color-mix(in srgb, var(--tint) 34%, transparent), transparent)", pointerEvents: "none" }} />
        <div style={{ position: "relative", display: "flex", alignItems: "center", gap: 14 }}>
          <div style={{ position: "relative", width: 66, height: 66, borderRadius: 16, flexShrink: 0, boxShadow: "0 6px 12px color-mix(in srgb, var(--tint) 50%, transparent)" }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 16, overflow: "hidden", background: `linear-gradient(135deg, var(--tint), color-mix(in srgb, var(--tint) 45%, transparent), ${Signature.ink})` }}>
              <div style={{ position: "absolute", left: 33 + 18 - 42, top: 33 + 20 - 42, width: 84, height: 84, borderRadius: "50%", boxShadow: `inset 0 0 0 8px ${white(0.18)}` }} />
              <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
                <AnimatePresence initial={false} mode="popLayout">
                  <motion.span key={chapter} initial={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }} exit={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} transition={{ duration: 0.25 }} style={{ display: "grid" }}>
                    {info.icon}
                  </motion.span>
                </AnimatePresence>
              </div>
            </div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 16, boxShadow: `inset 0 0 0 1px ${white(0.16)}` }} />
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 4, alignItems: "flex-start", flex: 1, minWidth: 0 }}>
            <span style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <StudioEqualizer color="var(--tint)" height={10} active={playing} preview={ctx.isPreview} />
              <span style={{ fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700, letterSpacing: 1, textTransform: "uppercase", lineHeight: "12px", color: "var(--tint)", whiteSpace: "nowrap" }}>
                {zh ? `第 ${chapter + 1} 章 / 共 ${CHAPTERS.length} 章` : `Chapter ${chapter + 1} of ${CHAPTERS.length}`}
              </span>
            </span>
            <span style={{ position: "relative", alignSelf: "stretch", height: 24, overflow: "hidden" }}>
              <AnimatePresence initial={false} custom={forward}>
                <motion.span
                  key={chapter}
                  custom={forward}
                  variants={{
                    enter: (f: boolean) => ({ y: f ? 24 : -24, opacity: 0 }),
                    center: { y: 0, opacity: 1 },
                    exit: (f: boolean) => ({ y: f ? -24 : 24, opacity: 0 }),
                  }}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  transition={chapterSpring}
                  style={{ position: "absolute", left: 0, top: 0, fontFamily: fonts.rounded, fontSize: info.title[zh ? 1 : 0].length > 17 ? 16 : 18, fontWeight: 700, lineHeight: "24px", whiteSpace: "nowrap" }}
                >
                  {info.title[zh ? 1 : 0]}
                </motion.span>
              </AnimatePresence>
            </span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 12, fontWeight: 500, lineHeight: "15px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>{zh ? "动效小谈 · 第 48 期" : "Motion Notes · Ep. 48"}</span>
          </div>
        </div>
        <div style={{ position: "relative", display: "flex", flexDirection: "column", gap: 6, paddingTop: 10 }}>
          <div {...gesture} style={{ position: "relative", width: TW + 16, height: 26 + 16, margin: -8, touchAction: "none" }}>
            <div style={{ position: "absolute", left: 8, top: 8, width: TW, height: 26, display: "flex", alignItems: "center", gap: 3 }}>
              {CHAPTERS.map((c, index) => {
                const end = chapterEnd(index);
                const share = clamp((progress - c.start) / (end - c.start));
                const width = TW * (end - c.start) - (index === CHAPTERS.length - 1 ? 0 : 3);
                const h = thickness * (1 + 0.35 * d * (index === chapter ? 1 : 0));
                return (
                  <span key={index} style={{ position: "relative", width, height: h, borderRadius: h / 2, background: white(0.14), overflow: "hidden", flexShrink: 0 }}>
                    <span style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: Math.max(width * share, share > 0 ? thickness : 0), borderRadius: h / 2, background: "var(--tint)" }} />
                  </span>
                );
              })}
            </div>
            <div style={{ position: "absolute", left: 8 + x - knob / 2, top: 8 + 13 - knob / 2, width: knob, height: knob, borderRadius: "50%", background: "#fff", boxShadow: `0 2px 4px ${black(0.45)}`, transform: `scale(${knobScale})` }} />
            <div style={{ position: "absolute", left: 8 + bubbleX, top: 8 + 13 - 26 - 11, width: 60, height: 22, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
              <span style={{ height: 22, padding: "0 8px", borderRadius: 11, background: "#fff", color: Signature.ink, fontFamily: fonts.rounded, fontSize: 12, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "22px", whiteSpace: "nowrap", transformOrigin: "50% 100%", transform: `scale(${0.4 + 0.6 * d})`, opacity: clamp(d) }}>{studioClock(progress * DURATION)}</span>
            </div>
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "13px", color: Signature.textSecondary }}>
            <span>{studioClock(progress * DURATION)}</span>
            <span>{"-" + studioClock((1 - progress) * DURATION)}</span>
          </div>
        </div>
        <div style={{ position: "relative", display: "flex", alignItems: "center", justifyContent: "center", gap: 34 }}>
          <SportPress scale={0.9} dim={0.06} onClick={() => skip(-15)}>
            <SkipGlyph label="15" back />
          </SportPress>
          <SportPress
            scale={0.9}
            dim={0.06}
            radius={23}
            onClick={() => {
              haptics.tap("medium");
              script.cancel();
              st.current.scripting = false;
              endDrag();
              setPlaying((p) => !p);
            }}
          >
            <span style={{ width: 46, height: 46, borderRadius: "50%", background: "#fff", color: Signature.ink, display: "grid", placeItems: "center" }}>
              {playing ? <Pause size={19} fill="currentColor" strokeWidth={0} /> : <Play size={18} fill="currentColor" strokeWidth={0} style={{ marginLeft: 2 }} />}
            </span>
          </SportPress>
          <SportPress scale={0.9} dim={0.06} onClick={() => skip(30)}>
            <SkipGlyph label="30" />
          </SportPress>
        </div>
        <SignatureRim />
      </motion.div>
    </StudioScene>
  );
}

function SkipGlyph({ label, back }: { label: string; back?: boolean }) {
  return (
    <span style={{ position: "relative", width: 36, height: 36, display: "grid", placeItems: "center", color: "#fff" }}>
      {back ? <RotateCcw size={25} strokeWidth={2.2} /> : <RotateCw size={25} strokeWidth={2.2} />}
      <span style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", paddingTop: 2, fontFamily: fonts.rounded, fontSize: 8.5, fontWeight: 800 }}>{label}</span>
    </span>
  );
}
