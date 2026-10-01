/** feedback.order-box · 打包封箱 (Feedback+OrderBox.swift) */
import { Headphones } from "lucide-react";
import { AnimatePresence, motion, useMotionValueEvent, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, hex, spring, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { checkPath } from "./_scene";
import { SPRINGS, track, useAnimated } from "./shared";

// MARK: - Geometry

/** A box of W × H × D drawn in oblique projection: depth runs up and to the right. */
const G = {
  size: { width: 240, height: 178 },
  width: 132,
  height: 82,
  depth: 64,
  origin: { x: 40, y: 172 },
  longFlap: 66,
  shortFlap: 32,
  longOpen: 118,
  shortOpen: 125,
};
type P = [number, number];
const point = (x: number, y: number, z: number): P => [G.origin.x + x + z * 0.42, G.origin.y - y - z * 0.36];
const quad = (...points: P[]) => points.map((p) => `${p[0].toFixed(2)},${p[1].toFixed(2)}`).join(" ");
/** Where the stamp lands on the front face. */
const STAMP_CENTRE = { x: G.origin.x + G.width - 36, y: G.origin.y - G.height / 2 + 2 };
/** Cardboard tone: `light` 0 (in shade) … 1 (facing the light). */
const cardboard = (light: number) => {
  const l = Math.min(Math.max(light, 0), 1);
  return `rgb(${(176 + (236 - 176) * l).toFixed(1)} ${(124 + (192 - 124) * l).toFixed(1)} ${(74 + (138 - 74) * l).toFixed(1)})`;
};
const EDGE = hex(0x8a5f36, 0.55);
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

export default function OrderBox({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";

  const [itemMV, itemTo] = useAnimated(0);
  const [minorMV, minorTo] = useAnimated(0);
  const [leftMV, leftTo] = useAnimated(0);
  const [rightMV, rightTo] = useAnimated(0);
  const [tapeMV, tapeTo] = useAnimated(0);
  const [, setFrame] = useState(0);
  const redraw = () => setFrame((n) => n + 1);
  useMotionValueEvent(itemMV, "change", redraw);
  useMotionValueEvent(minorMV, "change", redraw);
  useMotionValueEvent(leftMV, "change", redraw);
  useMotionValueEvent(rightMV, "change", redraw);
  useMotionValueEvent(tapeMV, "change", redraw);

  /** `stampRest`: the scale the stamp starts from (the drop), or the small lift it leaves with on reset. */
  const [stamp, setStamp] = useState<{ stamped: boolean; rest: number; t: Transition }>({ stamped: false, rest: 1.15, t: { duration: 0 } });
  const [ring, setRing] = useState(false);
  const [done, setDone] = useState(false);
  const [busy, setBusy] = useState(false);
  const [hops, setHops] = useState(0);
  const [thuds, setThuds] = useState(0);
  const s = useRef({ busy: false, done: false, token: 0 });

  const reset = () => {
    s.current.token++;
    s.current.done = false;
    const back = spring(0.45, 0.8);
    setRing(false);
    setStamp({ stamped: false, rest: 1.15, t: back });
    setDone(false);
    tapeTo(0, back);
    leftTo(0, back);
    rightTo(0, back);
    minorTo(0, back);
    itemTo(0, anim.easeIn(0.2));
  };

  const pack = (buzz: boolean) => {
    const current = ++s.current.token;
    const pace = 1 / Math.max(ctx.n("tempo"), 0.1);
    const alive = () => s.current.token === current;
    s.current.busy = true;
    setBusy(true);
    // The stamp is invisible here: move it up to its drop pose.
    setStamp({ stamped: false, rest: ctx.n("stamp"), t: { duration: 0 } });
    if (buzz) haptics.tap();
    itemTo(1, spring(0.45 * pace, 0.8));
    let at = 0.38 * pace;
    const step = (fn: () => void) => after(at, () => alive() && fn());
    step(() => minorTo(1, anim.easeInOut(0.3 * pace)));
    at += 0.3 * pace;
    step(() => {
      leftTo(1, spring(0.4 * pace, 0.72));
      rightTo(1, { ...spring(0.4 * pace, 0.72), delay: 0.08 * pace });
    });
    at += 0.3 * pace;
    step(() => buzz && haptics.tap("soft"));
    at += 0.16 * pace;
    step(() => tapeTo(1, anim.easeInOut(0.35 * pace)));
    at += 0.45 * pace;
    step(() => setHops((n) => n + 1));
    at += 0.56;
    step(() => buzz && haptics.tap("medium"));
    at += 0.18;
    step(() => setStamp((v) => ({ ...v, stamped: true, t: spring(0.28, 0.55) })));
    at += 0.11;
    step(() => {
      setThuds((n) => n + 1);
      setRing(true);
      s.current.done = true;
      setDone(true);
      if (buzz) haptics.success();
    });
    at += 0.5;
    step(() => {
      s.current.busy = false;
      setBusy(false);
    });
  };

  const tapped = () => {
    if (s.current.busy) return;
    if (s.current.done) reset();
    else pack(true);
  };

  /** Preview loop and intro: pack, or reopen first when the last run is still showing. */
  const play = () => {
    if (s.current.busy) return;
    if (!s.current.done) {
      pack(false);
      return;
    }
    reset();
    const current = ++s.current.token;
    after(0.7, () => s.current.token === current && pack(false));
  };
  useAutoplay(ctx.isPreview, play, { every: 5.4 / ctx.n("tempo") + 0.6, delay: 0.5 });

  // Hop, landing squash and the stamp's thud.
  const hop = ctx.n("hop");
  const he = useElapsed(hops, 1.6, true);
  const lift = he < 0 ? 0 : track(he, 0, [{ cubic: 0, d: 0.14 }, { cubic: -hop, d: 0.2 }, { cubic: 0, d: 0.2 }, { cubic: 0, d: 0.35 }]);
  const squashY = he < 0 ? 1 : track(he, 1, [{ cubic: 0.92, d: 0.14 }, { cubic: 1.05, d: 0.2 }, { cubic: 1.0, d: 0.16 }, { cubic: 0.9, d: 0.07 }, { spring: 1, d: 0.32, ...SPRINGS.bouncy }]);
  const squashX = he < 0 ? 1 : track(he, 1, [{ cubic: 1.05, d: 0.14 }, { cubic: 0.97, d: 0.2 }, { cubic: 1.0, d: 0.16 }, { cubic: 1.07, d: 0.07 }, { spring: 1, d: 0.32, ...SPRINGS.bouncy }]);
  const ground = he < 0 ? 1 : track(he, 1, [{ cubic: 1.05, d: 0.14 }, { cubic: 0.62, d: 0.2 }, { cubic: 1.06, d: 0.2 }, { spring: 1, d: 0.35, ...SPRINGS.bouncy }]);
  const te = useElapsed(thuds, 1.2, true);
  const dip = te < 0 ? 1 : track(te, 1, [{ cubic: 0.965, d: 0.07 }, { spring: 1, d: 0.35, ...SPRINGS.bouncy }]);

  const item = itemMV.get();
  const dropping = stamp.rest > 1.3;
  const captionT = anim.smoothD(0.3);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8 }}>
      {/* Box */}
      <div style={{ position: "relative", width: G.size.width, height: G.size.height, marginTop: 16, flexShrink: 0, transform: "scale(1.1)", transformOrigin: "50% 100%" }}>
        <div
          style={{ position: "absolute", left: 120 + 12 - 85, top: 89 + 86 - 8, width: 170, height: 16, borderRadius: "50%", background: black(0.22), filter: "blur(6px)", transform: `scale(${ground})`, opacity: Math.min(Math.max(ground, 0), 1) }}
        />
        <div style={{ position: "absolute", inset: 0, transform: `scale(${dip})`, transformOrigin: "50% 100%" }}>
          <div style={{ position: "absolute", inset: 0, transform: `translateY(${lift}px) scale(${squashX}, ${squashY})`, transformOrigin: "50% 100%" }}>
            <BoxBack minor={minorMV.get()} />
            {/* The purchase: a small product tile that drops into the box. */}
            <div
              style={{
                position: "absolute",
                left: 120 + 13 - 25,
                top: 89 - 92 + 110 * item - 25,
                width: 50,
                height: 50,
                borderRadius: 14,
                background: Palette.primary,
                boxShadow: `inset 0 0 0 1px ${white(0.25)}, 0 4px 16px ${alpha(Palette.indigo, 0.35)}`,
                color: "#fff",
                display: "grid",
                placeItems: "center",
                opacity: Math.min(Math.max(item * 4, 0), 1),
              }}
            >
              <Headphones size={25} strokeWidth={2.4} />
            </div>
            <BoxFront minor={minorMV.get()} left={leftMV.get()} right={rightMV.get()} tape={tapeMV.get()} />
            {/* Stamp */}
            <motion.div
              initial={false}
              animate={{ scale: stamp.stamped ? 1 : stamp.rest, rotate: stamp.stamped || !dropping ? -10 : -28, opacity: stamp.stamped ? 1 : 0 }}
              transition={stamp.t}
              style={{ position: "absolute", left: STAMP_CENTRE.x - 23, top: STAMP_CENTRE.y - 23, width: 46, height: 46 }}
            >
              <motion.div
                initial={false}
                animate={{ scale: ring ? 1.9 : 1, opacity: ring ? 0 : 0.7 }}
                transition={ring ? anim.easeOut(0.5) : { duration: 0 }}
                style={{ position: "absolute", inset: -1, borderRadius: "50%", border: `2px solid ${Palette.green}` }}
              />
              <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: `linear-gradient(${hex(0x4be08f)}, ${hex(0x1fa85b)})`, boxShadow: `0 2px 6px ${black(0.2)}` }} />
              <div style={{ position: "absolute", inset: 3, borderRadius: "50%", border: `2.5px solid ${white(0.85)}` }} />
              <svg width={19} height={15} viewBox="0 0 19 15" style={{ position: "absolute", left: 13.5, top: 15.5, overflow: "visible" }}>
                <path d={checkPath(19, 15)} fill="none" stroke="#fff" strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </motion.div>
          </div>
        </div>
      </div>

      {/* Caption: `.id(done)` + `.transition(.blurReplace)` */}
      <div style={{ position: "relative", width: 300, height: 42, flexShrink: 0 }}>
        <AnimatePresence initial={false}>
          <motion.div
            key={done ? "done" : "idle"}
            initial={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
            animate={{ opacity: 1, scale: 1, filter: "blur(0px)" }}
            exit={{ opacity: 0, scale: 0.8, filter: "blur(6px)" }}
            transition={captionT}
            style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 2, whiteSpace: "nowrap" }}
          >
            <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600 }}>{done ? (zh ? "下单成功" : "Order placed") : zh ? "无线降噪耳机" : "Wireless headphones"}</span>
            <span style={{ fontSize: 13, lineHeight: "18px", fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel }}>
              {done ? (zh ? "订单 A-2048 · 周四送达" : "Order A-2048 · arrives Thursday") : zh ? "¥899.00 · 包邮" : "$129.00 · free shipping"}
            </span>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Button */}
      <button type="button" onClick={ctx.isPreview ? undefined : tapped} style={{ position: "relative", width: 190, height: 42, flexShrink: 0, borderRadius: 21, opacity: busy ? 0.5 : 1, fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>
        <motion.div initial={false} animate={{ opacity: done ? 0 : 1 }} transition={captionT} style={{ position: "absolute", inset: 0, borderRadius: 21, background: PRIMARY_STRONG }} />
        <motion.div initial={false} animate={{ opacity: done ? 1 : 0 }} transition={captionT} style={{ position: "absolute", inset: 0, borderRadius: 21, background: Palette.labelAlpha(0.09) }} />
        <span style={{ position: "relative", color: done ? Palette.label : "#fff" }}>{done ? (zh ? "再来一单" : "Order again") : zh ? "提交订单" : "Place order"}</span>
      </button>
      <DemoHint ctx={ctx} en="Tap Place order" zh="点击“提交订单”" />
    </div>
  );
}

// MARK: - Layers

const LAYER = { position: "absolute", inset: 0, overflow: "visible", pointerEvents: "none" } as const;

/** Behind the product: the inside of the box and the far flap. */
function BoxBack({ minor }: { minor: number }) {
  const { width: w, height: h, depth: d } = G;
  const angle = ((1 - minor) * G.shortOpen * Math.PI) / 180;
  const reach = G.shortFlap * Math.cos(angle);
  const rise = G.shortFlap * Math.sin(angle);
  return (
    <svg width={G.size.width} height={G.size.height} style={LAYER}>
      {/* Inside walls seen through the opening. */}
      <polygon points={quad(point(0, h, 0), point(w, h, 0), point(w, h, d), point(0, h, d))} fill={hex(0x6e4a28)} />
      <polygon points={quad(point(0, h, d), point(w, h, d), point(w, h - 26, d), point(0, h - 26, d))} fill={hex(0x8a5f36)} />
      {/* Far flap, hinged on the back edge. */}
      <polygon
        points={quad(point(0, h, d), point(w, h, d), point(w, h + rise, d - reach), point(0, h + rise, d - reach))}
        fill={cardboard(0.45 + 0.5 * minor)}
        stroke={hex(0x8a5f36, 0.5)}
        strokeWidth={0.6}
      />
    </svg>
  );
}

/** In front of the product: the faces, the near and side flaps and the tape. */
function BoxFront({ minor, left, right, tape: rawTape }: { minor: number; left: number; right: number; tape: number }) {
  const { width: w, height: h, depth: d } = G;
  const tape = Math.min(Math.max(rawTape, 0), 1);
  const top = point(0, h, 0);
  const bottom = point(0, 0, 0);
  const label = { x: G.origin.x + 12, y: G.origin.y - 40, width: 44, height: 28 };

  // The near flap is hinged on the front top edge; open it leans towards the viewer.
  const nearAngle = ((1 - minor) * G.shortOpen * Math.PI) / 180;
  const nearReach = G.shortFlap * Math.cos(nearAngle);
  const nearRise = G.shortFlap * Math.sin(nearAngle);

  /** A long flap hinged on the left or right top edge; closed it lies on the top towards the middle. */
  const side = (closed: number, onLeft: boolean) => {
    const angle = ((1 - closed) * G.longOpen * Math.PI) / 180;
    const reach = G.longFlap * Math.cos(angle);
    const rise = G.longFlap * Math.sin(angle);
    const hinge = onLeft ? 0 : w;
    const tip = onLeft ? reach : w - reach;
    // The top catches the light once it lies flat; the left flap's underside is the darker one while open.
    const open = onLeft ? 0.38 : 0.62;
    const light = open + (0.98 - open) * Math.min(Math.max(closed, 0), 1);
    return <polygon points={quad(point(hinge, h, 0), point(hinge, h, d), point(tip, h + rise, d), point(tip, h + rise, 0))} fill={cardboard(light)} stroke={EDGE} strokeWidth={0.6} />;
  };

  // Tape runs up the front face, then over the seam to the back edge.
  const half = 8;
  const frontRun = 20;
  const drawn = (frontRun + d) * tape;
  const x0 = w / 2 - half;
  const x1 = w / 2 + half;
  const frontDrawn = Math.min(drawn, frontRun);
  const z = drawn - frontRun;
  const tapeColour = hex(0xfff3d6, 0.9);

  return (
    <svg width={G.size.width} height={G.size.height} style={LAYER}>
      <defs>
        <linearGradient id="order-box-front" gradientUnits="userSpaceOnUse" x1={top[0]} y1={top[1]} x2={bottom[0]} y2={bottom[1]}>
          <stop offset="0" stopColor={cardboard(0.78)} />
          <stop offset="1" stopColor={cardboard(0.56)} />
        </linearGradient>
      </defs>
      <polygon points={quad(point(w, 0, 0), point(w, 0, d), point(w, h, d), point(w, h, 0))} fill={cardboard(0.22)} stroke={EDGE} strokeWidth={0.6} />
      <polygon points={quad(point(0, 0, 0), point(w, 0, 0), point(w, h, 0), point(0, h, 0))} fill="url(#order-box-front)" stroke={EDGE} strokeWidth={0.6} />
      {/* Shipping label. */}
      <rect x={label.x} y={label.y} width={label.width} height={label.height} rx={3} fill={white(0.92)} />
      {[0, 1, 2].map((line) => (
        <rect key={line} x={label.x + 5} y={label.y + 6 + line * 6} width={line === 2 ? 18 : 30} height={2.4} rx={1.2} fill={black(line === 0 ? 0.55 : 0.25)} />
      ))}
      {[0, 1, 2, 3, 4].map((bar) => (
        <rect key={bar} x={label.x + label.width - 14 + bar * 2.2} y={label.y + label.height - 11} width={bar % 2 === 0 ? 1.4 : 0.8} height={7} fill={black(0.6)} />
      ))}
      <polygon points={quad(point(0, h, 0), point(w, h, 0), point(w, h + nearRise, nearReach), point(0, h + nearRise, nearReach))} fill={cardboard(0.5 + 0.45 * minor)} stroke={EDGE} strokeWidth={0.6} />
      {side(left, true)}
      {side(right, false)}
      {tape > 0.001 && (
        <>
          <polygon points={quad(point(x0, h - frontRun, 0), point(x1, h - frontRun, 0), point(x1, h - frontRun + frontDrawn, 0), point(x0, h - frontRun + frontDrawn, 0))} fill={tapeColour} opacity={0.78} />
          {drawn > frontRun && <polygon points={quad(point(x0, h, 0), point(x1, h, 0), point(x1, h, z), point(x0, h, z))} fill={tapeColour} stroke={hex(0xc9a66b, 0.6)} strokeWidth={0.5} />}
        </>
      )}
    </svg>
  );
}
