/** cards.receipt-print · 小票打印 (Cards+ReceiptPrint.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Printer } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, anim, black, clamp, delayed, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, tr, useMV, type LText } from "./shared";
import { track } from "./_kit";

const AREA = { w: 320, h: 292 };
const PAPER_W = 172;
const LINE = 19;
const MARGIN = 12;
/** The slot, measured from the top of the area. */
const SLOT_Y = 238;
const INK = 0x2b2b33;
const MONO = `${fonts.mono}, "PingFang SC", system-ui, sans-serif`;

type Line = { kind: "header" | "meta" | "rule" | "barcode" | "thanks" } | { kind: "item"; index: number } | { kind: "total"; amount: string };
const ITEMS: { name: LText; price: string }[] = [
  { name: ["Flat white", "馥芮白"], price: "4.50" },
  { name: ["Croissant", "可颂"], price: "3.80" },
  { name: ["Oat cookie", "燕麦曲奇"], price: "2.90" },
  { name: ["Cold brew", "冷萃咖啡"], price: "5.20" },
];
const TOTALS = ["0.00", "4.50", "8.30", "11.20", "16.40"];

function linesFor(items: number): Line[] {
  const count = clamp(items, 2, 4);
  const result: Line[] = [{ kind: "header" }, { kind: "meta" }, { kind: "rule" }];
  for (let index = 0; index < count; index++) result.push({ kind: "item", index });
  result.push({ kind: "rule" }, { kind: "total", amount: TOTALS[count] }, { kind: "barcode" }, { kind: "thanks" });
  return result;
}

const BARS: [number, number][] = (() => {
  const mask = (1n << 64n) - 1n;
  const next = (s: bigint) => (s * 6364136223846793005n + 1442695040888963407n) & mask;
  const bars: [number, number][] = [];
  let x = 0;
  let seed = 0xc0ffeen;
  while (x < PAPER_W - 24) {
    seed = next(seed);
    const width = 1 + Number((seed >> 40n) % 3n);
    seed = next(seed);
    const gap = 1 + Number((seed >> 40n) % 3n);
    bars.push([x, width]);
    x += width + gap;
  }
  return bars;
})();

export default function ReceiptPrint({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const items = ctx.i("items");
  const lines = linesFor(items);
  /** Lines pushed out of the slot (fractional while a line is moving). */
  const feedMV = useMotionValue(0);
  /** Lines whose text has been printed. */
  const [typed, setTyped] = useState(0);
  const printing = useRef(false);
  const [ready, setReadyState] = useState(false);
  const readyRef = useRef(false);
  const [kick, setKick] = useState({ n: 0, amplitude: 0 });
  const kicks = useRef(0);
  const [lamp, setLamp] = useState(false);
  /** Sideways pull on the hanging paper, in points. */
  const pullMV = useMotionValue(0);
  /** −1 / +1 once torn: the paper is carried off that way. */
  const carriedMV = useMotionValue(0);
  const [torn, setTornState] = useState(false);
  const tornRef = useRef(false);
  const [gone, setGone] = useState(false);
  const held = useRef(false);
  const script = useTimeouts();

  const setReady = (v: boolean) => {
    readyRef.current = v;
    setReadyState(v);
  };
  const setTorn = (v: boolean) => {
    tornRef.current = v;
    setTornState(v);
  };

  const reset = () => {
    script.clearAll();
    printing.current = false;
    setReady(false);
    setLamp(false);
    [feedMV, pullMV, carriedMV].forEach((mv) => {
      mv.stop();
      mv.jump(0);
    });
    setTyped(0);
    setTorn(false);
    setGone(false);
  };

  const firstItems = useRef(items);
  useEffect(() => {
    if (firstItems.current === items) return;
    firstItems.current = items;
    reset();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items]);

  const bump = (fed: number, count: number) => {
    kicks.current += 1;
    const amplitude = ctx.n("wobble") * Math.min(fed / Math.max(count, 1), 1);
    setKick({ n: kicks.current, amplitude: kicks.current % 2 === 0 ? amplitude : -amplitude });
  };

  const tearOff = (direction: number, haptic: boolean) => {
    if (!readyRef.current || tornRef.current) return;
    setReady(false);
    setLamp(false);
    if (haptic) haptics.tap("rigid");
    setTorn(true);
    animate(carriedMV, direction, anim.curve(0.3, 0, 0.7, 1, 0.5));
    setGone(true);
    script.clearAll();
    script.after(0.6, reset);
  };

  const run = (autoTear: boolean, buzz: boolean) => {
    if (printing.current || readyRef.current || tornRef.current) return;
    printing.current = true;
    const interval = ctx.n("interval");
    const count = lines.length;
    script.clearAll();
    const step = (line: number) => {
      if (line < count) {
        animate(feedMV, line + 1, anim.easeOut(Math.min(0.11, interval * 0.6)));
        setTyped(line + 1);
        bump(line + 1, count);
        setLamp((l) => !l);
        if (buzz) haptics.tap("light");
        script.after(interval, () => step(line + 1));
        return;
      }
      animate(feedMV, count + 0.7, anim.easeOut(0.3));
      bump(count + 0.7, count);
      setLamp(true);
      printing.current = false;
      setReady(true);
      if (!autoTear) return;
      script.after(1.3, () => tearOff(1, false));
    };
    step(0);
  };

  const letGo = (velocity: number) => {
    if (!readyRef.current || tornRef.current) return;
    if (Math.abs(velocity) > 90) tearOff(velocity > 0 ? 1 : -1, true);
    else animate(pullMV, 0, spring(0.35, 0.5));
  };

  const pan = usePan({
    onChange: ({ translation }) => {
      if (!readyRef.current || tornRef.current) return;
      held.current = true;
      pullMV.stop();
      pullMV.set(translation.x);
      if (Math.abs(translation.x) > 40) {
        held.current = false;
        tearOff(translation.x > 0 ? 1 : -1, true);
      }
    },
    onEnd: ({ translation, velocity }) => {
      if (!held.current) return;
      held.current = false;
      pullMV.jump(pullMV.get());
      letGo(translation.x + velocity.x * 0.25);
    },
  });

  useAutoplay(ctx.isPreview, () => run(ctx.isPreview, false), { every: 5.4, delay: 0.4 });

  const feed = useMV(feedMV);
  const pull = useMV(pullMV);
  const carried = useMV(carriedMV);
  const e = useElapsed(kick.n, 0.9, true);
  const wobble = e < 0 ? 0 : track(e, 0, [{ cubic: kick.amplitude, d: 0.07 }, { spring: 0, d: 0.55, response: 0.3, damping: 0.28 }]);

  const fullHeight = MARGIN + (lines.length + 0.7) * LINE;
  const out = MARGIN + feed * LINE;
  // The paper leans as it is pulled, pivoting on the corner of the slot it is pulled away from.
  const lean = clamp(pull / 90, -1, 1) * 9;
  const pivotX = pull >= 0 ? (AREA.w - PAPER_W) / 2 : (AREA.w + PAPER_W) / 2;
  const paperLeft = (AREA.w - PAPER_W) / 2;

  return (
    <Stage gap={2}>
      <div style={{ position: "relative", width: AREA.w, height: AREA.h, flexShrink: 0 }}>
        {/* printer */}
        <div
          onClick={() => (readyRef.current ? tearOff(1, true) : run(false, true))}
          style={{ position: "absolute", left: (AREA.w - 236) / 2, top: SLOT_Y - 10, width: 236, height: 54, borderRadius: 18, background: "linear-gradient(#454B59, #24272F)", boxShadow: `0 8px 12px ${black(0.28)}`, cursor: "pointer" }}
        >
          <StrokeBorder radius={18} color={`linear-gradient(${white(0.28)}, ${white(0.04)})`} />
          <div style={{ position: "absolute", left: (236 - PAPER_W - 16) / 2, top: 7, width: PAPER_W + 16, height: 7, borderRadius: 4, background: black(0.85) }} />
          <div style={{ position: "absolute", left: 18, right: 18, top: 22, height: 24, display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 7, height: 7, borderRadius: 4, background: "#4BE38A", boxShadow: `0 0 ${lamp ? 5 : 1}px ${hex(0x4be38a, 0.9)}`, opacity: lamp ? 1 : 0.35 }} />
            <span style={{ fontSize: 10, lineHeight: "12px", fontWeight: 700, letterSpacing: 1.4, color: white(0.55) }}>{ctx.t("PRINT", "打印")}</span>
            <span style={{ flex: 1 }} />
            <div style={{ width: 34, height: 24, borderRadius: 12, background: white(0.1), display: "grid", placeItems: "center", color: white(0.75) }}>
              <Printer size={14} strokeWidth={2.4} />
            </div>
          </div>
        </div>
        {/* paper: everything still inside the printer is hidden; once torn the whole sheet shows */}
        <div style={{ position: "absolute", inset: 0, clipPath: torn ? `inset(${-AREA.h / 2}px 0 ${-AREA.h / 2}px 0)` : `inset(-200px 0 ${AREA.h - SLOT_Y}px 0)`, pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{ opacity: gone ? 0 : 1 }}
            transition={gone ? delayed(anim.easeIn(0.3), 0.2) : { duration: 0 }}
            style={{ position: "absolute", inset: 0 }}
          >
            <div
              style={{
                position: "absolute",
                inset: 0,
                transformOrigin: `${pivotX}px ${SLOT_Y}px`,
                transform: `translate(${carried * 120 + pull * 0.25}px, ${-Math.abs(carried) * 46}px) rotate(${lean + carried * 24}deg)`,
              }}
            >
              <div style={{ position: "absolute", inset: 0, transformOrigin: `${AREA.w / 2}px ${SLOT_Y}px`, transform: `rotate(${wobble}deg)` }}>
                <div style={{ position: "absolute", left: paperLeft, top: SLOT_Y - out }}>
                  <Sheet lines={lines} typed={typed} height={fullHeight} ctx={ctx} />
                </div>
              </div>
            </div>
          </motion.div>
        </div>
        {/* Shade where the paper leaves the slot. */}
        <div style={{ position: "absolute", left: paperLeft, top: SLOT_Y - 9, width: PAPER_W, height: 9, background: `linear-gradient(${black(0)}, ${black(0.3)})`, opacity: feed > 0.2 && !torn ? 1 : 0, pointerEvents: "none" }} />
        {ready && <div {...pan} style={{ position: "absolute", left: paperLeft, top: SLOT_Y - out, width: PAPER_W, height: Math.max(out, 1), touchAction: "none", cursor: "grab" }} />}
      </div>
      <DemoHint ctx={ctx} en="Tap the printer, then swipe the receipt off" zh="点击打印机，再把小票横向撕下" />
    </Stage>
  );
}

/** Receipt paper: straight top, serrated bottom where the cutter tears it. */
function paperPath(w: number, h: number): string {
  const teeth = 14;
  const step = w / teeth;
  const depth = 4;
  let d = `M0 0H${w}V${h - depth}`;
  for (let tooth = 0; tooth < teeth; tooth++) {
    const x = w - tooth * step;
    d += `L${x - step / 2} ${h}L${x - step} ${h - depth}`;
  }
  return `${d}Z`;
}

/** The printed strip: every line at a fixed height, text revealed left to right as it is printed. */
function Sheet({ lines, typed, height, ctx }: { lines: Line[]; typed: number; height: number; ctx: DemoContext }) {
  const row = (line: Line): ReactNode => {
    switch (line.kind) {
      case "header":
        return <span style={{ flex: 1, textAlign: "center", fontSize: 13, fontWeight: 800, letterSpacing: 1.5 }}>{ctx.t("CORNER CAFÉ", "街角咖啡")}</span>;
      case "meta":
        return <span style={{ flex: 1, textAlign: "center", fontSize: 9, fontWeight: 500, opacity: 0.6, whiteSpace: "pre" }}>{"No. 0428   10:24"}</span>;
      case "rule":
        return <div style={{ flex: 1, height: 1, background: `repeating-linear-gradient(to right, ${hex(INK, 0.45)} 0 3px, transparent 3px 6px)` }} />;
      case "item": {
        const item = ITEMS[line.index % ITEMS.length];
        return (
          <>
            <span style={{ fontSize: 11, fontWeight: 500 }}>{tr(ctx, item.name)}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontSize: 11, fontWeight: 500 }}>{item.price}</span>
          </>
        );
      }
      case "total":
        return (
          <>
            <span style={{ fontSize: 13, fontWeight: 800 }}>{ctx.t("TOTAL", "合计")}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontSize: 13, fontWeight: 800 }}>{line.amount}</span>
          </>
        );
      case "barcode":
        return (
          <svg width={PAPER_W - 24} height={14}>
            {BARS.map(([x, w]) => (
              <rect key={x} x={x} y={0} width={w} height={14} fill={hex(INK)} />
            ))}
          </svg>
        );
      default:
        return <span style={{ flex: 1, textAlign: "center", fontSize: 9, fontWeight: 600, letterSpacing: 2, opacity: 0.6 }}>{ctx.t("THANK YOU", "谢谢惠顾")}</span>;
    }
  };
  return (
    <div style={{ position: "relative", width: PAPER_W, height, color: hex(INK), fontFamily: MONO }}>
      <svg width={PAPER_W} height={height} style={{ position: "absolute", inset: 0, overflow: "visible", filter: `drop-shadow(0 2px 5px ${black(0.18)})` }}>
        <defs>
          <linearGradient id="receipt-paper" x1="0" x2="1" y1="0" y2="0">
            <stop offset="0" stopColor="#F4F1EA" />
            <stop offset="0.5" stopColor="#FFFFFF" />
            <stop offset="1" stopColor="#F1EEE6" />
          </linearGradient>
        </defs>
        <path d={paperPath(PAPER_W, height)} fill="url(#receipt-paper)" />
      </svg>
      <div style={{ position: "absolute", left: 12, right: 12, top: MARGIN }}>
        {lines.map((line, index) => {
          const shown = index < typed;
          return (
            <motion.div
              key={index}
              initial={false}
              animate={{ clipPath: shown ? "inset(0% 0% 0% 0%)" : "inset(0% 100% 0% 0%)" }}
              transition={shown ? anim.linear(0.14) : { duration: 0 }}
              style={{ height: LINE, display: "flex", alignItems: "center", lineHeight: 1, whiteSpace: "nowrap" }}
            >
              {row(line)}
            </motion.div>
          );
        })}
      </div>
    </div>
  );
}
