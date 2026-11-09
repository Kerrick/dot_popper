// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a moon. A fresh dot is a harvest moon: warm cream, soft seas
// and craters. A popped dot is the same moon in eclipse, near black with a
// thin ember rim. A bright dot sliding out from under a popped one is
// then, literally, a crescent. The vertex color says what kind of dot it
// is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;

const vec3 MOON = vec3(1.0, 0.941, 0.784);
const vec3 MARE = vec3(0.851, 0.639, 0.353);
const vec3 RIM = vec3(1.0, 0.961, 0.847);
const vec2 LIGHT = vec2(-0.53, -0.848);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 q) {
  return (noise(q) * 0.5 + noise(q * 2.03 + 7.1) * 0.25 + noise(q * 4.1 + 3.3) * 0.125 + noise(q * 8.0 + 1.7) * 0.0625) / 0.9375;
}
vec3 moon(vec2 p, float d, float aa, float bonus) {
  float sc = sin(seed * 2.4), cc = cos(seed * 2.4);
  vec2 q = vec2(cc * p.x - sc * p.y, sc * p.x + cc * p.y);
  float n = fbm(q * 2.1 + seed);
  float mare = smoothstep(0.42, 0.68, n) * (1.0 - smoothstep(0.65, 0.92, d));
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  vec3 c = mix(MOON, MARE, mare * 0.5);
  c = mix(c, MARE, smoothstep(0.6, 0.75, fbm(q * 9.0 - seed)) * 0.14);
  for (int i = 0; i < 8; i++) {
    float fi = float(i);
    vec2 cp = vec2(sin(fi * 2.399 + seed), cos(fi * 3.11 + seed * 0.7)) * (0.3 + 0.35 * fract(fi * 0.37 + seed));
    float r = 0.04 + 0.09 * fract(fi * 0.71 + seed * 0.3);
    float dd = length(q - cp);
    c = mix(c, vec3(0.788, 0.561, 0.306), (1.0 - smoothstep(r * 0.75, r, dd)) * 0.35);
    c = mix(c, vec3(1.0, 0.976, 0.902), smoothstep(r, r * 1.25, dd) * (1.0 - smoothstep(r * 1.25, r * 1.7, dd)) * 0.45);
  }
  float lam = 0.84 + 0.26 * clamp(z * 0.55 + dot(p, LIGHT) * 0.55, -1.0, 1.0);
  c *= lam;
  c = mix(c, RIM, smoothstep(0.86, 0.99, d) * 0.55);
  if (bonus > 0.5) {
    vec3 cold = mix(vec3(0.875, 0.957, 1.0), vec3(0.624, 0.816, 0.949), smoothstep(-0.6, 0.5, -dot(p, LIGHT)));
    c = mix(c, cold * dot(c, vec3(0.333)) / 0.91, 0.9);
    vec2 a = abs(p);
    c = mix(c, vec3(0.063, 0.086, 0.227), clamp((0.762 - (sqrt(a.x) + sqrt(a.y))) / max(aa * 3.0, 1e-4) + 0.5, 0.0, 1.0));
  }
  float ring = clamp((d - (1.0 - max(0.03, 1.5 * aa))) / aa + 0.5, 0.0, 1.0);
  return mix(c, RIM, ring);
}
vec3 eclipsed(vec2 p, float d, float aa) {
  float lit = clamp(dot(p, LIGHT), -1.0, 1.0);
  vec3 c = mix(vec3(0.051, 0.031, 0.071), vec3(0.145, 0.063, 0.102), clamp(0.5 + 0.5 * lit, 0.0, 1.0) * 0.9);
  c = mix(c, vec3(0.416, 0.149, 0.086), exp((d - 1.0) / 0.09) * 0.6 * clamp(0.65 + 0.45 * lit, 0.0, 1.0));
  float ring = clamp((d - (1.0 - max(0.04, 1.5 * aa))) / aa + 0.5, 0.0, 1.0);
  return mix(c, mix(vec3(0.416, 0.157, 0.094), vec3(0.878, 0.388, 0.184), clamp(0.45 + 0.55 * lit, 0.0, 1.0)), ring);
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
  vec4 color = vec4(vec3(0.008, 0.008, 0.039) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(vec3(1.0, 0.851, 0.549) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = fresh > 0.001 ? mix(eclipsed(p, d, aa), moon(p, d, aa, bonus), fresh) : eclipsed(p, d, aa);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
