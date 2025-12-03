import 'dart:math' as math;
import 'dart:ui';

import 'package:basic_beach/draw_court.dart';

/// A 3D vector with basic math operations for perspective projection.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  Vec3 cross(Vec3 other) => Vec3(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  double get length => math.sqrt(dot(this));

  Vec3 normalized() {
    final len = length;
    if (len == 0) {
      return this;
    }
    return Vec3(x / len, y / len, z / len);
  }
}

/// Maps 2D world positions on the court to pseudo 3D values (depth and scale)
/// so movement and rendering can share the same perspective math.
class CourtPerspectiveConverter {
  CourtPerspectiveConverter(
    this.layout, {
    this.backScale = 1.0,
    this.frontScale = 4.0,
    this.backDepth = 0.0,
    this.frontDepth = 1.0,
  });

  final CourtLayout layout;
  final double backScale;
  final double frontScale;
  final double backDepth;
  final double frontDepth;

  /// Depth factor relative to the camera (0 = back line, 1 = front line).
  double cameraDepth(double y) {
    final span = layout.frontLineY - layout.backLineY;
    if (span.abs() < 1e-3) {
      return 0.0;
    }
    final t = (y - layout.backLineY) / span;
    return t.clamp(0.0, 1.0);
  }

  /// Depth value mapped to [backDepth, frontDepth].
  double depth(double y) => lerpDouble(backDepth, frontDepth, cameraDepth(y))!;

  /// Scale factor for rendering/movement, defaults to [backScale→frontScale].
  double scaleAtY(double y, {double? minScale, double? maxScale}) {
    final start = minScale ?? backScale;
    final end = maxScale ?? frontScale;
    return lerpDouble(start, end, cameraDepth(y))!;
  }

  /// Converts a 2D offset to a Vec3 using the computed depth for its y value.
  Vec3 toVec3(Offset point) => Vec3(point.dx, point.dy, depth(point.dy));
}
