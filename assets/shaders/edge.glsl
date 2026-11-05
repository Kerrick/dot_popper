// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A glow along the screen's edges only, in the vertex color, fading to
// nothing within +band+ units of the edge, so it never covers the dots
// in the middle of the field. A wrong tap lights it.

uniform vec2 size; // the screen, in graphics units
uniform float band;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
  vec2 at = uv * size;
  float edge = min(min(at.x, size.x - at.x), min(at.y, size.y - at.y));
  float glow = 1.0 - smoothstep(0.0, band, edge);
  return vec4(color.rgb, color.a * glow * glow);
}
