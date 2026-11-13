// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a jack-o'-lantern: a solid pumpkin seen from slightly above,
// fitting the dot's circle exactly. The whole dot obeys the one viewpoint:
// the ribs meet at the stem on top, and the bottom of the fruit is out of
// sight. Each lobe is lit as its own bulge, with a narrow dark crease
// between lobes, a little uneven from lobe to lobe; the carved face lies
// on the surface, so it wraps with it. The vertex color says what kind of
// dot it is, as in dot.glsl. A popped dot is the same pumpkin unlit.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;  // this dot's own, so each is its own pumpkin
uniform float time;  // seconds, for the candle's flicker

const float TILT = 0.60;
const float LOBES = 11.0;
const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec3 HALF_V = vec3(-0.2288, -0.3378, 0.9130);
const vec3 HOT = vec3(1.0, 0.965, 0.76);
const vec3 FLAME = vec3(1.0, 0.839, 0.302);
const vec3 BRIGHT = vec3(1.0, 0.541, 0.118);
const vec3 DEEP = vec3(0.714, 0.282, 0.043);
const vec3 CREASE = vec3(0.361, 0.114, 0.020);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float halfplane(vec2 p, vec2 a, vec2 b, vec2 inward) {
  vec2 e = b - a;
  vec2 n = normalize(vec2(e.y, -e.x));
  if (dot(inward - a, n) > 0.0) n = -n;
  return dot(p - a, n);
}
float tri(vec2 p, vec2 a, vec2 b, vec2 c) {
  vec2 m = (a + b + c) / 3.0;
  return max(halfplane(p, a, b, m), max(halfplane(p, b, c, m), halfplane(p, c, a, m)));
}
float eye(vec2 p, float side, float tilt) {
  vec2 c = vec2(side * 0.44, 0.68);
  float s = 0.19;
  float cs = cos(tilt * side), sn = sin(tilt * side);
  mat2 r = mat2(cs, -sn, sn, cs);
  vec2 q = r * (p - c) + c;
  return tri(q, c + vec2(side * 0.05, s * 1.05), c + vec2(-s * 1.25, -s * 0.75), c + vec2(s * 1.25, -s * 0.75));
}
float star(vec2 p, vec2 c) {
  vec2 q = abs(p - c);
  return (sqrt(q.x) + sqrt(q.y) - 0.62) * 0.55;
}
float tooth(vec2 p, float tx, float top, float bot, bool is_top) {
  return max(abs(p.x - tx) - 0.1, is_top ? (top - 0.15) - p.y : p.y - (bot + 0.15));
}
// The carved openings, on the surface (longitude x, latitude y, in
// radians of arc). Negative inside.
float carved(vec2 p, float variant, float bonus) {
  float tilt = variant < 0.5 ? 0.0 : (variant < 1.5 ? 0.1 : -0.08);
  float eyes = bonus > 0.5 ? min(star(p, vec2(0.44, 0.68)), star(p, vec2(-0.44, 0.68)))
                           : min(eye(p, 1.0, tilt), eye(p, -1.0, tilt));
  float nose = tri(p, vec2(0.0, 0.47), vec2(-0.11, 0.29), vec2(0.11, 0.29));
  float k = 0.83;
  float u2 = 1.0 - (p.x / k) * (p.x / k);
  float top = 0.26 - 0.18 * u2;
  float bot = 0.26 - 0.48 * u2;
  float mouth = max(max(p.y - top, bot - p.y), abs(p.x) - k);
  float teeth;
  if (variant < 0.5) {
    teeth = min(tooth(p, -0.4, top, bot, true), min(tooth(p, 0.4, top, bot, true), tooth(p, 0.0, top, bot, false)));
  } else if (variant < 1.5) {
    teeth = min(min(tooth(p, -0.2, top, bot, true), tooth(p, 0.24, top, bot, true)),
                min(tooth(p, -0.54, top, bot, false), tooth(p, 0.56, top, bot, false)));
  } else {
    teeth = min(min(tooth(p, -0.46, top, bot, true), tooth(p, 0.02, top, bot, true)),
                min(tooth(p, 0.48, top, bot, true), min(tooth(p, -0.24, top, bot, false), tooth(p, 0.26, top, bot, false))));
  }
  mouth = max(mouth, -teeth);
  return min(min(eyes, nose), mouth);
}
vec4 pumpkin(vec2 p, float d, float aa, float bright_look, float bonus) {
  float z = sqrt(max(1.0 - min(d, 0.9999) * min(d, 0.9999), 0.0));
  float ca = cos(TILT), sa = sin(TILT);
  float pu = -p.y * ca + z * sa;
  float pf = p.y * sa + z * ca;
  float th = atan(p.x, pf);
  float lat = asin(clamp(pu, -1.0, 1.0));
  float s = mod(seed * 9.99 + 3.0, 6.283);
  float wob = 0.012 * sin(lat * 2.1 + s + th * 2.0);
  float ang = th + wob + s * 0.2;
  float u = ang * LOBES / 6.28318;
  float v = u + 0.1 * sin(ang * 2.0 + s) + 0.05 * sin(ang * 5.0 + s * 1.7);
  float i = floor(v);
  float t = v - i;
  float edge = min(t, 1.0 - t);
  // The face is carved on a smoothed patch of the fruit, so the creases
  // stop before the knife does.
  float zone = smoothstep(0.74, 1.08, length(vec2(th / 1.05, (lat - 0.28) / 0.72)));
  vec3 east = vec3(cos(th), -sin(th) * sa, -sin(th) * ca);
  vec3 n = normalize(vec3(p, z) + east * (t * 2.0 - 1.0) * 1.05 * (0.15 + 0.85 * zone));
  float lam = dot(n, L);
  float spec = pow(max(dot(n, HALF_V), 0.0), 26.0);
  float jitter = sin(i * 7.3 + seed);

  // One of three faces, the pumpkin's own, so it keeps its face as its
  // candle goes out.
  float variant = mod(floor(seed), 3.0);
  float fd = carved(vec2(th, lat), variant, bonus);
  if (abs(th) > 1.35) fd = 1.0;
  float back = carved(vec2(th, lat + 0.075), variant, bonus);
  float back_cold = carved(vec2(th, lat + 0.05), variant, bonus);
  float fw = max(fwidth(fd), 1e-4);
  float inside = clamp(-fd / fw + 0.5, 0.0, 1.0);

  float clear = smoothstep(0.04, 0.16, fd) * zone;
  float crease = 1.0 - (1.0 - (1.0 - exp(-pow(edge / 0.05, 1.4)))) * clear;
  float ao = 1.0 - (1.0 - smoothstep(0.0, 0.32, edge)) * clear;

  vec3 lit = mix(DEEP, BRIGHT, clamp(0.25 + lam * 0.95, 0.0, 1.0));
  lit = mix(lit, vec3(1.0, 0.765, 0.416), clamp(lam - 0.55, 0.0, 1.0) * 0.55);
  lit *= 1.0 + jitter * 0.05;
  lit = mix(lit, vec3(1.0, 0.914, 0.722), spec * 0.55);
  lit *= 0.6 + 0.4 * ao;
  lit = mix(CREASE, lit, crease);

  vec3 dark = mix(vec3(0.102, 0.063, 0.086), vec3(0.227, 0.141, 0.157), clamp(lam * 1.1, 0.0, 1.0));
  dark *= 1.0 + jitter * 0.04;
  dark = mix(dark, vec3(0.173, 0.102, 0.125), spec * 0.55);
  dark = mix(vec3(0.027, 0.016, 0.024), dark, crease) * (0.55 + 0.45 * ao);

  float flicker = 0.92 + 0.08 * sin(time * 17.0 + seed) * sin(time * 7.3 + seed * 2.0);
  float spill = exp(-max(fd, 0.0) / 0.05);
  lit = mix(lit, vec3(1.0, 0.71, 0.29), spill * spill * 0.45 * flicker);
  float center = exp(-pow(max(-fd, 0.0) / 0.05, 2.0));
  vec3 hot = bonus > 0.5 ? mix(vec3(0.957, 1.0, 0.824), vec3(0.717, 1.0, 0.431), pow(center, 0.7))
                         : mix(HOT, FLAME, pow(center, 0.7));
  // Looked into from above, each cut's far wall stands lit, the hot light behind it.
  vec3 wall_col = mix(vec3(1.0, 0.478, 0.078), vec3(1.0, 0.722, 0.27), clamp(-fd / 0.06, 0.0, 1.0));
  hot = mix(hot, wall_col, step(0.0, back));
  vec3 fire = mix(lit, hot * flicker, inside);
  fire = mix(fire, vec3(0.663, 0.267, 0.047), inside * (1.0 - smoothstep(0.0, 0.012, -fd)) * 0.9);

  vec3 cold = mix(dark, vec3(0.341, 0.251, 0.22), (1.0 - smoothstep(0.0, 0.012, abs(fd))) * 0.55 * step(0.0, fd));
  cold = mix(cold, vec3(0.11, 0.075, 0.063), inside * step(0.0, back_cold));
  cold = mix(cold, vec3(0.016, 0.008, 0.012), inside * step(back_cold, 0.0));

  vec3 c = mix(cold, fire, bright_look);
  float dimple = exp(-pow(p.x / 0.22, 2.0) - pow((p.y + ca) / 0.13, 2.0));
  c = mix(c, mix(vec3(0.039, 0.024, 0.031), CREASE, bright_look), dimple * 0.55);

  // The stem, on the crown, and inside the circle.
  float py = -ca, top_y = -0.965;
  float ss = clamp((py + 0.03 - p.y) / (py + 0.03 - top_y), 0.0, 1.0);
  float lean = -0.03 * ss;
  float hw = 0.135 - 0.06 * ss + 0.018 * sin(ss * 20.0);
  float body = max(abs(p.x - lean) - hw, max(p.y - (py + 0.05), top_y - p.y));
  float base = (length(vec2(p.x / 0.165, (p.y - py - 0.01) / 0.07)) - 1.0) * 0.07;
  float sd = min(body, base);
  float in_stem = clamp(-sd / aa + 0.5, 0.0, 1.0);
  float su = clamp((p.x - lean) / max(hw, 0.03), -1.0, 1.0);
  float ridge = 0.5 + 0.5 * cos(su * 8.5 + ss * 1.3);
  vec3 stem = mix(mix(vec3(0.11, 0.141, 0.086), vec3(0.18, 0.227, 0.133), ridge),
                  mix(vec3(0.247, 0.353, 0.141), vec3(0.494, 0.604, 0.267), ridge), bright_look);
  c = mix(c, stem, in_stem);
  float cap = (length(vec2((p.x - lean) / max(hw * 0.85, 0.03), (p.y + 0.958) / 0.03)) - 1.0) * 0.03;
  c = mix(c, mix(vec3(0.333, 0.4, 0.235), vec3(0.812, 0.863, 0.573), bright_look),
          clamp(-cap / aa + 0.5, 0.0, 1.0) * in_stem * 0.85);

  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), bright_look);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.239, 0.184, 0.176), vec3(0.416, 0.329, 0.314), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       vec3(1.0, 0.839, 0.565), bright_look);
  c = mix(c, rim_color, ring);
  return vec4(c, 1.0);
}
vec4 effect(vec4 params, Image tex, vec2 uv, vec2 screen) {
  float bright_look = params.r;
  float alarmed = params.g;
  float bonus = params.b;
  vec2 p = (uv * 2.0 - 1.0) * extent;
  float d = length(p);
  float aa = max(fwidth(d), 1e-4);
  float fade_out = 1.0 - smoothstep(extent - 0.1, extent, d);
  float s = (1.0 - smoothstep(shadow_reach - 0.2, shadow_reach, length(p - vec2(0.0, shadow_offset)))) * shadow_alpha;
  vec4 color = vec4(vec3(0.016, 0.008, 0.031) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * bright_look * fade_out;
  color = over(vec4(vec3(1.0, 0.698, 0.29) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = pumpkin(p, d, aa, bright_look, bonus).rgb;
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
