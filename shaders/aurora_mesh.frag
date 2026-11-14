#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_time;
uniform float u_energy;     // Overall track energy / RMS level (0.0 to 1.0)
uniform float u_bass;       // Sub-bass / bass pulse (0.0 to 1.0)
uniform vec3 u_color_1;     // Primary warm amber from album art
uniform vec3 u_color_2;     // Secondary honey tone from album art
uniform vec3 u_color_3;     // Highlight accent
uniform vec3 u_color_bg;    // Studio charcoal background base

out vec4 fragColor;

// 2D Simplex noise
vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }

float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187,
                      0.366025403784439,
                     -0.577350269189626,
                      0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy));
  vec2 x0 = v -   i + dot(i, C.xx);
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod289(i);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m;
  m = m*m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

void main() {
  vec2 uv = gl_FragCoord.xy / u_resolution.xy;
  
  // Fluid speed directly proportional to audio energy: calm during silence
  float speed = 0.02 + (u_energy * 0.45);
  float t = u_time * speed;
  
  // First warp octave
  vec2 q = vec2(
    snoise(uv * 1.8 + vec2(t * 0.5, t * 0.3)),
    snoise(uv * 1.8 + vec2(-t * 0.4, t * 0.6))
  );
  
  // Second warp octave with audio energy injection
  vec2 r = vec2(
    snoise(uv * 2.4 + 3.5 * q + vec2(1.7, 9.2) + 0.15 * t),
    snoise(uv * 2.4 + 3.5 * q + vec2(8.3, 2.8) + 0.12 * t)
  );
  
  // Organic mesh density field
  float f = snoise(uv * 1.5 + 3.5 * r);
  f = 0.5 + 0.5 * f;
  
  // Bass pulses expand the illuminated mesh nodes
  f += u_bass * 0.32;
  
  // Multi-stop cinematic gradient interpolation
  vec3 color = u_color_bg;
  
  // Blend primary warm amber blobs
  color = mix(color, u_color_1, smoothstep(0.12, 0.7, f * (0.4 + u_energy * 0.6)));
  
  // Blend secondary honey waves
  float f2 = 0.5 + 0.5 * snoise(uv * 2.0 - r * 2.0 + t * 0.4);
  color = mix(color, u_color_2, smoothstep(0.35, 0.85, f2 * (0.3 + u_energy * 0.7)));
  
  // Accent highlights at turbulent peaks
  if (u_energy > 0.05) {
    float highlight = pow(smoothstep(0.65, 0.95, f), 2.5);
    color = mix(color, u_color_3, highlight * (u_energy * 0.85));
  }
  
  // Deep ambient vignetting to maintain UI contrast
  vec2 centeredUV = (gl_FragCoord.xy - 0.5 * u_resolution) / min(u_resolution.x, u_resolution.y);
  float vignette = smoothstep(1.5, 0.3, length(centeredUV));
  color *= (0.35 + 0.65 * vignette);
  
  fragColor = vec4(color, 1.0);
}
