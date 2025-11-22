import 'dart:math' as math;
import 'dart:ui';

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

/// Projects 3D points to 2D screen coordinates using perspective projection.
class PerspectiveProjector {
  /// Creates a perspective projector with camera position, target, and focal length.
  ///
  /// The [camera] is the eye position in world space.
  /// The [target] is where the camera is looking at.
  /// The [upHint] provides the "up" direction for the camera.
  /// The [focalLength] controls the zoom level (smaller = more zoomed out).
  PerspectiveProjector({
    required this.camera,
    required Vec3 target,
    required Vec3 upHint,
    this.focalLength = 1,
  }) {
    final view = (target - camera).normalized();
    final horizontal = view.cross(upHint).normalized();
    final vertical = horizontal.cross(view).normalized();
    forward = view;
    right = horizontal;
    up = vertical;
  }

  final Vec3 camera;
  final double focalLength;
  late final Vec3 forward;
  late final Vec3 right;
  late final Vec3 up;

  /// Projects a 3D world point to 2D screen coordinates.
  Offset project(Vec3 point) {
    final relative = point - camera;
    final x = relative.dot(right);
    final y = relative.dot(up);
    final z = math.max(relative.dot(forward), 0.001);
    final scale = focalLength / z;
    return Offset(x * scale, y * scale);
  }
}
