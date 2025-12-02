import 'package:basic_beach/draw_court.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/painting.dart';

class BouncingBall extends BodyComponent {
  BouncingBall(this.spawnPosition);

  final Vector2 spawnPosition;

  static const double _radius = 0.6;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = _radius;
    final fixtureDef = FixtureDef(shape)
      ..density = 0.9
      ..friction = 0.3
      ..restitution = 0.85;
    final bodyDef = BodyDef()
      ..type = BodyType.dynamic
      ..position = spawnPosition;
    final body = world.createBody(bodyDef)..createFixture(fixtureDef);
    body.linearDamping = 0.05;
    body.angularDamping = 0.1;
    return body;
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    // Skala bollen efter y-position med CourtLayouts djupfaktorer,
    // så att skalan härleds automatiskt från court-geometrin.
    final worldRect = game.camera.visibleWorldRect;
    final layout = computeCourtLayout(worldRect);

    final y = center.dy;
    final middleY = layout.centerLineY;

    double depth;
    if (y <= middleY) {
      final denom = (middleY - layout.backLineY).abs();
      final localT = denom > 0 ? (middleY - y).abs() / denom : 0.0;
      depth = layout.depthFactorTop * localT;
    } else {
      final denom = (layout.frontLineY - middleY).abs();
      final localT = denom > 0 ? (y - middleY).abs() / denom : 0.0;
      depth = layout.depthFactorBottom * localT;
    }

    const double baseScale = 1.0;
    const double depthScaleSpan = 0.4;
    final scale = baseScale - depthScaleSpan * depth;

    final scaledRadius = radius * scale;

    final gradient = RadialGradient(
      colors: const [Color(0xFFFFF5C3), Color(0xFFD17833)],
    ).createShader(Rect.fromCircle(center: center, radius: scaledRadius));
    final paint = Paint()..shader = gradient;
    canvas.drawCircle(center, scaledRadius, paint);

    final seamPaint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, scaledRadius, seamPaint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Limit maximum velocity to avoid tunneling through the floor
    final velocity = body.linearVelocity;
    final maxVelocity = 20.0;
    if (velocity.length > maxVelocity) {
      body.linearVelocity = velocity.normalized() * maxVelocity;
    }
  }
}
