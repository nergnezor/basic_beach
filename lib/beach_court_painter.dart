import 'dart:math' as math;
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

const double _lineWidthMeters = 0.05;
const double _postWidthMeters = 0.12;
const double _marginFactor = 0.04;
const double _minMarginPx = 24.0;
const double _heightScale = 0.35;
const double _viewHeightMeters = 6.0;

/// Renders a beach volleyball court with official FIVB measurements
/// with a blend between top-down and perspective projections.
class BeachCourtPainter {
  BeachCourtPainter()
    : projector = PerspectiveProjector(
        camera: const Vec3(0, -60, 15),
        target: const Vec3(0, -10, 0),
        upHint: const Vec3(0, 0, 1),
        focalLength: 1.8,
      ),
      viewBlend = 0.0,
      zoom = 2.0;

  final PerspectiveProjector projector;
  double viewBlend;
  double zoom;

  void render(Canvas canvas, Rect viewport) {
    if (viewport.isEmpty) {
      return;
    }

    canvas.save();
    canvas.clipRect(viewport);
    canvas.translate(viewport.left, viewport.top);

    final size = viewport.size;
    final marginPx = math.max(size.shortestSide * _marginFactor, _minMarginPx);

    const halfSandWidth = BeachCourtMeasurements.totalSandWidth / 2;
    const halfSandLength = BeachCourtMeasurements.totalSandLength / 2;

    const courtHalfWidth = BeachCourtMeasurements.courtWidth / 2;
    const courtHalfLength = BeachCourtMeasurements.courtLength / 2;

    // Project court corners to get bounds for better framing
    final courtCorners = const [
      Vec3(-courtHalfWidth, -courtHalfLength, 0),
      Vec3(courtHalfWidth, -courtHalfLength, 0),
      Vec3(courtHalfWidth, courtHalfLength, 0),
      Vec3(-courtHalfWidth, courtHalfLength, 0),
    ];
    final projectedCourtCorners = courtCorners.map(projector.project).toList();
    final courtMinX = projectedCourtCorners.map((p) => p.dx).reduce(math.min);
    final courtMaxX = projectedCourtCorners.map((p) => p.dx).reduce(math.max);
    final courtMinY = projectedCourtCorners.map((p) => p.dy).reduce(math.min);
    final courtMaxY = projectedCourtCorners.map((p) => p.dy).reduce(math.max);

    // Also project sand corners to get minY for baseline anchoring
    final sandCorners = const [
      Vec3(-halfSandWidth, -halfSandLength, 0),
      Vec3(halfSandWidth, -halfSandLength, 0),
      Vec3(halfSandWidth, halfSandLength, 0),
      Vec3(-halfSandWidth, halfSandLength, 0),
    ];
    final projectedCorners = sandCorners.map(projector.project).toList();
    final minY = projectedCorners.map((p) => p.dy).reduce(math.min);

    final viewHeightPoint = projector.project(
      const Vec3(0, 0, _viewHeightMeters),
    );
    final topY = math.max(viewHeightPoint.dy, courtMaxY);
    final verticalRange = math.max(topY - courtMinY, 0.1);
    final horizontalRange = math.max(courtMaxX - courtMinX, 0.1);

    final availableWidth = math.max(size.width - marginPx * 2, 1.0);
    final availableHeight = math.max(size.height - marginPx * 2, 1.0);
    final scaleX = availableWidth / horizontalRange;
    final scaleY = availableHeight / verticalRange;
    final scale = math.min(scaleX, scaleY) * zoom.clamp(0.0, 5.0);
    const double metersToPx = 0.1;
    final lineWidth = _lineWidthMeters * scale * metersToPx;
    final postWidth = _postWidthMeters * scale * metersToPx;
    final meshWidth = lineWidth * 0.1;

    final scaleTopDown = math.min(
      availableWidth / BeachCourtMeasurements.totalSandWidth,
      availableHeight / BeachCourtMeasurements.totalSandLength,
    );
    final contentWidth = BeachCourtMeasurements.totalSandWidth * scaleTopDown;
    final contentHeight = BeachCourtMeasurements.totalSandLength * scaleTopDown;
    final translateX =
        marginPx + (size.width - marginPx * 2 - contentWidth) / 2;
    final translateY =
        marginPx + (size.height - marginPx * 2 - contentHeight) / 2;

    Offset mapTopDown(Vec3 worldPoint) {
      final x = worldPoint.x + halfSandWidth;
      final y =
          BeachCourtMeasurements.totalSandLength -
          (worldPoint.y + halfSandLength);
      final heightOffset = worldPoint.z * scaleTopDown * _heightScale;
      return Offset(
        translateX + x * scaleTopDown,
        translateY + y * scaleTopDown - heightOffset,
      );
    }

    Offset mapPerspective(Vec3 worldPoint) {
      final projected = projector.project(worldPoint);
      final xOffset = marginPx + (availableWidth - horizontalRange * scale) / 2;
      final baselineScreenY =
          size.height - marginPx - 30.0 * zoom.clamp(0.3, 3.0);
      final yOffset = baselineScreenY - minY * scale;
      return Offset(
        xOffset + (projected.dx - courtMinX) * scale,
        yOffset + (topY - projected.dy) * scale,
      );
    }

    Offset mapPoint(Vec3 worldPoint) {
      if (viewBlend <= 0) {
        return mapTopDown(worldPoint);
      }
      if (viewBlend >= 1) {
        return mapPerspective(worldPoint);
      }
      return Offset.lerp(
            mapTopDown(worldPoint),
            mapPerspective(worldPoint),
            viewBlend,
          ) ??
          mapPerspective(worldPoint);
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
    final sandPath = buildPath(const [
      Vec3(-halfSandWidth, -halfSandLength, 0),
      Vec3(halfSandWidth, -halfSandLength, 0),
      Vec3(halfSandWidth, halfSandLength, 0),
      Vec3(-halfSandWidth, halfSandLength, 0),
    ]);

    final sandPaint = Paint()
      ..shader =
          const LinearGradient(
            colors: [Color(0xFFF7E2B7), Color(0xFFE7C18A)],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(
            Rect.fromLTWH(0, marginPx, size.width, size.height - marginPx * 2),
          );
    canvas.drawPath(sandPath, sandPaint);

    _drawFootprints(canvas, mapPoint);

    // Draw court boundary
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
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(courtPath, linePaint);

    // Draw center line (dividing the two sides)
    final centerLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = lineWidth;
    canvas.drawLine(
      mapPoint(const Vec3(-courtHalfWidth, 0, 0.02)),
      mapPoint(const Vec3(courtHalfWidth, 0, 0.02)),
      centerLinePaint,
    );

    // Draw attack lines
    const attackLineY = BeachCourtMeasurements.attackLineDistance;
    final attackLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = lineWidth;
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

    _drawNet(canvas, mapPoint, lineWidth, postWidth, meshWidth);

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

  void _drawNet(
    Canvas canvas,
    Offset Function(Vec3) mapPoint,
    double tapeWidth,
    double postWidth,
    double meshWidth,
  ) {
    const netHalfLength = BeachCourtMeasurements.netLength / 2;
    const netHeight = BeachCourtMeasurements.netHeight;
    const netPos = 0.0; // Center of court

    final postPaint = Paint()
      ..color = const Color(0xFF7C4A1F)
      ..strokeWidth = postWidth
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
    final netBottomStart = mapPoint(
      const Vec3(-netHalfLength, netPos, netHeight / 2),
    );
    final netBottomEnd = mapPoint(
      const Vec3(netHalfLength, netPos, netHeight / 2),
    );

    final tapePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = tapeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(netTopStart, netTopEnd, tapePaint);

    // Draw net mesh
    final meshPaint = Paint()
      ..color = const Color(0x66000000)
      ..strokeWidth = meshWidth;

    const columns = 30;
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

    const rows = columns / 8;
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

    // Net shadow intentionally not drawn.
  }
}
