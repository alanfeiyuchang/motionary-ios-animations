/** Shared pieces of the round-2 Feedback demos (FeedbackSceneKit.swift). */
import { MoreHorizontal } from "lucide-react";
import type { CSSProperties, ReactNode } from "react";
import { Palette, demoCard } from "../../kit";

/** SwiftUI's `Color.gradient`: the colour, slightly lighter at the top. */
export const gradientOf = (color: string) => `linear-gradient(color-mix(in srgb, ${color}, white 17%), ${color})`;

/** `FeedbackCheckShape` as an SVG path for a `width` × `height` box (stroke it with round cap/join). */
export const checkPath = (width: number, height: number) =>
  `M${width * 0.04} ${height * 0.55} L${width * 0.37} ${height - height * 0.04} L${width - width * 0.03} ${height * 0.06}`;

const ROW_WIDTHS = [132, 96, 150, 112, 124];
const ROW_TINTS = [Palette.sky, Palette.coral, Palette.violet, Palette.amber, Palette.mint];

/** `FeedbackMockRows`: placeholder list rows (a tinted tile and two lines). */
export function FeedbackMockRows({ count = 4, rowHeight = 50, tints = ROW_TINTS, style }: { count?: number; rowHeight?: number; tints?: string[]; style?: CSSProperties }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignSelf: "stretch", flexShrink: 0, ...style }}>
      {Array.from({ length: count }, (_, index) => (
        <div key={index} style={{ display: "flex", alignItems: "center", gap: 12, padding: "0 16px", height: rowHeight, flexShrink: 0 }}>
          <div style={{ width: 32, height: 32, borderRadius: 9, background: gradientOf(tints[index % tints.length]), flexShrink: 0 }} />
          <div style={{ display: "flex", flexDirection: "column", gap: 6, alignItems: "flex-start" }}>
            <div style={{ width: ROW_WIDTHS[index % ROW_WIDTHS.length], height: 8, borderRadius: 4, background: Palette.labelAlpha(0.18) }} />
            <div style={{ width: ROW_WIDTHS[(index + 2) % ROW_WIDTHS.length] * 0.72, height: 7, borderRadius: 3.5, background: Palette.labelAlpha(0.09) }} />
          </div>
        </div>
      ))}
    </div>
  );
}

/** `FeedbackMockHeader`: a page title bar (`.headline` title, a 30 pt round symbol button). */
export function FeedbackMockHeader({ title, symbol }: { title: string; symbol?: ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", padding: "0 16px", height: 52, alignSelf: "stretch", flexShrink: 0 }}>
      <span style={{ fontSize: 17, lineHeight: "22px", fontWeight: 600, whiteSpace: "nowrap" }}>{title}</span>
      <div style={{ flex: 1 }} />
      <div style={{ width: 30, height: 30, borderRadius: 15, background: Palette.labelAlpha(0.07), color: Palette.secondaryLabel, display: "grid", placeItems: "center", flexShrink: 0 }}>
        {symbol ?? <MoreHorizontal size={17} strokeWidth={2.6} />}
      </div>
    </div>
  );
}

/**
 * `.feedbackScene(width:height:cornerRadius:)`: the clipped, elevated card the demos stage their scene
 * in. The outer box carries the card's hairline and shadow, the inner one clips the content.
 */
export function FeedbackScene({ width = 300, height = 270, cornerRadius = 26, children, style, innerStyle }: { width?: number; height?: number; cornerRadius?: number; children?: ReactNode; style?: CSSProperties; innerStyle?: CSSProperties }) {
  return (
    <div style={{ ...demoCard(cornerRadius), position: "relative", width, height, flexShrink: 0, ...style }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: cornerRadius, overflow: "hidden", ...innerStyle }}>{children}</div>
      <div style={{ position: "absolute", inset: 0, borderRadius: cornerRadius, boxShadow: `inset 0 0 0 1px ${Palette.stroke}`, pointerEvents: "none" }} />
    </div>
  );
}
