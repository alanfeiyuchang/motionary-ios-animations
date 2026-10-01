/** feedback.sticker-slap · 拍上贴纸 (Feedback+StickerSlap.swift) */
import { motion, type Transition } from "motion/react";
import { useRef, useState } from "react";
import { DemoHint, Palette, alpha, anim, black, demoCard, fonts, hex, useAutoplay, useElapsed, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { track, type Keyframe } from "./shared";

type StickerState = "raised" | "stuck" | "peeled";

const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";
/** `Color.gray` (systemGray). */
const GRAY = "142 142 147";
const DUST_LIFE = 0.55;
const INSTANT: Transition = { duration: 0 };
const DIP: Keyframe[] = [{ cubic: 0.965, d: 0.06 }, { spring: 1, d: 0.45, response: 0.32, damping: 0.5 }];
const deg = (shear: number) => (Math.atan(shear) * 180) / Math.PI;

export default function StickerSlap({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [state, setStateRaw] = useState<StickerState>("raised");
  const [t, setT] = useState<Transition>(INSTANT);
  const [impacts, setImpacts] = useState(0);
  const [dust, setDust] = useState(false);
  const [shine, setShine] = useState(false);
  const stateRef = useRef<StickerState>("raised");
  const busy = useRef(false);
  const zh = ctx.lang === "zh";
  const paid = state === "stuck";

  const setState = (s: StickerState, tr: Transition) => {
    stateRef.current = s;
    setT(tr);
    setStateRaw(s);
  };

  const slap = (buzz: boolean) => {
    clearAll();
    busy.current = true;
    setShine(false);
    // Jump back above the card without animating, then fall.
    setState("raised", INSTANT);
    after(0.03, () => {
      setState("stuck", anim.easeIn(0.17));
      after(0.16, () => {
        setImpacts((n) => n + 1);
        setDust(true);
        if (buzz) haptics.tap("rigid");
        after(0.2, () => {
          setShine(true);
          busy.current = false;
          after(0.6, () => setDust(false));
        });
      });
    });
  };

  const peel = (buzz: boolean) => {
    clearAll();
    setDust(false);
    if (buzz) haptics.tap();
    setState("peeled", anim.easeIn(0.22));
  };

  const toggle = (buzz = true) => {
    if (busy.current) return;
    if (stateRef.current === "stuck") peel(buzz);
    else slap(buzz);
  };
  useAutoplay(ctx.isPreview, () => toggle(false), { every: 2.3, delay: 0.6 });

  // Impact: the card dips, the sticker squashes and its shear flicks.
  const e = useElapsed(impacts, 1.2, true);
  const dip = e < 0 ? 1 : track(e, 1, DIP);
  const wobbleScale = e < 0 ? 1 : track(e, 1, [{ cubic: 1 - ctx.n("squash"), d: 0.05 }, { spring: 1, d: 0.5, response: 0.3, damping: 0.5 }]);
  const wobbleShear = e < 0 ? 0 : track(e, 0, [{ cubic: 0.1, d: 0.07 }, { spring: 0, d: 0.48, response: 0.3, damping: 0.45 }]);

  const rest = ctx.n("angle");
  const pose = {
    raised: { scale: ctx.n("drop"), rotate: rest - 14, shear: -0.25, opacity: 0 },
    stuck: { scale: 1, rotate: rest, shear: 0, opacity: 1 },
    peeled: { scale: 1.3, rotate: rest + 9, shear: 0.12, opacity: 0 },
  }[state];

  const line = (title: string, amount: string) => (
    <div style={{ display: "flex", alignItems: "center", height: 24, fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>
      <span>{title}</span>
      <div style={{ flex: 1 }} />
      <span style={{ fontVariantNumeric: "tabular-nums" }}>{amount}</span>
    </div>
  );
  const chipColor = paid ? Palette.green : hex(0xc27a00);

  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
      <div style={{ position: "relative", width: 300, height: 220, flexShrink: 0, display: "grid", placeItems: "center" }}>
        {/* Invoice */}
        <div style={{ ...demoCard(24), gridArea: "1/1", width: 264, height: 190, padding: 18, display: "flex", flexDirection: "column", justifyContent: "center", transform: `scale(${dip})` }}>
          <div style={{ display: "flex", alignItems: "center", paddingBottom: 14 }}>
            <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600 }}>{zh ? "账单 #2048" : "Invoice #2048"}</span>
              <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel }}>{zh ? "北岸设计工作室" : "Northshore Studio"}</span>
            </div>
            <div style={{ flex: 1 }} />
            <span
              style={{
                position: "relative",
                display: "inline-grid",
                placeItems: "center",
                height: 22,
                padding: "0 9px",
                borderRadius: 11,
                fontSize: 11,
                lineHeight: "13px",
                fontWeight: 600,
                whiteSpace: "nowrap",
                color: chipColor,
                background: alpha(paid ? Palette.green : Palette.amber, 0.16),
                transition: `color ${paid ? 0.17 : 0.22}s ease-in, background-color ${paid ? 0.17 : 0.22}s ease-in`,
              }}
            >
              {paid ? (zh ? "已结清" : "Settled") : zh ? "10月12日到期" : "Due Oct 12"}
            </span>
          </div>
          {line(zh ? "品牌设计" : "Brand design", zh ? "¥6,400" : "$960")}
          {line(zh ? "动效规范" : "Motion guidelines", zh ? "¥2,200" : "$320")}
          <div style={{ height: 1, margin: "10px 0", background: Palette.labelAlpha(0.08), flexShrink: 0 }} />
          <div style={{ display: "flex", alignItems: "baseline" }}>
            <span style={{ fontSize: 13, lineHeight: "18px", color: Palette.secondaryLabel }}>{zh ? "合计" : "Total"}</span>
            <div style={{ flex: 1 }} />
            <span style={{ fontFamily: fonts.rounded, fontSize: 26, lineHeight: "31px", fontWeight: 700, fontVariantNumeric: "tabular-nums" }}>{zh ? "¥8,600.00" : "$1,280.00"}</span>
          </div>
        </div>

        {/* Dust, then the sticker, both 34 pt right of and 4 pt above the centre. */}
        <div style={{ gridArea: "1/1", width: 300, height: 220, transform: "translate(34px, -4px)", pointerEvents: "none" }}>
          {dust && <Dust key={impacts} count={Math.max(ctx.i("dust"), 1)} />}
        </div>
        <div style={{ gridArea: "1/1", transform: "translate(34px, -4px)", pointerEvents: "none" }}>
          <motion.div initial={false} animate={{ scale: pose.scale, rotate: pose.rotate, opacity: pose.opacity }} transition={t}>
            <motion.div initial={false} animate={{ skewX: deg(pose.shear) }} transition={t}>
              <div style={{ transform: `skewX(${deg(wobbleShear)}deg) scale(${wobbleScale})` }}>
                <StickerFace text={zh ? "已付款" : "PAID"} shine={shine} />
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>

      <button type="button" onClick={() => toggle()} style={{ position: "relative", width: 190, height: 42, borderRadius: 21, flexShrink: 0, overflow: "hidden", background: Palette.labelAlpha(0.09) }}>
        <motion.div initial={false} animate={{ opacity: paid ? 0 : 1 }} transition={paid ? anim.easeIn(0.17) : anim.easeIn(0.22)} style={{ position: "absolute", inset: 0, background: PRIMARY_STRONG }} />
        <span style={{ position: "relative", fontSize: 15, lineHeight: "20px", fontWeight: 600, color: paid ? Palette.label : "#fff" }}>
          {paid ? (zh ? "撕下贴纸" : "Peel it off") : zh ? "标记为已付款" : "Mark as paid"}
        </span>
      </button>
      <DemoHint ctx={ctx} en="Tap the button" zh="点击按钮" />
    </div>
  );
}

/** A die-cut sticker: bold label on green, white border, soft gloss and a sweeping highlight. */
function StickerFace({ text, shine }: { text: string; shine: boolean }) {
  return (
    <div style={{ position: "relative", padding: 5, borderRadius: 17, background: "#fff", boxShadow: `0 4px 7px ${black(0.28)}` }}>
      <div
        style={{
          position: "relative",
          display: "flex",
          alignItems: "center",
          gap: 7,
          height: 52,
          padding: "0 15px",
          borderRadius: 13,
          overflow: "hidden",
          color: "#fff",
          background: "linear-gradient(to bottom right, #3DDC84, #12924B)",
        }}
      >
        <div style={{ position: "absolute", inset: 0, background: `linear-gradient(${white(0.3)}, ${white(0)} 50%)` }} />
        <motion.div
          initial={false}
          animate={{ x: shine ? "calc(100% + 30px)" : "-76px" }}
          transition={shine ? anim.easeInOut(0.55) : { duration: 0 }}
          style={{ position: "absolute", left: 0, top: 0, width: "100%", height: "100%" }}
        >
          <div style={{ width: 46, height: "100%", background: `linear-gradient(90deg, ${white(0)}, ${white(0.65)}, ${white(0)})`, transform: "rotate(18deg)" }} />
        </motion.div>
        {/* checkmark.seal.fill */}
        <svg width={27} height={27} viewBox="0 0 24 24" style={{ position: "relative", flexShrink: 0 }}>
          <path
            d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"
            fill="#fff"
            stroke="#fff"
            strokeWidth={1.6}
            strokeLinejoin="round"
          />
          <path d="m8.4 12.3 2.5 2.5 4.8-5.2" fill="none" stroke="#22B062" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        <span style={{ position: "relative", fontFamily: fonts.rounded, fontSize: 27, lineHeight: "32px", fontWeight: 900, letterSpacing: 1, whiteSpace: "nowrap" }}>{text}</span>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 17, boxShadow: `inset 0 0 0 0.5px ${black(0.08)}`, pointerEvents: "none" }} />
    </div>
  );
}

/** Dust kicked out from under the sticker at impact: puffs and a thin ring spreading along an ellipse. */
function Dust({ count }: { count: number }) {
  const elapsed = useElapsed(0, DUST_LIFE);
  const t = elapsed / DUST_LIFE;
  if (t <= 0 || t >= 1) return null;
  const cx = 150;
  const cy = 110;
  const eased = 1 - (1 - t) ** 3;
  const fade = (1 - t) * (1 - t);
  return (
    <svg width={300} height={220} viewBox="0 0 300 220" style={{ overflow: "visible" }}>
      <ellipse cx={cx} cy={cy} rx={78 + 34 * eased} ry={36 + 22 * eased} fill="none" stroke={`rgb(${GRAY} / ${0.5 * fade})`} strokeWidth={1.5 * (1 - t) + 0.3} />
      {Array.from({ length: count }, (_, index) => {
        const seed = Math.abs(Math.sin(index * 12.9898));
        const angle = ((index + seed * 0.6) / count) * 2 * Math.PI;
        const reach = 16 + 30 * seed;
        const x = cx + Math.cos(angle) * (74 + reach * eased);
        const y = cy + Math.sin(angle) * (34 + reach * eased * 0.6);
        return <circle key={index} cx={x} cy={y} r={3 + (5 + 5 * seed) * eased} fill={`rgb(${GRAY} / ${0.42 * fade})`} />;
      })}
    </svg>
  );
}
