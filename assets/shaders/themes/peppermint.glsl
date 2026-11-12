// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a peppermint, a round hard candy seen from above that fills
// the dot's circle: a starlight mint, white candy with red wedges swirled
// about its middle like a pinwheel, each widening out to the edge so the
// red goes round the outside and the white makes a star in the middle,
// under a glossy dome. A bright dot is a whole mint in the light. A
// popped dot is the same mint crunched, in shadow: cracked through into
// three pieces, the dark gaps between them showing, its stripes deep red
// and its white gone slate.
// Every crunched mint is cracked alike. The bonus mint is a spearmint,
// green-striped, with a dark star at its heart. The vertex color says
// what kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform float time;

const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec3 HALF_V = vec3(-0.2288, -0.3378, 0.9130);
const float STRIPES = 8.0;

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float hash1(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }

// How far +p+ is inside a red stripe, as a signed distance in radii:
// negative inside. The stripes swirl about the middle and widen outward
// all the way to the edge, leaving a white star in the middle.
float stripe(vec2 p) {
  float r = length(p);
  float a = atan(p.y, p.x) + 1.1 * r - 0.25;
  float f = fract(a * STRIPES / 6.28318) - 0.5;
  float half_w = mix(0.03, 0.3, smoothstep(0.12, 0.9, r));
  float across = (abs(f) - half_w) * 6.28318 / STRIPES * max(r, 0.05);
  return max(across, 0.12 - r);
}

// The three cracks of a crunched mint, as a distance from the nearest,
// in radii, and which of the three pieces +p+ lies in.
const vec2 BREAK = vec2(0.07, -0.04);
float crack_line(vec2 p, float angle, float phase) {
  vec2 dir = vec2(cos(angle), sin(angle));
  vec2 q = p - BREAK;
  float along = dot(q, dir);
  float across = q.x * dir.y - q.y * dir.x;
  // A jagged line: it wanders, with a few sharp kinks, more toward the
  // edge where the mint broke apart.
  float zig = (0.03 * sin(along * 9.0 + phase * 6.0) + 0.018 * sin(along * 23.0 + phase * 11.0)
               + 0.012 * (abs(fract(along * 4.3 + phase) - 0.5) * 4.0 - 1.0)) * smoothstep(0.0, 0.35, along);
  float wide = mix(0.01, 0.05, smoothstep(0.15, 1.0, along));
  return along < 0.0 ? 9.0 : abs(across - zig) - wide;
}
float cracks(vec2 p) {
  return min(crack_line(p, -1.85, 0.2), min(crack_line(p, 0.32, 0.6), crack_line(p, 2.45, 0.1)));
}
float piece(vec2 p) {
  float a = atan(p.y - BREAK.y, p.x - BREAK.x);
  if (a > -1.85 && a < 0.32) return 0.0;
  if (a >= 0.32 && a < 2.45) return 1.0;
  return 2.0;
}

vec3 mint(vec2 p, float d, float aa, float fresh, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  // A low dome: the candy rises gently to its middle and rounds off at
  // its edge.
  float dome = 0.55 + 0.45 * smoothstep(1.0, 0.7, d);
  vec3 n = normalize(vec3(p * (1.1 - 0.6 * dome), 0.6 + z));
  float lam = clamp(0.3 + 0.8 * dot(n, L), 0.0, 1.0);
  float spec = pow(max(dot(n, HALF_V), 0.0), 40.0);

  // --- Whole, in the light ---
  float sd = stripe(p);
  float in_stripe = cover_of(sd, aa);
  float grain = hash1(floor(p * 90.0)) - 0.5;
  vec3 white = mix(vec3(0.84, 0.82, 0.86), vec3(1.0, 0.985, 0.975), clamp(lam * 1.15, 0.0, 1.0));
  white *= 1.0 + 0.025 * grain;
  vec3 red_lo = bonus > 0.5 ? vec3(0.05, 0.42, 0.24) : vec3(0.62, 0.04, 0.09);
  vec3 red_hi = bonus > 0.5 ? vec3(0.32, 0.86, 0.52) : vec3(0.98, 0.2, 0.22);
  vec3 red = mix(red_lo, red_hi, clamp(lam * 1.1, 0.0, 1.0));
  // Each stripe is a little deeper in its middle, so it reads as color
  // set into the candy, not painted on.
  red *= 0.85 + 0.15 * smoothstep(-0.05, 0.0, sd);
  vec3 c = mix(white, red, in_stripe);
  // A thin soft edge of pink where red meets white.
  c = mix(c, mix(red_hi, vec3(1.0), 0.55), (1.0 - smoothstep(0.0, 0.025, abs(sd))) * 0.35 * step(0.0, sd));
  // The little white heart where the stripes meet.
  if (bonus > 0.5) {
    vec2 q = abs(p) / 0.62;
    float star = (pow(q.x, 0.42) + pow(q.y, 0.42) - 1.0) * 0.2;
    c = mix(c, vec3(1.0), cover_of(star - 0.035, aa) * 0.6);
    c = mix(c, vec3(0.04, 0.12, 0.1), cover_of(star, aa));
  }
  // Gloss: a broad soft sheen and a sharp window of light, top left.
  c = mix(c, vec3(1.0), spec * 0.55);
  vec2 g = (p - vec2(-0.38, -0.44)) * mat2(0.8, 0.6, -0.6, 0.8);
  float glare = cover_of((length(g / vec2(0.2, 0.075)) - 1.0) * 0.075, aa * 1.5);
  c = mix(c, vec3(1.0), glare * 0.9);
  c = mix(c, vec3(1.0), exp(-pow(length(p - vec2(-0.2, -0.24)) / 0.35, 2.0)) * 0.12);
  // The edge rounds down into shade at the bottom right.
  c *= 1.0 - 0.18 * smoothstep(0.82, 1.0, d) * clamp(dot(normalize(p + 1e-4), vec2(0.6, 0.8)) + 0.3, 0.0, 1.0);
  vec3 whole = c;

  // --- Crunched, in shadow ---
  // Each piece has shifted a little, so the stripes no longer meet
  // across a crack.
  float k = piece(p);
  vec2 shift = k < 0.5 ? vec2(0.012, -0.018) : (k < 1.5 ? vec2(-0.018, 0.0) : vec2(0.008, 0.016));
  vec2 ps = p + shift;
  float sd2 = stripe(ps);
  float lam2 = lam * (k < 0.5 ? 1.0 : (k < 1.5 ? 0.85 : 0.92));
  vec3 slate = mix(vec3(0.07, 0.055, 0.075), vec3(0.17, 0.14, 0.18), clamp(lam2 * 1.1, 0.0, 1.0));
  vec3 deep = mix(vec3(0.15, 0.02, 0.045), vec3(0.3, 0.05, 0.08), clamp(lam2 * 1.1, 0.0, 1.0));
  vec3 s = mix(slate, deep, cover_of(sd2, aa));
  // A dull sheen, still candy, and no lighter than a shipped popped dot.
  s = mix(s, vec3(0.2, 0.17, 0.21), spec * 0.3);
  s = mix(s, vec3(0.22, 0.19, 0.24), glare * 0.3);
  // The cracks: dark gaps, each with a broken edge a step lighter on its
  // lit side, so they read by shape in dark tones.
  float cr = cracks(p);
  float lip = cover_of(abs(cr - 0.016) - 0.012, aa) * step(0.0, cr);
  s = mix(s, vec3(0.24, 0.2, 0.24), lip * 0.9);
  s = mix(s, vec3(0.025, 0.012, 0.02), cover_of(cr, aa));
  s *= 1.0 - 0.18 * smoothstep(0.82, 1.0, d) * clamp(dot(normalize(p + 1e-4), vec2(0.6, 0.8)) + 0.3, 0.0, 1.0);

  vec3 col = mix(s, whole, fresh);
  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.19, 0.15, 0.19), vec3(0.32, 0.26, 0.31), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       vec3(1.0, 0.98, 0.97), fresh);
  return mix(col, rim_color, ring);
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
  vec4 color = vec4(vec3(0.01, 0.008, 0.012) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(vec3(1.0, 0.9, 0.9) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = mint(p, d, aa, fresh, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
