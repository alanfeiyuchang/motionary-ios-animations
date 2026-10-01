/** icons.mic-record · 麦克风录音 (Icons+MicRecord.swift) */
import { useRef } from "react";
import { DemoHint, NumericText, Palette, fonts, hex, useAutoplay, useHaptics, type DemoProps } from "../../kit";
import { IC, Item, Stage, Svg, Z, nowSeconds, rr, useIconNow, usePlayhead } from "./_time-kit";

const DURATION = 0.6;
const DISC = 96;

/** A voice-like level in 0…1: three sines of unrelated rates, sharpened so peaks stand out. */
const level = (time: number) => {
  const a = 0.5 + 0.5 * Math.sin(time * 7.3);
  const b = 0.5 + 0.5 * Math.sin(time * 12.7 + 1.3);
  const c = 0.5 + 0.5 * Math.sin(time * 3.1 + 0.6);
  return Math.pow(a * 0.5 + b * 0.3 + c * 0.2, 1.6);
};

export default function MicRecord({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const play = usePlayhead(false);
  const recordingSince = useRef(0);
  const lastLength = useRef(0);
  const clock = useIconNow(ctx.isPreview);
  const t = play.elapsed(clock);
  const on = play.isOn;

  const toggle = () => {
    const now = nowSeconds();
    if (play.isOn) lastLength.current = Math.max(Math.floor(now - recordingSince.current), 0);
    else recordingSince.current = now;
    if (play.toggle(DURATION, DURATION)) haptics.tap("medium");
    else haptics.tap("rigid");
  };
  useAutoplay(ctx.isPreview, toggle, { every: 2.6 });

  const gain = ctx.n("gain");
  const rings = Math.max(ctx.i("rings"), 1);
  const response = ctx.n("response");

  const eased = IC.easeOut(IC.seg(t, 0, 0.3));
  const amount = on ? eased : 1 - eased;
  const sp = IC.spring(t - 0.05, response, 0.62);
  const morph = on ? sp : 1 - sp;
  const discScale = t < 0.07 ? 1 - 0.1 * IC.easeOut(t / 0.07) : 0.9 + 0.1 * IC.spring(t - 0.07, 0.36, 0.5);
  const lvl = level(clock);

  const confirm = on ? 0 : IC.seg(t, 0.05, 0.65);
  const seconds = on ? Math.max(Math.floor(clock - recordingSince.current), 0) : lastLength.current;
  const blink = on ? 0.35 + 0.65 * (0.5 + 0.5 * Math.cos(clock * 2 * Math.PI)) : 0;

  const gone = IC.unit(morph);
  const left = 1 - gone;
  const bodyW = IC.mix(24, 32, morph);
  const bodyH = IC.mix(42, 32, morph);
  const bodyY = IC.mix(-9, 0, gone);
  const stemH = 12 * left;
  const stemY = 15 + 6 * left;

  return (
    <Stage gap={6}>
      <div onClick={toggle} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, cursor: "pointer" }}>
        <Z w={250} h={210}>
          {Array.from({ length: rings }, (_, k) => rings - 1 - k).map((index) => {
            const l = level(clock - index * 0.09);
            const rest = 0.22 + 0.2 * index;
            const scale = 1 + amount * Math.min(rest + l * gain * (0.3 + 0.1 * index), 1.15);
            return (
              <Item
                key={index}
                w={DISC}
                h={DISC}
                tf={`scale(${scale})`}
                o={IC.unit(amount * 1.6)}
                style={{ borderRadius: "50%", background: hex(0xff4d5e, 0.26 - 0.06 * index) }}
              />
            );
          })}
          <Svg w={DISC} h={DISC} tf={`scale(${1 + 0.9 * IC.easeOut(confirm)})`} o={confirm > 0 && confirm < 1 ? 1 : 0}>
            <circle r={DISC / 2} fill="none" stroke={hex(0x6e7bff, 0.6 * (1 - confirm))} strokeWidth={5 * (1 - confirm) + 0.5} />
          </Svg>
          <Item
            w={DISC}
            h={DISC}
            tf={`scale(${discScale})`}
            style={{
              filter: `drop-shadow(0 8px 14px ${hex(0x6e7bff, 0.4 * (1 - amount))}) drop-shadow(0 6px ${14 + 8 * lvl}px ${hex(0xff4d5e, amount * (0.35 + 0.3 * lvl * Math.min(gain, 1)))})`,
            }}
          >
            <div style={{ position: "absolute", inset: 0, borderRadius: "50%", background: Palette.primary }} />
            <div
              style={{ position: "absolute", inset: 0, borderRadius: "50%", opacity: amount, background: `linear-gradient(${hex(0xff7a80)}, ${Palette.red}, ${hex(0xe22d48)})` }}
            />
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: "50%",
                background: "linear-gradient(rgb(255 255 255 / 0.3), rgb(255 255 255 / 0) 50%)",
                boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.28)",
              }}
            />
            <svg width={DISC} height={DISC} viewBox={`${-DISC / 2} ${-DISC / 2} ${DISC} ${DISC}`} style={{ position: "absolute", inset: 0, overflow: "visible" }}>
              {left > 0.02 && (
                <>
                  <path
                    d="M19 -4A19 19 0 0 1 -19 -4"
                    fill="none"
                    stroke="#fff"
                    strokeWidth={5}
                    strokeLinecap="round"
                    pathLength={1}
                    strokeDasharray={`${Math.max(1 - gone, 0.0001)} 2`}
                    strokeDashoffset={-0.5 * gone}
                  />
                  <path d={rr(-2.5, stemY - stemH / 2, 5, stemH, 2.5)} fill="#fff" />
                  <path d={rr(-11 * left, 24.5, 22 * left, 5, 2.5)} fill="#fff" />
                </>
              )}
              <path d={rr(-bodyW / 2, bodyY - bodyH / 2, bodyW, bodyH, IC.mix(12, 8, gone))} fill="#fff" />
            </svg>
          </Item>
        </Z>
        <div style={{ display: "flex", alignItems: "center", gap: 7, paddingRight: 15 }}>
          <div style={{ width: 8, height: 8, borderRadius: "50%", background: Palette.red, opacity: blink }} />
          <NumericText
            value={seconds}
            text={`${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`}
            style={{ fontFamily: fonts.rounded, fontSize: 20, lineHeight: "24px", fontWeight: 600, color: on ? Palette.label : Palette.secondaryLabel }}
          />
        </div>
      </div>
      <DemoHint ctx={ctx} en="Tap to record, tap again to stop" zh="点击开始录音，再点一次停止" />
    </Stage>
  );
}
