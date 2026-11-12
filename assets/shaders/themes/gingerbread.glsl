// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a round gingerbread cookie that fills the dot's circle,
// seen from above: baked golden, browner at its edge, a squiggle of white
// icing piped just inside its rim, and a gingerbread man set on it,
// iced with eyes, a smile and cuffs, with red candy buttons. A bright dot is the cookie
// in warm light. A popped dot is the same cookie in shadow, and the
// gingerbread man is gone ("Run, run, as fast as you can"): only the
// man-shaped hole he left is there, dark through to the tray. Every
// popped cookie is alike. The bonus cookie is glazed and has a big dark
// star in the man's place. The vertex color says what kind of dot it is,
// as in dot.glsl.

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

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float hash1(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash1(i), hash1(i + vec2(1, 0)), f.x), mix(hash1(i + vec2(0, 1)), hash1(i + vec2(1, 1)), f.x), f.y);
}
float capsule(vec2 p, vec2 a, vec2 b, float r) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - r;
}
float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// The gingerbread man, as a signed distance: head, body, arms and legs.
float man(vec2 p) {
  float head = length(p - vec2(0.0, -0.4)) - 0.21;
  float body = capsule(p, vec2(0.0, -0.16), vec2(0.0, 0.18), 0.2);
  float arms = min(capsule(p, vec2(-0.1, -0.1), vec2(-0.47, 0.0), 0.105), capsule(p, vec2(0.1, -0.1), vec2(0.47, -0.04), 0.105));
  float legs = min(capsule(p, vec2(-0.08, 0.2), vec2(-0.25, 0.56), 0.115), capsule(p, vec2(0.08, 0.2), vec2(0.25, 0.56), 0.115));
  return smin(smin(smin(head, body, 0.06), arms, 0.07), legs, 0.07);
}

vec3 cookie(vec2 p, float d, float aa, float fresh, float bonus) {
  // A flat cookie whose edge rounds down: the normal tilts only near it.
  float edge = smoothstep(0.72, 1.0, d);
  float bump = noise(p * 9.0) * 0.6 + noise(p * 23.0) * 0.4;
  vec3 n = normalize(vec3(p * edge * 1.6 + (vec2(noise(p * 14.0 + 3.0), noise(p * 14.0 + 9.0)) - 0.5) * 0.25, 1.0));
  float lam = clamp(0.35 + 0.75 * dot(n, L), 0.0, 1.0);
  // Small dark pits in the baked surface.
  float pits = smoothstep(0.78, 0.9, hash1(floor(p * 34.0)));

  // The icing squiggle just inside the rim.
  float a = atan(p.y, p.x);
  float sq = abs(d - 0.84 - 0.028 * sin(a * 16.0)) - 0.034;
  float sq_lit = clamp(0.5 + 9.0 * dot(p - normalize(p + 1e-4) * (0.84 + 0.028 * sin(a * 16.0)), vec2(0.53, 0.85)), 0.0, 1.0);

  float m = bonus > 0.5 ? 9.0 : man(p);

  // --- Whole, in warm light ---
  vec3 dough = bonus > 0.5 ? mix(vec3(0.82, 0.55, 0.28), vec3(1.0, 0.86, 0.6), lam) : mix(vec3(0.7, 0.38, 0.14), vec3(0.98, 0.7, 0.4), lam);
  dough *= 0.95 + 0.08 * bump;
  dough = mix(dough, dough * 0.8, pits * 0.3);
  dough = mix(dough, vec3(0.55, 0.28, 0.1), edge * 0.45);
  vec3 c = dough;
  // The man stands a little proud of the cookie: a shadow at his lower
  // right, a lit edge at his upper left, and he is baked a little darker.
  float mshadow = man(p - vec2(0.025, 0.04));
  c *= 1.0 - 0.35 * cover_of(mshadow, aa * 6.0) * step(0.0, m) * (1.0 - bonus);
  float m_edge = clamp(0.5 - 30.0 * (man(p + vec2(0.015, 0.022)) - m), 0.0, 1.0);
  vec3 ginger = mix(vec3(0.55, 0.27, 0.09), vec3(0.86, 0.52, 0.24), lam) * (0.94 + 0.1 * bump);
  ginger = mix(ginger, ginger * 1.25, smoothstep(-0.03, 0.0, m) * m_edge);
  c = mix(c, ginger, cover_of(m, aa));
  // His icing: eyes, a smile (the lower half of a ring), and cuffs at
  // his wrists and ankles.
  float icing = min(length(p - vec2(-0.075, -0.44)) - 0.035, length(p - vec2(0.075, -0.44)) - 0.035);
  float smile = abs(length(p - vec2(0.0, -0.43)) - 0.11) - 0.018;
  icing = min(icing, max(smile, -0.36 - p.y));
  float cuffs = 9.0;
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    vec2 w = p - vec2(sx * 0.38, sx < 0.0 ? -0.018 : -0.048);
    cuffs = min(cuffs, abs(w.x + 0.03 * sin(w.y * 60.0)) - 0.016 + max(abs(w.y) - 0.09, 0.0));
    vec2 k = p - vec2(sx * 0.215, 0.47);
    vec2 kd = normalize(vec2(sx * 0.17, 0.36));
    float along = dot(k, kd);
    float across = k.x * kd.y - k.y * kd.x;
    cuffs = min(cuffs, abs(along + 0.03 * sin(across * 60.0)) - 0.016 + max(abs(across) - 0.1, 0.0));
  }
  vec3 white = mix(vec3(0.84, 0.8, 0.78), vec3(1.0, 0.99, 0.97), clamp(lam + 0.2, 0.0, 1.0));
  float man_icing = min(icing, cuffs);
  c = mix(c, white * 0.6, cover_of(man_icing - 0.012, aa * 3.0) * 0.4 * (bonus > 0.5 ? 0.0 : 1.0));
  c = mix(c, white, cover_of(man_icing, aa) * cover_of(m, aa));
  // Three red candy buttons, each with a glint.
  vec2 bq = vec2(p.x, mod(p.y + 0.15, 0.14) - 0.07);
  float candy = max(length(bq) - 0.045, abs(p.y - 0.06) - 0.2);
  vec3 red = mix(vec3(0.6, 0.04, 0.08), vec3(0.96, 0.22, 0.22), clamp(0.5 - 8.0 * dot(bq, vec2(0.5, 0.85)), 0.0, 1.0));
  red = mix(red, vec3(1.0, 0.85, 0.85), cover_of(length(bq - vec2(-0.014, -0.016)) - 0.012, aa));
  c = mix(c, red, cover_of(candy, aa) * (1.0 - bonus));
  // The squiggle: raised, its shadow falling down and right.
  c *= 1.0 - 0.3 * cover_of(abs(d - 0.855 - 0.028 * sin(a * 16.0)) - 0.034, aa * 5.0) * step(0.0, sq);
  c = mix(c, mix(white * 0.86, white, sq_lit), cover_of(sq, aa));
  if (bonus > 0.5) {
    vec2 q = abs(p) / 0.6;
    float star = (pow(q.x, 0.42) + pow(q.y, 0.42) - 1.0) * 0.2;
    c *= 1.0 - 0.25 * cover_of(star - 0.015, aa * 2.0) * step(0.0, star);
    c = mix(c, vec3(0.16, 0.07, 0.04), cover_of(star, aa));
  }
  vec3 whole = c;

  // --- In shadow, and he has run away ---
  vec3 sdough = mix(vec3(0.12, 0.06, 0.035), vec3(0.24, 0.13, 0.07), lam) * (0.92 + 0.12 * bump);
  sdough = mix(sdough, sdough * 0.7, pits * 0.5);
  sdough = mix(sdough, vec3(0.08, 0.04, 0.025), edge * 0.45);
  vec3 s = sdough;
  float hole = man(p);
  // The hole's lit wall, the cut edge of the cookie, shows on its far
  // (lower right) side; the near side falls into shadow.
  float wall = cover_of(hole + 0.04, aa) * (1.0 - cover_of(man(p - vec2(-0.03, -0.045)), aa));
  vec3 tray = vec3(0.02, 0.012, 0.012);
  s = mix(s, tray, cover_of(hole, aa));
  s = mix(s, vec3(0.42, 0.26, 0.16), wall * cover_of(hole, aa) * 0.95);
  s = mix(s, mix(vec3(0.26, 0.24, 0.26), vec3(0.4, 0.37, 0.4), sq_lit), cover_of(sq, aa));

  vec3 col = mix(s, whole, fresh);
  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.3, 0.2, 0.15), vec3(0.5, 0.36, 0.27), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       vec3(1.0, 0.92, 0.8), fresh);
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
  vec4 color = vec4(vec3(0.012, 0.008, 0.006) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(vec3(1.0, 0.85, 0.6) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = cookie(p, d, aa, fresh, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
