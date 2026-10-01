/** morph.notification-expand · 通知展开 (Morph+NotificationExpand.swift) */
import { AnimatePresence, motion } from "motion/react";
import { Calendar, Heart, Mail, MessageCircle, Reply } from "lucide-react";
import { useLayoutEffect, useRef, useState, type ReactNode } from "react";
import { DemoHint, Palette, black, fonts, glass, hex, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Column, MorphReveal, mixN, useProgress } from "./_shared";

const INNER = 268;

export default function NotificationExpand({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [expanded, setExpanded] = useState(false);
  const [liked, setLiked] = useState(false);
  const [p, to] = useProgress(0);
  const zh = ctx.lang === "zh";
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  const stagger = ctx.n("stagger");
  const recede = expanded && ctx.b("recede");

  // Height of the message at its expanded width (up to three lines).
  const probe = useRef<HTMLDivElement>(null);
  const [bodyH, setBodyH] = useState(32);
  useLayoutEffect(() => {
    if (probe.current) setBodyH(probe.current.offsetHeight);
  }, [zh]);

  const set = (value: boolean) => {
    if (value === expanded) return;
    haptics.tap(value ? "medium" : "light");
    setExpanded(value);
    to(value ? 1 : 0, spr);
  };
  useAutoplay(ctx.isPreview, () => set(!expanded), { every: 1.9 });

  const textCol = Math.max(38, 17 + 2 + bodyH);
  const mediaTop = 12 + textCol + 10;
  const openH = mediaTop + 84 + 10 + 36 + 12;
  const cardH = Math.max(mixN(62, openH, p), 40);
  const media = { x: mixN(242, 12, p), y: mixN(12, mediaTop, p), w: Math.max(mixN(38, INNER, p), 1), h: Math.max(mixN(38, 84, p), 1) };
  const message = zh
    ? "山顶的日落太美了！刚拍到这张，云海正好被染成金色，你一定要看看。"
    : "Sunset from the summit was unreal. Just caught this one as the clouds turned gold, you have to see it.";
  const bodyFont = { fontSize: 13, lineHeight: "16px" } as const;

  return (
    <Column gap={10}>
      <div
        style={{
          position: "relative",
          width: 316,
          height: 306,
          flexShrink: 0,
          borderRadius: 38,
          overflow: "hidden",
          boxShadow: `inset 0 0 0 1px ${white(0.12)}, 0 14px 24px ${hex(0x10243f, 0.3)}`,
          color: "#fff",
        }}
      >
        <div
          onClick={() => set(false)}
          style={{
            position: "absolute",
            inset: 0,
            background: `radial-gradient(200px circle at 10% 15%, ${hex(0x7a6bff, 0.4)}, transparent), radial-gradient(230px circle at 80% 95%, ${hex(0xffc58a, 0.55)}, transparent), linear-gradient(to bottom, #0E2A47, #1F5E7A, #6FB4A8)`,
          }}
        />
        <div style={{ position: "absolute", left: 12, right: 12, top: 14, display: "flex", flexDirection: "column", gap: 8, pointerEvents: "none" }}>
          <motion.div
            initial={false}
            animate={{ opacity: expanded ? 0.55 : 1, scale: expanded ? 0.94 : 1 }}
            transition={spr}
            style={{ height: 50, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center" }}
          >
            <span style={{ fontSize: 12, lineHeight: "14px", fontWeight: 600, opacity: 0.8 }}>{zh ? "9月30日 星期三" : "Wednesday, September 30"}</span>
            <span style={{ fontSize: 34, lineHeight: "40px", fontWeight: 600, fontFamily: fonts.rounded, fontVariantNumeric: "tabular-nums" }}>9:41</span>
          </motion.div>

          <div style={{ position: "relative", height: cardH, pointerEvents: "auto", cursor: "pointer" }} onClick={() => set(!expanded)}>
            <motion.div
              initial={false}
              animate={{ boxShadow: `0 ${expanded ? 12 : 5}px ${expanded ? 22 : 10}px ${black(expanded ? 0.28 : 0.12)}` }}
              transition={spr}
              style={{ position: "absolute", inset: 0, borderRadius: 22, ...glass("ultraThin", "dark"), background: "rgb(84 92 104 / 0.5)", border: `0.6px solid ${white(0.2)}` }}
            />
            <div style={{ position: "absolute", left: 12, top: 12 }}>
              <AppIcon colors={["#5BE584", "#1FB855"]}>
                <MessageCircle size={20} fill="currentColor" strokeWidth={0} />
              </AppIcon>
            </div>
            <div style={{ position: "absolute", left: 60, top: 12, width: expanded ? 220 : 172, display: "flex", flexDirection: "column", gap: 2 }}>
              <div style={{ display: "flex", alignItems: "baseline" }}>
                <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600 }}>{zh ? "林一舟" : "Leo Park"}</span>
                <span style={{ flex: 1, minWidth: 4 }} />
                <span style={{ fontSize: 11, opacity: 0.6 }}>{zh ? "现在" : "now"}</span>
              </div>
              <div
                style={{
                  ...bodyFont,
                  opacity: 0.92,
                  overflow: "hidden",
                  ...(expanded
                    ? { display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical" }
                    : { whiteSpace: "nowrap", textOverflow: "ellipsis" }),
                }}
              >
                {message}
              </div>
            </div>
            <div
              ref={probe}
              style={{ ...bodyFont, position: "absolute", left: 60, top: 0, width: 220, visibility: "hidden", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical" }}
            >
              {message}
            </div>
            <div style={{ position: "absolute", left: media.x, top: media.y, width: media.w, height: media.h, borderRadius: mixN(8, 14, p), overflow: "hidden" }}>
              <Media w={media.w} h={media.h} />
            </div>
            <AnimatePresence>
              {expanded ? (
                <motion.div
                  key="actions"
                  exit={{ opacity: 0 }}
                  transition={spr}
                  style={{ position: "absolute", left: 12, top: mediaTop + 94, width: INNER, display: "flex", gap: 8 }}
                >
                  <MorphReveal delay={0.12} style={{ flex: 1 }}>
                    <Action title={zh ? "回复" : "Reply"}>
                      <Reply size={15} fill="currentColor" strokeWidth={2} />
                    </Action>
                  </MorphReveal>
                  <MorphReveal delay={0.12 + stagger} style={{ flex: 1 }}>
                    <button
                      type="button"
                      style={{ display: "block", width: "100%" }}
                      onClick={(e) => {
                        e.stopPropagation();
                        haptics.tap();
                        setLiked((v) => !v);
                      }}
                    >
                      <Action title={zh ? "喜欢" : "Like"}>
                        <motion.span
                          key={liked ? "on" : "off"}
                          initial={{ scale: 0.5, opacity: 0 }}
                          animate={{ scale: 1, opacity: 1 }}
                          transition={spring(0.3, 0.5)}
                          style={{ display: "grid", color: liked ? Palette.pink : "#fff" }}
                        >
                          <Heart size={15} strokeWidth={2.4} fill={liked ? "currentColor" : "none"} />
                        </motion.span>
                      </Action>
                    </button>
                  </MorphReveal>
                </motion.div>
              ) : null}
            </AnimatePresence>
          </div>

          {[0, 1].map((index) => {
            const calendar = index === 0;
            return (
              <motion.div
                key={index}
                initial={false}
                animate={{ scale: recede ? 0.94 : 1, opacity: recede ? 0.45 : 1 }}
                transition={spr}
                style={{
                  transformOrigin: "50% 0%",
                  display: "flex",
                  alignItems: "center",
                  gap: 10,
                  padding: 12,
                  borderRadius: 22,
                  ...glass("ultraThin", "dark"),
                  background: "rgb(84 92 104 / 0.42)",
                  border: `0.6px solid ${white(0.16)}`,
                }}
              >
                <AppIcon colors={calendar ? ["#FF7A6B", "#F0453A"] : ["#5AB8FF", "#2B7CF0"]}>
                  {calendar ? <Calendar size={20} strokeWidth={2.2} /> : <Mail size={20} fill="#fff" stroke="#2B7CF0" strokeWidth={2} />}
                </AppIcon>
                <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
                  <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600 }}>
                    {calendar ? (zh ? "设计评审" : "Design review") : zh ? "周报已发送" : "Weekly digest"}
                  </span>
                  <span style={{ ...bodyFont, opacity: 0.8, whiteSpace: "nowrap" }}>
                    {calendar ? (zh ? "15 分钟后 · 三楼会议室" : "In 15 min · Room 3A") : zh ? "本周有 4 条新动态" : "4 new updates this week"}
                  </span>
                </div>
              </motion.div>
            );
          })}
        </div>
      </div>
      <DemoHint ctx={ctx} en={expanded ? "Tap the wallpaper to collapse" : "Tap the notification"} zh={expanded ? "点击壁纸收起" : "点击通知"} />
    </Column>
  );
}

function Action({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div style={{ height: 36, borderRadius: 18, background: white(0.16), display: "flex", alignItems: "center", justifyContent: "center", gap: 6, fontSize: 13, fontWeight: 600, color: "#fff" }}>
      {children}
      <span>{title}</span>
    </div>
  );
}

function AppIcon({ colors, children }: { colors: [string, string]; children: ReactNode }) {
  return (
    <div style={{ width: 38, height: 38, flexShrink: 0, borderRadius: 9, background: `linear-gradient(to bottom, ${colors[0]}, ${colors[1]})`, display: "grid", placeItems: "center", color: "#fff" }}>
      {children}
    </div>
  );
}

function ridge(w: number, h: number, base: number, peaks: number[]) {
  let d = `M0 ${h} L0 ${h * base}`;
  const step = w / peaks.length;
  peaks.forEach((peak, i) => {
    const x0 = i * step;
    const ty = h * (base - peak * 0.5);
    d += ` Q${x0 + step * 0.3} ${ty + 2} ${x0 + step * 0.5} ${ty} Q${x0 + step * 0.7} ${ty + 4} ${x0 + step} ${h * base}`;
  });
  return `${d} L${w} ${h} Z`;
}

/** The attached photo: a dusk sky with a low sun and two ridgelines, redrawn at whatever size it has. */
function Media({ w, h }: { w: number; h: number }) {
  const r = Math.min(w, h) * 0.2;
  const sx = w * 0.64;
  const sy = h * 0.56;
  return (
    <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ position: "absolute", left: 0, top: 0 }}>
      <defs>
        <linearGradient id="nx-sky" gradientUnits="userSpaceOnUse" x1={w * 0.3} y1={0} x2={w * 0.6} y2={h}>
          <stop offset="0" stopColor="#3B2A78" />
          <stop offset="0.5" stopColor="#E5567A" />
          <stop offset="1" stopColor="#FFB55A" />
        </linearGradient>
        <radialGradient id="nx-glow">
          <stop offset="0" stopColor="#fff" stopOpacity="0.5" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
      </defs>
      <rect width={w} height={h} fill="url(#nx-sky)" />
      <circle cx={sx} cy={sy} r={r * 2.4} fill="url(#nx-glow)" />
      <circle cx={sx} cy={sy} r={r} fill="#FFE9B0" />
      <path d={ridge(w, h, 0.62, [0.18, 0.44, 0.3, 0.52, 0.36])} fill={hex(0x5a2d6e, 0.85)} />
      <path d={ridge(w, h, 0.78, [0.3, 0.14, 0.34, 0.2, 0.4])} fill="#24143F" />
    </svg>
  );
}
