/** showcase.calendar-agenda · 日程就地展开 (Showcase+CalendarAgenda.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { Calendar, ChevronDown, MapPin } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { NumericText, anim, delayed, fonts, hex, spring, springDB, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureNumber } from "./signature";
import { SportEyebrowRow, SportPress } from "./_a-sport";
import { StudioScene } from "./_studio";

const EVENTS = [
  { title: ["Design review", "设计评审"], place: ["Studio 2", "二号工作室"], start: 9 * 60 + 30, end: 10 * 60 + 15, color: 0x5aa8ff },
  { title: ["Motion sync", "动效同步会"], place: ["Video call", "视频会议"], start: 10 * 60 + 30, end: 11 * 60 + 30, color: 0xff8a1f },
  { title: ["Lunch with Mia", "和 Mia 午餐"], place: ["Corner Bistro", "街角小馆"], start: 12 * 60, end: 13 * 60, color: 0xc8f560 },
];
const clock = (minutes: number) => `${Math.trunc(Math.trunc(minutes) / 60)}:${String(Math.trunc(minutes) % 60).padStart(2, "0")}`;
const NORMAL = 46;
const OPEN = 82;
const SQUEEZED = 28;
const GAP = 6;
const DAY_START = 9 * 60 + 12;
const DAY_END = 13 * 60 + 12;

export default function CalendarAgenda({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const li = zh ? 1 : 0;
  const [expanded, setExpanded] = useState<number | null>(null);
  const [now, setNow] = useState(9 * 60 + 40);
  const [lineAnim, setLineAnim] = useState<Transition>(anim.linear(0.5));
  const st = useRef({ step: 0, now: 9 * 60 + 40 });
  const speed = ctx.n("speed");
  const expandSpring = spring(ctx.n("response"), ctx.n("damping"));

  useEffect(() => {
    const id = window.setInterval(() => {
      const s = st.current;
      if (s.now >= DAY_END) {
        s.now = DAY_START;
        setLineAnim(spring(0.6, 0.85));
      } else {
        s.now = Math.min(DAY_END, s.now + speed * 0.5);
        setLineAnim(anim.linear(0.5));
      }
      setNow(s.now);
    }, 500);
    return () => window.clearInterval(id);
  }, [speed]);

  const setOpen = (target: number | null) => {
    setLineAnim(expandSpring);
    setExpanded(target);
  };
  const autoStep = () => {
    const order = [1, 2, 0, null];
    const target = order[st.current.step % order.length];
    st.current.step += 1;
    setOpen(target);
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 1.7, delay: 0.8 });

  const height = (index: number) => (expanded === null ? NORMAL : expanded === index ? OPEN : SQUEEZED);
  const top = (index: number) => {
    let y = 0;
    for (let i = 0; i < index; i++) y += height(i) + GAP;
    return y;
  };
  const nowY = (() => {
    const total = top(EVENTS.length - 1) + height(EVENTS.length - 1);
    let previousEnd = DAY_START;
    let previousBottom = -4;
    for (let index = 0; index < EVENTS.length; index++) {
      const event = EVENTS[index];
      const y = top(index);
      if (now < event.start) return previousBottom + (y - previousBottom) * ((now - previousEnd) / Math.max(event.start - previousEnd, 1));
      if (now <= event.end) return y + height(index) * ((now - event.start) / (event.end - event.start));
      previousEnd = event.end;
      previousBottom = y + height(index);
    }
    return previousBottom + (total + 4 - previousBottom) * Math.min((now - previousEnd) / Math.max(DAY_END - previousEnd, 1), 1);
  })();
  const smooth = springDB(0.3, 0);

  return (
    <StudioScene ctx={ctx} en="Tap an event to expand it" zh="点击事件就地展开">
      <div style={{ ...signatureCard(), width: 292, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 10, color: "#fff" }}>
        <div style={{ display: "flex" }}>
          <SportEyebrowRow title={zh ? "今天" : "Today"} icon={<Calendar size={13} strokeWidth={2.6} />} trailing={zh ? "3 个日程" : "3 events"} />
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 8 }}>
          <span style={{ ...signatureNumber(30), lineHeight: "36px" }}>1</span>
          <span style={{ fontFamily: fonts.rounded, fontSize: 14, fontWeight: 600, color: Signature.textSecondary }}>{zh ? "周四 · 十月" : "Thursday · October"}</span>
        </div>
        <div style={{ position: "relative", display: "flex", flexDirection: "column", gap: GAP }}>
          {EVENTS.map((event, index) => {
            const isOpen = expanded === index;
            const isSqueezed = expanded !== null && expanded !== index;
            const live = now >= event.start && now <= event.end;
            const past = now > event.end;
            return (
              <div key={index} style={{ display: "flex", alignItems: "flex-start", gap: 7 }}>
                <span style={{ width: 32, paddingTop: 8, textAlign: "right", fontFamily: fonts.rounded, fontSize: 10, fontWeight: 700, fontVariantNumeric: "tabular-nums", lineHeight: "12px", color: past ? white(0.3) : Signature.textSecondary, flexShrink: 0 }}>{clock(event.start)}</span>
                <SportPress
                  scale={0.98}
                  dim={0.03}
                  radius={12}
                  style={{ flex: 1, minWidth: 0 }}
                  onClick={() => {
                    haptics.tap("light");
                    setOpen(expanded === index ? null : index);
                  }}
                >
                  <motion.div
                    initial={false}
                    animate={{ height: height(index), opacity: past && !isOpen ? 0.55 : 1, backgroundColor: hex(event.color, live ? 0.24 : 0.13), boxShadow: `inset 0 0 0 1px ${hex(event.color, isOpen ? 0.55 : live ? 0.35 : 0)}` }}
                    transition={{ default: expandSpring, opacity: smooth, backgroundColor: smooth }}
                    style={{ position: "relative", borderRadius: 12, overflow: "hidden", display: "flex", alignItems: "flex-start", gap: 10, padding: "0 10px", textAlign: "left" }}
                  >
                    <motion.span initial={false} animate={{ marginTop: isSqueezed ? 6 : 8, marginBottom: isSqueezed ? 6 : 8 }} transition={expandSpring} style={{ width: 4, alignSelf: "stretch", borderRadius: 2, background: hex(event.color), flexShrink: 0 }} />
                    <motion.div initial={false} animate={{ paddingTop: isSqueezed ? 6 : 7 }} transition={expandSpring} style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1, minWidth: 0 }}>
                      <motion.span initial={false} animate={{ fontSize: isSqueezed ? 12.5 : 14.5 }} transition={expandSpring} style={{ fontFamily: fonts.rounded, fontWeight: 700, lineHeight: 1.2, whiteSpace: "nowrap" }}>
                        {event.title[li]}
                      </motion.span>
                      <AnimatePresence initial={false}>
                        {!isSqueezed && (
                          <motion.span key="time" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={expandSpring} style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "13px", color: hex(event.color, 0.95), whiteSpace: "nowrap" }}>
                            {clock(event.start) + " – " + clock(event.end)}
                          </motion.span>
                        )}
                        {isOpen && (
                          <motion.div
                            key="details"
                            initial={{ opacity: 0, y: 8 }}
                            animate={{ opacity: 1, y: 0, transition: delayed(anim.easeOut(0.28), 0.08) }}
                            exit={{ opacity: 0, transition: anim.easeIn(0.1) }}
                            style={{ display: "flex", alignItems: "center", gap: 5, paddingTop: 6, marginRight: 16 }}
                          >
                            <span style={{ display: "grid", color: Signature.textSecondary }}>
                              <MapPin size={11} strokeWidth={2.6} />
                            </span>
                            <span style={{ fontFamily: fonts.rounded, fontSize: 11.5, fontWeight: 600, color: white(0.8), whiteSpace: "nowrap" }}>{event.place[li]}</span>
                            <span style={{ flex: 1 }} />
                            <span style={{ display: "flex" }}>
                              {["M", "J", "K"].map((letter, k) => (
                                <span key={k} style={{ width: 20, height: 20, borderRadius: "50%", background: ["#FFB45C", "#8FC9F0", "#E58BB8"][k], boxShadow: `inset 0 0 0 1.5px ${Signature.card}`, marginLeft: k ? -8 : 0, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 9, fontWeight: 800, color: Signature.ink }}>
                                  {letter}
                                </span>
                              ))}
                            </span>
                            <span style={{ height: 22, padding: "0 10px", borderRadius: 11, background: hex(event.color), display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 800, color: Signature.ink, whiteSpace: "nowrap" }}>{zh ? "加入" : "Join"}</span>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </motion.div>
                    <AnimatePresence initial={false}>
                      {!isSqueezed && (
                        <motion.span key="chev" initial={{ opacity: 0 }} animate={{ opacity: 1, rotate: isOpen ? 180 : 0 }} exit={{ opacity: 0 }} transition={expandSpring} style={{ position: "absolute", right: 10, top: 11, display: "grid", color: white(0.4) }}>
                          <ChevronDown size={12} strokeWidth={3} />
                        </motion.span>
                      )}
                    </AnimatePresence>
                  </motion.div>
                </SportPress>
              </div>
            );
          })}
          <motion.div
            initial={false}
            animate={{ y: nowY - 7.5 }}
            transition={lineAnim}
            style={{ position: "absolute", left: -2, right: 2, top: 0, height: 15, display: "flex", alignItems: "center", pointerEvents: "none", filter: `drop-shadow(0 0 5px ${hex(0xff8a1f, 0.7)})` }}
          >
            <span style={{ width: 36, height: 15, borderRadius: 7.5, background: Signature.accent, display: "grid", placeItems: "center", fontFamily: fonts.rounded, fontSize: 9, fontWeight: 800, color: Signature.ink, flexShrink: 0 }}>
              <NumericText value={now} text={clock(now)} />
            </span>
            <span style={{ flex: 1, height: 1.5, background: `linear-gradient(90deg, ${Signature.accent}, ${hex(0xff8a1f, 0.25)})` }} />
          </motion.div>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}
