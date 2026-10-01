/** navigation.command-palette · 命令面板 (Navigation+CommandPalette.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Archive, Contrast, Delete, Inbox, Link, PanelLeft, Search, Settings, SquarePen } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, delayed, fonts, forever, glass, spring, useHaptics, useTimeouts, type DemoContext, type DemoProps, type Lang } from "../../kit";
import { BOUNCY, cubicKF, springKF, track, useSince } from "./groupB-kit";
import { colorGradient } from "./nav-util";
import { NavigationScreenPlaceholder } from "./shared";
import { CheckCircleFill, useAutoplayFlag } from "./_r2";

// MARK: - Data & matching

interface Command {
  id: number;
  icon: ReactNode;
  color: string;
  /** English title, one word per element. */
  words: string[];
  /** Chinese title, one character per element, with its pinyin syllable in `pinyin`. */
  chars: string[];
  pinyin: string[];
  key: string;
}
const ic = { size: 14, strokeWidth: 2.8 } as const;
const COMMANDS: Command[] = [
  { id: 0, icon: <Contrast {...ic} />, color: Palette.indigo, words: ["Switch", "Theme"], chars: ["切", "换", "主", "题"], pinyin: ["qie", "huan", "zhu", "ti"], key: "T" },
  { id: 1, icon: <Search {...ic} />, color: Palette.sky, words: ["Search", "Threads"], chars: ["搜", "索", "会", "话"], pinyin: ["sou", "suo", "hui", "hua"], key: "F" },
  { id: 2, icon: <Link {...ic} />, color: Palette.mint, words: ["Share", "Link"], chars: ["分", "享", "链", "接"], pinyin: ["fen", "xiang", "lian", "jie"], key: "L" },
  { id: 3, icon: <Settings {...ic} />, color: Palette.coral, words: ["Open", "Settings"], chars: ["打", "开", "设", "置"], pinyin: ["da", "kai", "she", "zhi"], key: "," },
  { id: 4, icon: <SquarePen {...ic} />, color: Palette.amber, words: ["New", "Note"], chars: ["新", "建", "笔", "记"], pinyin: ["xin", "jian", "bi", "ji"], key: "N" },
  { id: 5, icon: <Inbox {...ic} />, color: Palette.pink, words: ["Go", "to", "Inbox"], chars: ["前", "往", "收", "件", "箱"], pinyin: ["qian", "wang", "shou", "jian", "xiang"], key: "I" },
  { id: 6, icon: <PanelLeft {...ic} />, color: Palette.violet, words: ["Toggle", "Sidebar"], chars: ["显", "示", "侧", "栏"], pinyin: ["xian", "shi", "ce", "lan"], key: "B" },
  { id: 7, icon: <Archive {...ic} />, color: Palette.green, words: ["Archive", "Done"], chars: ["归", "档", "已", "完", "成"], pinyin: ["gui", "dang", "yi", "wan", "cheng"], key: "E" },
];
const units = (c: Command, lang: Lang) => (lang === "zh" ? c.chars : c.words);
const tokens = (c: Command, lang: Lang) => (lang === "zh" ? c.pinyin : c.words.map((w) => w.toLowerCase()));
const titleOf = (c: Command, lang: Lang) => (lang === "zh" ? c.chars.join("") : c.words.join(" "));
/** The scripted queries the field types (the demo has no keyboard): Latin letters in English, pinyin in Chinese. */
const scripts = (lang: Lang) => (lang === "zh" ? ["she", "xi"] : ["set", "th"]);

interface Match {
  command: Command;
  /** Index of the first matched word / character, and how many of them the query covers. */
  start: number;
  covered: number;
  /** Letters matched inside the last covered English word. */
  lastCount: number;
}

/** The query must be a prefix of the title read from some word (or pinyin syllable) boundary. */
function matchOf(command: Command, query: string, lang: Lang): Match | null {
  if (!query) return { command, start: 0, covered: 0, lastCount: 0 };
  const list = tokens(command, lang);
  for (let start = 0; start < list.length; start++) {
    let remaining = query;
    let covered = 0;
    let lastCount = 0;
    let index = start;
    let matched = true;
    while (remaining.length > 0) {
      if (index >= list.length) {
        matched = false;
        break;
      }
      const token = list[index];
      if (remaining.length >= token.length) {
        if (!remaining.startsWith(token)) {
          matched = false;
          break;
        }
        remaining = remaining.slice(token.length);
        lastCount = token.length;
      } else {
        if (!token.startsWith(remaining)) {
          matched = false;
          break;
        }
        lastCount = remaining.length;
        remaining = "";
      }
      covered += 1;
      index += 1;
    }
    if (matched) return { command, start, covered, lastCount };
  }
  return null;
}

function resultsFor(query: string, lang: Lang): Match[] {
  const matches = COMMANDS.map((c) => matchOf(c, query, lang)).filter((m): m is Match => m !== null);
  matches.sort((a, b) => (a.start !== b.start ? a.start - b.start : a.command.id - b.command.id));
  return matches.slice(0, 5);
}

/** The title with its matched part bold and tinted. */
function MatchTitle({ match, ctx }: { match: Match; ctx: DemoContext }) {
  const zh = ctx.lang === "zh";
  const tint = ctx.scheme === "dark" ? "#A9B1FF" : "#4B57E0";
  const parts: ReactNode[] = [];
  units(match.command, ctx.lang).forEach((unit, index) => {
    if (index > 0 && !zh) parts.push(" ");
    const inRange = match.covered > 0 && index >= match.start && index < match.start + match.covered;
    if (!inRange) return void parts.push(unit);
    const isLast = index === match.start + match.covered - 1;
    const count = zh || !isLast ? unit.length : Math.min(match.lastCount, unit.length);
    parts.push(
      <span key={index} style={{ color: tint, fontWeight: 700 }}>
        {unit.slice(0, count)}
      </span>,
    );
    if (count < unit.length) parts.push(unit.slice(count));
  });
  return <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{parts}</span>;
}

function Keycap({ text, onClick }: { text: string; onClick?: (e: React.MouseEvent) => void }) {
  return (
    <span
      onClick={onClick}
      style={{
        minWidth: 20,
        height: 20,
        boxSizing: "border-box",
        padding: "0 5px",
        borderRadius: 6,
        background: Palette.labelAlpha(0.08),
        boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.08)}`,
        color: Palette.secondaryLabel,
        fontFamily: fonts.rounded,
        fontSize: 11,
        lineHeight: "20px",
        fontWeight: 600,
        textAlign: "center",
        flexShrink: 0,
        cursor: onClick ? "pointer" : undefined,
      }}
    >
      {text}
    </span>
  );
}

const ROW_H = 40;

export default function CommandPalette({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [isOpen, setOpen] = useState(false);
  /** Flips right after the panel is inserted, so the first rows can rise in with a stagger. */
  const [rowsIn, setRowsIn] = useState(false);
  const [query, setQueryState] = useState("");
  const [selectedID, setSelectedID] = useState<number | null>(0);
  const [selectSpring, setSelectSpring] = useState<"query" | "move">("query");
  const [pulses, setPulses] = useState(0);
  const [toast, setToast] = useState<Command | null>(null);
  const [closing, setClosing] = useState(false);
  const scriptIndex = useRef(0);
  const movedDown = useRef(false);
  const rest = useRef(0);
  const toastToken = useRef(0);
  const live = useRef({ isOpen, query, selectedID });
  live.current = { isOpen, query, selectedID };

  const lang = ctx.lang;
  const move = spring(ctx.n("response"), 0.78);
  const results = resultsFor(query, lang);
  const script = () => scripts(lang)[scriptIndex.current % scripts(lang).length];

  const open = () => {
    if (live.current.isOpen) return;
    haptics.tap("light");
    setQueryState("");
    movedDown.current = false;
    setRowsIn(false);
    setSelectedID(resultsFor("", lang)[0]?.command.id ?? null);
    setClosing(false);
    setOpen(true);
    live.current = { isOpen: true, query: "", selectedID: resultsFor("", lang)[0]?.command.id ?? null };
    // Next tick: the rows exist now, so their staggered rise can animate.
    after(0.02, () => setRowsIn(true));
  };
  const close = () => {
    if (!live.current.isOpen) return;
    live.current.isOpen = false;
    setClosing(true);
    setOpen(false);
  };
  const setQuery = (text: string) => {
    const first = resultsFor(text, lang)[0]?.command.id ?? null;
    setSelectSpring("query");
    setQueryState(text);
    setSelectedID(first);
    live.current = { ...live.current, query: text, selectedID: first };
    movedDown.current = false;
  };
  /** Types the next letter of the scripted query (a tap on the field, or one autoplay tick). */
  const typeNext = () => {
    const now = live.current;
    if (!now.isOpen || now.query.length >= script().length) return;
    haptics.selection();
    setQuery(script().slice(0, now.query.length + 1));
  };
  const deleteLast = () => {
    const now = live.current;
    if (!now.isOpen || !now.query) return;
    haptics.selection();
    setQuery(now.query.slice(0, -1));
  };
  const moveDown = () => {
    const now = live.current;
    const list = resultsFor(now.query, lang);
    if (!now.isOpen || list.length <= 1) return;
    const current = list.findIndex((m) => m.command.id === now.selectedID);
    haptics.selection();
    const next = list[(current + 1) % list.length].command.id;
    setSelectSpring("move");
    setSelectedID(next);
    live.current.selectedID = next;
    movedDown.current = true;
  };
  const run = () => {
    const now = live.current;
    const command = resultsFor(now.query, lang).find((m) => m.command.id === now.selectedID)?.command;
    if (!now.isOpen || !command) return;
    haptics.success();
    setPulses((n) => n + 1);
    scriptIndex.current += 1;
    toastToken.current += 1;
    const token = toastToken.current;
    after(0.16, () => {
      close();
      setToast(command);
      after(1.3, () => {
        if (token === toastToken.current) setToast(null);
      });
    });
  };
  const choose = (id: number) => {
    if (!live.current.isOpen) return;
    if (live.current.selectedID !== id) {
      setSelectSpring("move");
      setSelectedID(id);
      live.current.selectedID = id;
    }
    run();
  };

  // One autoplay tick: open → type a letter → arrow down once → run → rest, then again with the next query.
  useAutoplayFlag(
    ctx.isPreview,
    () => {
      const now = live.current;
      if (!now.isOpen) {
        if (rest.current > 0) {
          rest.current -= 1;
          return;
        }
        open();
        return;
      }
      if (now.query.length < script().length) typeNext();
      else if (resultsFor(now.query, lang).length > 1 && !movedDown.current) moveDown();
      else {
        run();
        rest.current = 3;
      }
    },
    { every: 0.46 },
  );

  const pulseT = useSince(pulses, 0.4);
  const pulse = track(pulseT, 1, [cubicKF(0.96, 0.09), springKF(1, 0.3, BOUNCY)]);
  const blur = ctx.n("blur");
  const selectedIndex = results.findIndex((m) => m.command.id === selectedID);
  const listHeight = Math.max(results.length, 1) * ROW_H;
  const pageSpring = closing ? spring(ctx.n("response") * 0.9, 0.9) : move;

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      {/* page behind */}
      <motion.div
        initial={false}
        animate={{ opacity: isOpen ? 0.55 : 1, filter: `blur(${isOpen ? 2.5 : 0}px)` }}
        transition={pageSpring}
        style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 18 }}
      >
        <div style={{ paddingTop: 26 }}>
          <NavigationScreenPlaceholder rows={2} />
        </div>
        <div
          onClick={open}
          style={{ height: 40, padding: "0 14px", display: "flex", alignItems: "center", gap: 8, borderRadius: 20, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 10px rgb(0 0 0 / 0.08)`, color: Palette.secondaryLabel, cursor: "pointer", flexShrink: 0 }}
        >
          <Search size={15} strokeWidth={2.8} />
          <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap" }}>{ctx.t("Search commands", "搜索命令")}</span>
          <span style={{ display: "flex", gap: 3 }}>
            <Keycap text="⌘" />
            <Keycap text="K" />
          </span>
        </div>
        <DemoHint ctx={ctx} en="Tap the field to type · tap a result to run it" zh="点击搜索框输入 · 点击结果执行" />
      </motion.div>
      <motion.div
        onClick={close}
        initial={false}
        animate={{ opacity: isOpen ? 0.12 : 0 }}
        transition={pageSpring}
        style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: isOpen ? "auto" : "none" }}
      />
      {/* panel */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            key="panel"
            initial={{ opacity: 0, scale: 0.94, y: -16, filter: `blur(${blur}px)` }}
            animate={{ opacity: 1, scale: 1, y: 0, filter: "blur(0px)", transition: move }}
            exit={{ opacity: 0, scale: 0.94, y: -16, filter: `blur(${blur}px)`, transition: spring(ctx.n("response") * 0.9, 0.9) }}
            style={{
              position: "absolute",
              left: 20,
              top: 22,
              width: 300,
              borderRadius: 22,
              overflow: "hidden",
              transformOrigin: "50% 0%",
              ...glass("regular"),
              boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 16px 30px rgb(0 0 0 / 0.26)`,
            }}
          >
            {/* field */}
            <div onClick={typeNext} style={{ height: 48, padding: "0 14px", display: "flex", alignItems: "center", gap: 8, cursor: "text" }}>
              <Search size={17} strokeWidth={2.8} color={Palette.secondaryLabel} style={{ flexShrink: 0 }} />
              <div style={{ display: "flex", alignItems: "center" }}>
                <AnimatePresence initial={false} mode="popLayout">
                  {query.split("").map((letter, index) => (
                    <motion.span
                      key={index}
                      initial={{ opacity: 0, scale: 0.4 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.4 }}
                      transition={move}
                      style={{ display: "inline-block", fontSize: 17, lineHeight: "22px", fontWeight: 500, transformOrigin: "50% 100%" }}
                    >
                      {letter}
                    </motion.span>
                  ))}
                </AnimatePresence>
                <motion.span initial={{ opacity: 1 }} animate={{ opacity: 0.15 }} transition={forever(anim.easeInOut(0.5))} style={{ width: 2, height: 20, marginLeft: 1, borderRadius: 1, background: Palette.indigo, flexShrink: 0 }} />
                {!query && <span style={{ paddingLeft: 5, fontSize: 16, lineHeight: "21px", color: Palette.tertiaryLabel, whiteSpace: "nowrap" }}>{ctx.t("Type a command…", "输入命令…")}</span>}
              </div>
              <div style={{ flex: 1 }} />
              <AnimatePresence initial={false}>
                {query && (
                  <motion.div
                    key="delete"
                    onClick={(e) => {
                      e.stopPropagation();
                      deleteLast();
                    }}
                    initial={{ opacity: 0, scale: 0.5 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.5 }}
                    transition={move}
                    style={{ width: 32, height: 32, display: "grid", placeItems: "center", color: Palette.secondaryLabel, cursor: "pointer", flexShrink: 0 }}
                  >
                    <Delete size={19} strokeWidth={2.2} />
                  </motion.div>
                )}
              </AnimatePresence>
              <Keycap
                text="esc"
                onClick={(e) => {
                  e.stopPropagation();
                  close();
                }}
              />
            </div>
            <div style={{ height: 0.5, background: Palette.labelAlpha(0.2), opacity: 0.7 }} />
            {/* results */}
            <motion.div initial={false} animate={{ height: listHeight + 12 }} transition={move} style={{ position: "relative" }}>
              {selectedIndex >= 0 && (
                <motion.div
                  initial={false}
                  animate={{ y: 6 + selectedIndex * ROW_H }}
                  transition={selectSpring === "move" ? spring(0.3, 0.8) : move}
                  style={{ position: "absolute", left: 6, right: 6, top: 0, height: ROW_H, borderRadius: 12, background: alpha(Palette.indigo, 0.16), opacity: rowsIn ? 1 : 0, transition: "opacity 0.25s" }}
                />
              )}
              <AnimatePresence initial={false}>
                {results.map((match, index) => {
                  const isSelected = match.command.id === selectedID;
                  return (
                    <motion.div
                      key={match.command.id}
                      onClick={() => choose(match.command.id)}
                      initial={{ opacity: 0, scale: 0.94, y: 6 + index * ROW_H }}
                      animate={{ opacity: 1, scale: 1, y: 6 + index * ROW_H }}
                      exit={{ opacity: 0, scale: 0.94 }}
                      transition={move}
                      style={{ position: "absolute", left: 6, right: 6, top: 0, height: ROW_H, cursor: "pointer" }}
                    >
                      <motion.div
                        initial={false}
                        animate={{ opacity: rowsIn ? 1 : 0, y: rowsIn ? 0 : 10 }}
                        transition={rowsIn ? delayed(spring(0.4, 0.8), 0.05 + index * ctx.n("stagger")) : { duration: 0 }}
                        style={{ height: ROW_H }}
                      >
                        <div style={{ height: ROW_H, padding: "0 8px", boxSizing: "border-box", display: "flex", alignItems: "center", gap: 10, transform: isSelected ? `scale(${pulse})` : undefined }}>
                          <div style={{ width: 26, height: 26, borderRadius: 8, background: colorGradient(match.command.color), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{match.command.icon}</div>
                          <MatchTitle match={match} ctx={ctx} />
                          <div style={{ flex: 1, minWidth: 6 }} />
                          <span style={{ display: "flex", gap: 3, opacity: isSelected ? 1 : 0.6, transition: "opacity 0.25s" }}>
                            <Keycap text="⌘" />
                            <Keycap text={match.command.key} />
                          </span>
                        </div>
                      </motion.div>
                    </motion.div>
                  );
                })}
                {results.length === 0 && (
                  <motion.div
                    key="empty"
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    exit={{ opacity: 0 }}
                    transition={move}
                    style={{ position: "absolute", left: 0, right: 0, top: 6, height: 40, display: "grid", placeItems: "center", fontSize: 13, color: Palette.secondaryLabel }}
                  >
                    {ctx.t("No matching commands", "没有匹配的命令")}
                  </motion.div>
                )}
              </AnimatePresence>
            </motion.div>
            {/* footer */}
            <div style={{ height: 30, padding: "0 14px", display: "flex", alignItems: "center", gap: 12, background: Palette.labelAlpha(0.04) }}>
              {(
                [
                  ["↑↓", ctx.t("Navigate", "选择"), moveDown],
                  ["↵", ctx.t("Run", "执行"), run],
                ] as [string, string, () => void][]
              ).map(([key, label, action]) => (
                <div key={key} onClick={action} style={{ display: "flex", alignItems: "center", gap: 5, cursor: "pointer" }}>
                  <Keycap text={key} />
                  <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{label}</span>
                </div>
              ))}
              <div style={{ flex: 1 }} />
              <NumericText value={results.length} style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: Palette.secondaryLabel }} />
            </div>
          </motion.div>
        )}
      </AnimatePresence>
      {/* toast */}
      <div style={{ position: "absolute", left: 0, right: 0, bottom: 22, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
        <AnimatePresence>
          {toast && (
            <motion.div
              key={toast.id}
              initial={{ opacity: 0, scale: 0.8, y: 14 }}
              animate={{ opacity: 1, scale: 1, y: 0, transition: spring(0.4, 0.7) }}
              exit={{ opacity: 0, scale: 0.8, y: 14, transition: anim.easeIn(0.25) }}
              style={{
                height: 36,
                padding: "0 14px",
                display: "flex",
                alignItems: "center",
                gap: 8,
                borderRadius: 18,
                background: Palette.elevated,
                boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 6px 14px rgb(0 0 0 / 0.16)`,
                transformOrigin: "50% 100%",
              }}
            >
              <CheckCircleFill size={19} color={Palette.green} />
              <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{titleOf(toast, lang)}</span>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
