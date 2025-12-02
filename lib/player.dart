import 'dart:math' as math;
import 'dart:ui';
import 'package:basic_beach/draw_court.dart';
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

    // Helper lambdas for polygon tests (convex quad/rhombus)
    bool _pointInPoly(Offset p, List<Offset> verts) {
      // Convex polygon, check all edges sign
      bool? sign;
      for (int i = 0; i < verts.length; i++) {
        final a = verts[i];
        final b = verts[(i + 1) % verts.length];
        final cross =
            (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
        final s = cross >= 0;
        sign ??= s;
        if (sign != s) return false;
      }
      return true;
    }

    Offset _closestPointOnSegment(Offset p, Offset a, Offset b) {
      final abx = b.dx - a.dx;
      final aby = b.dy - a.dy;
      final apx = p.dx - a.dx;
      final apy = p.dy - a.dy;
      final abLen2 = abx * abx + aby * aby;
      if (abLen2 == 0) return a;
      double t = (apx * abx + apy * aby) / abLen2;
      t = t.clamp(0.0, 1.0);
      return Offset(a.dx + t * abx, a.dy + t * aby);
    }

    Offset _projectToPoly(Offset p, List<Offset> verts) {
      // If inside, return as is; else project to nearest edge
      if (_pointInPoly(p, verts)) return p;
      Offset best = verts.first;
      double bestDist2 = double.infinity;
      for (int i = 0; i < verts.length; i++) {
        final a = verts[i];
        final b = verts[(i + 1) % verts.length];
        final q = _closestPointOnSegment(p, a, b);
        final dx = q.dx - p.dx;
        final dy = q.dy - p.dy;
        final d2 = dx * dx + dy * dy;
        if (d2 < bestDist2) {
          bestDist2 = d2;
          best = q;
        }
      }
      return best;
    }

    // Initiera slumpmässig riktning ibland
    if (_walkDirection.length2 == 0) {
      final angle = math.Random().nextDouble() * 2 * math.pi;
      _walkDirection = Vector2(math.cos(angle), math.sin(angle));
    }

    // Beräkna skalan på samma sätt som i renderCircle, baserat på
    // kroppens globala y mellan backLine och frontLine.
    final back = layout.backLineY;
    final front = layout.frontLineY;
    final yWorld = body.position.y;
    final t = ((yWorld - back) / (front - back)).clamp(0.0, 1.0);
    final scale = lerpDouble(0.5, 4, t)!;

    // Uppskatta fotposition i världens koordinater. Kroppen ritas från
    // huvud (center) nedåt ~5 * scaledRadius.
    final scaledRadius = _radius * scale;
    final double footOffsetWorld = 13.0 * scaledRadius;
    final headPos = body.position;
    final footPos = headPos + Vector2(0, footOffsetWorld);

    // Project foot into polygon if outside, and reflect direction on escape
    var clampedFoot = footPos;
    final footOffset = Offset(clampedFoot.x, clampedFoot.y);
    final wasInside = _pointInPoly(footOffset, poly);
    if (!wasInside) {
      final projected = _projectToPoly(footOffset, poly);
      // Simple reflection: invert component that crossed farthest
      final dx = footOffset.dx - projected.dx;
      final dy = footOffset.dy - projected.dy;
      if (dx.abs() > dy.abs()) {
        _walkDirection.x = -_walkDirection.x;
      } else {
        _walkDirection.y = -_walkDirection.y;
      }
      clampedFoot = Vector2(projected.dx, projected.dy);
    }

    // Flytta tillbaka huvudets center från den klampade fotpositionen
    final newHeadPos = clampedFoot - Vector2(0, footOffsetWorld);
    body.setTransform(newHeadPos, body.angle);

    // Ibland randomisera riktning lite för mer “levande” rörelse
    if (math.Random().nextDouble() < 0.02) {
      final jitterAngle = (math.Random().nextDouble() - 0.5) * 0.5;
      final currentAngle = math.atan2(_walkDirection.y, _walkDirection.x);
      final newAngle = currentAngle + jitterAngle;
      _walkDirection.setValues(math.cos(newAngle), math.sin(newAngle));
    }

    if (_walkDirection.length2 > 0) {
      body.linearVelocity = _walkDirection.normalized() * _walkSpeed;
    } else {
      body.linearVelocity = Vector2.zero();
    }
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    // Skala spelaren efter y-position i världens koordinater.
    // // CourtLayout räknar automatiskt ut djupfaktorer utifrån
    // // bak-/framlinje och nät.
    final worldRect = game.camera.visibleWorldRect;
    final layout = computeCourtLayout(worldRect);

    final back = layout.backLineY;
    final front = layout.frontLineY;

    // Projektera spelarens y på segmentet [back, front]
    final yWorld = body.position.y;
    final t = ((yWorld - back) / (front - back)).clamp(
      0.0,
      1.0,
    ); // 0 vid back, 1 vid front

    final scale = lerpDouble(1, 4, t)!; // exempel
    final scaledRadius = radius * scale;

    final headPaint = Paint()..color = const Color(0xFF0000FF);
    final bodyPaint = Paint()
      ..color = const Color.fromARGB(255, 48, 111, 136)
      ..strokeWidth = scaledRadius * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Head
    canvas.drawCircle(center, scaledRadius, headPaint);

    // Torso
    final torsoTop = Offset(center.dx, center.dy + scaledRadius);
    final torsoBottom = Offset(center.dx, center.dy + scaledRadius * 4);
    canvas.drawLine(torsoTop, torsoBottom, bodyPaint);

    // Arms (two segments each)
    final shoulderY = center.dy + scaledRadius * 1.5;
    final armLength = scaledRadius * 1.8;

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
    final legLength = scaledRadius * 2.0;

    final stepRadius = scaledRadius * 0.8;
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
