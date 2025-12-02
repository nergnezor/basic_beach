import 'dart:ui';

import 'package:basic_beach/draw_court.dart';
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

class Net extends Component with HasGameReference<Forge2DGame> {
  Net() {
    // Ensure the net renders between top and bottom players
    priority = 10;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final canvasRect = game.camera.visibleWorldRect;
    drawNet(canvas, canvasRect);
  }
}
