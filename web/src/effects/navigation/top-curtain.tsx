/** navigation.top-curtain · 顶部幕帘面板 (Navigation+TopCurtain.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Flashlight, Moon, Plane, ScanQrCode, Sun, Timer, Wifi } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, localPoint, rubberBand, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { Bounce } from "./groupA-kit";
import { colorGradient, useMotionNumber } from "./nav-util";
import { diag, stageColumn, useNavPan } from "./_r2";

const TOGGLES: { icon: ReactNode; label: [string, string]; color: string }[] = [
  { icon: <Wifi size={20} strokeWidth={2.8} />, label: ["Wi-Fi", "无线网络"], color: Palette.blue },
  { icon: <Moon size={19} fill="currentColor" strokeWidth={2} />, label: ["Focus", "专注"], color: Palette.violet },
  { icon: <Plane size={19} fill="currentColor" strokeWidth={1.6} />, label: ["Flight", "飞行"], color: Palette.coral },
  { icon: <Flashlight size={19} fill="currentColor" strokeWidth={2} />, label: ["Torch", "手电"], color: Palette.amber },
];
const FRAME = { w: 290, h: 284 };
const HEIGHT = 196;
const LIP = 26;
const TRAVEL = HEIGHT - LIP;

export default function TopCurtain({ ctx }: DemoProps) {
  const haptics = useHaptics();
  /** How far the panel is pulled out: 0 (only the lip shows) … travel (fully open). */
  const pulledMV = useMotionValue(0);
  const pulled = useMotionNumber(pulledMV);
  const [isOpen, setOpenState] = useState(false);
  const openRef = useRef(false);
  const dragBase = useRef<number | null>(null);
  const [toggles, setToggles] = useState([true, false, false, true]);
  const [level, setLevel] = useState(0.6);
  const [settleSpring, setSettleSpring] = useState(() => spring(0.5, 0.62));

  const settle = (open: boolean) => {
    haptics.tap(open ? "soft" : "light");
    const t = spring(ctx.n("response"), open ? ctx.n("damping") : Math.max(ctx.n("damping"), 0.85));
    setSettleSpring(t);
    animate(pulledMV, open ? TRAVEL : 0, t);
    openRef.current = open;
    setOpenState(open);
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (dragBase.current === null) {
          pulledMV.stop();
          dragBase.current = pulledMV.get();
        }
        let value = dragBase.current + s.translation.y;
        if (value > TRAVEL) value = TRAVEL + rubberBand(value - TRAVEL, 60);
        if (value < 0) value = -rubberBand(-value, 14);
        pulledMV.set(value);
      },
      onEnd: (s) => {
        if (dragBase.current === null) return;
        dragBase.current = null;
        const projected = pulledMV.get() + (s?.velocity.y ?? 0) * 0.2;
        settle(projected > TRAVEL / 2);
      },
    },
    { directions: ["down", "up"] },
  );

  useAutoplay(ctx.isPreview, () => settle(!openRef.current), { every: 1.7 });

  const fraction = pulled / TRAVEL;
  const t = Math.min(Math.max(fraction, 0), 1);
  const tuck = (index: number) => -(1 - fraction) * (10 + 8 * (index + 1));
  const bend = isOpen ? 16 : 0;
  const cap = { width: 19, height: 5, borderRadius: 2.5, background: Palette.labelAlpha(0.28) } as const;

  return (
    <div style={stageColumn(14)}>
      <div style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 32, overflow: "hidden", background: "#000", boxShadow: "0 10px 18px rgb(0 0 0 / 0.16)" }}>
        {/* page */}
        <div
          onClick={() => openRef.current && settle(false)}
          style={{
            position: "absolute",
            inset: 0,
            borderRadius: 32,
            overflow: "hidden",
            background: Palette.surface,
            transformOrigin: "50% 100%",
            transform: `scale(${1 - ctx.n("depth") * t})`,
            filter: t > 0.001 ? `blur(${3 * t}px)` : undefined,
          }}
        >
          <div style={{ padding: "0 18px", display: "flex", flexDirection: "column", gap: 12 }}>
            <div style={{ paddingTop: 34, fontSize: 22, lineHeight: "28px", fontWeight: 700 }}>{ctx.t("Today", "今天")}</div>
            <div style={{ position: "relative", height: 96, borderRadius: 20, background: diag(Palette.mint, Palette.sky, Palette.violet), flexShrink: 0 }}>
              <div style={{ position: "absolute", left: 14, bottom: 14, fontSize: 17, lineHeight: "22px", fontWeight: 600, color: "#fff" }}>{ctx.t("3 tasks left", "还剩 3 项任务")}</div>
            </div>
            {[0, 1].map((row) => (
              <div key={row} style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{ width: 34, height: 34, borderRadius: 10, background: Palette.labelAlpha(0.08), flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
                </div>
              </div>
            ))}
          </div>
          <div style={{ position: "absolute", inset: 0, background: "#000", opacity: ctx.n("dim") * t, pointerEvents: "none" }} />
        </div>
        {/* panel */}
        <div
          {...pan}
          style={{
            position: "absolute",
            left: 0,
            top: -80 - TRAVEL + pulled,
            width: FRAME.w,
            borderRadius: "0 0 28px 28px",
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 8px 16px rgb(0 0 0 / 0.22)`,
            overflow: "hidden",
            touchAction: "none",
          }}
        >
          {/* extra fill above the content, so an overshooting panel never shows a gap at the top */}
          <div style={{ height: 80 }} />
          <div style={{ height: TRAVEL, boxSizing: "border-box", padding: "14px 14px 0", display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ display: "flex", gap: 8, transform: `translateY(${tuck(0)}px)` }}>
              {TOGGLES.map((item, index) => {
                const on = toggles[index];
                return (
                  <div
                    key={index}
                    onClick={() => {
                      haptics.tap("light");
                      setToggles((v) => v.map((x, i) => (i === index ? !x : x)));
                    }}
                    style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 6, cursor: "pointer" }}
                  >
                    <div style={{ position: "relative", width: 46, height: 46, borderRadius: "50%", background: Palette.labelAlpha(0.08), display: "grid", placeItems: "center", color: on ? "#fff" : Palette.labelAlpha(0.7), transition: "color 0.25s" }}>
                      <motion.div initial={false} animate={{ opacity: on ? 1 : 0 }} transition={spring(0.3, 0.7)} style={{ position: "absolute", inset: 0, borderRadius: "50%", background: colorGradient(item.color) }} />
                      <Bounce trigger={on ? 1 : 0} style={{ position: "relative" }}>
                        {item.icon}
                      </Bounce>
                    </div>
                    <div style={{ fontSize: 10, lineHeight: "12px", fontWeight: 600, color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{ctx.t(...item.label)}</div>
                  </div>
                );
              })}
            </div>
            <div style={{ padding: "0 6px", display: "flex", alignItems: "center", gap: 10, color: Palette.secondaryLabel, transform: `translateY(${tuck(1)}px)` }}>
              <Sun size={13} fill="currentColor" strokeWidth={2.6} />
              <div
                onClick={(e) => {
                  haptics.tap("light");
                  const el = e.currentTarget;
                  setLevel(Math.min(Math.max(localPoint(e, el).x / el.offsetWidth, 0.1), 1));
                }}
                style={{ position: "relative", flex: 1, height: 22, borderRadius: 11, background: Palette.labelAlpha(0.08), overflow: "hidden", cursor: "pointer" }}
              >
                <motion.div
                  initial={false}
                  animate={{ width: `max(22px, ${level * 100}%)` }}
                  transition={spring(0.35, 0.8)}
                  style={{ position: "absolute", left: 0, top: 0, bottom: 0, borderRadius: 11, background: colorGradient(Palette.amber) }}
                />
              </div>
              <Sun size={18} fill="currentColor" strokeWidth={2.6} />
            </div>
            <div style={{ display: "flex", gap: 8, transform: `translateY(${tuck(2)}px)` }}>
              {(
                [
                  [<Timer key="t" size={15} strokeWidth={2.6} />, ["Timer", "计时器"]],
                  [<ScanQrCode key="s" size={15} strokeWidth={2.6} />, ["Scan", "扫码"]],
                ] as [ReactNode, [string, string]][]
              ).map(([icon, label], index) => (
                <div key={index} style={{ flex: 1, height: 38, borderRadius: 13, background: Palette.labelAlpha(0.07), color: Palette.labelAlpha(0.8), display: "flex", alignItems: "center", justifyContent: "center", gap: 7 }}>
                  {icon}
                  <span style={{ fontSize: 13, lineHeight: "18px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...label)}</span>
                </div>
              ))}
            </div>
          </div>
          {/* a bar that bends into an upward chevron once the panel is open */}
          <div onClick={() => settle(!openRef.current)} style={{ height: LIP, display: "grid", placeItems: "center", cursor: "pointer" }}>
            <motion.div initial={false} animate={{ y: isOpen ? 2 : 0 }} transition={settleSpring} style={{ display: "flex" }}>
              <motion.div initial={false} animate={{ rotate: -bend }} transition={settleSpring} style={{ ...cap, transformOrigin: "100% 50%" }} />
              <motion.div initial={false} animate={{ rotate: bend }} transition={settleSpring} style={{ ...cap, marginLeft: -1, transformOrigin: "0% 50%" }} />
            </motion.div>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 32, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Pull the handle down, or tap it" zh="向下拉动拉手，或点击它" />
    </div>
  );
}
