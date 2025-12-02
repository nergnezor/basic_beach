import 'dart:math';
import 'dart:ui';

class CourtLayout {
  final double centerLineY;
  final double backLineY;
  final double frontLineY;
  // Relativ djupfaktor 0..1 från "kamera"/front mot back,
  // används för automatisk perspektivskala.
  final double depthFactorTop;
  final double depthFactorBottom;
  final double widthCenter;
  final double widthBack;
  final double widthFront;
  final List<Offset> topPolygon;
  final List<Offset> bottomPolygon;
  static const double frontToBackScaleFactor = 4;

  const CourtLayout({
    required this.centerLineY,
    required this.backLineY,
    required this.frontLineY,
    required this.widthCenter,
    required this.widthBack,
    required this.widthFront,
    required this.topPolygon,
    required this.bottomPolygon,
    required this.depthFactorTop,
    required this.depthFactorBottom,
  });
}

CourtLayout computeCourtLayout(Rect canvasRect) {
  final courtWidthCenter = canvasRect.width * 0.4;
  final edgeToCenterWidthFactor = CourtLayout.frontToBackScaleFactor / 2;
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

  // Court-halvor som polygoner (vänster/höger)
  final leftBackX = -courtWidthBack / 2;
  final rightBackX = courtWidthBack / 2;
  final leftFrontX = -courtWidthFront / 2;
  final rightFrontX = courtWidthFront / 2;

  final topPoly = <Offset>[
    Offset(leftBackX, backLineY),
    Offset(rightBackX, backLineY),
    Offset(courtWidthCenter / 2, centerLineY),
    Offset(-courtWidthCenter / 2, centerLineY),
  ];

  final bottomPoly = <Offset>[
    Offset(-courtWidthCenter / 2, centerLineY),
    Offset(courtWidthCenter / 2, centerLineY),
    Offset(rightFrontX, frontLineY),
    Offset(leftFrontX, frontLineY),
  ];

  // Automatisk djupfaktor baserat på court-höjd: 0 vid nätet,
  // 1 vid bak-/framlinje.
  final topDepth = (centerLineY - backLineY).abs() / courtHeight;
  final bottomDepth = (frontLineY - centerLineY).abs() / courtHeight;

  return CourtLayout(
    centerLineY: centerLineY,
    backLineY: backLineY,
    frontLineY: frontLineY,
    widthCenter: courtWidthCenter,
    widthBack: courtWidthBack,
    widthFront: courtWidthFront,
    topPolygon: topPoly,
    bottomPolygon: bottomPoly,
    depthFactorTop: topDepth.clamp(0.0, 1.0),
    depthFactorBottom: bottomDepth.clamp(0.0, 1.0),
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

  // Back line
  canvas.drawLine(
    Offset(-courtWidthBack / 2, backLineY),
    Offset(courtWidthBack / 2, backLineY),
    paint..strokeWidth = 0.5,
  );

  // Front line
  canvas.drawLine(
    Offset(-courtWidthFront / 2, frontLineY),
    Offset(courtWidthFront / 2, frontLineY),
    paint..strokeWidth = 2,
  );

  // Middle line (no net here anymore)
  final middleY = layout.centerLineY;
  canvas.drawLine(
    Offset(-layout.widthCenter / 2, middleY),
    Offset(layout.widthCenter / 2, middleY),
    paint..strokeWidth = 0.5,
  );

  // Court polygon
  final leftPath = Path()..addPolygon(layout.topPolygon, true);
  final rightPath = Path()..addPolygon(layout.bottomPolygon, true);

  canvas.drawPath(
    leftPath,
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF228B22).withAlpha(50),
  );

  canvas.drawPath(
    rightPath,
    paint
      ..style = PaintingStyle.fill
      ..color = const Color.fromARGB(255, 202, 161, 57).withAlpha(150),
  );
}

void drawNet(Canvas canvas, Rect canvasRect) {
  final layout = computeCourtLayout(canvasRect);
  final paint = Paint()..color = const Color(0x6FFFFFFF);

  final centerY = layout.centerLineY;
  final backLineY = layout.backLineY;
  final frontLineY = layout.frontLineY;

  // Net positioned where left and right halves meet
  final netHeight = (frontLineY - backLineY) * 0.2;
  final netWidth = layout.widthCenter;
  final netRect = Rect.fromCenter(
    center: Offset(0, centerY - netHeight / 2),
    width: netWidth,
    height: netHeight,
  );
  final rrect = RRect.fromRectAndRadius(netRect, const Radius.circular(0.5));
  canvas.drawRRect(rrect, paint);
  canvas.drawRRect(
    rrect,
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.2
      ..color = const Color(0x1fffffFF).withAlpha(100),
  );
}
