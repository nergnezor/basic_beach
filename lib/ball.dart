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
    final gradient = RadialGradient(
      colors: const [Color(0xFFFFF5C3), Color(0xFFD17833)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    final paint = Paint()..shader = gradient;
    canvas.drawCircle(center, radius, paint);

    final seamPaint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, seamPaint);
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
