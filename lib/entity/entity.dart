import 'dart:math';

import 'package:flame/position.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../effects/damage_effect.dart';
import '../effects/ripple_water_effect.dart';
import '../effects/walk_effect.dart';
import '../hud/build/build_hud.dart';
import '../map/map_controller.dart';
import '../map/map_data.dart';
import '../scene/game_scene.dart';
import '../utils/preload_assets.dart';
import 'physics_entity.dart';
import 'player/player.dart';
import 'status.dart';

abstract class Entity extends PhysicsEntity {
  Status status = Status();
  bool marketToBeRemoved = false;
  bool isActive = true;

  String name;
  String id;

  ///tiled position
  int posX;
  int posY;

  MapController map;
  int mapHeight = 1;
  double width = 16;
  double height = 16;

  Rect collisionBox;
  bool isCollisionTrigger = false;

  //double worldSize;

  Paint p = Paint();

  double shadownSize = 2;
  Sprite shadownLarge;
  Offset shadownOffset = Offset.zero;
  final RippleWaterEffect _rippleWaterEffect = RippleWaterEffect();
  final WalkEffect _walkEffect = WalkEffect();
  final DamageEffect _damageEffect = DamageEffect();

  Entity(double x, double y, this.map) : super(x, y) {
    //worldSize = GameScene.tilePixels.toDouble();

    shadownLarge = PreloadAssets.getEffectSprite('shadown_large');
    updatePhysics();
  }

  void draw(Canvas c) {
    print("drawning wrongly, this draw method should be overwritten.");
  }

  void update() {
    if (!isActive || marketToBeRemoved) {
      return;
    }
    var walkSpeed = max(inputSpeed.dx.abs(), inputSpeed.dy.abs());
    status.update(walkSpeed);
    if (status.getEnergy() <= 0) {
      maxSpeedEnergyMultiplier = .5;
    } else {
      maxSpeedEnergyMultiplier = 1;
    }
  }

  void debugDraw(Canvas c) {
    p.color = Colors.red;
    p.strokeWidth = 1;
    p.style = PaintingStyle.stroke;
    c.drawRect(collisionBox, p);
  }

  void drawEffects(Canvas c) {
    if (!isActive) {
      return;
    }
    var scale = GameScene.pixelsPerTile/16;

    _drawShadown(c);
    if (this is Player) {
      _rippleWaterEffect.draw(c, x*scale, y*scale - zOffset, mapHeight);
      _walkEffect.draw(c, x*scale, y*scale - zOffset, mapHeight, inputSpeed);
    }
    _damageEffect.draw(c, x*scale, y*scale - zOffset);
  }

  double get zOffset {
    // 2D in Building mode
    if (map.buildingState != BuildButtonState.none){
      return 0;
    }
    // Return z Offset based on height to follow 3D terrain
    return max(0, (mapHeight - Land.lowWater) / map.vertFactor * map.scale * 8);
  }

  void _drawShadown(Canvas c) {
    var scale = GameScene.pixelsPerTile/16;
    var distanceToGround = 1 - (z.abs().clamp(0, 100) / 100);

    var p = Paint();
    p.color = Color.fromRGBO(255, 255, 255, distanceToGround);

    var sizeX = 16 * shadownSize / 2;
    var sizeY = (16 - 3) * shadownSize;

    shadownLarge?.renderScaled(
      c,
      Position(
        x * scale - sizeX * distanceToGround * scale + shadownOffset.dx * scale,
        y * scale - sizeY * distanceToGround * scale + shadownOffset.dy * scale
            - zOffset,
      ),
      scale: shadownSize * distanceToGround * scale,
      overridePaint: p,
    );
  }

  void updatePhysics() {
    posX = (x / 16).floor();
    posY = (y / 16).floor();

    collisionBox = Rect.fromLTWH(x - (width / 2), y - height, width, height);

    updateGravity();
    moveFriction();
  }

  void getHut(int damage, Entity other, {bool isMine = false}) {
    status.takeDamage(damage);
    showDamage(damage, isMine: isMine);
  }

  void showDamage(int damage, {bool isMine = false}) {
    _damageEffect.addText(damage, isMine: isMine);
  }

  void onTriggerStay(Entity entity) {}

  void destroy() {
    marketToBeRemoved = true;
  }

  @override
  String toString() {
    return """name: $name, (x: $x, y: $y), isActive: $isActive, isAlive: ${status.isAlive()}, hp: ${status.getHP()}, marketToBeRemoved: $marketToBeRemoved, id: $id""";
  }

}
