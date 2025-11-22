import 'dart:math';
import 'dart:ui';

import 'package:flame_forge2d/flame_forge2d.dart';

class Worm extends BodyComponent with ContactCallbacks {
  static const double wormRadius = 100.5;
  static const double wormDensity = 1.0;
  static const double wormFriction = 0.2;
  static const double wormRestitution = 0.2;

  // Worm(Vector2 position) {
  //   final shape = CircleShape()..radius = wormRadius;
  //   final fixtureDef = FixtureDef(shape)
  //     ..density = wormDensity
  //     ..friction = wormFriction
  //     ..restitution = wormRestitution;
  //   final bodyDef = BodyDef()
  //     ..position = position
  //     ..type = BodyType.dynamic;
  //   // body = world.createBody(bodyDef)..createFixtureFromFixtureDef(fixtureDef);
  //   // body = world.createBody(bodyDef)..createFixture(fixtureDef);
  //   body.bodyType = BodyType.dynamic;
  // }
  final Vector2 spawnPosition;

  Worm(this.spawnPosition) : super();
  //

  @override
  Body createBody() {
    final shape = CircleShape()..radius = wormRadius;
    final fixtureDef = FixtureDef(shape);
    // ..density = wormDensity
    // ..friction = wormFriction
    // ..restitution = wormRestitution;
    final bodyDef = BodyDef()
      ..position = spawnPosition
      ..type = BodyType.dynamic;
    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    super.renderCircle(canvas, center, radius);
    final paint = Paint()..color = const Color(0xFFFF0000);
    canvas.drawCircle(center, radius, paint);
    const bodyCount = 6;
    for (var i = 0; i < bodyCount; i++) {
      final angle = (i / bodyCount) * pi * 2;
      final x = center.dx + radius * 0.5 * cos(angle);
      final y = center.dy + radius * 0.3 * sin(angle);
      canvas.drawCircle(Offset(x, y), radius * 0.2, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    final velocity = body.linearVelocity;
    final speed = velocity.length;
    if (speed > 5) {
      body.linearVelocity = velocity.normalized() * 5;
    }
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is! Worm) {
      return;
    }
    final otherWorm = other;
    if (body == otherWorm.body) {
      return;
    }
    final position = body.position;
    final otherPosition = otherWorm.body.position;
    final direction = otherPosition - position;
    final force = direction.normalized() * 1000;
    body.applyForce(force);
  }
}
