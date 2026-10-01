/** navigation.radial-menu · 径向快捷菜单 (Navigation+RadialMenu.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Plus } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { Palette, alpha, anim, delayed, spring, useAutoplay, useHaptics, usePan, useTimeouts, type DemoContext, type DemoProps, type PanState, type Point } from "../../kit";
import { colorGradient } from "./groupA-kit";
import { CameraFill, PhotoFill } from "./_r2";
import { DocFill, LocationFill, MicFill, menuGlass } from "./_stubs-kit";

type L = [string, string];
const ITEMS: { icon: (size: number) => ReactNode; color: string; title: L }[] = [
  { icon: (s) => <CameraFill size={s} />, color: Palette.coral, title: ["Camera", "相机"] },
  { icon: (s) => <PhotoFill size={s} />, color: Palette.amber, title: ["Photo", "照片"] },
  { icon: (s) => <MicFill size={s} />, color: Palette.mint, title: ["Voice", "语音"] },
  { icon: (s) => <LocationFill size={s} />, color: Palette.sky, title: ["Location", "位置"] },
  { icon: (s) => <DocFill size={s} />, color: Palette.violet, title: ["File", "文件"] },
];
const BUTTON = 60;

export default function RadialMenu({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [open, setOpenState] = useState(false);
  const openRef = useRef(false);
  const [highlighted, setHighlightedState] = useState<number | null>(null);
  const highlightedRef = useRef<number | null>(null);
  const [chosen, setChosenState] = useState<number | null>(null);
  const chosenRef = useRef<number | null>(null);
  /** Which state change the item scale is answering: the open stagger or the quick highlight spring. */
  const [cause, setCause] = useState<"open" | "hot">("open");
  const badgeVisit = useRef(0);
  const previewPhase = useRef(0);
  const pressBeganOpen = useRef<boolean | null>(null);
  /** True when the current press opened the menu by moving the finger. */
  const openedByMove = useRef(false);
  const cancelled = useRef(false);
  const pressToken = useRef(0);
  const token = useRef(0);

  const radius = ctx.n("radius");
  const stagger = ctx.n("stagger");
  const angle = (index: number) => {
    const spread = (ctx.n("spread") * Math.PI) / 180;
    const start = 1.5 * Math.PI - spread / 2;
    const step = ITEMS.length > 1 ? spread / (ITEMS.length - 1) : 0;
    return start + index * step;
  };
  const position = (index: number): Point => ({ x: Math.cos(angle(index)) * radius, y: Math.sin(angle(index)) * radius });

  const setHighlighted = (v: number | null) => {
    if (v === highlightedRef.current) return;
    highlightedRef.current = v;
    setHighlightedState(v);
    setCause("hot");
  };
  const setOpen = (value: boolean) => {
    if (value) haptics.tap("medium");
    if (value !== openRef.current) setCause("open");
    openRef.current = value;
    setOpenState(value);
    if (!value) {
      highlightedRef.current = null;
      setHighlightedState(null);
    }
  };
  const commit = (index: number) => {
    haptics.success();
    highlightedRef.current = null;
    setHighlightedState(null);
    if (openRef.current) setCause("open");
    openRef.current = false;
    setOpenState(false);
    if (chosenRef.current === null) badgeVisit.current += 1;
    chosenRef.current = index;
    setChosenState(index);
    const current = ++token.current;
    after(1.1, () => {
      if (token.current === current && chosenRef.current === index) {
        chosenRef.current = null;
        setChosenState(null);
      }
    });
  };
  const dismissFromScrim = () => {
    if (!openRef.current) return;
    haptics.tap("light");
    setOpen(false);
  };

  const nearestItem = (location: Point): number | null => {
    const finger = { x: location.x - BUTTON / 2, y: location.y - BUTTON / 2 };
    let nearest: number | null = null;
    let best = 40;
    for (let index = 0; index < ITEMS.length; index++) {
      const p = position(index);
      const d = Math.hypot(p.x - finger.x, p.y - finger.y);
      if (d < best) {
        best = d;
        nearest = index;
      }
    }
    return nearest;
  };

  // Touch-down never opens the menu by itself: it opens after a short hold, once the finger has moved
  // more than 8 pt, or on a tap's release.
  const pressChanged = (s: PanState) => {
    if (pressBeganOpen.current === null) {
      pressBeganOpen.current = openRef.current;
      openedByMove.current = false;
      if (!openRef.current) {
        const current = ++pressToken.current;
        after(0.15, () => {
          if (pressToken.current !== current || pressBeganOpen.current === null || openRef.current) return;
          setOpen(true);
        });
      }
    }
    const distance = Math.hypot(s.translation.x, s.translation.y);
    if (!openRef.current && distance > 8) {
      pressToken.current += 1;
      openedByMove.current = true;
      setOpen(true);
    }
    if (!openRef.current) return;
    const nearest = nearestItem(s.location);
    if (nearest !== highlightedRef.current) {
      setHighlighted(nearest);
      if (nearest !== null) haptics.selection();
    }
  };
  const pressEnded = (s: PanState) => {
    if (cancelled.current) {
      // A cancelled press never commits; a menu it opened by moving closes again.
      const began = pressBeganOpen.current;
      if (began === null) return;
      pressBeganOpen.current = null;
      pressToken.current += 1;
      setHighlighted(null);
      if (!began && openedByMove.current) setOpen(false);
      openedByMove.current = false;
      return;
    }
    const wasOpen = pressBeganOpen.current ?? false;
    pressBeganOpen.current = null;
    openedByMove.current = false;
    pressToken.current += 1;
    const moved = Math.hypot(s.translation.x, s.translation.y) > 20;
    if (!openRef.current) setOpen(true);
    else if (highlightedRef.current !== null) commit(highlightedRef.current);
    else if (moved || wasOpen) setOpen(false);
  };
  const pan = usePan({ onChange: pressChanged, onEnd: pressEnded }, 0);

  useAutoplay(
    ctx.isPreview,
    () => {
      switch (previewPhase.current % 4) {
        case 0:
          setOpen(true);
          break;
        case 1:
          setHighlighted(1);
          break;
        case 2:
          setHighlighted(3);
          break;
        default:
          commit(3);
      }
      previewPhase.current += 1;
    },
    { every: 0.9 },
  );

  const hotSpring = spring(0.25, 0.6);
  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <motion.div initial={false} animate={{ filter: open ? "blur(2px)" : "blur(0px)" }} transition={anim.easeOut(0.25)} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
        <ChatBackdrop ctx={ctx} />
      </motion.div>
      <motion.div
        onClick={dismissFromScrim}
        initial={false}
        animate={{ opacity: open ? 0.14 : 0 }}
        transition={anim.easeOut(0.25)}
        style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: open ? "auto" : "none" }}
      />
      {!ctx.isPreview && (
        <motion.div
          initial={false}
          animate={{ opacity: open || chosen !== null ? 0 : 1 }}
          transition={anim.easeOut(0.2)}
          style={{ position: "absolute", left: 0, right: 0, top: "50%", marginTop: -9 - 40, textAlign: "center", fontSize: 13, lineHeight: "18px", fontWeight: 500, color: Palette.secondaryLabel, pointerEvents: "none" }}
        >
          {ctx.t("Press + and slide to an item", "按住 + 并滑向选项")}
        </motion.div>
      )}
      <div style={{ position: "absolute", left: "50%", bottom: 36, width: BUTTON, height: BUTTON, marginLeft: -BUTTON / 2 }}>
        {ITEMS.map((item, index) => {
          const point = position(index);
          const isHot = highlighted === index;
          const delay = open ? index * stagger : (ITEMS.length - 1 - index) * stagger * 0.5;
          const openSpring = delayed(spring(0.42, 0.68), delay);
          return (
            <motion.div
              key={index}
              onClick={() => commit(index)}
              initial={false}
              animate={{
                x: open ? point.x : 0,
                y: open ? point.y : 0,
                rotate: open ? 0 : -90,
                opacity: open ? 1 : 0,
                scale: open ? (isHot ? 1.25 : 1) : 0.3,
                boxShadow: `0px 4px ${isHot ? 14 : 6}px ${alpha(item.color, isHot ? 0.6 : 0.25)}`,
              }}
              transition={{ default: openSpring, scale: cause === "open" ? openSpring : hotSpring, boxShadow: hotSpring }}
              style={{
                position: "absolute",
                left: (BUTTON - 48) / 2,
                top: (BUTTON - 48) / 2,
                width: 48,
                height: 48,
                borderRadius: "50%",
                background: colorGradient(item.color),
                color: "#fff",
                display: "grid",
                placeItems: "center",
                pointerEvents: open ? "auto" : "none",
                cursor: "pointer",
                zIndex: isHot ? 1 : 0,
              }}
            >
              {item.icon(22)}
              <motion.div
                initial={false}
                animate={{ opacity: isHot ? 1 : 0, scale: isHot ? 1 : 0.6 }}
                transition={hotSpring}
                style={{
                  ...menuGlass(),
                  position: "absolute",
                  left: "50%",
                  top: -32,
                  x: "-50%",
                  padding: "4px 8px",
                  borderRadius: 12,
                  fontSize: 12,
                  lineHeight: "16px",
                  fontWeight: 600,
                  color: Palette.label,
                  whiteSpace: "nowrap",
                  transformOrigin: "50% 100%",
                  pointerEvents: "none",
                }}
              >
                {ctx.t(...item.title)}
              </motion.div>
            </motion.div>
          );
        })}
        <motion.div
          {...pan}
          onPointerCancel={(e) => {
            cancelled.current = true;
            pan.onPointerCancel(e);
            cancelled.current = false;
          }}
          initial={false}
          animate={{ scale: highlighted === null ? 1 : 0.9 }}
          transition={spring(0.25, 0.7)}
          style={{
            ...pan.style,
            position: "absolute",
            inset: 0,
            borderRadius: "50%",
            background: Palette.primary,
            boxShadow: `0 8px 14px ${alpha(Palette.indigo, 0.4)}`,
            color: "#fff",
            display: "grid",
            placeItems: "center",
            cursor: "pointer",
            zIndex: 2,
          }}
        >
          <motion.span initial={false} animate={{ rotate: open ? 135 : 0 }} transition={spring(0.35, 0.7)} style={{ display: "flex" }}>
            <Plus size={26} strokeWidth={3.2} />
          </motion.span>
        </motion.div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
        <AnimatePresence>
          {chosen !== null && (
            <motion.div
              key={badgeVisit.current}
              initial={{ y: -58, opacity: 0 }}
              animate={{ y: 0, opacity: 1, transition: spring(0.4, 0.8) }}
              exit={{ y: -58, opacity: 0, transition: anim.easeOut(0.25) }}
              style={{ position: "absolute", top: 22 }}
            >
              <div
                style={{
                  ...menuGlass(),
                  padding: "8px 14px",
                  borderRadius: 18,
                  display: "flex",
                  alignItems: "center",
                  gap: 7,
                  fontSize: 15,
                  lineHeight: "20px",
                  fontWeight: 600,
                  whiteSpace: "nowrap",
                }}
              >
                {ITEMS[chosen].icon(17)}
                {ctx.t(...ITEMS[chosen].title)}
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

/** A short chat so the attach menu fans out over a real conversation instead of an empty stage. */
function ChatBackdrop({ ctx }: { ctx: DemoContext }) {
  const bubble = (text: string, outgoing: boolean) => (
    <div
      style={{
        alignSelf: outgoing ? "flex-end" : "flex-start",
        padding: "9px 14px",
        borderRadius: 18,
        fontSize: 15,
        lineHeight: "18px",
        color: outgoing ? "#fff" : Palette.label,
        background: outgoing ? "linear-gradient(to bottom right, #6E7BFF, #A46BFF)" : Palette.surface,
        whiteSpace: "nowrap",
      }}
    >
      {text}
    </div>
  );
  return (
    <div style={{ position: "absolute", inset: 0, padding: "22px 20px 0", display: "flex", flexDirection: "column", gap: 10 }}>
      {bubble(ctx.t("Where should we meet tonight?", "今晚在哪儿碰头？"), false)}
      {bubble(ctx.t("Sending you the spot 📍", "我把位置发给你 📍"), true)}
      {bubble(ctx.t("Perfect — see you at 7!", "好，七点见！"), false)}
    </div>
  );
}
