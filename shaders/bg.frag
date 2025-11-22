// ignore-line
#include <flutter/runtime_effect.glsl>

uniform float iTime;
uniform vec2 iResolution;
out vec4 fragColor;

const float PI = 3.14159265359;

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
  float x = fragCoord.x;
  float y = fragCoord.y;
  float w = iResolution.x;
  float h = iResolution.y;

  vec2 uv = vec2(x / w, 1 - (y / h));

  float horizon = 0.85;
  vec3 color;

  if (uv.y < horizon)
  {
    // Ocean
    float t = uv.y / horizon;
    vec3 deep = vec3(0.0, 0.1, 0.3);
    vec3 shallow = vec3(0.0, 0.4, 0.7);

    float wave =
        sin(uv.x * 12.0 + iTime * 1.2) * 0.015 +
        sin(uv.x * 24.0 - iTime * 1.7) * 0.008;

    t = clamp(t + wave, 0.0, 1.0);
    color = mix(deep, shallow, t);
  }
  else
  {
    // Base sky gradient
    float t = (uv.y - horizon) / (1.0 - horizon);
    vec3 horizonCol = vec3(0.6, 0.8, 1.0);
    vec3 zenithCol = vec3(0.1, 0.3, 0.7);
    color = mix(horizonCol, zenithCol, t);

    // Simple procedural clouds (only in sky)
    float yy = (uv.y - horizon) / (1.0 - horizon);
    float wind = iTime * 0.05;

    float c1 = sin((uv.x + wind) * 6.0  + yy * 2.0);
    float c2 = sin((uv.x + wind * 0.6) * 3.0  + yy * 3.5);
    float c3 = sin((uv.x - wind * 0.4) * 1.5  + yy * 5.5);

    float clouds = (c1 * 0.6 + c2 * 0.5 + c3 * 0.4) * 0.4 + 0.45;

    // Fade clouds near top/bottom of sky band
    float band = smoothstep(0.05, 0.5, yy) * (1.0 - smoothstep(0.7, 1.0, yy));
    clouds = clamp(clouds * band, 0.0, 0.85);

    // Mix in soft white clouds
    vec3 cloudCol = vec3(1.0);
    color = mix(color, cloudCol, clouds);
  }

  fragColor = vec4(color, 1.0);
}

void main() { mainImage(fragColor, FlutterFragCoord().xy); }
