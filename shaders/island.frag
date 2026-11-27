#version 460 core
#include <flutter/runtime_effect.glsl>

// ═══════════════════════════════════════════════════════════════════════
//  数学闯关岛 · 黏土玩具风 实时 3D（SDF 光线步进）
//
//  性能约束（手机上必须能跑）：
//   - 只在离屏低分辨率渲染（约 300x650），再放大到全屏
//   - 步进 44 步上限，软阴影 6 步，AO 3 采样
//   - 8 个平台 / 4 棵树 / 3 块礁石 / 灯塔，全部早退
//  uniform 全部用 vec4，避免 vec3 对齐差异导致参数错位。
// ═══════════════════════════════════════════════════════════════════════

uniform vec4 uA; // (w, h, time, fovTan)
uniform vec4 uB; // (cam.x, cam.y, cam.z, levels)
uniform vec4 uC; // (target.x, target.y, target.z, unused)
uniform vec4 uD; // (sun.x, sun.y, sun.z, sunPower)

out vec4 fragColor;

const int STEPS = 36;
const float R_ISLAND = 7.4;
const float H_TOP = 3.55;

float sat(float x) { return clamp(x, 0.0, 1.0); }
vec3 sat3(vec3 v) { return clamp(v, 0.0, 1.0); }

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float vnoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
  return 0.62 * vnoise(p) + 0.38 * vnoise(p * 2.03);
}

float smin(float a, float b, float k) {
  float h = sat(0.5 + 0.5 * (b - a) / k);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float sdRoundBox(vec3 p, vec3 b, float r) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdRoundCyl(vec3 p, float r, float h, float rr) {
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - rr;
}

// ───────── 地形 ─────────

float islandBase(vec2 xz) {
  float r = length(xz);
  float mound = H_TOP * (1.0 - smoothstep(1.1, R_ISLAND, r));
  mound += 0.45 * (1.0 - smoothstep(0.0, 5.2, r));
  return max(0.0, mound);
}

float islandH(vec2 xz) {
  float r = length(xz);
  float rough = (fbm2(xz * 0.62) - 0.5) * 0.26 * smoothstep(1.2, 3.0, r);
  return max(0.0, islandBase(xz) + rough);
}

// 螺旋石阶
float pathMask(vec2 xz) {
  float r = length(xz);
  float t = sat((R_ISLAND - 0.6 - r) / (R_ISLAND - 1.0));
  float ang = atan(xz.y, xz.x);
  float want = -1.5708 + t * 9.2;
  float d = abs(mod(ang - want + 3.14159, 6.28318) - 3.14159);
  return sat(1.0 - d / (mix(0.52, 0.34, t) / max(r, 0.8)));
}

vec3 platformPos(float i, float levels) {
  float n = max(levels - 1.0, 1.0);
  float t = i / n;
  float ang = -1.5708 + t * 9.2;
  float r = mix(R_ISLAND - 1.0, 1.15, t);
  vec2 xz = vec2(cos(ang), sin(ang)) * r;
  return vec3(xz.x, islandBase(xz) + 0.30, xz.y);
}

// ───────── 距离场 ─────────

const float M_SAND = 2.0;
const float M_STONE = 3.0;
const float M_ROCK = 4.0;
const float M_TRUNK = 5.0;
const float M_LEAF = 6.0;
const float M_WALL = 7.0;
const float M_ROOF = 8.0;
const float M_DISC = 9.0;

float mapScene(vec3 p, out float mat) {
  vec2 xz = p.xz;
  float h = islandH(xz);
  float d = (p.y - h) * 0.60;
  mat = (h < 0.42) ? M_SAND : 1.0; // 1 = 草
  if (pathMask(xz) > 0.55) {
    mat = M_STONE;
    d -= 0.03;
  }

  // 关卡平台（8 个）
  for (int i = 0; i < 8; i++) {
    if (float(i) >= uB.w) break;
    vec3 c = platformPos(float(i), uB.w);
    float dd = sdRoundCyl(p - c, 0.46, 0.075, 0.06);
    if (dd < d) {
      d = smin(d, dd, 0.09);
      mat = M_DISC;
    }
    float db = length(p - (c + vec3(0.0, 0.30, 0.0))) - 0.20;
    if (db < d) {
      d = smin(d, db, 0.06);
      mat = M_DISC;
    }
  }

  // 椰子树（4 棵）
  for (int i = 0; i < 4; i++) {
    float a = 0.9 + float(i) * 1.83;
    vec2 t0 = vec2(cos(a), sin(a)) * 5.6;
    vec3 b = vec3(t0.x, islandH(t0), t0.y);
    vec3 tp = b + vec3(0.22 * sin(float(i) * 2.1), 1.5, 0.16 * cos(float(i) * 1.7));
    vec3 pa = p - b;
    vec3 ba = tp - b;
    float hh = sat(dot(pa, ba) / dot(ba, ba));
    float dt = length(pa - ba * hh) - 0.105;
    if (dt < d) {
      d = smin(d, dt, 0.10);
      mat = M_TRUNK;
    }
    for (int j = 0; j < 3; j++) {
      float aa = float(j) * 2.09 + float(i);
      vec3 c = tp + vec3(cos(aa) * 0.30, 0.10 + 0.05 * float(j), sin(aa) * 0.30);
      float dl = length(p - c) - (0.44 - 0.05 * float(j));
      if (dl < d) {
        d = smin(d, dl, 0.16);
        mat = M_LEAF;
      }
    }
  }

  // 礁石（3 块）
  for (int i = 0; i < 3; i++) {
    float a = 1.7 + float(i) * 2.1;
    vec2 xz2 = vec2(cos(a), sin(a)) * (R_ISLAND - 0.30);
    vec3 c = vec3(xz2.x, islandBase(xz2) * 0.35 + 0.10, xz2.y);
    float dr = (length((p - c) / vec3(0.58, 0.42, 0.52)) - 1.0) * 0.5;
    if (dr < d) {
      d = smin(d, dr, 0.14);
      mat = M_ROCK;
    }
  }

  // 山顶灯塔 + 两个小塔楼
  vec3 topC = vec3(0.0, islandBase(vec2(0.0)) + 0.10, 0.0);
  float dt = sdRoundCyl(p - (topC + vec3(0.0, 0.62, 0.0)), 0.30, 0.60, 0.04);
  if (dt < d) { d = smin(d, dt, 0.08); mat = M_WALL; }
  float dl = sdRoundCyl(p - (topC + vec3(0.0, 1.34, 0.0)), 0.24, 0.16, 0.03);
  if (dl < d) { d = smin(d, dl, 0.05); mat = M_WALL; }
  float dr2 = sdRoundCyl(p - (topC + vec3(0.0, 1.62, 0.0)), 0.30, 0.16, 0.02);
  if (dr2 < d) { d = smin(d, dr2, 0.05); mat = M_ROOF; }
  for (int i = 0; i < 2; i++) {
    float a = float(i) * 3.14 + 0.6;
    vec3 c = topC + vec3(cos(a) * 0.62, 0.30, sin(a) * 0.62);
    float db = sdRoundBox(p - c, vec3(0.17, 0.34, 0.17), 0.05);
    if (db < d) { d = smin(d, db, 0.06); mat = M_WALL; }
  }

  return d;
}

float mapD(vec3 p) {
  float m;
  return mapScene(p, m);
}

// ───────── 着色 ─────────

vec3 discColor(vec3 p) {
  float k = fract(atan(p.z, p.x) / 6.28318 * 3.0);
  if (k < 0.25) return vec3(1.0, 0.72, 0.76);
  if (k < 0.50) return vec3(1.0, 0.86, 0.52);
  if (k < 0.75) return vec3(0.62, 0.85, 0.96);
  return vec3(0.70, 0.92, 0.66);
}

vec3 materialColor(float mat, vec3 p) {
  if (mat < 1.5) {
    return mix(vec3(0.42, 0.72, 0.30), vec3(0.58, 0.85, 0.38), fbm2(p.xz * 1.7));
  } else if (mat < M_SAND + 0.5) {
    return mix(vec3(0.94, 0.85, 0.66), vec3(1.0, 0.93, 0.78), fbm2(p.xz * 2.6));
  } else if (mat < M_STONE + 0.5) {
    return mix(vec3(0.74, 0.74, 0.72), vec3(0.90, 0.90, 0.88), fbm2(p.xz * 3.1));
  } else if (mat < M_ROCK + 0.5) {
    return vec3(0.62, 0.65, 0.68);
  } else if (mat < M_TRUNK + 0.5) {
    return vec3(0.72, 0.52, 0.32);
  } else if (mat < M_LEAF + 0.5) {
    return vec3(0.36, 0.70, 0.32);
  } else if (mat < M_WALL + 0.5) {
    return vec3(0.97, 0.95, 0.92);
  } else if (mat < M_ROOF + 0.5) {
    return vec3(0.92, 0.48, 0.30);
  }
  return discColor(p);
}

vec3 calcNormal(vec3 p, float eps) {
  vec2 e = vec2(eps, 0.0);
  return normalize(vec3(
    mapD(p + e.xyy) - mapD(p - e.xyy),
    mapD(p + e.yxy) - mapD(p - e.yxy),
    mapD(p + e.yyx) - mapD(p - e.yyx)));
}

float softShadow(vec3 ro, vec3 rd) {
  float res = 1.0;
  float t = 0.10;
  for (int i = 0; i < 6; i++) {
    float h = mapD(ro + rd * t);
    res = min(res, 7.0 * h / t);
    t += clamp(h, 0.10, 0.9);
    if (res < 0.05 || t > 16.0) break;
  }
  return sat(res);
}

float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float sca = 1.0;
  for (int i = 0; i < 3; i++) {
    float h = 0.03 + 0.16 * float(i);
    occ += (h - mapD(p + n * h)) * sca;
    sca *= 0.75;
  }
  return sat(1.0 - 1.8 * occ);
}

vec3 skyColor(vec3 rd, vec3 sunDir) {
  vec3 col = mix(vec3(0.86, 0.96, 1.0), vec3(0.42, 0.76, 0.95), sat(rd.y * 1.5));
  col = mix(col, vec3(1.0, 0.97, 0.90), sat(0.30 - abs(rd.y)) * 0.5);
  float s = sat(dot(rd, sunDir));
  col += vec3(1.0, 0.94, 0.76) * pow(s, 400.0) * 1.8;
  col += vec3(1.0, 0.92, 0.72) * pow(s, 22.0) * 0.16;
  if (rd.y > 0.03) {
    vec2 cp = rd.xz / max(rd.y, 0.10) * 0.5;
    float c = fbm2(cp * 1.2);
    col = mix(col, vec3(1.0), smoothstep(0.55, 0.85, c) * smoothstep(0.03, 0.28, rd.y) * 0.8);
  }
  return col;
}

vec3 shadeWater(vec3 p, vec3 rd, vec3 sunDir, float t) {
  vec2 q = p.xz * 1.4;
  float w1 = sin(q.x * 1.7 + t * 1.1) + sin(q.y * 2.1 - t * 0.9);
  float w2 = sin((q.x + q.y) * 3.1 + t * 1.7);
  vec3 n = normalize(vec3(w1 * 0.05, 1.0, w2 * 0.05));

  float r = length(p.xz);
  float shallowK = 1.0 - smoothstep(R_ISLAND - 1.6, R_ISLAND + 1.2, r);
  vec3 base = mix(vec3(0.10, 0.62, 0.68), vec3(0.32, 0.86, 0.82), shallowK);

  float ndl = sat(dot(n, sunDir));
  vec3 col = base * (0.60 + 0.50 * ndl);
  float fres = pow(1.0 - sat(dot(-rd, n)), 3.0);
  col = mix(col, vec3(0.75, 0.92, 0.99), 0.30 + 0.45 * fres);
  float foam = smoothstep(0.26, 0.02, abs(r - (R_ISLAND - 0.55 + 0.20 * sin(t * 1.2 + r * 3.0))));
  col = mix(col, vec3(1.0), foam * 0.7);
  vec3 hv = normalize(sunDir - rd);
  col += vec3(1.0, 0.97, 0.88) * pow(sat(dot(n, hv)), 80.0) * 1.1;
  return col;
}

vec3 shadeSurface(vec3 p, vec3 n, vec3 rd, float mat, vec3 sunDir) {
  vec3 base = materialColor(mat, p);
  float sha = softShadow(p + n * 0.04, sunDir);
  float ao = calcAO(p, n);
  float ndl = sat(dot(n, sunDir));

  float up = sat(n.y * 0.5 + 0.5);
  vec3 skyLight = mix(vec3(0.55, 0.45, 0.38), vec3(0.70, 0.82, 0.95), up);

  vec3 col = base * (0.32 * ao);
  col += base * skyLight * 0.40 * ao;
  col += base * vec3(1.0, 0.96, 0.88) * ndl * sha;

  vec3 hv = normalize(sunDir - rd);
  col += vec3(1.0, 0.98, 0.92) * pow(sat(dot(n, hv)), 24.0) * 0.09 * sha;
  col += base * pow(1.0 - sat(dot(n, -rd)), 3.0) * 0.20;
  return col;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - 0.5 * uA.xy) / uA.y;
  float fovTan = uA.w;
  float tm = uA.z;

  vec3 ro = uB.xyz;
  vec3 ta = uC.xyz;
  vec3 sunDir = normalize(uD.xyz);

  vec3 fw = normalize(ta - ro);
  vec3 rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
  vec3 up = cross(rt, fw);
  vec3 rd = normalize(fw + rt * uv.x * fovTan * 2.0 + up * uv.y * fovTan * 2.0);

  // 岛的包围球：射线打不到就直接跳过整个场景
  vec3 bc = vec3(0.0, 1.8, 0.0);
  float br = 8.6;
  vec3 oc = ro - bc;
  float bq = dot(oc, rd);
  float bdisc = bq * bq - (dot(oc, oc) - br * br);

  float t = 0.06;
  float mat = 0.0;
  bool hit = false;

  if (bdisc > 0.0) {
    float tEntry = max(-bq - sqrt(bdisc), 0.08);
    t = tEntry;
    for (int i = 0; i < STEPS; i++) {
      vec3 p = ro + rd * t;
      float m;
      float d = mapScene(p, m);
      if (d < 0.003 * t) {
        hit = true;
        mat = m;
        break;
      }
      t += d * 0.75;
      if (t > 34.0) break;
    }
  }

  float tw = 1e9;
  if (rd.y < -0.0001) tw = -ro.y / rd.y;

  vec3 col;
  if (hit) {
    vec3 p = ro + rd * t;
    vec3 n = calcNormal(p, max(0.002 * t, 0.005));
    col = shadeSurface(p, n, rd, mat, sunDir);
    col = mix(col, vec3(0.72, 0.93, 0.95), sat(1.0 - p.y * 0.55) * 0.10);
  } else if (tw > 0.0 && tw < 1e8) {
    col = shadeWater(ro + rd * tw, rd, sunDir, tm);
  } else {
    col = skyColor(rd, sunDir);
  }

  float dist = hit ? t : (tw < 1e8 ? tw : 1000.0);
  col = mix(col, skyColor(rd, sunDir), sat((dist - 16.0) / 46.0) * 0.55);

  float lum = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(lum), col, 1.14);
  col = col / (col + vec3(0.88)) * 1.30;
  col = pow(sat3(col), vec3(0.95));
  col *= 1.0 - 0.16 * dot(uv, uv);

  fragColor = vec4(sat3(col), 1.0);
}