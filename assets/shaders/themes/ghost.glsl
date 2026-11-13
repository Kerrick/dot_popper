// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a little ghost: a domed sheet that fills the dot's circle,
// nub arms at the waist and a scalloped hem cut from its lower edge. A
// bright dot is white and glows; a popped dot is the same ghost gone near
// black, its face a dim negative of the bright one. The vertex color
// says what kind of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform float time;

const vec3 WHITE = vec3(0.984, 0.992, 1.0);
const vec3 SHADE = vec3(0.765, 0.804, 0.922);
const vec3 SHADE2 = vec3(0.604, 0.651, 0.847);
const vec3 EYE = vec3(0.09, 0.075, 0.188);
const vec3 BLUSH = vec3(0.969, 0.737, 0.812);
const vec3 DARK = vec3(0.055, 0.047, 0.125);
const vec3 DARK2 = vec3(0.122, 0.102, 0.22);
const vec3 HOLLOW = vec3(0.255, 0.231, 0.412);
const float K = 4.0;

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }

// The sheet's edge at this angle: the circle on top, the hem below.
float edge_at(vec2 p) {
  float phi = atan(p.x, p.y);
  float a = abs(phi);
  float wob = 0.05 * sin(phi + seed * 13.7) + 0.02 * sin(time * 3.0 + seed);
  float scallop = 0.87 + 0.16 * pow(abs(cos(K * (phi + wob))), 0.55);
  float env = 1.0 - smoothstep(1.0, 1.32, a);
  float arm = 0.07 * exp(-pow((a - 1.72) / 0.16, 2.0));
  return mix(1.0, scallop, env) + arm;
}
float fold(vec2 p) {
  float s = 0.0;
  for (int i = 0; i < 4; i++) {
    float ph = (i < 2 ? 1.0 : 3.0) * 1.5708 / K * (mod(float(i), 2.0) < 0.5 ? 1.0 : -1.0);
    float cx = sin(ph) * 0.88;
    float cy = cos(ph) * 0.88;
    float xx = p.x - cx * (0.45 + 0.55 * clamp((p.y + 0.2) / max(cy + 0.2, 0.01), 0.0, 1.0));
    float h = exp(-pow(xx / (0.05 + 0.09 * clamp(cy - p.y, 0.0, 1.0)), 2.0)) * smoothstep(-0.25, cy - 0.05, p.y);
    s = max(s, h * (abs(ph) < 1.0 ? 0.75 : 0.5));
  }
  return s;
}
float oval(vec2 p, vec2 c, vec2 r, float aa) {
  float d = (length((p - c) / r) - 1.0) * r.x;
  return clamp(0.5 - d / aa, 0.0, 1.0);
}
float star_eye(vec2 p, float sx, float aa) {
  vec2 q = abs(p - vec2(sx * 0.29, -0.14));
  return clamp(0.5 - (sqrt(q.x) + sqrt(q.y) - 0.6) / max(aa * 4.0, 1e-4), 0.0, 1.0);
}
vec3 bright_sheet(vec2 p, float d, float sdf, float aa, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  float lit = clamp(0.5 + 0.3 * dot(p, vec2(-0.53, -0.848)) + 0.35 * (z - 0.5), 0.0, 1.0);
  vec3 c = mix(SHADE, WHITE, smoothstep(0.25, 0.8, lit));
  c = mix(c, SHADE2, fold(p) * 0.4);
  c = mix(c, SHADE, smoothstep(0.3, 0.95, p.y) * 0.35);
  if (bonus > 0.5) c = mix(c, vec3(1.0, 0.851, 0.471), 0.7);
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    c = mix(c, BLUSH, exp(-pow((p.x - sx * 0.58) / 0.16, 2.0) - pow((p.y - 0.1) / 0.1, 2.0)) * 0.55);
  }
  if (bonus > 0.5) {
    c = mix(c, EYE, max(star_eye(p, 1.0, aa), star_eye(p, -1.0, aa)));
  } else {
    float eye = max(oval(p, vec2(0.29, -0.14), vec2(0.15, 0.22), aa), oval(p, vec2(-0.29, -0.14), vec2(0.15, 0.22), aa));
    c = mix(c, EYE, eye);
    for (int i = 0; i < 2; i++) {
      float sx = i == 0 ? -1.0 : 1.0;
      c = mix(c, WHITE, clamp(0.5 - (length(p - vec2(sx * 0.29 - 0.055, -0.25)) - 0.055) / aa, 0.0, 1.0));
    }
  }
  c = mix(c, EYE, oval(p, vec2(0.0, 0.3), vec2(0.135, 0.16), aa));
  return mix(c, WHITE, smoothstep(-0.05, -0.01, sdf) * 0.9);
}
vec3 popped_sheet(vec2 p, float d, float sdf, float aa) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  float lit = clamp(0.5 + 0.3 * dot(p, vec2(-0.53, -0.848)) + 0.35 * (z - 0.5), 0.0, 1.0);
  vec3 c = mix(DARK, DARK2, smoothstep(0.2, 0.8, lit));
  c = mix(c, vec3(0.18, 0.157, 0.314), fold(p) * 0.3);
  float face = max(oval(p, vec2(0.29, -0.14), vec2(0.15, 0.22), aa), oval(p, vec2(-0.29, -0.14), vec2(0.15, 0.22), aa));
  face = max(face, oval(p, vec2(0.0, 0.3), vec2(0.135, 0.16), aa));
  c = mix(c, HOLLOW, face);
  float rim = (1.0 - smoothstep(0.0, 0.045, abs(sdf))) * step(sdf, 0.0);
  return mix(c, mix(vec3(0.227, 0.2, 0.376), vec3(0.365, 0.333, 0.529), clamp(0.55 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)), rim);
}
vec4 effect(vec4 params, Image tex, vec2 uv, vec2 screen) {
  float bright_look = params.r;
  float alarmed = params.g;
  float bonus = params.b;
  vec2 p = (uv * 2.0 - 1.0) * extent;
  float d = length(p);
  float sdf = d - edge_at(p);
  float aa = max(fwidth(d), 1e-4);
  float fade_out = 1.0 - smoothstep(extent - 0.1, extent, d);
  vec2 ps = p - vec2(0.0, shadow_offset);
  float sd = length(ps) - edge_at(ps);
  float s = (1.0 - smoothstep(-0.14, 0.06, sd)) * shadow_alpha;
  vec4 color = vec4(vec3(0.008, 0.008, 0.039) * s, s);
  float h = exp(-pow(max(sdf, 0.0) / halo_width, 2.0)) * halo_alpha * bright_look * fade_out;
  color = over(vec4(vec3(0.784, 0.902, 1.0) * h, h), color);
  float a = exp(-pow((sdf - 0.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp(-sdf / aa + 0.5, 0.0, 1.0);
  vec3 body = mix(popped_sheet(p, d, sdf, aa), bright_sheet(p, d, sdf, aa, bonus), bright_look);
  body = mix(body, alarm, alarmed * smoothstep(-0.2, -0.02, sdf));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
