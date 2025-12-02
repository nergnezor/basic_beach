import 'dart:math' as math;
import 'dart:ui';
import 'package:basic_beach/draw_court.dart';
import 'package:basic_beach/player.dart';
import 'package:flutter/services.dart';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ball.dart';

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
        ),
      ),
    );
  }
}

class MouseJointExample extends Forge2DGame {
  MouseJointExample()
    : super(world: MouseJointWorld(), gravity: Vector2(0, 80));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
  }
}

class MouseJointWorld extends Forge2DWorld
    with DragCallbacks, HasGameReference<Forge2DGame>, WidgetsBindingObserver {
  late final FragmentProgram program;
  FragmentShader? shader;
  bool playingMusic = false;
  double time = 0;
  TextComponent lifeText = TextComponent(
    text: "100",
    position: Vector2(30, 20),
  );
  Size? _lastLogicalSize;

  @override
  void didChangeMetrics() {
    _updateSize();
  }

  void _updateSize() {
    final view = PlatformDispatcher.instance.views.first;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    if (_lastLogicalSize != null && _lastLogicalSize == logicalSize) {
      return; // no change
    }
    _lastLogicalSize = logicalSize;
  }

  @override
  Future<void> onLoad() async {
    game.camera.viewport.add(FpsTextComponent());
    game.camera.viewport.add(lifeText);

    program = await FragmentProgram.fromAsset('shaders/bg.frag');
    shader = program.fragmentShader();
    // Initialize size-dependent camera/zoom once and listen for future resizes
    _updateSize();
    WidgetsBinding.instance.addObserver(this);
    // if not web
    if (!kIsWeb) {
      // FlameAudio.bgm.play('megalergik.mp3');
      playingMusic = true;
    }

    // Add boundaries and sand floor
    add(SandFloor(height: 5.8));
    add(BouncingBall(Vector2(0, -4)));
    // Place the four players on the court
    final canvasRect = game.camera.visibleWorldRect;
    final layout = computeCourtLayout(canvasRect);

    final leftX = -layout.widthBack / 4;
    final rightX = layout.widthBack / 4;
    final topY =
        (layout.backLineY + layout.frontLineY) / 2 -
        (layout.frontLineY - layout.backLineY) / 4;
    final bottomY =
        (layout.backLineY + layout.frontLineY) / 2 +
        (layout.frontLineY - layout.backLineY) / 4;

    // Bestäm gånggränser från court-bredden
    final leftWalkLeft = -layout.widthBack / 2;
    final leftWalkRight = 0.0;
    final rightWalkLeft = 0.0;
    final rightWalkRight = layout.widthBack / 2;

    // Övre två spelare går automatiskt på sin planhalva
    add(
      Player(
        Vector2(leftX, topY),
        playerId: 0,
        autoWalk: true,
        walkLeftBoundary: leftWalkLeft,
        walkRightBoundary: leftWalkRight,
      ),
    );

    add(Player(Vector2(leftX, bottomY), playerId: 1));

    add(
      Player(
        Vector2(rightX, topY),
        playerId: 2,
        autoWalk: true,
        walkLeftBoundary: rightWalkLeft,
        walkRightBoundary: rightWalkRight,
      ),
    );

    add(Player(Vector2(rightX, bottomY), playerId: 3));

    // game.add(Worm(Vector2(game.size.x / 2, 0)));
    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    // Draw background gradient
    final fragment = shader;
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

    drawCourt(canvas, canvasRect);

    super.render(canvas);
  }

  @override
  void update(double dt) {
    time += dt;
    super.update(dt);
  }
}
