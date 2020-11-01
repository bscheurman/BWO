import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/position.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/cupertino.dart';

import '../effects/water_tile_effects.dart';
import '../hud/build/build_hud.dart';
import '../utils/vector3.dart';
import 'map_controller.dart';
import 'map_data.dart';

/// update and draw each large map tile
/// Uses canvas setVertices for best performance, creating 3D terrain effect
/// Generates large scale terrain features like mountain ranges, hills, seas
/// Replaces ground.dart
/// Author: Brad Scheurman
class MapTile {
  static Vector3 lightV = Vector3(0.5,0,1).normalized();
  MapTile (int x, int y, this.map) {
    init (x, y);
  }
  MapController map;
  int x0, y0;
  double tileSize = 16;
  double scale = 1;
  static const int size = 64;
  static Paint vpaint = Paint();
  static const int stripLength = 64;

  Int16List heights = Int16List((size+2)*(size+1));
  Uint8List shades = Uint8List((size+2)*(size+1));
  Uint8List types = Uint8List((size+2)*(size+1));

  static const int overviewSize = 16;
  final Int16List _ovHeights = Int16List((overviewSize+2)*(overviewSize+1));
  final Uint8List _ovShades = Uint8List((overviewSize+2)*(overviewSize+1));
  final Uint8List _ovTypes = Uint8List((overviewSize+2)*(overviewSize+1));
  final _ovPositionsStrips = <List<Offset>>[];
  final _ovColorsStrips = <List<Color>>[];
  final _buildPositionsStrips = <List<Offset>>[];

  final List<Vertices> _strips = [];
  final _positionsStrips = <List<Offset>>[];
  final _colorsStrips = <List<Color>>[];
  List<GroundSprite> groundSprites = <GroundSprite>[];

  WaterTileEffects water;

  bool insideOf (int x, int y) =>  (x >= x0 && x <= x0 + size && y >= y0 && y <= y0 + size);

  /// Generate new tile data as it enters viewport
  void init (int x, int y) {
    tileSize = map.tilePix;
    scale = tileSize/16;
    x0 = (x/size).floor().toInt()*size;
    y0 = (y/size).floor().toInt()*size;

    // Vertices For normal zoom levels
    if (tileSize > 1) {
      if (map.buildingState == BuildButtonState.none && _positionsStrips.length == 0) {
        water = WaterTileEffects(this);
        _fillTriangles( size, 1, heights, shades, types,
            _positionsStrips, _colorsStrips);
        water.init();
        water.initFoam();
      } else if (map.buildingState != BuildButtonState.none &&
          _buildPositionsStrips.length == 0) {
        _fillTriangles( size, 1, heights, shades, types,
            _buildPositionsStrips, _colorsStrips);
      }
    }
    // Vertices For maximum zoom out, skips every 4th tile
    else if (tileSize <= 1 && _ovPositionsStrips.length == 0){
      _fillTriangles( overviewSize, 4, _ovHeights, _ovShades, _ovTypes,
          _ovPositionsStrips, _ovColorsStrips);
    }
  }
  void update (int x, int y) {
    init (x, y);
  }
  /// Generates the vertices procedurally from small and large scale noise
  /// creating interesting large scale features like mountain ranges
  /// Each strip of vertices curves according to height for 3D effect
  void _fillTriangles (int _size, int skip,
      Int16List _heights, Uint8List _shades, Uint8List _types,
      List<List<Offset>> _positionsStrips, List<List<Color>> _colorsStrips) {
    var positions= <Offset>[];
    var colors = <Color>[];
    int heightLeft, heightTop;
    double tx, ty;
    var index = 0;
    var shade;
    int tileShade;

    for (double i=0; i<= _size+1; i++) {
      for (double j=0; j<= _size; j++) {
        ty = y0 + i*skip - skip;
        tx = x0 + j*skip - skip;

        var tileHeight =
        ((map.terrainNoise.getSimplexFractal2(ty+250, tx-300) *
            128) + 127).toInt();
        // Large scale variety such as mountain ranges and seas
        var tileNoise2 = ((map.terrainNoise2.getSimplexFractal2(ty+250, tx-300) *
            4*128) + 4*128-1).clamp(80*4,150*4).toInt();

        tileHeight = ((tileHeight-10) * (tileNoise2-60*4) / (60*4)).toInt();
        _heights[index] = tileHeight;

        if (i>0) {
          heightTop = _heights[index-_size-1];

        }
        // Light source shading from vector to show hillsides
        if (i>0 && j>0 && tileHeight >= Land.lowWater) {
          heightLeft = _heights[index-1];

          var west = Vector3(8*skip.toDouble(), 0, (heightLeft-tileHeight).toDouble());
          var north = Vector3(0, 8*skip.toDouble(), (heightTop-tileHeight).toDouble());
          var normal = west.cross(north);
          normal.normalize();
          //print ('normal: ${normal.x},${normal.y},${normal.z}');
          shade = lightV.dot(normal)*.6 + 0.4;
          tileShade = (shade * 256).toInt();
          _shades[index] = (tileShade);
        } else {
          shade = 1;
          _shades[index] = (255);
        }
        var land = Land.fromHeight(tileHeight, tx, ty, this);

        var color = land.color;
        _types[index] = land.type;
        if (_size == size && map.buildingState == BuildButtonState.none) {
          land.addFeatures(tx, ty, tileHeight, 16, map);
          if (i>0 && j>0 && tileHeight < Land.lowWater-3 && heightTop <
                  Land.lowWater-3 && _heights[index-1] < Land.lowWater-3) {
            if (i%2 == 1 && j%2 == 1) {
              water.waterStarsPoints.add(Offset(tx, ty));
            }
          }
          if (tileHeight >= Land.lowWater-2+2 && tileHeight <= Land.lowSand) {
            water.waterFoamPoints.add(Offset(tx, ty-1));
            water.waterFoamPoints.add(Offset(tx, ty+1-1));
            water.waterFoamPoints.add(Offset(tx+1, ty-1));
            water.waterFoamPoints.add(Offset(tx, ty+1-1));
            water.waterFoamPoints.add(Offset(tx+1, ty+1-1));
            water.waterFoamPoints.add(Offset(tx+1, ty-1));
          }
        }

        // Generate triangles vertices
        if (i>0 && j>0) {
          if (shade < 1) {
            color = Color.fromARGB(color.alpha, (color.red * shade).toInt(),
                (color.green * shade).toInt(), (color.blue * shade).toInt());
          }
          if (i>1) {
            double perspectiveTop = 0, perspective = 0;
            if (tileSize > 1 && map.buildingState == BuildButtonState.none) {
              perspectiveTop = max( 0, (heightTop - Land.lowSand)
                  / map.vertFactor * 0.5);
              perspective = max( 0, (tileHeight - Land.lowSand)
                  / map.vertFactor * 0.5);
            }

            positions.add(Offset(tx, ty - skip - perspectiveTop));
            positions.add(Offset(tx, ty - perspective-0.0));

            colors.add(color); // should get different color for lower point
            colors.add(color);

            if (j == _size) {
              positions.add(Offset(tx + skip, ty - skip - perspectiveTop));
              positions.add(Offset(tx + skip, ty - perspective-0.0));
              colors.add(color);
              colors.add(color);
            }
            if (positions.length >= stripLength * 2 / skip + 2) {
              _positionsStrips.add(positions);
              _colorsStrips.add(colors);
              positions = [];
              colors = [];
            }
          }
        }
        index ++;
      }
    }
    rescale ( tileSize);
  }

  /// Quickly Rescale the vertices when zoom changes
  void rescale (double size) {
    var n = 0;
    tileSize = size;
    scale = tileSize/16;
    _strips.clear();
    var posStrips = _positionsStrips;
    var colStrips = _colorsStrips;
    if (tileSize <= 1) {
      posStrips = _ovPositionsStrips;
      colStrips = _ovColorsStrips;
    } else if (map.buildingState != BuildButtonState.none){
      posStrips = _buildPositionsStrips;
    }
    for (var positions in posStrips){
      var scaledPositions;
      if (tileSize > 1){
        scaledPositions = positions.map((offset) => offset*size).toList();
      } else {
        scaledPositions = positions;
      }
      var vertices = Vertices(VertexMode.triangleStrip,scaledPositions,colors:colStrips[n]);
      _strips.add (vertices);
      n ++;
    };
  }

  /// draw vertices, sprites and water effects
  void draw(Canvas c) {
    for (var vertices in _strips) {
      c.drawVertices(vertices, BlendMode.src, vpaint);
    };

    if (tileSize >= 8) {
      for (var grass in groundSprites) {
          grass.sprite.renderScaled(c,
              Position(grass.x * tileSize, grass.y * tileSize), scale: scale);
      }
    }
    if (water != null) {
      water.blinkWaterEffect(c, tileSize);
      water.drawFoamColor(c, tileSize);
    }
  }

  /// Entities need to find height at their location, from MapTile
  int getHeightAt(int x, int y) {
    var index = ((y%size)+1) * (size+1);
    index += ((x%size)+1);
    if (index < heights.length) {
      return heights[index];
    }
    return 192;
  }
}

/// Sprite for Grass, generated on ground
class GroundSprite {
  GroundSprite (this.x,this.y,this.sprite);
  Sprite sprite;
  double x;
  double y;
}