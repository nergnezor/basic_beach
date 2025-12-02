import 'dart:math' as math;
import 'dart:ui';
import 'package:basic_beach/draw_court.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class Player extends BodyComponent {
  Player(
    this.spawnPosition, {
    required this.playerId,
    this.autoWalk = false,
    required this.isLeftSide,
    required this.isTopRow,
  }) {
    priority = isTopRow ? 5 : 15; // top drawn before bottom
  }

  final Vector2 spawnPosition;
  final int playerId;
  final bool autoWalk;
  final bool isLeftSide;
  final bool isTopRow;

  static const double _radius = 1.0;

  Vector2 _walkDirection = Vector2(1, 0);
  final _walkSpeed = 25.0; // units per second
  double _time = 0.0; // for foot-circle animation of legs

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

    if (!autoWalk) {
      body.linearVelocity = Vector2.zero();
      return;
    }

    // Hämta court-rektangel i världens koordinater
    final rect = game.camera.visibleWorldRect;

    final layout = computeCourtLayout(rect);
    final poly = isTopRow ? layout.topPolygon : layout.bottomPolygon;

    // Compute AABB of polygon
    double minX = poly.first.dx, maxX = poly.first.dx;
    double minY = poly.first.dy, maxY = poly.first.dy;
    for (final o in poly) {
      if (o.dx < minX) minX = o.dx;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy < minY) minY = o.dy;
      if (o.dy > maxY) maxY = o.dy;
    }

    // Use this AABB instead of earlier side/row limits
    final sideLeftLimit = minX;
    final sideRightLimit = maxX;
    final rowTopLimit = minY;
    final rowBottomLimit = maxY;

    // Initiera slumpmässig riktning ibland
    if (_walkDirection.length2 == 0) {
      final angle = math.Random().nextDouble() * 2 * math.pi;
      _walkDirection = Vector2(math.cos(angle), math.sin(angle));
    }

    // Beräkna en uppskattad fotposition i världens koordinater.
    // Kroppen ritas från huvud (center) nedåt ~5 * radius, så använd det
    // som vertikal offset mellan head-center och fot.
    const double footOffsetWorld = 5.0 * _radius;
    final headPos = body.position;
    final footPos = headPos + Vector2(0, footOffsetWorld);

    var clampedFoot = footPos;

    // Kontrollera kollision på fotnivå och vänd/reflektera riktning
    if (clampedFoot.x <= sideLeftLimit && _walkDirection.x < 0) {
      _walkDirection.x = -_walkDirection.x;
      clampedFoot.x = sideLeftLimit;
    } else if (clampedFoot.x >= sideRightLimit && _walkDirection.x > 0) {
      _walkDirection.x = -_walkDirection.x;
      clampedFoot.x = sideRightLimit;
    }

    if (clampedFoot.y <= rowTopLimit && _walkDirection.y < 0) {
      _walkDirection.y = -_walkDirection.y;
      clampedFoot.y = rowTopLimit;
    } else if (clampedFoot.y >= rowBottomLimit && _walkDirection.y > 0) {
      _walkDirection.y = -_walkDirection.y;
      clampedFoot.y = rowBottomLimit;
    }

    // Flytta tillbaka huvudets center från den klampade fotpositionen
    final newHeadPos = clampedFoot - Vector2(0, footOffsetWorld);
    body.setTransform(newHeadPos, body.angle);

    // Ibland randomisera riktning lite för mer “levande” rörelse
    if (isTopRow) {
      if (math.Random().nextDouble() < 0.02) {
        final jitterAngle = (math.Random().nextDouble() - 0.5) * 0.5;
        final currentAngle = math.atan2(_walkDirection.y, _walkDirection.x);
        final newAngle = currentAngle + jitterAngle;
        _walkDirection.setValues(math.cos(newAngle), math.sin(newAngle));
      }
    } else {
      // Nedre rad kan stå still eller gå bara lite
      _walkDirection.setValues(0, 0);
    }

    if (_walkDirection.length2 > 0) {
      body.linearVelocity = _walkDirection.normalized() * _walkSpeed;
    } else {
      body.linearVelocity = Vector2.zero();
    }
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    final headPaint = Paint()..color = const Color(0xFF0000FF);
    final bodyPaint = Paint()
      ..color = const Color.fromARGB(255, 48, 111, 136)
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

  void setWalkDirection(Vector2 dir) {
    _walkDirection = dir;
  }
}
