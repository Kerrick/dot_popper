// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a pumpkin pie seen from above, in its dish: a crimped crust
// round the edge, each crimp a pillow of pastry browned on its crest, the
// glossy spiced custard set a little below it, and a piped swirl of
// whipped cream in the middle casting its shadow. A popped dot is the same
// dish after dinner, in the dark: the middle eaten, a smear of filling and
// crumbs on the glazed floor, the crust's edge left behind as a broken
// ring, and a fork across it. Every eaten pie is alike. The vertex color
// says what kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;

const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec3 HALF_V = vec3(-0.2288, -0.3378, 0.9130);
const vec3 SHADOW = vec3(0.016, 0.008, 0.02);
const vec3 HALO = vec3(1.0, 0.75, 0.44);
const vec3 RIM = vec3(1.0, 0.886, 0.659);
const vec3 POP_RIM = vec3(0.49, 0.37, 0.33);
const float TAU = 6.28318;
const float CRIMPS = 20.0;
const float INNER = 0.7;

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
// Coverage of a signed distance (negative inside), over one pixel.
float fill(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float star(vec2 p, vec2 c, float size) {
  vec2 q = abs(p - c) / size;
  return (sqrt(q.x) + sqrt(q.y) - 0.762) * size * 0.55;
}
vec3 normal_of(vec2 grad, float scale) { return normalize(vec3(-grad * scale, 1.0)); }

// The crimps lean, as a thumb leaves them: where across its crimp a
// point is, -0.5 to 0.5, 0 on the crest, +t+ of the way out.
const float LEAN = 0.5;
float crimp_u(vec2 p, float t) {
  float a = atan(p.y, p.x) / TAU * CRIMPS + LEAN * t;
  return fract(a + 0.5) - 0.5;
}
// The crust's scalloped outer edge, where each crimp ends.
float crust_outer(vec2 p) {
  float u = crimp_u(p, 1.0);
  return 0.93 + 0.045 * pow(max(cos(3.14159 * u), 0.0), 0.8);
}

// The crust's height: a rounded roll of pastry, fluted, 0 to 1.
float crust_h(vec2 p) {
  float r = length(p);
  float t = (r - INNER) / (crust_outer(p) - INNER);
  if (t <= 0.0 || t >= 1.0) return 0.0;
  float u = crimp_u(p, t);
  float roll = pow(sin(3.14159 * t), 0.65);
  float flute = pow(max(cos(3.14159 * u), 0.0), 1.1);
  return roll * (0.3 + 0.7 * mix(1.0, flute, smoothstep(0.1, 0.45, t)));
}

// The cream: a piped rosette, a dome with ridges that twist round it.
const float CREAM = 0.4;
float cream_edge(vec2 p) {
  float r = length(p), a = atan(p.y, p.x);
  return r - CREAM * (1.0 + 0.07 * cos(8.0 * a - 16.0 * r));
}
float cream_h(vec2 p) {
  float r = length(p), a = atan(p.y, p.x);
  float k = clamp(r / CREAM, 0.0, 1.2);
  float dome = pow(max(1.0 - k * k, 0.0), 0.6);
  float ridge = 0.5 + 0.5 * cos(8.0 * a - 16.0 * r);
  float coil = 0.5 + 0.5 * cos(TAU * (k * 2.0 - a / TAU));
  float peak = exp(-dot(p + vec2(0.02, 0.03), p + vec2(0.02, 0.03)) / 0.004);
  return dome * (0.62 + 0.2 * ridge + 0.22 * coil) + 0.04 * ridge + 0.25 * peak;
}

// The fork lying across the eaten dish, as a signed distance, and where
// across it a point is (-1 to 1) for its round shading.
const vec2 FORK_A = vec2(0.76, 0.2);
const vec2 FORK_B = vec2(-0.4, 0.52);
float fork(vec2 p, out float across) {
  vec2 axis = normalize(FORK_B - FORK_A);
  vec2 side = vec2(-axis.y, axis.x);
  float len = length(FORK_B - FORK_A);
  float s = dot(p - FORK_A, axis) / len;
  float x = dot(p - FORK_A, side);
  float w;
  if (s < 0.58) w = mix(0.09, 0.058, s / 0.58);
  else if (s < 0.68) w = mix(0.058, 0.036, (s - 0.58) / 0.1);
  else if (s < 0.78) w = mix(0.036, 0.115, smoothstep(0.68, 0.78, s));
  else w = 0.115;
  across = clamp(x / w, -1.0, 1.0);
  float body = max(abs(x) - w, max(-s * len, (s - 0.83) * len));
  // The end of the handle is round.
  body = max(body, -s * len - 0.0);
  body = min(max(body, 0.09 - s * len), length(p - FORK_A - axis * 0.09) - 0.09);
  // Four tines, from the head to their tips.
  float tine_x = mod(x + 0.115, 0.0767) - 0.0383;
  float tines = max(max(abs(tine_x) - 0.018, abs(x) - 0.115), max((0.79 - s) * len, (s - 1.0) * len));
  return min(body, tines);
}

vec3 dot_body(vec2 p, float d, float aa, float fresh, float bonus) {
  float a = atan(p.y, p.x);
  float outer = crust_outer(p);
  float e = 0.004;
  float h = crust_h(p);
  vec2 g = vec2(crust_h(p + vec2(e, 0.0)) - crust_h(p - vec2(e, 0.0)), crust_h(p + vec2(0.0, e)) - crust_h(p - vec2(0.0, e))) / (2.0 * e);
  vec3 n = normal_of(g, 0.08);
  float lam = dot(n, L);
  float spec = pow(max(dot(n, HALF_V), 0.0), 30.0);
  float in_crust = fill(d - outer, aa) * (1.0 - fill(d - INNER, aa));
  float blister = fbm(p * 16.0 + 3.0);
  float t = clamp((d - INNER) / (outer - INNER), 0.0, 1.0);

  // --- The pie, in the light ---
  // Pale in the folds, browned on the crests, blistered.
  vec3 pastry = mix(vec3(1.0, 0.84, 0.54), vec3(0.85, 0.5, 0.19), smoothstep(0.4, 1.0, h) * (0.55 + 0.45 * blister));
  pastry = mix(pastry, vec3(0.64, 0.33, 0.11), smoothstep(0.62, 0.85, fbm(p * 26.0 + 11.0)) * smoothstep(0.5, 1.0, h) * 0.5);
  pastry *= 0.4 + 0.75 * clamp(lam + 0.12, 0.0, 1.0);
  pastry *= 0.92 + 0.12 * blister;
  pastry += vec3(1.0, 0.9, 0.7) * spec * 0.3;
  pastry *= 0.5 + 0.5 * smoothstep(0.0, 0.3, h);

  // The custard, set a little below the crust: a soft dome, a glossy
  // skin, the crust's shadow on its far side, darker at its edge.
  vec3 cn = normalize(vec3(p * 0.45, 1.0));
  float clam = dot(cn, L);
  vec3 custard = mix(vec3(0.66, 0.31, 0.08), vec3(0.98, 0.63, 0.29), clamp(0.1 + clam * 1.0, 0.0, 1.0));
  custard *= 0.93 + 0.1 * fbm(p * 9.0 + 2.0);
  custard = mix(custard, vec3(0.55, 0.27, 0.08), smoothstep(0.7, 0.85, fbm(p * 38.0 + 5.0)) * 0.3);
  float sheen = exp(-pow(length((p - vec2(-0.28, -0.36)) / vec2(0.2, 0.11)), 2.0));
  custard = mix(custard, vec3(1.0, 0.9, 0.72), sheen * 0.55);
  custard += vec3(0.25, 0.14, 0.06) * exp(-pow(length((p - vec2(0.3, 0.38)) / vec2(0.22, 0.1)), 2.0));
  float under_crust = smoothstep(INNER - 0.1, INNER, length(p + L.xy * 0.07));
  custard *= 1.0 - 0.32 * under_crust;
  custard *= 0.7 + 0.3 * smoothstep(INNER, INNER - 0.06, d);

  vec3 inside;
  if (bonus > 0.5) {
    vec3 mint = mix(vec3(0.55, 0.85, 0.76), vec3(0.88, 1.0, 0.95), clamp(0.2 + clam * 0.9, 0.0, 1.0));
    mint = mix(mint, vec3(1.0), sheen * 0.45);
    mint *= 1.0 - 0.25 * under_crust;
    float st = star(p, vec2(0.0), 1.0);
    float lifted = star(p - vec2(0.03, 0.045), vec2(0.0), 1.0);
    mint *= 1.0 - 0.35 * fill(lifted + 0.01, aa * 2.0) * (1.0 - fill(st, aa));
    vec3 choc = mix(vec3(0.15, 0.07, 0.04), vec3(0.34, 0.19, 0.11), smoothstep(0.0, -0.05, st));
    choc = mix(choc, vec3(0.62, 0.46, 0.38), exp(-pow(length(p - vec2(-0.07, -0.1)) / 0.07, 2.0)) * 0.6);
    inside = mix(mint, choc, fill(st, aa * 2.5));
  } else {
    // The cream shades the custard below and to its right.
    float shade = fill(cream_edge(p - vec2(0.06, 0.09)), aa * 14.0);
    custard *= 1.0 - 0.38 * shade;
    float ch = cream_h(p);
    vec2 cg = vec2(cream_h(p + vec2(e, 0.0)) - cream_h(p - vec2(e, 0.0)), cream_h(p + vec2(0.0, e)) - cream_h(p - vec2(0.0, e))) / (2.0 * e);
    vec3 crn = normal_of(cg, 0.11);
    float crl = dot(crn, L);
    vec3 cream = mix(vec3(0.74, 0.6, 0.52), vec3(1.0, 0.99, 0.96), clamp(0.05 + crl * 1.15, 0.0, 1.0));
    cream += vec3(1.0) * pow(max(dot(crn, HALF_V), 0.0), 40.0) * 0.2;
    cream *= 0.88 + 0.12 * smoothstep(0.0, 0.25, ch);
    inside = mix(custard, cream, fill(cream_edge(p), aa));
  }
  // The dish's lip, glazed, where the crimps leave it bare.
  float lip_lit = clamp(0.55 + 0.6 * dot(p / max(d, 1e-4), L.xy), 0.0, 1.0);
  vec3 dish_lip = mix(vec3(0.42, 0.17, 0.1), vec3(0.78, 0.4, 0.24), lip_lit);
  vec3 lit = mix(dish_lip, pastry, in_crust);
  lit = mix(lit, inside, fill(d - INNER, aa));
  // The crust overhangs the custard: a dark seam where they meet.
  lit *= 1.0 - 0.35 * exp(-pow((d - INNER) / 0.018, 2.0));

  // --- The dish after dinner, in the dark ---
  // The crust's edge is left, broken off where it was eaten.
  float jag = 0.16 * (noise(vec2(d * 30.0, 1.0)) - 0.5) + 0.05 * (noise(vec2(d * 90.0, 4.0)) - 0.5);
  float gap1 = abs(mod(a - 0.55 + jag + 3.14159, TAU) - 3.14159) - 0.42;
  float gap2 = abs(mod(a + 2.45 + jag + 3.14159, TAU) - 3.14159) - 0.22;
  float kept = fill(-min(gap1, gap2) * 0.6, aa);
  vec3 old_crust = mix(vec3(0.16, 0.1, 0.07), vec3(0.42, 0.31, 0.21), clamp(0.15 + lam * 0.95, 0.0, 1.0));
  old_crust *= 0.9 + 0.12 * blister;
  old_crust += vec3(0.5, 0.42, 0.34) * spec * 0.2;
  old_crust *= 0.5 + 0.5 * smoothstep(0.0, 0.25, h);
  // Where a piece broke off, its broken face shows, paler and crumbly.
  float face = exp(-pow(min(abs(gap1), abs(gap2)) / 0.035, 2.0)) * step(0.0, -min(gap1, gap2) + 0.02);
  old_crust = mix(old_crust, vec3(0.44, 0.35, 0.26) * (0.8 + 0.3 * fbm(p * 40.0)), face * 0.5);

  // The glazed floor: a deep rust, its wall lit on the near side, a sheen.
  float wall = smoothstep(INNER - 0.14, INNER + 0.02, d);
  float wall_lit = clamp(0.5 - 0.7 * dot(p / max(d, 1e-4), L.xy), 0.0, 1.0);
  vec3 floor_col = mix(vec3(0.12, 0.05, 0.045), vec3(0.2, 0.09, 0.07), clamp(0.6 - 0.4 * d, 0.0, 1.0));
  floor_col = mix(floor_col, mix(vec3(0.07, 0.03, 0.03), vec3(0.3, 0.14, 0.1), wall_lit), wall);
  float glaze = exp(-pow(length((p - vec2(-0.2, -0.3)) / vec2(0.3, 0.12)), 2.0));
  floor_col += vec3(0.16, 0.1, 0.09) * glaze;
  // What's left of the filling: a rim of it along the crust, a smear
  // where a fork dragged through it, and crumbs.
  float rim_fill = exp(-pow((d - INNER + 0.012) / 0.022, 2.0)) * (0.6 + 0.4 * noise(vec2(a * 12.0, 0.0)));
  // The smear: a broad stroke across the floor, combed by the tines.
  vec2 sq = p - vec2(0.05, 0.62);
  float sr = length(sq), sa = atan(sq.y, sq.x);
  float along = clamp((sa + 2.55) / 1.15, 0.0, 1.0);
  float smear = exp(-pow((sr - 0.8) / (0.09 * (1.0 - along * 0.6)), 4.0)) * smoothstep(-2.6, -2.45, sa) * smoothstep(-1.3, -1.5, sa);
  smear *= 0.7 + 0.3 * smoothstep(-0.2, 0.6, sin((sr - 0.8) * 110.0));
  vec3 filling_dark = vec3(0.46, 0.2, 0.07);
  vec3 eaten = mix(floor_col, filling_dark, clamp(rim_fill + smear, 0.0, 1.0) * 0.8);
  // Crumbs, the same in every dish.
  vec2 crumbs[6];
  crumbs[0] = vec2(0.36, -0.06); crumbs[1] = vec2(-0.5, 0.06); crumbs[2] = vec2(0.12, 0.02);
  crumbs[3] = vec2(-0.1, -0.52); crumbs[4] = vec2(0.5, -0.36); crumbs[5] = vec2(-0.2, 0.18);
  for (int i = 0; i < 6; i++) {
    float cr = 0.026 + 0.012 * float(i - 2 * (i / 2));
    vec2 q = p - crumbs[i];
    float cd = length(q * vec2(1.0, 1.25)) - cr + 0.004 * sin(atan(q.y, q.x) * 3.0 + float(i));
    eaten *= 1.0 - 0.5 * fill(length(q - vec2(-0.012, -0.016)) - cr * 1.1, aa * 3.0) * step(0.0, cd);
    vec3 crumb = mix(vec3(0.3, 0.21, 0.14), vec3(0.52, 0.4, 0.29), clamp(0.5 - dot(q / cr, vec2(0.6, 0.8)) * 0.5, 0.0, 1.0));
    eaten = mix(eaten, crumb, fill(cd, aa));
  }
  vec3 dark_lip = mix(vec3(0.12, 0.05, 0.04), vec3(0.3, 0.15, 0.11), lip_lit);
  vec3 dark = mix(dark_lip, old_crust, in_crust * kept);
  dark = mix(dark, eaten, fill(d - INNER, aa));
  dark *= 1.0 - 0.3 * exp(-pow((d - INNER) / 0.02, 2.0)) * kept;
  // The fork, steel in the dark, its shadow on the dish below it.
  float across;
  float fsd = fork(p - vec2(0.035, 0.05), across);
  dark *= 1.0 - 0.45 * fill(fsd, aa * 5.0);
  fsd = fork(p, across);
  float fl = clamp(0.55 - 0.5 * across, 0.0, 1.0);
  vec3 steel = mix(vec3(0.24, 0.25, 0.3), vec3(0.62, 0.64, 0.7), fl);
  steel = mix(steel, vec3(0.78, 0.8, 0.86), exp(-pow((across + 0.35) / 0.18, 2.0)) * 0.6);
  dark = mix(dark, steel, fill(fsd, aa));

  vec3 c = mix(dark, lit, fresh);
  float w = mix(max(0.034, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_dark = mix(POP_RIM * 0.62, POP_RIM * 1.1, clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0));
  return mix(c, mix(rim_dark, RIM, fresh), ring);
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
