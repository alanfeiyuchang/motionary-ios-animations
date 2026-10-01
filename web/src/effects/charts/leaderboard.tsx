/** charts.leaderboard · 排行榜超车 (Charts+Leaderboard.swift) */
import { Crown } from "lucide-react";
import { AnimatePresence, motion } from "motion/react";
import { useRef, useState } from "react";
import { NumericText, Palette, alpha, anim, black, fonts, forever, spring, useAutoplay, type DemoProps } from "../../kit";
import { ChartStage, captionSecondary, card, mono, swiftRound, sys, useChartHaptics, useNums, useTask } from "./_round2";

const seed = [
  { id: 0, en: "Mira", zh: "米拉", colors: [Palette.indigo, Palette.violet], score: 2480 },
  { id: 1, en: "Jonas", zh: "乔纳斯", colors: [Palette.amber, Palette.coral], score: 2310 },
  { id: 2, en: "Aiko", zh: "爱子", colors: [Palette.mint, Palette.sky], score: 2150 },
  { id: 3, en: "Theo", zh: "西奥", colors: [Palette.pink, Palette.violet], score: 1990 },
  { id: 4, en: "Lena", zh: "莱娜", colors: [Palette.sky, Palette.blue], score: 1840 },
];

/** (player, points): a scripted round of gains that produces single and double overtakes, then loops. */
const script: [number, number][] = [
  [3, 420],
  [4, 380],
  [1, 260],
  [2, 510],
  [0, 330],
  [4, 470],
  [3, 290],
  [1, 360],
];

const ROW_H = 36;
const ROW_GAP = 4;

export default function Leaderboard({ ctx }: DemoProps) {
  const haptics = useChartHaptics();
  const task = useTask();
  const scores = useRef(seed.map((p) => p.score));
  const shown = useNums(seed.length, seed.map((p) => p.score));
  const [ranks, setRanks] = useState([0, 1, 2, 3, 4]);
  const ranksRef = useRef(ranks);
  const [deltas, setDeltas] = useState<Record<number, number>>({});
  const [lifted, setLifted] = useState<number | null>(null);
  const [leader, setLeader] = useState(0);
  /** The row that moves first, on the overtake spring; the rows it passes follow on a softer one. */
  const [mover, setMover] = useState<number | null>(null);
  const step = useRef(0);

  /** Tap and autoplay: the next scripted gain. The mover gets the stage; the rows it passes follow underneath. */
  const advance = () => {
    const [id, gain] = script[step.current % script.length];
    step.current += 1;
    haptics.tap("light");

    scores.current = scores.current.map((s, i) => (i === id ? s + gain : s));
    const order = seed.map((p) => p.id).sort((a, b) => scores.current[b] - scores.current[a]);
    const newRanks = seed.map(() => 0);
    order.forEach((player, rank) => (newRanks[player] = rank));
    const changes: Record<number, number> = {};
    seed.forEach((p) => {
      const change = ranksRef.current[p.id] - newRanks[p.id];
      if (change !== 0) changes[p.id] = change;
    });
    const moved = changes[id] !== undefined;
    const response = ctx.n("response");

    shown.to(id, scores.current[id], anim.easeOut(0.5));
    setLifted(moved ? id : null);
    setDeltas(changes);
    task.run(async (sleep) => {
      await sleep(0.14);
      setMover(id);
      ranksRef.current = ranksRef.current.map((r, i) => (i === id ? newRanks[id] : r));
      setRanks(ranksRef.current);
      setLeader(order[0]);
      await sleep(0.08);
      ranksRef.current = newRanks;
      setRanks(newRanks);
      await sleep(response * 0.75);
      if (moved && !ctx.isPreview) haptics.tap("soft");
      setLifted(null);
      await sleep(0.75);
      setDeltas({});
    });
  };

  useAutoplay(ctx.isPreview, advance, { every: 1.7, delay: 0.7 });

  const overtake = spring(ctx.n("response"), ctx.n("damping"));
  const follow = spring(0.42, 0.86);
  const lift = lifted !== null ? spring(0.3, 0.7) : spring(0.35, 0.7);
  const liftScale = ctx.n("lift");

  return (
    <ChartStage ctx={ctx} hint={["Tap to score the next points", "点击计入下一次得分"]}>
      <div onClick={advance} style={{ ...card(10), cursor: "pointer" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
            <div style={captionSecondary}>{ctx.t("Weekly league", "本周联赛")}</div>
            <div style={sys(19, 700, true)}>{ctx.t("Top players", "选手排行")}</div>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 9px", borderRadius: 999, background: Palette.labelAlpha(0.06) }}>
            <motion.span animate={{ opacity: [0.35, 1] }} transition={forever(anim.easeInOut(0.8))} style={{ width: 6, height: 6, borderRadius: "50%", background: Palette.green }} />
            <span style={{ ...sys(12, 600), color: Palette.secondaryLabel }}>{ctx.t("Live", "实时")}</span>
          </div>
        </div>
        <div style={{ position: "relative", height: 5 * ROW_H + 4 * ROW_GAP, marginTop: 5 }}>
          {/* The crown is a matched geometry between leaders: both ends of its trip are the top row, so it holds
              its place while the rows change underneath. */}
          <div style={{ position: "absolute", left: 42, top: -6, zIndex: 3, color: Palette.amber, filter: `drop-shadow(0 0 3px ${alpha(Palette.amber, 0.5)})`, pointerEvents: "none" }}>
            <Crown size={14} fill="currentColor" strokeWidth={1.5} />
          </div>
          {seed.map((player) => {
            const rank = ranks[player.id];
            const isLeader = leader === player.id;
            const isLifted = lifted === player.id;
            const delta = deltas[player.id] ?? 0;
            const tone = delta > 0 ? Palette.green : Palette.red;
            return (
              <motion.div
                key={player.id}
                initial={false}
                animate={{ y: rank * (ROW_H + ROW_GAP), scale: isLifted ? liftScale : 1 }}
                transition={{ y: mover === player.id ? overtake : follow, scale: lift }}
                style={{ position: "absolute", left: 0, right: 0, top: 0, height: ROW_H, zIndex: isLifted ? 2 : 0, display: "flex", alignItems: "center", gap: 10, padding: "0 10px" }}
              >
                <motion.div
                  initial={false}
                  animate={{ opacity: isLifted ? 0 : 1 }}
                  transition={lift}
                  style={{ position: "absolute", inset: 0, borderRadius: 12, background: Palette.labelAlpha(0.045) }}
                />
                <motion.div
                  initial={false}
                  animate={{ opacity: isLifted ? 1 : 0 }}
                  transition={lift}
                  style={{
                    position: "absolute",
                    inset: 0,
                    borderRadius: 12,
                    background: `linear-gradient(${alpha(player.colors[0], 0.16)}, ${alpha(player.colors[0], 0.16)}), ${Palette.elevated}`,
                    boxShadow: `inset 0 0 0 1px ${alpha(player.colors[0], 0.5)}, 0 8px 28px ${black(0.22)}`,
                  }}
                />
                <div style={{ position: "relative", width: 16, display: "flex", justifyContent: "center", color: isLeader ? Palette.amber : Palette.secondaryLabel, transition: "color 0.3s" }}>
                  <NumericText value={rank + 1} style={{ fontFamily: fonts.rounded, fontSize: 14, lineHeight: "17px", fontWeight: 700 }} />
                </div>
                <div
                  style={{
                    position: "relative",
                    width: 26,
                    height: 26,
                    borderRadius: "50%",
                    flex: "none",
                    background: `linear-gradient(135deg, ${player.colors[0]}, ${player.colors[1]})`,
                    display: "grid",
                    placeItems: "center",
                    color: "#fff",
                    ...sys(12, 700, true),
                  }}
                >
                  {ctx.t(player.en, player.zh).slice(0, 1)}
                </div>
                <div style={{ position: "relative", ...sys(15, 600) }}>{ctx.t(player.en, player.zh)}</div>
                <div style={{ flex: 1, minWidth: 4 }} />
                <AnimatePresence initial={false}>
                  {delta !== 0 && (
                    <motion.div
                      key="delta"
                      initial={{ scale: 0.3, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1, transition: spring(0.3, 0.7) }}
                      exit={{ scale: 0.3, opacity: 0, transition: anim.easeOut(0.3) }}
                      style={{ position: "relative", display: "flex", alignItems: "center", gap: 1, padding: "3px 6px", borderRadius: 999, color: tone, background: alpha(tone, 0.14) }}
                    >
                      <svg width={7} height={6} viewBox="0 0 7 6" style={{ transform: delta > 0 ? undefined : "rotate(180deg)" }}>
                        <path d="M3.5 0.3 L6.8 5.7 H0.2 Z" fill="currentColor" />
                      </svg>
                      <span style={sys(11, 700, true)}>{Math.abs(delta)}</span>
                    </motion.div>
                  )}
                </AnimatePresence>
                <div style={{ position: "relative", width: 48, textAlign: "right", ...sys(15, 700, true), ...mono }}>{swiftRound(shown.get(player.id))}</div>
              </motion.div>
            );
          })}
        </div>
      </div>
    </ChartStage>
  );
}
