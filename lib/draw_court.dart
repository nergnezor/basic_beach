import 'dart:math';
import 'dart:ui';

class CourtLayout {
  final double backLineY;
  final double frontLineY;
  final double widthBack;
  final double widthFront;

  const CourtLayout({
    required this.backLineY,
    required this.frontLineY,
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

  return CourtLayout(
    backLineY: backLineY,
    frontLineY: frontLineY,
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
