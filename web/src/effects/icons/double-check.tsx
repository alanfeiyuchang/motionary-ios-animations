/** icons.double-check · 双勾已读 (Icons+DoubleCheck.swift) */
import { AnimatePresence, motion } from "motion/react";
import { useId, useRef } from "react";
import { DemoHint, Palette, anim, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { DISTANT_PAST, IC, Stage, Svg, Z, checkPath, nowSeconds, since, useIconNow, useLater } from "./_time-kit";

const SENT = 0.9;
const CW = 78;
const CH = 60;
const LW = 12;
const SHIFT = 15;
const GREY = hex(0x8e8e99);
const CHECK = checkPath(CW, CH);

export default function DoubleCheck({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const uid = useId().replace(/:/g, "");
  const start = useRef(DISTANT_PAST);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const gap = ctx.n("gap");
  const draw = ctx.n("draw");
  const damping = ctx.n("damping");
  const delivered = SENT + gap;
  const read = SENT + 2 * gap;
  const stage = t < SENT ? 0 : t < delivered ? 1 : t < read ? 2 : 3;

  const send = (scripted = false) => {
    // One message at a time: taps are ignored until it has been read.
    if (since(nowSeconds(), start.current) <= read + 0.3) return;
    start.current = nowSeconds();
    haptics.tap("light");
    later(SENT, scripted, (h) => h.tap("soft"));
    later(delivered, scripted, (h) => h.tap("soft"));
    later(read, scripted, (h) => h.success());
  };
  useAutoplay(ctx.isPreview, () => send(true), { every: read + 1.5 });

  const pop = IC.spring(t, 0.36, 0.62);
  const slide = IC.spring(t - delivered, 0.34, 0.7);
  const wipe = IC.easeInOut(IC.seg(t, read, read + 0.3));
  const swell = 0.2 * IC.shake(t - read - 0.12, 9, 20);
  const glow = IC.bump(IC.seg(t, read, read + 0.7));

  const ring = IC.easeOut(IC.seg(t, 0, 0.25));
  const leaving = IC.easeIn(IC.seg(t, SENT - 0.04, SENT + 0.14));
  const turns = 720 * IC.easeInOut(IC.seg(t, 0.08, SENT));

  const first = IC.easeOut(IC.seg(t, SENT, SENT + draw));
  const second = IC.easeOut(IC.seg(t, delivered, delivered + draw));
  const firstPop = 0.7 + 0.3 * IC.spring(t - SENT, 0.3, damping);
  const secondPop = 0.7 + 0.3 * IC.spring(t - delivered, 0.3, damping);
  const firstTf = `translate(${-SHIFT * slide} 0) scale(${firstPop}) translate(${-CW / 2} ${-CH / 2})`;
  const secondTf = `translate(${SHIFT * 1.2} 0) scale(${secondPop}) translate(${-CW / 2} ${-CH / 2})`;
  const line = { fill: "none", strokeLinecap: "round" as const, strokeLinejoin: "round" as const, pathLength: 1 };

  const checks = (paint: string) => (
    <>
      {first > 0.001 && (
        <g mask={`url(#${uid}-gap)`}>
          <path d={CHECK} transform={firstTf} stroke={paint} strokeWidth={LW} strokeDasharray={`${first} 2`} {...line} />
        </g>
      )}
      {second > 0.001 && <path d={CHECK} transform={secondTf} stroke={paint} strokeWidth={LW} strokeDasharray={`${second} 2`} {...line} />}
    </>
  );
  const captions = [ctx.t("Sending…", "发送中…"), ctx.t("Sent", "已发送"), ctx.t("Delivered", "已送达"), ctx.t("Read", "已读")];

  return (
    <Stage gap={10} onClick={() => send()}>
      <div style={{ width: 250, height: 62, display: "flex", alignItems: "center", justifyContent: "flex-end", flexShrink: 0 }}>
        <div
          style={{
            ...textStyle.callout,
            fontWeight: 500,
            color: "#fff",
            whiteSpace: "nowrap",
            padding: "11px 16px",
            borderRadius: "20px 20px 6px 20px",
            background: Palette.ocean,
            boxShadow: `0 5px 10px ${hex(0x4f7cff, 0.3)}`,
            transformOrigin: "100% 100%",
            transform: `translateY(${18 * (1 - pop)}px) scale(${0.6 + 0.4 * pop})`,
            opacity: IC.seg(t, 0, 0.1),
          }}
        >
          {ctx.t("On my way, see you at 7!", "我出发啦，七点见！")}
        </div>
      </div>
      <Z w={250} h={122}>
        <Svg w={76} h={76} tf={`scale(${1 - 0.4 * leaving})`} o={1 - leaving}>
          <g fill="none" stroke={GREY} strokeWidth={10} strokeLinecap="round">
            {ring > 0.001 && <circle r={38} transform="rotate(-90)" pathLength={1} strokeDasharray={`${ring} 2`} />}
            <path d={`M0 0L0 ${-0.3 * 76}`} transform={`rotate(${turns})`} opacity={ring} />
            <path d={`M0 0L${0.22 * 76} 0`} transform={`rotate(${turns / 12})`} opacity={ring} />
          </g>
        </Svg>
        <Svg w={210} h={110} tf={`scale(${1 + swell})`} style={{ filter: glow > 0.01 ? `drop-shadow(0 0 14px ${hex(0x4f7cff, 0.55 * glow)})` : undefined }}>
          <defs>
            <linearGradient id={`${uid}-ocean`} x1={-CW / 2} y1={-CH / 2} x2={CW / 2} y2={CH / 2} gradientUnits="userSpaceOnUse">
              <stop offset="0" stopColor={Palette.sky} />
              <stop offset="1" stopColor={Palette.blue} />
            </linearGradient>
            {/* The second check cuts a gap out of the first where they cross. */}
            <mask id={`${uid}-gap`} maskUnits="userSpaceOnUse" x={-140} y={-90} width={280} height={180}>
              <rect x={-140} y={-90} width={280} height={180} fill="#fff" />
              {second > 0 && <path d={CHECK} transform={secondTf} stroke="#000" strokeWidth={LW * 2.1} strokeDasharray={`${Math.max(second, 0.0001)} 2`} {...line} />}
            </mask>
            <clipPath id={`${uid}-wipe`}>
              <rect x={-105} y={-90} width={210 * wipe} height={180} />
            </clipPath>
          </defs>
          {checks(GREY)}
          <g clipPath={`url(#${uid}-wipe)`}>{checks(`url(#${uid}-ocean)`)}</g>
        </Svg>
      </Z>
      <div style={{ display: "grid", ...textStyle.subheadline, fontWeight: 600 }}>
        <AnimatePresence initial={false}>
          <motion.span
            key={stage}
            initial={{ opacity: 0, y: 8, filter: "blur(2px)" }}
            animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
            exit={{ opacity: 0, y: -8, filter: "blur(2px)" }}
            transition={anim.snappyD(0.3)}
            style={{ gridArea: "1 / 1", textAlign: "center", whiteSpace: "nowrap", color: stage === 3 ? Palette.blue : Palette.secondaryLabel }}
          >
            {captions[stage]}
          </motion.span>
        </AnimatePresence>
      </div>
      <DemoHint ctx={ctx} en="Tap to send again" zh="点击再发一条" />
    </Stage>
  );
}
