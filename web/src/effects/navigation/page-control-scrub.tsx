/** navigation.page-control-scrub · 可拖擦的页码控件 (Navigation+PageControlScrub.swift) */
import { animate, motion, useMotionValue } from "motion/react";
import { Haze, MoonStar, Snowflake, Sun } from "lucide-react";
import { useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, anim, delayed, fonts, glass, hex, localPoint, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { useMotionNumber } from "./nav-util";
import { CloudRainFill, CloudSunFill, usePageDrag, vert, useNavPan } from "./_r2";

const YELLOW = "#FFD60A";
const CITIES: { name: [string, string]; condition: [string, string]; temperature: number; icon: ReactNode; colors: [string, string] }[] = [
  { name: ["Seattle", "西雅图"], condition: ["Light rain", "小雨"], temperature: 14, icon: <CloudRainFill size={72} rain="#5AC8FA" />, colors: ["#4A6FA5", "#23395B"] },
  { name: ["Lisbon", "里斯本"], condition: ["Sunny", "晴"], temperature: 27, icon: <Sun size={72} color={YELLOW} fill={YELLOW} strokeWidth={2.4} />, colors: ["#3AA0FF", "#6FD3FF"] },
  { name: ["Kyoto", "京都"], condition: ["Partly cloudy", "多云"], temperature: 21, icon: <CloudSunFill size={76} sun={YELLOW} />, colors: ["#5B8CFF", "#A9C6FF"] },
  { name: ["Reykjavik", "雷克雅未克"], condition: ["Snow", "雪"], temperature: -3, icon: <Snowflake size={68} strokeWidth={2} />, colors: ["#7C8BA8", "#B9C4D6"] },
  {
    name: ["Marrakesh", "马拉喀什"],
    condition: ["Hot", "炎热"],
    temperature: 36,
    icon: (
      <span style={{ position: "relative", display: "block", width: 76, height: 76 }}>
        <Haze size={76} strokeWidth={1.9} style={{ position: "absolute", inset: 0 }} />
        <svg width={76} height={76} viewBox="0 0 24 24" style={{ position: "absolute", inset: 0 }} fill={YELLOW} stroke={YELLOW} strokeWidth={1.9} strokeLinecap="round">
          <path d="M6.3 12.300a5.700 5.700 0 0 1 11.400 0Z" stroke="none" />
          <path d="m5.200 5.400 1.400 1.400M12 3v1.800M18.800 5.400l-1.400 1.400" fill="none" />
        </svg>
      </span>
    ),
    colors: ["#FF8A3D", "#FFC247"],
  },
  { name: ["Auckland", "奥克兰"], condition: ["Clear night", "晴夜"], temperature: 12, icon: <MoonStar size={68} fill="currentColor" strokeWidth={1.6} />, colors: ["#241B5C", "#5B4FC9"] },
];

const SPACING = 20;
const DOT = 8;
const INSET = 10;
const CARD_STEP = 218;
const CONTROL_W = SPACING * CITIES.length + INSET * 2;
const LAST = CITIES.length - 1;
const centre = (page: number) => INSET + SPACING * (page + 0.5);
const clampPage = (v: number) => Math.min(Math.max(v, 0), LAST);

export default function PageControlScrub({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const progressMV = useMotionValue(0);
  const tailMV = useMotionValue(0);
  const progress = useMotionNumber(progressMV);
  const tail = useMotionNumber(tailMV);
  /** The state value SwiftUI would hold (the animation's target), for `progress.rounded()`. */
  const goal = useRef(0);
  const [scrubbing, setScrubbingState] = useState(false);
  const scrubRef = useRef(false);
  const [platter, setPlatter] = useState<"hidden" | "in" | "out">("hidden");
  const platterShown = platter === "in";
  const platterToken = useRef(0);
  const lastPage = useRef(0);
  const autoForward = useRef(true);

  const setScrubbing = (v: boolean) => {
    scrubRef.current = v;
    setScrubbingState(v);
  };
  const beginScrub = () => {
    setScrubbing(true);
    platterToken.current += 1;
    setPlatter("in");
  };

  /** Springs to a page: the head first, the tail on a softer spring, then the platter melts away. */
  const settle = (page: number) => {
    const clamped = Math.min(Math.max(page, 0), LAST);
    const response = ctx.n("response");
    const stretch = ctx.n("stretch");
    setScrubbing(false);
    lastPage.current = clamped;
    goal.current = clamped;
    animate(progressMV, clamped, spring(response, 0.8));
    animate(tailMV, clamped, spring(response * (1 + 0.6 * stretch), 0.86));
    platterToken.current += 1;
    const token = platterToken.current;
    after(0.7, () => {
      if (token !== platterToken.current || scrubRef.current) return;
      setPlatter((p) => (p === "in" ? "out" : p));
    });
  };

  const scrub = useNavPan(
    {
      onChange: (s) => {
        if (!scrubRef.current) {
          beginScrub();
          haptics.tap("light");
        }
        const page = clampPage((s.location.x - INSET) / SPACING - 0.5);
        const stretch = ctx.n("stretch");
        goal.current = page;
        animate(progressMV, page, spring(0.18, 0.86));
        animate(tailMV, page, spring(0.18 + 0.4 * stretch, 0.9));
        const rounded = Math.round(page);
        if (rounded !== lastPage.current) {
          lastPage.current = rounded;
          haptics.selection();
        }
      },
      onEnd: () => {
        if (!scrubRef.current) return;
        settle(Math.round(goal.current));
      },
    },
    { axis: "horizontal", minimumDistance: 2 },
  );

  const step = (delta: number) => {
    const target = Math.round(goal.current) + delta;
    if (target < 0 || target > LAST) return;
    haptics.selection();
    settle(target);
  };

  const { pan: swipe } = usePageDrag(progressMV, {
    unit: CARD_STEP,
    last: LAST,
    bandLow: 0.6,
    onPage: (page) => {
      tailMV.stop();
      tailMV.set(page);
      goal.current = page;
    },
    settle: (target, start) => {
      if (target !== Math.round(start)) haptics.selection();
      settle(target);
    },
  });

  // Preview: a simulated scrub from one end of the dots to the other, released at the far page.
  useAutoplay(
    ctx.isPreview,
    () => {
      const target = autoForward.current ? LAST : 0;
      autoForward.current = !autoForward.current;
      beginScrub();
      const lag = 0.06 + 0.12 * ctx.n("stretch");
      goal.current = target;
      animate(progressMV, target, anim.easeInOut(1.3));
      animate(tailMV, target, delayed(anim.easeInOut(1.3), lag));
      const token = platterToken.current;
      after(1.45, () => {
        if (token !== platterToken.current) return;
        settle(target);
      });
    },
    { every: 2.7 },
  );

  const enlarged = scrubbing || platterShown;
  const sideScale = ctx.n("side");
  const fade = platter === "out" ? "0.35s ease-in-out" : "0.25s ease-out";
  const head = clampPage(progress);
  const back = clampPage(tail);
  const low = centre(Math.min(head, back));
  const high = centre(Math.max(head, back));
  const size = DOT * (enlarged ? 1.25 : 1);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 14, overflow: "hidden" }}>
      {/* cards */}
      <div {...swipe} style={{ position: "relative", alignSelf: "stretch", height: 216, flexShrink: 0, touchAction: "pan-y" }}>
        {CITIES.map((city, index) => {
          const distance = index - progress;
          const near = Math.min(Math.abs(distance), 1);
          return (
            <div
              key={index}
              style={{
                position: "absolute",
                left: "50%",
                top: 8,
                width: 210,
                height: 200,
                marginLeft: -105,
                borderRadius: 28,
                transform: `translateX(${distance * CARD_STEP}px) scale(${1 - (1 - sideScale) * near})`,
                opacity: 1 - 0.4 * near,
                zIndex: Math.round((1 - near) * 100),
                boxShadow: `0 8px 14px ${hex(city.colors[0], 0.35)}`,
              }}
            >
              <div style={{ position: "absolute", inset: 0, borderRadius: 28, overflow: "hidden", background: vert(...city.colors), color: "#fff" }}>
                <div style={{ position: "absolute", right: 18, bottom: 18, transform: `translateX(${distance * -34}px)`, filter: "drop-shadow(0 4px 8px rgb(0 0 0 / 0.15))" }}>{city.icon}</div>
                <div style={{ position: "absolute", left: 18, top: 18, display: "flex", flexDirection: "column", gap: 2 }}>
                  <div style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t(...city.name)}</div>
                  <div style={{ fontFamily: fonts.rounded, fontSize: 54, lineHeight: "64px", fontWeight: 300, fontVariantNumeric: "tabular-nums" }}>{city.temperature}°</div>
                  <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 500, opacity: 0.85, whiteSpace: "nowrap" }}>{ctx.t(...city.condition)}</div>
                </div>
              </div>
            </div>
          );
        })}
      </div>
      {/* control */}
      <div
        {...scrub}
        onClick={(e) => step(localPoint(e, e.currentTarget).x < centre(goal.current) ? -1 : 1)}
        style={{ position: "relative", width: CONTROL_W, height: 44, flexShrink: 0, cursor: "pointer", touchAction: "pan-y" }}
      >
        <motion.div
          initial={false}
          animate={{ opacity: platterShown && ctx.b("platter") ? 1 : 0, scale: platterShown ? 1 : 0.9 }}
          transition={platter === "out" ? anim.easeInOut(0.35) : anim.easeOut(0.25)}
          style={{ position: "absolute", left: 0, right: 0, top: 6, height: 32, borderRadius: 16, ...glass("regular"), boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 10px rgb(0 0 0 / 0.12)` }}
        />
        {CITIES.map((_, index) => (
          <div
            key={index}
            style={{
              position: "absolute",
              left: centre(index) - DOT / 2,
              top: 22 - DOT / 2,
              width: DOT,
              height: DOT,
              borderRadius: "50%",
              background: Palette.labelAlpha(0.22),
              transform: `scale(${enlarged ? 1.25 : 1})`,
              transition: `transform ${fade}`,
            }}
          />
        ))}
        <div
          style={{
            position: "absolute",
            left: (low + high) / 2 - (high - low + size) / 2,
            top: 22 - size / 2,
            width: high - low + size,
            height: size,
            borderRadius: size / 2,
            background: Palette.label,
            pointerEvents: "none",
          }}
        />
      </div>
      <DemoHint ctx={ctx} en="Slide along the dots, or swipe the cards" zh="沿圆点滑动，或左右滑动卡片" />
    </div>
  );
}
