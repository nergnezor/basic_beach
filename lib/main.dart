import 'dart:math';
import 'dart:ui';
import 'package:flutter/services.dart';

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
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<MouseJointExample>.controlled(
          gameFactory: MouseJointExample.new,
          overlayBuilderMap: {
            'zoomOverlay': (context, game) => Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      onPressed: () {
                        (game.world as MouseJointWorld).changeZoom(1.1);
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      onPressed: () {
                        (game.world as MouseJointWorld).changeZoom(1 / 1.1);
                      },
                      child: const Icon(Icons.remove),
                    ),
                  ],
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class MouseJointExample extends Forge2DGame with KeyboardEvents {
  MouseJointExample()
    : super(world: MouseJointWorld(), gravity: Vector2(0, 80));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    overlays.add('zoomOverlay');
  }

  MouseJointWorld get _mouseJointWorld => world as MouseJointWorld;

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyV) {
      _mouseJointWorld.togglePerspectiveTarget();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
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
  double _targetBlend = 1;
  final double _blendSpeed = 0.8;
  void togglePerspectiveTarget() {
    _targetBlend = (_targetBlend >= 0.5) ? 0.0 : 1.0;
  }

  void changeZoom(double factor) {
    courtPainter.zoom = (courtPainter.zoom * factor).clamp(0.3, 3.0);
  }

  @override
  Future<void> onLoad() async {
    // game.camera.viewfinder.visibleGameSize = Vector2.all(gameSize);
    game.camera.viewport.add(FpsTextComponent());
    game.camera.viewport.add(lifeText);

    program = await FragmentProgram.fromAsset('shaders/bg.frag');
    shader = program.fragmentShader();
    courtPainter = BeachCourtPainter();
    courtPainter.viewBlend = 0;
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
    // Compute zoom from window width so zoom changes with window resizing.
    // Example: width 1000 -> zoom 1.0; clamp to reasonable bounds.
    final ratio = canvasRect.height / canvasRect.width;
    final w = canvasRect.width;
    final h = canvasRect.height;
    final computedZoom = pow(w, -0.1).toDouble();
    debugPrint(
      "Window size: ${w.toStringAsFixed(1)}x${h.toStringAsFixed(1)}, "
      "ratio: ${ratio.toStringAsFixed(3)}, computedZoom: ${computedZoom.toStringAsFixed(3)}",
    );

    courtPainter.zoom = computedZoom;
    courtPainter.render(canvas, canvasRect);
    super.render(canvas);
  }

  @override
  void update(double dt) {
    _updateCourtBlend(dt);
    time += dt;
    super.update(dt);
  }

  void _updateCourtBlend(double dt) {
    final difference = _targetBlend - courtPainter.viewBlend;
    if (difference.abs() < 0.001) {
      courtPainter.viewBlend = _targetBlend;
      return;
    }
    final direction = difference.sign;
    courtPainter.viewBlend =
        (courtPainter.viewBlend + direction * _blendSpeed * dt).clamp(0.0, 1.0);
  }
}
