// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a glass ornament on a tree. A bright dot is lit gold glass,
// glowing from within, with a frosted band and the window's reflection;
// a popped dot is the same ornament in dark glass, its light out. The
// cap stays inside the circle. The vertex color says what kind of dot it
// is, as in dot.glsl.

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

const vec3 SHADOW = vec3(0.008, 0.024, 0.02);
const vec3 HALO = vec3(1.0, 0.851, 0.541);
const vec3 GOLD_HI = vec3(1.0, 0.98, 0.9);
const vec3 GOLD = vec3(1.0, 0.902, 0.659);
const vec3 GOLD_DEEP = vec3(0.851, 0.643, 0.263);
const vec3 RIM = vec3(1.0, 0.973, 0.878);
const vec3 POP_RIM = vec3(0.435, 0.51, 0.475);

float ring(float d, float aa, float w) { return clamp((d - (1.0 - max(w, 1.5 * aa))) / aa + 0.5, 0.0, 1.0); }

// The window's reflection, a soft rounded patch up toward the light.
float window(vec2 p) {
  vec2 q = p - vec2(-0.36, -0.4);
  float c = 0.766, s = 0.643;
  q = vec2(c * q.x + s * q.y, -s * q.x + c * q.y);
  return 1.0 - smoothstep(0.7, 1.0, length(q / vec2(0.24, 0.13)));
}

// The crimped cap on top, inside the circle, as a signed distance.
float cap(vec2 p) {
  vec2 q = p - vec2(0.0, -0.86);
  float crimp = 0.02 * cos(q.x * 70.0);
  return max(abs(q.x) - 0.19, max(-0.16 - q.y, q.y - (0.12 + crimp)));
}

vec3 dot_body(vec2 p, float d, float aa, float fresh, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  float lam = dot(vec3(p, z), normalize(vec3(LIGHT, 0.9)));
  float win = window(p);
  float lat = p.y + 0.3 * z;
  float band = 1.0 - smoothstep(0.08, 0.12, abs(lat - 0.36));
  float glint = step(0.93, hash(floor((p + seed) * 46.0))) * band;

  // Lit: gold glass glowing from within, a frosted band, the window.
  vec3 lit = mix(GOLD_DEEP, GOLD, clamp(0.5 + 0.65 * lam, 0.0, 1.0));
  lit = mix(lit, GOLD_HI, exp(-d * d / 0.3) * 0.5);
  lit = mix(lit, mix(vec3(1.0, 0.93, 0.76), GOLD_HI, 0.5 + 0.5 * noise(p * 30.0 + seed)), band * 0.85);
  lit = mix(lit, vec3(1.0), glint * 0.9);
  lit = mix(lit, vec3(1.0), win * 0.85);
  if (bonus > 0.5) {
    vec3 ice = mix(vec3(0.62, 0.878, 0.8), vec3(0.902, 1.0, 0.965), clamp(0.5 + 0.65 * lam, 0.0, 1.0));
    lit = mix(ice, vec3(1.0), max(win * 0.85, glint * 0.9));
    lit = mix(lit, vec3(0.063, 0.133, 0.227), fill(star(p, vec2(0.0, 0.08), 0.5), aa * 1.5));
  }

  // Popped: the same ornament in dark glass, its light out.
  vec3 glass = vec3(0.24, 0.047, 0.078);
  vec3 dark = glass * (0.45 + 0.75 * clamp(0.5 + 0.6 * lam, 0.0, 1.0));
  dark = mix(dark, vec3(0.32, 0.34, 0.33), win * 0.4);
  dark = mix(dark, glass * 1.4, band * 0.4);

  vec3 c = mix(dark, lit, fresh);
  float sd = cap(p);
  float in_cap = fill(sd, aa);
  float ridge = 0.5 + 0.5 * cos(p.x * 70.0);
  vec3 metal = mix(mix(vec3(0.16, 0.17, 0.17), vec3(0.3, 0.31, 0.3), ridge),
                   mix(vec3(0.76, 0.6, 0.3), vec3(0.98, 0.88, 0.6), ridge), fresh);
  c = mix(c, metal, in_cap);
  c = mix(c, mix(vec3(0.03), vec3(0.45, 0.32, 0.12), fresh), in_cap * (1.0 - smoothstep(0.0, 0.02, abs(sd + 0.004))) * 0.6);
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
