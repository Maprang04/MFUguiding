import 'package:flutter/material.dart';

import 'admin_notification.dart';
import 'admin_setting.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

enum DashboardLanguage { english, thai }

enum DashboardTab { dashboard, notification, setting }

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  DashboardLanguage _language = DashboardLanguage.english;
  DashboardTab _selectedTab = DashboardTab.dashboard;

  bool get _isEnglish => _language == DashboardLanguage.english;

  // แก้ไขภาษาไทยต่างดาวให้ถูกต้องเรียบร้อยครับ
  String get _pageTitle => _isEnglish ? 'Dashboard' : 'แดชบอร์ด';
  String get _totalUsersLabel => _isEnglish ? 'Total\nUsers' : 'ผู้ใช้งาน\nทั้งหมด';
  String get _activeUsersLabel => _isEnglish ? 'Active\nUsers' : 'ผู้ใช้งาน\nขณะนี้';
  String get _barrierReportLabel => _isEnglish ? 'Barrier\nReport' : 'รายงาน\nสิ่งกีดขวาง';
  String get _emergencyAlertsLabel => _isEnglish ? 'Emergency\nAlerts' : 'แจ้งเตือน\nฉุกเฉิน';
  String get _dashboardLabel => _isEnglish ? 'Dashboard' : 'แดชบอร์ด';
  String get _notificationLabel => _isEnglish ? 'Notification' : 'การแจ้งเตือน';
  String get _settingLabel => _isEnglish ? 'Setting' : 'การตั้งค่า';

  void _toggleLanguage() {
    setState(() {
      _language = _isEnglish ? DashboardLanguage.thai : DashboardLanguage.english;
    });
  }

  void _onBottomNavTap(int index) {
    switch (index) {
      case 0:
        setState(() {
          _selectedTab = DashboardTab.dashboard;
        });
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminNotificationPage(),
          ),
        );
        setState(() {
          _selectedTab = DashboardTab.notification;
        });
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdminSettingPage(),
          ),
        );
        setState(() {
          _selectedTab = DashboardTab.setting;
        });
        break;
    }
  }

  void _navigateToNotificationPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminNotificationPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _DashboardHeader(
            title: _pageTitle,
            languageCode: _isEnglish ? 'EN' : 'TH',
            onLanguageTap: _toggleLanguage,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GridView.count(
                physics: const BouncingScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 0.95,
                children: [
                  DashboardStatCard(
                    title: _totalUsersLabel,
                    count: '7',
                    backgroundColor: const Color(0xFF3B82F6), // สีฟ้า
                    onTap: () {},
                  ),
                  DashboardStatCard(
                    title: _activeUsersLabel,
                    count: '7',
                    backgroundColor: const Color(0xFF34D399), // สีเขียว
                    onTap: () {},
                  ),
                  DashboardStatCard(
                    title: _barrierReportLabel,
                    count: '6',
                    backgroundColor: const Color(0xFFF1A864), // สีส้มพาสเทลตรงตามภาพ
                    onTap: _navigateToNotificationPage,
                  ),
                  DashboardStatCard(
                    title: _emergencyAlertsLabel,
                    count: '5',
                    backgroundColor: const Color(0xFFB8282B), // สีแดงเข้มตรงตามภาพ
                    onTap: _navigateToNotificationPage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab.index,
        backgroundColor: const Color(0xFF8B0000),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: _onBottomNavTap,
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

class _DashboardHeader extends StatelessWidget {
  final String title;
  final String languageCode;
  final VoidCallback onLanguageTap;

  const _DashboardHeader({
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

class DashboardStatCard extends StatelessWidget {
  final String title;
  final String count;
  final Color backgroundColor;
  final VoidCallback onTap;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.count,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                count,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
