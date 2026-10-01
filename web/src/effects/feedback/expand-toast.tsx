/** feedback.expand-toast · 可展开详情吐司 (Feedback+ExpandToast.swift) */
import { ChevronDown } from "lucide-react";
import { motion, type Transition } from "motion/react";
import { useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, black, delayed, fonts, hex, spring, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { FeedbackMockRows, FeedbackScene } from "./_scene";
import { SPRINGS, track } from "./shared";

const TRACK = 150;
const INK = hex(0x3a2300);

/** SF `airplane`, pointing right (lucide's plane is a different, tilted shape). */
const Airplane = ({ size, color }: { size: number; color: string }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
    <path d="M22.5 12c0-1.1-1.7-1.9-3.2-1.9h-4.4L9.7 2.6H7.3l2.9 7.5H5.9L3.8 7.4H2l1.4 4.6L2 16.6h1.8l2.1-2.7h4.3l-2.9 7.5h2.4l5.2-7.5h4.4c1.5 0 3.2-.8 3.2-1.9z" />
  </svg>
);

export default function ExpandToast({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const [expanded, setExpanded] = useState(false);
  const [presses, setPresses] = useState(0);
  const sp = spring(ctx.n("response"), ctx.n("damping"));

  const toggle = () => {
    haptics.tap();
    setPresses((n) => n + 1);
    setExpanded((v) => !v);
  };
  useAutoplay(ctx.isPreview, toggle, { every: 2.4, delay: 0.8 });

  const e = useElapsed(presses, 1.2, true);
  const squeeze = e < 0 ? 1 : track(e, 1, [{ cubic: 0.965, d: 0.09 }, { spring: 1, d: 0.4, ...SPRINGS.bouncy }]);

  /** A detail row rising out of a blur once the toast is open. */
  const reveal = (index: number, children: ReactNode) => {
    const rise = delayed(spring(ctx.n("response") * 0.9, 0.82), 0.08 + index * ctx.n("stagger"));
    return (
      <motion.div
        initial={false}
        animate={{ opacity: expanded ? 1 : 0, y: expanded ? 0 : 12, filter: `blur(${expanded ? 0 : 6}px)` }}
        transition={expanded ? rise : anim.easeOut(0.15)}
      >
        {children}
      </motion.div>
    );
  };
  const routeT: Transition = expanded ? delayed(spring(0.9, 0.85), 0.18) : anim.easeOut(0.15);
  const reach = expanded ? TRACK * 0.38 : 0;

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <FeedbackScene width={300} height={270}>
        {/* Page */}
        <motion.div initial={false} animate={{ scale: expanded ? 0.96 : 1 }} transition={sp} style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", paddingTop: 76 }}>
          <FeedbackMockRows count={4} rowHeight={46} />
        </motion.div>
        <motion.div initial={false} animate={{ opacity: expanded ? 0.18 : 0 }} transition={sp} style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: "none" }} />

        {/* Toast */}
        <div style={{ position: "absolute", left: 0, right: 0, top: 14, display: "flex", justifyContent: "center", pointerEvents: "none" }}>
          <div style={{ transform: `scale(${squeeze})` }}>
            <motion.div
              onClick={ctx.isPreview ? undefined : toggle}
              initial={false}
              animate={{
                width: expanded ? 272 : 236,
                height: expanded ? 212 : 54,
                borderRadius: expanded ? 26 : 27,
                boxShadow: expanded ? `0 12px 44px ${black(0.34)}` : `0 6px 24px ${black(0.24)}`,
              }}
              transition={sp}
              style={{ position: "relative", overflow: "hidden", background: `linear-gradient(${hex(0x25252c)}, ${hex(0x151519)})`, pointerEvents: "auto", cursor: "pointer" }}
            >
              {/* Details: always present, 272 wide, centred under the header. */}
              <div style={{ position: "absolute", left: "50%", marginLeft: -136, top: 62, width: 272, padding: "0 14px", display: "flex", flexDirection: "column", gap: 12, pointerEvents: "none" }}>
                {reveal(
                  0,
                  <div style={{ height: 20, display: "flex", alignItems: "center", justifyContent: "center", gap: 10, fontFamily: fonts.mono, fontSize: 12, lineHeight: "16px", fontWeight: 700, color: white(0.75) }}>
                    <span>SFO</span>
                    <div style={{ position: "relative", width: TRACK, height: 16 }}>
                      <div style={{ position: "absolute", left: 0, top: 6.5, width: TRACK, height: 3, borderRadius: 1.5, background: white(0.16) }} />
                      <motion.div initial={false} animate={{ width: reach }} transition={routeT} style={{ position: "absolute", left: 0, top: 6.5, height: 3, borderRadius: 1.5, background: Palette.amber }} />
                      <motion.div initial={false} animate={{ x: reach - 4 }} transition={routeT} style={{ position: "absolute", left: 0, top: 0, width: 16, height: 16, display: "grid", placeItems: "center" }}>
                        <Airplane size={14} color={Palette.amber} />
                      </motion.div>
                    </div>
                    <span>NRT</span>
                  </div>,
                )}
                {reveal(
                  1,
                  <div style={{ display: "flex", gap: 8 }}>
                    <Fact label={zh ? "起飞" : "Dep"} old="18:40" value="19:25" highlight />
                    <Fact label={zh ? "登机口" : "Gate"} value="B7" />
                    <Fact label={zh ? "座位" : "Seat"} value="24A" />
                  </div>,
                )}
                {reveal(
                  2,
                  <div style={{ display: "flex", gap: 8, fontSize: 13, lineHeight: "18px", fontWeight: 600 }}>
                    <div style={{ flex: 1, height: 34, borderRadius: 17, background: "#fff", color: "#000", display: "grid", placeItems: "center" }}>{zh ? "改签" : "Rebook"}</div>
                    <div style={{ flex: 1, height: 34, borderRadius: 17, background: white(0.13), color: "#fff", display: "grid", placeItems: "center" }}>{zh ? "知道了" : "Got it"}</div>
                  </div>,
                )}
              </div>

              {/* Header */}
              <motion.div
                initial={false}
                animate={{ height: expanded ? 62 : 54, paddingLeft: expanded ? 14 : 11 }}
                transition={sp}
                style={{ position: "absolute", left: 0, top: 0, width: "100%", paddingRight: 14, display: "flex", alignItems: "center", gap: 11 }}
              >
                <motion.div
                  initial={false}
                  animate={{ width: expanded ? 38 : 32, height: expanded ? 38 : 32, borderRadius: expanded ? 12 : 10 }}
                  transition={sp}
                  style={{ flexShrink: 0, background: `linear-gradient(${hex(0xffd56b)}, ${Palette.amber})`, display: "grid", placeItems: "center" }}
                >
                  <motion.div initial={false} animate={{ scale: expanded ? 17 / 14 : 1 }} transition={sp} style={{ display: "grid", placeItems: "center" }}>
                    <Airplane size={17} color={INK} />
                  </motion.div>
                </motion.div>
                <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0, flex: 1, whiteSpace: "nowrap" }}>
                  <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, color: "#fff", overflow: "hidden", textOverflow: "ellipsis" }}>{zh ? "航班延误 45 分钟" : "Delayed 45 min"}</span>
                  <span style={{ fontSize: 11, lineHeight: "13px", color: white(0.58), overflow: "hidden", textOverflow: "ellipsis" }}>{zh ? "ML 837 · 旧金山 → 东京" : "ML 837 · SFO → NRT"}</span>
                </div>
                <motion.div
                  initial={false}
                  animate={{ rotate: expanded ? 180 : 0 }}
                  transition={sp}
                  style={{ width: 22, height: 22, flexShrink: 0, borderRadius: 11, background: white(0.1), color: white(0.55), display: "grid", placeItems: "center" }}
                >
                  <ChevronDown size={13} strokeWidth={3.2} />
                </motion.div>
              </motion.div>
              <motion.div initial={false} animate={{ borderRadius: expanded ? 26 : 27 }} transition={sp} style={{ position: "absolute", inset: 0, boxShadow: `inset 0 0 0 0.5px ${white(0.12)}`, pointerEvents: "none" }} />
            </motion.div>
          </div>
        </div>
      </FeedbackScene>
      <DemoHint ctx={ctx} en="Tap the toast" zh="点击吐司" />
    </div>
  );
}

function Fact({ label, old, value, highlight }: { label: string; old?: string; value: string; highlight?: boolean }) {
  return (
    <div style={{ flex: 1, minWidth: 0, height: 46, borderRadius: 12, background: white(0.07), padding: "0 9px", display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "flex-start", gap: 3 }}>
      <div style={{ display: "flex", gap: 4, fontSize: 11, lineHeight: "13px", color: white(0.5), whiteSpace: "nowrap" }}>
        <span>{label}</span>
        {old && <span style={{ fontVariantNumeric: "tabular-nums", textDecoration: "line-through" }}>{old}</span>}
      </div>
      <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 700, fontVariantNumeric: "tabular-nums", color: highlight ? Palette.amber : "#fff" }}>{value}</span>
    </div>
  );
}
