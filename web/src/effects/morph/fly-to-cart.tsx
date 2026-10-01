/** morph.fly-to-cart · 飞入购物车 (Morph+FlyToCart.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { Backpack, Camera, Check, Headphones, Plus, ShoppingCart } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, NumericText, Palette, anim, black, cubicBezier, fonts, hex, spring, useAutoplay, useHaptics, useLatest, useTimeouts, white, type DemoProps } from "../../kit";
import { Column, diag, mixN, morphScreen, smooth, unit, useMV } from "./_shared";

/** `shoe.fill`: a low sneaker in profile. */
function Shoe({ size = 24 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor">
      <path d="M2 15.2 V10.4 c0-.9 1-1.3 1.6-.7 c1.3 1.1 2.9.9 3.9-.5 l1.3-1.9 c.4-.6 1.2-.7 1.7-.2 l4.3 4.1 c.9.9 2.1 1.4 3.4 1.6 l1.6.2 c1.3.2 2.2 1.2 2.2 2.2 Z" />
      <rect x="2" y="16.4" width="20" height="2.4" rx="1.2" />
      <path d="M10.4 9.3 l1.5-1.4 M12.2 11 l1.5-1.4 M14 12.6 l1.4-1.3" stroke="rgba(0,0,0,0.25)" strokeWidth="0.9" strokeLinecap="round" fill="none" />
    </svg>
  );
}

interface Product {
  name: [string, string];
  price: number;
  icon: (size: number) => ReactNode;
  colors: [string, string];
}
const products: Product[] = [
  { name: ["Trail Runner", "越野跑鞋"], price: 129, icon: (s) => <Shoe size={s * 1.15} />, colors: [Palette.amber, Palette.coral] },
  { name: ["Studio Headset", "录音棚耳机"], price: 249, icon: (s) => <Headphones size={s} strokeWidth={2.4} />, colors: [Palette.sky, Palette.blue] },
  { name: ["Day Pack", "日用背包"], price: 89, icon: (s) => <Backpack size={s} strokeWidth={2.2} />, colors: [Palette.mint, Palette.green] },
  { name: ["Field Camera", "旅行相机"], price: 599, icon: (s) => <Camera size={s} strokeWidth={2.2} />, colors: [Palette.pink, Palette.violet] },
];
const W = 316;
const H = 306;
/** Centre of the cart glyph inside the bottom bar. */
const CART = { x: 40, y: 276 };
const BAR = { x: 12, y: 254, w: 292, h: 44 };
const TILE = { w: 141, h: 94 };
const PHOTO = { w: 141, h: 56 };
const tileRect = (i: number) => ({ x: 12 + (i % 2) * (TILE.w + 10), y: 48 + Math.floor(i / 2) * (TILE.h + 8) });
const photoCenter = (i: number) => ({ x: tileRect(i).x + TILE.w / 2, y: tileRect(i).y + PHOTO.h / 2 });
const primaryStrong = diag("#4B57E0", "#7A45D6");

interface Flight {
  id: number;
  product: number;
  buzz: boolean;
}

export default function FlyToCart({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [flights, setFlights] = useState<Flight[]>([]);
  const nextID = useRef(0);
  const [count, setCount] = useState(0);
  const [total, setTotal] = useState(0);
  const [added, setAdded] = useState<Record<number, number>>({});
  const addedRef = useRef<Record<number, number>>({});
  const [dipped, setDipped] = useState<number | null>(null);
  const cartScaleMV = useMotionValue(1);
  const cartTiltMV = useMotionValue(0);
  const badgeMV = useMotionValue(1);
  const rippleMV = useMotionValue(1);
  const cartScale = useMV(cartScaleMV);
  const cartTilt = useMV(cartTiltMV);
  const badgeScale = useMV(badgeMV);
  const ripple = useMV(rippleMV);
  const autoIndex = useRef(0);
  const L = ctx.lang === "zh" ? 1 : 0;

  const setAddedFor = (index: number, stamp: number | null) => {
    const next = { ...addedRef.current };
    if (stamp === null) delete next[index];
    else next[index] = stamp;
    addedRef.current = next;
    setAdded(next);
  };
  const add = (index: number, buzz = true) => {
    haptics.tap("light");
    setDipped(index);
    after(0.1, () => setDipped((d) => (d === index ? null : d)));
    const stamp = nextID.current;
    nextID.current += 1;
    setFlights((f) => [...f, { id: stamp, product: index, buzz }]);
    setAddedFor(index, stamp);
    after(1.0, () => {
      if (addedRef.current[index] === stamp) setAddedFor(index, null);
    });
  };
  const arrive = (flight: Flight) => {
    setFlights((f) => f.filter((x) => x.id !== flight.id));
    if (flight.buzz) haptics.tap("rigid");
    cartScaleMV.jump(1.28);
    cartTiltMV.jump(-14);
    badgeMV.jump(1.5);
    rippleMV.jump(0);
    const pop = spring(0.3, 0.4);
    animate(cartScaleMV, 1, pop);
    animate(cartTiltMV, 0, pop);
    animate(badgeMV, 1, pop);
    setCount((c) => c + 1);
    setTotal((t) => t + products[flight.product].price);
    animate(rippleMV, 1, anim.easeOut(0.55));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      if (count >= 8) {
        setCount(0);
        setTotal(0);
      }
      const order = [2, 1, 3, 0];
      add(order[autoIndex.current % order.length], false);
      autoIndex.current += 1;
    },
    { every: 1.15 },
  );

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        <div style={{ position: "absolute", left: 16, top: 0, height: 46, display: "flex", alignItems: "center", fontSize: 22, fontWeight: 700 }}>{L ? "新品" : "New in"}</div>
        {products.map((product, index) => {
          const r = tileRect(index);
          const isAdded = added[index] !== undefined;
          return (
            <motion.div
              key={index}
              onClick={() => add(index)}
              initial={false}
              animate={{ scale: dipped === index ? 0.96 : 1 }}
              transition={dipped === index ? spring(0.18, 0.7) : spring(0.4, 0.5)}
              style={{ position: "absolute", left: r.x, top: r.y, width: TILE.w, height: TILE.h, borderRadius: 18, overflow: "hidden", background: Palette.elevated, cursor: "pointer" }}
            >
              <div style={{ height: PHOTO.h, background: diag(...product.colors), color: "#fff", display: "grid", placeItems: "center" }}>{product.icon(30)}</div>
              <div style={{ height: TILE.h - PHOTO.h, padding: "0 10px", display: "flex", alignItems: "center", gap: 4 }}>
                <div style={{ display: "flex", flexDirection: "column", gap: 1, minWidth: 0 }}>
                  <span style={{ fontSize: 12, lineHeight: "14.5px", fontWeight: 600, whiteSpace: "nowrap" }}>{product.name[L]}</span>
                  <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>${product.price}</span>
                </div>
                <span style={{ flex: 1 }} />
                <motion.div
                  initial={false}
                  animate={{ scale: isAdded ? 1.12 : 1 }}
                  transition={isAdded ? spring(0.3, 0.6) : spring(0.35, 0.7)}
                  style={{ position: "relative", width: 26, height: 26, flexShrink: 0, borderRadius: 13, background: primaryStrong, color: "#fff", display: "grid", placeItems: "center", overflow: "hidden" }}
                >
                  <motion.div initial={false} animate={{ opacity: isAdded ? 1 : 0 }} transition={spring(0.3, 0.6)} style={{ position: "absolute", inset: 0, background: Palette.green }} />
                  <AnimatePresence initial={false} mode="popLayout">
                    <motion.span
                      key={isAdded ? "check" : "plus"}
                      initial={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                      animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }}
                      exit={{ scale: 0.4, opacity: 0, filter: "blur(3px)" }}
                      transition={spring(0.3, 0.6)}
                      style={{ position: "relative", display: "grid" }}
                    >
                      {isAdded ? <Check size={13} strokeWidth={3.6} /> : <Plus size={14} strokeWidth={3.4} />}
                    </motion.span>
                  </AnimatePresence>
                </motion.div>
              </div>
              <div style={{ position: "absolute", inset: 0, borderRadius: 18, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
            </motion.div>
          );
        })}
        {/* Cart bar */}
        <div style={{ position: "absolute", inset: 0, pointerEvents: "none" }}>
          <div
            style={{
              position: "absolute",
              left: BAR.x,
              top: BAR.y,
              width: BAR.w,
              height: BAR.h,
              borderRadius: BAR.h / 2,
              background: primaryStrong,
              boxShadow: `0 6px 12px ${hex(Palette.indigo, 0.35)}`,
              transform: `scale(${1 + (cartScale - 1) * 0.14})`,
              color: "#fff",
              display: "flex",
              alignItems: "center",
              paddingLeft: 50,
              paddingRight: 16,
            }}
          >
            <span style={{ fontSize: 14, fontWeight: 600 }}>{L ? "查看购物车" : "View cart"}</span>
            <span style={{ flex: 1 }} />
            <span style={{ fontSize: 15, fontWeight: 700, fontFamily: fonts.rounded, display: "inline-flex" }}>
              $<NumericText value={total} />
            </span>
          </div>
          <div
            style={{
              position: "absolute",
              left: CART.x,
              top: CART.y,
              width: 30 + 44 * ripple,
              height: 30 + 44 * ripple,
              transform: "translate(-50%, -50%)",
              borderRadius: "50%",
              border: "2px solid #fff",
              opacity: 0.7 * (1 - ripple),
            }}
          />
          <div
            style={{
              position: "absolute",
              left: CART.x - 16,
              top: CART.y - 16,
              width: 32,
              height: 32,
              borderRadius: 16,
              background: white(0.2),
              color: "#fff",
              display: "grid",
              placeItems: "center",
              transform: `rotate(${cartTilt}deg) scale(${cartScale})`,
            }}
          >
            <ShoppingCart size={16} strokeWidth={2.4} fill="currentColor" />
            <div
              style={{
                position: "absolute",
                right: -7,
                top: -6,
                minWidth: 18,
                height: 18,
                padding: "0 4px",
                borderRadius: 9,
                background: Palette.red,
                boxShadow: `inset 0 0 0 1.5px ${white(0.9)}`,
                fontSize: 11,
                fontWeight: 700,
                display: "grid",
                placeItems: "center",
                transform: `scale(${count > 0 ? badgeScale : 0.01})`,
                opacity: count > 0 ? 1 : 0,
              }}
            >
              <NumericText value={count} />
            </div>
          </div>
        </div>
        {flights.map((flight) => (
          <CartFlight key={flight.id} flight={flight} duration={ctx.n("duration")} arc={ctx.n("arc")} spin={ctx.n("spin")} shrink={ctx.n("shrink")} onArrive={arrive} />
        ))}
      </div>
      <DemoHint ctx={ctx} en="Tap a product" zh="点击任意商品" />
    </Column>
  );
}

const flightCurve = cubicBezier(0.5, 0, 0.9, 0.62);

/** One photo in flight; it owns its progress so flights overlap freely. */
function CartFlight({ flight, duration, arc, spin, shrink, onArrive }: { flight: Flight; duration: number; arc: number; spin: number; shrink: number; onArrive: (f: Flight) => void }) {
  const [t, setT] = useState(0);
  const arriveRef = useLatest(onArrive);
  useEffect(() => {
    let raf = 0;
    const start = performance.now();
    const step = (now: number) => {
      const p = Math.min((now - start) / 1000 / duration, 1);
      setT(flightCurve(p));
      if (p < 1) raf = requestAnimationFrame(step);
      else arriveRef.current(flight);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const item = products[flight.product];
  const point = (u: number) => {
    const start = photoCenter(flight.product);
    // A toss: up and over first, then down into the cart.
    const control = { x: mixN(start.x, CART.x, 0.45), y: Math.max(start.y - arc, 20) };
    const a = (1 - u) * (1 - u);
    const b = 2 * (1 - u) * u;
    const c = u * u;
    return { x: a * start.x + b * control.x + c * CART.x, y: a * start.y + b * control.y + c * CART.y };
  };
  const piece = (u: number, opacity: number, solid: boolean, key: string) => {
    const width = mixN(PHOTO.w, PHOTO.h, smooth(u, 0, 0.35));
    const height = PHOTO.h;
    const swell = 1 + 0.08 * Math.sin(Math.PI * unit(u / 0.3));
    const scale = swell * mixN(1, shrink, Math.pow(unit(u), 1.4));
    const radius = mixN(16, height / 2, smooth(u, 0.2, 0.9));
    const p = point(u);
    return (
      <div
        key={key}
        style={{
          position: "absolute",
          left: p.x - width / 2,
          top: p.y - height / 2,
          width,
          height,
          borderRadius: radius,
          background: diag(...item.colors),
          boxShadow: solid ? `inset 0 0 0 1.5px ${white(0.5)}, 0 8px 10px ${black(0.28)}` : undefined,
          transform: `rotate(${spin * smooth(u, 0.1, 1)}deg) scale(${scale})`,
          opacity,
          color: "#fff",
          display: "grid",
          placeItems: "center",
        }}
      >
        {solid ? item.icon(30) : null}
      </div>
    );
  };
  const ghost = (lag: number, opacity: number) => (t - lag > 0.02 && t < 0.98 ? piece(t - lag, opacity * smooth(t, 0.05, 0.3), false, `g${lag}`) : null);
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: H, pointerEvents: "none" }}>
      {ghost(0.12, 0.16)}
      {ghost(0.06, 0.3)}
      {piece(t, 1 - smooth(t, 0.92, 1), true, "solid")}
    </div>
  );
}
