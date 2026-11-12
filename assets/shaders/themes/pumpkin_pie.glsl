// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a pumpkin pie seen from above: a fluted crust, the custard,
// a dollop of cream. A popped dot is the empty dish it was baked in, with
// crumbs. The vertex color says what kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;

const vec2 LIGHT = vec2(-0.53, -0.848);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 q) {
  return (noise(q) * 0.5 + noise(q * 2.03 + 7.1) * 0.25 + noise(q * 4.1 + 3.3) * 0.125) / 0.875;
}
// Coverage of a signed distance (negative inside), smoothed over one pixel.
float fill(float sd, float aa) { return clamp(-sd / aa + 0.5, 0.0, 1.0); }
// The four-pointed star every bonus dot carries, as a signed distance.
float star(vec2 p, vec2 c, float size) {
  vec2 q = abs(p - c) / size;
  return (sqrt(q.x) + sqrt(q.y) - 0.762) * size * 0.55;
}

const vec3 SHADOW = vec3(0.016, 0.008, 0.02);
const vec3 HALO = vec3(1.0, 0.75, 0.44);
const vec3 RIM = vec3(1.0, 0.886, 0.659);
const vec3 POP_RIM = vec3(0.478, 0.416, 0.439);
const float CRUST = 0.79;

// Round specks scattered on a grid of +cells+ a radius, +share+ of them there.
float specks(vec2 p, float cells, float size, float share, float s) {
  vec2 g = floor(p * cells);
  vec2 c = (g + 0.5 + 0.6 * (vec2(hash(g + s), hash(g + s + 7.0)) - 0.5)) / cells;
  return step(1.0 - share, hash(g + s + 3.0)) * (1.0 - smoothstep(size * 0.6, size, length(p - c)));
}

float ring(float d, float aa, float w) { return clamp((d - (1.0 - max(w, 1.5 * aa))) / aa + 0.5, 0.0, 1.0); }

vec3 dot_body(vec2 p, float d, float aa, float fresh, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  float lam = dot(vec3(p, z * 0.6), normalize(vec3(LIGHT, 0.9)));
  float ang = atan(p.y, p.x);
  float filling = fill(d - CRUST, aa);
  // The crust's fluted edge: a tube round the pie, crimped.
  float t = clamp((d - CRUST) / (1.0 - CRUST), 0.0, 1.0);
  float flute = 0.5 + 0.5 * cos(ang * 20.0 + seed);
  float tube = sin(t * 3.14159);
  vec2 radial = p / max(d, 1e-4);
  float lit_side = clamp(0.5 + 0.5 * dot(radial, LIGHT) * (1.0 - 2.0 * t), 0.0, 1.0);
  vec3 pastry = mix(vec3(0.78, 0.52, 0.24), vec3(1.0, 0.89, 0.66), clamp(0.25 + 0.6 * tube * (0.35 + 0.65 * flute) + 0.25 * lit_side, 0.0, 1.0));
  pastry *= 0.84 + 0.16 * flute;
  pastry = mix(pastry, vec3(0.78, 0.52, 0.26), smoothstep(0.62, 0.82, fbm(p * 6.0 + seed)) * 0.4);

  // The filling: smooth custard, darker toward the crust, a little spice.
  vec3 custard = mix(vec3(0.85, 0.52, 0.23), vec3(0.96, 0.67, 0.37), smoothstep(CRUST, 0.35, d));
  custard = mix(custard, vec3(1.0, 0.8, 0.55), (1.0 - smoothstep(0.0, 0.25, length(p - vec2(-0.3, -0.32)))) * 0.35);
  custard = mix(custard, vec3(0.62, 0.34, 0.14), specks(p, 9.0, 0.035, 0.35, seed) * 0.5);
  float cream_r = 0.27 + 0.03 * cos(ang * 6.0 + seed);
  float swirl = 0.5 + 0.5 * cos(ang * 2.0 + d * 26.0);
  vec3 cream = mix(vec3(0.9, 0.88, 0.84), vec3(1.0, 0.99, 0.96), swirl);
  vec3 lit = mix(custard, cream, fill(d - cream_r, aa));
  if (bonus > 0.5) {
    lit = mix(vec3(0.72, 0.95, 0.87), vec3(0.95, 1.0, 0.98), swirl * 0.6 + 0.2);
    lit = mix(lit, vec3(0.23, 0.13, 0.07), fill(star(p, vec2(0.0), 0.5), aa * 1.5));
    pastry = mix(pastry, vec3(0.85, 0.97, 0.92), 0.5);
  }
  lit = mix(pastry, lit, filling);

  // Eaten: the empty dish, crumbs and a smear left.
  float glaze = clamp(0.5 + 0.6 * dot(p, LIGHT), 0.0, 1.0);
  vec3 dish = mix(vec3(0.09, 0.06, 0.075), vec3(0.17, 0.12, 0.14), glaze);
  dish = mix(dish, vec3(0.27, 0.15, 0.1), smoothstep(0.58, 0.78, fbm(p * 3.0 + seed * 4.0)) * 0.3);
  float crumbs = specks(p, 8.0, 0.045, 0.14, seed + 11.0) * smoothstep(0.35, 0.65, d);
  dish = mix(dish, vec3(0.36, 0.26, 0.18), crumbs * 0.7);
  vec3 lip = mix(vec3(0.24, 0.18, 0.2), vec3(0.4, 0.34, 0.36), tube * glaze);
  vec3 dark = mix(lip, dish, filling);

  vec3 c = mix(dark, lit, fresh);
  return mix(c, mix(POP_RIM, RIM, fresh), ring(d, aa, mix(0.04, 0.055, fresh)));
}

vec4 effect(vec4 params, Image tex, vec2 uv, vec2 screen) {
  float fresh = params.r;
  float alarmed = params.g;
  float bonus = params.b;
  vec2 p = (uv * 2.0 - 1.0) * extent;
  float d = length(p);
  float aa = max(fwidth(d), 1e-4);
  float fade_out = 1.0 - smoothstep(extent - 0.1, extent, d);
  float s = (1.0 - smoothstep(shadow_reach - 0.2, shadow_reach, length(p - vec2(0.0, shadow_offset)))) * shadow_alpha;
  vec4 color = vec4(SHADOW * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(HALO * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = dot_body(p, d, aa, fresh, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
