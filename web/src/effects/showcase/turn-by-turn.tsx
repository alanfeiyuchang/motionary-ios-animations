/** showcase.turn-by-turn · 逐向导航卡 (Showcase+TurnByTurn.swift) */
import { AnimatePresence, motion, type Transition } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { NumericText, black, delayed, fonts, hex, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow, signatureNumber } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioScene, studioEase, useAnimatedNumber, useStudioScript } from "./_studio";

interface Step {
  bend: number;
  distance: number;
  action: [string, string];
  street: [string, string];
  lanes: number[];
  take: number[];
}
const STEPS: Step[] = [
  { bend: 90, distance: 300, action: ["Turn right", "右转"], street: ["Maple Street", "枫林路"], lanes: [-90, 0, 0, 90], take: [3] },
  { bend: -90, distance: 450, action: ["Turn left", "左转"], street: ["Harbor Avenue", "海港大道"], lanes: [-90, -90, 0, 0], take: [0, 1] },
  { bend: 0, distance: 800, action: ["Continue", "直行"], street: ["Ring Road East", "东环路"], lanes: [-90, 0, 0, 90], take: [1, 2] },
  { bend: 45, distance: 200, action: ["Keep right", "靠右"], street: ["Exit 12 · Airport", "12 号出口 · 机场"], lanes: [0, 0, 45, 45], take: [2, 3] },
  { bend: -180, distance: 150, action: ["Make a U-turn", "掉头"], street: ["Station Road", "车站路"], lanes: [-180, 0, 0, 0], take: [0] },
];

/** `ManeuverArrow.path(in:)` for a `size`-square box. */
function arrowPath(bend: number, size: number): string {
  const unit = size;
  const amount = Math.min(Math.abs(bend) / 90, 1);
  const stem = unit * (0.92 - 0.42 * amount);
  const radius = unit * 0.24;
  const tail = unit * (0.08 + 0.3 * amount);
  const head = unit * 0.3;
  const sign = bend >= 0 ? 1 : -1;
  const points = [{ x: 0, y: 0 }];
  let position = { x: 0, y: -stem };
  points.push(position);
  const startHeading = -Math.PI / 2;
  const sweep = (bend * Math.PI) / 180;
  const normal = startHeading + Math.PI / 2;
  const center = { x: position.x + sign * radius * Math.cos(normal), y: position.y + sign * radius * Math.sin(normal) };
  for (let i = 1; i <= 16; i++) {
    const n = startHeading + (sweep * i) / 16 + Math.PI / 2;
    position = { x: center.x - sign * radius * Math.cos(n), y: center.y - sign * radius * Math.sin(n) };
    points.push(position);
  }
  const heading = startHeading + sweep;
  const tip = { x: position.x + tail * Math.cos(heading), y: position.y + tail * Math.sin(heading) };
  points.push(tip);
  const left = { x: tip.x + head * Math.cos(heading + 2.45), y: tip.y + head * Math.sin(heading + 2.45) };
  const right = { x: tip.x + head * Math.cos(heading - 2.45), y: tip.y + head * Math.sin(heading - 2.45) };
  const all = [...points, left, right];
  const xs = all.map((p) => p.x);
  const ys = all.map((p) => p.y);
  const sx = size / 2 - (Math.min(...xs) + Math.max(...xs)) / 2;
  const sy = size / 2 - (Math.min(...ys) + Math.max(...ys)) / 2;
  const f = (p: { x: number; y: number }) => `${(p.x + sx).toFixed(2)} ${(p.y + sy).toFixed(2)}`;
  return `M${points.map(f).join("L")}M${f(left)}L${f(tip)}L${f(right)}`;
}

function Arrow({ bend, size, width, color, transition }: { bend: number; size: number; width: number; color: string; transition: Transition }) {
  const [value, api] = useAnimatedNumber(bend);
  const target = useRef(bend);
  useEffect(() => {
    if (target.current !== bend) {
      target.current = bend;
      api.animateTo(bend, transition);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bend]);
  return (
    <svg width={size} height={size} style={{ overflow: "visible", display: "block" }}>
      <path d={arrowPath(value, size)} fill="none" stroke={color} strokeWidth={width} strokeLinecap="round" strokeLinejoin="round" style={{ transition: "stroke 0.3s" }} />
    </svg>
  );
}

export default function TurnByTurn({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const li = zh ? 1 : 0;
  const [step, setStep] = useState(0);
  const [distance, setDistance] = useState(STEPS[0].distance);
  const [pulses, setPulses] = useState(0);
  const st = useRef({ step: 0, distance: STEPS[0].distance });
  const run = useStudioScript();
  const leg = ctx.n("leg");
  const morph = spring(ctx.n("response"), ctx.n("damping"));
  const current = STEPS[step % STEPS.length];
  const next = STEPS[(step + 1) % STEPS.length];

  const countDown = (user: boolean) => {
    const from = st.current.distance;
    const ticks = Math.max(Math.trunc(from / 10), 1);
    run.run(async (task) => {
      if (!(await task.pause(0.5))) return;
      const finished = await task.script(leg, (t) => {
        const left = from - Math.trunc(ticks * t) * 10;
        if (left !== st.current.distance && left > 0) {
          st.current.distance = left;
          setDistance(left);
        }
      });
      if (!finished) return;
      st.current.distance = 0;
      setDistance(0);
      setPulses((n) => n + 1);
      if (user) haptics.tap("rigid");
    });
  };
  const advance = (user: boolean) => {
    if (user) haptics.tap("medium");
    st.current.step += 1;
    st.current.distance = STEPS[st.current.step % STEPS.length].distance;
    setStep(st.current.step);
    setDistance(st.current.distance);
    countDown(user);
  };
  useEffect(() => {
    countDown(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  useAutoplay(ctx.isPreview, () => advance(false), { every: leg + 1.3, delay: leg + 1.0, intro: false });

  const pe = useElapsed(pulses, 0.65, true);
  const tileScale = pe < 0 ? 1 : pe < 0.14 ? 1 + 0.08 * studioEase(pe / 0.14) : 1.08 - 0.08 * springAt(pe - 0.14, 0.3, 0.5);
  const share = distance / Math.max(current.distance, 1);
  const line = current.action[li] + (zh ? " · " : " onto ") + current.street[li];
  const thenLine = (zh ? "然后 " : "Then ") + next.action[li] + " · " + next.street[li];

  return (
    <StudioScene ctx={ctx} en="Tap for the next manoeuvre" zh="点击，进入下一个转向">
      <SportPress scale={0.98} dim={0.04} radius={26} onClick={() => advance(true)}>
        <div style={{ ...signatureCard(), width: 292, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 12, color: "#fff", textAlign: "left" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
            <div style={{ width: 78, height: 78, borderRadius: 20, background: Signature.accentGradient, boxShadow: `inset 0 0 0 1px ${white(0.25)}, 0 6px 12px ${hex(0xff8a1f, 0.45)}`, display: "grid", placeItems: "center", flexShrink: 0, transform: `scale(${tileScale})` }}>
              <Arrow bend={current.bend} size={48} width={9} color="#fff" transition={morph} />
            </div>
            <div style={{ position: "relative", flex: 1, minWidth: 0, height: 66 }}>
              <AnimatePresence initial={false}>
                <motion.div
                  key={step}
                  initial={{ y: 26, opacity: 0, filter: "blur(8px)" }}
                  animate={{ y: 0, opacity: 1, filter: "blur(0px)" }}
                  exit={{ y: -22, opacity: 0, filter: "blur(8px)" }}
                  transition={morph}
                  style={{ position: "absolute", left: 0, top: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "flex-start" }}
                >
                  <span style={{ position: "relative", height: 48, alignSelf: "stretch" }}>
                    <AnimatePresence initial={false}>
                      {distance > 0 ? (
                        <motion.span key="d" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={spring(0.35, 0.7)} style={{ position: "absolute", left: 0, bottom: 0, display: "flex", alignItems: "baseline", gap: 4 }}>
                          <span style={{ ...signatureNumber(42), lineHeight: "48px" }}>
                            <NumericText value={-distance} text={String(distance)} />
                          </span>
                          <span style={{ fontFamily: fonts.rounded, fontSize: 17, fontWeight: 700, color: Signature.textSecondary }}>{zh ? "米" : "m"}</span>
                        </motion.span>
                      ) : (
                        <motion.span key="now" initial={{ scale: 0.7, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.7, opacity: 0 }} transition={spring(0.35, 0.7)} style={{ position: "absolute", left: 0, bottom: 0, fontFamily: fonts.rounded, fontSize: 38, fontWeight: 700, lineHeight: "46px", color: Signature.accentSoft, transformOrigin: "0% 50%", whiteSpace: "nowrap" }}>
                          {zh ? "现在" : "Now"}
                        </motion.span>
                      )}
                    </AnimatePresence>
                  </span>
                  <span style={{ fontFamily: fonts.rounded, fontSize: line.length > 24 ? 11 : 14, fontWeight: 600, lineHeight: "18px", color: white(0.85), whiteSpace: "nowrap" }}>{line}</span>
                </motion.div>
              </AnimatePresence>
            </div>
          </div>
          <div style={{ position: "relative", height: 4, borderRadius: 2, background: white(0.1), overflow: "hidden" }}>
            <motion.div initial={false} animate={{ width: `max(4px, ${share * 100}%)` }} transition={distance === current.distance ? morph : distance === 0 ? spring(0.35, 0.7) : { duration: 0.08, ease: "linear" }} style={{ position: "absolute", left: 0, top: 0, height: 4, borderRadius: 2, background: Signature.accentGradient }} />
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span style={signatureEyebrow()}>{zh ? "车道" : "Lanes"}</span>
            <span style={{ flex: 1 }} />
            {[0, 1, 2, 3].map((index) => {
              const take = current.take.includes(index);
              const t = delayed(morph, index * 0.04);
              return (
                <motion.span key={index} initial={false} animate={{ scale: take ? 1 : 0.94, backgroundColor: take ? hex(0xff8a1f, 0.9) : "rgba(255,255,255,0.06)" }} transition={t} style={{ width: 34, height: 28, borderRadius: 8, display: "grid", placeItems: "center" }}>
                  <Arrow bend={current.lanes[index]} size={15} width={2.6} color={take ? "#fff" : white(0.22)} transition={t} />
                </motion.span>
              );
            })}
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10, padding: 8, borderRadius: 14, background: black(0.28) }}>
            <span style={{ width: 30, height: 30, borderRadius: "50%", background: white(0.1), display: "grid", placeItems: "center", flexShrink: 0 }}>
              <Arrow bend={next.bend} size={16} width={3} color={white(0.9)} transition={morph} />
            </span>
            <span style={{ position: "relative", flex: 1, height: 16, overflow: "hidden" }}>
              <AnimatePresence initial={false}>
                <motion.span key={step} initial={{ y: 16, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -16, opacity: 0 }} transition={morph} style={{ position: "absolute", left: 0, top: 0, fontFamily: fonts.rounded, fontSize: thenLine.length > 30 ? 10.5 : 13, fontWeight: 600, lineHeight: "16px", color: Signature.textSecondary, whiteSpace: "nowrap" }}>
                  {thenLine}
                </motion.span>
              </AnimatePresence>
            </span>
          </div>
          <SignatureRim />
        </div>
      </SportPress>
    </StudioScene>
  );
}
