/** icons.live-waveform · 实时波形 (Icons+LiveWaveform.swift) */
import { useRef } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, useHaptics, useTimeouts, type DemoProps } from "../../kit";
import { Replace } from "./_icons-kit";
import { IC, Stage, usePhase, useIconNow, usePlayhead } from "./_time-kit";

const PAUSE = 0.95;
const RESUME = 0.8;
const BAR_W = 14;
const MAX_H = 132;
const LINE_H = 6;
const FILL = `linear-gradient(to top, ${Palette.blue}, ${Palette.sky}, ${Palette.mint})`;

export default function LiveWaveform({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const { after } = useTimeouts();
  /** On = paused. */
  const play = usePlayhead(false);
  const playRef = useRef(play);
  playRef.current = play;
  const cancelResume = useRef<(() => void) | null>(null);
  const now = useIconNow(ctx.isPreview);
  const t = play.elapsed(now);
  const paused = play.isOn;
  const phase = usePhase(now, ctx.n("tempo"));

  const count = Math.max(ctx.i("bars"), 1);
  const energy = ctx.n("energy");
  const caps = ctx.b("caps");
  const gap = count > 7 ? 8 : 10;
  const totalWidth = count * BAR_W + (count - 1) * gap;

  const toggle = () => {
    const on = play.toggle(PAUSE, RESUME);
    haptics.tap(on ? "rigid" : "light");
  };
  const tap = () => {
    cancelResume.current?.();
    toggle();
  };
  /** Autoplay and the detail intro: pause, hold the flat line for a beat, then resume. */
  const blip = () => {
    if (playRef.current.isOn) return;
    toggle();
    cancelResume.current?.();
    cancelResume.current = after(1.5, () => {
      if (playRef.current.isOn) playRef.current.toggle(PAUSE, RESUME);
    });
  };
  useAutoplay(ctx.isPreview, blip, { every: 4.2, delay: 1.6 });

  /** Level 0…1 of bar `index` at `ph`: three unrelated sines, sharpened, loudest in the middle. */
  const level = (index: number, ph: number) => {
    const s = index;
    const p = ph * 2.4;
    const a = Math.sin(p * (2.1 + 0.37 * s) + s * 1.7);
    const b = Math.sin(p * (3.3 - 0.21 * s) + s * 0.9);
    const c = Math.sin(p * 5.9 + s * 2.3);
    const raw = IC.unit(0.5 + 0.28 * a + 0.17 * b + 0.08 * c);
    const middle = (count - 1) / 2;
    const edge = middle > 0 ? Math.abs(s - middle) / middle : 0;
    return Math.pow(raw, 1.4) * (1 - 0.28 * edge) * energy;
  };
  /** The peak-hold cap: the highest recent level, minus a steady fall since it happened. */
  const peak = (index: number) => {
    let best = 0;
    for (let sample = 0; sample < 26; sample++) {
      const back = sample * 0.05;
      best = Math.max(best, level(index, phase - back) - Math.max(back - 0.2, 0) * 0.55);
    }
    return best;
  };
  const delay = (index: number) => Math.abs(index - (count - 1) / 2) * 0.04;
  const liveness = (index: number) => (paused ? 1 - IC.spring(t - delay(index), 0.4, 0.5) : IC.spring(t - 0.12 - delay(index), 0.38, 0.55));

  const flat = paused ? IC.spring(t - 0.42, 0.4, 0.62) : 1 - IC.easeIn(IC.seg(t, 0, 0.16));
  const calm = IC.unit(flat);
  const grey = paused ? IC.seg(t, 0.1, 0.5) : 1 - IC.seg(t, 0, 0.25);
  const lineW = Math.max(totalWidth * flat, 0.01);
  const rest = BAR_W + (LINE_H - BAR_W) * calm;
  const reach = MAX_H - BAR_W;

  return (
    <Stage gap={14} onClick={tap}>
      <div style={{ width: 250, height: 170, display: "grid", placeItems: "center", flexShrink: 0 }}>
        <div style={{ position: "relative", width: totalWidth, height: MAX_H + 14, filter: `drop-shadow(0 6px 12px ${hex(0x3ac4ff, 0.35 * (1 - grey))})` }}>
          {Array.from({ length: count }, (_, index) => {
            const live = liveness(index);
            const lv = Math.max(live, 0);
            const height = rest + reach * level(index, phase) * lv;
            const hop = 22 * Math.max(-live, 0);
            const capY = Math.max(rest + reach * peak(index) * lv, height) + 5;
            const capOpacity = caps ? IC.unit(live * 3) : 0;
            const left = index * (BAR_W + gap);
            return (
              <div key={index}>
                <div style={{ position: "absolute", left, bottom: hop, width: BAR_W, height, borderRadius: Math.min(BAR_W, height) / 2, background: FILL }} />
                <div style={{ position: "absolute", left, bottom: capY, width: BAR_W, height: 4, borderRadius: 2, background: FILL, opacity: 0.85 * capOpacity }} />
              </div>
            );
          })}
          {calm > 0.01 && (
            <>
              <div style={{ position: "absolute", left: (totalWidth - lineW) / 2, bottom: 0, width: lineW, height: LINE_H, borderRadius: LINE_H / 2, background: FILL }} />
              <div
                style={{ position: "absolute", left: (totalWidth - lineW) / 2, bottom: 0, width: lineW, height: LINE_H, borderRadius: LINE_H / 2, background: hex(0x8e8e99), opacity: grey }}
              />
            </>
          )}
        </div>
      </div>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          height: 34,
          padding: "0 14px",
          borderRadius: 17,
          background: Palette.labelAlpha(0.06),
          color: Palette.secondaryLabel,
          ...textStyle.subheadline,
          fontWeight: 600,
        }}
      >
        <Replace k={paused ? "play" : "pause"} style={{ width: 16 }}>
          <svg width={14} height={14} viewBox="0 0 14 14" style={{ display: "block" }}>
            {paused ? (
              <path d="M3 1.9a1 1 0 0 1 1.5-.86l8.3 5.1a1 1 0 0 1 0 1.72l-8.3 5.1A1 1 0 0 1 3 12.1Z" fill="currentColor" />
            ) : (
              <path d="M2.2 1.4h3a.8.8 0 0 1 .8.8v9.6a.8.8 0 0 1-.8.8h-3a.8.8 0 0 1-.8-.8V2.2a.8.8 0 0 1 .8-.8ZM8.8 1.4h3a.8.8 0 0 1 .8.8v9.6a.8.8 0 0 1-.8.8h-3a.8.8 0 0 1-.8-.8V2.2a.8.8 0 0 1 .8-.8Z" fill="currentColor" />
            )}
          </svg>
        </Replace>
        <span style={{ display: "grid" }}>
          {[false, true].map((state) => (
            <span key={String(state)} style={{ gridArea: "1 / 1", whiteSpace: "nowrap", opacity: paused === state ? 1 : 0, transition: "opacity 0.3s" }}>
              {state ? ctx.t("Paused", "已暂停") : ctx.t("Now playing", "正在播放")}
            </span>
          ))}
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap to pause or play" zh="点击暂停或播放" />
    </Stage>
  );
}
