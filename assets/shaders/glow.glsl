// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A soft round droplet in the vertex color, brightest in the middle, for
// a pop's burst and a new best's sparkles. Drawn with additive blending.

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
  float d = length(uv * 2.0 - 1.0);
  return vec4(color.rgb, color.a * (1.0 - smoothstep(0.3, 1.0, d)));
}
