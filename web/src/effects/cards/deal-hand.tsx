/** cards.deal-hand · 发牌成扇 (Cards+DealHand.swift) */
import { animate, useMotionValue } from "motion/react";
import { Heart, Spade, Sparkle } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, black, clamp, delayed, ease, fonts, spring, springAt, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, persp, useMV } from "./shared";

const HAND = [
  { rank: "10", red: false },
  { rank: "J", red: true },
  { rank: "Q", red: false },
  { rank: "K", red: true },
  { rank: "A", red: false },
];
const COUNT = HAND.length;
const CARD = { w: 76, h: 108 };
const DECK = { x: 0, y: -94 };
const DECK_TILT = -6;
const HAND_Y = 44;
const RADIUS = 250;

export default function DealHand({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [dealt, setDealtState] = useState(false);
  const dealtRef = useRef(false);
  const [lifted, setLifted] = useState<number | null>(null);
  const autoStep = useRef(0);
  const [deckTaps, setDeckTaps] = useState(0);
  const ticks = useTimeouts();

  const setDealt = (value: boolean, muted: boolean) => {
    setLifted(null);
    dealtRef.current = value;
    setDealtState(value);
    ticks.clearAll();
    if (!value || muted) return;
    const stagger = ctx.n("stagger");
    const landing = ctx.n("response") * 0.6;
    for (let i = 0; i < COUNT; i++) ticks.after(landing + i * stagger, () => haptics.tap("light"));
  };

  const tapDeck = () => {
    haptics.tap("medium");
    setDeckTaps((n) => n + 1);
    setDealt(!dealtRef.current, false);
  };

  const tapCard = (index: number) => {
    if (!dealtRef.current) return;
    haptics.selection();
    setLifted((l) => (l === index ? null : index));
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      switch (autoStep.current % 4) {
        case 0:
          setDealt(true, true);
          break;
        case 1:
          setLifted(3);
          break;
        case 2:
          setLifted(1);
          break;
        default:
          setDealt(false, true);
      }
      autoStep.current += 1;
    },
    { every: 1.5 },
  );

  const e = useElapsed(deckTaps, 0.49, true);
  const kick = e < 0 ? 1 : e < 0.09 ? 1 - 0.07 * ease.inOut(e / 0.09) : 0.93 + 0.07 * springAt(e - 0.09, 0.3, 0.5);

  return (
    <Stage gap={6}>
      <div style={{ position: "relative", width: 320, height: 304, flexShrink: 0 }}>
        <div
          onClick={tapDeck}
          style={{
            position: "absolute",
            left: 160 - CARD.w / 2 + DECK.x,
            top: 152 - CARD.h / 2 + DECK.y,
            width: CARD.w,
            height: CARD.h,
            transform: `scale(${kick}) rotate(${DECK_TILT}deg)`,
            cursor: "pointer",
          }}
        >
          <div style={{ position: "absolute", left: 0, top: 0, width: CARD.w, height: CARD.h + 4.8, borderRadius: 11, boxShadow: `0 8px 10px ${black(0.22)}` }} />
          {[0, 1, 2, 3].map((layer) => (
            <div key={layer} style={{ position: "absolute", left: 0, top: (3 - layer) * 1.6, filter: layer < 3 ? `brightness(${1 - 0.05 * (3 - layer)})` : undefined }}>
              <CardBack />
            </div>
          ))}
        </div>
        {HAND.map((_, index) => (
          <HandCard
            key={index}
            index={index}
            dealt={dealt}
            lifted={lifted}
            response={ctx.n("response")}
            stagger={ctx.n("stagger")}
            spread={ctx.n("spread")}
            arc={ctx.n("arc")}
            onTap={() => tapCard(index)}
          />
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap the deck to deal, tap a card to pick it" zh="点击牌堆发牌，点击单张抽起" />
    </Stage>
  );
}

/** One card of the hand. `t` is its flight from the deck (0) to its fan slot (1). */
function HandCard({ index, dealt, lifted, response, stagger, spread, arc, onTap }: { index: number; dealt: boolean; lifted: number | null; response: number; stagger: number; spread: number; arc: number; onTap: () => void }) {
  const tMV = useMotionValue(0);
  const liftMV = useMotionValue(0);
  const shiftMV = useMotionValue(0);
  const liftTarget = lifted === index ? 1 : 0;
  // Neighbours of the picked card splay away from it: 6° next to it, 3° one further, and so on.
  const shiftTarget = lifted === null || lifted === index ? 0 : (index < lifted ? -6 : 6) / Math.abs(index - lifted);
  const prevDealt = useRef(dealt);

  useEffect(() => {
    const dealtChanged = prevDealt.current !== dealt;
    prevDealt.current = dealt;
    // Deal left to right; gather right to left.
    const order = dealt ? index : COUNT - 1 - index;
    const flight = delayed(spring(response, 0.8), order * stagger);
    const pick = dealtChanged ? flight : spring(0.34, 0.66);
    if (dealtChanged) animate(tMV, dealt ? 1 : 0, flight);
    animate(liftMV, liftTarget, pick);
    animate(shiftMV, shiftTarget, pick);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dealt, liftTarget, shiftTarget]);

  const t = useMV(tMV);
  const lift = useMV(liftMV);
  const shift = useMV(shiftMV);
  const clamped = clamp(t);
  const fanAngle = -spread / 2 + (spread * index) / (COUNT - 1) + shift;
  const radians = (fanAngle * Math.PI) / 180;
  const reach = RADIUS + lift * 24;
  const slot = { x: reach * Math.sin(radians), y: HAND_Y + RADIUS - reach * Math.cos(radians) };
  const side = index * 2 >= COUNT - 1 ? 1 : -1;
  const control = { x: (DECK.x + slot.x) / 2 + side * arc, y: (DECK.y + slot.y) / 2 - 12 };
  const u = 1 - t;
  const x = u * u * DECK.x + 2 * u * t * control.x + t * t * slot.x;
  const y = u * u * DECK.y + 2 * u * t * control.y + t * t * slot.y;
  const turn = clamp((clamped - 0.1) / 0.65);
  const eased = turn * turn * (3 - 2 * turn);
  const flip = 180 * (1 - eased);
  const apex = Math.sin(clamped * Math.PI);
  const roll = fanAngle * clamped + DECK_TILT * (1 - clamped) + side * apex * 12;
  const scale = 1 + 0.14 * apex + 0.05 * lift;

  return (
    <div
      onClick={onTap}
      style={{
        position: "absolute",
        left: 160 - CARD.w / 2,
        top: 152 - CARD.h / 2,
        width: CARD.w,
        height: CARD.h,
        zIndex: clamped < 0.35 ? 20 - index : 30 + index,
        transform: `translate(${x}px, ${y}px) rotate(${roll}deg) scale(${scale})`,
        pointerEvents: dealt ? "auto" : "none",
        cursor: "pointer",
      }}
    >
      <div
        style={{
          width: CARD.w,
          height: CARD.h,
          borderRadius: 11,
          transform: `${persp(CARD.w, CARD.h, 0.5)} rotateY(${flip}deg)`,
          boxShadow: `0 ${(3 + 8 * apex + 5 * lift) / scale}px ${(5 + 9 * apex + 6 * lift) / scale}px ${black(0.14 + 0.1 * apex)}`,
        }}
      >
        {flip > 90 ? <CardBack /> : <CardFace index={index} />}
      </div>
    </div>
  );
}

function Suit({ red, size, color }: { red: boolean; size: number; color: string }) {
  const Icon = red ? Heart : Spade;
  return <Icon size={size} fill={color} color={color} strokeWidth={1} />;
}

function CardFace({ index }: { index: number }) {
  const model = HAND[index];
  const ink = model.red ? "#E0364A" : "#1B1C22";
  const corner = (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", color: ink }}>
      <span style={{ fontFamily: fonts.rounded, fontSize: 15, lineHeight: "18px", fontWeight: 700 }}>{model.rank}</span>
      <Suit red={model.red} size={11} color={ink} />
    </div>
  );
  return (
    <div style={{ position: "relative", width: CARD.w, height: CARD.h, borderRadius: 11, background: "linear-gradient(#FFFFFF, #F1F1F4)", boxShadow: `inset 0 0 0 0.8px ${black(0.12)}` }}>
      <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
        <Suit red={model.red} size={38} color={ink} />
      </div>
      <div style={{ position: "absolute", left: 7, top: 7 }}>{corner}</div>
      <div style={{ position: "absolute", right: 7, bottom: 7, transform: "rotate(180deg)" }}>{corner}</div>
    </div>
  );
}

const LATTICE = (() => {
  const w = 56;
  const h = 88;
  let d = "";
  for (let offset = -h; offset < w; offset += 9) d += `M${offset} 0L${offset + h} ${h}M${offset + h} 0L${offset} ${h}`;
  return { w, h, d };
})();

function CardBack() {
  return (
    <div style={{ position: "relative", width: CARD.w, height: CARD.h, borderRadius: 11, background: "linear-gradient(to bottom right, #4B57E0, #7A45D6)" }}>
      <div style={{ position: "absolute", inset: 6 }}>
        <StrokeBorder radius={7} color={white(0.55)} />
      </div>
      <svg width={LATTICE.w} height={LATTICE.h} style={{ position: "absolute", left: 10, top: 10, borderRadius: 6, overflow: "hidden" }}>
        <path d={LATTICE.d} stroke={white(0.2)} strokeWidth={0.7} fill="none" />
      </svg>
      <div style={{ position: "absolute", left: 21, top: 37, width: 34, height: 34, borderRadius: 17, background: "#5A4FDB", boxShadow: `inset 0 0 0 1px ${white(0.55)}`, display: "grid", placeItems: "center", color: "#fff" }}>
        <Sparkle size={18} fill="currentColor" strokeWidth={1.5} />
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 11, boxShadow: `inset 0 0 0 2.5px ${white(0.9)}` }} />
      <div style={{ position: "absolute", inset: 0, borderRadius: 11, boxShadow: `inset 0 0 0 0.8px ${black(0.12)}` }} />
    </div>
  );
}
