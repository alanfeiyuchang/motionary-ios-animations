/** cards.book-open · 翻开书本 (Cards+BookOpen.swift) */
import { animate, useMotionValue } from "motion/react";
import { Sparkle } from "lucide-react";
import { useRef, type CSSProperties, type ReactNode } from "react";
import { DemoHint, black, clamp, hex, spring, useAutoplay, useHaptics, usePan, useTimeouts, white, type DemoContext, type DemoProps } from "../../kit";
import { Stage, StrokeBorder, diag, persp, useMV } from "./shared";

const PAGE = { w: 132, h: 184 };
const COVER = { w: 138, h: 194 };
const COVER_COLORS = ["#3A2E8C", "#1C1846"];
const GOLD = "linear-gradient(to bottom right, #F7E3A1, #C9A24B)";
const GOLD_FLAT = "#E4C679";
const PAPER = "#FBF8F1";
const INK = 0x2a2530;
const PAGE_RADIUS = "2px 7px 7px 2px";
const COVER_RADIUS = "4px 10px 10px 4px";
/** `design: .serif`: Chinese falls back to the system sans on iOS. */
const SERIF = `ui-serif, "New York", Georgia, "PingFang SC", system-ui, sans-serif`;
const goldText: CSSProperties = { background: GOLD, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" };

export default function BookOpen({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const progress = useMotionValue(0);
  const isOpen = useRef(false);
  const dragStart = useRef<number | null>(null);
  const dragged = useRef(false);
  const landing = useTimeouts();

  const settle = (open: boolean, muted: boolean) => {
    isOpen.current = open;
    const response = ctx.n("response");
    animate(progress, open ? 1 : 0, spring(response, 0.86));
    landing.clearAll();
    landing.after(response * 0.7, () => {
      if (!muted) haptics.tap(open ? "light" : "rigid");
    });
  };

  const toggle = (muted: boolean) => {
    if (dragStart.current !== null) return;
    haptics.tap("soft");
    settle(!isOpen.current, muted);
  };

  const pan = usePan(
    {
      onChange: ({ translation }) => {
        if (dragStart.current === null) {
          dragStart.current = progress.get();
          dragged.current = true;
          progress.stop();
          landing.clearAll();
        }
        progress.set(clamp(dragStart.current - translation.x / 150));
      },
      onEnd: ({ velocity }) => {
        if (dragStart.current === null) return;
        dragStart.current = null;
        progress.jump(progress.get());
        const flick = -(velocity.x * 0.25) / 150;
        settle(progress.get() + flick > 0.5, false);
      },
    },
    10,
  );

  useAutoplay(ctx.isPreview, () => toggle(true), { every: 2.6 });

  const p = clamp(useMV(progress));
  const pages = Math.max(ctx.i("pages"), 1);
  const perspective = ctx.n("perspective");
  const spineX = (-COVER.w / 2) * (1 - p);
  const zh = ctx.lang === "zh";

  return (
    <Stage gap={20}>
      <div
        {...pan}
        onPointerDown={(e) => {
          dragged.current = false;
          pan.onPointerDown(e);
        }}
        onClick={() => {
          if (!dragged.current) toggle(false);
        }}
        style={{ position: "relative", width: 300, height: 226, flexShrink: 0, touchAction: "pan-y", cursor: "pointer" }}
      >
        {/* back board */}
        <Centered w={COVER.w} h={COVER.h} x={spineX + COVER.w / 2}>
          <div style={{ width: COVER.w, height: COVER.h, borderRadius: COVER_RADIUS, background: `linear-gradient(${COVER_COLORS.join(", ")})`, boxShadow: `0 10px 14px ${black(0.28)}` }} />
        </Centered>
        {/* page block */}
        <Centered w={PAGE.w} h={PAGE.h} x={spineX + PAGE.w / 2}>
          {[0, 1, 2].map((k) => (
            <div
              key={k}
              style={{
                position: "absolute",
                left: (3 - k) * 1.2,
                top: (3 - k) * 0.8,
                width: PAGE.w,
                height: PAGE.h,
                borderRadius: PAGE_RADIUS,
                background: "#E9E3D6",
                boxShadow: `inset 0 0 0 0.5px ${black(0.1)}`,
              }}
            />
          ))}
          <div style={{ position: "absolute", inset: 0, borderRadius: PAGE_RADIUS, overflow: "hidden", background: PAPER }}>
            <FirstPage reveal={p} ctx={ctx} />
            <div style={{ position: "absolute", inset: 0, background: `linear-gradient(to right, ${black(0.34 * Math.sin(p * Math.PI))}, transparent)`, pointerEvents: "none" }} />
            <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: 20, background: `linear-gradient(to right, ${black(0.16 * p)}, transparent)`, pointerEvents: "none" }} />
          </div>
        </Centered>
        {Array.from({ length: pages + 1 }, (_, index) => {
          const lag = 0.09;
          const span = 1 - lag * pages;
          const local = clamp((p - lag * index) / span);
          const angle = local * (179 - index * 1.2);
          const flipped = angle > 90;
          const edgeOn = Math.sin((angle * Math.PI) / 180);
          const size = index === 0 ? COVER : PAGE;
          return (
            <Centered key={index} w={size.w} h={size.h} x={spineX + size.w / 2} z={flipped ? 20 + index : 10 - index}>
              <div style={{ width: size.w, height: size.h, transformOrigin: "0 50%", transform: `${persp(size.w, size.h, perspective)} rotateY(${-angle}deg)` }}>
                <LeafFace index={index} isLast={index === pages} flipped={flipped} edgeOn={edgeOn} zh={zh} />
              </div>
            </Centered>
          );
        })}
      </div>
      <DemoHint ctx={ctx} en="Tap the book, or drag the cover" zh="点击书本，或拖动封面" />
    </Stage>
  );
}

function Centered({ w, h, x, z, children }: { w: number; h: number; x: number; z?: number; children: ReactNode }) {
  return <div style={{ position: "absolute", left: 150 - w / 2 + x, top: 113 - h / 2, width: w, height: h, zIndex: z }}>{children}</div>;
}

function LeafFace({ index, isLast, flipped, edgeOn, zh }: { index: number; isLast: boolean; flipped: boolean; edgeOn: number; zh: boolean }) {
  const fill: CSSProperties = { position: "absolute", inset: 0 };
  if (index === 0) {
    if (flipped) {
      return (
        <div style={{ ...fill, borderRadius: COVER_RADIUS, overflow: "hidden", background: diag(COVER_COLORS), transform: "scaleX(-1)" }}>
          <div style={{ position: "absolute", inset: 4, borderRadius: 5, overflow: "hidden", background: "#EFE6D2", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 13 }}>
            {Array.from({ length: 8 }, (_, row) => (
              <div key={row} style={{ display: "flex", gap: 13, flexShrink: 0 }}>
                {Array.from({ length: 6 }, (_, column) => (
                  <Sparkle key={column} size={9} fill="currentColor" strokeWidth={1} style={{ flexShrink: 0, color: hex(0xb8894a, (row + column) % 2 === 0 ? 0.5 : 0.22) }} />
                ))}
              </div>
            ))}
          </div>
          <div style={{ ...fill, background: black(0.3 * edgeOn) }} />
        </div>
      );
    }
    return (
      <div style={{ ...fill, borderRadius: COVER_RADIUS, overflow: "hidden", background: diag(COVER_COLORS), isolation: "isolate" }}>
        <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: 11, background: `linear-gradient(to right, ${black(0.35)}, ${black(0.05)})` }} />
        <div style={{ position: "absolute", left: 11, top: 0, bottom: 0, width: 1, background: white(0.12) }} />
        <div style={{ position: "absolute", left: 22, right: 11, top: 11, bottom: 11, opacity: 0.85 }}>
          <StrokeBorder radius={5} color={GOLD} />
        </div>
        <div style={{ ...fill, paddingLeft: 12, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 10 }}>
          <Sparkle size={21} fill="currentColor" strokeWidth={1.5} style={{ color: GOLD_FLAT }} />
          <span style={{ ...goldText, fontFamily: SERIF, fontSize: 19, lineHeight: "23px", fontWeight: 700, letterSpacing: zh ? 8 : 3, whiteSpace: "nowrap" }}>{zh ? "动效" : "MOTION"}</span>
          <div style={{ width: 28, height: 1, background: GOLD }} />
          <span style={{ ...goldText, fontFamily: SERIF, fontSize: 10.5, lineHeight: "13px", fontWeight: 500, letterSpacing: 1, whiteSpace: "nowrap" }}>{zh ? "设计手记" : "A Field Guide"}</span>
        </div>
        <div style={{ ...fill, background: `linear-gradient(to bottom right, transparent, ${white(0.5 * edgeOn)}, transparent)`, mixBlendMode: "plus-lighter" }} />
        <div style={{ ...fill, background: black(0.32 * edgeOn) }} />
      </div>
    );
  }
  return (
    <div style={{ ...fill, borderRadius: PAGE_RADIUS, overflow: "hidden", background: PAPER, transform: flipped ? "scaleX(-1)" : undefined, boxShadow: `inset 0 0 0 0.5px ${black(0.08)}` }}>
      {flipped && (
        <>
          {isLast && (
            <div style={{ ...fill, padding: "0 18px", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 8, color: hex(INK, 0.75) }}>
              <span style={{ fontFamily: SERIF, fontSize: 11, lineHeight: "14px", fontStyle: zh ? "normal" : "italic", textAlign: "center" }}>{zh ? "「没有无缘无故的运动。」" : "“Nothing moves without a reason.”"}</span>
              <div style={{ width: 18, height: 0.8, background: "currentColor", opacity: 0.5 }} />
            </div>
          )}
          <div style={{ position: "absolute", right: 0, top: 0, bottom: 0, width: 20, background: `linear-gradient(to right, transparent, ${black(0.14)})` }} />
        </>
      )}
      <div style={{ ...fill, background: black(0.26 * edgeOn) }} />
      <div style={{ ...fill, borderRadius: PAGE_RADIUS, boxShadow: `inset 0 0 0 0.5px ${black(0.08)}` }} />
    </div>
  );
}

/** The first right-hand page; its blocks rise and fade in one after another as the book opens. */
function FirstPage({ reveal, ctx }: { reveal: number; ctx: DemoContext }) {
  const stage = (start: number) => clamp((reveal - start) / 0.3);
  const rise = (amount: number): CSSProperties => ({ opacity: amount, transform: `translateY(${(1 - amount) * 10}px)` });
  const zh = ctx.lang === "zh";
  return (
    <div style={{ position: "absolute", inset: 0, padding: "16px 14px 16px 18px", display: "flex", flexDirection: "column", alignItems: "flex-start" }}>
      <span style={{ fontFamily: SERIF, fontSize: 8.5, lineHeight: "11px", fontWeight: 600, letterSpacing: 1.6, color: "#B8894A", ...rise(stage(0.42)) }}>{zh ? "第一章" : "CHAPTER ONE"}</span>
      <span style={{ fontFamily: SERIF, fontSize: 22, lineHeight: "27px", fontWeight: 700, color: hex(INK), marginTop: 5, ...rise(stage(0.52)) }}>{zh ? "缓动" : "Easing"}</span>
      <div style={{ alignSelf: "stretch", marginTop: 14, display: "flex", flexDirection: "column", gap: 8, ...rise(stage(0.62)) }}>
        {Array.from({ length: 6 }, (_, i) => (
          <div key={i} style={{ height: 10, borderRadius: 5, background: hex(INK, 0.16), maxWidth: i === 5 ? 120 : undefined }} />
        ))}
      </div>
      <span style={{ flex: 1 }} />
      <span style={{ alignSelf: "center", fontFamily: SERIF, fontSize: 9, lineHeight: "11px", fontWeight: 500, color: hex(INK, 0.5), ...rise(stage(0.62)) }}>1</span>
    </div>
  );
}
