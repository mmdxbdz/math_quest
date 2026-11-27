#version 460 core
#include <flutter/runtime_effect.glsl>

// ═══════════════════════════════════════════════════════════════════════
//  数学闯关岛 · 黏土玩具风 实时 3D（SDF 光线步进）
//
//  每个像素：从相机发一条射线 → 沿距离场步进 → 求交点法线
//  → 太阳软阴影 + SDF 环境光遮蔽 + 天光/地面反弹 → 水面 → 天空
//  场景全由代码生成：起伏的岛、沙滩、螺旋石阶、糖果色平台、椰子树、
//  礁石、山顶灯塔、带波纹和浪花的海面。
// ═══════════════════════════════════════════════════════════════════════

uniform vec2 uSize;      // 画布像素尺寸
uniform vec3 uCam;       // 相机位置
uniform vec3 uTarget;    // 看向哪里
uniform float uFovTan;   // tan(fov/2)
uniform float uTime;     // 秒（水波）
uniform float uFocus;    // 保留
uniform float uLevels;   // 螺旋上摆几个平台
uniform vec4 uSun;       // xyz = 太阳方向, w = 强度

out vec4 fragColor;

// ───────────────────────── 基础工具 ─────────────────────────

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

float fbm(vec2 p) {
  float s = 0.0;
  s += 0.50 * vnoise(p);
  s += 0.25 * vnoise(p * 2.03);
  s += 0.125 * vnoise(p * 4.07);
  return s;
}

float smin(float a, float b, float k) {
  float h = sat(0.5 + 0.5 * (b - a) / k);
  return mix(b, a, h) - k * h * (1.0 - h);
}

float sdSphere(vec3 p, float r) { return length(p) - r; }

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
  vec3 pa = p - a, ba = b - a;
  float h = sat(dot(pa, ba) / dot(ba, ba));
  return length(pa - ba * h) - r;
}

// 圆角盒子：黏土感的来源
float sdRoundBox(vec3 p, vec3 b, float r) {
  vec3 q = abs(p) - b;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float sdRoundCyl(vec3 p, float r, float h, float round_) {
  vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - round_;
}

// ───────────────────────── 岛的地形 ─────────────────────────

const float R_ISLAND = 7.4;
const float H_TOP = 3.55;

float islandBase(vec2 xz) {
  float r = length(xz);
  float mound = H_TOP * (1.0 - smoothstep(1.1, R_ISLAND, r));
  mound += 0.45 * (1.0 - smoothstep(0.0, 5.2, r));
  return max(0.0, mound);
}

float islandH(vec2 xz) {
  float r = length(xz);
  float h = islandBase(xz);
  float rough = (fbm(xz * 0.62) - 0.5) * 0.30 * smoothstep(1.2, 3.0, r);
  return max(0.0, h + rough);
}

// 螺旋石阶：0 = 不在路上，1 = 正中间
float pathMask(vec2 xz) {
  float r = length(xz);
  float t = sat((R_ISLAND - 0.6 - r) / (R_ISLAND - 1.0));
  float ang = atan(xz.y, xz.x);
  float want = -1.5708 + t * 9.2;
  float d = abs(mod(ang - want + 3.14159, 6.28318) - 3.14159);
  float width = mix(0.52, 0.34, t) / max(r, 0.8);
  return sat(1.0 - d / width);
}

// ───────────────────────── 场景距离场 ─────────────────────────

const float M_GRASS = 1.0;
const float M_SAND = 2.0;
const float M_STONE = 3.0;
const float M_ROCK = 4.0;
const float M_TRUNK = 5.0;
const float M_LEAF = 6.0;
const float M_WALL = 7.0;
const float M_ROOF = 8.0;
const float M_DISC = 9.0;

vec3 platformPos(float i) {
  float n = max(uLevels - 1.0, 1.0);
  float t = i / n;
  float ang = -1.5708 + t * 9.2;
  float r = mix(R_ISLAND - 1.0, 1.15, t);
  vec2 xz = vec2(cos(ang), sin(ang)) * r;
  return vec3(xz.x, islandBase(xz) + 0.30, xz.y);
}

float mapScene(vec3 p, out float mat) {
  mat = M_GRASS;

  vec2 xz = p.xz;
  float h = islandH(xz);
  float dGround = (p.y - h) * 0.55;

  if (h < 0.42) mat = M_SAND;
  float stone = pathMask(xz);
  if (stone > 0.55) {
    mat = M_STONE;
    dGround -= 0.035;
  }

  float d = dGround;

  // 关卡平台：糖果色圆盘 + 上面的小球
  for (int i = 0; i < 12; i++) {
    if (float(i) >= uLevels) break;
    vec3 c = platformPos(float(i));
    float dDisc = sdRoundCyl(p - c, 0.46, 0.075, 0.06);
    if (dDisc < d) {
      d = smin(d, dDisc, 0.09);
      mat = M_DISC;
    }
    float dBead = sdSphere(p - (c + vec3(0.0, 0.30, 0.0)), 0.20);
    if (dBead < d) {
      d = smin(d, dBead, 0.06);
      mat = M_DISC;
    }
  }

  // 椰子树
  vec3 trunks[6];
  trunks[0] = vec3(-5.6, 0.0, 2.1);
  trunks[1] = vec3(-4.4, 0.0, -3.4);
  trunks[2] = vec3(5.2, 0.0, -2.4);
  trunks[3] = vec3(4.6, 0.0, 3.6);
  trunks[4] = vec3(-0.9, 0.0, 5.9);
  trunks[5] = vec3(1.9, 0.0, -6.0);

  for (int i = 0; i < 6; i++) {
    vec3 b = trunks[i];
    b.y = islandH(b.xz);
    vec3 top = b + vec3(0.22 * sin(float(i) * 2.1), 1.55, 0.16 * cos(float(i) * 1.7));
    float dTrunk = sdCapsule(p, b, top, 0.105);
    if (dTrunk < d) {
      d = smin(d, dTrunk, 0.10);
      mat = M_TRUNK;
    }
    for (int j = 0; j < 3; j++) {
      float a = float(j) * 2.09 + float(i);
      vec3 c = top + vec3(cos(a) * 0.30, 0.10 + 0.05 * float(j), sin(a) * 0.30);
      float dLeaf = sdSphere(p - c, 0.46 - 0.06 * float(j));
      if (dLeaf < d) {
        d = smin(d, dLeaf, 0.16);
        mat = M_LEAF;
      }
    }
  }

  // 礁石
  for (int i = 0; i < 5; i++) {
    float a = 1.1 + float(i) * 1.27;
    vec2 xz2 = vec2(cos(a), sin(a)) * (R_ISLAND - 0.35 + 0.3 * sin(float(i) * 3.1));
    vec3 c = vec3(xz2.x, islandBase(xz2) * 0.35 + 0.10, xz2.y);
    float dRock = (length((p - c) / vec3(0.58, 0.42, 0.52)) - 1.0) * 0.5;
    if (dRock < d) {
      d = smin(d, dRock, 0.14);
      mat = M_ROCK;
    }
  }

  // 山顶灯塔 + 小城堡
  vec3 topC = vec3(0.0, islandBase(vec2(0.0)) + 0.10, 0.0);
  float dTower = sdRoundCyl(p - (topC + vec3(0.0, 0.62, 0.0)), 0.30, 0.60, 0.04);
  if (dTower < d) { d = smin(d, dTower, 0.08); mat = M_WALL; }
  float dLamp = sdRoundCyl(p - (topC + vec3(0.0, 1.34, 0.0)), 0.24, 0.16, 0.03);
  if (dLamp < d) { d = smin(d, dLamp, 0.05); mat = M_WALL; }
  float dRoof = sdRoundCyl(p - (topC + vec3(0.0, 1.62, 0.0)), 0.30, 0.16, 0.02);
  if (dRoof < d) { d = smin(d, dRoof, 0.05); mat = M_ROOF; }
  for (int i = 0; i < 3; i++) {
    float a = float(i) * 2.09 + 0.4;
    vec3 c = topC + vec3(cos(a) * 0.62, 0.30, sin(a) * 0.62);
    float dB = sdRoundBox(p - c, vec3(0.17, 0.34, 0.17), 0.05);
    if (dB < d) { d = smin(d, dB, 0.06); mat = M_WALL; }
    float dT = sdRoundCyl(p - (c + vec3(0.0, 0.38, 0.0)), 0.15, 0.10, 0.02);
    if (dT < d) { d = smin(d, dT, 0.04); mat = M_ROOF; }
  }

  return d;
}

float mapD(vec3 p) {
  float m;
  return mapScene(p, m);
}

// ───────────────────────── 着色 ─────────────────────────

vec3 discColor(vec3 p) {
  float a = atan(p.z, p.x);
  float k = fract(a / 6.28318 * 3.0);
  if (k < 0.25) return vec3(1.0, 0.72, 0.76);
  if (k < 0.50) return vec3(1.0, 0.86, 0.52);
  if (k < 0.75) return vec3(0.62, 0.85, 0.96);
  return vec3(0.70, 0.92, 0.66);
}

vec3 materialColor(float mat, vec3 p) {
  if (mat < M_GRASS + 0.5) {
    float n = fbm(p.xz * 1.7);
    return mix(vec3(0.42, 0.72, 0.30), vec3(0.56, 0.84, 0.38), n);
  } else if (mat < M_SAND + 0.5) {
    float n = fbm(p.xz * 2.6);
    return mix(vec3(0.94, 0.85, 0.66), vec3(1.0, 0.93, 0.78), n);
  } else if (mat < M_STONE + 0.5) {
    float n = fbm(p.xz * 3.1);
    return mix(vec3(0.74, 0.74, 0.72), vec3(0.88, 0.88, 0.86), n);
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
  float t = 0.08;
  for (int i = 0; i < 20; i++) {
    float h = mapD(ro + rd * t);
    res = min(res, 8.0 * h / t);
    t += clamp(h, 0.06, 0.55);
    if (res < 0.02 || t > 22.0) break;
  }
  return sat(res);
}

float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float sca = 1.0;
  for (int i = 0; i < 5; i++) {
    float h = 0.02 + 0.13 * float(i);
    float d = mapD(p + n * h);
    occ += (h - d) * sca;
    sca *= 0.82;
  }
  return sat(1.0 - 1.9 * occ);
}

vec3 shadeWater(vec3 p, vec3 rd, vec3 sunDir) {
  float t = uTime;
  vec2 q = p.xz * 1.5;
  float w1 = sin(q.x * 1.7 + t * 1.1) * 0.5 + sin(q.y * 2.1 - t * 0.9) * 0.5;
  float w2 = sin((q.x + q.y) * 3.1 + t * 1.7) * 0.35;
  vec3 n = normalize(vec3(w1 * 0.10, 1.0, w2 * 0.10));

  vec3 deep = vec3(0.10, 0.62, 0.68);
  vec3 shallow = vec3(0.32, 0.86, 0.82);
  float r = length(p.xz);
  float shallowK = 1.0 - smoothstep(R_ISLAND - 1.6, R_ISLAND + 1.2, r);
  vec3 base = mix(deep, shallow, shallowK);

  float ndl = sat(dot(n, sunDir));
  float sha = softShadow(p + vec3(0.0, 0.05, 0.0), sunDir);
  vec3 col = base * (0.55 + 0.55 * ndl * sha);

  float fres = pow(1.0 - sat(dot(-rd, n)), 3.0);
  vec3 skyc = vec3(0.75, 0.92, 0.99);
  col = mix(col, skyc, 0.35 + 0.45 * fres);

  float foam = smoothstep(0.30, 0.02, abs(r - (R_ISLAND - 0.55 + 0.22 * sin(t * 1.3 + r * 3.0))));
  col = mix(col, vec3(1.0), foam * 0.75);

  vec3 h = normalize(sunDir - rd);
  col += vec3(1.0, 0.97, 0.88) * pow(sat(dot(n, h)), 90.0) * 1.4 * sha;
  return col;
}

vec3 shadeSurface(vec3 p, vec3 n, vec3 rd, float mat, vec3 sunDir) {
  vec3 base = materialColor(mat, p);

  float sha = softShadow(p + n * 0.03, sunDir);
  float ao = calcAO(p, n);

  float ndl = sat(dot(n, sunDir));
  float up = sat(n.y * 0.5 + 0.5);
  vec3 skyLight = mix(vec3(0.55, 0.45, 0.38), vec3(0.70, 0.82, 0.95), up);

  vec3 col = base * (0.34 * ao);
  col += base * skyLight * 0.42 * ao;
  col += base * vec3(1.0, 0.96, 0.88) * ndl * sha * 0.95;

  vec3 h = normalize(sunDir - rd);
  col += vec3(1.0, 0.98, 0.92) * pow(sat(dot(n, h)), 26.0) * 0.10 * sha;

  float rim = pow(1.0 - sat(dot(n, -rd)), 3.0);
  col += base * rim * 0.22;
  return col;
}

vec3 skyColor(vec3 rd, vec3 sunDir) {
  vec3 top = vec3(0.42, 0.76, 0.95);
  vec3 bot = vec3(0.86, 0.96, 1.0);
  vec3 col = mix(bot, top, sat(rd.y * 1.6));
  col = mix(col, vec3(1.0, 0.97, 0.90), sat(0.30 - abs(rd.y)) * 0.55);

  float s = sat(dot(rd, sunDir));
  col += vec3(1.0, 0.94, 0.76) * pow(s, 700.0) * 2.2;
  col += vec3(1.0, 0.92, 0.72) * pow(s, 26.0) * 0.18;

  if (rd.y > 0.02) {
    vec2 cp = rd.xz / max(rd.y, 0.08) * 0.55;
    float c = fbm(cp * 1.3 + vec2(uTime * 0.008, 0.0));
    float cl = smoothstep(0.56, 0.80, c) * smoothstep(0.02, 0.25, rd.y);
    col = mix(col, vec3(1.0), cl * 0.85);
  }
  return col;
}

// ───────────────────────── 主函数 ─────────────────────────

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = (frag - 0.5 * uSize) / uSize.y;

  vec3 ro = uCam;
  vec3 fw = normalize(uTarget - uCam);
  vec3 rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0)));
  vec3 up = cross(rt, fw);
  vec3 rd = normalize(fw + rt * uv.x * uFovTan * 2.0 + up * uv.y * uFovTan * 2.0);

  vec3 sunDir = normalize(uSun.xyz);

  float t = 0.06;
  float mat = 0.0;
  bool hit = false;
  for (int i = 0; i < 96; i++) {
    vec3 p = ro + rd * t;
    if (p.y < -1.5) break;
    float m;
    float d = mapScene(p, m);
    if (d < 0.0025 * t + 0.0015) {
      hit = true;
      mat = m;
      break;
    }
    t += d * 0.72;
    if (t > 70.0) break;
  }

  float tw = 1e9;
  if (rd.y < -0.0001) tw = (0.0 - ro.y) / rd.y;

  bool waterHit = (!hit) && (tw > 0.0) && (tw < 1e8);
  vec3 col;
  if (hit) {
    vec3 p = ro + rd * t;
    vec3 n = calcNormal(p, max(0.0016 * t, 0.004));
    col = shadeSurface(p, n, rd, mat, sunDir);
    float mist = sat(1.0 - p.y * 0.55);
    col = mix(col, vec3(0.72, 0.93, 0.95), mist * 0.10);
  } else if (waterHit) {
    vec3 p = ro + rd * tw;
    col = shadeWater(p, rd, sunDir);
  } else {
    col = skyColor(rd, sunDir);
  }

  float dist = hit ? t : (waterHit ? tw : 1000.0);
  float fogK = sat((dist - 16.0) / 46.0);
  col = mix(col, skyColor(rd, sunDir), fogK * 0.55);

  col *= mix(0.92, 1.06, uSun.w);

  float lum = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(vec3(lum), col, 1.16);
  col = col / (col + vec3(0.86)) * 1.32;
  col = pow(sat3(col), vec3(0.95));

  float vig = 1.0 - 0.18 * dot(uv, uv);
  col *= vig;

  fragColor = vec4(sat3(col), 1.0);
}