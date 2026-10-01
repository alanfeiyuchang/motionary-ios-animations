/** inputs.card-input (Inputs+CardInput.swift) */
import { AnimatePresence, animate, motion, useMotionValue } from "motion/react";
import { useEffect, useRef, useState } from "react";
import { Calendar, CreditCard, Lock } from "lucide-react";
import { DemoHint, NumericText, Palette, alpha, anim, black, fonts, mix, spring, springAt, useAutoplay, useElapsed, useHaptics, white, type DemoProps } from "../../kit";
import { TextInputStyles } from "./_b-common";
import { column, gray, spacer, useLive, useMV, useTask } from "./_c-common";

type Field = "number" | "expiry" | "code";
type Brand = "nova" | "twin" | null;

const NUMBERS = ["4242424242424242", "5412753498210046"];
const WIDTH = 270;
const CARD = { w: 270, h: 166 };

const grouped = (digits: string) => (digits.match(/.{1,4}/g) ?? []).join(" ");
const slashed = (digits: string) => (digits.length > 2 ? digits.slice(0, 2) + "/" + digits.slice(2) : digits);
const digitsOf = (text: string, limit: number) => text.replace(/\D/g, "").slice(0, limit);
const brandOf = (number: string): Brand => (number[0] === "4" ? "nova" : number[0] === "5" ? "twin" : null);

export default function CardInput({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [number, setNumberState, numberRef] = useLive("");
  const [expiry, setExpiryState, expiryRef] = useLive("");
  const [code, setCodeState, codeRef] = useLive("");
  /** The field that looks focused: follows real focus, or the script. */
  const [active, setActive] = useState<Field | null>(null);
  const angle = useMotionValue(0);
  const [sheens, setSheens] = useState(0);
  const step = useRef(0);
  const scriptTask = useTask();
  const scriptRunning = useRef(false);
  /** True while the form holds values typed by the script; the first real focus clears them. */
  const scripted = useRef(false);
  const focus = useRef<Field | null>(null);
  const inputs = useRef<Record<Field, HTMLInputElement | null>>({ number: null, expiry: null, code: null });
  const isStatic = ctx.isPreview;

  useEffect(() => {
    animate(angle, active === "code" ? 180 : 0, spring(ctx.n("flip"), 0.78));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [active]);

  const setFocus = (field: Field | null) => {
    if (field) inputs.current[field]?.focus();
    else (document.activeElement as HTMLElement | null)?.blur?.();
  };

  // Single source of truth (keyboard and script both write here)
  const setNumber = (text: string) => {
    const value = digitsOf(text, 16);
    if (value === numberRef.current) return;
    const completed = value.length === 16 && numberRef.current.length < 16;
    setNumberState(value);
    if (!completed) return;
    if (ctx.b("sheen")) setSheens((s) => s + 1);
    if (!scriptRunning.current) {
      haptics.tap("light");
      if (focus.current === "number") setFocus("expiry");
    }
  };
  const setExpiry = (text: string) => {
    const value = digitsOf(text, 4);
    if (value === expiryRef.current) return;
    setExpiryState(value);
    if (value.length === 4 && !scriptRunning.current && focus.current === "expiry") setFocus("code");
  };
  const setCode = (text: string) => {
    const value = digitsOf(text, 3);
    if (value === codeRef.current) return;
    setCodeState(value);
    if (value.length === 3 && !scriptRunning.current && focus.current === "code") {
      haptics.success();
      setFocus(null);
    }
  };
  const clear = () => {
    setNumberState("");
    setExpiryState("");
    setCodeState("");
  };

  /** A real field took focus: the script stops and hands over an empty form. */
  const stopScript = () => {
    scriptTask.cancel();
    scriptRunning.current = false;
    scripted.current = false;
    clear();
  };
  const onFocusChange = (field: Field | null) => {
    focus.current = field;
    if (field !== null && scripted.current) stopScript();
    if (!scriptRunning.current) setActive(field);
  };

  // Script (preview loop and the detail intro)
  const runScript = () => {
    const sample = NUMBERS[step.current % NUMBERS.length];
    step.current += 1;
    scripted.current = true;
    scriptRunning.current = true;
    scriptTask.start(async (sleep) => {
      setActive(null);
      clear();
      if (!(await sleep(0.35))) return;
      setActive("number");
      for (let index = 1; index <= sample.length; index++) {
        if (!(await sleep(0.062))) return;
        setNumber(sample.slice(0, index));
      }
      if (!(await sleep(0.4))) return;
      setActive("expiry");
      for (let index = 1; index <= 4; index++) {
        if (!(await sleep(0.11))) return;
        setExpiry("1228".slice(0, index));
      }
      if (!(await sleep(0.35))) return;
      setActive("code");
      if (!(await sleep(0.65))) return;
      for (let index = 1; index <= 3; index++) {
        if (!(await sleep(0.17))) return;
        setCode("737".slice(0, index));
      }
      if (!(await sleep(0.9))) return;
      setActive(null);
      scriptRunning.current = false;
    });
  };
  useAutoplay(ctx.isPreview, runScript, { every: 5.6, delay: 0.4 });

  const field = (id: Field, icon: React.ReactNode, placeholder: string, text: string, set: (v: string) => void, grow = false) => {
    const isActive = active === id;
    return (
      <motion.div
        initial={false}
        animate={{ scale: isActive ? 1.02 : 1, boxShadow: `inset 0 0 0 1.5px ${alpha(Palette.indigo, isActive ? 0.9 : 0)}` }}
        transition={spring(0.3, 0.7)}
        onClick={(e) => {
          e.stopPropagation();
          if (!isStatic) setFocus(id);
        }}
        style={{
          flex: grow ? undefined : 1,
          minWidth: 0,
          height: 46,
          padding: "0 12px",
          borderRadius: 14,
          background: Palette.labelAlpha(0.06),
          display: "flex",
          alignItems: "center",
          gap: 8,
          fontFamily: fonts.rounded,
          fontSize: 16,
          fontWeight: 500,
          fontVariantNumeric: "tabular-nums",
        }}
      >
        <span style={{ width: 20, display: "grid", placeItems: "center", color: isActive ? Palette.indigo : Palette.secondaryLabel, transition: "color 0.2s", flexShrink: 0 }}>{icon}</span>
        {isStatic ? (
          <span style={{ whiteSpace: "nowrap", color: text ? Palette.label : Palette.tertiaryLabel }}>{text || placeholder}</span>
        ) : (
          <input
            ref={(el) => {
              inputs.current[id] = el;
            }}
            className="ml-b-input"
            inputMode="numeric"
            autoComplete="off"
            value={text}
            placeholder={placeholder}
            onChange={(e) => set(e.target.value)}
            onFocus={() => onFocusChange(id)}
            onBlur={() => focus.current === id && onFocusChange(null)}
            style={{ flex: 1, width: "100%", fontSize: 16, fontWeight: 500, fontVariantNumeric: "tabular-nums" }}
          />
        )}
      </motion.div>
    );
  };

  return (
    <div style={column} onClick={() => setFocus(null)}>
      <TextInputStyles />
      <div style={spacer} />
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 16, flexShrink: 0 }}>
        <Faces angleMV={angle} depth={ctx.n("depth")} number={number} expiry={slashed(expiry)} code={code} sheens={sheens} damping={ctx.n("pop")} t={ctx.t} />
        <div style={{ width: WIDTH, display: "flex", flexDirection: "column", gap: 10 }}>
          {field("number", <CreditCard size={16} strokeWidth={2.2} />, ctx.t("Card number", "卡号"), grouped(number), setNumber, true)}
          <div style={{ display: "flex", gap: 10 }}>
            {field("expiry", <Calendar size={16} strokeWidth={2.2} />, ctx.t("MM/YY", "月/年"), slashed(expiry), setExpiry)}
            {field("code", <Lock size={16} strokeWidth={2.2} />, ctx.t("CVV", "安全码"), code, setCode)}
          </div>
        </div>
      </div>
      <div style={spacer} />
      <DemoHint ctx={ctx} en="Type a card number, then tap the CVV field" zh="输入卡号，再点安全码输入框" style={{ paddingBottom: 12 }} />
    </div>
  );
}

/** Both faces of the card, re-derived from the flip angle: faces swap at 90°, the card lifts mid-turn. */
function Faces({
  angleMV,
  depth,
  number,
  expiry,
  code,
  sheens,
  damping,
  t,
}: {
  angleMV: ReturnType<typeof useMotionValue<number>>;
  depth: number;
  number: string;
  expiry: string;
  code: string;
  sheens: number;
  damping: number;
  t: (en: string, zh: string) => string;
}) {
  const angle = useMV(angleMV);
  const brand = brandOf(number);
  const showsBack = angle > 90;
  const lift = Math.abs(Math.sin((angle * Math.PI) / 180));
  const bumpT = useElapsed(number.length, 0.31, true);
  const bump = bumpT < 0 ? 1 : bumpT < 0.06 ? 1 + 0.015 * (bumpT / 0.06) : mix(1.015, 1, springAt(bumpT - 0.06, 0.25, 0.85));
  const sheenT = useElapsed(sheens, 0.7, true);
  const sheenP = sheenT < 0 ? 0 : sheenT / 0.7;
  const sheenX = -240 + 480 * (sheenP < 0.5 ? 2 * sheenP * sheenP : 1 - Math.pow(-2 * sheenP + 2, 2) / 2);
  const face = { position: "absolute", inset: 0, borderRadius: 20, overflow: "hidden" } as const;
  const gradientLayer = { position: "absolute", inset: 0 } as const;
  const smooth = anim.smoothD(0.5);

  return (
    <div
      style={{
        width: CARD.w,
        height: CARD.h,
        flexShrink: 0,
        transform: `scale(${(1 + 0.06 * lift) * bump})`,
        filter: `drop-shadow(0 ${10 + 8 * lift}px ${16 + 10 * lift}px ${black(0.22 + 0.1 * lift)})`,
      }}
    >
      <div style={{ position: "absolute", inset: 0, transform: `perspective(${Math.max(CARD.w / Math.max(depth, 0.01), 1)}px) rotateY(${angle}deg)` }}>
        {/* front */}
        <div style={{ ...face, opacity: showsBack ? 0 : 1 }}>
          <div style={{ ...gradientLayer, background: "linear-gradient(121.6deg, #444857, #1D1F28)" }} />
          <motion.div initial={false} animate={{ opacity: brand === "nova" ? 1 : 0 }} transition={smooth} style={{ ...gradientLayer, background: "linear-gradient(121.6deg, #4F6BFF, #8A45E0, #2BB8E8)" }} />
          <motion.div initial={false} animate={{ opacity: brand === "twin" ? 1 : 0 }} transition={smooth} style={{ ...gradientLayer, background: "linear-gradient(121.6deg, #FF9A4A, #F0506E, #9B2D8F)" }} />
          <div style={{ position: "absolute", left: CARD.w / 2 + 120 - 110, top: CARD.h / 2 - 90 - 110, width: 220, height: 220, borderRadius: "50%", background: white(0.1) }} />
          {/* content */}
          <div style={{ position: "absolute", inset: 0, padding: 18, display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
            <div style={{ display: "flex", alignItems: "flex-start", gap: 8, alignSelf: "stretch" }}>
              <div style={{ position: "relative", width: 36, height: 27, borderRadius: 6, background: "linear-gradient(127deg, #FFE9A8, #D9A441)" }}>
                <div style={{ position: "absolute", inset: 6, borderRadius: 3, border: `1px solid ${black(0.22)}` }} />
              </div>
              <svg width={16} height={18} viewBox="0 0 16 18" fill="none" stroke={white(0.75)} strokeWidth={2} strokeLinecap="round" style={{ marginTop: 5 }}>
                <path d="M2 6.2a4 4 0 0 1 0 5.600" />
                <path d="M6.4 3.600a7.600 7.600 0 0 1 0 10.800" />
                <path d="M10.800 1a11.300 11.300 0 0 1 0 16" />
              </svg>
              <div style={{ flex: 1 }} />
              <div style={{ height: 28, display: "grid", placeItems: "center end" }}>
                <AnimatePresence mode="popLayout" initial={false}>
                  {brand === "nova" && (
                    <motion.span
                      key="nova"
                      initial={{ scale: 0.6, opacity: 0 }}
                      animate={{ scale: 1, opacity: 1 }}
                      exit={{ scale: 0.6, opacity: 0 }}
                      transition={smooth}
                      style={{ fontFamily: fonts.rounded, fontSize: 21, fontWeight: 900, fontStyle: "italic", color: "#fff", lineHeight: "26px", transformOrigin: "100% 50%" }}
                    >
                      NOVA
                    </motion.span>
                  )}
                  {brand === "twin" && (
                    <motion.div key="twin" initial={{ scale: 0.6, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.6, opacity: 0 }} transition={smooth} style={{ position: "relative", width: 44, height: 26, transformOrigin: "100% 50%" }}>
                      <div style={{ position: "absolute", left: 1, top: 0, width: 26, height: 26, borderRadius: "50%", background: "#FFD166" }} />
                      <div style={{ position: "absolute", left: 17, top: 0, width: 26, height: 26, borderRadius: "50%", background: white(0.85) }} />
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ display: "flex", gap: 12 }}>
              {[0, 1, 2, 3].map((group) => (
                <div key={group} style={{ display: "flex", gap: 1.5 }}>
                  {[0, 1, 2, 3].map((columnIndex) => (
                    <Slot key={columnIndex} character={number[group * 4 + columnIndex]} damping={damping} />
                  ))}
                </div>
              ))}
            </div>
            <div style={{ flex: 1 }} />
            <div style={{ display: "flex", alignItems: "flex-end", alignSelf: "stretch" }}>
              <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
                <span style={{ fontSize: 8, fontWeight: 600, lineHeight: "10px", color: white(0.6) }}>{t("CARDHOLDER", "持卡人")}</span>
                <span style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: 600, lineHeight: "16px", color: "#fff" }}>JAMIE LEE</span>
              </div>
              <div style={{ flex: 1 }} />
              <div style={{ display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-end" }}>
                <span style={{ fontSize: 8, fontWeight: 600, lineHeight: "10px", color: white(0.6) }}>{t("VALID THRU", "有效期")}</span>
                <span style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: 600, lineHeight: "16px", color: white(expiry ? 1 : 0.5) }}>
                  <NumericText value={expiry.length} text={expiry || "••/••"} />
                </span>
              </div>
            </div>
          </div>
          {/* sheen */}
          <div
            style={{
              position: "absolute",
              left: CARD.w / 2 - 45,
              top: 0,
              width: 90,
              height: CARD.h,
              background: `linear-gradient(90deg, ${white(0)}, ${white(0.5)}, ${white(0)})`,
              transform: `translateX(${sheenX}px) scaleY(2) rotate(20deg)`,
              mixBlendMode: "plus-lighter",
              pointerEvents: "none",
            }}
          />
          <div style={{ ...gradientLayer, borderRadius: 20, border: `1px solid ${white(0.18)}` }} />
        </div>
        {/* back */}
        <div style={{ ...face, opacity: showsBack ? 1 : 0, transform: "rotateY(180deg)" }}>
          <div style={{ ...gradientLayer, background: "linear-gradient(121.6deg, #454A5C, #1F2230)" }} />
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", gap: 14 }}>
            <div style={{ height: 36, marginTop: 20, background: black(0.85), flexShrink: 0 }} />
            <div style={{ display: "flex", justifyContent: "flex-end", paddingRight: 18 }}>
              <div style={{ display: "flex", borderRadius: 5, overflow: "hidden" }}>
                <div style={{ width: 150, height: 32, background: gray(0.92), display: "flex", alignItems: "center", paddingLeft: 10, fontFamily: fonts.serif, fontStyle: "italic", fontSize: 15, color: gray(0.3) }}>
                  Jamie Lee
                </div>
                <div style={{ width: 58, height: 32, background: "#fff", boxShadow: `inset 0 0 0 2px ${Palette.indigo}`, display: "flex", alignItems: "center", justifyContent: "center", gap: 3 }}>
                  {[0, 1, 2].map((index) => (
                    <Slot key={index} character={code[index]} damping={damping} ink={[0.12 * 255, 0.12 * 255, 0.12 * 255]} />
                  ))}
                </div>
              </div>
            </div>
            <div style={{ fontSize: 9, fontWeight: 600, lineHeight: "11px", color: white(0.55), textAlign: "right", paddingRight: 18, marginTop: -6 }}>{t("Security code", "安全码")}</div>
          </div>
          <div style={{ ...gradientLayer, borderRadius: 20, border: `1px solid ${white(0.14)}` }} />
        </div>
      </div>
    </div>
  );
}

/** One character cell: a placeholder dot until its digit drops in (rises, shrinks from oversize, sharpens). */
function Slot({ character, damping, ink = [255, 255, 255] }: { character?: string; damping: number; ink?: number[] }) {
  const color = (a: number) => `rgb(${ink.map(Math.round).join(" ")} / ${a})`;
  const t = spring(0.32, damping);
  const soft = { opacity: { type: "tween", duration: 0.2, ease: "easeOut" }, filter: { type: "tween", duration: 0.2, ease: "easeOut" } } as const;
  return (
    <div style={{ position: "relative", width: 11, height: 26, display: "grid", placeItems: "center" }}>
      <AnimatePresence initial={false}>
        {character ? (
          <motion.span
            key={`d${character}`}
            initial={{ scale: 1.6, y: 12, filter: "blur(3px)", opacity: 0 }}
            animate={{ scale: 1, y: 0, filter: "blur(0px)", opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ ...t, ...soft }}
            style={{ gridArea: "1 / 1", fontFamily: fonts.rounded, fontSize: 17, fontWeight: 600, fontVariantNumeric: "tabular-nums", lineHeight: "26px", color: color(1) }}
          >
            {character}
          </motion.span>
        ) : (
          <motion.span
            key="dot"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ type: "tween", duration: 0.2, ease: "easeOut" }}
            style={{ gridArea: "1 / 1", width: 5, height: 5, borderRadius: "50%", background: color(0.45) }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
