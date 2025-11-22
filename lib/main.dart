import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ball.dart';
import 'beach_court_painter.dart';
import 'boundaries.dart';

void main() {
  runApp(const GameWidget.controlled(gameFactory: MouseJointExample.new));
}

class MouseJointExample extends Forge2DGame {
  MouseJointExample()
    : super(world: MouseJointWorld(), gravity: Vector2(0, 80));
}

class MouseJointWorld extends Forge2DWorld
    with DragCallbacks, HasGameReference<Forge2DGame> {
  late final FragmentProgram program;
  FragmentShader? shader;
  late final BeachCourtPainter courtPainter;
  bool playingMusic = false;
  double time = 0;
  PositionComponent camera = PositionComponent();
  TextComponent lifeText = TextComponent(
    text: "100",
    position: Vector2(30, 20),
  );

  @override
  Future<void> onLoad() async {
    // game.camera.viewfinder.visibleGameSize = Vector2.all(gameSize);
    game.camera.viewport.add(FpsTextComponent());
    game.camera.viewport.add(lifeText);

    program = await FragmentProgram.fromAsset('shaders/bg.frag');
    shader = program.fragmentShader();
    courtPainter = BeachCourtPainter();
    shader = program.fragmentShader();
    // if not web
    if (!kIsWeb) {
      // FlameAudio.bgm.play('megalergik.mp3');
      playingMusic = true;
    }

    // Add boundaries and sand floor
    addAll(createBoundaries(game));
    add(SandFloor(height: 5.8));
    add(BouncingBall(Vector2(0, -4)));

    // game.add(Worm(Vector2(game.size.x / 2, 0)));
    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    // Draw background gradient
    final fragment = shader;
    // final canvasRect = canvas.getLocalClipBounds();
    // final canvasRect = Rect.fromLTWH(0, 0, game.size.x, game.size.y);
    final canvasRect = game.camera.visibleWorldRect;
    if (fragment != null) {
      fragment
        ..setFloat(0, time)
        ..setFloat(1, canvasRect.width)
        ..setFloat(2, canvasRect.height);
      canvas.drawRect(canvasRect, Paint()..shader = fragment);
    } else {
      canvas.drawRect(canvasRect, Paint()..color = const Color(0xFF0A1E32));
    }
    courtPainter.render(canvas, canvasRect);
    super.render(canvas);
  }

  @override
  void update(double dt) {
    time += dt;
    super.update(dt);
  }
}
