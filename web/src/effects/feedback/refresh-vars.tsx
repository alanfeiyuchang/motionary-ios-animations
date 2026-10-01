/** Shared host of the refresh variations (RefreshVarHost in Feedback+RefreshVariations.swift). */
import { Calendar, CreditCard, Heart, Plane, ShoppingCart, Sun, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { Palette, spring, useClock, type DemoContext } from "../../kit";
import { DividerRow, RefreshHost, type IndicatorProps } from "./refresh-host";

const ITEMS: { Icon: LucideIcon; fill: boolean; tint: string; title: [string, string]; detail: [string, string] }[] = [
  { Icon: Plane, fill: true, tint: Palette.sky, title: ["Flight MN 88 on time", "MN 88 航班准点"], detail: ["Gate B12 · boarding 9:40", "B12 登机口 · 9:40 登机"] },
  { Icon: ShoppingCart, fill: true, tint: Palette.coral, title: ["Order shipped", "订单已发货"], detail: ["Arrives Thursday", "预计周四送达"] },
  { Icon: Heart, fill: true, tint: Palette.pink, title: ["Mia liked your photo", "米娅赞了你的照片"], detail: ["2 min ago", "2 分钟前"] },
  { Icon: CreditCard, fill: false, tint: Palette.mint, title: ["Refund received", "退款已到账"], detail: ["$42.00 to card •• 4242", "¥298.00 至尾号 4242"] },
  { Icon: Calendar, fill: false, tint: Palette.violet, title: ["Design review moved", "设计评审已改期"], detail: ["Friday · 3:00 pm", "周五 · 下午 3:00"] },
  { Icon: Sun, fill: true, tint: Palette.amber, title: ["Clear skies today", "今日晴朗"], detail: ["High 24° · Low 15°", "最高 24° · 最低 15°"] },
];

export function RefreshVarHost({ ctx, indicator }: { ctx: DemoContext; indicator: (p: IndicatorProps) => ReactNode }) {
  const zh = ctx.lang === "zh";
  return (
    <RefreshHost
      ctx={ctx}
      threshold={80}
      holdHeight={70}
      height={260}
      rowCount={4}
      script={[0.6, 0.6, 16, 0.4, 0.45]}
      doneSpring={spring(0.5, 0.84)}
      insertion={{ initial: { y: -62 } }}
      indicator={indicator}
      renderRow={(item) => {
        const { Icon, fill, tint, title, detail } = ITEMS[item % ITEMS.length];
        return (
          <DividerRow height={62} inset={62} scheme={ctx.scheme}>
            <div style={{ width: 36, height: 36, flexShrink: 0, borderRadius: 10, background: `linear-gradient(rgb(255 255 255 / 0.14), transparent), ${tint}`, display: "grid", placeItems: "center", color: "#fff" }}>
              <Icon size={16} strokeWidth={fill ? 1.8 : 2.4} fill={fill ? "currentColor" : "none"} />
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
              <span style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{title[zh ? 1 : 0]}</span>
              <span style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{detail[zh ? 1 : 0]}</span>
            </div>
          </DividerRow>
        );
      }}
    />
  );
}

/** `RefreshVarSpinner`: a 72 % arc turning once per 0.8 s (absolute time). */
export function VarSpinner({ color, size = 26, fps }: { color: string; size?: number; fps?: number }) {
  const t = useClock(true, fps) + performance.timeOrigin / 1000;
  const r = size / 2 - 1.5;
  return (
    <svg width={size} height={size} style={{ transform: `rotate(${((t % 0.8) / 0.8) * 360}deg)` }}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={3} strokeLinecap="round" pathLength={1} strokeDasharray="0.72 2" />
    </svg>
  );
}
