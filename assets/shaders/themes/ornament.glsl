// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a glass ornament hanging on the tree, seen a little from
// above, fitting the dot's circle, its crimped brass cap on its top. A
// bright dot is mirrored gold glass: it reflects the warm room, a window's
// panes, the tree's lights and the dark line of the horizon, round a
// frosted band. A popped dot is the same ornament broken and in shadow: a
// shard gone from its face, so the hollow shows, and cracks running from
// the hole. Every broken one is broken alike. The vertex color says what
// kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;  // a bright dot's own, so each catches the lights its own way
uniform float time;  // seconds, for the lights' twinkle

const float TILT = 0.36;
const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec3 AMBER = vec3(0.55, 0.3, 0.07);
const vec3 GOLD = vec3(0.98, 0.76, 0.36);
const vec3 PALE = vec3(1.0, 0.95, 0.8);
const vec3 SHADE_DARK = vec3(0.09, 0.015, 0.03);
const vec3 SHADE_LIT = vec3(0.24, 0.04, 0.065);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// The hole the shard left, as a radius at each angle about its middle:
// long and short points in turn, so its edge is jagged. Fixed, so every
// broken ornament is broken the same.
const vec2 HOLE = vec2(0.2, 0.06);
float hole_radius(float i) {
  float k = mod(i, 9.0);
  if (k < 0.5) return 0.5;
  if (k < 1.5) return 0.26;
  if (k < 2.5) return 0.4;
  if (k < 3.5) return 0.32;
  if (k < 4.5) return 0.54;
  if (k < 5.5) return 0.27;
  if (k < 6.5) return 0.38;
  if (k < 7.5) return 0.22;
  return 0.34;
}
vec2 hole_point(float i) {
  float a = i * 6.28318 / 9.0 + 0.3;
  return HOLE + vec2(cos(a), sin(a)) * hole_radius(i);
}
float hole(vec2 p) {
  vec2 q = p - HOLE;
  float a = mod(atan(q.y, q.x) - 0.3, 6.28318);
  float k = a / (6.28318 / 9.0);
  float i = floor(k);
  vec2 a0 = hole_point(i) - HOLE, a1 = hole_point(i + 1.0) - HOLE;
  // Inside the triangle of the middle and this edge: the side of the edge.
  vec2 e = a1 - a0;
  vec2 n = normalize(vec2(e.y, -e.x));
  if (dot(-a0, n) > 0.0) n = -n;
  return dot(q - a0, n);
}
// The cracks: from the hole's long points out across the glass.
float cracks(vec2 p) {
  float c = 1.0;
  c = min(c, min(segment(p, hole_point(0.0), vec2(0.78, 0.22)), segment(p, vec2(0.78, 0.22), vec2(0.95, 0.3))));
  c = min(c, min(segment(p, hole_point(2.0), vec2(0.34, 0.72)), segment(p, vec2(0.34, 0.72), vec2(0.28, 0.95))));
  c = min(c, min(segment(p, hole_point(4.0), vec2(-0.5, 0.38)), segment(p, vec2(-0.5, 0.38), vec2(-0.82, 0.44))));
  c = min(c, min(segment(p, hole_point(6.0), vec2(-0.3, -0.42)), segment(p, vec2(-0.3, -0.42), vec2(-0.42, -0.66))));
  return c;
}

// How bright the room is in the direction +r+, seen in the mirrored glass:
// a ceiling's warm light above the horizon, the dark tree below it, a
// window up to the left, and the tree's lights near the horizon.
float room(vec3 r, vec3 up, float aa, float lights, float window) {
  float h = dot(r, up);
  float b = h > 0.0 ? mix(0.62, 1.05, smoothstep(0.0, 0.85, h)) : mix(0.5, 0.3, smoothstep(0.0, 0.6, -h));
  b *= 1.0 - 0.55 * exp(-pow(h / 0.07, 2.0));
  vec2 w = r.xy - vec2(-0.5, -0.5);
  vec2 box = abs(w) - vec2(0.17, 0.19);
  float win = length(max(box, 0.0)) + min(max(box.x, box.y), 0.0) - 0.04;
  float bars = min(abs(w.x), abs(w.y)) - 0.022;
  float pane = clamp(0.5 - win / (aa * 2.0), 0.0, 1.0) * clamp(0.5 + bars / (aa * 2.0), 0.0, 1.0);
  // Lit, the window shows its panes; in shadow, only a soft sheen.
  float soft = smoothstep(0.12, -0.16, win) * smoothstep(-0.1, 0.2, r.z);
  b = window > 0.5 ? mix(b, 1.75, pane * step(0.0, r.z)) : b + 0.6 * soft;
  b += lights;
  return b;
}
vec3 gold_glass(float b) {
  vec3 c = mix(AMBER, GOLD, smoothstep(0.12, 0.8, b));
  c = mix(c, PALE, smoothstep(0.8, 1.3, b));
  return mix(c, vec3(1.0, 0.99, 0.95), smoothstep(1.3, 1.7, b));
}
vec3 ice_glass(float b) {
  vec3 c = mix(vec3(0.24, 0.35, 0.55), vec3(0.72, 0.85, 0.98), smoothstep(0.12, 0.8, b));
  c = mix(c, vec3(0.92, 0.97, 1.0), smoothstep(0.8, 1.3, b));
  return mix(c, vec3(1.0), smoothstep(1.3, 1.7, b));
}
vec3 shade_glass(float b) {
  return mix(SHADE_DARK, SHADE_LIT, smoothstep(0.1, 1.4, b));
}

vec3 ornament(vec2 p, float d, float aa, float bright_look, float bonus) {
  float z = sqrt(max(1.0 - min(d, 0.9999) * min(d, 0.9999), 0.0));
  float ca = cos(TILT), sa = sin(TILT);
  vec3 n = vec3(p, z);
  vec3 up = vec3(0.0, -ca, sa);
  vec3 r = 2.0 * z * n - vec3(0.0, 0.0, 1.0);
  float lat = asin(clamp(dot(n, up), -1.0, 1.0));
  float th = atan(p.x, p.y * sa + z * ca);
  float lam = clamp(dot(n, L), 0.0, 1.0);

  // The tree's lights, a few warm points along the horizon, twinkling.
  float lights = 0.0;
  for (int i = 0; i < 5; i++) {
    float fi = float(i);
    float a = fi * 1.31 + seed * 2.7;
    vec3 dir = normalize(vec3(sin(a) * 0.9, -0.05 - 0.22 * fract(fi * 0.61 + seed), cos(a) * 0.9 + 0.35));
    float g = exp(-pow(acos(clamp(dot(normalize(r), dir), -1.0, 1.0)) / 0.05, 2.0));
    lights += g * (0.75 + 0.25 * sin(time * (2.0 + fi) + seed * 5.0 + fi));
  }
  float b = room(r, up, max(fwidth(r.x), 1e-4), lights, 1.0);
  float fres = pow(1.0 - z, 3.0);
  b = mix(b, 1.15, fres * 0.5);
  // Warm light thrown back from below, along the lower right of the glass.
  b += 0.45 * smoothstep(0.55, 0.95, d) * smoothstep(-0.1, 0.7, dot(p / max(d, 1e-3), vec2(0.45, 0.89)));

  vec3 bright = bonus > 0.5 ? ice_glass(b) : gold_glass(b);
  float b0 = mix(room(r, up, max(fwidth(r.x), 1e-4), 0.0, 0.0), 1.15, fres * 0.3);
  vec3 dark = shade_glass(mix(b0, 0.6, 0.15));
  // Still glass in the dark: only the faintest light along its rim, so
  // nothing in a broken ornament is bright.
  dark += vec3(0.08, 0.025, 0.03) * smoothstep(0.82, 0.98, d) * clamp(0.3 + 0.9 * dot(p / max(d, 1e-3), vec2(-0.53, -0.848)), 0.0, 1.0);

  // The frosted band round the middle, with a red rickrack along it.
  float band_w = 0.13;
  float lw = max(fwidth(lat), 1e-4);
  float in_band = clamp(0.5 - (abs(lat) - band_w) / lw, 0.0, 1.0);
  float grain = step(0.86, hash(floor(vec2(th * 38.0, lat * 38.0))));
  vec3 frost = mix(vec3(0.83, 0.79, 0.72), vec3(1.0, 0.99, 0.95), 0.35 + 0.65 * lam);
  frost = mix(frost, vec3(1.0), grain * 0.5 * lam);
  float zig = abs(lat - 0.075 * (2.0 * abs(fract(th * 2.6) - 0.5) * 2.0 - 1.0)) - 0.026;
  float edge_line = abs(abs(lat) - band_w + 0.012) - 0.012;
  float red = max(cover_of(zig, lw * 1.5), cover_of(edge_line, lw * 1.5)) * step(abs(th), 1.7);
  vec3 berry = bonus > 0.5 ? vec3(0.12, 0.2, 0.5) : vec3(0.78, 0.09, 0.12);
  frost = mix(frost, berry * (0.6 + 0.5 * lam) + vec3(0.25, 0.15, 0.1) * grain * lam, red);
  bright = mix(bright, frost, in_band);
  vec3 dull = mix(vec3(0.12, 0.1, 0.1), vec3(0.22, 0.19, 0.19), lam);
  dull = mix(dull, vec3(0.2, 0.04, 0.055), red);
  dark = mix(dark, dull, in_band);

  // The bonus ornament's star, painted on the glass above the band.
  if (bonus > 0.5) {
    vec2 sq = abs(p - vec2(0.0, -0.2)) / 0.5;
    float st = (sqrt(sq.x) + sqrt(sq.y) - 0.76) * 0.5;
    bright = mix(bright, vec3(0.08, 0.12, 0.34), cover_of(st, aa * 1.5));
  }

  // The broken one: the hollow through the hole, its edge, and cracks.
  float hd = hole(p);
  float in_hole = cover_of(hd, aa);
  vec3 hollow = mix(vec3(0.012, 0.008, 0.006), vec3(0.11, 0.08, 0.05), smoothstep(0.1, -0.35, p.y - p.x * 0.4) * smoothstep(0.0, -0.12, hd));
  float lip = cover_of(abs(hd + 0.018) - 0.014, aa) * clamp(0.35 + 1.4 * dot(normalize(p - HOLE + 1e-4), vec2(-0.53, -0.848)), 0.0, 1.0);
  float ck = cracks(p);
  float crack_line = cover_of(ck - 0.018, aa) * (1.0 - in_hole);
  float crack_shadow = cover_of(ck - 0.045, aa) * (1.0 - in_hole);
  dark = mix(dark, dark * 0.4, crack_shadow);
  dark = mix(dark, vec3(0.025, 0.008, 0.012), crack_line);
  dark = mix(dark, hollow, in_hole);
  dark = mix(dark, vec3(0.2, 0.13, 0.12), lip * (1.0 - in_hole * 0.3));

  vec3 c = mix(dark, bright, bright_look);

  // The cap: a crimped brass collar at the top, seen from above.
  float cx = p.x / 0.2;
  float top_y = -0.95, bot_y = -0.76;
  float ang = asin(clamp(cx, -1.0, 1.0));
  float skirt = bot_y + 0.05 * sqrt(max(1.0 - cx * cx, 0.0)) + 0.018 * abs(sin(ang * 6.0));
  float cap_sd = max(abs(p.x) - 0.2 + 0.03 * smoothstep(-0.83, top_y, p.y), max(p.y - skirt, top_y - p.y));
  float lid = (length(vec2(p.x / 0.18, (p.y - top_y) / 0.045)) - 1.0) * 0.045;
  float in_cap = max(cover_of(cap_sd, aa), cover_of(lid, aa));
  float rib = 0.5 + 0.5 * cos(ang * 14.0);
  float cyl = clamp(0.55 - 0.6 * cx + 0.25 * cos(ang), 0.0, 1.2);
  vec3 brass = mix(vec3(0.42, 0.29, 0.1), vec3(1.0, 0.86, 0.52), clamp(cyl * (0.7 + 0.3 * rib), 0.0, 1.0));
  brass = mix(brass, vec3(1.0, 0.97, 0.86), smoothstep(0.85, 1.0, cyl * (0.8 + 0.2 * rib)) * 0.7);
  vec3 iron = mix(vec3(0.08, 0.075, 0.075), vec3(0.25, 0.24, 0.23), clamp(cyl * (0.7 + 0.3 * rib), 0.0, 1.0));
  float on_lid = cover_of(lid, aa);
  brass = mix(brass, mix(vec3(0.62, 0.48, 0.22), vec3(0.95, 0.82, 0.5), smoothstep(0.1, -0.12, p.x)), on_lid);
  iron = mix(iron, vec3(0.2, 0.19, 0.18), on_lid);
  // The wire loop, a small arch on the lid.
  float loop = abs(length(vec2(p.x / 0.07, (p.y - top_y + 0.005) / 0.035)) - 1.0) * 0.035 - 0.006;
  float in_loop = cover_of(loop, aa) * step(p.y, top_y);
  vec3 cap = mix(iron, brass, bright_look);
  cap = mix(cap, mix(vec3(0.16, 0.14, 0.12), vec3(0.85, 0.85, 0.82), bright_look), in_loop);
  // The cap's shadow on the glass just below it.
  float shade = exp(-max(p.y - skirt, 0.0) / 0.05) * step(abs(p.x), 0.22) * (1.0 - in_cap);
  c *= 1.0 - shade * 0.45 * smoothstep(0.24, 0.12, abs(p.x));
  c = mix(c, cap, max(in_cap, in_loop));

  float w = mix(max(0.038, 1.5 * aa), max(0.024, 1.5 * aa), bright_look);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.17, 0.13, 0.12), vec3(0.3, 0.24, 0.22), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       bonus > 0.5 ? vec3(0.9, 0.96, 1.0) : vec3(1.0, 0.93, 0.7), bright_look);
  return mix(c, rim_color, ring);
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
  vec4 color = vec4(vec3(0.008, 0.016, 0.012) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * bright_look * fade_out;
  color = over(vec4(vec3(1.0, 0.85, 0.54) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = ornament(p, d, aa, bright_look, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
