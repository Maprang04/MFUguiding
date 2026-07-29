import 'package:flutter_test/flutter_test.dart';
import 'package:mfuguide/floor_plan_coordinates.dart';

void main() {
  const knownLocations = {
    'AP1': (x: 16.25, y: 11.75),
    'AP2': (x: 10.5, y: 9.75),
    'AP3': (x: 2.0, y: 0.5),
    'Room 1 entrance': (x: 15.0, y: 5.0),
    'Room 2 entrance': (x: 15.0, y: 9.0),
    'Room 3 entrance': (x: 11.0, y: 5.0),
  };

  test('uses the real floor-plan asset dimensions', () {
    expect(FloorPlanCoordinates.imageSize.width, 2048);
    expect(FloorPlanCoordinates.imageSize.height, 1095);
  });

  test('all six known locations are inside the calibrated floor', () {
    for (final entry in knownLocations.entries) {
      expect(
        FloorPlanCoordinates.isInsideFloor(entry.value.x, entry.value.y),
        isTrue,
        reason: entry.key,
      );
    }
  });

  test('all six known locations map inside the source image', () {
    for (final entry in knownLocations.entries) {
      final point = FloorPlanCoordinates.metersToImage(
        entry.value.x,
        entry.value.y,
      );
      expect(
        point.dx,
        inInclusiveRange(0, FloorPlanCoordinates.imageSize.width),
        reason: '${entry.key} x',
      );
      expect(
        point.dy,
        inInclusiveRange(0, FloorPlanCoordinates.imageSize.height),
        reason: '${entry.key} y',
      );
    }
  });

  test('x points right and y points upward on the image', () {
    final origin = FloorPlanCoordinates.metersToImage(0, 0);
    expect(FloorPlanCoordinates.metersToImage(1, 0).dx, greaterThan(origin.dx));
    expect(FloorPlanCoordinates.metersToImage(0, 1).dy, lessThan(origin.dy));
  });
}
