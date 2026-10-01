/** gestures.pull-to-create · 下拉新建 (Gestures+PullToCreate.swift) */
import { animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, anim, black, clamp, fonts, forever, rubberBand, spring, useAutoplay, useHaptics, usePan, useTimeouts, type DemoProps } from "../../kit";
import { useGhost } from "./_sim-kit";

type Task = { id: number; en: string; zh: string };

const SEED: [string, string][] = [
  ["Reply to Mina", "回复小敏"],
  ["Renew passport", "续签护照"],
  ["Fix the tab bar bug", "修复标签栏问题"],
  ["Book dentist", "预约牙医"],
  ["Plan the weekend", "安排周末"],
];
const NEW: [string, string][] = [
  ["Buy coffee beans", "买咖啡豆"],
  ["Call the landlord", "给房东打电话"],
  ["Ship version 2.0", "发布 2.0 版本"],
  ["Water the plants", "给植物浇水"],
];
const WIDTH = 280;

/** Heat-map tint for a (fractional) row position. */
function heat(position: number): string {
  const t = clamp(position / 5, 0, 1);
  const top = [0.93, 0.2, 0.3];
  const bottom = [1.0, 0.7, 0.22];
  const c = top.map((v, i) => Math.round((v + (bottom[i] - v) * t) * 255));
  return `rgb(${c[0]},${c[1]},${c[2]})`;
}

/** How far the list really moves for a raw pull: 1:1 up to one row, rubber-banded beyond. */
const displayed = (pull: number, row: number) => (pull <= row ? pull : row + rubberBand(pull - row, 110));

export default function PullToCreate({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const timers = useTimeouts();
  const [items, setItems] = useState<Task[]>(() => SEED.map(([en, zh], id) => ({ id, en, zh })));
  const pull = useMotionValue(0);
  const [armed, setArmed] = useState(false);
  const armedRef = useRef(false);
  const [committing, setCommitting] = useState(false);
  const committingRef = useRef(false);
  const held = useRef(false);
  const nextID = useRef(100);
  const [typing, setTyping] = useState<{ id: number; typed: number } | null>(null);
  const row = ctx.n("row");
  const perspective = ctx.n("perspective");
  const rowRef = useRef(row);
  rowRef.current = row;

  /** Finger (or ghost finger) moved: `translation` is the vertical drag distance. */
  const dragChanged = (translation: number) => {
    pull.stop();
    pull.set(Math.max(translation, 0));
    const nowArmed = pull.get() >= ctx.n("row") * ctx.n("threshold");
    if (nowArmed !== armedRef.current) {
      armedRef.current = nowArmed;
      setArmed(nowArmed);
      if (held.current) haptics.tap("medium");
    }
  };

  /** Swaps the unfolded placeholder for a real row. Nothing moves: the two look identical. */
  const finishCommit = () => {
    const [en, zh] = NEW[nextID.current % NEW.length];
    const task: Task = { id: nextID.current, en, zh };
    nextID.current += 1;
    setItems((list) => [task, ...list].slice(0, 5));
    pull.stop();
    pull.jump(0);
    armedRef.current = false;
    setArmed(false);
    committingRef.current = false;
    setCommitting(false);
    setTyping({ id: task.id, typed: 0 });
    if (!ghost.scripted) haptics.success();
    const length = [...ctx.t(en, zh)].length;
    timers.clearAll();
    for (let count = 0; count <= length; count++) timers.after(0.035 * (count + 1), () => setTyping({ id: task.id, typed: count }));
    timers.after(0.035 * (length + 1) + 0.5, () => setTyping(null));
  };

  const release = () => {
    held.current = false;
    if (committingRef.current) return;
    if (armedRef.current) {
      committingRef.current = true;
      setCommitting(true);
      animate(pull, rowRef.current, spring(0.3, 0.85));
      // `completionCriteria: .logicallyComplete`: the spring's response time.
      window.setTimeout(finishCommit, 300);
    } else animate(pull, 0, spring(0.38, 0.82));
  };

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        if (committingRef.current) return;
        if (!held.current) {
          held.current = true;
          ghost.touch();
        }
        dragChanged(translation.y);
      },
      onEnd: () => {
        if (held.current) release();
      },
    },
    6,
  );

  /** A scripted finger pulls past the threshold and lets go, through the same handlers as the drag. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (held.current || committingRef.current || pull.get() !== 0) return;
      const reach = ctx.n("row") * Math.max(ctx.n("threshold"), 1) + 16;
      ghost.run(async (g) => {
        if (!(await g.drag({ x: 0, y: 0 }, { x: 0, y: reach }, 0.85, (p) => dragChanged(p.y)))) return;
        if (!(await g.sleep(0.22))) return;
        release();
      });
    },
    { every: 2.6, delay: 0.5 },
  );

  const listY = useTransform(pull, (p) => displayed(p, row));
  const hingeShade = useTransform(pull, (p) => 0.3 * (1 - Math.min(p, row) / Math.max(row, 1)));
  const foldTransform = useTransform(pull, (p) => {
    const open = clamp(Math.min(p, row) / Math.max(row, 1), 0, 1);
    return `translateY(${displayed(p, row) - row}px) perspective(${WIDTH / Math.max(perspective, 0.01)}px) rotateX(${Math.acos(open)}rad)`;
  });
  const foldShade = useTransform(pull, (p) => 0.55 * (1 - clamp(Math.min(p, row) / Math.max(row, 1), 0, 1)));
  const foldOpacity = useTransform(pull, (p) => (p > 0.5 ? 1 : 0));

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div
        {...pan}
        style={{
          ...pan.style,
          position: "relative",
          width: WIDTH,
          height: row * 5,
          borderRadius: 26,
          overflow: "hidden",
          background: black(0.82),
          boxShadow: `0 10px 16px ${black(0.14)}`,
          flex: "none",
          cursor: "grab",
        }}
      >
        <motion.div style={{ position: "absolute", left: 0, right: 0, top: 0, y: listY }}>
          {items.map((item, index) => {
            const full = ctx.t(item.en, item.zh);
            const isTyping = typing?.id === item.id;
            return (
              <Tinted key={item.id} position={index} pull={pull} row={row}>
                <Row text={isTyping ? [...full].slice(0, typing.typed).join("") : full} caret={isTyping} height={row} />
              </Tinted>
            );
          })}
          {/* The folded row shades the list just under its hinge. */}
          <motion.div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 14, background: `linear-gradient(180deg, #000, transparent)`, opacity: hingeShade, pointerEvents: "none" }} />
        </motion.div>

        <motion.div style={{ position: "absolute", left: 0, right: 0, top: 0, height: row, background: heat(0), transformOrigin: "50% 100%", transform: foldTransform, opacity: foldOpacity }}>
          <Row text={armed || committing ? ctx.t("Release to create", "松手创建") : ctx.t("Pull to create", "下拉新建")} caret={false} height={row} dim={committing} />
          <motion.div style={{ position: "absolute", inset: 0, background: "#000", opacity: foldShade }} />
        </motion.div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 26, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Pull the list down" zh="把列表往下拉" />
    </div>
  );
}

/** Row tint that slides down the heat map as the new row makes room above. */
function Tinted({ position, pull, row, children }: { position: number; pull: MotionValue<number>; row: number; children: React.ReactNode }) {
  const background = useTransform(pull, (p) => heat(position + Math.min(p, row) / Math.max(row, 1)));
  return <motion.div style={{ background }}>{children}</motion.div>;
}

function Row({ text, caret, height, dim = false }: { text: string; caret: boolean; height: number; dim?: boolean }) {
  return (
    <div style={{ position: "relative", height, padding: "0 18px", display: "flex", alignItems: "center", boxShadow: `inset 0 -1px 0 ${black(0.14)}` }}>
      <div style={{ display: "flex", alignItems: "center", gap: 2, opacity: dim ? 0 : 1, minWidth: 0 }}>
        <span style={{ fontFamily: fonts.text, fontSize: 16, fontWeight: 600, color: "#fff", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{text}</span>
        {caret && (
          <motion.span
            initial={{ opacity: 1 }}
            animate={{ opacity: 0.15 }}
            transition={forever(anim.easeInOut(0.45))}
            style={{ width: 2, height: 18, borderRadius: 1, background: "#fff", flex: "none" }}
          />
        )}
      </div>
    </div>
  );
}
