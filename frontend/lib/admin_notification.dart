import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'admin_detail.dart';
import 'admin_setting.dart';

enum NotificationLanguage { english, thai }

enum NotificationTab { barrierReport, emergencyAlerts }

class AdminNotificationPage extends StatefulWidget {
  const AdminNotificationPage({super.key});

  @override
  State<AdminNotificationPage> createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  NotificationLanguage _language = NotificationLanguage.english;
  NotificationTab _selectedTab = NotificationTab.barrierReport;

  bool get _isEnglish => _language == NotificationLanguage.english;

  // แก้ไขข้อความต่างดาวเป็นภาษาไทยที่ถูกต้อง
  String get _title => _isEnglish ? 'Notification' : 'การแจ้งเตือน';
  String get _barrierTab => _isEnglish ? 'Barrier Report' : 'รายงานสิ่งกีดขวาง';
  String get _emergencyTab => _isEnglish ? 'Emergency Alerts' : 'แจ้งเตือนฉุกเฉิน';
  String get _dashboardLabel => _isEnglish ? 'Dashboard' : 'แดชบอร์ด';
  String get _notificationLabel => _isEnglish ? 'Notification' : 'การแจ้งเตือน';
  String get _settingLabel => _isEnglish ? 'Setting' : 'การตั้งค่า';
  String get _approvedLabel => _isEnglish ? 'Appved' : 'อนุมัติแล้ว'; // ตามรูปใช้คำว่า Appved
  String get _rejectLabel => _isEnglish ? 'Reject' : 'ปฏิเสธ';
  String get _seeDetails => _isEnglish ? 'See details' : 'ดูรายละเอียด';
  String get _makeInProgress => _isEnglish ? 'Make as In Progress' : 'กำลังดำเนินการ';
  String get _makeResolved => _isEnglish ? 'Make as Resolved' : 'แก้ไขแล้ว';
  String get _roomLabel => _isEnglish ? 'Room' : 'ห้อง';
  String get _byLabel => _isEnglish ? 'By' : 'โดย';

  void _toggleLanguage() {
    setState(() {
      _language = _isEnglish ? NotificationLanguage.thai : NotificationLanguage.english;
    });
  }

  void _selectTab(NotificationTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
    );
  }

  void _navigateToSetting() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminSettingPage()),
    );
  }

  void _navigateToDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDetailPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _NotificationHeader(
            title: _title,
            languageCode: _isEnglish ? 'EN' : 'TH',
            onLanguageTap: _toggleLanguage,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _NotificationTabBar(
              selectedTab: _selectedTab,
              barrierLabel: _barrierTab,
              emergencyLabel: _emergencyTab,
              onBarrierTap: () => _selectTab(NotificationTab.barrierReport),
              onEmergencyTap: () => _selectTab(NotificationTab.emergencyAlerts),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_selectedTab == NotificationTab.barrierReport) ...[
                    NotificationBarrierCard(
                      roomTitle: '${_roomLabel} 301',
                      reporter: '${_byLabel} Asia Thongkong ',
                      locationLabel: 'AS',
                      approvedLabel: _approvedLabel,
                      rejectLabel: _rejectLabel,
                      seeDetailsLabel: _seeDetails,
                      onApproved: () => _showSnackBar(_approvedLabel),
                      onReject: () => _showSnackBar(_rejectLabel),
                      onSeeDetails: _navigateToDetail,
                    ),
                    const SizedBox(height: 16),
                    NotificationBarrierCard(
                      roomTitle: '${_roomLabel} 302',
                      reporter: '${_byLabel} Asia Thongkong ',
                      locationLabel: 'AS',
                      approvedLabel: _approvedLabel,
                      rejectLabel: _rejectLabel,
                      seeDetailsLabel: _seeDetails,
                      onApproved: () => _showSnackBar(_approvedLabel),
                      onReject: () => _showSnackBar(_rejectLabel),
                      onSeeDetails: _navigateToDetail,
                    ),
                  ] else ...[
                    NotificationAlertCard(
                      username: 'Asia Thongkong ',
                      emergencyType: 'SOS Button Pressed',
                      timeLabel: '10.00 AM',
                      buttonLabel: _makeInProgress,
                      buttonColor: const Color(0xFF007AFF), // สีฟ้าตามภาพ
                      locationText: '${_roomLabel} 301 2nd Floor, AS',
                      onButtonTap: () => _showSnackBar(_makeInProgress),
                    ),
                    const SizedBox(height: 16),
                    NotificationAlertCard(
                      username: 'Asia Thongkong ',
                      emergencyType: 'SOS Button Pressed',
                      timeLabel: '11.00 AM',
                      buttonLabel: _makeResolved,
                      buttonColor: const Color(0xFF10B981), // สีเขียวตามภาพ
                      locationText: '${_roomLabel} 302 2nd Floor, AS',
                      onButtonTap: () => _showSnackBar(_makeResolved),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        backgroundColor: const Color(0xFF8B0000),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            _navigateToDashboard();
          } else if (index == 2) {
            _navigateToSetting();
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.map_outlined),
            label: _dashboardLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.mail_outline),
            label: _notificationLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: _settingLabel,
          ),
        ],
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  final String title;
  final String languageCode;
  final VoidCallback onLanguageTap;

  const _NotificationHeader({
    required this.title,
    required this.languageCode,
    required this.onLanguageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: const BoxDecoration(
        color: Color(0xFF8B0000),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: onLanguageTap,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  languageCode,
                  style: const TextStyle(
                    color: Color(0xFF8B0000),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTabBar extends StatelessWidget {
  final NotificationTab selectedTab;
  final String barrierLabel;
  final String emergencyLabel;
  final VoidCallback onBarrierTap;
  final VoidCallback onEmergencyTap;

  const _NotificationTabBar({
    required this.selectedTab,
    required this.barrierLabel,
    required this.emergencyLabel,
    required this.onBarrierTap,
    required this.onEmergencyTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onBarrierTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: selectedTab == NotificationTab.barrierReport
                    ? const Color(0xFFC81E1E) // สีแดงเข้มตามภาพ
                    : const Color(0xFFE2C2C2), // สีเนื้ออ่อนตามภาพ
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                barrierLabel,
                style: TextStyle(
                  color: selectedTab == NotificationTab.barrierReport
                      ? Colors.white
                      : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onEmergencyTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: selectedTab == NotificationTab.emergencyAlerts
                    ? const Color(0xFFC81E1E)
                    : const Color(0xFFE2C2C2),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                emergencyLabel,
                style: TextStyle(
                  color: selectedTab == NotificationTab.emergencyAlerts
                      ? Colors.white
                      : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationBarrierCard extends StatelessWidget {
  final String roomTitle;
  final String reporter;
  final String locationLabel;
  final String approvedLabel;
  final String rejectLabel;
  final String seeDetailsLabel;
  final VoidCallback onApproved;
  final VoidCallback onReject;
  final VoidCallback onSeeDetails;

  const NotificationBarrierCard({
    super.key,
    required this.roomTitle,
    required this.reporter,
    required this.locationLabel,
    required this.approvedLabel,
    required this.rejectLabel,
    required this.seeDetailsLabel,
    required this.onApproved,
    required this.onReject,
    required this.onSeeDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8), // พื้นหลังเทาอ่อนตามภาพ
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                roomTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(width: 24),
              Text(
                reporter,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onApproved,
                  child: Text(
                    approvedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 100,
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53E3E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onReject,
                  child: Text(
                    rejectLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.black87,
              ),
              const SizedBox(width: 6),
              Text(
                locationLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeDetails,
                child: Text(
                  seeDetailsLabel,
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationAlertCard extends StatelessWidget {
  final String username;
  final String emergencyType;
  final String timeLabel;
  final String buttonLabel;
  final Color buttonColor;
  final String locationText;
  final VoidCallback onButtonTap;

  const NotificationAlertCard({
    super.key,
    required this.username,
    required this.emergencyType,
    required this.timeLabel,
    required this.buttonLabel,
    required this.buttonColor,
    required this.locationText,
    required this.onButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User name : $username',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Emergency Type : $emergencyType',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Time : $timeLabel',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 32,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: onButtonTap,
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.black87,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  locationText,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}