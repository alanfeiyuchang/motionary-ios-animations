/** loading.snake-pixels · 贪吃蛇像素 (Loading+SnakePixels.swift) */
import { useMemo, useRef } from "react";
import { Palette, white, type DemoProps } from "../../kit";
import { previewFps } from "./shared";
import { LoadingCurve, TimeCanvas, blurFill, css, labelRGB, mixColor, roundRect, type RGB } from "./round2";

const SIZE = 198;
const FOOD_GAP = 11;
const FIRST_FOOD = 7;
const MEALS = 5;

/** A closed path through every cell of an even n × n grid. */
function makePath(n: number): [number, number][] {
  const cells: [number, number][] = [];
  for (let col = 0; col < n; col++) cells.push([col, 0]);
  for (let row = 1; row < n; row++) {
    const leftward = row % 2 === 1;
    for (let step = 0; step < n - 1; step++) cells.push([leftward ? n - 1 - step : 1 + step, row]);
  }
  for (let row = n - 1; row >= 1; row--) cells.push([0, row]);
  return cells;
}

function bodyColor(u: number): RGB {
  const x = Math.min(Math.max(u, 0), 1);
  return x < 0.5 ? mixColor(Palette.mint, Palette.sky, x * 2) : mixColor(Palette.sky, Palette.violet, (x - 0.5) * 2);
}

export default function SnakePixels({ ctx }: DemoProps) {
  const speed = Math.max(ctx.n("speed"), 0.5);
  const n = [4, 6, 8][Math.min(Math.max(ctx.i("grid"), 0), 2)];
  const path = useMemo(() => makePath(n), [n]);
  const baseLength = Math.max(ctx.i("length"), 2);
  const food = ctx.b("food");
  const clock = useRef(0);

  const lengthAfter = (count: number) => {
    if (!food) return baseLength;
    const cycle = MEALS + 1;
    return baseLength + (((count % cycle) + cycle) % cycle);
  };

  return (
    <div style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}>
      <TimeCanvas
        width={SIZE + 40}
        height={SIZE + 40}
        fps={previewFps(ctx.isPreview)}
        draw={(g, _s, dt, canvas) => {
          clock.current += dt * speed;
          const head = clock.current + 4;
          const k = canvas.width / (SIZE + 40);
          const label = labelRGB(canvas);
          // A 20 pt margin keeps the head's glow from being cut off at the canvas edge.
          g.translate(20, 20);
          const total = path.length;
          const gap = n <= 4 ? 8 : n <= 6 ? 6 : 4;
          const cell = (SIZE - gap * (n - 1)) / n;
          const corner = cell * 0.28;

          const eaten = food ? Math.max(Math.floor((head - FIRST_FOOD) / FOOD_GAP) + 1, 0) : 0;
          const lastMeal = FIRST_FOOD + (eaten - 1) * FOOD_GAP;
          const sinceMeal = eaten > 0 ? head - lastMeal : 1000;
          const grow = LoadingCurve.smoothstep(sinceMeal / 2);
          const bodyLength = lengthAfter(eaten - 1) + (lengthAfter(eaten) - lengthAfter(eaten - 1)) * grow;
          const bulge = sinceMeal * 2;
          const nextFood = FIRST_FOOD + eaten * FOOD_GAP;
          const nextFoodIndex = ((Math.trunc(nextFood) % total) + total) % total;
          const foodIn = eaten > 0 ? LoadingCurve.smoothstep((sinceMeal - 0.6) / 1.5) : 1;

          for (let index = 0; index < total; index++) {
            const [col, row] = path[index];
            const x = col * (cell + gap);
            const y = row * (cell + gap);
            g.beginPath();
            roundRect(g, x, y, cell, cell, corner);
            g.fillStyle = css(label, 0.07);
            g.fill();

            let behind = (head - index) % total;
            if (behind < 0) behind += total;

            let intensity = 0;
            let scale = 1;
            let along = 0;
            if (behind > total - 1) {
              const entering = behind - (total - 1);
              intensity = entering;
              scale = 0.6 + 0.4 * entering;
            } else if (behind < bodyLength) {
              along = behind / bodyLength;
              intensity = Math.pow(1 - along, 1.25);
              scale = 0.74 + 0.26 * (1 - along) + 0.18 * Math.exp(-behind * 2.4);
              if (food && sinceMeal < bodyLength) {
                const hump = Math.exp(-Math.pow(behind - bulge, 2) / 0.9);
                scale += 0.2 * hump;
                intensity = Math.min(intensity + 0.5 * hump, 1);
              }
            }

            const mx = x + cell / 2;
            const my = y + cell / 2;
            if (intensity > 0.01) {
              const side = cell * scale;
              const shape = () => roundRect(g, mx - side / 2, my - side / 2, side, side, corner * scale);
              if (behind < 1 || behind > total - 1) blurFill(g, k, css(Palette.mint, 0.55 * intensity), 7, shape);
              g.beginPath();
              shape();
              g.fillStyle = css(bodyColor(along), 0.2 + 0.8 * intensity);
              g.fill();
              if (behind < 1.2 || behind > total - 1) {
                g.beginPath();
                roundRect(g, mx - side / 2 + side * 0.16, my - side / 2 + side * 0.14, side * 0.3, side * 0.18, side * 0.09);
                g.fillStyle = white(0.5 * intensity);
                g.fill();
              }
            } else if (food && index === nextFoodIndex && nextFood - head < total - bodyLength - 1) {
              const pulse = 0.62 + 0.1 * Math.sin(head * 1.4);
              const side = cell * pulse * foodIn;
              const shape = () => roundRect(g, mx - side / 2, my - side / 2, side, side, side * 0.34);
              blurFill(g, k, css(Palette.coral, 0.5 * foodIn), 6, shape);
              g.beginPath();
              shape();
              g.fillStyle = css(Palette.coral, foodIn);
              g.fill();
            }
          }
        }}
      />
    </div>
  );
}
