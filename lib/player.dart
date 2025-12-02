import 'dart:math' as math;
import 'dart:ui';
import 'package:flame_forge2d/flame_forge2d.dart';

class Player extends BodyComponent {
  Player(
    this.spawnPosition, {
    required this.playerId,
    this.autoWalk = false,
    this.walkLeftBoundary,
    this.walkRightBoundary,
  });

  final Vector2 spawnPosition;
  final int playerId;

  // If true, this player will automatically walk horizontally
  // between [walkLeftBoundary] and [walkRightBoundary].
  final bool autoWalk;
  final double? walkLeftBoundary;
  final double? walkRightBoundary;

  static const double _radius = 1.0;

  double _walkDirection = 1.0; // 1: right, -1: left
  final _walkSpeed = 4.0; // units per second
  double _time = 0.0; // for foot-circle animation

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
  void update(double dt) {
    super.update(dt);

    _time += dt;

    if (autoWalk) {
      final pos = body.position;

      if (walkLeftBoundary != null && pos.x <= walkLeftBoundary!) {
        _walkDirection = 1.0;
      } else if (walkRightBoundary != null && pos.x >= walkRightBoundary!) {
        _walkDirection = -1.0;
      }

      body.linearVelocity = Vector2(_walkDirection * _walkSpeed, 0);
    }
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    final headPaint = Paint()..color = const Color(0xFF0000FF);
    final bodyPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = radius * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

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

    // Legs (two segments each) with circular foot motion
    final hipY = torsoBottom.dy;
    final legLength = radius * 2.0;

    final stepRadius = radius * 0.8;
    final stepSpeed = 4.0; // radians per second
    final phase = autoWalk ? _time * stepSpeed : 0.0;

    // Left leg
    final leftHip = Offset(center.dx, hipY);
    final leftKnee = leftHip + Offset(-legLength * 0.4, legLength * 0.8);
    // Circle motion for foot: offset around a small circle
    final leftFootBase = leftKnee + Offset(-legLength * 0.4, legLength * 0.7);
    final leftFoot = Offset(
      leftFootBase.dx + stepRadius * math.cos(phase),
      leftFootBase.dy + stepRadius * math.sin(phase),
    );
    canvas.drawLine(leftHip, leftKnee, bodyPaint);
    canvas.drawLine(leftKnee, leftFoot, bodyPaint);

    // Right leg (phase shifted so they alternate)
    final rightHip = Offset(center.dx, hipY);
    final rightKnee = rightHip + Offset(legLength * 0.4, legLength * 0.8);
    final rightFootBase = rightKnee + Offset(legLength * 0.4, legLength * 0.7);
    final rightFoot = Offset(
      rightFootBase.dx + stepRadius * math.cos(phase + math.pi),
      rightFootBase.dy + stepRadius * math.sin(phase + math.pi),
    );
    canvas.drawLine(rightHip, rightKnee, bodyPaint);
    canvas.drawLine(rightKnee, rightFoot, bodyPaint);
  }
}
