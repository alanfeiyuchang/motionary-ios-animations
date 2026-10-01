/** feedback.progress-toast · 进度环吐司 (Feedback+ProgressToast.swift) */
import { ArrowUp, FileText, Film, Image, Spline, StickyNote } from "lucide-react";
import { AnimatePresence, motion, useMotionValueEvent, type Transition } from "motion/react";
import { useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, anim, black, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { FeedbackScene, gradientOf } from "./_scene";
import { SPRINGS, track, useAnimated } from "./shared";

type Stage = "hidden" | "uploading" | "done";

const FILES: { name: string; size: string; icon: ReactNode; tint: string }[] = [
  { name: "IMG_2041.heic", size: "3.2 MB", icon: <Image size={13} strokeWidth={2.6} />, tint: Palette.sky },
  { name: "Invoice-0924.pdf", size: "640 KB", icon: <FileText size={13} strokeWidth={2.6} />, tint: Palette.coral },
  { name: "Demo-cut.mov", size: "48 MB", icon: <Film size={13} strokeWidth={2.6} />, tint: Palette.violet },
  { name: "Notes.md", size: "12 KB", icon: <StickyNote size={13} strokeWidth={2.6} />, tint: Palette.amber },
  { name: "Logo.svg", size: "88 KB", icon: <Spline size={13} strokeWidth={2.6} />, tint: Palette.mint },
];
/** Uneven shares of the upload time, so the ring stalls and catches up like a real transfer. */
const WEIGHTS = [1.25, 0.7, 1.45, 0.6, 1.0];
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
const DONE_SPRING = spring(0.4, 0.55);

export default function ProgressToast({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const zh = ctx.lang === "zh";
  const count = Math.min(Math.max(ctx.i("files"), 2), FILES.length);

  const [stage, setStage] = useState<Stage>("hidden");
  const [stageT, setStageT] = useState<Transition>(anim.easeIn(0.2));
  const [progressMV, progressTo, progressSet] = useAnimated(0);
  const [progress, setProgress] = useState(0);
  useMotionValueEvent(progressMV, "change", setProgress);
  const [finished, setFinished] = useState(0);
  const [finishedT, setFinishedT] = useState<Transition>(spring(0.35, 0.6));
  const [squeezes, setSqueezes] = useState(0);
  const stageRef = useRef<Stage>("hidden");
  const go = (next: Stage, t: Transition) => {
    stageRef.current = next;
    setStageT(t);
    setStage(next);
  };

  const start = (buzz = true) => {
    if (stageRef.current === "uploading") return;
    clearAll();
    const total = count;
    const upload = ctx.n("duration");
    const drop = spring(0.5, ctx.n("damping"));
    const preview = ctx.isPreview;
    if (buzz) haptics.tap();
    const run = () => {
      progressSet(0);
      setFinishedT({ duration: 0 });
      setFinished(0);
      go("uploading", drop);
      const weights = WEIGHTS.slice(0, total);
      const sum = weights.reduce((a, b) => a + b, 0);
      let at = 0.35;
      for (let index = 0; index < total; index++) {
        const segment = (upload * weights[index]) / sum;
        after(at, () => progressTo((index + 1) / total, anim.easeInOut(segment)));
        at += segment;
        if (index < total - 1) {
          after(at, () => {
            setFinishedT(spring(0.35, 0.6));
            setFinished(index + 1);
            if (buzz) haptics.selection();
          });
        }
      }
      after(at, () => {
        setFinishedT(DONE_SPRING);
        setFinished(total);
        go("done", DONE_SPRING);
        setSqueezes((n) => n + 1);
        if (buzz) haptics.success();
      });
      after(at + 1.4, () => {
        go("hidden", anim.easeIn(0.28));
        if (!preview) return;
        after(0.6, () => {
          setFinishedT(anim.smoothD(0.3));
          setFinished(0);
        });
      });
    };
    if (stageRef.current === "done") {
      // A tap while the result is still showing: let it leave first.
      go("hidden", anim.easeIn(0.2));
      after(0.25, run);
    } else run();
  };

  useAutoplay(ctx.isPreview, () => start(false), { every: ctx.n("duration") + 3.6, delay: 0.4 });

  const visible = stage !== "hidden";
  const done = stage === "done";
  const uploading = stage === "uploading";

  // The capsule is sized by its content: measure the one-line result to tighten around it.
  const doneLabel = zh ? `已上传 ${count} 个文件` : `${count} files uploaded`;
  const measure = useRef<HTMLSpanElement>(null);
  const [doneWidth, setDoneWidth] = useState(110);
  useLayoutEffect(() => {
    if (measure.current) setDoneWidth(Math.ceil(measure.current.offsetWidth));
  }, [doneLabel]);
  const textWidth = done ? doneWidth : 150;
  const toastWidth = 10 + 28 + 10 + textWidth + (done ? 16 : 18);

  const e = useElapsed(squeezes, 1.2, true);
  const squeeze = e < 0 ? 1 : track(e, 1, [{ cubic: 0.94, d: 0.14 }, { spring: 1, d: 0.45, ...SPRINGS.bouncy }]);
  const current = Math.min(finished + 1, count);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene width={300} height={300} cornerRadius={26}>
        {/* File card */}
        <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
          <div style={{ height: 68, flexShrink: 0, display: "flex", alignItems: "center", fontSize: 15, lineHeight: "20px", fontWeight: 600, color: Palette.secondaryLabel }}>
            {zh ? "共享文件夹" : "Shared folder"}
          </div>
          <div style={{ alignSelf: "stretch" }}>
            {FILES.slice(0, count).map((file, index) => {
              const isDone = index < finished;
              const isActive = uploading && index === finished;
              return (
                <motion.div
                  key={file.name}
                  initial={false}
                  animate={{ backgroundColor: Palette.labelAlpha(isActive ? 0.05 : 0) }}
                  transition={finishedT}
                  style={{ display: "flex", alignItems: "center", gap: 10, padding: "0 16px", height: 36 }}
                >
                  <div style={{ width: 24, height: 24, borderRadius: 7, background: gradientOf(file.tint), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{file.icon}</div>
                  <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{file.name}</span>
                  <div style={{ flex: 1 }} />
                  <div style={{ width: 60, flexShrink: 0, display: "flex", justifyContent: "flex-end" }}>
                    {/* A ZStack hugging the size text: the check sits centred over it. */}
                    <div style={{ position: "relative", display: "grid", placeItems: "center" }}>
                      <motion.span
                        initial={false}
                        animate={{ opacity: isDone ? 0 : isActive ? 1 : 0.6 }}
                        transition={finishedT}
                        style={{ fontSize: 11, lineHeight: "13px", fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}
                      >
                        {file.size}
                      </motion.span>
                      <AnimatePresence initial={false}>
                        {isDone && (
                          <motion.div
                            key="check"
                            initial={{ scale: 0.2, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 0.2, opacity: 0 }}
                            transition={finishedT}
                            style={{ position: "absolute", left: "50%", top: "50%", marginLeft: -9.5, marginTop: -9.5 }}
                          >
                            <svg width={19} height={19} viewBox="0 0 19 19">
                              <circle cx={9.5} cy={9.5} r={8} fill={Palette.green} />
                              <path d="M5.9 9.8 L8.5 12.3 L13.2 6.9" fill="none" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" style={{ stroke: "var(--ml-elevated)" }} />
                            </svg>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
          <div style={{ flex: 1 }} />
          <motion.button
            type="button"
            onClick={() => start()}
            initial={false}
            animate={{ opacity: uploading ? 0.45 : 1 }}
            transition={stageT}
            style={{ width: 268, height: 38, borderRadius: 19, marginBottom: 12, flexShrink: 0, background: PRIMARY_STRONG, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", gap: 6, fontSize: 15, lineHeight: "20px", fontWeight: 600 }}
          >
            <svg width={17} height={17} viewBox="0 0 17 17">
              <circle cx={8.5} cy={8.5} r={8.5} fill="#fff" />
              <path d="M8.5 12.6 V4.9 M5.2 8 L8.5 4.7 L11.8 8" fill="none" stroke="#5D50DC" strokeWidth={1.7} strokeLinecap="round" strokeLinejoin="round" />
            </svg>
            {zh ? `上传 ${count} 个文件` : `Upload ${count} files`}
          </motion.button>
        </div>

        {/* Toast */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 12, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{ scale: visible ? 1 : 0.8, filter: `blur(${visible ? 0 : 8}px)`, opacity: visible ? 1 : 0, y: visible ? 0 : -70 }}
            transition={stageT}
          >
            <div style={{ transform: `scale(${squeeze}, ${2 - squeeze})` }}>
              <motion.div
                initial={false}
                animate={{ width: toastWidth }}
                transition={stageT}
                style={{ position: "relative", height: 48, borderRadius: 24, background: hex(0x101014), boxShadow: `inset 0 0 0 0.5px ${white(0.12)}, 0 8px 16px ${black(0.28)}` }}
              >
                <div style={{ position: "absolute", left: 10, top: 10 }}>
                  <Ring progress={progress} done={done} />
                </div>
                <div style={{ position: "absolute", left: 48, top: 0, bottom: 0, display: "flex", alignItems: "center" }}>
                  <AnimatePresence initial={false}>
                    {done ? (
                      <motion.span
                        key="done"
                        initial={{ opacity: 0, filter: "blur(6px)", scale: 0.6 }}
                        animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                        exit={{ opacity: 0, filter: "blur(6px)", scale: 0.6 }}
                        transition={stageT}
                        style={{ position: "absolute", left: 0, transformOrigin: "left center", fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff", whiteSpace: "nowrap" }}
                      >
                        {doneLabel}
                      </motion.span>
                    ) : (
                      <motion.div
                        key="progress"
                        initial={{ opacity: 0, filter: "blur(6px)", scale: 0.6 }}
                        animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                        exit={{ opacity: 0, filter: "blur(6px)", scale: 0.6 }}
                        transition={stageT}
                        style={{ position: "absolute", left: 0, width: 150, transformOrigin: "left center", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1 }}
                      >
                        <span style={{ display: "flex", fontSize: 13, lineHeight: "18px", fontWeight: 600, color: "#fff", whiteSpace: "pre" }}>
                          {zh ? "正在上传 " : "Uploading "}
                          <NumericText value={current} />
                          {zh ? `/${count}` : ` of ${count}`}
                        </span>
                        <span style={{ display: "flex", gap: 4, width: 150, fontSize: 11, lineHeight: "13px", fontVariantNumeric: "tabular-nums", color: white(0.6), whiteSpace: "nowrap" }}>
                          <span style={{ overflow: "hidden", textOverflow: "ellipsis", minWidth: 0 }}>{FILES[Math.min(finished, count - 1)].name}</span>
                          <span>·</span>
                          <span>{Math.round(progress * 100)}%</span>
                        </span>
                      </motion.div>
                    )}
                  </AnimatePresence>
                </div>
              </motion.div>
            </div>
          </motion.div>
        </div>
        <span ref={measure} style={{ position: "absolute", left: 0, top: 0, visibility: "hidden", fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap", pointerEvents: "none" }}>
          {doneLabel}
        </span>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Tap Upload" zh="点击“上传”" />
    </div>
  );
}

function Ring({ progress, done }: { progress: number; done: boolean }) {
  // The ZStack takes the size of its largest child (the 31 pt disc), so the circles are 31 pt wide.
  const length = 2 * Math.PI * 15.5;
  return (
    <div style={{ position: "relative", width: 28, height: 28 }}>
      <svg width={28} height={28} viewBox="0 0 28 28" style={{ position: "absolute", inset: 0, overflow: "visible" }}>
        <defs>
          <linearGradient id="progress-toast-ring" gradientUnits="userSpaceOnUse" x1={14} y1={-1.5} x2={14} y2={29.5}>
            <stop offset="0" stopColor={Palette.sky} />
            <stop offset="1" stopColor={Palette.mint} />
          </linearGradient>
        </defs>
        <circle cx={14} cy={14} r={15.5} fill="none" stroke={white(0.16)} strokeWidth={3} />
        <motion.circle
          cx={14}
          cy={14}
          r={15.5}
          fill="none"
          stroke="url(#progress-toast-ring)"
          strokeWidth={3}
          strokeLinecap="round"
          strokeDasharray={`${length * progress} ${length}`}
          transform="rotate(-90 14 14)"
          initial={false}
          animate={{ opacity: done || progress <= 0 ? 0 : 1 }}
          transition={progress <= 0 ? { duration: 0 } : DONE_SPRING}
        />
      </svg>
      <motion.div
        initial={false}
        animate={{ scale: done ? 0.2 : 1, opacity: done ? 0 : 1 }}
        transition={DONE_SPRING}
        style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: "#fff" }}
      >
        <motion.div animate={{ y: [1.5, -1.5] }} transition={{ duration: 0.55, ease: [0.42, 0, 0.58, 1], repeat: Infinity, repeatType: "reverse" }}>
          <ArrowUp size={15} strokeWidth={3.3} />
        </motion.div>
      </motion.div>
      <motion.div
        initial={false}
        animate={{ scale: done ? 1 : 0.3, opacity: done ? 1 : 0 }}
        transition={DONE_SPRING}
        style={{ position: "absolute", left: -1.5, top: -1.5, width: 31, height: 31, borderRadius: "50%", background: `linear-gradient(${hex(0x4be08f)}, ${Palette.green})` }}
      />
      <svg width={12} height={9} viewBox="0 0 12 9" style={{ position: "absolute", left: 8, top: 9.5, overflow: "visible" }}>
        <motion.path
          d="M0 4.95 L4.32 9 L12 0"
          fill="none"
          stroke="#fff"
          strokeWidth={2.6}
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={false}
          animate={{ pathLength: done ? 1 : 0, opacity: done ? 1 : 0 }}
          transition={done ? { pathLength: { ...anim.easeOut(0.25), delay: 0.12 }, opacity: { duration: 0.01, delay: 0.12 } } : anim.linear(0.05)}
        />
      </svg>
    </div>
  );
}
