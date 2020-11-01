import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../../map/map_controller.dart';
import '../../utils/preload_assets.dart';
import 'foundation.dart';
import 'furniture.dart';

class Door extends Furniture {
  Sprite openDoor;
  bool show = true;
  bool isOpen = false;

  Door(double newPosX, double newPosY, MapController map, double width,
      double height, String imageId, Foundation foundation)
      : super(newPosX, newPosY, map, width, height, imageId, foundation) {
    loadsprite();
  }

  void loadsprite() {
    openDoor = PreloadAssets.getFurnitureSprite('${imageId}_open');
  }

  @override
  void draw(Canvas c) {
    if (isOpen) {
      currentSprite = openDoor;
      isActive = false;
    } else {
      currentSprite = sprite;
      isActive = true;
    }
    super.draw(c);
    //sprite?.renderScaled(c, Position(x, y), scale: 1);
  }
}
