import 'dart:math';
import 'dart:ui' as ui;

import 'package:fast_noise/fast_noise.dart';
import 'package:flutter/material.dart';

import '../effects/water_tile_effects.dart';
import '../entity/entity.dart';
import '../entity/player/player.dart';
import '../entity/wall/floor.dart';
import '../game_controller.dart';
import '../hud/build/build_foundation.dart';
import '../hud/build/build_hud.dart';
import '../scene/game_scene.dart';
import '../utils/timer_helper.dart';
import 'map_data.dart';
import 'map_tile.dart';

class MapController {
  //final Map<int, Map<int, Map<int, Tile>>> map = {};
  final List<Floor> floorTiles = [];
  MapData mapData;
  Player player;

  double widthViewPort;
  double heightViewPort;

  int border = 6;

  double posX = 0;
  double posY = 0;
  Offset targetPos;


  List<Entity> entityList = [];
  List<Entity> entitysOnViewport = [];
  final List<Entity> _tmpEntitysToBeAdded = [];
  int treesGenerated = 0;
  int tilesGenerated = 0;

  int safeY = 0;
  int safeYmax = 0;
  int safeX = 0;
  int safeXmax = 0;

  double cameraSpeed = 5;
  BuildFoundation buildFoundation;
  double tilePix;
  double scale = 0.5;
  int zoom = 2;
  int stripLength = 64;
  GameScene gameScene;
  double vertFactor = 3;
  BuildButtonState buildingState = BuildButtonState.none;

  SimplexNoise terrainNoise = SimplexNoise(
    frequency: 0.003, //0.004
    gain: 1,
    lacunarity: 2.6,
    octaves: 3,
    fractalType: FractalType.FBM,
  );

  SimplexNoise terrainNoise2 = SimplexNoise(
    frequency: .0002,
    gain: 1,
    lacunarity: 2.6,
    octaves: 3,
    fractalType: FractalType.FBM,
  );

  PerlinNoise treeNoise = PerlinNoise(
    frequency: .8,
    gain: 1,
    lacunarity: 1,
    octaves: 1,
    fractalType: FractalType.FBM,
  );

  MapController(Offset startPosition, this.gameScene) {
    posX = startPosition.dx;
    posY = startPosition.dy;
    targetPos = Offset(posX, posY);
    mapData = MapData (this);
  }
  void drawMap(Canvas c, double moveX, double moveY, Rect screenSize,
      {int tileSize = 16, int movimentType = MovimentType.move}) {
    var borderSize = (border * tileSize);
    scale = tileSize / 16;
    tilePix = tileSize.toDouble();
    // account for 64px wide triangle strips in map overview zoom level
    widthViewPort =
        (screenSize.width / tileSize).roundToDouble() + (border * 2) + MapTile.size;
    heightViewPort =
        (screenSize.height / tileSize).roundToDouble() + (border * 2) + MapTile.size;

    targetPos = Offset(
        (-moveX.roundToDouble() + screenSize.width / 2) + border * tileSize,
        (-moveY.roundToDouble() + screenSize.height / 2) + border * tileSize);
    if ((posY - targetPos.dy).abs() > 50 || (posX - targetPos.dx).abs() > 50) {
      movimentType = MovimentType.move; // keeps camera centered after zooms
    }
    // move camera
    if (movimentType == MovimentType.move) {
      posX = targetPos.dx;
      posY = targetPos.dy;
    } else if (movimentType == MovimentType.follow) {
      var delta = min(GameController.deltaTime, 0.05);
      posX = ui
          .lerpDouble(
          posX, targetPos.dx, delta * cameraSpeed)
          .roundToDouble();
      posY = ui
          .lerpDouble(
          posY, targetPos.dy, delta * cameraSpeed)
          .roundToDouble();
    }

    c.save();
    c.translate(posX - borderSize, posY - borderSize);

    var viewPort = Rect.fromLTWH(
      -posX / tileSize,
      -posY / tileSize,
      widthViewPort,
      heightViewPort,
    );

    safeY = (viewPort.top).ceil();
    safeYmax = (viewPort.bottom).ceil() + 6;
    safeX = (viewPort.left).ceil();
    safeXmax = (viewPort.right).ceil();

    var t = TimerHelper();
    var x, y;

    for (y = safeY; y < safeYmax; y+=MapTile.size) {
      for (x = safeX; x < safeXmax; x+=MapTile.size) {
        mapData.doTileAt (x, y, tileSize, c);
      }
    }
    // Draw each floor tile
    for (var floor in floorTiles){
      floor.draw(c);
    }
    t.logDelayPassed('draw map:');

    _findEntitysOnViewport();

    var t1 = TimerHelper();
    // Organize List to show Entity elements (Players, Trees)
    // on correct Y-Index order
    entitysOnViewport.sort((a, b) => a.y.compareTo(b.y));
    t1.logDelayPassed('draw effects:');

    var t2 = TimerHelper();
    //drawShadowns behind all elements
    for (var entity in entitysOnViewport) {
      if (!entity.marketToBeRemoved) entity.drawEffects(c);
    }
    t2.logDelayPassed('draw effects:');
    var t3 = TimerHelper();
    for (var entity in entitysOnViewport) {
      if (!entity.marketToBeRemoved) entity.draw(c);
    }
    t3.logDelayPassed('draw entity:');

    buildFoundation.drawRoofs(c);
    // static so that all tiles shift water colors in sync
    WaterTileEffects.shiftFoamColor ();

    c.restore();
  }

  int updateFrames = 0;
  void updateMap(double cx, double cy, Rect screenSize,
      {int tileSize = 16, int movimentType = MovimentType.move}) {

    tilePix = tileSize.toDouble();
    scale = tileSize/16;  // min zoom level has tileSize = 1 pixel per tile

    // account for 64px wide triangle strips in map overview zoom level
    //var strip = tileSize > 1 ? 0 : stripLength;
    var widthViewPort =
        (screenSize.width / tileSize).roundToDouble() + (border * 2) + stripLength*2;
    var heightViewPort =
        (screenSize.height / tileSize).roundToDouble() + (border * 2) + stripLength*2;

    var pos = Offset(
        (-cx.roundToDouble() + screenSize.width / 2) + border * tileSize,
        (-cy.roundToDouble() + screenSize.height / 2) + border * tileSize);

    var viewPort = Rect.fromLTWH(
      -pos.dx / tileSize,
      -pos.dy / tileSize,
      widthViewPort,
      heightViewPort,
    );

    var safeY = (viewPort.top).ceil();
    var safeYmax = (viewPort.bottom).ceil() + 6;
    var safeX = (viewPort.left).ceil();
    var safeXmax = (viewPort.right).ceil();

    for (var y = safeY; y < safeYmax; y+=MapTile.size) {
      for (var x = safeX; x < safeXmax; x+=MapTile.size) {
        mapData.doTileAt (x, y, tileSize, null);
      }
    }
  }

  int getHeightOnPos(int x, int y) {
    return mapData.getHeightAt (x, y);
  }

  void addEntity(Entity newEntity) {
    var foundEntity = _tmpEntitysToBeAdded.firstWhere(
        (element) => element.id == newEntity.id,
        orElse: () => null);

    if (foundEntity == null) {
      _tmpEntitysToBeAdded.add(newEntity);
    }
  }

  void addPlayerRef(Player player) {
    this.player = player;
    entityList.add(player);
  }

  bool _isEntityInsideViewport(Entity entity) {
    return (entity.posX > safeX &&
        entity.posY > safeY &&
        entity.posX < safeXmax &&
        entity.posY < safeYmax);
  }

  void _findEntitysOnViewport() {
    var t = TimerHelper();
    entitysOnViewport.clear();

    entityList.removeWhere((element) => element.marketToBeRemoved);

    //add entities in queuee
    for (var e in _tmpEntitysToBeAdded) {
      entityList.add(e);
      entitysOnViewport.add(e);
    }
    _tmpEntitysToBeAdded.clear();

    var distance = (Offset(posX, posY) - targetPos).distance;

    for (var i = 0; i < entityList.length; i++) {
      if (entityList[i] is Player || _isEntityInsideViewport(entityList[i])) {
        entitysOnViewport.add(entityList[i]);
      }

      if (_isEntityInsideViewport(entityList[i]) == false &&
          entityList[i] is Player &&
          entityList[i] != player &&
          distance < 16) {
        //entityList.remove(entityList[i]);
        entityList[i].marketToBeRemoved = true;
      }
    }
    t.logDelayPassed('_findEntitysOnViewport:');
  }

  /// Zoom levels change the pixels per tile used for the draw() functions
  /// (but world units per tile stays as 16 units/tile)
  void setZoom (int zoom) {
    gameScene.setZoom(zoom);
  }

}

class MovimentType {
  static const int none = 0;
  static const int move = 1;
  static const int follow = 2;
}
