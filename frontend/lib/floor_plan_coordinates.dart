import 'package:flutter/widgets.dart';

/// The coordinate calibration shared with model/floorplan/grid_config.json.
///
/// Meter origin (0, 0) is near the bottom-left of the drawing. X increases
/// to the right and Y increases upward. Image pixels start at the top-left.
abstract final class FloorPlanCoordinates {
  static const imageSize = Size(2048, 1095);
  static const xRangeMeters = (min: 0.0, max: 23.0);
  static const yRangeMeters = (min: 0.0, max: 12.0);

  static const pixelsPerMeterX = 81.75973015049297;
  static const pixelOriginX = 83.54800207576601;
  static const pixelsPerMeterY = -91.0665258711722;
  static const pixelOriginY = 1092.7911826821548;

  static Offset metersToImage(double xMeters, double yMeters) {
    return Offset(
      pixelsPerMeterX * xMeters + pixelOriginX,
      pixelsPerMeterY * yMeters + pixelOriginY,
    );
  }

  static Rect containedImageRect(Size canvasSize) {
    final fitted = applyBoxFit(BoxFit.contain, imageSize, canvasSize);
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & canvasSize,
    );
  }

  static Offset metersToCanvas(
    double xMeters,
    double yMeters,
    Size canvasSize,
  ) {
    final imagePoint = metersToImage(xMeters, yMeters);
    final imageRect = containedImageRect(canvasSize);
    return Offset(
      imageRect.left + imagePoint.dx / imageSize.width * imageRect.width,
      imageRect.top + imagePoint.dy / imageSize.height * imageRect.height,
    );
  }

  static bool isInsideFloor(double xMeters, double yMeters) {
    return xMeters >= xRangeMeters.min &&
        xMeters <= xRangeMeters.max &&
        yMeters >= yRangeMeters.min &&
        yMeters <= yRangeMeters.max;
  }
}
