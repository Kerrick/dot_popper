// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as a snowman's face, a packed snowball that fills the dot's
// circle: a striped knit hat pulled down over the top, coal eyes and a
// coal smile, a carrot nose, cold cheeks. A bright dot is the snowman,
// white and glittering. A popped dot is the same snowman melted: a dark
// round puddle, slush at its edge, with his hat, carrot and coal lying in
// it. Every puddle is alike. The vertex color says what kind of dot it
// is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform float time;  // seconds, for the glitter

const vec3 L = vec3(-0.4336, -0.6401, 0.6341);
const vec2 LIGHT = vec2(-0.53, -0.848);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float hash(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  f = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float ellipse(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }
float segment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a, ba = b - a;
  return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}
// A lump of coal: a rough oval, as a signed distance.
float coal(vec2 p, vec2 c, float r) {
  vec2 q = p - c;
  float a = atan(q.y, q.x);
  return length(q / vec2(1.0, 0.88)) - r * (1.0 + 0.07 * sin(a * 3.0 + c.x * 7.0) + 0.03 * sin(a * 5.0 + c.y * 11.0));
}
// The carrot, from its root at +a+ to its tip at +b+.
float carrot(vec2 p, vec2 a, vec2 b, float root) {
  vec2 ba = b - a;
  float t = clamp(dot(p - a, ba) / dot(ba, ba), 0.0, 1.0);
  return length(p - a - ba * t) - root * (1.0 - t) - 0.008;
}
vec3 carrot_color(vec2 p, vec2 a, vec2 b, float root, float lit_side) {
  vec2 ba = b - a;
  vec2 n = normalize(vec2(-ba.y, ba.x));
  float t = clamp(dot(p - a, ba) / dot(ba, ba), 0.0, 1.0);
  float across = dot(p - a, n) / max(root * (1.0 - t) + 0.01, 0.01);
  vec3 c = mix(vec3(0.78, 0.3, 0.04), vec3(1.0, 0.62, 0.22), clamp(0.5 + 0.5 * across * lit_side, 0.0, 1.0));
  // The rings round a carrot.
  float ring = smoothstep(0.75, 1.0, abs(sin(t * 34.0)));
  return mix(c, vec3(0.62, 0.22, 0.03), ring * 0.45 * (1.0 - t));
}

vec3 snowman(vec2 p, float d, float aa, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  vec3 n = normalize(vec3(p, z) + vec3(noise(p * 6.0) - 0.5, noise(p * 6.0 + 9.0) - 0.5, 0.0) * 0.22);
  float lam = clamp(dot(n, L), 0.0, 1.0);
  // Packed snow: white in the light, cold blue in its shade.
  vec3 c = mix(vec3(0.66, 0.74, 0.9), vec3(1.0, 1.0, 1.0), smoothstep(0.05, 0.75, lam));
  c = mix(c, vec3(0.8, 0.86, 0.98), smoothstep(0.85, 1.0, d) * 0.5);
  // Glitter where the light catches the crust.
  float g = step(0.985, hash(floor(p * 60.0) + floor(seed))) * (0.5 + 0.5 * sin(time * 3.0 + hash(floor(p * 60.0)) * 30.0));
  c = mix(c, vec3(1.0), g * lam);
  // Cold cheeks.
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    c = mix(c, vec3(1.0, 0.72, 0.78), exp(-pow((p.x - sx * 0.42) / 0.13, 2.0) - pow((p.y - 0.1) / 0.09, 2.0)) * 0.55);
  }
  // Coal eyes and a coal smile, each lump with a glint.
  float eyes = min(coal(p, vec2(-0.24, -0.1), 0.095), coal(p, vec2(0.24, -0.1), 0.095));
  float smile = 1.0;
  for (int i = 0; i < 5; i++) {
    float t = (float(i) - 2.0) / 2.0;
    smile = min(smile, coal(p, vec2(t * 0.32, 0.36 + 0.09 * (1.0 - t * t) - 0.08), 0.05));
  }
  float lumps = min(eyes, smile);
  c *= 1.0 - 0.3 * cover_of(min(coal(p - vec2(0.02, 0.03), vec2(-0.24, -0.1), 0.09), coal(p - vec2(0.02, 0.03), vec2(0.24, -0.1), 0.09)), aa * 6.0);
  vec3 coal_col = vec3(0.07, 0.07, 0.09) + vec3(0.12) * smoothstep(0.6, 1.0, noise(p * 40.0));
  c = mix(c, coal_col, cover_of(lumps, aa));
  float glints = min(length(p - vec2(-0.27, -0.13)) - 0.022, length(p - vec2(0.21, -0.13)) - 0.022);
  c = mix(c, vec3(0.9, 0.92, 1.0), cover_of(glints, aa));
  // The carrot, stuck in at a slant.
  vec2 ra = vec2(0.0, 0.08), rb = vec2(0.44, 0.17);
  c *= 1.0 - 0.3 * cover_of(carrot(p - vec2(0.02, 0.05), ra, rb, 0.075), aa * 6.0);
  c = mix(c, carrot_color(p, ra, rb, 0.075, -1.0), cover_of(carrot(p, ra, rb, 0.075), aa));

  // The knit hat, pulled down over the top, its cuff ribbed.
  float brim = -0.36 + 0.12 * p.x * p.x;
  float in_hat = cover_of(p.y - brim, aa);
  float cuff = cover_of(abs(p.y - (brim - 0.08)) - 0.085, aa);
  float lit = clamp(0.35 + 0.8 * dot(vec3(p, z), L), 0.0, 1.0);
  vec3 body = bonus > 0.5 ? vec3(0.62, 0.8, 0.98) : vec3(0.12, 0.5, 0.3);
  vec3 stripe = bonus > 0.5 ? vec3(0.95, 0.98, 1.0) : vec3(0.98, 0.94, 0.84);
  vec3 cuff_col = bonus > 0.5 ? vec3(0.3, 0.45, 0.8) : vec3(0.82, 0.14, 0.16);
  float band = step(0.5, fract((p.y - brim) * -4.2));
  vec3 hat = mix(body, stripe, band);
  // Knit stitches: little V's in rows.
  vec2 k = vec2(p.x * 14.0, (p.y - brim) * 16.0);
  float vee = abs(fract(k.x) - 0.5) * 2.0 - fract(k.y);
  hat *= 0.82 + 0.18 * smoothstep(-0.3, 0.3, vee);
  float rib = 0.5 + 0.5 * cos(p.x * 60.0);
  vec3 cuffc = cuff_col * (0.78 + 0.22 * rib);
  hat = mix(hat, cuffc, cuff);
  hat *= 0.5 + 0.65 * lit;
  hat = mix(hat, hat * 0.6, smoothstep(-0.2, 0.0, p.y - brim) * (1.0 - cuff));
  hat = mix(hat, hat + vec3(0.18), exp(-pow(length(p - vec2(-0.32, -0.72)) / 0.22, 2.0)) * 0.6);
  hat *= 1.0 - 0.3 * cover_of(abs(p.y - (brim - 0.17)) - 0.012, aa * 2.0);
  // The hat's shadow on the snow below its cuff.
  c *= 1.0 - 0.35 * cover_of(p.y - brim - 0.06, aa * 10.0) * (1.0 - in_hat);
  c = mix(c, hat, in_hat);
  if (bonus > 0.5) {
    vec2 sq = abs(p - vec2(0.0, -0.66)) / 0.3;
    float st = (sqrt(sq.x) + sqrt(sq.y) - 1.0) * 0.13;
    c = mix(c, mix(vec3(0.9, 0.66, 0.15), vec3(1.0, 0.94, 0.6), clamp(0.6 - 2.0 * (p.y + 0.66) - p.x, 0.0, 1.0)), cover_of(st, aa));
  }
  return c;
}

vec3 puddle(vec2 p, float d, float aa) {
  // Dark meltwater, with the night's light lying across it in ripples.
  vec3 c = mix(vec3(0.05, 0.07, 0.12), vec3(0.11, 0.14, 0.22), clamp(0.5 - 0.6 * dot(p, LIGHT), 0.0, 1.0));
  float ripple = sin(length(p - vec2(-0.2, -0.25)) * 26.0) * 0.5 + 0.5;
  c = mix(c, vec3(0.2, 0.25, 0.36), smoothstep(0.8, 1.0, ripple) * smoothstep(0.75, 0.2, length(p - vec2(-0.2, -0.25))) * 0.5);
  // Slush left at the edge.
  float edge_n = noise(vec2(atan(p.y, p.x) * 3.0, 1.0)) * 0.12;
  float slush = smoothstep(0.78 - edge_n, 0.86 - edge_n, d);
  vec3 slush_col = mix(vec3(0.15, 0.17, 0.25), vec3(0.3, 0.33, 0.44), clamp(0.5 + 0.6 * dot(p / max(d, 1e-3), LIGHT) + (noise(p * 9.0) - 0.5) * 0.6, 0.0, 1.0));
  c = mix(c, slush_col, slush);
  // His hat, sodden, lying flat at the top left.
  vec2 hq = p - vec2(-0.3, -0.34);
  float hat = ellipse(hq, vec2(0.0), vec2(0.3, 0.17)) + 0.03 * sin(atan(hq.y, hq.x) * 4.0);
  vec3 hat_col = mix(vec3(0.05, 0.13, 0.09), vec3(0.11, 0.24, 0.16), clamp(0.5 - 2.0 * hq.y, 0.0, 1.0));
  hat_col = mix(hat_col, vec3(0.3, 0.29, 0.26), step(0.5, fract(hq.y * 7.0)) * 0.6);
  hat_col = mix(hat_col, vec3(0.28, 0.05, 0.06), cover_of(abs(hq.y - 0.11) - 0.05, aa) * 0.9);
  c *= 1.0 - 0.35 * cover_of(hat - 0.04, aa * 6.0);
  c = mix(c, hat_col, cover_of(hat, aa));
  // His carrot, floating.
  vec2 ra = vec2(0.05, 0.2), rb = vec2(0.52, -0.08);
  c *= 1.0 - 0.4 * cover_of(carrot(p - vec2(0.02, 0.04), ra, rb, 0.075), aa * 6.0);
  c = mix(c, carrot_color(p, ra, rb, 0.075, 1.0) * 0.62, cover_of(carrot(p, ra, rb, 0.075), aa));
  // His coal, sunk in the water.
  float lumps = min(min(coal(p, vec2(-0.2, 0.34), 0.1), coal(p, vec2(0.04, 0.5), 0.08)),
                    min(min(coal(p, vec2(0.3, 0.4), 0.075), coal(p, vec2(-0.44, 0.12), 0.075)), coal(p, vec2(0.44, 0.14), 0.065)));
  c = mix(c, vec3(0.015, 0.015, 0.02), cover_of(lumps, aa));
  c = mix(c, vec3(0.32, 0.35, 0.45), cover_of(abs(lumps + 0.014) - 0.009, aa) * 0.8 * smoothstep(-0.2, 0.3, -dot(p, LIGHT) + 0.2));
  return c;
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
  vec4 color = vec4(vec3(0.008, 0.012, 0.03) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(vec3(0.85, 0.92, 1.0) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = fresh > 0.001 ? mix(puddle(p, d, aa), snowman(p, d, aa, bonus), fresh) : puddle(p, d, aa);
  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim = mix(mix(vec3(0.3, 0.33, 0.44), vec3(0.52, 0.56, 0.68), clamp(0.5 + 0.6 * dot(p, LIGHT), 0.0, 1.0)), vec3(1.0), fresh);
  body = mix(body, rim, ring);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
