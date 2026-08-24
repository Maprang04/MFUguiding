import 'package:flutter/services.dart';

class MotionState {
  final bool moving;
  final double intensity;

  const MotionState({required this.moving, required this.intensity});
}

class MotionDetectionService {
  static const _channel = MethodChannel('mfu.smartguide/connected_wifi');

  Future<MotionState> read() async {
    final value = await _channel
        .invokeMapMethod<String, dynamic>('getMotionState')
        .timeout(const Duration(seconds: 2));
    return MotionState(
      moving: value?['moving'] == true,
      intensity: (value?['intensity'] as num?)?.toDouble() ?? 0,
    );
  }
}
