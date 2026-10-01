/** navigation.context-menu-lift · 长按抬起菜单 (Navigation+ContextMenuLift.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Copy, Heart, Leaf, Share, Trash2 } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, clamp, delayed, elementScale, mix, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { useMotionNumber } from "./nav-util";
import { SunHorizonFill, diag } from "./_r2";
import { Mountain2Fill, menuGlass, useLayoutHeight } from "./_stubs-kit";

type L = [string, string];
const PHOTOS: { icon: (size: number) => ReactNode; colors: [string, string]; title: L; caption: L }[] = [
  { icon: (s) => <Mountain2Fill size={s * 1.15} />, colors: [Palette.sky, Palette.indigo], title: ["Alpine Lake", "高山湖泊"], caption: ["Yesterday · 24 photos", "昨天 · 24 张照片"] },
  { icon: (s) => <SunHorizonFill size={s * 1.1} />, colors: [Palette.amber, Palette.coral], title: ["Golden Hour", "黄金时刻"], caption: ["Sep 12 · 8 photos", "9 月 12 日 · 8 张照片"] },
  { icon: (s) => <Leaf size={s} fill="currentColor" strokeWidth={1.6} />, colors: [Palette.mint, Palette.green], title: ["Fern Study", "蕨类习作"], caption: ["Sep 3 · 15 photos", "9 月 3 日 · 15 张照片"] },
];
const ACTIONS: { icon: ReactNode; title: L; destructive?: boolean }[] = [
  { icon: <Share size={18} strokeWidth={2} />, title: ["Share", "分享"] },
  { icon: <Copy size={18} strokeWidth={2} />, title: ["Copy", "拷贝"] },
  { icon: <Heart size={18} strokeWidth={2} />, title: ["Favorite", "收藏"] },
  { icon: <Trash2 size={18} strokeWidth={2} />, title: ["Delete", "删除"], destructive: true },
];
const ROW = { w: 300, h: 64 };
const CARD = { w: 280, h: 150 };
/** Title (a 22 pt line is 26 pt tall) + spacing above the first row, inside the list's 18 pt top padding. */
const FIRST_ROW = 18 + 26 + 10;
const ROW_STEP = ROW.h + 10;

export default function ContextMenuLift({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const root = useRef<HTMLDivElement>(null);
  const stageH = useLayoutHeight(root, ctx.isPreview ? 340 : 400);
  const [lifted, setLiftedState] = useState<number | null>(null);
  const liftedRef = useRef<number | null>(null);
  /** The row is "lifted" in the model (the presentation may still be animating back). */
  const isUp = useRef(false);
  const [pressing, setPressingState] = useState<number | null>(null);
  const pressingRef = useRef<number | null>(null);
  const liftMV = useMotionValue(0);
  const lift = useMotionNumber(liftMV);
  const visit = useRef(0);
  const closeToken = useRef(0);
  const press = useRef<{ id: number; x: number; y: number; scale: number; cancel: () => void } | null>(null);
  const cancelAuto = useRef<(() => void) | null>(null);

  const hold = ctx.n("hold");
  const response = ctx.n("response");
  const move = spring(response, 0.78);

  const setPressing = (v: number | null) => {
    pressingRef.current = v;
    setPressingState(v);
  };

  const doLift = (index: number, silent = false) => {
    if (!silent) haptics.tap("medium");
    setPressing(null);
    if (liftedRef.current !== index) visit.current += 1;
    liftedRef.current = index;
    setLiftedState(index);
    isUp.current = true;
    closeToken.current += 1;
    animate(liftMV, 1, move);
  };
  const close = () => {
    if (!isUp.current) return;
    haptics.tap("light");
    isUp.current = false;
    animate(liftMV, 0, move);
    const token = ++closeToken.current;
    after(response * 1.5, () => {
      if (token !== closeToken.current) return;
      liftedRef.current = null;
      setLiftedState(null);
    });
  };

  /** Simulated long-press: sink for the hold time, then lift, silently. */
  const autoPress = () => {
    if (pressingRef.current !== null) return;
    const index = 1;
    setPressing(index);
    cancelAuto.current?.();
    cancelAuto.current = after(hold, () => {
      if (pressingRef.current !== index || isUp.current) return;
      doLift(index, true);
    });
  };
  useAutoplay(ctx.isPreview, () => (isUp.current ? close() : autoPress()), { every: 1.8 });
  useEffect(() => () => cancelAuto.current?.(), []);

  const rowDown = (index: number, e: React.PointerEvent<HTMLDivElement>) => {
    if (press.current || isUp.current || liftedRef.current !== null) return;
    if (e.pointerType === "mouse" && e.button !== 0) return;
    const el = e.currentTarget;
    try {
      el.setPointerCapture(e.pointerId);
    } catch {
      /* pointer already gone */
    }
    setPressing(index);
    const cancel = after(hold, () => {
      if (!press.current) return;
      press.current = null;
      doLift(index);
    });
    press.current = { id: e.pointerId, x: e.clientX, y: e.clientY, scale: elementScale(el) || 1, cancel };
  };
  const rowMove = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId) return;
    if (Math.hypot(e.clientX - p.x, e.clientY - p.y) / p.scale > 12) rowUp(e);
  };
  const rowUp = (e: React.PointerEvent<HTMLDivElement>) => {
    const p = press.current;
    if (!p || p.id !== e.pointerId) return;
    press.current = null;
    p.cancel();
    setPressing(null);
  };

  const listH = FIRST_ROW + PHOTOS.length * ROW_STEP - 10 + (ctx.isPreview ? 0 : 10 + 4 + 16);
  // The stack hugs its list until the scrim (which fills the stage) joins it: the list then sits at the top.
  const rest = Math.max((stageH - listH) / 2, 0);
  const l01 = clamp(lift);
  const listY = rest * (1 - lift);

  let card: ReactNode = null;
  if (lifted !== null) {
    const photo = PHOTOS[lifted];
    const from = { x: 20, y: rest + FIRST_ROW + lifted * ROW_STEP };
    const w = Math.max(mix(ROW.w, CARD.w, lift), 40);
    const h = Math.max(mix(ROW.h, CARD.h, lift), 40);
    card = (
      <>
        <div
          style={{
            position: "absolute",
            left: mix(from.x, 0, lift),
            top: mix(from.y, 18, lift),
            width: w,
            height: h,
            borderRadius: 20,
            background: Palette.elevated,
            boxShadow: "0 14px 26px rgb(0 0 0 / 0.25)",
            overflow: "hidden",
            opacity: l01,
            display: "flex",
            flexDirection: "column",
            zIndex: 2,
          }}
        >
          <div style={{ flex: 1, minHeight: 0, background: diag(...photo.colors), color: white(0.92), display: "grid", placeItems: "center", overflow: "hidden" }}>{photo.icon(54)}</div>
          <div style={{ padding: "10px 14px", display: "flex", flexDirection: "column", gap: 2, flexShrink: 0 }}>
            <div style={{ fontSize: 17, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...photo.title)}</div>
            <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...photo.caption)}</div>
          </div>
        </div>
        {/* The menu's divider makes its stack as wide as the stage, exactly like the app. */}
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 18 + CARD.h + 10,
            transform: `scale(${mix(0.4, 1, lift)})`,
            transformOrigin: "0% 0%",
            opacity: l01,
            pointerEvents: isUp.current ? "auto" : "none",
            zIndex: 2,
          }}
        >
          <LiftMenu key={visit.current} ctx={ctx} onSelect={close} />
        </div>
      </>
    );
  }

  return (
    <div ref={root} style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div
        style={{
          position: "absolute",
          left: 20,
          top: 0,
          width: ROW.w,
          paddingTop: 18,
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-start",
          gap: 10,
          transform: `translateY(${listY}px) scale(${1 - 0.03 * lift})`,
          filter: l01 > 0.001 ? `blur(${ctx.n("blur") * l01}px)` : undefined,
        }}
      >
        <div style={{ fontSize: 22, lineHeight: "26px", fontWeight: 700 }}>{ctx.t("Albums", "相簿")}</div>
        {PHOTOS.map((photo, index) => {
          const isPressing = pressing === index;
          return (
            <motion.div
              key={index}
              onPointerDown={(e) => rowDown(index, e)}
              onPointerMove={rowMove}
              onPointerUp={rowUp}
              onPointerCancel={rowUp}
              initial={false}
              animate={{ scale: isPressing ? 0.96 : 1 }}
              transition={isPressing ? anim.easeOut(hold) : spring(0.3, 0.7)}
              style={{
                width: ROW.w,
                height: ROW.h,
                padding: "0 10px",
                display: "flex",
                alignItems: "center",
                gap: 12,
                borderRadius: 18,
                background: Palette.elevated,
                boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 8px rgb(0 0 0 / 0.06)`,
                opacity: lifted === index ? 1 - l01 : 1,
                cursor: "pointer",
                touchAction: "pan-y",
                userSelect: "none",
                WebkitUserSelect: "none",
                flexShrink: 0,
              }}
            >
              <div style={{ width: 44, height: 44, borderRadius: 10, background: diag(...photo.colors), color: white(0.92), display: "grid", placeItems: "center", flexShrink: 0 }}>{photo.icon(20)}</div>
              <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
                <div style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...photo.title)}</div>
                <div style={{ fontSize: 12, lineHeight: "14px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...photo.caption)}</div>
              </div>
            </motion.div>
          );
        })}
        <DemoHint ctx={ctx} en="Press and hold a row" zh="长按任意一行" style={{ marginTop: 4, lineHeight: "16px" }} />
      </div>
      <div onClick={close} style={{ position: "absolute", inset: 0, background: "#000", opacity: 0.15 * l01, pointerEvents: lifted !== null ? "auto" : "none", zIndex: 1 }} />
      {card}
    </div>
  );
}

function LiftMenu({ ctx, onSelect }: { ctx: DemoContext; onSelect: () => void }) {
  return (
    <div
      style={{
        ...menuGlass(),
        padding: "4px 0",
        borderRadius: 16,
        boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 10px 22px rgb(0 0 0 / 0.18)`,
        display: "flex",
        flexDirection: "column",
        alignItems: "flex-start",
      }}
    >
      {ACTIONS.map((action, index) => [
        action.destructive && <div key={`d${index}`} style={{ alignSelf: "stretch", height: 1, background: Palette.labelAlpha(0.12) }} />,
        <motion.button
          key={index}
          onClick={onSelect}
          initial={{ opacity: 0, y: -6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={delayed(spring(0.35, 0.85), 0.05 + index * 0.03)}
          style={{
            width: 200,
            height: 34,
            padding: "0 14px",
            display: "flex",
            alignItems: "center",
            gap: 12,
            fontSize: 15,
            lineHeight: "20px",
            color: action.destructive ? Palette.red : Palette.label,
            textAlign: "left",
            flexShrink: 0,
          }}
        >
          <span style={{ whiteSpace: "nowrap" }}>{ctx.t(...action.title)}</span>
          <span style={{ flex: 1, minWidth: 24 }} />
          {action.icon}
        </motion.button>,
      ])}
    </div>
  );
}
