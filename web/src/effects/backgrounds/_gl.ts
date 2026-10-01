/**
 * Small WebGL helpers for the Backgrounds category (the kit's ShaderCanvas only fills a quad):
 *
 * - `MeshRenderer`: SwiftUI's `MeshGradient(width:height:points:colors:)`, tessellated on the CPU with
 *   bicubic (Catmull-Rom) interpolation of both the vertex positions and the colours (`smoothsColors`),
 *   then rasterised with per-vertex colours.
 * - `GooRenderer`: Canvas `addFilter(.alphaThreshold(min: 0.5))` + `addFilter(.blur(radius:))`: the
 *   shapes drawn in a 2D canvas are Gaussian-blurred on the GPU and cut at 50 % alpha with an
 *   anti-aliased edge; a caller-supplied shader colours the silhouette.
 */

function compile(gl: WebGLRenderingContext, type: number, src: string) {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, src);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) console.error("[backgrounds gl]", gl.getShaderInfoLog(shader));
  return shader;
}

function program(gl: WebGLRenderingContext, vs: string, fs: string) {
  const p = gl.createProgram()!;
  gl.attachShader(p, compile(gl, gl.VERTEX_SHADER, vs));
  gl.attachShader(p, compile(gl, gl.FRAGMENT_SHADER, fs));
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) console.error("[backgrounds gl] link", gl.getProgramInfoLog(p));
  return p;
}

function sizeCanvas(canvas: HTMLCanvasElement, w: number, h: number, k: number) {
  const pw = Math.max(1, Math.round(w * k));
  const ph = Math.max(1, Math.round(h * k));
  if (canvas.width !== pw || canvas.height !== ph) {
    canvas.width = pw;
    canvas.height = ph;
  }
}

// MARK: - Mesh gradient

const MESH_VS = `
attribute vec2 a_pos;
attribute vec3 a_color;
varying vec3 v_color;
void main() {
  v_color = a_color;
  gl_Position = vec4(a_pos.x * 2.0 - 1.0, 1.0 - a_pos.y * 2.0, 0.0, 1.0);
}`;
const MESH_FS = `
precision mediump float;
varying vec3 v_color;
void main() { gl_FragColor = vec4(clamp(v_color, 0.0, 1.0), 1.0); }`;

/** 1-D Catmull-Rom through p1…p2 with neighbours p0, p3. */
function cr(p0: number, p1: number, p2: number, p3: number, u: number) {
  return 0.5 * (2 * p1 + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u);
}

export class MeshRenderer {
  private gl: WebGLRenderingContext | null;
  private prog: WebGLProgram | null = null;
  private posBuf: WebGLBuffer | null = null;
  private colBuf: WebGLBuffer | null = null;
  private idxBuf: WebGLBuffer | null = null;
  private layout = "";
  private indexCount = 0;
  private pos = new Float32Array(0);
  private col = new Float32Array(0);
  /** Sub-quads per patch side. */
  private readonly sub: number;

  constructor(private canvas: HTMLCanvasElement, sub = 18) {
    this.sub = sub;
    this.gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: true, alpha: true });
    const gl = this.gl;
    if (!gl) return;
    this.prog = program(gl, MESH_VS, MESH_FS);
    this.posBuf = gl.createBuffer();
    this.colBuf = gl.createBuffer();
    this.idxBuf = gl.createBuffer();
  }

  dispose() {
    this.gl?.getExtension("WEBGL_lose_context")?.loseContext();
  }

  /**
   * `points`: `cols × rows` unit positions (x, y pairs, row-major, like SwiftUI's `points`);
   * `colors`: matching sRGB triples in 0…1.
   */
  draw(w: number, h: number, k: number, cols: number, rows: number, points: number[], colors: number[]) {
    const gl = this.gl;
    if (!gl || !this.prog) return;
    sizeCanvas(this.canvas, w, h, k);
    const sub = this.sub;
    const nx = (cols - 1) * sub + 1;
    const ny = (rows - 1) * sub + 1;
    const layout = `${cols}x${rows}`;
    if (layout !== this.layout) {
      this.layout = layout;
      this.pos = new Float32Array(nx * ny * 2);
      this.col = new Float32Array(nx * ny * 3);
      const idx = new Uint16Array((nx - 1) * (ny - 1) * 6);
      let n = 0;
      for (let j = 0; j < ny - 1; j++) {
        for (let i = 0; i < nx - 1; i++) {
          const a = j * nx + i;
          idx[n++] = a;
          idx[n++] = a + 1;
          idx[n++] = a + nx;
          idx[n++] = a + 1;
          idx[n++] = a + nx + 1;
          idx[n++] = a + nx;
        }
      }
      this.indexCount = n;
      gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.idxBuf);
      gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, idx, gl.STATIC_DRAW);
    }
    // Value of component c (of `stride`) at grid (i, j), extrapolated linearly past the borders.
    const at = (arr: number[], stride: number, c: number, i: number, j: number): number => {
      if (i < 0) return 2 * at(arr, stride, c, 0, j) - at(arr, stride, c, 1, j);
      if (i > cols - 1) return 2 * at(arr, stride, c, cols - 1, j) - at(arr, stride, c, cols - 2, j);
      if (j < 0) return 2 * at(arr, stride, c, i, 0) - at(arr, stride, c, i, 1);
      if (j > rows - 1) return 2 * at(arr, stride, c, i, rows - 1) - at(arr, stride, c, i, rows - 2);
      return arr[(j * cols + i) * stride + c];
    };
    const evalAt = (arr: number[], stride: number, c: number, pi: number, pj: number, u: number, v: number) => {
      const r = [0, 0, 0, 0];
      for (let m = 0; m < 4; m++) {
        const j = pj - 1 + m;
        r[m] = cr(at(arr, stride, c, pi - 1, j), at(arr, stride, c, pi, j), at(arr, stride, c, pi + 1, j), at(arr, stride, c, pi + 2, j), u);
      }
      return cr(r[0], r[1], r[2], r[3], v);
    };
    for (let gy = 0; gy < ny; gy++) {
      const pj = Math.min(Math.floor(gy / sub), rows - 2);
      const v = gy / sub - pj;
      for (let gx = 0; gx < nx; gx++) {
        const pi = Math.min(Math.floor(gx / sub), cols - 2);
        const u = gx / sub - pi;
        const n = gy * nx + gx;
        this.pos[n * 2] = evalAt(points, 2, 0, pi, pj, u, v);
        this.pos[n * 2 + 1] = evalAt(points, 2, 1, pi, pj, u, v);
        for (let c = 0; c < 3; c++) this.col[n * 3 + c] = evalAt(colors, 3, c, pi, pj, u, v);
      }
    }
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(this.prog);
    const aPos = gl.getAttribLocation(this.prog, "a_pos");
    const aCol = gl.getAttribLocation(this.prog, "a_color");
    gl.bindBuffer(gl.ARRAY_BUFFER, this.posBuf);
    gl.bufferData(gl.ARRAY_BUFFER, this.pos, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(aPos);
    gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.colBuf);
    gl.bufferData(gl.ARRAY_BUFFER, this.col, gl.DYNAMIC_DRAW);
    gl.enableVertexAttribArray(aCol);
    gl.vertexAttribPointer(aCol, 3, gl.FLOAT, false, 0, 0);
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.idxBuf);
    gl.drawElements(gl.TRIANGLES, this.indexCount, gl.UNSIGNED_SHORT, 0);
  }
}

// MARK: - Goo (blur + alpha threshold)

const QUAD_VS = `
attribute vec2 a_pos;
varying vec2 v_uv;
void main() {
  v_uv = vec2(a_pos.x * 0.5 + 0.5, 0.5 - a_pos.y * 0.5);
  gl_Position = vec4(a_pos, 0.0, 1.0);
}`;

// Separable Gaussian on the alpha channel. v_uv has its origin top-left; textures uploaded from a
// canvas keep that orientation (UNPACK_FLIP_Y false), FBO passes keep it too.
const BLUR_FS = `
precision highp float;
varying vec2 v_uv;
uniform sampler2D u_tex;
uniform vec2 u_step;
uniform float u_sigma;
void main() {
  float radius = ceil(u_sigma * 3.0);
  float sum = 0.0;
  float weight = 0.0;
  for (int i = -72; i <= 72; i++) {
    float x = float(i);
    if (abs(x) > radius) continue;
    float w = exp(-0.5 * x * x / (u_sigma * u_sigma));
    sum += texture2D(u_tex, v_uv + u_step * x).a * w;
    weight += w;
  }
  gl_FragColor = vec4(0.0, 0.0, 0.0, sum / max(weight, 1e-5));
}`;

export interface GooTarget {
  tex: WebGLTexture;
  fb: WebGLFramebuffer;
  w: number;
  h: number;
}

/**
 * Blurs a shapes canvas (alpha) and runs `fragment` to colour the result. The fragment shader gets
 *   uniform sampler2D u_field;   // blurred alpha (sample `.a`), same orientation as v_uv
 *   uniform vec2 u_size;         // canvas size in points
 *   varying vec2 v_uv;           // 0…1, origin top-left
 *   float sil(vec2 uv);          // thresholded (≥ 0.5) silhouette with a 1 px anti-aliased edge
 * plus the caller's uniforms.
 */
export class GooRenderer {
  private gl: WebGLRenderingContext | null;
  private blurProg: WebGLProgram | null = null;
  private finalProg: WebGLProgram | null = null;
  private quad: WebGLBuffer | null = null;
  private src: WebGLTexture | null = null;
  private extra: WebGLTexture | null = null;
  private a: GooTarget | null = null;
  private b: GooTarget | null = null;
  private locs = new Map<string, WebGLUniformLocation | null>();

  constructor(private canvas: HTMLCanvasElement, fragment: string) {
    this.gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: true, alpha: true });
    const gl = this.gl;
    if (!gl) return;
    gl.getExtension("OES_standard_derivatives");
    this.blurProg = program(gl, QUAD_VS, BLUR_FS);
    const header = `#extension GL_OES_standard_derivatives : enable
precision highp float;
varying vec2 v_uv;
uniform sampler2D u_field;
uniform sampler2D u_extra;
uniform vec2 u_size;
float fieldAt(vec2 uv) { return texture2D(u_field, uv).a; }
float sil(vec2 uv) {
  float f = fieldAt(uv);
  float e = max(fwidth(f) * 0.75, 1e-4);
  return smoothstep(0.5 - e, 0.5 + e, f);
}
`;
    this.finalProg = program(gl, QUAD_VS, header + fragment);
    this.quad = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
    this.src = this.texture();
    this.extra = this.texture();
  }

  dispose() {
    this.gl?.getExtension("WEBGL_lose_context")?.loseContext();
  }

  private texture() {
    const gl = this.gl!;
    const t = gl.createTexture()!;
    gl.bindTexture(gl.TEXTURE_2D, t);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array([0, 0, 0, 0]));
    return t;
  }

  private target(old: GooTarget | null, w: number, h: number): GooTarget {
    const gl = this.gl!;
    if (old && old.w === w && old.h === h) return old;
    const tex = this.texture();
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, null);
    const fb = gl.createFramebuffer()!;
    gl.bindFramebuffer(gl.FRAMEBUFFER, fb);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    return { tex, fb, w, h };
  }

  private loc(p: WebGLProgram, name: string) {
    const key = (p === this.blurProg ? "b:" : "f:") + name;
    if (!this.locs.has(key)) this.locs.set(key, this.gl!.getUniformLocation(p, name));
    return this.locs.get(key)!;
  }

  private bindQuad(p: WebGLProgram) {
    const gl = this.gl!;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.quad);
    const a = gl.getAttribLocation(p, "a_pos");
    gl.enableVertexAttribArray(a);
    gl.vertexAttribPointer(a, 2, gl.FLOAT, false, 0, 0);
  }

  /**
   * `shapes`: a 2D canvas (any resolution) covering the `w × h` stage, shapes drawn opaque.
   * `sigma`: blur radius in points. `extra`: optional second canvas bound as `u_extra`.
   */
  render(
    shapes: HTMLCanvasElement,
    sigma: number,
    w: number,
    h: number,
    k: number,
    uniforms: Record<string, number | number[]>,
    extra?: HTMLCanvasElement | null,
  ) {
    const gl = this.gl;
    if (!gl || !this.blurProg || !this.finalProg) return;
    sizeCanvas(this.canvas, w, h, k);
    gl.disable(gl.BLEND);
    gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, this.src);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, shapes);
    const tw = shapes.width;
    const th = shapes.height;
    const scale = tw / w; // texture pixels per point
    this.a = this.target(this.a, tw, th);
    this.b = this.target(this.b, tw, th);
    gl.useProgram(this.blurProg);
    this.bindQuad(this.blurProg);
    gl.uniform1i(this.loc(this.blurProg, "u_tex"), 0);
    gl.uniform1f(this.loc(this.blurProg, "u_sigma"), Math.max(sigma * scale, 0.01));
    // Horizontal pass: src → a
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.a.fb);
    gl.viewport(0, 0, tw, th);
    gl.uniform2f(this.loc(this.blurProg, "u_step"), 1 / tw, 0);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    // Vertical pass: a → b. (FBO rows are flipped relative to the canvas upload; the quad's v_uv maps
    // both the same way, so orientation is preserved end to end.)
    gl.bindFramebuffer(gl.FRAMEBUFFER, this.b.fb);
    gl.bindTexture(gl.TEXTURE_2D, this.a.tex);
    gl.uniform2f(this.loc(this.blurProg, "u_step"), 0, 1 / th);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    // Final pass to the screen.
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(this.finalProg);
    this.bindQuad(this.finalProg);
    gl.bindTexture(gl.TEXTURE_2D, this.b.tex);
    gl.uniform1i(this.loc(this.finalProg, "u_field"), 0);
    if (extra) {
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D, this.extra);
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, extra);
      gl.uniform1i(this.loc(this.finalProg, "u_extra"), 1);
      gl.activeTexture(gl.TEXTURE0);
    }
    gl.uniform2f(this.loc(this.finalProg, "u_size"), w, h);
    for (const [name, value] of Object.entries(uniforms)) {
      const l = this.loc(this.finalProg, name);
      if (!l) continue;
      if (typeof value === "number") gl.uniform1f(l, value);
      else if (value.length === 2) gl.uniform2f(l, value[0], value[1]);
      else if (value.length === 3) gl.uniform3f(l, value[0], value[1], value[2]);
      else if (value.length === 4) gl.uniform4f(l, value[0], value[1], value[2], value[3]);
      else gl.uniform3fv(l, new Float32Array(value));
    }
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
}

// MARK: - Lifetime

const pending = new WeakMap<HTMLCanvasElement, { renderer: { dispose(): void }; timer: number }>();

/**
 * Creates (or, after StrictMode's unmount/re-mount, reuses) the renderer bound to `canvas`. A lost
 * WebGL context can't be re-acquired from the same canvas, so disposal is deferred a moment.
 */
export function acquire<T extends { dispose(): void }>(canvas: HTMLCanvasElement, make: () => T): T {
  const held = pending.get(canvas);
  if (held) {
    window.clearTimeout(held.timer);
    pending.delete(canvas);
    return held.renderer as T;
  }
  return make();
}

export function release(canvas: HTMLCanvasElement, renderer: { dispose(): void }) {
  const timer = window.setTimeout(() => {
    pending.delete(canvas);
    renderer.dispose();
  }, 300);
  pending.set(canvas, { renderer, timer });
}

// MARK: - Full-screen fragment shader

/**
 * A local stand-in for the kit's `ShaderCanvas` (whose cleanup calls `loseContext()`, so React
 * StrictMode's effect re-run gets a dead context and a blank canvas). Pair with `acquire`/`release`.
 * The fragment shader gets `v_uv` (0…1, origin top-left) and `u_size` (points).
 */
export class QuadRenderer {
  private gl: WebGLRenderingContext | null;
  private prog: WebGLProgram | null = null;
  private locs = new Map<string, WebGLUniformLocation | null>();

  constructor(private canvas: HTMLCanvasElement, fragment: string) {
    this.gl = canvas.getContext("webgl", { antialias: false, premultipliedAlpha: true, alpha: true });
    const gl = this.gl;
    if (!gl) return;
    this.prog = program(gl, QUAD_VS, "precision highp float;\nvarying vec2 v_uv;\nuniform vec2 u_size;\n" + fragment);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]), gl.STATIC_DRAW);
  }

  dispose() {
    this.gl?.getExtension("WEBGL_lose_context")?.loseContext();
  }

  draw(w: number, h: number, k: number, uniforms: Record<string, number | number[]>) {
    const gl = this.gl;
    if (!gl || !this.prog) return;
    sizeCanvas(this.canvas, w, h, k);
    gl.viewport(0, 0, this.canvas.width, this.canvas.height);
    gl.useProgram(this.prog);
    const a = gl.getAttribLocation(this.prog, "a_pos");
    gl.enableVertexAttribArray(a);
    gl.vertexAttribPointer(a, 2, gl.FLOAT, false, 0, 0);
    const loc = (name: string) => {
      if (!this.locs.has(name)) this.locs.set(name, gl.getUniformLocation(this.prog!, name));
      return this.locs.get(name)!;
    };
    gl.uniform2f(loc("u_size"), w, h);
    for (const [name, value] of Object.entries(uniforms)) {
      const l = loc(name);
      if (!l) continue;
      if (typeof value === "number") gl.uniform1f(l, value);
      else if (value.length === 2) gl.uniform2f(l, value[0], value[1]);
      else if (value.length === 3) gl.uniform3f(l, value[0], value[1], value[2]);
      else gl.uniform4f(l, value[0], value[1], value[2], value[3]);
    }
    gl.drawArrays(gl.TRIANGLES, 0, 6);
  }
}
