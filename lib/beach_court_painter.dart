import 'dart:ui';

import 'package:flutter/material.dart';

import 'math_utils.dart';

/// Official FIVB Beach Volleyball Court measurements (in meters).
/// Reference: FIVB Beach Volleyball Rules, Court dimensions section.
class BeachCourtMeasurements {
  /// Court length (baseline to baseline)
  static const double courtLength = 16.0;

  /// Court width (sideline to sideline)
  static const double courtWidth = 8.0;

  /// Distance from baseline to attack line
  static const double attackLineDistance = 3.0;

  /// Free zone width (minimum)
  static const double freeZoneWidth = 5.0;

  /// Net height for men
  static const double netHeightMen = 2.43;

  /// Net height for women
  static const double netHeightWomen = 2.24;

  /// Net height used (default to men's)
  static const double netHeight = netHeightMen;

  /// Net length
  static const double netLength = 8.94;

  /// Position of net (middle of court)
  static const double netPosition = courtLength / 2;

  /// Total sand area width (including free zone)
  static const double totalSandWidth = courtWidth + 2 * freeZoneWidth;

  /// Total sand area length (including free zone)
  static const double totalSandLength = courtLength + 2 * freeZoneWidth;
}

/// Renders a beach volleyball court with official FIVB measurements
/// from a perspective camera view.
class BeachCourtPainter {
  BeachCourtPainter()
      : projector = PerspectiveProjector(
          camera: const Vec3(0, -1.5, 3),
          target: const Vec3(0, 8, 0),
          upHint: const Vec3(0, 0, 1),
          focalLength: 0.9,
        );

  final PerspectiveProjector projector;

  void render(Canvas canvas, Rect viewport) {
    if (viewport.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRect(viewport);
    canvas.translate(viewport.left, viewport.top);

    final size = viewport.size;
    final scale = size.shortestSide * 0.32;
    final baseY = size.height * 0.7;

    Offset mapPoint(Vec3 worldPoint) {
      final projected = projector.project(worldPoint);
      return Offset(
        size.width / 2 + projected.dx * scale,
        baseY - projected.dy * scale,
      );
    }

    Path buildPath(List<Vec3> points) {
      final first = mapPoint(points.first);
      final path = Path()..moveTo(first.dx, first.dy);
      for (final point in points.skip(1)) {
        final offset = mapPoint(point);
        path.lineTo(offset.dx, offset.dy);
      }
      path.close();
      return path;
    }

    // Draw sand area
    const halfWidth = BeachCourtMeasurements.totalSandWidth / 2;
    const halfLength = BeachCourtMeasurements.totalSandLength / 2;
    final sandPath = buildPath(const [
      Vec3(-halfWidth, -halfLength, 0),
      Vec3(halfWidth, -halfLength, 0),
      Vec3(halfWidth, halfLength, 0),
      Vec3(-halfWidth, halfLength, 0),
    ]);

    final sandPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFF7E2B7), Color(0xFFE7C18A)],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, baseY - scale, size.width, scale * 2));
    canvas.drawPath(sandPath, sandPaint);

    _drawFootprints(canvas, mapPoint);

    // Draw court boundary
    const courtHalfWidth = BeachCourtMeasurements.courtWidth / 2;
    const courtHalfLength = BeachCourtMeasurements.courtLength / 2;
    final courtPath = buildPath(const [
      Vec3(-courtHalfWidth, -courtHalfLength, 0),
      Vec3(courtHalfWidth, -courtHalfLength, 0),
      Vec3(courtHalfWidth, courtHalfLength, 0),
      Vec3(-courtHalfWidth, courtHalfLength, 0),
    ]);

    final courtFill = Paint()
      ..color = const Color(0xFFF2D9A4).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(courtPath, courtFill);

    final linePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(courtPath, linePaint);

    // Draw center line (dividing the two sides)
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      mapPoint(const Vec3(-courtHalfWidth, 0, 0.02)),
      mapPoint(const Vec3(courtHalfWidth, 0, 0.02)),
      centerLinePaint,
    );

    // Draw attack lines
    const attackLineY = BeachCourtMeasurements.attackLineDistance;
    final attackLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      mapPoint(const Vec3(-courtHalfWidth, -attackLineY, 0.01)),
      mapPoint(const Vec3(courtHalfWidth, -attackLineY, 0.01)),
      attackLinePaint,
    );
    canvas.drawLine(
      mapPoint(const Vec3(-courtHalfWidth, attackLineY, 0.01)),
      mapPoint(const Vec3(courtHalfWidth, attackLineY, 0.01)),
      attackLinePaint,
    );

    _drawNet(canvas, mapPoint);
    _drawBall(canvas, mapPoint);

    canvas.restore();
  }

  void _drawFootprints(Canvas canvas, Offset Function(Vec3) mapPoint) {
    final footprints = <Vec3>[
      const Vec3(-2.6, 1.5, 0.05),
      const Vec3(-2.2, 1.9, 0.05),
      const Vec3(1.3, 2.7, 0.05),
      const Vec3(1.7, 3.1, 0.05),
      const Vec3(-0.6, 5.0, 0.05),
      const Vec3(-0.2, 5.4, 0.05),
    ];

    final footprintPaint = Paint()
      ..color = const Color(0x883C2F2F)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (final foot in footprints) {
      final center = mapPoint(foot);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 18, height: 9),
        footprintPaint,
      );
    }
  }

  void _drawNet(Canvas canvas, Offset Function(Vec3) mapPoint) {
    const netHalfLength = BeachCourtMeasurements.netLength / 2;
    const netHeight = BeachCourtMeasurements.netHeight;
    const netPos = 0.0; // Center of court

    final postPaint = Paint()
      ..color = const Color(0xFF7C4A1F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    void drawPost(double x) {
      canvas.drawLine(
        mapPoint(Vec3(x, netPos, 0)),
        mapPoint(Vec3(x, netPos, netHeight)),
        postPaint,
      );
    }

    drawPost(-netHalfLength - 0.3);
    drawPost(netHalfLength + 0.3);

    final netTopStart = mapPoint(const Vec3(-netHalfLength, netPos, netHeight));
    final netTopEnd = mapPoint(const Vec3(netHalfLength, netPos, netHeight));
    final netBottomStart = mapPoint(const Vec3(-netHalfLength, netPos, 0.2));
    final netBottomEnd = mapPoint(const Vec3(netHalfLength, netPos, 0.2));

    final tapePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(netTopStart, netTopEnd, tapePaint);

    // Draw net mesh
    final meshPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = 1;

    const columns = 9;
    for (var i = 0; i <= columns; i++) {
      final t = i / columns;
      final top = Offset(
        lerpDouble(netTopStart.dx, netTopEnd.dx, t)!,
        lerpDouble(netTopStart.dy, netTopEnd.dy, t)!,
      );
      final bottom = Offset(
        lerpDouble(netBottomStart.dx, netBottomEnd.dx, t)!,
        lerpDouble(netBottomStart.dy, netBottomEnd.dy, t)!,
      );
      canvas.drawLine(top, bottom, meshPaint);
    }

    const rows = 5;
    for (var i = 1; i < rows; i++) {
      final t = i / rows;
      final left = Offset(
        lerpDouble(netTopStart.dx, netBottomStart.dx, t)!,
        lerpDouble(netTopStart.dy, netBottomStart.dy, t)!,
      );
      final right = Offset(
        lerpDouble(netTopEnd.dx, netBottomEnd.dx, t)!,
        lerpDouble(netTopEnd.dy, netBottomEnd.dy, t)!,
      );
      canvas.drawLine(left, right, meshPaint);
    }

    // Draw net shadow
    final shadowPaint = Paint()
      ..color = const Color(0x33131313)
      ..style = PaintingStyle.fill;
    final shadowPath = Path()
      ..moveTo(netBottomStart.dx, netBottomStart.dy)
      ..lineTo(netBottomEnd.dx, netBottomEnd.dy)
      ..lineTo(netBottomEnd.dx + 18, netBottomEnd.dy + 12)
      ..lineTo(netBottomStart.dx + 18, netBottomStart.dy + 12)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);
  }

  void _drawBall(Canvas canvas, Offset Function(Vec3) mapPoint) {
    final ballCenter = mapPoint(const Vec3(-1.0, 6.0, 0.3));
    const ballRadius = 10.0;

    final ballPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFF5C3), Color(0xFFFFC94A)],
      ).createShader(
        Rect.fromCircle(center: ballCenter, radius: ballRadius * 1.2),
      );
    canvas.drawCircle(ballCenter, ballRadius, ballPaint);

    final seamPaint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: ballCenter, radius: ballRadius),
      -0.7,
      2.6,
      false,
      seamPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: ballCenter, radius: ballRadius * 0.9),
      1.1,
      2.4,
      false,
      seamPaint,
    );
  }
}
