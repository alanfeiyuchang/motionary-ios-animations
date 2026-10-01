/** navigation.curve-fab-bar · 凹槽悬浮按钮栏 (Navigation+CurveFabBar.swift) */
import { animate, motion, useMotionValue, useTransform } from "motion/react";
import { Plus, Search } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, alpha, anim, delayed, spring, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { BOUNCY, Glyph, cubicKF, linearKF, springKF, track, useSince } from "./groupB-kit";
import { useMotionNumber } from "./nav-util";
import { NavigationScreenPlaceholder } from "./shared";
import { CameraFill, DocTextFill, PhotoFill, diag, useAutoplayFlag } from "./_r2";

const TAB_ICONS: ReactNode[] = [
  <Glyph key={0} name="house.fill" size={21} />,
  <Search key={1} size={21} strokeWidth={2.8} />,
  <Glyph key={2} name="bell.fill" size={21} />,
  <Glyph key={3} name="person.fill" size={21} />,
];
const TAB_X = [36, 84, 228, 276];

const ACTIONS: { icon: ReactNode; title: [string, string]; colors: [string, string]; angle: number }[] = [
  { icon: <CameraFill size={21} />, title: ["Camera", "拍摄"], colors: [Palette.pink, Palette.coral], angle: 152 },
  { icon: <PhotoFill size={21} />, title: ["Photo", "照片"], colors: [Palette.amber, Palette.coral], angle: 90 },
  { icon: <DocTextFill size={21} />, title: ["Note", "笔记"], colors: [Palette.mint, Palette.sky], angle: 28 },
];

const BAR_W = 312;
const BAR_H = 64;
const FAB = 56;
const LIFT = 64;
const REST = -FAB / 2 - 4;

/** `CurveFabBarShape` */
function barPath(depth: number): string {
  const corner = 24;
  const half = 46;
  const x = BAR_W / 2;
  return [
    `M0 ${corner}Q0 0 ${corner} 0`,
    `L${x - half - 14} 0`,
    `C${x - half * 0.62} 0 ${x - half * 0.72} ${depth} ${x} ${depth}`,
    `C${x + half * 0.72} ${depth} ${x + half * 0.62} 0 ${x + half + 14} 0`,
    `L${BAR_W - corner} 0Q${BAR_W} 0 ${BAR_W} ${corner}`,
    `L${BAR_W} ${BAR_H - corner}Q${BAR_W} ${BAR_H} ${BAR_W - corner} ${BAR_H}`,
    `L${corner} ${BAR_H}Q0 ${BAR_H} 0 ${BAR_H - corner}Z`,
  ].join("");
}

function ActionDisc({ index, open, ctx, onPick }: { index: number; open: boolean; ctx: DemoProps["ctx"]; onPick: () => void }) {
  const action = ACTIONS[index];
  const progress = useMotionValue(0);
  const response = ctx.n("response");
  const radius = ctx.n("radius");
  const swirl = ctx.n("swirl");
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    const delay = open ? 0.06 + index * 0.045 : (ACTIONS.length - 1 - index) * 0.03;
    const controls = animate(progress, open ? 1 : 0, delayed(open ? spring(response, 0.62) : spring(response * 0.7, 0.9), delay));
    return () => controls.stop();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);
  const angleOf = (p: number) => ((action.angle - swirl * (1 - p)) * Math.PI) / 180;
  const x = useTransform(progress, (p) => Math.cos(angleOf(p)) * radius * p);
  const y = useTransform(progress, (p) => -Math.sin(angleOf(p)) * radius * p);
  const scale = useTransform(progress, (p) => 0.3 + 0.7 * Math.max(p, 0));
  const opacity = useTransform(progress, (p) => Math.min(Math.max(p * 1.8, 0), 1));
  return (
    <motion.div
      onClick={(e) => {
        e.stopPropagation();
        onPick();
      }}
      style={{
        position: "absolute",
        left: (FAB - 48) / 2,
        top: (FAB - 48) / 2,
        width: 48,
        height: 48,
        x,
        y,
        scale,
        opacity,
        borderRadius: "50%",
        background: diag(...action.colors),
        boxShadow: `inset 0 0 0 1px ${white(0.3)}, 0 5px 10px ${alpha(action.colors[0], 0.4)}`,
        color: "#fff",
        display: "grid",
        placeItems: "center",
        cursor: "pointer",
      }}
    >
      {action.icon}
      <div style={{ position: "absolute", left: "50%", bottom: -17, transform: "translate(-50%, 0)", fontSize: 10, lineHeight: "12px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>
        {ctx.t(...action.title)}
      </div>
    </motion.div>
  );
}

export default function CurveFabBar({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [open, setOpen] = useState(false);
  const openRef = useRef(false);
  const [selected, setSelected] = useState(0);
  const [landings, setLandings] = useState(0);
  const landingsRef = useRef(0);
  const response = ctx.n("response");
  const depthMV = useMotionValue(ctx.n("depth"));
  const depth = useMotionNumber(depthMV);
  const depthParam = ctx.n("depth");
  useEffect(() => {
    if (!openRef.current) depthMV.jump(depthParam);
  }, [depthParam, depthMV]);

  const auto = useAutoplayFlag(ctx.isPreview, () => toggle(), { every: 1.6 });

  function toggle() {
    const opening = !openRef.current;
    const live = !auto.current;
    haptics.tap("light");
    openRef.current = opening;
    setOpen(opening);
    // Open: the freed edge snaps flat and wobbles. Close: the notch re-forms a beat after the button starts to fall.
    animate(depthMV, opening ? 0 : ctx.n("depth"), opening ? delayed(spring(response * 0.9, 0.42), 0.04) : delayed(spring(response, 0.45), response * 0.25));
    if (opening) return;
    landingsRef.current += 1;
    const current = landingsRef.current;
    setLandings(current);
    if (!live) return;
    // The haptic lands with the button, not on touch-down.
    after(response * 0.5, () => {
      if (landingsRef.current !== current || openRef.current) return;
      haptics.tap("medium");
    });
  }

  const pick = () => {
    haptics.success();
    if (openRef.current) toggle();
  };

  const select = (index: number) => {
    if (openRef.current) return toggle();
    if (index === selected) return;
    haptics.selection();
    setSelected(index);
  };

  // The landing: the whole bar dips as the button drops back into its cradle.
  const landT = useSince(landings, response * 0.45 + 0.09 + 0.45);
  const dip = track(landT, 0, [linearKF(0, response * 0.45), cubicKF(4, 0.09), springKF(0, 0.45, BOUNCY)]);
  const fabSpring = open ? spring(response, 0.68) : spring(response * 0.9, 0.6);

  return (
    <div
      onClick={() => openRef.current && toggle()}
      style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center" }}
    >
      <motion.div
        initial={false}
        animate={{ opacity: open ? 0.45 : 1, filter: `blur(${open ? 3 : 0}px)` }}
        transition={anim.easeInOut(0.3)}
        style={{ paddingTop: 22, flexShrink: 0 }}
      >
        <NavigationScreenPlaceholder rows={3} />
      </motion.div>
      <div style={{ flex: 1 }} />
      <div style={{ position: "relative", width: BAR_W, height: BAR_H, flexShrink: 0, marginBottom: ctx.isPreview ? 22 : 0, transform: `translateY(${dip}px)` }}>
        <svg width={BAR_W} height={BAR_H} style={{ position: "absolute", left: 0, top: 0, overflow: "visible", filter: "drop-shadow(0 6px 16px rgb(0 0 0 / 0.14))" }}>
          <path d={barPath(depth)} fill={Palette.elevated} />
        </svg>
        {/* tabs */}
        {TAB_ICONS.map((icon, index) => (
          <div
            key={index}
            onClick={(e) => {
              e.stopPropagation();
              select(index);
            }}
            style={{ position: "absolute", left: TAB_X[index] - 24, top: 4, width: 48, height: BAR_H - 4, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 5, cursor: "pointer", color: index === selected ? Palette.indigo : Palette.secondaryLabel, transition: "color 0.3s" }}
          >
            <div style={{ height: 23, display: "grid", placeItems: "center" }}>{icon}</div>
            <div style={{ width: 5, height: 5 }} />
          </div>
        ))}
        <motion.div
          initial={false}
          animate={{ x: TAB_X[selected] - 2.5 }}
          transition={spring(0.35, 0.7)}
          style={{ position: "absolute", left: 0, top: 4 + (BAR_H - 4) / 2 + 9, width: 5, height: 5, borderRadius: "50%", background: Palette.indigo, pointerEvents: "none" }}
        />
        {/* actions */}
        <div style={{ position: "absolute", left: (BAR_W - FAB) / 2, top: REST - LIFT, width: FAB, height: FAB, pointerEvents: open ? "auto" : "none" }}>
          {ACTIONS.map((_, index) => (
            <ActionDisc key={index} index={index} open={open} ctx={ctx} onPick={pick} />
          ))}
        </div>
        {/* the button */}
        <motion.div
          onClick={(e) => {
            e.stopPropagation();
            toggle();
          }}
          initial={false}
          animate={{
            y: REST - (open ? LIFT : 0),
            boxShadow: `inset 0 0 0 1px ${white(0.25)}, 0 ${open ? 12 : 5}px ${open ? 18 : 9}px ${alpha(Palette.indigo, open ? 0.5 : 0.35)}`,
          }}
          transition={fabSpring}
          style={{ position: "absolute", left: (BAR_W - FAB) / 2, top: 0, width: FAB, height: FAB, borderRadius: "50%", background: Palette.primary, color: "#fff", display: "grid", placeItems: "center", cursor: "pointer" }}
        >
          <motion.div initial={false} animate={{ rotate: open ? 135 : 0 }} transition={fabSpring} style={{ display: "grid" }}>
            <Plus size={28} strokeWidth={3.4} />
          </motion.div>
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tap the + button" zh="点击加号按钮" style={{ paddingTop: 14, paddingBottom: 12 }} />
    </div>
  );
}
