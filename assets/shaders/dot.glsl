// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot, drawn from its geometry at the screen's own resolution, so it
// is crisp at any size. The game draws a square around each dot with
// this shader and says what kind of dot it is in the vertex color:
//
//   red    how fresh it looks, 1 for fresh and 0 for popped (between the
//          two only while a dot changes, for a moment after it pops)
//   green  how strongly its rim glows from a wrong tap
//   blue   how much of a bonus dot it is, 1 for a bonus dot and 0 for
//          an ordinary one (it fades with its freshness as it pops)
//   alpha  how opaque the whole dot is
//
// A fresh dot is light, warm, and glossy, and ends in a thin bright rim
// whose outer edge is its hit circle, smoothed over one device pixel, so
// a player tracks exactly where a tap reaches it; its halo is faint and
// only a few pixels deep. A popped dot is dark, matte, and fully opaque
// to that same edge, with a thin light rim and a sunken crater, so a
// fresh dot beneath it is plainly covered. Each dot casts a small,
// tight shadow on whatever lies under it, which shows which dot is on
// top. A bonus dot, earned by a streak, is a fresh dot in mint in place of
// amber, with a dark four-pointed star on its face and a stronger halo:
// the star is a shape, so it needs no color to be seen, and it is as
// bright overall as any fresh dot, so it is plainly the dot to pop. The sizes and colors come from DotPopper::Presentation::Look.

uniform float extent;        // the square's half side, in radii
uniform float rim;           // the fresh rim's width, in radii
uniform float shadow_offset; // how far down the shadow falls, in radii
uniform float shadow_reach;  // the shadow's radius, in radii
uniform float shadow_alpha;
uniform float halo_width;    // how deep the halo is past the edge, in radii
uniform float halo_alpha;

uniform vec3 fresh_light;
uniform vec3 fresh_body;
uniform vec3 fresh_deep;
uniform vec3 fresh_bounce;
uniform vec3 fresh_rim;
uniform vec3 bonus_light;
uniform vec3 bonus_body;
uniform vec3 bonus_deep;
uniform vec3 bonus_bounce;
uniform vec3 bonus_rim;
uniform vec3 bonus_mark;
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

vec3 fresh_shade(vec2 p, float d, float lit, float aa, float bonus) {
  vec3 light = mix(fresh_light, bonus_light, bonus);
  vec3 body = mix(fresh_body, bonus_body, bonus);
  vec3 deep = mix(fresh_deep, bonus_deep, bonus);
  vec3 bounce_color = mix(fresh_bounce, bonus_bounce, bonus);
  vec3 rim_color = mix(fresh_rim, bonus_rim, bonus);
  vec3 c = mix(deep, body, smoothstep(-0.35, 0.45, lit));
  c = mix(c, light, smoothstep(0.45, 1.0, lit) * 0.75);
  c = mix(c, deep, smoothstep(0.74, 1.0, d) * 0.4);
  // Light bounced up into the lower edge, as through a gumdrop.
  float bounce = smoothstep(0.6, 0.9, d) * (1.0 - smoothstep(0.9, 1.0, d)) * clamp(-lit, 0.0, 1.0);
  c = mix(c, bounce_color, bounce * 0.7);
  // A gloss crescent along the upper left edge.
  float outer = 1.0 - smoothstep(0.80, 0.84, length(p + vec2(0.02, 0.02)));
  float inner = 1.0 - smoothstep(0.78, 0.86, length(p - vec2(0.12, 0.17)));
  float crescent = clamp(outer - inner, 0.0, 1.0) * smoothstep(-0.1, 0.6, lit);
  c = mix(c, gloss, crescent * 0.6);
  // And a highlight, an oval tipped toward the light.
  vec2 q = p - vec2(-0.34, -0.47);
  q = vec2(q.x * 0.83 + q.y * 0.56, -q.x * 0.56 + q.y * 0.83);
  float highlight = 1.0 - smoothstep(0.45, 1.0, length(q / vec2(0.25, 0.13)));
  c = mix(c, gloss, highlight * 0.92);
  // A bonus dot's star: sqrt|x| + sqrt|y| is a four-pointed star whose
  // tips reach 0.58 along each axis, drawn dark on the bright body.
  float arms = sqrt(abs(p.x)) + sqrt(abs(p.y));
  float star = clamp((0.762 - arms) / max(fwidth(arms), 1e-4) + 0.5, 0.0, 1.0);
  c = mix(c, bonus_mark, star * bonus);
  // The rim: at least a pixel and a half wide, its inner edge as sharp
  // as its outer one, brightest toward the light.
  float width = max(rim, 1.5 * aa);
  float ring = clamp((d - (1.0 - width)) / aa + 0.5, 0.0, 1.0);
  return mix(c, mix(bounce_color, rim_color, 0.55 + 0.45 * lit), ring);
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
  float bonus = params.b;
  vec2 p = (uv * 2.0 - 1.0) * extent;
  float d = length(p);
  float aa = max(fwidth(d), 1e-4);
  float lit = clamp(dot(p, LIGHT), -1.0, 1.0);

  // Beneath the disc: its shadow, its halo, and the alarm's glow.
  float fade_out = 1.0 - smoothstep(extent - 0.1, extent, d);
  float s = (1.0 - smoothstep(shadow_reach - 0.2, shadow_reach, length(p - vec2(0.0, shadow_offset)))) * shadow_alpha;
  vec4 color = vec4(shadow * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * (1.0 + 2.0 * bonus) * freshness * fade_out;
  color = over(vec4(mix(halo, bonus_body, bonus) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);

  // The disc itself, its edge smoothed over one device pixel.
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = mix(popped_shade(p, d, lit), fresh_shade(p, d, lit, aa, bonus), freshness);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
