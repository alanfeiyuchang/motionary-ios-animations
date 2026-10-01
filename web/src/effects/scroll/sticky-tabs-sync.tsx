/** scroll.sticky-tabs-sync · 滚动联动分区标签 (Scroll+StickyTabsSync.swift) */
import { useEffect, useLayoutEffect, useRef, useState } from "react";
import { Palette, alpha, anim, black, clamp, glass, spring, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { ScrollKitIcon, useScroller } from "./_kit";
import { ScrollMath, useSpringValue } from "./_motion";

type Item = [en: string, zh: string, noteEn: string, noteZh: string, price: string];
const SECTIONS: { title: [string, string]; items: Item[] }[] = [
  { title: ["Popular", "人气"], items: [
    ["Charred leek toast", "炭烤韭葱吐司", "Whipped ricotta, lemon", "打发乳清奶酪、柠檬", "9"],
    ["Miso butter noodles", "味噌黄油拌面", "Scallion, sesame", "葱花、芝麻", "14"],
    ["Burnt honey flan", "焦蜜布丁", "Sea salt", "海盐", "8"],
  ] },
  { title: ["Starters", "前菜"], items: [
    ["Citrus cured trout", "柑橘腌鳟鱼", "Fennel, dill oil", "茴香、莳萝油", "12"],
    ["Roasted beet salad", "烤甜菜沙拉", "Goat cheese, walnut", "山羊奶酪、核桃", "10"],
    ["Crispy rice cakes", "脆米饼", "Chili crisp", "香辣脆", "8"],
  ] },
  { title: ["Mains", "主菜"], items: [
    ["Braised short rib", "红酒炖牛小排", "Parsnip purée", "欧防风泥", "26"],
    ["Grilled sea bream", "炭烤鲷鱼", "Salsa verde", "青酱", "24"],
    ["Wild mushroom risotto", "野菌烩饭", "Aged parmesan", "陈年帕玛森", "19"],
    ["Harissa chicken", "哈里萨烤鸡", "Yogurt, mint", "酸奶、薄荷", "21"],
  ] },
  { title: ["Sides", "配菜"], items: [
    ["Smashed potatoes", "压碎烤土豆", "Garlic, rosemary", "蒜、迷迭香", "7"],
    ["Blistered greens", "炝炒时蔬", "Brown butter", "焦化黄油", "7"],
    ["Sourdough basket", "酸种面包篮", "Cultured butter", "发酵黄油", "5"],
  ] },
  { title: ["Desserts", "甜点"], items: [
    ["Dark chocolate tart", "黑巧克力挞", "Crème fraîche", "法式酸奶油", "9"],
    ["Poached pear", "炖梨", "Vanilla, almond", "香草、杏仁", "8"],
    ["Olive oil gelato", "橄榄油冰淇淋", "Two scoops", "两球", "6"],
  ] },
  { title: ["Drinks", "饮品"], items: [
    ["Yuzu spritz", "柚子气泡酒", "Low alcohol", "低酒精", "9"],
    ["Cold brew tonic", "冷萃汤力", "Orange peel", "橙皮", "6"],
    ["Jasmine pearl tea", "茉莉龙珠", "Pot for two", "两人份一壶", "7"],
    ["Sparkling water", "气泡水", "750 ml", "750 毫升", "4"],
  ] },
];
const HEADER = 40;
const ROW = 62;
const BAR = 48;
const PRIMARY_STRONG = "linear-gradient(135deg, #4B57E0, #7A45D6)";

/** Scroll offset at which each section's header docks under the bar. */
const STARTS = (() => {
  let y = 0;
  return SECTIONS.map((s) => {
    const start = y;
    y += HEADER + s.items.length * ROW;
    return start;
  });
})();

interface Rect {
  x: number;
  w: number;
}

export default function StickyTabsSync({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  const zh = ctx.lang === "zh";
  const lead = Math.max(ctx.n("lead"), 1);
  const underline = ctx.i("style") === 1;
  /** Tab frames inside the strip's content. */
  const tabs = useRef<(HTMLDivElement | null)[]>([]);
  const [frames, setFrames] = useState<Rect[]>([]);
  /** Set by a tap: the pill stays on this tab while the list travels there. */
  const [locked, setLockedState] = useState<number | null>(null);
  const lockedRef = useRef<number | null>(null);
  const lockToken = useRef(0);
  /** 0 → 1 as the pill springs from where it was onto the locked tab. */
  const lockAmount = useSpringValue(1);
  const lockFrom = useRef<{ rect: Rect | null; weights: number[] }>({ rect: null, weights: [] });
  const highlighted = useRef(0);
  const step = useRef(0);
  /** Set while autoplay drives the list, so scripted tab changes stay silent. */
  const scripted = useRef(false);
  const setLocked = (v: number | null) => {
    lockedRef.current = v;
    setLockedState(v);
  };

  const sc = useScroller({
    axis: "y",
    onPhase: (p) => {
      // A finger on the list takes over from a tap's scroll.
      if (p !== "interacting") return;
      scripted.current = false;
      if (lockedRef.current !== null) setLocked(null);
    },
  });
  const strip = useScroller({ axis: "x" });
  const offset = sc.offset;

  useLayoutEffect(() => {
    const measure = () => setFrames(tabs.current.map((t) => (t ? { x: t.offsetLeft, w: t.offsetWidth } : { x: 0, w: 0 })));
    measure();
    void document.fonts?.ready.then(measure);
  }, [zh]);

  /** The section under the bar and how far the hand-off to the next one has progressed. */
  let index = 0;
  STARTS.forEach((start, i) => {
    if (start <= offset + 0.5) index = i;
  });
  const handoff = index + 1 < STARTS.length ? ScrollMath.unit(offset, STARTS[index + 1] - lead, STARTS[index + 1]) : 0;

  const scrubWeight = (i: number) => (i === index ? 1 - handoff : i === index + 1 ? handoff : 0);
  /** Leading and trailing edges travel on different curves, so the pill stretches across the gap. */
  const scrubRect = (): Rect | null => {
    const from = frames[index];
    if (!from) return null;
    const to = frames[index + 1];
    if (!(handoff > 0) || !to) return from;
    const t = handoff;
    const trailing = ScrollMath.lerp(from.x + from.w, to.x + to.w, 1 - (1 - t) * (1 - t));
    const leading = ScrollMath.lerp(from.x, to.x, t * t);
    return { x: leading, w: Math.max(trailing - leading, 8) };
  };

  const k = lockAmount.value;
  let rect = scrubRect();
  let weight = scrubWeight;
  if (locked !== null && frames[locked]) {
    const from = lockFrom.current.rect ?? frames[locked];
    const to = frames[locked];
    const a = from.x + (to.x - from.x) * k;
    const b = from.x + from.w + (to.x + to.w - from.x - from.w) * k;
    rect = { x: a, w: Math.max(b - a, 8) };
    const kk = clamp(k, 0, 1);
    weight = (i: number) => (lockFrom.current.weights[i] ?? 0) * (1 - kk) + (i === locked ? kk : 0);
  }
  const current = { rect, weights: SECTIONS.map((_, i) => weight(i)) };
  const currentRef = useRef(current);
  currentRef.current = current;

  // The tab that counts as current (for centring the strip and the haptic).
  const nearest = locked ?? (handoff > 0.5 ? index + 1 : index);
  useEffect(() => {
    if (nearest === highlighted.current) return;
    highlighted.current = nearest;
    if (!ctx.isPreview && lockedRef.current === null && !scripted.current) haptics.selection();
    const f = frames[nearest];
    if (f) strip.scrollTo(f.x + f.w / 2 - strip.viewport() / 2, anim.smoothD(0.35));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nearest]);

  /** A tab tap (and the autoplay's simulated tap): lock the pill onto the tab and travel there. */
  const select = (i: number, haptic: boolean) => {
    if (haptic) {
      scripted.current = false;
      haptics.selection();
    }
    const duration = ctx.n("duration");
    const token = ++lockToken.current;
    lockFrom.current = { rect: currentRef.current.rect, weights: currentRef.current.weights };
    lockAmount.to(0, null);
    lockAmount.to(1, spring(0.4, 0.78));
    setLocked(i);
    sc.scrollTo(STARTS[i], anim.easeInOut(duration));
    after(duration + 0.12, () => {
      // The list now rests on the section, so the scrubbed pill is where the locked one was.
      if (token === lockToken.current) setLocked(null);
    });
  };

  useAutoplay(
    ctx.isPreview,
    () => {
      scripted.current = true;
      switch (step.current % 4) {
        case 0:
          // A plain scroll: the pill is scrubbed through three hand-offs.
          setLocked(null);
          sc.scrollTo(STARTS[3] + 30, anim.easeInOut(1.6));
          break;
        case 1: select(5, false); break;
        case 2: select(1, false); break;
        default: select(0, false);
      }
      step.current += 1;
    },
    { every: 1.9 },
  );

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      <div {...sc.props} style={{ ...sc.props.style, position: "absolute", inset: 0 }}>
        {/* Bottom padding: room for the last section's header to reach the bar. */}
        <div ref={sc.contentRef} style={{ padding: `${BAR}px 14px 70px` }}>
          {SECTIONS.map((section, s) => (
            <div key={s}>
              <div style={{ height: HEADER, paddingTop: 10, display: "flex", alignItems: "baseline", gap: 6 }}>
                <span style={{ fontSize: 19, lineHeight: "23px", fontWeight: 700 }}>{section.title[zh ? 1 : 0]}</span>
                <span style={{ fontSize: 13, fontWeight: 600, fontVariantNumeric: "tabular-nums", color: Palette.tertiaryLabel }}>{section.items.length}</span>
              </div>
              {section.items.map((item, r) => (
                <div key={r} style={{ height: ROW }}>
                  <div
                    style={{
                      height: ROW - 6,
                      padding: "0 10px",
                      display: "flex",
                      alignItems: "center",
                      gap: 12,
                      borderRadius: 16,
                      background: Palette.elevated,
                      boxShadow: `inset 0 0 0 1px ${Palette.stroke}`,
                    }}
                  >
                    <ScrollKitIcon index={s * 3 + r} size={40} />
                    <div style={{ display: "flex", flexDirection: "column", gap: 2, minWidth: 0 }}>
                      <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, whiteSpace: "nowrap" }}>{item[zh ? 1 : 0]}</div>
                      <div style={{ fontSize: 12, lineHeight: "16px", color: Palette.secondaryLabel, whiteSpace: "nowrap" }}>{item[zh ? 3 : 2]}</div>
                    </div>
                    <div style={{ flex: 1 }} />
                    <div style={{ fontSize: 15, lineHeight: "20px", fontWeight: 600, fontVariantNumeric: "tabular-nums", color: Palette.secondaryLabel }}>${item[4]}</div>
                  </div>
                </div>
              ))}
            </div>
          ))}
        </div>
      </div>
      {/* Bar */}
      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: 0,
          height: BAR,
          ...glass("regular"),
          boxShadow: `inset 0 -0.5px 0 ${Palette.labelAlpha(0.1)}, 0 4px 12px ${black(0.12 * ScrollMath.unit(offset, 0, 24))}`,
        }}
      >
        <div {...strip.props} style={{ ...strip.props.style, position: "absolute", inset: 0 }}>
          {/* The detail stage keeps its Reset button in the top-trailing corner. */}
          <div ref={strip.contentRef} style={{ position: "relative", width: "max-content", height: BAR, paddingRight: ctx.isPreview ? 0 : 40 }}>
            <div style={{ position: "relative", height: BAR, padding: "0 12px", display: "flex", alignItems: "center", gap: 4 }}>
              {rect &&
                (underline ? (
                  <div style={{ position: "absolute", left: rect.x + 10, top: BAR - 6, width: Math.max(rect.w - 20, 8), height: 3, borderRadius: 1.5, background: Palette.primary }} />
                ) : (
                  <div
                    style={{
                      position: "absolute",
                      left: rect.x,
                      top: (BAR - 32) / 2,
                      width: rect.w,
                      height: 32,
                      borderRadius: 16,
                      background: PRIMARY_STRONG,
                      boxShadow: `0 3px 9px ${alpha(Palette.indigo, 0.35)}`,
                    }}
                  />
                ))}
              {SECTIONS.map((section, i) => {
                const w = clamp(weight(i), 0, 1);
                const title = section.title[zh ? 1 : 0];
                return (
                  <div
                    key={i}
                    ref={(el) => {
                      tabs.current[i] = el;
                    }}
                    onClick={() => select(i, true)}
                    style={{ position: "relative", height: 32, padding: "0 13px", display: "flex", alignItems: "center", fontSize: 15, fontWeight: 600, whiteSpace: "nowrap", cursor: "pointer", flexShrink: 0 }}
                  >
                    <span style={{ color: Palette.secondaryLabel, opacity: 1 - w }}>{title}</span>
                    <span style={{ position: "absolute", left: 13, color: underline ? Palette.label : "#fff", opacity: w }}>{title}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
