/** morph.avatar-stack-expand · 头像堆展开 (Morph+AvatarStackExpand.swift) */
import { motion } from "motion/react";
import { ChevronUp } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, anim, black, delayed, hex, spring, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { Column, mixN, smooth, unit, useProgress, vert } from "./_shared";

interface Member {
  name: [string, string];
  role: [string, string];
  color: string;
  online: boolean;
}
const members: Member[] = [
  { name: ["Ava Lin", "林艾娃"], role: ["Owner", "所有者"], color: Palette.coral, online: true },
  { name: ["Ben Ortiz", "欧本"], role: ["Can edit", "可编辑"], color: Palette.indigo, online: true },
  { name: ["Chloe Park", "朴可艾"], role: ["Can edit", "可编辑"], color: Palette.mint, online: false },
  { name: ["Dev Rao", "饶德文"], role: ["Can view", "仅查看"], color: Palette.amber, online: true },
  { name: ["Emi Sato", "佐藤惠美"], role: ["Can view", "仅查看"], color: Palette.pink, online: false },
];
const W = 316;
const H = 306;
const CARD_X = 12;
const CARD_W = 292;
const COLLAPSED = 96;
const EXPANDED = 290;
const AVATAR = 36;
const ROW = 44;
const FIRST_ROW = 96;
const stackSlot = (index: number, overlap: number) => ({ x: CARD_X + CARD_W - 18 - AVATAR / 2 - (members.length - 1 - index) * (AVATAR - overlap), y: H / 2 });
const rowSlot = (index: number) => ({ x: CARD_X + 18 + AVATAR / 2, y: FIRST_ROW + index * ROW });

export default function AvatarStackExpand({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const [expanded, setExpanded] = useState(false);
  const L = ctx.lang === "zh" ? 1 : 0;
  const count = members.length;
  const card = spring(ctx.n("response"), 0.85);
  const stagger = ctx.n("stagger");

  const toggle = () => {
    haptics.tap(expanded ? "light" : "medium");
    setExpanded((v) => !v);
  };
  useAutoplay(ctx.isPreview, toggle, { every: 1.7 });

  return (
    <Column gap={10}>
      <div onClick={toggle} style={{ position: "relative", width: W, height: H, flexShrink: 0, cursor: "pointer" }}>
        <motion.div
          initial={false}
          animate={{
            height: expanded ? EXPANDED : COLLAPSED,
            top: (H - (expanded ? EXPANDED : COLLAPSED)) / 2,
            boxShadow: `inset 0 0 0 1px rgb(128 128 128 / 0.16), 0 ${expanded ? 12 : 8}px ${expanded ? 22 : 14}px ${black(expanded ? 0.16 : 0.1)}`,
          }}
          transition={card}
          style={{ position: "absolute", left: CARD_X, width: CARD_W, borderRadius: 26, background: Palette.elevated }}
        />
        <motion.div
          initial={false}
          animate={{ y: expanded ? (H - EXPANDED) / 2 + 38 : H / 2 }}
          transition={card}
          style={{ position: "absolute", left: CARD_X, top: -19, width: CARD_W, height: 38, padding: "0 18px", display: "flex", alignItems: "center" }}
        >
          <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
            <span style={{ fontSize: 17, lineHeight: "20.5px", fontWeight: 700 }}>{L ? "周末露营计划" : "Weekend camp"}</span>
            <span style={{ fontSize: 12, lineHeight: "14.5px", color: Palette.secondaryLabel }}>{L ? "5 位成员 · 3 人在线" : "5 members · 3 online"}</span>
          </div>
          <span style={{ flex: 1 }} />
          <motion.div
            initial={false}
            animate={{ opacity: expanded ? 1 : 0, scale: expanded ? 1 : 0.5 }}
            transition={card}
            style={{ width: 30, height: 30, borderRadius: 15, background: Palette.labelAlpha(0.07), color: Palette.secondaryLabel, display: "grid", placeItems: "center" }}
          >
            <ChevronUp size={15} strokeWidth={3.2} />
          </motion.div>
        </motion.div>
        {members.slice(1).map((_, i) => (
          <motion.div
            key={i}
            initial={false}
            animate={{ opacity: expanded ? 1 : 0 }}
            transition={delayed(anim.easeOut(0.25), expanded ? 0.2 + (i + 1) * stagger : 0)}
            style={{ position: "absolute", left: CARD_X + 66, top: FIRST_ROW + (i + 0.5) * ROW - 0.5, width: CARD_W - 78, height: 1, background: Palette.stroke }}
          />
        ))}
        {members.map((member, index) => (
          <MemberRow
            key={index}
            member={member}
            index={index}
            expanded={expanded}
            transition={delayed(spring(ctx.n("response"), ctx.n("damping")), (expanded ? index : count - 1 - index) * stagger)}
            overlap={ctx.n("overlap")}
            L={L}
          />
        ))}
      </div>
      <DemoHint ctx={ctx} en={expanded ? "Tap to stack them back" : "Tap the avatar stack"} zh={expanded ? "再点一下叠回去" : "点击头像堆"} />
    </Column>
  );
}

/** One member: the avatar on its arc plus the row text that arrives with it. */
function MemberRow({ member, index, expanded, transition, overlap, L }: { member: Member; index: number; expanded: boolean; transition: ReturnType<typeof spring>; overlap: number; L: number }) {
  const [progress, to] = useProgress(0);
  const first = useRef(true);
  useEffect(() => {
    if (first.current) {
      first.current = false;
      return;
    }
    to(expanded ? 1 : 0, transition);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [expanded]);
  const from = stackSlot(index, overlap);
  const dest = rowSlot(index);
  // x eases out, y stays on the spring: the avatar swings in on an arc.
  const lead = progress < 0 || progress > 1 ? progress : 1 - Math.pow(1 - progress, 2.2);
  const cx = mixN(from.x, dest.x, lead);
  const cy = mixN(from.y, dest.y, progress);
  const text = smooth(progress, 0.5, 1);
  const ring = 1 - smooth(progress, 0.2, 0.7);
  return (
    <div style={{ position: "absolute", inset: 0, pointerEvents: "none", zIndex: members.length - index }}>
      <div
        style={{
          position: "absolute",
          left: CARD_X + 66,
          top: dest.y - 18,
          width: CARD_W - 84,
          height: 36,
          display: "flex",
          alignItems: "center",
          opacity: text,
          filter: text < 0.99 ? `blur(${(1 - text) * 4}px)` : undefined,
          transform: `translateX(${(1 - text) * 24}px)`,
        }}
      >
        <div style={{ display: "flex", flexDirection: "column", gap: 1 }}>
          <span style={{ fontSize: 15, lineHeight: "18px", fontWeight: 600 }}>{member.name[L]}</span>
          <span style={{ fontSize: 11, lineHeight: "13px", color: member.online ? Palette.green : Palette.secondaryLabel }}>{member.online ? (L ? "在线" : "Online") : L ? "2 小时前" : "2h ago"}</span>
        </div>
        <span style={{ flex: 1 }} />
        <span style={{ height: 24, padding: "0 9px", borderRadius: 12, background: Palette.labelAlpha(0.06), color: Palette.secondaryLabel, fontSize: 11, fontWeight: 600, display: "grid", placeItems: "center" }}>{member.role[L]}</span>
      </div>
      <div style={{ position: "absolute", left: cx - AVATAR / 2, top: cy - AVATAR / 2, width: AVATAR, height: AVATAR, transform: `scale(${1 + 0.1 * Math.sin(Math.PI * unit(progress))})` }}>
        {/* The cut-out ring that separates overlapping avatars in the stack. */}
        <div style={{ position: "absolute", inset: -2.5, borderRadius: "50%", background: Palette.elevated, opacity: ring }} />
        <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: vert(hex(member.color, 0.72), member.color), color: "#fff", fontSize: 15, fontWeight: 700, display: "grid", placeItems: "center" }}>
          {[...member.name[L]][0]}
        </div>
        {member.online ? (
          <div
            style={{
              position: "absolute",
              right: 0,
              bottom: 0,
              width: 11,
              height: 11,
              borderRadius: "50%",
              background: Palette.green,
              boxShadow: `inset 0 0 0 2px ${Palette.elevated}`,
              border: `2px solid ${Palette.elevated}`,
              transform: `scale(${smooth(progress, 0.6, 1) * (progress > 1 ? progress : 1)})`,
            }}
          />
        ) : null}
      </div>
    </div>
  );
}
