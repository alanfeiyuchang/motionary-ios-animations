/** navigation.app-switcher · 应用切换器 (Navigation+AppSwitcher.swift) */
import { animate, motion, useMotionValue, type MotionValue, type Transition } from "motion/react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, PlaceholderLines, alpha, anim, rubberBand, spring, useHaptics, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Glyph } from "./groupB-kit";
import { predicted, useMotionNumber } from "./nav-util";
import { CloudSunFill, NoteText, PhotoFill, diag, stageColumn, useAutoplayFlag, useNavPan } from "./_r2";

type IconFn = (size: number) => ReactNode;
const APPS: { id: number; icon: IconFn; name: [string, string]; colors: [string, string] }[] = [
  { id: 0, icon: (s) => <NoteText size={s} />, name: ["Notes", "记事"], colors: [Palette.amber, Palette.coral] },
  { id: 1, icon: (s) => <CloudSunFill size={s} />, name: ["Weather", "天气"], colors: [Palette.sky, Palette.blue] },
  { id: 2, icon: (s) => <Glyph name="music.note" size={s} />, name: ["Music", "音乐"], colors: [Palette.pink, Palette.violet] },
  { id: 3, icon: (s) => <PhotoFill size={s} />, name: ["Photos", "相册"], colors: [Palette.mint, Palette.sky] },
];
const FRAME = { w: 290, h: 284 };
const SCALE = 0.56;
/** Passed cards are packed this much tighter than upcoming ones. */
const PASSED = 0.36;
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

function Card({
  app,
  index,
  focus,
  zoomed,
  away,
  flying,
  enabled,
  move,
  ctx,
  onTap,
  onClose,
}: {
  app: (typeof APPS)[number];
  index: number;
  focus: MotionValue<number>;
  zoomed: boolean;
  away: number;
  flying: boolean;
  enabled: boolean;
  move: Transition;
  ctx: DemoContext;
  onTap: () => void;
  onClose: () => void;
}) {
  // The discrete inputs, each interpolated on its own (SwiftUI animates every modifier's value linearly).
  const indexMV = useMotionValue(index);
  const zoomMV = useMotionValue(0);
  const awayMV = useMotionValue(0);
  const liftMV = useMotionValue(0);
  const f = useMotionNumber(focus);
  const i = useMotionNumber(indexMV);
  const zoom = useMotionNumber(zoomMV);
  const awayX = useMotionNumber(awayMV);
  const lift = useMotionNumber(liftMV);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) return;
    animate(indexMV, index, move);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [index]);
  useEffect(() => {
    if (first.current) return;
    animate(zoomMV, zoomed ? 1 : 0, move);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [zoomed]);
  useEffect(() => {
    if (first.current) return;
    animate(awayMV, away, move);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [away]);
  useEffect(() => {
    if (first.current) return;
    if (flying) animate(liftMV, -340, anim.easeIn(0.22));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [flying]);
  useEffect(() => {
    first.current = false;
  }, []);

  const pan = useNavPan(
    {
      onChange: (s) => {
        // The pan is measured inside the scaled card; the lift is applied outside the scale.
        const dy = s.translation.y * SCALE;
        liftMV.stop();
        liftMV.set(dy < 0 ? dy : rubberBand(dy, 20));
      },
      onEnd: (s) => {
        const travel = (s?.translation.y ?? 0) * SCALE;
        const velocity = (s?.velocity.y ?? 0) * SCALE;
        if (s && (travel < -70 || velocity < -600)) onClose();
        else animate(liftMV, 0, move);
      },
    },
    { directions: ["up"], enabled },
  );

  const distance = i - f;
  const spacing = ctx.n("spacing");
  const rest = (distance >= 0 ? distance * spacing : distance * spacing * PASSED) + 6;
  const lifted = Math.min(Math.max(-lift / 160, 0), 1);
  const scale = lerp(SCALE * (1 - 0.12 * lifted), 1, zoom);
  const shade = lerp(0.34 * Math.min(Math.max(-distance, 0), 1), 0, zoom);
  const radius = lerp(40, 32, zoom);
  const x = lerp(rest + awayX, 0, zoom);
  const y = lerp(18 + lift, 0, zoom);
  const tilt = lerp(-ctx.n("tilt"), 0, zoom);
  // Labels of cards already passed fade out quickly (those cards overlap); upcoming ones only dim.
  const labelOpacity = distance < 0 ? Math.max(0, 1 + distance * 2.5) : 1 - Math.min(distance, 1) * 0.4;

  return (
    <div style={{ position: "absolute", inset: 0, zIndex: zoomed ? 100 : index, transform: `translate(${x}px, ${y}px)`, opacity: 1 - 0.5 * lifted, pointerEvents: "none" }}>
      <div
        {...pan}
        onClick={onTap}
        style={{
          position: "absolute",
          inset: 0,
          transform: `perspective(${Math.max(FRAME.w, FRAME.h) / 0.5}px) rotateY(${tilt}deg) scale(${scale})`,
          pointerEvents: "auto",
          cursor: "pointer",
          touchAction: "pan-y",
        }}
      >
        <div style={{ position: "absolute", inset: 0, borderRadius: radius, background: Palette.elevated, overflow: "hidden", boxShadow: `-10px 14px 24px rgb(0 0 0 / ${lerp(0.4, 0, zoom)})` }}>
          <div style={{ position: "absolute", inset: 0, padding: 20, display: "flex", flexDirection: "column", gap: 14 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 13, background: diag(...app.colors), color: "#fff", display: "grid", placeItems: "center", flexShrink: 0 }}>{app.icon(24)}</div>
              <span style={{ fontSize: 22, lineHeight: "28px", fontWeight: 700, whiteSpace: "nowrap" }}>{ctx.t(...app.name)}</span>
            </div>
            <div style={{ position: "relative", height: 100, borderRadius: 20, background: diag(...app.colors), flexShrink: 0 }}>
              <div style={{ position: "absolute", right: 14, bottom: 14, color: white(0.3) }}>{app.icon(58)}</div>
            </div>
            {[0, 1].map((row) => (
              <div key={row} style={{ display: "flex", alignItems: "center", gap: 12 }}>
                <div style={{ width: 36, height: 36, borderRadius: 10, background: alpha(app.colors[row % app.colors.length], 0.3), flexShrink: 0 }} />
                <div style={{ flex: 1 }}>
                  <PlaceholderLines count={2} color={Palette.labelAlpha(0.1)} />
                </div>
              </div>
            ))}
          </div>
          <div style={{ position: "absolute", inset: 0, background: "#000", opacity: shade, pointerEvents: "none" }} />
        </div>
        {/* label */}
        <div style={{ position: "absolute", left: 0, right: 0, top: -40, display: "flex", justifyContent: "center", opacity: lerp(labelOpacity * (1 - lifted), 0, zoom), pointerEvents: "none" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 6, transformOrigin: "50% 100%", transform: `scale(${1 / SCALE})` }}>
            <div style={{ width: 20, height: 20, borderRadius: 6, background: diag(...app.colors), color: "#fff", display: "grid", placeItems: "center" }}>{app.icon(12)}</div>
            <span style={{ fontSize: 12, lineHeight: "16px", fontWeight: 600, color: white(0.92), whiteSpace: "nowrap" }}>{ctx.t(...app.name)}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function AppSwitcher({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [cards, setCardsState] = useState(() => APPS.map((a) => a.id));
  const cardsRef = useRef(cards);
  const focusMV = useMotionValue(1);
  const goal = useRef(1);
  const dragStart = useRef<number | null>(null);
  const [flying, setFlying] = useState<number[]>([]);
  const flyingRef = useRef<number[]>([]);
  const [zoomed, setZoomedState] = useState<number | null>(null);
  const zoomedRef = useRef<number | null>(null);
  const cancelWork = useRef<(() => void) | null>(null);
  const autoStep = useRef(0);

  const move = spring(ctx.n("response"), ctx.n("damping"));
  const setCards = (next: number[]) => {
    cardsRef.current = next;
    setCardsState(next);
  };
  const setZoomed = (id: number | null) => {
    zoomedRef.current = id;
    setZoomedState(id);
  };
  const focusTo = (value: number) => {
    goal.current = value;
    animate(focusMV, value, move);
  };
  const lastIndex = () => Math.max(cardsRef.current.length - 1, 0);

  const settle = (index: number) => {
    haptics.tap("light");
    focusTo(Math.min(Math.max(index, 0), lastIndex()));
  };

  const pan = useNavPan(
    {
      onChange: (s) => {
        if (zoomedRef.current !== null || cardsRef.current.length === 0) return;
        if (dragStart.current === null) {
          focusMV.stop();
          dragStart.current = focusMV.get();
        }
        let position = dragStart.current - s.translation.x / ctx.n("spacing");
        if (position < 0) position = -rubberBand(-position, 0.5);
        if (position > lastIndex()) position = lastIndex() + rubberBand(position - lastIndex(), 0.5);
        goal.current = position;
        focusMV.set(position);
      },
      onEnd: (s) => {
        const start = dragStart.current;
        if (start === null) return;
        dragStart.current = null;
        const projected = s ? start - predicted(s).x / ctx.n("spacing") : focusMV.get();
        settle(Math.round(projected));
      },
    },
    { axis: "horizontal" },
  );

  const reset = () => {
    setCards(APPS.map((a) => a.id));
    focusTo(1);
  };

  const close = (id: number) => {
    if (!cardsRef.current.includes(id) || flyingRef.current.includes(id)) return;
    haptics.tap("medium");
    flyingRef.current = [...flyingRef.current, id];
    setFlying(flyingRef.current);
    cancelWork.current?.();
    cancelWork.current = after(0.22, () => {
      setCards(cardsRef.current.filter((c) => c !== id));
      focusTo(Math.min(Math.max(Math.round(goal.current), 0), lastIndex()));
      flyingRef.current = flyingRef.current.filter((c) => c !== id);
      setFlying(flyingRef.current);
      if (cardsRef.current.length > 0) return;
      // Nothing left: deal the deck again after a beat.
      cancelWork.current = after(0.9, reset);
    });
  };

  const tapped = (id: number, index: number) => {
    if (zoomedRef.current !== null || flyingRef.current.includes(id)) return;
    haptics.tap("light");
    focusTo(index);
    setZoomed(id);
  };
  const unzoom = () => {
    if (zoomedRef.current === null) return;
    haptics.tap("light");
    setZoomed(null);
  };

  useAutoplayFlag(
    ctx.isPreview,
    () => {
      const phase = autoStep.current % 6;
      autoStep.current += 1;
      const list = cardsRef.current;
      if (list.length <= 1) return reset();
      const current = Math.round(goal.current);
      const at = Math.min(current, list.length - 1);
      if (phase === 0 || phase === 1) settle(current + 1);
      else if (phase === 2) close(list[at]);
      else if (phase === 3) tapped(list[at], at);
      else if (phase === 4) unzoom();
      else settle(Math.max(current - 1, 0));
    },
    { every: 1.3 },
  );

  const zoomIndex = zoomed === null ? -1 : cards.indexOf(zoomed);

  return (
    <div style={stageColumn(14)}>
      <div
        {...pan}
        style={{ position: "relative", width: FRAME.w, height: FRAME.h, flexShrink: 0, borderRadius: 32, overflow: "hidden", background: "linear-gradient(to bottom right, #23264A, #0E0F1C)", boxShadow: "0 10px 18px rgb(0 0 0 / 0.2)", touchAction: "pan-y", isolation: "isolate" }}
      >
        <motion.div
          initial={false}
          animate={{ opacity: cards.length === 0 ? 1 : 0 }}
          transition={move}
          style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center", fontSize: 15, fontWeight: 500, color: white(0.55), pointerEvents: "none" }}
        >
          {ctx.t("No recent apps", "没有最近使用的应用")}
        </motion.div>
        {APPS.map((app) => {
          const index = cards.indexOf(app.id);
          if (index < 0) return null;
          // When another card is zoomed, the rest leave sideways.
          const away = zoomIndex >= 0 && zoomIndex !== index ? (index < zoomIndex ? -260 : 260) : 0;
          return (
            <Card
              key={app.id}
              app={app}
              index={index}
              focus={focusMV}
              zoomed={zoomed === app.id}
              away={away}
              flying={flying.includes(app.id)}
              enabled={zoomed === null}
              move={move}
              ctx={ctx}
              onTap={() => tapped(app.id, index)}
              onClose={() => close(app.id)}
            />
          );
        })}
        {/* home indicator shown while an app is open; tapping it returns to the switcher */}
        <motion.div
          onClick={unzoom}
          initial={false}
          animate={{ opacity: zoomed === null ? 0 : 1 }}
          transition={move}
          style={{ position: "absolute", left: "50%", bottom: 0, marginLeft: -108, padding: "12px 60px", zIndex: 200, cursor: "pointer", pointerEvents: zoomed === null ? "none" : "auto" }}
        >
          <div style={{ width: 96, height: 5, borderRadius: 2.5, background: Palette.labelAlpha(0.45) }} />
        </motion.div>
        <div style={{ position: "absolute", inset: 0, borderRadius: 32, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none", zIndex: 300 }} />
      </div>
      <DemoHint ctx={ctx} en="Swipe sideways, flick a card up, or tap one" zh="横向滑动，向上甩掉一张，或点开一张" />
    </div>
  );
}
