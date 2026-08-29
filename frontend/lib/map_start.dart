import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mfuguide/map_report.dart';
import 'package:mfuguide/floor_plan_coordinates.dart';
import 'package:mfuguide/navigation_api.dart';
import 'package:mfuguide/user_page_header.dart';
import 'package:mfuguide/connected_wifi_service.dart';
import 'package:mfuguide/motion_detection_service.dart';

class MapStartPage extends StatefulWidget {
  final String currentLanguage;
  final String destinationId;
  final String destinationLabel;
  final VoidCallback? onClose;
  final ValueChanged<String>? onLanguageChanged;

  const MapStartPage({
    super.key,
    this.currentLanguage = 'EN',
    this.destinationId = 'room_1',
    this.destinationLabel = 'Room 1 entrance',
    this.onClose,
    this.onLanguageChanged,
  });

  @override
  State<MapStartPage> createState() => _MapStartPageState();
}

class _MapStartPageState extends State<MapStartPage> {
  final Color _burgundy = const Color(0xFF8B0000);
  final NavigationApi _navigationApi = NavigationApi();
  final ConnectedWifiService _wifiService = ConnectedWifiService();
  final MotionDetectionService _motionService = MotionDetectionService();
  Timer? _wifiTimer;
  Timer? _motionTimer;
  bool _readingWifi = false;
  bool _readingMotion = false;
  bool _waitingForPosition = true;
  int _wifiReadAttempts = 0;
  int _completeFingerprintReadings = 0;
  bool _showObstacleAlert = false;
  bool _isLoading = true;
  bool _stopping = false;
  String? _error;
  String? _sessionId;
  late final String _clientId;
  Map<String, dynamic>? _session;
  Future<void> _positionUpdateQueue = Future<void>.value();
  int? _lastRouteVersion;
  bool _arrived = false;
  double _motionDistanceMeters = 0.75;

  late String _language;

  String t(String en, String th) => _language == 'EN' ? en : th;

  double get _positionUncertaintyMeters {
    final band = _session?['signal_band']?.toString();
    final confidence = _session?['confidence']?.toString();
    var radius = switch (band) {
      'near' => 2.5,
      'medium' => 4.0,
      'edge' => 6.0,
      _ => 6.0,
    };
    if (confidence == 'low') radius += 1.5;
    return radius;
  }

  @override
  void initState() {
    super.initState();
    _language = widget.currentLanguage;
    _clientId = 'mfu-flutter-${DateTime.now().microsecondsSinceEpoch}';
    _startNavigation();
  }

  void _toggleLanguage() {
    setState(() => _language = _language == 'EN' ? 'TH' : 'EN');
    widget.onLanguageChanged?.call(_language);
  }

  Future<void> _startNavigation() async {
    setState(() {
      _isLoading = true;
      _waitingForPosition = true;
      _wifiReadAttempts = 0;
      _completeFingerprintReadings = 0;
      _error = null;
    });
    try {
      if (_sessionId == null) {
        final created = await _navigationApi.createSession(
          clientId: _clientId,
          destinationId: widget.destinationId,
          // Let the first live Wi-Fi observation determine the start zone.
          startPosition: null,
        );
        _sessionId = created['session_id']?.toString();
      }
      if (_sessionId == null) {
        throw const NavigationApiException(
          'Backend did not return a navigation session id.',
        );
      }
      await _readAndSubmitWifi();
      _wifiTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _readAndSubmitWifi(),
      );
      _motionTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _advanceWhileMoving(),
      );
      /* Legacy scripted simulator observations removed from the runtime flow.
      const observations = [
        ('AP3', -61),
        ('AP3', -63),
        ('AP3', -62),
        ('AP2', -73),
        ('AP2', -69),
        ('AP2', -66),
        ('AP1', -72),
        ('AP1', -68),
        ('AP1', -64),
      ];
      for (final observation in observations) {
        if (!mounted || _stopping) return;
        final result = await _navigationApi.submitSimulatorObservation(
          clientId: _clientId,
          associatedAp: observation.$1,
          rssi: observation.$2,
        );
        final current = (result['session'] as Map?)?.cast<String, dynamic>();
        if (!mounted || current == null) return;
        final routeVersion = (current['route_version'] as num?)?.toInt();
        setState(() {
          _session = current;
          _lastRouteVersion = routeVersion;
          _isLoading = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 850));
      }
      await _playRouteToDestination();
      */
    } on NavigationApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _readAndSubmitWifi() async {
    if (_readingWifi || _stopping || !mounted) return;
    _readingWifi = true;
    try {
      final reading = await _wifiService.read();
      _wifiReadAttempts++;
      if (reading.accessPointRssi.length == 3) {
        _completeFingerprintReadings++;
      } else {
        _completeFingerprintReadings = 0;
      }
      final result = await _serializePositionUpdate(
        () => _navigationApi.submitMobileObservation(
          clientId: _clientId,
          associatedAp: reading.accessPoint,
          rssi: reading.rssi,
          accessPointRssi: reading.accessPointRssi,
        ),
      );
      final current = (result['session'] as Map?)?.cast<String, dynamic>();
      if (!mounted || current == null) return;
      final routeVersion = (current['route_version'] as num?)?.toInt();
      if (_lastRouteVersion != null &&
          routeVersion != null &&
          routeVersion < _lastRouteVersion!) {
        return;
      }
      final positioning = result['positioning'] as Map?;
      final recommendedDistance =
          (positioning?['recommended_motion_distance_m'] as num?)?.toDouble();
      setState(() {
        _session = current;
        if (recommendedDistance != null) {
          _motionDistanceMeters = recommendedDistance.clamp(0.55, 1.1);
        }
        _lastRouteVersion = routeVersion;
        _isLoading = false;
        _waitingForPosition =
            _completeFingerprintReadings < 3 && _wifiReadAttempts < 8;
        _error = null;
      });
    } on ConnectedWifiException catch (error) {
      if (_arrived) return;
      if (mounted) {
        setState(() {
          _error = error.message;
          _isLoading = false;
          _waitingForPosition = false;
        });
      }
    } on NavigationApiException catch (error) {
      if (_arrived) return;
      if (mounted) {
        setState(() {
          _error = error.message;
          _isLoading = false;
          _waitingForPosition = false;
        });
      }
    } finally {
      _readingWifi = false;
    }
  }

  Future<T> _serializePositionUpdate<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _positionUpdateQueue = _positionUpdateQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _advanceWhileMoving() async {
    if (_readingMotion ||
        _stopping ||
        _waitingForPosition ||
        _arrived ||
        !mounted ||
        _sessionId == null) {
      return;
    }
    final route = ((_session?['route'] as List?) ?? const []);
    if (route.length < 2) return;
    _readingMotion = true;
    try {
      final motion = await _motionService.read();
      if (!motion.moving || !mounted || _stopping) return;
      final result = await _serializePositionUpdate(
        () => _navigationApi.submitMotionProgress(
          sessionId: _sessionId!,
          clientId: _clientId,
          distanceMeters: _motionDistanceMeters,
        ),
      );
      final current = (result['session'] as Map?)?.cast<String, dynamic>();
      if (!mounted || current == null) return;
      final arrived = (result['progress'] as Map?)?['arrived'] == true;
      final routeVersion = (current['route_version'] as num?)?.toInt();
      if (_lastRouteVersion != null &&
          routeVersion != null &&
          routeVersion < _lastRouteVersion!) {
        return;
      }
      setState(() {
        _session = current;
        _lastRouteVersion = routeVersion ?? _lastRouteVersion;
        _arrived = arrived;
      });
      if (arrived) {
        _wifiTimer?.cancel();
        _motionTimer?.cancel();
        try {
          await _navigationApi.completeSession(
            sessionId: _sessionId!,
            clientId: _clientId,
          );
        } on NavigationApiException {
          // The marker can remain arrived if completion persistence retries later.
        }
      }
    } on PlatformException {
      // Wi-Fi-only navigation remains available on devices without a sensor.
    } on TimeoutException {
      // A missed sensor poll must not interrupt navigation.
    } on NavigationApiException {
      // The next motion/Wi-Fi cycle will retry after a temporary failure.
    } finally {
      _readingMotion = false;
    }
  }

  // Retained for the explicit arrival action that will be wired to a room beacon/QR.
  // ignore: unused_element
  Future<void> _completeArrival() async {
    if (_arrived || _stopping || _sessionId == null) return;
    _arrived = true;
    _wifiTimer?.cancel();
    _motionTimer?.cancel();
    try {
      final completed = await _navigationApi.completeSession(
        sessionId: _sessionId!,
        clientId: _clientId,
      );
      if (mounted) {
        setState(() {
          _session = {
            ...?_session,
            'status': completed['status'],
            'completed_at': completed['completed_at'],
          };
        });
      }
    } on NavigationApiException {
      // Keep the local arrival state if a development backend restarts.
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 52,
        ),
        title: Text(t('You have arrived', 'ถึงจุดหมายแล้ว')),
        content: Text(widget.destinationLabel, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('Done', 'เสร็จสิ้น')),
          ),
        ],
      ),
    );
  }

  double get _remainingDistance {
    final route = ((_session?['route'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    if (route.length < 2) return 0;
    var distance = 0.0;
    for (var index = 1; index < route.length; index++) {
      final previous = route[index - 1];
      final current = route[index];
      if (previous['x'] is num &&
          previous['y'] is num &&
          current['x'] is num &&
          current['y'] is num) {
        distance += math.sqrt(
          math.pow(
                (current['x'] as num).toDouble() -
                    (previous['x'] as num).toDouble(),
                2,
              ) +
              math.pow(
                (current['y'] as num).toDouble() -
                    (previous['y'] as num).toDouble(),
                2,
              ),
        );
      }
    }
    return distance;
  }

  Future<void> _closeNavigation() async {
    _stopping = true;
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        await _navigationApi.finishSession(
          sessionId: sessionId,
          clientId: _clientId,
        );
      } on NavigationApiException {
        // The screen can still close when a local development service stops.
      }
    }
    if (!mounted) return;
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _wifiTimer?.cancel();
    _motionTimer?.cancel();
    _navigationApi.close();
    super.dispose();
  }

  void _openReportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapReportPage(
          currentLanguage: _language,
          navigationSessionId: _sessionId,
          estimatedPosition: (_session?['estimated_position'] as Map?)
              ?.cast<String, dynamic>(),
          initialLocation: widget.destinationLabel,
          onLanguageChanged: widget.onLanguageChanged,
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t('Emergency', 'ฉุกเฉิน')),
          content: Text(
            t(
              'Call emergency services now?',
              'โทรหาบริการฉุกเฉินตอนนี้หรือไม่?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Cancel', 'ยกเลิก')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t(
                        'Calling emergency number...',
                        'กำลังโทรหมายเลขฉุกเฉิน...',
                      ),
                    ),
                  ),
                );
              },
              child: Text(t('Call', 'โทร')),
            ),
          ],
        );
      },
    );
  }

  void _handleNoAlert() {
    setState(() {
      _showObstacleAlert = false;
    });
  }

  void _handleYesAlert() {
    setState(() {
      _showObstacleAlert = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('Assistance is on the way.', 'กำลังขอความช่วยเหลือ')),
        backgroundColor: _burgundy,
      ),
    );
  }

  void _toggleObstacleAlert() {
    setState(() {
      _showObstacleAlert = !_showObstacleAlert;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _burgundy,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleObstacleAlert,
              child: Container(
                color: Colors.grey.shade100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _FollowNavigationMap(
                      route: ((_session?['route'] as List?) ?? const [])
                          .whereType<Map>()
                          .toList(),
                      currentPosition: _session?['estimated_position'] as Map?,
                      uncertaintyMeters: _positionUncertaintyMeters,
                    ),
                    if (_error != null)
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _startNavigation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(
                            t('Retry connection', 'ลองเชื่อมต่อใหม่'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: UserPageHeader(
              title: t('Navigation', 'กำลังนำทาง'),
              subtitle: widget.destinationLabel,
              language: _language,
              onBack: _closeNavigation,
              onLanguageTap: _toggleLanguage,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 96,
            left: 0,
            right: 0,
            child: Center(child: _buildGuideCard()),
          ),
          Positioned(
            left: 16,
            top: MediaQuery.paddingOf(context).top + 178,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCircleActionButton(
                  icon: Icons.report,
                  iconColor: Colors.white,
                  backgroundColor: _burgundy,
                  label: t('Report', 'รายงาน'),
                  onTap: _openReportPage,
                ),
                const SizedBox(height: 14),
                _buildCircleActionButton(
                  icon: Icons.phone,
                  iconColor: Colors.white,
                  backgroundColor: Colors.green,
                  label: t('Emergency', 'ฉุกเฉิน'),
                  onTap: _showEmergencyDialog,
                ),
              ],
            ),
          ),
          if (_showObstacleAlert) _buildObstacleAlert(),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomBar()),
          if (_waitingForPosition && _error == null)
            Positioned.fill(child: _buildPositionLoadingOverlay()),
        ],
      ),
    );
  }

  Widget _buildPositionLoadingOverlay() {
    return ColoredBox(
      color: const Color(0xFFE9C5C5),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.16,
            child: Image.asset(
              'assets/welcome-background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          const ColoredBox(color: Color(0x77F3DADA)),
          SafeArea(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 118,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Positioned(
                            bottom: 2,
                            child: Container(
                              width: 60,
                              height: 13,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFFF3D32),
                            size: 112,
                          ),
                          const Positioned(
                            top: 24,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Color(0xFFD92222),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'MFU',
                      style: TextStyle(
                        color: _burgundy,
                        fontSize: 33,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      'SmartGuide',
                      style: TextStyle(
                        color: _burgundy,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 27),
                    Text(
                      t(
                        'Detecting your location...',
                        'กำลังระบุตำแหน่งของคุณ...',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF272323),
                        fontSize: 16,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(
                        'Please remain still for a moment',
                        'กรุณายืนรอสักครู่',
                      ),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 160,
                      child: LinearProgressIndicator(
                        value: (_completeFingerprintReadings / 3).clamp(0, 1),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                        color: _burgundy,
                        backgroundColor: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    final zone = _session?['zone_label']?.toString();
    final guideText = _isLoading
        ? t('Connecting navigation...', 'กำลังเชื่อมต่อระบบนำทาง...')
        : _error != null
        ? t('Backend connection failed', 'เชื่อมต่อ Backend ไม่สำเร็จ')
        : zone ?? t('Keep Straight on', 'เดินตรงไป');
    final distance = _remainingDistance;
    final displayedGuideText = !_isLoading && _error == null
        ? _arrived
              ? t('You have arrived', 'ถึงจุดหมายแล้ว')
              : distance > 0
              ? t(
                  'Continue for ${distance.toStringAsFixed(1)} m',
                  'เดินต่ออีก ${distance.toStringAsFixed(1)} ม.',
                )
              : guideText
        : guideText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: _burgundy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      color: _burgundy,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(Icons.arrow_upward, color: _burgundy),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              displayedGuideText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObstacleAlert() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _burgundy,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 18,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 46,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              t('An obstacle has been detected.', 'พบสิ่งกีดขวาง'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              t('Would you like assistance?', 'ต้องการขอความช่วยเหลือหรือไม่?'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleNoAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      t('NO', 'ไม่'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleYesAlert,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      t('YES', 'ใช่'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _burgundy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.destinationLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _closeNavigation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowNavigationMap extends StatefulWidget {
  final List<Map> route;
  final Map? currentPosition;
  final double uncertaintyMeters;

  const _FollowNavigationMap({
    required this.route,
    required this.currentPosition,
    required this.uncertaintyMeters,
  });

  @override
  State<_FollowNavigationMap> createState() => _FollowNavigationMapState();
}

class _FollowNavigationMapState extends State<_FollowNavigationMap>
    with TickerProviderStateMixin {
  static const double _estimatedWalkingSpeedMetersPerSecond = 1.1;
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _cameraController;
  late final AnimationController _markerController;
  Animation<Matrix4>? _cameraAnimation;
  Animation<Offset>? _markerAnimation;
  List<Offset> _movementPath = const [];
  Size _viewportSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _cameraController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 650),
        )..addListener(() {
          final animation = _cameraAnimation;
          if (animation != null) _transformController.value = animation.value;
        });
    _markerController = AnimationController(vsync: this)
      ..addListener(() {
        final position = _markerAnimation?.value;
        if (position != null) _followMeters(position, animate: false);
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _followUser());
  }

  @override
  void didUpdateWidget(covariant _FollowNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.currentPosition;
    final current = widget.currentPosition;
    if (old?['x'] != current?['x'] || old?['y'] != current?['y']) {
      if (current?['x'] is num && current?['y'] is num) {
        final end = Offset(
          (current!['x'] as num).toDouble(),
          (current['y'] as num).toDouble(),
        );
        // If a new Wi-Fi update arrives while the marker is moving, continue
        // from the currently visible point instead of jumping to the previous
        // target.
        final visible = _markerAnimation?.value;
        final begin = visible ??
            (old?['x'] is num && old?['y'] is num
                ? Offset(
                    (old!['x'] as num).toDouble(),
                    (old['y'] as num).toDouble(),
                  )
                : end);
        _movementPath = _pathToNewZone(
          begin: begin,
          end: end,
          previousRoute: oldWidget.route,
        );
        final distanceMeters = _polylineLength(_movementPath);
        final travelMilliseconds = math.max(
          350,
          math.min(
            30000,
            (distanceMeters /
                    _estimatedWalkingSpeedMetersPerSecond *
                    1000)
                .round(),
          ),
        );
        _markerController.duration = Duration(
          milliseconds: travelMilliseconds,
        );
        _markerAnimation = _PolylineTween(_movementPath).animate(
          CurvedAnimation(
            parent: _markerController,
            curve: Curves.linear,
          ),
        );
        _markerController.forward(from: 0);
      }
      // The marker listener keeps the camera centred while travelling. Do not
      // pan to the new zone anchor before the marker has reached it.
      if (_markerAnimation == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _followUser());
      }
    }
  }

  List<Offset> _pathToNewZone({
    required Offset begin,
    required Offset end,
    required List<Map> previousRoute,
  }) {
    // Normal walking progress arrives about once per second and advances only
    // 1.1 m. It is already constrained to the current route by the model, so
    // animate directly to that point. Rebuilding a path through old waypoints
    // here can briefly pull the marker/blue line backwards and look like a
    // route jump.
    if ((end - begin).distance <= 1.5) return [begin, end];

    final candidates = previousRoute
        .where((point) => point['x'] is num && point['y'] is num)
        .map(
          (point) => Offset(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          ),
        )
        .toList();
    if (candidates.isEmpty) return [begin, end];

    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < candidates.length; index++) {
      final distance = (candidates[index] - end).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }

    final path = <Offset>[begin];
    for (var index = 0; index <= closestIndex; index++) {
      if ((candidates[index] - path.last).distance > 0.01) {
        path.add(candidates[index]);
      }
    }
    if ((end - path.last).distance > 0.01) path.add(end);

    // If the previous route does not pass near the newly detected zone,
    // avoid a long detour and fall back to a direct visual transition.
    final directDistance = (end - begin).distance;
    if (closestDistance > 1.5 ||
        _polylineLength(path) > directDistance * 2 + 2) {
      return [begin, end];
    }
    return path;
  }

  double _polylineLength(List<Offset> points) {
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      total += (points[index] - points[index - 1]).distance;
    }
    return total;
  }

  List<Map> _displayRoute(Offset? current, double progress) {
    if (current == null || _movementPath.length < 2 || progress >= 1) {
      return _connectRouteOrigin(widget.route, current);
    }

    // Consume exactly the same distance along the movement polyline as the
    // marker animation. This makes the travelled blue segment disappear
    // continuously instead of jumping only when a waypoint is reached.
    final totalLength = _polylineLength(_movementPath);
    var consumed = totalLength * progress.clamp(0.0, 1.0);
    var nextPointIndex = 1;
    while (nextPointIndex < _movementPath.length) {
      final segmentLength =
          (_movementPath[nextPointIndex] -
                  _movementPath[nextPointIndex - 1])
              .distance;
      if (consumed < segmentLength) break;
      consumed -= segmentLength;
      nextPointIndex++;
    }

    final result = <Map>[];
    for (final point in _movementPath.skip(nextPointIndex)) {
      result.add({'x': point.dx, 'y': point.dy});
    }
    for (final point in widget.route) {
      final duplicate = result.isNotEmpty &&
          result.last['x'] is num &&
          result.last['y'] is num &&
          point['x'] is num &&
          point['y'] is num &&
          math.sqrt(
                math.pow(
                      (result.last['x'] as num).toDouble() -
                          (point['x'] as num).toDouble(),
                      2,
                    ) +
                    math.pow(
                      (result.last['y'] as num).toDouble() -
                          (point['y'] as num).toDouble(),
                      2,
                    ),
              ) <
              0.01;
      if (!duplicate) {
        result.add(point);
      }
    }
    return _connectRouteOrigin(result, current);
  }

  List<Map> _connectRouteOrigin(List<Map> route, Offset? current) {
    if (current == null || route.isEmpty) return route;
    final points = route
        .where((point) => point['x'] is num && point['y'] is num)
        .map(
          (point) => Offset(
            (point['x'] as num).toDouble(),
            (point['y'] as num).toDouble(),
          ),
        )
        .toList();
    if (points.length < 2) {
      return [
        {'x': current.dx, 'y': current.dy},
      ];
    }

    // Project the marker onto the closest remaining route segment and remove
    // points behind it. Connecting to waypoint #2 directly caused a short
    // back-and-forth section near the marker.
    var nearest = points.first;
    var nearestSegment = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < points.length - 1; index++) {
      final start = points[index];
      final delta = points[index + 1] - start;
      final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
      final fraction = lengthSquared == 0
          ? 0.0
          : (((current.dx - start.dx) * delta.dx +
                        (current.dy - start.dy) * delta.dy) /
                    lengthSquared)
                .clamp(0.0, 1.0);
      final projected = start + delta * fraction;
      final distance = (current - projected).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = projected;
        nearestSegment = index;
      }
    }

    final connected = <Map>[
      {'x': current.dx, 'y': current.dy},
    ];
    if ((nearest - current).distance > 0.08) {
      connected.add({'x': nearest.dx, 'y': nearest.dy});
    }
    for (final point in points.skip(nearestSegment + 1)) {
      final previous = connected.last;
      final distance = math.sqrt(
        math.pow(point.dx - (previous['x'] as num).toDouble(), 2) +
            math.pow(point.dy - (previous['y'] as num).toDouble(), 2),
      );
      if (distance > 0.08) {
        connected.add({'x': point.dx, 'y': point.dy});
      }
    }
    return connected;
  }

  void _followUser({bool animate = true}) {
    if (!mounted) return;
    final current = widget.currentPosition;
    if (current == null || current['x'] is! num || current['y'] is! num) return;
    _followMeters(
      Offset(
        (current['x'] as num).toDouble(),
        (current['y'] as num).toDouble(),
      ),
      animate: animate,
    );
  }

  void _followMeters(Offset meters, {required bool animate}) {
    if (!mounted || _viewportSize.isEmpty) return;
    final point = FloorPlanCoordinates.metersToCanvas(
      meters.dx,
      meters.dy,
      _viewportSize,
    );
    const zoom = 2.8;
    final target = Matrix4.identity()
      ..translateByDouble(
        _viewportSize.width / 2,
        _viewportSize.height / 2,
        0,
        1,
      )
      ..scaleByDouble(zoom, zoom, 1, 1)
      ..translateByDouble(-point.dx, -point.dy, 0, 1);
    if (!animate) {
      _cameraController.stop();
      _transformController.value = target;
      return;
    }
    _cameraAnimation =
        Matrix4Tween(begin: _transformController.value, end: target).animate(
          CurvedAnimation(
            parent: _cameraController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _cameraController.forward(from: 0);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _markerController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 1,
                maxScale: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/floorplan_clean.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                    AnimatedBuilder(
                      animation: _markerController,
                      builder: (context, _) {
                        final animated = _markerAnimation?.value;
                        final position = animated == null
                            ? widget.currentPosition
                            : {'x': animated.dx, 'y': animated.dy};
                        final routeOrigin = animated ??
                            (widget.currentPosition?['x'] is num &&
                                    widget.currentPosition?['y'] is num
                                ? Offset(
                                    (widget.currentPosition!['x'] as num)
                                        .toDouble(),
                                    (widget.currentPosition!['y'] as num)
                                        .toDouble(),
                                  )
                                : null);
                        return CustomPaint(
                          painter: _NavigationRoutePainter(
                            route: _displayRoute(
                              routeOrigin,
                              _markerController.value,
                            ),
                            currentPosition: position,
                            uncertaintyMeters: widget.uncertaintyMeters,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 120,
              child: IconButton.filled(
                tooltip: 'Follow current position',
                onPressed: _followUser,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF8B0000),
                ),
                icon: const Icon(Icons.my_location_rounded),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PolylineTween extends Animatable<Offset> {
  final List<Offset> points;
  late final List<double> _segmentLengths;
  late final double _totalLength;

  _PolylineTween(List<Offset> source)
    : points = source.length >= 2 ? source : [source.first, source.first] {
    _segmentLengths = <double>[];
    var total = 0.0;
    for (var index = 1; index < points.length; index++) {
      final length = (points[index] - points[index - 1]).distance;
      _segmentLengths.add(length);
      total += length;
    }
    _totalLength = total;
  }

  @override
  Offset transform(double t) {
    if (_totalLength <= 0 || t >= 1) return points.last;
    var remaining = _totalLength * t.clamp(0.0, 1.0);
    for (var index = 0; index < _segmentLengths.length; index++) {
      final length = _segmentLengths[index];
      if (remaining <= length && length > 0) {
        return Offset.lerp(
          points[index],
          points[index + 1],
          remaining / length,
        )!;
      }
      remaining -= length;
    }
    return points.last;
  }
}

class _NavigationRoutePainter extends CustomPainter {
  final List<Map> route;
  final Map? currentPosition;
  final double uncertaintyMeters;

  const _NavigationRoutePainter({
    required this.route,
    required this.currentPosition,
    required this.uncertaintyMeters,
  });

  Offset _toCanvas(double xMeters, double yMeters, Rect imageRect) {
    final sourcePoint = FloorPlanCoordinates.metersToImage(xMeters, yMeters);
    return Offset(
      imageRect.left +
          sourcePoint.dx /
              FloorPlanCoordinates.imageSize.width *
              imageRect.width,
      imageRect.top +
          sourcePoint.dy /
              FloorPlanCoordinates.imageSize.height *
              imageRect.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final imageRect = FloorPlanCoordinates.containedImageRect(size);
    if (route.isNotEmpty) {
      final path = Path();
      var hasStart = false;
      final current = currentPosition;
      if (current != null && current['x'] is num && current['y'] is num) {
        final start = _toCanvas(
          (current['x'] as num).toDouble(),
          (current['y'] as num).toDouble(),
          imageRect,
        );
        path.moveTo(start.dx, start.dy);
        hasStart = true;
      }
      for (var index = 0; index < route.length; index++) {
        final x = (route[index]['x'] as num).toDouble();
        final y = (route[index]['y'] as num).toDouble();
        final point = _toCanvas(x, y, imageRect);
        if (index == 0 && !hasStart) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF1976D2)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      final destination = route.last;
      canvas.drawCircle(
        _toCanvas(
          (destination['x'] as num).toDouble(),
          (destination['y'] as num).toDouble(),
          imageRect,
        ),
        7,
        Paint()..color = Colors.red,
      );
    }
    final current = currentPosition;
    if (current != null && current['x'] is num && current['y'] is num) {
      final currentX = (current['x'] as num).toDouble();
      final currentY = (current['y'] as num).toDouble();
      final point = _toCanvas(
        currentX,
        currentY,
        imageRect,
      );
      final radiusPoint = _toCanvas(
        currentX + uncertaintyMeters,
        currentY,
        imageRect,
      );
      final radius = (radiusPoint - point).distance;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = Colors.green.withValues(alpha: 0.45)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(point, 8, Paint()..color = Colors.green);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _NavigationRoutePainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.currentPosition != currentPosition ||
        oldDelegate.uncertaintyMeters != uncertaintyMeters;
  }
}
