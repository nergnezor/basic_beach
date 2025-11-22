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

  float r = 0.0;
  float g = 0.0;
  float b = 0.0;
  float a = 0.1;

  float offset = w / 2 * sin(iTime * PI);

  if (x > offset && y < -h * 0.4)
  {
    r = 1.0;
    g = 0.7;
  }

  fragColor = vec4(r, g, b, a);
}

void main() { mainImage(fragColor, FlutterFragCoord().xy); }
