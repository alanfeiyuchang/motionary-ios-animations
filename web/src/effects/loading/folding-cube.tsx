/** loading.folding-cube · 折纸方块 (Loading+FoldingCube.swift) */
import { Palette, white, type DemoProps } from "../../kit";
import { previewFps, primary, usePhase } from "./shared";
import { BLACK, Caption, LoadingCurve, centerColumn, mixColor, rgbOf } from "./round2";

const SIDE = 44;
const FRONTS = [Palette.mint, Palette.sky, Palette.indigo, Palette.violet];
const ease = LoadingCurve.easeInOutCubic;

/** `u` is the quadrant's own phase in 0..<1. Unfold 0…0.2, flat until 0.75, fold 0.75…0.95, hidden after. */
function foldAt(u: number) {
  const opening = ease(u / 0.2);
  const closing = ease((u - 0.75) / 0.2);
  const unfold = -180 * (1 - opening);
  const fold = 180 * closing;
  const visibleIn = Math.min(Math.max((180 + unfold) / 25, 0), 1);
  const visibleOut = Math.min(Math.max((180 - fold) / 25, 0), 1);
  return { unfold, fold, opacity: Math.min(visibleIn, visibleOut), tilt: Math.max(Math.abs(unfold), Math.abs(fold)) };
}

export default function FoldingCube({ ctx }: DemoProps) {
  const zh = ctx.lang === "zh";
  const period = Math.max(ctx.n("period"), 0.3);
  const phase = usePhase(1 / period, previewFps(ctx.isPreview));
  const perspective = ctx.n("perspective");
  const gap = ctx.n("gap");
  const diamond = ctx.i("stance") === 0;
  const states = [0, 1, 2, 3].map((q) => {
    const u = phase - q * 0.25;
    return foldAt(u - Math.floor(u));
  });
  const open = states.reduce((sum, s) => sum + s.opacity * (1 - s.tilt / 180), 0) / 4;
  // SwiftUI's rotation3DEffect perspective p ≈ a CSS perspective of (frame side / p).
  const persp = perspective > 0.001 ? `perspective(${SIDE / perspective}px) ` : "";
  return (
    <div style={centerColumn(18)}>
      <div style={{ width: 200, height: 170, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", flex: "none" }}>
        <div style={{ width: 150, height: 132, display: "grid", placeItems: "center", flex: "none" }}>
          <div style={{ position: "relative", width: SIDE * 2, height: SIDE * 2, transform: `rotate(${diamond ? 45 : 0}deg)` }}>
            {states.map((state, quadrant) => {
              const shade = Math.sin((state.tilt * Math.PI) / 180);
              const showsBack = state.tilt > 90;
              const face = showsBack ? mixColor(FRONTS[quadrant], BLACK, 0.24) : rgbOf(FRONTS[quadrant]);
              // `.brightness(-0.2 · shade)` subtracts from every channel.
              const dark = face.map((c) => Math.round(Math.max(0, c - 255 * 0.2 * shade)));
              return (
                <div
                  key={quadrant}
                  style={{
                    position: "absolute",
                    inset: 0,
                    transform: `rotate(${quadrant * 90}deg)`,
                    zIndex: state.tilt > 0.5 ? 2 : 1,
                    opacity: state.opacity,
                    pointerEvents: "none",
                  }}
                >
                  <div style={{ position: "absolute", left: 0, top: 0, width: SIDE, height: SIDE, transform: `${persp}rotateY(${state.fold}deg)`, transformOrigin: "100% 50%" }}>
                    <div style={{ width: SIDE, height: SIDE, padding: gap / 2, transform: `${persp}rotateX(${state.unfold}deg)`, transformOrigin: "50% 100%" }}>
                      <div
                        style={{
                          width: "100%",
                          height: "100%",
                          borderRadius: 5,
                          background: `linear-gradient(135deg, ${white((showsBack ? 0.04 : 0.3) * (1 - 0.2 * shade))}, transparent), rgb(${dark.join(" ")})`,
                        }}
                      />
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
        <div style={{ width: 52 + 54 * open, height: 9, borderRadius: "50%", background: primary(0.05 + 0.1 * open), filter: "blur(4px)", flex: "none" }} />
      </div>
      <Caption title={zh ? "正在解包资源" : "Unpacking assets"} detail={zh ? "展开 4 个资源包中的第 2 个…" : "Unfolding bundle 2 of 4…"} />
    </div>
  );
}
