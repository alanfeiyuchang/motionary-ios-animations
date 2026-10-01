/** gestures.kanban-drag · 看板拖拽 (Gestures+KanbanDrag.swift) */
import { animate, motion, useMotionValue, useTransform, type MotionValue } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, black, clamp, fonts, spring, useAutoplay, useHaptics, usePan, type DemoProps, type Point } from "../../kit";
import { labelColor, useGhost } from "./_sim-kit";

const COLUMN = 94;
const GUTTER = 9;
const HEADER = 36;
const CARD = { w: 86, h: 52 };
const SPACING = 8;
const CAPACITY = 4;
const SIZE = { w: COLUMN * 3 + GUTTER * 2, h: HEADER + CAPACITY * (CARD.h + SPACING) + 4 };

const centre = (column: number, row: number): Point => ({
  x: column * (COLUMN + GUTTER) + COLUMN / 2,
  y: HEADER + row * (CARD.h + SPACING) + CARD.h / 2,
});

type Card = { id: number; en: string; zh: string; tint: string };
type Slot = { column: number; row: number };

const SEED: Card[][] = [
  [
    { id: 0, en: "Onboarding", zh: "引导页", tint: Palette.indigo },
    { id: 1, en: "Dark mode", zh: "深色模式", tint: Palette.violet },
    { id: 2, en: "Search", zh: "搜索", tint: Palette.sky },
  ],
  [
    { id: 3, en: "Checkout", zh: "支付流程", tint: Palette.coral },
    { id: 4, en: "Push alerts", zh: "推送通知", tint: Palette.amber },
  ],
  [{ id: 5, en: "Sign-in", zh: "登录页", tint: Palette.mint }],
];
const TITLES: [string, string][] = [
  ["To do", "待办"],
  ["Doing", "进行中"],
  ["Done", "完成"],
];

export default function KanbanDrag({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const ghost = useGhost();
  const [columns, setColumns] = useState<Card[][]>(SEED);
  const [draggingID, setDraggingID] = useState<number | null>(null);
  const [target, setTarget] = useState<Slot>({ column: 0, row: 0 });
  // Mirrors of the state for handlers that run between renders.
  const s = useRef({ columns: SEED, draggingID: null as number | null, origin: { column: 0, row: 0 }, target: { column: 0, row: 0 }, drag: { x: 0, y: 0 }, held: false }).current;
  const autoStep = useRef(0);
  const lagX = useMotionValue(0);
  const amount = useMotionValue(0);
  const dragX = useMotionValue(0);
  const settle = spring(ctx.n("response"), 0.78);

  const slotOf = (id: number): Slot | null => {
    for (let c = 0; c < s.columns.length; c++) {
      const row = s.columns[c].findIndex((card) => card.id === id);
      if (row >= 0) return { column: c, row };
    }
    return null;
  };

  const lift = (id: number) => {
    const home = slotOf(id);
    if (!home) return;
    const c = centre(home.column, home.row);
    s.origin = home;
    s.target = home;
    s.drag = c;
    s.draggingID = id;
    lagX.stop();
    lagX.jump(c.x);
    dragX.jump(c.x);
    amount.stop();
    amount.jump(1);
    setTarget(home);
    setDraggingID(id);
  };

  /** The card's centre follows `point`; the hover target is the nearest free slot. */
  const dragMoved = (point: Point, move: (p: Point) => void) => {
    const id = s.draggingID;
    if (id === null) return;
    s.drag = { x: clamp(point.x, 20, SIZE.w - 20), y: clamp(point.y, 20, SIZE.h - 10) };
    move(s.drag);
    dragX.set(s.drag.x);
    animate(lagX, s.drag.x, spring(0.34, 0.72));

    const columnIndex = clamp(Math.floor(s.drag.x / (COLUMN + GUTTER)), 0, 2);
    const others = s.columns[columnIndex].filter((c) => c.id !== id).length;
    let next = s.target;
    if (others < CAPACITY) {
      const raw = (s.drag.y - HEADER - CARD.h / 2) / (CARD.h + SPACING);
      next = { column: columnIndex, row: clamp(Math.round(raw), 0, others) };
    }
    if (next.column !== s.target.column || next.row !== s.target.row) {
      s.target = next;
      setTarget(next);
      if (s.held) haptics.selection();
    }
  };

  const drop = () => {
    const id = s.draggingID;
    if (id === null) return;
    const home = slotOf(id);
    if (!home) return;
    const card = s.columns[home.column][home.row];
    const moved = s.target.column !== s.origin.column || s.target.row !== s.origin.row;
    const next = s.columns.map((c) => c.slice());
    next[home.column].splice(home.row, 1);
    const row = Math.min(s.target.row, next[s.target.column].length);
    next[s.target.column].splice(row, 0, card);
    s.columns = next;
    s.draggingID = null;
    setColumns(next);
    setDraggingID(null);
    animate(lagX, s.drag.x, settle);
    animate(amount, 0, settle);
    if (s.held) haptics.tap(moved ? "medium" : "soft");
    s.held = false;
  };

  // Where every resting card sits: the lifted card is taken out and a gap opens at the hover target.
  const slots = new Map<number, Slot>();
  columns.forEach((cards, columnIndex) => {
    let row = 0;
    for (const card of cards) {
      if (card.id === draggingID) continue;
      if (draggingID !== null && target.column === columnIndex && target.row === row) row += 1;
      slots.set(card.id, { column: columnIndex, row });
      row += 1;
    }
  });
  const count = (column: number) => columns[column].filter((c) => c.id !== draggingID).length + (draggingID !== null && target.column === column ? 1 : 0);

  const movers = useRef(new Map<number, (p: Point) => void>()).current;

  /** A scripted finger carries the top card of the fullest column to the next column. */
  useAutoplay(
    ctx.isPreview,
    () => {
      if (s.draggingID !== null || s.held) return;
      autoStep.current += 1;
      let from = 0;
      s.columns.forEach((c, i) => {
        if (c.length > s.columns[from].length) from = i;
      });
      const card = s.columns[from][0];
      if (!card) return;
      let to = (from + 1 + (autoStep.current % 2)) % 3;
      if (s.columns[to].length >= CAPACITY) to = (to + 1) % 3;
      if (to === from) return;
      const start = centre(from, 0);
      const end = centre(to, Math.min(s.columns[to].length, 1));
      const control = { x: (start.x + end.x) / 2, y: Math.min(start.y, end.y) + 96 };
      lift(card.id);
      const move = movers.get(card.id) ?? (() => {});
      ghost.run(async (g) => {
        if (!(await g.sleep(0.25))) return;
        if (!(await g.drag(start, end, 0.95, (p) => dragMoved(p, move), control))) return;
        if (!(await g.sleep(0.2))) return;
        drop();
      });
    },
    { every: 2.6, delay: 0.5 },
  );

  const limit = Math.abs(ctx.n("tilt"));
  const lean = useTransform(() => clamp((dragX.get() - lagX.get()) * 0.45, -limit, limit) * amount.get());

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div style={{ position: "relative", width: SIZE.w, height: SIZE.h, flex: "none" }}>
        {[0, 1, 2].map((index) => (
          <Column key={index} index={index} title={ctx.t(...TITLES[index])} count={count(index)} highlighted={draggingID !== null && target.column === index} scheme={ctx.scheme} />
        ))}
        {columns.flat().map((card) => {
          const slot = slots.get(card.id) ?? { column: 0, row: 0 };
          return (
            <CardView
              key={card.id}
              card={card}
              title={ctx.t(card.en, card.zh)}
              lifted={draggingID === card.id}
              home={centre(slot.column, slot.row)}
              settle={settle}
              liftScale={ctx.n("lift")}
              lean={lean}
              scheme={ctx.scheme}
              register={(move) => movers.set(card.id, move)}
              onGrab={() => {
                if (s.draggingID !== null && !s.held) drop();
                if (s.draggingID !== null) return false;
                ghost.touch();
                s.held = true;
                lift(card.id);
                haptics.tap("light");
                return true;
              }}
              onMove={(p, move) => {
                if (s.draggingID === card.id && s.held) dragMoved(p, move);
              }}
              onDrop={() => {
                if (s.draggingID === card.id && s.held) drop();
              }}
              origin={() => {
                const home = slotOf(card.id);
                return home ? centre(home.column, home.row) : { x: 0, y: 0 };
              }}
            />
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Drag a card to another column" zh="把卡片拖到另一列" />
    </div>
  );
}

function Column({ index, title, count, highlighted, scheme }: { index: number; title: string; count: number; highlighted: boolean; scheme: "dark" | "light" }) {
  const t = spring(0.3, 0.85);
  return (
    <motion.div
      initial={false}
      animate={{
        backgroundColor: alpha(Palette.indigo, highlighted ? 0.14 : 0),
        boxShadow: highlighted ? `inset 0 0 0 1.5px ${alpha(Palette.indigo, 0.7)}` : `inset 0 0 0 1px ${labelColor(scheme, 0.08)}`,
      }}
      transition={t}
      style={{ position: "absolute", left: index * (COLUMN + GUTTER), top: 0, width: COLUMN, height: SIZE.h, borderRadius: 18, backgroundImage: `linear-gradient(${Palette.elevated}, ${Palette.elevated})`, backgroundBlendMode: "normal" }}
    >
      <motion.div
        initial={false}
        animate={{ backgroundColor: alpha(Palette.indigo, highlighted ? 0.14 : 0) }}
        transition={t}
        style={{ position: "absolute", inset: 0, borderRadius: 18 }}
      />
      <div style={{ position: "relative", height: HEADER - 6, padding: "0 8px", display: "flex", alignItems: "center", gap: 4 }}>
        <span style={{ fontSize: 11, fontWeight: 700, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{title}</span>
        <div style={{ flex: 1 }} />
        <motion.span
          initial={false}
          animate={{ backgroundColor: highlighted ? Palette.indigo : labelColor(scheme, 0.08), color: highlighted ? "rgba(255,255,255,1)" : scheme === "dark" ? "rgba(235,235,245,0.6)" : "rgba(60,60,67,0.6)" }}
          transition={t}
          style={{ minWidth: 16, height: 16, borderRadius: 8, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700 }}
        >
          <NumericText value={count} />
        </motion.span>
      </div>
    </motion.div>
  );
}

function CardView({
  card,
  title,
  lifted,
  home,
  settle,
  liftScale,
  lean,
  scheme,
  register,
  onGrab,
  onMove,
  onDrop,
  origin,
}: {
  card: Card;
  title: string;
  lifted: boolean;
  home: Point;
  settle: ReturnType<typeof spring>;
  liftScale: number;
  lean: MotionValue<number>;
  scheme: "dark" | "light";
  register: (move: (p: Point) => void) => void;
  onGrab: () => boolean;
  onMove: (p: Point, move: (p: Point) => void) => void;
  onDrop: () => void;
  origin: () => Point;
}) {
  const x = useMotionValue(home.x);
  const y = useMotionValue(home.y);
  const move = (p: Point) => {
    x.stop();
    y.stop();
    x.set(p.x);
    y.set(p.y);
  };
  register(move);
  const base = useRef<Point>({ x: 0, y: 0 });
  // The card keeps leaning while it flies home after a drop (the lean amount springs to 0).
  const [leaning, setLeaning] = useState(false);
  useEffect(() => {
    if (lifted) {
      setLeaning(true);
      return;
    }
    animate(x, home.x, settle);
    animate(y, home.y, settle);
    const id = window.setTimeout(() => setLeaning(false), 900);
    return () => window.clearTimeout(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lifted, home.x, home.y]);

  const pan = usePan({
    onStart: () => {
      base.current = origin();
      if (!onGrab()) base.current = { x: NaN, y: NaN };
    },
    onChange: ({ translation }) => {
      if (Number.isNaN(base.current.x)) return;
      onMove({ x: base.current.x + translation.x, y: base.current.y + translation.y }, move);
    },
    onEnd: () => onDrop(),
  });
  const zero = useMotionValue(0);

  return (
    <motion.div
      {...pan}
      style={{ ...pan.style, position: "absolute", left: -CARD.w / 2, top: -CARD.h / 2, width: CARD.w, height: CARD.h, x, y, zIndex: lifted ? 10 : 0, cursor: "grab" }}
    >
      <motion.div style={{ position: "absolute", inset: 0, rotate: leaning || lifted ? lean : zero, transformOrigin: "50% 0%" }}>
        <motion.div
          initial={false}
          animate={{
            scale: lifted ? liftScale : 1,
            boxShadow: `0 ${lifted ? 12 : 2}px ${lifted ? 20 : 4}px ${black(lifted ? 0.28 : 0.1)}, inset 0 0 0 1px ${lifted ? alpha(card.tint, 0.6) : labelColor(scheme, 0.08)}`,
          }}
          transition={spring(0.28, 0.7)}
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 12,
            background: scheme === "dark" ? "#3A3A40" : "#fff",
            padding: "0 9px",
            display: "flex",
            flexDirection: "column",
            alignItems: "flex-start",
            justifyContent: "center",
            gap: 5,
          }}
        >
          <div style={{ width: 22, height: 5, borderRadius: 2.5, background: card.tint }} />
          <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.label, whiteSpace: "nowrap" }}>{title}</div>
          <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
            <div style={{ width: 11, height: 11, borderRadius: "50%", background: `linear-gradient(180deg, ${card.tint}, ${alpha(card.tint, 0.55)})` }} />
            <div style={{ width: 30, height: 4, borderRadius: 2, background: Palette.labelAlpha(0.12) }} />
          </div>
        </motion.div>
      </motion.div>
    </motion.div>
  );
}
