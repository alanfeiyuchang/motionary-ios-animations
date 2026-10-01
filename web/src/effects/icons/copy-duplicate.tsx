/** icons.copy-duplicate · 复制叠页 (Icons+CopyDuplicate.swift) */
import { useRef } from "react";
import { DemoHint, Palette, hex, textStyle, useAutoplay, type DemoProps } from "../../kit";
import { Replace } from "./_icons-kit";
import { CheckCircleFill, DISTANT_PAST, IC, Item, Stage, Z, checkPath, nowSeconds, rotateAt, since, useIconNow, useLater } from "./_time-kit";

const SW = 92;
const SH = 116;
const PEEK = 7;
const RADIUS = 18;
const LINE_W = [36, 58, 58, 40];

export default function CopyDuplicate({ ctx }: DemoProps) {
  const { haptics, later } = useLater();
  const start = useRef(DISTANT_PAST);
  const now = useIconNow(ctx.isPreview);
  const t = since(now, start.current);

  const distance = ctx.n("offset");
  const damping = ctx.n("damping");
  const hold = ctx.n("hold");
  const copied = t > 0.42 && t < 1.0 + hold;

  const copy = (scripted = false) => {
    // A tap while the copy is out simply plays it again from the top.
    if (since(nowSeconds(), start.current) <= 0.5) return;
    start.current = nowSeconds();
    haptics.tap("light");
    later(0.42, scripted, (h) => h.success());
  };
  useAutoplay(ctx.isPreview, () => copy(true), { every: 2.6 });

  const returning = IC.easeInOut(IC.seg(t, 1.0 + hold, 1.32 + hold));
  const amount = IC.spring(t - 0.1, 0.4, damping) * (1 - returning);
  const spread = PEEK + (distance - PEEK) * amount;
  const press = 1 - 0.06 * IC.bump(IC.seg(t, 0, 0.24));
  const wobble = 4 * IC.shake(t - 0.1, 8, 18) * (1 - returning);
  const sweep = IC.easeInOut(IC.seg(t, 0.04, 0.42));
  const leaving = IC.easeIn(IC.seg(t, 0.92 + hold, 1.12 + hold));
  const pop = IC.spring(t - 0.4, 0.32, 0.5) * (1 - leaving);
  const stroke = IC.easeOut(IC.seg(t, 0.48, 0.7));

  const lines = (width: (line: number) => number, color: (line: number) => string) => (
    <div style={{ position: "absolute", left: 16, top: 18, display: "flex", flexDirection: "column", alignItems: "flex-start", gap: 9 }}>
      {[0, 1, 2, 3].map((line) => (
        <div key={line} style={{ width: width(line), height: line === 0 ? 8 : 6, borderRadius: 4, background: color(line) }} />
      ))}
    </div>
  );

  return (
    <Stage gap={12}>
      <Z w={250} h={196} onClick={() => copy()}>
        <Item w={96 + spread} h={14} tf={`translateY(${SH / 2 + 16}px)`} style={{ borderRadius: "50%", background: "rgb(0 0 0 / 0.16)", filter: "blur(8px)" }} />
        <Item
          w={SW}
          h={SH}
          tf={`translate(${spread / 2}px, ${-spread / 2}px) ${rotateAt(5 * IC.unit(amount) + wobble, -SW / 2, SH / 2)}`}
          style={{ borderRadius: RADIUS, background: hex(ctx.scheme === "dark" ? 0x3a3766 : 0xe4e2ff), boxShadow: `inset 0 0 0 2px ${hex(0x6e7bff, 0.7)}` }}
        >
          {lines(
            (line) => LINE_W[line] * IC.easeOut(IC.seg(t, 0.2 + line * 0.06, 0.42 + line * 0.06)) * (1 - returning),
            (line) => hex(0x6e7bff, line === 0 ? 0.9 : 0.5),
          )}
        </Item>
        <Item w={SW} h={SH} tf={`translate(${-spread / 2}px, ${spread / 2}px) scale(${press})`} style={{ filter: `drop-shadow(0 8px 14px ${hex(0x6e7bff, 0.4)})` }}>
          <div style={{ position: "absolute", inset: 0, borderRadius: RADIUS, overflow: "hidden", background: Palette.primary }}>
            <div
              style={{
                position: "absolute",
                left: SW / 2 - 23,
                top: SH / 2 - 100,
                width: 46,
                height: 200,
                background: "linear-gradient(to right, rgb(255 255 255 / 0), rgb(255 255 255 / 0.4), rgb(255 255 255 / 0))",
                transform: `translateX(${-110 + 220 * sweep}px) rotate(22deg)`,
                opacity: sweep > 0 && sweep < 1 ? 1 : 0,
              }}
            />
            {lines(
              (line) => LINE_W[line],
              (line) => `rgb(255 255 255 / ${line === 0 ? 0.95 : 0.6})`,
            )}
            <div style={{ position: "absolute", inset: 0, borderRadius: RADIUS, boxShadow: "inset 0 0 0 1px rgb(255 255 255 / 0.25)" }} />
          </div>
          <svg
            width={44}
            height={44}
            viewBox="0 0 44 44"
            style={{
              position: "absolute",
              right: -14,
              bottom: -14,
              overflow: "visible",
              transform: `scale(${Math.max(pop, 0)})`,
              filter: `drop-shadow(0 4px 8px ${hex(0x1fa866, 0.45)})`,
            }}
          >
            <defs>
              <linearGradient id="copy-badge" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor={hex(0x52de94)} />
                <stop offset="1" stopColor={hex(0x1fa866)} />
              </linearGradient>
            </defs>
            <circle cx={22} cy={22} r={22} fill="url(#copy-badge)" />
            <circle cx={22} cy={22} r={20.5} fill="none" stroke="#fff" strokeWidth={3} />
            {stroke > 0.001 && (
              <path
                d={checkPath(19, 16)}
                transform="translate(12.5 14)"
                fill="none"
                stroke="#fff"
                strokeWidth={4.5}
                strokeLinecap="round"
                strokeLinejoin="round"
                pathLength={1}
                strokeDasharray={`${stroke} 2`}
              />
            )}
          </svg>
        </Item>
      </Z>
      <div style={{ display: "flex", alignItems: "center", gap: 6, ...textStyle.subheadline, fontWeight: 600 }}>
        <Replace k={copied ? "done" : "link"}>
          {copied ? (
            <CheckCircleFill size={18} color={Palette.green} />
          ) : (
            <svg width={18} height={18} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.6} strokeLinecap="round" strokeLinejoin="round" style={{ display: "block", color: Palette.secondaryLabel }}>
              <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
              <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
            </svg>
          )}
        </Replace>
        <span style={{ display: "grid" }}>
          {[false, true].map((state) => (
            <span
              key={String(state)}
              style={{
                gridArea: "1 / 1",
                justifySelf: "start",
                whiteSpace: "nowrap",
                color: state ? Palette.label : Palette.secondaryLabel,
                opacity: copied === state ? 1 : 0,
                transition: "opacity 0.22s ease-in-out",
              }}
            >
              {state ? ctx.t("Copied to clipboard", "已复制到剪贴板") : "motionary.app/fx/copy"}
            </span>
          ))}
        </span>
      </div>
      <DemoHint ctx={ctx} en="Tap to copy" zh="点击复制" />
    </Stage>
  );
}
