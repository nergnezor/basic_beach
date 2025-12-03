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
    priority = isTopRow ? 5 : 15;
  }

  final Vector2 spawnPosition;
  final int playerId;
  final bool autoWalk;
  final bool isLeftSide;
  final bool isTopRow;

  static const double _radius = 1.0;

  Vector2 _walkDirection = Vector2(1, 0);
  final double _walkSpeed = 25.0;
  double _time = 0.0;

  @override
  Body createBody() {
    final s = CircleShape()..radius = _radius;
    final f = FixtureDef(s)
      ..density = 1.0
      ..friction = 0.5
      ..restitution = 0.2;
    final bd = BodyDef()
      ..type = BodyType.kinematic
      ..position = spawnPosition;
    final b = world.createBody(bd)..createFixture(f);
    b.linearDamping = 0.2;
    b.angularDamping = 0.3;
    return b;
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

    if (_walkDirection.length2 == 0) {
      final a = math.Random().nextDouble() * math.pi * 2;
      _walkDirection.setValues(math.cos(a), math.sin(a));
    }

    // scale movement by depth to match visual size
    final y = body.position.y;
    final tDepth =
        ((y - layout.backLineY) / (layout.frontLineY - layout.backLineY)).clamp(
          0.0,
          1.0,
        );
    final depthScale = lerpDouble(1, 4, tDepth)!;
    final moveSpeed = _walkSpeed * depthScale;
    body.linearVelocity = (_walkDirection.length2 > 0)
        ? _walkDirection.normalized() * moveSpeed
        : Vector2.zero();

    final head = body.position.clone();
    final back = layout.backLineY;
    final front = layout.frontLineY;
    final phase = autoWalk ? _time * 4.0 : 0.0;

    final foot = _calculateFootPos(head, back, front, phase);
    final footOff = Offset(foot.x, foot.y);

    if (!_pointInPoly(footOff, poly)) {
      final proj = _projectToPoly(footOff, poly);
      final target = Vector2(proj.dx, proj.dy);

      var guess = head.clone();
      const iters = 5;
      for (int i = 0; i < iters; i++) {
        final cur = _calculateFootPos(guess, back, front, phase);
        guess.add(target - cur);
      }
      body.setTransform(guess, body.angle);

      final wallNormal = (foot - target).normalized();
      if (wallNormal.length2 > 0) {
        final dot = body.linearVelocity.dot(wallNormal);
        if (dot > 0) body.linearVelocity.sub(wallNormal * dot);
      }

      if (math.Random().nextDouble() < 0.8) {
        final e = foot - target;
        if (e.x.abs() > 0.1) _walkDirection.x *= -1;
        if (e.y.abs() > 0.1) _walkDirection.y *= -1;
      }
    }

    if (math.Random().nextDouble() < 0.02) {
      final jitter = (math.Random().nextDouble() - 0.5) * 0.5;
      final ang = math.atan2(_walkDirection.y, _walkDirection.x) + jitter;
      _walkDirection.setValues(math.cos(ang), math.sin(ang));
    }
  }

  @override
  void renderCircle(Canvas canvas, Offset center, double radius) {
    final worldRect = game.camera.visibleWorldRect;
    final layout = computeCourtLayout(worldRect);
    final back = layout.backLineY;
    final front = layout.frontLineY;

    final y = body.position.y;
    final t = ((y - back) / (front - back)).clamp(0.0, 1.0);
    final scale = lerpDouble(1, 4, t)!;
    final sr = radius * scale;

    final headPaint = Paint()..color = const Color(0xFF0000FF);
    final bodyPaint = Paint()
      ..color = const Color.fromARGB(255, 48, 111, 136)
      ..strokeWidth = sr * 0.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, sr, headPaint);
    final torsoTop = Offset(center.dx, center.dy + sr);
    final torsoBottom = Offset(center.dx, center.dy + sr * 4);
    canvas.drawLine(torsoTop, torsoBottom, bodyPaint);

    final shoulderY = center.dy + sr * 1.5;
    final armLen = sr * 1.8;
    final leftShoulder = Offset(center.dx, shoulderY);
    final leftElbow = leftShoulder + Offset(-armLen * 0.8, armLen * 0.4);
    final leftHand = leftElbow + Offset(-armLen * 0.6, armLen * 0.6);
    canvas.drawLine(leftShoulder, leftElbow, bodyPaint);
    canvas.drawLine(leftElbow, leftHand, bodyPaint);

    final rightShoulder = Offset(center.dx, shoulderY);
    final rightElbow = rightShoulder + Offset(armLen * 0.8, armLen * 0.4);
    final rightHand = rightElbow + Offset(armLen * 0.6, armLen * 0.6);
    canvas.drawLine(rightShoulder, rightElbow, bodyPaint);
    canvas.drawLine(rightElbow, rightHand, bodyPaint);

    final hipLeft = Offset(torsoBottom.dx - sr * 0.25, torsoBottom.dy);
    final hipRight = Offset(torsoBottom.dx + sr * 0.25, torsoBottom.dy);
    final kneeR = sr * 0.6;
    final footR = sr * 0.9;
    final phase = autoWalk ? _time * 4.0 : 0.0;

    final leftKnee = Offset(
      hipLeft.dx + kneeR * math.cos(phase),
      hipLeft.dy + kneeR * math.sin(phase),
    );
    final leftFoot = Offset(
      leftKnee.dx + footR * math.cos(phase + math.pi / 2),
      leftKnee.dy + footR * math.sin(phase + math.pi / 2),
    );
    canvas.drawLine(hipLeft, leftKnee, bodyPaint);
    canvas.drawLine(leftKnee, leftFoot, bodyPaint);

    final rightKnee = Offset(
      hipRight.dx + kneeR * math.cos(phase + math.pi),
      hipRight.dy + kneeR * math.sin(phase + math.pi),
    );
    final rightFoot = Offset(
      rightKnee.dx + footR * math.cos(phase + 3 * math.pi / 2),
      rightKnee.dy + footR * math.sin(phase + 3 * math.pi / 2),
    );
    canvas.drawLine(hipRight, rightKnee, bodyPaint);
    canvas.drawLine(rightKnee, rightFoot, bodyPaint);
  }

  void setWalkDirection(Vector2 dir) => _walkDirection = dir;

  Vector2 _calculateFootPos(
    Vector2 headPos,
    double back,
    double front,
    double phase,
  ) {
    final t = ((headPos.y - back) / (front - back)).clamp(0.0, 1.0);
    final scale = lerpDouble(1, 4, t)!;
    final sr = _radius * scale;
    final torsoBottomY = headPos.y + sr * 4;
    final hipL = Vector2(headPos.x - sr * 0.25, torsoBottomY);
    final hipR = Vector2(headPos.x + sr * 0.25, torsoBottomY);
    final kneeR = sr * 0.6;
    final footR = sr * 0.9;

    final leftKnee = Vector2(
      hipL.x + kneeR * math.cos(phase),
      hipL.y + kneeR * math.sin(phase),
    );
    final leftFoot = Vector2(
      leftKnee.x + footR * math.cos(phase + math.pi / 2),
      leftKnee.y + footR * math.sin(phase + math.pi / 2),
    );

    final rightKnee = Vector2(
      hipR.x + kneeR * math.cos(phase + math.pi),
      hipR.y + kneeR * math.sin(phase + math.pi),
    );
    final rightFoot = Vector2(
      rightKnee.x + footR * math.cos(phase + 3 * math.pi / 2),
      rightKnee.y + footR * math.sin(phase + 3 * math.pi / 2),
    );

    return (leftFoot.y > rightFoot.y) ? leftFoot : rightFoot;
  }

  bool _pointInPoly(Offset p, List<Offset> verts) {
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
}
