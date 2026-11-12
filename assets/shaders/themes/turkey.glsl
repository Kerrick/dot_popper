// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a tom turkey, face on, in full display: his tail fanned
// behind him to the edge of the circle, two rows of feathers in rust,
// orange and gold, each with a dark band and a cream tip; his wings
// dropped and barred at his sides; his round bronze breast; and his pale
// blue head with its red wattle. A popped dot is the same tom asleep on
// his roost at night, all in dark tones: his fan folded shut like a
// closed hand fan and hanging behind the limb, his wings folded, his head
// sunk into his shoulders with his eyes shut. Every sleeping turkey is alike. The
// vertex color says what kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform float time;  // seconds, for the glint in his eyes

const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec3 SHADOW = vec3(0.016, 0.008, 0.02);
const vec3 HALO = vec3(1.0, 0.78, 0.5);
const vec3 RIM = vec3(1.0, 0.93, 0.78);
const vec3 POP_RIM = vec3(0.47, 0.38, 0.36);
const vec2 PIVOT = vec2(0.0, 0.2);
const float FAN = 2.05;
const float PI = 3.14159;

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float ellipse(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float star(vec2 p, vec2 c, float size) {
  vec2 q = abs(p - c) / size;
  return (sqrt(q.x) + sqrt(q.y) - 0.762) * size * 0.55;
}
// A segment from +a+ to +b+, +w+ thick, as a signed distance.
float capsule(vec2 p, vec2 a, vec2 b, float w) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - w;
}

// The fan's feathers, in turn: rust, orange, gold, orange.
vec3 feather_color(float i, float bonus) {
  float k = mod(i, 4.0);
  if (bonus > 0.5) {
    return k < 0.5 ? vec3(0.2, 0.62, 0.6) : (k > 1.5 && k < 2.5 ? vec3(0.62, 0.92, 0.84) : vec3(0.38, 0.8, 0.74));
  }
  return k < 0.5 ? vec3(0.78, 0.27, 0.1) : (k > 1.5 && k < 2.5 ? vec3(1.0, 0.8, 0.32) : vec3(0.98, 0.54, 0.16));
}

// Scalloped rows of breast feathers: 0 at a feather's dark root, 1 on
// its lit edge.
float scallops(vec2 q, float size) {
  vec2 g = q / size;
  float row = floor(g.y);
  g.x += mod(row, 2.0) * 0.5;
  vec2 f = fract(g) - vec2(0.5, 0.0);
  float edge = length(f * vec2(1.0, 0.85));
  return smoothstep(0.12, 0.5, edge) * (1.0 - smoothstep(0.5, 0.58, edge));
}

vec3 turkey(vec2 p, float d, float aa, float fresh, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  float lam = clamp(0.35 + 0.75 * dot(vec3(p, z), L), 0.0, 1.0);

  // Where the fan is: the angle about the pivot (0 straight up), and how
  // far out toward the circle's edge, 0 to 1.
  vec2 q = p - PIVOT;
  float phi = atan(q.x, -q.y);
  vec2 dir = normalize(q + vec2(1e-5));
  float b = dot(PIVOT, dir);
  float reach = -b + sqrt(b * b - (dot(PIVOT, PIVOT) - 1.0));
  float t = length(q) / reach;

  // --- In full display ---
  // The long feathers behind: each a vane rounded across, darker at its
  // root, its quill pale, a dark band and a cream edge at its tip.
  float n1 = 19.0;
  float u1 = (phi + FAN) / (2.0 * FAN) * n1;
  float i1 = floor(u1), f1 = fract(u1) - 0.5;
  float tip1 = 1.0 - 0.07 * pow(2.0 * abs(f1), 2.5);
  float tt = t / tip1;
  vec3 back = feather_color(i1, bonus);
  back = mix(back * 0.45, back, smoothstep(0.25, 0.7, tt));
  back *= 0.7 + 0.38 * cos(f1 * PI) - 0.28 * smoothstep(0.3, 0.5, f1);
  back = mix(back, mix(back, vec3(1.0, 0.92, 0.75), 0.4), exp(-pow(f1 / 0.035, 2.0)) * smoothstep(0.3, 0.6, tt) * (1.0 - smoothstep(0.8, 0.85, tt)));
  back *= 1.0 - 0.5 * smoothstep(0.4, 0.5, abs(f1));
  vec3 band = bonus > 0.5 ? vec3(0.04, 0.14, 0.2) : vec3(0.18, 0.07, 0.04);
  vec3 tip_col = (bonus > 0.5 ? vec3(0.92, 1.0, 0.98) : vec3(1.0, 0.94, 0.8)) * (0.84 + 0.16 * cos(f1 * PI));
  back = mix(back, band, smoothstep(0.855, 0.87, tt));
  back = mix(back, tip_col, smoothstep(0.915, 0.93, tt));
  back = mix(tip_col * 0.62, back, cover_of((t - tip1) * reach, aa));

  // The shorter coverts in front, set between the long feathers.
  float n2 = 16.0;
  float span2 = FAN * 0.92;
  float u2 = (phi + span2) / (2.0 * span2) * n2;
  float i2 = floor(u2), f2 = fract(u2) - 0.5;
  float tip2 = 0.6 - 0.06 * pow(2.0 * abs(f2), 2.5);
  float t2 = t / tip2;
  vec3 cov = bonus > 0.5 ? vec3(0.14, 0.4, 0.44) : vec3(0.6, 0.27, 0.1);
  cov = mix(cov * 0.5, cov, smoothstep(0.3, 0.8, t2));
  cov *= 0.72 + 0.36 * cos(f2 * PI) - 0.25 * smoothstep(0.3, 0.5, f2);
  cov = mix(cov, band, smoothstep(0.8, 0.83, t2));
  cov = mix(cov, bonus > 0.5 ? vec3(0.85, 1.0, 0.95) : vec3(1.0, 0.84, 0.56), smoothstep(0.89, 0.92, t2));
  float in_cov = cover_of((t - tip2) * reach, aa) * step(abs(phi), span2);
  vec3 fan = back * (1.0 - 0.45 * exp(-pow((t - tip2 - 0.02) / 0.045, 2.0)) * step(abs(phi), span2));
  fan = mix(fan, cov, in_cov);
  fan *= 0.72 + 0.4 * lam;

  // His wings, dropped at his sides: dark primaries barred pale.
  float wing_t = t * 7.0 + abs(phi) * 1.2;
  float bars = smoothstep(0.55, 0.62, fract(wing_t)) * (1.0 - smoothstep(0.8, 0.87, fract(wing_t)));
  vec3 wing = mix(vec3(0.26, 0.14, 0.07), vec3(0.9, 0.85, 0.75), bars * 0.6) * (0.6 + 0.5 * lam);
  float quill = fract((abs(phi) - FAN) * 9.0);
  wing *= 0.8 + 0.2 * smoothstep(0.0, 0.2, quill);
  vec3 c = mix(fan, wing, smoothstep(FAN - 0.02, FAN + 0.02, abs(phi)));

  // His breast: round, bronze, a copper edge on every feather.
  vec2 bc = vec2(0.0, 0.47);
  vec2 br = vec2(0.42, 0.4);
  float body = ellipse(p, bc, br);
  vec3 bn = normalize(vec3((p - bc) / br, 0.55));
  float blam = clamp(0.25 + 0.85 * dot(bn, L), 0.0, 1.0);
  float sc = scallops(p - bc + vec2(0.0, 0.6), 0.16);
  vec3 bronze = mix(vec3(0.2, 0.09, 0.04), vec3(0.56, 0.31, 0.13), blam);
  bronze = mix(bronze, vec3(0.9, 0.58, 0.28) * (0.45 + 0.65 * blam), sc * 0.38);
  bronze = mix(bronze, vec3(0.42, 0.5, 0.3) * blam, 0.12 * smoothstep(0.2, 0.8, p.x - bc.x + 0.4));
  bronze += vec3(0.25, 0.16, 0.08) * pow(max(dot(bn, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0), 18.0);
  c *= 1.0 - 0.4 * cover_of(ellipse(p, bc + vec2(0.03, -0.03), br + 0.05), aa * 12.0) * (1.0 - cover_of(body, aa));
  c = mix(c, bronze, cover_of(body, aa));

  // His neck, head, beak, snood and wattle.
  vec2 hc = vec2(0.0, -0.16);
  vec2 hr = vec2(0.17, 0.19);
  vec3 flesh = mix(vec3(0.58, 0.05, 0.09), vec3(0.97, 0.27, 0.25), lam);
  float neck = capsule(p, vec2(0.0, 0.12), hc, 0.1);
  c *= 1.0 - 0.3 * cover_of(capsule(p, vec2(0.02, 0.14), hc + vec2(0.02, 0.0), 0.12), aa * 8.0) * (1.0 - cover_of(neck, aa));
  c = mix(c, mix(vec3(0.55, 0.16, 0.2), vec3(0.9, 0.45, 0.45), lam), cover_of(neck, aa));
  float head = ellipse(p, hc, hr);
  vec3 hn = normalize(vec3((p - hc) / hr, 0.7));
  vec3 face = mix(vec3(0.46, 0.58, 0.78), vec3(0.9, 0.96, 1.0), clamp(0.2 + 0.9 * dot(hn, L), 0.0, 1.0));
  c *= 1.0 - 0.3 * cover_of(ellipse(p, hc + vec2(0.03, 0.04), hr + 0.02), aa * 8.0) * (1.0 - cover_of(head, aa));
  c = mix(c, face, cover_of(head, aa));
  vec2 ec = vec2(abs(p.x), p.y) - vec2(0.075, -0.2);
  c = mix(c, vec3(0.08, 0.05, 0.06), cover_of(length(ec) - 0.042, aa));
  float blink = 0.85 + 0.15 * sin(time * 1.9 + seed * 3.0);
  c = mix(c, vec3(1.0), cover_of(length(ec - vec2(-0.012, -0.014)) - 0.013, aa) * blink);
  // The wattle hangs from his throat; the beak; the snood draped over it.
  float wattle = min(ellipse(p, vec2(0.02, -0.02), vec2(0.075, 0.09)), ellipse(p, vec2(-0.015, 0.07), vec2(0.065, 0.08)));
  c *= 1.0 - 0.3 * cover_of(ellipse(p, vec2(0.04, 0.05), vec2(0.09, 0.14)), aa * 6.0) * (1.0 - cover_of(wattle, aa));
  c = mix(c, flesh, cover_of(wattle, aa));
  float beak = max(abs(p.x) - 0.06 * (1.0 - (p.y + 0.16) / 0.11), max(-0.16 - p.y, p.y + 0.05));
  c = mix(c, mix(vec3(0.68, 0.52, 0.28), vec3(1.0, 0.9, 0.62), lam), cover_of(beak, aa));
  if (bonus > 0.5) {
    float st = star(p, bc + vec2(0.0, 0.02), 0.62);
    c = mix(c, vec3(1.0, 0.92, 0.55), cover_of(st, aa * 1.5));
  }
  vec3 display = c;

  // --- Asleep on his roost ---
  // The night behind him, and the limb he sits on.
  vec3 s = mix(vec3(0.065, 0.05, 0.07), vec3(0.11, 0.08, 0.095), clamp(0.5 - 0.5 * p.y, 0.0, 1.0));
  float limb_y = 0.72 + 0.05 * p.x;
  float limb = abs(p.y - limb_y) - 0.07;
  // His fan, folded shut like a closed hand fan and hanging down behind
  // the limb, as a roosting turkey's tail does: five feathers' rounded
  // tips, each with its dark band and its edge, as by day, all dark.
  vec2 fp = vec2(0.0, 0.38);
  vec2 fq = p - fp;
  float fphi = atan(fq.x, fq.y);
  float half_fan = 0.3;
  float fu = (fphi + half_fan) / (2.0 * half_fan) * 5.0;
  float ff = fract(fu) - 0.5;
  float ftip = 0.6 - 0.035 * pow(2.0 * abs(ff), 2.0);
  float ft = length(fq) / ftip;
  float closed_fan = max(max(length(fq) - ftip, abs(fphi) - half_fan), -fq.y);
  vec3 folded = mix(feather_color(floor(fu), 0.0), vec3(0.55, 0.4, 0.3), 0.6) * 0.22;
  folded = mix(folded * 0.5, folded, smoothstep(0.3, 0.8, ft));
  folded *= 0.75 + 0.35 * cos(ff * PI) - 0.3 * smoothstep(0.35, 0.5, abs(ff));
  folded = mix(folded, vec3(0.05, 0.03, 0.03), smoothstep(0.82, 0.84, ft));
  folded = mix(folded, vec3(0.2, 0.17, 0.14) * (0.8 + 0.2 * cos(ff * PI)), smoothstep(0.9, 0.92, ft));
  s *= 1.0 - 0.45 * cover_of(max(max(length(fq - vec2(0.03, 0.04)) - ftip, abs(fphi) - half_fan - 0.03), -fq.y), aa * 8.0) * (1.0 - cover_of(closed_fan, aa));
  s = mix(s, folded, cover_of(closed_fan, aa));
  // His feet gripping the limb.
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    float toes = min(capsule(p, vec2(sx * 0.17, limb_y - 0.1), vec2(sx * 0.1, limb_y - 0.03), 0.024),
                     capsule(p, vec2(sx * 0.17, limb_y - 0.1), vec2(sx * 0.24, limb_y - 0.03), 0.024));
    s = mix(s, vec3(0.2, 0.14, 0.12), cover_of(toes, aa));
  }
  // His body, round, bronze in the dark, a copper edge on each feather.
  vec2 rc = vec2(0.0, 0.32);
  vec2 rr = vec2(0.56, 0.46);
  float ball = ellipse(p, rc, rr);
  vec3 ball_n = normalize(vec3((p - rc) / rr, 0.6));
  float rlam = clamp(0.25 + 0.85 * dot(ball_n, L), 0.0, 1.0);
  float rs = scallops(p - rc + vec2(0.0, 0.6), 0.15);
  vec3 bird = mix(vec3(0.09, 0.06, 0.045), vec3(0.26, 0.16, 0.1), rlam);
  bird = mix(bird, vec3(0.34, 0.22, 0.14) * (0.45 + 0.65 * rlam), rs * 0.35);
  // His wings folded at his sides, their tips barred pale.
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    vec2 wc = vec2(sx * 0.39, 0.36);
    vec2 wr = vec2(0.2, 0.35);
    float w = ellipse(p, wc, wr);
    float along = p.y - wc.y;
    float bar = smoothstep(0.42, 0.52, fract(along * 7.0)) * (1.0 - smoothstep(0.72, 0.82, fract(along * 7.0))) * step(0.12, along);
    vec3 wcol = mix(vec3(0.07, 0.045, 0.04), vec3(0.24, 0.15, 0.1), rlam);
    wcol = mix(wcol, vec3(0.22, 0.19, 0.17) * (0.7 + 0.4 * rlam), bar * 0.6);
    bird *= 1.0 - 0.4 * cover_of(ellipse(p, wc - vec2(sx * 0.04, -0.02), wr + 0.03), aa * 8.0) * (1.0 - cover_of(w, aa));
    bird = mix(bird, wcol, cover_of(w, aa));
  }
  s *= 1.0 - 0.5 * cover_of(ellipse(p, rc + vec2(0.04, 0.05), rr + 0.03), aa * 12.0) * (1.0 - cover_of(ball, aa));
  s = mix(s, bird, cover_of(ball, aa));
  vec3 bark = mix(vec3(0.08, 0.055, 0.05), vec3(0.2, 0.15, 0.12), smoothstep(0.07, -0.07, p.y - limb_y));
  bark *= 0.9 + 0.1 * smoothstep(0.3, 0.7, sin(p.x * 13.0 + 2.0 * sin(p.y * 20.0)));
  s = mix(s, bark, cover_of(limb, aa) * (1.0 - cover_of(ball, aa)));
  // His head, sunk into his shoulders, as big as by day, slate in the
  // dark; his eyes shut.
  vec2 rh = vec2(0.0, -0.1);
  float rhead = ellipse(p, rh, hr);
  s *= 1.0 - 0.45 * cover_of(ellipse(p, rh + vec2(0.02, 0.06), hr + 0.03), aa * 8.0) * (1.0 - cover_of(rhead, aa));
  s = mix(s, mix(vec3(0.09, 0.095, 0.13), vec3(0.21, 0.22, 0.27), clamp(0.2 + 0.9 * dot(normalize(vec3((p - rh) / hr, 0.7)), L), 0.0, 1.0)), cover_of(rhead, aa));
  vec2 re = vec2(abs(p.x), p.y) - vec2(0.075, -0.13);
  float lid = abs(re.y - 0.026 * (1.0 - pow(re.x / 0.052, 2.0))) - 0.014;
  s = mix(s, vec3(0.05, 0.035, 0.05), cover_of(lid, aa) * step(abs(re.x), 0.054));
  vec3 night_flesh = mix(vec3(0.13, 0.045, 0.05), vec3(0.24, 0.085, 0.085), lam);
  float rwattle = min(ellipse(p, vec2(0.02, 0.04), vec2(0.07, 0.085)), ellipse(p, vec2(-0.015, 0.12), vec2(0.06, 0.075)));
  s *= 1.0 - 0.3 * cover_of(ellipse(p, vec2(0.04, 0.1), vec2(0.085, 0.13)), aa * 6.0) * (1.0 - cover_of(rwattle, aa));
  s = mix(s, night_flesh, cover_of(rwattle, aa));
  float rbeak = max(abs(p.x) - 0.06 * (1.0 - (p.y + 0.1) / 0.11), max(-0.1 - p.y, p.y - 0.01));
  s = mix(s, vec3(0.22, 0.18, 0.13), cover_of(rbeak, aa));

  vec3 col = mix(s, display, fresh);
  float wr = mix(max(0.036, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - wr)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_dark = mix(POP_RIM * 0.6, POP_RIM * 1.1, clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0));
  return mix(col, mix(rim_dark, RIM, fresh), ring);
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
  vec3 body = turkey(p, d, aa, fresh, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
