import 'dart:math';

import 'package:flutter/material.dart';

import '../utils/preload_assets.dart';
import 'map_controller.dart';
import 'map_tile.dart';
import 'tree.dart';

/// Manages infinite set of large map tiles (64x64 tiles each)
/// Generates and displays tiles as they enter the viewport
/// Author: Brad Scheurman
class MapData {
  MapData (this.map);
  final Map<int, Map<int, MapTile>> mapTiles = {};
  MapController map;
  MapTile workingTile;

  void doTileAt (int x, int y, int size, Canvas canvas) {
    MapTile mapTile;

    // each map tile is 64x64 small tiles
    var x0 = (x/MapTile.size).floor().toInt();
    var y0 = (y/MapTile.size).floor().toInt();
    if (mapTiles[x0] != null && mapTiles[x0][y0] != null) {
      mapTile = mapTiles[x0][y0];
    } else {
      mapTile = MapTile (x,y, map);
      if (mapTiles[x0] == null) {
        mapTiles[x0] = {x0: null}; //initialize line
      }
      mapTiles[x0][y0] = mapTile; //initialize line
    }

    if (size != mapTile.tileSize) {
      if (canvas == null) {
        mapTile.rescale (size.toDouble());
      }
      return;
    }

    if (canvas != null) {
      mapTile.draw (canvas);
    } else {
      mapTile.update (x,y);
    }

    workingTile = mapTile;
  }

  // Entitys needs to know the terrain height at their x,y
  int getHeightAt(int x, int y) {
    // need map lookup
    var x0 = (x / MapTile.size).floor().toInt();
    var y0 = (y / MapTile.size).floor().toInt();
    if (mapTiles[x0] != null && mapTiles[x0][y0] != null) {
      var mapTile = mapTiles[x0][y0];
      return mapTile.getHeightAt(x, y);
    }
    return 192;
  }
}

// Land base class, defines the land types and colors for height
class Land {
  static const waterType = 1;
  static const lowWaterType = 2;
  static const lowSandType = 3;
  static const sandType = 4;
  static const grassType = 5;
  static const rockType = 6;

  static const water = 95-30;
  static const lowWater = 110-30;
  static const lowSand = 112-30;
  static const sand = 118-30;
  static const lowGrass = 140;
  static const rock = 190;

  Land (this.type, this.color);
  int type;
  Color color;

  factory Land.fromHeight(int heightLvl, double x, double y, MapTile tile ) {
    var green = (155 - (heightLvl-100)/2).toInt();

    if (heightLvl <= Land.lowWater) {
      var blue = Color.fromRGBO(0, (heightLvl*2.5).toInt(),
            min(255,(heightLvl*4)), .94);
      return Land(Land.lowWaterType, blue); // Colors.blue[400]
    } else if (heightLvl <= Land.lowSand) {
      return Land(Land.lowSandType, Color.fromRGBO(255, 224, 130, 1));
    } else if (heightLvl < Land.sand) {
      return Land(Land.sandType, Colors.amber[200]);
    } else if (heightLvl < Land.lowGrass) {
      if (Random().nextInt(100) > 95) {
        var id = Random().nextInt(4) + 7;
        tile.groundSprites.add(
            GroundSprite(x, y, PreloadAssets.getEnviromentSprite("grass$id")));
      }
      return Land(Land.grassType, Color.fromRGBO(116, green + 50, 54, 1));
    } else if (heightLvl < 160) {
      if (Random().nextInt(100) > 96) {
        var id = Random().nextInt(2) + 11;
        tile.groundSprites.add (GroundSprite (x,y,PreloadAssets
                .getEnviromentSprite("grass$id")));
      }
      return Land(Land.grassType, Color.fromRGBO(82, green + 40, 46, 1));
    } else if (heightLvl < 185) {
      if (Random().nextInt(100) > 98) {
        var id = Random().nextInt(2) + 13;
        tile.groundSprites.add (GroundSprite (x,y,PreloadAssets
                .getEnviromentSprite("grass$id")));
      }
      return Land(Land.grassType, Color.fromRGBO(75, green + 36, 65, 1));
    } else if (heightLvl < Land.rock) {
      return Land(Land.grassType, Color.fromRGBO(82, green+28, 46, 1));
    } else {
      return Land(Land.rockType, Color.fromRGBO(  // gray color for peaks
          min(200,heightLvl - 60), min(200,heightLvl - 60),
          min(200,heightLvl - 60), 1));
    }
  }
  // add trees etc while generating tiles
  void addFeatures (double x, double y, int height, double tileSize,
                    MapController map) {
    // TREES
    if (height < lowGrass || height > rock) {
      return;
    }
    if (x % 6 == 0 && y % 6 == 0) {
      var treeHeight =
      ((map.treeNoise.getPerlin2(x.toDouble(), y.toDouble()) * 128) + 127)
          .toInt();

      if (treeHeight > 165) {
        var ix = x.toInt(), iy = y.toInt(), tileSizeInt = tileSize.toInt();
        if (treeHeight % 5 == 0) {
          map.entityList.add(Tree(ix, iy, map, tileSizeInt, "tree_4"));
        } else if (treeHeight % 6 == 0) {
          map.entityList.add(Tree(ix, iy, map, tileSizeInt, "tree_3"));
        } else if (treeHeight % 7 == 0) {
          map.entityList.add(Tree(ix, iy, map, tileSizeInt, "tree_2"));
        } else {
          map.entityList.add(Tree(ix, iy, map, tileSizeInt, "tree_1"));
        }
      }
    }

  }
}

