// SPDX-License-Identifier: LicenseRef-setdef-all-rights-reserved
//
// One dot as Santa's face, filling the dot's circle: his red hat flopped
// to one side with a fur trim and a pompom, rosy cheeks and nose, and a
// white curly beard and mustache that fill the lower half. A bright dot
// is Santa awake, his eyes twinkling. A popped dot is the same Santa
// asleep after his night, in the dark: his eyes shut, his mouth open in a
// snore. Every sleeping Santa is alike. The vertex color says what kind
// of dot it is, as in dot.glsl.

uniform float extent;
uniform float shadow_offset;
uniform float shadow_reach;
uniform float shadow_alpha;
uniform float halo_width;
uniform float halo_alpha;
uniform vec3 alarm;
uniform float seed;
uniform float time;  // seconds, for the twinkle in his eyes

const vec3 L = vec3(-0.4336, -0.6401, 0.6341);

vec4 over(vec4 top, vec4 bottom) { return top + bottom * (1.0 - top.a); }
float cover_of(float sd, float aa) { return clamp(0.5 - sd / aa, 0.0, 1.0); }
float hash1(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 q) { return vec2(hash1(q), hash1(q + 19.19)); }
float ellipse(vec2 p, vec2 c, vec2 r) { return (length((p - c) / r) - 1.0) * min(r.x, r.y); }

// Curly locks: soft lumps, each lit from the top left, darker in the
// creases between them. Returns light from 0 (crease) to 1 (crown).
float curls(vec2 q) {
  vec2 i = floor(q), f = fract(q);
  float best = 9.0;
  vec2 to = vec2(0.0);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = g + 0.2 + 0.6 * hash2(i + g) - f;
      float dd = dot(o, o);
      if (dd < best) { best = dd; to = o; }
    }
  }
  float r = sqrt(best);
  float lit = clamp(0.6 + 0.9 * dot(-to, vec2(-0.6, -0.8)), 0.0, 1.0);
  return mix(lit, 0.15, smoothstep(0.3, 0.78, r));
}

// A lash hanging from a shut lid at +lx+, as a signed distance.
float segment_lash(vec2 r, float lx) {
  vec2 dir = normalize(vec2(lx * 5.0, 1.0));
  float along = dot(r, dir);
  float across = abs(r.x * dir.y - r.y * dir.x);
  return max(across - 0.014 * (1.0 - clamp(along / 0.06, 0.0, 1.0)) - 0.003, max(-along, along - 0.06));
}

vec3 santa(vec2 p, float d, float aa, float fresh, float bonus) {
  float z = sqrt(max(1.0 - min(d, 1.0) * min(d, 1.0), 0.0));
  vec3 n = vec3(p, z);
  float lam = clamp(0.35 + 0.75 * dot(n, L), 0.0, 1.0);

  // Where each part is.
  float trim_mid = -0.3 + 0.16 * p.x * p.x;
  float puff = 0.03 * abs(sin(p.x * 9.0 + 0.6)) + 0.012 * sin(p.x * 23.0);
  float trim = max(trim_mid - 0.13 - puff - p.y, p.y - (trim_mid + 0.12 + puff));
  vec2 pom_c = vec2(0.6, -0.6);
  float pom_r = 0.2 + 0.02 * sin(atan(p.y - pom_c.y, p.x - pom_c.x) * 9.0);
  float pom = length(p - pom_c) - pom_r;
  float hat = p.y - (trim_mid - 0.08);
  float face = ellipse(p, vec2(0.0, 0.0), vec2(0.52, 0.32));
  float brows = min(ellipse(p, vec2(-0.22, -0.13), vec2(0.13, 0.045)), ellipse(p, vec2(0.22, -0.13), vec2(0.13, 0.045)));
  // The mustache: a lobe each side of the nose, curling up at its tip.
  vec2 mq = vec2(abs(p.x), p.y);
  float must_y = 0.22 - 0.16 * smoothstep(0.12, 0.52, mq.x) * smoothstep(0.12, 0.52, mq.x);
  float must = ellipse(mq, vec2(0.25, must_y), vec2(0.27, (0.12 - 0.06 * smoothstep(0.22, 0.52, mq.x)) * (0.45 + 0.55 * smoothstep(0.0, 0.14, mq.x))));
  float nose = length(p - vec2(0.0, 0.09)) - 0.115;
  float mouth = ellipse(p, vec2(0.0, 0.39), vec2(0.11, 0.06));
  vec2 eye_c = vec2(abs(p.x), p.y) - vec2(0.21, -0.04);

  // --- Awake, in the light ---
  float red_shade = clamp(lam + 0.25 * smoothstep(-1.0, -0.4, p.y), 0.0, 1.0);
  vec3 cloth = bonus > 0.5 ? mix(vec3(0.03, 0.24, 0.13), vec3(0.2, 0.66, 0.36), red_shade)
                           : mix(vec3(0.42, 0.04, 0.07), vec3(0.9, 0.16, 0.16), red_shade);
  // A fold running down to the pompom, where the hat flops over.
  float fold = exp(-pow((p.y + 0.62 - 0.9 * (p.x - 0.1) * (p.x - 0.1) + 0.25 * (p.x - 0.1)) / 0.07, 2.0)) * smoothstep(-0.3, 0.2, p.x);
  cloth *= 1.0 - 0.35 * fold;
  cloth = mix(cloth, cloth + vec3(0.18, 0.1, 0.08), exp(-pow((p.y + 0.66 - 0.9 * (p.x - 0.1) * (p.x - 0.1) + 0.25 * (p.x - 0.1) + 0.09) / 0.06, 2.0)) * smoothstep(-0.3, 0.2, p.x) * 0.6);

  float wave = sin(p.x * 17.0 + 1.8 * sin(p.y * 6.0 + p.x * 4.0));
  float lock = 0.5 + 0.5 * wave * (0.7 + 0.3 * sin(p.y * 13.0 + p.x * 9.0));
  vec3 fur = mix(vec3(0.72, 0.76, 0.87), vec3(1.0, 0.995, 0.985), clamp(lam * 0.8 + lock * 0.35, 0.0, 1.0));
  float lock_small = curls(p * 9.0 + 3.1);
  vec3 trim_fur = mix(vec3(0.84, 0.86, 0.93), vec3(1.0, 1.0, 1.0), clamp(lam * 0.8 + lock_small * 0.25, 0.0, 1.0));

  vec3 skin = mix(vec3(0.9, 0.6, 0.5), vec3(1.0, 0.84, 0.73), clamp(lam * 1.1, 0.0, 1.0));
  for (int i = 0; i < 2; i++) {
    float sx = i == 0 ? -1.0 : 1.0;
    skin = mix(skin, vec3(0.97, 0.5, 0.5), exp(-pow((p.x - sx * 0.34) / 0.12, 2.0) - pow((p.y - 0.08) / 0.08, 2.0)) * 0.75);
  }
  vec3 c = mix(fur, skin, cover_of(face, aa));
  // His eyes: dark, crinkled by a smile, each with a twinkle.
  float blink = 0.85 + 0.15 * sin(time * 1.7 + seed * 3.0);
  float eye_open;
  eye_open = cover_of(ellipse(eye_c, vec2(0.0), vec2(0.065, 0.085)), aa);
  c = mix(c, vec3(0.1, 0.06, 0.08), eye_open);
  float glint = cover_of(length(eye_c - vec2(-0.022, -0.03)) - 0.024, aa) * blink;
  c = mix(c, vec3(1.0), glint);
  float crinkle = abs(length((eye_c - vec2(0.0, 0.11)) / vec2(1.0, 0.8)) - 0.1) - 0.008;
  c = mix(c, vec3(0.75, 0.42, 0.36), cover_of(crinkle, aa) * step(0.0, eye_c.y) * step(abs(eye_c.x), 0.07) * 0.8);
  vec3 nose_col = mix(vec3(0.85, 0.36, 0.34), vec3(1.0, 0.62, 0.56), clamp(lam + 0.2, 0.0, 1.0));
  nose_col = mix(nose_col, vec3(1.0, 0.92, 0.88), cover_of(length(p - vec2(-0.035, 0.035)) - 0.03, aa) * 0.85);
  c = mix(c, nose_col, cover_of(nose, aa));
  c = mix(c, mix(vec3(0.45, 0.1, 0.12), vec3(0.28, 0.04, 0.07), smoothstep(0.31, 0.36, p.y)), cover_of(mouth, aa));
  // The mustache, whiter than the beard, shadows the beard below it.
  c *= 1.0 - 0.32 * cover_of(ellipse(mq, vec2(0.25, must_y + 0.05), vec2(0.28, 0.12)), aa * 8.0) * (1.0 - cover_of(must, aa));
  float must_lit = clamp(0.6 + 0.5 * lam - 0.55 * smoothstep(-0.02, 0.1, p.y - must_y), 0.0, 1.0);
  vec3 must_col = mix(vec3(0.74, 0.77, 0.88), vec3(1.0), must_lit);
  must_col *= 0.88 + 0.12 * (0.5 + 0.5 * sin((p.y - must_y) * 60.0 - mq.x * 20.0));
  c = mix(c, must_col, cover_of(must, aa));
  c = mix(c, trim_fur, cover_of(brows, aa));
  c = mix(c, cloth, cover_of(hat, aa));
  // The trim throws a shadow on the brow below it.
  c *= 1.0 - 0.3 * cover_of(trim - 0.04, aa * 8.0) * (1.0 - cover_of(trim, aa)) * step(trim_mid, p.y);
  c = mix(c, trim_fur, cover_of(trim, aa));
  float pom_lit = clamp(0.4 + 0.8 * dot(normalize(p - pom_c + 1e-4), vec2(-0.6, -0.8)) * smoothstep(0.0, pom_r, length(p - pom_c)), 0.0, 1.0);
  vec3 pom_col = mix(vec3(0.76, 0.79, 0.88), vec3(1.0), clamp(pom_lit * 0.6 + lock_small * 0.5, 0.0, 1.0));
  if (bonus > 0.5) {
    // The bonus Santa's hat ends in a gold star instead of a pompom.
    vec2 sq = abs(p - pom_c) / 0.36;
    float star_sd = (sqrt(sq.x) + sqrt(sq.y) - 1.0) * 0.16;
    float star_lit = clamp(0.55 - 1.6 * dot(p - pom_c, vec2(0.53, 0.848)), 0.0, 1.0);
    c = mix(c, mix(vec3(0.85, 0.6, 0.12), vec3(1.0, 0.93, 0.55), star_lit), cover_of(star_sd, aa));
  } else {
    c = mix(c, pom_col, cover_of(pom, aa));
  }
  vec3 awake = c;

  // --- Asleep, in the dark ---
  vec3 night_fur = mix(vec3(0.16, 0.17, 0.26), vec3(0.27, 0.28, 0.39), clamp(lam * 0.8 + lock * 0.2, 0.0, 1.0));
  vec3 night_trim = mix(vec3(0.17, 0.18, 0.27), vec3(0.29, 0.3, 0.41), clamp(lam * 0.8 + lock_small * 0.15, 0.0, 1.0));
  vec3 night_skin = mix(vec3(0.06, 0.045, 0.08), vec3(0.12, 0.09, 0.14), lam);
  vec3 night_cloth = mix(vec3(0.06, 0.02, 0.045), vec3(0.17, 0.05, 0.08), red_shade) * (1.0 - 0.3 * fold);
  vec3 s = mix(night_fur, night_skin, cover_of(face, aa));
  // Shut eyes: a lid's curve, bowed down, with three lashes.
  vec2 e = eye_c;
  float lid = abs(e.y - 0.04 * (1.0 - pow(e.x / 0.09, 2.0))) - 0.02;
  float shut = cover_of(lid, aa) * step(abs(e.x), 0.09);
  for (int i = 0; i < 3; i++) {
    float lx = -0.045 + float(i) * 0.045;
    vec2 r = e - vec2(lx * 1.2, 0.04 * (1.0 - pow(lx * 1.2 / 0.09, 2.0)));
    shut = max(shut, cover_of(segment_lash(r, lx), aa));
  }
  s = mix(s, vec3(0.6, 0.6, 0.74), shut);
  s = mix(s, mix(vec3(0.16, 0.1, 0.14), vec3(0.3, 0.2, 0.24), lam), cover_of(nose, aa));
  float snore = ellipse(p, vec2(0.0, 0.4), vec2(0.11, 0.12));
  s = mix(s, vec3(0.02, 0.012, 0.03), cover_of(snore, aa));
  s *= 1.0 - 0.3 * cover_of(ellipse(mq, vec2(0.25, must_y + 0.05), vec2(0.28, 0.12)), aa * 8.0) * (1.0 - cover_of(must, aa));
  s = mix(s, night_fur * (0.8 + 0.5 * must_lit), cover_of(must, aa));
  s = mix(s, night_trim, cover_of(brows, aa));
  s = mix(s, night_cloth, cover_of(hat, aa));
  s = mix(s, night_trim, cover_of(trim, aa));
  s = mix(s, mix(vec3(0.15, 0.15, 0.22), vec3(0.3, 0.31, 0.42), pom_lit * 0.7 + lock_small * 0.3), cover_of(pom, aa));

  vec3 col = mix(s, awake, fresh);
  float w = mix(max(0.038, 1.5 * aa), max(0.022, 1.5 * aa), fresh);
  float ring = clamp((d - (1.0 - w)) / aa + 0.5, 0.0, 1.0);
  vec3 rim_color = mix(mix(vec3(0.26, 0.26, 0.36), vec3(0.44, 0.45, 0.58), clamp(0.5 + 0.6 * dot(p, vec2(-0.53, -0.848)), 0.0, 1.0)),
                       vec3(1.0, 0.97, 0.92), fresh);
  return mix(col, rim_color, ring);
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
  vec4 color = vec4(vec3(0.008, 0.008, 0.03) * s, s);
  float h = exp(-pow(max(d - 1.0, 0.0) / halo_width, 2.0)) * halo_alpha * fresh * fade_out;
  color = over(vec4(vec3(1.0, 0.9, 0.8) * h, h), color);
  float a = exp(-pow((d - 1.05) / 0.1, 2.0)) * alarmed * fade_out;
  color = over(vec4(alarm * a, a), color);
  float cover = clamp((1.0 - d) / aa + 0.5, 0.0, 1.0);
  vec3 body = santa(p, d, aa, fresh, bonus);
  body = mix(body, alarm, alarmed * smoothstep(0.78, 0.96, d));
  color = over(vec4(body * cover, cover), color) * params.a;
  return vec4(color.rgb / max(color.a, 1e-5), color.a);
}
