import 'package:flutter/services.dart';

class StepCounterException implements Exception {
  final String message;
  final String? code;
  const StepCounterException(this.message, [this.code]);
}

class StepCounterService {
  static const _channel = MethodChannel('mfu.smartguide/connected_wifi');

  Future<int> readTotalSteps() async {
    try {
      final value = await _channel
          .invokeMethod<num>('getStepCount')
          .timeout(const Duration(seconds: 3));
      if (value == null) {
        throw const StepCounterException('Step counter returned no data.');
      }
      return value.toInt();
    } on PlatformException catch (error) {
      throw StepCounterException(
        error.message ?? 'Cannot read step counter.',
        error.code,
      );
    }
  }
}
