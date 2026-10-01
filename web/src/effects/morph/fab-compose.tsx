/** morph.fab-compose · 悬浮按钮展开写信 (Morph+FabCompose.swift) */
import { motion } from "motion/react";
import { ArrowUp, Check, Image as ImageIcon, Paperclip, SquarePen, Type, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { DemoHint, Palette, black, hex, spring, useAutoplay, useHaptics, useTimeouts, white, type DemoProps } from "../../kit";
import { Column, diag, mixN, morphScreen, smooth, unit, useProgress, vert } from "./_shared";

const FAB = { x: 244, y: 234, w: 56, h: 56 };
const SHEET = { x: 8, y: 30, w: 300, h: 268 };
const bodyText: [string, string] = ["Trail opens at seven. I'll bring coffee and the good map.", "步道七点开放。咖啡和那张好用的地图我来带，山脚见。"];
const primaryStrong = diag("#4B57E0", "#7A45D6");

export default function FabCompose({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after, clearAll } = useTimeouts();
  const [open, setOpen] = useState(false);
  const [typed, setTyped] = useState(0);
  const [sent, setSent] = useState(false);
  const [progress, to] = useProgress(0);
  const autoStep = useRef(0);
  const typing = useRef(0);
  const zh = ctx.lang === "zh";
  const L = zh ? 1 : 0;
  const spr = spring(ctx.n("response"), ctx.n("damping"));
  useEffect(() => () => window.clearInterval(typing.current), []);

  const present = () => {
    if (open) return;
    clearAll();
    window.clearInterval(typing.current);
    haptics.tap("medium");
    setTyped(0);
    setSent(false);
    setOpen(true);
    to(1, spr);
    const total = [...bodyText[L]].length;
    after(ctx.n("response") * 0.9, () => {
      let count = 0;
      typing.current = window.setInterval(() => {
        count += 1;
        setTyped(count);
        if (count >= total) window.clearInterval(typing.current);
      }, 1000 / 28);
    });
  };
  const close = (sending: boolean) => {
    if (!open) return;
    clearAll();
    window.clearInterval(typing.current);
    if (sending) haptics.success();
    else haptics.tap("light");
    setOpen(false);
    setSent(sending);
    to(0, spr);
    if (sending) after(1.25, () => setSent(false));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      const step = autoStep.current % 4;
      if (step === 0 || step === 2) present();
      else close(step === 1);
      autoStep.current += 1;
    },
    { every: 1.7 },
  );

  const openP = unit(progress);
  const fillHold = ctx.n("fill");
  // x eases out while y stays linear, so the centre travels on an arc.
  const lead = progress < 0 || progress > 1 ? progress : 1 - Math.pow(1 - progress, 1.7);
  const width = Math.max(mixN(FAB.w, SHEET.w, progress), 30);
  const height = Math.max(mixN(FAB.h, SHEET.h, progress), 30);
  const midX = mixN(FAB.x + FAB.w / 2, SHEET.x + SHEET.w / 2, lead);
  const midY = mixN(FAB.y + FAB.h / 2, SHEET.y + SHEET.h / 2, progress);
  const radius = Math.min(mixN(28, 26, openP), Math.min(width, height) / 2);
  const tint = 1 - smooth(progress, fillHold * 0.55, fillHold);
  const glow = sent ? Palette.green : Palette.indigo;

  return (
    <Column gap={10}>
      <div style={{ ...morphScreen(), background: Palette.surface }}>
        <motion.div initial={false} animate={{ scale: open ? ctx.n("recede") : 1 }} transition={spr} style={{ position: "absolute", inset: 0 }}>
          <Inbox L={L} />
        </motion.div>
        <motion.div
          initial={false}
          animate={{ opacity: open ? 0.28 : 0 }}
          transition={spr}
          onClick={() => close(false)}
          style={{ position: "absolute", inset: 0, background: "#000", pointerEvents: open ? "auto" : "none" }}
        />
        <div
          onClick={() => progress < 0.5 && present()}
          style={{
            position: "absolute",
            left: midX - width / 2,
            top: midY - height / 2,
            width,
            height,
            borderRadius: radius,
            overflow: "hidden",
            background: Palette.elevated,
            boxShadow: `0 8px 12px ${hex(glow, 0.38 * tint)}, 0 14px 24px ${black(0.24 * openP)}`,
            cursor: progress < 0.5 ? "pointer" : undefined,
          }}
        >
          <div
            style={{
              position: "absolute",
              left: (width - SHEET.w) / 2,
              top: 0,
              width: SHEET.w,
              height: SHEET.h,
              transform: `scale(${0.88 + 0.12 * openP})`,
              transformOrigin: "50% 0%",
              opacity: smooth(progress, fillHold * 0.7, fillHold + 0.3),
              pointerEvents: progress > 0.7 ? "auto" : "none",
            }}
          >
            <Sheet progress={progress} typed={typed} L={L} onClose={() => close(false)} onSend={() => close(true)} />
          </div>
          <div style={{ position: "absolute", inset: 0, opacity: tint, pointerEvents: "none" }}>
            <div style={{ position: "absolute", inset: 0, background: Palette.primary }} />
            <motion.div initial={false} animate={{ opacity: sent ? 1 : 0 }} transition={spring(0.35, 0.7)} style={{ position: "absolute", inset: 0, background: Palette.green }} />
          </div>
          <div
            style={{
              position: "absolute",
              inset: 0,
              display: "grid",
              placeItems: "center",
              color: "#fff",
              transform: `scale(${1 + 1.4 * openP})`,
              opacity: 1 - smooth(progress, 0, 0.28),
              pointerEvents: "none",
            }}
          >
            <motion.span key={sent ? "sent" : "pen"} initial={{ scale: 0.5, opacity: 0, filter: "blur(4px)" }} animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }} transition={spring(0.35, 0.7)} style={{ display: "grid" }}>
              {sent ? <Check size={24} strokeWidth={3} /> : <SquarePen size={23} strokeWidth={2.4} />}
            </motion.span>
          </div>
          <div style={{ position: "absolute", inset: 0, borderRadius: radius, boxShadow: `inset 0 0 0 1px ${white(0.28 * tint)}`, pointerEvents: "none" }} />
        </div>
      </div>
      <DemoHint ctx={ctx} en={open ? "Send, or close with ✕" : "Tap the compose button"} zh={open ? "点发送，或点 ✕ 关闭" : "点击写信按钮"} />
    </Column>
  );
}

function Sheet({ progress, typed, L, onClose, onSend }: { progress: number; typed: number; L: number; onClose: () => void; onSend: () => void }) {
  const zh = L === 1;
  const rise = (step: number) => ({ transform: `translateY(${(1 - smooth(progress, 0.55 + 0.07 * step, 0.85 + 0.07 * step)) * 14}px)` });
  const shown = [...bodyText[L]].slice(0, typed).join("");
  // The caret is part of the text run, so it always sits after the last glyph.
  const [on, setOn] = useState(true);
  useEffect(() => {
    const id = window.setInterval(() => setOn(Math.floor((Date.now() / 1000) * 2) % 2 === 0), 250);
    return () => window.clearInterval(id);
  }, []);
  const field = (label: string, step: number, content: React.ReactNode) => (
    <div style={rise(step)}>
      <div style={{ height: 38, display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ fontSize: 13, color: Palette.secondaryLabel }}>{label}</span>
        {content}
      </div>
      <div style={{ height: 1, background: Palette.stroke }} />
    </div>
  );
  return (
    <div style={{ position: "absolute", inset: 0, padding: 14, display: "flex", flexDirection: "column" }}>
      <div style={{ display: "flex", alignItems: "center", paddingBottom: 12, ...rise(0) }}>
        <button type="button" onClick={onClose} style={{ width: 32, height: 32, borderRadius: 16, background: Palette.labelAlpha(0.07), color: Palette.secondaryLabel, display: "grid", placeItems: "center" }}>
          <X size={15} strokeWidth={3.2} />
        </button>
        <span style={{ flex: 1, textAlign: "center", fontSize: 15, fontWeight: 600 }}>{zh ? "新邮件" : "New Message"}</span>
        <button type="button" onClick={onSend} style={{ width: 32, height: 32, borderRadius: 16, background: primaryStrong, color: "#fff", display: "grid", placeItems: "center" }}>
          <ArrowUp size={17} strokeWidth={3.2} />
        </button>
      </div>
      {field(
        zh ? "收件人" : "To",
        1,
        <div style={{ height: 24, padding: "0 9px 0 3px", borderRadius: 12, background: hex(Palette.indigo, 0.14), display: "flex", alignItems: "center", gap: 5 }}>
          <span style={{ width: 18, height: 18, borderRadius: 9, background: Palette.sunset }} />
          <span style={{ fontSize: 13, fontWeight: 500 }}>{zh ? "陈米娅" : "Mia Chen"}</span>
        </div>,
      )}
      {field(zh ? "主题" : "Subject", 2, <span style={{ fontSize: 14, fontWeight: 600 }}>{zh ? "周六去爬山" : "Saturday hike"}</span>)}
      <div style={{ paddingTop: 12, fontSize: 14, lineHeight: "20px", ...rise(3) }}>
        {shown}
        <span style={{ color: Palette.indigo, opacity: on ? 1 : 0 }}>|</span>
      </div>
      <span style={{ flex: 1 }} />
      <div style={{ display: "flex", alignItems: "center", gap: 18, color: Palette.secondaryLabel, ...rise(4) }}>
        <Paperclip size={17} strokeWidth={1.9} />
        <ImageIcon size={17} strokeWidth={1.9} />
        <Type size={17} strokeWidth={1.9} />
        <span style={{ flex: 1 }} />
        <span style={{ fontSize: 11 }}>{zh ? "草稿已保存" : "Draft saved"}</span>
      </div>
    </div>
  );
}

const senders: [string, string][] = [
  ["Mia Chen", "陈米娅"],
  ["Studio Weekly", "工作室周报"],
  ["Noah Kim", "金诺亚"],
  ["Orbit Travel", "轨道旅行"],
];
const subjects: [string, string][] = [
  ["Are we still on for Saturday?", "周六的计划还照常吗？"],
  ["Five things we shipped", "本周上线的五件事"],
  ["Photos from the ridge", "山脊上拍的照片"],
  ["Your itinerary is ready", "你的行程已生成"],
];
const tints = [Palette.coral, Palette.indigo, Palette.mint, Palette.amber];
const times = ["9:41", "8:15", "7:02", "6:30"];

function Inbox({ L }: { L: number }) {
  return (
    <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column" }}>
      <div style={{ height: 52, marginBottom: 8, padding: "0 16px", display: "flex", alignItems: "flex-end", fontSize: 24, lineHeight: "29px", fontWeight: 700 }}>{L ? "收件箱" : "Inbox"}</div>
      {[0, 1, 2, 3].map((index) => (
        <div key={index} style={{ position: "relative", height: 56, flexShrink: 0, padding: "0 16px", display: "flex", alignItems: "center", gap: 11 }}>
          <div style={{ width: 36, height: 36, flexShrink: 0, borderRadius: 18, background: vert(hex(tints[index], 0.7), tints[index]), color: "#fff", fontSize: 15, fontWeight: 700, display: "grid", placeItems: "center" }}>
            {[...senders[index][L]][0]}
          </div>
          <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 2 }}>
            <div style={{ display: "flex", alignItems: "center" }}>
              <span style={{ fontSize: 14, lineHeight: "17px", fontWeight: 600 }}>{senders[index][L]}</span>
              <span style={{ flex: 1 }} />
              <span style={{ fontSize: 11, color: Palette.secondaryLabel, fontVariantNumeric: "tabular-nums" }}>{times[index]}</span>
            </div>
            <span style={{ fontSize: 13, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{subjects[index][L]}</span>
          </div>
          <div style={{ position: "absolute", left: 63, right: 0, bottom: 0, height: 1, background: Palette.stroke }} />
        </div>
      ))}
    </div>
  );
}
