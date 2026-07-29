
import 'package:flutter/material.dart';
import 'package:mfuguide/map_report.dart';

class MapStartPage extends StatefulWidget {
  final String currentLanguage;
  final ValueChanged<String>? onLanguageChanged;

  const MapStartPage({
    super.key,
    this.currentLanguage = 'EN',
    this.onLanguageChanged,
  });

  @override
  State<MapStartPage> createState() => _MapStartPageState();
}

class _MapStartPageState extends State<MapStartPage> {
  final Color _burgundy = const Color(0xFF8B0000);
  bool _showObstacleAlert = false;

  String get _language => widget.currentLanguage;

  String t(String en, String th) => _language == 'EN' ? en : th;

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
            t('Call emergency services now?', 'โทรหาบริการฉุกเฉินตอนนี้หรือไม่?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t('Cancel', 'ยกเลิก')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(
                      'Calling emergency number...',
                      'กำลังโทรหมายเลขฉุกเฉิน...',
                    )),
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
        content: Text(t(
          'Assistance is on the way.',
          'กำลังขอความช่วยเหลือ',
        )),
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
                child: const Center(
                  child: Text(
                    'MAP PLAN',
                    style: TextStyle(
                      color: Colors.black26,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 32,
            left: 0,
            right: 0,
            child: Center(child: _buildGuideCard()),
          ),
          Positioned(
            left: 16,
            top: 120,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: _burgundy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
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
            child: Icon(
              Icons.arrow_upward,
              color: _burgundy,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            t('Keep Straight on', 'เดินตรงไป'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
                  color: Colors.black.withOpacity(0.14),
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
              color: Colors.black.withOpacity(0.2),
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
              t(
                'Would you like assistance?',
                'ต้องการขอความช่วยเหลือหรือไม่?',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
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
      color: _burgundy,
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('3 min', '3 นาที'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '0.06 m   16.39',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E2E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
