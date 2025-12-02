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

    final rect = game.camera.visibleWorldRect;
    final layout = computeCourtLayout(rect);
    final poly = isTopRow ? layout.topPolygon : layout.bottomPolygon;

    // Helper lambdas for polygon tests
    bool pointInPoly(Offset p, List<Offset> verts) {
      bool? sign;
      for (int i = 0; i < verts.length; i++) {
        final a = verts[i];
        final b = verts[(i + 1) % verts.length];
        final cross =
            (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
        if (cross == 0) continue;
        final s = cross > 0;
        sign ??= s;
        if (sign != s) return false;
      }
      return true;
    }

    Offset closestPointOnSegment(Offset p, Offset a, Offset b) {
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

    Offset projectToPoly(Offset p, List<Offset> verts) {
      if (pointInPoly(p, verts)) return p;
      Offset best = verts.first;
      double bestDist2 = double.infinity;
      for (int i = 0; i < verts.length; i++) {
        final a = verts[i];
        final b = verts[(i + 1) % verts.length];
        final q = closestPointOnSegment(p, a, b);
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

    // --- Main Update Logic ---

    // Set walk direction if needed
    if (_walkDirection.length2 == 0) {
      final angle = math.Random().nextDouble() * 2 * math.pi;
      _walkDirection = Vector2(math.cos(angle), math.sin(angle));
    }

    // Apply velocity
    if (_walkDirection.length2 > 0) {
      body.linearVelocity = _walkDirection.normalized() * _walkSpeed;
    } else {
      body.linearVelocity = Vector2.zero();
    }

    // --- Boundary Collision and Correction ---
    final headPos = body.position.clone();
    final back = layout.backLineY;
    final front = layout.frontLineY;
    final stepSpeed = 4.0;
    final phase = autoWalk ? _time * stepSpeed : 0.0;

    final footPos = _calculateFootPos(headPos, back, front, phase);
    final footOffset = Offset(footPos.x, footPos.y);

    if (!pointInPoly(footOffset, poly)) {
      final projectedFootOffset = projectToPoly(footOffset, poly);
      final targetFootPos = Vector2(
        projectedFootOffset.dx,
        projectedFootOffset.dy,
      );

      // --- Iterative Solver ---
      // We iteratively adjust the head position to move the foot to the target position.
      // This is more robust than a single complex calculation.
      var correctedHeadPos = headPos.clone();
      const iterations = 5;

      for (int i = 0; i < iterations; i++) {
        // Calculate the foot position based on our current guess for the head.
        final currentFootPos = _calculateFootPos(
          correctedHeadPos,
          back,
          front,
          phase,
        );
        // Find the error between where the foot is and where we want it to be.
        final error = targetFootPos - currentFootPos;
        // Apply that error to our head position guess.
        correctedHeadPos.add(error);
      }

      body.setTransform(correctedHeadPos, body.angle);

      // Kill velocity towards the wall to prevent "sticking"
      final wallNormal = (footPos - targetFootPos).normalized();
      if (wallNormal.length2 > 0) {
        final dot = body.linearVelocity.dot(wallNormal);
        if (dot > 0) {
          body.linearVelocity.sub(wallNormal * dot);
        }
      }

      // On collision, change direction
      if (math.Random().nextDouble() < 0.8) {
        final errorVec = footPos - targetFootPos;
        if (errorVec.x.abs() > 0.1) _walkDirection.x *= -1;
        if (errorVec.y.abs() > 0.1) _walkDirection.y *= -1;
      }
    }

    // Randomize direction slightly for more "alive" movement
    if (math.Random().nextDouble() < 0.02) {
      final jitterAngle = (math.Random().nextDouble() - 0.5) * 0.5;
      final currentAngle = math.atan2(_walkDirection.y, _walkDirection.x);
      final newAngle = currentAngle + jitterAngle;
      _walkDirection.setValues(math.cos(newAngle), math.sin(newAngle));
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

    // Legs (two segments each) with circular knee and foot motion
    final hipLeft = Offset(
      torsoBottom.dx - scaledRadius * 0.25,
      torsoBottom.dy,
    );
    final hipRight = Offset(
      torsoBottom.dx + scaledRadius * 0.25,
      torsoBottom.dy,
    );

    final kneeRadius = scaledRadius * 0.6;
    final footRadius = scaledRadius * 0.9;
    final stepSpeed = 4.0;
    final phase = autoWalk ? _time * stepSpeed : 0.0;

    // Left leg (matches update() logic)
    final leftKnee = Offset(
      hipLeft.dx + kneeRadius * math.cos(phase),
      hipLeft.dy + kneeRadius * math.sin(phase),
    );
    final leftFoot = Offset(
      leftKnee.dx + footRadius * math.cos(phase + math.pi / 2),
      leftKnee.dy + footRadius * math.sin(phase + math.pi / 2),
    );
    canvas.drawLine(hipLeft, leftKnee, bodyPaint);
    canvas.drawLine(leftKnee, leftFoot, bodyPaint);

    // Right leg (matches update() logic, phase shifted)
    final rightKnee = Offset(
      hipRight.dx + kneeRadius * math.cos(phase + math.pi),
      hipRight.dy + kneeRadius * math.sin(phase + math.pi),
    );
    final rightFoot = Offset(
      rightKnee.dx + footRadius * math.cos(phase + 3 * math.pi / 2),
      rightKnee.dy + footRadius * math.sin(phase + 3 * math.pi / 2),
    );
    canvas.drawLine(hipRight, rightKnee, bodyPaint);
    canvas.drawLine(rightKnee, rightFoot, bodyPaint);
  }

  void setWalkDirection(Vector2 dir) {
    _walkDirection = dir;
  }

  // Helper to compute foot position from head position, encapsulating the animation logic.
  Vector2 _calculateFootPos(
    Vector2 headPos,
    double back,
    double front,
    double phase,
  ) {
    final t = ((headPos.y - back) / (front - back)).clamp(0.0, 1.0);
    final scale = lerpDouble(1, 4, t)!;
    final scaledRadius = _radius * scale;
    final torsoBottomY = headPos.y + scaledRadius * 4;
    final hipLeft = Vector2(headPos.x - scaledRadius * 0.25, torsoBottomY);
    final hipRight = Vector2(headPos.x + scaledRadius * 0.25, torsoBottomY);

    final kneeRadius = scaledRadius * 0.6;
    final footRadius = scaledRadius * 0.9;

    // Vänster knä och fot
    final leftKnee = Vector2(
      hipLeft.x + kneeRadius * math.cos(phase),
      hipLeft.y + kneeRadius * math.sin(phase),
    );
    final leftFoot = Vector2(
      leftKnee.x + footRadius * math.cos(phase + math.pi / 2),
      leftKnee.y + footRadius * math.sin(phase + math.pi / 2),
    );

    // Höger knä och fot (fasförskjutet)
    final rightKnee = Vector2(
      hipRight.x + kneeRadius * math.cos(phase + math.pi),
      hipRight.y + kneeRadius * math.sin(phase + math.pi),
    );
    final rightFoot = Vector2(
      rightKnee.x + footRadius * math.cos(phase + 3 * math.pi / 2),
      rightKnee.y + footRadius * math.sin(phase + 3 * math.pi / 2),
    );

    return (leftFoot.y > rightFoot.y) ? leftFoot : rightFoot;
  }
}
