import 'dart:math';
import 'dart:ui';

class CourtLayout {
  final double centerLineY;
  final double backLineY;
  final double frontLineY;
  final double widthCenter;
  final double widthBack;
  final double widthFront;

  const CourtLayout({
    required this.centerLineY,
    required this.backLineY,
    required this.frontLineY,
    required this.widthCenter,
    required this.widthBack,
    required this.widthFront,
  });
}

CourtLayout computeCourtLayout(Rect canvasRect) {
  final courtWidthCenter = canvasRect.width * 0.4;
  final edgeToCenterWidthFactor = 2;
  final courtWidthFront = courtWidthCenter * edgeToCenterWidthFactor;
  final courtWidthBack = courtWidthCenter / edgeToCenterWidthFactor;

  final courtHeight = min(canvasRect.height, canvasRect.width) / 2;
  final bottomPadding = courtHeight / 5;
  final yBottom = canvasRect.height / 2 - bottomPadding;

  final backLineY = yBottom - courtHeight;
  final frontLineY = yBottom;

  // Använd likformighet
  final halfCenterWidth = courtWidthCenter;
  final halfCenterY =
      (halfCenterWidth / courtWidthFront) * (frontLineY - backLineY);
  final centerLineY = backLineY + halfCenterY - bottomPadding;

  return CourtLayout(
    centerLineY: centerLineY,
    backLineY: backLineY,
    frontLineY: frontLineY,
    widthCenter: courtWidthCenter,
    widthBack: courtWidthBack,
    widthFront: courtWidthFront,
  );
}

void drawCourt(Canvas canvas, Rect canvasRect) {
  final paint = Paint()
    ..color = const Color(0xFFFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  final layout = computeCourtLayout(canvasRect);
  final backLineY = layout.backLineY;
  final frontLineY = layout.frontLineY;
  final courtWidthBack = layout.widthBack;
  final courtWidthFront = layout.widthFront;

  // Draw back line
  canvas.drawLine(
    Offset(-courtWidthBack / 2, backLineY),
    Offset(courtWidthBack / 2, backLineY),
    paint..strokeWidth = 0.5,
  );

  // Draw front line
  canvas.drawLine(
    Offset(-courtWidthFront / 2, frontLineY),
    Offset(courtWidthFront / 2, frontLineY),
    paint..strokeWidth = 2,
  );

  // Draw middle line
  final middleY = layout.centerLineY;
  canvas.drawLine(
    Offset(-layout.widthCenter / 2, middleY),
    Offset(layout.widthCenter / 2, middleY),
    paint..strokeWidth = 0.5,
  );

  // Draw net as a rectangle
  final netHeight = (frontLineY - backLineY) * 0.2;
  final netWidth = layout.widthCenter;
  final netRect = Rect.fromCenter(
    center: Offset(0, middleY - netHeight / 2),
    width: netWidth,
    height: netHeight,
  );
  canvas.drawRect(
    netRect,
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF808080).withAlpha(50),
  );

  final courtPoly = Path()
    ..moveTo(-courtWidthBack / 2, backLineY)
    ..lineTo(courtWidthBack / 2, backLineY)
    ..lineTo(courtWidthFront / 2, frontLineY)
    ..lineTo(-courtWidthFront / 2, frontLineY)
    ..close();
  canvas.drawPath(
    courtPoly,
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF228B22).withAlpha(50),
  );
}
