// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// A theme's sky, drawn once into a canvas at the screen's full resolution
// when the theme is put on (Shell::Scene), so it costs nothing per frame.
// A gradient, a low glow, soft cloud, stars, and a vignette; fog is drawn
// over the scenery by a second pass.

uniform vec2 size;
uniform vec3 top;
uniform vec3 mid;
uniform vec3 bottom;
uniform vec3 glow;
uniform vec2 glow_at;
uniform float glow_amount;
uniform vec3 edge;
uniform float stars;
uniform vec3 fog;
uniform float fog_amount;
uniform float pass;  // 0: sky; 1: fog over the scenery

float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 q) {
  return (noise(q) * 0.5 + noise(q * 2.03 + 7.1) * 0.25 + noise(q * 4.1 + 3.3) * 0.125) / 0.875;
}
float starfield(vec2 p, float cell) {
  vec2 g = floor(p / cell);
  vec2 c = (g + vec2(hash(g), hash(g + 13.0))) * cell;
  float lit = step(0.82, hash(g + 71.0));
  return lit * exp(-pow(length(p - c) / (cell * 0.022), 2.0)) * (0.3 + 0.7 * hash(g + 5.0));
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
  float aspect = size.x / size.y;
  vec2 p = uv * size;
  float n = fbm(vec2(uv.x * aspect, uv.y) * 3.5);
  if (pass > 0.5) {
    float m = fbm(vec2(uv.x * 2.2 + 5.0, uv.y * 14.0)) * smoothstep(0.72, 1.0, uv.y);
    return vec4(fog, clamp(smoothstep(0.35, 0.75, m / max(smoothstep(0.72, 1.0, uv.y), 0.01)) * smoothstep(0.72, 1.0, uv.y) * fog_amount, 0.0, 1.0));
  }
  vec3 c = uv.y < 0.5 ? mix(top, mid, smoothstep(0.1, 0.5, uv.y)) : mix(mid, bottom, smoothstep(0.5, 1.0, uv.y));
  c *= 0.93 + 0.14 * n;
  vec2 g = (uv - glow_at) * vec2(aspect, 1.0);
  c = mix(c, glow, exp(-dot(g, g) / 0.09) * glow_amount);
  float s = max(starfield(p, 34.0), starfield(p + 91.0, 53.0)) * (1.0 - smoothstep(0.4, 0.68, uv.y)) * stars;
  c = mix(c, vec3(0.92, 0.91, 1.0), s);
  c = mix(c, edge, smoothstep(0.8, 1.45, length((uv - vec2(0.5, 0.45)) * 2.0)) * 0.7);
  c += (fract(sin(dot(screen, vec2(12.9898, 78.233))) * 43758.5453) - 0.5) / 255.0;
  return vec4(c, 1.0);
}
