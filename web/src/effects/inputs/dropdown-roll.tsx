/** inputs.dropdown-roll (Inputs+DropdownRoll.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useState } from "react";
import { Calendar, ChevronsUpDown, Clock, Package, Rabbit, Store, Zap } from "lucide-react";
import { DemoHint, Palette, alpha, anim, black, clamp, spring, textStyle, useAutoplay, useHaptics, useSilently, type DemoProps } from "../../kit";
import { column, spacer, useLive, useMV, useTask } from "./_c-common";

interface Option {
  icon: React.ReactNode;
  tint: string;
  title: [string, string];
  price: [string, string];
  arrival: [string, string];
}
const iconProps = { size: 15, strokeWidth: 2.4 } as const;
const OPTIONS: Option[] = [
  { icon: <Package {...iconProps} />, tint: Palette.blue, title: ["Standard", "标准配送"], price: ["Free", "免费"], arrival: ["Arrives Friday", "预计周五送达"] },
  { icon: <Rabbit {...iconProps} />, tint: Palette.mint, title: ["Next day", "次日达"], price: ["$4.99", "¥12"], arrival: ["Arrives tomorrow", "预计明天送达"] },
  { icon: <Zap {...iconProps} fill="currentColor" />, tint: Palette.amber, title: ["Same day", "当日达"], price: ["$9.99", "¥25"], arrival: ["Arrives by 9 pm today", "预计今晚 9 点前送达"] },
  { icon: <Store {...iconProps} />, tint: Palette.coral, title: ["Store pickup", "到店自取"], price: ["Free", "免费"], arrival: ["Ready in 2 hours", "2 小时后可取"] },
  { icon: <Calendar {...iconProps} />, tint: Palette.violet, title: ["Scheduled", "预约配送"], price: ["$2.99", "¥8"], arrival: ["Pick a time slot", "自选送达时段"] },
];
const TARGETS = [3, 0, 2, 4, 1];
const ROW = 48;
const WIDTH = 280;
const REACH = 144;
const COUNT = OPTIONS.length;

export default function DropdownRoll({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const silently = useSilently();
  const [selected, setSelected, selectedRef] = useLive(1);
  /** The row the open list is anchored on (it stays where the field was). */
  const [origin, setOrigin] = useState(1);
  const [checked, setChecked] = useState(1);
  const openMV = useMotionValue(0);
  const [isOpen, setIsOpen, isOpenRef] = useLive(false);
  const [step, setStep] = useState(0);
  const closeTask = useTask();
  const introTask = useTask();

  const unroll = () => {
    closeTask.cancel();
    haptics.tap("light");
    setOrigin(selectedRef.current);
    setIsOpen(true);
    animate(openMV, 1, spring(ctx.n("response"), ctx.n("damping")));
  };
  const close = (index: number) => {
    closeTask.cancel();
    setChecked(index);
    setSelected(index);
    setIsOpen(false);
    animate(openMV, 0, spring(ctx.n("response") * 0.9, 0.86));
  };
  /** Check the row, then roll the list back up into it. */
  const pick = (index: number) => {
    if (!isOpenRef.current) return;
    haptics.selection();
    setChecked(index);
    closeTask.start(async (sleep) => {
      if (!(await sleep(index === selectedRef.current ? 0.05 : 0.26))) return;
      close(index);
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      if (ctx.isPreview) {
        if (step % 2 === 0) unroll();
        else pick(TARGETS[Math.floor(step / 2) % TARGETS.length]);
        setStep(step + 1);
      } else {
        // Detail arrival: open, choose, close, so the page never rests with the menu hanging open.
        introTask.start(async (sleep) => {
          unroll();
          if (!(await sleep(1.1)) || !isOpenRef.current) return;
          silently(() => pick(3));
        });
      }
    },
    { every: 1.25, delay: 0.5 },
  );

  const open = useMV(openMV);
  const clamped = clamp(open);
  const stagger = ctx.n("stagger");
  const tilt = ctx.n("tilt");

  /** Progress of a row `distance` steps from the selection: the open value, delayed by distance. */
  const progress = (distance: number) => {
    if (distance <= 0) return 1;
    const furthest = Math.max(selected, COUNT - 1 - selected);
    const raw = open * (1 + stagger * furthest) - stagger * distance;
    return Math.min(Math.max(raw, 0), Math.max(open, 1));
  };
  /** Extra offset that keeps the list anchored on `origin` and inside the stage while it is open. */
  const anchorShift = (() => {
    const top = -origin * ROW - ROW / 2;
    const bottom = (COUNT - 1 - origin) * ROW + ROW / 2;
    let fit = 0;
    if (bottom > REACH) fit = REACH - bottom;
    if (top < -REACH) fit = -REACH - top;
    return ((selected - origin) * ROW + fit) * open;
  })();
  /** Height, in rows, unrolled so far by the first `distance` rows on one side of the selection. */
  const extent = (distance: number) => {
    let sum = 0;
    for (let s = 1; s <= distance; s++) sum += progress(s);
    return sum;
  };
  /** Centre of a row: each hangs from the far edge of the one before it, and its hinge rotation does the unfolding. */
  const offset = (index: number) => {
    const distance = Math.abs(index - selected);
    if (distance <= 0) return anchorShift;
    const rows = 1 + extent(distance - 1);
    return (index < selected ? -rows : rows) * ROW + anchorShift;
  };
  const first = anchorShift - ROW / 2 - extent(selected) * ROW;
  const last = anchorShift + ROW / 2 + extent(COUNT - 1 - selected) * ROW;
  const panelHeight = Math.max(last - first, ROW);

  return (
    <div style={column}>
      <div style={spacer} />
      <div style={{ position: "relative", alignSelf: "stretch", height: 300, flexShrink: 0, display: "grid", placeItems: "center" }}>
        {isOpen && <div style={{ position: "absolute", inset: 0 }} onClick={() => close(selectedRef.current)} />}
        {/* Label above and result line below the field; the open list covers them like a real menu. */}
        <div style={{ gridArea: "1 / 1", display: "flex", flexDirection: "column", alignItems: "center", opacity: 1 - clamped * 0.6, pointerEvents: "none" }}>
          <div style={{ width: 272, ...textStyle.footnote, fontWeight: 600, color: Palette.secondaryLabel }}>{ctx.t("Delivery method", "配送方式")}</div>
          <div style={{ height: ROW + 16 }} />
          <div style={{ width: 272, display: "flex", alignItems: "center", gap: 6, ...textStyle.footnote, fontWeight: 500, color: Palette.secondaryLabel }}>
            <Clock size={14} strokeWidth={2.2} />
            <span style={{ display: "inline-grid" }}>
              <AnimatePresence initial={false}>
                <motion.span
                  key={selected}
                  initial={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
                  animate={{ opacity: 1, filter: "blur(0px)", scale: 1 }}
                  exit={{ opacity: 0, filter: "blur(6px)", scale: 0.9 }}
                  transition={anim.easeInOut(0.35)}
                  style={{ gridArea: "1 / 1", whiteSpace: "nowrap", transformOrigin: "0 50%" }}
                >
                  {ctx.t(...OPTIONS[selected].arrival)}
                </motion.span>
              </AnimatePresence>
            </span>
          </div>
        </div>
        {/* Field and list in one. */}
        <div style={{ gridArea: "1 / 1", position: "relative", width: WIDTH, height: ROW }}>
          <div
            style={{
              position: "absolute",
              left: 0,
              top: ROW / 2 + (first + last) / 2 - panelHeight / 2,
              width: WIDTH,
              height: panelHeight,
              borderRadius: 16,
              background: Palette.elevated,
              boxShadow: `inset 0 0 0 1px ${Palette.labelAlpha(0.1)}, 0 ${4 + 10 * clamped}px ${(8 + 18 * clamped) * 1.5}px ${black(0.1 + 0.14 * clamped)}`,
              pointerEvents: "none",
            }}
          />
          {OPTIONS.map((option, index) => {
            const isSelected = index === selected;
            const amount = progress(Math.abs(index - selected));
            const above = index < selected;
            const angle = isSelected ? 0 : (1 - Math.min(amount, 1)) * tilt * (above ? 1 : -1);
            const isChecked = index === checked;
            return (
              <div
                key={index}
                onClick={() => (isOpenRef.current ? pick(index) : unroll())}
                style={{
                  position: "absolute",
                  left: 0,
                  top: 0,
                  width: WIDTH,
                  height: ROW,
                  padding: "0 12px",
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  opacity: isSelected ? 1 : Math.min(amount * 1.4, 1),
                  transformOrigin: above ? "50% 100%" : "50% 0%",
                  transform: `translateY(${offset(index)}px) perspective(${WIDTH / 0.6}px) rotateX(${angle}deg)`,
                  zIndex: isSelected ? 2 : 1,
                  pointerEvents: isSelected || isOpen ? "auto" : "none",
                  cursor: "pointer",
                }}
              >
                <div
                  style={{
                    position: "absolute",
                    inset: "3px 5px",
                    borderRadius: 11,
                    background: alpha(Palette.indigo, 0.12),
                    opacity: isChecked ? clamped : 0,
                    transition: "opacity 0.2s ease-out",
                  }}
                />
                <div style={{ position: "relative", width: 28, height: 28, borderRadius: 8, background: option.tint, color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{option.icon}</div>
                <span style={{ position: "relative", ...textStyle.subheadline, fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...option.title)}</span>
                <div style={{ flex: 1 }} />
                <span style={{ position: "relative", ...textStyle.footnote, fontWeight: 500, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...option.price)}</span>
                <div style={{ position: "relative", width: 18, height: 18, display: "grid", placeItems: "center", flexShrink: 0 }}>
                  <ChevronsUpDown size={15} strokeWidth={2.8} style={{ gridArea: "1 / 1", color: Palette.secondaryLabel, opacity: isSelected ? 1 - clamped : 0 }} />
                  <svg width={14} height={11} viewBox="0 0 14 11" style={{ gridArea: "1 / 1", overflow: "visible", opacity: clamped }}>
                    <motion.path
                      d="M0 6.05 L5.04 11 L14 0"
                      fill="none"
                      stroke={Palette.indigo}
                      strokeWidth={2.4}
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      initial={false}
                      animate={{ pathLength: isChecked ? 1 : 0, opacity: isChecked ? 1 : 0 }}
                      transition={{ pathLength: anim.easeOut(0.22), opacity: { duration: isChecked ? 0.01 : 0.22 } }}
                    />
                  </svg>
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Tap the field, then choose a row" zh="点击选择框，再选一行" style={{ paddingBottom: 14 }} />
    </div>
  );
}
