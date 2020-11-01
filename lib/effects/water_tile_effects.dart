import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../map/map_tile.dart';

// Renders stars for the whole map tile, using vertices triangles
class WaterTileEffects {
  Random r = Random();

  List<double> nextStarsTimes = <double>[];
  List<double> starsLifeTimes = <double>[];
  List<double> animSpeeds = <double>[];
  List<double> alphas = <double>[];
  List<bool> visible = <bool>[];
  List<Color> waterStarsColors = <Color>[];
  List<Offset> waterStarsPointsScaled = <Offset>[];
  List<Offset> waterStarsPoints = <Offset>[];
  List<Offset> waterFoamPoints = <Offset>[];
  List<Offset> waterFoamPointsScaled = <Offset>[];
  List<Color> waterFoamColors = <Color>[];
  Vertices shoreVertices;

  Color blinkStarsInitialColor;
  MapTile mapTile;
  Paint p = Paint();
  int frames = 0;

  Color foamColor;
  Color normalColor;
  Color sandColor;

  // static so that all tiles shift colors in sync
  static int direction = 0;
  static double speed = .5;
  static double timeInFuture = 0;
  static double timeLine = 0;

  WaterTileEffects(this.mapTile);
  void init () {
    int i;
    for (i=0; i<waterStarsPoints.length; i++) {
      nextStarsTimes.add(5 + GameController.time + r.nextInt(30));
      starsLifeTimes.add(0);
      animSpeeds.add(0.5);
      alphas.add(1);
      visible.add(false);
    };
  }

  void initFoam () {
    foamColor = Colors.blue[200];
    normalColor = Color.fromRGBO(83, 173, 246, 1);
    sandColor = Color.fromRGBO(231, 200, 140, 1);
    for (var i=0; i<waterFoamPoints.length; i++) {
      waterFoamColors.add(foamColor);
    };

    timeInFuture = GameController.time + 2;
  }

  void blinkWaterEffect(Canvas c, double size) {
    var n=0, j=0;
    if (frames++ % 4 == 0 && size >= 4) {
      waterStarsPointsScaled.clear();
      waterStarsColors.clear();
      for (n = 0; n < nextStarsTimes.length; n++) {
        if (GameController.time > nextStarsTimes[n]) {
          nextStarsTimes[n] = 10 + GameController.time + r.nextInt(60);
          starsLifeTimes[n] = GameController.time + 4;
          animSpeeds[n] = 0.4 + r.nextDouble() * 0.4;
          alphas[n] = 1;
          blinkStarsInitialColor = Colors.blue[50];
          visible[n] = true;
        }
        if (GameController.time > starsLifeTimes[n]) {
          visible[n] = false;
        }
        if (visible[n] && alphas[n] > 0) {
          alphas[n] = (alphas[n] -
              GameController.deltaTime * 4 * animSpeeds[n])
              .clamp(0.0, 1.0);
          blinkStarsInitialColor = Color.fromRGBO(
            blinkStarsInitialColor.red,
            blinkStarsInitialColor.green,
            blinkStarsInitialColor.blue,
            alphas[n],
          );
          waterStarsPointsScaled.add(
              waterStarsPoints[n] * mapTile.tileSize);
          waterStarsPointsScaled.add(waterStarsPoints[n].scale(
              mapTile.tileSize, mapTile.tileSize).translate(-1, 2));
          waterStarsPointsScaled.add(waterStarsPoints[n].scale(
              mapTile.tileSize, mapTile.tileSize).translate(1, 2));
          for (j = 0; j < 3; j++) {
            waterStarsColors.add(blinkStarsInitialColor);
          }
        }
      }
    }
    if (waterStarsPointsScaled.length == waterStarsColors.length) {
      var waterVertices = Vertices(
          VertexMode.triangles, waterStarsPointsScaled,
          colors: waterStarsColors);
      c.drawVertices(waterVertices, BlendMode.src, p);
    }
  }

  // static so that all tiles shift colors at once
  static void shiftFoamColor () {
    if (GameController.time > timeInFuture && timeLine >= 1) {
      timeInFuture = GameController.time + 3;
      direction++;
      timeLine = 0;
      if (direction > 5) {
        direction = 0;
      }
    }
    timeLine += GameController.deltaTime * speed;
    timeLine = timeLine.clamp(0.0, 1.0);
  }
  void drawFoamColor(Canvas c, double size) {

    Color current;
    if (direction == 0 || direction == 2) {
      current = Color.lerp(normalColor, foamColor, timeLine);
    } else if (direction == 1 || direction == 3) {
      current = Color.lerp(foamColor, normalColor, timeLine);
    } else if (direction == 4) {
      current = Color.lerp(normalColor, sandColor, timeLine);
    } else {
      current = Color.lerp(sandColor, normalColor, timeLine);
    }
    if (frames % 4 == 0) {
      waterFoamPointsScaled.clear();
      waterFoamColors.clear();
      for (var n = 0; n < waterFoamPoints.length; n++) {
        waterFoamPointsScaled.add(
            waterFoamPoints[n] * mapTile.tileSize);
        waterFoamColors.add(current);
      }
    }
    if (waterFoamPointsScaled.length == waterFoamColors.length) {
      shoreVertices = Vertices(
          VertexMode.triangles, waterFoamPointsScaled,
          colors: waterFoamColors);
      c.drawVertices(shoreVertices, BlendMode.src, p);
    }

  }
}
