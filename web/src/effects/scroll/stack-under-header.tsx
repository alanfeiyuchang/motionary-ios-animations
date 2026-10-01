/** scroll.stack-under-header · 顶部叠放列表 (Scroll+StackUnderHeader.swift) */
import { Layers } from "lucide-react";
import { useRef } from "react";
import { NumericText, Palette, anim, black, clamp, glass, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { ScrollKitRow, brightness, useScroller } from "./_kit";
import { Ico, ScrollMath } from "./_motion";

const HEADER = 50;
const ROW = 66;
const PITCH = 76;
const COUNT = 16;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

export default function StackUnderHeader({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const down = useRef(false);
  const sc = useScroller({ axis: "y" });
  const offset = sc.offset;
  const step = ctx.n("scale");
  const peek = ctx.n("peek");
  const levels = Math.max(Math.round(ctx.n("depth")), 1);
  // The pin line leaves room above it for the slivers of the stacked cards.
  const pin = HEADER + 8 + peek * levels;
  const stacked = clamp(Math.ceil(offset / PITCH - 1e-6), 0, COUNT - 1);

  /** The chip's tap: back to the top, dealing the deck out again. */
  const dealOut = () => {
    if (!ctx.isPreview) haptics.tap("light");
    sc.scrollTo(0, anim.easeInOut(0.6));
  };
  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      if (down.current) sc.scrollTo(PITCH * 6, anim.easeInOut(2.0));
      else dealOut();
    },
    { every: 2.6 },
  );

  const lifted = ScrollMath.unit(offset, 0, 20);
  // The detail stage keeps its Reset button in the top-trailing corner.
  const trailingInset = ctx.isPreview ? 14 : 52;

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        <div ref={sc.contentRef} style={{ padding: `${pin}px 16px 16px`, display: "flex", flexDirection: "column", gap: PITCH - ROW }}>
          {Array.from({ length: COUNT }, (_, i) => {
            const over = pin - (pin + i * PITCH - offset);
            const depth = Math.max(over, 0) / PITCH;
            const shown = Math.min(depth, levels);
            return (
              <ScrollKitRow
                key={i}
                index={i + 2}
                lang={ctx.lang}
                style={{
                  height: ROW,
                  flexShrink: 0,
                  boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 3px 10px ${black(0.14)}`,
                  transformOrigin: "50% 0",
                  transform: `translateY(${Math.max(over, 0) - peek * shown}px) scale(${1 - step * shown})`,
                  filter: shown > 0.001 ? brightness(-0.015 * shown) : undefined,
                  opacity: 1 - ScrollMath.unit(depth, levels, levels + 0.8),
                }}
              />
            );
          })}
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 0,
          height: HEADER,
          padding: `0 ${trailingInset}px 0 16px`,
          display: "flex",
          alignItems: "center",
          gap: 8,
          ...glass("regular"),
          boxShadow: `inset 0 -0.5px 0 ${Palette.labelAlpha(0.1 * lifted)}`,
        }}
      >
        <div style={{ fontSize: 22, fontWeight: 700 }}>{ctx.t("Inbox", "收件箱")}</div>
        <div style={{ flex: 1 }} />
        <div
          onClick={dealOut}
          style={{
            position: "relative",
            height: 26,
            padding: "0 10px",
            borderRadius: 13,
            display: "flex",
            alignItems: "center",
            gap: 5,
            background: Palette.labelAlpha(0.08),
            color: stacked > 0 ? "#fff" : Palette.secondaryLabel,
            transition: "color 0.25s",
            fontSize: 12,
            cursor: "pointer",
            overflow: "hidden",
          }}
        >
          <div style={{ position: "absolute", inset: 0, background: PRIMARY_STRONG, opacity: stacked > 0 ? 1 : 0, transition: "opacity 0.25s" }} />
          <Ico icon={Layers} size={11} weight={700} fill style={{ position: "relative" }} />
          <NumericText value={stacked} style={{ position: "relative", fontWeight: 700 }} />
          <span style={{ position: "relative", fontWeight: 600, whiteSpace: "nowrap" }}>{ctx.t("stacked", "张已叠放")}</span>
        </div>
      </div>
    </div>
  );
}
