// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// The night the dots play on: deep ink-indigo, lighter in a soft pool
// toward the middle and darker at the edges, dithered so the gradient
// never bands.

uniform vec2 size; // the screen, in graphics units
uniform vec3 ink_top;
uniform vec3 ink_bottom;
uniform vec3 ink_glow;
uniform vec3 ink_edge;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
  vec3 c = mix(ink_top, ink_bottom, smoothstep(0.0, 1.0, uv.y));
  vec2 from_middle = (uv - vec2(0.5, 0.4)) * size / max(size.x, size.y);
  c = mix(c, ink_glow, (1.0 - smoothstep(0.0, 0.62, length(from_middle))) * 0.5);
  c = mix(c, ink_edge, smoothstep(0.75, 1.55, length((uv - 0.5) * 2.0)) * 0.75);
  float noise = fract(sin(dot(screen, vec2(12.9898, 78.233))) * 43758.5453);
  return vec4(c + (noise - 0.5) / 255.0, 1.0);
}
