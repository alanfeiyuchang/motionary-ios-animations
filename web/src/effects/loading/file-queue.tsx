/** loading.file-queue · 文件上传队列 (Loading+FileQueue.swift) */
import { motion, type Transition } from "motion/react";
import { ArrowUp, AudioLines, Check, Clock, CloudUpload, FileText, Film, Image as ImageIcon, Presentation, type LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, SymbolBounce, alpha, anim, demoCard, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { popScale } from "./bar-shared";
import { TrimCircle, TrimPath, makeRun, primary, springSmooth, useAnimatedNumber, useTriggerElapsed, type Run } from "./shared";

interface QueueFile {
  name: string;
  size: string;
  icon: LucideIcon;
  color: string;
  /** Relative upload time. */
  weight: number;
}
const FILES: QueueFile[] = [
  { name: "Keynote-final.key", size: "48.2 MB", icon: Presentation, color: Palette.coral, weight: 1.0 },
  { name: "IMG_2041.heic", size: "6.4 MB", icon: ImageIcon, color: Palette.sky, weight: 0.7 },
  { name: "demo-reel.mov", size: "212 MB", icon: Film, color: Palette.violet, weight: 1.3 },
  { name: "notes.pdf", size: "1.1 MB", icon: FileText, color: Palette.amber, weight: 0.6 },
  { name: "mix-v3.wav", size: "34 MB", icon: AudioLines, color: Palette.mint, weight: 0.9 },
];
type Phase = "waiting" | "uploading" | "done";
const fill = <T,>(v: T) => FILES.map(() => v);

export default function FileQueue({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const p0 = useAnimatedNumber(0);
  const p1 = useAnimatedNumber(0);
  const p2 = useAnimatedNumber(0);
  const p3 = useAnimatedNumber(0);
  const p4 = useAnimatedNumber(0);
  const progress = [p0, p1, p2, p3, p4];
  const [phases, setPhases] = useState<Phase[]>(fill<Phase>("waiting"));
  const [collapsed, setCollapsed] = useState<boolean[]>(fill(false));
  const [finished, setFinished] = useState(false);
  const [pops, setPops] = useState<number[]>(fill(0));
  const [t, setT] = useState<Transition>(springSmooth(0.25));
  const task = useRef<Run | null>(null);
  const busy = useRef(false);
  const muted = useRef(false);
  const state = useRef({ phases, finished });
  state.current = { phases, finished };
  const latest = useRef(ctx);
  latest.current = ctx;
  useEffect(() => () => task.current?.cancel(), []);

  const count = Math.min(Math.max(ctx.i("files"), 1), FILES.length);

  const start = () => {
    task.current?.cancel();
    const c = latest.current;
    const files = Math.min(Math.max(c.i("files"), 1), FILES.length);
    const upload = Math.max(c.n("upload"), 0.2);
    const damping = c.n("damping");
    const collapses = c.b("collapse");
    const dirty = state.current.finished || state.current.phases.some((p) => p !== "waiting");
    const buzz = !c.isPreview && !muted.current;
    const run = makeRun();
    task.current = run;
    busy.current = true;
    const phaseAt = (index: number, value: Phase) => setPhases((list) => list.map((v, i) => (i === index ? value : v)));
    (async () => {
      if (dirty) {
        const reset = spring(0.45, 0.85);
        setT(reset);
        progress.forEach((p) => p.to(0, reset));
        setPhases(fill<Phase>("waiting"));
        setCollapsed(fill(false));
        setFinished(false);
        await run.sleep(0.6);
      }
      for (let index = 0; index < files; index++) {
        const duration = upload * FILES[index].weight;
        setT(springSmooth(0.25));
        phaseAt(index, "uploading");
        progress[index].to(1, anim.curve(0.3, 0, 0.3, 1, duration));
        await run.sleep(duration);
        setT(springSmooth(0.3));
        phaseAt(index, "done");
        setPops((list) => list.map((v, i) => (i === index ? v + 1 : v)));
        if (buzz) haptics.tap();
        await run.sleep(0.45);
        if (collapses) {
          setT(spring(0.45, damping));
          setCollapsed((list) => list.map((v, i) => (i === index ? true : v)));
          await run.sleep(0.22);
        }
      }
      setT(spring(0.45, 0.7));
      setFinished(true);
      if (buzz) haptics.success();
      // Hold the result before the queue may be started again.
      await run.sleep(1.6);
      busy.current = false;
    })().catch(() => {});
  };

  // Only an idle queue is started, so a run is never cut short.
  useAutoplay(
    ctx.isPreview,
    () => {
      if (busy.current) return;
      muted.current = true;
      start();
      muted.current = false;
    },
    { every: 1.2, delay: 0.5 },
  );

  const doneCount = phases.slice(0, count).filter((p) => p === "done").length;
  const current = Math.min(doneCount + 1, count);
  const overall = progress.slice(0, count).reduce((sum, p) => sum + p.value, 0) / count;
  const tint = finished ? Palette.green : Palette.blue;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={() => {
          haptics.tap();
          start();
        }}
        style={{ ...demoCard(24), width: 300, display: "flex", flexDirection: "column", flex: "none", cursor: "pointer" }}
      >
        <div style={{ height: 54, padding: "0 14px", display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ position: "relative", width: 26, height: 26, flex: "none" }}>
            <TrimCircle size={26} lineWidth={3.5} color={primary(0.1)} />
            <TrimCircle size={26} lineWidth={3.5} to={Math.min(Math.max(overall, 0), 1)} color={tint} rotate={-90} />
            <motion.div
              initial={false}
              animate={{ scale: finished ? 1 : 0.2, opacity: finished ? 1 : 0 }}
              transition={t}
              style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: Palette.green }}
            >
              <Check size={12} strokeWidth={4.2} />
            </motion.div>
          </div>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 1 }}>
            <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{finished ? (zh ? "全部上传完成" : "All uploaded") : zh ? "正在上传" : "Uploading"}</span>
            <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums", display: "flex", gap: 3, whiteSpace: "nowrap" }}>
              {finished ? (
                zh ? `${count} 个文件已同步到云端` : `${count} files synced to the cloud`
              ) : (
                <>
                  {zh && <span>第</span>}
                  <NumericText value={current} />
                  <span>{zh ? `/ ${count} 个` : `of ${count}`}</span>
                </>
              )}
            </span>
          </div>
          <span style={{ flex: 1 }} />
          <SymbolBounce trigger={finished} style={{ color: tint, transition: "color 0.3s" }}>
            <CloudUpload size={21} strokeWidth={2.4} />
          </SymbolBounce>
        </div>
        {FILES.slice(0, count).map((file, index) => {
          const hidden = collapsed[index];
          return (
            <motion.div
              key={file.name}
              initial={false}
              animate={{ height: hidden ? 0 : 52, scale: hidden ? 0.94 : 1, opacity: hidden ? 0 : 1 }}
              transition={t}
              style={{ overflow: "hidden", transformOrigin: "50% 0%", flex: "none" }}
            >
              <Row file={file} progress={progress[index].value} phase={phases[index]} pops={pops[index]} zh={zh} transition={t} />
            </motion.div>
          );
        })}
        <div style={{ height: 6 }} />
      </div>
      <DemoHint ctx={ctx} en="Tap to upload again" zh="点击重新上传" />
    </div>
  );
}

function Row({ file, progress, phase, pops, zh, transition }: { file: QueueFile; progress: number; phase: Phase; pops: number; zh: boolean; transition: Transition }) {
  const active = phase === "uploading";
  const done = phase === "done";
  const waiting = phase === "waiting";
  const Icon = file.icon;
  const pop = popScale(useTriggerElapsed(pops, 0.8), 1.18, 0.12);
  const trim = useAnimatedNumber(0);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    trim.to(done ? 1 : 0, transition);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [done]);
  const shown = Math.min(Math.max(progress, 0), 1);
  return (
    <motion.div initial={false} animate={{ opacity: waiting ? 0.62 : 1 }} transition={transition} style={{ height: 52, padding: "0 14px", display: "flex", alignItems: "center", gap: 11 }}>
      <div
        style={{
          width: 34,
          height: 34,
          borderRadius: 10,
          background: alpha(file.color, waiting ? 0.16 : 0.24),
          transition: "background 0.25s",
          color: file.color,
          display: "grid",
          placeItems: "center",
          flex: "none",
        }}
      >
        <Icon size={16} strokeWidth={2.4} />
      </div>
      <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 5 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{file.name}</span>
          <span style={{ flex: 1 }} />
          <span
            style={{
              fontSize: 12,
              lineHeight: "16px",
              fontWeight: 500,
              fontVariantNumeric: "tabular-nums",
              whiteSpace: "nowrap",
              color: done ? Palette.green : active ? Palette.label : Palette.secondaryLabel,
            }}
          >
            {done ? (zh ? "完成" : "Done") : active ? `${Math.round(shown * 100)}%` : file.size}
          </span>
        </div>
        <div style={{ position: "relative", height: 3, borderRadius: 1.5, background: primary(0.1) }}>
          <div
            style={{
              position: "absolute",
              inset: 0,
              borderRadius: 1.5,
              background: done ? Palette.green : `linear-gradient(90deg, ${Palette.sky}, ${Palette.blue})`,
              transform: `scaleX(${Math.max(progress, 0)})`,
              transformOrigin: "0 50%",
            }}
          />
        </div>
      </div>
      <div style={{ position: "relative", width: 22, height: 22, flex: "none", transform: `scale(${pop})` }}>
        <motion.div initial={false} animate={{ opacity: waiting ? 1 : 0 }} transition={transition} style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: Palette.tertiaryLabel }}>
          <Clock size={14} strokeWidth={2.4} />
        </motion.div>
        <motion.div
          initial={false}
          animate={{ opacity: active ? 1 : 0, y: active ? 0 : 6 }}
          transition={transition}
          style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", color: Palette.blue }}
        >
          <ArrowUp size={14} strokeWidth={3.4} />
        </motion.div>
        <motion.div initial={false} animate={{ scale: done ? 1 : 0.3, opacity: done ? 1 : 0 }} transition={transition} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.green }} />
        <TrimPath d="M 0 4.4 L 3.6 8 L 10 0" width={10} height={8} trim={Math.min(Math.max(trim.value, 0), 1)} color="#fff" lineWidth={2.2} style={{ position: "absolute", left: 6, top: 7 }} />
      </div>
    </motion.div>
  );
}
