import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class Player extends BodyComponent {
  Player(this.spawnPosition, {required this.playerId});

  final Vector2 spawnPosition;
  final int playerId;

  static const double _radius = 1.0;

  @override
  Body createBody() {
    final shape = CircleShape()..radius = _radius;
    final fixtureDef = FixtureDef(shape)
      ..density = 1.0
      ..friction = 0.5
      ..restitution = 0.2;
    final bodyDef = BodyDef()
      ..type = BodyType.kinematic
      ..position = spawnPosition;
    final body = world.createBody(bodyDef)..createFixture(fixtureDef);
    body.linearDamping = 0.2;
    body.angularDamping = 0.3;
    return body;
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = const Color(0xFF0000FF);
    canvas.drawCircle(center, radius, paint);

    // Upper body
    final width = radius * 4;
    final height = radius * 4;
    center = Offset(center.dx, center.dy + height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: width, height: height),
        const Radius.circular(1),
      ),
      Paint()..color = const Color(0x7FFFFFFF),
    );
  }
}
