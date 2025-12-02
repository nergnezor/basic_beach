import 'dart:math' as math;
import 'dart:ui';
import 'package:basic_beach/draw_court.dart';
import 'package:basic_beach/net.dart';
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

    // Övre vänster – auto, vänster sida
    add(
      Player(
        Vector2(leftX, topY),
        playerId: 0,
        autoWalk: true,
        isLeftSide: true,
        isTopRow: true,
      ),
    );
    // Övre höger – auto, höger sida
    add(
      Player(
        Vector2(rightX, topY),
        playerId: 1,
        autoWalk: true,
        isLeftSide: false,
        isTopRow: true,
      ),
    );

    // Nedre vänster – stilla
    add(
      Player(
        Vector2(leftX, bottomY),
        playerId: 2,
        autoWalk: false,
        isLeftSide: true,
        isTopRow: false,
      ),
    );

    // Nedre höger – stilla
    add(
      Player(
        Vector2(rightX, bottomY),
        playerId: 3,
        autoWalk: false,
        isLeftSide: false,
        isTopRow: false,
      ),
    );
    add(Net());

    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    final fragment = shader;
    final canvasRect = game.camera.visibleWorldRect;

    // background...
    if (fragment != null) {
      fragment
        ..setFloat(0, time)
        ..setFloat(1, canvasRect.width)
        ..setFloat(2, canvasRect.height);
      canvas.drawRect(canvasRect, Paint()..shader = fragment);
    } else {
      canvas.drawRect(canvasRect, Paint()..color = const Color(0xFF0A1E32));
    }

    // Court ground and lines
    drawCourt(canvas, canvasRect);

    // Players (top & bottom)
    super.render(canvas);

    // Net drawn on top
    drawNet(canvas, canvasRect);
  }

  @override
  void update(double dt) {
    super.update(dt);
    time += dt;
  }
}
