/** morph.avatar-profile · 头像展开资料卡 (Morph+AvatarProfile.swift) */
import { motion } from "motion/react";
import { Check, ChevronRight, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, cubicBezier, fonts, hex, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { Column, MorphReveal, diag, horiz, lerpRect, mixN, rectStyle, unit, useProgress, type Rect } from "./_shared";

interface Person {
  name: [string, string];
  role: [string, string];
  initials: [string, string];
  colors: [string, string];
  stats: number[];
}
const people: Person[] = [
  { name: ["Maya Chen", "陈知夏"], role: ["Product designer", "产品设计师"], initials: ["MC", "夏"], colors: [Palette.violet, Palette.pink], stats: [128, 2409, 312] },
  { name: ["Leo Park", "林一舟"], role: ["iOS engineer", "iOS 工程师"], initials: ["LP", "舟"], colors: [Palette.sky, Palette.blue], stats: [86, 1730, 204] },
  { name: ["Ava Stone", "苏晚晴"], role: ["Motion artist", "动效设计师"], initials: ["AS", "晴"], colors: [Palette.amber, Palette.coral], stats: [342, 9120, 518] },
  { name: ["Noah Reed", "周牧野"], role: ["Illustrator", "插画师"], initials: ["NR", "野"], colors: [Palette.mint, Palette.green], stats: [57, 864, 149] },
];
const statNames: [string, string][] = [
  ["Posts", "作品"],
  ["Followers", "粉丝"],
  ["Following", "关注"],
];
const CARD: Rect = { x: 0, y: 0, w: 316, h: 300 };
const rowY = (i: number) => 14 + i * 70;

export default function AvatarProfile({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const [selected, setSelected] = useState<number | null>(null);
  /** The row whose card is on screen (kept through the collapse). */
  const [shown, setShown] = useState<number | null>(null);
  const [following, setFollowing] = useState(false);
  const [detail, setDetail] = useState(true);
  const [p, to] = useProgress(0);
  const autoIndex = useRef(0);
  const [opens, setOpens] = useState(0);
  const L = ctx.lang === "zh" ? 1 : 0;
  const zh = L === 1;
  const spr = spring(ctx.n("response"), ctx.n("damping"));

  const open = (index: number) => {
    if (selected !== null) return;
    haptics.tap("medium");
    setFollowing(false);
    setDetail(true);
    setSelected(index);
    setShown(index);
    setOpens((n) => n + 1);
    to(1, spr);
  };
  const close = () => {
    if (selected === null || !detail) return;
    haptics.tap("soft");
    setDetail(false);
    after(0.06, () => {
      setSelected(null);
      to(0, spr);
    });
  };
  // Drop the overlay once the collapse has landed.
  useEffect(() => {
    if (selected === null && shown !== null && p < 0.002) setShown(null);
  }, [selected, shown, p]);
  useAutoplay(
    ctx.isPreview,
    () => {
      if (selected === null) {
        open(autoIndex.current % people.length);
        autoIndex.current += 1;
      } else close();
    },
    { every: 2.1 },
  );
  const toggleFollow = () => {
    if (following) haptics.tap();
    else haptics.success();
    setFollowing((v) => !v);
  };

  const person = shown !== null ? people[shown] : null;
  const row: Rect = { x: 0, y: rowY(shown ?? 0), w: 316, h: 62 };
  const bg = lerpRect(row, CARD, p);
  const tint = lerpRect({ x: 12, y: row.y + 9, w: 44, h: 44 }, { x: 0, y: 0, w: 316, h: 104 }, p);
  const q = unit(p);
  const fade = selected === null ? 0.4 + 0.6 * (1 - q) : mixN(1, 0.4, q);

  return (
    <Column gap={14}>
      <div style={{ position: "relative", width: 316, height: 300, flexShrink: 0 }}>
        <div style={{ position: "absolute", inset: 0, transform: `scale(${mixN(1, 0.95, p)})`, opacity: fade }}>
          {people.map((person, index) =>
            shown === index ? null : (
              <div
                key={index}
                onClick={() => open(index)}
                style={{
                  position: "absolute",
                  left: 0,
                  top: rowY(index),
                  width: 316,
                  height: 62,
                  borderRadius: 18,
                  background: Palette.elevated,
                  boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 4px 8px ${black(0.07)}`,
                  cursor: "pointer",
                }}
              >
                <RowContent person={person} L={L} />
              </div>
            ),
          )}
        </div>
        {person ? (
          <div style={{ position: "absolute", inset: 0, zIndex: 2 }}>
            <div
              style={{
                ...rectStyle(bg),
                borderRadius: mixN(18, 28, p),
                background: Palette.elevated,
                boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 ${mixN(4, 12, q)}px ${mixN(8, 24, q)}px ${black(mixN(0.07, 0.18, q))}`,
              }}
            />
            {/* The row's own leftovers fade with it. */}
            <div style={{ ...rectStyle(row), opacity: 1 - q, pointerEvents: "none" }}>
              <ChevronRight size={14} strokeWidth={2.6} style={{ position: "absolute", right: 10, top: 24, color: Palette.tertiaryLabel }} />
            </div>
            <div
              onClick={close}
              style={{
                ...rectStyle(tint),
                borderRadius: `${mixN(22, 28, p)}px ${mixN(22, 28, p)}px ${mixN(22, 0, q)}px ${mixN(22, 0, q)}px`,
                background: diag(...person.colors),
                cursor: "pointer",
              }}
            >
              <div
                style={{
                  position: "absolute",
                  left: 12,
                  top: 12,
                  width: 28,
                  height: 28,
                  borderRadius: 14,
                  background: black(0.22),
                  color: "#fff",
                  display: "grid",
                  placeItems: "center",
                  opacity: q,
                }}
              >
                <motion.span initial={false} animate={{ opacity: detail ? 1 : 0 }} transition={anim.easeOut(0.12)} style={{ display: "grid" }}>
                  <X size={12} strokeWidth={3.4} />
                </motion.span>
              </div>
            </div>
            {/* Avatar ring */}
            <div
              style={{
                position: "absolute",
                left: 158 - 36,
                top: 104 - 36,
                width: 72,
                height: 72,
                borderRadius: 36,
                background: Palette.elevated,
                boxShadow: `0 6px 12px ${hex(person.colors[1], 0.35)}`,
                opacity: q,
                transform: `scale(${mixN(0.4, 1, p)})`,
                pointerEvents: "none",
              }}
            >
              <div
                style={{
                  position: "absolute",
                  inset: 4,
                  borderRadius: "50%",
                  padding: 2.5,
                  background: diag(...person.colors),
                  WebkitMask: "linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)",
                  WebkitMaskComposite: "xor",
                  maskComposite: "exclude",
                }}
              />
            </div>
            {/* Initials: the white one of the row and the gradient one of the card travel together. */}
            {[0, 1].map((k) => (
              <div
                key={k}
                style={{
                  position: "absolute",
                  left: mixN(34, 158, p),
                  top: mixN(row.y + 31, 104, p),
                  transform: "translate(-50%, -50%)",
                  whiteSpace: "nowrap",
                  fontFamily: fonts.rounded,
                  fontWeight: 700,
                  fontSize: k === 0 ? (zh ? 18 : 15) : zh ? 28 : 24,
                  lineHeight: 1.2,
                  opacity: k === 0 ? 1 - q : q,
                  pointerEvents: "none",
                  ...(k === 0 ? { color: "#fff" } : { background: diag(...person.colors), WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" }),
                }}
              >
                {person.initials[L]}
              </div>
            ))}
            {/* Name and role */}
            {(
              [
                { text: person.name[L], y0: row.y + 22.5, y1: 104 + 44 + 12.5, small: { fontSize: 15, fontWeight: 600 }, big: { fontSize: 21, fontWeight: 700 }, ratio: 15 / 21, color: Palette.label },
                { text: person.role[L], y0: row.y + 40.5, y1: 104 + 44 + 25 + 3 + 8.5, small: { fontSize: 12, fontWeight: 400 }, big: { fontSize: 14, fontWeight: 400 }, ratio: 12 / 14, color: Palette.secondaryLabel },
              ] as const
            ).map((t, i) => (
              <div key={i} style={{ pointerEvents: "none" }}>
                <div
                  style={{
                    position: "absolute",
                    left: mixN(68, 158, p),
                    top: mixN(t.y0, t.y1, p),
                    transform: `translate(${-50 * p}%, -50%)`,
                    whiteSpace: "nowrap",
                    lineHeight: 1.2,
                    color: t.color,
                    opacity: 1 - q,
                    ...t.small,
                  }}
                >
                  {t.text}
                </div>
                <div
                  style={{
                    position: "absolute",
                    left: mixN(68, 158, p),
                    top: mixN(t.y0, t.y1, p),
                    transform: `translate(${-50 + 50 * t.ratio * (1 - p)}%, -50%)`,
                    whiteSpace: "nowrap",
                    lineHeight: 1.2,
                    color: t.color,
                    opacity: q,
                    ...t.big,
                  }}
                >
                  {t.text}
                </div>
              </div>
            ))}
            {opens > 0 ? (
              <motion.div
                key={opens}
                initial={false}
                animate={{ opacity: detail ? 1 : 0 }}
                transition={anim.easeOut(0.12)}
                style={{ position: "absolute", left: 0, top: 104 + 44 + 25 + 3 + 17 + 14, width: 316, display: "flex", flexDirection: "column", alignItems: "center", opacity: q }}
              >
                <Stats person={person} L={L} duration={ctx.n("count")} />
                <MorphReveal delay={0.36} style={{ marginTop: 14 }}>
                  <motion.button
                    type="button"
                    onClick={toggleFollow}
                    initial={false}
                    animate={{ width: following ? 150 : 132 }}
                    transition={spring(0.38, 0.62)}
                    style={{ position: "relative", height: 40, borderRadius: 20, background: Palette.labelAlpha(0.08), display: "flex", alignItems: "center", justifyContent: "center", gap: 6, overflow: "hidden" }}
                  >
                    <motion.span
                      initial={false}
                      animate={{ opacity: following ? 0 : 1 }}
                      transition={spring(0.38, 0.62)}
                      style={{ position: "absolute", inset: 0, background: horiz(...person.colors) }}
                    />
                    {following ? (
                      <motion.span initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} transition={spring(0.38, 0.62)} style={{ position: "relative", display: "grid" }}>
                        <Check size={14} strokeWidth={3.4} />
                      </motion.span>
                    ) : null}
                    <span style={{ position: "relative", fontSize: 15, fontWeight: 600, color: following ? Palette.label : "#fff" }}>
                      {following ? (zh ? "已关注" : "Following") : zh ? "关注" : "Follow"}
                    </span>
                  </motion.button>
                </MorphReveal>
              </motion.div>
            ) : null}
          </div>
        ) : null}
      </div>
      <DemoHint ctx={ctx} en={selected === null ? "Tap a person" : "Tap the header to close"} zh={selected === null ? "点击一位联系人" : "点击头图关闭"} />
    </Column>
  );
}

function RowContent({ person, L }: { person: Person; L: number }) {
  return (
    <div style={{ position: "absolute", inset: 0, padding: "0 12px", display: "flex", alignItems: "center", gap: 12 }}>
      <div style={{ width: 44, height: 44, borderRadius: 22, background: diag(...person.colors), display: "grid", placeItems: "center", color: "#fff", fontFamily: fonts.rounded, fontWeight: 700, fontSize: L ? 18 : 15 }}>
        {person.initials[L]}
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
        <span style={{ fontSize: 15, fontWeight: 600, lineHeight: "18px" }}>{person.name[L]}</span>
        <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel }}>{person.role[L]}</span>
      </div>
      <span style={{ flex: 1 }} />
      <ChevronRight size={14} strokeWidth={2.6} style={{ color: Palette.tertiaryLabel, marginRight: -2 }} />
    </div>
  );
}

const expoOut = cubicBezier(0.16, 1, 0.3, 1);
const format = (n: number) => (n >= 1000 ? `${Math.floor(n / 1000)},${String(n % 1000).padStart(3, "0")}` : String(n));

function Stats({ person, L, duration }: { person: Person; L: number; duration: number }) {
  // Exponential ease-out: the digits race at first and crawl into the final value.
  const [shown, setShown] = useState(0);
  useEffect(() => {
    let raf = 0;
    const start = performance.now();
    const step = (now: number) => {
      const t = (now - start) / 1000 - 0.2;
      setShown(expoOut(unit(t / Math.max(duration, 0.01))));
      if (t < duration) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [duration]);
  return (
    <div style={{ display: "flex", width: 316, padding: "0 20px" }}>
      {[0, 1, 2].map((c) => (
        <MorphReveal key={c} delay={0.2 + 0.05 * c} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 1 }}>
          <span style={{ fontSize: 20, lineHeight: "24px", fontWeight: 700, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums" }}>{format(Math.round(person.stats[c] * shown))}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", fontWeight: 500, color: Palette.secondaryLabel }}>{statNames[c][L]}</span>
        </MorphReveal>
      ))}
    </div>
  );
}
