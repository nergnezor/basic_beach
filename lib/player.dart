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
    final headPaint = Paint()..color = const Color(0xFF0000FF);
    final bodyPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = radius * 0.5
      ..style = PaintingStyle.stroke;

    // Head
    canvas.drawCircle(center, radius, headPaint);

    // Torso
    final torsoTop = Offset(center.dx, center.dy + radius);
    final torsoBottom = Offset(center.dx, center.dy + radius * 4);
    canvas.drawLine(torsoTop, torsoBottom, bodyPaint);

    // Arms (two segments each)
    final shoulderY = center.dy + radius * 1.5;
    final armLength = radius * 1.8;

    // Left arm
    final leftShoulder = Offset(center.dx, shoulderY);
    final leftElbow = leftShoulder + Offset(-armLength * 0.8, armLength * 0.4);
    final leftHand = leftElbow + Offset(-armLength * 0.6, armLength * 0.6);
    canvas.drawLine(leftShoulder, leftElbow, bodyPaint);
    canvas.drawLine(leftElbow, leftHand, bodyPaint);

    // Right arm
    final rightShoulder = Offset(center.dx, shoulderY);
    final rightElbow = rightShoulder + Offset(armLength * 0.8, armLength * 0.4);
    final rightHand = rightElbow + Offset(armLength * 0.6, armLength * 0.6);
    canvas.drawLine(rightShoulder, rightElbow, bodyPaint);
    canvas.drawLine(rightElbow, rightHand, bodyPaint);

    // Legs (two segments each)
    final hipY = torsoBottom.dy;
    final legLength = radius * 2.0;

    // Left leg
    final leftHip = Offset(center.dx, hipY);
    final leftKnee = leftHip + Offset(-legLength * 0.4, legLength * 0.8);
    final leftFoot = leftKnee + Offset(-legLength * 0.4, legLength * 0.7);
    canvas.drawLine(leftHip, leftKnee, bodyPaint);
    canvas.drawLine(leftKnee, leftFoot, bodyPaint);

    // Right leg
    final rightHip = Offset(center.dx, hipY);
    final rightKnee = rightHip + Offset(legLength * 0.4, legLength * 0.8);
    final rightFoot = rightKnee + Offset(legLength * 0.4, legLength * 0.7);
    canvas.drawLine(rightHip, rightKnee, bodyPaint);
    canvas.drawLine(rightKnee, rightFoot, bodyPaint);
  }
}
