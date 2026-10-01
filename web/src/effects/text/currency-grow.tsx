/** text.currency-grow · 金额输入生长 (Text+CurrencyGrow.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Delete } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Palette, alpha, fonts, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { usePulse } from "./_fx";

interface Piece {
  id: string;
  text: string;
  width: number;
  dim?: boolean;
  isMark?: boolean;
}

const SCRIPT = ["0", "0", ".", "5", "0", "", "", "clear", "", "1", "2", "5", "0", ""];
const KEYS = [
  ["1", "2", "3"],
  ["4", "5", "6"],
  ["7", "8", "9"],
  [".", "0", "⌫"],
];

function piecesOf(entry: string, grouping: boolean): Piece[] {
  const parts = entry.split(".");
  const whole = Array.from(parts[0] ?? "");
  const result: Piece[] = [];
  if (!whole.length) result.push({ id: "i0", text: "0", width: 40, dim: true });
  whole.forEach((digit, index) => {
    result.push({ id: `i${index}`, text: digit, width: 40 });
    const after = whole.length - 1 - index;
    if (grouping && after > 0 && after % 3 === 0) result.push({ id: `s${index}`, text: ",", width: 16, isMark: true });
  });
  if (entry.includes(".")) {
    result.push({ id: "p", text: ".", width: 16, isMark: true });
    const cents = Array.from(parts[1] ?? "");
    for (let index = 0; index < 2; index++) {
      if (index < cents.length) result.push({ id: `f${index}`, text: cents[index], width: 40 });
      else result.push({ id: `f${index}`, text: "0", width: 40, dim: true });
    }
  }
  return result;
}

export default function CurrencyGrow({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** Raw entry: digits with at most one ".". */
  const [entry, setEntryState] = useState("1250");
  const entryRef = useRef("1250");
  const [pressed, setPressed] = useState<string | null>(null);
  const [shakes, setShakes] = useState(0);
  const step = useRef(0);
  const pressTimer = useRef(0);
  const holdTimer = useRef(0);
  const heldLong = useRef(false);
  useEffect(
    () => () => {
      window.clearTimeout(pressTimer.current);
      window.clearTimeout(holdTimer.current);
    },
    [],
  );

  const reject = () => {
    setShakes((s) => s + 1);
    haptics.error();
  };

  const apply = (key: string) => {
    let next = entryRef.current;
    if (key === "clear") next = "";
    else if (key === "⌫") {
      if (!next.length) return reject();
      next = next.slice(0, -1);
    } else if (key === ".") {
      if (next.includes(".")) return reject();
      if (!next.length) next = "0";
      next += ".";
    } else {
      const dot = next.indexOf(".");
      if (dot >= 0) {
        if (!(next.length - dot - 1 < 2)) return reject();
        next += key;
      } else {
        if (!(next.length < 9)) return reject();
        next = next === "0" ? key : next + key;
      }
    }
    entryRef.current = next;
    setEntryState(next);
  };

  const press = (key: string) => {
    setPressed(key === "clear" ? "⌫" : key);
    window.clearTimeout(pressTimer.current);
    pressTimer.current = window.setTimeout(() => setPressed(null), 160);
    apply(key);
  };

  const auto = () => {
    const key = SCRIPT[step.current % SCRIPT.length];
    step.current += 1;
    if (key) press(key);
  };
  useAutoplay(ctx.isPreview, auto, { every: 0.45 });

  const items = piecesOf(entry, ctx.b("grouping"));
  const natural = items.reduce((sum, piece) => sum + piece.width, 30);
  const scale = Math.min(1, ctx.n("fit") / natural);
  const transition = spring(ctx.n("response"), 0.72);
  const p = usePulse(shakes, 0.42);
  const shake = Math.sin(p * Math.PI * 5) * 9 * (1 - p);
  let x = -natural / 2 + 30;
  const lefts = items.map((piece) => {
    const left = x;
    x += piece.width;
    return left;
  });
  const label = ctx.scheme === "dark" ? "255 255 255" : "0 0 0";

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "4px 12px 4px 5px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
        <span style={{ width: 22, height: 22, borderRadius: "50%", background: Palette.sunset, display: "inline-flex", alignItems: "center", justifyContent: "center", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 800, color: "#fff" }}>M</span>
        <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600, color: Palette.secondaryLabel }}>{ctx.t("Send to Mia", "转给 Mia")}</span>
      </div>

      <div style={{ position: "relative", width: 320, height: 84 }}>
        <div style={{ position: "absolute", left: 160, top: 0, width: 0, height: 84, transform: `translateX(${shake}px)` }}>
          <motion.div initial={false} animate={{ scale }} transition={transition} style={{ position: "absolute", left: 0, top: 0, width: 0, height: 84 }}>
            <motion.span
              initial={false}
              animate={{ x: -natural / 2 }}
              transition={transition}
              style={{ position: "absolute", left: 0, top: 34, width: 30, fontFamily: fonts.rounded, fontSize: 32, lineHeight: "38px", fontWeight: 700, color: Palette.secondaryLabel }}
            >
              $
            </motion.span>
            <AnimatePresence initial={false}>
              {items.map((piece, i) => (
                <motion.span
                  key={piece.id}
                  initial={piece.isMark ? { x: lefts[i], y: 8, scale: 0.1, opacity: 0, filter: "blur(0px)" } : { x: lefts[i] + 28, y: 0, scale: 0.6, opacity: 0, filter: "blur(6px)" }}
                  animate={{ x: lefts[i], y: 0, scale: 1, opacity: 1, filter: "blur(0px)" }}
                  exit={piece.isMark ? { y: 8, scale: 0.1, opacity: 0 } : { y: 26, scale: 0.7, opacity: 0, filter: "blur(4px)" }}
                  transition={transition}
                  style={{ position: "absolute", left: 0, top: 4, width: piece.width, height: 76, fontFamily: fonts.rounded, fontSize: 64, lineHeight: "76px", fontWeight: 800, fontVariantNumeric: "tabular-nums", textAlign: "center" }}
                >
                  <AnimatePresence initial={false} mode="popLayout">
                    <motion.span
                      key={`${piece.text}${piece.dim ? "d" : ""}`}
                      initial={{ y: 30, opacity: 0, filter: "blur(4px)" }}
                      animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
                      exit={{ y: -30, opacity: 0, filter: "blur(4px)" }}
                      transition={transition}
                      style={{ display: "block", width: piece.width, color: `rgb(${label} / ${piece.dim ? 0.25 : 1})` }}
                    >
                      {piece.text}
                    </motion.span>
                  </AnimatePresence>
                </motion.span>
              ))}
            </AnimatePresence>
          </motion.div>
        </div>
      </div>

      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {KEYS.map((row, r) => (
          <div key={r} style={{ display: "flex", gap: 6 }}>
            {row.map((key) => {
              const isDown = pressed === key;
              return (
                <motion.div
                  key={key}
                  initial={false}
                  animate={{ scale: isDown ? 0.93 : 1 }}
                  transition={spring(0.22, 0.6)}
                  onPointerDown={() => {
                    heldLong.current = false;
                    window.clearTimeout(holdTimer.current);
                    holdTimer.current = window.setTimeout(() => {
                      heldLong.current = true;
                      if (key !== "⌫") return;
                      haptics.tap("medium");
                      press("clear");
                    }, 450);
                  }}
                  onPointerUp={() => window.clearTimeout(holdTimer.current)}
                  onPointerLeave={() => window.clearTimeout(holdTimer.current)}
                  onPointerCancel={() => window.clearTimeout(holdTimer.current)}
                  onClick={() => {
                    if (heldLong.current) return;
                    haptics.tap("light");
                    press(key);
                  }}
                  style={{
                    width: 88,
                    height: 40,
                    borderRadius: 12,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    fontFamily: fonts.rounded,
                    fontSize: 21,
                    fontWeight: 600,
                    cursor: "pointer",
                    color: isDown ? Palette.indigo : Palette.label,
                    background: isDown ? alpha(Palette.indigo, 0.2) : Palette.labelAlpha(0.06),
                    transition: "color 0.15s, background-color 0.15s",
                  }}
                >
                  {key === "⌫" ? <Delete size={20} strokeWidth={2.2} /> : key}
                </motion.div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}
