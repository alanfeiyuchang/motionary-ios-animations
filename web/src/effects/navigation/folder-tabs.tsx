/** navigation.folder-tabs · 流体文件夹标签 (Navigation+FolderTabs.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Circle, FileText, Film, Folder, Image as ImageIcon, Lightbulb, ListTodo, Quote, TextAlignStart, type LucideIcon } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, delayed, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { Bounce } from "./groupA-kit";
import { useMotionNumber } from "./nav-util";
import { stageColumn } from "./_r2";

type L = [string, string];
type Row = { icon: (size: number) => ReactNode; title: L; detail: L };
type Tab = { icon: (size: number) => ReactNode; title: L; color: string; rows: Row[] };

const lucide = (Icon: LucideIcon, filled = false) => (size: number) =>
  <Icon size={size} strokeWidth={2.4} fill={filled ? "currentColor" : "none"} />;

/** `note.text`: a rounded note with text lines. */
const NoteText = (size: number) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round">
    <rect x={3} y={4} width={18} height={16} rx={3.5} />
    <path d="M7.5 9.5h9M7.5 13h9M7.5 16.2h5" strokeWidth={1.8} />
  </svg>
);
/** `checkmark.circle.fill` */
const CheckCircleFill = (size: number) => (
  <svg width={size} height={size} viewBox="0 0 24 24">
    <path
      fill="currentColor"
      fillRule="evenodd"
      d="M12 1.5a10.5 10.5 0 1 1 0 21 10.5 10.5 0 0 1 0-21Zm4.9 6.6a1.1 1.1 0 0 0-1.55.2l-4.5 5.9-2.3-2.3a1.1 1.1 0 0 0-1.55 1.55l3.2 3.2a1.1 1.1 0 0 0 1.65-.1l5.25-6.9a1.1 1.1 0 0 0-.2-1.55Z"
    />
  </svg>
);

const TABS: Tab[] = [
  {
    icon: NoteText,
    title: ["Notes", "笔记"],
    color: Palette.amber,
    rows: [
      { icon: lucide(TextAlignStart), title: ["Launch checklist", "发布清单"], detail: ["9:41", "9:41"] },
      { icon: lucide(Lightbulb, true), title: ["Spring tuning ideas", "弹簧调参灵感"], detail: ["Mon", "周一"] },
      { icon: lucide(Quote, true), title: ["Interview quotes", "访谈摘录"], detail: ["Sep 12", "9月12日"] },
    ],
  },
  {
    icon: lucide(ListTodo),
    title: ["Tasks", "任务"],
    color: Palette.indigo,
    rows: [
      { icon: CheckCircleFill, title: ["Record the trailer", "录制预告片"], detail: ["Done", "完成"] },
      { icon: lucide(Circle), title: ["Polish tab motion", "打磨标签动效"], detail: ["Today", "今天"] },
      { icon: lucide(Circle), title: ["Ship the web port", "上线网页版"], detail: ["Fri", "周五"] },
    ],
  },
  {
    icon: lucide(Folder, true),
    title: ["Files", "文件"],
    color: Palette.mint,
    rows: [
      { icon: lucide(FileText), title: ["Prompt guide.pdf", "提示词指南.pdf"], detail: ["2.4 MB", "2.4 MB"] },
      { icon: lucide(ImageIcon), title: ["Cover-final.png", "封面-终版.png"], detail: ["860 KB", "860 KB"] },
      { icon: lucide(Film), title: ["Trailer.mov", "预告片.mov"], detail: ["48 MB", "48 MB"] },
    ],
  },
];

const W = 300;
const STRIP = 46;
const PANEL = 190;
const SLOT = W / TABS.length;
const H = STRIP + PANEL;

/** `FolderSilhouette`: tab + panel as one outline. */
function silhouette(lead: number, trail: number, ear: number): string {
  const tabCorner = 14;
  const panelCorner = 22;
  const join = STRIP;
  const left = Math.min(Math.max(lead, 0), W - tabCorner * 2);
  const right = Math.max(Math.min(trail, W), left + tabCorner * 2);
  const leftEar = Math.min(ear, Math.max(left, 0));
  const rightEar = Math.min(ear, Math.max(W - right, 0));
  const panelLeft = Math.min(panelCorner, Math.max(left - leftEar, 0));
  const panelRight = Math.min(panelCorner, Math.max(W - right - rightEar, 0));
  return [
    `M${left} ${join - leftEar}`,
    `L${left} ${tabCorner}`,
    `Q${left} 0 ${left + tabCorner} 0`,
    `L${right - tabCorner} 0`,
    `Q${right} 0 ${right} ${tabCorner}`,
    `L${right} ${join - rightEar}`,
    `Q${right} ${join} ${right + rightEar} ${join}`,
    `L${W - panelRight} ${join}`,
    `Q${W} ${join} ${W} ${join + panelRight}`,
    `L${W} ${H - panelCorner}`,
    `Q${W} ${H} ${W - panelCorner} ${H}`,
    `L${panelCorner} ${H}`,
    `Q0 ${H} 0 ${H - panelCorner}`,
    `L0 ${join + panelLeft}`,
    `Q0 ${join} ${panelLeft} ${join}`,
    `L${left - leftEar} ${join}`,
    `Q${left} ${join} ${left} ${join - leftEar}`,
    "Z",
  ].join("");
}

export default function FolderTabs({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [selected, setSelected] = useState(0);
  const [previous, setPrevious] = useState(0);
  const [bounces, setBounces] = useState([0, 0, 0]);
  /** Counts selections, so each one mounts fresh rows (even while that tab's last copy still fades). */
  const [visit, setVisit] = useState(0);
  const leadMV = useMotionValue(0);
  const trailMV = useMotionValue(SLOT);
  const lead = useMotionNumber(leadMV);
  const trail = useMotionNumber(trailMV);
  const autoForward = useRef(true);

  const select = (index: number) => {
    if (index === selected) return;
    haptics.selection();
    const goingRight = index > selected;
    const response = ctx.n("response");
    const fast = spring(response, ctx.n("damping"));
    const slow = spring(response * ctx.n("stretch"), Math.min(ctx.n("damping") + 0.08, 1));
    const targetLead = index * SLOT;
    setBounces((b) => b.map((v, i) => (i === index ? v + 1 : v)));
    setPrevious(selected);
    setSelected(index);
    setVisit((n) => n + 1);
    animate(trailMV, targetLead + SLOT, goingRight ? fast : slow);
    animate(leadMV, targetLead, goingRight ? slow : fast);
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      let next = selected + (autoForward.current ? 1 : -1);
      if (next >= TABS.length) {
        autoForward.current = false;
        next = selected - 1;
      } else if (next < 0) {
        autoForward.current = true;
        next = selected + 1;
      }
      select(next);
    },
    { every: 1.3 },
  );

  const d = silhouette(lead, trail, ctx.n("ear"));
  const direction = selected >= previous ? 1 : -1;
  const tab = TABS[selected];

  return (
    <div style={stageColumn(18)}>
      <div style={{ position: "relative", width: W, height: H, flexShrink: 0 }}>
        {/* recessed track */}
        <div style={{ position: "absolute", left: 0, top: 0, width: W, height: STRIP + 30, borderRadius: "18px 18px 0 0", background: Palette.labelAlpha(0.07) }} />
        <svg width={W} height={H} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", filter: "drop-shadow(0 9px 16px rgb(0 0 0 / 0.12))" }}>
          <path d={d} fill={Palette.elevated} stroke={Palette.stroke} strokeWidth={1} />
        </svg>
        {/* dividers */}
        {[1, 2].map((index) => (
          <div
            key={index}
            style={{
              position: "absolute",
              left: index * SLOT,
              top: (STRIP - 18) / 2,
              width: 1,
              height: 18,
              background: Palette.labelAlpha(0.14),
              opacity: index === selected || index - 1 === selected ? 0 : 1,
              transition: "opacity 0.22s ease-out",
              pointerEvents: "none",
            }}
          />
        ))}
        {/* labels */}
        <div style={{ position: "absolute", left: 0, top: 0, display: "flex" }}>
          {TABS.map((t, index) => {
            const isSelected = index === selected;
            return (
              <div
                key={index}
                onClick={() => select(index)}
                style={{ width: SLOT, height: STRIP, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, cursor: "pointer" }}
              >
                <Bounce trigger={bounces[index]} style={{ color: isSelected ? t.color : Palette.secondaryLabel, transition: "color 0.22s ease-out" }}>
                  {t.icon(16)}
                </Bounce>
                <span
                  style={{
                    fontSize: 15,
                    lineHeight: "20px",
                    fontWeight: isSelected ? 700 : 500,
                    color: isSelected ? Palette.label : Palette.secondaryLabel,
                    transition: "color 0.22s ease-out",
                    whiteSpace: "nowrap",
                  }}
                >
                  {ctx.t(...t.title)}
                </span>
              </div>
            );
          })}
        </div>
        {/* panel */}
        <div style={{ position: "absolute", left: 0, top: STRIP, width: W, height: PANEL, overflow: "hidden" }}>
          <AnimatePresence initial={false}>
            <motion.div
              key={visit}
              initial={false}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={anim.easeOut(0.22)}
              style={{ position: "absolute", inset: 0, padding: "0 14px", display: "flex", flexDirection: "column", justifyContent: "center", gap: 8 }}
            >
              {tab.rows.map((row, index) => (
                <motion.div
                  key={index}
                  initial={{ opacity: 0, x: 28 * direction, filter: "blur(6px)" }}
                  animate={{ opacity: 1, x: 0, filter: "blur(0px)" }}
                  transition={delayed(spring(0.42, 0.8), 0.04 + index * 0.045)}
                  style={{ height: 50, padding: "0 10px", display: "flex", alignItems: "center", gap: 12, borderRadius: 14, background: Palette.labelAlpha(0.04), flexShrink: 0 }}
                >
                  <div style={{ width: 34, height: 34, borderRadius: 10, background: alpha(tab.color, 0.16), color: tab.color, display: "grid", placeItems: "center", flexShrink: 0 }}>
                    {row.icon(17)}
                  </div>
                  <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{ctx.t(...row.title)}</span>
                  <div style={{ flex: 1, minWidth: 8 }} />
                  <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 500, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums", whiteSpace: "nowrap" }}>
                    {ctx.t(...row.detail)}
                  </span>
                </motion.div>
              ))}
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap a tab" zh="点击任一标签" />
    </div>
  );
}
