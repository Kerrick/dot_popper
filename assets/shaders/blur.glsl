// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One direction of a separable Gaussian blur, for the bright dots' and
// droplets' glow: five reads, the center and two on each side between
// pixels, so the linear filter does the work of nine taps.
// DotPopper::Presentation::BlurKernel computes +offsets+ and +weights+;
// +texel_step+ is one blurred pixel along the blur's direction, in uv.

uniform vec2 texel_step;
uniform float offsets[3];
uniform float weights[3];

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
  vec4 sum = Texel(tex, uv) * weights[0];
  for (int i = 1; i < 3; i++) {
    sum += Texel(tex, uv + texel_step * offsets[i]) * weights[i];
    sum += Texel(tex, uv - texel_step * offsets[i]) * weights[i];
  }
  return sum * color;
}
