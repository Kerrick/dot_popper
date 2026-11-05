// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One dot, drawn from its geometry at the screen's own resolution, so it
// is crisp at any size. The game draws a square around each dot with
// this shader and says what kind of dot it is in the vertex color:
//
//   red    how fresh it looks, 1 for fresh and 0 for popped (between the
//          two only while a dot changes, for a moment after it pops)
//   green  how strongly its rim glows from a wrong tap
//   alpha  how opaque the whole dot is
//
// A fresh dot is light, warm, and glossy, with a soft halo. A popped dot
// is dark, matte, and fully opaque, with a thin light rim and a sunken
// crater, so a fresh dot beneath it is plainly covered. Each dot casts a
// shadow on whatever lies under it, which shows which dot is on top.
// The colors come from DotPopper::Presentation::Look.

uniform float extent;        // the square's half side, in radii
uniform float shadow_offset; // how far down the shadow falls, in radii
uniform float shadow_alpha;
uniform float halo_alpha;

uniform vec3 fresh_light;
uniform vec3 fresh_body;
uniform vec3 fresh_deep;
uniform vec3 fresh_bounce;
uniform vec3 gloss;
uniform vec3 halo;
uniform vec3 popped_top;
uniform vec3 popped_bottom;
uniform vec3 popped_rim;
uniform vec3 popped_crater;
uniform vec3 popped_lip;
uniform vec3 shadow;
uniform vec3 alarm;

// Toward the light: up and to the left.
const vec2 LIGHT = vec2(-0.5300, -0.8480);

// Premultiplied "over".
vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }

vec3 fresh_shade(vec2 p, float d, float lit) {
  vec3 c = mix(fresh_deep, fresh_body, smoothstep(-0.35, 0.45, lit));
  c = mix(c, fresh_light, smoothstep(0.45, 1.0, lit) * 0.75);
  c = mix(c, fresh_deep, smoothstep(0.74, 1.0, d) * 0.4);
  // Light bounced up into the lower edge, as through a gumdrop.
  float bounce = smoothstep(0.6, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d)) * clamp(-lit, 0.0, 1.0);
  c = mix(c, fresh_bounce, bounce * 0.7);
  // A gloss crescent along the upper left edge.
  float outer = 1.0 - smoothstep(0.80, 0.84, length(p + vec2(0.02, 0.02)));
  float inner = 1.0 - smoothstep(0.78, 0.86, length(p - vec2(0.12, 0.17)));
  float crescent = clamp(outer - inner, 0.0, 1.0) * smoothstep(-0.1, 0.6, lit);
  c = mix(c, gloss, crescent * 0.6);
  // And a highlight, an oval tipped toward the light.
  vec2 q = p - vec2(-0.34, -0.47);
  q = vec2(q.x * 0.83 + q.y * 0.56, -q.x * 0.56 + q.y * 0.83);
  float highlight = 1.0 - smoothstep(0.45, 1.0, length(q / vec2(0.25, 0.13)));
  return mix(c, gloss, highlight * 0.92);
}

vec3 popped_shade(vec2 p, float d, float lit) {
  vec3 c = mix(popped_bottom, popped_top, clamp(0.5 + 0.5 * lit, 0.0, 1.0));
  // The crater: sunken, so its wall toward the light is in shadow and
  // the far wall catches the light.
  float crater = 1.0 - smoothstep(0.44, 0.48, d);
  c = mix(c, popped_crater, crater * 0.92);
  float wall = smoothstep(0.38, 0.47, d) * (1.0 - smoothstep(0.47, 0.58, d));
  float facing = dot(p / max(d, 1e-4), -LIGHT);
  c = mix(c, popped_lip, wall * clamp(facing, 0.0, 1.0) * 0.95);
  c = mix(c, popped_crater, wall * clamp(-facing, 0.0, 1.0) * 0.7);
  // A thin rim, lighter toward the light.
  float rim = smoothstep(0.86, 0.91, d);
  return mix(c, popped_rim, rim * (0.65 + 0.35 * lit));
}

vec4 effect(vec4 params, Image tex, vec2 uv, vec2 screen) {
  float freshness = params.r;
  float alarmed = params.g;
  vec2 p = (uv * 2.0 - 1.0) * extent;
  float d = length(p);
  float aa = max(fwidth(d), 1e-4);
  float lit = clamp(dot(p, LIGHT), -1.0, 1.0);

  // Beneath the disc: its shadow, its halo, and the alarm's glow.
  float fade_out = 1.0 - smoothstep(extent - 0.25, extent, d);
  float s = (1.0 - smoothstep(0.8, 1.25, length(p - vec2(0.0, shadow_offset)))) * shadow_alpha;
  vec4 color = vec4(shadow * s, s);
  float h = exp(-pow(max(d - 0.9, 0.0) / 0.3, 2.0)) * halo_alpha * freshness * fade_out;
  color = over(vec4(halo * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);

  // The disc itself, its edge smoothed over one device pixel.
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = mix(popped_shade(p, d, lit), fresh_shade(p, d, lit), freshness);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
