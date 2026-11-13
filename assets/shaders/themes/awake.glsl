// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as an eye, in the wood. A bright dot is an open cat's eye that
// fills the circle and looks toward the player; a popped dot is a shut lid
// with a bone lash line, a flat two-tone shape. Open or shut is a shape,
// so it reads without color. The vertex color says what kind of dot it
// is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform vec2 gaze;  // toward the last touch, within the iris, in radii

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
vec3 open_eye(vec2 p, float d, float aa, float bonus) {
  float th = atan(p.y, p.x);
  float st = fbm(vec2(cos(th) * 5.0 + seed + d * 0.4, sin(th) * 5.0 + d * 2.2));
  vec3 iris = mix(vec3(0.965, 0.894, 0.227), vec3(1.0, 0.973, 0.635), smoothstep(0.35, 0.7, st) * 0.55);
  float tone = smoothstep(0.1, 0.95, d) * smoothstep(0.4, 0.7, fbm(vec2(cos(th) * 2.4 + seed, sin(th) * 2.4 + d))) * 0.65;
  iris = mix(iris, vec3(0.824, 0.604, 0.078), tone);
  iris = mix(iris, vec3(0.31, 0.231, 0.031), smoothstep(0.72, 0.97, d) * 0.75);
  vec2 q = p - gaze;
  float pupil;
  if (bonus > 0.5) {
    vec2 a = abs(q);
    pupil = clamp((0.88 - (sqrt(a.x) + sqrt(a.y))) / max(aa * 3.0, 1e-4) + 0.5, 0.0, 1.0);
  } else {
    float k = max(1.0 - (q.y / 0.78) * (q.y / 0.78), 0.0);
    float hw = 0.2 * pow(k, 0.9);
    pupil = clamp((hw - abs(q.x)) / max(aa * 2.0, 1e-4) + 0.5, 0.0, 1.0) * step(abs(q.y), 0.78);
  }
  vec3 c = mix(iris, vec3(0.031, 0.039, 0.024), pupil);
  c = mix(c, vec3(1.0, 0.992, 0.886), clamp((0.15 - length(p + vec2(0.34, 0.4))) / aa + 0.5, 0.0, 1.0));
  c = mix(c, vec3(1.0, 0.992, 0.886), clamp((0.055 - length(p - vec2(0.3, -0.42))) / aa + 0.5, 0.0, 1.0) * 0.8);
  float ring = clamp((d - (1.0 - max(0.045, 1.5 * aa))) / aa + 0.5, 0.0, 1.0);
  return mix(c, vec3(1.0, 0.992, 0.886), ring);
}
vec3 shut_lid(vec2 p, float d, float aa) {
  float sag = 0.24 - 0.34 * p.x * p.x;
  vec3 upper = mix(vec3(0.216, 0.275, 0.227), vec3(0.165, 0.216, 0.173), smoothstep(-0.6, 0.3, p.y));
  vec3 c = p.y < sag ? upper : vec3(0.106, 0.149, 0.118);
  float near = abs(p.y - sag) / sqrt(1.0 + pow(0.68 * p.x, 2.0));
  c = mix(c, vec3(0.78, 0.8, 0.706), clamp((0.036 - near) / aa + 0.5, 0.0, 1.0) * (1.0 - smoothstep(0.74, 0.84, d)));
  for (int i = 0; i < 5; i++) {
    float lx = -0.42 + float(i) * 0.21;
    float ang = lx * 0.9;
    float ly = 0.24 - 0.34 * lx * lx;
    vec2 r = p - vec2(lx, ly);
    float along = r.x * sin(ang) + r.y * cos(ang);
    float across = abs(r.x * cos(ang) - r.y * sin(ang));
    float tick = clamp(((0.04 * (1.0 - along / 0.17)) - across) / aa + 0.5, 0.0, 1.0) * step(0.0, along) * step(along, 0.17);
    c = mix(c, vec3(0.78, 0.8, 0.706), tick);
  }
  float ring = clamp((d - (1.0 - max(0.05, 1.5 * aa))) / aa + 0.5, 0.0, 1.0);
  return mix(c, mix(vec3(0.522, 0.561, 0.49), vec3(0.78, 0.8, 0.706), clamp(0.4 + 0.4 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)), ring);
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
  vec4 color = vec4(vec3(0.012, 0.02, 0.012) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * bright_look * fade_out;
  color = over(vec4(vec3(0.965, 0.847, 0.29) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = bright_look > 0.001 ? mix(shut_lid(p, d, aa), open_eye(p, d, aa, bonus), bright_look) : shut_lid(p, d, aa);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
