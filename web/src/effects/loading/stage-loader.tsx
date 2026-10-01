/** loading.stage-loader · 多阶段加载 (Loading+StageLoader.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, delayed, demoCard, fonts, spring, useClock, useHaptics, type DemoProps } from "../../kit";
import { popScale } from "./bar-shared";
import { TrimCircle, TrimPath, previewFps, primary, springSmooth, useAnimatedNumber, useTask, useTriggerElapsed } from "./shared";

const TITLES: [string, string][] = [
  ["Uploading…", "正在上传…"],
  ["Analyzing…", "正在分析…"],
  ["Rendering…", "正在渲染…"],
  ["Optimizing…", "正在优化…"],
  ["Publishing…", "正在发布…"],
];
const SHORT: [string, string][] = [
  ["Upload", "上传"],
  ["Analyze", "分析"],
  ["Render", "渲染"],
  ["Optimize", "优化"],
  ["Publish", "发布"],
];
/** The last stage is always "Publish", whatever the stage count. */
const slot = (index: number, count: number) => (index >= count - 1 ? TITLES.length - 1 : index);

const TRACK = 260;
const NODE = 22;
type NodeState = "pending" | "active" | "done";

export default function StageLoader({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const count = Math.min(Math.max(ctx.i("stages"), 1), TITLES.length);
  const progress = useAnimatedNumber(0);
  const [completedRaw, setCompleted] = useState(0);
  const [pops, setPops] = useState(0);
  const [run, setRun] = useState(0);
  const [t, setT] = useState<Transition>(springSmooth(0.4));
  const latest = useRef(ctx);
  latest.current = ctx;

  useTask(`${run}-${count}`, async (task) => {
    const live = !ctx.isPreview && run > 0;
    const total = count;
    setT(springSmooth(0.4));
    progress.to(0, springSmooth(0.4));
    setCompleted(0);
    await task.sleep(0.6);
    for (let stage = 0; stage < total; stage++) {
      const time = Math.max(latest.current.n("stage"), 0.2);
      progress.to((stage + 0.82) / total, anim.easeOut(time));
      await task.sleep(time);
      const s = spring(0.42, latest.current.n("damping"));
      setT(s);
      progress.to((stage + 1) / total, s);
      setCompleted(stage + 1);
      if (live) {
        if (stage === total - 1) haptics.success();
        else haptics.tap("light");
      }
      await task.sleep(0.3);
    }
    setPops((v) => v + 1);
    if (!ctx.isPreview) return;
    await task.sleep(1.8);
    setRun((v) => v + 1);
  });

  const completed = Math.min(completedRaw, count);
  const allDone = completed >= count;
  const stateOf = (index: number): NodeState => (index < completed ? "done" : index === completed ? "active" : "pending");
  const title = allDone ? (zh ? "全部完成" : "All done") : TITLES[slot(Math.min(completed, count - 1), count)][zh ? 1 : 0];
  const fill = TRACK * Math.min(Math.max(progress.value, 0), 1.05);
  const percent = Math.round(Math.min(Math.max(progress.value, 0), 1) * 100);
  const pop = popScale(useTriggerElapsed(pops, 0.8), 1.03, 0.14);
  const step = Math.min(completed + 1, count);

  return (
    <div
      onClick={() => {
        haptics.tap();
        setRun((v) => v + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 18 }}
    >
      <div style={{ ...demoCard(26), width: 300, padding: 20, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 18, transform: `scale(${pop})`, flex: "none" }}>
        <div style={{ display: "flex", alignItems: "center", alignSelf: "stretch" }}>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3 }}>
            <div style={{ position: "relative", height: 26, display: "grid", alignItems: "center", justifyItems: "start" }}>
              <AnimatePresence initial={false}>
                <motion.span
                  key={completed}
                  initial={{ y: 16, opacity: 0, filter: "blur(5px)" }}
                  animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
                  exit={{ y: -16, opacity: 0, filter: "blur(5px)" }}
                  transition={t}
                  style={{ gridArea: "1 / 1", fontSize: 20, lineHeight: "25px", fontWeight: 600, whiteSpace: "nowrap", color: allDone ? Palette.green : Palette.label }}
                >
                  {title}
                </motion.span>
              </AnimatePresence>
            </div>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>
              <NumericText value={step} text={zh ? `第 ${step} 步，共 ${count} 步` : `Step ${step} of ${count}`} />
            </span>
          </div>
          <span style={{ flex: 1 }} />
          <span style={{ fontFamily: fonts.rounded, fontSize: 22, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: allDone ? Palette.green : Palette.label }}>{percent}%</span>
        </div>
        <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 8 }}>
          <div style={{ position: "relative", width: TRACK, height: 30 }}>
            <div style={{ position: "absolute", left: 0, top: 12, width: TRACK, height: 6, borderRadius: 3, background: primary(0.08) }} />
            <div
              style={{
                position: "absolute",
                left: 0,
                top: 12,
                width: Math.max(fill, 6),
                height: 6,
                borderRadius: 3,
                background: `linear-gradient(90deg, ${Palette.mint}, ${Palette.sky})`,
                boxShadow: `0 0 10px ${alpha(allDone ? Palette.green : Palette.sky, 0.5)}`,
                transition: "box-shadow 0.3s ease-out",
                overflow: "hidden",
              }}
            >
              <div style={{ position: "absolute", inset: 0, background: Palette.green, opacity: allDone ? 1 : 0, transition: "opacity 0.3s cubic-bezier(0, 0, 0.58, 1)" }} />
            </div>
            {Array.from({ length: count }, (_, index) => (
              <div key={index} style={{ position: "absolute", left: (TRACK * (index + 1)) / count - NODE, top: 4 }}>
                <StageNode index={index} state={stateOf(index)} preview={ctx.isPreview} transition={t} />
              </div>
            ))}
          </div>
          <div style={{ display: "flex", width: TRACK }}>
            {Array.from({ length: count }, (_, index) => {
              const pending = stateOf(index) === "pending";
              return (
                <span
                  key={index}
                  style={{
                    width: TRACK / count,
                    textAlign: "right",
                    fontSize: 11,
                    lineHeight: "13px",
                    whiteSpace: "nowrap",
                    fontWeight: pending ? 400 : 600,
                    color: pending ? Palette.secondaryLabel : Palette.label,
                  }}
                >
                  {SHORT[slot(index, count)][zh ? 1 : 0]}
                </span>
              );
            })}
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to restart" zh="点击重新开始" />
    </div>
  );
}

function StageNode({ index, state, preview, transition }: { index: number; state: NodeState; preview: boolean; transition: Transition }) {
  const done = state === "done";
  const [kick, setKick] = useState(0);
  const was = useRef(done);
  useEffect(() => {
    if (done && !was.current) setKick((v) => v + 1);
    was.current = done;
  }, [done]);
  const scale = popScale(useTriggerElapsed(kick, 0.8), 1.28, 0.12);
  return (
    <div
      style={{
        position: "relative",
        width: NODE,
        height: NODE,
        borderRadius: "50%",
        transform: `scale(${scale})`,
        boxShadow: `0 2px 10px ${alpha(Palette.green, done ? 0.45 : 0)}`,
        transition: "box-shadow 0.3s",
      }}
    >
      <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.elevated }} />
      <motion.div
        initial={false}
        animate={{ opacity: state === "pending" ? 1 : 0 }}
        transition={transition}
        style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 1.5px ${primary(0.14)}` }}
      />
      <AnimatePresence>
        {state === "active" && (
          <motion.div key="spin" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={transition} style={{ position: "absolute", inset: 0 }}>
            <Spinner preview={preview} />
          </motion.div>
        )}
      </AnimatePresence>
      <motion.div
        initial={false}
        animate={{ scale: done ? 1 : 0.01, opacity: done ? 1 : 0 }}
        transition={transition}
        style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `linear-gradient(135deg, ${Palette.mint}, ${Palette.green})` }}
      />
      <motion.span
        initial={false}
        animate={{ opacity: done ? 0 : 1 }}
        transition={transition}
        style={{
          position: "absolute",
          inset: 0,
          display: "grid",
          placeItems: "center",
          fontFamily: fonts.rounded,
          fontSize: 10,
          fontWeight: 700,
          color: state === "active" ? Palette.label : Palette.secondaryLabel,
        }}
      >
        {index + 1}
      </motion.span>
      <Check done={done} />
    </div>
  );
}

function Check({ done }: { done: boolean }) {
  const trim = useAnimatedNumber(0);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    trim.to(done ? 1 : 0, done ? delayed(anim.easeOut(0.25), 0.08) : anim.easeOut(0.15));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [done]);
  return (
    <TrimPath
      d={`M ${10 * 0.08} ${8 * 0.55} L ${10 * 0.38} ${8 - 8 * 0.08} L ${10 - 10 * 0.06} ${8 * 0.1}`}
      width={10}
      height={8}
      trim={trim.value}
      color="#fff"
      lineWidth={2.2}
      style={{ position: "absolute", left: 6, top: 7 }}
    />
  );
}

function Spinner({ preview }: { preview: boolean }) {
  useClock(true, previewFps(preview));
  const turn = (Date.now() / 800) % 1;
  return (
    <>
      <div style={{ position: "absolute", inset: 0, borderRadius: "50%", boxShadow: `inset 0 0 0 2px ${alpha(Palette.sky, 0.22)}` }} />
      <TrimCircle size={NODE} lineWidth={2} inset={1} from={0} to={0.3} color={Palette.sky} rotate={turn * 360} />
    </>
  );
}
