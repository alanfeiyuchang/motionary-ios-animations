/** scroll.riding-avatar · 头像随行的群聊 (Scroll+RidingAvatar.swift) */
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Palette, alpha, anim, black, clamp, elementScale, fonts, glass, useAutoplay, useTimeouts, type DemoProps, type Lang } from "../../kit";
import { useScroller } from "./_kit";

interface Run {
  /** 0 is the user; 1…3 are the other members. */
  sender: number;
  lines: [string, string][];
}
const MEMBERS: { name: [string, string]; initial: [string, string]; colors: [string, string] }[] = [
  { name: ["You", "我"], initial: ["Y", "我"], colors: [Palette.blue, Palette.indigo] },
  { name: ["Noor", "小诺"], initial: ["N", "诺"], colors: [Palette.coral, Palette.pink] },
  { name: ["Idris", "阿迪"], initial: ["I", "迪"], colors: [Palette.mint, Palette.sky] },
  { name: ["June", "六月"], initial: ["J", "六"], colors: [Palette.amber, Palette.coral] },
];
const DAYS: { label: [string, string]; runs: Run[] }[] = [
  { label: ["Monday", "周一"], runs: [
    { sender: 1, lines: [["Did anyone look at the build?", "有人看过新版本了吗？"], ["The list feels different", "列表的手感变了"], ["In a good way I think", "我觉得是变好了"]] },
    { sender: 0, lines: [["That's the new spring", "那是新调的弹簧"], ["Damping went from 0.9 to 0.78", "阻尼从 0.9 改到了 0.78"]] },
    { sender: 2, lines: [["I can tell", "感觉得出来"], ["It settles a touch later but it feels alive", "停得稍微晚一点，但是活了"]] },
  ] },
  { label: ["Yesterday", "昨天"], runs: [
    { sender: 3, lines: [["Quick one", "问个小问题"], ["Should the date chip stay visible?", "日期标签要一直显示吗？"], ["It covers the first message", "它会挡住第一条消息"], ["Maybe hide it when idle", "不如停下来就藏起来"]] },
    { sender: 0, lines: [["Hide after a beat", "停一拍再藏"], ["Bring it back on touch", "一碰就回来"]] },
    { sender: 1, lines: [["Yes please", "就这么办"], ["And keep my avatar next to my wall of text", "还有，让头像陪着我那一大串字"]] },
    { sender: 0, lines: [["Already riding along", "已经在跟着走了"]] },
  ] },
  { label: ["Today", "今天"], runs: [
    { sender: 2, lines: [["Shipping at four?", "四点发版？"], ["I still need to check dark mode", "我还得看一眼深色模式"], ["And the long names", "还有那些很长的名字"]] },
    { sender: 3, lines: [["Dark mode is clean", "深色模式没问题"], ["I went through every screen", "每个界面我都过了一遍"]] },
    { sender: 0, lines: [["Then four it is", "那就四点"], ["Thanks, all of you", "辛苦各位"]] },
    { sender: 1, lines: [["See you at the launch", "发布会见"]] },
  ] },
];
const CHIP = 32;
const AVATAR = 30;

/** Bubbles of one run are joined on the sender's side by tight corners; the last keeps a small tail corner. */
function bubbleRadius(index: number, count: number, mine: boolean) {
  const big = 17;
  const tight = 6;
  const top = index === 0 ? big : tight;
  const bottom = index === count - 1 ? 4 : tight;
  // top-left, top-right, bottom-right, bottom-left
  return mine ? `${big}px ${top}px ${bottom}px ${big}px` : `${top}px ${big}px ${big}px ${bottom}px`;
}

export default function RidingAvatar({ ctx }: DemoProps) {
  const { after } = useTimeouts();
  const ride = ctx.b("ride");
  const hue = ctx.n("hue");
  const delay = ctx.n("delay");
  /** True once the list has been still for the delay: pinned day chips fade out. */
  const [chipsHidden, setChipsHidden] = useState(false);
  const hideToken = useRef(0);
  const down = useRef(false);

  const phaseChanged = (idle: boolean) => {
    const token = ++hideToken.current;
    if (!idle) {
      setChipsHidden(false);
      return;
    }
    after(delay, () => {
      if (token === hideToken.current) setChipsHidden(true);
    });
  };
  const sc = useScroller({ axis: "y", onPhase: (p) => phaseChanged(p === "idle") });
  useEffect(() => {
    phaseChanged(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useAutoplay(
    ctx.isPreview,
    () => {
      down.current = !down.current;
      sc.scrollTo(down.current ? 560 : 0, anim.easeInOut(2.0));
    },
    { every: 2.6 },
  );

  // Content positions of the days (for the pinned-chip test) and of the outgoing bubbles (for their hue).
  const days = useRef<(HTMLDivElement | null)[]>([]);
  const mine = useRef<Record<string, HTMLDivElement | null>>({});
  const [layout, setLayout] = useState<{ days: { top: number; height: number }[]; mine: Record<string, number> }>({ days: [], mine: {} });
  useLayoutEffect(() => {
    const content = sc.contentRef.current;
    if (!content) return;
    const measure = () => {
      const base = content.getBoundingClientRect();
      const scale = elementScale(content) || 1;
      const mids: Record<string, number> = {};
      for (const [key, el] of Object.entries(mine.current)) {
        if (!el) continue;
        const r = el.getBoundingClientRect();
        mids[key] = (r.top + r.height / 2 - base.top) / scale;
      }
      setLayout({ days: days.current.map((d) => (d ? { top: d.offsetTop, height: d.offsetHeight } : { top: 0, height: 0 })), mine: mids });
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(content);
    void document.fonts?.ready.then(measure);
    return () => observer.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ctx.lang]);

  const viewport = Math.max(sc.size.height || (ctx.isPreview ? 340 : 400), 1);
  const offset = sc.offset;

  return (
    <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
      <div ref={sc.contentRef} style={{ position: "relative", padding: "6px 12px 14px", display: "flex", flexDirection: "column", gap: 10 }}>
        {DAYS.map((day, d) => {
          const m = layout.days[d];
          const shift = m ? clamp(2 - (m.top - offset), 0, Math.max(m.height - CHIP, 0)) : 0;
          // Only a chip that is actually pinned hides; one sitting in the flow stays.
          const hidden = shift > 0.5 && chipsHidden;
          return (
            <div
              key={d}
              ref={(el) => {
                days.current[d] = el;
              }}
              style={{ position: "relative", display: "flex", flexDirection: "column", gap: 10 }}
            >
              {/* The chip sticks to the top edge while any of the day is on screen and is carried off by the day's last message. */}
              <div style={{ position: "sticky", top: 2, zIndex: 3, height: CHIP, display: "grid", placeItems: "center", pointerEvents: "none", flexShrink: 0 }}>
                <div
                  style={{
                    padding: "5px 11px",
                    borderRadius: 999,
                    fontSize: 12,
                    lineHeight: "16px",
                    fontWeight: 600,
                    color: Palette.secondaryLabel,
                    ...glass("regular"),
                    boxShadow: `inset 0 0 0 1px ${Palette.stroke}, 0 2px 7px ${black(0.08)}`,
                    opacity: hidden ? 0 : 1,
                    transition: hidden ? "opacity 0.3s ease-out" : "opacity 0.12s ease-out",
                  }}
                >
                  {day.label[ctx.lang === "zh" ? 1 : 0]}
                </div>
              </div>
              {day.runs.map((run, r) =>
                run.sender === 0 ? (
                  <div key={r} style={{ display: "flex", flexDirection: "column", alignItems: "flex-end", gap: 3, paddingLeft: 54 }}>
                    {run.lines.map((line, i) => {
                      const key = `${d}-${r}-${i}`;
                      const mid = layout.mine[key];
                      const t = mid === undefined ? 0 : clamp((mid - offset) / viewport, 0, 1);
                      return (
                        <div
                          key={i}
                          ref={(el) => {
                            mine.current[key] = el;
                          }}
                          style={{
                            padding: "7px 12px",
                            fontSize: 15,
                            lineHeight: "20px",
                            color: "#fff",
                            background: `linear-gradient(${MEMBERS[0].colors[0]}, ${MEMBERS[0].colors[1]})`,
                            borderRadius: bubbleRadius(i, run.lines.length, true),
                            // Outgoing bubbles take their colour from where they are on screen.
                            filter: `hue-rotate(${t * hue}deg)`,
                          }}
                        >
                          {line[ctx.lang === "zh" ? 1 : 0]}
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <Incoming key={r} run={run} ride={ride} lang={ctx.lang} />
                ),
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function Incoming({ run, ride, lang }: { run: Run; ride: boolean; lang: Lang }) {
  const member = MEMBERS[run.sender];
  const zh = lang === "zh";
  return (
    <div style={{ position: "relative", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 3, paddingLeft: AVATAR + 8, paddingRight: 40 }}>
      {/* A column exactly as tall as the run; the avatar sits at its bottom and rides 10 pt above the viewport's bottom edge. */}
      <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: AVATAR, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}>
        <div
          style={{
            position: ride ? "sticky" : "static",
            bottom: 10,
            width: AVATAR,
            height: AVATAR,
            borderRadius: "50%",
            background: `linear-gradient(135deg, ${member.colors[0]}, ${member.colors[1]})`,
            boxShadow: `0 2px 7px ${alpha(member.colors[0], 0.35)}`,
            display: "grid",
            placeItems: "center",
            color: "#fff",
            fontFamily: fonts.rounded,
            fontSize: 13,
            fontWeight: 700,
          }}
        >
          {member.initial[zh ? 1 : 0]}
        </div>
      </div>
      <div style={{ fontSize: 11, lineHeight: "13px", fontWeight: 600, color: member.colors[0], paddingLeft: 12 }}>{member.name[zh ? 1 : 0]}</div>
      {run.lines.map((line, i) => (
        <div
          key={i}
          style={{
            padding: "7px 12px",
            fontSize: 15,
            lineHeight: "20px",
            background: Palette.elevated,
            boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
            borderRadius: bubbleRadius(i, run.lines.length, false),
          }}
        >
          {line[zh ? 1 : 0]}
        </div>
      ))}
    </div>
  );
}
