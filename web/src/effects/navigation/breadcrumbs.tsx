/** navigation.breadcrumbs · 折叠面包屑 (Navigation+Breadcrumbs.swift) */
import { AnimatePresence, motion } from "motion/react";
import { ChevronRight, Ellipsis, Folder } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, delayed, spring, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BlurReplace, HouseFill, useTextWidths } from "./groupA-kit";
import { BOUNCY, cubicKF, linearKF, springKF, track, useSince } from "./groupB-kit";
import { PhotoFill, stageColumn, useAutoplayFlag } from "./_r2";

type L = [string, string];
interface Crumb {
  depth: number;
  title: L;
}
interface Entry {
  file?: boolean;
  title: L;
  detail: L;
}
/** What each depth lists. Depths 0–3 hold folders (tapping one goes deeper); depth 4 holds files. */
const LEVELS: Entry[][] = [
  [
    { title: ["Projects", "项目"], detail: ["12 items", "12 项"] },
    { title: ["Photos", "照片"], detail: ["248 items", "248 项"] },
    { title: ["Music", "音乐"], detail: ["36 items", "36 项"] },
  ],
  [
    { title: ["Motionary", "Motionary"], detail: ["8 items", "8 项"] },
    { title: ["Sketches", "草图"], detail: ["31 items", "31 项"] },
    { title: ["Archive", "归档"], detail: ["5 items", "5 项"] },
  ],
  [
    { title: ["Assets", "素材"], detail: ["4 items", "4 项"] },
    { title: ["Sources", "源码"], detail: ["96 items", "96 项"] },
    { title: ["Exports", "导出"], detail: ["7 items", "7 项"] },
  ],
  [
    { title: ["Icons", "图标"], detail: ["3 items", "3 项"] },
    { title: ["Covers", "封面"], detail: ["9 items", "9 项"] },
    { title: ["Clips", "片段"], detail: ["14 items", "14 项"] },
  ],
  [
    { file: true, title: ["icon-light.png", "icon-light.png"], detail: ["84 KB", "84 KB"] },
    { file: true, title: ["icon-dark.png", "icon-dark.png"], detail: ["91 KB", "91 KB"] },
    { file: true, title: ["icon-tinted.png", "icon-tinted.png"], detail: ["77 KB", "77 KB"] },
  ],
];
const ROOT: Crumb = { depth: 0, title: ["Home", "主页"] };
const MAX_DEPTH = LEVELS.length - 1;
const ALL_TITLES: L[] = [ROOT.title, ...LEVELS.slice(0, MAX_DEPTH).flatMap((level) => level.map((e) => e.title))];
const CRUMB_FONT = { fontSize: 13, lineHeight: "18px" } as const;
const HOME_ICON = 15;

type Item = { id: string; crumb?: Crumb; hidden?: number };

export default function Breadcrumbs({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [path, setPathState] = useState<Crumb[]>([ROOT]);
  const pathRef = useRef(path);
  const [forward, setForward] = useState(true);
  const [swallowed, setSwallowed] = useState(0);
  const cancelPop = useRef<(() => void) | null>(null);
  const zh = ctx.lang === "zh";
  const texts = ALL_TITLES.map((t) => (zh ? t[1] : t[0]));
  const [mediumW, probeA] = useTextWidths(texts, { ...CRUMB_FONT, fontWeight: 500 });
  const [boldW, probeB] = useTextWidths(texts, { ...CRUMB_FONT, fontWeight: 600 });

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const limit = Math.max(ctx.i("visible"), 2);
  /** Counts navigations, so every visit of a level mounts fresh rows (even while its last copy still fades). */
  const [visit, setVisit] = useState(0);
  const setPath = (next: Crumb[]) => {
    pathRef.current = next;
    setPathState(next);
    setVisit((n) => n + 1);
  };

  const auto = useAutoplayFlag(
    ctx.isPreview,
    () => {
      // Preview loop: walk down to the deepest folder, then jump back to the root.
      const now = pathRef.current;
      if (now.length <= MAX_DEPTH) push(LEVELS[now.length - 1][0].title);
      else pop(0);
    },
    { every: 1.0 },
  );

  function push(title: L) {
    const now = pathRef.current;
    if (now.length > MAX_DEPTH) return;
    cancelPop.current?.();
    haptics.tap("light");
    if (now.length >= limit) setSwallowed((n) => n + 1);
    setForward(true);
    setPath([...now, { depth: now.length, title }]);
  }

  /** Pops back to `depth`, folding one crumb per beat from the right. */
  function pop(depth: number) {
    if (depth >= pathRef.current.length - 1 || depth < 0) return;
    cancelPop.current?.();
    const live = !auto.current;
    const stagger = ctx.n("stagger");
    const beat = () => {
      if (pathRef.current.length - 1 <= depth) return;
      if (live) haptics.selection();
      setForward(false);
      setPath(pathRef.current.slice(0, -1));
      cancelPop.current = after(stagger, beat);
    };
    beat();
  }

  // Root, an ellipsis standing for the collapsed middle, then the last crumbs that fit.
  const items: Item[] =
    path.length > limit
      ? [{ id: "crumb-0", crumb: path[0] }, { id: "ellipsis", hidden: path.length - limit }, ...path.slice(-(limit - 1)).map((c) => ({ id: `crumb-${c.depth}`, crumb: c }))]
      : path.map((c) => ({ id: `crumb-${c.depth}`, crumb: c }));

  // The HStack, resolved by hand so every item can spring to its place.
  const widthOf = (item: Item) => {
    if (!item.crumb) return 30;
    const c = item.crumb;
    const isCurrent = c.depth === path.length - 1;
    const k = ALL_TITLES.findIndex((t) => t[0] === c.title[0]);
    const text = (isCurrent ? boldW : mediumW)[Math.max(k, 0)];
    const showText = c.depth > 0 || path.length === 1;
    return 16 + (c.depth === 0 ? HOME_ICON : 0) + (showText ? text : 0) + (c.depth === 0 && showText ? 5 : 0);
  };
  let x = 8;
  const placed = items.map((item, index) => {
    const lead = index > 0 ? 14 : 0;
    const w = widthOf(item);
    const at = { item, x, lead, w };
    x += lead + w;
    return at;
  });
  const current = placed.find((p) => p.item.crumb && p.item.crumb.depth === path.length - 1);
  const gulpT = useSince(swallowed, 0.62);
  const gulp = track(gulpT, 1, [linearKF(1, 0.1), cubicKF(1.25, 0.12), springKF(1, 0.4, BOUNCY)]);
  const accent = ctx.scheme === "dark" ? "#A9B1FF" : "#4B57E0";
  const depth = path.length - 1;
  const isLeaf = depth === MAX_DEPTH;
  const tint = isLeaf ? Palette.pink : Palette.sky;
  const direction = forward ? 1 : -1;
  const fold = { opacity: 0, rotateY: 82, scaleX: 0.4 };

  return (
    <div style={stageColumn(12)}>
      {probeA}
      {probeB}
      {/* trail */}
      <div style={{ position: "relative", width: 304, height: 44, flexShrink: 0, borderRadius: 16, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 5px 10px rgb(0 0 0 / 0.07)`, overflow: "hidden" }}>
        {current && (
          <motion.div
            initial={false}
            animate={{ x: current.x + current.lead, width: current.w }}
            transition={move}
            style={{ position: "absolute", left: 0, top: 8, height: 28, borderRadius: 14, background: alpha(Palette.indigo, 0.18) }}
          />
        )}
        <AnimatePresence initial={false}>
          {placed.map(({ item, x: left, lead, w }) => {
            const c = item.crumb;
            const isCurrent = !!c && c.depth === path.length - 1;
            return (
              <motion.div key={item.id} initial={{ x: left }} animate={{ x: left }} exit={{ x: left }} transition={move} style={{ position: "absolute", left: 0, top: 0, height: 44, display: "flex", alignItems: "center" }}>
                {/* folds about its leading edge like a paper flap; the same motion unfolds a new one */}
                <motion.div
                  initial={fold}
                  animate={{ opacity: 1, rotateY: 0, scaleX: 1 }}
                  exit={fold}
                  transition={move}
                  style={{ display: "flex", alignItems: "center", transformOrigin: "0% 50%", transformPerspective: (lead + w) / 0.6 }}
                >
                  {lead > 0 && (
                    <div style={{ width: 14, display: "grid", placeItems: "center", color: Palette.tertiaryLabel }}>
                      <ChevronRight size={12} strokeWidth={3.4} />
                    </div>
                  )}
                  {c ? (
                    <div
                      onClick={() => pop(c.depth)}
                      style={{ height: 28, padding: "0 8px", display: "flex", alignItems: "center", gap: 5, color: isCurrent ? accent : Palette.secondaryLabel, transition: "color 0.25s", cursor: "pointer" }}
                    >
                      {c.depth === 0 && <HouseFill size={HOME_ICON} />}
                      {(c.depth > 0 || path.length === 1) && <span style={{ ...CRUMB_FONT, fontWeight: isCurrent ? 600 : 500, whiteSpace: "nowrap" }}>{zh ? c.title[1] : c.title[0]}</span>}
                    </div>
                  ) : (
                    <div
                      onClick={() => pop(item.hidden ?? 0)}
                      style={{ width: 30, height: 26, borderRadius: 13, background: Palette.labelAlpha(0.08), color: Palette.secondaryLabel, display: "grid", placeItems: "center", transform: `scale(${gulp})`, cursor: "pointer" }}
                    >
                      <Ellipsis size={15} strokeWidth={3.2} />
                    </div>
                  )}
                </motion.div>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>
      {/* browser */}
      <div style={{ width: 304, boxSizing: "border-box", padding: 12, display: "flex", flexDirection: "column", gap: 10, flexShrink: 0, borderRadius: 22, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 14px rgb(0 0 0 / 0.08)` }}>
        <div style={{ padding: "0 6px", display: "flex", alignItems: "baseline" }}>
          <BlurReplace id={depth} transition={move} style={{ justifyItems: "start" }}>
            <span style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700, whiteSpace: "nowrap" }}>{zh ? path[depth].title[1] : path[depth].title[0]}</span>
          </BlurReplace>
          <div style={{ flex: 1 }} />
          <span style={{ display: "inline-flex", fontSize: 12, lineHeight: "16px", fontWeight: 600, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums", whiteSpace: "pre" }}>
            <NumericText value={depth + 1} />
            {` / ${LEVELS.length}`}
          </span>
        </div>
        <div style={{ position: "relative", height: 3 * 48 + 2 * 6 }}>
          <AnimatePresence initial={false}>
            <motion.div key={visit} initial={false} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.97 }} transition={move} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", gap: 6 }}>
              {LEVELS[depth].map((entry, index) => (
                <motion.div
                  key={index}
                  onClick={() => !isLeaf && push(entry.title)}
                  initial={{ opacity: 0, x: 40 * direction }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={delayed(spring(0.42, 0.82), 0.03 + index * 0.04)}
                  style={{ height: 48, padding: "0 10px", display: "flex", alignItems: "center", gap: 12, borderRadius: 14, background: Palette.labelAlpha(0.04), flexShrink: 0, cursor: isLeaf ? undefined : "pointer" }}
                >
                  <div style={{ width: 34, height: 34, borderRadius: 10, background: alpha(tint, 0.16), color: tint, display: "grid", placeItems: "center", flexShrink: 0 }}>
                    {entry.file ? <PhotoFill size={18} /> : <Folder size={17} fill="currentColor" strokeWidth={2} />}
                  </div>
                  <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{zh ? entry.title[1] : entry.title[0]}</span>
                  <div style={{ flex: 1, minWidth: 8 }} />
                  <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>{zh ? entry.detail[1] : entry.detail[0]}</span>
                  {!isLeaf && <ChevronRight size={14} strokeWidth={3.2} color={Palette.tertiaryLabel} style={{ flexShrink: 0, marginLeft: -4 }} />}
                </motion.div>
              ))}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Open folders, then tap a crumb to go back" zh="打开文件夹，再点面包屑返回" />
    </div>
  );
}
