#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_bass;       // 20Hz - 250Hz energy (0.0 to 1.0)
uniform float u_mid;        // 250Hz - 2000Hz energy (0.0 to 1.0)
uniform float u_treble;     // 2000Hz - 16000Hz energy (0.0 to 1.0)
uniform vec3 u_primary_color;
uniform vec3 u_secondary_color;
uniform vec3 u_accent_color;

out vec4 fragColor;

// Simplex 3D Noise algorithms for procedural GPU deformation
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 permute(vec4 x) { return mod289(((x * 34.0) + 1.0) * x); }
vec4 taylorInvSqrt(vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float snoise(vec3 v) {
  const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
  const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i  = floor(v + dot(v, C.yyy));
  vec3 x0 = v - i + dot(i, C.xxx);
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min(g.xyz, l.zxy);
  vec3 i2 = max(g.xyz, l.zxy);
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy;
  vec3 x3 = x0 - D.yyy;
  i = mod289(i);
  vec4 p = permute(permute(permute(
             i.z + vec4(0.0, i1.z, i2.z, 1.0))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0))
           + i.x + vec4(0.0, i1.x, i2.x, 1.0));
  float n_ = 0.142857142857;
  vec3  ns = n_ * D.wyz - D.xzx;
  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_);
  vec4 x = x_ * ns.x + ns.yyyy;
  vec4 y = y_ * ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy);
  vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0) * 2.0 + 1.0;
  vec4 s1 = floor(b1) * 2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
  vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x);
  vec3 p1 = vec3(a0.zw, h.y);
  vec3 p2 = vec3(a1.xy, h.z);
  vec3 p3 = vec3(a1.zw, h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
  m = m * m;
  return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

// Signed Distance Field of deformed 3D liquid sphere
float map(vec3 p) {
  // Bass drives the fundamental base radius and pulse expansion
  float baseRadius = 0.95 + (u_bass * 0.38);
  
  // Mid frequencies drive surface harmonic ripple waves
  float midWave = snoise(p * 2.2 + vec3(0.0, u_time * 0.9, 0.0)) * (0.12 + u_mid * 0.28);
  
  // Treble drives high-frequency fine surface shimmer
  float trebleShimmer = snoise(p * 5.5 + vec3(u_time * 1.5, 0.0, 0.0)) * (0.04 + u_treble * 0.12);
  
  return length(p) - baseRadius + midWave + trebleShimmer;
}

vec3 calcNormal(vec3 p) {
  const vec2 h = vec2(0.001, 0.0);
  return normalize(vec3(
    map(p + h.xyy) - map(p - h.xyy),
    map(p + h.yxy) - map(p - h.yxy),
    map(p + h.yyx) - map(p - h.yyx)
  ));
}

void main() {
  vec2 uv = (gl_FragCoord.xy - 0.5 * u_resolution) / min(u_resolution.x, u_resolution.y);
  
  // Slowly rotate the camera around the orb for cinematic fluid motion
  float camAngle = u_time * 0.15;
  vec3 ro = vec3(3.4 * sin(camAngle), 0.6 * cos(camAngle * 0.7), 3.4 * cos(camAngle));
  vec3 target = vec3(0.0, 0.0, 0.0);
  vec3 ww = normalize(target - ro);
  vec3 uu = normalize(cross(ww, vec3(0.0, 1.0, 0.0)));
  vec3 vv = normalize(cross(uu, ww));
  vec3 rd = normalize(uv.x * uu + uv.y * vv + 1.6 * ww);
  
  float t = 0.0;
  float tMax = 7.0;
  bool hit = false;
  vec3 p;
  
  for (int i = 0; i < 52; i++) {
    p = ro + rd * t;
    float d = map(p);
    if (d < 0.001) {
      hit = true;
      break;
    }
    t += d;
    if (t > tMax) break;
  }
  
  vec3 finalColor = vec3(0.0);
  
  if (hit) {
    vec3 n = calcNormal(p);
    vec3 lightDir1 = normalize(vec3(1.0, 2.0, 1.5));
    vec3 lightDir2 = normalize(vec3(-1.5, -1.0, -1.0));
    
    float diff1 = max(dot(n, lightDir1), 0.0);
    float diff2 = max(dot(n, lightDir2), 0.0);
    float fresnel = pow(1.0 - max(dot(-rd, n), 0.0), 3.2);
    
    // Dynamic iridescent gradient mixing
    float colorMixFactor = 0.5 + 0.5 * sin(p.y * 3.5 + u_time * 1.2);
    vec3 surfaceColor = mix(u_primary_color, u_secondary_color, colorMixFactor);
    
    finalColor = surfaceColor * (diff1 * 0.7 + diff2 * 0.3 + 0.15);
    finalColor += u_accent_color * fresnel * (1.2 + u_bass * 1.8);
    finalColor += vec3(1.0) * pow(max(dot(reflect(rd, n), lightDir1), 0.0), 32.0) * (0.8 + u_treble * 1.2);
  } else {
    // Atmospheric volumetric radial glow aura behind the orb
    float dist = length(uv);
    float halo = exp(-dist * 2.4) * (0.4 + u_bass * 0.65);
    vec3 bgGlow = mix(u_primary_color, u_secondary_color, uv.y + 0.5);
    finalColor = bgGlow * halo;
    
    // Treble sparkles/ambient dust motes
    float sparkle = pow(snoise(vec3(uv * 12.0, u_time * 0.8)) * 0.5 + 0.5, 6.0) * u_treble * 1.5;
    finalColor += u_accent_color * sparkle;
  }
  
  // Subtle cinematic vignette
  float vignette = smoothstep(1.4, 0.4, length(uv));
  finalColor *= vignette;
  
  fragColor = vec4(finalColor, 1.0);
}
