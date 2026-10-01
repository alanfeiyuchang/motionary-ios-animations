/** navigation.submenu-slide · 子菜单滑入 (Navigation+SubmenuSlide.swift) */
import { motion } from "motion/react";
import { ArrowUpDown, Check, ChevronLeft, ChevronRight, CircleCheck, Ellipsis, FileImage, FolderPlus, Palette as PaletteIcon } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, delayed, glass, spring, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { BlurReplace } from "./groupA-kit";
import { colorGradient } from "./nav-util";
import { DocTextFill, NoteText, PhotoFill, stageColumn, useAutoplayFlag } from "./_r2";

type L = [string, string];
type Level = "root" | "sort" | "tint";
const ROW = 40;
const SIZE: Record<Level, { w: number; h: number }> = {
  root: { w: 208, h: ROW * 4 + 12 },
  sort: { w: 180, h: ROW * 5 + 12 },
  tint: { w: 220, h: ROW * 2 + 18 },
};
const FILES: { icon: ReactNode; name: L; detail: L }[] = [
  { icon: <FileImage size={17} strokeWidth={2.4} />, name: ["Brand deck", "品牌方案"], detail: ["12 MB · May 3", "12 MB · 5月3日"] },
  { icon: <DocTextFill size={17} />, name: ["Invoice", "发票"], detail: ["240 KB · Jun 18", "240 KB · 6月18日"] },
  { icon: <PhotoFill size={17} />, name: ["Moodboard", "情绪板"], detail: ["48 MB · Apr 9", "48 MB · 4月9日"] },
  { icon: <NoteText size={17} />, name: ["Notes", "笔记"], detail: ["6 KB · Jun 2", "6 KB · 6月2日"] },
];
const SORT_NAMES: L[] = [["Name", "名称"], ["Date", "日期"], ["Size", "大小"], ["Kind", "类型"]];
/** File ids in display order for each sort option. */
const SORT_ORDERS = [[0, 1, 2, 3], [1, 3, 0, 2], [2, 0, 1, 3], [3, 2, 1, 0]];
const TINTS = [Palette.indigo, Palette.coral, Palette.amber, Palette.mint, Palette.pink];
const ROW_TEXT = { fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap" } as const;

export default function SubmenuSlide({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [open, setOpen] = useState(false);
  const [level, setLevel] = useState<Level>("root");
  const [sort, setSort] = useState(0);
  /** The sort name shown on the root row; it catches up once the root is back on screen. */
  const [shownSort, setShownSort] = useState(0);
  const [tint, setTint] = useState(0);
  const live = useRef({ open, level, sort, tint });
  live.current = { open, level, sort, tint };
  const cancelReturn = useRef<(() => void)[]>([]);
  const autoStep = useRef(0);

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");
  const stopReturn = () => {
    cancelReturn.current.forEach((c) => c());
    cancelReturn.current = [];
  };

  const toggleMenu = () => {
    stopReturn();
    haptics.tap("light");
    const opening = !live.current.open;
    // Always opens on the root level.
    if (opening) setLevel("root");
    setOpen(opening);
  };
  const go = (target: Level) => {
    if (target === live.current.level) return;
    stopReturn();
    haptics.selection();
    if (target === "root") setShownSort(live.current.sort);
    setLevel(target);
  };
  const returnSoon = (sortNow: number) => {
    stopReturn();
    cancelReturn.current.push(
      after(0.35, () => {
        setLevel("root");
        cancelReturn.current.push(after(0.2, () => setShownSort(sortNow)));
      }),
    );
  };
  const chooseSort = (index: number) => {
    haptics.selection();
    setSort(index);
    returnSoon(index);
  };
  const chooseTint = (index: number) => {
    haptics.selection();
    setTint(index);
    returnSoon(live.current.sort);
  };

  useAutoplayFlag(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 6;
      autoStep.current += 1;
      const now = live.current;
      if (phase === 0) {
        if (!now.open) toggleMenu();
      } else if (phase === 1) go("sort");
      else if (phase === 2) chooseSort((now.sort + 1) % SORT_NAMES.length);
      else if (phase === 3) go("tint");
      else if (phase === 4) chooseTint((now.tint + 1) % TINTS.length);
      else if (now.open) toggleMenu();
    },
    { every: 1.15 },
  );

  const color = TINTS[tint];
  const size = SIZE[level];
  const order = SORT_ORDERS[sort];

  /** Every level stays mounted; the current one sits at 0, the root waits on the left, submenus on the right. */
  const page = (target: Level, rows: ReactNode[]) => {
    const current = level === target;
    const side = target === "root" ? -1 : 1;
    return (
      <motion.div
        initial={false}
        animate={{ x: current ? 0 : side * size.w, opacity: current ? 1 : 0 }}
        transition={move}
        style={{ position: "absolute", left: 0, top: 0, width: SIZE[target].w, padding: "6px 0", pointerEvents: current ? "auto" : "none" }}
      >
        {rows.map((row, index) => (
          // A row's own trailing motion: later rows start a little later and from a little further away.
          <motion.div key={index} initial={false} animate={{ x: current ? 0 : side * 10 * index }} transition={delayed(move, current ? index * stagger : 0)}>
            {row}
          </motion.div>
        ))}
      </motion.div>
    );
  };
  const rowBox = { height: ROW, padding: "0 14px", display: "flex", alignItems: "center", cursor: "pointer" } as const;
  const lead = (icon: ReactNode) => <div style={{ width: 20, display: "grid", placeItems: "center", flexShrink: 0 }}>{icon}</div>;
  const drillRow = (icon: ReactNode, title: L, target: Level, value: ReactNode) => (
    <div onClick={() => go(target)} style={{ ...rowBox, gap: 10 }}>
      {lead(icon)}
      <span style={ROW_TEXT}>{ctx.t(...title)}</span>
      <div style={{ flex: 1, minWidth: 4 }} />
      <div style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel, display: "grid" }}>{value}</div>
      <ChevronRight size={14} strokeWidth={3.2} color={Palette.secondaryLabel} style={{ opacity: 0.7, flexShrink: 0 }} />
    </div>
  );
  const plainRow = (icon: ReactNode, title: L) => (
    <div onClick={toggleMenu} style={{ ...rowBox, gap: 10 }}>
      {lead(icon)}
      <span style={ROW_TEXT}>{ctx.t(...title)}</span>
    </div>
  );
  const backRow = (title: L) => (
    <div onClick={() => go("root")} style={{ ...rowBox, gap: 8, color, transition: "color 0.3s", boxShadow: `inset 0 -1px 0 ${Palette.labelAlpha(0.08)}` }}>
      {lead(<ChevronLeft size={15} strokeWidth={3.2} />)}
      <span style={{ ...ROW_TEXT, fontWeight: 700 }}>{ctx.t(...title)}</span>
    </div>
  );
  const mi = { size: 15, strokeWidth: 2.6 } as const;

  return (
    <div style={stageColumn(14)}>
      <div style={{ position: "relative", width: 300, height: 284, flexShrink: 0, borderRadius: 32, overflow: "hidden", background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 18px rgb(0 0 0 / 0.16)` }}>
        {/* content behind the menu */}
        <div onClick={() => live.current.open && toggleMenu()} style={{ position: "absolute", inset: 0, padding: "14px 16px 0" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", height: 36 }}>
            <span style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }}>{ctx.t("Files", "文件")}</span>
            <motion.div
              onClick={(e) => {
                e.stopPropagation();
                toggleMenu();
              }}
              style={{ position: "relative", width: 36, height: 36, borderRadius: "50%", background: Palette.labelAlpha(0.08), color: open ? "#fff" : Palette.label, display: "grid", placeItems: "center", cursor: "pointer", overflow: "hidden", transition: "color 0.2s" }}
            >
              <motion.div initial={false} animate={{ opacity: open ? 1 : 0 }} transition={spring(0.36, open ? 0.74 : 0.9)} style={{ position: "absolute", inset: 0, background: color }} />
              <Ellipsis size={19} strokeWidth={3.2} style={{ position: "relative" }} />
            </motion.div>
          </div>
          <div style={{ position: "relative", marginTop: 10 }}>
            {FILES.map((file, id) => (
              <motion.div key={id} initial={false} animate={{ y: order.indexOf(id) * 50 }} transition={spring(0.4, 0.8)} style={{ position: "absolute", left: 0, top: 0, height: 44, display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{ position: "relative", width: 34, height: 34, borderRadius: 10, overflow: "hidden", color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>
                  {TINTS.map((t, k) => (
                    <motion.div key={k} initial={false} animate={{ opacity: tint === k ? 1 : 0 }} transition={spring(0.35, 0.75)} style={{ position: "absolute", inset: 0, background: colorGradient(t) }} />
                  ))}
                  <span style={{ position: "relative", display: "grid" }}>{file.icon}</span>
                </div>
                <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
                  <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...file.name)}</span>
                  <span style={{ fontSize: 11, lineHeight: "13px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...file.detail)}</span>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
        {/* menu */}
        <motion.div
          initial={false}
          animate={{ width: size.w, height: size.h, scale: open ? 1 : 0.3, opacity: open ? 1 : 0, filter: `blur(${open ? 0 : 6}px)` }}
          transition={{ default: spring(0.36, open ? 0.74 : 0.9), width: move, height: move }}
          style={{
            position: "absolute",
            right: 14,
            top: 58,
            borderRadius: 18,
            overflow: "hidden",
            transformOrigin: "100% 0%",
            ...glass("regular"),
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 20px rgb(0 0 0 / 0.22)`,
            pointerEvents: open ? "auto" : "none",
          }}
        >
          {page("root", [
            drillRow(
              <ArrowUpDown {...mi} />,
              ["Sort by", "排序方式"],
              "sort",
              <BlurReplace id={shownSort} transition={anim.snappyD(0.3)} style={{ justifyItems: "end" }}>
                <span style={{ whiteSpace: "nowrap" }}>{ctx.t(...SORT_NAMES[shownSort])}</span>
              </BlurReplace>,
            ),
            drillRow(<PaletteIcon {...mi} />, ["Tint", "标记颜色"], "tint", <div style={{ width: 12, height: 12, borderRadius: "50%", background: color, transition: "background 0.3s" }} />),
            plainRow(<CircleCheck {...mi} />, ["Select", "选择"]),
            plainRow(<FolderPlus {...mi} />, ["New folder", "新建文件夹"]),
          ])}
          {page("sort", [
            backRow(["Sort by", "排序方式"]),
            ...SORT_NAMES.map((name, index) => (
              <div key={index} onClick={() => chooseSort(index)} style={{ ...rowBox, gap: 10, position: "relative" }}>
                <div style={{ width: 20, flexShrink: 0 }}>
                  {index === 0 && (
                    <motion.div initial={false} animate={{ y: sort * ROW }} transition={spring(0.4, 0.8)} style={{ width: 20, display: "grid", placeItems: "center", color }}>
                      <Check size={15} strokeWidth={3.4} />
                    </motion.div>
                  )}
                </div>
                <span style={{ ...ROW_TEXT, fontWeight: sort === index ? 600 : 500 }}>{ctx.t(...name)}</span>
              </div>
            )),
          ])}
          {page("tint", [
            backRow(["Tint", "标记颜色"]),
            <div key="swatches" style={{ position: "relative", display: "flex", padding: "0 8px" }}>
              <motion.div
                initial={false}
                animate={{ x: tint * ((SIZE.tint.w - 16) / TINTS.length) }}
                transition={spring(0.35, 0.75)}
                style={{ position: "absolute", left: 8 + ((SIZE.tint.w - 16) / TINTS.length - 33) / 2, top: (ROW + 6 - 33) / 2, width: 33, height: 33, boxSizing: "border-box", borderRadius: "50%", border: `2px solid ${Palette.labelAlpha(0.7)}`, pointerEvents: "none" }}
              />
              {TINTS.map((t, index) => (
                <div key={index} onClick={() => chooseTint(index)} style={{ flex: 1, height: ROW + 6, display: "grid", placeItems: "center", cursor: "pointer" }}>
                  <div style={{ width: 24, height: 24, borderRadius: "50%", background: colorGradient(t) }} />
                </div>
              ))}
            </div>,
          ])}
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Open the menu and drill into a row" zh="打开菜单，点进带箭头的行" />
    </div>
  );
}
