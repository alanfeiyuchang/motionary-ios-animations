/** navigation.island-bar-player · 灵动岛标签栏播放器 (Navigation+IslandBarPlayer.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Leaf, Search, Sun, Volume2, Waves } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, delayed, spring, useAutoplay, useClock, useHaptics, white, type DemoProps } from "../../kit";
import { Bounce, SquareGrid2x2Fill } from "./groupA-kit";
import { Glyph } from "./groupB-kit";
import { PauseFill, PlayFill, diag, stageColumn } from "./_r2";

type IconFn = (size: number | string) => ReactNode;
const TRACKS: { title: [string, string]; artist: [string, string]; icon: IconFn; colors: [string, string] }[] = [
  { title: ["Slow Tide", "缓潮"], artist: ["Mira Lane", "米拉·莱恩"], icon: (s) => <Waves size={s} strokeWidth={3} />, colors: [Palette.sky, Palette.indigo] },
  { title: ["Paper Suns", "纸太阳"], artist: ["The Quiet Hours", "静默时刻"], icon: (s) => <Sun size={s} strokeWidth={3} fill="currentColor" />, colors: [Palette.amber, Palette.coral] },
  { title: ["Night Garden", "夜花园"], artist: ["Okapi", "欧卡皮"], icon: (s) => <Leaf size={s} strokeWidth={2} fill="currentColor" />, colors: [Palette.mint, Palette.violet] },
];
const TAB_ICONS: ReactNode[] = [
  <Glyph key={0} name="house.fill" size={19} />,
  <Search key={1} size={19} strokeWidth={2.8} />,
  <Glyph key={2} name="square.stack.fill" size={19} />,
  <Glyph key={3} name="person.fill" size={19} />,
];

/** Round artwork that spins while playing, inside a progress ring. */
function Disc({ track, seconds }: { track: (typeof TRACKS)[number]; seconds: number }) {
  const progress = (seconds % 14) / 14;
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", inset: 3, borderRadius: "50%", background: diag(...track.colors), color: white(0.92), display: "grid", placeItems: "center", transform: `rotate(${seconds * 42}deg)` }}>
        <div style={{ position: "absolute", inset: 9, display: "grid" }}>{track.icon("100%")}</div>
      </div>
      <svg viewBox="0 0 100 100" style={{ position: "absolute", inset: 0, width: "100%", height: "100%", overflow: "visible", transform: "rotate(-90deg)" }}>
        <circle cx={50} cy={50} r={50} fill="none" stroke={white(0.16)} strokeWidth={1.5} vectorEffect="non-scaling-stroke" />
        <circle cx={50} cy={50} r={50} fill="none" stroke={track.colors[0]} strokeWidth={1.5} strokeLinecap="round" vectorEffect="non-scaling-stroke" pathLength={1} strokeDasharray={`${progress} 1`} />
      </svg>
    </div>
  );
}

function Equalizer({ playing, color, time }: { playing: boolean; color: string; time: number }) {
  return (
    <div style={{ width: 20, height: 18, display: "flex", alignItems: "center", justifyContent: "center", gap: 2.5, flexShrink: 0 }}>
      {[0, 1, 2, 3].map((index) => {
        const wave = Math.sin(time * (5.2 + index * 1.7) + index * 1.3);
        const level = playing ? 0.5 + 0.5 * wave : 0;
        return <div key={index} style={{ width: 2.5, height: 4 + 12 * level, borderRadius: 1.25, background: color, transition: playing ? undefined : "height 0.2s ease-out" }} />;
      })}
    </div>
  );
}

export default function IslandBarPlayer({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [mode, setMode] = useState<"tabs" | "player">("tabs");
  const [current, setCurrent] = useState<number | null>(null);
  const [playing, setPlaying] = useState(false);
  const [tab, setTab] = useState(0);
  const [tabBounces, setTabBounces] = useState([0, 0, 0, 0]);
  const autoStep = useRef(0);
  const seconds = useClock(playing, ctx.isPreview ? 30 : undefined);

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const blur = ctx.n("blur");
  const size = mode === "player" ? { w: 264, h: 64 } : { w: current === null ? 216 : 262, h: 56 };

  const play = (index: number) => {
    haptics.tap("medium");
    setCurrent(index);
    setPlaying(true);
    setMode("player");
  };
  const showTabs = () => {
    if (mode !== "player") return;
    haptics.tap("medium");
    setMode("tabs");
  };
  const showPlayer = () => {
    if (mode !== "tabs" || current === null) return;
    haptics.tap("medium");
    setMode("player");
  };
  const togglePlay = () => {
    haptics.tap("light");
    setPlaying((p) => !p);
  };
  const selectTab = (index: number) => {
    haptics.selection();
    setTabBounces((b) => b.map((v, i) => (i === index ? v + 1 : v)));
    setTab(index);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 6;
      autoStep.current += 1;
      if (phase === 0) play(0);
      else if (phase === 1) showTabs();
      else if (phase === 2) selectTab((tab + 1) % TAB_ICONS.length);
      else if (phase === 3) showPlayer();
      else if (phase === 4) play(((current ?? 0) + 1) % TRACKS.length);
      else showTabs();
    },
    { every: 1.5 },
  );

  const content = {
    initial: { opacity: 0, scale: 0.7, filter: `blur(${blur}px)` },
    animate: { opacity: 1, scale: 1, filter: "blur(0px)", transition: delayed(move, 0.08) },
    exit: { opacity: 0, scale: 0.7, filter: `blur(${blur}px)`, transition: anim.easeIn(0.16) },
  };
  const track = TRACKS[current ?? 0];
  const big = mode === "player";
  const diameter = big ? 44 : 30;
  const discX = big ? -size.w / 2 + 32 : size.w / 2 - 27;

  return (
    <div style={stageColumn(14)}>
      <div
        style={{
          position: "relative",
          width: 290,
          height: 284,
          flexShrink: 0,
          borderRadius: 32,
          background: Palette.elevated,
          boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)`,
          overflow: "hidden",
        }}
      >
        {/* track list */}
        <div style={{ padding: "16px 14px 0", display: "flex", flexDirection: "column", gap: 4 }}>
          <div style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700, padding: "0 6px 2px" }}>{ctx.t("Up next", "接下来播放")}</div>
          {TRACKS.map((t, index) => {
            const active = current === index;
            return (
              <motion.div
                key={index}
                onClick={() => play(index)}
                initial={false}
                animate={{ backgroundColor: `rgb(var(--ml-label-rgb) / ${active ? 0.06 : 0})` }}
                transition={move}
                style={{ height: 46, padding: "0 8px", display: "flex", alignItems: "center", gap: 12, borderRadius: 14, cursor: "pointer" }}
              >
                <div style={{ width: 36, height: 36, borderRadius: 10, background: diag(...t.colors), color: white(0.9), display: "grid", placeItems: "center", flexShrink: 0 }}>{t.icon(16)}</div>
                <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                  <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: active ? t.colors[0] : Palette.label, transition: "color 0.3s", whiteSpace: "nowrap" }}>{ctx.t(...t.title)}</div>
                  <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...t.artist)}</div>
                </div>
                <div style={{ flex: 1 }} />
                <div style={{ width: 24, display: "grid", placeItems: "center", color: active ? t.colors[0] : Palette.secondaryLabel, opacity: active ? 1 : 0.6 }}>
                  <AnimatePresence initial={false} mode="popLayout">
                    <motion.div
                      key={active && playing ? "speaker" : "play"}
                      initial={{ opacity: 0, scale: 0.5, filter: "blur(4px)" }}
                      animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                      exit={{ opacity: 0, scale: 0.5, filter: "blur(4px)" }}
                      transition={anim.snappyD(0.25)}
                      style={{ display: "grid" }}
                    >
                      {active && playing ? <Volume2 size={15} strokeWidth={3} fill="currentColor" /> : <PlayFill size={13} />}
                    </motion.div>
                  </AnimatePresence>
                </div>
              </motion.div>
            );
          })}
        </div>
        {/* bar */}
        <div style={{ position: "absolute", left: 0, right: 0, bottom: 14, height: 64, display: "flex", alignItems: "flex-end", justifyContent: "center", pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{ width: size.w, height: size.h }}
            transition={move}
            style={{ position: "relative", borderRadius: 32, background: "#0E0E12", boxShadow: `inset 0 0 0 1px ${white(0.1)}, 0 8px 16px rgb(0 0 0 / 0.3)`, pointerEvents: "auto" }}
          >
            <AnimatePresence initial={false}>
              {mode === "tabs" ? (
                <motion.div key="tabs" {...content} style={{ position: "absolute", left: "50%", top: "50%", width: size.w, height: 40, marginLeft: -size.w / 2, marginTop: -20, display: "flex", paddingLeft: 8, boxSizing: "border-box" }}>
                  {TAB_ICONS.map((icon, index) => (
                    <div key={index} onClick={() => selectTab(index)} style={{ position: "relative", width: 50, height: 40, display: "grid", placeItems: "center", cursor: "pointer", color: white(tab === index ? 1 : 0.45), transition: "color 0.25s" }}>
                      <motion.div
                        initial={false}
                        animate={{ opacity: tab === index ? 1 : 0, scale: tab === index ? 1 : 0.6 }}
                        transition={spring(0.32, 0.7)}
                        style={{ position: "absolute", inset: 0, borderRadius: 20, background: white(0.14) }}
                      />
                      <Bounce trigger={tabBounces[index]} style={{ position: "relative" }}>
                        {icon}
                      </Bounce>
                    </div>
                  ))}
                </motion.div>
              ) : (
                <motion.div
                  key="player"
                  {...content}
                  style={{ position: "absolute", left: "50%", top: "50%", width: size.w, height: 44, marginLeft: -size.w / 2, marginTop: -22, display: "flex", alignItems: "center", gap: 8, padding: "0 12px 0 10px", boxSizing: "border-box" }}
                >
                  <div style={{ width: 46, height: 44, flexShrink: 0 }} />
                  <div style={{ display: "grid", minWidth: 0 }}>
                    <AnimatePresence initial={false}>
                      <motion.div
                        key={current ?? 0}
                        initial={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
                        animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                        exit={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
                        transition={move}
                        style={{ gridArea: "1 / 1", display: "flex", flexDirection: "column", gap: 1, alignItems: "flex-start", transformOrigin: "0 50%" }}
                      >
                        <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff", whiteSpace: "nowrap" }}>{ctx.t(...track.title)}</div>
                        <div style={{ fontSize: 11, lineHeight: "13px", color: white(0.55), whiteSpace: "nowrap" }}>{ctx.t(...track.artist)}</div>
                      </motion.div>
                    </AnimatePresence>
                  </div>
                  <div style={{ flex: 1 }} />
                  <Equalizer playing={playing} color={track.colors[0]} time={seconds} />
                  <div onClick={togglePlay} style={{ width: 32, height: 40, display: "grid", placeItems: "center", color: "#fff", cursor: "pointer", flexShrink: 0 }}>
                    <AnimatePresence initial={false} mode="popLayout">
                      <motion.div
                        key={playing ? "pause" : "play"}
                        initial={{ opacity: 0, scale: 0.5, filter: "blur(4px)" }}
                        animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
                        exit={{ opacity: 0, scale: 0.5, filter: "blur(4px)" }}
                        transition={anim.snappyD(0.25)}
                        style={{ display: "grid" }}
                      >
                        {playing ? <PauseFill size={19} /> : <PlayFill size={19} />}
                      </motion.div>
                    </AnimatePresence>
                  </div>
                  <div onClick={showTabs} style={{ width: 34, height: 34, borderRadius: "50%", background: white(0.14), color: white(0.9), display: "grid", placeItems: "center", cursor: "pointer", flexShrink: 0 }}>
                    <SquareGrid2x2Fill size={15} />
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
            {/* the artwork is one view in both modes: it only changes size and side */}
            <AnimatePresence initial={false}>
              {current !== null && (
                <motion.div
                  key="disc"
                  onClick={() => (big ? togglePlay() : showPlayer())}
                  initial={{ opacity: 0, scale: 0.2, width: diameter, height: diameter, x: discX - diameter / 2, y: -diameter / 2 }}
                  animate={{ opacity: 1, scale: 1, width: diameter, height: diameter, x: discX - diameter / 2, y: -diameter / 2 }}
                  exit={{ opacity: 0, scale: 0.2 }}
                  transition={move}
                  style={{ position: "absolute", left: "50%", top: "50%", cursor: "pointer" }}
                >
                  <Disc track={track} seconds={seconds} />
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap a track, then the grid button" zh="点一首歌，再点右侧的网格按钮" />
    </div>
  );
}
