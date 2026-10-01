/** feedback.all-done-list · 清单全部完成 (Feedback+AllDoneList.swift) */
import { motion, useMotionValueEvent, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, NumericText, Palette, alpha, anim, black, clamp, delayed, mix, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { checkPath } from "./_scene";
import { useAnimated } from "./shared";

const TASKS = [
  { en: "Reply to Jun", zh: "回复小俊的评审", tagEn: "Work", tagZh: "工作", tint: Palette.indigo },
  { en: "Book train to Osaka", zh: "订去大阪的车票", tagEn: "Trip", tagZh: "出行", tint: Palette.coral },
  { en: "Water the plants", zh: "给龟背竹浇水", tagEn: "Home", tagZh: "家务", tint: Palette.mint },
  { en: "Run 5 km", zh: "跑步 5 公里", tagEn: "Health", tagZh: "健康", tint: Palette.amber },
];
const INITIAL = [true, true, false, false];
const ROW = 44;
const HEADER = 58;
const GREEN_FILL = `linear-gradient(#4BE08F, #1FA85B)`;

export default function AllDoneList({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [checked, setCheckedState] = useState(INITIAL);
  const [checkT, setCheckT] = useState<Transition>(spring(0.3, 0.55));
  const [struck, setStruck] = useState(false);
  const [badge, setBadgeState] = useState(false);
  const [badgeCheck, setBadgeCheck] = useState(false);
  // `fold` and the badge morph are interpolated every frame, like the Animatable card.
  const [fold, foldTo] = useAnimated(0);
  const [morph, morphTo] = useAnimated(0);
  const [, setFrame] = useState(0);
  useMotionValueEvent(fold, "change", () => setFrame((n) => n + 1));
  useMotionValueEvent(morph, "change", () => setFrame((n) => n + 1));
  const checkedRef = useRef(INITIAL);
  const badgeRef = useRef(false);
  const busy = useRef(false);
  const zh = ctx.lang === "zh";

  const setChecked = (next: boolean[], t: Transition) => {
    checkedRef.current = next;
    setCheckT(t);
    setCheckedState(next);
  };

  const celebrate = (buzz: boolean) => {
    clearAll();
    busy.current = true;
    const stagger = ctx.n("stagger");
    const foldResponse = ctx.n("fold");
    const pop = ctx.n("pop");
    const rows = checkedRef.current.length;
    after(0.35, () => {
      setStruck(true);
      for (let i = 0; i < rows; i++) after(i * stagger, () => buzz && haptics.selection());
      after(rows * stagger + 0.22 + 0.25, () => {
        foldTo(1, spring(foldResponse, 0.86));
        after(foldResponse * 0.85, () => {
          badgeRef.current = true;
          setBadgeState(true);
          morphTo(1, spring(0.45, pop));
          setBadgeCheck(true);
          if (buzz) haptics.success();
          after(1.3, () => {
            busy.current = false;
          });
        });
      });
    });
  };

  const toggle = (index: number, buzz = true) => {
    if (busy.current || badgeRef.current || index < 0 || index >= checkedRef.current.length) return;
    if (buzz) haptics.tap();
    const next = checkedRef.current.map((c, i) => (i === index ? !c : c));
    setChecked(next, spring(0.3, 0.55));
    if (next.every(Boolean)) celebrate(buzz);
  };

  const reset = () => {
    clearAll();
    busy.current = false;
    badgeRef.current = false;
    setBadgeCheck(false);
    setBadgeState(false);
    morphTo(0, spring(0.5, 0.82));
    foldTo(0, spring(0.5, 0.82));
    setStruck(false);
    setChecked(INITIAL, spring(0.5, 0.82));
  };

  // Preview loop and intro: tick the next open task; start over once the badge has been shown.
  const advance = () => {
    if (busy.current) return;
    if (badgeRef.current) reset();
    else toggle(checkedRef.current.indexOf(false), false);
  };
  useAutoplay(ctx.isPreview, advance, { every: 1.25, delay: 0.6 });

  const amount = clamp(fold.get());
  const angle = amount * 88;
  const projected = ROW * Math.cos((angle * Math.PI) / 180);
  const listHeight = HEADER + projected * checked.length + 12;
  const m = morph.get();
  const mc = clamp(m);
  const width = Math.max(mix(272, 124, m), 0);
  const height = Math.max(mix(listHeight, 124, m), 0);
  const radius = mix(24, 62, mc);
  const done = checked.filter(Boolean).length;
  const stagger = ctx.n("stagger");

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div
        onClick={() => {
          if (badgeRef.current && !busy.current) reset();
        }}
        style={{ position: "relative", width: 300, height: 262, flexShrink: 0, display: "grid", placeItems: "center" }}
      >
        {/* AllDoneCard */}
        <div
          style={{
            gridArea: "1/1",
            position: "relative",
            width,
            height,
            borderRadius: radius,
            transform: `translateY(${-22 * m}px)`,
            boxShadow: `0 10px 18px ${mc > 0 ? `color-mix(in srgb, ${alpha(Palette.green, 0.35)} ${mc * 100}%, ${black(0.12)})` : black(0.12)}`,
          }}
        >
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, overflow: "hidden", background: Palette.elevated }}>
            <div style={{ position: "absolute", inset: 0, background: GREEN_FILL, opacity: mc }} />
            {/* The list keeps its own size, centred in the (shrinking) card. */}
            <div
              style={{
                position: "absolute",
                left: "50%",
                top: "50%",
                width: 272,
                height: listHeight,
                marginLeft: -136,
                marginTop: -listHeight / 2,
                opacity: 1 - mc,
                display: "flex",
                flexDirection: "column",
                pointerEvents: badge ? "none" : undefined,
              }}
            >
              <div style={{ height: HEADER, flexShrink: 0, display: "flex", flexDirection: "column", justifyContent: "center", gap: 8, padding: "6px 18px 0" }}>
                <div style={{ display: "flex", alignItems: "center" }}>
                  <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>{zh ? "今天" : "Today"}</span>
                  <div style={{ flex: 1 }} />
                  <span style={{ display: "inline-flex", fontSize: 15, lineHeight: "20px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: done === checked.length ? Palette.green : Palette.secondaryLabel }}>
                    <NumericText value={done} />/{checked.length}
                  </span>
                </div>
                <div style={{ position: "relative", height: 4, borderRadius: 2, background: Palette.labelAlpha(0.09) }}>
                  <motion.div
                    initial={false}
                    animate={{ width: `${(done / Math.max(checked.length, 1)) * 100}%` }}
                    transition={checkT}
                    style={{ position: "absolute", left: 0, top: 0, height: 4, borderRadius: 2, background: `linear-gradient(90deg, ${Palette.mint}, ${Palette.green})` }}
                  />
                </div>
              </div>
              {checked.map((isChecked, index) => {
                const task = TASKS[index % TASKS.length];
                const even = index % 2 === 0;
                const shade = Math.sin((angle * Math.PI) / 180) * (even ? 0.1 : 0.3);
                const strike = struck ? delayed(anim.easeOut(0.22), index * stagger) : anim.easeOut(0.15);
                return (
                  <div key={index} style={{ position: "relative", height: projected, flexShrink: 0 }}>
                    <div
                      onClick={(e) => {
                        e.stopPropagation();
                        toggle(index);
                      }}
                      style={{
                        position: "absolute",
                        left: 0,
                        [even ? "top" : "bottom"]: 0,
                        width: 272,
                        height: ROW,
                        display: "flex",
                        alignItems: "center",
                        gap: 12,
                        padding: "0 18px",
                        background: Palette.elevated,
                        cursor: "pointer",
                        transformOrigin: even ? "50% 0%" : "50% 100%",
                        // rotation3DEffect(perspective: 0.35): eye distance = max(w, h) / 0.35.
                        transform: angle > 0.01 ? `perspective(${272 / 0.35}px) rotateX(${even ? -angle : angle}deg)` : undefined,
                      }}
                    >
                      <Check checked={isChecked} t={checkT} />
                      <span style={{ position: "relative", fontSize: 15, lineHeight: "20px", fontWeight: 500, whiteSpace: "nowrap" }}>
                        <motion.span initial={false} animate={{ opacity: struck ? 0.45 : 1 }} transition={strike}>
                          {zh ? task.zh : task.en}
                        </motion.span>
                        <motion.span
                          initial={false}
                          animate={{ scaleX: struck ? 1 : 0 }}
                          transition={strike}
                          style={{ position: "absolute", left: -3, right: -3, top: "50%", height: 1.6, borderRadius: 0.8, background: Palette.labelAlpha(0.7), transformOrigin: "0% 50%" }}
                        />
                      </span>
                      <div style={{ flex: 1 }} />
                      <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: task.tint, padding: "0 8px", height: 20, borderRadius: 10, display: "inline-flex", alignItems: "center", background: alpha(task.tint, 0.14), whiteSpace: "nowrap" }}>
                        {zh ? task.tagZh : task.tagEn}
                      </span>
                      {shade > 0.001 && <div style={{ position: "absolute", inset: 0, background: black(shade), pointerEvents: "none" }} />}
                      <div style={{ position: "absolute", left: 0, right: 0, [even ? "bottom" : "top"]: 0, height: 0.5, background: Palette.labelAlpha(0.06) }} />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
        </div>

        {/* badgeFace. The Swift view also declares twelve rays, but their opacity is
            `rays ? 0 : (badge ? 1 : 0)` and both flags flip in the same update, so the app never shows them. */}
        <svg width={52} height={40} viewBox="0 0 52 40" style={{ gridArea: "1/1", overflow: "visible", transform: "translateY(-22px)", pointerEvents: "none" }}>
          <motion.path
            d={checkPath(52, 40)}
            fill="none"
            stroke="#fff"
            strokeWidth={9}
            strokeLinecap="round"
            strokeLinejoin="round"
            initial={false}
            animate={{ pathLength: badgeCheck ? 1 : 0, opacity: badgeCheck ? 1 : 0 }}
            transition={badgeCheck ? { pathLength: delayed(anim.easeOut(0.3), 0.16), opacity: { duration: 0.01, delay: 0.16 } } : anim.easeOut(0.15)}
          />
        </svg>
        <motion.div
          initial={false}
          animate={{ y: badgeCheck ? 72 : 84, opacity: badgeCheck ? 1 : 0 }}
          transition={badgeCheck ? delayed(anim.easeOut(0.3), 0.16) : anim.easeOut(0.15)}
          style={{ gridArea: "1/1", display: "flex", flexDirection: "column", alignItems: "center", gap: 2, pointerEvents: "none", whiteSpace: "nowrap" }}
        >
          <span style={{ fontSize: 20, lineHeight: "25px", fontWeight: 700 }}>{zh ? "全部完成" : "All done"}</span>
          <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>{zh ? "今天的 4 项任务" : "4 tasks today"}</span>
        </motion.div>
      </div>
      <DemoHint ctx={ctx} en="Tick the remaining tasks" zh="勾掉剩下的任务" />
    </div>
  );
}

/** AllDoneCheck: a ring that springs into a green disc while the check is written. */
function Check({ checked, t }: { checked: boolean; t: Transition }) {
  return (
    <div style={{ position: "relative", width: 24, height: 24, flexShrink: 0, display: "grid", placeItems: "center" }}>
      <motion.div initial={false} animate={{ opacity: checked ? 0 : 1 }} transition={t} style={{ position: "absolute", inset: 0, borderRadius: 12, boxShadow: `inset 0 0 0 1.6px ${Palette.labelAlpha(0.25)}` }} />
      <motion.div
        initial={false}
        animate={{ scale: checked ? 1 : 0.3, opacity: checked ? 1 : 0 }}
        transition={t}
        style={{ position: "absolute", inset: 0, borderRadius: 12, background: `linear-gradient(#4BE08F, ${Palette.green})` }}
      />
      <svg width={10.5} height={8} viewBox="0 0 10.5 8" style={{ position: "relative", overflow: "visible" }}>
        <motion.path
          d={checkPath(10.5, 8)}
          fill="none"
          stroke="#fff"
          strokeWidth={2.4}
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={false}
          animate={{ pathLength: checked ? 1 : 0, opacity: checked ? 1 : 0 }}
          transition={checked ? { pathLength: delayed(anim.easeOut(0.2), 0.08), opacity: { duration: 0.01, delay: 0.08 } } : anim.linear(0.05)}
        />
      </svg>
    </div>
  );
}
