/** morph.chip-filter-panel · 筛选胶囊展开面板 (Morph+ChipFilterPanel.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { ChevronDown, House, Lamp, Leaf, SlidersHorizontal, Star, Waves, type LucideIcon } from "lucide-react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, black, delayed, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { Column, blurReplace, diag, mixN, morphScreen, smooth, unit, useMV, useProgress } from "./_shared";

const PANEL = { x: 12, y: 56, w: 292, h: 190 };
const results = [128, 64, 37, 21, 12, 7, 3];
const chipW = (badged: boolean) => (badged ? 112 : 88);
const options: [string, string][] = [
  ["Entire home", "整套房源"],
  ["Pool", "泳池"],
  ["Wi-Fi", "无线网络"],
  ["Kitchen", "厨房"],
  ["Pets", "可带宠物"],
  ["Parking", "停车位"],
];
const primaryStrong = diag("#4B57E0", "#7A45D6");

export default function ChipFilterPanel({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [open, setOpen] = useState(false);
  const [draft, setDraft] = useState<Set<number>>(() => new Set());
  const [applied, setApplied] = useState<Set<number>>(() => new Set());
  const [progress, to] = useProgress(0);
  const badgeMV = useMotionValue(1);
  const badgeScale = useMV(badgeMV);
  const autoStep = useRef(0);
  const zh = ctx.lang === "zh";
  const L = zh ? 1 : 0;
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");

  const present = () => {
    if (open) return;
    haptics.tap("light");
    setDraft(applied);
    setOpen(true);
    to(1, spr);
  };
  const dismiss = () => {
    if (!open) return;
    setOpen(false);
    to(0, spr);
  };
  const toggle = (index: number) => {
    haptics.selection();
    setDraft((d) => {
      const next = new Set(d);
      if (next.has(index)) next.delete(index);
      else next.add(index);
      return next;
    });
  };
  const reset = () => {
    if (draft.size === 0) return;
    haptics.tap("light");
    setDraft(new Set());
  };
  const apply = () => {
    if (!open) return;
    const changed = draft.size !== applied.size || [...draft].some((d) => !applied.has(d));
    haptics.success();
    setOpen(false);
    setApplied(draft);
    to(0, spr);
    if (!changed || draft.size === 0) return;
    // The badge lands a beat after the chip has re-formed.
    badgeMV.jump(0.2);
    animate(badgeMV, 1, delayed(spring(0.34, 0.45), ctx.n("response") * 0.55));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      switch (autoStep.current % 7) {
        case 0:
          // Each lap starts from a clean chip.
          if (applied.size) setApplied(new Set());
          if (!open) {
            setDraft(new Set());
            setOpen(true);
            to(1, spr);
          }
          break;
        case 1:
          toggle(1);
          break;
        case 2:
          toggle(3);
          break;
        case 3:
          apply();
          break;
        case 4:
          present();
          break;
        case 5:
          toggle(4);
          break;
        default:
          apply();
      }
      autoStep.current += 1;
    },
    { every: 0.85 },
  );

  // The morphing surface: a chip at progress 0, the panel at 1.
  const badged = applied.size > 0;
  const openP = unit(progress);
  const cw = chipW(badged);
  // Same origin for both rects: the top-left corner never moves, even on the overshoot.
  const width = Math.max(mixN(cw, PANEL.w, progress), 20);
  const height = Math.max(mixN(32, PANEL.h, progress), 20);
  const radius = Math.min(mixN(16, 24, openP), height / 2);
  const tint = badged ? 1 - smooth(progress, 0.05, 0.45) : 0;
  const reveal = (step: number) => smooth(progress, 0.38 + step * stagger * 1.6, 0.68 + step * stagger * 1.6);
  const count = results[Math.min(draft.size, 6)];
  const pillSpring = spring(0.3, 0.7);

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        <motion.div initial={false} animate={{ scale: open ? 0.97 : 1 }} transition={spr} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column" }}>
          <div style={{ height: 46, flexShrink: 0, padding: "0 16px", display: "flex", alignItems: "flex-end", gap: 4 }}>
            <span style={{ fontSize: 19, lineHeight: "23px", fontWeight: 700 }}>{zh ? "京都的住处" : "Stays in Kyoto"}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontSize: 13, lineHeight: "20px", fontWeight: 600, color: Palette.secondaryLabel }}>
              <NumericText value={-applied.size} text={String(results[Math.min(applied.size, 6)])} />
            </span>
            <span style={{ fontSize: 13, lineHeight: "20px", color: Palette.secondaryLabel }}>{zh ? "个结果" : "results"}</span>
          </div>
          <div style={{ display: "flex", gap: 8, paddingLeft: 12, paddingTop: 10 }}>
            <motion.div initial={false} animate={{ width: cw }} transition={spr} style={{ height: 32, flexShrink: 0 }} />
            <StaticChip title={zh ? "价格" : "Price"} />
            <StaticChip title={zh ? "日期" : "Dates"} />
          </div>
          <div style={{ position: "relative", margin: "12px 12px 0" }}>
            <AnimatePresence initial={false}>
              <motion.div key={applied.size} {...blurReplace()} transition={spr} style={{ position: "absolute", left: 0, right: 0, top: 0, display: "flex", flexDirection: "column", gap: 8 }}>
                {[0, 1, 2].map((row) => (
                  <Row key={row} index={(row + applied.size) % 4} L={L} />
                ))}
              </motion.div>
            </AnimatePresence>
          </div>
        </motion.div>
        <motion.div
          initial={false}
          animate={{ opacity: open ? ctx.n("dim") : 0 }}
          transition={spr}
          onClick={dismiss}
          style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: open ? "auto" : "none" }}
        />
        <div
          onClick={() => progress < 0.5 && present()}
          style={{
            position: "absolute",
            left: 12,
            top: 56,
            width,
            height,
            borderRadius: radius,
            overflow: "hidden",
            background: Palette.elevated,
            boxShadow: `0 ${2 + 12 * openP}px ${4 + 20 * openP}px ${black(0.08 + 0.16 * openP)}`,
            cursor: progress < 0.5 ? "pointer" : undefined,
          }}
        >
          <div style={{ position: "absolute", inset: 0, background: primaryStrong, opacity: tint }} />
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              width: PANEL.w,
              height: PANEL.h,
              padding: 14,
              display: "flex",
              flexDirection: "column",
              opacity: smooth(progress, 0.3, 0.7),
              pointerEvents: progress > 0.6 ? "auto" : "none",
            }}
          >
            <div style={{ height: 24, marginBottom: 12, display: "flex", alignItems: "center" }}>
              <span style={{ fontSize: 16, fontWeight: 700 }}>{zh ? "筛选条件" : "Filters"}</span>
              <span style={{ flex: 1 }} />
              <button type="button" onClick={reset} style={{ height: 24, fontSize: 13, fontWeight: 600, color: draft.size ? Palette.indigo : Palette.tertiaryLabel, transition: "color 0.25s" }}>
                {zh ? "重置" : "Reset"}
              </button>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 8 }}>
              {options.map((option, index) => {
                const on = draft.has(index);
                const shown = reveal(index);
                return (
                  <button key={index} type="button" onClick={() => toggle(index)} style={{ opacity: shown, transform: `scale(${0.8 + 0.2 * shown})`, minWidth: 0 }}>
                    <motion.div
                      initial={false}
                      animate={{ scale: on ? 1 : 0.97 }}
                      transition={pillSpring}
                      style={{ position: "relative", height: 32, borderRadius: 16, background: Palette.labelAlpha(0.07), display: "grid", placeItems: "center", padding: "0 6px", overflow: "hidden" }}
                    >
                      <motion.div initial={false} animate={{ opacity: on ? 1 : 0 }} transition={pillSpring} style={{ position: "absolute", inset: 0, background: primaryStrong }} />
                      <span style={{ position: "relative", fontSize: option[L].length > 10 ? 10.5 : 12, fontWeight: 600, whiteSpace: "nowrap", color: on ? "#fff" : Palette.label, transition: "color 0.2s" }}>{option[L]}</span>
                    </motion.div>
                  </button>
                );
              })}
            </div>
            <span style={{ flex: 1 }} />
            <button
              type="button"
              onClick={apply}
              style={{
                height: 40,
                borderRadius: 14,
                background: primaryStrong,
                color: "#fff",
                fontSize: 14,
                fontWeight: 600,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                gap: 5,
                opacity: reveal(6),
                transform: `translateY(${(1 - reveal(6)) * 10}px)`,
              }}
            >
              <span>{zh ? "查看" : "Show"}</span>
              <NumericText value={count} />
              <span>{zh ? "个结果" : "stays"}</span>
            </button>
          </div>
          <div
            style={{
              position: "absolute",
              left: 0,
              top: 0,
              width: cw,
              height: 32,
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              gap: 6,
              opacity: 1 - smooth(progress, 0, 0.3),
              pointerEvents: "none",
              color: badged ? "#fff" : Palette.label,
            }}
          >
            <SlidersHorizontal size={13} strokeWidth={2.6} />
            <span style={{ fontSize: 13, fontWeight: 600, whiteSpace: "nowrap" }}>{zh ? "筛选" : "Filters"}</span>
            {badged ? (
              <span
                style={{
                  width: 18,
                  height: 18,
                  borderRadius: 9,
                  background: "#fff",
                  color: "#4B57E0",
                  fontSize: 11,
                  fontWeight: 700,
                  display: "grid",
                  placeItems: "center",
                  fontVariantNumeric: "tabular-nums",
                  transform: `scale(${badgeScale})`,
                }}
              >
                {applied.size}
              </span>
            ) : null}
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en={open ? "Pick options, then apply" : "Tap the Filters chip"} zh={open ? "选几项，再点应用" : "点击「筛选」胶囊"} />
    </Column>
  );
}

function StaticChip({ title }: { title: string }) {
  return (
    <div style={{ height: 32, padding: "0 12px", borderRadius: 16, background: Palette.elevated, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, display: "flex", alignItems: "center", gap: 5 }}>
      <span style={{ fontSize: 13, fontWeight: 600, whiteSpace: "nowrap" }}>{title}</span>
      <ChevronDown size={11} strokeWidth={3.4} style={{ color: Palette.secondaryLabel }} />
    </div>
  );
}

const rowNames: [string, string][] = [
  ["Cedar Loft", "雪松阁楼"],
  ["Kamo Riverside House", "鸭川河畔町屋"],
  ["Bamboo Courtyard", "竹影小院"],
  ["Lantern Machiya", "灯笼町屋"],
];
const rowPrices = ["$128", "$214", "$96", "$172"];
const rowRatings = ["4.9", "4.8", "4.7", "4.9"];
const rowTints: [string, string][] = [
  [Palette.amber, Palette.coral],
  [Palette.sky, Palette.blue],
  [Palette.mint, Palette.green],
  [Palette.pink, Palette.violet],
];
const rowIcons: LucideIcon[] = [House, Waves, Leaf, Lamp];

function Row({ index, L }: { index: number; L: number }) {
  const Icon = rowIcons[index];
  return (
    <div style={{ padding: 8, borderRadius: 18, background: Palette.elevated, display: "flex", alignItems: "center", gap: 12 }}>
      <div style={{ width: 46, height: 46, flexShrink: 0, borderRadius: 12, background: diag(...rowTints[index]), color: "#fff", display: "grid", placeItems: "center" }}>
        <Icon size={21} strokeWidth={2.3} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 3, minWidth: 0 }}>
        <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600, whiteSpace: "nowrap" }}>{rowNames[index][L]}</span>
        <span style={{ display: "flex", alignItems: "center", gap: 3, fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel }}>
          <Star size={11} fill={Palette.amber} strokeWidth={0} />
          {rowRatings[index]}
        </span>
      </div>
      <span style={{ flex: 1 }} />
      <span style={{ fontSize: 14, fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{rowPrices[index]}</span>
    </div>
  );
}
