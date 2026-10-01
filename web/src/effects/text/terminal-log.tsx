/** text.terminal-log · 终端日志流 (Text+TerminalLog.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, anim, black, fonts, hex, useClock, useHaptics, useLatest, white, type DemoProps } from "../../kit";
import { randIn, useTask } from "./_text-kit";
import { usePulse } from "./_fx";

type Tag = "ok" | "warn" | "info";
type Kind = "command" | "log" | "result" | "note";
interface Line {
  id: number;
  kind: Kind;
  text: string;
  tag: Tag;
  resolved: boolean;
}
interface Step {
  tag: Tag;
  running: string;
  done: string;
  progress?: boolean;
  work: number;
}
const TAGS: Record<Tag, { label: string; color: string }> = {
  ok: { label: " OK ", color: hex(0x3ddc84) },
  warn: { label: "WARN", color: hex(0xffc247) },
  info: { label: "INFO", color: hex(0x4fb8ff) },
};
const MAX_LINES = 9;
const LINE_HEIGHT = 19;
const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function scripts(zh: boolean): { command: string; steps: Step[]; summary: string }[] {
  return [
    {
      command: "motionary build --release",
      steps: [
        { tag: "info", running: zh ? "解析依赖" : "Resolving packages", done: zh ? "已解析 42 个依赖" : "Resolved 42 packages", work: 0.35 },
        { tag: "ok", running: zh ? "编译" : "Compiling", done: zh ? "已编译 214 个文件" : "Compiled 214 files", progress: true, work: 1.1 },
        { tag: "warn", running: zh ? "检查资源" : "Checking assets", done: zh ? "3 个资源未被引用" : "3 assets are unused", work: 0.4 },
        { tag: "ok", running: zh ? "链接" : "Linking", done: zh ? "已链接 MotionLab" : "Linked MotionLab", work: 0.45 },
        { tag: "ok", running: zh ? "签名" : "Signing", done: zh ? "已签名 · 18.4 MB" : "Signed · 18.4 MB", work: 0.3 },
      ],
      summary: zh ? "✓ 构建完成，用时 4.2 秒" : "✓ Build finished in 4.2s",
    },
    {
      command: "motionary test --ui",
      steps: [
        { tag: "info", running: zh ? "启动模拟器" : "Booting simulator", done: zh ? "模拟器已就绪" : "Simulator ready", work: 0.5 },
        { tag: "ok", running: zh ? "运行界面测试" : "Running UI tests", done: zh ? "128 项测试通过" : "128 tests passed", progress: true, work: 1.2 },
        { tag: "warn", running: zh ? "重试" : "Retrying", done: zh ? "1 项不稳定，重试后通过" : "1 flaky test retried", work: 0.45 },
        { tag: "ok", running: zh ? "比对截图" : "Diffing snapshots", done: zh ? "截图无差异" : "Snapshots are clean", work: 0.4 },
      ],
      summary: zh ? "✓ 全部通过，用时 12.8 秒" : "✓ All green in 12.8s",
    },
  ];
}

export default function TerminalLog({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const store = useRef<{ lines: Line[]; nextID: number; typing: boolean; running: boolean; round: number }>({
    lines: [{ id: 0, kind: "command", text: "", tag: "ok", resolved: true }],
    nextID: 1,
    typing: false,
    running: false,
    round: 0,
  });
  const [lines, setLines] = useState<Line[]>(store.current.lines);
  const [typing, setTypingState] = useState(false);
  const [running, setRunningState] = useState(false);
  const [runs, setRuns] = useState(0);
  const live = useLatest({ speed: ctx.n("speed"), interval: ctx.n("interval"), zh: ctx.lang === "zh" });

  const commit = () => setLines(store.current.lines.slice());
  const setTyping = (v: boolean) => {
    store.current.typing = v;
    setTypingState(v);
  };
  const setRunning = (v: boolean) => {
    store.current.running = v;
    setRunningState(v);
  };
  const append = (kind: Kind, text: string, tag: Tag = "ok", resolved = true) => {
    const s = store.current;
    const id = s.nextID++;
    s.lines = [...s.lines, { id, kind, text, tag, resolved }];
    if (s.lines.length > 40) s.lines = s.lines.slice(s.lines.length - 40);
    commit();
    return id;
  };
  const update = (id: number, change: (line: Line) => Line) => {
    const s = store.current;
    s.lines = s.lines.map((line) => (line.id === id ? change(line) : line));
    commit();
  };

  useTask(runs, async (sleep) => {
    const s = store.current;
    // Interrupted mid-run: leave a ^C and open a fresh prompt.
    if (s.running || s.typing) {
      s.lines = s.lines.map((line) => (line.resolved ? line : { ...line, resolved: true, tag: "warn" as Tag }));
      append("note", "^C");
      append("command", "");
      setRunning(false);
      setTyping(false);
    }
    for (;;) {
      const all = scripts(live.current.zh);
      const script = all[s.round % all.length];
      if (!(await sleep(0.7))) return;
      s.round += 1;

      // Type the command on the waiting prompt line.
      const lastLine = s.lines[s.lines.length - 1];
      const promptID = lastLine?.kind === "command" ? lastLine.id : append("command", "");
      setTyping(true);
      for (const character of script.command) {
        update(promptID, (line) => ({ ...line, text: line.text + character }));
        const base = 1 / Math.max(live.current.speed, 1);
        const factor = character === " " ? 2.2 : randIn(0.5, 1.6);
        if (!(await sleep(base * factor))) return;
      }
      if (!(await sleep(0.28))) return;
      setTyping(false);
      setRunning(true);

      for (const step of script.steps) {
        const id = append("log", step.running + (step.progress ? "" : "…"), step.tag, false);
        if (step.progress) {
          const ticks = 14;
          for (let tick = 0; tick <= ticks; tick++) {
            const filled = Math.floor((tick * 10) / ticks);
            const bar = "▰".repeat(filled) + "▱".repeat(10 - filled);
            const percent = `${String(Math.floor((tick * 100) / ticks)).padStart(3, " ")}%`;
            update(id, (line) => ({ ...line, text: `${step.running} ${bar} ${percent}` }));
            if (!(await sleep(step.work / ticks))) return;
          }
        } else if (!(await sleep(step.work))) return;
        update(id, (line) => ({ ...line, text: step.done, resolved: true }));
        if (!(await sleep(live.current.interval))) return;
      }
      append("result", script.summary);
      setRunning(false);
      if (!(await sleep(0.5))) return;
      append("command", "");
      if (!(await sleep(1.9))) return;
    }
  });

  const visible = lines.slice(-MAX_LINES);
  const lastID = lines[lines.length - 1]?.id ?? -1;
  const mono = { fontFamily: fonts.mono, fontSize: 12.5, fontWeight: 500 } as const;
  const textColor = (line: Line) => (line.kind === "command" ? white(0.95) : line.kind === "log" ? white(line.resolved ? 0.8 : 0.55) : line.kind === "result" ? hex(0x3ddc84) : white(0.45));

  return (
    <div
      onClick={() => {
        haptics.tap("rigid");
        setRuns((r) => r + 1);
      }}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12, cursor: "pointer" }}
    >
      <div style={{ width: 304, borderRadius: 16, background: hex(0x12141a), overflow: "hidden", boxShadow: `inset 0 0 0 1px ${white(0.1)}, 0 10px 36px ${black(0.28)}` }}>
        <div style={{ position: "relative", height: 32, padding: "0 13px", background: white(0.06), display: "flex", alignItems: "center", justifyContent: "center" }}>
          <div style={{ position: "absolute", left: 13, top: 11, display: "flex", gap: 7 }}>
            {[0xff5f57, 0xfebc2e, 0x28c840].map((c) => (
              <span key={c} style={{ width: 10, height: 10, borderRadius: "50%", background: hex(c) }} />
            ))}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
            <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 600, color: white(0.55) }}>zsh — motionary</span>
            <span style={{ width: 5, height: 5, borderRadius: "50%", background: hex(0x3ddc84), opacity: running ? 1 : 0, transition: "opacity 0.2s ease-in-out" }} />
          </div>
        </div>
        <div style={{ padding: "11px 14px" }}>
          <div style={{ position: "relative", width: 276, height: LINE_HEIGHT * MAX_LINES }}>
            <AnimatePresence initial={false}>
              {visible.map((line, index) => (
                <motion.div
                  key={line.id}
                  initial={{ y: index * LINE_HEIGHT + 8, opacity: 0 }}
                  animate={{ y: index * LINE_HEIGHT, opacity: 1 }}
                  exit={{ opacity: 0 }}
                  transition={anim.easeOut(0.2)}
                  style={{ position: "absolute", left: 0, top: 0, width: 276, height: LINE_HEIGHT, display: "flex", alignItems: "center", gap: 7, whiteSpace: "pre" }}
                >
                  {line.kind === "command" && <span style={{ ...mono, fontWeight: 800, color: hex(0x3ddc84) }}>❯</span>}
                  {line.kind === "log" && <TagView tag={line.tag} resolved={line.resolved} />}
                  <div style={{ display: "flex", alignItems: "center", gap: 1, minWidth: 0 }}>
                    <span style={{ ...mono, color: textColor(line), overflow: "hidden", textOverflow: "ellipsis" }}>{line.text}</span>
                    {line.id === lastID && line.kind === "command" && <Caret style={ctx.i("caret")} blinking={!typing} />}
                  </div>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to interrupt and run the next command" zh="点击中断并运行下一条命令" />
    </div>
  );
}

function TagView({ tag, resolved }: { tag: Tag; resolved: boolean }) {
  const p = usePulse(resolved ? 1 : 0, 0.5);
  const box = { width: 40, height: 15, flex: "none", display: "flex", alignItems: "center", justifyContent: "center", fontFamily: fonts.mono, fontSize: 11, fontWeight: 800, whiteSpace: "pre" } as const;
  if (!resolved) return <Spinner style={box} />;
  const decay = (1 - p) * (1 - p);
  const { label, color } = TAGS[tag];
  return (
    <span style={{ ...box, position: "relative", color: decay > 0.5 ? hex(0x12141a) : color }}>
      <span style={{ position: "absolute", inset: 0, borderRadius: 4, background: color, opacity: 0.16 + 0.84 * decay }} />
      <span style={{ position: "relative" }}>{label}</span>
    </span>
  );
}

function Spinner({ style }: { style: React.CSSProperties }) {
  const t = useClock(true, 15);
  return <span style={{ ...style, color: white(0.45) }}>{`[ ${SPINNER[Math.floor(t / 0.08) % SPINNER.length]} ]`}</span>;
}

function Caret({ style, blinking }: { style: number; blinking: boolean }) {
  const t = useClock(blinking, 12);
  const on = !blinking || Math.floor(t / 0.25) % 2 === 0;
  const color = white(0.9);
  return (
    <span style={{ position: "relative", width: 9, height: 15, flex: "none", opacity: on ? 1 : 0 }}>
      {style === 1 ? (
        <span style={{ position: "absolute", left: 0, top: 0, width: 2, height: 15, background: color }} />
      ) : style === 2 ? (
        <span style={{ position: "absolute", left: 0.5, bottom: 0, width: 8, height: 2, background: color }} />
      ) : (
        <span style={{ position: "absolute", left: 0.5, top: 0, width: 8, height: 15, background: color }} />
      )}
    </span>
  );
}
