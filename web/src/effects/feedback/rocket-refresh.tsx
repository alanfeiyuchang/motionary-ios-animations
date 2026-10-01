/** feedback.rocket-refresh · 火箭发射下拉刷新 (Feedback+RocketRefresh.swift) */
import { AnimatePresence, animate, motion, useMotionValue, useMotionValueEvent, type Transition } from "motion/react";
import { CloudSun, Fuel, ListChecks, MoonStar, Radio, Users } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, black, mix, rubberBand, spring, useAutoplay, useClock, useHaptics, usePan, useTimeouts, white, type DemoProps } from "../../kit";
import { gradientOf } from "./_scene";
import { separator } from "./shared";

const ITEMS: { icon: ReactNode; tint: string; title: [string, string]; detail: [string, string] }[] = [
  { icon: <MoonStar size={16} fill="currentColor" strokeWidth={1.6} />, tint: Palette.indigo, title: ["Lunar flyby tonight", "今晚近月飞越"], detail: ["Closest approach 21:14", "最近点 21:14"] },
  { icon: <Radio size={17} strokeWidth={2.4} />, tint: Palette.mint, title: ["Signal acquired", "已捕获信号"], detail: ["Ground station 3 · strong", "3 号地面站 · 信号强"] },
  { icon: <Fuel size={16} strokeWidth={2.4} />, tint: Palette.coral, title: ["Fuelling complete", "燃料加注完成"], detail: ["Stage 2 · 100%", "二级 · 100%"] },
  { icon: <CloudSun size={17} fill="currentColor" strokeWidth={2} />, tint: Palette.amber, title: ["Weather is go", "天气条件允许"], detail: ["Wind 6 kt · clear", "风速 6 节 · 晴"] },
  { icon: <ListChecks size={17} strokeWidth={2.4} />, tint: Palette.sky, title: ["Checklist signed off", "检查单已签署"], detail: ["42 of 42 items", "42 / 42 项"] },
  { icon: <Users size={16} fill="currentColor" strokeWidth={2} />, tint: Palette.violet, title: ["Crew on board", "乘组已登舱"], detail: ["Hatch closed", "舱门已关闭"] },
];

const THRESHOLD = 80;
const HOLD = 68;
/** How far above the list's top edge the rocket's centre rides while it is pulled. */
const RIDE = 30;
const ROCKET_H = 38;
const ROW_H = 62;

const now = () => performance.now() / 1000;
const clamp01 = (v: number) => Math.min(Math.max(v, 0), 1);

export default function RocketRefresh({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const live = !ctx.isPreview;
  const zh = ctx.lang === "zh";
  const finger = useMotionValue(0);
  /** Extra shift of the rows: the scripted pull of previews and the hold height while refreshing. */
  const shift = useMotionValue(0);
  /** The rocket's centre while it is animated (launch, hold, leaving) instead of riding the pull. */
  const flight = useMotionValue(0);
  /** 0 → 1 after every flip of `refreshing`: the coil's bouncy spring between its two shapes. */
  const coilBlend = useMotionValue(1);
  const [refreshing, setRefreshing] = useState(false);
  const [leaving, setLeaving] = useState(false);
  /** The rocket follows `flight` (true) or the pull (false). */
  const [flying, setFlying] = useState(false);
  const [launchTime, setLaunchTime] = useState(-1e9);
  const [items, setItems] = useState([3, 2, 1, 0]);
  const s = useRef({ refreshing: false, userDriven: false, token: 0, nextItem: 4, past: false, coilFrom: { length: 0, tension: 0, opacity: 0.7 } });
  const anims = useRef<Record<string, ReturnType<typeof animate> | undefined>>({});
  const [, force] = useState(0);
  const rerender = () => force((n) => n + 1);
  useMotionValueEvent(finger, "change", rerender);
  useMotionValueEvent(shift, "change", rerender);
  useMotionValueEvent(flight, "change", rerender);
  useMotionValueEvent(coilBlend, "change", rerender);
  useEffect(() => () => Object.values(anims.current).forEach((a) => a?.stop()), []);

  const run = (key: string, mv: typeof finger, to: number, t: Transition) => {
    anims.current[key]?.stop();
    anims.current[key] = animate(mv, to, t);
  };

  const pull = finger.get() + shift.get();
  const tension = clamp01((pull - 20) / (THRESHOLD - 20));
  /** The rocket's centre: riding the pull, parked mid-strip while loading, off the top when leaving. */
  const modelY = leaving ? -60 : refreshing ? HOLD / 2 - 12 : pull - RIDE;
  const rocketY = flying ? flight.get() : modelY;
  const coilTarget = { length: refreshing ? 6 : Math.max(modelY - ROCKET_H / 2 + 2, 0), tension: refreshing ? 0 : tension, opacity: refreshing ? 0.35 : 0.7 };
  const blend = coilBlend.get();
  const from = s.current.coilFrom;
  const coil = { length: mix(from.length, coilTarget.length, blend), tension: mix(from.tension, coilTarget.tension, blend), opacity: clamp01(mix(from.opacity, coilTarget.opacity, blend)) };
  const coilNow = useRef(coil);
  coilNow.current = coil;
  const rocketNow = useRef(rocketY);
  rocketNow.current = rocketY;

  const startCoilSpring = () => {
    s.current.coilFrom = coilNow.current;
    anims.current.coil?.stop();
    coilBlend.jump(0);
    anims.current.coil = animate(coilBlend, 1, spring(0.35, 0.4));
  };

  // The threshold click: only a real finger buzzes.
  const past = pull >= THRESHOLD;
  useEffect(() => {
    if (past === s.current.past) return;
    s.current.past = past;
    if (past && !s.current.refreshing && s.current.userDriven && live) haptics.tap("rigid");
  }, [past, live, haptics]);

  /** Finger lifted, or the scripted pull ended: launch if past the threshold. */
  const release = () => {
    const st = s.current;
    if (st.refreshing) return;
    if (finger.get() + shift.get() < THRESHOLD) {
      run("shift", shift, 0, spring(0.4, 0.75));
      return;
    }
    setLaunchTime(now());
    setLeaving(false);
    startCoilSpring();
    flight.jump(rocketNow.current);
    setFlying(true);
    run("flight", flight, HOLD / 2 - 12, spring(0.4, 0.6));
    st.refreshing = true;
    setRefreshing(true);
    run("shift", shift, HOLD, spring(0.4, 0.9));
    const buzz = live && st.userDriven;
    if (buzz) haptics.tap("heavy");
    const current = ++st.token;
    after(ctx.n("duration"), () => {
      if (st.token !== current) return;
      setLeaving(true);
      run("flight", flight, -60, anim.easeIn(0.28));
      after(0.24, () => {
        if (st.token !== current) return;
        const id = st.nextItem++;
        setItems((list) => [id, ...list].slice(0, 4));
        startCoilSpring();
        run("shift", shift, 0, spring(0.5, 0.84));
        st.refreshing = false;
        setRefreshing(false);
        if (buzz) haptics.success();
        // Once the strip has closed, put the rocket back on its coil for the next pull.
        after(0.5, () => {
          if (st.token !== current) return;
          setLeaving(false);
          setFlying(false);
        });
      });
    });
  };

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        // Native-like resistance: 72 pt of pull takes ~130 pt of finger travel, 100 pt ~215 pt.
        anims.current.finger?.stop();
        finger.set(rubberBand(Math.max(translation.y, 0), 240, 0.8));
        s.current.userDriven = true;
      },
      onEnd: () => {
        release();
        run("finger", finger, 0, spring(0.4, 0.9));
      },
    },
    4,
  );

  const simulate = () => {
    const st = s.current;
    if (st.refreshing) return;
    st.userDriven = false;
    clearAll();
    const current = ++st.token;
    run("shift", shift, THRESHOLD * 0.6, anim.easeOut(0.6));
    after(0.6, () => {
      if (st.token !== current || st.refreshing) return;
      // Linger just under the threshold so the trembling reads, then pull through.
      run("shift", shift, THRESHOLD - 5, anim.easeOut(0.5));
      after(0.75, () => {
        if (st.token !== current || st.refreshing) return;
        run("shift", shift, THRESHOLD + 12, anim.easeOut(0.25));
        after(0.5, () => {
          if (st.token !== current) return;
          release();
        });
      });
    });
  };
  useAutoplay(ctx.isPreview, simulate, { every: ctx.n("duration") + 3.6, delay: 0.6 });

  const insertSpring = spring(0.5, 0.84);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14 }}>
      <div style={{ position: "relative", width: 300, height: 260, flexShrink: 0, borderRadius: 22, boxShadow: `0 10px 18px ${black(0.12)}` }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 22, overflow: "hidden", background: "#0B1030" }}>
          <div style={{ position: "absolute", left: 0, top: 0, width: 300, height: Math.max(pull, 1), overflow: "hidden" }}>
            <Indicator
              pull={pull}
              tension={tension}
              refreshing={refreshing}
              rocketY={rocketY}
              nozzleY={modelY + ROCKET_H / 2 - 2}
              coil={coil}
              launchTime={launchTime}
              exhaust={Math.max(ctx.i("exhaust"), 1)}
              shake={ctx.n("shake")}
              preview={ctx.isPreview}
            />
          </div>
          <div
            {...(live ? pan : {})}
            style={{ position: "absolute", left: 0, top: 0, width: 300, height: 260, transform: `translateY(${pull}px)`, background: Palette.elevated, borderRadius: "22px 22px 0 0", overflow: "hidden", touchAction: "pan-x", cursor: live ? "grab" : undefined }}
          >
            <AnimatePresence initial={false}>
              {items.map((item, index) => {
                const data = ITEMS[item % ITEMS.length];
                return (
                  <motion.div
                    key={item}
                    initial={{ y: -ROW_H, opacity: 0 }}
                    animate={{ y: index * ROW_H, opacity: 1 }}
                    exit={{ y: 4 * ROW_H, opacity: 0 }}
                    transition={insertSpring}
                    style={{ position: "absolute", left: 0, top: 0, width: 300, height: ROW_H, padding: "0 14px", display: "flex", alignItems: "center", gap: 12 }}
                  >
                    <div style={{ width: 36, height: 36, borderRadius: 10, background: gradientOf(data.tint), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{data.icon}</div>
                    <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start", minWidth: 0 }}>
                      <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{data.title[zh ? 1 : 0]}</span>
                      <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{data.detail[zh ? 1 : 0]}</span>
                    </div>
                    <div style={{ position: "absolute", left: 62, right: 0, bottom: 0, height: 0.5, background: separator(ctx.scheme) }} />
                  </motion.div>
                );
              })}
            </AnimatePresence>
          </div>
        </div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 22, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
      </div>
      <DemoHint ctx={ctx} en="Pull the list down" zh="向下拖动列表" />
    </div>
  );
}

// MARK: - Indicator

interface IndicatorProps {
  pull: number;
  tension: number;
  refreshing: boolean;
  rocketY: number;
  nozzleY: number;
  coil: { length: number; tension: number; opacity: number };
  launchTime: number;
  exhaust: number;
  shake: number;
  preview: boolean;
}

function Indicator({ pull, tension, refreshing, rocketY, nozzleY, coil, launchTime, exhaust, shake, preview }: IndicatorProps) {
  const active = refreshing || tension > 0.5;
  useClock(active, preview ? 30 : undefined);
  const t = now();
  const since = t - launchTime;
  const charge = Math.max(0, (tension - 0.55) / 0.45);
  const tremble = refreshing ? 0.6 : shake * charge;
  const jitter = active ? tremble * (Math.sin(t * 83) * 0.6 + Math.sin(t * 131) * 0.4) : 0;
  const flame = refreshing ? 1 : pull >= THRESHOLD ? 0.8 : charge * 0.45;
  const flicker = Math.sin(t * 47) * 0.5 + 0.5;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: 300, height: 120, opacity: pull > 6 ? 1 : 0, background: "linear-gradient(#0B1030, #1C2A5E)" }}>
      <svg width={300} height={120} style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
        <Sky now={t} since={since} refreshing={refreshing} exhaust={exhaust} nozzleY={nozzleY} edge={pull} />
        <path d={coilPath(coil.length, coil.tension)} fill="none" stroke={white(coil.opacity)} strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <div style={{ position: "absolute", left: 137, top: 0, width: 26, height: ROCKET_H + 22, transform: `translate(${jitter}px, ${rocketY - ROCKET_H / 2}px)` }}>
        <RocketShip flame={flame} flicker={flicker} />
      </div>
    </div>
  );
}

/** A coil spring hanging from the top centre: `length` of travel, turns that narrow as it is stretched. */
function coilPath(length: number, tension: number): string {
  const x = 150;
  const reach = Math.max(length, 0);
  if (reach <= 8) return `M${x} 0 L${x} ${reach}`;
  const lead = 4;
  const amplitude = 7 * (1 - 0.6 * clamp01(tension));
  const steps = 14;
  const span = reach - lead * 2;
  let d = `M${x} 0 L${x} ${lead}`;
  for (let step = 1; step <= steps; step++) {
    const side = step === steps ? 0 : step % 2 === 0 ? -1 : 1;
    d += ` L${x + side * amplitude} ${lead + (span * step) / steps}`;
  }
  return `${d} L${x} ${reach}`;
}

/** The rocket, nose up, with a flame below its nozzle. `flame` 0…1 is its size, `flicker` 0…1 its jitter. */
function RocketShip({ flame, flicker }: { flame: number; flicker: number }) {
  return (
    <svg width={26} height={60} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
      <defs>
        <linearGradient id="rr-flame" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FFF3B0" />
          <stop offset="0.5" stopColor={Palette.amber} />
          <stop offset="1" stopColor={Palette.coral} stopOpacity={0.1} />
        </linearGradient>
        <linearGradient id="rr-fins" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FF7A5C" />
          <stop offset="1" stopColor="#D9432F" />
        </linearGradient>
        <linearGradient id="rr-body" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#fff" />
          <stop offset="1" stopColor="#C9D2E8" />
        </linearGradient>
        <clipPath id="rr-nose">
          <rect x={0} y={0} width={15} height={10} />
        </clipPath>
      </defs>
      {/* Flame first, so the body covers its root. */}
      {flame > 0.02 && (
        <g transform={`translate(13 33) scale(${0.8 + 0.2 * flicker} ${flame * (0.8 + 0.3 * flicker)}) translate(-5.5 0)`}>
          <path d="M0 0 L11 0 Q11 13.2 5.5 24 Q0 13.2 0 0 Z" fill="url(#rr-flame)" />
        </g>
      )}
      <g transform="translate(0 22)">
        <path d="M7 0 Q0 4.8 0 16 L8 12 Z M19 0 Q26 4.8 26 16 L18 12 Z" fill="url(#rr-fins)" />
      </g>
      <g transform="translate(5.5 0)">
        <path d="M7.5 0 Q15 5.04 15 18 L13.5 36 L1.5 36 L0 18 Q0 5.04 7.5 0 Z" fill="url(#rr-body)" />
        <path d="M7.5 0 Q15 5.04 15 18 L13.5 36 L1.5 36 L0 18 Q0 5.04 7.5 0 Z" fill="#FF7A5C" clipPath="url(#rr-nose)" />
        <circle cx={7.5} cy={17.75} r={3.15} fill="#3AC4FF" stroke="#1C2A5E" strokeWidth={1.2} />
      </g>
    </svg>
  );
}

const unit = (seed: number) => {
  const value = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return value - Math.floor(value);
};

/** Stars, exhaust and the launch puff: all stateless functions of the clock. */
function Sky({ now: t, since, refreshing, exhaust, nozzleY, edge }: { now: number; since: number; refreshing: boolean; exhaust: number; nozzleY: number; edge: number }) {
  const nodes: ReactNode[] = [];
  // Stars: still while pulling; streaking down while the rocket flies.
  const speed = refreshing ? Math.min(since / 0.3, 1) : 0;
  for (let index = 0; index < 16; index++) {
    const x = unit(index) * 300;
    const fall = refreshing ? since * (70 + 90 * unit(index + 40)) : 0;
    const y = (unit(index + 20) * 110 + fall) % 110;
    const twinkle = 0.45 + 0.55 * unit(index + 60);
    const length = 1.4 + speed * (5 + 6 * unit(index + 80));
    nodes.push(<rect key={`s${index}`} x={x} y={y} width={1.4} height={length} rx={0.7} fill="#fff" fillOpacity={twinkle} />);
  }
  if (refreshing) {
    // Exhaust puffs, cooling from amber to grey as they swell and fade.
    const life = 0.55;
    for (let index = 0; index < exhaust; index++) {
      const age = (t / life + index / exhaust) % 1;
      // No puff is older than the launch itself.
      if (age * life > since - 0.12) continue;
      const drift = (unit(index + 7) - 0.5) * 22 * age;
      const radius = 2 + 6 * age;
      const heat = Math.max(0, 1 - age * 2.4);
      nodes.push(
        <circle
          key={`p${index}`}
          cx={150 + drift}
          cy={nozzleY + 6 + age * 34}
          r={radius}
          fill={`rgb(${150 + 105 * heat} ${155 + 40 * heat} ${175 - 104 * heat})`}
          fillOpacity={(1 - age) * (0.35 + 0.5 * heat)}
        />,
      );
    }
    // The burst of smoke that spreads along the list's edge right at lift-off.
    const p = since / 0.6;
    if (p > 0 && p < 1) {
      const eased = 1 - (1 - p) ** 3;
      for (let index = 0; index < 10; index++) {
        const side = index % 2 === 0 ? -1 : 1;
        const reach = (18 + 46 * unit(index + 3)) * eased;
        const radius = 5 + 9 * eased * (0.6 + 0.4 * unit(index + 9));
        nodes.push(<circle key={`c${index}`} cx={150 + side * reach} cy={edge - radius * 0.5} r={radius} fill="rgb(217 217 217)" fillOpacity={0.5 * (1 - p)} />);
      }
    }
  }
  return <>{nodes}</>;
}
