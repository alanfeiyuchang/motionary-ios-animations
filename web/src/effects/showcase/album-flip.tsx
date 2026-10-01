/** showcase.album-flip · 专辑封面翻面 (Showcase+AlbumFlip.swift) */
import { AnimatePresence, motion } from "motion/react";
import { ChevronLeft, Image as ImageIcon, List } from "lucide-react";
import { useRef, useState } from "react";
import { black, delayed, fonts, hex, spring, useAutoplay, useHaptics, white, type DemoProps } from "../../kit";
import { Signature, SignatureRim, signatureCard, signatureEyebrow } from "./signature";
import { SportPress } from "./_a-sport";
import { StudioEqualizer, StudioScene, useAnimatedNumber } from "./_studio";

const TRACKS: [string, string][] = [["Low Beams", "近光灯"], ["Highway Glass", "玻璃公路"], ["Neon Mile", "霓虹一英里"], ["Tunnel Light", "隧道的光"], ["Last Exit", "最后一个出口"]];
const LENGTHS = ["3:12", "4:05", "3:48", "2:57", "5:21"];
const SIDE = 196;

function ridgePoints(seed: number, baseline: number, amplitude: number): string {
  const points = ["0,1"];
  for (let i = 0; i <= 9; i++) {
    const n = Math.sin(seed * 12.9898 + i * 78.233) * 43758.5453;
    const jitter = n - Math.floor(n);
    points.push(`${i / 9},${baseline - amplitude * (i % 2 === 0 ? jitter * 0.5 : 0.6 + jitter * 0.4)}`);
  }
  points.push("1,1");
  return points.join(" ");
}

export default function AlbumFlip({ ctx }: DemoProps) {
  const haptics = useHaptics();
  const zh = ctx.lang === "zh";
  const li = zh ? 1 : 0;
  const [angle, angleApi] = useAnimatedNumber(0);
  const [turns, setTurns] = useState(0);
  const [track, setTrack] = useState(1);
  const st = useRef({ turns: 0, track: 1, step: 0 });
  const flipped = turns % 2 !== 0;

  const flip = (user: boolean) => {
    if (user) haptics.tap("medium");
    st.current.turns += 1;
    setTurns(st.current.turns);
    angleApi.animateTo(st.current.turns * 180, spring(ctx.n("response"), ctx.n("damping")));
  };
  const select = (index: number) => {
    st.current.track = index;
    setTrack(index);
  };
  const autoStep = () => {
    if (st.current.step % 3 === 1) select((st.current.track + 1) % TRACKS.length);
    else flip(false);
    st.current.step += 1;
  };
  useAutoplay(ctx.isPreview, autoStep, { every: 1.6, delay: 0.7 });

  const turn = ((angle % 360) + 360) % 360;
  const showsBack = turn > 90 && turn < 270;
  const edge = Math.abs(Math.sin((angle * Math.PI) / 180));
  const persp = SIDE / Math.max(ctx.n("perspective"), 0.01);
  const select4 = spring(0.4, 0.8);

  return (
    <StudioScene ctx={ctx} en="Tap the cover, then pick a track" zh="点击封面翻面，再选一首曲目">
      <div style={{ ...signatureCard(), width: 228, padding: 16, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 12, color: "#fff" }}>
        <div style={{ width: SIDE, height: SIDE, transform: `scale(${1 + ctx.n("lift") * edge})`, filter: `drop-shadow(0 ${7 + 12 * edge}px ${10 + 14 * edge}px ${black(0.35 + 0.25 * edge)})` }}>
          <div style={{ position: "relative", width: SIDE, height: SIDE, transform: `perspective(${persp}px) rotateY(${angle}deg)` }}>
            <div style={{ position: "absolute", inset: 0, opacity: showsBack ? 0 : 1, pointerEvents: showsBack ? "none" : "auto" }}>
              <SportPress scale={0.98} dim={0.03} radius={14} onClick={() => flip(true)}>
                <Cover zh={zh} />
              </SportPress>
            </div>
            <div style={{ position: "absolute", inset: 0, transform: "rotateY(180deg)", opacity: showsBack ? 1 : 0, pointerEvents: showsBack ? "auto" : "none" }}>
              <div style={{ position: "relative", width: SIDE, height: SIDE, boxSizing: "border-box", padding: "8px 10px", borderRadius: 14, background: "linear-gradient(#2A2A30, #1A1A1E)", boxShadow: `inset 0 0 0 1px ${white(0.12)}`, display: "flex", flexDirection: "column", gap: 4 }}>
                <motion.span initial={false} animate={{ y: track * 32 }} transition={select4} style={{ position: "absolute", left: 10, right: 10, top: 8 + 22 + 4, height: 28, borderRadius: 14, background: Signature.accentGradient }} />
                <SportPress scale={0.97} dim={0.03} onClick={() => flip(true)}>
                  <span style={{ ...signatureEyebrow(), height: 22, display: "flex", alignItems: "center", gap: 6, whiteSpace: "nowrap" }}>
                    <ChevronLeft size={10} strokeWidth={4} />
                    {zh ? "A 面 · 5 首" : "Side A · 5 tracks"}
                    <span style={{ flex: 1 }} />
                    19:23
                  </span>
                </SportPress>
                {TRACKS.map((t, index) => {
                  const playing = index === track;
                  return (
                    <motion.div key={index} initial={false} animate={{ opacity: flipped ? 1 : 0, x: flipped ? 0 : 14 }} transition={delayed(spring(0.45, 0.8), flipped ? 0.22 + index * 0.045 : 0)} style={{ position: "relative" }}>
                      <SportPress
                        scale={0.97}
                        dim={0.03}
                        style={{ width: "100%" }}
                        onClick={() => {
                          if (index === st.current.track) return;
                          haptics.selection();
                          select(index);
                        }}
                      >
                        <span style={{ height: 28, padding: "0 8px", display: "flex", alignItems: "center", gap: 8 }}>
                          <span style={{ position: "relative", width: 16, height: 14, display: "grid", placeItems: "center" }}>
                            <AnimatePresence initial={false}>
                              {playing ? (
                                <motion.span key="eq" initial={{ scale: 0, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0, opacity: 0 }} transition={select4} style={{ position: "absolute" }}>
                                  <StudioEqualizer color={Signature.ink} height={11} preview={ctx.isPreview} />
                                </motion.span>
                              ) : (
                                <motion.span key="n" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={select4} style={{ position: "absolute", fontFamily: fonts.rounded, fontSize: 11, fontWeight: 700, fontVariantNumeric: "tabular-nums", color: Signature.textSecondary }}>
                                  {index + 1}
                                </motion.span>
                              )}
                            </AnimatePresence>
                          </span>
                          <motion.span initial={false} animate={{ color: playing ? Signature.ink : "#FFFFFF" }} transition={select4} style={{ fontFamily: fonts.rounded, fontSize: 13, fontWeight: playing ? 700 : 600, whiteSpace: "nowrap" }}>
                            {t[li]}
                          </motion.span>
                          <span style={{ flex: 1 }} />
                          <motion.span initial={false} animate={{ color: playing ? hex(0x0b0b0d, 0.7) : white(0.55) }} transition={select4} style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 600, fontVariantNumeric: "tabular-nums" }}>
                            {LENGTHS[index]}
                          </motion.span>
                        </span>
                      </SportPress>
                    </motion.div>
                  );
                })}
              </div>
            </div>
            <div style={{ position: "absolute", inset: 0, borderRadius: 14, overflow: "hidden", pointerEvents: "none", mixBlendMode: "plus-lighter" }}>
              <div style={{ position: "absolute", left: -SIDE, top: 0, width: SIDE * 3, height: SIDE, transform: `translateX(${(edge * 1.3 - 0.75) * SIDE}px)`, background: `linear-gradient(153.43deg, transparent calc(50% - 110px), ${white(0.5 * edge)} 50%, transparent calc(50% + 110px))` }} />
            </div>
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", gap: 1 }}>
            <span style={{ position: "relative", height: 18, overflow: "hidden" }}>
              <AnimatePresence initial={false}>
                <motion.span key={track} initial={{ y: 18, opacity: 0 }} animate={{ y: 0, opacity: 1 }} exit={{ y: -18, opacity: 0 }} transition={select4} style={{ position: "absolute", left: 0, top: 0, fontFamily: fonts.rounded, fontSize: 15, fontWeight: 700, lineHeight: "18px", whiteSpace: "nowrap" }}>
                  {TRACKS[track][li]}
                </motion.span>
              </AnimatePresence>
            </span>
            <span style={{ fontFamily: fonts.rounded, fontSize: 11, fontWeight: 500, lineHeight: "13px", color: Signature.textSecondary, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{zh ? "夜行 · 灯笼乐队" : "Night Drive · The Lanterns"}</span>
          </div>
          <SportPress scale={0.9} dim={0.06} radius={18} onClick={() => flip(true)}>
            <span style={{ width: 36, height: 36, borderRadius: "50%", background: white(0.1), boxShadow: `inset 0 0 0 1px ${white(0.14)}`, display: "grid", placeItems: "center", color: "#fff" }}>
              <AnimatePresence initial={false} mode="popLayout">
                <motion.span key={String(flipped)} initial={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} animate={{ scale: 1, opacity: 1, filter: "blur(0px)" }} exit={{ scale: 0.4, opacity: 0, filter: "blur(4px)" }} transition={{ duration: 0.22 }} style={{ display: "grid" }}>
                  {flipped ? <ImageIcon size={15} strokeWidth={2.6} /> : <List size={15} strokeWidth={3} />}
                </motion.span>
              </AnimatePresence>
            </span>
          </SportPress>
        </div>
        <SignatureRim />
      </div>
    </StudioScene>
  );
}

function Cover({ zh }: { zh: boolean }) {
  // The striped sun: a solid top 50 pt, then five thinning bars.
  const stops: string[] = ["#000 0px", "#000 50px"];
  let y = 50;
  for (let i = 0; i < 5; i++) {
    const gap = 2.5 + i * 1.2;
    const bar = 8 - i * 0.9;
    stops.push(`transparent ${y}px`, `transparent ${y + gap}px`, `#000 ${y + gap}px`, `#000 ${y + gap + bar}px`);
    y += gap + bar;
  }
  stops.push(`transparent ${y}px`);
  const mask = `linear-gradient(${stops.join(", ")})`;
  return (
    <div style={{ position: "relative", width: SIDE, height: SIDE, borderRadius: 14, overflow: "hidden", background: "linear-gradient(#241446, #8A2B5C, #F0703A, #FFC27A)", textAlign: "left" }}>
      <div style={{ position: "absolute", left: SIDE / 2 - 52, top: SIDE / 2 - 52 + 14, width: 104, height: 104, filter: `drop-shadow(0 0 18px ${hex(0xff9a3d, 0.7)})` }}>
        <div style={{ width: 104, height: 104, borderRadius: "50%", background: "linear-gradient(#FFE9B8, #FF9A3D, #F0456A)", WebkitMaskImage: mask, maskImage: mask }} />
      </div>
      <svg viewBox="0 0 1 1" preserveAspectRatio="none" style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}>
        <polygon points={ridgePoints(11, 0.78, 0.16)} fill="#3A1B46" />
        <polygon points={ridgePoints(5, 0.9, 0.12)} fill="#160D22" />
      </svg>
      <div style={{ position: "absolute", left: 14, top: 14, display: "flex", flexDirection: "column", gap: 2, alignItems: "flex-start" }}>
        <span style={{ fontFamily: fonts.rounded, fontSize: zh ? 22 : 17, fontWeight: 900, letterSpacing: zh ? 6 : 3, lineHeight: 1.2, color: "#fff", whiteSpace: "nowrap" }}>{zh ? "夜行" : "NIGHT DRIVE"}</span>
        <span style={{ fontFamily: fonts.rounded, fontSize: 9, fontWeight: 700, letterSpacing: 2, lineHeight: "11px", color: white(0.7), whiteSpace: "nowrap" }}>{zh ? "灯笼乐队" : "THE LANTERNS"}</span>
      </div>
      <div style={{ position: "absolute", inset: 0, borderRadius: 14, boxShadow: `inset 0 0 0 1px ${white(0.18)}` }} />
    </div>
  );
}
