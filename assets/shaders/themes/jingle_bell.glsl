// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a jingle bell, a hollow sphere of polished silver that fills
// the dot's circle, seen from the front: its two halves joined by a
// ridged seam around its middle, a slot cut up from its foot to a round
// sound hole, and a red ribbon bow tied at its top. A bright dot is a
// whole bell in the light, mirror-bright. A popped dot is the same bell
// in shadow, burst open along its slot: the slot gapes into a wide dark
// mouth, its torn edges curled out, and the little ball that rang it
// sits inside. Every burst bell is alike. The bonus bell is gold, with a
// star cut through it for its sound hole. The vertex color says what
// kind of dot it is, as in dot.glsl.

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

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float ellipse(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }

// What a mirror sphere shows in direction +r+: a bright sky above, a
// darker room below, a dark horizon line between, and a window.
float mirror(vec3 r) {
  float up = -r.y;
  // The night sky, darker overhead and paler toward the horizon.
  float sky = mix(0.9, 0.42, smoothstep(0.02, 0.75, up));
  // The snowy ground, bright near the horizon, falling off below.
  float ground = mix(0.78, 0.3, smoothstep(-0.02, -0.8, up));
  float v = mix(ground, sky, smoothstep(-0.03, 0.03, up));
  v -= 0.45 * exp(-pow((up + 0.04) / 0.04, 2.0));
  // Two soft streaks of light from the side, as polished metal shows.
  v += 0.35 * exp(-pow((r.x + 0.55) / 0.08, 2.0)) * smoothstep(-0.2, 0.3, up);
  v += 0.18 * exp(-pow((r.x - 0.6) / 0.06, 2.0)) * smoothstep(-0.5, 0.0, up);
  return clamp(v, 0.0, 1.0);
}

// The bow at the crown: two loops and a knot, as a signed distance.
float bow(vec2 p) {
  vec2 k = (p - vec2(0.0, -0.76)) / 1.4;
  float knot = ellipse(k, vec2(0.0), vec2(0.075, 0.065));
  vec2 m = vec2(abs(k.x), k.y);
  float loop = ellipse(m, vec2(0.17, -0.03), vec2(0.15, 0.095));
  float tails = max(abs(m.x - 0.07 - 0.25 * (m.y - 0.04)) - 0.04, max(0.04 - m.y, m.y - 0.22));
  return min(knot - 0.004, min(loop, tails)) * 1.4;
}

vec3 bell(vec2 p, float d, float aa, float bright_look, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  vec3 n = vec3(p, z);
  vec3 r = reflect(vec3(0.0, 0.0, -1.0), n);
  float env = mirror(r);
  float lam = clamp(0.3 + 0.75 * dot(n, L), 0.0, 1.0);
  float spec = pow(max(dot(n, HALF_V), 0.0), 90.0);

  // The seam, a raised ridge around the middle, seen a little from
  // above, so it bows down.
  float seam_y = 0.04 + 0.1 * (1.0 - z) * 0.0 + 0.16 * p.x * p.x;
  float seam = abs(p.y - seam_y) - 0.03;
  float seam_lit = clamp(0.5 - 8.0 * (p.y - seam_y), 0.0, 1.0);
  // The slot from the foot up to the sound hole.
  vec2 hole_c = vec2(0.0, 0.42);
  float hole = length(p - hole_c) - 0.12;
  float slot = max(abs(p.x) - 0.04, hole_c.y - p.y);
  float cut = min(hole, slot);
  vec2 sq = abs(p - vec2(0.0, 0.46)) / 0.36;
  float star = (sqrt(sq.x) + sqrt(sq.y) - 1.0) * 0.14;
  if (bonus > 0.5) cut = star;

  // --- Whole, in the light ---
  vec3 tint = bonus > 0.5 ? vec3(1.0, 0.84, 0.46) : vec3(0.9, 0.94, 1.0);
  vec3 c = tint * mix(0.42, 1.08, env);
  c *= 0.82 + 0.25 * lam;
  c = mix(c, vec3(1.0), spec);
  // The ridge: lit on its top edge, shaded below.
  vec3 ridge = tint * mix(0.62, 1.05, seam_lit) * (0.85 + 0.2 * lam);
  c = mix(c, ridge, cover_of(seam, aa));
  c = mix(c, tint * 0.35, cover_of(abs(p.y - seam_y - 0.03) - 0.007, aa) * 0.8);
  c = mix(c, tint * 0.55, cover_of(abs(p.y - seam_y + 0.03) - 0.005, aa) * 0.5);
  // The cut, dark inside, with the ball glinting in the hole.
  vec3 inside = vec3(0.06, 0.06, 0.08);
  float ball = length(p - vec2(-0.01, 0.47)) - 0.075;
  inside = mix(inside, vec3(0.42, 0.42, 0.46), cover_of(ball, aa) * (bonus > 0.5 ? 0.0 : 1.0));
  inside = mix(inside, vec3(0.85), cover_of(length(p - vec2(-0.035, 0.445)) - 0.02, aa) * (bonus > 0.5 ? 0.0 : 1.0));
  c = mix(c, tint * 0.5, cover_of(cut - 0.025, aa) * 0.6);
  c = mix(c, inside, cover_of(cut, aa));
  vec3 whole = c;

  // --- Burst open, in shadow ---
  // The slot has torn wide: a dark mouth from the foot up past where the
  // hole was, its edges curled out and catching a little light.
  float side = sign(p.x);
  float tear = 0.025 * sin(p.y * 13.0 + side * 1.7) + 0.015 * sin(p.y * 29.0 - side * 0.8);
  float gape = 0.05 + 0.62 * clamp((p.y - 0.1) / 0.9, 0.0, 1.0);
  float mouth = max(abs(p.x) - gape * smoothstep(0.02, 0.35, p.y) - 0.025 - tear * smoothstep(0.15, 0.4, p.y), 0.06 - p.y);
  mouth = min(mouth, length(p - vec2(0.0, 0.12)) - 0.085);
  vec3 s = vec3(0.14, 0.15, 0.19) * mix(0.45, 1.05, env) * (0.75 + 0.35 * lam);
  s = mix(s, vec3(0.42, 0.44, 0.52), spec * 0.6);
  vec3 sridge = vec3(0.24, 0.25, 0.3) * mix(0.55, 1.05, seam_lit);
  s = mix(s, sridge, cover_of(seam, aa) * step(0.0, mouth - 0.06));
  float curl = cover_of(abs(mouth - 0.04) - 0.026, aa) * step(0.0, mouth);
  float curl_lit = clamp(0.6 - 3.0 * (mouth - 0.04), 0.0, 1.0);
  s = mix(s, mix(vec3(0.3, 0.31, 0.38), vec3(0.6, 0.62, 0.72), curl_lit), curl * 0.9);
  vec3 hollow = mix(vec3(0.02, 0.02, 0.03), vec3(0.07, 0.07, 0.09), smoothstep(0.9, 0.2, p.y));
  float pea = length(p - vec2(0.03, 0.62)) - 0.13;
  float pea_lit = clamp(0.55 + 2.8 * dot(p - vec2(0.03, 0.62), vec2(-0.6, -0.8)), 0.0, 1.0);
  hollow = mix(hollow, mix(vec3(0.16, 0.16, 0.2), vec3(0.42, 0.43, 0.5), pea_lit), cover_of(pea, aa));
  s = mix(s, hollow, cover_of(mouth, aa));

  vec3 col = mix(s, whole, bright_look);
  // The ribbon bow, red in both.
  float b = bow(p);
  float bl = clamp(0.5 + 2.5 * dot(p - vec2(0.0, -0.82), vec2(-0.5, -0.86)), 0.0, 1.0);
  vec3 ribbon = mix(mix(vec3(0.3, 0.03, 0.06), vec3(0.52, 0.07, 0.11), bl), mix(vec3(0.66, 0.05, 0.1), vec3(0.98, 0.25, 0.27), bl), bright_look);
  if (bonus > 0.5) ribbon = mix(vec3(0.04, 0.38, 0.22), vec3(0.3, 0.82, 0.5), bl);
  col = mix(col, ribbon * 0.4, cover_of(b - 0.02, aa * 4.0) * 0.5);
  col = mix(col, ribbon, cover_of(b, aa));
  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), bright_look);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.28, 0.29, 0.36), vec3(0.48, 0.5, 0.6), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       bonus > 0.5 ? vec3(1.0, 0.95, 0.8) : vec3(0.98, 0.99, 1.0), bright_look);
  return mix(col, rim_color, ring);
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
  vec4 color = vec4(vec3(0.006, 0.008, 0.02) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * bright_look * fade_out;
  color = over(vec4(vec3(0.9, 0.95, 1.0) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = bell(p, d, aa, bright_look, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
