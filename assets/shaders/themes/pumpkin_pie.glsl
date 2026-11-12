// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a pumpkin pie seen from above, in its dish: a crimped crust
// round the edge, each crimp a pillow of pastry browned on its crest, the
// glossy spiced custard set a little below it, and a piped swirl of
// whipped cream in the middle casting its shadow. A popped dot is the same
// dish after dinner, in the dark, the pie gone: the bare glazed dish, its
// fluted rim, its floor wiped clean but for a few crumbs, all in dark
// tones. Every empty dish is alike. The vertex color says what kind of
// dot it is, as in dot.glsl.

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

// The empty dish: a flat floor, a wall sloping up to a rounded rim
// fluted as many times as the crust was crimped, 0 to 1.
const float FLOOR = 0.58;
const float RIM_IN = 0.8;
float dish_rim(vec2 p) {
  float u = fract(atan(p.y, p.x) / TAU * CRIMPS + 0.5) - 0.5;
  return 0.94 + 0.045 * (0.5 + 0.5 * cos(TAU * u));
}
float dish_h(vec2 p) {
  float r = length(p);
  float u = fract(atan(p.y, p.x) / TAU * CRIMPS + 0.5) - 0.5;
  float wall = smoothstep(FLOOR, RIM_IN, r);
  float t = clamp((r - RIM_IN) / (dish_rim(p) - RIM_IN), 0.0, 1.0);
  float lip = sin(3.14159 * t) * (0.75 + 0.25 * cos(TAU * u));
  return 0.55 * wall + 0.3 * lip * step(RIM_IN, r);
}

vec3 dot_body(vec2 p, float d, float aa, float fresh, float bonus) {
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
  // The pie is gone. All of it is dark, read by its shape: the glaze a
  // deep rust, the rim a little less dark than the floor, each flute
  // rounded by shade alone, with no glint or sheen.
  vec2 dg = vec2(dish_h(p + vec2(e, 0.0)) - dish_h(p - vec2(e, 0.0)), dish_h(p + vec2(0.0, e)) - dish_h(p - vec2(0.0, e))) / (2.0 * e);
  vec3 dn = normal_of(dg, 0.1);
  float relief = dot(dn, L) - L.z;
  vec3 glaze = mix(vec3(0.13, 0.055, 0.045), vec3(0.25, 0.12, 0.09), smoothstep(RIM_IN - 0.04, RIM_IN + 0.06, d));
  vec3 dark = glaze * clamp(1.0 + 1.6 * relief, 0.45, 1.2);
  // Dark grooves between the flutes, and the wall in shadow where the
  // rim meets the floor, draw the dish's shape.
  float flute_u = fract(atan(p.y, p.x) / TAU * CRIMPS + 0.5) - 0.5;
  dark *= 1.0 - 0.55 * smoothstep(0.3, 0.5, abs(flute_u)) * smoothstep(RIM_IN - 0.02, RIM_IN + 0.04, d);
  dark *= 1.0 - 0.5 * exp(-pow((d - RIM_IN + 0.03) / 0.04, 2.0));
  // Past the flutes, the dish's outer edge falls away into shadow.
  dark = mix(dark, vec3(0.07, 0.03, 0.026), fill(dish_rim(p) - d, aa));
  // A trail of crust flakes where the last slice was lifted, the same
  // in every dish, each with its shadow.
  vec3 flakes[5];
  flakes[0] = vec3(0.1, 0.3, 0.05); flakes[1] = vec3(0.22, 0.21, 0.066); flakes[2] = vec3(0.315, 0.165, 0.026);
  flakes[3] = vec3(0.4, 0.06, 0.044); flakes[4] = vec3(0.47, -0.04, 0.024);
  for (int i = 0; i < 5; i++) {
    float cr = flakes[i].z;
    float turn = float(i) * 1.9;
    vec2 q = mat2(cos(turn), sin(turn), -sin(turn), cos(turn)) * (p - flakes[i].xy);
    float qa = atan(q.y, q.x);
    float edge = cr * (0.78 + 0.28 * noise(vec2(qa * 1.3 + float(i) * 7.0, 0.5)) + 0.08 * cos(3.0 * qa + float(i)));
    float cd = length(q * vec2(0.8, 1.3)) - edge;
    vec2 sq = p - flakes[i].xy - vec2(0.014, 0.02);
    dark *= 1.0 - 0.5 * fill(length(sq) - cr * 1.05, aa * 2.0) * step(0.0, cd);
    vec3 crumb = mix(vec3(0.13, 0.08, 0.05), vec3(0.25, 0.17, 0.1), clamp(0.5 + dot(p - flakes[i].xy, L.xy) / cr * 0.55, 0.0, 1.0));
    dark = mix(dark, crumb, fill(cd, aa));
  }

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
