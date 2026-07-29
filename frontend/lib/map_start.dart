import 'package:flutter/material.dart';
import 'package:mfuguide/map_report.dart';
import 'package:mfuguide/floor_plan_coordinates.dart';
import 'package:mfuguide/navigation_api.dart';
import 'package:mfuguide/user_page_header.dart';

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
  bool _showObstacleAlert = false;
  bool _isLoading = true;
  bool _stopping = false;
  String? _error;
  String? _sessionId;
  late final String _clientId;
  Map<String, dynamic>? _session;

  late String _language;

  String t(String en, String th) => _language == 'EN' ? en : th;

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
      _error = null;
    });
    try {
      if (_sessionId == null) {
        final created = await _navigationApi.createSession(
          clientId: _clientId,
          destinationId: widget.destinationId,
        );
        _sessionId = created['session_id']?.toString();
      }
      if (_sessionId == null) {
        throw const NavigationApiException(
          'Backend did not return a navigation session id.',
        );
      }
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
        setState(() {
          _session = current;
          _isLoading = false;
        });
        await Future<void>.delayed(const Duration(milliseconds: 850));
      }
    } on NavigationApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
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
    _navigationApi.close();
    super.dispose();
  }

  void _openReportPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapReportPage(
          currentLanguage: _language,
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
              guideText,
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
    final route = (_session?['route'] as List?) ?? const [];
    final position = _session?['estimated_position'] as Map?;
    final positionText = position == null
        ? t('Waiting for position', 'กำลังรอตำแหน่ง')
        : '(${position['x']}, ${position['y']}) • ${route.length} waypoints';
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
                const SizedBox(height: 6),
                Text(
                  positionText,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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

  const _FollowNavigationMap({
    required this.route,
    required this.currentPosition,
  });

  @override
  State<_FollowNavigationMap> createState() => _FollowNavigationMapState();
}

class _FollowNavigationMapState extends State<_FollowNavigationMap>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late final AnimationController _cameraController;
  Animation<Matrix4>? _cameraAnimation;
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _followUser());
  }

  @override
  void didUpdateWidget(covariant _FollowNavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.currentPosition;
    final current = widget.currentPosition;
    if (old?['x'] != current?['x'] || old?['y'] != current?['y']) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followUser());
    }
  }

  Offset? _positionOnCanvas() {
    final current = widget.currentPosition;
    if (current == null ||
        current['x'] is! num ||
        current['y'] is! num ||
        _viewportSize.isEmpty) {
      return null;
    }
    return FloorPlanCoordinates.metersToCanvas(
      (current['x'] as num).toDouble(),
      (current['y'] as num).toDouble(),
      _viewportSize,
    );
  }

  void _followUser() {
    if (!mounted) return;
    final point = _positionOnCanvas();
    if (point == null) return;
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
                    CustomPaint(
                      painter: _NavigationRoutePainter(
                        route: widget.route,
                        currentPosition: widget.currentPosition,
                      ),
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

class _NavigationRoutePainter extends CustomPainter {
  final List<Map> route;
  final Map? currentPosition;

  const _NavigationRoutePainter({
    required this.route,
    required this.currentPosition,
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
      for (var index = 0; index < route.length; index++) {
        final x = (route[index]['x'] as num).toDouble();
        final y = (route[index]['y'] as num).toDouble();
        final point = _toCanvas(x, y, imageRect);
        if (index == 0) {
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
      final point = _toCanvas(
        (current['x'] as num).toDouble(),
        (current['y'] as num).toDouble(),
        imageRect,
      );
      canvas.drawCircle(point, 8, Paint()..color = Colors.green);
      canvas.drawCircle(point, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _NavigationRoutePainter oldDelegate) {
    return oldDelegate.route != route ||
        oldDelegate.currentPosition != currentPosition;
  }
}
